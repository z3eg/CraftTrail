"""Run the complete shipped TOC with a filtered recipe list and hardware-click API doubles."""
import ast
import os
import sys
from pathlib import Path

if os.environ.get('CRAFTTRAIL_TEST_DEPS'):
    sys.path.insert(0, os.environ['CRAFTTRAIL_TEST_DEPS'])
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
module = ast.parse((root / 'tests/test_addon.py').read_text(encoding='utf-8'))
harness = next(ast.literal_eval(node.value) for node in module.body if isinstance(node, ast.Assign)
               and any(isinstance(target, ast.Name) and target.id == 'harness' for target in node.targets))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(harness)
lua.execute(r'''
local names = {[45357]='Inscription',[4036]='Engineering',[2018]='Blacksmithing',[2259]='Alchemy',
 [2108]='Leatherworking',[2550]='Cooking',[2656]='Smelting',[3908]='Tailoring',[7411]='Enchanting',
 [25229]='Jewelcrafting',[3273]='First Aid',[53462]='Midnight Ink',[51005]='Milling'}
GetSpellInfo = function(id) return names[id] or ('Recipe' .. id), nil, 'icon' end
IsSpellKnown = function() return 0 end
GetSpellCooldown = function() return 0,0,0 end
allRecipes, casts = {}, {}
subFilter, slotFilter, searchText, makeable = 1, 0, '', false
local function Rebuild()
 recipes = {}
 local hidden = false
 for _, r in ipairs(allRecipes) do
  if r.header then hidden = not r.expanded end
  local visible = (subFilter == 0 or r.category == subFilter) and (slotFilter == 0 or (r.slot or 1) == slotFilter)
  if not r.header and hidden then visible = false end
  if not r.header and searchText ~= '' and not string.find(r.name, searchText, 1, true) then visible = false end
  if not r.header and makeable then
   for _, reagent in ipairs(r.reagents) do if GetItemCount(reagent[1], false) < reagent[2] then visible = false end end
  end
  if visible then recipes[#recipes + 1] = r end
 end
end
GetTradeSkillSubClasses = function() return 'Glyphs', 'Inks' end
GetTradeSkillInvSlots = function() return 'Head', 'Other' end
GetTradeSkillSubClassFilter = function(i) return (subFilter == i) and 1 or 0 end
GetTradeSkillInvSlotFilter = function(i) return (slotFilter == i) and 1 or 0 end
SetTradeSkillSubClassFilter = function(i, enabled) if enabled == 1 then subFilter = i end; Rebuild() end
SetTradeSkillInvSlotFilter = function(i, enabled) if enabled == 1 then slotFilter = i end; Rebuild() end
SetTradeSkillItemNameFilter = function(text) searchText = text or ''; Rebuild() end
SetTradeSkillItemLevelFilter = function() end
TradeSkillFrame_SetFilter = function(text) searchText = text or ''; Rebuild() end
TradeSkillOnlyShowMakeable = function(value) makeable = value == true or value == 1; Rebuild() end
ExpandTradeSkillSubClass = function(index)
 if index == 0 then for _, r in ipairs(allRecipes) do if r.header then r.expanded = true end end
 else recipes[index].expanded = true end; Rebuild()
end
CollapseTradeSkillSubClass = function(index) recipes[index].expanded = false; Rebuild() end
GetTradeSkillInfo = function(index)
 local r = recipes[index]; if r then return r.name, r.header and 'header' or 'optimal', 0, r.expanded, r.verb end
end
GetTradeSkillItemLink = function(index)
 local r = recipes[index]; return r and not r.header and (r.output and ('item:' .. r.output) or ('enchant:' .. r.spell))
end
GetTradeSkillRecipeLink = function(index) local r=recipes[index]; return r and r.spell and ('enchant:' .. r.spell) end
GetTradeSkillNumMade = function(index) local r=recipes[index]; return r.min or 1, r.max or r.min or 1 end
GetTradeSkillCooldown = function(index) return recipes[index].cooldown end
GetTradeSkillTools = function(index) return unpack(recipes[index].tools or {}) end
SelectTradeSkill = function(index) selection = index end
TradeSkillFrameEditBox = CreateFrame('EditBox')
TradeSkillFrameEditBox.GetText = function() return searchText end
TradeSkillFrameAvailableFilterCheckButton = CreateFrame('CheckButton')
TradeSkillFrameAvailableFilterCheckButton.GetChecked = function() return makeable end
TradeSkillFrameAvailableFilterCheckButton.SetChecked = function(self,value) makeable=value end
DoTradeSkill = function(index, count)
 assert(not combat and not linked and not dead and not casting, 'native craft bypassed an activity guard')
 assert(count == 1, 'one hardware click must perform exactly one native cast')
 local r = recipes[index]; assert(r and r.spell and not r.header, 'stale native recipe index')
 casts[#casts + 1] = r.spell
end
function Click(button)
 if not button.enabled then return false end
 button.scripts.PreClick(button)
 if button.enabled and button.attributes.macrotext then
  assert(string.sub(button.attributes.macrotext, 1, 5) == '/run ', 'craft still uses a spell-name macro')
  assert(loadstring(string.sub(button.attributes.macrotext, 6)))()
  return true
 end
 return false
end
function Setup(list, profession, bagItems)
 allRecipes = list; line = profession; bags = {[0]=bagItems or {}}
 subFilter, slotFilter, searchText, makeable = 0,0,'',false
 Rebuild(); selection = 1
end
function Recipe(spell, output, reagents, category)
 return {spell=spell, output=output, reagents=reagents or {}, category=category or 1, name=GetSpellInfo(spell)}
end
function Check(value, message) assert(value, message) end
''')
addon = lua.table()
lua.globals().addon = addon
for line in (root / 'CraftTrail.toc').read_text().splitlines():
    if line.endswith('.lua'):
        lua.execute((root / line).read_text(encoding='utf-8'), 'CraftTrail', addon)
