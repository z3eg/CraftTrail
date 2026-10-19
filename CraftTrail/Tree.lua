local addonName, addon = ...
local professions = {
    [129] = {3273, "First Aid"}, [164] = {2018, "Blacksmithing"}, [165] = {2108, "Leatherworking"},
    [171] = {2259, "Alchemy"}, [185] = {2550, "Cooking"}, [186] = {2656, "Smelting"},
    [197] = {3908, "Tailoring"}, [202] = {4036, "Engineering"}, [333] = {7411, "Enchanting"},
    [755] = {25229, "Jewelcrafting"}, [773] = {45357, "Inscription"}
}
addon.recipeChoices = {}
function addon.ProfessionSpell(skill) return professions[skill] and professions[skill][1] end

function addon.ProfessionName(skill)
    local profession = professions[skill]
    return profession and (GetSpellInfo(profession[1]) or profession[2]) or "another profession"
end

function addon.OpenProfession()
    local name = GetTradeSkillLine()
    for skill, profession in pairs(professions) do
        if name == GetSpellInfo(profession[1]) or name == profession[2] or
            (skill == 186 and (name == "Mining" or name == GetSpellInfo(2575))) then
            return skill
        end
    end
end

function addon.IsSupportedProfession() return addon.OpenProfession() ~= nil end

function addon.ComponentOptions(item)
    local catalog = addon.RecipeCatalog()
    local choices, seen = {}, {}
    for _, recipe in ipairs(catalog.byItem[item] or {}) do
        recipe.skill = addon.OpenProfession()
        choices[#choices + 1], seen[recipe.spell or recipe.name] = recipe, true
    end
    for _, recipe in ipairs((addon.componentRecipes or {})[item] or {}) do
        if not seen[recipe.spell] then choices[#choices + 1] = recipe; seen[recipe.spell] = true end
    end
    table.sort(choices, function(a, b)
        local knownA = a.spell and catalog.bySpell[a.spell] ~= nil
        local knownB = b.spell and catalog.bySpell[b.spell] ~= nil
        if knownA ~= knownB then return knownA end
        local sameA, sameB = a.skill == addon.OpenProfession(), b.skill == addon.OpenProfession()
        if sameA ~= sameB then return sameA end
        return (a.spell or 0) < (b.spell or 0)
    end)
    return choices
end

function addon.CycleRecipe(item)
    local choices = addon.ComponentOptions(item)
    for index, recipe in ipairs(choices) do
        if recipe.spell == addon.recipeChoices[item] then
            addon.recipeChoices[item] = choices[index % #choices + 1].spell
            return
        end
    end
    addon.recipeChoices[item] = choices[2] and choices[2].spell or nil
end

function addon.BuildDependencyTree(index)
    local rootRecipe = addon.crossRoot and addon.crossRoot.recipe or addon.ReadRecipe(index)
    if not rootRecipe then return {} end
    local rows, bags, surplus, path = {}, {}, {}, {}
    local function Add(item, needed, depth, forced, isRoot)
        if #rows >= 160 then return end
        local choices = item and addon.ComponentOptions(item) or {}
        local recipe = forced or choices[1]
        if item and addon.recipeChoices[item] and not forced then
            for _, candidate in ipairs(choices) do
                if candidate.spell == addon.recipeChoices[item] then recipe = candidate; break end
            end
        end
        local total = item and GetItemCount(item, false) or 0
        if item and bags[item] == nil then bags[item] = total end
        local carried = not isRoot and item and math.min(needed, bags[item]) or 0
        if item then bags[item] = bags[item] - carried end
        local planned = not isRoot and item and math.min(needed - carried, surplus[item] or 0) or 0
        if item then surplus[item] = (surplus[item] or 0) - planned end
        local shortage = math.max(0, needed - carried - planned)
        local node = {item = item, needed = needed, carried = carried, total = total, planned = planned,
            depth = depth, recipe = recipe, alternatives = isRoot and 0 or #choices, isRoot = isRoot}
        rows[#rows + 1] = node
        if recipe and shortage > 0 then
            local key = recipe.spell or item or recipe.name
            if path[key] then node.stopped = "Recipe cycle stopped."; return end
            if depth >= 8 then node.stopped = "Expand limit reached (8 levels)."; return end
            local yield = math.max(1, recipe.min or 1)
            node.casts = math.ceil(shortage / yield)
            if item then surplus[item] = (surplus[item] or 0) + node.casts * yield - shortage end
            path[key] = true
            for _, reagent in ipairs(recipe.reagents) do Add(reagent[1], reagent[2] * node.casts, depth + 1) end
            path[key] = nil
        end
    end
    Add(rootRecipe.item, math.max(1, rootRecipe.min or 1), 0, rootRecipe, true)
    if #rows >= 160 then rows[#rows].stopped = "Tree limited to 160 nodes." end
    return rows
end
