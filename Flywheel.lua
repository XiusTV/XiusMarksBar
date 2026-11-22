--[[
    Xius Marks Bar - Flywheel.lua
    Double-click a unit for a radial target-mark wheel.
    Double-click the ground for a radial world-marker wheel.
    Key bindings open the same wheels during combat.
    TargetFrame uses global mouse monitoring only — never HookScript on TargetFrame
    (HookScript taints the Forever/Retail UnitPopup right-click menu).
]]

local addonName, ns = ...
local ADDON, XMB = addonName, ns

if XMB.disabled then
    return
end

local type = type
local pcall = pcall
local pairs = pairs
local tostring = tostring
local setmetatable = setmetatable
local rad = math.rad
local cos = math.cos
local sin = math.sin
local max = math.max
local min = math.min
local match = string.match
local CreateFrame = CreateFrame
local UIParent = UIParent
local GetTime = GetTime
local GetCursorPosition = GetCursorPosition
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local SetPortraitTexture = SetPortraitTexture
local IsShiftKeyDown = IsShiftKeyDown
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsMouselooking = IsMouselooking
local SpellIsTargeting = SpellIsTargeting
local IsMouseButtonDown = IsMouseButtonDown

local WHEEL = 168
local HALF = WHEEL / 2
local RADIUS = 58
local DOUBLE_WINDOW = 0.32
local TARGET_DOUBLE_WINDOW = 0.35
local SAME_CLICK = 0.08
local MOVE_LIMIT = 56
local SPOKE_SIZE = 36
local SPOKE_HOVER = 44

local IsSecret = XMB.IsSecret
local IsFiniteNumber = XMB.IsFiniteNumber
local MARK_TEXTURES = XMB.MARK_TEXTURES
local MARK_NAMES = XMB.MARK_NAMES
local WORLD_ICON = XMB.WORLD_ICON
local WORLD_NAMES = XMB.WORLD_NAMES

local NAMEPLATE_TOKENS = {}
for n = 1, 40 do
    NAMEPLATE_TOKENS[n] = "nameplate" .. n
end

local STATIC_UNIT_FRAMES = {
    "PlayerFrame",
    "TargetFrame",
    "FocusFrame",
    "PetFrame",
    "TargetFrameToT",
    "FocusFrameToT",
    "PartyMemberFrame1",
    "PartyMemberFrame2",
    "PartyMemberFrame3",
    "PartyMemberFrame4",
    "Boss1TargetFrame",
    "Boss2TargetFrame",
    "Boss3TargetFrame",
    "Boss4TargetFrame",
    "Boss5TargetFrame",
}

local watcher = CreateFrame("Frame")

local function CombatLocked()
    return XMB:CombatLocked()
end

local function Clock()
    if type(GetTime) ~= "function" then
        return 0
    end
    local ok, value = pcall(GetTime)
    if ok and IsFiniteNumber(value) then
        return value
    end
    return 0
end

-- Weak tables avoid writing custom fields onto Blizzard unit frames or nameplates (prevents taint).
local hookedFrames = setmetatable({}, { __mode = "k" })
local plateUnits = setmetatable({}, { __mode = "k" })
local pendingHooks = setmetatable({}, { __mode = "k" })
-- TargetFrame double-click is detected globally — never HookScript TargetFrame (taints UnitPopup).
local targetFrameClickAt = 0
local targetFramePulseAt = 0
local targetFrameOpenAt = 0
local targetFrameLeftWasDown = false
local targetFrameMonitor = CreateFrame("Frame")
local targetFrameUsesGlobalMouse = false

local UNIT_TOGGLE_SNIPPET = [[
if self:GetAttribute("enabled") == 0 then
  return
end
local wheel = self:GetFrameRef("wheel")
local block = self:GetFrameRef("block")
local units = self:GetFrameRef("units")
local worlds = self:GetFrameRef("worlds")
if not wheel or not units or not worlds then
  return
end
if wheel:IsShown() and wheel:GetAttribute("mode") == "unit" then
  wheel:Hide()
  if block then
    block:Hide()
  end
  return
end
if not UnitExists("target") then
  return
end
wheel:SetAttribute("mode", "unit")
worlds:Hide()
units:Show()
for i = 0, 8 do
  local unitBtn = self:GetFrameRef("u" .. i)
  local worldBtn = self:GetFrameRef("w" .. i)
  if unitBtn then
    unitBtn:SetAttribute("unit", "target")
    unitBtn:SetAttribute("unit1", "target")
    unitBtn:SetAttribute("*unit1", "target")
    unitBtn:Show()
  end
  if worldBtn then
    worldBtn:Hide()
  end
end
wheel:ClearAllPoints()
wheel:SetPoint("CENTER", "$cursor", "BOTTOMLEFT", 0, 0)
if block then
  block:Show()
end
wheel:Show()
]]

local WORLD_TOGGLE_SNIPPET = [[
if self:GetAttribute("enabled") == 0 then
  return
end
local wheel = self:GetFrameRef("wheel")
local block = self:GetFrameRef("block")
local units = self:GetFrameRef("units")
local worlds = self:GetFrameRef("worlds")
if not wheel or not units or not worlds then
  return
end
if wheel:IsShown() and wheel:GetAttribute("mode") == "world" then
  wheel:Hide()
  if block then
    block:Hide()
  end
  return
end
wheel:SetAttribute("mode", "world")
units:Hide()
worlds:Show()
for i = 0, 8 do
  local unitBtn = self:GetFrameRef("u" .. i)
  local worldBtn = self:GetFrameRef("w" .. i)
  if unitBtn then
    unitBtn:Hide()
  end
  if worldBtn then
    worldBtn:Show()
  end
end
wheel:ClearAllPoints()
wheel:SetPoint("CENTER", "$cursor", "BOTTOMLEFT", 0, 0)
if block then
  block:Show()
end
wheel:Show()
]]

local COMBAT_SNIPPET = [[
if newstate == "combat" then
  self:Hide()
  local block = self:GetFrameRef("block")
  if block then
    block:Hide()
  end
end
]]

local lastClick = {
    time = 0,
    kind = nil,
    guid = nil,
    unit = nil,
    x = 0,
    y = 0,
}
local pendingClick = {
    kind = nil,
    unit = nil,
    time = 0,
    x = 0,
    y = 0,
}
local hasPendingClick = false
local singleFocus = {}

local function CursorRaw()
    if type(GetCursorPosition) ~= "function" then
        return 0, 0
    end
    local ok, x, y = pcall(GetCursorPosition)
    if not ok or not IsFiniteNumber(x) or not IsFiniteNumber(y) then
        return 0, 0
    end
    return x, y
end

