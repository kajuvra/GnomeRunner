-- Create a local table for addon namespace
local GnomeRunner = {}

-- Add your variables to the table
GnomeRunner.frame = CreateFrame("Frame", "GnomeRunnerFrame")
GnomeRunner.flareSpellIDs = {
    [30263] = true, -- Red Smoke Flare
    [30262] = true, -- White Smoke Flare
    [32812] = true, -- Purple Smoke Flare
    [30264] = true  -- Green Smoke Flare
}

-- Moved addonPrefix and soundFile inside the GnomeRunner table
GnomeRunner.addonPrefix = "GnomeRunner"
GnomeRunner.soundFile = "Interface\\AddOns\\GnomeRunner\\Sounds\\GnomeMaleCharge03.ogg"

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

GnomeRunner.UpdateTimer = function()
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

GnomeRunner.EndRace = function()
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

GnomeRunner.CountRacers = function()
    local numberOfRaiders = 0
    local playerGUID = GnomeRunner.playerGUID

    for index = 1, IsInRaid() and 40 or 40 do
        local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, isAssistant, _, _ = GetRaidRosterInfo(index)
        
        if isAssistant or UnitIsGroupLeader("raid" .. index) then
            -- Skip leader and assistants
        else
            local unitGUID = UnitGUID("raid" .. index)
            if unitGUID and unitGUID ~= playerGUID then
                numberOfRaiders = numberOfRaiders + 1
            end
        end
    end

    GnomeRunner.totalRacers = numberOfRaiders
end

-- Modify the CheckPlayer function to store the raid leader's name
function GnomeRunner.CheckPlayer()
    local playerName = UnitName("player")

    local inRaid = IsInRaid()
    local _, instanceType, _, _, _, _, _, instanceMapID = GetInstanceInfo()

    if inRaid and instanceType == "raid" then
        local leaderIndex
        for index = 1, GetNumGroupMembers() do
            local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, isAssistant, _, _ = GetRaidRosterInfo(index)
            
            if isAssistant or UnitIsGroupLeader("raid" .. index) then
                leaderIndex = index
                break  -- Exit the loop once the leader or assistant is found
            end
        end

        if leaderIndex then
            GnomeRunner.raidLeader = GetRaidRosterInfo(leaderIndex)
        end

        GnomeRunner.CountRacers()
        GnomeRunner.totalDeaths = 0  -- Reset totalDeaths
    end
end


-- Modify the existing CheckFlareUsage function
GnomeRunner.CheckFlareUsage = function(spellID)
    if GnomeRunner.raceInProgress then
        local playerName = UnitName("player")

        if GnomeRunner.flareSpellIDs[spellID] then
            if UnitIsGroupLeader("player") then
                SendChatMessage(playerName .. " used a flare!", "RAID")
                GnomeRunner.ReportFlareUsage(playerName) -- Report flare usage to the addon
            else
                C_ChatInfo.SendAddonMessage(GnomeRunner.addonPrefix, "FLARE_USED:" .. playerName .. ":" .. spellID, "WHISPER", GnomeRunner.raidLeader)

            end
        end
    end
end

-- New function to set the payout
GnomeRunner.payout = function(amount)
    local numericAmount = tonumber(amount)
    
    if numericAmount then
        GnomeRunner.prizePot = numericAmount
        GnomeRunner.payoutSet = true
        print("payout for the race set to: " .. amount .. " gold")
        SendChatMessage("payout for the race set to: " .. amount .. " gold", "RAID_WARNING")
    else
        print("Error: Please specify a valid amount for the payout.")
    end
end

-- Function to trigger the sound for race start
GnomeRunner.PlayRaceStartSound = function()
    if IsInRaid() and UnitIsGroupLeader("player") then
        PlaySoundFile(GnomeRunner.soundFile)
        C_ChatInfo.SendAddonMessage(GnomeRunner.addonPrefix, "START_RACE_SOUND", "RAID")
    end
end

-- New function to set the race name with raid warning
GnomeRunner.SetRaceName = function(newName)
    GnomeRunner.raceName = newName
    print("Race name set to: " .. newName)
    SendChatMessage("Race name set to: " .. newName, "RAID_WARNING")
