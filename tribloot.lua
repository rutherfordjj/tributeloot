-------------------------------------------------------
--                T R I B U T E L O O T
-------------------------------------------------------
--        Author(s): Euthymius
--          Website: http://www.tributeguild.net
--
--          Created: March 11, 2009
--    Last Modified: September 01, 2009
-------------------------------------------------------
local TributeLoot = LibStub("AceAddon-3.0"):NewAddon("TributeLoot", "AceConsole-3.0", "AceTimer-3.0")
TributeLoot.title = "TributeLoot"
TributeLoot.version = "Version r19"

-------------------------------------------------------
--Global Variables
-------------------------------------------------------
local gItemListTable = {}
local gLootInProgress = false
local gOptionsDatabase


-------------------------------------------------------
-- This "enumeration" is used for returning status
-- information for some functions below
-------------------------------------------------------
local eStatusResults = {
   NONE=0,
   INVALID_ITEM=1,
   PLAYER_ALREADY_EXISTS=2,
   PLAYER_NOT_FOUND=3,
   SUCCESS=4,
}


-------------------------------------------------------
-- This table sets the default database values
-------------------------------------------------------
local defaults = {
   profile = {
      CountdownSeconds  = 45,
      ItemQualityFilter = 4,
      ResultsChannel    = "OFFICER",
      LinkRecipes       = false,
   }
}