local function CursorPoint()
    local x, y = CursorRaw()
    local scale = 1
    if UIParent and UIParent.GetEffectiveScale then
        local rawScale = UIParent:GetEffectiveScale()
        if IsFiniteNumber(rawScale) and rawScale > 0 then
            scale = rawScale
        end
    end
    x, y = x / scale, y / scale
    local sw, sh = 1024, 768
    if UIParent then
        local rawW = UIParent:GetWidth()
        local rawH = UIParent:GetHeight()
        if IsFiniteNumber(rawW) and rawW > 0 then
            sw = rawW
        end
        if IsFiniteNumber(rawH) and rawH > 0 then
            sh = rawH
        end
    end
    if not IsFiniteNumber(sw) or sw <= 0 then
        sw = 1024
    end
    if not IsFiniteNumber(sh) or sh <= 0 then
        sh = 768
    end
    x = max(HALF, min(sw - HALF, x))
    y = max(HALF, min(sh - HALF, y))
    return x, y
end

local function ShowTip(owner, title, line)
    if not XMB.db or not XMB.db.showTooltips or not GameTooltip or not title then
        return
    end
    local ok = pcall(GameTooltip.SetOwner, GameTooltip, owner, "ANCHOR_RIGHT")
    if not ok then
        return
    end
    GameTooltip:SetText(title, 0.95, 0.78, 0.28)
    if line then
        GameTooltip:AddLine(line, 0.9, 0.9, 0.9, true)
    end
    GameTooltip:Show()
end

local function HideTip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function PlaceSpoke(parent, btn, index)
    local angle = rad(90 - (index - 1) * 45)
    btn:SetPoint("CENTER", parent, "CENTER", cos(angle) * RADIUS, sin(angle) * RADIUS)
end

local function ArmMark(btn, kind, marker)
    -- Identical secure click to the marks bar. Nothing wraps this OnClick.
    -- A wrapped click runs tainted on this client, and SetRaidTarget then does nothing.
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("useOnKeyDown", false)
    btn:SetAttribute("checkselfcast", false)
    btn:SetAttribute("checkfocuscast", false)
    if btn.SetMouseClickEnabled then
        btn:SetMouseClickEnabled(true)
    end
    btn:EnableMouse(true)
    local actionType = kind == "world" and "worldmarker" or "raidtarget"
    btn:SetAttribute("type", actionType)
    btn:SetAttribute("type1", actionType)
    btn:SetAttribute("*type1", actionType)
    -- Right click has no mark. It only closes the wheel.
    btn:SetAttribute("type2", "macro")
    btn:SetAttribute("*type2", "macro")
    btn:SetAttribute("macrotext2", "")
    btn:SetAttribute("*macrotext2", "")
    if kind == "unit" then
        btn:SetAttribute("unit", "target")
        btn:SetAttribute("unit1", "target")
        btn:SetAttribute("*unit1", "target")
    end
    local action
    if kind == "world" then
        action = (marker and marker ~= 0) and "toggle" or "clear"
        if marker and marker > 0 then
            btn.xmbWorldMarker = marker
        end
    elseif marker and marker ~= 0 then
        action = "toggle"
    else
        action = "clear"
    end
    if marker and marker ~= 0 then
        btn:SetAttribute("marker", marker)
        btn:SetAttribute("marker1", marker)
        btn:SetAttribute("*marker1", marker)
    elseif kind == "unit" then
        btn:SetAttribute("marker", 0)
        btn:SetAttribute("marker1", 0)
        btn:SetAttribute("*marker1", 0)
    end
    btn:SetAttribute("action", action)
    btn:SetAttribute("action1", action)
    btn:SetAttribute("*action1", action)
    btn.xmbWheelMark = true
    if XMB.BindSpokePostClick then
        XMB.BindSpokePostClick(btn)
    end
end

local function MakeActionButton(parent, name)
    return CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
end

local function ResetWheelIcons()
    local uList = XMB.flywheelUnitButtons
    if uList then
        for i = 1, #uList do
            local icon = uList[i].icon
            if icon then
                icon:SetSize(SPOKE_SIZE, SPOKE_SIZE)
            end
        end
    end
    local wList = XMB.flywheelWorldButtons
    if wList then
        for i = 1, #wList do
            local icon = wList[i].icon
            if icon then
                icon:SetSize(SPOKE_SIZE, SPOKE_SIZE)
            end
        end
    end
end

function XMB:ApplyFlywheelSettings()
    local db = self.db
    local wheel = self.flywheel
    if CombatLocked() then
        self.pendingFlywheelSettings = true
        return
    end
    self.pendingFlywheelSettings = nil
    if self.UpdateTargetFrameMonitor then
        self:UpdateTargetFrameMonitor()
    end
    if self.flywheelToggle then
        self.flywheelToggle:SetAttribute("enabled", (db and db.flywheelUnits) and 1 or 0)
    end
    if self.flywheelWorldToggle then
        self.flywheelWorldToggle:SetAttribute("enabled", (db and db.flywheelWorld) and 1 or 0)
    end
    if not wheel or not wheel:IsShown() then
        return
    end
    local mode = wheel:GetAttribute("mode")
    local allowed = true
    if mode == "world" then
        allowed = db and db.flywheelWorld
    else
        allowed = db and db.flywheelUnits
    end
    if not allowed then
        wheel:Hide()
        if self.flywheelBlocker then
            self.flywheelBlocker:Hide()
        end
    end
end

function XMB:FlywheelCombatNotice()
    if self.flywheelCombatTold then
        return
    end
    self.flywheelCombatTold = true
    self:Print("The mark wheel can't open from a click during combat. Use the bar, or bind the wheels under Key Bindings.")
end

local function CallTruthy(func, ...)
    if type(func) ~= "function" then
        return false
    end
    local ok, value = pcall(func, ...)
    if not ok or IsSecret(value) then
        return false
    end
    return not not value
end

-- Unit tokens and UnitExists can be secret inside an instance. A secret token
-- still names a unit, so the wheel can open. Comparisons happen only on readable values.
local function UnitIsReal(unit)
    if not UnitExists then
        return false
    end
    if IsSecret(unit) then
        return true
    end
    if type(unit) ~= "string" or unit == "" then
        return false
    end
    local ok, value = pcall(UnitExists, unit)
    if not ok then
        return false
    end
    if IsSecret(value) then
        return true
    end
    return not not value
end

local function ReadableGUID(unit)
    if not UnitGUID or IsSecret(unit) or type(unit) ~= "string" then
        return nil
    end
    local ok, value = pcall(UnitGUID, unit)
    if not ok or IsSecret(value) or type(value) ~= "string" then
        return nil
    end
    return value
end

