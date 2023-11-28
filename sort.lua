local _, main = ...;
main.sort = {};
local sort = main.sort;
local events = CreateFrame("Frame");
local currentBagSettingArray = main.currentBagSettingArray;
local c = C_Container;
--TODO: Stack combining

-- there's a lot of inefficincies in this but the main bottleneck is actually moving the items anyway and
-- just looping over arrays is really quick so it doesn't actually matter in the grand scheme of things
local itemsToPush = {};

local function SwapItems()
    if itemsToPush[1] then
        local item = itemsToPush[1];
        local bag1, slot1, bag2, slot2 = item["currentBag"], item["currentSlot"], item["futureBag"], item["futureSlot"];
        local _, _, locked1 = c.GetContainerItemInfo(bag1, slot1);
        local _, _, locked2 = c.GetContainerItemInfo(bag2, slot2);
        if locked1 ~= true and locked2 ~= true then --this is neccesary as the item can be either nil or false
            ClearCursor()
            c.PickupContainerItem(bag1, slot1)
            c.PickupContainerItem(bag2, slot2)
            table.remove(itemsToPush, 1);
        end
    else
        events:UnregisterEvent("BAG_UPDATE_COOLDOWN");
        events:UnregisterEvent("BAG_UPDATE");
        --call that checks if everything is actually sorted and if not just sorts again, sometimes it just breaks mid-sort without this
        sort:Sort();
    end
end

