local addonName, addon = ...

local function True(value)
    return value == true or value == 1
end

local function KnowsSpell(id)
    if True(IsSpellKnown(id)) then return true end
    local wanted = GetSpellInfo(id)
    if not wanted or not GetNumSpellTabs or not GetSpellName then return false end
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, count = GetSpellTabInfo(tab)
        for index = offset + 1, offset + count do
            if GetSpellName(index, BOOKTYPE_SPELL or "spell") == wanted then return true end
        end
    end
    return false
end
addon.KnowsSpell = KnowsSpell

local function Blocked()
    if InCombatLockdown() then return "Unavailable in combat." end
    if True(IsTradeSkillLinked()) then return "Open your own profession." end
    if True(UnitIsDeadOrGhost("player")) then return "Unavailable while dead." end
    if UnitCastingInfo("player") or UnitChannelInfo("player") then return "Finish the current cast first." end
end

local function SpellReady(id)
    if not KnowsSpell(id) then return false, "This character has not learned this recipe or spell." end
    local start, duration, enabled = GetSpellCooldown(id)
    if enabled == 0 or (start and duration and start + duration > GetTime()) then
        return false, "Spell is on cooldown."
    end
    return true
end

local function InkRecipeIndex(itemID)
    -- Learned profession recipes are not necessarily exposed as spellbook spells.
    -- Read the current list without changing the user's class/search filters.
    for index = 1, GetNumTradeSkills() do
        local _, kind = GetTradeSkillInfo(index)
        if kind and kind ~= "header" and addon.ItemID(GetTradeSkillItemLink(index)) == itemID then
            return index
        end
    end
end

function addon.BagStacks()
    local stacks = {}
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local id = addon.ItemID(GetContainerItemLink(bag, slot))
            local _, count, locked = GetContainerItemInfo(bag, slot)
            if id and not True(locked) and count and count >= 5 and not stacks[id] then
                stacks[id] = { bag = bag, slot = slot }
            end
        end
    end
    return stacks
end

function addon.ActionState(kind, id, stacks, pigmentCount, recipeSpell)
    local reason = Blocked()
    if reason then return false, reason end
    if addon.NativeCraftState and (kind == "craft" or kind == "recipe") then
        local spell = recipeSpell or (addon.inks[id] and addon.inks[id].spell)
        local ready, why = addon.NativeCraftState(spell, id)
        if ready and addon.CrossCraftMacro then
            local macro = addon.CrossCraftMacro(spell, id)
            if macro then return true, why, macro end
        end
        return ready, why, ready and ("/run CraftTrail_Craft(" .. (spell or 0) .. "," .. (id or 0) .. ")") or nil
    end
    if kind == "craft" then
        local recipe = addon.inks[id]
        local index = InkRecipeIndex(id)
        -- A filtered-out profession recipe is not proof it is unlearned.
        -- Let the normal hardware-click cast validate knowledge instead of
        -- permanently disabling the button on unreliable spellbook APIs.
        -- Generic IsUsableSpell/its enabled cooldown flag can reject profession
        -- recipes even with reagents available. Validate bag reagents directly;
        -- the normal cast still enforces learned recipe, tools and requirements.
        local start, duration = GetSpellCooldown(recipe.spell)
        if start and duration and duration > 0 and start + duration > GetTime() then
            return false, "Spell is on cooldown."
        end
        if GetItemCount(recipe.pigment, false) < (pigmentCount or recipe.count) then
            return false, "Not enough pigment in your bags for one ink cast."
        end
        if index then
            for reagent = 1, GetTradeSkillNumReagents(index) do
                local item = addon.ItemID(GetTradeSkillReagentItemLink(index, reagent))
                local _, _, count = GetTradeSkillReagentInfo(index, reagent)
                if not item or not count then return false, "Recipe reagents are not loaded yet." end
                if GetItemCount(item, false) < count then return false, "Not enough recipe reagents in your bags." end
            end
            if GetTradeSkillTools then
                local tools = { GetTradeSkillTools(index) }
                for tool = 1, #tools, 2 do
                    if tools[tool] and not True(tools[tool + 1]) then return false, "Missing required crafting tool." end
                end
            end
        end
        local spell = GetSpellInfo(recipe.spell)
        if not spell then return false, "Recipe is not loaded yet." end
        local hint = index and "Craft one ink." or
            "Craft one ink. Recipe hidden by filters; the game will validate learned recipe and tools."
        return true, hint, "/cast [nocombat] " .. spell
    end
    local ready, why = SpellReady(51005)
    if not ready then return false, why end
    local _, skill = GetTradeSkillLine()
    if (skill or 0) < (addon.herbSkill[id] or math.huge) then
        return false, "Inscription skill is too low to mill this herb."
    end
    local stack = stacks[id]
    if not stack then return false, "Need at least 5 of this herb in one unlocked bag stack." end
    local spell = GetSpellInfo(51005)
    if not spell then return false, "Milling is not loaded yet." end
    return true, "Mill five herbs, once.", "/cast [nocombat] " .. spell ..
        "\n/use [nocombat] " .. stack.bag .. " " .. stack.slot
end

function addon.ConfigureAction(button, stacks)
    if InCombatLockdown() then return end
    local enabled, reason, macro = addon.ActionState(button.kind, button.itemID, stacks, button.pigmentCount, button.recipeSpell)
    button.reason = reason
    button:SetAttribute("type", enabled and "macro" or nil)
    button:SetAttribute("macrotext", macro)
    if enabled then button:Enable() else button:Disable() end
end

function addon.CreateAction(row)
    local button = CreateFrame("Button", row:GetName() .. "Action", row, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    button:GetFontString():Hide()
    local label = button:CreateFontString(button:GetName() .. "Label", "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    button:SetFontString(label)
    button:SetNormalFontObject(GameFontNormal)
    button:SetHighlightFontObject(GameFontHighlight)
    button:SetDisabledFontObject(GameFontDisable)
    button:SetWidth(52)
    button:SetHeight(22)
    button:ClearAllPoints()
    button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    button:SetFrameLevel(row:GetFrameLevel() + 1)
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("PreClick", function(self)
        -- Revalidate slot identity and requirements on the hardware click, before the secure macro.
        if not InCombatLockdown() then addon.ConfigureAction(self, addon.BagStacks()) end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.reason or "")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    return button
end
