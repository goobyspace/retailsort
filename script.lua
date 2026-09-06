-- Mock of the blizz API so I can test other people's bags hopefully ideally
-- Doesn't seem to work quite the same as retail, but it's better than nothing idk

local BAG_DUMP = [[
bag 0: 20 slot(s), 16 free, family=0, assignedType=false, ignored=false
bag 1: 6 slot(s), 0 free, family=0, assignedType=Consumable, ignored=false
bag 2: 6 slot(s), 5 free, family=0, assignedType=Trade Goods, ignored=false
bag 3: 6 slot(s), 6 free, family=0, assignedType=false, ignored=false
bag 4: 4 slot(s), 3 free, family=0, assignedType=Equipment, ignored=false
Bag 0 (20 slots):
  slot 01: Hearthstone | itemID=6948 | qty=1 | locked=unlocked | family=0 | type=Miscellaneous | subType=Junk | rarity=1 | ilvl=1 | maxStack=1 | link=[Hearthstone]
  slot 02: Recruitment Letter | itemID=4992 | qty=1 | locked=unlocked | family=0 | type=Quest | subType=Quest | rarity=1 | ilvl=1 | maxStack=1 | link=[Recruitment Letter]
  slot 03: Minor Healing Potion | itemID=118 | qty=5 | locked=unlocked | family=0 | type=Consumable | subType=Consumable | rarity=1 | ilvl=5 | maxStack=5 | link=[Minor Healing Potion]
  slot 04: Really Sticky Glue | itemID=4941 | qty=10 | locked=unlocked | family=0 | type=Consumable | subType=Consumable | rarity=1 | ilvl=10 | maxStack=20 | link=[Really Sticky Glue]
  slot 05: empty
  slot 06: empty
  slot 07: empty
  slot 08: empty
  slot 09: empty
  slot 10: empty
  slot 11: empty
  slot 12: empty
  slot 13: empty
  slot 14: empty
  slot 15: empty
  slot 16: empty
  slot 17: empty
  slot 18: empty
  slot 19: empty
  slot 20: empty
Bag 1 (6 slots):
  slot 01: Faintly Glowing Skull | itemID=4945 | qty=1 | locked=unlocked | family=0 | type=Consumable | subType=Consumable | rarity=1 | ilvl=9 | maxStack=1 | link=[Faintly Glowing Skull]
  slot 02: Herb Baked Egg | itemID=6888 | qty=3 | locked=unlocked | family=0 | type=Consumable | subType=Consumable | rarity=1 | ilvl=7 | maxStack=20 | link=[Herb Baked Egg]
  slot 03: Ice Cold Milk | itemID=1179 | qty=4 | locked=unlocked | family=0 | type=Consumable | subType=Consumable | rarity=1 | ilvl=15 | maxStack=20 | link=[Ice Cold Milk]
  slot 04: Linen Bandage | itemID=1251 | qty=20 | locked=unlocked | family=0 | type=Consumable | subType=Consumable | rarity=1 | ilvl=1 | maxStack=20 | link=[Linen Bandage]
  slot 05: Longjaw Mud Snapper | itemID=4592 | qty=13 | locked=unlocked | family=0 | type=Consumable | subType=Consumable | rarity=1 | ilvl=15 | maxStack=20 | link=[Longjaw Mud Snapper]
  slot 06: Minor Healing Potion | itemID=118 | qty=5 | locked=unlocked | family=0 | type=Consumable | subType=Consumable | rarity=1 | ilvl=5 | maxStack=5 | link=[Minor Healing Potion]
Bag 2 (6 slots):
  slot 01: Linen Cloth | itemID=2589 | qty=2 | locked=unlocked | family=0 | type=Trade Goods | subType=Trade Goods | rarity=1 | ilvl=5 | maxStack=20 | link=[Linen Cloth]
  slot 02: empty
  slot 03: empty
  slot 04: empty
  slot 05: empty
  slot 06: empty
Bag 3 (6 slots):
  slot 01: empty
  slot 02: empty
  slot 03: empty
  slot 04: empty
  slot 05: empty
  slot 06: empty
Bag 4 (4 slots):
  slot 01: Fishing Pole | itemID=6256 | qty=1 | locked=unlocked | family=0 | type=Weapon | subType=Fishing Pole | rarity=1 | ilvl=1 | maxStack=1 | link=[Fishing Pole]
  slot 02: empty
  slot 03: empty
  slot 04: empty
]];

