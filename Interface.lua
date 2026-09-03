local _, main = ...
main.ui = {}
local ui = main.ui
local typeArray = { "Quest", "Equipment", "Consumable", "Trade Goods" };
local typeIconArray = {
    ["Quest"] = "inv_misc_pocketwatch_01",
    ["Consumable"] = "Inv_potion_93",
    ["Equipment"] = "Inv_chest_chain_05",
    ["Trade Goods"] = "Inv_fabric_silk_02",
};
local bagFrames = {};

local function CreateTooltip(frame, tooltip)
    local texture = frame:CreateTexture(nil, "HIGHLIGHT");
    local mask = frame:CreateMaskTexture();
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask");
    mask:SetSize(22, 22);
    mask:SetPoint("CENTER");
    texture:SetColorTexture(1, 1, 1);
    texture:SetSize(20, 20);
    texture:SetPoint("CENTER");
    texture:AddMaskTexture(mask);
    texture:SetAlpha(0);

    return function(self, event)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT");
        GameTooltip:AddLine('Clean Up Bags', 1, 1, 1, 1);
        GameTooltip:AddLine(
            "Auto-sorts your inventory to make room for new items. You can assign an item type to a specific bag by clicking the bag's top-left icon.",
            1, 0.835, 0, 1);
        GameTooltip:Show();
        texture:SetAlpha(0.25);
    end, function(self, event)
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent);
        texture:SetAlpha(0);
    end
end