local function IsStableUnitToken(unit)
    if IsSecret(unit) or type(unit) ~= "string" or unit == "" then
        return false
    end
    if unit == "target" or unit == "focus" or unit == "player" or unit == "pet" then
        return true
    end
    if match(unit, "^party%d+$") or match(unit, "^raid%d+$") or match(unit, "^boss%d+$") or match(unit, "^arena%d+$") then
        return true
    end
    return false
end

function XMB:RefreshFlywheelPortrait(unit)
    local portrait = self.flywheelPortrait
    if not portrait then
        return
    end
    unit = unit or self.markUnit or "target"
    if IsSecret(unit) or type(unit) ~= "string" then
        unit = "target"
    end
    if UnitIsReal(unit) and SetPortraitTexture then
        local ok, shown = pcall(SetPortraitTexture, portrait, unit)
        if IsSecret(shown) then
            shown = true
        end
        if ok and shown ~= false then
            portrait:Show()
            return
        end
    end
    portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    portrait:Show()
end

function XMB:UseMarkUnit(unit)
    -- mouseover and nameplate tokens disappear once the cursor moves onto an icon.
    -- Stable unit tokens (focus, party1, raid1, etc.) can be marked directly outside combat.
    local resolved = "target"
    if not CombatLocked() and IsStableUnitToken(unit) and UnitIsReal(unit) then
        resolved = unit
    end
    self.markUnit = resolved
    local buttons = self.flywheelUnitButtons
    if not buttons or CombatLocked() then
        return resolved
    end
    for i = 1, #buttons do
        buttons[i]:SetAttribute("unit", resolved)
        buttons[i]:SetAttribute("unit1", resolved)
        buttons[i]:SetAttribute("*unit1", resolved)
    end
    return resolved
end

local function ReadableFrame(frame)
    if not frame or IsSecret(frame) then
        return false
    end
    if frame.IsForbidden then
        local ok, forbidden = pcall(frame.IsForbidden, frame)
        if not ok or IsSecret(forbidden) or forbidden then
            return false
        end
    end
    return true
end

local function GetMouseFocusFrames()
    if type(GetMouseFoci) == "function" then
        local ok, foci = pcall(GetMouseFoci)
        if ok and not IsSecret(foci) and type(foci) == "table" then
            return foci
        end
    elseif type(GetMouseFocus) == "function" then
        local ok, focus = pcall(GetMouseFocus)
        if ok and ReadableFrame(focus) then
            singleFocus[1] = focus
            return singleFocus
        end
    end
    return nil
end

local function IsOverWheel()
    local wheel = XMB.flywheel
    if not wheel or not wheel:IsShown() then
        return false
    end
    local foci = GetMouseFocusFrames()
    if foci then
        for i = 1, #foci do
            local frame = foci[i]
            local depth = 0
            while ReadableFrame(frame) and depth < 12 do
                depth = depth + 1
                if frame == wheel then
                    return true
                end
                if not frame.GetParent then
                    break
                end
                local ok, parent = pcall(frame.GetParent, frame)
                if not ok then
                    break
                end
                frame = parent
            end
        end
    end
    return false
end

function XMB:CloseFlywheel()
    if CombatLocked() then
        return
    end
    if self.flywheel and self.flywheel:IsShown() then
        self.flywheel:Hide()
    end
    if self.flywheelBlocker and self.flywheelBlocker:IsShown() then
        self.flywheelBlocker:Hide()
    end
    if self.flywheelEsc and self.flywheelEsc:IsShown() then
        self.flywheelEsc:Hide()
    end
end

-- Hide the wheel when combat starts. Secure state driver also hides it; this clears
-- overlays immediately. Never touches TargetFrame attributes or anchors.
function XMB:ForceCloseFlywheel()
    hasPendingClick = false
    lastClick.kind = nil
    targetFrameClickAt = 0
    targetFramePulseAt = 0
    local wheel = self.flywheel
    if wheel then
        pcall(wheel.Hide, wheel)
    end
    local block = self.flywheelBlocker
    if block then
        pcall(block.Hide, block)
    end
    if self.flywheelEsc and self.flywheelEsc.IsShown and self.flywheelEsc:IsShown() then
        self.flywheelEsc:Hide()
    end
end

-- Never call EnableMouse(false) on hidden buttons so the secure combat toggle can show them.
local function ShowWheelList(list, shown)
    if not list then
        return
    end
    for i = 1, #list do
        local btn = list[i]
        if shown then
            btn:Show()
        else
            btn:Hide()
        end
    end
end

function XMB:OpenFlywheel(kind, unit)
    local db = self.db
    local wheel = self.flywheel
    if not db or not wheel then
        return
    end
    if kind == "world" then
        if not db.flywheelWorld then
            return
        end
    else
        kind = "unit"
        if not db.flywheelUnits then
            return
        end
    end
    if CombatLocked() then
        self:FlywheelCombatNotice()
        return
    end
    if kind == "unit" then
        local resolved = self:UseMarkUnit(unit)
        if not UnitIsReal(resolved) then
            self:Print("Select a unit, then open the mark wheel.")
            return
        end
        self:RefreshFlywheelPortrait(resolved)
    elseif self.flywheelPortrait then
        self.flywheelPortrait:Hide()
    end

    local block = self.flywheelBlocker
    if wheel:IsShown() and wheel:GetAttribute("mode") == kind then
        wheel:Hide()
        if block then
            block:Hide()
        end
        return
    end

    local pointOk, x, y = pcall(CursorPoint)
    if not pointOk or not IsFiniteNumber(x) or not IsFiniteNumber(y) then
        x = (UIParent:GetWidth() or 1024) * 0.5
        y = (UIParent:GetHeight() or 768) * 0.5
    end
    -- Out of combat, show the wheel directly. Key bindings use the secure toggle buttons.
    wheel:SetAttribute("mode", kind)
    wheel:ClearAllPoints()
    wheel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)

    if kind == "world" then
        ShowWheelList(self.flywheelUnitButtons, false)
        if self.flywheelUnits then
            self.flywheelUnits:Hide()
        end
        if self.flywheelWorlds then
            self.flywheelWorlds:Show()
        end
        ShowWheelList(self.flywheelWorldButtons, true)
    else
        ShowWheelList(self.flywheelWorldButtons, false)
        if self.flywheelWorlds then
            self.flywheelWorlds:Hide()
        end
        if self.flywheelUnits then
            self.flywheelUnits:Show()
        end
        ShowWheelList(self.flywheelUnitButtons, true)
    end
    if block then
        block:Show()
    end
    wheel:Show()
    self.flywheelOpenedAt = Clock()
end

local function RawEqual(a, b)
    return a == b
end

local function SafeSame(a, b)
    if IsSecret(a) or IsSecret(b) or a == nil or b == nil then
        return false
    end
    local ok, same = pcall(RawEqual, a, b)
    if not ok or IsSecret(same) then
        return false
    end
    return same
