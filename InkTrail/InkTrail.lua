local addonName, addon = ...
local driver = CreateFrame("Frame")
local panel, originalHeight, panelOffset
local widgets = {}
local needsBuild, retryTime, retries = false, 0, 0
local requested = {}
local cacheTooltip = CreateFrame("GameTooltip", "InkTrailItemCache", UIParent, "GameTooltipTemplate")
cacheTooltip:Hide()

function addon.ItemID(link)
    return link and tonumber(string.match(link, "item:(%d+)"))
end

-- Reads the selected recipe without changing its selection, filters or crafting queue.
function addon.BuildGroups(index)
    local groups, seen = {}, {}
    local function Add(ink, amount)
        local recipe = addon.inks[ink]
        if not recipe or seen[ink] then return end
        seen[ink] = true
        groups[#groups + 1] = { ink = ink, amount = amount, pigment = recipe.pigment,
            pigmentCount = recipe.count, herbs = addon.herbs[recipe.pigment] }
    end
    if not index or index < 1 then return groups end
    local _, kind = GetTradeSkillInfo(index)
    if not kind or kind == "header" then return groups end
    local output = addon.ItemID(GetTradeSkillItemLink(index))
    if addon.inks[output] then
        Add(output, 1)
        -- Prefer the selected recipe's live pigment quantity where available.
        for reagent = 1, GetTradeSkillNumReagents(index) do
            if addon.ItemID(GetTradeSkillReagentItemLink(index, reagent)) == groups[1].pigment then
                local _, _, count = GetTradeSkillReagentInfo(index, reagent)
                groups[1].pigmentCount = count or groups[1].pigmentCount
            end
        end
    else
        for reagent = 1, GetTradeSkillNumReagents(index) do
            local ink = addon.ItemID(GetTradeSkillReagentItemLink(index, reagent))
            local _, _, count = GetTradeSkillReagentInfo(index, reagent)
            Add(ink, count or 1)
        end
    end
    return groups
end

local function ItemDetails(id)
    local name, link, _, _, _, _, _, _, _, texture = GetItemInfo(id)
    if not name and not requested[id] then
        requested[id] = true
        cacheTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        cacheTooltip:SetHyperlink("item:" .. id .. ":0:0:0:0:0:0:0")
        cacheTooltip:Hide()
    end
    local fallback = addon.names[id] or ("Item " .. id)
    return link or ("|cffffffff|Hitem:" .. id .. ":0:0:0:0:0:0:0|h[" .. fallback .. "]|h|r"),
        texture or "Interface\\Icons\\INV_Misc_QuestionMark", name ~= nil
end

local function Tooltip(self)
    if not self.itemID then return end
    local link = ItemDetails(self.itemID)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
end

