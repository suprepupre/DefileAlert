local GetTime              = GetTime
local UnitGUID             = UnitGUID
local UnitName             = UnitName
local UnitExists           = UnitExists
local UnitIsUnit           = UnitIsUnit
local GetNumRaidMembers    = GetNumRaidMembers
local IsRaidLeader         = IsRaidLeader
local IsRaidOfficer        = IsRaidOfficer
local SendChatMessage      = SendChatMessage
local PlaySoundFile        = PlaySoundFile
local CreateFrame          = CreateFrame
local GetZoneText          = GetZoneText
local select               = select
local tonumber             = tonumber
local pairs                = pairs
local format               = string.format
local strsub               = string.sub
local strfind              = string.find
local strtrim              = strtrim
local strlower             = string.lower
local print                = print
local type                 = type
local UIParent             = UIParent

local ADDON_VERSION = "1.0.3-diag"

local DEFILE_IDS = {
    [72762] = true,
    [73708] = true,
    [73709] = true,
    [73710] = true,
}

local LK_NPC_ID = 36597

local EV_CLEU             = "COMBAT_LOG_EVENT_UNFILTERED"
local EV_SPELL_CAST_START = "SPELL_CAST_START"
local EV_SPELL_SUMMON     = "SPELL_SUMMON"
local EV_UNIT_SPELLCAST   = "UNIT_SPELLCAST_START"

local ICC_ZONE = "Icecrown Citadel"

local DEBOUNCE_SEC    = 2.0
local PENDING_TIMEOUT = 0.5

local ALERT_SOUND = "Interface\\AddOns\\DefileAlert\\Sounds\\AirHorn.ogg"

local pending      = false
local lastAnnounce = 0
local lkGUID       = nil
local zoneActive   = false
local detected     = false
local pendingGUID  = nil
local pendingStart = 0
local diagMode     = false
local castDetectTime = 0

local TARG = {
    boss1  = "boss1target",
    boss2  = "boss2target",
    boss3  = "boss3target",
    boss4  = "boss4target",
    focus  = "focustarget",
    target = "targettarget",
}

local defaults = {
    announceEnabled  = true,
    announceChannel  = "RAID_WARNING",
    downgradeToRaid  = true,
    whisperTarget    = true,
    flashSelf        = true,
    flashOther       = false,
    soundEnabled     = true,
    centerText       = true,
    selfFlashColor   = { r = 1, g = 0, b = 0, a = 0.45 },
    otherFlashColor  = { r = 0, g = 0.8, b = 0, a = 0.35 },
    centerTextColor  = { r = 1, g = 1, b = 0 },
    selfTextColor    = { r = 1, g = 0.1, b = 0.1 },
    raidMessage      = "{skull} DEFILE >> %s << {skull}",
    whisperMessage   = "{skull} DEFILE ON YOU — MOVE! {skull}",
    soundFile        = "Interface\\AddOns\\DefileAlert\\Sounds\\AirHorn.ogg",
    textScale        = 46,
    flashDuration    = 0.9,
    textDuration     = 3.5,
}

local db

DefileAlertAPI = {}

local function IsGUID(str)
    if not str then return true end
    if str == "" then return true end
    return strfind(str, "^0x") ~= nil
end

local function GUIDtoPlayerName(guid)
    if not guid then return nil end
    local n = GetNumRaidMembers()
    if n > 0 then
        for i = 1, n do
            local uid = "raid" .. i
            if UnitGUID(uid) == guid then
                return UnitName(uid)
            end
        end
    else
        if UnitGUID("player") == guid then
            return UnitName("player")
        end
        if UnitExists("party1") then
            for i = 1, 4 do
                local uid = "party" .. i
                if UnitExists(uid) and UnitGUID(uid) == guid then
                    return UnitName(uid)
                end
            end
        end
    end
    return nil
end

local function FindLKUnit(knownGUID)
    for i = 1, 4 do
        local uid = "boss" .. i
        if UnitExists(uid) then
            local g = UnitGUID(uid)
            if g and ((knownGUID and g == knownGUID)
                      or GUIDtoNPC(g) == LK_NPC_ID) then
                return uid
            end
        end
    end
    if UnitExists("focus") then
        local g = UnitGUID("focus")
        if g and ((knownGUID and g == knownGUID)
                  or GUIDtoNPC(g) == LK_NPC_ID) then
            return "focus"
        end
    end
    if UnitExists("target") then
        local g = UnitGUID("target")
        if g and ((knownGUID and g == knownGUID)
                  or GUIDtoNPC(g) == LK_NPC_ID) then
            return "target"
        end
    end
    return nil
end