end

local function MovedTooFar(x1, y1, x2, y2, limit)
    if not IsFiniteNumber(x1) or not IsFiniteNumber(y1) or not IsFiniteNumber(x2) or not IsFiniteNumber(y2) then
        return false
    end
    limit = limit or MOVE_LIMIT
    local dx = x1 - x2
    local dy = y1 - y2
    return (dx * dx + dy * dy) > (limit * limit)
end

local function HasUnit(value)
    if IsSecret(value) then
        return true
    end
    return type(value) == "string" and value ~= ""
end

local function ReadFrameUnitFields(frame)
    return frame.unit or frame.namePlateUnitToken or frame.displayedUnit
end

local function ReadUnitFrame(plate)
    return plate.UnitFrame
end

local function UnitFromFrame(frame)
    if not ReadableFrame(frame) then
        return nil
    end
    local mapped = plateUnits[frame]
    if HasUnit(mapped) then
        return mapped
    end
    local okU, unitField = pcall(ReadFrameUnitFields, frame)
    if okU and HasUnit(unitField) then
        return unitField
    end
    if not frame.GetAttribute then
        return nil
    end
    local okA, attr = pcall(frame.GetAttribute, frame, "unit")
    if okA and HasUnit(attr) then
        return attr
    end
    return nil
end

local function CheckCursorOverFrame(frame, cx, cy, padX, padAbove, padBelow)
    if not frame:IsVisible() then
        return false
    end
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    local width, height = frame:GetWidth(), frame:GetHeight()
    local scale = frame:GetEffectiveScale() or 1
    if not IsFiniteNumber(left) or not IsFiniteNumber(bottom)
        or not IsFiniteNumber(width) or not IsFiniteNumber(height)
        or not IsFiniteNumber(scale) or scale <= 0 then
        return false
    end
    local l = (left - padX) * scale
    local r = (left + width + padX) * scale
    local b = (bottom - padBelow) * scale
    local t = (bottom + height + padAbove) * scale
    return cx >= l and cx <= r and cy >= b and cy <= t
end

local function CursorOverFrame(frame, cx, cy, padX, padAbove, padBelow)
    if not ReadableFrame(frame) or not frame.GetLeft or not frame.IsVisible then
        return false
    end
    local ok, inside = pcall(CheckCursorOverFrame, frame, cx, cy, padX, padAbove, padBelow)
    return ok and not IsSecret(inside) and inside or false
end

local function PlateUnit(plate)
    if not ReadableFrame(plate) then
        return nil
    end
    local unit = plateUnits[plate]
    if UnitIsReal(unit) then
        return unit
    end
    local okP, token = pcall(ReadFrameUnitFields, plate)
    if okP and UnitIsReal(token) then
        return token
    end
    local okUF, uf = pcall(ReadUnitFrame, plate)
    if okUF and ReadableFrame(uf) then
        unit = plateUnits[uf]
        if UnitIsReal(unit) then
            return unit
        end
        local okUFT, ufToken = pcall(ReadFrameUnitFields, uf)
        if okUFT and UnitIsReal(ufToken) then
            return ufToken
        end
    end
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then
        return nil
    end
    for n = 1, 40 do
        local candidate = NAMEPLATE_TOKENS[n]
        if UnitIsReal(candidate) then
            local ok, got = pcall(C_NamePlate.GetNamePlateForUnit, candidate)
            if ok and got == plate then
                plateUnits[plate] = candidate
                return candidate
            end
        end
    end
    return nil
end

local function UnitUnderCursor()
    if UnitIsReal("mouseover") then
        return "mouseover"
    end
    local foci = GetMouseFocusFrames()
    if foci then
        for i = 1, #foci do
            local frame = foci[i]
            local guard = 0
            while ReadableFrame(frame) and guard < 12 do
                guard = guard + 1
                local unit = UnitFromFrame(frame)
                if UnitIsReal(unit) then
                    return unit
                end
                if not frame.GetParent then
                    break
                end
                local ok, parent = pcall(frame.GetParent, frame)
                if not ok then
                    break
                end
                frame = parent
            end
        end
    end
    if not C_NamePlate or not C_NamePlate.GetNamePlates then
        return nil
    end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or IsSecret(plates) or type(plates) ~= "table" then
        return nil
    end
    local cx, cy = CursorRaw()
    for i = 1, #plates do
        local plate = plates[i]
        if ReadableFrame(plate) then
            local okUF, visual = pcall(ReadUnitFrame, plate)
            visual = (okUF and ReadableFrame(visual)) and visual or plate
            if CursorOverFrame(visual, cx, cy, 8, 6, 6) or (visual ~= plate and CursorOverFrame(plate, cx, cy, 8, 6, 6)) then
                local unit = PlateUnit(plate)
                if UnitIsReal(unit) then
                    return unit
                end
            end
        end
    end
    return nil
end

local function FlushFlywheelClick()
    if not hasPendingClick then
        return
    end
    hasPendingClick = false
    if not XMB.db or CombatLocked() then
        return
    end
    if IsOverWheel() then
        return
    end
    local db = XMB.db
    local kind, unit = pendingClick.kind, pendingClick.unit
    local clickTime = pendingClick.time
    local clickX, clickY = pendingClick.x, pendingClick.y

    if kind ~= "unit" or not UnitIsReal(unit) then
        local ok, hovered = pcall(UnitUnderCursor)
        if ok and UnitIsReal(hovered) then
            kind = "unit"
            unit = hovered
        end
    end

    if XMB.flywheel and XMB.flywheel:IsShown() then
        if (clickTime - (XMB.flywheelOpenedAt or 0)) > 0.05 then
            XMB:CloseFlywheel()
        end
    end

    if kind == "unit" then
        if not db.flywheelUnits or not UnitIsReal(unit) then
            return
        end
    elseif kind == "world" then
        if not db.flywheelWorld then
            return
        end
    else
        return
    end

    local guid = kind == "unit" and ReadableGUID(unit) or nil
    local previousKind = lastClick.kind
    local previousUnit = lastClick.unit
    local previousGuid = lastClick.guid
    local prevX, prevY = lastClick.x, lastClick.y
    local dt = clickTime - lastClick.time
    local close = previousKind
        and dt <= DOUBLE_WINDOW
        and dt > SAME_CLICK
        and not MovedTooFar(clickX, clickY, prevX, prevY)

    lastClick.time = clickTime
    lastClick.kind = kind
    lastClick.guid = guid
    lastClick.unit = unit
    lastClick.x = clickX
    lastClick.y = clickY

    if not close then
        return
    end
    if kind == "world" and previousKind == "world" then
        lastClick.kind = nil
        XMB:OpenFlywheel("world")
        return
    end
    -- If click 1 was on a 3D unit and click 2 at the same spot (<24px) briefly missed mouseover,
    -- allow opening the unit wheel on the newly selected target.
    if previousKind == "unit" and kind == "world" then
        if db.flywheelUnits and not MovedTooFar(clickX, clickY, prevX, prevY, 24) and UnitIsReal("target") then
            lastClick.kind = nil
            XMB:OpenFlywheel("unit", "target")
        end
        return
    end
    if kind ~= "unit" or previousKind ~= "unit" then
        return
    end
    local markUnit = unit or previousUnit
    if not UnitIsReal(markUnit) then
        return
    end
    if guid and previousGuid and not SafeSame(guid, previousGuid) then
        return
    end
    lastClick.kind = nil
    XMB:OpenFlywheel("unit", markUnit)
