local _, main = ...;
main.sort = {};
local sort = main.sort;
local events = CreateFrame("Frame");
local c = C_Container;
-- there's a lot of inefficincies in this but the main bottleneck is actually moving the items anyway and
-- just looping over arrays is really quick so it doesn't actually matter in the grand scheme of things
--the plan is a list of waves; every swap inside a wave touches slots no other swap in that wave touches,
--so a whole wave can be fired in one frame and we only pay one server round trip per wave instead of per item
local movePlan = {};
local slotWave = {};
local planLength = 0;
local planGeneration = 0;
local waveKey = 1;
local lockRetries = 0;
local swapsDone = 0;
local sortPasses = 0;
local sortQueued = false;
local planOnFinish = nil;
local MAX_LOCK_RETRIES = 20;
local MAX_SORT_PASSES = 10;
local MAX_SETTLE_TRIES = 30;
local RunSort; --defined below, the planner it needs lives between here and there
local RunWave;

local function ClearPlan()
    movePlan = {};
    slotWave = {};
    for bagKey = 0, 4, 1 do
        slotWave[bagKey] = {};
    end
    planLength = 0;
    planGeneration = planGeneration + 1;
    waveKey = 1;
    lockRetries = 0;
    swapsDone = 0;
    planOnFinish = nil;
end

--a slot may only be touched once per wave, and never before the wave that last changed it
local function AddMove(fromBag, fromSlot, toBag, toSlot, minWave)
    local wave = minWave or 1;
    local usedFrom = slotWave[fromBag][fromSlot] or 0;
    local usedTo = slotWave[toBag][toSlot] or 0;
    if usedFrom >= wave then wave = usedFrom + 1 end
    if usedTo >= wave then wave = usedTo + 1 end
    slotWave[fromBag][fromSlot] = wave;
    slotWave[toBag][toSlot] = wave;
    if movePlan[wave] == nil then movePlan[wave] = {} end
    if wave > planLength then planLength = wave end
    table.insert(movePlan[wave], {
        { ["currentBag"] = fromBag, ["currentSlot"] = fromSlot },
        { ["currentBag"] = toBag,   ["currentSlot"] = toSlot },
    });
    return wave;
end

local function StopListening()
    events:UnregisterEvent("BAG_UPDATE_COOLDOWN");
    events:UnregisterEvent("BAG_UPDATE");
end

local function AnySlotLocked()
    for bagKey = 0, 4, 1 do
        local slots = c.GetContainerNumSlots(bagKey) or 0;
        for slotKey = 1, slots, 1 do
            local info = c.GetContainerItemInfo(bagKey, slotKey);
            if info ~= nil and info["isLocked"] == true then
                return true;
            end
        end
    end
    return false;
end

--a swap is only real once the server clears the lock, so indexing before that reads the bag as it was
--before the swap and plans moves that undo it
local function WhenSettled(callback)
    if sortQueued then return end
    StopListening();
    ClearPlan();
    sortQueued = true;
    local tries = 0;
    local function attempt()
        if tries >= MAX_SETTLE_TRIES or not AnySlotLocked() then
            sortQueued = false;
            callback();
            return
        end
        tries = tries + 1;
        C_Timer.After(0.1, attempt);
    end
    attempt();
end

local function StartSort(isVerification)
    WhenSettled(function()
        RunSort(isVerification);
    end);
end

