local API
local db

local CreateFrame        = CreateFrame
local UIParent           = UIParent
local GameTooltip        = GameTooltip
local PlaySoundFile      = PlaySoundFile
local PlaySound          = PlaySound
local format             = string.format
local pairs              = pairs
local type               = type
local unpack             = unpack
local floor              = math.floor
local tinsert            = tinsert
local _G                 = _G

local C_HEADER  = { 1, 0.82, 0 }
local C_LABEL   = { 1, 1, 1 }
local C_VALUE   = { 0.6, 0.9, 1 }
local C_DIM     = { 0.5, 0.5, 0.5 }

local widgetCounter = 0
local function UniqueName(prefix)
    widgetCounter = widgetCounter + 1
    return "DefileAlert_" .. prefix .. widgetCounter
end

local function MakeHeader(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetTextColor(unpack(C_HEADER))
    fs:SetText(text)
    return fs
end

local function MakeSeparator(parent, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 16, y)
    line:SetPoint("TOPRIGHT", -16, y)
    line:SetHeight(1)
    line:SetTexture(1, 0.82, 0, 0.25)
    return line
end

local function MakeCheckbox(parent, x, y, label, dbKey, onChange)
    local name = UniqueName("CB")
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetWidth(26)
    cb:SetHeight(26)

    local text = cb:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    text:SetTextColor(unpack(C_LABEL))
    text:SetText(label)

    cb:SetScript("OnClick", function(self)
        local checked = (self:GetChecked() == 1)
        db[dbKey] = checked
        if onChange then onChange(checked) end
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)

    cb.Refresh = function(self)
        self:SetChecked(db[dbKey])
    end

    return cb
end

local function MakeSlider(parent, x, y, label, dbKey, minVal, maxVal, step, valueFmt, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", x, y)
    container:SetWidth(320)
    container:SetHeight(50)

    local title = container:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetTextColor(unpack(C_LABEL))

    local sliderName = UniqueName("Slider")
    local slider = CreateFrame("Slider", sliderName, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 0, -18)
    slider:SetWidth(200)
    slider:SetHeight(17)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)

    local low  = _G[sliderName .. "Low"]
    local high = _G[sliderName .. "High"]
    local txt  = _G[sliderName .. "Text"]
    if low  then low:SetText("");  low:Hide()  end
    if high then high:SetText(""); high:Hide() end
    if txt  then txt:SetText("");  txt:Hide()  end

    local function UpdateLabel(val)
        title:SetText(label .. ": " .. format(valueFmt, val))
    end

    slider:SetScript("OnValueChanged", function(self, val)
        local snapped = floor(val / step + 0.5) * step
        db[dbKey] = snapped
        UpdateLabel(snapped)
        if onChange then onChange(snapped) end
    end)

    container.slider = slider
    container.Refresh = function(self)
        local v = db[dbKey]
        slider:SetValue(v)
        UpdateLabel(v)
    end

    return container
end

local function MakeColorSwatch(parent, x, y, label, dbKey, hasAlpha, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", x, y)
    container:SetWidth(200)
    container:SetHeight(22)

    local swatch = CreateFrame("Button", nil, container)
    swatch:SetPoint("LEFT", 0, 0)
    swatch:SetWidth(20)
    swatch:SetHeight(20)

    local bgTex = swatch:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints()
    bgTex:SetTexture(0.15, 0.15, 0.15, 1)

    local colorTex = swatch:CreateTexture(nil, "ARTWORK")
    colorTex:SetAllPoints()

    local border = swatch:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetTexture(1, 1, 1, 0.3)

    local text = container:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    text:SetPoint("LEFT", swatch, "RIGHT", 6, 0)
    text:SetTextColor(unpack(C_LABEL))
    text:SetText(label)

    local function UpdateSwatch()
        local c = db[dbKey]
        colorTex:SetTexture(c.r, c.g, c.b, c.a or 1)
    end

    swatch:SetScript("OnClick", function()
        local c = db[dbKey]
        local prev_r, prev_g, prev_b, prev_a = c.r, c.g, c.b, c.a

        local function OnColorChanged()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = hasAlpha and (1 - OpacitySliderFrame:GetValue()) or (c.a or 1)
            c.r, c.g, c.b, c.a = r, g, b, a
            UpdateSwatch()
            if onChange then onChange(c) end
        end

        local function OnCancel()
            c.r, c.g, c.b, c.a = prev_r, prev_g, prev_b, prev_a
            UpdateSwatch()
            if onChange then onChange(c) end
        end

        ColorPickerFrame.func        = nil
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.cancelFunc  = nil
        ColorPickerFrame:Hide()
        ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
        ColorPickerFrame.hasOpacity    = hasAlpha
        ColorPickerFrame.opacity       = hasAlpha and (1 - (c.a or 1)) or 0
        ColorPickerFrame.previousValues = {
            r = prev_r, g = prev_g, b = prev_b, a = prev_a
        }
        ColorPickerFrame.func        = OnColorChanged
        ColorPickerFrame.opacityFunc = OnColorChanged
        ColorPickerFrame.cancelFunc  = OnCancel
        ColorPickerFrame:Show()
    end)

    swatch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label)
        local c = db[dbKey]
        if hasAlpha then
            GameTooltip:AddLine(format("R:%.0f  G:%.0f  B:%.0f  A:%.0f%%",
                c.r * 255, c.g * 255, c.b * 255, (c.a or 1) * 100), unpack(C_VALUE))
        else
            GameTooltip:AddLine(format("R:%.0f  G:%.0f  B:%.0f",
                c.r * 255, c.g * 255, c.b * 255), unpack(C_VALUE))
        end
        GameTooltip:AddLine("Click to change", unpack(C_DIM))
        GameTooltip:Show()
    end)
    swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)

    container.Refresh = function(self) UpdateSwatch() end
    UpdateSwatch()

    return container