local function GetWidget(index, item)
    local key = (item and "item" or "label") .. index
    if widgets[key] then return widgets[key] end
    local row = CreateFrame(item and "Button" or "Frame", "InkTrailRow" .. key, panel)
    row:SetFrameLevel(panel:GetFrameLevel() + 1)
    row:SetWidth(285)
    row:SetHeight(item and 26 or 20)
    row.text = row:CreateFontString(nil, "OVERLAY", item and "GameFontHighlightSmall" or "GameFontNormalSmall")
    row.text:SetPoint("LEFT", row, "LEFT", item and 27 or 0, 0)
    row.text:SetWidth(item and 254 or 285)
    row.text:SetJustifyH("LEFT")
    if item then
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetWidth(22)
        row.icon:SetHeight(22)
        row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnEnter", Tooltip)
        row:SetScript("OnLeave", function(self)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        row:SetScript("OnClick", function(self)
            local link = ItemDetails(self.itemID)
            if not HandleModifiedItemClick(link) then
                SetItemRef(string.match(link, "|H(.-)|h"), link, "LeftButton")
            end
        end)
    end
    widgets[key] = row
    return row
end

local function ResizeDetails()
    if InCombatLockdown() or not panel or not panel:IsShown() then return end
    local child = TradeSkillDetailScrollChildFrame
    if panelOffset then
        child:SetHeight(math.max(originalHeight, panelOffset + panel:GetHeight() + 12))
        TradeSkillDetailScrollFrame:UpdateScrollChildRect()
    end
end

function addon.ClipRows()
    if InCombatLockdown() or not panel or not panel:IsShown() then return end
    local viewport = TradeSkillDetailScrollFrame
    local top, bottom = viewport:GetTop(), viewport:GetBottom()
    if not top or not bottom then return end
    -- Legacy scroll frames do not reliably clip nested secure buttons. Never let
    -- a partly visible row draw or receive clicks outside the details viewport.
    for _, row in pairs(widgets) do
        if row.used then
            local rowTop, rowBottom = row:GetTop(), row:GetBottom()
            if rowTop and rowBottom and rowTop <= top and rowBottom >= bottom then
                row:Show()
                if row.hasAction then row.action:Show() end
            else
                if GameTooltip:IsOwned(row) or (row.action and GameTooltip:IsOwned(row.action)) then GameTooltip:Hide() end
                row:Hide()
            end
        end
    end
end

local function Clear()
    if InCombatLockdown() or not panel then return end
    if GameTooltip:GetOwner() and GameTooltip:GetOwner():GetParent() == panel then GameTooltip:Hide() end
    for _, widget in pairs(widgets) do widget.used = false; widget:Hide() end
    panel:Hide()
    TradeSkillDetailScrollChildFrame:SetHeight(originalHeight)
    TradeSkillDetailScrollFrame:UpdateScrollChildRect()
end

function addon.Refresh()
    if InCombatLockdown() or not panel then return false end
    Clear()
    if not TradeSkillFrame:IsShown() then addon.HideDescription(); addon.ResetWindow(); return false end
    addon.UpdateWindow()
    addon.UpdateRecipeList()
    local inscription = GetSpellInfo(45357)
    if not inscription or GetTradeSkillLine() ~= inscription then
        addon.RestoreDescription(GetTradeSkillSelectionIndex())
        return false
    end
    local index = GetTradeSkillSelectionIndex()
    local descriptionMissing = addon.UpdateDescription(index)
    local groups = addon.BuildGroups(index)
    if #groups == 0 then return descriptionMissing end

    local lowest = TradeSkillReagentLabel:GetBottom()
    for reagent = 1, GetTradeSkillNumReagents(index) do
        local button = _G["TradeSkillReagent" .. reagent]
        local bottom = button and button:IsShown() and button:GetBottom()
        if bottom and (not lowest or bottom < lowest) then lowest = bottom end
    end
    local child = TradeSkillDetailScrollChildFrame
    panelOffset = math.max(0, (child:GetTop() or 0) - (lowest or child:GetTop() or 0)) + 12
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", child, "TOPLEFT", 5, -panelOffset)
    panel:Show()
    local position, rowIndex, missing = 0, 0, descriptionMissing
    local stacks = addon.BagStacks()
    local function Row(text, item, action, pigmentCount)
        rowIndex = rowIndex + 1
        local row = GetWidget(rowIndex, item)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -position)
        row.used = true
        row.hasAction = action ~= nil
        row.itemID = item
        if item then
            local link, texture, cached = ItemDetails(item)
            row.text:SetText((text or "") .. link)
            row.icon:SetTexture(texture)
            missing = missing or not cached
            row.text:SetWidth(action and 199 or 254)
            if action then
                if not row.action then row.action = addon.CreateAction(row) end
                row.action:ClearAllPoints()
                row.action:SetPoint("RIGHT", row, "RIGHT", 0, 0)
                row.action.kind, row.action.itemID = action, item
                row.action.pigmentCount = pigmentCount
                row.action:SetText(action == "craft" and "Craft" or "Mill")
                addon.ConfigureAction(row.action, stacks)
                row.action:Show()
            elseif row.action then
                row.action:Hide()
            end
        else
            row.text:SetText(text)
        end
        row:Show()
        position = position + row:GetHeight()
    end
    Row("InkTrail - ink > pigment > herbs")
    for _, group in ipairs(groups) do
        Row(group.amount .. "x ", group.ink, "craft", group.pigmentCount)
        Row((group.amount * group.pigmentCount) .. "x pigment: ", group.pigment)
        Row("Mill any ONE herb below (5 per milling):")
        for _, herb in ipairs(group.herbs) do Row(nil, herb, "mill") end
        position = position + 6
    end
    Row("Milling yields vary. Hover for item/bank info.")
    panel:SetHeight(position)
    ResizeDetails()
    addon.ClipRows()
    return missing
end

local function Tick(self, elapsed)
    retryTime = retryTime + elapsed
    if not needsBuild and retryTime < 0.5 then return end
    retryTime = 0
    local fresh = needsBuild
    needsBuild = false
    local missing = addon.Refresh()
    ResizeDetails()
    retries = retries + 1
    if not missing or retries >= 10 then
        self:SetScript("OnUpdate", nil)
    elseif fresh then
        -- A bounded retry handles item names/icons arriving after the recipe opens.
        retries = 0
    end
end

local function Schedule()
    needsBuild, retryTime, retries = true, 0, 0
    driver:SetScript("OnUpdate", Tick)
end

local function Attach()
    if InCombatLockdown() or panel or not TradeSkillDetailScrollChildFrame or not TradeSkillFrame_SetSelection then return end
    originalHeight = TradeSkillDetailScrollChildFrame:GetHeight()
    panel = CreateFrame("Frame", "InkTrailDetails", TradeSkillDetailScrollChildFrame)
    panel:SetFrameLevel(TradeSkillDetailScrollChildFrame:GetFrameLevel() + 1)
    panel:SetWidth(289)
    panel:Hide()
    hooksecurefunc("TradeSkillFrame_SetSelection", Schedule)
    hooksecurefunc("TradeSkillFrame_Update", Schedule)
    TradeSkillDetailScrollFrame:HookScript("OnVerticalScroll", addon.ClipRows)
    TradeSkillDetailScrollFrame:HookScript("OnScrollRangeChanged", addon.ClipRows)
    TradeSkillFrame:HookScript("OnShow", Schedule)
    TradeSkillFrame:HookScript("OnHide", function()
        driver:SetScript("OnUpdate", nil)
        Clear()
        addon.HideDescription()
        addon.ResetWindow()
    end)
    Schedule()
end

driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("TRADE_SKILL_SHOW")
driver:RegisterEvent("TRADE_SKILL_UPDATE")
for _, event in ipairs({ "BAG_UPDATE", "ITEM_LOCK_CHANGED", "SPELL_UPDATE_COOLDOWN", "SKILL_LINES_CHANGED",
    "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
    driver:RegisterEvent(event)
end
driver:SetScript("OnEvent", function(self, event, unit)
    if string.match(event, "^UNIT_") and unit ~= "player" then return end
    Attach()
    if panel and event ~= "ADDON_LOADED" and (TradeSkillFrame:IsShown() or event == "PLAYER_REGEN_ENABLED") then Schedule() end
end)
Attach()
