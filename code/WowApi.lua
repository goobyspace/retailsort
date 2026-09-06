local _, main = ...;
--every direct Blizzard API call used by the sorting logic goes through here, so script.lua can swap this table for a mock
main.wow = {};

main.wow.GetContainerNumSlots = function(bag)
    return C_Container.GetContainerNumSlots(bag);
end

main.wow.GetContainerNumFreeSlots = function(bag)
    return C_Container.GetContainerNumFreeSlots(bag);
end

main.wow.GetContainerItemInfo = function(bag, slot)
    return C_Container.GetContainerItemInfo(bag, slot);
end

main.wow.PickupContainerItem = function(bag, slot)
    C_Container.PickupContainerItem(bag, slot);
end

main.wow.GetItemInfo = function(itemID)
    return C_Item.GetItemInfo(itemID);
end

main.wow.GetItemFamily = function(itemID)
    return C_Item.GetItemFamily(itemID);
end

main.wow.ClearCursor = function()
    ClearCursor();
end

main.wow.InCombatLockdown = function()
    return InCombatLockdown();
end

main.wow.After = function(seconds, callback)
    C_Timer.After(seconds, callback);
end

main.wow.CreateFrame = function(...)
    return CreateFrame(...);
end
