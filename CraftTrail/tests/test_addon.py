"""Exercise the shipped addon with Lua 5.1 and mocked legacy WoW frame APIs.

Requires lupa (including lupa.lua51); these tests never start the game/server.
"""
import os
import sys
from pathlib import Path

# Optional existing dependency directory; normally install requirements-dev.txt.
if os.environ.get("CRAFTTRAIL_TEST_DEPS"):
    sys.path.insert(0, os.environ["CRAFTTRAIL_TEST_DEPS"])
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
harness = r'''
frames, hooks = {}, {}
local Frame = {}
Frame.__index = Frame
function Frame:GetName() return self.name end
function Frame:GetWidth() return self.width or 293 end
local anchors = {TOPLEFT={0,0}, TOP={0.5,0}, TOPRIGHT={1,0}, LEFT={0,0.5}, CENTER={0.5,0.5}, RIGHT={1,0.5}, BOTTOMLEFT={0,1}, BOTTOM={0.5,1}, BOTTOMRIGHT={1,1}}
function Frame:GetLeft()
    if not self.point then return self.left or 25 end
    local own, relative, target, x = unpack(self.point)
    return relative:GetLeft() + anchors[target][1] * relative:GetWidth() + x - anchors[own][1] * self:GetWidth()
end
function Frame:GetFrameLevel() return 2 end
function Frame:SetFrameLevel() end
function Frame:SetBackdrop() end
function Frame:SetBackdropColor() end
function Frame:EnableMouse() end
function Frame:EnableMouseWheel() end
function Frame:RegisterForDrag() end
function Frame:SetMovable(value) self.movable = value end
function Frame:SetClampedToScreen() end
function Frame:SetUserPlaced(value) self.userPlaced = value end
function Frame:StartMoving() self.moving = true end
function Frame:StopMovingOrSizing() self.moving = false end
function Frame:SetID(id) self.id = id end
function Frame:GetID() return self.id end
function Frame:GetFontString()
    if not self.font then self.font = CreateFrame('Font', nil, self) end
    return self.font
end
function Frame:SetFontObject() end
function Frame:SetHyperlinksEnabled(value) self.hyperlinksEnabled = value end
function Frame:GetText() return self.textValue end
function Frame:GetStringHeight()
    local lines = 0
    local visible = string.gsub(self.textValue or '', '|H.-|h(.-)|h', '%1')
    visible = string.gsub(string.gsub(visible, '|c%x%x%x%x%x%x%x%x', ''), '|r', '')
    for line in string.gmatch(visible .. '\n', '(.-)\n') do
        lines = lines + math.max(1, math.ceil(#line / 45))
    end
    return lines * 14
end
function Frame:ClearLines() self.tooltipLines = {} end
function Frame:NumLines() return #self.tooltipLines end
function Frame:SetTradeSkillItem(index)
    self.tooltipLines = recipes[index].tooltip or {'Glyph', 'Use: Glyph effect.'}
    for n, text in ipairs(self.tooltipLines) do
        local name = self:GetName() .. 'TextLeft' .. n
        local region = _G[name] or CreateFrame('Font', name, self)
        region:SetText(text)
    end
end
function Frame:SetNormalFontObject() end
function Frame:SetHighlightFontObject() end
function Frame:SetDisabledFontObject() end
function Frame:SetFontString(font) self.font = font end
function Frame:SetStatusBarTexture(texture) self.statusTexture = texture end
function Frame:SetStatusBarColor(r, g, b) self.color = {r, g, b} end
function Frame:SetMinMaxValues(low, high) self.minimum, self.maximum = low, high end
function Frame:SetValue(value) self.value = value end
function Frame:SetAllPoints(relative) self.allPoints = relative end
function Frame:UnlockHighlight() self.highlight = false end
function Frame:LockHighlight() self.highlight = true end
function Frame:SetVertexColor() end
function Frame:SetAttribute(key, value)
    assert(not combat, 'protected attribute changed in combat')
    self.attributes = self.attributes or {}; self.attributes[key] = value
end
function Frame:Enable() assert(not combat); self.enabled = true end
function Frame:Disable() assert(not combat); self.enabled = false end
function Frame:IsEnabled() return self.enabled end
function Frame:SetWidth(v) self.width = v end
function Frame:SetHeight(v) self.height = v end
function Frame:GetHeight() return self.height or 20 end
function Frame:GetNumPoints() return 1 end
function Frame:GetPoint()
    if self.point then return unpack(self.point) end
    return 'LEFT', self.parent, 'LEFT', 0, 0
end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetPoint(point, relative, relativePoint, x, y)
    self.point = {point, relative, relativePoint, x or 0, y or 0}
end
function Frame:GetTop()
    if not self.point then return self.top or 400 end
    local own, relative, target, x, y = unpack(self.point)
    return relative:GetTop() - anchors[target][2] * relative:GetHeight() + y + anchors[own][2] * self:GetHeight()
end
function Frame:GetBottom() return self:GetTop() - self:GetHeight() end
function Frame:SetText(v) self.textValue = v end
function Frame:SetTexture(v) self.texture = v end
function Frame:SetJustifyH() end
function Frame:SetHighlightTexture() end
function Frame:RegisterForClicks() end
function Frame:SetScript(event, fn) self.scripts[event] = fn end
function Frame:HookScript(event, fn) self.scripts[event] = fn end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
function Frame:GetParent() return self.parent end
function Frame:CreateFontString() return CreateFrame('Font', nil, self) end
function Frame:CreateTexture() return CreateFrame('Texture', nil, self) end
function Frame:UpdateScrollChildRect() self.updated = (self.updated or 0) + 1 end
function Frame:SetOwner(owner) self.owner = owner end
function Frame:GetOwner() return self.owner end
function Frame:IsOwned(owner) return self.owner == owner end
function Frame:SetHyperlink(link) self.hyperlink = link; self.tooltipCalls = (self.tooltipCalls or 0) + 1 end
function CreateFrame(kind, name, parent)
    local frame = setmetatable({scripts = {}, events = {}, shown = true, parent = parent, name = name}, Frame)
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
UIParent = CreateFrame('Frame'); UIParent.height = 1200; UIParent.top = 1200
GameTooltip = CreateFrame('GameTooltip')
TradeSkillFrame = CreateFrame('Frame'); TradeSkillFrame.height = 512; TradeSkillFrame.top = 1000
TradeSkillDetailScrollChildFrame = CreateFrame('Frame', nil, TradeSkillFrame)
TradeSkillDetailScrollChildFrame:SetHeight(150)
TradeSkillDetailScrollFrame = CreateFrame('ScrollFrame', nil, TradeSkillFrame)
TradeSkillDetailScrollFrame.height = 176
TradeSkillDetailScrollFrame:SetPoint('TOPLEFT', TradeSkillFrame, 'TOPLEFT', 20, -234)
TradeSkillDetailScrollChildFrame:SetPoint('TOPLEFT', TradeSkillDetailScrollFrame, 'TOPLEFT', 0, 0)
TradeSkillCreateButton = CreateFrame('Button', 'TradeSkillCreateButton', TradeSkillFrame)
TradeSkillCreateButton:SetPoint('CENTER', TradeSkillFrame, 'TOPLEFT', 224, -422)
TradeSkillCancelButton = CreateFrame('Button', 'TradeSkillCancelButton', TradeSkillFrame)
TradeSkillCancelButton:SetPoint('CENTER', TradeSkillFrame, 'TOPLEFT', 305, -422)
TradeSkillDescription = CreateFrame('Font', 'TradeSkillDescription', TradeSkillDetailScrollChildFrame)
TradeSkillDescription:SetPoint('TOPLEFT', TradeSkillDetailScrollChildFrame, 'TOPLEFT', 5, -50)
TradeSkillReagentLabel = CreateFrame('Frame', nil, TradeSkillDetailScrollChildFrame)
TradeSkillReagentLabel:SetPoint('TOPLEFT', TradeSkillDetailScrollChildFrame, 'TOPLEFT', 5, -60)
for n = 1, 8 do
    local row = CreateFrame('Button', 'TradeSkillReagent' .. n, TradeSkillDetailScrollChildFrame)
    if n == 1 then row:SetPoint('TOPLEFT', TradeSkillReagentLabel, 'BOTTOMLEFT', -2, -3)
    elseif n % 2 == 0 then row:SetPoint('LEFT', _G['TradeSkillReagent' .. (n - 1)], 'RIGHT', 0, 0)
    else row:SetPoint('TOPLEFT', _G['TradeSkillReagent' .. (n - 2)], 'BOTTOMLEFT', 0, -2) end
    row.height = 36
end
TradeSkillListScrollFrame = CreateFrame('ScrollFrame')
TradeSkillHighlightFrame = CreateFrame('Frame')
TradeSkillTypeColor = { optimal = { r = 1, g = 0.5, b = 0.25, font = 'font' } }
TRADE_SKILLS_DISPLAYED = 8
for n = 1, 8 do
    CreateFrame('Button', 'TradeSkillSkill' .. n, TradeSkillFrame)
    CreateFrame('Font', 'TradeSkillSkill' .. n .. 'Count', TradeSkillFrame)
end
function FauxScrollFrame_GetOffset() return scrollOffset or 0 end
function GetNumTradeSkills() return #recipes end
SlashCmdList = {}
combat, linked, dead, casting, cooldown, unusable = false, false, false, false, false, false
skill, bags, unknown = 100, {}, {}
function InCombatLockdown() return combat end
function IsTradeSkillLinked() return linked end
function UnitIsDeadOrGhost() return dead end
function UnitCastingInfo() return casting and 'Casting' or nil end
function UnitChannelInfo() return nil end
function IsSpellKnown(id) return not unknown[id] end
function GetSpellCooldown() if cooldown then return 100, 2, 1 end; return 0, 0, 1 end
function GetTime() return 100 end
function IsUsableSpell() return not unusable end
function GetContainerNumSlots(bag) return bags[bag] and #bags[bag] or 0 end
function GetContainerItemLink(bag, slot) return 'item:' .. bags[bag][slot].id end
function GetContainerItemInfo(bag, slot)
    local item = bags[bag][slot]; return 'icon', item.count, item.locked
end
function GetItemCount(id, includeBank)
    assert(not includeBank, 'bank materials must not enable bag actions')
    local count = 0
    for _, contents in pairs(bags) do for _, item in ipairs(contents) do
        if item.id == id then count = count + item.count end
    end end
    return count
end
selection, line = 1, 'Inscription'
recipes = {
    {output = 40897, reagents = {{43116, 3}, {39354, 1}}},
    {output = 43116, reagents = {{39338, 4}}},
    {output = 123, reagents = {{456, 1}}},
    {output = 40897, reagents = {{43116, 1}, {43127, 2}, {39354, 1}}},
    {header = true, reagents = {}},
}
function GetSpellInfo(id) if id == 45357 then return 'Inscription' elseif id == 51005 then return 'Milling' else return 'InkSpell' .. id end end
function GetTradeSkillLine() return line, skill end
function GetTradeSkillSelectionIndex() return selection end
function GetTradeSkillInfo(index)
    local r = recipes[index]; if r then return r.name or 'Recipe', r.header and 'header' or 'optimal', r.available or 0 end
end
function GetTradeSkillItemLink(index) return 'item:' .. recipes[index].output end
function GetTradeSkillDescription(index) return recipes[index].description end
function GetSpellLink(id) return '|cff71d5ff|Hspell:' .. id .. '|h[' .. GetSpellInfo(id) .. ']|h|r' end
function GetTradeSkillNumReagents(index) return #recipes[index].reagents end
function GetTradeSkillReagentItemLink(index, n) return 'item:' .. recipes[index].reagents[n][1] end
function GetTradeSkillReagentInfo(index, n) return 'Reagent', 'icon', recipes[index].reagents[n][2], 0 end
cold = false
function GetItemInfo(id)
    if cold then return nil end
    return 'Localized ' .. id, '|cffffffff|Hitem:' .. id .. ':0:0:0:0:0:0:0|h[Localized ' .. id .. ']|h|r',
        1, 1, 1, '', '', 20, '', 'icon-' .. id
end
function HandleModifiedItemClick(link) modifiedLink = link; return modified end
function SetItemRef(id, link) itemRef, itemRefLink = id, link end
function hooksecurefunc(name, fn) hooks[name] = fn end
function TradeSkillFrame_SetSelection() end
function TradeSkillFrame_Update() end
'''
lua.execute(harness)
addon = lua.table()
for name in ("Data.lua", "Actions.lua", "Progress.lua", "Description.lua", "Window.lua", "CraftTrail.lua"):
    lua.execute((ROOT / name).read_text(encoding="utf-8"), "CraftTrail", addon)