end

local function SafeFlushFlywheelClick()
    pcall(FlushFlywheelClick)
end

local function KeyIsDown(fn)
    if type(fn) ~= "function" then
        return false
    end
    local ok, down = pcall(fn)
    if not ok or IsSecret(down) then
        return false
    end
    return down and true or false
end

-- NONE is a plain double-click. SHIFT, ALT, and CTRL require that key alone.
local function FlywheelModifierMatches(db)
    local mode = db and db.flywheelModifier or "NONE"
    local shift = KeyIsDown(IsShiftKeyDown)
    local alt = KeyIsDown(IsAltKeyDown)
    local ctrl = KeyIsDown(IsControlKeyDown)
    if mode == "SHIFT" then
        return shift and not alt and not ctrl
    end
    if mode == "ALT" then
        return alt and not shift and not ctrl
    end
    if mode == "CTRL" then
        return ctrl and not shift and not alt
    end
    return not shift and not alt and not ctrl
end

function XMB:NoteFlywheelClick(kind, unit)
    local db = self.db
    if not db or CombatLocked() then
        return
    end
    if not db.flywheelUnits and not db.flywheelWorld then
        return
    end
    if not FlywheelModifierMatches(db) then
        return
    end
    if CallTruthy(IsMouselooking) or CallTruthy(SpellIsTargeting) then
        return
    end
    if IsOverWheel() then
        return
    end
    if kind == "unit" and not UnitIsReal(unit) then
        kind = "world"
        unit = nil
    end
    local now = Clock()
    local x, y = CursorRaw()
    if hasPendingClick and (now - pendingClick.time) < SAME_CLICK then
        if kind == "unit" and UnitIsReal(unit) then
            pendingClick.kind = "unit"
            pendingClick.unit = unit
        end
        return
    end
    pendingClick.kind = kind
    pendingClick.unit = unit
    pendingClick.time = now
    pendingClick.x = x
    pendingClick.y = y
    hasPendingClick = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0, SafeFlushFlywheelClick)
    else
        SafeFlushFlywheelClick()
    end
end

local function CanOpenTargetFrameWheel()
    if CombatLocked() then
        return false
    end
    local db = XMB.db
    if not db or not db.flywheelUnits then
        return false
    end
    if not FlywheelModifierMatches(db) then
        return false
    end
    if CallTruthy(IsMouselooking) or CallTruthy(SpellIsTargeting) then
        return false
    end
    -- TargetFrame / portrait double-click always marks the current target.
    if not UnitIsReal("target") then
        return false
    end
    return true
end

local function OpenTargetFrameWheel()
    if not CanOpenTargetFrameWheel() then
        return
    end
    local now = Clock()
    if (now - targetFrameOpenAt) < 0.2 then
        return
    end
    targetFrameOpenAt = now
    targetFrameClickAt = 0
    targetFramePulseAt = 0
    -- OpenFlywheel centers on GetCursorPosition() / UIParent scale and clamps to screen.
    XMB:OpenFlywheel("unit", "target")
end

-- True when the cursor is over TargetFrame / its container / portrait region.
-- Never reads or writes TargetFrame scripts — only IsMouseOver / GetMouseFoci.
local function CursorOverTargetFrame()
    local tf = _G.TargetFrame
    if not ReadableFrame(tf) then
        return false
    end
    if tf.IsShown and not tf:IsShown() then
        return false
    end
    if tf.IsMouseOver then
        local ok, over = pcall(tf.IsMouseOver, tf)
        if ok and over == true then
            return true
        end
    end
    local container = tf.TargetFrameContainer
    if ReadableFrame(container) and container.IsMouseOver then
        local ok, over = pcall(container.IsMouseOver, container)
        if ok and over == true then
            return true
        end
    end
    local foci = GetMouseFocusFrames()
    if not foci then
        return false
    end
    for i = 1, #foci do
        local frame = foci[i]
        local depth = 0
        while ReadableFrame(frame) and depth < 16 do
            depth = depth + 1
            if frame == tf or frame == container or frame == _G.TargetFramePortrait then
                return true
            end
            if not frame.GetParent then
                break
            end
            local ok, parent = pcall(frame.GetParent, frame)
            if not ok then
                break
            end
            frame = parent
        end
    end
    return false
end

local function IsUnderTargetFrame(frame)
    local tf = _G.TargetFrame
    if not ReadableFrame(tf) or not ReadableFrame(frame) then
        return false
    end
    local depth = 0
    while ReadableFrame(frame) and depth < 16 do
        depth = depth + 1
        if frame == tf then
            return true
        end
        if not frame.GetParent then
            break
        end
        local ok, parent = pcall(frame.GetParent, frame)
        if not ok then
            break
        end
        frame = parent
    end
    return false
end

-- Rising-edge LeftButton press over TargetFrame within 0.35s opens the wheel.
-- RightButton is never observed here, so UnitPopup stays untainted.
local function NoteTargetFrameLeftClick()
    if CombatLocked() then
        targetFrameClickAt = 0
        targetFramePulseAt = 0
        return
    end
    if not CanOpenTargetFrameWheel() then
        targetFrameClickAt = 0
        return
    end
    if not CursorOverTargetFrame() then
        targetFrameClickAt = 0
        return
    end
    local now = Clock()
    if (now - targetFramePulseAt) < SAME_CLICK then
        return
    end
    targetFramePulseAt = now
    local dt = now - targetFrameClickAt
    if targetFrameClickAt > 0 and dt <= TARGET_DOUBLE_WINDOW and dt > SAME_CLICK then
        OpenTargetFrameWheel()
        return
    end
    targetFrameClickAt = now
end

local function OnTargetFrameLeftEdge()
    if CombatLocked() then
        targetFrameClickAt = 0
        targetFramePulseAt = 0
        return
    end
    if CursorOverTargetFrame() then
        NoteTargetFrameLeftClick()
    else
        targetFrameClickAt = 0
    end