end

local function MakeEditBox(parent, x, y, label, dbKey, width)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", x, y)
    container:SetWidth(width + 100)
    container:SetHeight(40)

    local title = container:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetTextColor(unpack(C_LABEL))
    title:SetText(label)

    local eb = CreateFrame("EditBox", nil, container)
    eb:SetPoint("TOPLEFT", 0, -16)
    eb:SetWidth(width)
    eb:SetHeight(22)
    eb:SetFontObject(ChatFontNormal)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(256)

    local bg = eb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0, 0, 0, 0.5)

    local function Edge(p1, p2, w, h)
        local t = eb:CreateTexture(nil, "ARTWORK")
        t:SetPoint(unpack(p1))
        t:SetPoint(unpack(p2))
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
        t:SetTexture(0.4, 0.4, 0.4, 0.8)
    end
    Edge({"TOPLEFT", -1, 1},     {"TOPRIGHT", 1, 1},     nil, 1)
    Edge({"BOTTOMLEFT", -1, -1}, {"BOTTOMRIGHT", 1, -1}, nil, 1)
    Edge({"TOPLEFT", -1, 1},     {"BOTTOMLEFT", -1, -1}, 1, nil)
    Edge({"TOPRIGHT", 1, 1},     {"BOTTOMRIGHT", 1, -1}, 1, nil)

    eb:SetScript("OnEnterPressed", function(self)
        db[dbKey] = self:GetText()
        self:ClearFocus()
    end)
    eb:SetScript("OnEscapePressed", function(self)
        self:SetText(db[dbKey] or "")
        self:ClearFocus()
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        db[dbKey] = self:GetText()
    end)

    container.editbox = eb
    container.Refresh = function(self)
        eb:SetText(db[dbKey] or "")
    end

    return container
end

