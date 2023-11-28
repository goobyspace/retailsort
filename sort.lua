local _, main = ...;
main.sort = {};
local sort = main.sort;
local events = CreateFrame("Frame");
local currentBagSettingArray;
local c = C_Container;
--TODO: Stack combining
--TODO: Implement quiver/soulstone bag/etc so proff items get put in a proff bag

--all of this could probably be done in half the amount of loops
--but i guess i was feeling loopy when i made this :D
--+ the main bottleneck is actually moving the items anyway and just looping over arrays is really quick so it doesn't actually matter in the grand scheme of things
local itemsToPush = {};

local function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end


local function GetBagSlots()
   local bagArray = {};
   local totalSlots = 0;
   for bagKey=0,4,1 
   do
      local currentBag = c.GetContainerNumSlots(bagKey);
      local _, family = c.GetContainerNumFreeSlots(bagKey);
      local slotArray = {};
      --fill up the bagarray with all the slots, if this is skipped bag will be considered a 0 slot bag
      if currentBagSettingArray[bagKey+1]["ignore"] ~= true then
         for currentSlot = 1,currentBag, 1
         do
            totalSlots = totalSlots + 1;
            table.insert(slotArray,{["currentSlot"] = currentSlot, ["currentBag"] = bagKey});
         end
         bagArray[bagKey] = {["slotArray"] = slotArray, ["maxSlots"] = currentBag, ["currentBag"] = bagKey};
      else
         bagArray[bagKey] = {["slotArray"] = slotArray, ["maxSlots"] = 0, ["currentBag"] = bagKey};
      end
   end
   return bagArray,totalSlots;
end

local function GetItemArrayFromBags(bagArray)
   local itemArray = {};
   local itemAmount = 0;
   for key = 0, 4,1
   do
      local slots = bagArray[key]["maxSlots"];
      local slotArray = bagArray[key]["slotArray"];
      for slotKey = 1,slots,1
      do
         local currentSlot = slotArray[slotKey]["currentSlot"];
         local currentBag = slotArray[slotKey]["currentBag"];
         local itemID = c.GetContainerItemID(currentBag,currentSlot);
         if itemID ~= nil then
            itemAmount = itemAmount + 1;
            local itemName,_,itemRarity,itemLevel,_,itemType,itemSubType = GetItemInfo(itemID);
            table.insert(itemArray,{
               ["currentSlot"] = currentSlot,
               ["currentBag"] = currentBag,
               ["itemName"] = itemName,
               ["itemRarity"] = itemRarity,
               ["itemLevel"] = itemLevel,
               ["itemType"] = itemType,
               ["itemSubType"] = itemSubType,
               ["itemID"] = itemID,
            });
         end
      end
   end
   return itemArray, itemAmount;
end

local function TypeChecker(typeString)
   --possible types: "Armor", "Consumable", "Container", "Gem", "Key", "Miscellaneous", "Money", "Reagent", "Recipe", "Projectile", "Quest", "Quiver", "Trade Goods", "Weapon"
   local types = {"Quest", "Consumable","Weapon","Armor","Trade Goods","Container","Gem","Key", "Money", "Reagent", "Recipe", "Projectile", "Quiver", "Miscellaneous"}
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
   local itemName, itemType, subType, rarity = item["itemName"], item["itemType"], item["itemSubType"], item["itemRarity"];
   local compareItemName, compareItemType, compareItemSubType, compareItemRarity = compareItem["itemName"], compareItem["itemType"], compareItem["itemSubType"], compareItem["itemRarity"];
   local checkedType = TypeChecker(itemType);
   local checkedCompareType = TypeChecker(compareItemType);
   if compareItemName == "Hearthstone" then 
      return false;
   elseif itemName == "Hearthstone" then 
      return true;
   elseif subType == "Mount" then
      if compareItemSubType == "Mount" then
         if rarity > compareItemRarity then
            return true;
         elseif rarity == compareItemRarity then
            if itemName < compareItemName then
               return true;
            else return false;
            end;
         else return false;
         end
      else return true;
      end
   elseif compareItemSubType == "Mount" then
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

