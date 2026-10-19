# CraftTrail

## Version 2.3.1: stable cross-profession recipe and scroll position

The original rendered recipe is captured before native selection resets. The
pinned tree retains its original anchor and detail scroll extent; refreshes no
longer briefly shrink the scroll area. Deferred hide/show events and temporary
empty destination lists keep the original context. The snapshot list uses plain
native-style rows and highlights the original recipe. Offline regressions cover
non-first recipes, nonzero scrolling and delayed window events.

## Version 2.3.0: keep the original profession visible

Cross-profession crafting now preserves the original title/rank, recipe summary,
visible recipe list and dependency tree while the client switches internally.
The list snapshot supports mouse-wheel scrolling and selection back into the
original profession. Destination controls are hidden; use tree Craft buttons.
Back to recipe restores the native controls. This UI behavior has offline test
coverage; its appearance still requires a real 3.3.5a client check.

## Version 2.2.0: cross-profession crafting

Click Craft on a component from another learned profession to open that
profession and attempt one cast after checking its live recipe list. The
original dependency tree stays visible, with a Back to recipe button. Slow
client loading may require another click. No delayed automatic crafts run.

## Version 2.1.0: CraftTrail identity

The add-on is now **CraftTrail**, including its folder, TOC, UI objects and
saved-variable name. Remove the old InkTrail add-on folder before installing.
See the repository README for optional saved-settings migration instructions.
`/crafttrail` is the primary command; `/inktrail` remains an alias.

Craft now resolves the learned recipe and calls `DoTradeSkill(index, 1)` through
the secure button's hardware-click macro, matching the stock 3.3.5 profession
Create action. It does not rely on `/cast Ink Name`, generic spell knowledge or
generic spell cooldown flags. Lookup temporarily clears recipe filters and
expands categories, then restores filters, collapsed headers and the selected
top-level recipe. A stale index is never saved for later clicks. The native
recipe's bag reagent quantities, tools and cooldown are checked again on click.

Each node shows an icon/item link (spell link for an enchant), required and
allocated bag quantities, conservative batch counts/yield ranges, and a Craft
button when a recipe exists. Arrows cycle alternate methods. Shared bag stock
and planned surplus are counted once. Existing supplies stop expansion; cycles,
eight-level depth and a 160-node cap prevent runaway trees. Materials from other
professions can switch and craft when learned by this character; missing
professions remain references with an explicit disabled reason. Gathering-only
professions produce raw material leaves, not fictional craft buttons.

`/crafttrail why` includes the last native request and a subsequent client error.
Requests, started casts and successful casts are different states; a submitted
request alone is not reported as a completed craft. `/crafttrail version` prints
the version. The original `/inktrail` commands remain available.

Full-TOC Lua tests cover button clicks through the actual macro callback to a
mocked DoTradeSkill, including hidden Midnight Ink, restored UI state, stale bags,
tools, recipe cooldowns, native errors, batch/shared-material accounting and all
eleven recipe windows. These tests do not replace a real-client protected-action,
layout and third-party-tooltip check.

## Version 1.3.2: filtered ink recipes and visible blockers

Profession filters can hide an ink recipe while the spellbook API reports zero
for that same recipe. That combination no longer disables Craft. With enough
bag pigments, a filtered recipe can attempt its normal secure cast; the game
still validates learned recipe, tools and other requirements. This is not an
automatic craft or a bypass of game requirements.

Disabled ink actions now show the actual blocker beneath their row. Use
`/crafttrail why` to print the selected recipe's ink checks and pigment counts,
or `/crafttrail version` to print the installed version. Offline tests reproduce
the hidden-Midnight-Ink case with five Dusky Pigment and zero spell knowledge.
The real-client click still needs verification.

## Version 1.3.1: ink Craft availability

Craft checks the learned Inscription recipe list as well as spell knowledge.
It no longer treats the generic spell usability or disabled cooldown flag as
proof that an ink cannot be crafted. Bag updates refresh the button after milling.
Visible ink recipes use their live reagent quantities and tool requirements;
filtered recipes use spell knowledge and the bundled pigment requirement. An
unlearned or hidden recipe without spell knowledge remained disabled in 1.3.1;
1.3.2 removes that false-negative check for filtered recipes. The normal
cast still enforces the game's requirements and keeps the glyph selected.

Lua 5.1 regression tests reproduce Midnight Ink with two and five Dusky Pigment,
generic spell API zero flags, bag events, missing tools and additional reagents.
These are offline tests; the updated button still needs a real-client check.

## Version 1.3.0: readable glyph effects and inline spell links

Selecting a glyph now shows its effect description below the glyph header and
above the reagents. The text comes from the client's formatted item tooltip,
including its effect values, rather than a second handwritten description database.
Long descriptions wrap and push the reagents/reference panel down in the same
scrolling details view. Item-name, class and level metadata are not repeated.

Recognized ability and talent names become inline native spell links. For example,
**Hammer of Justice** in the glyph description can be hovered for its spell tooltip
or clicked to open its spell reference. Shift-click uses the normal chat-link
handler. The visible sentence keeps its original words; link markers do not add
another list of spell names.