end

-- Moved the definition of OnAddonLoaded above its call
function GnomeRunner.OnAddonLoaded()
    local function DelayedAnnouncement()
        if IsInRaid() then
            print("GnomeRunner addon loaded!")
            SendChatMessage("Gnome Runner is active! To start a race, please use /gr payout.", "RAID_WARNING")
        end
    end

    -- Delayed announcement for Gnome Runner usage
    C_Timer.After(GnomeRunner.startDelay, DelayedAnnouncement)

    GnomeRunner.RegisterSlashCommands()
    GnomeRunner.InitializeFrame()
end

function GnomeRunner.StartRace()
    print("StartRace function called")  -- Add this line for debugging

    if not GnomeRunner.raceInProgress then
        GnomeRunner.raceInProgress = true
        GnomeRunner.raceStartTime = GetServerTime()
        GnomeRunner.totalDeaths = 0
        GnomeRunner.totalRacers = 0
        GnomeRunner.totalGoldDistributed = 0

        local countdown = GnomeRunner.countdownSeconds
        local countTimer

        local DisplayCountdown = function(count)
            if count > 0 then
                SendChatMessage(count, "RAID_WARNING")
            else
                SendChatMessage("GO GO GO! " .. GnomeRunner.raceName .. " has just begun!", "RAID_WARNING")
                GnomeRunner.PlayRaceStartSound()
            end
        end

        countTimer = C_Timer.NewTicker(1, function()
            if countdown == GnomeRunner.countdownSeconds then
                SendChatMessage("The Race: " .. GnomeRunner.raceName .. " is starting!", "RAID_WARNING")
            end

            DisplayCountdown(countdown)

            countdown = countdown - 1
            if countdown < 0 then
                countTimer:Cancel()
                GnomeRunner.frame:SetScript("OnUpdate", function(_, elapsed)
                    GnomeRunner.OnUpdate(elapsed)
                end)
            end
        end)
    else
        print("Race already in progress.")
    end
end

function GnomeRunner.OnEvent(self, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20)
    if event == "ADDON_LOADED" and arg1 == "GnomeRunner" then
        GnomeRunner.OnAddonLoaded()
    elseif event == "PLAYER_DEAD" then
        GnomeRunner.OnPlayerDead()
    elseif event == "RAID_ROSTER_UPDATE" then
        GnomeRunner.OnRaidRosterUpdate()
    elseif event == "CHAT_MSG_ADDON" then
        GnomeRunner.OnChatMsgAddon(arg1, arg2, arg3, arg4)
    elseif event == "PLAYER_ENTERING_WORLD" then
        GnomeRunner.OnPlayerEnteringWorld()
    end
end

-- Add a variable for the delay
GnomeRunner.startDelay = 5

function GnomeRunner.OnGroupRosterUpdate()
    local function DelayedAnnouncement()
        if IsInRaid() then
            print("GnomeRunner addon loaded!")
            SendChatMessage("Gnome Runner is active! To start a race, please use /gr payout.", "RAID_WARNING")
        end
    end

    -- Delayed announcement for Gnome Runner usage
    C_Timer.After(GnomeRunner.startDelay, DelayedAnnouncement)

    GnomeRunner.RegisterSlashCommands()
    GnomeRunner.InitializeFrame()
end

GnomeRunner.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
GnomeRunner.frame:SetScript("OnEvent", function(_, event, ...)
    GnomeRunner.OnEvent(_, event, ...)
end)

-- New function to announce player deaths in raid chat
function GnomeRunner.AnnouncePlayerDeath(playerName)
    SendChatMessage(playerName .. " has died!", "RAID")
end

-- Modify the existing OnPlayerDead function
function GnomeRunner.OnPlayerDead()
    GnomeRunner.CheckPlayer()

    if GnomeRunner.raceInProgress then
        local playerName = UnitName("player")

        if UnitIsGroupLeader("player") then
            GnomeRunner.AnnouncePlayerDeath(playerName) -- Announce player death in raid chat
        else
            C_ChatInfo.SendAddonMessage (GnomeRunner.addonPrefix, "PLAYER_DEAD:" .. playerName, "WHISPER", GnomeRunner.raidLeader)
        end

        GnomeRunner.totalDeaths = GnomeRunner.totalDeaths + 1
    end