local function MakeDropdown(parent, x, y, label, dbKey, options, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", x, y)
    container:SetWidth(260)
    container:SetHeight(22)

    local title = container:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    title:SetPoint("LEFT", 0, 0)
    title:SetTextColor(unpack(C_LABEL))
    title:SetText(label)

    local btn = CreateFrame("Button", nil, container)
    btn:SetPoint("LEFT", title, "RIGHT", 8, 0)
    btn:SetWidth(140)
    btn:SetHeight(22)

    local btnBg = btn:CreateTexture(nil, "BACKGROUND")
    btnBg:SetAllPoints()
    btnBg:SetTexture(0.1, 0.1, 0.1, 0.8)

    local btnBorder = btn:CreateTexture(nil, "ARTWORK")
    btnBorder:SetPoint("TOPLEFT", -1, 1)
    btnBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    btnBorder:SetTexture(0.4, 0.4, 0.4, 0.6)
    btnBorder:SetDrawLayer("ARTWORK", -1)

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    btnText:SetPoint("LEFT", 6, 0)
    btnText:SetTextColor(unpack(C_VALUE))

    local arrow = btn:CreateFontString(nil, "OVERLAY")
    arrow:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetTextColor(0.7, 0.7, 0.7)
    arrow:SetText("v")

    local menu = CreateFrame("Frame", nil, btn)
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    menu:SetWidth(140)
    menu:SetFrameStrata("TOOLTIP")
    menu:Hide()

    local menuBg = menu:CreateTexture(nil, "BACKGROUND")
    menuBg:SetAllPoints()
    menuBg:SetTexture(0.05, 0.05, 0.05, 0.95)

    local itemHeight = 20
    menu:SetHeight(#options * itemHeight + 4)

    for idx = 1, #options do
        local opt = options[idx]
        local item = CreateFrame("Button", nil, menu)
        item:SetPoint("TOPLEFT", 2, -(idx - 1) * itemHeight - 2)
        item:SetWidth(136)
        item:SetHeight(itemHeight)

        local hl = item:CreateTexture(nil, "ARTWORK")
        hl:SetAllPoints()
        hl:SetTexture(1, 1, 1, 0.1)
        hl:Hide()

        local iText = item:CreateFontString(nil, "OVERLAY")
        iText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        iText:SetPoint("LEFT", 4, 0)
        iText:SetTextColor(1, 1, 1)
        iText:SetText(opt.label)

        item:SetScript("OnEnter", function() hl:Show() end)
        item:SetScript("OnLeave", function() hl:Hide() end)
        item:SetScript("OnClick", function()
            db[dbKey] = opt.value
            btnText:SetText(opt.label)
            menu:Hide()
            if onChange then onChange(opt.value) end
            PlaySound("igMainMenuOptionCheckBoxOn")
        end)
    end

    btn:SetScript("OnClick", function()
        if menu:IsShown() then menu:Hide() else menu:Show() end
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)

    menu:SetScript("OnShow", function(self)
        self:SetScript("OnUpdate", function(self2)
            if not self2:IsMouseOver() and not btn:IsMouseOver() then
                if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
                    self2:Hide()
                end
            end
        end)
    end)
    menu:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    container.Refresh = function(self)
        local current = db[dbKey]
        for i = 1, #options do
            if options[i].value == current then
                btnText:SetText(options[i].label)
                return
            end
        end
        btnText:SetText(current or "???")
    end

    return container
end

local function MakeButton(parent, x, y, width, text, onClick, r, g, b)
    r, g, b = r or 0.2, g or 0.2, b or 0.2

    local btn = CreateFrame("Button", nil, parent)
    btn:SetPoint("TOPLEFT", x, y)
    btn:SetWidth(width)
    btn:SetHeight(24)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(r, g, b, 0.8)
    btn._bg = bg
    btn._r, btn._g, btn._b = r, g, b

    local brd = btn:CreateTexture(nil, "ARTWORK")
    brd:SetPoint("TOPLEFT", -1, 1)
    brd:SetPoint("BOTTOMRIGHT", 1, -1)
    brd:SetTexture(0.5, 0.5, 0.5, 0.5)
    brd:SetDrawLayer("ARTWORK", -1)

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    lbl:SetPoint("CENTER", 0, 1)
    lbl:SetTextColor(1, 1, 1)
    lbl:SetText(text)
    btn.label = lbl

    btn:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        if onClick then onClick() end
    end)
    btn:SetScript("OnEnter", function(self)
        self._bg:SetTexture(r + 0.15, g + 0.15, b + 0.15, 0.9)
    end)
    btn:SetScript("OnLeave", function(self)
        self._bg:SetTexture(r, g, b, 0.8)
    end)

    return btn
end

local optionsFrame = nil
local allWidgets  = {}

local function RefreshAll()
    for i = 1, #allWidgets do
        if allWidgets[i].Refresh then
            allWidgets[i]:Refresh()
        end
    end
end

local function BuildOptionsFrame()
    if optionsFrame then return end

    API = DefileAlertAPI
    db  = API.db

    local PANEL_W = 440

    local f = CreateFrame("Frame", "DefileAlertOptionsFrame", UIParent)
    f:SetWidth(PANEL_W)
    f:SetHeight(100)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0.05, 0.05, 0.08, 0.94)

    local function AddBorderLine(p1, p2, w, h)
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetPoint(p1[1], p1[2], p1[3])
        t:SetPoint(p2[1], p2[2], p2[3])
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
        t:SetTexture(1, 0.2, 0.2, 0.6)
    end
    AddBorderLine({"TOPLEFT", -1, 1},     {"TOPRIGHT", 1, 1},     nil, 2)
    AddBorderLine({"BOTTOMLEFT", -1, -1}, {"BOTTOMRIGHT", 1, -1}, nil, 2)
    AddBorderLine({"TOPLEFT", -1, 1},     {"BOTTOMLEFT", -1, -1}, 2, nil)
    AddBorderLine({"TOPRIGHT", 1, 1},     {"BOTTOMRIGHT", 1, -1}, 2, nil)

    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(36)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)

    local titleBg = titleBar:CreateTexture(nil, "ARTWORK")
    titleBg:SetAllPoints()
    titleBg:SetTexture(0.15, 0.02, 0.02, 0.9)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    titleText:SetPoint("LEFT", 14, 0)
    titleText:SetText("|cffff0000Defile|r|cffffffffAlert|r")

    local verText = titleBar:CreateFontString(nil, "OVERLAY")
    verText:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    verText:SetPoint("LEFT", titleText, "RIGHT", 8, -1)
    verText:SetTextColor(unpack(C_DIM))
    verText:SetText("v" .. (API.version or "?"))

    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -8)
    closeBtn:SetWidth(22)
    closeBtn:SetHeight(22)
    closeBtn:SetFrameLevel(titleBar:GetFrameLevel() + 10)

    local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
    closeBg:SetAllPoints()
    closeBg:SetTexture(0, 0, 0, 0)

    local closeLabel = closeBtn:CreateFontString(nil, "OVERLAY")
    closeLabel:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    closeLabel:SetPoint("CENTER", 0, 1)
    closeLabel:SetText("X")
    closeLabel:SetTextColor(0.8, 0.3, 0.3)

    closeBtn:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        f:Hide()
    end)
    closeBtn:SetScript("OnEnter", function()
        closeLabel:SetTextColor(1, 0.5, 0.5)
        closeBg:SetTexture(1, 0.3, 0.3, 0.15)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeLabel:SetTextColor(0.8, 0.3, 0.3)
        closeBg:SetTexture(0, 0, 0, 0)
    end)

    tinsert(UISpecialFrames, "DefileAlertOptionsFrame")

    MakeButton(titleBar, PANEL_W - 248, -6, 90,
        "Test Self",
        function() if API.TestSelf then API.TestSelf() end end,
        0.5, 0.05, 0.05)

    MakeButton(titleBar, PANEL_W - 150, -6, 90,
        "Test Other",
        function() if API.TestOther then API.TestOther() end end,
        0.05, 0.1, 0.4)

    local Y = -44

    MakeHeader(f, "ANNOUNCEMENTS", 16, Y)
    Y = Y - 22

    allWidgets[#allWidgets + 1] = MakeCheckbox(f, 16, Y,
        "Announce to Raid/RW", "announceEnabled")
    Y = Y - 28

    allWidgets[#allWidgets + 1] = MakeDropdown(f, 36, Y,
        "Channel:", "announceChannel", {
            { label = "RAID_WARNING", value = "RAID_WARNING" },
            { label = "RAID",         value = "RAID" },
            { label = "SAY",          value = "SAY" },
            { label = "YELL",         value = "YELL" },
        })
    Y = Y - 28

    allWidgets[#allWidgets + 1] = MakeCheckbox(f, 16, Y,
        "Downgrade to /raid if not assist/leader", "downgradeToRaid")
    Y = Y - 28

    allWidgets[#allWidgets + 1] = MakeCheckbox(f, 16, Y,
        "Whisper target player", "whisperTarget")
    Y = Y - 28

    MakeSeparator(f, Y)
    Y = Y - 14

    MakeHeader(f, "SCREEN FLASH", 16, Y)
    Y = Y - 22

    allWidgets[#allWidgets + 1] = MakeCheckbox(f, 16, Y,
        "Flash when Defile on YOU", "flashSelf")
    allWidgets[#allWidgets + 1] = MakeColorSwatch(f, 280, Y + 3,
        "Self Color", "selfFlashColor", true)
    Y = Y - 28

    allWidgets[#allWidgets + 1] = MakeCheckbox(f, 16, Y,
        "Flash when Defile on others", "flashOther")
    allWidgets[#allWidgets + 1] = MakeColorSwatch(f, 280, Y + 3,
        "Other Color", "otherFlashColor", true)
    Y = Y - 30

    allWidgets[#allWidgets + 1] = MakeSlider(f, 36, Y,
        "Flash Duration", "flashDuration", 0.3, 2.0, 0.1, "%.1fs")
    Y = Y - 46

    MakeSeparator(f, Y)
    Y = Y - 14

    MakeHeader(f, "CENTER TEXT", 16, Y)
    Y = Y - 22

    allWidgets[#allWidgets + 1] = MakeCheckbox(f, 16, Y,
        "Show center screen text", "centerText")
    Y = Y - 28

    allWidgets[#allWidgets + 1] = MakeColorSwatch(f, 36, Y,
        "Self Text Color", "selfTextColor", false)
    allWidgets[#allWidgets + 1] = MakeColorSwatch(f, 230, Y,
        "Other Text Color", "centerTextColor", false)
    Y = Y - 30

    allWidgets[#allWidgets + 1] = MakeSlider(f, 36, Y,
        "Text Size", "textScale", 20, 72, 2, "%.0f")
    Y = Y - 46

    allWidgets[#allWidgets + 1] = MakeSlider(f, 36, Y,
        "Text Duration", "textDuration", 1.0, 8.0, 0.5, "%.1fs")
    Y = Y - 46

    MakeSeparator(f, Y)
    Y = Y - 14

    MakeHeader(f, "SOUND", 16, Y)
    Y = Y - 22

    allWidgets[#allWidgets + 1] = MakeCheckbox(f, 16, Y,
        "Play alert sound", "soundEnabled")
    Y = Y - 28

    allWidgets[#allWidgets + 1] = MakeEditBox(f, 36, Y,
        "Current sound:", "soundFile", 360)
    Y = Y - 42

    local soundPresets = {
        { label = "Air Horn",        path = "Interface\\AddOns\\DefileAlert\\Sounds\\AirHorn.ogg" },
        { label = "Raid Warning",    path = "Sound\\interface\\RaidWarning.wav" },
        { label = "PVP Flag",        path = "Sound\\Spells\\PVPFlagTaken.wav" },
        { label = "Horde Bell",      path = "Sound\\Doodad\\BellTollHorde.wav" },
        { label = "Alliance Bell",   path = "Sound\\Doodad\\BellTollAlliance.wav" },
    }

    local function MakeSoundBtn(px, py, preset)
        MakeButton(f, px, py, 185, preset.label,
            function()
                db.soundFile = preset.path
                PlaySoundFile(preset.path)
                RefreshAll()
            end, 0.12, 0.12, 0.18)
    end

    MakeSoundBtn(36,  Y, soundPresets[1])
    MakeSoundBtn(228, Y, soundPresets[2])
    Y = Y - 28
    MakeSoundBtn(36,  Y, soundPresets[3])
    MakeSoundBtn(228, Y, soundPresets[4])
    Y = Y - 28

    MakeSeparator(f, Y)
    Y = Y - 14

    MakeHeader(f, "MESSAGES", 16, Y)
    Y = Y - 22

    allWidgets[#allWidgets + 1] = MakeEditBox(f, 36, Y,
        "Raid Message (%s = player name):", "raidMessage", 360)
    Y = Y - 46

    allWidgets[#allWidgets + 1] = MakeEditBox(f, 36, Y,
        "Whisper Message:", "whisperMessage", 360)
    Y = Y - 42

    MakeSeparator(f, Y)
    Y = Y - 18

    local resetHolder = CreateFrame("Frame", nil, f)
    resetHolder:SetPoint("TOPLEFT", PANEL_W / 2 - 100, Y)
    resetHolder:SetWidth(200)
    resetHolder:SetHeight(50)

    local confirmLabel, btnYes, btnNo, btnReset

    local function HideConfirm()
        confirmLabel:Hide()
        btnYes:Hide()
        btnNo:Hide()
        btnReset:Show()
    end

    btnReset = MakeButton(resetHolder, 30, 0, 140,
        "Reset All Defaults",
        function()
            btnReset:Hide()
            confirmLabel:Show()
            btnYes:Show()
            btnNo:Show()
        end, 0.4, 0.08, 0.08)

    confirmLabel = resetHolder:CreateFontString(nil, "OVERLAY")
    confirmLabel:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    confirmLabel:SetPoint("TOP", resetHolder, "TOP", 0, 2)
    confirmLabel:SetTextColor(1, 0.3, 0.3)
    confirmLabel:SetText("Reset all settings?")
    confirmLabel:Hide()

    btnYes = MakeButton(resetHolder, 15, -18, 76,
        "Yes",
        function()
            local defs = API.defaults
            for k, v in pairs(defs) do
                if type(v) == "table" then
                    if type(db[k]) ~= "table" then db[k] = {} end
                    for k2, v2 in pairs(v) do db[k][k2] = v2 end
                else
                    db[k] = v
                end
            end
            HideConfirm()
            RefreshAll()
            print("|cffff4444[DefileAlert]|r Settings reset to defaults.")
        end, 0.15, 0.45, 0.15)
    btnYes:Hide()

    btnNo = MakeButton(resetHolder, 109, -18, 76,
        "No",
        function()
            HideConfirm()
        end, 0.45, 0.1, 0.1)
    btnNo:Hide()

    Y = Y - 50

    local statusBar = CreateFrame("Frame", nil, f)
    statusBar:SetPoint("BOTTOMLEFT", 0, 0)
    statusBar:SetPoint("BOTTOMRIGHT", 0, 0)
    statusBar:SetHeight(22)

    local statusBg = statusBar:CreateTexture(nil, "ARTWORK")
    statusBg:SetAllPoints()
    statusBg:SetTexture(0.08, 0.08, 0.12, 0.9)

    local statusText = statusBar:CreateFontString(nil, "OVERLAY")
    statusText:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    statusText:SetPoint("LEFT", 10, 0)
    statusText:SetTextColor(unpack(C_DIM))

    f:SetScript("OnShow", function()
        HideConfirm()
        local active = API.zoneActive and API.zoneActive()
        local lk = API.lkUnit and API.lkUnit()
        statusText:SetText(
            "Zone: " .. (active and "|cff00ff00ICC|r" or "|cffaaaaaanot ICC|r")
            .. "    LK: " .. (lk or "|cffaaaaaanone|r")
        )
        RefreshAll()
    end)

    local finalH = -(Y) + 44
    f:SetHeight(finalH)

    optionsFrame = f
