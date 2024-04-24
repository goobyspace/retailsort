local _, main = ...;
main.sort = {};
local sort = main.sort;
local events = CreateFrame("Frame");
local c = C_Container;
-- there's a lot of inefficincies in this but the main bottleneck is actually moving the items anyway and
-- just looping over arrays is really quick so it doesn't actually matter in the grand scheme of things
local itemsToPush = {};

local function SwapItems()
    if InCombatLockdown() then
        main.ui.CombatBlock();
        itemsToPush = {}; --clear the array, stop doing anything when we're in combat because otherwise we will break your bags to the point of having to relog
        return
    end
    if itemsToPush[1] then
        local item = itemsToPush[1];
        local item2 = { ["currentBag"] = item["futureBag"], ["currentSlot"] = item["futureSlot"] }
        main.utils.swap(item, item2);
        table.remove(itemsToPush, 1);
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

    local orderedBags = { [1] = 0, [2] = 1, [3] = 2, [4] = 3, [5] = 4 };
    for orderedKey = 1, 5, 1 do --make sure to do the profession bags first
        local _, bagFamily = c.GetContainerNumFreeSlots(orderedKey - 1);
        local bagKey = orderedKey - 1;
        local bagLength = #bagArray[bagKey]["slotArray"];
        if bagFamily ~= 0 then
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
        end
    end
    for orderedKey = 1, 5, 1 do -- now do the rest of the bags in the same way
        local bagType = main.currentBagSettingArray[orderedKey]["type"];
        local _, bagFamily = c.GetContainerNumFreeSlots(orderedKey - 1);
        local bagKey = orderedKey - 1;
        local bagLength = #bagArray[bagKey]["slotArray"];
        if bagFamily ~= 0 then
        elseif bagType ~= nil and bagType ~= false then
            local itemFound = nil;
            local sortKey = 1;
            for slotKey = 1, bagLength, 1 do
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
    else
        --put down items
    end
end

function sort:Sort()
    local bagArray, totalSlots = main.index.getBagSlots();
    local itemArray, totalItems = main.index.getItemArrayFromBags(bagArray);
    local sortedArray = main.index.sortItemArray(itemArray);
    itemArrayToBags(sortedArray, bagArray);
end
