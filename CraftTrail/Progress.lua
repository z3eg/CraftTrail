local addonName, addon = ...
local bar, cast, resultUntil

local function Idle()
    cast, resultUntil = nil, nil
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.label:SetText("Ready")
    bar:SetScript("OnUpdate", nil)
end

local function Tick()
    local now = GetTime()
    if cast then
        local elapsed = math.max(0, math.min(cast.duration, now - cast.start))
        bar:SetValue(elapsed)
        bar.label:SetText(string.format("%s  %.1fs", cast.name, math.max(0, cast.finish - now)))
        if now > cast.finish + 0.2 then Idle() end
    elseif resultUntil and now >= resultUntil then
        Idle()
    end
end

function addon.SyncCastBar(event)
    if not bar or not bar:IsShown() then return end
    if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        cast = nil
        resultUntil = GetTime() + 1
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        bar:SetStatusBarColor(0.8, 0.2, 0.15)
        bar.label:SetText(event == "UNIT_SPELLCAST_INTERRUPTED" and "Interrupted" or "Cast failed")
        bar:SetScript("OnUpdate", Tick)
        return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        cast = nil
        resultUntil = GetTime() + 0.7
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        bar:SetStatusBarColor(0.2, 0.75, 0.3)
        bar.label:SetText("Complete")
        bar:SetScript("OnUpdate", Tick)
        return
    end
    local name, _, _, _, startMS, endMS = UnitCastingInfo("player")
    if not name then name, _, _, _, startMS, endMS = UnitChannelInfo("player") end
    if name and startMS and endMS and endMS > startMS then
        cast = { name = name, start = startMS / 1000, finish = endMS / 1000,
            duration = (endMS - startMS) / 1000 }
        resultUntil = nil
        bar:SetMinMaxValues(0, cast.duration)
        bar:SetStatusBarColor(0.25, 0.6, 1)
        bar:SetScript("OnUpdate", Tick)
        Tick()
    elseif not resultUntil then
        Idle()
    end
end

function addon.ShowCastBar()
    if not bar then
        bar = CreateFrame("StatusBar", "CraftTrailCastBar", TradeSkillFrame)
        bar:SetWidth(322)
        bar:SetHeight(14)
        bar:SetPoint("BOTTOMLEFT", TradeSkillFrame, "BOTTOMLEFT", 22, 108)
        bar:SetFrameLevel(TradeSkillFrame:GetFrameLevel() + 2)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:EnableMouse(false)
        local background = bar:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(bar)
        background:SetTexture(0.04, 0.04, 0.04, 1)
        bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bar.label:SetPoint("CENTER", bar, "CENTER", 0, 0)
        for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_DELAYED",
            "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
            "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
            bar:RegisterEvent(event)
        end
        bar:SetScript("OnEvent", function(self, event, unit)
            if unit == "player" then addon.SyncCastBar(event) end
        end)
        bar:SetScript("OnHide", function() Idle() end)
        Idle()
    end
    bar:Show()
    addon.SyncCastBar()
end

function addon.HideCastBar()
    if bar then Idle(); bar:Hide() end
end
