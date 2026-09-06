local _, main = ...;
local events = CreateFrame("Frame");

main.commands = {
    ["sort"] = function()
        main.sort.Sort();
    end,
    ["debugsort"] = function()
        print("|cff00cc66Retail Sort:|r recording a sort, the log opens when it finishes.");
        main.sort.DebugSort();
    end,
    ["debug"] = function()
        local dump = main.utils.getBagLayoutDebugDump();
        main.ui:ShowDebugDump(dump);
        print("|cff00cc66Retail Sort debug dump opened in a window.|r");
    end,
    ["restore"] = function()
        main.ui:ShowDebugInput();
        print("|cff00cc66Retail Sort:|r paste a debug dump into the window, then press Restore This Layout.");
    end,
    ["help"] = function()
        print(" ");
        print("Retail Sort Help");
        print("|cff00cc66/retailsort sort|r - sorts your bags");
        print("|cff00cc66/retailsort debugsort|r - sorts your bags and opens a log of every decision it made");
        print("|cff00cc66/retailsort debug|r - copies the current bag layout to the clipboard");
        print("|cff00cc66/retailsort config|r - shows config menu");
        print("|cff00cc66/retailsort help|r - shows help info");
        print(" ");
    end
}
local function SlashCommandHandler(str)
    if (#str == 0) then
        main.commands.help();
    end
    -- turn arguments after / command into table and then check if they match a function and what the other arguments are, if they dont match a function request help
    local args = {};
    for _, arg in ipairs({ string.split(' ', str) }) do
        if (#arg > 0) then
            table.insert(args, arg);
        end
    end

    local path = main.commands;

    for id, arg in ipairs(args) do
        if (#arg > 0) then
            arg = arg:lower();
            if (path[arg]) then
                if (type(path[arg]) == "function") then
                    path[arg](select(id + 1, unpack(args)));
                    return;
                elseif (type(path[arg]) == "table") then
                    path = path[arg];
                end
            else
                main.commands.help();
                return;
            end
        end
    end
end

local function VarChecker()
    main.name = UnitName("player");
    main.realm = GetRealmName();
    main.faction = UnitFactionGroup("Player");

    if BagSettingArray == nil then
        BagSettingArray = {};
    end
    if BagSettingArray[main.name .. main.realm] == nil then
        BagSettingArray[main.name .. main.realm] = {
            { ["type"] = false, ["ignore"] = false },
            { ["type"] = false, ["ignore"] = false },
            { ["type"] = false, ["ignore"] = false },
            { ["type"] = false, ["ignore"] = false },
            { ["type"] = false, ["ignore"] = false }
        };
    end

    main.currentBagSettingArray = BagSettingArray[main.name .. main.realm];
end

local function DebugMode(debugMode)
    if debugMode == true then
        SLASH_RELOADUI1 = "/rl"; -- For quicker reloading whilst debugg
        SlashCmdList.RELOADUI = ReloadUI;

        for i = 1, NUM_CHAT_WINDOWS do
            _G["ChatFrame" .. i .. "EditBox"]:SetAltArrowKeyMode(false);
        end
    end
end

function main:InitEventHandler(event, name)
    if name ~= "RetailSort" then
        return;
    end
    VarChecker();
    SLASH_QSoundShort1 = "/RS";
    SlashCmdList.QSoundShort = SlashCommandHandler;
    SLASH_QSound1 = "/RetailSort";
    SlashCmdList.QSound = SlashCommandHandler;
    DebugMode(false);

    TargetFrame:SetScript("OnEvent", nil);
    TargetFrame:Hide();
    PlayerFrame:SetScript("OnEvent", nil);
    PlayerFrame:Hide();

    main.ui.MenuInit();
    events:UnregisterEvent("ADDON_LOADED");
end

events:RegisterEvent("ADDON_LOADED");
events:SetScript("OnEvent", main.InitEventHandler);