Candidate references come from that glyph's class abilities and talents in the
local `SkillLineAbility`, `Talent` and `TalentTab` DBC data. Display names are
resolved through the client. Longest whole-name matches win over shorter overlaps;
unmatched names stay plain text. This is conservative name matching, not a claim to
resolve every nickname, plural, pet skill or cross-class reference. References use
a representative base rank from the bundled data.

The description uses a `SimpleHTML` region with native inline hyperlinks, and the
old description layout is restored for non-glyph recipes and other professions.
When item details have not arrived, it shows a loading message and uses the existing
bounded refresh rather than inventing an effect. Offline tests cover real-data
ability/talent mapping, tooltip extraction, localized use prefixes, links and
modified clicks, unknown/overlapping names, long text and layout restoration.
In-game verification of this new description field remains pending.

## Version 1.2.0: action labels and cast progress

Every visible ink row retains a **Craft** button, and every visible herb row
retains its own **Mill** button, even when disabled. Each button now owns a
separately named font label, and its position/visibility is reapplied with the row.
Unavailable materials disable the button; they do not remove it. Rows outside the
scroll viewport remain hidden until scrolled into view.

A cast bar sits in the window footer, above the native crafting controls. Its
24-unit reserved area is excluded from the scroll viewport. The bar reads actual
player cast/channel start and end timestamps, shows remaining seconds, and updates
when casts are delayed. It reports **Complete**, **Cast failed**, or **Interrupted**
from player spell events and returns to **Ready** while idle. It tracks the current
cast, not an estimate of an entire batch, and performs no crafting on its own.

