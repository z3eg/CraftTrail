"""Export factual WotLK ink/milling relationships from supplied core and DBC data.

Run from any directory. No database connection, game files copied, or server changes.
"""
import argparse
import hashlib
import json
import re
import struct
import subprocess
from collections import defaultdict
from pathlib import Path

ADDON = Path(__file__).resolve().parents[1]


def dbc_rows(path):
    data = path.read_bytes()
    magic, count, fields, size, _ = struct.unpack_from("<4s4I", data)
    assert magic == b"WDBC" and size == fields * 4
    for index in range(count):
        yield struct.unpack_from("<" + "I" * fields, data, 20 + index * size)


def loot_rows(path):
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^\((\d+),(\d+),(\d+),([\d.]+),\d+,\d+,\d+,(\d+),(\d+),", line)
        if match:
            yield tuple(float(v) if i == 3 else int(v) for i, v in enumerate(match.groups()))


def generate():
    references = defaultdict(list)
    for entry, item, reference, chance, minimum, maximum in loot_rows(SQL / "reference_loot_template.sql"):
        references[entry].append((item, reference, chance, minimum, maximum))

    def resolve(item, reference, chance, minimum, maximum, visited=()):
        if not reference:
            return [(item, chance, minimum, maximum)]
        assert reference not in visited, "Cyclic milling reference"
        result = []
        for child in references[reference]:
            result.extend(resolve(*child, visited + (reference,)))
        return result

    herbs = defaultdict(dict)
    for herb, item, reference, chance, minimum, maximum in loot_rows(SQL / "milling_loot_template.sql"):
        for pigment, probability, low, high in resolve(item, reference, chance, minimum, maximum):
            herbs[pigment][herb] = (probability, low, high)

    data = DBC.read_bytes()
    magic, count, fields, size, pool_size = struct.unpack_from("<4s4I", data)
    assert magic == b"WDBC" and fields == 234 and size == fields * 4
    pool = data[20 + count * size:]
    def dbc_string(offset):
        return pool[offset:pool.index(0, offset)].decode("utf-8") if offset else ""
    spell_classes = defaultdict(int)
    for row in dbc_rows(ABILITIES):
        spell_classes[row[2]] |= row[4]
    tab_classes = {row[0]: row[20] for row in dbc_rows(TALENT_TABS)}
    for row in dbc_rows(TALENTS):
        for spell in row[4:9]:
            if spell:
                spell_classes[spell] |= tab_classes.get(row[1], 0)
    class_names = defaultdict(dict)
    inks, apply_glyph = {}, {}
    wanted = {39469, 39774, *range(43115, 43128)}
    for index in range(count):
        row = struct.unpack_from("<234I", data, 20 + index * size)
        if spell_classes[row[0]]:
            name = dbc_string(row[136])
            if name:
                for player_class in range(1, 12):
                    if spell_classes[row[0]] & (1 << (player_class - 1)):
                        old = class_names[player_class].get(name)
                        candidate = (row[39], row[0])
                        if old is None or candidate < old:
                            class_names[player_class][name] = candidate
        for effect in range(3):
            if row[71 + effect] == 74:  # SPELL_EFFECT_APPLY_GLYPH
                apply_glyph[row[0]] = row[110 + effect]
            output = row[107 + effect]
            if output not in wanted or row[71 + effect] != 24:  # SPELL_EFFECT_CREATE_ITEM
                continue
            reagents = [(row[52 + n], row[60 + n]) for n in range(8) if row[52 + n] in herbs]
            if not reagents:
                continue
            assert len(reagents) == 1, "Ink recipe needs multiple pigments"
            pigment, amount = reagents[0]
            inks[output] = (row[0], pigment, amount)
    assert set(inks) == wanted, f"Missing ink recipes: {wanted - set(inks)}"

    needed = set(inks) | {value[1] for value in inks.values()}
    needed |= {herb for pigment in needed for herb in herbs.get(pigment, {})}
    glyph_data = GLYPHS.read_bytes()
    magic, glyph_count, glyph_fields, glyph_size, _ = struct.unpack_from("<4s4I", glyph_data)
    assert magic == b"WDBC" and glyph_fields == 4 and glyph_size == 16
    properties = {}
    for index in range(glyph_count):
        row = struct.unpack_from("<4I", glyph_data, 20 + index * glyph_size)
        properties[row[0]] = row[2]
    names, herb_skill, glyph_levels, glyph_types, glyph_classes = {}, {}, {}, {}, {}
    herb_ids = {herb for entries in herbs.values() for herb in entries}
    # The first five item_template columns are numeric IDs and the SQL-quoted name.
    pattern = re.compile(r"^\((\d+),(\d+),(\d+),-?\d+,'((?:\\.|[^'\\])*)',")
    columns = []
    with (SQL / "item_template.sql").open(encoding="utf-8") as source:
        for line in source:
            if line.startswith("  `"):
                columns.append(line.split("`")[1])
            match = pattern.match(line)
            if not match:
                continue
            item = int(match[1])
            if item in needed:
                names[item] = match[4].replace("\\'", "'").replace("\\\\", "\\")
            if item in herb_ids or int(match[2]) == 16:
                numeric = line[match.end():].split(",", 15)
                if item in herb_ids:
                    herb_skill[item] = int(numeric[13])  # RequiredSkillRank, column 18
                if int(match[2]) == 16:
                    glyph_levels[item] = int(numeric[11])  # RequiredLevel, column 16
                    glyph_classes[item] = int(match[3])
                    # Numeric item columns through spellid_5 precede the next text field.
                    rest = line[match.end():].split(",", 125)
                    for column in (columns.index(f"spellid_{n}") - 5 for n in range(1, 6)):
                        spell = int(rest[column])
                        if spell in apply_glyph:
                            glyph_types[item] = properties[apply_glyph[spell]]
    assert needed <= names.keys(), f"Missing item names: {needed - names.keys()}"

    lines = ["-- Generated factual WotLK relationships; see tools/generate_data.py and README.md.",
             "local addonName, addon = ...", "addon.inks = {"]
    for ink, (spell, pigment, amount) in sorted(inks.items()):
        lines.append(f"    [{ink}] = {{ pigment = {pigment}, count = {amount}, spell = {spell} }},")
    lines.extend(["}", "addon.herbs = {"])
    for pigment in sorted({value[1] for value in inks.values()}):
        entries = ", ".join(str(herb) for herb in sorted(herbs[pigment], key=lambda key: names[key]))
        lines.append(f"    [{pigment}] = {{ {entries} }},")
    lines.extend(["}", "addon.names = {"])
    for item, name in sorted(names.items()):
        lines.append(f"    [{item}] = {json.dumps(name, ensure_ascii=False)},")
    lines.extend(["}", "addon.herbSkill = {"])
    for item, skill in sorted(herb_skill.items()):
        lines.append(f"    [{item}] = {skill},")
    lines.extend(["}", "addon.glyphLevels = {"])
    for item, level in sorted(glyph_levels.items()):
        lines.append(f"    [{item}] = {level},")
    assert set(glyph_types.values()) <= {0, 1}, "Unexpected glyph type flags"
    lines.extend(["}", "addon.glyphTypes = {"])
    for item, kind in sorted(glyph_types.items()):
        lines.append(f"    [{item}] = {kind},")
    lines.extend(["}", "addon.glyphClasses = {"])
    for item, player_class in sorted(glyph_classes.items()):
        lines.append(f"    [{item}] = {player_class},")
    lines.extend(["}", "addon.classSpells = {"])
    for player_class, values in sorted(class_names.items()):
        entries = ", ".join(str(value[1]) for _, value in sorted(values.items()))
        lines.append(f"    [{player_class}] = {{ {entries} }},")
    lines.extend(["}", ""])
    (ADDON / "Data.lua").write_text("\n".join(lines), encoding="utf-8")
    manifest = {
        "coreCommit": subprocess.check_output(["git", "-C", str(CORE), "rev-parse", "HEAD"], text=True).strip(),
        "inputs": {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in
                   [DBC, GLYPHS, ABILITIES, TALENTS, TALENT_TABS, SQL / "milling_loot_template.sql", SQL / "reference_loot_template.sql", SQL / "item_template.sql"]},
        "inkCount": len(inks), "pigmentCount": len(herbs), "itemCount": len(names),
        "glyphLevelCount": len(glyph_levels), "classifiedGlyphCount": len(glyph_types),
        "note": "Local base SQL and client DBC snapshot; live database overrides were not queried."
    }
    (ADDON / "tools/data-sources.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Exported {len(inks)} inks, {len(herbs)} pigments, {len(names)} item references.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-root", required=True, type=Path, help="AzerothCore checkout containing base world SQL")
    parser.add_argument("--dbc-dir", required=True, type=Path, help="Directory containing matching 3.3.5a DBC files")
    args = parser.parse_args()
    CORE = args.core_root.resolve()
    SQL = CORE / "data/sql/base/db_world"
    DBC = args.dbc_dir.resolve() / "Spell.dbc"
    GLYPHS = DBC.with_name("GlyphProperties.dbc")
    ABILITIES = DBC.with_name("SkillLineAbility.dbc")
    TALENTS = DBC.with_name("Talent.dbc")
    TALENT_TABS = DBC.with_name("TalentTab.dbc")
    generate()
