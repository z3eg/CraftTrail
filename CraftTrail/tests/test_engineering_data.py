"""Validate the Engineering catalog scaffold; it is not yet loaded in-game."""
import os
import sys
from pathlib import Path

if os.environ.get('CRAFTTRAIL_TEST_DEPS'):
    sys.path.insert(0, os.environ['CRAFTTRAIL_TEST_DEPS'])
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
addon = lua.table()
lua.execute((root / 'EngineeringData.lua').read_text(encoding='utf-8'), 'CraftTrail', addon)
lua.globals().addon = addon
lua.execute('''
local engineering = 0
for item, recipes in pairs(addon.componentRecipes) do
    assert(addon.componentNames[item])
    local isEngineering = false
    for _, recipe in ipairs(recipes) do
        assert(recipe.spell > 0 and recipe.min >= 1 and recipe.max >= recipe.min)
        isEngineering = isEngineering or recipe.skill == 202
        for _, reagent in ipairs(recipe.reagents) do
            assert(reagent[2] > 0 and addon.componentNames[reagent[1]])
        end
    end
    if isEngineering then engineering = engineering + 1 end
end
assert(engineering == 295)
local fire = addon.componentRecipes[10500][1]
local green = addon.componentRecipes[4385][1]
local flying = addon.componentRecipes[4368][1]
assert(fire.spell == 12594 and fire.reagents[1][1] == 4385)
assert(green.spell == 3956 and green.reagents[3][1] == 4368)
assert(flying.spell == 3934 and flying.reagents[1][2] == 6 and flying.reagents[2][2] == 2)
''')
print('Engineering catalog passed: 295 outputs, named positive reagents/yields and the real goggles upgrade chain.')