lua.globals().addon = addon
lua.execute(r'''
function Check(value, message) assert(value, message) end
function Tick()
    for _, frame in ipairs(frames) do
        if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 0.6) end
    end
end
function VisibleItems()
    local result = {}
    for _, frame in ipairs(frames) do
        if frame.itemID and frame.icon and frame:IsShown() then result[#result + 1] = frame end
    end
    return result
end
local count = 0
for _, recipe in pairs(addon.inks) do
    count = count + 1
    Check(addon.herbs[recipe.pigment] and #addon.herbs[recipe.pigment] > 0, 'missing herb sources')
end
Check(count == 15, 'ink coverage')
local groups = addon.BuildGroups(1)
Check(#groups == 1 and groups[1].ink == 43116, 'glyph ink selection')
Check(groups[1].pigment == 39338 and groups[1].pigmentCount == 2 and groups[1].amount == 3, 'golden pigment quantity')
local herbs = {}; for _, id in ipairs(groups[1].herbs) do herbs[id] = true end
Check(#groups[1].herbs == 4 and herbs[3369] and herbs[3356] and herbs[3357] and herbs[3355], 'Lions Ink herbs')
Tick()
Check(CraftTrailDetails:IsShown(), 'inline panel visibility')
Check(TradeSkillDetailScrollChildFrame:GetHeight() > 150, 'scrollable detail expansion')
local rows = VisibleItems()
Check(#rows == 6, 'ink, pigment and four herb item rows')
Check(string.find(rows[2].text.textValue, '6x pigment:', 1, true), 'pigment total for selected recipe')
rows[3].scripts.OnEnter(rows[3])
Check(GameTooltip.owner == rows[3] and string.find(GameTooltip.hyperlink, '|Hitem:', 1, true), 'native hover tooltip')
modified = true; itemRef = nil
rows[3].scripts.OnClick(rows[3])
Check(modifiedLink == GameTooltip.hyperlink and itemRef == nil, 'shift click native link')
modified = false
rows[3].scripts.OnClick(rows[3])
Check(itemRef and string.find(itemRef, '^item:'), 'normal click item reference')
rows[3].scripts.OnLeave(rows[3]); Check(not GameTooltip:IsShown(), 'tooltip hides on leave')
selection = 2; hooks.TradeSkillFrame_SetSelection(); Tick()
Check(addon.BuildGroups(2)[1].pigmentCount == 4, 'selected ink uses live pigment recipe')
selection = 4; hooks.TradeSkillFrame_SetSelection(); Tick()
Check(#addon.BuildGroups(4) == 2 and CraftTrailRowitem9 and CraftTrailRowitem9.used, 'multiple ink groups')
selection = 3; hooks.TradeSkillFrame_SetSelection(); Tick()
Check(not CraftTrailDetails:IsShown() and TradeSkillDetailScrollChildFrame:GetHeight() == 150, 'unrelated recipe cleanup')
Check(#addon.BuildGroups(0) == 0 and #addon.BuildGroups(5) == 0, 'invalid and header selection')
selection = 1; line = 'Alchemy'; hooks.TradeSkillFrame_Update(); Tick()
Check(not CraftTrailDetails:IsShown(), 'other profession hidden')
line = 'Inscription'; cold = true; hooks.TradeSkillFrame_SetSelection(); Tick()
Check(CraftTrailDetails:IsShown() and CraftTrailItemCache.tooltipCalls > 0, 'cold cache requested')
rows = VisibleItems()
Check(string.find(rows[3].text.textValue, '|Hitem:', 1, true), 'cold cache native fallback link')
cold = false; Tick()
Check(string.find(rows[3].text.textValue, 'Localized', 1, true), 'asynchronous localized cache refresh')
cold = true; hooks.TradeSkillFrame_SetSelection()
for n = 1, 20 do Tick() end
for _, frame in ipairs(frames) do Check(not frame.scripts.OnUpdate, 'bounded retries stop') end
TradeSkillFrame:Hide(); TradeSkillFrame.scripts.OnHide()
Check(not CraftTrailDetails:IsShown() and TradeSkillDetailScrollChildFrame:GetHeight() == 150, 'close cleanup')
Check(selection == 1, 'recipe selection preserved')
''')
print("Lua 5.1 addon tests passed: data coverage, recipe drilldown, native links/tooltips, scrolling, cache retries and cleanup.")