------------------------------------------------------------------
-- parse the pasted dump into bags[bagKey] = { numSlots = n, slots = { [slot] = item } }
------------------------------------------------------------------
local function trim(s)
    if s == nil then return nil end
    return s:match('^%s*(.-)%s*$');
end

local function parseDump(text)
    local bags = {};
    local currentBag = nil;
    for line in text:gmatch('[^\r\n]+') do
        local bagKey, numSlots = line:match('^%s*Bag%s+(%d+)%s*%((%d+)');
        if bagKey then
            local bagIndex = tonumber(bagKey);
            currentBag = bagIndex;
            local bag = bagIndex and bags[bagIndex];
            if bagIndex ~= nil and bag == nil then
                bag = { numSlots = tonumber(numSlots), slots = {} };
                bags[bagIndex] = bag;
            end
        elseif currentBag ~= nil then
            local slotNum, itemName, itemID, qty =
                line:match('^%s*slot%s+(%d+):%s*(.-)%s*|%s*itemID=(%d+)%s*|%s*qty=(%d+)');
            if slotNum then
                bags[currentBag].slots[tonumber(slotNum)] = {
                    itemID = tonumber(itemID),
                    itemName = trim(itemName),
                    qty = tonumber(qty),
                    isLocked = line:match('locked=(%a+)') == 'locked',
                    family = tonumber(line:match('family=(%d+)')) or 0,
                    itemType = trim(line:match('type=([^|]+)')),
                    subType = trim(line:match('subType=([^|]+)')),
                    rarity = tonumber(line:match('rarity=(%d+)')) or 1,
                    ilvl = tonumber(line:match('ilvl=(%d+)')) or 1,
                    maxStack = tonumber(line:match('maxStack=(%d+)')) or 1,
                };
            end
        end
    end
    return bags;
end

--reads "bag N: ... assignedType=X, ignored=Y" lines written by getBagSettingsDump/DebugSort, defaults to false/false if absent
local function parseBagSettings(text)
    local settings = {};
    for key = 1, 5, 1 do
        settings[key] = { ["type"] = false, ["ignore"] = false };
    end
    for line in text:gmatch('[^\r\n]+') do
        local bagKey, assignedType, ignored = line:match('^%s*bag%s+(%d+):.-assignedType=([^,]+),%s*ignored=(%a+)');
        if bagKey then
            assignedType = trim(assignedType);
            settings[tonumber(bagKey) + 1] = {
                ["type"] = (assignedType ~= 'false') and assignedType or false,
                ["ignore"] = ignored == 'true',
            };
        end
    end
    return settings;
end

local bags = parseDump(BAG_DUMP);
local bagSettings = parseBagSettings(BAG_DUMP);

------------------------------------------------------------------
-- fake addon environment: build `main` the same way WoW's loader would
------------------------------------------------------------------
local main = {};
main.faction = "Alliance";
main.currentBagSettingArray = bagSettings;


--first sighting of an itemID anywhere in the dump defines its "item info" for every stack of it
local itemInfoByID = {};
for _, bagData in pairs(bags) do
    for _, item in pairs(bagData.slots) do
        if itemInfoByID[item.itemID] == nil then
            itemInfoByID[item.itemID] = item;
        end
    end
end

