local addonName, addon = ...
local native, dragBar

local function SavePoints(frame)
    local points = {}
    if frame then
        for index = 1, frame:GetNumPoints() do points[index] = { frame:GetPoint(index) } end
    end
    return points
end

local function RestorePoints(frame, points)
    if not frame then return end
    frame:ClearAllPoints()
    for _, point in ipairs(points) do frame:SetPoint(unpack(point)) end
end

local function IsInscription()
    return GetTradeSkillLine() == GetSpellInfo(45357)
end

function addon.WindowSettings()
    if type(InkTrailDB) ~= "table" then InkTrailDB = {} end
    return InkTrailDB
end

function addon.ResetWindow()
    if not native or InCombatLockdown() then return end
    TradeSkillFrame:SetHeight(native.height)
    TradeSkillDetailScrollFrame:SetHeight(native.details)
    RestorePoints(TradeSkillCreateButton, native.create)
    RestorePoints(TradeSkillCancelButton, native.cancel)
    dragBar:Hide()
    native.background:Hide()
    addon.HideCastBar()
end

function addon.UpdateWindow()
    if InCombatLockdown() or not TradeSkillFrame then return end
    if not native then
        native = { height = TradeSkillFrame:GetHeight(), details = TradeSkillDetailScrollFrame:GetHeight(),
            create = SavePoints(TradeSkillCreateButton), cancel = SavePoints(TradeSkillCancelButton) }
        local background = CreateFrame("Frame", nil, TradeSkillFrame)
        background:SetFrameLevel(TradeSkillFrame:GetFrameLevel())
        background:SetPoint("TOPLEFT", TradeSkillFrame, "TOPLEFT", 16, -190)
        background:SetPoint("BOTTOMRIGHT", TradeSkillFrame, "BOTTOMRIGHT", -42, 82)
        background:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        background:SetBackdropColor(0.07, 0.05, 0.03, 1)
        native.background = background
        dragBar = CreateFrame("Frame", nil, TradeSkillFrame)
        dragBar:SetWidth(220)
        dragBar:SetHeight(28)
        dragBar:SetPoint("TOPLEFT", TradeSkillFrame, "TOPLEFT", 70, -5)
        dragBar:EnableMouse(true)
        dragBar:RegisterForDrag("LeftButton")
        dragBar:SetScript("OnDragStart", function()
            if not InCombatLockdown() then TradeSkillFrame:StartMoving() end
        end)
        dragBar:SetScript("OnDragStop", function()
            if InCombatLockdown() then return end
            TradeSkillFrame:StopMovingOrSizing()
            local left, top = TradeSkillFrame:GetLeft(), TradeSkillFrame:GetTop()
            if left and top then
                addon.WindowSettings().position = { x = left, y = top - UIParent:GetHeight() }
                TradeSkillFrame:SetUserPlaced(true)
            end
        end)
        TradeSkillFrame:SetMovable(true)
        TradeSkillFrame:SetClampedToScreen(true)
    end
    if not IsInscription() then addon.ResetWindow(); return end
    local settings = addon.WindowSettings()
    local position = settings.position
    if type(position) == "table" and type(position.x) == "number" and type(position.y) == "number" then
        TradeSkillFrame:ClearAllPoints()
        TradeSkillFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", position.x, position.y)
    end
    local height = native.height
    if settings.tall ~= false then
        height = math.max(native.height, math.min(native.height * 1.5, (TradeSkillFrame:GetTop() or UIParent:GetHeight()) - 20))
    end
    TradeSkillFrame:SetHeight(height)
    TradeSkillDetailScrollFrame:SetHeight(native.details + height - native.height - 24)
    addon.ShowCastBar()
    -- The remaining count/Create All controls already anchor to these two buttons.
    if TradeSkillCreateButton then
        TradeSkillCreateButton:ClearAllPoints()
        TradeSkillCreateButton:SetPoint("CENTER", TradeSkillFrame, "BOTTOMLEFT", 224, 90)
    end
    if TradeSkillCancelButton then
        TradeSkillCancelButton:ClearAllPoints()
        TradeSkillCancelButton:SetPoint("CENTER", TradeSkillFrame, "BOTTOMLEFT", 305, 90)
    end
    if height > native.height then native.background:Show() else native.background:Hide() end
    dragBar:Show()
end