lua.execute(r'''
cold = false; TradeSkillFrame:Show(); line = 'Inscription'; selection = 1
bags = { [0] = { {id = 39338, count = 4}, {id = 3356, count = 5} } }
hooks.TradeSkillFrame_SetSelection(); Tick()
local rows = VisibleItems()
local craft = rows[1].action
Check(craft.enabled and craft.attributes.macrotext == '/cast [nocombat] InkSpell57704', 'one ink craft secure macro')
Check(TradeSkillFrame:GetHeight() == 768 and TradeSkillDetailScrollFrame:GetHeight() == 408, '1.5x height grows actual detail viewport')
local mill
for _, row in ipairs(rows) do if row.itemID == 3356 then mill = row.action end end
Check(mill and mill.enabled and mill.attributes.macrotext == '/cast [nocombat] Milling\n/use [nocombat] 0 2', 'five herbs enables one targeted milling action')
bags[0][2].count = 4; mill.scripts.PreClick(mill)
Check(not mill.enabled and mill.attributes.type == nil, 'four herbs cannot mill')
bags[0] = {{id = 3356, count = 3}, {id = 3356, count = 2}}
addon.ConfigureAction(mill, addon.BagStacks())
Check(not mill.enabled, 'split stacks cannot mill even with total five')
bags[0] = {{id = 3356, count = 5, locked = true}}
addon.ConfigureAction(mill, addon.BagStacks())
Check(not mill.enabled, 'locked stack unavailable')
bags[0][1].locked = false; skill = 74
addon.ConfigureAction(mill, addon.BagStacks())
Check(not mill.enabled, 'herb milling skill enforced')
skill = 75; addon.ConfigureAction(mill, addon.BagStacks())
Check(mill.enabled, 'herb milling skill boundary accepted')
unknown[51005] = true; addon.ConfigureAction(mill, addon.BagStacks())
Check(not mill.enabled, 'unlearned milling disabled'); unknown[51005] = nil
bags[0] = {{id = 39338, count = 1}}
craft.scripts.PreClick(craft)
Check(not craft.enabled and craft.attributes.macrotext == nil, 'craft disabled when pigments insufficient')
bags[0][1].count = 4; unknown[57704] = true
local learnedOutput = recipes[2].output; recipes[2].output = 999
addon.ConfigureAction(craft, addon.BagStacks())
Check(craft.enabled, 'hidden ink can attempt a normal cast; spellbook absence is not proof of unlearned recipe')
recipes[2].output = learnedOutput
addon.ConfigureAction(craft, addon.BagStacks())
Check(craft.enabled, 'learned profession recipe accepted even when absent from spellbook'); unknown[57704] = nil
linked = true; addon.ConfigureAction(craft, addon.BagStacks())
Check(not craft.enabled, 'linked profession actions disabled'); linked = false
unusable = true; addon.ConfigureAction(craft, addon.BagStacks())
Check(craft.enabled, 'generic spell usability does not disable a craftable profession recipe'); unusable = false
casting = true; addon.ConfigureAction(craft, addon.BagStacks())
Check(not craft.enabled, 'busy casting disables craft'); casting = false
cooldown = true; addon.ConfigureAction(craft, addon.BagStacks())
Check(not craft.enabled, 'cooldown disables craft'); cooldown = false
dead = true; addon.ConfigureAction(craft, addon.BagStacks())
Check(not craft.enabled, 'dead character cannot craft'); dead = false
bags[0] = {{id = 3356, count = 5}}
addon.ConfigureAction(mill, addon.BagStacks())
bags[0][1].id = 36901
mill.scripts.PreClick(mill)
Check(not mill.enabled and mill.attributes.type == nil, 'stale slot cannot target a different herb')
combat = true
Check(not addon.ActionState('craft', 43116, {}), 'combat eligibility gate')
mill.scripts.PreClick(mill)
addon.Refresh()
TradeSkillFrame.scripts.OnHide()
combat = false

SlashCmdList.CRAFTTRAIL('normal')
Check(TradeSkillFrame:GetHeight() == 512 and TradeSkillDetailScrollFrame:GetHeight() == 152, 'normal height option')
SlashCmdList.CRAFTTRAIL('tall')
Check(TradeSkillFrame:GetHeight() == 768, 'tall height option')
local drag
for _, frame in ipairs(frames) do if frame.scripts.OnDragStart then drag = frame end end
Check(drag and TradeSkillFrame.movable, 'header drag available')
drag.scripts.OnDragStart(); Check(TradeSkillFrame.moving, 'drag starts')
drag.scripts.OnDragStop()
Check(CraftTrailDB.position and TradeSkillFrame.userPlaced and not TradeSkillFrame.moving, 'position saved on drag stop')
local savedX, savedY = CraftTrailDB.position.x, CraftTrailDB.position.y
addon.UpdateWindow()
Check(TradeSkillFrame.point[4] == savedX and TradeSkillFrame.point[5] == savedY, 'saved position restored')
line = 'Alchemy'; addon.UpdateWindow()
Check(TradeSkillFrame:GetHeight() == 512 and TradeSkillDetailScrollFrame:GetHeight() == 176, 'other professions retain normal height')
line = 'Inscription'; SlashCmdList.CRAFTTRAIL('reset')
Check(CraftTrailDB.position == nil, 'position reset available')

local savedRecipes = recipes
recipes = {
    {header = true, name = 'Shaman', reagents = {}},
    {output = 41105, name = 'Higher glyph', reagents = {}},
    {output = 40897, name = 'Low glyph', reagents = {}},
    {output = 43116, name = 'An ink stays here', reagents = {}},
    {header = true, name = 'Another class', reagents = {}},
    {output = 41105, name = 'Higher other', reagents = {}},
    {output = 41531, name = 'Lower other', reagents = {}},
}
local order = addon.RecipeOrder()
Check(order[1] == 1 and order[2] == 3 and order[3] == 2 and order[4] == 4 and order[5] == 5 and order[6] == 7 and order[7] == 6,
    'ascending levels within headers, non-glyph slots preserved')
selection = 3; addon.UpdateRecipeList()
Check(TradeSkillSkill2.id == 3 and TradeSkillSkill3.id == 2, 'sorted rows retain original recipe indices')
Check(TradeSkillSkill2.craftTrailLevel.textValue == 'Lv 15', 'visible required character level')
Check(TradeSkillSkill2.highlight and TradeSkillHighlightFrame:IsShown(), 'sorted selection highlight')
scrollOffset = 5; selection = 7; addon.UpdateRecipeList()
Check(TradeSkillSkill1.id == 7 and TradeSkillSkill1.craftTrailLevel.textValue == 'Lv 15', 'sorted scrolled rows')
scrollOffset = 0
recipes[3].output = 43316; recipes[3].name = 'Minor glyph'
addon.UpdateRecipeList()
Check(TradeSkillSkill2.craftTrailMinor.textValue == 'm', 'minor glyph lowercase marker')
Check(TradeSkillSkill3.craftTrailMinor.textValue == '', 'major glyph has no marker')
Check(TradeSkillSkill2:GetFontString().point[4] == 14 and TradeSkillSkill3:GetFontString().point[4] == 14,
    'minor and major names share a fixed alignment column')
line = 'Alchemy'; addon.UpdateRecipeList()
Check(not TradeSkillSkill2.craftTrailMinor:IsShown() and not TradeSkillSkill2.craftTrailLevel:IsShown(), 'annotations removed outside Inscription')
line = 'Inscription'
recipes = savedRecipes; selection = 1; scrollOffset = 0
''')
print("Action eligibility, stale-slot click validation, combat guards, taller viewport, saved dragging and per-class level sorting passed.")