local function ReadBossTargetName(lkUnit)
    if not lkUnit then return nil end
    local t = TARG[lkUnit]
    if t then return UnitName(t) end
    return UnitName(lkUnit .. "target")
end

local function InitDB()
    if type(DefileAlertDB) ~= "table" then DefileAlertDB = {} end
    for k, v in pairs(defaults) do
        if DefileAlertDB[k] == nil then
            if type(v) == "table" then
                DefileAlertDB[k] = {}
                for k2, v2 in pairs(v) do DefileAlertDB[k][k2] = v2 end
            else
                DefileAlertDB[k] = v
            end
        end
    end
    db = DefileAlertDB

    if db.soundFile == "Sound\\interface\\RaidWarning.wav" then
        db.soundFile = defaults.soundFile
    end
    if not db.soundFile or db.soundFile == "" then
        db.soundFile = defaults.soundFile
    end
    if db.otherFlashColor and db.otherFlashColor.r == 0
       and db.otherFlashColor.g == 0.3 and db.otherFlashColor.b == 1 then
        db.otherFlashColor.r = defaults.otherFlashColor.r
        db.otherFlashColor.g = defaults.otherFlashColor.g
        db.otherFlashColor.b = defaults.otherFlashColor.b
        db.otherFlashColor.a = defaults.otherFlashColor.a
    end

    DefileAlertAPI.db = db
    DefileAlertAPI.defaults = defaults
    DefileAlertAPI.version = ADDON_VERSION
    DefileAlertAPI.zoneActive = function() return zoneActive end
    DefileAlertAPI.lkUnit = function() return lkGUID end
end

local function GUIDtoNPC(guid)
    if not guid then return 0 end
    return tonumber(strsub(guid, 9, 12), 16) or 0
end

local flashFrame = CreateFrame("Frame", "DefileAlertFlash", UIParent)
flashFrame:SetFrameStrata("TOOLTIP")
flashFrame:SetAllPoints(UIParent)
flashFrame:Hide()

local flashTex = flashFrame:CreateTexture(nil, "BACKGROUND")
flashTex:SetAllPoints(flashFrame)

local flashElapsed = 0

flashFrame:SetScript("OnUpdate", function(self, dt)
    flashElapsed = flashElapsed + dt
    local dur = db and db.flashDuration or 0.9
    local fade = dur * 0.33
    if flashElapsed >= dur then
        self:Hide()
        return
    end
    if flashElapsed > fade then
        local alpha = flashTex._baseAlpha or 0.4
        flashTex:SetAlpha(alpha * (dur - flashElapsed) / (dur - fade))
    end
end)

local function FlashScreen(r, g, b, a)
    flashTex:SetTexture(r, g, b, a or 0.4)
    flashTex:SetAlpha(a or 0.4)
    flashTex._baseAlpha = a or 0.4
    flashElapsed = 0
    flashFrame:Show()
end

DefileAlertAPI.FlashScreen = FlashScreen

local textFrame = CreateFrame("Frame", "DefileAlertText", UIParent)
textFrame:SetFrameStrata("FULLSCREEN_DIALOG")
textFrame:SetAllPoints(UIParent)
textFrame:Hide()

local alertText = textFrame:CreateFontString(nil, "OVERLAY")
alertText:SetFont("Fonts\\FRIZQT__.TTF", 46, "OUTLINE")
alertText:SetPoint("CENTER", 0, 180)
alertText:SetShadowOffset(2, -2)
alertText:SetShadowColor(0, 0, 0, 1)

local textElapsed = 0

textFrame:SetScript("OnUpdate", function(self, dt)
    textElapsed = textElapsed + dt
    local dur = db and db.textDuration or 3.5
    local fade = dur - 1.0
    if textElapsed >= dur then self:Hide(); return end
    if textElapsed > fade then alertText:SetAlpha(dur - textElapsed) end
end)

local function ShowCenterText(text, r, g, b)
    local size = db and db.textScale or 46
    alertText:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    alertText:SetText(text)
    alertText:SetTextColor(r or 1, g or 1, b or 0, 1)
    alertText:SetAlpha(1)
    textElapsed = 0
    textFrame:Show()
end

DefileAlertAPI.ShowCenterText = ShowCenterText

