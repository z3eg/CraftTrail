local addonName, addon = ...
local scanner, field, measure
local spellNames = {}

local function Plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"))
end

local function Names(playerClass)
    if spellNames[playerClass] then return spellNames[playerClass] end
    local result, seen = {}, {}
    for _, id in ipairs(addon.classSpells[playerClass] or {}) do
        local name = GetSpellInfo(id)
        if name and #name >= 3 and not seen[name] then
            seen[name] = true
            result[#result + 1] = { name = name, lower = string.lower(name), id = id }
        end
    end
    spellNames[playerClass] = result
    return result
end

local function Word(character)
    return character ~= "" and string.find(character, "[%w_\128-\255]") ~= nil
end

function addon.LinkDescription(item, text)
    local playerClass = addon.glyphClasses[item]
    if not playerClass then return text end
    local candidates, output, position = Names(playerClass), {}, 1
    local lower = string.lower(text)
    while position <= #text do
        local first, last, chosen
        for _, candidate in ipairs(candidates) do
            local start, finish = string.find(lower, candidate.lower, position, true)
            while start and (Word(string.sub(text, start - 1, start - 1)) or Word(string.sub(text, finish + 1, finish + 1))) do
                start, finish = string.find(lower, candidate.lower, finish + 1, true)
            end
            if start and (not first or start < first or (start == first and finish > last)) then
                first, last, chosen = start, finish, candidate
            end
        end
        if not first then output[#output + 1] = string.sub(text, position); break end
        output[#output + 1] = string.sub(text, position, first - 1)
        output[#output + 1] = "|cff71d5ff|Hspell:" .. chosen.id .. "|h" .. string.sub(text, first, last) .. "|h|r"
        position = last + 1
    end
    return table.concat(output)
end

function addon.ReadGlyphDescription(index)
    if not scanner then scanner = CreateFrame("GameTooltip", "InkTrailDescriptionScan", UIParent, "GameTooltipTemplate") end
    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    scanner:ClearLines()
    scanner:SetTradeSkillItem(index)
    local format = ITEM_SPELL_TRIGGER_ONUSE or "Use:"
    local placeholder = string.find(format, "%s", 1, true)
    local prefix = placeholder and string.sub(format, 1, placeholder - 1) or format
    prefix = prefix:gsub("%s+$", "")
    local result = {}
    for line = 2, scanner:NumLines() do
        local region = _G[scanner:GetName() .. "TextLeft" .. line]
        local text = region and region:GetText()
        if text then
            text = Plain(text)
            if string.sub(text, 1, #prefix) == prefix then
                result[#result + 1] = (string.sub(text, #prefix + 1):gsub("^%s+", ""))
            end
        end
    end
    scanner:Hide()
    return #result > 0 and table.concat(result, "\n") or nil
end

local function SpellLink(link)
    return type(link) == "string" and string.match(link, "^spell:(%d+)$")
end

function addon.HideDescription()
    if field then field:Hide() end
end

function addon.RestoreDescription(index)
    addon.HideDescription()
    local _, kind
    if index and index > 0 then _, kind = GetTradeSkillInfo(index) end
    if kind and kind ~= "header" then
        local text = GetTradeSkillDescription(index)
        TradeSkillDescription:SetText(text or " ")
        TradeSkillDescription:SetHeight(0)
        TradeSkillReagentLabel:ClearAllPoints()
        TradeSkillReagentLabel:SetPoint("TOPLEFT", TradeSkillDescription, text and "BOTTOMLEFT" or "TOPLEFT", 0, text and -10 or 0)
    end
end

function addon.UpdateDescription(index)
    if InCombatLockdown() then return false end
    local _, kind
    if index and index > 0 then _, kind = GetTradeSkillInfo(index) end
    if not kind or kind == "header" then addon.HideDescription(); return false end
    local item = index and index > 0 and addon.ItemID(GetTradeSkillItemLink(index))
    if not item or not addon.glyphLevels[item] then
        addon.RestoreDescription(index)
        return false
    end
    if not field then
        field = CreateFrame("SimpleHTML", "InkTrailGlyphDescription", TradeSkillDetailScrollChildFrame)
        field:SetWidth(285)
        field:SetFontObject(GameFontHighlightSmall)
        field:SetPoint("TOPLEFT", TradeSkillDescription, "TOPLEFT", 0, 0)
        field:SetHyperlinksEnabled(true)
        field:SetScript("OnHyperlinkEnter", function(self, link)
            if not SpellLink(link) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
        end)
        field:SetScript("OnHyperlinkLeave", function(self)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        field:SetScript("OnHyperlinkClick", function(self, link, text, button)
            local id = SpellLink(link)
            if not id then return end
            local full = GetSpellLink(tonumber(id)) or ("|cff71d5ff|H" .. link .. "|h[" .. text .. "]|h|r")
            if not HandleModifiedItemClick(full) then SetItemRef(link, full, button or "LeftButton") end
        end)
        measure = field:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        measure:SetWidth(285)
        measure:Hide()
    end
    local description = addon.ReadGlyphDescription(index)
    local text = description or "Loading glyph description..."
    measure:SetText(text)
    field:SetHeight(math.max(16, measure:GetStringHeight() + 6))
    field:SetText(addon.LinkDescription(item, text))
    field:Show()
    TradeSkillDescription:SetText(" ")
    TradeSkillReagentLabel:ClearAllPoints()
    TradeSkillReagentLabel:SetPoint("TOPLEFT", field, "BOTTOMLEFT", 0, -10)
    return description == nil
end