end

local function OnTargetFrameMonitorUpdate()
    if CombatLocked() then
        targetFrameLeftWasDown = false
        return
    end
    local db = XMB.db
    if not db or not db.flywheelUnits then
        targetFrameLeftWasDown = false
        return
    end
    local down = false
    if type(IsMouseButtonDown) == "function" then
        local ok, value = pcall(IsMouseButtonDown, "LeftButton")
        down = ok and value and true or false
    end
    if down and not targetFrameLeftWasDown then
        OnTargetFrameLeftEdge()
    end
    targetFrameLeftWasDown = down
end

local function StopTargetFrameMonitor()
    targetFrameMonitor:SetScript("OnUpdate", nil)
    targetFrameLeftWasDown = false
end

local function StartTargetFrameMonitor()
    -- OnUpdate IsMouseButtonDown edge detection. GLOBAL_MOUSE_DOWN also feeds the
    -- same NoteTargetFrameLeftClick path; SAME_CLICK coalesces duplicate edges.
    if targetFrameMonitor:GetScript("OnUpdate") then
        return
    end
    targetFrameMonitor:SetScript("OnUpdate", OnTargetFrameMonitorUpdate)
end

function XMB:UpdateTargetFrameMonitor()
    local db = self.db
    if db and db.flywheelUnits and not CombatLocked() then
        StartTargetFrameMonitor()
    else
        StopTargetFrameMonitor()
        targetFrameClickAt = 0
        targetFramePulseAt = 0
    end
end

local function HookUnitClick(_frame)
    -- Do not HookScript Blizzard unit frames (especially TargetFrame): that taints UnitPopup.
    -- SecureUnitButton_OnClick / SecureUnitButtonMixin hooks cover other unit frames.
    -- TargetFrame double-click uses global mouse monitoring only.
    return
end

local function FlushUnitHooks()
    if CombatLocked() then
        return
    end
    for frame in pairs(pendingHooks) do
        pendingHooks[frame] = nil
    end
    XMB:UpdateTargetFrameMonitor()
end

local function HookStaticUnitFrames()
    for i = 1, #STATIC_UNIT_FRAMES do
        HookUnitClick(_G[STATIC_UNIT_FRAMES[i]])
    end
    XMB:UpdateTargetFrameMonitor()
end

local function HookNameplate(unit)
    if unit == nil or IsSecret(unit) or type(unit) ~= "string" then
        return
    end
    local plate
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, got = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok then
            plate = got
        end
    elseif GetNamePlateForUnit then
        local ok, got = pcall(GetNamePlateForUnit, unit)
        if ok then
            plate = got
        end
    end
    if not ReadableFrame(plate) then
        return
    end
    plateUnits[plate] = unit
    HookUnitClick(plate)
    local okUF, uf = pcall(ReadUnitFrame, plate)
    if okUF and ReadableFrame(uf) then
        plateUnits[uf] = unit
        HookUnitClick(uf)
    end
end

local function HookExistingPlates()
    for n = 1, 40 do
        local token = NAMEPLATE_TOKENS[n]
        if UnitIsReal(token) then
            HookNameplate(token)
        end
    end
end

