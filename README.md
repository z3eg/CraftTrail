# CraftTrail

Recipe material trails for World of Warcraft **Wrath of the Lich King 3.3.5a**
(interface 30300).

**CraftTrail 2.0.0** displays the selected recipe as a connected material tree,
with native item links, required/allocated bag counts, per-node Craft buttons,
disabled reasons, batch yields and alternate recipes. It uses the native
profession Create action rather than trying to cast profession recipes by name.

Supported recipe windows: Alchemy, Blacksmithing, Enchanting, Engineering,
Inscription, Jewelcrafting, Leatherworking, Tailoring, Smelting/Mining, Cooking
and First Aid. Enchanting/tinkering can use the normal target-item cursor.
Herbalism, Skinning and Fishing have no crafting recipe window; their materials
appear as linked gather/buy/obtain leaves rather than invented Craft actions.

Existing Inscription features remain: pigment/herb milling links and buttons,
glyph descriptions/spell links, required levels, minor markers and level sorting.
All supported recipe windows share the taller movable layout and cast bar.

Engineering has an [interactive design preview](docs/engineering-preview.html)
and the [original dependency-tree design](docs/engineering-design.md). The actual
tree now runs in-game for every supported recipe profession. The separate browser
preview remains a simulation, not a game client.

## Install

Copy the **InkTrail** folder into your client's `Interface/AddOns` directory.
The resulting path must be `Interface/AddOns/InkTrail/InkTrail.toc`. Restart the
game and enable InkTrail. Keep the folder name InkTrail; this preserves the
existing add-on identity and saved window settings. No server build is required.

Craft debugging: `/crafttrail why` prints native recipe eligibility and the last
request/client error; `/crafttrail version` prints the installed version.
`/inktrail` remains an alias. Learned recipes are resolved from the complete
open profession list, including hidden/collapsed recipes. Filters, headers and
the selected top-level recipe are restored after lookup/crafting. Each click
submits one `DoTradeSkill(index, 1)` call; it does not automate the whole chain.
Missing bag materials, tools, cooldowns and busy states disable the action.
Cross-profession recipes remain references until their profession is open.

Build the installable package and separate Engineering browser sketch with:

```sh
python tools/package.py
```

The output is `dist/CraftTrail-2.0.0.zip`. Copy only its InkTrail folder
into AddOns; open `Engineering-preview.html` in a browser. The preview is not an
in-game module; the actual dependency tree is included in the InkTrail folder.

This repository contains the Lua source, TOC, documentation, tests and data
generator. It does not contain game clients, databases, DBC files, private saved
variables or packaged releases.

## Develop and test

Install Python 3 and the development dependency, then run the Lua 5.1 fixture:

```sh
python -m pip install -r requirements-dev.txt
python InkTrail/tests/test_addon.py
python InkTrail/tests/test_native_tree.py
python InkTrail/tests/test_profession_data.py
python InkTrail/tests/test_engineering_data.py
node tools/test_preview.cjs
```

The tests execute the shipped Lua against simulated legacy WoW APIs. They cover
the complete shipped TOC, actual button-to-native-call dispatch, hidden/collapsed
recipes, stale inventory, tools/cooldowns, restored selection/filters, native
errors, shared-stock allocation, batch surplus, cycle/depth limits, all 11 recipe
professions, links, sorting, layout calculations and progress events. They cannot prove the
real client's protected clicks, rendering or third-party tooltips.
The latest craft fix still needs an in-game check.

The generated relationships are included in `InkTrail/Data.lua` and
`InkTrail/ProfessionData.lua` (3,149 craftable items and 3,638 referenced items).
Live learned recipes supply actual reagent quantities, tools and yield ranges;
the bundled catalog expands dependencies, including other professions.
Regeneration is optional and needs your own matching AzerothCore SQL checkout and
3.3.5a DBC data:

```sh
python InkTrail/tools/generate_data.py --core-root /path/to/azerothcore-wotlk --dbc-dir /path/to/dbc
python InkTrail/tools/generate_professions.py --core-root /path/to/azerothcore-wotlk --dbc-dir /path/to/dbc
```

See [InkTrail's documentation](InkTrail/README.md) for controls, limitations, data
provenance and the feature history. `InkTrail/tools/data-sources.json` records the
hashes of the data used for the current generated source.
