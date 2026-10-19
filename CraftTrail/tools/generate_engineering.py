"""Generate Engineering dependency recipes from supplied 3.3.5a DBCs and core SQL."""
import argparse
import hashlib
import json
import re
import struct
import subprocess
from collections import defaultdict
from pathlib import Path


def rows(path):
    data = path.read_bytes()
    magic, count, fields, size, _ = struct.unpack_from('<4s4I', data)
    assert magic == b'WDBC' and size == fields * 4
    return [struct.unpack_from('<' + 'I' * fields, data, 20 + index * size) for index in range(count)]


def generate(core, dbc, all_professions=False):
    skills = defaultdict(set)
    professions = {129, 164, 165, 171, 185, 186, 197, 202, 333, 755, 773}
    for row in rows(dbc / 'SkillLineAbility.dbc'):
        if row[1] in professions:
            skills[row[2]].add(row[1])
    outputs = defaultdict(list)
    for row in rows(dbc / 'Spell.dbc'):
        if row[0] not in skills:
            continue
        reagents = [(row[52 + index], row[60 + index]) for index in range(8)
                    if row[52 + index] and row[60 + index]]
        if not reagents:
            continue
        for effect in range(3):
            if row[71 + effect] != 24 or not row[107 + effect]:
                continue
            base = struct.unpack('<i', struct.pack('<I', row[80 + effect]))[0]
            dice = struct.unpack('<i', struct.pack('<I', row[74 + effect]))[0]
            low = max(1, base + (min(1, dice) if dice else 0))
            high = max(low, base + (max(1, dice) if dice else 0))
            for skill in sorted(skills[row[0]]):
                outputs[row[107 + effect]].append((row[0], skill, low, high, reagents))
    # Include every Engineering output plus the transitive craftable components.
    wanted = {item for item, recipes in outputs.items() if any(recipe[1] == 202 for recipe in recipes)}
    engineering_count = len(wanted)
    if all_professions:
        wanted = set(outputs)
    pending, visited = list(wanted), set()
    while pending:
        item = pending.pop()
        if item in visited:
            continue
        visited.add(item)
        for recipe in outputs.get(item, []):
            for reagent, _ in recipe[4]:
                if reagent not in visited:
                    pending.append(reagent)
    names = {}
    sql = core / 'data/sql/base/db_world/item_template.sql'
    pattern = re.compile(r"^\((\d+),\d+,\d+,-?\d+,'((?:\\.|[^'\\])*)',")
    for line in sql.read_text(encoding='utf-8').splitlines():
        match = pattern.match(line)
        if match and int(match[1]) in visited:
            names[int(match[1])] = match[2].replace("\\'", "'").replace('\\\\', '\\')
    assert engineering_count > 100, f'Unexpected Engineering output count: {engineering_count}'
    missing_names = sorted(visited - names.keys())
    if not all_professions:
        assert not missing_names, f'Missing item names: {missing_names}'
    manifest_name = 'profession-sources.json' if all_professions else 'engineering-sources.json'
    lines = [f'-- Generated factual 3.3.5a crafting relationships; see tools/{manifest_name}.',
             'local addonName, addon = ...', 'addon.componentRecipes = {']
    for item in sorted(visited):
        if item not in outputs:
            continue
        lines.append(f'    [{item}] = {{')
        for spell, skill, low, high, reagents in sorted(outputs[item]):
            entries = ', '.join(f'{{{reagent}, {count}}}' for reagent, count in reagents)
            lines.append(f'        {{ spell = {spell}, skill = {skill}, min = {low}, max = {high}, reagents = {{ {entries} }} }},')
        lines.append('    },')
    lines.extend(['}', 'addon.componentNames = {'])
    for item, name in sorted(names.items()):
        lines.append(f'    [{item}] = {json.dumps(name, ensure_ascii=False)},')
    lines.extend(['}', ''])
    addon = Path(__file__).resolve().parents[1]
    target = 'ProfessionData.lua' if all_professions else 'EngineeringData.lua'
    (addon / target).write_text('\n'.join(lines), encoding='utf-8')
    inputs = [dbc / 'Spell.dbc', dbc / 'SkillLineAbility.dbc', sql]
    manifest = {'coreCommit': subprocess.check_output(['git', '-C', str(core), 'rev-parse', 'HEAD'], text=True).strip(),
                'engineeringOutputs': engineering_count, 'referencedItems': len(visited),
                'craftableItems': sum(item in outputs for item in visited),
                'professionRecipeCounts': {str(skill): sum(recipe[1] == skill for recipes in outputs.values() for recipe in recipes)
                                           for skill in sorted(professions)},
                'missingSqlItemNames': missing_names,
                'inputs': {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in inputs},
                'note': 'Base SQL/DBC snapshot. All alternate recipes retained; no live database queried.'}
    (addon / 'tools' / manifest_name).write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(f'Engineering outputs: {engineering_count}; referenced items: {len(visited)}.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--core-root', type=Path, required=True)
    parser.add_argument('--dbc-dir', type=Path, required=True)
    args = parser.parse_args()
    generate(args.core_root.resolve(), args.dbc_dir.resolve())
