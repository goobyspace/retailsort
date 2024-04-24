local _, main = ...;
main.utils = {};

main.utils.dump = function(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. main.utils.dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

main.utils.swap = function(item1, item2)
    local bag1, slot1, bag2, slot2 = item1["currentBag"], item1["currentSlot"],
        item2["currentBag"], item2["currentSlot"];
    local _, _, locked1 = C_Container.GetContainerItemInfo(bag1, slot1);
    local _, _, locked2 = C_Container.GetContainerItemInfo(bag2, slot2);
    if locked1 ~= true and locked2 ~= true then --this is neccesary as the item can be either nil or false
        ClearCursor()
        C_Container.PickupContainerItem(bag1, slot1)
        C_Container.PickupContainerItem(bag2, slot2)
        ClearCursor()
    end
end