--every item that is not already home is part of a cycle or of a chain that ends in a free slot
local function PlanItemMoves(itemArray)
    local currentItem = {}; --currentItem[bag][slot] is the itemArray key sitting in that slot
    for bagKey = 0, 4, 1 do
        currentItem[bagKey] = {};
    end
    for key = 1, #itemArray, 1 do
        local item = itemArray[key];
        currentItem[item["currentBag"]][item["currentSlot"]] = key;
    end

    local visited = {};
    for key = 1, #itemArray, 1 do
        if visited[key] == nil then
            local step = 1;
            local currentKey = key;
            while currentKey ~= nil and visited[currentKey] == nil do
                visited[currentKey] = true;
                local item = itemArray[currentKey];
                local currentBag, currentSlot = item["currentBag"], item["currentSlot"];
                local futureBag, futureSlot = item["futureBag"], item["futureSlot"];
                if futureBag == nil or (currentBag == futureBag and currentSlot == futureSlot) then
                    break;
                end
                step = AddMove(currentBag, currentSlot, futureBag, futureSlot, step) + 1;

                local displacedKey = currentItem[futureBag][futureSlot];
                currentItem[futureBag][futureSlot] = currentKey;
                currentItem[currentBag][currentSlot] = displacedKey;
                item["currentBag"], item["currentSlot"] = futureBag, futureSlot;
                if displacedKey ~= nil then
                    local displaced = itemArray[displacedKey];
                    displaced["currentBag"], displaced["currentSlot"] = currentBag, currentSlot;
                end
                if displacedKey then
                    currentKey = displacedKey;
                end
            end
        end
    end
end

local function StartPlan(onFinish)
    if planLength > 0 then
        planOnFinish = onFinish;
        events:RegisterEvent("BAG_UPDATE_COOLDOWN");
        events:RegisterEvent("BAG_UPDATE");
        events:SetScript("OnEvent", function()
            RunWave();
        end);
        RunWave(); --call it once to trigger the events
    else
        sortPasses = 0;
    end
end

local function FinishPlan()
    local moved = swapsDone;
    local onFinish = planOnFinish;
    StopListening();
    ClearPlan();
    if moved > 0 and onFinish ~= nil then
        onFinish();     --a refused or interrupted swap can leave items behind, so verify by planning again
    else
        sortPasses = 0; --nothing moved, so another pass would only plan the exact same swaps again
    end
end

RunWave = function()
    if InCombatLockdown() then
        main.ui.CombatBlock();
        StopListening();
        ClearPlan(); --stop doing anything when we're in combat because otherwise we will break your bags to the point of having to relog
        sortPasses = 0;
        return
    end
    while waveKey <= planLength and movePlan[waveKey] == nil do
        waveKey = waveKey + 1;
    end
    if waveKey > planLength then
        FinishPlan();
        return
    end
    local wave = movePlan[waveKey];
    local locked = {};
    for key = 1, #wave, 1 do
        local move = wave[key];
        if main.utils.swap(move[1], move[2]) then
            swapsDone = swapsDone + 1;
        else
            table.insert(locked, move);
        end
    end
    if #locked == 0 then
        movePlan[waveKey] = nil;
        waveKey = waveKey + 1;
        lockRetries = 0;
        return
    end
    movePlan[waveKey] = locked; --slots that were locked get retried, the rest of the wave is done
    lockRetries = lockRetries + 1;
    if lockRetries > MAX_LOCK_RETRIES then
        FinishPlan();
    elseif #locked == #wave then
        --nothing moved, so no BAG_UPDATE is coming to drive the next attempt
        local generation = planGeneration;
        C_Timer.After(0.1, function()
            if generation == planGeneration then
                RunWave();
            end
        end);
    end
end

local function itemArrayToBags(itemArray, bagArray, mergeMoves)
    for key = 1, #mergeMoves, 1 do
        local move = mergeMoves[key];
        AddMove(move[1]["currentBag"], move[1]["currentSlot"], move[2]["currentBag"], move[2]["currentSlot"], 1);
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
                        local itemFamily = C_Item.GetItemFamily(item["itemID"]);
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

    --walk the permutation cycle by cycle: a cycle of n items always costs exactly n-1 swaps and a chain
    --that ends in a free slot costs its own length, which is the minimum possible number of moves
    PlanItemMoves(itemArray);
    StartPlan(function() StartSort(true) end);
end

