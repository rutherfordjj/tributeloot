-------------------------------------------------------
--                T R I B U T E L O O T
-------------------------------------------------------
--        Author(s): Euthymius - Thunderlord
--          Website: http://www.tributeguild.net  (DEFUNCT)
--
--          Created: March 11, 2009
--    Last Modified: February 22, 2013
-------------------------------------------------------
local TributeLoot = LibStub("AceAddon-3.0"):NewAddon("TL", "AceConsole-3.0", "AceTimer-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TributeLoot")
TributeLoot.title = "TL"
TributeLoot.version = "TributeLoot @project-version@"


-------------------------------------------------------
-- Global variable declarations
-------------------------------------------------------
local gtl_LinkedItemsTable = {}
local gtl_IsLootInProgress = false
local gtl_CurrentProfileOptions
local gtl_LootAdded = false


-------------------------------------------------------
-- This table sets the default profile options
-------------------------------------------------------
local defaults = {
   profile = {
      CountdownSeconds     = 45,
      ItemQualityFilter    = 4,
      ResultsChannel       = "GUILD",
      CustomResultsChannel = "",
      LinkRecipes          = true,
      IgnoredItems         = {},
   },
}


-------------------------------------------------------
-- Adding an item ID to this table will add it to the
-- menu as a checkable ignored item.
-------------------------------------------------------
local IgnoredOptions = {}


-------------------------------------------------------
-- This table sets up the options GUI
-------------------------------------------------------
local options = {
   type = "group",
   name = TributeLoot.title,
   args = {
      General = {
         order = 1,
         type = "group",
         name = "General",
         desc = "General",
         args = {
            CountdownSeconds = {
               type = "range",
               name = L["Countdown Seconds"],
               desc = L["Sets the number of seconds to countdown after loot is linked"],
               order = 1,
               width = "double",
               min = 35,
               max = 120,
               step = 5,
               get = function()
                  return gtl_CurrentProfileOptions.CountdownSeconds
               end,
               set = function(info, v)
                  gtl_CurrentProfileOptions.CountdownSeconds = v
               end,
            },
            ItemQualityFilter = {
               type = "select",
               name = L["Item Quality"],
               desc = L["Sets the minimum item quality to link as loot"],
               order = 2,
               width = "double",
               values = {
                  [0] = ITEM_QUALITY_COLORS[0].hex .. L["Poor"] .. "|r",
                  [1] = ITEM_QUALITY_COLORS[1].hex .. L["Common"] .. "|r",
                  [2] = ITEM_QUALITY_COLORS[2].hex .. L["Uncommon"] .. "|r",
                  [3] = ITEM_QUALITY_COLORS[3].hex .. L["Rare"] .. "|r",
                  [4] = ITEM_QUALITY_COLORS[4].hex .. L["Epic"] .. "|r",
               },
               get = function()
                  return gtl_CurrentProfileOptions.ItemQualityFilter
               end,
               set = function(info, v)
                  gtl_CurrentProfileOptions.ItemQualityFilter = v
               end,
            },
            ResultsChannel = {
               type = "select",
               order = 3,
               width = "double",
               name = L["Results Location"],
               desc = L["Determines where loot results are printed"],
               values = {
                  ["OFFICER"] = L["Officer"],
                  ["GUILD"] = L["Guild"],
                  ["RAID"] = L["Raid"],
                  ["PARTY"] = L["Party"],
                  ["SAY"] = L["Say"],
                  ["CHANNEL"] = L["Channel"],
               },
               get = function()
                  return gtl_CurrentProfileOptions.ResultsChannel
               end,
               set = function(info, v)
                  gtl_CurrentProfileOptions.ResultsChannel = v
               end,
            },
            CustomResultsChannel = {
               type = "input",
               order = 4,
               width = "double",
               name = L["Channel"],
               desc = L["Enter the channel name or number where results should print"],
               hidden = function()
                  return "CHANNEL" ~= gtl_CurrentProfileOptions.ResultsChannel
               end,
               get = function()
                  return gtl_CurrentProfileOptions.CustomResultsChannel
               end,
               set = function(info, v)
                  gtl_CurrentProfileOptions.CustomResultsChannel = v
               end,
            },
         },
      },
      IgnoreMenu = {
         order = 2,
         type = "group",
         name = L["Ignored Items"],
         desc = L["Ignored Items"],
         args = {
            IgnoredListDescription = {
               type = "description",
               order = 1,
               name = L["Add items to this list with the \"/tl ignore %s[item]|r\" command."]:format(ITEM_QUALITY_COLORS[4].hex),
               fontSize = "large",
               width = "full",
            },
            IgnoredList = {
               type = "multiselect",
               order = 2,
               name = L["Ignored List"],
               desc = L["Checking prevents items from being linked as loot"],
               values = function()
                  LoadIgnoredOptions()
                  return IgnoredOptions
               end,
               width = "full",
               get = function(info, v)
                  return gtl_CurrentProfileOptions.IgnoredItems[v]
               end,
               set = function(info, k, v)
                  if (false == v) then
                     gtl_CurrentProfileOptions.IgnoredItems[k] = nil
                  else
                     gtl_CurrentProfileOptions.IgnoredItems[k] = true
                  end
               end,
            },
            IgnoreRecipes = {
               type = "toggle",
               order = 3,
               width = "double",
               name = L["Ignore Recipes"],
               desc = L["Determines if recipes will be linked as loot"],
               get = function()
                  return not gtl_CurrentProfileOptions.LinkRecipes
               end,
               set = function(info, v)
                  gtl_CurrentProfileOptions.LinkRecipes = not v
               end,
            },
         },
      },
   },
}