-------------------------------------------------------
-- This table sets up the options GUI
-------------------------------------------------------
local options = {
	type = "group",
   name = "TributeLoot",
	args = {
      General = {
         order = 1,
         type = "group",
         name = "General",
         desc = "General",
         args = {
            CountdownSeconds = {
               type = "range",
               name = "Countdown Seconds",
               desc = "Sets the number of seconds to countdown after loot is linked",
               order = 2,
               width = "double",
               min = 35,
               max = 120,
               step = 1,
               get = function()
                  return gOptionsDatabase.CountdownSeconds
               end,
               set = function(info, v)
                  gOptionsDatabase.CountdownSeconds = v
               end,
            },
            ItemQualityFilter = {
               type = "select",
               name = "Item Quality",
               desc = "Sets the minimum item quality to link as loot",
               order = 3,
               width = "double",
               values = {
                  [0] = ITEM_QUALITY_COLORS[0].hex .. "Poor|r",
                  [1] = ITEM_QUALITY_COLORS[1].hex .. "Common|r",
                  [2] = ITEM_QUALITY_COLORS[2].hex .. "Uncommon|r",
                  [3] = ITEM_QUALITY_COLORS[3].hex .. "Rare|r",
                  [4] = ITEM_QUALITY_COLORS[4].hex .. "Epic|r",
                  [5] = ITEM_QUALITY_COLORS[5].hex .. "Legendary|r",
               },
               get = function()
                  return gOptionsDatabase.ItemQualityFilter
               end,
               set = function(info, v)
                  gOptionsDatabase.ItemQualityFilter = v
               end,
            },
            ResultsChannel = {
               type = "select",
               order = 4,
               width = "double",
               name = "Results Channel",
               desc = "Determines where loot results are printed",
               values = {
                  ["OFFICER"] = "Officer",
                  ["GUILD"] = "Guild",
                  ["RAID"] = "Raid",
                  ["RAID_WARNING"] = "Raid Warning",
                  ["PARTY"] = "Party",
                  ["SAY"] = "Say",
                  ["YELL"] = "Yell",
               },
               get = function()
                  return gOptionsDatabase.ResultsChannel
               end,
               set = function(info, v)
                  gOptionsDatabase.ResultsChannel = v
               end,
            },
            LinkRecipes = {
               type = "toggle",
               order = 5,
               width = "double",
               name = "Link Recipes",
               desc = "Determines if recipes will be linked as loot",
               get = function()
                  return gOptionsDatabase.LinkRecipes
               end,
               set = function(info, v)
                  gOptionsDatabase.LinkRecipes = v
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
-- 1.)  The item already exists in the item list table
-- 2.)  The item is below the minimum item quality level
-- 3.)  The item is on the ignore list
-- 4.)  The item is a recipes and linking recipes is disabled
--
-- @return true if item is valid, false otherwise
-------------------------------------------------------
function IsValidItem(item)
   local isValid = false

   if (nil ~= item) then
      local itemName, itemLink, itemRarity = GetItemInfo(item)

      --Check if the item is at least epic quality before doing anything else
      if (nil ~= itemLink) and (itemRarity >= gOptionsDatabase.ItemQualityFilter) then
         local itemId = GetItemId(itemLink)

         if (nil ~= itemId) and (nil ~= itemName) then
            --Check if the item should be ignored or if it is a duplicate
            if (false == IsIgnoredItem(itemId)) and (false == DoesItemEntryExist(itemId)) then
               --Check if the item is a recipe and if recipes should be linked
               if (false == IsRecipeItem(itemName)) or (true == gOptionsDatabase.LinkRecipes) then
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

   --Add item ids to the if-statement below to make them ignored
   if (40752 == itemId) or   -- Emblem of Heroism
      (40753 == itemId) or   -- Emblem of Valor
      (45624 == itemId) or   -- Emblem of Conquest
      (47241 == itemId) or   -- Emblem of Triumph
      (43345 == itemId) or   -- Dragon Hide Bag
      (43346 == itemId) or   -- Large Satchel of Spoils
      (43954 == itemId) or   -- Reins of the Twilight Drake
      (43952 == itemId) or   -- Reins of the Azure Drake
      (43959 == itemId) or   -- Reins of the Grand Black War Mammoth
      (45693 == itemId) or   -- Mimiron's Head
      (45506 == itemId) or   -- Archivum Data Disc (Normal)
      (45857 == itemId) or   -- Archivum Data Disc (Heroic)
      (45038 == itemId) then -- Fragment of Val'anyr

      isIgnored = true
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

   if itemName:find("Design:") or
      itemName:find("Formula:") or
      itemName:find("Pattern:") or
      itemName:find("Plans:") or
      itemName:find("Recipe:") or
      itemName:find("Schematic:") then

      isRecipe = true;
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
-- Adds a new item entry to the table at the specified index
--
-- The item will not be added if it meets any of the following conditions:
-- 1.)  There is already an entry at the "index" location
-- 2.)  IsValidItem() returns false
--
-- @return true if item is added, false otherwise
-------------------------------------------------------
function AddItem(index, itemLink)
   local retVal = false

   if (nil == gItemListTable[index]) and IsValidItem(itemLink) then
      -- Add the item entry to the table
      gItemListTable[index] = {
         ItemLink = itemLink,
         ItemId = GetItemId(itemLink),
         InList = {},
         RotList = {},
      }

      retVal = true
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
   if (false == gLootInProgress) then
      table.wipe(gItemListTable)
      gItemListTable = {}
      retVal = true
   end

   return retVal
end


-------------------------------------------------------
-- Checks if an item id already exists in the item table
-- (This function prevents duplicate items from being linked more than once.)
--
-- @return true if item entry already exists, false otherwise
--         table index if exists, nil otherwise
-------------------------------------------------------
function DoesItemEntryExist(itemId)
   local itemExists = false
   local location = nil

   if (nil ~= itemId) then
      for index, value in ipairs(gItemListTable) do
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
-- Checks if a player name exists in a list
--
-- @return true if player exists, false otherwise
--         table index if exists, nil otherwise
-------------------------------------------------------
function DoesPlayerExistInList(list, playerName)
   local playerExists = false
   local location = nil

   if (nil ~= list) and (nil ~= playerName) then
      for index, value in ipairs(list) do
         if (value == playerName) then
            playerExists = true
            location = index
            break
         end
      end
   end

   return playerExists, location