late = LuaRuntime(unpack_returned_tuples=True)
late.execute(harness)
late.execute("CraftTrailDB = {tall = false, position = {x = 77, y = -88}}")
late.execute("savedChild = TradeSkillDetailScrollChildFrame; TradeSkillDetailScrollChildFrame = nil")
late_addon = late.table()
for name in ("Data.lua", "Actions.lua", "Progress.lua", "Description.lua", "Window.lua", "CraftTrail.lua"):
    late.execute((ROOT / name).read_text(encoding="utf-8"), "CraftTrail", late_addon)
late.execute("assert(CraftTrailDetails == nil); TradeSkillDetailScrollChildFrame = savedChild")
late.execute("for _, frame in ipairs(frames) do if frame.events.ADDON_LOADED then frame.scripts.OnEvent(frame, 'ADDON_LOADED', 'Blizzard_TradeSkillUI') end end; assert(CraftTrailDetails and hooks.TradeSkillFrame_SetSelection)")
print("Late-loading Blizzard profession UI attachment passed.")
late.execute("for _, frame in ipairs(frames) do if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 0.6) end end; assert(TradeSkillFrame:GetHeight() == 512 and TradeSkillFrame.point[4] == 77 and TradeSkillFrame.point[5] == -88)")
print("Preloaded saved window settings restored in a fresh Lua runtime.")

