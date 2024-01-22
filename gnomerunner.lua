-- Create a local table for your addon namespace
local GnomeRunner = {}

-- Add your variables to the table
GnomeRunner.frame = CreateFrame("Frame", "GnomeRunnerFrame")
GnomeRunner.flareSpellIDs = {
    [30263] = true, -- Red Smoke Flare
    [30262] = true, -- White Smoke Flare
    [32812] = true, -- Purple Smoke Flare
    [30264] = true  -- Green Smoke Flare
}

local addonPrefix = "GnomeRunner"
local soundFile = "Interface\\AddOns\\GnomeRunner\\Sounds\\GnomeMaleCharge03.ogg"

GnomeRunner.prizePot = 0
GnomeRunner.payoutSet = false
GnomeRunner.raceInProgress = false
GnomeRunner.raceStartTime = 0
GnomeRunner.elapsedTime = 0
GnomeRunner.raceName = "Race Event"
GnomeRunner.timerUpdateInterval = 30 -- Update every 30 seconds
GnomeRunner.countdownInProgress = false
GnomeRunner.countdownSeconds = 10
GnomeRunner.totalDeaths = 0
GnomeRunner.totalRacers = 0
GnomeRunner.totalGoldDistributed = 0

GnomeRunner.playerGUID = UnitGUID("player")

local function UpdateTimer()
    if GnomeRunner.raceInProgress then
        local currentTime = GetServerTime()
        GnomeRunner.elapsedTime = math.max(currentTime - GnomeRunner.raceStartTime, 60) -- Ensure at least 1 minute is displayed

        local minutesElapsed = math.floor(GnomeRunner.elapsedTime / 60)
        local secondsElapsed = GnomeRunner.elapsedTime % 60

        -- Check if the elapsed time is a multiple of 30 minutes
        if secondsElapsed == 0 and minutesElapsed > 0 and minutesElapsed % 30 == 0 then
            SendChatMessage("Elapsed Time: " .. minutesElapsed .. " minutes", "RAID")
        end
    end
end

local function EndRace()
    if GnomeRunner.raceInProgress then
        SendChatMessage("Thank you for coming to \"" .. GnomeRunner.raceName .. "\". This is the race's final stats:", "RAID")
        SendChatMessage("Deaths: " .. GnomeRunner.totalDeaths, "RAID")
        SendChatMessage("Total Elapsed Time: " .. math.floor(GnomeRunner.elapsedTime / 60) .. " minutes", "RAID")
        SendChatMessage("Total Racers: " .. GnomeRunner.totalRacers, "RAID")
        SendChatMessage("Total Gold Distributed: " .. GnomeRunner.prizePot .. " gold", "RAID")

        GnomeRunner.raceInProgress = false
        GnomeRunner.raceStartTime = 0
        GnomeRunner.elapsedTime = 0
        GnomeRunner.totalDeaths = 0
        GnomeRunner.totalRacers = 0
        GnomeRunner.totalGoldDistributed = 0
    else
        print("No race in progress.")
    end
end

local function CountRacers()
    local numberOfRaiders = 0
    for index = 1, IsInRaid() and _G.MAX_RAID_MEMBERS or _G.MEMBERS_PER_RAID_GROUP do
        if GetRaidRosterInfo(index) then
            numberOfRaiders = numberOfRaiders + 1
        end
    end
    GnomeRunner.totalRacers = numberOfRaiders
end

local function CheckPlayer()
    local playerName = UnitName("player")

    local inRaid = IsInRaid()
    local _, instanceType, _, _, _, _, _, instanceMapID = GetInstanceInfo() --- First paste
        if inRaid and instanceType == "raid" then
        CountRacers()  -- Update totalRacers using the new function
        GnomeRunner.totalDeaths = 0  -- Reset totalDeaths
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i

            if UnitIsDeadOrGhost(unit) and UnitName(unit) == playerName then
                GnomeRunner.totalDeaths = GnomeRunner.totalDeaths + 1
                SendChatMessage(playerName .. " has died!", "RAID_WARNING")
            end
        end
    end
end

local function PlayRaceStartSound()
    PlaySoundFile(soundFile)

    -- Broadcast addon message to the raid group
    if IsInRaid() then
        print("Sending START_RACE_SOUND message")
        C_ChatInfo.SendAddonMessage(addonPrefix, "START_RACE_SOUND", "RAID")
        print("START_RACE_SOUND message sent")
    end
end