RunSort = function(isVerification)
    if isVerification then
        sortPasses = sortPasses + 1;
        if sortPasses > MAX_SORT_PASSES then
            sortPasses = 0; --something outside our control keeps changing the bags, give up instead of looping forever
            return
        end
    else
        sortPasses = 0;
    end
    ClearPlan();
    local bagArray, totalSlots = main.index.getBagSlots();
    local itemArray, totalItems = main.index.getItemArrayFromBags(bagArray);
    --merging first, so the stack sizes the sort order depends on are the ones we will actually end up with
    local mergedArray, mergeMoves = main.index.planStackMerges(itemArray);
    local sortedArray = main.index.sortItemArray(mergedArray);
    itemArrayToBags(sortedArray, bagArray, mergeMoves);
end

function sort:Sort()
    StartSort(false);
end

--debug only: put items back where a pasted layout says they were, so a bag state can be replayed
local restoreLayout = nil;
local restorePasses = 0;
local StartRestore;

local function RunRestore()
    if restoreLayout == nil then return end
    ClearPlan();
    local bagArray = main.index.getBagSlots();
    local itemArray = main.index.getItemArrayFromBags(bagArray);

    local byItemID = {};
    for key = 1, #itemArray, 1 do
        local itemID = itemArray[key]["itemID"];
        if byItemID[itemID] == nil then byItemID[itemID] = {} end
        table.insert(byItemID[itemID], key);
    end

    local taken = {};
    local missing = 0;
    for bagKey = 0, 4, 1 do
        local targetBag = restoreLayout[bagKey];
        if targetBag ~= nil then
            for slotKey = 1, #bagArray[bagKey]["slotArray"], 1 do
                local target = targetBag[slotKey];
                if target ~= nil then
                    local candidates = byItemID[target["itemID"]] or {};
                    local chosen = nil;
                    for pass = 1, 2, 1 do --an exact stack size is the better match, but any stack beats leaving the slot empty
                        for key = 1, #candidates, 1 do
                            local candidate = candidates[key];
                            if taken[candidate] == nil and
                                (pass == 2 or itemArray[candidate]["currentStack"] == target["qty"]) then
                                chosen = candidate;
                                break;
                            end
                        end
                        if chosen ~= nil then break end
                    end
                    if chosen == nil then
                        missing = missing + 1;
                    else
                        taken[chosen] = true;
                        itemArray[chosen]["futureBag"] = bagKey;
                        itemArray[chosen]["futureSlot"] = slotKey;
                        bagArray[bagKey]["slotArray"][slotKey]["Assigned"] = true;
                    end
                end
            end
        end
    end

    local extra = 0;
    for key = 1, #itemArray, 1 do
        if taken[key] == nil then
            extra = extra + 1;
            for bagKey = 0, 4, 1 do
                local slotArray = bagArray[bagKey]["slotArray"];
                local placed = false;
                for slotKey = 1, #slotArray, 1 do
                    if slotArray[slotKey]["Assigned"] == nil then
                        slotArray[slotKey]["Assigned"] = true;
                        itemArray[key]["futureBag"] = bagKey;
                        itemArray[key]["futureSlot"] = slotKey;
                        taken[key] = true;
                        placed = true;
                        break;
                    end
                end
                if placed then break end
            end
        end
    end

    PlanItemMoves(itemArray);
    if restorePasses <= 1 then
        print(string.format(
            "|cff00cc66Retail Sort restore:|r %d moves planned, %d layout slots unmatched, %d items not in the layout.",
            planLength, missing, extra));
    end
    StartPlan(function() StartRestore(true) end);
end

StartRestore = function(isVerification)
    if isVerification then
        restorePasses = restorePasses + 1;
        if restorePasses > MAX_SORT_PASSES then
            restorePasses = 0;
            return
        end
    else
        restorePasses = 0;
    end
    WhenSettled(RunRestore);
end

function sort:Restore(layout)
    restoreLayout = layout;
    StartRestore(false);
end