-------------------------------------------------------
-- Determines if an item should be linked
--
-- The item is considered invalid if it meets any of the following conditions:
-- 1.)  The item is below the minimum item quality level
-- 2.)  The item is on the ignore list
-- 3.)  The item is a recipe and linking recipes is disabled
--
-- @return true if item is valid, false otherwise
-------------------------------------------------------
function IsValidItem(item)
   local isValid = false

   if (nil ~= item) then
      local itemName, itemLink, itemRarity = GetItemInfo(item)

      --Check if the item is below the minimum item quality level
      if (nil ~= itemLink) and (itemRarity >= gtl_CurrentProfileOptions.ItemQualityFilter) then
         local itemId = GetItemId(itemLink)

         if (nil ~= itemId) and (nil ~= itemName) then
            --Check if the item should be ignored
            if (false == IsIgnoredItem(itemId)) then
               --Check if the item is a recipe and if recipes should be linked
               if (false == IsRecipeItem(itemName)) or (true == gtl_CurrentProfileOptions.LinkRecipes) then
                  isValid = true
               end
            end
         end
      end
   end

   return isValid
end


-------------------------------------------------------
-- Determines if an item is on the ignored list
--
-- @return true if item is ignored, false otherwise
-------------------------------------------------------
function IsIgnoredItem(itemId)
   local isIgnored = false

   if (nil ~= itemId) then
      if (true == gtl_CurrentProfileOptions.IgnoredItems[itemId]) then
         isIgnored = true
      end
   end

   return isIgnored
end


-------------------------------------------------------
-- Determines if an item is a recipe
--
-- @return true if item is recipe, false otherwise
-------------------------------------------------------
function IsRecipeItem(itemName)
   local isRecipe = false

   if (nil ~= itemName) then
      if (itemName:find(L["Design:"])) or
         (itemName:find(L["Formula:"])) or
         (itemName:find(L["Pattern:"])) or
         (itemName:find(L["Plans:"])) or
         (itemName:find(L["Recipe:"])) or
         (itemName:find(L["Schematic:"])) then

         isRecipe = true
      end
   end

   return isRecipe
end


-------------------------------------------------------
-- Extracts the itemId from an itemLink
--
-- @return itemId as a numeric value if successful
--         nil if error
-------------------------------------------------------
function GetItemId(itemLink)
   local itemId = nil

   if (nil ~= itemLink) then
      itemId = select(3, itemLink:find("item:(%d+):"))

      if (nil ~= itemId) then
         itemId = tonumber(itemId:trim())
      end
   end

   return itemId
end


-------------------------------------------------------
-- Update the ignored item options table
-------------------------------------------------------
function LoadIgnoredOptions()
   for k, v in pairs(gtl_CurrentProfileOptions.IgnoredItems) do
      local itemName, itemLink, itemRarity = GetItemInfo(k)

      if (nil ~= itemName) and (nil ~= itemRarity) then
         IgnoredOptions[k] = string.format("%s%s|r (ID: %s)", ITEM_QUALITY_COLORS[itemRarity].hex, itemName, k)
      else
         IgnoredOptions[k] = k
      end
   end