end


-------------------------------------------------------
-- Adds a player to a list
--
-- @return SUCCESS if successful
--         PLAYER_ALREADY_EXISTS if player already exists in list
-------------------------------------------------------
function AddPlayerToList(list, playerName)
   local status = eStatusResults.PLAYER_ALREADY_EXISTS  

   if not DoesPlayerExistInList(list, playerName) then
      table.insert(list, playerName)
      status = eStatusResults.SUCCESS
   end

   return status
end


-------------------------------------------------------
-- Removes a player from a list
--
-- @return SUCCESS if successful
--         PLAYER_NOT_FOUND if player doesn't exist in list
-------------------------------------------------------
function RemovePlayerFromList(list, playerName)
   local status = eStatusResults.PLAYER_NOT_FOUND
   local playerExists, location = DoesPlayerExistInList(list, playerName)

   if (true == playerExists) and (nil ~= location) then
      table.remove(list, location)
      status = eStatusResults.SUCCESS
   end

   return status
end


-------------------------------------------------------
-- Links items in raid warning
-------------------------------------------------------
function LinkLoot()
   local self = TributeLoot
   local itemLink
   local itemNumber = 0

   if (true == gLootInProgress) then
      self:Print("Cannot link anymore items until Last Call")
   else
      --Clear previous results when linking more items
      ClearItems()

      for i = 1, GetNumLootItems() do
         if (LootSlotIsItem(i)) then
            itemLink = GetLootSlotLink(i)
            if (nil ~= itemLink) then
               itemNumber = itemNumber + 1
               if AddItem(itemNumber, itemLink) then
                  PrintRaidMessage(itemNumber .. " -- " .. itemLink)
               else
                  itemNumber = itemNumber - 1
               end
            end
         end
      end

      if (itemNumber > 0) then
         PrintRaidMessage("Whisper me \"in\" or \"rot\" with an item number above (example \"in 1\")")
         StartCountDown()
      else
         self:Print("No items to link!  Make sure a loot window is open.")
      end
   end
end


-------------------------------------------------------
-- Starts the countdown
-------------------------------------------------------
function StartCountDown()
   local self = TributeLoot
   local countdown = gOptionsDatabase.CountdownSeconds -- NOTE:  This value should be greater than 30

   gLootInProgress = true
   ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", WhisperHandler)
   ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", WhisperInformHandler)

   self:ScheduleTimer(PrintRaidMessage, countdown - 30, "Last call in 30 seconds")
   self:ScheduleTimer(PrintRaidMessage, countdown - 15, "15")
   self:ScheduleTimer(PrintRaidMessage, countdown - 10, "10")
   self:ScheduleTimer(PrintRaidMessage, countdown - 5, "5")
   self:ScheduleTimer(PrintRaidMessage, countdown - 4, "4")
   self:ScheduleTimer(PrintRaidMessage, countdown - 3, "3")
   self:ScheduleTimer(PrintRaidMessage, countdown - 2, "2")
   self:ScheduleTimer(PrintRaidMessage, countdown - 1, "1")
   self:ScheduleTimer(PrintRaidMessage, countdown, "Last Call")
   self:ScheduleTimer(LastCall, countdown + 1, nil)
end


-------------------------------------------------------
-- Notifies the mod that loot is finished, so stop
-- handling whispers and print the results
-------------------------------------------------------
function LastCall()
   ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER", WhisperHandler)
   ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER_INFORM", WhisperInformHandler)
   gLootInProgress = false
   PrintLootResults()
end


