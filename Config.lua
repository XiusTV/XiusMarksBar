--[[
    Xius Marks Bar - Config.lua
    Defaults, saved variables, options panel, and slash commands.
]]

local ADDON, XMB = ...
_G.XiusMarksBar = XMB

XMB.ADDON = ADDON
XMB.TITLE = "Xius Marks Bar"
XMB.VERSION = "1.3.6"
XMB.DB_VERSION = 1

local function IsSecret(value)
    if type(issecretvalue) ~= "function" then
        return false
    end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret and true or false
end

local function IsFiniteNumber(value)
    if type(value) ~= "number" or IsSecret(value) then
        return false
    end
    return value == value and value > -math.huge and value < math.huge
end

XMB.IsSecret = IsSecret
XMB.IsFiniteNumber = IsFiniteNumber

XMB.MARK_TEXTURES = {}
for i = 1, 8 do
    XMB.MARK_TEXTURES[i] = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i
end

XMB.MARK_NAMES = {
    "Star",
    "Circle",
    "Diamond",
    "Triangle",
    "Moon",
    "Square",
    "Cross",
    "Skull",
}

-- World marker index -> raid icon texture (square, triangle, diamond, cross, star, circle, moon, skull).
XMB.WORLD_ICON = { 6, 4, 3, 7, 1, 2, 5, 8 }
XMB.WORLD_NAMES = {
    "Blue Square",
    "Green Triangle",
    "Purple Diamond",
    "Red Cross",
    "Yellow Star",
    "Orange Circle",
    "Silver Moon",
    "White Skull",
}

BINDING_HEADER_XIUSMARKSBAR = "Xius Marks Bar"
BINDING_NAME_XIUSMB_UNIT_WHEEL = "Open target mark wheel"
BINDING_NAME_XIUSMB_WORLD_WHEEL = "Open world marker wheel"
_G["BINDING_NAME_CLICK XiusMB_FlywheelToggle:LeftButton"] = "Open target mark wheel"
_G["BINDING_NAME_CLICK XiusMB_FlywheelWorldToggle:LeftButton"] = "Open world marker wheel"
for i = 1, 8 do
    local icon = "|T" .. XMB.MARK_TEXTURES[i] .. ":14:14:0:0|t "
    _G["BINDING_NAME_CLICK XiusMB_Key_TM" .. i .. ":LeftButton"] = icon .. "Mark Target: " .. XMB.MARK_NAMES[i]
end
_G["BINDING_NAME_CLICK XiusMB_Key_TClear:LeftButton"] =
    "|TInterface\\Buttons\\UI-GroupLoot-Pass-Up:14:14:0:0|t Clear Target Mark"
for i = 1, 8 do
    local icon = "|T" .. XMB.MARK_TEXTURES[XMB.WORLD_ICON[i]] .. ":14:14:0:0|t "
    _G["BINDING_NAME_CLICK XiusMB_Key_WM" .. i .. ":LeftButton"] = icon .. "World Marker: " .. XMB.WORLD_NAMES[i]
end
_G["BINDING_NAME_CLICK XiusMB_Key_WClear:LeftButton"] =
    "|TInterface\\Buttons\\UI-GroupLoot-Pass-Up:14:14:0:0|t Clear World Markers"

XMB.defaults = {
    dbVersion = 1,
    isLocked = false,
    showTooltips = true,
    onlyInGroup = false,
    showCountdown = true,
    showPull5 = true,
    showPull10 = true,
    showPull20 = true,
    showReady = true,
    showRole = true,
    enableTargetMarks = true,
    enableWorldMarks = true,
    showTarget = false,
    showWorld = false,
    flywheelUnits = true,
    flywheelWorld = true,
    growthDirection = "AUTO",
    scale = 1,
}

local optionWidgets = {}
local keybindWidgets = {}
local wrappingLabels = {}
local optionsCategory
local optionsPanel
local syncingOptions = false
local activeBindButton = nil
local keyCaptureFrame = nil

local function FormatBindingKey(key)
    if not key or key == "" then
        return "|cff808080Not Bound|r"
    end
    local text = key
    if type(GetBindingText) == "function" then
        local ok, localized = pcall(GetBindingText, key, "KEY_", true)
        if ok and type(localized) == "string" and localized ~= "" then
            text = localized
        end
    end
    if #text > 12 then
        text = text:gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-")
        text = text:gsub("MOUSEWHEELUP", "MWUp"):gsub("MOUSEWHEELDOWN", "MWDn")
        text = text:gsub("BUTTON", "Mouse")
    end
    return "|cffffd100" .. text .. "|r"
end