The API timing follows the original client's
[casting-bar interface](https://github.com/wowgaming/3.3.5-interface-files/blob/main/CastingBarFrame.lua).
Offline tests cover every action's independent label and visibility, footer
separation, real-timestamp progress, delays, channels, terminal states and idle
cleanup. Real-client rendering and protected action execution remain unverified.

## Version 1.1.1 fixes

The screenshot of the taller window revealed that Blizzard's Create and Exit
buttons retain fixed offsets from the top. They now anchor below the expanded
details viewport; the quantity and Create All controls follow their native anchor
chain. Their original anchors are restored outside Inscription.

The reference panel now anchors to the scroll child's left edge, independently of
which reagent column is lowest. Every action button has a unique frame name. Rows
outside, or partly outside, the detail viewport are explicitly hidden on scrolling,
including their secure click targets, so they cannot cover the crafting toolbar.

Milling checks accept legacy numeric 0/1 flags and fall back to the learned spellbook
when the direct known-spell query fails. These are compatibility fixes; the exact
reason the reported character's button was disabled has not been confirmed live.
Hover a disabled action button for its current reason.

The regression fixture now models the native toolbar anchors and frame geometry,
checks viewport and click-target boundaries, and exercises 91 Kingsblood with
numeric flags and spellbook-only Milling knowledge. Those checks pass offline.
The patched layout and actual casts still require confirmation in the game client.

A client addon for the original **Wrath of the Lich King 3.3.5a** client.
Adds an ink → pigment → milling herbs reference **inside the default
Inscription recipe details**, underneath the ordinary reagents. Scroll the recipe
details down to see the whole reference.

Select a glyph and CraftTrail shows:

- Its required ink, as an item icon and native item link.
- The pigment and quantity needed to make that ink for one recipe craft.
- Every herb in the bundled milling data that can produce that pigment, each
  with an icon and native item link. The herbs are alternatives: mill five of
  **one** herb, not five of every listed herb. Milling yields are random.

For example, a recipe requiring one Lion's Ink shows two Golden Pigment and
Grave Moss, Kingsblood, Liferoot and Wild Steelbloom. Selecting an ink recipe
itself also shows its pigment and herbs. All 15 Wrath inks are included.

Hover any item for the ordinary game item tooltip. Existing tooltip addons can
append their bank, guild-bank or alternate-character counts through their normal
hooks. CraftTrail does not maintain another inventory database or query a guild bank.
Those counts remain dependent on the other addon's saved inventory information.
Shift-click a row to insert its item link into an active chat box; ordinary click
opens the item reference tooltip. Names and icons use the client's localized item
cache, with English names and a question-mark icon as a temporary fallback.

## Crafting, milling and the recipe list

- **Craft**, beside an ink, performs one ink cast per click while keeping the glyph
  selected. It is disabled when bag pigments are
  insufficient for one cast, the character is busy/dead, the spell is on cooldown,
  or a visible recipe is missing a reagent/tool. Pigments in a bank do not enable it.
- **Mill**, beside each herb, mills one batch of five per click. It requires learned
  Milling, sufficient Inscription skill for that herb, and at least five of that
  exact herb in one unlocked stack in bags 0–4. Five is sufficient; six is not
  required. Split stacks such as three plus two need to be combined manually.
- Secure click buttons use normal game casting. Each click rechecks eligibility;
  milling also rechecks the bag slot so rearranged bags cannot target another herb.
  Buttons refresh on bag, lock, skill, cooldown and player casting changes. They do
  not repeat casts, merge stacks, fetch bank materials or bypass game restrictions.
  Linked/inspected profession lists do not allow these actions. Combat changes are
  deferred until combat ends; the action macros themselves refuse combat casts.
- Glyph rows display the **required character level**, not the profession skill
  needed to craft them. Glyphs sort by that level, lowest first, within each header
  section of the current filtered list. Class headings and non-glyph slots stay in
  place; clicks continue to use the original recipe indices.
- Minor glyphs have a lowercase **m** in a fixed-width column before their names.
  Major glyphs leave that column blank. Both names start at exactly the same
  horizontal position. A **?** marks an obsolete/custom glyph item for which the
  bundled client data has no glyph-type association, rather than guessing its type.

## Window size and position

Inscription opens about **1.5 times its normal height**, increasing the recipe
details viewport rather than enlarging the text. It is limited by available screen
space. The recipe list remains eight rows high. Drag the window by its title/header;
its position and size preference are saved between sessions using `CraftTrailDB`.

- `/crafttrail normal` restores the normal height.
- `/crafttrail tall` enables the taller view again.
- `/crafttrail reset` clears the saved position and returns to the default location.

Other professions return to their normal window height. Size/position changes are
made outside combat.

## Install

1. Exit the WoW client before installing this new addon.
2. Extract the release ZIP into your game's `Interface/AddOns` directory. The
   final layout must be `Interface/AddOns/CraftTrail/CraftTrail.toc` (no extra nested
   directory).
3. Relaunch WoW, enable **CraftTrail** in the character selection AddOns list, and
   open Inscription. Select a glyph and scroll down in its recipe details.

No server rebuild, server restart, SQL import or PlayerBots change is required.
This first version targets Blizzard's default profession window. Replacement
profession interfaces such as Skillet or AdvancedTradeSkillWindow are not supported.
UI labels are English; item names come from the client's item cache.

## Validation and limits

The actual Lua files run under **Lua 5.1** in the offline fixture. Tests cover
ink/pigment/herb coverage, selected-recipe quantities, multiple inks, native item
links and tooltips, modified-click handling, scroll-child expansion, delayed item
cache loading, bounded retries and cleanup when changing professions or closing.
Additional tests cover action eligibility and boundaries, missing materials,
unlearned spells, skill requirements, locked/split stacks, stale-slot revalidation,
linked professions, combat guards, larger detail viewports, saved dragging,
per-class ascending level order, original recipe indices and aligned minor markers.
Run `python tests/test_addon.py` with `lupa.lua51` available. The test dependency
is not part of the addon and is not required by WoW.

The update has **not yet been tested in a running WoW client**. Mocked tests do not
execute WoW's protected-action system or prove visual layout, actual casting,
third-party tooltip additions or saved-variable file persistence. In-game checks:
select a glyph using Lion's Ink, hover its herbs with the bank-tooltip addon enabled,
craft one ink with two Golden Pigment, mill one five-herb stack, and confirm smaller
or locked stacks disable milling. Compare known major/minor glyphs and their levels,
click a sorted row, drag the window, reload, and verify its saved position. Switch
professions and confirm the extra reference disappears and normal height returns.

## Data and API references

The implementation uses the legacy selection and reagent APIs exposed by the
[3.3.5 trade-skill Lua](https://github.com/wowgaming/3.3.5-interface-files/blob/main/Blizzard_TradeSkillUI/Blizzard_TradeSkillUI.lua)
and attaches to the detail scroll child defined in its
[XML layout](https://github.com/wowgaming/3.3.5-interface-files/blob/main/Blizzard_TradeSkillUI/Blizzard_TradeSkillUI.xml).
It uses secure post-hooks rather than replacing Blizzard functions. Crafting and
milling occur only through user clicks on secure action buttons based on the legacy
[secure templates](https://github.com/wowgaming/3.3.5-interface-files/blob/main/SecureTemplates.lua).
Version 2.0.2 temporarily expands categories/clears filters for native lookup,
then restores them. Earlier versions did not perform this lookup.

`Data.lua` contains factual IDs, names and ink/milling relationships generated
from the local WotLK `Spell.dbc`, `GlyphProperties.dbc` and AzerothCore's `item_template`,
`milling_loot_template` and `reference_loot_template` base SQL. The generator
resolves the milling reference tables, including common and rare pigments and
Northrend frozen herbs. It copies no game assets or SQL databases into the addon.
`tools/data-sources.json` records input hashes and the core revision. Live SQL
overrides were not queried; custom realm milling changes need a data refresh.
Selected ink recipes use their live pigment quantity when available.
Glyph levels and herb skill requirements come from item templates; glyph type is
resolved through each item's apply-glyph spell to its glyph-properties type flag.

To regenerate, run `python tools/generate_data.py --core-root /path/to/azerothcore-wotlk --dbc-dir /path/to/dbc`
from this add-on folder, supplying your own matching source data.
This reads local source data only and does not connect to a database or touch
running services. No changes to the voice bridge or its command catalog are needed.
