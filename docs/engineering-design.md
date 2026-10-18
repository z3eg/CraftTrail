# Engineering dependency tree — design preview

This records the original sketch. Version 2.0.0 now implements the connected
tree in-game for Engineering and all other recipe professions. Open
`engineering-preview.html` in a browser for the original simulated-inventory demo.

The example relationships come from matching 3.3.5a Spell/SkillLineAbility DBCs
and AzerothCore item names, not invented recipe ingredients:

```mermaid
flowchart TD
    fire["Fire Goggles ×1 · Craft"] --> green["Green Tinted Goggles ×1 · Craft"]
    fire --> extras["Citrine ×2 · Elemental Fire ×2 · Heavy Leather ×4"]
    green --> flying["Flying Tiger Goggles ×1 · Craft"]
    green --> middle["Medium Leather ×4 · Moss Agate ×2"]
    flying --> base["Light Leather ×6 · Tigerseye ×2"]
```

In-game layout: an indented tree under the selected recipe, with connecting
lines, native item links/icons, required/carried quantities and one Craft button
per craftable node. Disabled nodes display a concrete missing-material, tool,
skill, cooldown or learned-recipe reason. Raw and other-profession materials
remain visible. Native tooltips preserve third-party bank tooltip additions;
only bag contents enable crafting. One click performs one normal cast and
keeps the selected top-level recipe. Existing progress/window behavior is shared.

Implemented behavior: choose a learned recipe when multiple methods exist; allow
explicit alternatives; account for shared materials once and craft yield ranges;
expand only shortages by default; stop cycles and bound depth/node count.
Cross-profession steps stay references unless their profession is open and the
recipe can be cast. Never silently switch professions or automate chained casts.

`ProfessionData.lua` generalizes the initial Engineering catalog and is loaded
by the TOC. `EngineeringData.lua` remains the original reference subset. The manifests record data hashes and core
revision. No live database overrides were queried. The browser demonstration
does not call WoW APIs or claim to show the player's real bags.