local function PersistBindings()
    local set = (GetCurrentBindingSet and GetCurrentBindingSet()) or 1
    if set ~= 1 and set ~= 2 then
        set = 1
    end
    if type(SaveBindings) == "function" then
        pcall(SaveBindings, set)
    elseif type(AttemptToSaveBindings) == "function" then
        pcall(AttemptToSaveBindings, set)
    end
end

local function ClearCommandBinding(command, silent)
    if not command or not GetBindingKey or not SetBinding then
        return false
    end
    if InCombatLockdown() then
        if not silent then
            XMB:Print("Leave combat to change keybindings.")
        end
        return false
    end
    local changed = false
    pcall(function()
        local keys = { GetBindingKey(command) }
        for i = 1, #keys do
            local k = keys[i]
            if k and k ~= "" then
                SetBinding(k)
                changed = true
            end
        end
        if changed then
            PersistBindings()
        end
    end)
    return changed
end

local function AssignCommandBinding(command, label, fullKey)
    if not command or not fullKey or fullKey == "" or not GetBindingKey or not SetBinding then
        return false
    end
    if InCombatLockdown() then
        XMB:Print("Leave combat to change keybindings.")
        return false
    end
    pcall(function()
        local prevAction = GetBindingAction and GetBindingAction(fullKey) or nil
        local oldKeys = { GetBindingKey(command) }
        for i = 1, #oldKeys do
            local k = oldKeys[i]
            if k and k ~= "" and k ~= fullKey then
                SetBinding(k)
            end
        end
        SetBinding(fullKey, command)
        PersistBindings()
        if prevAction and prevAction ~= "" and prevAction ~= command then
            local prevName = _G["BINDING_NAME_" .. prevAction] or prevAction
            XMB:Print(string.format("Bound [%s] to %s (unbound from %s).", fullKey, label or command, prevName))
        end
    end)
    return true
end

local function BuildModifiedKey(key)
    local prefix = ""
    if IsAltKeyDown and IsAltKeyDown() then
        prefix = prefix .. "ALT-"
    end
    if IsControlKeyDown and IsControlKeyDown() then
        prefix = prefix .. "CTRL-"
    end
    if IsShiftKeyDown and IsShiftKeyDown() then
        prefix = prefix .. "SHIFT-"
    end
    if IsMetaKeyDown and IsMetaKeyDown() then
        prefix = prefix .. "META-"
    end
    return prefix .. key
end

local GROWTH_LABELS = {
    AUTO = "Auto (Screen Position)",
    UP = "Always Expand Up",
    DOWN = "Always Expand Down",
}
local GROWTH_ORDER = { "AUTO", "UP", "DOWN" }

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then
        dst = {}
    end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil or type(dst[k]) ~= type(v) or IsSecret(dst[k]) then
            dst[k] = v
        end
    end
    return dst
end

function XMB:GetDB()
    return self.db
end

function XMB:InitDB()
    local saved = XiusMarksBarDB
    local hadPull5 = type(saved) == "table" and saved.showPull5 ~= nil
    local hadPull10 = type(saved) == "table" and saved.showPull10 ~= nil
    local hadPull20 = type(saved) == "table" and saved.showPull20 ~= nil
    local oldCountdown = type(saved) == "table" and saved.showCountdown
    XiusMarksBarDB = CopyDefaults(self.defaults, XiusMarksBarDB)
    self.db = XiusMarksBarDB
    local db = self.db
    if oldCountdown == false then
        if not hadPull5 then
            db.showPull5 = false
        end
        if not hadPull10 then
            db.showPull10 = false
        end
        if not hadPull20 then
            db.showPull20 = false
        end
    end

    if db.growthDirection ~= "UP" and db.growthDirection ~= "DOWN" then
        db.growthDirection = "AUTO"
    end
    if not IsFiniteNumber(db.scale) then
        db.scale = 1
    end
    if db.scale < 0.6 then
        db.scale = 0.6
    elseif db.scale > 1.6 then
        db.scale = 1.6
    end
    if not IsFiniteNumber(db.headerLeft) or not IsFiniteNumber(db.headerBottom) or not IsFiniteNumber(db.headerTop) then
        db.headerLeft = nil
        db.headerBottom = nil
        db.headerTop = nil
    end
    db.dbVersion = self.DB_VERSION
end

function XMB:NotifySettingsChanged()
    if self.ApplySettings then
        self:ApplySettings()
    end
end