local function itemArrayToBags(itemArray, bagArray)
    --TODO: I think this is logical and works but sometimes it doesn't work so maybe draw the logic out at some point since it was written at 3am
    -- Currently working because we just keep doing it until it's done, but really it should be able to sort it in one go
    for key = 1, #itemArray, 1 --first we make sure that we know what item is currently in a slot
    do
        local item = itemArray[key];
        local currentBag = item["currentBag"];
        local currentSlot = item["currentSlot"];
        bagArray[currentBag]["slotArray"][currentSlot]["currentItem"] = key;
    end
    local alteredBags = 0;
    local orderedBags = {};
    for orderedKey = 1, 5, 1 do
        local bagType = currentBagSettingArray[orderedKey]["type"];
        local _, bagFamily = c.GetContainerNumFreeSlots(orderedKey - 1); --goes from 0-4 instead of 1-5
        local bagKey = orderedKey - 1;
        local currentBag = bagArray[bagKey];
        local bagLength = #bagArray[bagKey]["slotArray"];
        if bagFamily ~= 0 then
            alteredBags = alteredBags + 1;
            table.insert(orderedBags, orderedKey, currentBag["currentBag"]); --this makes sure that the bags that are assigned slots are at the end of the array of bags
            local itemFound = nil;
            local sortKey = 1;
            for slotKey = 1, bagLength, 1
            do
                while true do --keep going until you find an item that hasn't been assigned yet or there are no more items
                    if itemArray[sortKey] and itemArray[sortKey]["Assigned"] == nil then
                        local item = itemArray[sortKey];
                        local itemFamily = GetItemFamily(item["itemID"]);
                        if itemFound == true and itemFamily ~= bagFamily then
                            break;
                        elseif itemFamily == bagFamily then
                            itemFound = true;
                            if itemArray[sortKey] and itemArray[sortKey]["Assigned"] == nil and bagArray[bagKey]["slotArray"][slotKey]["Assigned"] == nil then
                                itemArray[sortKey]["futureBag"] = bagKey;
                                itemArray[sortKey]["futureSlot"] = slotKey;
                                itemArray[sortKey]["Assigned"] = true;
                                bagArray[bagKey]["slotArray"][slotKey]["Assigned"] = true;
                                break;
                            end
                        end
                        sortKey = sortKey + 1;
                    elseif itemArray[sortKey] and itemArray[sortKey]["Assigned"] == true then
                        sortKey = sortKey + 1;
                    elseif itemArray[sortKey] == nil then
                        break;
                    end
                end
            end
        elseif bagType ~= nil and bagType ~= false then
            alteredBags = alteredBags + 1;
            table.insert(orderedBags, orderedKey, currentBag["currentBag"]); --this makes sure that the bags that are assigned slots are at the end of the array of bags
            local itemFound = nil;
            local sortKey = 1;
            for slotKey = 1, bagLength, 1
            do
                local types = {
                    ["Quest"] = "Quest",
                    ["Consumable"] = "Consumable",
                    ["Weapon"] = "Equipment",
                    ["Armor"] =
                    "Equipment",
                    ["Trade Goods"] = "Trade Goods"
                };
                while true do --keep going until you find an item that hasn't been assigned yet or there are no more items
                    if itemArray[sortKey] and itemArray[sortKey]["Assigned"] == nil then
                        local item = itemArray[sortKey];
                        local itemType = types[item["itemType"]];
                        if itemFound == true and itemType ~= bagType then
                            break;
                        elseif itemType == bagType then
                            itemFound = true;
                            if itemArray[sortKey] and itemArray[sortKey]["Assigned"] == nil and bagArray[bagKey]["slotArray"][slotKey]["Assigned"] == nil then
                                itemArray[sortKey]["futureBag"] = bagKey;
                                itemArray[sortKey]["futureSlot"] = slotKey;
                                itemArray[sortKey]["Assigned"] = true;
                                bagArray[bagKey]["slotArray"][slotKey]["Assigned"] = true;
                                break;
                            end
                        end
                        sortKey = sortKey + 1;
                    elseif itemArray[sortKey] and itemArray[sortKey]["Assigned"] == true then
                        sortKey = sortKey + 1;
                    elseif itemArray[sortKey] == nil then
                        break;
                    end
                end
            end
        else
            table.insert(orderedBags, orderedKey - alteredBags, currentBag["currentBag"]);
        end
    end

    local sortKey = 1;
    for orderedKey = 1, 5, 1 --then we assign the items to specific slots for the future
    do
        local bagKey = orderedBags[orderedKey];
        local _, bagFamily = c.GetContainerNumFreeSlots(bagKey); --goes from 0-4 instead of 1-5
        if bagFamily == 0 then
            local currentBag = bagArray[bagKey]["slotArray"];
            local bagLength = #currentBag;
            for slotKey = 1, bagLength, 1
            do
                if bagArray[bagKey]["slotArray"][slotKey]["Assigned"] == nil then
                    while true do --keep going until you find an item that hasn't been assigned yet or there are no more items
                        if itemArray[sortKey] and itemArray[sortKey]["Assigned"] == nil then
                            itemArray[sortKey]["futureBag"] = bagKey;
                            itemArray[sortKey]["futureSlot"] = slotKey;
                            itemArray[sortKey]["Assigned"] = true;
                            bagArray[bagKey]["slotArray"][slotKey]["Assigned"] = true;
                            sortKey = sortKey + 1;
                            break;
                        elseif itemArray[sortKey] and itemArray[sortKey]["Assigned"] == true then
                            sortKey = sortKey + 1;
                        else
                            break;
                        end
                    end
                end
            end
        end
    end

    for key = 1, #itemArray, 1 --finally we make a list of all items, including finding out if items will be swapped on the same slot
    do
        local function setItem(localItem)
            if localItem["Placed"] == nil and localItem["Pushed"] == nil then
                local currentBag = localItem["currentBag"];
                local currentSlot = localItem["currentSlot"];
                local futureBag = localItem["futureBag"];
                local futureSlot = localItem["futureSlot"];
                if currentBag == futureBag and currentSlot == futureSlot then
                    localItem["Placed"] = true;
                else
                    localItem["Pushed"] = true;
                    table.insert(itemsToPush, localItem);
                    local newKey = bagArray[futureBag]["slotArray"][futureSlot]["currentItem"];
                    if newKey == nil then return end;
                    local newItem = itemArray[newKey];
                    local newFutureBag = newItem["futureBag"];
                    local newFutureSlot = newItem["futureSlot"]
                    if newItem["Pushed"] == false and newFutureBag == currentBag and newFutureSlot == currentSlot then
                        newItem["Placed"] = true;
                    elseif newItem["Pushed"] == true then
                        newItem["Placed"] = true;
                    else
                        itemArray[newKey]["currentBag"] = currentBag;
                        itemArray[newKey]["currentSlot"] = currentSlot;
                        setItem(newItem);
                    end
                end
            end
        end
        local item = itemArray[key];
        setItem(item);
    end
    --infinite loop protection for kind of ugly solution
    --to-do: fix sorting so we only need to do it once
    local itemAmount = table.getn(itemsToPush);
    if itemAmount > 0 then
        events:RegisterEvent("BAG_UPDATE_COOLDOWN");
        events:RegisterEvent("BAG_UPDATE");
        events:SetScript("OnEvent", function()
            SwapItems();
        end);
        SwapItems(); --call it once to trigger the events
    end
end

function sort:Sort()
    local bagArray, totalSlots = main.index.GetBagSlots();
    local itemArray, totalItems = main.index.GetItemArrayFromBags(bagArray);
    local sortedArray = main.index.sortItemArray(itemArray);
    itemArrayToBags(sortedArray, bagArray);
end
