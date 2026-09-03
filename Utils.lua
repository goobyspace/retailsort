local _, main = ...;
main.utils = {};

main.utils.dump = function(o, seen)
    if o == nil then
        return 'nil';
    end
    if type(o) ~= 'table' then
        return tostring(o);
    end

    seen = seen or {};
    if seen[o] then
        return '<cycle>';
    end
    seen[o] = true;

    local s = '{ ';
    local first = true;
    for k, v in pairs(o) do
        if not first then
            s = s .. ', ';
        end
        local keyText = type(k) == 'number' and '[' .. tostring(k) .. ']' or
            '[' .. string.format('%q', tostring(k)) .. ']';
        s = s .. keyText .. ' = ' .. main.utils.dump(v, seen);
        first = false;
    end
    return s .. ' }';
end

main.utils.getBagLayoutDebugDump = function()
    local lines = {};

    for bag = 0, 4, 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0;
        table.insert(lines, string.format('Bag %d (%d slots):', bag, numSlots));

        for slot = 1, numSlots, 1 do
            local info = C_Container.GetContainerItemInfo(bag, slot);
            if info and info.itemID then
                local itemName = C_Item.GetItemNameByID and C_Item.GetItemNameByID(info.itemID) or
                    (select(1, GetItemInfo(info.itemID)) or 'Unknown');
                local family = C_Item.GetItemFamily and C_Item.GetItemFamily(info.itemID) or 'unknown';
                local lockedText = info.isLocked and 'locked' or 'unlocked';

                local itemLink = '';
                if C_Item.GetItemLink then
                    local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot);
                    if itemLocation then
                        local ok, result = pcall(C_Item.GetItemLink, itemLocation);
                        if ok and result then
                            itemLink = result;
                        end
                    end
                end

                table.insert(lines,
                    string.format('  slot %02d: %s | itemID=%d | qty=%d | locked=%s | family=%s | link=%s',
                        slot,
                        itemName,
                        info.itemID,
                        info.stackCount or 0,
                        lockedText,
                        family,
                        itemLink
                    ));
            else
                table.insert(lines, string.format('  slot %02d: empty', slot));
            end
        end
    end

    return table.concat(lines, '\n');
end

--reads back what getBagLayoutDebugDump wrote, into layout[bag][slot] = { itemID, qty }
main.utils.parseBagLayoutDump = function(text)
    if type(text) ~= 'string' then
        return nil, 'no text to read';
    end

    local layout = {};
    local currentBag = nil;
    local entries = 0;
    for line in text:gmatch('[^\r\n]+') do
        local bag = tonumber(line:match('^%s*Bag%s+(%d+)%s*%(') or '');
        if bag ~= nil then
            currentBag = bag;
            layout[currentBag] = {};
        elseif currentBag ~= nil then
            local slot, itemID, qty = line:match('^%s*slot%s+(%d+):.*itemID=(%d+).*qty=(%d+)');
            if slot then
                layout[currentBag][tonumber(slot)] = { ["itemID"] = tonumber(itemID), ["qty"] = tonumber(qty) };
                entries = entries + 1;
            end
        end
    end

    if entries == 0 then
        return nil, 'found no "slot NN: ... itemID=N ... qty=N" lines';
    end
    return layout, entries;
end

main.utils.copyTextToClipboard = function(text)
    if type(text) ~= 'string' or text == '' then
        return false;
    end

    local ok, err = pcall(function()
        if CopyToClipboard then
            CopyToClipboard(text);
            return true;
        end
        return false;
    end);

    if ok and err == true then
        return true;
    end

    local chatBox = ChatEdit_ChooseBoxForSend(DEFAULT_CHAT_FRAME);
    if chatBox then
        chatBox:SetText(text);
        chatBox:HighlightText();
        chatBox:SetFocus();
        return true;
    end

    return false;
end

main.utils.swap = function(item1, item2)
    if type(item1) ~= 'table' or type(item2) ~= 'table' then
        return false;
    end

    local bag1, slot1 = item1["currentBag"], item1["currentSlot"];
    local bag2, slot2 = item2["currentBag"], item2["currentSlot"];
    if bag1 == nil or slot1 == nil or bag2 == nil or slot2 == nil then
        return false;
    end

    local info1 = C_Container.GetContainerItemInfo(bag1, slot1);
    local info2 = C_Container.GetContainerItemInfo(bag2, slot2);
    local locked1 = (info1 and info1.isLocked == true) or false;
    local locked2 = (info2 and info2.isLocked == true) or false;

    if not locked1 and not locked2 then -- this is necessary as the item can be either nil or false
        ClearCursor();
        C_Container.PickupContainerItem(bag1, slot1);
        C_Container.PickupContainerItem(bag2, slot2);
        ClearCursor();
        return true;
    end
    return false; --caller must not assume the merge/move happened
end
