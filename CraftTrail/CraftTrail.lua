local addonName, addon = ...
local driver = CreateFrame("Frame")
local panel, originalHeight, panelOffset
local widgets = {}
local needsBuild, retryTime, retries = false, 0, 0
local requested = {}
local cacheTooltip = CreateFrame("GameTooltip", "CraftTrailItemCache", UIParent, "GameTooltipTemplate")
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

function addon.ExplainCraftAvailability()
    if addon.BuildDependencyTree then
        print("CraftTrail " .. (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version") or "unknown") ..
            " - " .. (GetTradeSkillLine() or "no profession"))
        if addon.lastCraft then
            print("Last native craft: " .. addon.lastCraft.name .. " - " .. addon.lastCraft.state ..
                (addon.lastCraft.error and (": " .. addon.lastCraft.error) or ""))
        end
        for _, node in ipairs(addon.BuildDependencyTree(GetTradeSkillSelectionIndex())) do
            if node.recipe then
                local ready, reason = addon.NativeCraftState(node.recipe.spell, node.item)
                print((node.item and ((addon.componentNames or {})[node.item] or tostring(node.item)) or
                    node.recipe.name or "Recipe") .. ": " .. (ready and "ENABLED - " or "DISABLED - ") .. reason)
            end
        end
        return
    end
    local groups = addon.BuildGroups(GetTradeSkillSelectionIndex())
    local version = GetAddOnMetadata and GetAddOnMetadata(addonName, "Version") or "unknown"
    print("CraftTrail " .. version .. " Craft checks:")
    if #groups == 0 then print("Select an Inscription glyph or ink recipe first.") end
    for _, group in ipairs(groups) do
        local enabled, reason = addon.ActionState("craft", group.ink, {}, group.pigmentCount)
        print((addon.names[group.ink] or tostring(group.ink)) .. ": " ..
            (enabled and "ENABLED - " or "DISABLED - ") .. reason .. " Pigment in bags: " ..
            GetItemCount(group.pigment, false) .. "; required: " .. group.pigmentCount .. ".")
    end
end

local function ItemDetails(id)
    local name, link, _, _, _, _, _, _, _, texture = GetItemInfo(id)
    if not name and not requested[id] then
        requested[id] = true
        cacheTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        cacheTooltip:SetHyperlink("item:" .. id .. ":0:0:0:0:0:0:0")
        cacheTooltip:Hide()
    end
    local fallback = addon.names[id] or (addon.componentNames or {})[id] or ("Item " .. id)
    return link or ("|cffffffff|Hitem:" .. id .. ":0:0:0:0:0:0:0|h[" .. fallback .. "]|h|r"),
        texture or "Interface\\Icons\\INV_Misc_QuestionMark", name ~= nil
end

local function Tooltip(self)
    if not self.itemID and not self.spellID then return end
    local link = self.itemID and ItemDetails(self.itemID) or ("spell:" .. self.spellID)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
end

local function GetWidget(index, item)
    local key = (item and "item" or "label") .. index
    if widgets[key] then return widgets[key] end
    local row = CreateFrame(item and "Button" or "Frame", "CraftTrailRow" .. key, panel)
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
            local link = self.itemID and ItemDetails(self.itemID) or (self.spellID and GetSpellLink and GetSpellLink(self.spellID))
            if not link then return end
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
    local isInscription = inscription and GetTradeSkillLine() == inscription
    if not isInscription and not (addon.IsSupportedProfession and addon.IsSupportedProfession()) then
        addon.RestoreDescription(GetTradeSkillSelectionIndex())
        return false
    end
    local index = GetTradeSkillSelectionIndex()
    if GetNumTradeSkills() == 0 then return true end
    local pinned = addon.crossRoot and addon.crossRoot.view
    local descriptionMissing = not pinned and isInscription and addon.UpdateDescription(index) or false
    if pinned then addon.HideDescription()
    elseif not isInscription then addon.RestoreDescription(index) end
    local tree = addon.BuildDependencyTree and addon.BuildDependencyTree(index)
    local groups = not tree and addon.BuildGroups(index) or {}
    if (tree and #tree == 0) or (not tree and #groups == 0) then return descriptionMissing end

    local lowest = TradeSkillReagentLabel:GetBottom()
    for reagent = 1, GetTradeSkillNumReagents(index) do
        local button = _G["TradeSkillReagent" .. reagent]
        local bottom = button and button:IsShown() and button:GetBottom()
        if bottom and (not lowest or bottom < lowest) then lowest = bottom end
    end
    local child = TradeSkillDetailScrollChildFrame
    panelOffset = math.max(0, (child:GetTop() or 0) - (lowest or child:GetTop() or 0)) + 12
    if pinned then panelOffset = 76 end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", child, "TOPLEFT", 5, -panelOffset)
    panel:Show()
    local position, rowIndex, missing = 0, 0, descriptionMissing
    local stacks = addon.BagStacks()
    local function Row(text, item, action, pigmentCount, node)
        rowIndex = rowIndex + 1
        local hasLink = item or (node and node.recipe)
        local row = GetWidget(rowIndex, hasLink)
        local indent = node and math.min(node.depth, 8) * 11 or 0
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", indent, -position)
        row:SetWidth(285 - indent)
        row.used = true
        row.hasAction = action ~= nil
        row.itemID = item
        row.spellID = node and node.recipe and node.recipe.spell
        if hasLink then
            local link, texture, cached
            if item then link, texture, cached = ItemDetails(item)
            else
                local name, icon = node.recipe.name
                if row.spellID then
                    local spellName, rank, spellIcon = GetSpellInfo(row.spellID)
                    name, icon = spellName, spellIcon
                end
                link = (row.spellID and GetSpellLink and GetSpellLink(row.spellID)) or (name or "Recipe")
                texture, cached = icon or "Interface\\Icons\\INV_Misc_QuestionMark", name ~= nil
            end
            row.text:SetText((text or "") .. link)
            row.icon:SetTexture(texture)
            missing = missing or not cached
            local textWidth = node and (action and 194 or 245) or (action and 199 or 254)
            row.text:SetWidth(textWidth - indent - (node and node.alternatives > 1 and 22 or 0))
            if action then
                if not row.action then row.action = addon.CreateAction(row) end
                row.action:ClearAllPoints()
                row.action:SetPoint("RIGHT", row, "RIGHT", 0, 0)
                row.action.kind, row.action.itemID = action, item
                row.action.pigmentCount = pigmentCount
                row.action.recipeSpell = node and node.recipe and node.recipe.spell
                row.action:SetText(action == "mill" and "Mill" or "Craft")
                addon.ConfigureAction(row.action, stacks)
                row.action:Show()
            elseif row.action then
                row.action:Hide()
            end
            if node and node.alternatives > 1 and action then
                if not row.choice then
                    row.choice = CreateFrame("Button", row:GetName() .. "Choice", row, "UIPanelButtonTemplate")
                    row.choice:SetWidth(20); row.choice:SetHeight(22); row.choice:SetText(">")
                    row.choice:SetScript("OnClick", function()
                        if not InCombatLockdown() then addon.CycleRecipe(row.itemID); addon.Refresh() end
                    end)
                end
                row.choice:SetPoint("RIGHT", row.action, "LEFT", -2, 0)
                row.choice:Show()
            elseif row.choice then row.choice:Hide() end
            if node and node.depth > 0 then
                if not row.branch then
                    row.branch = row:CreateTexture(nil, "ARTWORK")
                    row.branch:SetTexture(0.65, 0.55, 0.35, 0.8)
                    row.branch:SetWidth(8); row.branch:SetHeight(1)
                    row.trunk = row:CreateTexture(nil, "ARTWORK")
                    row.trunk:SetTexture(0.65, 0.55, 0.35, 0.8); row.trunk:SetWidth(1)
                end
                row.branch:SetPoint("RIGHT", row, "LEFT", -1, 0); row.branch:Show()
            elseif row.branch then row.branch:Hide(); row.trunk:Hide() end
        else
            row.text:SetText(text)
            row:SetHeight(math.max(20, row.text:GetStringHeight() + 4))
        end
        if hasLink then row:SetHeight(math.max(26, row.text:GetStringHeight() + 8)) end
        if node then
            row:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 8,
                insets = {left = 2, right = 2, top = 2, bottom = 2}})
            row:SetBackdropColor(0.1, 0.09, 0.07, 0.95)
            row.text:ClearAllPoints(); row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 30, -6)
            row.icon:ClearAllPoints(); row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -5)
            if action then row.action:ClearAllPoints(); row.action:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -4) end
            if not row.meta then
                row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.meta:SetJustifyH("LEFT")
                row.blocker = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.blocker:SetJustifyH("LEFT")
            end
            local status = (node.isRoot and "In bags: " .. node.total or "Allocated bags: " .. node.carried .. "/" .. node.needed)
            if node.planned > 0 then status = status .. "; planned batch: " .. node.planned end
            if node.casts then status = status .. "; " .. node.casts .. " cast(s), yield " ..
                (node.recipe.min or 1) .. "-" .. (node.recipe.max or node.recipe.min or 1) end
            row.meta:SetWidth(245 - indent)
            row.meta:ClearAllPoints(); row.meta:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -4)
            row.meta:SetText(status); row.meta:Show()
            local reason = node.stopped
            if not reason and node.recipe and addon.lastCraft and addon.lastCraft.spell == node.recipe.spell then
                reason = addon.lastCraft.error and ("Last craft error: " .. addon.lastCraft.error)
            end
            if not reason and action then
                local enabled = row.action:IsEnabled()
                if not enabled or enabled == 0 then reason = row.action.reason end
            end
            if not reason and not node.recipe and not addon.herbs[node.item] then reason = "Raw material: gather, buy or obtain." end
            row.blocker:SetWidth(245 - indent)
            row.blocker:ClearAllPoints(); row.blocker:SetPoint("TOPLEFT", row.meta, "BOTTOMLEFT", 0, -4)
            row.blocker:SetText(reason or "")
            if reason then row.blocker:Show() else row.blocker:Hide() end
            row:SetHeight(math.max(30, row.text:GetStringHeight() + row.meta:GetStringHeight() +
                (reason and row.blocker:GetStringHeight() + 4 or 0) + 20))
            if row.trunk and node.depth > 0 then
                row.trunk:SetPoint("TOPRIGHT", row, "TOPLEFT", -9, 0)
                row.trunk:SetHeight(row:GetHeight()); row.trunk:Show()
            end
        else
            row:SetBackdrop(nil)
            if row.meta then row.meta:Hide(); row.blocker:Hide() end
            if hasLink then
                row.text:ClearAllPoints(); row.text:SetPoint("LEFT", row, "LEFT", 27, 0)
                row.icon:ClearAllPoints(); row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
            end
        end
        row:Show()
        position = position + row:GetHeight() + (node and 5 or 0)
        if not node and hasLink and (action == "craft" or action == "recipe") then
            local enabled = row.action:IsEnabled()
            if not enabled or enabled == 0 then
                Row("Craft unavailable: " .. (row.action.reason or "Unknown reason."))
            end
        end
        return row
    end
    if tree then
        local heading = Row(addon.crossRoot and "CraftTrail - original recipe" or "CraftTrail - dependency tree (one cast)")
        if addon.crossRoot then
            if not heading.back then
                heading.back = CreateFrame("Button", nil, heading, "SecureActionButtonTemplate,UIPanelButtonTemplate")
                heading.back:SetWidth(96); heading.back:SetHeight(20)
                heading.back:SetPoint("RIGHT", heading, "RIGHT", 0, 0)
                heading.back:RegisterForClicks("LeftButtonUp")
                heading.back:SetScript("PreClick", function(self)
                    if InCombatLockdown() then return end
                    local macro = addon.ReturnProfessionMacro()
                    self:SetAttribute("type", macro and "macro" or nil)
                    self:SetAttribute("macrotext", macro)
                end)
            end
            heading.back:SetText("Back to recipe")
            local backMacro = addon.ReturnProfessionMacro()
            heading.back:SetAttribute("type", backMacro and "macro" or nil)
            heading.back:SetAttribute("macrotext", backMacro)
            if backMacro then heading.back:Enable() else heading.back:Disable() end
            heading.back:Show()
        elseif heading.back then heading.back:Hide() end
        for _, node in ipairs(tree) do
            Row(node.needed .. "x ", node.item, node.recipe and "recipe" or nil, nil, node)
            if node.item and addon.herbs[node.item] then
                Row("Mill any ONE herb below (5 per milling):")
                for _, herb in ipairs(addon.herbs[node.item]) do Row(nil, herb, "mill") end
            end
        end
    else
      Row("CraftTrail - ink > pigment > herbs")
      for _, group in ipairs(groups) do
        Row(group.amount .. "x ", group.ink, "craft", group.pigmentCount)
        Row((group.amount * group.pigmentCount) .. "x pigment: ", group.pigment)
        Row("Mill any ONE herb below (5 per milling):")
        for _, herb in ipairs(group.herbs) do Row(nil, herb, "mill") end
        position = position + 6
      end
      Row("Milling yields vary. Hover for item/bank info.")
    end
    panel:SetHeight(position)
    ResizeDetails()
    addon.ClipRows()
    if addon.ApplyProfessionView then addon.ApplyProfessionView() end
    return missing or (addon.recipeCatalog and addon.recipeCatalog.incomplete)