end


-------------------------------------------------------
-- Adds Item to ignore list
-------------------------------------------------------
function IgnoreItem(itemLink)
   local self = TributeLoot

   if (nil ~= itemLink) then
      local itemId = GetItemId(itemLink)

      if (nil ~= itemId) then
         if (true ~= gtl_CurrentProfileOptions.IgnoredItems[itemId]) then
            gtl_CurrentProfileOptions.IgnoredItems[itemId] = true
            NotifyMenuOptionsChange()
            self:Print(L["Item %s was added to the ignore list."]:format(itemLink))
         else
            self:Print(L["Item %s is already ignored."]:format(itemLink))
         end
      else
         self:Print(L["Please link a valid item."])
      end
   end
end


-------------------------------------------------------
-- Removes Item from ignore list
-------------------------------------------------------
function UnignoreItem(itemLink)
   local self = TributeLoot

   if (nil ~= itemLink) then
      local itemId = GetItemId(itemLink)

      if (nil ~= itemId) then
         if (true == gtl_CurrentProfileOptions.IgnoredItems[itemId]) then
            gtl_CurrentProfileOptions.IgnoredItems[itemId] = nil
            NotifyMenuOptionsChange()
            self:Print(L["Item %s was removed from the ignore list."]:format(itemLink))
         else
            self:Print(L["Item %s was not on the ignore list."]:format(itemLink))
         end
      else
         self:Print(L["Please link a valid item."])
      end
   end
end


-------------------------------------------------------
-- Adds a new item entry to the table at the specified index
-- If the item already exists in the table, this will just increment the count.
-- The item will not be added if IsValidItem() returns false
--
-- @return true if item is added or count updated, false otherwise
-------------------------------------------------------
function AddItem(itemLink)
   local retVal = false

   if (nil ~= itemLink) then
      local itemId = GetItemId(itemLink)
      local alreadyExists, location = DoesItemEntryExist(itemId)

      if (true == alreadyExists) then
         -- Increment the item count
         if (nil ~= location) and (nil ~= gtl_LinkedItemsTable[location]) then
            gtl_LinkedItemsTable[location].Count = gtl_LinkedItemsTable[location].Count + 1
            retVal = true
         end
      elseif (true == IsValidItem(itemLink)) then
         -- Add the item entry to the table
          local itemEntry = {
            ItemLink = itemLink,
            ItemId = GetItemId(itemLink),
            Count = 1,
            InList = {},
            RotList = {},
         }

         table.insert(gtl_LinkedItemsTable, itemEntry)
         retVal = true
      end
   end

   return retVal
end


-------------------------------------------------------
-- Clears loot results
--
-- @return true if successful, false otherwise
-------------------------------------------------------
function ClearItems()
   local retVal = false

   --Do not clear the table if loot is currently in progress
   if (false == gtl_IsLootInProgress) then
      table.wipe(gtl_LinkedItemsTable)
      gtl_LinkedItemsTable = {}
      retVal = true
   end

   return retVal
end


-------------------------------------------------------
-- Checks if an item id already exists in the item table
--
-- @return true if item entry already exists, false otherwise
--         table index if exists, nil otherwise
-------------------------------------------------------
function DoesItemEntryExist(itemId)
   local itemExists = false
   local location = nil

   if (nil ~= itemId) then
      for index, value in ipairs(gtl_LinkedItemsTable) do
         if (value.ItemId == itemId) then
            itemExists = true
            location = index
            break
         end
      end
   end

   return itemExists, location
end


-------------------------------------------------------
-- Adds a player to a list
--
-- @return true if successful, false otherwise
-------------------------------------------------------
function AddPlayerToList(list, playerName, extraInfo)
   local status = false

   if (nil ~= playerName) and (nil ~= list) then
      --Check if the player entry already exists
      if (nil == list[playerName]) then
         list[playerName] = {
            Active = true,
            ExtraInfo = extraInfo,
         }
         status = true
      end
   end

   return status
end