local function CreateMenu()
    local cleanUpButton = CreateFrame("Button", nil, ContainerFrame1);
    cleanUpButton:SetWidth(16);
    cleanUpButton:SetHeight(16);

    local cleanUpTexture = cleanUpButton:CreateTexture(nil, "BACKGROUND");
    cleanUpTexture:SetTexture("Interface/AddOns/RetailSort/inv_pet_broom");
    cleanUpTexture:SetAllPoints(cleanUpButton);
    cleanUpButton.texture = cleanUpTexture;

    cleanUpButton:SetPoint("TOPRIGHT", -10, -30)
    local cleanEnter, cleanLeave = CreateTooltip(cleanUpButton, "Cleanup Bags");
    cleanUpButton:SetScript("OnEnter", cleanEnter);
    cleanUpButton:SetScript("OnLeave", cleanLeave);
    cleanUpButton:SetScript("OnClick", function(self, event)
        cleanUpButton:SetPoint("TOPRIGHT", -11, -31)
        cleanUpButton:SetWidth(14);
        cleanUpButton:SetHeight(14);
        main.sort.Sort();
        C_Timer.After(0.1, function()
            cleanUpButton:SetPoint("TOPRIGHT", -10, -30)
            cleanUpButton:SetWidth(16);
            cleanUpButton:SetHeight(16);
        end)
    end);
    cleanUpButton:Show()
    local ContainerPortraits = {
        ContainerFrame1PortraitButton, ContainerFrame2PortraitButton,
        ContainerFrame3PortraitButton, ContainerFrame4PortraitButton,
        ContainerFrame5PortraitButton
    }
    for key = 1, 5, 1 do
        local _, bagFamily = C_Container.GetContainerNumFreeSlots(key - 1);
        bagFrames[key] = {};
        bagFrames[key]["bagFamily"] = bagFamily;
        local currentPortrait = ContainerPortraits[key];
        local bagType = main.currentBagSettingArray[key]["type"];
        -- goes away when you click literally anywhere outside the menu
        -- goes away when you bags are closed
        bagFrames[key]["frame"] = CreateFrame("Frame", nil, currentPortrait, "SortMenuBackdropTemplate");
        bagFrames[key]["frame"]:SetPoint("BOTTOMLEFT");
        bagFrames[key]["frame"]:SetBackdrop(
            { -- despite filling this out in the XML template, we still need to fill it out here for it to work ?
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 }
            });
        bagFrames[key]["frame"]:SetBackdropColor(0, 0, 0, 0.9);

        local optionsLine = bagFrames[key]["frame"]:CreateLine()
        optionsLine:SetColorTexture(0.55, 0.55, 0.55);
        optionsLine:SetThickness(1);
        optionsLine:SetStartPoint("TOP", -60, -116)
        optionsLine:SetEndPoint("TOP", 60, -116)

        bagFrames[key]["equipmentIcon"] = CreateFrame("Frame", nil, currentPortrait);
        bagFrames[key]["equipmentIcon"]:SetPoint("BOTTOMRIGHT", 7, 0);
        bagFrames[key]["equipmentIcon"]:SetSize(20, 20);

        local iconTexture = bagFrames[key]["equipmentIcon"]:CreateTexture(nil, "BACKGROUND")
        iconTexture:SetAllPoints();

        local equipmentBorder = CreateFrame("Frame", nil, bagFrames[key]["equipmentIcon"]);
        equipmentBorder:SetPoint("CENTER");
        equipmentBorder:SetSize(26, 26);

        local borderTexture = equipmentBorder:CreateTexture(nil, "BACKGROUND")
        borderTexture:SetAllPoints();
        borderTexture:SetTexture("interface/COMMON/RingBorder");
        borderTexture:SetVertexColor(180 / 255, 180 / 255, 220 / 255);
        bagFrames[key]["equipmentIcon"]:Hide();

        local function setEquipmentIcon()
            bagType = main.currentBagSettingArray[key]["type"]; -- incase it has been changed
            iconTexture:SetTexture("interface/icons/" .. typeIconArray[bagType]);
            if bagFrames[key]["bagFamily"] == 0 then
                bagFrames[key]["equipmentIcon"]:Show();
            end
        end

        local checkButtons = { bagFrames[key]["frame"]:GetChildren() };

        if bagType ~= nil and bagType ~= false then
            for _, child in ipairs(checkButtons) do
                if child:GetName() == bagType .. "Check" then
                    child:SetChecked(true);
                end
            end
            setEquipmentIcon();
            currentPortrait:HookScript("OnEnter", function()

            end);
        end
        currentPortrait:HookScript("OnEnter", function()
            bagType = main.currentBagSettingArray[key]["type"];
            if bagFrames[key]["bagFamily"] == 0 then
                if bagType ~= nil and bagType ~= false then
                    GameTooltip:AddDoubleLine("Assigned to", bagType, 1, 0.835, 0,
                        1, 1, 1);
                    GameTooltip:Show();
                end
                GameTooltip:AddLine('<Click for Bag Settings>', 0, 1, 0, 1);
                GameTooltip:Show();
            end
        end);
        local timerHook = nil;
        local function TimerCancel() -- this is laziness, because on retail it disappears if clicking outside the frame but it's waaaay easier to just do a timer
            if timerHook ~= nil then
                timerHook:Cancel();
                timerHook = nil;
            end
        end
        local function TimerStart()
            if timerHook ~= nil then timerHook:Cancel(); end
            timerHook = C_Timer.NewTicker(0.8, function()
                bagFrames[key]["frame"]:Hide();
            end, 1);
        end

        for typeKey, child in ipairs(checkButtons) do
            child:HookScript("OnEnter", TimerCancel);
            child:HookScript("OnLeave", TimerStart);
            child:HookScript("OnClick", function()
                local function WipeChecks()
                    for checkTypeKey, checkChild in ipairs(checkButtons) do
                        if checkTypeKey ~= typeKey then
                            checkChild:SetChecked(false);
                        end
                    end
                end

                if typeKey == 5 then --key 5 is ignore
                    if child:GetChecked() == true then
                        WipeChecks();
                        main.currentBagSettingArray[key]["type"] = false;
                        main.currentBagSettingArray[key]["ignore"] = true;
                        bagFrames[key]["equipmentIcon"]:Hide();
                    else
                        main.currentBagSettingArray[key]["ignore"] = false;
                    end
                elseif child:GetChecked() == true then
                    WipeChecks();
                    main.currentBagSettingArray[key]["type"] = typeArray[typeKey];
                    main.currentBagSettingArray[key]["ignore"] = false;
                    setEquipmentIcon();
                else -- if its false that means it was true before
                    main.currentBagSettingArray[key]["type"] = false;
                    bagFrames[key]["equipmentIcon"]:Hide();
                end
            end);
        end
        bagFrames[key]["frame"]:HookScript("OnEnter", TimerCancel);
        bagFrames[key]["frame"]:HookScript("OnLeave", TimerStart);
        currentPortrait:HookScript("OnClick", function()
            if bagFrames[key]["bagFamily"] == 0 then
                bagFrames[key]["frame"]:SetShown(not bagFrames[key]["frame"]:IsShown());
                if timerHook ~= nil then timerHook:Cancel(); end
                timerHook = C_Timer.NewTicker(1.8, function()
                    bagFrames[key]["frame"]:Hide();
                end, 1);
            end
        end);
        bagFrames[key]["frame"]:SetShown(false);
        local currentPortrait = ContainerPortraits[key];
        local clickCounter = 0; --displaying the text once would be probably better from a UX standpoint, but this is funny so im keeping it in
        currentPortrait:HookScript("OnClick", function()
            if bagFrames[key]["bagFamily"] ~= 0 then
                clickCounter = clickCounter + 1;
                GameTooltip:AddLine('Bag settings only available for normal bags', 1,
                    1 - (clickCounter / 15), 1 - (clickCounter / 7), 1);
                GameTooltip:Show();
            end
        end);
        currentPortrait:HookScript("OnLeave", function()
            if bagFrames[key]["bagFamily"] ~= 0 then
                clickCounter = 0;
            end
        end);
    end