-------------------------------------------------------
-- Prints the loot results
-------------------------------------------------------
function PrintLootResults()
   local self = TributeLoot
   local resultMessage
   local counter
   local channel = gOptionsDatabase.ResultsChannel
   SendChatMessage("<TributeLoot> Results", channel)

   for i,v in ipairs(gItemListTable) do
      resultMessage = v.ItemLink
      counter = 0
      for index, value in ipairs(v.InList) do
         resultMessage = resultMessage .. " " .. value .. " "
         counter = counter + 1
      end

      for index, value in ipairs(v.RotList) do
         resultMessage = resultMessage .. " (" .. value .. ") "
         counter = counter + 1
      end

      if (0 == counter) then
         resultMessage = resultMessage .. " rot"
      end

      SendChatMessage(resultMessage, channel)
   end
end


-------------------------------------------------------
-- Prints a message in raid warning if you have assist
-- Prints in raid if you don't have assist
-- Prints in party if you aren't in a raid
-- Prints in say if you aren't in a party (used for solo testing)
-------------------------------------------------------
function PrintRaidMessage(message)
   local channel

   if (GetNumRaidMembers() > 0) then
      if IsRaidLeader() or IsRaidOfficer() then
         channel = "RAID_WARNING"
      else
         channel = "RAID"
      end
   elseif (GetNumPartyMembers() > 0) then
      channel = "PARTY"
   else
      channel = "SAY"
   end

   SendChatMessage(message, channel)
end


-------------------------------------------------------
-- Handles incoming whispers
-------------------------------------------------------
function WhisperHandler(ChatFrameSelf, event, arg1, arg2)
   local self = TributeLoot
   local whisperMsg = arg1
   local player = arg2
   local status = eStatusResults.NONE

   --Do not process messages received from the mod
   if not whisperMsg:find("^<TributeLoot>") then
      local option, itemIndex = self:GetArgs(whisperMsg, 2)

      if (nil ~= option) and (nil~= player) then
         option = option:lower()

         if (nil ~= itemIndex) then
            --Need to convert itemIndex from string to number to index the array
            itemIndex = tonumber(itemIndex:trim())
         end

         if ("in" == option) then
            --Process the command
            if (nil ~= gItemListTable[itemIndex]) then
               status = AddPlayerToList(gItemListTable[itemIndex].InList, player)
            else
               status = eStatusResults.INVALID_ITEM
            end

            --Send whisper response
            if (eStatusResults.SUCCESS == status) then
               SendChatMessage("<TributeLoot> You were added to the [IN] list for " .. gItemListTable[itemIndex].ItemLink .. ". Whisper me \"out " .. itemIndex .. "\" to be removed.", "WHISPER", nil, player)
            elseif (eStatusResults.PLAYER_ALREADY_EXISTS == status) then
               SendChatMessage("<TributeLoot> You are already added to the [IN] list for " .. gItemListTable[itemIndex].ItemLink .. ", so I am ignoring this request.", "WHISPER", nil, player)
            elseif (eStatusResults.INVALID_ITEM == status) then
               SendChatMessage("<TributeLoot> You did not specify a valid item, please try again.", "WHISPER", nil, player)
            end
         elseif ("rot" == option) then
            --Process the command
            if (nil ~= gItemListTable[itemIndex]) then
               status = AddPlayerToList(gItemListTable[itemIndex].RotList, player)
            else
               status = eStatusResults.INVALID_ITEM
            end

            --Send whisper response
            if (eStatusResults.SUCCESS == status) then
               SendChatMessage("<TributeLoot> You were added to the [ROT] list for " .. gItemListTable[itemIndex].ItemLink .. ". Whisper me \"out " .. itemIndex .. "\" to be removed.", "WHISPER", nil, player)
            elseif (eStatusResults.PLAYER_ALREADY_EXISTS == status) then
               SendChatMessage("<TributeLoot> You are already added to the [ROT] list for " .. gItemListTable[itemIndex].ItemLink .. ", so I am ignoring this request.", "WHISPER", nil, player)
            elseif (eStatusResults.INVALID_ITEM == status) then
               SendChatMessage("<TributeLoot> You did not specify a valid item, please try again.", "WHISPER", nil, player)
            end
         elseif ("out" == option) then
            local listString = ""

            --Process the command
            if (nil ~= gItemListTable[itemIndex]) then
               status = RemovePlayerFromList(gItemListTable[itemIndex].InList, player)
               if (eStatusResults.SUCCESS == status) then
                  listString = "[IN]"
               end

               status = RemovePlayerFromList(gItemListTable[itemIndex].RotList, player)
               if(eStatusResults.SUCCESS == status) then
                  --If the player was also removed from the [IN] list, then append "and"
                  if ("" ~= listString) then
                     listString = listString .. " and "
                  end

                  listString = listString .. "[ROT]"
               end
            else
               status = eStatusResults.INVALID_ITEM
            end

            --Send whisper response
            if ("" ~= listString) then
               SendChatMessage("<TributeLoot> You were removed from the " .. listString .. " list for " .. gItemListTable[itemIndex].ItemLink .. ".", "WHISPER", nil, player)
            elseif (eStatusResults.PLAYER_NOT_FOUND == status) then
               SendChatMessage("<TributeLoot> You are not on the lists for " .. gItemListTable[itemIndex].ItemLink .. ", so I cannot remove you.", "WHISPER", nil, player)
            elseif (eStatusResults.INVALID_ITEM == status) then
               SendChatMessage("<TributeLoot> You did not specify a valid item, please try again.", "WHISPER", nil, player)
            end
         end
      end
   end

   --Do not display whispers if the mod handled it
   if (eStatusResults.NONE ~= status) then
      return true
   end
