local addonName, addon = ...
local list, summary, hidden = nil, nil, {}

local function Suppress(frame)
    if not frame then return end
    if hidden[frame] == nil then hidden[frame] = frame:IsShown() and true or false end
    frame:Hide()
end

function addon.CaptureProfessionView()
    local root = addon.crossRoot
    if not root or root.view then return end
    local name, rank, maximum = GetTradeSkillLine()
    root.view = {name=name, rank=rank, maximum=maximum, entries={}, offset=0}
    for index=1,GetNumTradeSkills() do
        local text, kind = GetTradeSkillInfo(index)
        local recipe = kind ~= "header" and addon.ReadRecipe(index)
        root.view.entries[#root.view.entries+1] = {text=text, header=kind=="header", recipe=recipe}
    end
    if FauxScrollFrame_GetOffset then root.view.offset = FauxScrollFrame_GetOffset(TradeSkillListScrollFrame) end
end

function addon.ReleaseProfessionView()
    if InCombatLockdown() then return end
    if list then list:Hide(); summary:Hide() end
    for frame, shown in pairs(hidden) do if shown then frame:Show() end end
    hidden = {}
end

function addon.ApplyProfessionView()
    if InCombatLockdown() then return end
    local root = addon.crossRoot
    local view = root and root.view
    if not view then addon.ReleaseProfessionView(); return end
    if not list then
        list = CreateFrame("Frame", "CraftTrailPinnedRecipes", TradeSkillFrame)
        list:SetFrameLevel(TradeSkillFrame:GetFrameLevel()+8)
        list:SetPoint("TOPLEFT", TradeSkillSkill1, "TOPLEFT", 0, 0)
        list:SetWidth(323); list:SetHeight(TRADE_SKILLS_DISPLAYED*TRADE_SKILL_HEIGHT)
        list:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background"})
        list:SetBackdropColor(0.04,0.04,0.04,1)
        list:EnableMouse(true); list:EnableMouseWheel(true)
        list:SetScript("OnMouseWheel", function(self, delta)
            if InCombatLockdown() or not addon.crossRoot then return end
            local current=addon.crossRoot.view
            current.offset=math.max(0,math.min(math.max(0,#current.entries-TRADE_SKILLS_DISPLAYED),current.offset-delta))
            addon.ApplyProfessionView()
        end)
        list.rows={}
        for n=1,TRADE_SKILLS_DISPLAYED do
            local row=CreateFrame("Button",nil,list,"SecureActionButtonTemplate,UIPanelButtonTemplate")
            row:SetPoint("TOPLEFT",list,"TOPLEFT",0,-(n-1)*TRADE_SKILL_HEIGHT)
            row:SetWidth(323); row:SetHeight(TRADE_SKILL_HEIGHT)
            row:RegisterForClicks("LeftButtonUp")
            row:SetScript("PreClick",function(self)
                if InCombatLockdown() then return end
                self:SetAttribute("type",addon.ReturnProfessionMacro() and self.originMacro and "macro" or nil)
                self:SetAttribute("macrotext",self.originMacro)
            end)
            list.rows[n]=row
        end
        summary=CreateFrame("Button","CraftTrailPinnedRecipe",TradeSkillDetailScrollChildFrame)
        summary:SetPoint("TOPLEFT",TradeSkillDetailScrollChildFrame,"TOPLEFT",0,0)
        summary:SetWidth(285); summary:SetHeight(64)
        summary.icon=summary:CreateTexture(nil,"ARTWORK")
        summary.icon:SetPoint("TOPLEFT",summary,"TOPLEFT",0,0)
        summary.icon:SetWidth(32); summary.icon:SetHeight(32)
        summary.text=summary:CreateFontString(nil,"OVERLAY","GameFontNormal")
        summary.text:SetPoint("TOPLEFT",summary,"TOPLEFT",40,-2)
        summary.text:SetWidth(245); summary.text:SetJustifyH("LEFT")
        summary:SetScript("OnEnter",function(self)
            local recipe=addon.crossRoot and addon.crossRoot.recipe
            if not recipe then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(recipe.item and ("item:"..recipe.item) or ("spell:"..recipe.spell))
            GameTooltip:Show()
        end)
        summary:SetScript("OnLeave",function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    end
    -- Underlying native indices now belong to the component's profession. Hide
    -- every control that could accidentally select/craft/filter those indices.
    for _,name in ipairs({"TradeSkillListScrollFrame","TradeSkillHighlightFrame","TradeSkillCollapseAllButton",
        "TradeSkillSubClassDropDown","TradeSkillInvSlotDropDown","TradeSkillFrameEditBox",
        "TradeSkillFrameAvailableFilterCheckButton","TradeSkillFrameAvailableFilterCheckButtonText",
        "TradeSkillSkillName","TradeSkillSkillIcon","TradeSkillSkillCooldown","TradeSkillRequirementLabel",
        "TradeSkillRequirementText","TradeSkillDescription","TradeSkillReagentLabel",
        "TradeSkillCreateButton","TradeSkillCreateAllButton","TradeSkillInputBox",
        "TradeSkillIncrementButton","TradeSkillDecrementButton","TradeSkillLinkButton"}) do Suppress(_G[name]) end
    for n=1,TRADE_SKILLS_DISPLAYED do Suppress(_G["TradeSkillSkill"..n]) end
    for n=1,MAX_TRADE_SKILL_REAGENTS or 8 do Suppress(_G["TradeSkillReagent"..n]) end
    if TradeSkillFrameTitleText then TradeSkillFrameTitleText:SetText(view.name) end
    if TradeSkillRankFrame then
        TradeSkillRankFrame:SetMinMaxValues(0,view.maximum or 1)
        TradeSkillRankFrame:SetValue(view.rank or 0)
    end
    if TradeSkillRankFrameSkillRank then TradeSkillRankFrameSkillRank:SetText((view.rank or 0).."/"..(view.maximum or 0)) end
    for n,row in ipairs(list.rows) do
        local entry=view.entries[view.offset+n]
        if entry then
            row:SetText(entry.text)
            row:SetAttribute("type",entry.recipe and "macro" or nil)
            row.originMacro=entry.recipe and ("/cast [nocombat] "..addon.ProfessionName(root.skill)..
                "\n/run CraftTrail_SelectOrigin("..(entry.recipe.spell or 0)..","..(entry.recipe.item or 0)..")") or nil
            row:SetAttribute("macrotext",row.originMacro)
            if entry.recipe then row:Enable() else row:Disable() end
            row:Show()
        else row:Hide() end
    end
    summary.text:SetText(root.recipe.name)
    local icon = root.recipe.item and select(10,GetItemInfo(root.recipe.item))
    summary.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    list:Show(); summary:Show()
end

CraftTrail_SelectOrigin=function(spell,item)
    if InCombatLockdown() or not addon.crossRoot or addon.OpenProfession()~=addon.crossRoot.skill then return end
    for _,entry in ipairs(addon.crossRoot.view.entries) do
        local recipe=entry.recipe
        if recipe and ((spell~=0 and recipe.spell==spell) or (spell==0 and item~=0 and recipe.item==item)) then
            addon.crossRoot.recipe=recipe
            CraftTrail_ReturnToRecipe()
            return
        end
    end
end