main.wow = {
    GetContainerNumSlots = function(bag)
        return bags[bag] and bags[bag].numSlots or 0;
    end,
    GetContainerNumFreeSlots = function(bag)
        local bagData = bags[bag];
        local numSlots = bagData and bagData.numSlots or 0;
        local used = 0;
        if bagData then
            for _ in pairs(bagData.slots) do used = used + 1 end
        end
        return numSlots - used, 0; --every bag is treated as an ordinary (family 0) bag
    end,
    GetContainerItemInfo = function(bag, slot)
        local bagData = bags[bag];
        local item = bagData and bagData.slots[slot];
        if item == nil then return nil end
        return { itemID = item.itemID, stackCount = item.qty, isLocked = item.isLocked };
    end,
    GetItemInfo = function(itemID)
        local item = itemInfoByID[itemID];
        if item == nil then return nil end
        return item.itemName, nil, item.rarity, item.ilvl, nil, item.itemType, item.subType, item.maxStack;
    end,
    GetItemFamily = function(itemID)
        local item = itemInfoByID[itemID];
        return item and item.family or 0;
    end,
    ClearCursor = function() end,
    PickupContainerItem = function() end,
    InCombatLockdown = function() return false end,
    After = function() end, --the test only computes the plan, it never runs the frame/timer driven execution
    CreateFrame = function()
        return { RegisterEvent = function() end, UnregisterEvent = function() end, SetScript = function() end };
    end,
};

------------------------------------------------------------------
-- load the real addon files against the fake environment
------------------------------------------------------------------
local function loadAddonFile(path)
    ---@diagnostic disable-next-line: undefined-global
    local chunk = assert(loadfile(path));
    return chunk("RetailSort", main);
end

loadAddonFile("code/Utils.lua");
loadAddonFile("code/IndexBags.lua");
loadAddonFile("code/Sort.lua");

------------------------------------------------------------------
-- run the planner and print the result
------------------------------------------------------------------
local bagArray = main.index.getBagSlots();
local itemArray = main.index.getItemArrayFromBags(bagArray);

-- Track how many times each item is moved across waves
local currentItemsBySlot = {};
for bagKey = 0, 4 do currentItemsBySlot[bagKey] = {} end
for _, item in ipairs(itemArray) do
    currentItemsBySlot[item.currentBag][item.currentSlot] = item.itemName ..
        " (" .. item.currentBag .. "," .. item.currentSlot .. ")";
end

local movePlan, planLength, finalItems = main.sort.ComputePlan(bagArray, itemArray);

print(string.format("Planned %d wave(s) of moves.", planLength));

for wave = 1, planLength do
    print(string.format("Wave %d (%d moves):", wave, #movePlan[wave]));
    for i, move in ipairs(movePlan[wave]) do
        local fromB, fromS = move[1].currentBag, move[1].currentSlot;
        local toB, toS = move[2].currentBag, move[2].currentSlot;
        local item1 = currentItemsBySlot[fromB][fromS] or "empty";
        local item2 = currentItemsBySlot[toB][toS] or "empty";
        print(string.format("  Move %d: [%d,%d](%s) <-> [%d,%d](%s)", i, fromB, fromS, item1, toB, toS, item2));
        -- update slot contents
        currentItemsBySlot[fromB][fromS] = item2;
        currentItemsBySlot[toB][toS] = item1;
    end
end

--in-game a finished plan is re-planned once more to verify nothing was left behind; keep replanning
--the already-sorted result here too, until a pass finds nothing left to move
local loopCount = 1;
local MAX_LOOPS = 10;
while planLength > 0 and loopCount < MAX_LOOPS do
    loopCount = loopCount + 1;
    bagArray = main.index.getBagSlots();
    movePlan, planLength, finalItems = main.sort.ComputePlan(bagArray, finalItems);
end

local finalLayout = {};
for bagKey = 0, 4, 1 do finalLayout[bagKey] = {} end
for _, item in ipairs(finalItems) do
    finalLayout[item.currentBag][item.currentSlot] = item;
end

for bagKey = 0, 4, 1 do
    local numSlots = bags[bagKey] and bags[bagKey].numSlots or 0;
    print(string.format("Bag %d (%d slots):", bagKey, numSlots));
    for slot = 1, numSlots, 1 do
        local item = finalLayout[bagKey][slot];
        if item then
            print(string.format("  slot %02d: %s x%d (itemID=%d)", slot, item.itemName, item.currentStack,
                item.itemID));
        else
            print(string.format("  slot %02d: empty", slot));
        end
    end
end

print(string.format("Loop count: %d", loopCount));