end


-------------------------------------------------------
-- Handles outgoing whispers
-------------------------------------------------------
function WhisperInformHandler(ChatFrameSelf, event, arg1, arg2)
   --Do not display whispers sent by the mod
   if arg1:find("^<TributeLoot>") then
      return true
   end
end


-------------------------------------------------------
-- Handles slash commands
-------------------------------------------------------
function SlashHandler(option)
   local self = TributeLoot

   --Make the option case insensitive
   option = option:lower()

   if ("link" == option) or ("l" == option) then
      LinkLoot()
   elseif ("results" == option) or ("r" == option) then
      PrintLootResults()
   elseif ("clear" == option) then
      if (true == ClearItems()) then
		   self:Print("Previous results were cleared.")
      else
         self:Print("Could not clear previous results.")
      end
   elseif ("options" == option) or ("o" == option) then
      self:ShowConfig()
   else
      self:Print(self.version)
      self:Print("/tl link")
      self:Print("/tl results")
      self:Print("/tl clear")
      self:Print("/tl options")
   end
end


-------------------------------------------------------
-- Initialize the option frames
-------------------------------------------------------
function TributeLoot:SetupOptions()
   LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("TributeLoot", options)

   self.optionsFrames = {}
	self.optionsFrames.general = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("TributeLoot", "TributeLoot", nil, "General")
end


-------------------------------------------------------
-- Show the option window
-------------------------------------------------------
function TributeLoot:ShowConfig()
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrames.general)
end


-------------------------------------------------------
-- Called whenever our database profile is changed
-------------------------------------------------------
function TributeLoot:OnProfileChanged(event, database, newProfileKey)
   gOptionsDatabase = database.profile
end


-------------------------------------------------------
-- AddOn Initialization
-------------------------------------------------------
function TributeLoot:OnInitialize()
   self.db = LibStub("AceDB-3.0"):New("TLDB", defaults, true)
   self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")

   gOptionsDatabase = self.db.profile

   self:RegisterChatCommand("tl", SlashHandler)
   self:SetupOptions()
end


-------------------------------------------------------
-- Executes when the addon is enabled
-------------------------------------------------------
function TributeLoot:OnEnable()
   self:Print("Enabled");
end


-------------------------------------------------------
-- Executes when the addon is disabled
-------------------------------------------------------
function TributeLoot:OnDisable()
   self:Print("Disabled");
end