local function OnAddonMessageReceived(prefix, message, channel, sender)
    if prefix == addonPrefix then
        if message == "START_RACE_SOUND" then
            print("Received START_RACE_SOUND message from " .. sender)
            PlaySoundFile(soundFile)
        end
    end
end

function GnomeRunner.frame.OnEvent(self, event, ...)
    if event == "RAID_ROSTER_UPDATE" then
        CheckPlayer()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, _, _, spellID = ...

        if unit == "player" then
            local spellName = GetSpellInfo(spellID)

            if spellName then
                print("Spell Cast Succeeded:", spellName, "ID:", spellID)  -- Print spell information

                -- Check if the spell ID is in GnomeRunner.flareSpellIDs
                if GnomeRunner.flareSpellIDs[spellID] then
                    print("Detected flare spell:", spellName)
                    local playerName = UnitName("player")
                    SendChatMessage(playerName .. " used a flare!", "RAID")
                    SendChatMessage(playerName .. " used a flare!", "RAID_WARNING")
                end
            else
                print("Spell Name not found for ID:", spellID)
                print("flareSpellIDs:", table.concat(GnomeRunner.flareSpellIDs, ", "))
            end
        end
    elseif event == "UNIT_AURA" then
        local unit = ...
        local playerName = UnitName(unit)

        -- Check if the event is for a friendly player
        if UnitIsPlayer(unit) and UnitInRaid(unit) then
            local isAssistant = false
            local isLeader = false

            for i = 1, GetNumGroupMembers() do
                local _, _, subgroup, _, _, _, _, _, _, _, _, isAssistant, isLeader = GetRaidRosterInfo(i)
                if isAssistant or isLeader then
                    -- Ignore assistants and raid leaders
                    return
                end
            end

            local buffs = {}
            for i = 1, 40 do
                local _, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i, "HELPFUL")

                if spellId then
                    local spellName = GetSpellInfo(spellId)
                    table.insert(buffs, spellName)
                else
                    break
                end
            end

            local debuffs = {}
            for i = 1, 40 do
                local _, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i, "HARMFUL")

                if spellId then
                    local spellName = GetSpellInfo(spellId)
                    table.insert(debuffs, spellName)
                else
                    break
                end
            end

            if #buffs > 0 then
                SendChatMessage(playerName .. " gained buffs: " .. table.concat(buffs, ", "), "RAID")
            end
            if #debuffs > 0 then
                SendChatMessage(playerName .. " gained debuffs: " .. table.concat(debuffs, ", "), "RAID")
            end
        end
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessageReceived(...)
    elseif event == "PLAYER_LOGIN" then
        CheckRaidGroupStatus()
        C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix) -- Register the addon message prefix
        self:RegisterEvent("CHAT_MSG_ADDON")
        self:SetScript("OnEvent", OnAddonMessageReceived)
    end
end --- Second paste
GnomeRunner.frame:RegisterEvent("RAID_ROSTER_UPDATE")
GnomeRunner.frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
GnomeRunner.frame:RegisterEvent("UNIT_AURA")
GnomeRunner.frame:RegisterEvent("PLAYER_LOGIN")
GnomeRunner.frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        CheckRaidGroupStatus()
    elseif event == "RAID_ROSTER_UPDATE" then
        CountRacers()
    end
end)

SLASH_START_RACE1 = "/race"
SlashCmdList["START_RACE"] = function(msg)
    if msg == "" then
        if not IsInRaid() then
            print("You are not in a raid. You must be in a raid to use /race.")
            return
        end

        if not UnitIsGroupLeader("player", "RAID") then
            print("You are not the raid leader. Only the raid leader can start the race.")
            return
        end

        if not GnomeRunner.payoutSet or GnomeRunner.raceName == "Race Event" then
            print("Payout or Race Name not set. Use /payout <gold amount> and then /racename <race name> to set the prize pot and race name.")
            return
        end

        if not GnomeRunner.raceInProgress then
            print("Starting the race!")
            GnomeRunner.raceInProgress = true
            GnomeRunner.raceStartTime = GetServerTime()
            GnomeRunner.countdownInProgress = true
            GnomeRunner.countdownSeconds = 10  -- Reset countdown seconds

            C_Timer.NewTicker(1, function()
                if GnomeRunner.countdownInProgress then
                    GnomeRunner.countdownSeconds = GnomeRunner.countdownSeconds - 1
                    if GnomeRunner.countdownSeconds > 0 then
                        SendChatMessage("Race starting in " .. GnomeRunner.countdownSeconds .. " seconds!", "RAID_WARNING")
                    else
                        SendChatMessage("GO GO GO! The race has started for \"" .. GnomeRunner.raceName .. "\"!", "RAID_WARNING")
                        GnomeRunner.countdownInProgress = false
                        GnomeRunner.countdownSeconds = 10

                        print("Playing sound locally")
                        PlaySoundFile(soundFile)  -- Play the race start sound locally for the receiver
                        print("Sound played locally")
                    end
                end
            })

            -- Add the following line to play the sound and send addon message
            PlayRaceStartSound()
        else
            -- End the existing race if a new one is started
            EndRace()
            print("Starting a new race!")
        end
    else
        print("Invalid command. Usage: /race")
    end