end

local function Tick(self, elapsed)
    retryTime = retryTime + elapsed
    if not needsBuild and retryTime < 0.5 then return end
    retryTime = 0
    local fresh = needsBuild
    needsBuild = false
    if addon.RestoreRecipeSelection then addon.RestoreRecipeSelection() end
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
    panel = CreateFrame("Frame", "CraftTrailDetails", TradeSkillDetailScrollChildFrame)
    panel:SetFrameLevel(TradeSkillDetailScrollChildFrame:GetFrameLevel() + 1)
    panel:SetWidth(289)
    panel:Hide()
    local function NativeUpdated()
        if addon.ApplyProfessionView then addon.ApplyProfessionView() end
        Schedule()
    end
    hooksecurefunc("TradeSkillFrame_SetSelection", NativeUpdated)
    hooksecurefunc("TradeSkillFrame_Update", NativeUpdated)
    TradeSkillDetailScrollFrame:HookScript("OnVerticalScroll", addon.ClipRows)
    TradeSkillDetailScrollFrame:HookScript("OnScrollRangeChanged", addon.ClipRows)
    TradeSkillFrame:HookScript("OnShow", NativeUpdated)
    TradeSkillFrame:HookScript("OnHide", function()
        if not addon.crossSwitch then
            addon.crossRoot = nil
            if addon.ReleaseProfessionView then addon.ReleaseProfessionView() end
        end
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
driver:RegisterEvent("UI_ERROR_MESSAGE")
driver:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
for _, event in ipairs({ "BAG_UPDATE", "ITEM_LOCK_CHANGED", "SPELL_UPDATE_COOLDOWN", "SKILL_LINES_CHANGED",
    "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
    driver:RegisterEvent(event)
end
driver:SetScript("OnEvent", function(self, event, unit, detail)
    if string.match(event, "^UNIT_") and unit ~= "player" then return end
    if addon.lastCraft then
        if event == "UI_ERROR_MESSAGE" and GetTime() - addon.lastCraft.time < 3 then
            addon.lastCraft.error = type(detail) == "string" and detail or (type(unit) == "string" and unit or nil)
            addon.lastCraft.state = "rejected"
        elseif detail == addon.lastCraft.name then
            if event == "UNIT_SPELLCAST_START" then addon.lastCraft.state = "started"
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then addon.lastCraft.state = "succeeded"
            elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then addon.lastCraft.state = "failed" end
        end
    end
    if addon.RecipeCatalog and (event == "TRADE_SKILL_SHOW" or event == "SPELLS_CHANGED" or
        event == "SKILL_LINES_CHANGED" or event == "BAG_UPDATE" or event == "ITEM_LOCK_CHANGED" or
        event == "SPELL_UPDATE_COOLDOWN" or event == "UNIT_SPELLCAST_STOP") then addon.recipeCatalog = nil end
    Attach()
    if panel and event ~= "ADDON_LOADED" and (TradeSkillFrame:IsShown() or event == "PLAYER_REGEN_ENABLED") then Schedule() end
end)
Attach()
