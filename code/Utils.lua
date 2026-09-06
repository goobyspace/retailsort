local _, main = ...;
main.utils = {};

--records what the sorter decided and did, so a full run can be pasted out of the game and read back
local trace = { active = false, lines = {}, truncated = false };
local TRACE_MAX_LINES = 4000;
main.trace = trace;

function trace:Start()
    self.active = true;
    self.lines = {};
    self.truncated = false;
end

function trace:IsActive()
    return self.active == true;
end

function trace:Add(text)
    if not self.active then return end
    if #self.lines >= TRACE_MAX_LINES then
        self.truncated = true;
        return
    end
    table.insert(self.lines, text);
end

function trace:AddFormat(format, ...)
    if not self.active then return end
    local ok, text = pcall(string.format, format, ...);
    self:Add(ok and text or format);
end

function trace:Stop()
    self.active = false;
end

function trace:GetText()
    if self.truncated then
        local capped = {};
        for key = 1, #self.lines, 1 do capped[key] = self.lines[key] end
        table.insert(capped, string.format('... trace truncated at %d lines ...', TRACE_MAX_LINES));
        return table.concat(capped, '\n');
    end
    return table.concat(self.lines, '\n');
end

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

--summarizes each bag's slot count, free slots, family and configured type/ignore setting
main.utils.getBagSettingsDump = function()
    local lines = {};
    for bag = 0, 4, 1 do
        local numSlots = main.wow.GetContainerNumSlots(bag) or 0;
        local free, family = main.wow.GetContainerNumFreeSlots(bag);
        local setting = main.currentBagSettingArray and main.currentBagSettingArray[bag + 1];
        table.insert(lines, string.format('bag %d: %d slot(s), %s free, family=%s, assignedType=%s, ignored=%s',
            bag, numSlots, tostring(free), tostring(family), tostring(setting and setting["type"]),
            tostring(setting and setting["ignore"])));
    end
    return lines;
end

main.utils.getBagLayoutDebugDump = function()
    local lines = main.utils.getBagSettingsDump();

    for bag = 0, 4, 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0;
        table.insert(lines, string.format('Bag %d (%d slots):', bag, numSlots));

        for slot = 1, numSlots, 1 do
            local info = C_Container.GetContainerItemInfo(bag, slot);
            if info and info.itemID then
                local itemName, _, itemRarity, itemLevel, _, itemType, itemSubType, maxStack =
                    C_Item.GetItemInfo(info.itemID);
                itemName = itemName or (C_Item.GetItemNameByID and C_Item.GetItemNameByID(info.itemID)) or 'Unknown';
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
                    string.format(
                        '  slot %02d: %s | itemID=%d | qty=%d | locked=%s | family=%s | type=%s | subType=%s | rarity=%s | ilvl=%s | maxStack=%s | link=%s',
                        slot,
                        itemName,
                        info.itemID,
                        info.stackCount or 0,
                        lockedText,
                        family,
                        itemType or 'unknown',
                        itemSubType or 'unknown',
                        itemRarity or 'unknown',
                        itemLevel or 'unknown',
                        maxStack or 'unknown',
                        itemLink
                    ));
            else
                table.insert(lines, string.format('  slot %02d: empty', slot));
            end
        end
    end

    return table.concat(lines, '\n');
end

--reads back what getBagLayoutDebugDump wrote, into layout[bag][slot] = { itemID, qty, itemType, itemSubType, itemRarity, itemLevel, maxStack }
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
                local itemType = line:match('type=([^|]+)');
                local itemSubType = line:match('subType=([^|]+)');
                local itemRarity = line:match('rarity=([^|]+)');
                local itemLevel = line:match('ilvl=([^|]+)');
                local maxStack = line:match('maxStack=([^|]+)');
                layout[currentBag][tonumber(slot)] = {
                    ["itemID"] = tonumber(itemID),
                    ["qty"] = tonumber(qty),
                    ["itemType"] = itemType and itemType:match('^%s*(.-)%s*$') or nil,
                    ["itemSubType"] = itemSubType and itemSubType:match('^%s*(.-)%s*$') or nil,
                    ["itemRarity"] = tonumber(itemRarity),
                    ["itemLevel"] = tonumber(itemLevel),
                    ["maxStack"] = tonumber(maxStack),
                };
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

    local info1 = main.wow.GetContainerItemInfo(bag1, slot1);
    local info2 = main.wow.GetContainerItemInfo(bag2, slot2);
    local locked1 = (info1 and info1.isLocked == true) or false;
    local locked2 = (info2 and info2.isLocked == true) or false;

    if trace:IsActive() then
        trace:AddFormat('      swap [%d,%d] itemID=%s qty=%s%s  <->  [%d,%d] itemID=%s qty=%s%s',
            bag1, slot1, tostring(info1 and info1.itemID or 'empty'), tostring(info1 and info1.stackCount or 0),
            locked1 and ' LOCKED' or '',
            bag2, slot2, tostring(info2 and info2.itemID or 'empty'), tostring(info2 and info2.stackCount or 0),
            locked2 and ' LOCKED' or '');
    end

    if not locked1 and not locked2 then -- this is necessary as the item can be either nil or false
        main.wow.ClearCursor();
        main.wow.PickupContainerItem(bag1, slot1);
        main.wow.PickupContainerItem(bag2, slot2);
        main.wow.ClearCursor();
        return true;
    end
    trace:Add('        -> skipped, slot locked');
    return false; --caller must not assume the merge/move happened
end