end

function GnomeRunner.OnRaidRosterUpdate()
    GnomeRunner.CountRacers()
end

function GnomeRunner.OnChatMsgAddon(prefix, message, channel, sender)
    if prefix == GnomeRunner.addonPrefix then
        if message == "START_RACE_SOUND" then
            PlaySoundFile(GnomeRunner.soundFile)
        end
    end
end

function GnomeRunner.OnPlayerEnteringWorld()
    GnomeRunner.CheckPlayer()
end

function GnomeRunner.RegisterSlashCommands()
    -- The existing slash command registration
    SlashCmdList["GNOMERUNNER"] = function(msg)
        GnomeRunner.HandleSlashCommand(msg)
    end
    SLASH_GNOMERUNNER1 = "/gnomerunner"
    SLASH_GNOMERUNNER2 = "/gr"
end

function GnomeRunner.HandleSlashCommand(msg)
    local isRaidLeader = UnitIsGroupLeader("player")

    local command, arg = strmatch(msg, "^(%S+)%s*(.-)$")

    local function printUsage(message)
        print(message)
    end

    if command == "startrace" then
        if isRaidLeader then
            GnomeRunner.StartRace()
        else
            printUsage("You must be a raid leader to start the race.")
        end
    elseif command == "endrace" then
        if isRaidLeader then
            GnomeRunner.EndRace()
        else
            printUsage("You must be a raid leader to end the race.")
        end
    elseif command == "info" then
        GnomeRunner.PrintRaceInfo()
    elseif command == "namerace" then
        if isRaidLeader then
            if arg and arg ~= "" then
                GnomeRunner.SetRaceName(arg)
            else
                printUsage("Usage: /gr namerace [new race name]")
            end
        else
            printUsage("You must be a raid leader to use this command.")
        end
    elseif command == "payout" then
        if isRaidLeader then
            local amount = tonumber(arg)
            if amount then
                GnomeRunner.payout(amount)
            else
                printUsage("Usage: /gr payout [amount]")
            end
        else
            printUsage("You must be a raid leader to use this command.")
        end
    else
        printUsage("Unknown command. Available commands: startrace, endrace, info, namerace, payout")
    end
end

function GnomeRunner.InitializeFrame()
    GnomeRunner.frame:SetScript("OnUpdate", function(_, elapsed)
        GnomeRunner.OnUpdate(elapsed)
    end)
end

function GnomeRunner.OnUpdate(elapsed)
    GnomeRunner.UpdateTimer()
end

function GnomeRunner.PrintRaceInfo()
    local playerCountMsg = "Number of Players: " .. GnomeRunner.totalRacers
    print("Race Information:")
    print("Race Name: " .. GnomeRunner.raceName)
    print("Total Racers: " .. GnomeRunner.totalRacers)
    print("Total Deaths: " .. GnomeRunner.totalDeaths)
    print("Total Gold Distributed: " .. GnomeRunner.prizePot)
    print("Payout Set: " .. tostring(GnomeRunner.payoutSet))
    print("Race In Progress: " .. tostring(GnomeRunner.raceInProgress))
    SendChatMessage(playerCountMsg, "RAID_WARNING")
end

-- Register events for addon
GnomeRunner.frame:RegisterEvent("ADDON_LOADED")
GnomeRunner.frame:RegisterEvent("PLAYER_DEAD")
GnomeRunner.frame:RegisterEvent("RAID_ROSTER_UPDATE")
GnomeRunner.frame:RegisterEvent("CHAT_MSG_ADDON")
GnomeRunner.frame:RegisterEvent("PLAYER_ENTERING_WORLD")

GnomeRunner.frame:SetScript("OnEvent", function(_, event, ...)
    GnomeRunner.OnEvent(_, event, ...)
end)