lua.execute(r'''
Check(SLASH_CRAFTTRAIL1=='/crafttrail' and SLASH_CRAFTTRAIL2=='/inktrail', 'slash command identity/legacy alias')
-- Actual button dispatch with the ink hidden by a class filter AND a collapsed header.
local glyph = Recipe(1111,40897,{{39774,1},{39354,1}},1)
local ink = Recipe(53462,39774,{{39334,2}},2)
local h1={header=true,name='Glyphs',expanded=true,category=1,reagents={}}
local h2={header=true,name='Inks',expanded=false,category=2,reagents={}}
Setup({h1,glyph,h2,ink},'Inscription',{{id=39334,count=5}})
subFilter=1; SetTradeSkillSubClassFilter(1,1,1); SelectTradeSkill(2)
addon.Refresh()
local ready, why, macro=addon.ActionState('craft',39774,{})
Check(ready, why)
Check(macro=='/run CraftTrail_Craft(53462,39774)', 'craft must use native recipe identity')
local row=CreateFrame('Button','NativeInkTestRow',TradeSkillFrame)
local button=addon.CreateAction(row); button.kind='craft'; button.itemID=39774
addon.ConfigureAction(button,{})
Check(Click(button) and #casts==1 and casts[1]==53462, 'hidden ink click did not invoke exactly one DoTradeSkill')
Check(addon.lastCraft.state=='requested', 'a submitted native request must not be claimed as a completed craft')
for _,frame in ipairs(frames) do
 if frame.events.UI_ERROR_MESSAGE then frame.scripts.OnEvent(frame,'UI_ERROR_MESSAGE','Missing required tool.') end
end
Check(addon.lastCraft.state=='rejected' and addon.lastCraft.error=='Missing required tool.', 'native client error not retained for diagnostics')
Check(subFilter==1 and not h2.expanded and GetTradeSkillItemLink(selection)=='item:40897', 'filters/header/glyph selection not restored')
addon.RestoreRecipeSelection()
Check(GetTradeSkillItemLink(selection)=='item:40897', 'deferred selection restoration failed')
-- Inventory can change between painting the button and its hardware click.
bags[0][1].count=1; addon.recipeCatalog=nil; addon.ConfigureAction(button,{})
Check(not button.enabled, 'insufficient pigments enabled native Craft')
bags[0][1].count=5; addon.recipeCatalog=nil; addon.ConfigureAction(button,{})
bags[0][1].count=0; local before=#casts; Click(button)
Check(#casts==before, 'stale bag state invoked DoTradeSkill')
bags[0][1].count=5
ink.tools={'Virtuoso Inking Set',0}; addon.recipeCatalog=nil
Check(not addon.NativeCraftState(53462,39774), 'missing tool enabled native craft')
ink.tools={'Virtuoso Inking Set',1}; ink.cooldown=60; addon.recipeCatalog=nil
Check(not addon.NativeCraftState(53462,39774), 'recipe cooldown ignored')
ink.cooldown=nil; addon.recipeCatalog=nil
local allRecipesCalls=0
local originalAllRecipes=addon.WithAllRecipes
addon.WithAllRecipes=function(callback) allRecipesCalls=allRecipesCalls+1; return originalAllRecipes(callback) end
for _, state in ipairs({'combat','linked','dead','casting'}) do
 _G[state]=true; before=#casts
 Check(not addon.NativeCraft(53462,39774), 'activity guard '..state..' ignored')
 Check(#casts==before, 'activity guard allowed a cast'); _G[state]=false
end
Check(allRecipesCalls==0, 'blocked craft changed recipe filters before checking activity guards')
addon.WithAllRecipes=originalAllRecipes
-- Remove the learned ink entirely; a static DBC recipe must not prove it is known.
allRecipes={h1,glyph}; addon.recipeCatalog=nil; SetTradeSkillSubClassFilter(1,1,1)
Check(not addon.NativeCraftState(53462,39774), 'unlearned ink was treated as learned')
-- Material-chain fixture: the live recipe, not cached/static reagent quantities, wins.
local fire=Recipe(12594,10500,{{4385,1},{3864,2},{7068,2},{4234,4}})
local green=Recipe(3956,4385,{{2319,4},{1206,2},{4368,1}})
local flying=Recipe(3934,4368,{{2318,6},{818,2}})
Setup({fire,green,flying},'Engineering',{{id=2318,count=6},{id=818,count=2}})
addon.recipeCatalog=nil; addon.Refresh()
local tree=addon.BuildDependencyTree(1)
Check(tree[1].item==10500 and tree[2].item==4385, 'goggles tree lost its direct parent')
local sawFlying=false
for _, node in ipairs(tree) do if node.item==4368 then sawFlying=node.depth==2 end end
Check(sawFlying, 'nested goggles missing')
Check(addon.NativeCraftState(3934,4368), 'craftable leaf disabled')
Check(not addon.NativeCraftState(12594,10500), 'root enabled without its direct components')
-- One shared bag stock and batch surplus must not be spent twice across branches.
local one=Recipe(900001,9001,{{9002,1},{9003,1}})
local two=Recipe(900002,9002,{{9004,3}}); two.min=2;two.max=3
local three=Recipe(900003,9003,{{9002,1}})
Setup({one,two,three},'Engineering',{{id=9004,count=3}}); addon.recipeCatalog=nil
tree=addon.BuildDependencyTree(1)
local planned, rawNeeds=0,0
for _,node in ipairs(tree) do
 planned=planned+node.planned
 if node.item==9004 then rawNeeds=rawNeeds+node.needed end
end
Check(planned==1 and rawNeeds==3, 'batch surplus was not reused once')
two.min=1;two.max=1;three.reagents={{9004,3}}
Setup({one,two,three},'Engineering',{{id=9004,count=4}}); addon.recipeCatalog=nil
tree=addon.BuildDependencyTree(1)
local allocated=0
for _,node in ipairs(tree) do if node.item==9004 then allocated=allocated+node.carried end end
Check(allocated==4, 'shared physical bag stock was counted twice')
-- Cycles and unbounded transmute graphs stop instead of recursing forever.
two.reagents={{9003,1}};three.reagents={{9002,1}}; addon.recipeCatalog=nil
tree=addon.BuildDependencyTree(1)
local stopped=false; for _,node in ipairs(tree) do stopped=stopped or node.stopped~=nil end
Check(stopped and #tree<20, 'cycle guard failed')
-- Deterministic alternate selection and the on-row selector change the actual recipe.
local alternate=Recipe(900004,9002,{{9005,1}})
Setup({one,two,alternate,three},'Engineering',{}); addon.recipeCatalog=nil; addon.recipeChoices={}
Check(#addon.ComponentOptions(9002)>=2, 'alternate recipes not exposed')
addon.CycleRecipe(9002)
tree=addon.BuildDependencyTree(1)
local choseAlternate=false
for _,node in ipairs(tree) do if node.item==9002 and node.recipe.spell==900004 then choseAlternate=true end end
Check(choseAlternate, 'alternate selector did not alter the tree recipe')
addon.recipeChoices={}
local deep={}
for n=1,20 do deep[n]=Recipe(930000+n,940000+n,{{940001+n,1}}) end
Setup(deep,'Engineering',{}); addon.recipeCatalog=nil
tree=addon.BuildDependencyTree(1)
Check(#tree==9 and tree[#tree].stopped, 'eight-level depth limit failed')
-- Every trade-skill profession uses the same renderer and native action, including enchanting without item output.
local professions={'Inscription','Engineering','Blacksmithing','Leatherworking','Alchemy','Cooking','Smelting',
 'Tailoring','Enchanting','Jewelcrafting','First Aid'}
for index,profession in ipairs(professions) do
 local spell=910000+index
 local r=Recipe(spell,profession~='Enchanting' and (920000+index) or nil,{{9999,2}})
 Setup({r},profession,{{id=9999,count=2}}); addon.recipeCatalog=nil
 Check(addon.IsSupportedProfession(), 'unsupported profession '..profession)
 addon.Refresh()
 Check(CraftTrailDetails:IsShown(), 'tree not rendered for '..profession)
 before=#casts; Check(addon.NativeCraft(spell,r.output), 'native action rejected '..profession)
 Check(#casts==before+1 and casts[#casts]==spell, 'wrong native recipe for '..profession)
end
print('Full-TOC native crafting and all-profession tree checks passed.')
-- Stock client's placeholder lives in the EditBox, but is NOT a name filter.
-- Use the real handler's behavior; the old fake SetFilter hid this regression.
SEARCH='Search'
TradeSkillFrame_SetFilter=nil
local editText
TradeSkillFrameEditBox.GetText=function() return editText or searchText end
TradeSkillFrameEditBox.SetText=function(self,text) editText=text end
TradeSkillFilter_OnTextChanged=function(self)
 local text=self:GetText()
 if text==SEARCH then SetTradeSkillItemNameFilter(''); return end
 SetTradeSkillItemLevelFilter(0,0)
 SetTradeSkillItemNameFilter(text)
end
for _,profession in ipairs(professions) do
 local list={}
 for n=1,25 do list[n]=Recipe(950000+n,960000+n,{},n%2+1) end
 list[1].name='Search' -- Broken restoration leaves exactly this single recipe.
 Setup(list,profession,{}); editText=SEARCH; addon.recipeCatalog=nil
 local catalog=addon.RecipeCatalog(true)
 Check(GetNumTradeSkills()==25, 'catalog reduced '..profession..' to a filtered recipe list')
 for n=1,25 do
  Check(catalog.bySpell[list[n].spell], 'learned recipe absent from catalog')
  SelectTradeSkill(n); addon.BuildDependencyTree(n)
  Check(GetTradeSkillItemLink(selection)=='item:'..list[n].output, 'selection lost')
 end
 Check(addon.NativeCraft(list[25].spell,list[25].output), 'last recipe cannot craft')
 Check(GetNumTradeSkills()==25, 'native craft hid other recipes')
 editText='Search'; SetTradeSkillItemNameFilter('Search')
 Check(GetNumTradeSkills()==1, 'fixture must reproduce single-recipe filter')
 SlashCmdList.CRAFTTRAIL('all')
 Check(GetNumTradeSkills()==25 and not makeable and subFilter==0 and slotFilter==0,
  'show-all command failed for '..profession)
 -- A genuine text search still survives catalog scans.
 editText='Recipe950002'; SetTradeSkillItemNameFilter(editText)
 addon.RecipeCatalog(true)
 Check(GetNumTradeSkills()==1 and recipes[1].spell==950002, 'user search was not preserved')
end
print('Multiple-recipe list preservation and show-all checks passed for all 11 professions.')
-- Filter restoration can rebuild category expansion in the client. Both open
-- and deliberately closed categories must survive repeated scans and crafts.
editText=''
local open={header=true,name='Open category',expanded=true,category=1,reagents={}}
local closed={header=true,name='Closed category',expanded=false,category=2,reagents={}}
local r1=Recipe(970001,980001,{},1)
local r2=Recipe(970002,980002,{},2)
Setup({open,r1,closed,r2},'Engineering',{})
local originalNameFilter=SetTradeSkillItemNameFilter
SetTradeSkillItemNameFilter=function(text)
 for _,r in ipairs(allRecipes) do if r.header then r.expanded=false end end
 originalNameFilter(text)
end
for n=1,3 do
 addon.RecipeCatalog(true)
 Check(open.expanded and not closed.expanded, 'catalog changed category expansion')
 Check(GetNumTradeSkills()==3, 'catalog hid open category recipes')
 Check(addon.NativeCraft(r1.spell,r1.output), 'category fixture craft failed')
 addon.RestoreRecipeSelection()
 Check(open.expanded and not closed.expanded and GetNumTradeSkills()==3,
  'craft changed category expansion')
end
SetTradeSkillItemNameFilter=originalNameFilter
print('Repeated catalog/craft category expansion preservation passed.')
-- Smelting can have no subclass/slot options and no checked "All" flag.
-- Disabling All on restore must not turn that unfiltered state into an empty list.
editText=''
local copper=Recipe(2657,2840,{{2770,1}})
local tin=Recipe(3304,3576,{{2771,1}})
local bronze=Recipe(2659,2841,{{2840,1},{3576,1}})
Setup({copper,tin,bronze},'Smelting',{{id=2770,count=4},{id=2771,count=4}})
GetTradeSkillSubClasses=function() end
GetTradeSkillInvSlots=function() end
GetTradeSkillSubClassFilter=function() return nil end
GetTradeSkillInvSlotFilter=function() return nil end
local subSetter,slotSetter=SetTradeSkillSubClassFilter,SetTradeSkillInvSlotFilter
SetTradeSkillSubClassFilter=function(i,enabled,exclusive)
 if i==0 and enabled==0 then subFilter=-1; SetTradeSkillItemNameFilter(searchText)
 else subSetter(i,enabled,exclusive) end
end
SetTradeSkillInvSlotFilter=function(i,enabled,exclusive)
 if i==0 and enabled==0 then slotFilter=-1; SetTradeSkillItemNameFilter(searchText)
 else slotSetter(i,enabled,exclusive) end
end
for _,profession in ipairs({'Smelting','Mining'}) do
 line=profession; addon.recipeCatalog=nil
 addon.Refresh()
 Check(GetNumTradeSkills()==3, 'smelting catalog restoration emptied the native recipe list')
 Check(addon.RecipeCatalog().bySpell[2657] and addon.RecipeCatalog().bySpell[3304], 'smelting recipes absent')
 Check(addon.NativeCraft(2657,2840), 'known copper smelting did not craft')
 Check(GetNumTradeSkills()==3, 'smelting craft hid recipes')
end
-- Some clients expose an option but still report no checked filter.
GetTradeSkillSubClasses=function() return 'Metal' end
GetTradeSkillInvSlots=function() return 'Other' end
addon.RecipeCatalog(true)
Check(GetNumTradeSkills()==3, 'unchecked filter options emptied smelting list')
print('Uncategorized Smelting/Mining recipe lists and native crafting passed.')
''')