local function AnnounceDefile(targetName, source)
    if not targetName or targetName == "" then return end
    if IsGUID(targetName) then return end

    local now = GetTime()
    if (now - lastAnnounce) < DEBOUNCE_SEC then return end
    lastAnnounce = now
    detected = true

    if diagMode and source then
        local delay = (castDetectTime > 0) and format("%.0fms", (now - castDetectTime) * 1000) or "?"
        print("|cff00ffff[DIAG]|r Announced via: |cff00ff00" .. source .. "|r  delay: " .. delay)
    end

    local isMe = UnitIsUnit(targetName, "player")

    if db.centerText then
        if isMe then
            local c = db.selfTextColor
            ShowCenterText(">>> DEFILE ON YOU <<<", c.r, c.g, c.b)
        else
            local c = db.centerTextColor
            ShowCenterText("Defile: " .. targetName, c.r, c.g, c.b)
        end
    end

    if isMe and db.flashSelf then
        local c = db.selfFlashColor
        FlashScreen(c.r, c.g, c.b, c.a)
    elseif not isMe and db.flashOther then
        local c = db.otherFlashColor
        FlashScreen(c.r, c.g, c.b, c.a)
    end

    if db.soundEnabled and isMe then
        local path = db.soundFile
        if not path or path == "" then path = ALERT_SOUND end
        PlaySoundFile(path)
    end

    if db.announceEnabled and GetNumRaidMembers() > 0 then
        local channel = db.announceChannel
        if channel == "RAID_WARNING"
           and not IsRaidOfficer() and not IsRaidLeader() then
            channel = db.downgradeToRaid and "RAID" or nil
        end
        if channel then
            SendChatMessage(format(db.raidMessage, targetName), channel)
        end
    end

    if db.whisperTarget and not isMe and GetNumRaidMembers() > 0 then
        SendChatMessage(db.whisperMessage, "WHISPER", nil, targetName)
    end

    print("|cffff4444[DefileAlert]|r " .. targetName
        .. (isMe and " |cffff0000(YOU!)|r" or ""))
end

DefileAlertAPI.AnnounceDefile = AnnounceDefile
DefileAlertAPI.TestSelf = function()
    lastAnnounce = 0
    AnnounceDefile(UnitName("player"), "TEST")
end
DefileAlertAPI.TestOther = function()
    lastAnnounce = 0
    AnnounceDefile("TestRaider", "TEST")
end

local core = CreateFrame("Frame", "DefileAlertCore")

core:SetScript("OnEvent", function(self, event, ...)

    if event == EV_CLEU then
        local _, etype = ...

                if etype == EV_SPELL_CAST_START then
            local _, _, srcGUID, srcName, _, destGUID, destName, _, spellId = ...

            if not DEFILE_IDS[spellId] then return end

            castDetectTime = GetTime()
            lkGUID = srcGUID

            if detected and (GetTime() - lastAnnounce) < DEBOUNCE_SEC then
                return
            end

            if destName and destName ~= "" and not IsGUID(destName) then
                if diagMode then
                    print("|cff00ffff[DIAG]|r CLEU destName: " .. destName)
                end
                AnnounceDefile(destName, "CLEU_CAST_destName")
                pending = false
                return
            end

            if destGUID and destGUID ~= "" and not IsGUID(destGUID) then
                local name = GUIDtoPlayerName(destGUID)
                if name then
                    if diagMode then
                        print("|cff00ffff[DIAG]|r CLEU destGUID resolved: " .. name)
                    end
                    AnnounceDefile(name, "CLEU_CAST_destGUID")
                    pending = false
                    return
                end
            end

            local lkUnit = FindLKUnit(srcGUID)
            if lkUnit then
                local name = ReadBossTargetName(lkUnit)
                if name and name ~= "" and not IsGUID(name) then
                    if diagMode then
                        print("|cff00ffff[DIAG]|r CLEU boss target: " .. name)
                    end
                    AnnounceDefile(name, "CLEU_CAST_bosstarget")
                    pending = false
                    return
                end
            end

            if diagMode then
                print("|cff00ffff[DIAG]|r CLEU: no target resolved, pending...")
            end

            pending = true
            pendingStart = GetTime()
            return
        end

        if etype == EV_SPELL_SUMMON and pending then
            local spellId = select(9, ...)
            if DEFILE_IDS[spellId] then
                pending = false
                pendingGUID = nil
            end
        end
        return
    end

    if event == EV_UNIT_SPELLCAST then
        local unit, _, _, _, spellId = ...
        if not DEFILE_IDS[spellId] then return end
        lkGUID = UnitGUID(unit)
        castDetectTime = GetTime()

        if detected and (GetTime() - lastAnnounce) < DEBOUNCE_SEC then
            return
        end

        local name = ReadBossTargetName(unit)

        if diagMode then
            print("|cff00ffff[DIAG]|r === UNIT_SPELLCAST_START ===")
            print("|cff00ffff[DIAG]|r   unit: " .. tostring(unit))
            print("|cff00ffff[DIAG]|r   spellId: " .. tostring(spellId))
            print("|cff00ffff[DIAG]|r   Boss target: " .. tostring(name))
        end

        if name and name ~= "" and not IsGUID(name) then
            AnnounceDefile(name, "UNIT_SPELLCAST_bosstarget")
            pending = false
            pendingGUID = nil
        end
        return
    end

    if event == "ZONE_CHANGED_NEW_AREA"
       or event == "PLAYER_ENTERING_WORLD" then
        local zone = GetZoneText()
        if zone == ICC_ZONE then
            if not zoneActive then
                zoneActive = true
                self:RegisterEvent(EV_CLEU)
                self:RegisterEvent(EV_UNIT_SPELLCAST)
            end
        else
            if zoneActive then
                zoneActive = false
                pending = false
                detected = false
                pendingGUID = nil
                lkGUID = nil
                self:UnregisterEvent(EV_CLEU)
                self:UnregisterEvent(EV_UNIT_SPELLCAST)
            end
        end
        return
    end

    if event == "ADDON_LOADED" then
        if ... ~= "DefileAlert" then return end
        InitDB()
        self:UnregisterEvent("ADDON_LOADED")
        local zone = GetZoneText()
        if zone == ICC_ZONE then
            zoneActive = true
            self:RegisterEvent(EV_CLEU)
            self:RegisterEvent(EV_UNIT_SPELLCAST)
        end
        print("|cffff4444[DefileAlert]|r v" .. ADDON_VERSION .. " loaded"
            .. (zoneActive and " — |cff00ff00ACTIVE|r" or "")
            .. " — /da config | /da diag")
    end
end)