end

SLASH_SET_PAYOUT1 = "/payout"
SlashCmdList["SET_PAYOUT"] = function(msg)
    if not IsInRaid() then
        print("You are not in a raid. You must be in a raid to use /payout.")
        return
    end

    local amount = tonumber(string.match(msg:lower(), "%d+"))
    if amount and amount > 0 then
        GnomeRunner.prizePot = amount
        GnomeRunner.payoutSet = true
        print("Prize pot set to " .. amount .. " gold. You can now use /racename and then /race.")
        SendChatMessage("The prize pot for the race has been set to " .. amount .. " gold! Use /racename and then /race to start the race.", "RAID_WARNING")
    else
        print("Invalid command. Usage: /payout gold amount")
    end
end

SLASH_SET_RACENAME1 = "/racename"
SlashCmdList["SET_RACENAME"] = function(msg)
    if not IsInRaid() then
        print("You are not in a raid. You must be in a raid to use /racename.")
        return
    end

    if msg ~= "" then
        GnomeRunner.raceName = msg
        SendChatMessage("Welcome to " .. GnomeRunner.raceName .. "! The race will start shortly.", "RAID_WARNING")
        print("Race name set to: " .. GnomeRunner.raceName)
    else
        print("Invalid command. Usage: /racename <message>")
    end
end

SLASH_END_RACE1 = "/endrace"
SlashCmdList["END_RACE"] = function()
    EndRace()
end

-- Check if the player is in a raid group when the addon loads
local function CheckRaidGroupStatus()
    local inRaid = IsInRaid()
    local inParty = IsInGroup()

    local playerName = UnitName("player") or "Unknown"
    print("Addon loaded for", playerName)
    print("Addon loading event processed")

    if inRaid and UnitIsGroupLeader("player") then
        C_Timer.After(10, function()
            if IsInRaid() then
                C_ChatInfo.SendAddonMessage("GnomeRunner", "ADDON_LOADED", "RAID") -- Inform raid members that the addon is loaded
            else
                print("Gnome Runner: You are in a party. Create a raid to start a race using /payout.")
            end
        end)
    elseif inParty then
        -- If the player is in a party but not in a raid, inform them that a raid is needed
        print("Gnome Runner: You are in a party. Create a raid to start a race using /payout.")
    end
end

-- Register an event to check raid group status when the addon loads
GnomeRunner.frame:RegisterEvent("RAID_ROSTER_UPDATE")
GnomeRunner.frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
GnomeRunner.frame:RegisterEvent("UNIT_AURA")
GnomeRunner.frame:RegisterEvent("PLAYER_LOGIN")

GnomeRunner.frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        CheckRaidGroupStatus()
    elseif event == "RAID_ROSTER_UPDATE" then
        CountRacers()
    end
end) --- Third paste 
-- Function to play the race start sound and send addon message
local function PlayRaceStartSound()
    PlaySoundFile(soundFile)

    -- Broadcast addon message to the raid group
    if IsInRaid() then
        print("Sending START_RACE_SOUND message")
        C_ChatInfo.SendAddonMessage(addonPrefix, "START_RACE_SOUND", "RAID")
        print("START_RACE_SOUND message sent")
    end
end

-- Function to handle addon messages received
local function OnAddonMessageReceived(prefix, message, channel, sender)
    if prefix == addonPrefix then
        if message == "START_RACE_SOUND" then
            print("Received START_RACE_SOUND message from " .. sender)
            PlaySoundFile(soundFile)
        end
    end
end

-- Function to check player status in the raid
local function CheckPlayer()
    local playerName = UnitName("player")

    local inRaid = IsInRaid()
    local _, instanceType, _, _, _, _, _, instanceMapID = GetInstanceInfo()

    if inRaid and instanceType == "raid" then
        CountRacers()  -- Update totalRacers using the new function
        GnomeRunner.totalDeaths = 0  -- Reset totalDeaths

        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i

            if UnitIsDeadOrGhost(unit) and UnitName(unit) == playerName then
                GnomeRunner.totalDeaths = GnomeRunner.totalDeaths + 1
                SendChatMessage(playerName .. " has died!", "RAID_WARNING")
            end
        end
    end