lua.execute(r'''
line = 'Inscription'; skill = 375; selection = 1; cold = false
TradeSkillFrame:Show(); SlashCmdList.CRAFTTRAIL('tall')
local originalKnown, originalBagInfo = IsSpellKnown, GetContainerItemInfo
IsSpellKnown = function() return 0 end
GetNumSpellTabs = function() return 1 end
GetSpellTabInfo = function() return 'General', 'icon', 0, 1 end
GetSpellName = function() return 'Milling' end
GetContainerItemInfo = function(bag, slot)
    local texture, count, locked = originalBagInfo(bag, slot)
    return texture, count, locked and 1 or 0
end
linked, dead = 0, 0
bags = { [0] = {{id = 3356, count = 91}} }
addon.Refresh()
local rows = VisibleItems()
local mill, seenNames = nil, {}
for _, row in ipairs(rows) do
    if row.action then
        Check(not seenNames[row.action:GetName()], 'secure action widgets have unique names')
        seenNames[row.action:GetName()] = true
        Check(row.action:GetParent() == row, 'action stays attached to its own herb row')
    end
    if row.itemID == 3356 then mill = row.action end
end
Check(mill and mill.enabled, '91 Kingsblood enables Milling with legacy zero flags and spellbook knowledge')
Check(TradeSkillCreateButton:GetTop() < TradeSkillDetailScrollFrame:GetBottom(), 'Create stays below the expanded viewport')
Check(TradeSkillCancelButton:GetTop() < TradeSkillDetailScrollFrame:GetBottom(), 'Exit stays below the expanded viewport')
Check(CraftTrailDetails:GetLeft() == TradeSkillDetailScrollChildFrame:GetLeft() + 5, 'reference anchored to left edge rather than second reagent column')
Check(CraftTrailDetails.point[2] == TradeSkillDetailScrollChildFrame, 'reference belongs geometrically to scroll child')
TradeSkillDetailScrollChildFrame:SetPoint('TOPLEFT', TradeSkillDetailScrollFrame, 'TOPLEFT', 0, 200)
TradeSkillDetailScrollFrame.scripts.OnVerticalScroll()
local hidden = 0
for _, frame in ipairs(frames) do
    if frame.used then
        if frame:IsShown() then
            Check(frame:GetTop() <= TradeSkillDetailScrollFrame:GetTop() and frame:GetBottom() >= TradeSkillDetailScrollFrame:GetBottom(),
                'every visible row and its click target remain inside the viewport')
        else hidden = hidden + 1 end
    end
end
Check(hidden > 0, 'out-of-viewport rows explicitly hidden after scrolling')
TradeSkillDetailScrollChildFrame:SetPoint('TOPLEFT', TradeSkillDetailScrollFrame, 'TOPLEFT', 0, 0)
TradeSkillDetailScrollFrame.scripts.OnVerticalScroll()
Check(#VisibleItems() == 6, 'scrolling back restores every ink/pigment/herb row')
GetSpellName = function() return 'Other spell' end
addon.ConfigureAction(mill, addon.BagStacks())
Check(not mill.enabled, 'spellbook fallback still rejects genuinely unlearned Milling')
IsSpellKnown, GetContainerItemInfo = originalKnown, originalBagInfo
linked, dead = false, false
line = 'Alchemy'; addon.Refresh()
Check(TradeSkillCreateButton.point[3] == 'TOPLEFT' and TradeSkillCreateButton.point[5] == -422,
    'original toolbar anchors restored outside Inscription')
''')
print("Screenshot regressions passed: toolbar geometry, bounded row hit areas, unique buttons, and 91 Kingsblood with legacy API flags.")