-------------------------------------------------------
-- Removes a player from a list
--
-- @return true if successful, false otherwise
-------------------------------------------------------
function RemovePlayerFromList(list, playerName)
   local status = false

   if (nil ~= playerName) and (nil ~= list) then
      --Check if the player entry exists
      if (nil ~= list[playerName]) then
         list[playerName] = nil
         status = true
      end
   end

   return status
end


-------------------------------------------------------
-- Adds loot to the window without linking it
-------------------------------------------------------
function AddLoot(displayItemMessages)
   local self = TributeLoot
   local count = 0
   local messaged = false

   --If loot hasn't been added since the last time it was linked, clear the table
   if (false == gtl_LootAdded) then
      ClearItems()
   end

   if (true == gtl_IsLootInProgress) then
      self:Print(L["Cannot add anymore items until Last Call."])
      messaged = true
   elseif (0 == GetNumLootItems()) then
      self:Print(L["No items found. Make sure a loot window is open."])
      messaged = true
   else
      --Build item table
      local link
      for i = 1, GetNumLootItems() do
         if (LootSlotHasItem(i)) then
            link = GetLootSlotLink(i)
            if (true == AddItem(link)) then
               count = count + 1

               if (displayItemMessages) then
                  self:Print("Added " .. link)
               end
            end
         end
      end

      --Check to see if loot was added
      if (count > 0) then
         gtl_LootAdded = true
      else
         if (displayItemMessages) then
            self:Print(L["No valid items were found. Check the item quality filter in the options."])
         end
      end
   end

   return messaged
end


