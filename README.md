# CraftTrail

Recipe material trails for World of Warcraft **Wrath of the Lich King 3.3.5a**
(interface 30300).

The first module is **InkTrail 1.3.1**, an Inscription add-on. It displays the
selected glyph's ink, pigment and milling herbs together, with native item links,
one-click ink crafting and herb milling, and a cast progress bar. It also adds
glyph descriptions with recognized spell links, required levels, minor markers,
level sorting and a taller movable profession window.

Support for other professions and recursive material chains is planned. It is
not implemented in this initial import.

## Install

Copy the **InkTrail** folder into your client's `Interface/AddOns` directory.
The resulting path must be `Interface/AddOns/InkTrail/InkTrail.toc`. Restart the
game and enable InkTrail. Keep the folder name InkTrail; this preserves the
existing add-on identity and saved window settings. No server build is required.

This repository contains the Lua source, TOC, documentation, tests and data
generator. It does not contain game clients, databases, DBC files, private saved
variables or packaged releases.

## Develop and test

Install Python 3 and the development dependency, then run the Lua 5.1 fixture:

```sh
python -m pip install -r requirements-dev.txt
python InkTrail/tests/test_addon.py
```

The tests execute the shipped Lua against simulated legacy WoW APIs. They cover
the Midnight Ink Craft availability regression, action guards, bag refreshes,
links, sorting, layout calculations and progress events. They cannot prove the
real client's protected clicks, rendering or third-party tooltips.
The latest craft fix still needs an in-game check.

The generated relationships are already included in `InkTrail/Data.lua`.
Regeneration is optional and needs your own matching AzerothCore SQL checkout and
3.3.5a DBC data:

```sh
python InkTrail/tools/generate_data.py --core-root /path/to/azerothcore-wotlk --dbc-dir /path/to/dbc
```

See [InkTrail's documentation](InkTrail/README.md) for controls, limitations, data
provenance and the feature history. `InkTrail/tools/data-sources.json` records the
hashes of the data used for the current generated source.