lua.execute(r'''
line = 'Inscription'; selection = 1; SlashCmdList.CRAFTTRAIL('tall'); addon.Refresh()
local rows, actions, labels = VisibleItems(), 0, {}
for _, row in ipairs(rows) do
    if row.hasAction then
        actions = actions + 1
        Check(row.action:IsShown(), 'every visible ink/herb row always shows its action, including disabled buttons')
        local label = row.action:GetFontString()
        Check(not labels[label], 'each action owns a distinct label')
        labels[label] = true
        Check(row.action.textValue == (row.action.kind == 'craft' and 'Craft' or 'Mill'), 'correct action caption')
    end
end
Check(actions == 5, 'one Craft and four Mill buttons for Lions Ink')
Check(CraftTrailCastBar:GetTop() < TradeSkillDetailScrollFrame:GetBottom(), 'cast bar below details viewport')
Check(CraftTrailCastBar:GetBottom() > TradeSkillCreateButton:GetTop(), 'cast bar above native toolbar')
local now, liveCast, liveChannel = 100, nil, nil
local originalTime, originalCasting, originalChannel = GetTime, UnitCastingInfo, UnitChannelInfo
GetTime = function() return now end
UnitCastingInfo = function()
    if liveCast then return liveCast.name, '', liveCast.name, 'icon', liveCast.start, liveCast.finish, true end
end
UnitChannelInfo = function()
    if liveChannel then return liveChannel.name, '', liveChannel.name, 'icon', liveChannel.start, liveChannel.finish end
end
liveCast = {name = 'Milling', start = 100000, finish = 103000}
CraftTrailCastBar.scripts.OnEvent(CraftTrailCastBar, 'UNIT_SPELLCAST_START', 'player')
now = 101; CraftTrailCastBar.scripts.OnUpdate(CraftTrailCastBar, 1)
Check(CraftTrailCastBar.value == 1 and CraftTrailCastBar.maximum == 3, 'cast progress uses live start/end timestamps')
Check(string.find(CraftTrailCastBar.label.textValue, '2.0s', 1, true), 'remaining cast time displayed')
liveCast.finish = 105000
CraftTrailCastBar.scripts.OnEvent(CraftTrailCastBar, 'UNIT_SPELLCAST_DELAYED', 'player')
Check(CraftTrailCastBar.maximum == 5, 'delayed cast adjusts actual duration')
liveCast = nil
CraftTrailCastBar.scripts.OnEvent(CraftTrailCastBar, 'UNIT_SPELLCAST_INTERRUPTED', 'player')
CraftTrailCastBar.scripts.OnEvent(CraftTrailCastBar, 'UNIT_SPELLCAST_STOP', 'player')
Check(CraftTrailCastBar.label.textValue == 'Interrupted', 'interrupt status survives following stop event')
now = 102.1; CraftTrailCastBar.scripts.OnUpdate(CraftTrailCastBar, 1.1)
Check(CraftTrailCastBar.label.textValue == 'Ready' and CraftTrailCastBar.scripts.OnUpdate == nil, 'idle stops progress updates')
CraftTrailCastBar.scripts.OnEvent(CraftTrailCastBar, 'UNIT_SPELLCAST_SUCCEEDED', 'player')
Check(CraftTrailCastBar.label.textValue == 'Complete' and CraftTrailCastBar.value == 1, 'success feedback comes from actual success event')
now = 103; CraftTrailCastBar.scripts.OnUpdate(CraftTrailCastBar, 0.9)
Check(CraftTrailCastBar.label.textValue == 'Ready', 'completion feedback expires')
liveChannel = {name = 'Channel', start = 103000, finish = 105000}
CraftTrailCastBar.scripts.OnEvent(CraftTrailCastBar, 'UNIT_SPELLCAST_CHANNEL_START', 'player')
now = 104; CraftTrailCastBar.scripts.OnUpdate(CraftTrailCastBar, 1)
Check(CraftTrailCastBar.value == 1 and CraftTrailCastBar.maximum == 2, 'channel progress supported')
CraftTrailCastBar.scripts.OnEvent(CraftTrailCastBar, 'UNIT_SPELLCAST_FAILED', 'party1')
Check(string.find(CraftTrailCastBar.label.textValue, 'Channel', 1, true), 'other players do not change cast bar')
liveChannel = nil
CraftTrailCastBar.scripts.OnEvent(CraftTrailCastBar, 'UNIT_SPELLCAST_FAILED', 'player')
Check(CraftTrailCastBar.label.textValue == 'Cast failed', 'failed cast feedback')
line = 'Alchemy'; addon.Refresh()
Check(not CraftTrailCastBar:IsShown() and CraftTrailCastBar.scripts.OnUpdate == nil, 'cast bar hidden and idle outside Inscription')
GetTime, UnitCastingInfo, UnitChannelInfo = originalTime, originalCasting, originalChannel
''')
print("All action-button labels/visibility and live-timestamp cast-bar lifecycle tests passed.")

