"""Validate the shipped all-profession dependency catalog and provenance counts."""
import json
import os
import sys
from pathlib import Path

if os.environ.get('INKTRAIL_TEST_DEPS'):
    sys.path.insert(0, os.environ['INKTRAIL_TEST_DEPS'])
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'tools/profession-sources.json').read_text())
lua = LuaRuntime()
addon = lua.table()
lua.execute((root / 'ProfessionData.lua').read_text(encoding='utf-8'), 'InkTrail', addon)
lua.globals().addon = addon
counts, items = lua.execute('''
local counts, items = {}, 0
for item, recipes in pairs(addon.componentRecipes) do
    assert(addon.componentNames[item], 'missing output name')
    items = items + 1
    for _, recipe in ipairs(recipes) do
        assert(recipe.spell > 0 and recipe.min >= 1 and recipe.max >= recipe.min)
        counts[recipe.skill] = (counts[recipe.skill] or 0) + 1
        for _, reagent in ipairs(recipe.reagents) do
            assert(reagent[2] > 0 and addon.componentNames[reagent[1]], 'invalid component')
        end
    end
end
return counts, items
''')
assert items == manifest['craftableItems'] == 3149
assert {str(skill): count for skill, count in counts.items()} == manifest['professionRecipeCounts']
assert len(list(counts)) == 11
assert not manifest['missingSqlItemNames']
print('All-profession catalog passed: 11 professions, 3149 craftable items, positive yields/reagents and source counts.')