local function SortItemArray(itemArray)
   local sortedArray = {};
   for key = 1, #itemArray, 1
   do
      local item = itemArray[key];
      local sorted = false;
      for sKey = 1, #sortedArray, 1
      do
         local compareItem = sortedArray[sKey];
         local result = CompareItems(item,compareItem);
         if result == true then
            table.insert(sortedArray,sKey,item);
            sorted = true;
            break;
         end       
      end
      if sorted == false then
         table.insert(sortedArray,item);
      end
   end
   return sortedArray;
end

local function SwapItems()
   if itemsToPush[1] then
      local item = itemsToPush[1];
      local bag1, slot1, bag2, slot2 = item["currentBag"],item["currentSlot"],item["futureBag"],item["futureSlot"];
      local _, _, locked1 = c.GetContainerItemInfo(bag1, slot1);
      local _, _, locked2 = c.GetContainerItemInfo(bag2, slot2);
      if locked1 ~= true and locked2 ~= true then --this is neccesary as the item can be either nil or false
         ClearCursor()
         c.PickupContainerItem(bag1, slot1)
         c.PickupContainerItem(bag2, slot2)
         table.remove(itemsToPush,1);
      end
   else
      events:UnregisterEvent("BAG_UPDATE_COOLDOWN");
      events:UnregisterEvent("BAG_UPDATE");
      --call that checks if everything is actually sorted and if not just sorts again, sometimes it just breaks mid-sort without this
      sort:Sort();
   end
end

local function OnUpdate()
   SwapItems();
end

local function itemArrayToBags(itemArray,bagArray)
   --TODO: I think this is logical and works but sometimes it doesn't work so maybe draw the logic out at some point since it was written at 3am

   for key = 1, #itemArray, 1--first we make sure that we know what item is currently in a slot
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
      local _, bagFamily = c.GetContainerNumFreeSlots(orderedKey-1);--goes from 0-4 instead of 1-5
      local bagKey = orderedKey-1;
      local currentBag = bagArray[bagKey];
      local bagLength = #bagArray[bagKey]["slotArray"];
      if bagFamily ~= 0 then
         alteredBags = alteredBags + 1;
         table.insert(orderedBags,orderedKey,currentBag["currentBag"]);--this makes sure that the bags that are assigned slots are at the end of the array of bags
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
         table.insert(orderedBags,orderedKey,currentBag["currentBag"]);--this makes sure that the bags that are assigned slots are at the end of the array of bags
         local itemFound = nil;
         local sortKey = 1;
         for slotKey = 1, bagLength, 1
         do
            local types = {["Quest"] = "Quest", ["Consumable"] = "Consumable",["Weapon"] = "Equipment",["Armor"] = "Equipment",["Trade Goods"] = "Trade Goods"};
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
         table.insert(orderedBags,orderedKey-alteredBags,currentBag["currentBag"]);
      end
   end

   local sortKey = 1;
   for orderedKey = 1, 5, 1--then we assign the items to specific slots for the future
   do
      local bagKey = orderedBags[orderedKey];
      local _, bagFamily = c.GetContainerNumFreeSlots(bagKey);--goes from 0-4 instead of 1-5
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

   for key = 1, #itemArray, 1--finally we make a list of all items, including finding out if items will be swapped on the same slot
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
               table.insert(itemsToPush,localItem);
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
      events:SetScript("OnEvent",OnUpdate);
      SwapItems();--call it once to trigger the events
   end
end

function sort:Sort()
   local name = UnitName("player");
   local realm = GetRealmName();
   currentBagSettingArray = bagSettingArray[name .. realm];
   local bagArray,totalSlots = GetBagSlots();
   local itemArray,totalItems = GetItemArrayFromBags(bagArray);
   local sortedArray = SortItemArray(itemArray);
   itemArrayToBags(sortedArray,bagArray);
end