end

local function bagsChanged()
    for key = 1, 5, 1 do
        local _, bagFamily = C_Container.GetContainerNumFreeSlots(key - 1);
        bagFrames[key]["bagFamily"] = bagFamily;
        if main.currentBagSettingArray[key]["type"] ~= nil and
            main.currentBagSettingArray[key]["type"] ~= false and
            bagFamily == 0 then
            bagFrames[key]["equipmentIcon"]:Show();
        else
            bagFrames[key]["equipmentIcon"]:Hide();
        end
    end
end

function ui:CombatBlock()
    GameTooltip:AddLine(
        "Cannot be used in combat.",
        1, 0.835, 0.5, 1);
    GameTooltip:Show();
end

function ui:CreateDebugWindow()
    if self.debugWindow then
        return self.debugWindow;
    end

    local frame = CreateFrame("Frame", "RetailSortDebugWindow", UIParent, "BackdropTemplate");
    frame:SetSize(620, 420);
    frame:SetPoint("CENTER");
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    });
    frame:SetBackdropColor(0.05, 0.05, 0.08, 0.95);
    frame:SetMovable(true);
    frame:EnableMouse(true);
    frame:RegisterForDrag("LeftButton");
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving();
    end);
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing();
    end);
    frame:SetClampedToScreen(true);

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
    title:SetPoint("TOP", 0, -14);
    title:SetText("Retail Sort Debug");

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
    close:SetPoint("TOPRIGHT", -8, -8);
    close:SetScript("OnClick", function()
        frame:Hide();
    end);

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate");
    scroll:SetPoint("TOPLEFT", 12, -32);
    scroll:SetPoint("BOTTOMRIGHT", -12, 40);

    local restore = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
    restore:SetSize(160, 22);
    restore:SetPoint("BOTTOMRIGHT", -12, 12);
    restore:SetText("Restore This Layout");
    restore:SetScript("OnClick", function()
        local layout, info = main.utils.parseBagLayoutDump(frame.editBox:GetText());
        if layout == nil then
            print("|cffff5555Retail Sort restore:|r " .. tostring(info));
            return;
        end
        frame:Hide();
        main.sort:Restore(layout);
    end);

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
    hint:SetPoint("BOTTOMLEFT", 14, 18);
    hint:SetText("Paste a dump and press Restore to move items back into that layout.");

    local editBox = CreateFrame("EditBox", nil, scroll);
    editBox:SetMultiLine(true);
    editBox:SetFontObject(ChatFontNormal);
    editBox:SetTextInsets(8, 8, 8, 8);
    editBox:SetAutoFocus(false);
    editBox:SetTextColor(1, 1, 1, 1);
    editBox:SetCursorPosition(0);
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus();
    end);
    editBox:SetScript("OnTextChanged", function(self)
        self:SetCursorPosition(0);
    end);
    editBox:SetWidth(scroll:GetWidth() - 24);
    editBox:SetHeight(1000);
    scroll:SetScrollChild(editBox);

    frame.editBox = editBox;
    frame:Hide();
    self.debugWindow = frame;
    return frame;
end

function ui:ShowDebugDump(text)
    local frame = self:CreateDebugWindow();
    frame.editBox:SetText(text or "");
    frame.editBox:HighlightText();
    frame.editBox:SetCursorPosition(0);
    frame:Show();
end

function ui:ShowDebugInput()
    local frame = self:CreateDebugWindow();
    frame.editBox:SetText("");
    frame.editBox:SetFocus();
    frame:Show();
end

function ui:MenuInit()
    local event = CreateFrame("Frame");
    event:RegisterEvent("BAG_CONTAINER_UPDATE");
    event:SetScript("OnEvent", bagsChanged);
    CreateMenu();
end
