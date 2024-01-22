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

GGnomeRunner.CountRacers = function()
    local numberOfRaiders = 0
    local playerGUID = GnomeRunner.playerGUID

    for index = 1, IsInRaid() and _G.MAX_RAID_MEMBERS or _G.MEMBERS_PER_RAID_GROUP do
        local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, isAssistant, _, _ = GetRaidRosterInfo(index)
        
        if isAssistant then
            -- Skip assistants
        else
            local unitGUID = UnitGUID("raid" .. index)
            if unitGUID and unitGUID ~= playerGUID then
                numberOfRaiders = numberOfRaiders + 1
            end
        end
    end

    GnomeRunner.totalRacers = numberOfRaiders
end

GnomeRunner.CheckPlayer = function()
    local playerName = UnitName("player")

    local inRaid = IsInRaid()
    local _, instanceType, _, _, _, _, _, instanceMapID = GetInstanceInfo()

    if inRaid and instanceType == "raid" then
        GnomeRunner.CountRacers()  -- Corrected function call
        GnomeRunner.totalDeaths = 0  -- Reset totalDeaths

        for i = 1, GetNumGroupMembers() do  -- Using GetNumGroupMembers for better adaptability
            local unit = "raid" .. i

            if UnitIsDeadOrGhost(unit) and UnitName(unit) == playerName then
                GnomeRunner.totalDeaths = GnomeRunner.totalDeaths + 1
                SendChatMessage(playerName .. " has died!", "RAID_WARNING")
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

-- Modify the function to broadcast sound only if the player is the raid leader
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

function GnomeRunner.StartRace()
    if not GnomeRunner.raceInProgress then
        GnomeRunner.raceInProgress = true
        GnomeRunner.raceStartTime = GetServerTime()
        GnomeRunner.totalDeaths = 0
        GnomeRunner.totalRacers = 0
        GnomeRunner.totalGoldDistributed = 0

        -- Delayed announcement for Gnome Runner usage
        C_Timer.After(GnomeRunner.startDelay, function()
            SendChatMessage("Gnome Runner is active! To start a race, please use /gr payout.", "RAID_WARNING")
        end)

        local countdown = GnomeRunner.countdownSeconds
        countTimer = C_Timer.NewTicker(1, function()
            if countdown == GnomeRunner.countdownSeconds then
                SendChatMessage("The Race: " .. GnomeRunner.raceName .. " is starting!", "RAID_WARNING")
            end

            if countdown > 0 then
                SendChatMessage(countdown, "RAID_WARNING")
                countdown = countdown - 1
            else
                SendChatMessage("GO GO GO! " .. GnomeRunner.raceName .. " has just begun!", "RAID_WARNING")
                GnomeRunner.PlayRaceStartSound()
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
GnomeRunner.startDelay = 20

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


function GnomeRunner.OnPlayerDead()
    GnomeRunner.CheckPlayer()
end

function GnomeRunner.OnRaidRosterUpdate()
    GnomeRunner.CountRacers()
end

function GnomeRunner.OnChatMsgAddon(prefix, message, channel, sender)
    if GnomeRunner.OnAddonMessageReceived then
        GnomeRunner.OnAddonMessageReceived(prefix, message, channel, sender)
    end
end

function GnomeRunner.OnPlayerEnteringWorld()
    GnomeRunner.CheckPlayer()
end

function GnomeRunner.RegisterSlashCommands()
    -- Your existing slash command registration
    SlashCmdList["GNOMERUNNER"] = function(msg)
        GnomeRunner.HandleSlashCommand(msg)
    end
    SLASH_GNOMERUNNER1 = "/gnomerunner"
    SLASH_GNOMERUNNER2 = "/gr"
end

function GnomeRunner.HandleSlashCommand(msg)
    -- Your existing slash command handling logic
    if msg == "startrace" then
        GnomeRunner.StartRace()
    elseif msg == "endrace" then
        GnomeRunner.EndRace()
    elseif msg == "info" then
        GnomeRunner.PrintRaceInfo()
    elseif msg:match("^namerace") then
    local _, newName = strsplit(" ", msg)
    if newName then
        GnomeRunner.SetRaceName(newName)
    else
        print("Usage: /gr namerace [new race name]")
    end
    elseif msg:match("^payout") then
        local _, amount = strsplit(" ", msg)
        if amount then
            GnomeRunner.payout(tonumber(amount))
        else
            print("Usage: /gr payout [amount]")
        end
    else
        print("Unknown command. Available commands: startrace, endrace, info, setrace, payout")
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
    print("Total Gold Distributed: " .. GnomeRunner.totalGoldDistributed)
    print("Race: " .. tostring(GnomeRunner.raceInProgress))
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