core:SetScript("OnUpdate", function(self, dt)
    if not pending or not pendingGUID then return end
    if (GetTime() - pendingStart) < 0.05 then return end

    local name = GUIDtoPlayerName(pendingGUID)
    if name then
        pending = false
        pendingGUID = nil
        AnnounceDefile(name, "OnUpdate_retry")
        return
    end

    if (GetTime() - pendingStart) >= PENDING_TIMEOUT then
        if diagMode then
            print("|cff00ffff[DIAG]|r TIMEOUT: could not resolve " .. tostring(pendingGUID))
        end
        pending = false
        pendingGUID = nil
    end
end)

core:RegisterEvent("ADDON_LOADED")
core:RegisterEvent("ZONE_CHANGED_NEW_AREA")
core:RegisterEvent("PLAYER_ENTERING_WORLD")

SLASH_DEFILEALERT1 = "/defilealert"
SLASH_DEFILEALERT2 = "/da"

SlashCmdList["DEFILEALERT"] = function(input)
    if not db then InitDB() end
    input = strtrim(strlower(input or ""))

    if input == "config" or input == "options" or input == "opt"
       or input == "gui" or input == "settings" or input == "" then
        if DefileAlertOptions_Toggle then
            DefileAlertOptions_Toggle()
        else
            print("|cffff4444[DefileAlert]|r Options panel not loaded.")
        end
    elseif input == "test" then
        DefileAlertAPI.TestSelf()
    elseif input == "testother" then
        DefileAlertAPI.TestOther()
    elseif input == "diag" then
        diagMode = not diagMode
        if diagMode then
            print("|cff00ffff[DefileAlert DIAG]|r Diagnostic mode |cff00ff00ON|r")
            print("|cff00ffff[DefileAlert DIAG]|r Trigger Defile and check output.")
            print("|cff00ffff[DefileAlert DIAG]|r Copy the [DIAG] lines and send them to me.")
        else
            print("|cff00ffff[DefileAlert DIAG]|r Diagnostic mode |cffff0000OFF|r")
        end
    elseif input == "status" then
        print("|cffff4444[DefileAlert]|r v" .. ADDON_VERSION .. " Status:")
        print("  Zone: " .. (zoneActive and "|cff00ff00ICC|r" or "|cffaaaaaanot ICC|r"))
        print("  LK GUID: " .. (lkGUID or "none"))
        print("  Diag: " .. (diagMode and "|cff00ff00ON|r" or "OFF"))
        print("  Channel: " .. (db.announceEnabled and db.announceChannel or "OFF"))
        print("  Whisper: " .. (db.whisperTarget and "ON" or "OFF"))
    elseif input == "help" then
        print("|cffff4444[DefileAlert]|r Commands:")
        print("  /da — open config panel")
        print("  /da test|testother — test alerts")
        print("  /da diag — toggle diagnostic mode")
        print("  /da status — detailed info")
    else
        print("|cffff4444[DefileAlert]|r Unknown command. /da help")
    end
end