function XMB:CreateFlywheel()
    if self.flywheel then
        return
    end

    local wheel = CreateFrame("Frame", "XiusMB_Flywheel", UIParent, "SecureHandlerStateTemplate")
    wheel:SetSize(WHEEL, WHEEL)
    wheel:SetFrameStrata("TOOLTIP")
    wheel:SetFrameLevel(50)
    wheel:EnableMouse(true)
    if wheel.SetToplevel then
        wheel:SetToplevel(true)
    end
    if wheel.SetPropagateMouseClicks then
        pcall(wheel.SetPropagateMouseClicks, wheel, false)
    end
    wheel:SetClampedToScreen(true)
    wheel:Hide()
    self.flywheel = wheel

    local block = CreateFrame("Button", "XiusMB_FlywheelBlocker", UIParent, "SecureHandlerClickTemplate")
    block:SetAllPoints(UIParent)
    block:SetFrameStrata("FULLSCREEN_DIALOG")
    block:SetFrameLevel(10)
    block:RegisterForClicks("AnyUp")
    block:EnableMouse(true)
    block:SetFrameRef("wheel", wheel)
    block:SetAttribute("_onclick", [[
local wheel = self:GetFrameRef("wheel")
if wheel then
  wheel:Hide()
end
self:Hide()
]])
    block:Hide()
    self.flywheelBlocker = block

    -- Secure right-click surface on the wheel background so right-click closes even during combat.
    local closeSurface = CreateFrame("Button", "XiusMB_FlywheelClose", wheel, "SecureHandlerClickTemplate")
    closeSurface:SetAllPoints(wheel)
    closeSurface:SetFrameLevel(wheel:GetFrameLevel() + 1)
    closeSurface:RegisterForClicks("RightButtonUp")
    closeSurface:SetFrameRef("wheel", wheel)
    closeSurface:SetFrameRef("block", block)
    closeSurface:SetAttribute("_onclick", [[
local wheel = self:GetFrameRef("wheel")
if wheel then
  wheel:Hide()
end
local block = self:GetFrameRef("block")
if block then
  block:Hide()
end
]])

    -- Non-protected helper registered in UISpecialFrames so ESCAPE closes the wheel outside combat
    -- without enabling keyboard capture on the protected wheel (which would block WASD in combat).
    local escFrame = CreateFrame("Frame", "XiusMB_FlywheelEsc", UIParent)
    escFrame:Hide()
    if type(UISpecialFrames) == "table" then
        local found = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == "XiusMB_FlywheelEsc" then
                found = true
                break
            end
        end
        if not found then
            UISpecialFrames[#UISpecialFrames + 1] = "XiusMB_FlywheelEsc"
        end
    end
    escFrame:SetScript("OnHide", function()
        if wheel:IsShown() and not CombatLocked() then
            wheel:Hide()
            if block:IsShown() then
                block:Hide()
            end
        end
    end)
    self.flywheelEsc = escFrame

    local units = CreateFrame("Frame", "XiusMB_FlywheelUnits", wheel)
    units:SetAllPoints()
    units:EnableMouse(false)
    units:SetFrameLevel(wheel:GetFrameLevel() + 5)
    units:Hide()
    units:SetScript("OnShow", function()
        XMB:RefreshFlywheelPortrait()
    end)
    self.flywheelUnits = units

    local worlds = CreateFrame("Frame", "XiusMB_FlywheelWorlds", wheel)
    worlds:SetAllPoints()
    worlds:EnableMouse(false)
    worlds:SetFrameLevel(wheel:GetFrameLevel() + 5)
    worlds:Hide()
    self.flywheelWorlds = worlds

    local function SpokeEnter(self)
        if self.icon then
            self.icon:SetSize(SPOKE_HOVER, SPOKE_HOVER)
        end
        ShowTip(self, self.tipTitle, self.tipLine)
    end

    local function SpokeLeave(self)
        if self.icon then
            self.icon:SetSize(SPOKE_SIZE, SPOKE_SIZE)
        end
        HideTip()
    end

    local function CenterEnter(self)
        ShowTip(self, self.tipTitle, self.tipLine)
    end

    local function AddSpokeIcon(btn, texture, isWorld)
        btn:SetSize(SPOKE_SIZE, SPOKE_SIZE)
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("CENTER")
        icon:SetSize(SPOKE_SIZE, SPOKE_SIZE)
        icon:SetTexture(texture)
        btn.icon = icon
        if isWorld then
            local flare = btn:CreateTexture(nil, "OVERLAY")
            flare:SetTexture("Interface\\RaidFrame\\Raid-WorldPing")
            flare:SetSize(12, 12)
            flare:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        end
        btn:SetScript("OnEnter", SpokeEnter)
        btn:SetScript("OnLeave", SpokeLeave)
    end

    self.flywheelUnitButtons = {}
    self.flywheelWorldButtons = {}

    local function AddMark(parentList, parent, name, kind, marker, texture, title, line)
        local btn = MakeActionButton(parent, name)
        btn:SetFrameLevel((parent:GetFrameLevel() or 0) + 20)
        ArmMark(btn, kind, marker)
        btn.tipTitle = title
        btn.tipLine = line
        if marker == 0 then
            btn:SetSize(64, 64)
            btn:SetPoint("CENTER", parent, "CENTER", 0, 0)
            btn:SetScript("OnEnter", CenterEnter)
            btn:SetScript("OnLeave", HideTip)
        else
            AddSpokeIcon(btn, texture, kind == "world")
            PlaceSpoke(parent, btn, marker)
        end
        parentList[#parentList + 1] = btn
        return btn
    end

    local unitCenter = AddMark(
        self.flywheelUnitButtons,
        units,
        "XiusMB_FW_UClear",
        "unit",
        0,
        nil,
        "Clear target mark",
        "Click to remove the mark. Right-click to close."
    )
    local portrait = unitCenter:CreateTexture(nil, "ARTWORK")
    portrait:SetPoint("CENTER")
    portrait:SetSize(60, 60)
    if unitCenter.CreateMaskTexture and portrait.AddMaskTexture then
        local okMask, mask = pcall(unitCenter.CreateMaskTexture, unitCenter)
        if okMask and mask and mask.SetTexture then
            mask:SetAllPoints(portrait)
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            pcall(portrait.AddMaskTexture, portrait, mask)
        end
    end
    portrait:Hide()
    self.flywheelPortrait = portrait

    for i = 1, 8 do
        AddMark(
            self.flywheelUnitButtons,
            units,
            "XiusMB_FW_U" .. i,
            "unit",
            i,
            MARK_TEXTURES[i],
            MARK_NAMES[i],
            "Left-click to mark. Right-click to close."
        )
    end

    local worldCenter = AddMark(
        self.flywheelWorldButtons,
        worlds,
        "XiusMB_FW_WClear",
        "world",
        0,
        nil,
        "Clear world marks",
        "Click to clear all ground markers. Right-click to close."
    )
    local worldIcon = worldCenter:CreateTexture(nil, "ARTWORK")
    worldIcon:SetPoint("CENTER")
    worldIcon:SetSize(32, 32)
    worldIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")

    for i = 1, 8 do
        AddMark(
            self.flywheelWorldButtons,
            worlds,
            "XiusMB_FW_W" .. i,
            "world",
            i,
            MARK_TEXTURES[WORLD_ICON[i]],
            WORLD_NAMES[i],
            "Left-click to place or clear ground marker. Right-click to close."
        )
    end

    local function SetupToggleButton(btnName, snippet, enabled)
        local toggle = CreateFrame("Button", btnName, UIParent, "SecureHandlerClickTemplate")
        toggle:SetSize(1, 1)
        toggle:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        toggle:SetAlpha(0)
        toggle:EnableMouse(false)
        toggle:RegisterForClicks("AnyUp")
        toggle:SetAttribute("enabled", enabled and 1 or 0)
        toggle:SetFrameRef("wheel", wheel)
        toggle:SetFrameRef("block", block)
        toggle:SetFrameRef("units", units)
        toggle:SetFrameRef("worlds", worlds)
        toggle:SetAttribute("_onclick", snippet)
        for i = 1, #self.flywheelUnitButtons do
            toggle:SetFrameRef("u" .. (i - 1), self.flywheelUnitButtons[i])
        end
        for i = 1, #self.flywheelWorldButtons do
            toggle:SetFrameRef("w" .. (i - 1), self.flywheelWorldButtons[i])
        end
        toggle:Show()
        return toggle
    end

    local db = self.db
    self.flywheelToggle = SetupToggleButton(
        "XiusMB_FlywheelToggle",
        UNIT_TOGGLE_SNIPPET,
        not db or db.flywheelUnits ~= false
    )
    self.flywheelWorldToggle = SetupToggleButton(
        "XiusMB_FlywheelWorldToggle",
        WORLD_TOGGLE_SNIPPET,
        not db or db.flywheelWorld ~= false
    )

    wheel:SetFrameRef("block", block)
    wheel:SetAttribute("_onstate-combat", COMBAT_SNIPPET)
    pcall(RegisterStateDriver, wheel, "combat", "[combat] combat; nocombat")

    wheel:SetScript("OnShow", function(self)
        XMB.flywheelOpenedAt = Clock()
        pcall(watcher.RegisterEvent, watcher, "GLOBAL_MOUSE_UP")
        if self:GetAttribute("mode") ~= "world" then
            XMB:RefreshFlywheelPortrait()
        end
        if not CombatLocked() and escFrame then
            escFrame:Show()
        end
    end)

    wheel:SetScript("OnHide", function()
        pcall(watcher.UnregisterEvent, watcher, "GLOBAL_MOUSE_UP")
        HideTip()
        ResetWheelIcons()
        if escFrame and escFrame:IsShown() then
            escFrame:Hide()
        end
        if not CombatLocked() then
            if block:IsShown() then
                block:Hide()
            end
            if XMB.markUnit and XMB.markUnit ~= "target" then
                XMB:UseMarkUnit("target")
            end
        end
    end)
end

-- Do not hooksecurefunc SecureActionButton_OnClick — that taints the secure
-- click path. Close the wheel from an insecure PostClick / deferred timer only.
local function CloseWheelAfterMark()
    if CombatLocked() then
        return
    end
    local wheel = XMB.flywheel
    if wheel and wheel:IsShown() then
        wheel:Hide()
    end
    local block = XMB.flywheelBlocker
    if block and block:IsShown() then
        block:Hide()
    end
end

local function BindSpokePostClick(btn)
    if not btn or btn.xmbPostClickBound then
        return
    end
    btn.xmbPostClickBound = true
    btn:HookScript("OnClick", function(self, button, down)
        if down then
            return
        end
        if self.xmbWorldMarker and button == "LeftButton" and XMB.NotifyWorldMarkerRequirement then
            XMB:NotifyWorldMarkerRequirement()
        end
        if not self.xmbWheelMark then
            return
        end
        if self.icon then
            self.icon:SetSize(SPOKE_SIZE, SPOKE_SIZE)
        end
        if CombatLocked() then
            return
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0, CloseWheelAfterMark)
        else
            CloseWheelAfterMark()
        end
    end)
end

XMB.BindSpokePostClick = BindSpokePostClick

local function HandleUnitButtonClick(frame)
    -- TargetFrame is owned by the global mouse monitor so UnitPopup stays untainted.
    if IsUnderTargetFrame(frame) then
        return
    end
    local unit = UnitFromFrame(frame)
    if UnitIsReal(unit) then
        XMB:NoteFlywheelClick("unit", unit)
    end
end

local function OnUnitButtonClick(self, button)
    if CombatLocked() or button ~= "LeftButton" then
        return
    end
    pcall(HandleUnitButtonClick, self)
end

if type(hooksecurefunc) == "function" then
    if SecureUnitButton_OnClick then
        hooksecurefunc("SecureUnitButton_OnClick", OnUnitButtonClick)
    end
    if SecureUnitButtonMixin and type(SecureUnitButtonMixin.OnClick) == "function" then
        hooksecurefunc(SecureUnitButtonMixin, "OnClick", OnUnitButtonClick)
    end
end

-- CompactUnitFrame_SetUnit HookScript path removed: it tainted party/raid clicks.
-- SecureUnitButton_OnClick / SecureUnitButtonMixin hooks above cover unit clicks.

local function HandleWorldLeftClick()
    local db = XMB.db
    if db and not db.flywheelUnits and not db.flywheelWorld then
        return
    end
    if UnitIsReal("mouseover") then
        XMB:NoteFlywheelClick("unit", "mouseover")
    else
        XMB:NoteFlywheelClick("world")
    end
end

if WorldFrame and WorldFrame.HookScript then
    local function OnWorldClick(_, button)
        if CombatLocked() then
            return
        end
        if button == "RightButton" then
            if XMB.flywheel and XMB.flywheel:IsShown() and not IsOverWheel() then
                XMB:CloseFlywheel()
            end
            return
        end
        if button ~= "LeftButton" then
            return
        end
        pcall(HandleWorldLeftClick)
    end
    local hooked = pcall(WorldFrame.HookScript, WorldFrame, "OnMouseUp", OnWorldClick)
    if not hooked then
        pcall(WorldFrame.HookScript, WorldFrame, "OnMouseDown", OnWorldClick)
    end
end

local function CreateFlywheelCall()
    XMB:CreateFlywheel()
end

function XMB:EnsureFlywheel()
    if self.flywheel or self.flywheelFailed then
        return
    end
    if CombatLocked() then
        self.pendingFlywheel = true
        return
    end
    self.pendingFlywheel = nil
    local created, err = pcall(CreateFlywheelCall)
    if not created then
        self.flywheelFailed = true
        self:Print("Could not create the mark wheel. " .. tostring(err))
    end
end

watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("PLAYER_LEAVING_WORLD")
watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
pcall(watcher.RegisterEvent, watcher, "NAME_PLATE_UNIT_ADDED")
-- GLOBAL_MOUSE_DOWN detects TargetFrame left double-clicks without HookScript on TargetFrame.
pcall(watcher.RegisterEvent, watcher, "GLOBAL_MOUSE_DOWN")
targetFrameUsesGlobalMouse = true
local hookedCompact = CompactUnitFrame_SetUnit and true or false
local selfLoaded = false

watcher:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            selfLoaded = true
            XMB:EnsureFlywheel()
            HookStaticUnitFrames()
        end
        if CompactUnitFrame_SetUnit then
            hookedCompact = true
        end
        if selfLoaded and hookedCompact then
            watcher:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        HookNameplate(arg1)
    elseif event == "PLAYER_ENTERING_WORLD" then
        HookStaticUnitFrames()
        HookExistingPlates()
    elseif event == "PLAYER_LEAVING_WORLD" then
        hasPendingClick = false
        lastClick.kind = nil
        targetFrameClickAt = 0
        targetFramePulseAt = 0
        StopTargetFrameMonitor()
        XMB:CloseFlywheel()
    elseif event == "PLAYER_TARGET_CHANGED" then
        if not UnitIsReal("target") then
            if lastClick.kind == "unit" then
                lastClick.kind = nil
            end
            targetFrameClickAt = 0
            targetFramePulseAt = 0
        end
        if XMB.flywheel and XMB.flywheel:IsShown() and XMB.flywheel:GetAttribute("mode") == "unit" then
            XMB:RefreshFlywheelPortrait()
        end
    elseif event == "GLOBAL_MOUSE_DOWN" then
        -- LeftButton only. RightButton is ignored so TargetFrame UnitPopup stays native.
        if arg1 ~= "LeftButton" or CombatLocked() then
            return
        end
        local db = XMB.db
        if not db or not db.flywheelUnits then
            return
        end
        OnTargetFrameLeftEdge()
    elseif event == "GLOBAL_MOUSE_UP" then
        if not (XMB.flywheel and XMB.flywheel:IsShown()) or CombatLocked() then
            return
        end
        if arg1 ~= "LeftButton" and arg1 ~= "RightButton" then
            return
        end
        if (Clock() - (XMB.flywheelOpenedAt or 0)) > 0.05 and not IsOverWheel() then
            XMB:CloseFlywheel()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Hide the radial wheel immediately when combat starts (state driver also hides it).
        XMB:ForceCloseFlywheel()
        StopTargetFrameMonitor()
        if XMB.markUnit and XMB.markUnit ~= "target" then
            XMB:UseMarkUnit("target")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        XMB:EnsureFlywheel()
        if XMB.markUnit and XMB.markUnit ~= "target" and (not XMB.flywheel or not XMB.flywheel:IsShown()) then
            XMB:UseMarkUnit("target")
        end
        if XMB.pendingFlywheelSettings then
            XMB:ApplyFlywheelSettings()
        end
        FlushUnitHooks()
    end
end)