function XMB:Print(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffe6c866Xius Marks Bar|r: " .. tostring(msg))
    end
end

local FLYWHEEL_KEYS = {
    flywheelUnits = true,
    flywheelWorld = true,
}

local function SetDBValue(key, value)
    local db = XMB.db
    if not db then
        return
    end
    db[key] = value
    if FLYWHEEL_KEYS[key] then
        if XMB.ApplyFlywheelSettings then
            XMB:ApplyFlywheelSettings()
        end
        return
    end
    XMB:NotifySettingsChanged()
end

local function FontFace()
    if GameFontHighlight and GameFontHighlight.GetFont then
        local ok, face = pcall(GameFontHighlight.GetFont, GameFontHighlight)
        if ok and type(face) == "string" and face ~= "" then
            return face
        end
    end
    if GameFontNormal and GameFontNormal.GetFont then
        local ok, face = pcall(GameFontNormal.GetFont, GameFontNormal)
        if ok and type(face) == "string" and face ~= "" then
            return face
        end
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function EnsureFont(fs, size)
    if not fs then
        return
    end
    local hasFace = false
    if fs.GetFont then
        local ok, face = pcall(fs.GetFont, fs)
        hasFace = ok and type(face) == "string" and face ~= ""
    end
    if not hasFace then
        pcall(fs.SetFont, fs, FontFace(), size or 12, "")
    end
end

local function PaintText(fs, r, g, b)
    if not fs then
        return
    end
    EnsureFont(fs, 12)
    pcall(fs.SetJustifyH, fs, "LEFT")
    pcall(fs.SetTextColor, fs, r, g, b, 1)
end

local function SafeText(fs, text, size)
    if not fs then
        return
    end
    EnsureFont(fs, size or 12)
    pcall(fs.SetText, fs, text or "")
end

local function ApplyCheckState(cb, checked)
    checked = checked and true or false
    cb:SetChecked(checked)
    if cb.mark then
        cb.mark:SetShown(checked)
    end
end

local function MakeCheck(parent, label, key, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x, y)

    local stock = cb.Text or cb.text
    if not stock and cb.GetName and cb:GetName() then
        stock = _G[cb:GetName() .. "Text"]
    end
    if stock then
        SafeText(stock, "")
        stock:Hide()
    end

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    SafeText(text, label, 12)
    PaintText(text, 1, 0.97, 0.90)
    cb.label = text

    local labelW = 260
    if text.GetStringWidth then
        local ok, w = pcall(text.GetStringWidth, text)
        if ok and IsFiniteNumber(w) and w > 40 then
            labelW = math.min(420, math.ceil(w) + 12)
        end
    end
    cb:SetHitRectInsets(0, -labelW, 0, 0)

    local checkedTex = cb:GetCheckedTexture()
    if checkedTex then
        checkedTex:SetAlpha(0)
    end

    -- The stock check texture does not show on this client's settings canvas.
    local mark = cb:CreateTexture(nil, "OVERLAY")
    mark:SetColorTexture(0.95, 0.78, 0.28, 1)
    mark:SetSize(10, 10)
    mark:SetPoint("CENTER", cb, "CENTER", 0, 0)
    mark:Hide()
    cb.mark = mark

    if XMB.db then
        ApplyCheckState(cb, XMB.db[key])
    end

    cb:SetScript("OnClick", function(self)
        if syncingOptions then
            return
        end
        local checked = self:GetChecked() and true or false
        if self.mark then
            self.mark:SetShown(checked)
        end
        if PlaySound and SOUNDKIT then
            if checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
                pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            elseif (not checked) and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF then
                pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            end
        end
        SetDBValue(key, checked)
    end)
    optionWidgets[key] = cb
    return cb
end

local function MakeLabel(parent, text, template, x, y, wrap)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetJustifyH("LEFT")
    local size = 12
    if template == "GameFontNormalLarge" then
        size = 16
    end
    SafeText(fs, text, size)
    if template == "GameFontHighlightSmall" or template == "GameFontHighlight" then
        PaintText(fs, 0.95, 0.92, 0.84)
    end
    if wrap then
        fs:SetJustifyV("TOP")
        fs:SetWidth(460)
        if fs.SetWordWrap then
            fs:SetWordWrap(true)
        end
        wrappingLabels[#wrappingLabels + 1] = fs
    end
    return fs
end

local function IsCheckWidget(widget)
    if not widget then
        return false
    end
    if widget.SetChecked and widget.GetChecked then
        return true
    end
    if widget.IsObjectType then
        local ok, isCheck = pcall(widget.IsObjectType, widget, "CheckButton")
        if ok and isCheck then
            return true
        end
    end
    return false
end

local function SyncOptionsPanel()
    local db = XMB.db
    if not db then
        return
    end
    syncingOptions = true
    for key, widget in pairs(optionWidgets) do
        if key == "growthDirection" then
            if widget.SetText then
                widget:SetText(GROWTH_LABELS[db.growthDirection or "AUTO"] or GROWTH_LABELS.AUTO)
            end
        elseif key == "scale" then
            local pct = math.floor((db.scale or 1) * 100 + 0.5)
            if widget.SetValue then
                widget:SetValue(pct)
            end
            local label = widget.valueText or widget.Text or (widget.GetName and _G[widget:GetName() .. "Text"])
            if label then
                SafeText(label, pct .. "%", 12)
                PaintText(label, 1, 0.97, 0.90)
            end
        elseif IsCheckWidget(widget) then
            ApplyCheckState(widget, db[key])
        end
    end
    for i = 1, #keybindWidgets do
        local btn = keybindWidgets[i]
        if btn and btn.SetText then
            if btn == activeBindButton then
                btn:SetText("|cff40ff40Press a key...|r")
            else
                local k1 = GetBindingKey and GetBindingKey(btn.command) or nil
                btn:SetText(FormatBindingKey(k1))
            end
        end
    end
    syncingOptions = false
end

local function StopBindingCapture()
    activeBindButton = nil
    if keyCaptureFrame and keyCaptureFrame:IsShown() then
        keyCaptureFrame:Hide()
    end
    SyncOptionsPanel()
end

local function StartBindingCapture(btn)
    if not btn or not btn.command then
        return
    end
    if InCombatLockdown() then
        XMB:Print("Leave combat to change keybindings.")
        return
    end
    if activeBindButton == btn then
        StopBindingCapture()
        return
    end
    activeBindButton = btn
    if keyCaptureFrame then
        keyCaptureFrame:Show()
    end
    SyncOptionsPanel()
end

local function ClearAllAddonBindings()
    if InCombatLockdown() then
        XMB:Print("Leave combat to change keybindings.")
        return
    end
    StopBindingCapture()
    local anyCleared = false
    for i = 1, #keybindWidgets do
        local btn = keybindWidgets[i]
        if btn and btn.command then
            if ClearCommandBinding(btn.command, true) then
                anyCleared = true
            end
        end
    end
    SyncOptionsPanel()
    if anyCleared then
        XMB:Print("Cleared all Xius Marks Bar keybindings.")
    else
        XMB:Print("All Xius Marks Bar keybindings are already blank.")
    end
end

local function SyncSoon()
    SyncOptionsPanel()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, SyncOptionsPanel)
        C_Timer.After(0.1, SyncOptionsPanel)
    end
end

function XMB:ResetToDefaults()
    if not self.db then
        self:InitDB()
    end
    local db = self.db
    for k, v in pairs(self.defaults) do
        db[k] = v
    end
    SyncOptionsPanel()
    if self.ApplyFlywheelSettings then
        self:ApplyFlywheelSettings()
    end
    self:NotifySettingsChanged()
end

function XMB:CreateOptions()
    if optionsPanel then
        return
    end

    local panel = CreateFrame("Frame", "XiusMarksBarOptionsPanel")
    panel.name = XMB.TITLE
    panel:Hide()
    if panel.SetClipsChildren then
        panel:SetClipsChildren(true)
    end

    local scroll = CreateFrame("ScrollFrame", "XiusMarksBarOptionsScroll", panel)
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 8)
    if scroll.SetClipsChildren then
        scroll:SetClipsChildren(true)
    end

    local page = CreateFrame("Frame", "XiusMarksBarOptionsPage", scroll)
    page:SetSize(480, 960)
    scroll:SetScrollChild(page)

    local bar = CreateFrame("Slider", "XiusMarksBarOptionsScrollBar", panel)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(16)
    bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -16)
    bar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 16)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    if bar.SetObeyStepOnDrag then
        bar:SetObeyStepOnDrag(true)
    end
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.12, 0.1, 0.07, 0.95)
    track:SetAllPoints()
    bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    local thumb = bar:GetThumbTexture()
    if thumb then
        thumb:SetSize(16, 24)
    end

    local function FitScroll()
        local width = scroll:GetWidth()
        if not IsFiniteNumber(width) or width < 80 then
            width = 480
        end
        page:SetWidth(width)
        local textW = math.max(240, width - 32)
        for i = 1, #wrappingLabels do
            wrappingLabels[i]:SetWidth(textW)
        end
    end

    local function UpdateBar()
        local maxScroll = scroll:GetVerticalScrollRange() or 0
        if not IsFiniteNumber(maxScroll) or maxScroll < 1 then
            maxScroll = 0
        end
        bar:SetMinMaxValues(0, maxScroll)
        local current = scroll:GetVerticalScroll() or 0
        if not IsFiniteNumber(current) or current < 0 then
            current = 0
        end
        if current > maxScroll then
            current = maxScroll
            scroll:SetVerticalScroll(current)
        end
        bar:SetValue(current)
        bar:SetShown(maxScroll > 1)
    end

    local function BindToWindow()
        local parent = panel:GetParent()
        if parent and parent ~= UIParent then
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
        elseif (panel:GetHeight() or 0) < 50 then
            panel:SetSize(560, 420)
        end
        FitScroll()
        UpdateBar()
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local step = 36
        local current = self:GetVerticalScroll() or 0
        local maxScroll = self:GetVerticalScrollRange() or 0
        local nextScroll = current - (delta * step)
        if nextScroll < 0 then
            nextScroll = 0
        end
        if nextScroll > maxScroll then
            nextScroll = maxScroll
        end
        self:SetVerticalScroll(nextScroll)
        bar:SetValue(nextScroll)
    end)
    scroll:SetScript("OnScrollRangeChanged", UpdateBar)
    bar:SetScript("OnValueChanged", function(_, value)
        local current = scroll:GetVerticalScroll() or 0
        if math.abs(current - value) > 0.5 then
            scroll:SetVerticalScroll(value)
        end
    end)

    local y = -16
    MakeLabel(page, "Xius Marks Bar", "GameFontNormalLarge", 16, y)
    y = y - 28
    MakeLabel(
        page,
        "Choose which marks, countdowns, and group buttons stay on the bar. Open this page with /xmb or /xmb config. It also lives under Options, AddOns.",
        "GameFontHighlightSmall",
        16,
        y,
        true
    )
    y = y - 52

    MakeLabel(page, "Bar", "GameFontNormal", 16, y)
    y = y - 26
    MakeCheck(page, "Lock bar (blocks dragging)", "isLocked", 12, y)
    y = y - 28
    MakeCheck(page, "Only show in a group or instance", "onlyInGroup", 12, y)
    y = y - 28
    MakeCheck(page, "Show tooltips", "showTooltips", 12, y)

    y = y - 36
    MakeLabel(page, "Marks On The Bar", "GameFontNormal", 16, y)
    y = y - 26
    MakeCheck(page, "NPC and target marks (star)", "enableTargetMarks", 12, y)
    y = y - 28
    MakeCheck(page, "World markers (flag)", "enableWorldMarks", 12, y)

    y = y - 36
    MakeLabel(page, "Countdown", "GameFontNormal", 16, y)
    y = y - 26
    MakeCheck(page, "5 second countdown", "showPull5", 12, y)
    y = y - 28
    MakeCheck(page, "10 second countdown", "showPull10", 12, y)
    y = y - 28
    MakeCheck(page, "20 second countdown", "showPull20", 12, y)

    y = y - 36
    MakeLabel(page, "Group Checks", "GameFontNormal", 16, y)
    y = y - 26
    MakeCheck(page, "Ready check", "showReady", 12, y)
    y = y - 28
    MakeCheck(page, "Role check", "showRole", 12, y)

    y = y - 36
    MakeLabel(page, "Mark Wheel", "GameFontNormal", 16, y)
    y = y - 26
    MakeCheck(page, "Double-click a unit for the mark wheel", "flywheelUnits", 12, y)
    y = y - 28
    MakeCheck(page, "Double-click the ground for the world-marker wheel", "flywheelWorld", 12, y)
    y = y - 30
    MakeLabel(
        page,
        "Works on mobs, players, nameplates, and unit frames. Double-click is outside combat. In combat, use Key Bindings for the mark wheels.",
        "GameFontHighlightSmall",
        16,
        y,
        true
    )

    y = y - 56
    MakeLabel(page, "Expand Direction", "GameFontNormal", 16, y)
    y = y - 24
    local growthBtn = CreateFrame("Button", "XiusMarksBarOpt_Growth", page, "UIPanelButtonTemplate")
    growthBtn:SetSize(220, 24)
    growthBtn:SetPoint("TOPLEFT", 16, y)
    optionWidgets.growthDirection = growthBtn
    local function GrowthLabel()
        local mode = XMB.db and XMB.db.growthDirection or "AUTO"
        return GROWTH_LABELS[mode] or GROWTH_LABELS.AUTO
    end
    growthBtn:SetText(GrowthLabel())
    growthBtn:SetScript("OnClick", function()
        if syncingOptions or not XMB.db then
            return
        end
        local current = XMB.db.growthDirection or "AUTO"
        local nextMode = "AUTO"
        for i = 1, #GROWTH_ORDER do
            if GROWTH_ORDER[i] == current then
                nextMode = GROWTH_ORDER[(i % #GROWTH_ORDER) + 1]
                break
            end
        end
        SetDBValue("growthDirection", nextMode)
        growthBtn:SetText(GrowthLabel())
    end)
    y = y - 28
    MakeLabel(
        page,
        "Click to cycle. Auto grows toward the middle of the screen.",
        "GameFontHighlightSmall",
        16,
        y,
        true
    )

    y = y - 34
    MakeLabel(page, "Bar Scale", "GameFontNormal", 16, y)
    y = y - 22
    local scaleSlider = CreateFrame("Slider", "XiusMarksBarOpt_Scale", page)
    scaleSlider:SetOrientation("HORIZONTAL")
    scaleSlider:SetSize(200, 16)
    scaleSlider:SetPoint("TOPLEFT", 16, y)
    scaleSlider:EnableMouse(true)
    scaleSlider:SetMinMaxValues(60, 160)
    scaleSlider:SetValueStep(5)
    if scaleSlider.SetObeyStepOnDrag then
        scaleSlider:SetObeyStepOnDrag(true)
    end
    local scaleBg = scaleSlider:CreateTexture(nil, "BACKGROUND")
    scaleBg:SetColorTexture(0.15, 0.12, 0.08, 0.95)
    scaleBg:SetPoint("TOPLEFT", 0, -4)
    scaleBg:SetPoint("BOTTOMRIGHT", 0, 4)
    scaleSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local scaleThumb = scaleSlider:GetThumbTexture()
    if scaleThumb then
        scaleThumb:SetSize(24, 24)
    end
    local scaleValueText = scaleSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleValueText:SetPoint("LEFT", scaleSlider, "RIGHT", 10, 0)
    scaleSlider.valueText = scaleValueText
    optionWidgets.scale = scaleSlider

    local initPct = math.floor(((XMB.db and XMB.db.scale) or 1) * 100 + 0.5)
    scaleSlider:SetValue(initPct)
    SafeText(scaleValueText, initPct .. "%", 12)
    PaintText(scaleValueText, 1, 0.97, 0.90)

    scaleSlider:SetScript("OnValueChanged", function(self, value)
        local pct = math.floor((value or 100) / 5 + 0.5) * 5
        if pct < 60 then
            pct = 60
        elseif pct > 160 then
            pct = 160
        end
        if self.valueText then
            SafeText(self.valueText, pct .. "%", 12)
            PaintText(self.valueText, 1, 0.97, 0.90)
        end
        if syncingOptions or not XMB.db then
            return
        end
        local nextScale = pct / 100
        if math.abs((XMB.db.scale or 1) - nextScale) > 0.001 then
            SetDBValue("scale", nextScale)
        end
    end)

    y = y - 34
    MakeLabel(page, "Keybindings — Target Marks", "GameFontNormal", 16, y)
    y = y - 20
    MakeLabel(
        page,
        "Left-click a box and press any key or mouse button to bind. Right-click (or press Backspace/Delete) to clear. All defaults start blank and sync with Options > Keybindings > AddOns.",
        "GameFontHighlightSmall",
        16,
        y,
        true
    )
    y = y - 42

    local capture = CreateFrame("Button", "XiusMarksBarKeyCapture", panel)
    capture:SetFrameStrata("FULLSCREEN_DIALOG")
    capture:SetFrameLevel(200)
    capture:SetAllPoints(UIParent)
    capture:EnableKeyboard(true)
    capture:EnableMouse(true)
    capture:EnableMouseWheel(true)
    capture:RegisterForClicks("AnyUp", "AnyDown")
    capture:Hide()
    capture:SetScript("OnKeyDown", function(_, key)
        if key == "LSHIFT" or key == "RSHIFT" or key == "SHIFT"
            or key == "LCTRL" or key == "RCTRL" or key == "CTRL"
            or key == "LALT" or key == "RALT" or key == "ALT"
            or key == "LMETA" or key == "RMETA" or key == "META"
            or key == "UNKNOWN" then
            return
        end
        if key == "ESCAPE" then
            StopBindingCapture()
            return
        end
        if key == "BACKSPACE" or key == "DELETE" then
            if activeBindButton then
                ClearCommandBinding(activeBindButton.command)
            end
            StopBindingCapture()
            return
        end
        local btn = activeBindButton
        if btn then
            AssignCommandBinding(btn.command, btn.bindLabel, BuildModifiedKey(key))
        end
        StopBindingCapture()
    end)
    capture:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            StopBindingCapture()
            return
        end
        if mouseButton == "RightButton" then
            if activeBindButton then
                ClearCommandBinding(activeBindButton.command)
            end
            StopBindingCapture()
            return
        end
        local mouseMap = {
            MiddleButton = "BUTTON3",
            Button4 = "BUTTON4",
            Button5 = "BUTTON5",
        }
        local token = mouseMap[mouseButton]
            or (type(mouseButton) == "string" and mouseButton:match("^Button%d+$") and mouseButton:upper())
        if token and activeBindButton then
            AssignCommandBinding(activeBindButton.command, activeBindButton.bindLabel, BuildModifiedKey(token))
        end
        StopBindingCapture()
    end)
    capture:SetScript("OnMouseWheel", function(_, delta)
        local wheelKey = (delta and delta > 0) and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"
        if activeBindButton then
            AssignCommandBinding(activeBindButton.command, activeBindButton.bindLabel, BuildModifiedKey(wheelKey))
        end
        StopBindingCapture()
    end)
    keyCaptureFrame = capture

    local function AddKeybindGrid(items, startY)
        local rowY = startY
        for i = 1, #items do
            local item = items[i]
            local col = (i - 1) % 2
            local colX = col == 0 and 16 or 246

            local icon = page:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("TOPLEFT", page, "TOPLEFT", colX, rowY - 3)
            icon:SetTexture(item.icon)
            if item.texCoord then
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            if item.isWorld then
                local flare = page:CreateTexture(nil, "OVERLAY")
                flare:SetTexture("Interface\\RaidFrame\\Raid-WorldPing")
                flare:SetSize(8, 8)
                flare:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
            end

            local lbl = MakeLabel(page, item.label, "GameFontHighlightSmall", colX + 22, rowY - 5, false)
            lbl:SetWidth(90)
            if lbl.SetWordWrap then
                lbl:SetWordWrap(false)
            end

            local btn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
            btn:SetSize(102, 22)
            btn:SetPoint("TOPLEFT", page, "TOPLEFT", colX + 114, rowY)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn.command = item.command
            btn.bindLabel = item.fullLabel or item.label
            btn:SetScript("OnClick", function(self, button)
                if button == "RightButton" then
                    StopBindingCapture()
                    ClearCommandBinding(self.command)
                    SyncOptionsPanel()
                    return
                end
                StartBindingCapture(self)
            end)
            keybindWidgets[#keybindWidgets + 1] = btn

            if col == 1 or i == #items then
                rowY = rowY - 26
            end
        end
        return rowY
    end

    local targetBindItems = {}
    for i = 8, 1, -1 do
        targetBindItems[#targetBindItems + 1] = {
            label = XMB.MARK_NAMES[i],
            fullLabel = "Mark Target: " .. XMB.MARK_NAMES[i],
            icon = XMB.MARK_TEXTURES[i],
            command = "CLICK XiusMB_Key_TM" .. i .. ":LeftButton",
        }
    end
    targetBindItems[#targetBindItems + 1] = {
        label = "Clear Target",
        fullLabel = "Clear Target Mark",
        icon = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
        command = "CLICK XiusMB_Key_TClear:LeftButton",
    }
    y = AddKeybindGrid(targetBindItems, y)

    y = y - 12
    MakeLabel(page, "Keybindings — Mark Wheels & World Markers", "GameFontNormal", 16, y)
    y = y - 24

    local worldBindItems = {
        {
            label = "Target Wheel",
            fullLabel = "Open target mark wheel",
            icon = XMB.MARK_TEXTURES[1],
            command = "CLICK XiusMB_FlywheelToggle:LeftButton",
        },
        {
            label = "World Wheel",
            fullLabel = "Open world marker wheel",
            icon = "Interface\\Icons\\INV_BannerPVP_02",
            texCoord = true,
            command = "CLICK XiusMB_FlywheelWorldToggle:LeftButton",
        },
    }
    for i = 1, 8 do
        worldBindItems[#worldBindItems + 1] = {
            label = XMB.WORLD_NAMES[i],
            fullLabel = "World Marker: " .. XMB.WORLD_NAMES[i],
            icon = XMB.MARK_TEXTURES[XMB.WORLD_ICON[i]],
            isWorld = true,
            command = "CLICK XiusMB_Key_WM" .. i .. ":LeftButton",
        }
    end
    worldBindItems[#worldBindItems + 1] = {
        label = "Clear World",
        fullLabel = "Clear World Markers",
        icon = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
        command = "CLICK XiusMB_Key_WClear:LeftButton",
    }
    y = AddKeybindGrid(worldBindItems, y)

    y = y - 12
    local resetPos = CreateFrame("Button", "XiusMarksBarOpt_ResetPos", page, "UIPanelButtonTemplate")
    resetPos:SetSize(140, 24)
    resetPos:SetPoint("TOPLEFT", 16, y)
    resetPos:SetText("Reset Position")
    resetPos:SetScript("OnClick", function()
        if XMB.ResetPosition then
            XMB:ResetPosition()
        end
    end)

    local collapse = CreateFrame("Button", "XiusMarksBarOpt_Collapse", page, "UIPanelButtonTemplate")
    collapse:SetSize(140, 24)
    collapse:SetPoint("LEFT", resetPos, "RIGHT", 8, 0)
    collapse:SetText("Collapse Marks")
    collapse:SetScript("OnClick", function()
        if XMB.SetRows then
            XMB:SetRows(false, false)
        end
    end)

    local clearBinds = CreateFrame("Button", "XiusMarksBarOpt_ClearBinds", page, "UIPanelButtonTemplate")
    clearBinds:SetSize(148, 24)
    clearBinds:SetPoint("LEFT", collapse, "RIGHT", 8, 0)
    clearBinds:SetText("Clear All Keybinds")
    clearBinds:SetScript("OnClick", function()
        ClearAllAddonBindings()
    end)

    page:SetHeight((-y) + 72)

    local function OnDefault()
        XMB:ResetToDefaults()
    end

    panel.refresh = SyncSoon
    panel.OnRefresh = SyncSoon
    panel.okay = SyncSoon
    panel.OnCommit = SyncSoon
    panel.cancel = SyncSoon
    panel.default = OnDefault
    panel.OnDefault = OnDefault
    pcall(panel.RegisterEvent, panel, "UPDATE_BINDINGS")
    pcall(panel.RegisterEvent, panel, "PLAYER_REGEN_DISABLED")
    panel:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            StopBindingCapture()
        elseif event == "UPDATE_BINDINGS" and panel:IsShown() then
            SyncOptionsPanel()
        end
    end)
    panel:SetScript("OnShow", function()
        BindToWindow()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, BindToWindow)
        end
        SyncSoon()
    end)
    panel:SetScript("OnHide", function()
        StopBindingCapture()
    end)
    panel:SetScript("OnSizeChanged", function()
        FitScroll()
        UpdateBar()
    end)
    SyncSoon()

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local registered, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name)
        if registered and category then
            optionsCategory = category
            pcall(Settings.RegisterAddOnCategory, category)
        end
    end
    if not optionsCategory and InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        optionsCategory = panel
    end
    optionsPanel = panel