-- Reorder only glyph slots within each visible header section; retain native indices for clicks.
function addon.RecipeOrder()
    local order, slots, glyphs = {}, {}, {}
    local function Flush()
        table.sort(glyphs, function(a, b)
            if a.level ~= b.level then return a.level < b.level end
            if a.name ~= b.name then return a.name < b.name end
            return a.index < b.index
        end)
        for n, slot in ipairs(slots) do order[slot] = glyphs[n].index end
        slots, glyphs = {}, {}
    end
    for index = 1, GetNumTradeSkills() do
        order[index] = index
        local name, kind = GetTradeSkillInfo(index)
        if kind == "header" then
            Flush()
        else
            local id = addon.ItemID(GetTradeSkillItemLink(index))
            local level = addon.glyphLevels[id]
            if level then
                slots[#slots + 1] = index
                glyphs[#glyphs + 1] = { index = index, level = level, name = name or "" }
            end
        end
    end
    Flush()
    return order
end

function addon.UpdateRecipeList()
    if InCombatLockdown() then return end
    for row = 1, TRADE_SKILLS_DISPLAYED do
        local button = _G["TradeSkillSkill" .. row]
        if button and button.inkTrailNamePoints then
            local text = button:GetFontString()
            text:ClearAllPoints()
            for _, point in ipairs(button.inkTrailNamePoints) do text:SetPoint(unpack(point)) end
            button.inkTrailMinor:Hide()
            button.inkTrailLevel:Hide()
        end
    end
    if not IsInscription() then return end
    local order = addon.RecipeOrder()
    local offset = FauxScrollFrame_GetOffset(TradeSkillListScrollFrame)
    local selected = GetTradeSkillSelectionIndex()
    local highlightShown = false
    for row = 1, TRADE_SKILLS_DISPLAYED do
        local index = order[offset + row]
        local button = _G["TradeSkillSkill" .. row]
        if index and button then
            local name, kind, available = GetTradeSkillInfo(index)
            if kind ~= "header" then
                local item = addon.ItemID(GetTradeSkillItemLink(index))
                local level = addon.glyphLevels[item]
                if level then
                    button:SetID(index)
                    button:SetText(name)
                    local text = button:GetFontString()
                    if not button.inkTrailNamePoints then
                        button.inkTrailNamePoints = {}
                        for n = 1, text:GetNumPoints() do
                            button.inkTrailNamePoints[n] = { text:GetPoint(n) }
                        end
                        button.inkTrailMinor = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        button.inkTrailMinor:SetPoint("LEFT", button, "LEFT", 0, 0)
                        button.inkTrailMinor:SetWidth(12)
                        button.inkTrailMinor:SetJustifyH("LEFT")
                        button.inkTrailLevel = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                        button.inkTrailLevel:SetPoint("RIGHT", button, "RIGHT", -2, 0)
                        button.inkTrailLevel:SetWidth(40)
                        button.inkTrailLevel:SetJustifyH("RIGHT")
                    end
                    local kindFlag = addon.glyphTypes[item]
                    button.inkTrailMinor:SetText(kindFlag == 1 and "m" or (kindFlag == 0 and "" or "?"))
                    button.inkTrailMinor:Show()
                    button.inkTrailLevel:SetText("Lv " .. level)
                    button.inkTrailLevel:Show()
                    text:ClearAllPoints()
                    text:SetPoint("LEFT", button, "LEFT", 14, 0)
                    local color = TradeSkillTypeColor[kind]
                    if color then
                        button:SetNormalFontObject(color.font)
                        button.r, button.g, button.b = color.r, color.g, color.b
                    end
                    local count = _G["TradeSkillSkill" .. row .. "Count"]
                    count:SetText(available and available > 0 and ("[" .. available .. "]") or "")
                    text:SetWidth(button:GetWidth() - 94)
                    button:UnlockHighlight()
                    button.isHighlighted = selected == index
                    if selected == index then
                        TradeSkillHighlightFrame:ClearAllPoints()
                        TradeSkillHighlightFrame:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
                        button:LockHighlight()
                    end
                    if color then count:SetVertexColor(color.r, color.g, color.b) end
                end
            end
            if selected == index then highlightShown = true end
        end
    end
    if highlightShown then TradeSkillHighlightFrame:Show() else TradeSkillHighlightFrame:Hide() end
end

SLASH_INKTRAIL1 = "/inktrail"
SlashCmdList.INKTRAIL = function(message)
    if InCombatLockdown() then return end
    local settings = addon.WindowSettings()
    message = string.lower(string.match(message or "", "^%s*(.-)%s*$"))
    if message == "why" then addon.ExplainCraftAvailability(); return end
    if message == "version" then
        print("InkTrail version: " .. (GetAddOnMetadata(addonName, "Version") or "unknown"))
        return
    end
    if message == "normal" then settings.tall = false
    elseif message == "tall" then settings.tall = true
    elseif message == "reset" then
        settings.position = nil
        if TradeSkillFrame then
            TradeSkillFrame:ClearAllPoints()
            TradeSkillFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
        end
    end
    if TradeSkillDetailScrollFrame then addon.UpdateWindow() end
end