end

-- Function to end the race and display final stats
local function EndRace()
    if GnomeRunner.raceInProgress then
        SendChatMessage("Thank you for coming to \"" .. GnomeRunner.raceName .. "\". This is the race's final stats:", "RAID")
        SendChatMessage("Deaths: " .. GnomeRunner.totalDeaths, "RAID")
        SendChatMessage("Total Elapsed Time: " .. math.floor(GnomeRunner.elapsedTime / 60) .. " minutes", "RAID")
        SendChatMessage("Total Racers: " .. GnomeRunner.totalRacers, "RAID")
        SendChatMessage("Total Gold Distributed: " .. GnomeRunner.prizePot .. " gold", "RAID")

        GnomeRunner.raceInProgress = false
        GnomeRunner.raceStartTime = 0
        GnomeRunner.elapsedTime = 0
        GnomeRunner.totalDeaths = 0
        GnomeRunner.totalRacers = 0
        GnomeRunner.totalGoldDistributed = 0
    else
        print("No race in progress.")
    end
end

-- Function to update the race timer
local function UpdateTimer()
    if GnomeRunner.raceInProgress then
        local currentTime = GetServerTime()
        GnomeRunner.elapsedTime = math.max(currentTime - GnomeRunner.raceStartTime, 60) -- Ensure at least 1 minute is displayed

        local minutesElapsed = math.floor(GnomeRunner.elapsedTime / 60)
        local secondsElapsed = GnomeRunner.elapsedTime % 60

        -- Check if the elapsed time is a multiple of 30 minutes
        if secondsElapsed == 0 and minutesElapsed > 0 and minutesElapsed % 30 == 0 then
            SendChatMessage("Elapsed Time: " .. minutesElapsed .. " minutes", "RAID")
        end
    end
end

-- Function to count the number of racers in the raid
local function CountRacers()
    local numberOfRaiders = 0
    for index = 1, IsInRaid() and _G.MAX_RAID_MEMBERS or _G.MEMBERS_PER_RAID_GROUP do
        if GetRaidRosterInfo(index) then
            numberOfRaiders = numberOfRaiders + 1
        end
    end
    GnomeRunner.totalRacers = numberOfRaiders
end

-- Function to check raid group status
local function CheckRaidGroupStatus()
    local inRaid = IsInRaid()
    local inParty = IsInGroup()

    local playerName = UnitName("player") or "Unknown"
    print("Addon loaded for", playerName)
    print("Addon loading event processed")

    if inRaid and UnitIsGroupLeader("player") then
        C_Timer.After(10, function()
            if IsInRaid() then
                C_ChatInfo.SendAddonMessage("GnomeRunner", "ADDON_LOADED", "RAID") -- Inform raid members that the addon is loaded
            else
                print("Gnome Runner: You are in a party. Create a raid to start a race using /payout.")
            end
        end)
    elseif inParty then
        -- If the player is in a party but not in a raid, inform them that a raid is needed
        print("Gnome Runner: You are in a party. Create a raid to start a race using /payout.")
    end
end

-- Register an event to check raid group status when the addon loads
GnomeRunner.frame:RegisterEvent("RAID_ROSTER_UPDATE")
GnomeRunner.frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
GnomeRunner.frame:RegisterEvent("UNIT_AURA")
GnomeRunner.frame:RegisterEvent("PLAYER_LOGIN")

GnomeRunner.frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        CheckRaidGroupStatus()
    elseif event == "RAID_ROSTER_UPDATE" then
        CountRacers()
    end
end) --- Fourth Paste
-- Function to play the race start sound and send addon message
local function PlayRaceStartSound()
    PlaySoundFile(soundFile)

    -- Broadcast addon message to the raid group
    if IsInRaid() then
        print("Sending START_RACE_SOUND message")
        C_ChatInfo.SendAddonMessage(addonPrefix, "START_RACE_SOUND", "RAID")
        print("START_RACE_SOUND message sent")
    end
end

-- Function to handle addon messages received
local function OnAddonMessageReceived(prefix, message, channel, sender)
    if prefix == addonPrefix then
        if message == "START_RACE_SOUND" then
            print("Received START_RACE_SOUND message from " .. sender)
            PlaySoundFile(soundFile)
        end
    end
