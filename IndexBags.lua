local _, main = ...;
main.index = {};
local c = C_Container;

main.index.getBagSlots = function()
    local bagArray = {};
    local totalSlots = 0;
    for bagKey = 0, 4, 1
    do
        local currentBag = c.GetContainerNumSlots(bagKey);
        local _, family = c.GetContainerNumFreeSlots(bagKey);
        local slotArray = {};
        --fill up the bagarray with all the slots, if this is skipped bag will be considered a 0 slot bag
        if main.currentBagSettingArray[bagKey + 1]["ignore"] ~= true then
            for currentSlot = 1, currentBag, 1
            do
                totalSlots = totalSlots + 1;
                table.insert(slotArray, { ["currentSlot"] = currentSlot, ["currentBag"] = bagKey });
            end
            bagArray[bagKey] = { ["slotArray"] = slotArray, ["maxSlots"] = currentBag, ["currentBag"] = bagKey };
        else
            bagArray[bagKey] = { ["slotArray"] = slotArray, ["maxSlots"] = 0, ["currentBag"] = bagKey };
        end
    end
    return bagArray, totalSlots;
end

local function IsMount(itemName)
    local mountList = {};
    if main.faction == "Alliance" then
        mountList = { "Pinto Bridle", "Brown Horse Bridle", "Chestnut Mare Bridle", "Swift Brown Steed", "Swift Palomino",
            "Swift White Steed", "Black Stallion Bridle", "Brown Ram", "Gray Ram", "White Ram", "Swift Brown Ram",
            "Swift Gray Ram", "Swift White Ram", "Swift Gray Ram", "Swift White Ram", "Reins of the", "Mechanostrider",
            "Black War Steed Bridle", "Black War Ram", "Black Battlestrider", "Stormpike Battle Charger",
            "Deathcharger's Reins", "Swift Razzashi Raptor", "Swift Zulian Tiger", "Resonating Crystal", };
    else
        mountList = { "Horn of the", "Whistle of the", "Swift Blue Raptor", "Swift Olive Raptor",
            "Swift Orange Raptor", "Skeletal Horse", "Skeletal Warhorse", "Brown Kodo", "Gray Kodo", "Great White Kodo",
            "Black War Kodo", "Deathcharger's Reins", "Swift Razzashi Raptor", "Swift Zulian Tiger", "Resonating Crystal", }
    end
    for key = 1, #mountList, 1 do
        if itemName:find(mountList[key]) then
            return true;
        end
    end
    return false;
end

main.index.getItemArrayFromBags = function(bagArray)
    local itemArray = {};
    local itemAmount = 0;
    for key = 0, 4, 1
    do
        local slots = bagArray[key]["maxSlots"];
        local slotArray = bagArray[key]["slotArray"];
        for slotKey = 1, slots, 1
        do
            local currentSlot = slotArray[slotKey]["currentSlot"];
            local currentBag = slotArray[slotKey]["currentBag"];
            local itemID = c.GetContainerItemID(currentBag, currentSlot);
            if itemID ~= nil then
                itemAmount = itemAmount + 1;
                local itemName, _, itemRarity, itemLevel, _, itemType, itemSubType, _, _, _, _, e, enum = GetItemInfo(
                    itemID);
                table.insert(itemArray, {
                    ["currentSlot"] = currentSlot,
                    ["currentBag"] = currentBag,
                    ["itemName"] = itemName,
                    ["itemRarity"] = itemRarity,
                    ["itemLevel"] = itemLevel,
                    ["itemType"] = itemType,
                    ["itemSubType"] = itemSubType,
                    ["itemID"] = itemID,
                    ["mount"] = IsMount(itemName),
                });
            end
        end
    end
    return itemArray, itemAmount;
end

local function TypeChecker(typeString)
    --possible types: "Armor", "Consumable", "Container", "Gem", "Key", "Miscellaneous", "Money", "Reagent", "Recipe", "Projectile", "Quest", "Quiver", "Trade Goods", "Weapon"
    local types = { "Quest", "Consumable", "Weapon", "Armor", "Trade Goods", "Container", "Gem", "Key", "Money",
        "Reagent",
        "Recipe", "Projectile", "Quiver", "Miscellaneous" }
    local returnNumb = nil;
    for key = 1, 14, 1
    do
        if typeString == types[key] then
            returnNumb = key;
            return key;
        end
    end
    return returnNumb;
end

local function CompareItems(item, compareItem)
    --if item is should go before this one return true, else return false
    --sorting order is: Hearthstones and mount go first, as travelling items go first in retail
    --then consumables > equipment > trade goods > the rest
    --within category its not completely clear but its something like subtype > alphabetical, i'm personally making it subtype > rarity > alphabetical
    --item rarity starts at 0 with gray and then goes up

    --its also important to note that lua sorts asciibetically, so uppercase letters are considered smaller than lowercase letters
    --this does not usually matter as generally the first letter is capitalized and nothing else
    --but it might be relevant if there's a multi word item that gets sorted weirdly
    -----------------------------------------------------
    local itemName, itemType, subType, rarity, mount =
        item["itemName"], item["itemType"], item["itemSubType"], item["itemRarity"], item["mount"];
    local compareItemName, compareItemType, compareItemSubType, compareItemRarity, compareMount =
        compareItem["itemName"], compareItem["itemType"], compareItem["itemSubType"], compareItem["itemRarity"],
        compareItem["mount"];
    local checkedType = TypeChecker(itemType);
    local checkedCompareType = TypeChecker(compareItemType);
    if compareItemName == "Hearthstone" then
        return false;
    elseif itemName == "Hearthstone" then
        return true;
    elseif mount then
        if compareMount then
            if rarity > compareItemRarity then
                return true;
            elseif rarity == compareItemRarity then
                if itemName < compareItemName then
                    return true;
                else
                    return false;
                end;
            else
                return false;
            end
        else
            return true;
        end
    elseif compareMount then
        return false;
    elseif checkedType then
        if checkedType < checkedCompareType then
            return true;
        elseif checkedType == checkedCompareType then
            if subType < compareItemSubType then
                return true;
            elseif subType == compareItemSubType then
                if rarity > compareItemRarity then
                    return true;
                elseif rarity == compareItemRarity then
                    if itemName < compareItemName then
                        return true;
                    end;
                end
            end
        end
    end
    return false;
end

main.index.sortItemArray = function(itemArray)
    local sortedArray = {};
    for key = 1, #itemArray, 1
    do
        local item = itemArray[key];
        local sorted = false;
        for sKey = 1, #sortedArray, 1
        do
            local compareItem = sortedArray[sKey];
            local result = CompareItems(item, compareItem);
            if result == true then
                table.insert(sortedArray, sKey, item);
                sorted = true;
                break;
            end
        end
        if sorted == false then
            table.insert(sortedArray, item);
        end
    end
    return sortedArray;
end
