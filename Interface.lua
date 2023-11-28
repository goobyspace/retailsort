local _, main = ...
main.ui = {}
local ui = main.ui
local menuFrame
local currentBagSettingArray;
local typeArray = { "Quest", "Equipment", "Consumable", "Trade Goods" };
local typeIconArray = {
    ["Quest"] = "inv_misc_pocketwatch_01",
    ["Consumable"] = "Inv_potion_93",
    ["Equipment"] = "Inv_chest_chain_05",
    ["Trade Goods"] = "Inv_fabric_silk_02",
};

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
    local name = UnitName("player");
    local realm = GetRealmName();
    currentBagSettingArray = BagSettingArray[name .. realm];
    local cleanUpButton = CreateFrame("Button", nil, ContainerFrame1);
    cleanUpButton:SetWidth(18);
    cleanUpButton:SetHeight(18);

    local cleanUpTexture = cleanUpButton:CreateTexture(nil, "BACKGROUND");
    cleanUpTexture:SetTexture("interface\\icons\\inv_gizmo_06");
    cleanUpTexture:SetAllPoints(cleanUpButton);
    cleanUpButton.texture = cleanUpTexture;

    cleanUpButton:SetPoint("TOPRIGHT", -10, -29)
    local cleanEnter, cleanLeave = CreateTooltip(cleanUpButton, "Cleanup Bags");
    cleanUpButton:SetScript("OnEnter", cleanEnter);
    cleanUpButton:SetScript("OnLeave", cleanLeave);
    cleanUpButton:SetScript("OnClick", function(self, event)
        cleanUpButton:SetPoint("TOPRIGHT", -11, -30)
        cleanUpButton:SetWidth(16);
        cleanUpButton:SetHeight(16);
        main.sort.Sort();
        C_Timer.After(0.1, function()
            cleanUpButton:SetPoint("TOPRIGHT", -10, -29)
            cleanUpButton:SetWidth(18);
            cleanUpButton:SetHeight(18);
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
        if bagFamily == 0 then
            local currentPortrait = ContainerPortraits[key];
            local bagType = currentBagSettingArray[key]["type"];
            -- goes away when you click literally anywhere outside the menu
            -- goes away when you bags are closed
            local optionsBG = CreateFrame("Frame", nil, currentPortrait, "SortMenuBackdropTemplate");
            optionsBG:SetPoint("BOTTOMLEFT");
            optionsBG:SetBackdrop(
                { -- despite filling this out in the XML template, we still need to fill it out here for it to work ?
                    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                    edgeSize = 16,
                    insets = { left = 4, right = 4, top = 4, bottom = 4 }
                });
            optionsBG:SetBackdropColor(0, 0, 0, 0.9);

            local optionsLine = optionsBG:CreateLine()
            optionsLine:SetColorTexture(0.55, 0.55, 0.55);
            optionsLine:SetThickness(1);
            optionsLine:SetStartPoint("TOP", -60, -116)
            optionsLine:SetEndPoint("TOP", 60, -116)

            local equipmentIcon = CreateFrame("Frame", nil, currentPortrait);
            equipmentIcon:SetPoint("BOTTOMRIGHT", 7, 0);
            equipmentIcon:SetSize(20, 20);

            local iconTexture = equipmentIcon:CreateTexture(nil, "BACKGROUND")
            iconTexture:SetAllPoints();

            local equipmentBorder = CreateFrame("Frame", nil, equipmentIcon);
            equipmentBorder:SetPoint("CENTER");
            equipmentBorder:SetSize(26, 26);

            local borderTexture = equipmentBorder:CreateTexture(nil, "BACKGROUND")
            borderTexture:SetAllPoints();
            borderTexture:SetTexture("interface/COMMON/RingBorder");
            borderTexture:SetVertexColor(180 / 255, 180 / 255, 220 / 255);
            equipmentIcon:Hide();

            local function setEquipmentIcon()
                bagType = currentBagSettingArray[key]["type"]; -- incase it has been changed
                iconTexture:SetTexture("interface/icons/" .. typeIconArray[bagType]);
                equipmentIcon:Show();
            end

            local checkButtons = { optionsBG:GetChildren() };

            if bagType ~= nil and bagType ~= false then
                for _, child in ipairs(checkButtons) do
                    if child:GetName() == bagType .. "Check" then
                        child:SetChecked(true);
                    end
                end
                setEquipmentIcon();
                currentPortrait:HookScript("OnEnter", function()
                    GameTooltip:AddDoubleLine("Assigned to", bagType, 1, 0.835, 0,
                        1, 1, 1);
                    GameTooltip:Show();
                end);
            end
            currentPortrait:HookScript("OnEnter", function()
                GameTooltip:AddLine('<Click for Bag Settings>', 0, 1, 0, 1);
                GameTooltip:Show();
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
                    optionsBG:Hide();
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
                            currentBagSettingArray[key]["type"] = false;
                            currentBagSettingArray[key]["ignore"] = true;
                            equipmentIcon:Hide();
                        else
                            currentBagSettingArray[key]["ignore"] = false;
                        end
                    elseif child:GetChecked() == true then
                        WipeChecks();
                        currentBagSettingArray[key]["type"] = typeArray[typeKey];
                        currentBagSettingArray[key]["ignore"] = false;
                        setEquipmentIcon();
                    else -- if its false that means it was true before
                        currentBagSettingArray[key]["type"] = false;
                        equipmentIcon:Hide();
                    end
                end);
            end
            optionsBG:HookScript("OnEnter", TimerCancel);
            optionsBG:HookScript("OnLeave", TimerStart);
            currentPortrait:HookScript("OnClick", function()
                optionsBG:SetShown(not optionsBG:IsShown());
                if timerHook ~= nil then timerHook:Cancel(); end
                timerHook = C_Timer.NewTicker(1.8, function()
                    optionsBG:Hide();
                end, 1);
            end);
            optionsBG:SetShown(false);
        else
            local currentPortrait = ContainerPortraits[key];
            local clickCounter = 0; --displaying the text once would be probably better from a UX standpoint, but this is funny so im keeping it in
            currentPortrait:HookScript("OnClick", function()
                clickCounter = clickCounter + 1;
                GameTooltip:AddLine('Bag settings only available for normal bags', 1,
                    1 - (clickCounter / 15), 1 - (clickCounter / 7), 1);
                GameTooltip:Show();
            end);
            currentPortrait:HookScript("OnLeave", function()
                clickCounter = 0;
            end);
        end
    end
end

function ui:MenuInit()
    local currentBagSettingArray = main.currentBagSettingArray;
    CreateMenu();
end