end

-- Function to check player status in the raid
local function CheckPlayer()
    local playerName = UnitName("player")

    local inRaid = IsInRaid()
    local _, instanceType, _, _, _, _, _, instanceMapID = GetInstanceInfo()

    if inRaid and instanceType == "raid" then
        CountRacers()  -- Update totalRacers using the new function
        GnomeRunner.totalDeaths = 0  -- Reset totalDeaths

        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i

            if UnitIsDeadOrGhost(unit) and UnitName(unit) == playerName then
                GnomeRunner.totalDeaths = GnomeRunner.totalDeaths + 1
                SendChatMessage(playerName .. " has died!", "RAID_WARNING")
            end
        end
    end
end

-- Function to end the race and display final stats
local function EndRace()
    if GnomeRunner.raceInProgress then
        SendChatMessage("Thank you for coming to \"" .. GnomeRunner.raceName .. "\". This is the race's final stats:", "RAID")
        SendChatMessage("Deaths: " .. GnomeRunner.totalDeaths, "RAID")
        SendChatMessage("Total Elapsed Time: " .. math.floor(GnomeRunner.elapsedTime / 60) .. " minutes", "RAID")
        SendChatMessage("Total Racers: " .. GnomeRunner.totalRacers, "RAID")
        SendChatMessage("Total Gold Distributed: " .. GnomeRunner.prizePot .. " gold", "RAID")

        GnomeRunner.raceInProgress = false
        GnomeRunner.raceStartTime = 0
        GnomeRunner.elapsedTime = 0
        GnomeRunner.totalDeaths = 0
        GnomeRunner.totalRacers = 0
        GnomeRunner.totalGoldDistributed = 0
    else
        print("No race in progress.")
    end
end

-- Function to update the race timer
local function UpdateTimer()
    if GnomeRunner.raceInProgress then
        local currentTime = GetServerTime()
        GnomeRunner.elapsedTime = math.max(currentTime - GnomeRunner.raceStartTime, 60) -- Ensure at least 1 minute is displayed

        local minutesElapsed = math.floor(GnomeRunner.elapsedTime / 60)
        local secondsElapsed = GnomeRunner.elapsedTime % 60

        -- Check if the elapsed time is a multiple of 30 minutes
        if secondsElapsed == 0 and minutesElapsed > 0 and minutesElapsed % 30 == 0 then
            SendChatMessage("Elapsed Time: " .. minutesElapsed .. " minutes", "RAID")
        end
    end
end

-- Function to count the number of racers in the raid
local function CountRacers()
    local numberOfRaiders = 0
    for index = 1, IsInRaid() and _G.MAX_RAID_MEMBERS or _G.MEMBERS_PER_RAID_GROUP do
        if GetRaidRosterInfo(index) then
            numberOfRaiders = numberOfRaiders + 1
        end
    end
    GnomeRunner.totalRacers = numberOfRaiders
end

-- Function to check raid group status
local function CheckRaidGroupStatus()
    local inRaid = IsInRaid()
    local inParty = IsInGroup()

    local playerName = UnitName("player") or "Unknown"
    print("Addon loaded for", playerName)
    print("Addon loading event processed")

    if inRaid and UnitIsGroupLeader("player") then
        C_Timer.After(10, function()
            if IsInRaid() then
                C_ChatInfo.SendAddonMessage("GnomeRunner", "ADDON_LOADED", "RAID") -- Inform raid members that the addon is loaded
            else
                print("Gnome Runner: You are in a party. Create a raid to start a race using /payout.")
            end
        end)
    elseif inParty then
        -- If the player is in a party but not in a raid, inform them that a raid is needed
        print("Gnome Runner: You are in a party. Create a raid to start a race using /payout.")
    end
end

-- Register an event to check raid group status when the addon loads
GnomeRunner.frame:RegisterEvent("RAID_ROSTER_UPDATE")
GnomeRunner.frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
GnomeRunner.frame:RegisterEvent("UNIT_AURA")
GnomeRunner.frame:RegisterEvent("PLAYER_LOGIN")

GnomeRunner.frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        CheckRaidGroupStatus()
    elseif event == "RAID_ROSTER_UPDATE" then
        CountRacers()
    end
end)

