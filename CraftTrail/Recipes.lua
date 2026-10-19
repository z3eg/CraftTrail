local addonName, addon = ...
local busy, restoreSelection

local function Flag(value) return value == true or value == 1 end
local function ActivityReason()
    if InCombatLockdown() then return "Unavailable in combat." end
    if Flag(IsTradeSkillLinked()) then return "Open your own profession." end
    if Flag(UnitIsDeadOrGhost("player")) then return "Unavailable while dead." end
    if UnitCastingInfo("player") or UnitChannelInfo("player") then return "Finish the current cast first." end
end
local function Item(link) return link and tonumber(string.match(link, "item:(%d+)")) end
local function Spell(link) return link and tonumber(string.match(link, "[a-z]+:(%d+)")) end

function addon.ReadRecipe(index)
    local name, kind = GetTradeSkillInfo(index)
    if not name or kind == "header" then return end
    local item = Item(GetTradeSkillItemLink(index))
    local spell = GetTradeSkillRecipeLink and Spell(GetTradeSkillRecipeLink(index))
    if not spell and item and addon.inks[item] then spell = addon.inks[item].spell end
    if not spell and item and addon.componentRecipes then
        for _, candidate in ipairs(addon.componentRecipes[item] or {}) do
            if GetSpellInfo(candidate.spell) == name then spell = candidate.spell; break end
        end
    end
    local low, high = 1, 1
    if GetTradeSkillNumMade then low, high = GetTradeSkillNumMade(index) end
    local recipe = { spell = spell, item = item, name = name, min = math.max(1, low or 1), max = math.max(1, high or low or 1),
        reagents = {}, tools = GetTradeSkillTools and {GetTradeSkillTools(index)} or {} }
    recipe.cooldown = GetTradeSkillCooldown and GetTradeSkillCooldown(index) or 0
    recipe.cooldownEnds = GetTime() + (recipe.cooldown or 0)
    for n = 1, GetTradeSkillNumReagents(index) do
        local _, _, count = GetTradeSkillReagentInfo(index, n)
        local reagent = Item(GetTradeSkillReagentItemLink(index, n))
        if not reagent or not count then recipe.loading = true
        else recipe.reagents[#recipe.reagents + 1] = {reagent, count} end
    end
    return recipe
end

local function Identity(index)
    local recipe = index and addon.ReadRecipe(index)
    return recipe and {spell = recipe.spell, item = recipe.item, name = recipe.name, line = GetTradeSkillLine()}
end

local function Find(identity)
    if not identity then return end
    for index = 1, GetNumTradeSkills() do
        local recipe = addon.ReadRecipe(index)
        if recipe and ((identity.spell and recipe.spell == identity.spell) or
            (not identity.spell and identity.item and recipe.item == identity.item) or
            (not identity.spell and not identity.item and recipe.name == identity.name)) then return index, recipe end
    end
end

local function RestoreSelected(identity)
    if identity and identity.line and identity.line ~= GetTradeSkillLine() then return end
    local index = Find(identity)
    if index then
        if SelectTradeSkill then SelectTradeSkill(index) end
        if TradeSkillFrame then TradeSkillFrame.selectedSkill = index end
    end
end

function addon.RestoreRecipeSelection()
    if restoreSelection then
        local saved = restoreSelection
        restoreSelection = nil
        if saved.line and saved.line ~= GetTradeSkillLine() then return end
        RestoreSelected(saved)
        if TradeSkillFrame_SetSelection then
            local index = Find(saved)
            if index then TradeSkillFrame_SetSelection(index) end
        end
    end
end

-- Temporary filter changes happen only while resolving the full learned list or
-- on the hardware click. Recipe indices are never reused after filter changes.
function addon.WithAllRecipes(callback)
    if busy then return end
    busy = true
    local selected = Identity(GetTradeSkillSelectionIndex())
    -- Snapshot UI state before any filter setter can dispatch UI updates.
    local search = TradeSkillFrameEditBox and TradeSkillFrameEditBox:GetText() or ""
    if search == SEARCH then search = "" end
    local makeable = TradeSkillFrameAvailableFilterCheckButton and
        TradeSkillFrameAvailableFilterCheckButton:GetChecked()
    local headers = {}
    local function RememberHeaders()
        for n = 1, GetNumTradeSkills() do
            local name, kind, _, expanded = GetTradeSkillInfo(n)
            if kind == "header" and headers[name] == nil then headers[name] = Flag(expanded) end
        end
    end
    RememberHeaders()
    local function RestoreHeaders()
        local n = 1
        while n <= GetNumTradeSkills() do
            local name, kind, _, expanded = GetTradeSkillInfo(n)
            if kind == "header" and headers[name] ~= nil then
                if headers[name] and not Flag(expanded) and ExpandTradeSkillSubClass then
                    ExpandTradeSkillSubClass(n)
                elseif not headers[name] and Flag(expanded) and CollapseTradeSkillSubClass then
                    CollapseTradeSkillSubClass(n)
                end
            end
            n = n + 1
        end
    end
    local filters = {}
    for _, group in ipairs({{"SubClass", "GetTradeSkillSubClasses"}, {"InvSlot", "GetTradeSkillInvSlots"}}) do
        local get, set, list = _G["GetTradeSkill" .. group[1] .. "Filter"],
            _G["SetTradeSkill" .. group[1] .. "Filter"], _G[group[2]]
        if get and set and list then
            local saved = {get = get, set = set, all = Flag(get(0)), enabled = {}}
            local hasOptions, hasSelection = false, false
            for n, name in ipairs({list()}) do
                if name then
                    hasOptions = true
                    saved.enabled[n] = Flag(get(n))
                    hasSelection = hasSelection or saved.enabled[n]
                end
            end
            -- Smelting may expose neither options nor a checked All flag.
            -- Restoring that as SetFilter(0, 0, 1) excludes every recipe.
            if hasOptions then
                saved.all = saved.all or not hasSelection
                filters[#filters + 1] = saved
            end
        end
    end
    for _, saved in ipairs(filters) do saved.set(0, 1, 1) end
    if SetTradeSkillItemNameFilter then SetTradeSkillItemNameFilter("") end
    if SetTradeSkillItemLevelFilter then SetTradeSkillItemLevelFilter(0, 0) end
    if TradeSkillOnlyShowMakeable then TradeSkillOnlyShowMakeable(false) end
    RememberHeaders() -- Also retain categories hidden by the original filters.
    if ExpandTradeSkillSubClass then ExpandTradeSkillSubClass(0) end
    local ok, result, extra = pcall(callback)
    RestoreHeaders() -- Include categories that will be hidden again by filters.
    for _, saved in ipairs(filters) do
        saved.set(0, saved.all and 1 or 0, 1)
        if not saved.all then
            for n, enabled in ipairs(saved.enabled) do if enabled then saved.set(n, 1, 0) end end
        end
    end
    if TradeSkillOnlyShowMakeable then TradeSkillOnlyShowMakeable(Flag(makeable)) end
    -- Stock 3.3.5 uses this handler (there is no TradeSkillFrame_SetFilter).
    -- It also restores numeric/~level searches, not just item-name searches.
    if TradeSkillFilter_OnTextChanged then
        TradeSkillFilter_OnTextChanged({GetText = function() return search end})
    elseif TradeSkillFrame_SetFilter then TradeSkillFrame_SetFilter(search)
    elseif SetTradeSkillItemNameFilter then SetTradeSkillItemNameFilter(search) end
    -- Filter setters can rebuild/reset category expansion. Restore AFTER them,
    -- never before; otherwise every scan or craft can collapse the user's list.
    RestoreHeaders()
    RestoreSelected(selected)
    restoreSelection = selected -- The stock filter-event handler may reset selection later this frame.
    busy = false
    if not ok then return nil, tostring(result) end
    return result, extra
end

function addon.ShowAllRecipes()
    if InCombatLockdown() or not TradeSkillFrame or not TradeSkillFrame:IsShown() then return end
    restoreSelection = nil
    SetTradeSkillSubClassFilter(0, 1, 1)
    SetTradeSkillInvSlotFilter(0, 1, 1)
    if TradeSkillFrameEditBox then TradeSkillFrameEditBox:SetText("") end
    SetTradeSkillItemNameFilter("")
    SetTradeSkillItemLevelFilter(0, 0)
    if TradeSkillFrameAvailableFilterCheckButton then TradeSkillFrameAvailableFilterCheckButton:SetChecked(false) end
    TradeSkillOnlyShowMakeable(false)
    ExpandTradeSkillSubClass(0)
    if UIDropDownMenu_SetSelectedID then
        UIDropDownMenu_SetSelectedID(TradeSkillSubClassDropDown, 1)
        UIDropDownMenu_SetSelectedID(TradeSkillInvSlotDropDown, 1)
    end
    if UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(TradeSkillSubClassDropDown, ALL_SUBCLASSES)
        UIDropDownMenu_SetText(TradeSkillInvSlotDropDown, ALL_INVENTORY_SLOTS)
    end
    if FauxScrollFrame_SetOffset then FauxScrollFrame_SetOffset(TradeSkillListScrollFrame, 0) end
    addon.recipeCatalog = nil
    if TradeSkillFrame_Update then TradeSkillFrame_Update() end
end

function addon.RecipeCatalog(force)
    local line = GetTradeSkillLine()
    if not force and addon.recipeCatalog and addon.recipeCatalog.line == line and
        (not addon.recipeCatalog.incomplete or GetTime() < addon.recipeCatalog.retryAt) then return addon.recipeCatalog end
    local catalog = {line = line, byItem = {}, bySpell = {}, retryAt = GetTime() + 1}
    if Flag(IsTradeSkillLinked()) then return catalog end
    addon.WithAllRecipes(function()
        for index = 1, GetNumTradeSkills() do
            local recipe = addon.ReadRecipe(index)
            if recipe then
                catalog.incomplete = catalog.incomplete or recipe.loading
                if recipe.spell then catalog.bySpell[recipe.spell] = recipe end
                if recipe.item then
                    catalog.byItem[recipe.item] = catalog.byItem[recipe.item] or {}
                    table.insert(catalog.byItem[recipe.item], recipe)
                end
            end
        end
    end)
    addon.recipeCatalog = catalog
    return catalog
end

function addon.NativeCraftState(spell, item)
    local activity = ActivityReason()
    if activity then return false, activity end
    local catalog = addon.RecipeCatalog()
    local recipe = spell and catalog.bySpell[spell] or (catalog.byItem[item] or {})[1]
    if not recipe then
        for _, candidate in ipairs((addon.componentRecipes or {})[item] or {}) do
            if candidate.spell == spell and addon.OpenProfession and candidate.skill ~= addon.OpenProfession() then
                return false, "Open " .. addon.ProfessionName(candidate.skill) .. " to craft this component."
            end
        end
        return false, "Recipe not learned in the open profession."
    end
    if recipe.loading then return false, "Recipe data is loading." end
    if (recipe.cooldownEnds or 0) > GetTime() then return false, "Recipe is on cooldown." end
    for _, reagent in ipairs(recipe.reagents) do
        if GetItemCount(reagent[1], false) < reagent[2] then return false, "Not enough " ..
            (addon.names[reagent[1]] or (addon.componentNames or {})[reagent[1]] or ("item " .. reagent[1])) .. " in bags." end
    end
    for n = 1, #recipe.tools, 2 do
        if recipe.tools[n] and not Flag(recipe.tools[n + 1]) then return false, "Missing tool: " .. recipe.tools[n] end
    end
    return true, "Craft one cast using the profession's native Create action."
end

function addon.NativeCraft(spell, item)
    local activity = ActivityReason()
    if activity then print("CraftTrail: " .. activity); return false end
    addon.RecipeCatalog(true)
    local ready, reason = addon.NativeCraftState(spell, item)
    if not ready then print("CraftTrail: " .. reason); return false end
    local request
    local result, why = addon.WithAllRecipes(function()
        local index, recipe = Find({spell = spell, item = item})
        if not index then return false, "Recipe changed; click again after refreshing." end
        -- Re-read cooldown/tools and exact recipe identity immediately before the cast.
        local catalog = addon.recipeCatalog
        if recipe.spell then catalog.bySpell[recipe.spell] = recipe end
        if recipe.item then catalog.byItem[recipe.item] = {recipe} end
        local allowed, blocked = addon.NativeCraftState(spell, item)
        if not allowed then return false, blocked end
        request = {spell = recipe.spell, name = recipe.name, time = GetTime(), state = "requested"}
        addon.lastCraft = request
        DoTradeSkill(index, 1)
        return true
    end)
    if not result then
        if request then request.state = "failed"; request.error = why or "Native craft request failed." end
        print("CraftTrail: " .. (why or "Could not resolve recipe."))
    end
    return result
end

-- Called only by the secure action button's /run macro on a user click.
CraftTrail_Craft = function(spell, item) return addon.NativeCraft(spell ~= 0 and spell or nil, item ~= 0 and item or nil) end