-------------------------------------------------------
-- Links items in raid warning
-------------------------------------------------------
function LinkLoot()
   local self = TributeLoot
   local messaged = false

   if (true == gtl_IsLootInProgress) then
      self:Print(L["Cannot link anymore items until Last Call."])
   else
      --If no items have been added yet, try to add them
      if (false == gtl_LootAdded) then
         messaged = AddLoot(false)
      end

      --Reset the loot added flag so items are cleared next time it is ran
      gtl_LootAdded = false

      --Print item table
      if (#gtl_LinkedItemsTable > 0) then
         PrintRaidMessage(L["Whisper me \"in\" or \"rot\" with an item number below (example \"in 1\")"])
         local message
         for i,v in ipairs(gtl_LinkedItemsTable) do
            message = i .. " -- " .. v.ItemLink
            if (v.Count > 1) then
               message = message .. "x" .. v.Count
            end
            PrintRaidMessage(message)
         end

         StartCountDown()
      else
         --Kind of a hack, but if a message was displayed in AddLoot(), then don't display a message here.
         if (false == messaged) then
            self:Print(L["No valid items were found. Check the item quality filter in the options."])
         end
      end
   end
end


-------------------------------------------------------
-- Starts the countdown
-------------------------------------------------------
function StartCountDown()
   local self = TributeLoot
   local countdown = gtl_CurrentProfileOptions.CountdownSeconds -- NOTE: This value should always be greater than 30

   gtl_IsLootInProgress = true

   --Process the whisper event independent of the chat frames so it is only handled once
   self:RegisterEvent("CHAT_MSG_WHISPER")

   --Hide the mod messages from the chat frames
   ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", WhisperFilter)
   ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", WhisperInformFilter)

   --Schedule the countdown
   self:ScheduleTimer(PrintRaidMessage, countdown - 30, L["Last call in 30 seconds"])
   self:ScheduleTimer(PrintRaidMessage, countdown - 15, L["15"])
   self:ScheduleTimer(PrintRaidMessage, countdown - 10, L["10"])
   self:ScheduleTimer(PrintRaidMessage, countdown - 5,  L["5"])
   self:ScheduleTimer(PrintRaidMessage, countdown - 4,  L["4"])
   self:ScheduleTimer(PrintRaidMessage, countdown - 3,  L["3"])
   self:ScheduleTimer(PrintRaidMessage, countdown - 2,  L["2"])
   self:ScheduleTimer(PrintRaidMessage, countdown - 1,  L["1"])
   self:ScheduleTimer(PrintRaidMessage, countdown, L["Last Call"])
   self:ScheduleTimer(LastCall, countdown + 1, nil)
end


-------------------------------------------------------
-- Notifies the mod that loot is finished,
-- so stop handling whispers and print the results
-------------------------------------------------------
function LastCall()
   local self = TributeLoot

   self:UnregisterEvent("CHAT_MSG_WHISPER")
   ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER", WhisperFilter)
   ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER_INFORM", WhisperInformFilter)
   gtl_IsLootInProgress = false
   PrintOverallLootResults()
end


-------------------------------------------------------
-- Returns where results should print
-------------------------------------------------------
function GetResultsChannel()
   local chatType = gtl_CurrentProfileOptions.ResultsChannel
   local channel = nil

   if (chatType == "CHANNEL") then
      channel = GetChannelName(gtl_CurrentProfileOptions.CustomResultsChannel)
   end

   return chatType, channel
end


-------------------------------------------------------
-- Prints the loot results
-------------------------------------------------------
function PrintOverallLootResults()
   local self = TributeLoot
   local resultMessage
   local counter
   local chatType, channel = GetResultsChannel()

   --Do not display the results header if there is nothing to link
   if (true == gtl_IsLootInProgress) then
      self:Print(L["Cannot print results until Last Call."])
   elseif (0 == #gtl_LinkedItemsTable) then
      self:Print(L["There are no results to print."])
   elseif (0 == channel) then
      self:Print(L["Cannot print results in the specified channel. Join the channel or change the options."])
   else
      SendChatMessage("<" .. TributeLoot.title .. "> " ..  L["Results"], chatType, nil, channel)

      for i,v in ipairs(gtl_LinkedItemsTable) do
         resultMessage = v.ItemLink

         if (v.Count > 1) then
            resultMessage = resultMessage .. "x" .. v.Count
         end

         counter = 0
         for key, value in pairs(v.InList) do
            resultMessage = resultMessage .. " " .. key .. " "
            counter = counter + 1
         end

         for key, value in pairs(v.RotList) do
            resultMessage = resultMessage .. " (" .. key .. ") "
            counter = counter + 1
         end

         if (0 == counter) then
            resultMessage = resultMessage .. " " .. L["rot"]
         end

         SendChatMessage(resultMessage, chatType, nil, channel)
      end
   end
end


-------------------------------------------------------
-- Prints detailed results on a single item
-------------------------------------------------------
function PrintDetailedResults(index)
   local self = TributeLoot
   local chatType, channel = GetResultsChannel()
   local resultsMessage
   local rot

   if (true == gtl_IsLootInProgress) then
      self:Print(L["Cannot print results until Last Call."])
   elseif (nil == index) or (nil == gtl_LinkedItemsTable[index]) then
      self:Print(L["Cannot print detailed results. You did not specify a valid item number."])
   elseif (0 == channel) then
      self:Print(L["Cannot print results in the specified channel. Join the channel or change the options."])
   else
      rot = true
      SendChatMessage("<" .. TributeLoot.title .. "> " .. L["Detailed Results for %s"]:format(gtl_LinkedItemsTable[index].ItemLink), chatType, nil, channel)

      for k, v in pairs(gtl_LinkedItemsTable[index].InList) do
         if (nil == v.ExtraInfo) then
            resultMessage = string.format("%s %s", k, L["mainspec"])
         elseif not (v.ExtraInfo:find("%D")) then
            resultMessage = L["%s bidding %s for %s"]:format(k, v.ExtraInfo, L["mainspec"])
         else
            resultMessage = L["%s replacing %s for %s"]:format(k, v.ExtraInfo, L["mainspec"])
         end

         rot = false
         SendChatMessage(resultMessage, chatType, nil, channel)
      end

      for k, v in pairs(gtl_LinkedItemsTable[index].RotList) do
         if (nil == v.ExtraInfo) then
            resultMessage = string.format("%s %s", k, L["offspec"])
         elseif not (v.ExtraInfo:find("%D")) then
            resultMessage = L["%s bidding %s for %s"]:format(k, v.ExtraInfo, L["offspec"])
         else
            resultMessage = L["%s replacing %s for %s"]:format(k, v.ExtraInfo, L["offspec"])
         end

         rot = false
         SendChatMessage(resultMessage, chatType, nil, channel)
      end

      if (true == rot) then
         SendChatMessage(L["No one is interested in this item."], chatType, nil, channel)
      end
   end
end


-------------------------------------------------------
-- Prints a message in raid warning if you have assist
-- Prints in raid if you don't have assist
-- Prints in party if you aren't in a raid
-- Prints in say if you aren't in a party (used for solo testing)
-------------------------------------------------------
function PrintRaidMessage(message)
   local chatType

   if (nil ~= message) then
      if IsInRaid() then
         if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            chatType = "RAID_WARNING"
         else
            chatType = "RAID"
         end
      elseif (GetNumSubgroupMembers() > 0) then
         chatType = "PARTY"
      else
         chatType = "SAY"
      end

      SendChatMessage(message, chatType)
   end
end


-------------------------------------------------------
-- Process whispers sent to the mod
-------------------------------------------------------
function TributeLoot:CHAT_MSG_WHISPER(event, message, sender)
   local self = TributeLoot

   if (nil ~= message) and (nil ~= sender) then
      local option, itemIndex, extraInfo = self:GetArgs(message, 3)

      if (nil ~= option) then
         option = option:lower()
      end

      if (nil ~= itemIndex) then
         itemIndex = tonumber(itemIndex:trim())
      end

      if ("in" == option) then
         if (nil ~= gtl_LinkedItemsTable[itemIndex]) then
            if (true == AddPlayerToList(gtl_LinkedItemsTable[itemIndex].InList, sender, extraInfo)) then
               SendChatMessage("<" .. TributeLoot.title .. "> " .. L["You were added to the %s list for %s. Whisper me \"out %d\" to be removed."]:format(L["[IN]"], gtl_LinkedItemsTable[itemIndex].ItemLink, itemIndex), "WHISPER", nil, sender)
            else
               SendChatMessage("<" .. TributeLoot.title .. "> " .. L["You are already added to the %s list for %s, so I am ignoring this request."]:format(L["[IN]"], gtl_LinkedItemsTable[itemIndex].ItemLink), "WHISPER", nil, sender)
            end
         else
            SendChatMessage("<" .. TributeLoot.title .. "> " .. L["You did not specify a valid item, please try again."], "WHISPER", nil, sender)
         end
      elseif ("rot" == option) then
         if (nil ~= gtl_LinkedItemsTable[itemIndex]) then
            if (true == AddPlayerToList(gtl_LinkedItemsTable[itemIndex].RotList, sender, extraInfo)) then
               SendChatMessage("<" .. TributeLoot.title .. "> " .. L["You were added to the %s list for %s. Whisper me \"out %d\" to be removed."]:format(L["[ROT]"], gtl_LinkedItemsTable[itemIndex].ItemLink, itemIndex), "WHISPER", nil, sender)
            else
               SendChatMessage("<" .. TributeLoot.title .. "> " .. L["You are already added to the %s list for %s, so I am ignoring this request."]:format(L["[ROT]"], gtl_LinkedItemsTable[itemIndex].ItemLink), "WHISPER", nil, sender)
            end
         else
            SendChatMessage("<" .. TributeLoot.title .. "> " .. L["You did not specify a valid item, please try again."], "WHISPER", nil, sender)
         end
      elseif ("out" == option) then
         if (nil ~= gtl_LinkedItemsTable[itemIndex]) then
            local listString = ""

            if (true == RemovePlayerFromList(gtl_LinkedItemsTable[itemIndex].InList, sender)) then
               listString = L["[IN]"]
            end

            if (true == RemovePlayerFromList(gtl_LinkedItemsTable[itemIndex].RotList, sender)) then
               if ("" ~= listString) then
                  listString = listString .. " " .. L["and"] .. " "
               end
               listString = listString .. L["[ROT]"]
            end

            if ("" ~= listString) then
               SendChatMessage("<" .. TributeLoot.title .. "> " .. L["You were removed from the %s list for %s."]:format(listString, gtl_LinkedItemsTable[itemIndex].ItemLink), "WHISPER", nil, sender)
            else
               SendChatMessage("<" .. TributeLoot.title .. "> " .. L["You are not on the lists for %s, so I cannot remove you."]:format(gtl_LinkedItemsTable[itemIndex].ItemLink) , "WHISPER", nil, sender)
            end
         else
            SendChatMessage("<" .. TributeLoot.title .. "> " .. L["You did not specify a valid item, please try again."], "WHISPER", nil, sender)
         end
      end
   end
end


-------------------------------------------------------
-- Supress whispers handled by the mod
-------------------------------------------------------
function WhisperFilter(ChatFrameSelf, event, arg1)
   if (nil ~= arg1) then
      local option = TributeLoot:GetArgs(arg1:lower(), 1)
      if ("in" == option) or ("rot" == option) or ("out" == option) then
         return true
      end
   end
end


-------------------------------------------------------
-- Supress whispers sent by the mod
-------------------------------------------------------
function WhisperInformFilter(ChatFrameSelf, event, arg1)
   if (nil ~= arg1) then
      if arg1:find("^<" .. TributeLoot.title .. ">") then
         return true
      end
   end
end


-------------------------------------------------------
-- Handles slash commands
-------------------------------------------------------
function SlashHandler(options)
   local self = TributeLoot
   local command, param1 = self:GetArgs(options, 2)

   if (nil ~= command) then
      command = command:lower()
   end

   if (L["link"] == command) or ("l" == command) then
      LinkLoot()
   elseif (L["addloot"] == command or ("a" == command)) then
      AddLoot(true)
   elseif (L["results"] == command) or ("r" == command) then
      if (nil ~= param1) then
         param1 = tonumber(param1)
         PrintDetailedResults(param1)
      else
         PrintOverallLootResults()
      end
   elseif (L["clear"] == command) then
      if (true == ClearItems()) then
         self:Print(L["Previous items were cleared."])
         gtl_LootAdded = false
      else
         self:Print(L["Could not clear previous items."])
      end
   elseif (L["options"] == command) or ("o" == command) then
      self:ShowConfig()
   elseif (L["ignore"] == command) or ("i" == command) then

      if (nil == param1) then
         self:ShowIgnoreMenu()
      else
         IgnoreItem(param1)
      end
   elseif (L["unignore"] == command) or ("u" == command) then
      if (nil == param1) then
         self:ShowIgnoreMenu()
      else
         UnignoreItem(param1)
      end
   else
      self:Print(self.version)
      self:Print("/tl " .. L["addloot"])
      self:Print("/tl " .. L["link"])
      self:Print("/tl " .. L["results"] .. " (#)")
      self:Print("/tl " .. L["clear"])
      self:Print("/tl " .. L["options"])
      self:Print("/tl " .. L["ignore"] .. L[" %s[item]|r"]:format(ITEM_QUALITY_COLORS[4].hex))
      self:Print("/tl " .. L["unignore"] .. L[" %s[item]|r"]:format(ITEM_QUALITY_COLORS[4].hex))
   end
end


-------------------------------------------------------
-- Updates the menu GUI with the option changes
-------------------------------------------------------
function NotifyMenuOptionsChange()
   LibStub("AceConfigRegistry-3.0"):NotifyChange("TL")
end


-------------------------------------------------------
-- Initialize the option frames
-------------------------------------------------------
function TributeLoot:SetupOptions()
   LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("TL", options)

   self.optionsFrames = {}
   self.optionsFrames.general = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("TL", "TributeLoot", nil, "General")
   self.optionsFrames.ignoreList = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("TL", "Ignored Items", "TributeLoot", "IgnoreMenu")
end


-------------------------------------------------------
-- Show the options window
-------------------------------------------------------
function TributeLoot:ShowConfig()
   if (nil ~= self.optionsFrames.general) then
      InterfaceOptionsFrame_OpenToCategory(self.optionsFrames.general)
   else
      self:Print(L["Could not show options frame."])
   end
end


-------------------------------------------------------
-- Show the options window
-------------------------------------------------------
function TributeLoot:ShowIgnoreMenu()
   if (nil ~= self.optionsFrames.ignoreList) then
      InterfaceOptionsFrame_OpenToCategory(self.optionsFrames.ignoreList)
   else
      self:Print(L["Could not show options frame."])
   end
end


-------------------------------------------------------
-- Called when options profile is changed
-------------------------------------------------------
function TributeLoot:OnProfileChanged(event, database, newProfileKey)
   gtl_CurrentProfileOptions = database.profile
end


-------------------------------------------------------
-- AddOn Initialization
-------------------------------------------------------
function TributeLoot:OnInitialize()
   self.db = LibStub("AceDB-3.0"):New("TLDB", defaults, true)
   self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
   self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
   self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")

   gtl_CurrentProfileOptions = self.db.profile

   --Load options on init so client will async query the item info from server
   --otherwise GetItemInfo will probably return nil the first time it is called
   LoadIgnoredOptions()

   self:RegisterChatCommand("tl", SlashHandler)
   self:SetupOptions()
end