lua.execute(r'''
local originalSpellInfo = GetSpellInfo
GetSpellInfo = function(id)
    if id == 853 then return 'Hammer of Justice' end
    if id == 20164 then return 'Justice' end
    if id == 20177 then return 'Reckoning' end
    return originalSpellInfo(id)
end
local foundAbility, foundTalent = false, false
for _, id in ipairs(addon.classSpells[2]) do
    if id == 853 then foundAbility = true end
    if id == 20177 then foundTalent = true end
end
Check(foundAbility and foundTalent and addon.glyphClasses[41095] == 2, 'real DBC ability/talent and glyph class mapping')
local originalOutput, originalTooltip = recipes[1].output, recipes[1].tooltip
recipes[1].output = 41095
recipes[1].tooltip = {'Glyph of Hammer of Justice', 'Classes: Paladin', 'Requires Level 15',
    '|cff00ff00Use: Increases your Hammer of Justice range by 5 yards.|r'}
line = 'Inscription'; selection = 1; addon.Refresh()
local description = CraftTrailGlyphDescription
Check(description:IsShown() and description.hyperlinksEnabled, 'always-visible interactive description')
Check(string.find(description.textValue, '|Hspell:853|hHammer of Justice|h', 1, true), 'ability becomes an inline native spell link')
Check(not string.find(description.textValue, 'Classes:', 1, true), 'tooltip metadata excluded')
Check(string.find(description.textValue, '5 yards.', 1, true), 'formatted tooltip values preserved')
Check(TradeSkillReagentLabel.point[2] == description and TradeSkillReagentLabel:GetTop() < description:GetBottom(), 'reagents below description')
local linked = addon.LinkDescription(41095, 'Hammer of Justice grants Justiceful power. Reckoning is a talent. Unknown Ability stays plain.')
Check(string.find(linked, '|Hspell:853|hHammer of Justice|h', 1, true), 'longest overlapping spell name wins')
Check(not string.find(linked, '|hJustice|h', 1, true) and string.find(linked, 'Justiceful', 1, true), 'no substring links')
Check(string.find(linked, '|Hspell:20177|hReckoning|h', 1, true), 'talent becomes a reference link')
Check(string.find(linked, 'Unknown Ability stays plain.', 1, true), 'unmatched wording unchanged')
description.scripts.OnHyperlinkEnter(description, 'spell:853')
Check(GameTooltip.hyperlink == 'spell:853' and GameTooltip:IsOwned(description), 'spell hover tooltip')
modified = false; itemRef = nil
description.scripts.OnHyperlinkClick(description, 'spell:853', 'Hammer of Justice', 'LeftButton')
Check(itemRef == 'spell:853', 'spell click opens reference')
modified = true; itemRef = nil
description.scripts.OnHyperlinkClick(description, 'spell:853', 'Hammer of Justice', 'LeftButton')
Check(itemRef == nil and string.find(modifiedLink, '|Hspell:853', 1, true), 'shift-click uses native spell link')
description.scripts.OnHyperlinkClick(description, 'https:invalid', 'Invalid', 'LeftButton')
Check(itemRef == nil, 'non-spell links ignored')
description.scripts.OnHyperlinkLeave(description)
Check(not GameTooltip:IsShown(), 'spell tooltip closes on leave')
recipes[1].tooltip = {'Glyph', 'Use: ' .. string.rep('Long description with Hammer of Justice. ', 8)}
addon.Refresh()
Check(description:GetHeight() > 60 and TradeSkillReagentLabel:GetTop() < description:GetBottom(), 'long description wraps and pushes reagents down')
recipes[1].tooltip = {'Glyph', 'Not loaded yet'}
Check(addon.Refresh(), 'missing description requests bounded refresh')
Check(description.textValue == 'Loading glyph description...', 'missing cache never invents an effect')
ITEM_SPELL_TRIGGER_ONUSE = 'Utiliser : %s'
recipes[1].tooltip = {'Glyphe', 'Utiliser : Texte localise.'}
Check(addon.ReadGlyphDescription(1) == 'Texte localise.', 'localized tooltip use prefix')
ITEM_SPELL_TRIGGER_ONUSE = nil
selection = 2; addon.Refresh()
Check(not description:IsShown() and TradeSkillReagentLabel.point[2] == TradeSkillDescription, 'ink recipes restore native description layout')
selection = 1; recipes[1].tooltip = {'Glyph', 'Use: Effect.'}; addon.Refresh()
line = 'Alchemy'; addon.Refresh()
Check(not description:IsShown() and TradeSkillReagentLabel.point[2] == TradeSkillDescription, 'other professions restore native layout')
recipes[1].output, recipes[1].tooltip = originalOutput, originalTooltip
GetSpellInfo = originalSpellInfo
''')
print("Inline glyph descriptions, real ability/talent references, native link interactions and wrapped layout tests passed.")

