local _, main = ...;
local events = CreateFrame("Frame");

main.commands = {
    ["sort"] = function()
        main.sort.Sort();
    end,
    ["help"] = function()
        print(" ");
        print("Retail Sort Help");
        print("|cff00cc66/retailsort sort|r - sorts your bags");
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

        SLASH_FRAMESTK1 = "/fs"; -- For quicker access to frame stack
        SlashCmdList.FRAMESTK = function()
            LoadAddOn('Blizzard_DebugTools');
            FrameStackTooltip_Toggle();
        end

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
    DebugMode(true);
    main.ui.MenuInit();
    events:UnregisterEvent("ADDON_LOADED");
end

events:RegisterEvent("ADDON_LOADED");
events:SetScript("OnEvent", main.InitEventHandler);