end

function XMB:OpenOptions()
    if InCombatLockdown() then
        self:Print("Leave combat to open options.")
        return
    end
    self:CreateOptions()
    SyncOptionsPanel()
    if Settings and Settings.OpenToCategory and optionsCategory then
        local id = optionsCategory
        if optionsCategory.GetID then
            local ok, catID = pcall(optionsCategory.GetID, optionsCategory)
            if ok and catID then
                id = catID
            end
        end
        pcall(Settings.OpenToCategory, id)
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if not InCombatLockdown() then
                    pcall(Settings.OpenToCategory, id)
                end
            end)
        end
        SyncSoon()
        return
    end
    if InterfaceOptionsFrame_OpenToCategory and optionsPanel then
        pcall(InterfaceOptionsFrame_OpenToCategory, optionsPanel)
        pcall(InterfaceOptionsFrame_OpenToCategory, optionsPanel)
        return
    end
    self:Print("The options page could not be opened.")
end

function XMB:HandleSlash(msg)
    if not self.db then
        self:InitDB()
    end
    local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = string.lower(cmd or "")
    if cmd == "" or cmd == "config" or cmd == "options" then
        self:OpenOptions()
    elseif cmd == "reset" then
        if self.ResetPosition then
            self:ResetPosition()
        end
    elseif cmd == "lock" or cmd == "unlock" then
        SetDBValue("isLocked", cmd == "lock")
        SyncOptionsPanel()
        self:Print(cmd == "lock" and "Bar locked." or "Bar unlocked.")
    elseif cmd == "collapse" or cmd == "hide" then
        if self.SetRows then
            self:SetRows(false, false)
        end
    elseif cmd == "scale" then
        local val = tonumber(arg)
        if val and val > 5 then
            val = val / 100
        end
        if not val or not IsFiniteNumber(val) or val < 0.6 or val > 1.6 then
            self:Print("Usage: /xmb scale 60-160 (or 0.6-1.6)")
            return
        end
        SetDBValue("scale", val)
        SyncOptionsPanel()
        self:Print(string.format("Scale set to %d%%.", math.floor(val * 100 + 0.5)))
    elseif cmd == "help" then
        self:Print("Commands: /xmb, /xmb reset, /xmb lock, /xmb unlock, /xmb scale 60-160, /xmb collapse")
    else
        self:OpenOptions()
    end
end

SLASH_XIUSMARKSBAR1 = "/xmb"
SlashCmdList.XIUSMARKSBAR = function(msg)
    XMB:HandleSlash(msg)
end