lua.execute(r'''
local savedRecipes, savedBags = recipes, bags
local savedKnown, savedUsable, savedCooldown = IsSpellKnown, IsUsableSpell, GetSpellCooldown
line = 'Inscription'; skill = 375; selection = 1
combat, linked, dead, casting = false, false, false, false
recipes = {
    {output = 40897, reagents = {{39774, 1}, {39354, 1}}},
    {output = 39774, reagents = {{39334, 2}}},
}
IsSpellKnown = function() return 0 end
IsUsableSpell = function() return 0 end
GetSpellCooldown = function() return 0, 0, 0 end
bags = {[0] = {{id = 39334, count = 1}}}
addon.Refresh()
local craft
for _, row in ipairs(VisibleItems()) do if row.itemID == 39774 then craft = row.action end end
Check(craft and not craft.enabled, 'Midnight Ink requires two Dusky Pigment')
for _, count in ipairs({2, 5}) do
    bags[0][1].count = count
    for _, frame in ipairs(frames) do
        if frame.events.BAG_UPDATE and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, 'BAG_UPDATE', 0) end
    end
    Tick()
    Check(craft.enabled, 'bag refresh enables Midnight Ink at two and five pigments despite generic API zero flags')
    Check(craft.attributes.macrotext == '/cast [nocombat] InkSpell53462', 'Midnight Ink casts the actual recipe')
    Check(selection == 1, 'craft preparation leaves the glyph selected')
end
GetTradeSkillTools = function() return 'Virtuoso Inking Set', 0 end
addon.ConfigureAction(craft, addon.BagStacks())
Check(not craft.enabled and craft.reason == 'Missing required crafting tool.', 'missing live recipe tool disables craft')
GetTradeSkillTools = function() return 'Virtuoso Inking Set', 1 end
addon.ConfigureAction(craft, addon.BagStacks())
Check(craft.enabled, 'present live recipe tool permits craft')
GetTradeSkillTools = nil
recipes[2].reagents[2] = {999, 1}
addon.ConfigureAction(craft, addon.BagStacks())
Check(not craft.enabled, 'all live ink reagents are checked')
recipes[2].reagents[2] = nil
recipes[2] = nil
IsSpellKnown = function(id) return id == 53462 and 1 or 0 end
addon.ConfigureAction(craft, addon.BagStacks())
Check(craft.enabled, 'known ink remains craftable when the recipe is filtered out')
recipes, bags = savedRecipes, savedBags
IsSpellKnown, IsUsableSpell, GetSpellCooldown = savedKnown, savedUsable, savedCooldown
''')
print("Midnight Ink regression passed: learned recipe, legacy zero flags, two/five pigments, bag events, live reagents/tools and preserved glyph selection.")

lua.execute(r'''
local savedRecipes, savedBags = recipes, bags
local savedKnown, savedCooldown = IsSpellKnown, GetSpellCooldown
line = 'Inscription'; skill = 375; selection = 1
combat, linked, dead, casting = false, false, false, false
recipes = {{output = 40897, reagents = {{39774, 1}, {39354, 1}}}}
IsSpellKnown = function() return 0 end
GetSpellCooldown = function() return 0, 0, 0 end
bags = {[0] = {{id = 39334, count = 5}}}
addon.Refresh()
local craft
for _, row in ipairs(VisibleItems()) do if row.itemID == 39774 then craft = row.action end end
Check(craft and craft.enabled, 'hidden Midnight Ink stays enabled even when generic knowledge API returns zero')
Check(craft.attributes.macrotext == '/cast [nocombat] InkSpell53462', 'hidden recipe retains normal secure cast')
bags[0][1].count = 1
addon.Refresh()
Check(not craft.enabled, 'insufficient bags still disable a hidden recipe')
local reasonFound = false
for _, frame in ipairs(frames) do
    if frame.text and frame:IsShown() and not frame.itemID then
        local text = frame.text:GetText() or ''
        if string.find(text, 'Craft unavailable: Not enough pigment', 1, true) then
            reasonFound = true
            Check(frame:GetHeight() >= frame.text:GetStringHeight(), 'disabled reason reserves its wrapped height')
        end
    end
end
Check(reasonFound, 'disabled craft reason is visible without hovering')
local savedPrint, messages = print, {}
print = function(text) messages[#messages + 1] = text end
GetAddOnMetadata = function() return '1.3.2' end
SlashCmdList.CRAFTTRAIL('why')
Check(#messages == 2 and string.find(messages[2], 'DISABLED', 1, true), 'why command reports exact blocker')
SlashCmdList.CRAFTTRAIL('version')
Check(messages[3] == 'CraftTrail version: 1.3.2', 'version command reports installed metadata')
print = savedPrint
recipes, bags = savedRecipes, savedBags
IsSpellKnown, GetSpellCooldown = savedKnown, savedCooldown
''')
print("Hidden-recipe regression passed with zero spell knowledge, visible wrapped blockers, and why/version diagnostics.")
