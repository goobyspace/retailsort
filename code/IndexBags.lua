local _, main = ...;
main.index = {};
local trace = main.trace;

main.index.getBagSlots = function()
    local bagArray = {};
    local totalSlots = 0;
    for bagKey = 0, 4, 1
    do
        local currentBag = main.wow.GetContainerNumSlots(bagKey);
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

--maps an item's itemType to the bag "type" setting it belongs in, mirrors the mapping used when assigning slots
local itemTypeToBagType = {
    ["Quest"] = "Quest",
    ["Consumable"] = "Consumable",
    ["Weapon"] = "Equipment",
    ["Armor"] = "Equipment",
    ["Trade Goods"] = "Trade Goods",
};

local function IsMount(itemName)
    --the mount item type isnt for classic era mounts, just for ones like on retail that you 'learn' so we have to check the name
    --should remove this check for cata
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
            local _, family = main.wow.GetContainerNumFreeSlots(slotArray[slotKey]["currentBag"]);
            local containerInfo = main.wow.GetContainerItemInfo(currentBag, currentSlot);
            if containerInfo ~= nil then
                local itemID = containerInfo["itemID"];
                itemAmount = itemAmount + 1;
                local itemName, _, itemRarity, itemLevel, _, itemType, itemSubType, maxStack, _, _, _, e, enum =
                    main.wow.GetItemInfo(itemID);
                local newItem = {
                    ["currentSlot"] = currentSlot,
                    ["currentBag"] = currentBag,
                    ["itemName"] = itemName,
                    ["itemRarity"] = itemRarity,
                    ["itemLevel"] = itemLevel,
                    ["itemType"] = itemType,
                    ["itemSubType"] = itemSubType,
                    ["itemID"] = itemID,
                    ["mount"] = IsMount(itemName),
                    ["maxStack"] = maxStack,
                    ["currentStack"] = containerInfo["stackCount"],
                    ["correctFamily"] = family == main.wow.GetItemFamily(itemID),
                    ["correctBagType"] = itemTypeToBagType[itemType] ~= nil and
                        main.currentBagSettingArray[currentBag + 1]["type"] == itemTypeToBagType[itemType],
                }
                table.insert(itemArray, newItem);
            end
        end
    end
    return itemArray, itemAmount;
end

--merges are planned instead of performed, because a slot stays locked until the server confirms the
--previous merge and any swap issued against it in the meantime is silently dropped
main.index.planStackMerges = function(itemArray)
    local moves = {};
    local partialsByID = {};
    local orderedIDs = {};
    for key = 1, #itemArray, 1 do
        local item = itemArray[key];
        local maxStack = item["maxStack"] or 1;
        if maxStack > 1 and item["currentStack"] < maxStack then
            local itemID = item["itemID"];
            if partialsByID[itemID] == nil then
                partialsByID[itemID] = {};
                table.insert(orderedIDs, itemID);
            end
            table.insert(partialsByID[itemID], key);
        end
    end

    local absorbed = {};
    for idKey = 1, #orderedIDs, 1 do
        local partials = partialsByID[orderedIDs[idKey]];
        while #partials > 1 do
            table.sort(partials, function(a, b)
                return itemArray[a]["currentStack"] > itemArray[b]["currentStack"];
            end);
            --emptying the smallest stack first costs one move per stack removed, which is the minimum
            local source = itemArray[partials[#partials]];
            local targetKey = nil;
            for key = 1, #partials - 1, 1 do
                local target = itemArray[partials[key]];
                if target["currentStack"] + source["currentStack"] <= target["maxStack"] then
                    targetKey = key;
                    break;
                end
            end
            if targetKey == nil then
                trace:AddFormat('  merge: %s x%d at [%d,%d] has no partial stack able to hold it (maxStack=%s)',
                    tostring(source["itemName"]), source["currentStack"], source["currentBag"], source["currentSlot"],
                    tostring(source["maxStack"]));
                break; --nothing can hold the smallest stack, so nothing can hold the bigger ones either
            end
            local target = itemArray[partials[targetKey]];
            trace:AddFormat('  merge: %s x%d [%d,%d] -> x%d [%d,%d] (maxStack=%s, result x%d)',
                tostring(source["itemName"]), source["currentStack"], source["currentBag"], source["currentSlot"],
                target["currentStack"], target["currentBag"], target["currentSlot"],
                tostring(target["maxStack"]), target["currentStack"] + source["currentStack"]);
            table.insert(moves, {
                { ["currentBag"] = source["currentBag"], ["currentSlot"] = source["currentSlot"] },
                { ["currentBag"] = target["currentBag"], ["currentSlot"] = target["currentSlot"] },
            });
            target["currentStack"] = target["currentStack"] + source["currentStack"];
            absorbed[partials[#partials]] = true;
            table.remove(partials, #partials);
        end
    end

    local remaining = {};
    for key = 1, #itemArray, 1 do
        if absorbed[key] == nil then
            table.insert(remaining, itemArray[key]);
        end
    end
    return remaining, moves;
end

local function TypeChecker(typeString)
    --possible types: "Armor", "Consumable", "Container", "Gem", "Key", "Miscellaneous", "Money", "Reagent", "Recipe", "Projectile", "Quest", "Quiver", "Trade Goods", "Weapon", "Permanent", "Glyph", "Battle Pets", "WoW Token", "Profession"
    local types = { "Quest", "Consumable", "Weapon", "Armor", "Trade Goods", "Container", "Gem", "Key", "Money",
        "Reagent", "Recipe", "Profession", "Glyph", "Battle Pets", "Projectile", "Quiver", "Miscellaneous", "Permanent",
        "WoW Token" }
    local returnNumb = 20;
    for key = 1, 19, 1
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
    local itemName, itemType, subType, rarity, mount, family, slot, stack, bag, correctBagType =
        item["itemName"], item["itemType"], item["itemSubType"], item["itemRarity"], item["mount"],
        item["correctFamily"], item["currentSlot"], item["currentStack"], item["currentBag"], item["correctBagType"];
    local compareItemName, compareItemType, compareItemSubType, compareItemRarity, compareMount,
    compareFamily, compareSlot, compareStack, compareBag, compareCorrectBagType =
        compareItem["itemName"], compareItem["itemType"], compareItem["itemSubType"], compareItem["itemRarity"],
        compareItem["mount"], compareItem["correctFamily"], compareItem["currentSlot"], compareItem["currentStack"],
        compareItem["currentBag"], compareItem["correctBagType"];
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
                    elseif itemName == compareItemName then
                        if stack > compareStack then
                            return true
                        elseif stack == compareStack then
                            if bag == compareBag then
                                if slot < compareSlot then
                                    return true;
                                end
                            elseif family ~= compareFamily then
                                --prefer the item already in its correct family bag
                                if family then
                                    return true;
                                end
                            elseif correctBagType ~= compareCorrectBagType then
                                --identical stacks: keep the one already in its correctly-typed bag there instead of swapping it out
                                if correctBagType then
                                    return true;
                                end
                            elseif bag < compareBag then
                                return true;
                            end
                        end
                    end
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
    if trace:IsActive() then
        trace:Add('  desired order (index -> item, current position):');
        for key = 1, #sortedArray, 1 do
            local item = sortedArray[key];
            trace:AddFormat('    %2d. %s x%d  (now at [%d,%d], id=%s, %s/%s)', key, tostring(item["itemName"]),
                item["currentStack"], item["currentBag"], item["currentSlot"], tostring(item["itemID"]),
                tostring(item["itemType"]), tostring(item["itemSubType"]));
        end
    end
    return sortedArray;
end