end

function DefileAlertOptions_Toggle()
    if not DefileAlertAPI or not DefileAlertAPI.db then
        print("|cffff4444[DefileAlert]|r Core not loaded yet.")
        return
    end

    BuildOptionsFrame()

    if optionsFrame:IsShown() then
        optionsFrame:Hide()
    else
        optionsFrame:Show()
    end
end

local blizzPanel = CreateFrame("Frame", "DefileAlertBlizzPanel")
blizzPanel.name = "DefileAlert"

local bpTitle = blizzPanel:CreateFontString(nil, "OVERLAY")
bpTitle:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
bpTitle:SetPoint("TOPLEFT", 16, -16)
bpTitle:SetTextColor(1, 0.2, 0.2)
bpTitle:SetText("|cffff0000Defile|r|cffffffffAlert|r")

local bpDesc = blizzPanel:CreateFontString(nil, "OVERLAY")
bpDesc:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
bpDesc:SetPoint("TOPLEFT", 16, -40)
bpDesc:SetTextColor(1, 1, 1)
bpDesc:SetText("Type  |cff00ff00/da|r  to open the configuration panel,\nor click the button below.")

local bpBtn = CreateFrame("Button", "DefileAlertOpenBtn", blizzPanel, "UIPanelButtonTemplate")
bpBtn:SetPoint("TOPLEFT", 16, -80)
bpBtn:SetWidth(200)
bpBtn:SetHeight(28)
bpBtn:SetText("Open DefileAlert Config")
bpBtn:SetScript("OnClick", function()
    if DefileAlertOptions_Toggle then
        DefileAlertOptions_Toggle()
    end
end)

InterfaceOptions_AddCategory(blizzPanel)