SLASH_START_RACE1 = "/race"
SlashCmdList["START_RACE"] = function(msg)
    if msg == "" then
        if not IsInRaid() then
            print("You are not in a raid. You must be in a raid to use /race.")
            return
        end

        if not UnitIsGroupLeader("player", "RAID") then
            print("You are not the raid leader. Only the raid leader can start the race.")
            return
        end

        if not GnomeRunner.payoutSet or GnomeRunner.raceName == "Race Event" then
            print("Payout or Race Name not set. Use /payout <gold amount> and then /racename <race name> to set the prize pot and race name.")
            return
        end

        if not GnomeRunner.raceInProgress then
            print("Starting the race!")
            GnomeRunner.raceInProgress = true
            GnomeRunner.raceStartTime = GetServerTime()
            GnomeRunner.countdownInProgress = true
            GnomeRunner.countdownSeconds = 10  -- Reset countdown seconds

            C_Timer.NewTicker(1, function()
                if GnomeRunner.countdownInProgress then
                    GnomeRunner.countdownSeconds = GnomeRunner.countdownSeconds - 1
                    if GnomeRunner.countdownSeconds > 0 then
                        SendChatMessage("Race starting in " .. GnomeRunner.countdownSeconds .. " seconds!", "RAID_WARNING")
                    else
                        SendChatMessage("GO GO GO! The race has started for \"" .. GnomeRunner.raceName .. "\"!", "RAID_WARNING")
                        GnomeRunner.countdownInProgress = false
                        GnomeRunner.countdownSeconds = 10

                        print("Playing sound locally")
                        PlaySoundFile(soundFile)  -- Play the race start sound locally for the receiver
                        print("Sound played locally")
                    end
                end
            })

            -- Add the following line to play the sound and send addon message
            PlayRaceStartSound()
        else
            -- End the existing race if a new one is started
            EndRace()
            print("Starting a new race!")
        end
    else
        print("Invalid command. Usage: /race")
    end
end

SLASH_SET_PAYOUT1 = "/payout"
SlashCmdList["SET_PAYOUT"] = function(msg)
    if not IsInRaid() then
        print("You are not in a raid. You must be in a raid to use /payout.")
        return
    end

    local amount = tonumber(string.match(msg:lower(), "%d+"))
    if amount and amount > 0 then
        GnomeRunner.prizePot = amount
        GnomeRunner.payoutSet = true
        print("Prize pot set to " .. amount .. " gold. You can now use /racename and then /race.")
        SendChatMessage("The prize pot for the race has been set to " .. amount .. " gold! Use /racename and then /race to start the race.", "RAID_WARNING")
    else
        print("Invalid command. Usage: /payout gold amount")
    end
end

SLASH_SET_RACENAME1 = "/racename"
SlashCmdList["SET_RACENAME"] = function(msg)
    if not IsInRaid() then
        print("You are not in a raid. You must be in a raid to use /racename.")
        return
    end

    if msg ~= "" then
        GnomeRunner.raceName = msg
        SendChatMessage("Welcome to " .. GnomeRunner.raceName .. "! The race will start shortly.", "RAID_WARNING")
        print("Race name set to: " .. GnomeRunner.raceName)
    else
        print("Invalid command. Usage: /racename <message>")
    end
end

SLASH_END_RACE1 = "/endrace"
SlashCmdList["END_RACE"] = function()
    EndRace()
end --- fifth paste
-- Check if the player is in a raid group when the addon loads
local function CheckRaidGroupStatus()
    local inRaid = IsInRaid()
    local inParty = IsInGroup()

    local playerName = UnitName("player") or "Unknown"
    print("Addon loaded for", playerName)
    print("Addon loading event processed")

    if inRaid and UnitIsGroupLeader("player") then
        C_Timer.After(10, function()
            if IsInRaid() then
                C_ChatInfo.SendAddonMessage("GnomeRunner", "ADDON_LOADED", "RAID") -- Inform raid members that the addon is loaded
            else
                print("Gnome Runner: You are in a party. Create a raid to start a race using /payout.")
            end
        end)
    elseif inParty then
        -- If the player is in a party but not in a raid, inform them that a raid is needed
        print("Gnome Runner: You are in a party. Create a raid to start a race using /payout.")
    end
end

-- Register an event to check raid group status when the addon loads
GnomeRunner.frame:RegisterEvent("RAID_ROSTER_UPDATE")
GnomeRunner.frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
GnomeRunner.frame:RegisterEvent("UNIT_AURA")
GnomeRunner.frame:RegisterEvent("PLAYER_LOGIN")

GnomeRunner.frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        CheckRaidGroupStatus()
    elseif event == "RAID_ROSTER_UPDATE" then
        CountRacers()
    end
end)