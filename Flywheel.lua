--[[
    Xius Marks Bar - Flywheel.lua
    Double-click a unit for a radial target-mark wheel.
    Double-click the ground for a radial world-marker wheel.
    Key bindings open the same wheels during combat.
]]

local ADDON, XMB = ...

BINDING_HEADER_XIUSMARKSBAR = "Xius Marks Bar"
BINDING_NAME_XIUSMB_UNIT_WHEEL = "Open target mark wheel"
BINDING_NAME_XIUSMB_WORLD_WHEEL = "Open world marker wheel"
_G["BINDING_NAME_CLICK XiusMB_FlywheelToggle:LeftButton"] = "Open target mark wheel"
_G["BINDING_NAME_CLICK XiusMB_FlywheelWorldToggle:LeftButton"] = "Open world marker wheel"

local WHEEL = 168
local HALF = WHEEL / 2
local RADIUS = 58
local DOUBLE_WINDOW = 0.32
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

-- Weak tables avoid writing custom fields onto Blizzard unit frames or nameplates (prevents taint).
local hookedFrames = setmetatable({}, { __mode = "k" })
local plateUnits = setmetatable({}, { __mode = "k" })
local pendingHooks = setmetatable({}, { __mode = "k" })

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
    local x, y = GetCursorPosition()
    if not IsFiniteNumber(x) or not IsFiniteNumber(y) then
        return 0, 0
    end
    return x, y
end

local function CursorPoint()
    local x, y = CursorRaw()
    local scale = UIParent:GetEffectiveScale() or 1
    if not IsFiniteNumber(scale) or scale <= 0 then
        scale = 1
    end
    x, y = x / scale, y / scale
    local sw, sh = UIParent:GetWidth() or 1024, UIParent:GetHeight() or 768
    if not IsFiniteNumber(sw) or sw <= 0 then
        sw = 1024
    end
    if not IsFiniteNumber(sh) or sh <= 0 then
        sh = 768
    end
    x = math.max(HALF, math.min(sw - HALF, x))
    y = math.max(HALF, math.min(sh - HALF, y))
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
    local angle = math.rad(90 - (index - 1) * 45)
    btn:SetPoint("CENTER", parent, "CENTER", math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
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
    if InCombatLockdown() then
        self.pendingFlywheelSettings = true
        return
    end
    self.pendingFlywheelSettings = nil
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
    if unit:match("^party%d+$") or unit:match("^raid%d+$") or unit:match("^boss%d+$") or unit:match("^arena%d+$") then
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
    if not InCombatLockdown() and IsStableUnitToken(unit) and UnitIsReal(unit) then
        resolved = unit
    end
    self.markUnit = resolved
    local buttons = self.flywheelUnitButtons
    if not buttons or InCombatLockdown() then
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
    if InCombatLockdown() then
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
    if InCombatLockdown() then
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

    if InCombatLockdown() then
        self:FlywheelCombatNotice()
        return
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

    -- Never call EnableMouse(false) on hidden buttons so the secure combat toggle can show them.
    local function ShowList(list, shown)
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
    if kind == "world" then
        ShowList(self.flywheelUnitButtons, false)
        if self.flywheelUnits then
            self.flywheelUnits:Hide()
        end
        if self.flywheelWorlds then
            self.flywheelWorlds:Show()
        end
        ShowList(self.flywheelWorldButtons, true)
    else
        ShowList(self.flywheelWorldButtons, false)
        if self.flywheelWorlds then
            self.flywheelWorlds:Hide()
        end
        if self.flywheelUnits then
            self.flywheelUnits:Show()
        end
        ShowList(self.flywheelUnitButtons, true)
    end
    wheel:Show()
    self.flywheelOpenedAt = GetTime()
end

local function SafeSame(a, b)
    if IsSecret(a) or IsSecret(b) or a == nil or b == nil then
        return false
    end
    local ok, same = pcall(function()
        return a == b
    end)
    if not ok or IsSecret(same) then
        return false
    end
    return same
end

local function MovedTooFar(x1, y1, x2, y2, limit)
    limit = limit or MOVE_LIMIT
    local ok, far = pcall(function()
        local dx = x1 - x2
        local dy = y1 - y2
        return (dx * dx + dy * dy) > (limit * limit)
    end)
    if not ok or IsSecret(far) then
        return false
    end
    return far
end

local function HasUnit(value)
    if IsSecret(value) then
        return true
    end
    return type(value) == "string" and value ~= ""
end

local function UnitFromFrame(frame)
    if not ReadableFrame(frame) then
        return nil
    end
    local mapped = plateUnits[frame]
    if HasUnit(mapped) then
        return mapped
    end
    local okU, unitField = pcall(function()
        return frame.unit or frame.namePlateUnitToken or frame.displayedUnit
    end)
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

local function CursorOverFrame(frame, padX, padAbove, padBelow)
    if not ReadableFrame(frame) or not frame.GetLeft or not frame.IsVisible then
        return false
    end
    local ok, inside = pcall(function()
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
        local cx, cy = CursorRaw()
        local l = (left - padX) * scale
        local r = (left + width + padX) * scale
        local b = (bottom - padBelow) * scale
        local t = (bottom + height + padAbove) * scale
        return cx >= l and cx <= r and cy >= b and cy <= t
    end)
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
    local okP, token = pcall(function()
        return plate.namePlateUnitToken or plate.unit
    end)
    if okP and UnitIsReal(token) then
        return token
    end
    local okUF, uf = pcall(function()
        return plate.UnitFrame
    end)
    if okUF and ReadableFrame(uf) then
        unit = plateUnits[uf]
        if UnitIsReal(unit) then
            return unit
        end
        local okUFT, ufToken = pcall(function()
            return uf.unit or uf.namePlateUnitToken or uf.displayedUnit
        end)
        if okUFT and UnitIsReal(ufToken) then
            return ufToken
        end
    end
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then
        return nil
    end
    for n = 1, 40 do
        local candidate = "nameplate" .. n
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
    for i = 1, #plates do
        local plate = plates[i]
        if ReadableFrame(plate) then
            local okUF, visual = pcall(function()
                return plate.UnitFrame
            end)
            visual = (okUF and ReadableFrame(visual)) and visual or plate
            if CursorOverFrame(visual, 8, 6, 6) or CursorOverFrame(plate, 8, 6, 6) then
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
    if not XMB.db or InCombatLockdown() then
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
    if not db or InCombatLockdown() then
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
    local now = GetTime()
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

local function HookUnitClick(frame)
    if not ReadableFrame(frame) or hookedFrames[frame] or not frame.HookScript then
        return
    end
    if InCombatLockdown() then
        pendingHooks[frame] = true
        return
    end
    pendingHooks[frame] = nil
    local ok = pcall(frame.HookScript, frame, "OnMouseUp", function(self, button)
        if InCombatLockdown() then
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
        local unit = UnitFromFrame(self)
        if UnitIsReal(unit) then
            XMB:NoteFlywheelClick("unit", unit)
        end
    end)
    if ok then
        hookedFrames[frame] = true
    end
end

local function FlushUnitHooks()
    if InCombatLockdown() then
        return
    end
    for frame in pairs(pendingHooks) do
        HookUnitClick(frame)
    end
end

local function HookStaticUnitFrames()
    local names = {
        "PlayerFrame",
        "TargetFrame",
        "FocusFrame",
        "PetFrame",
        "TargetFrameToT",
        "FocusFrameToT",
    }
    for i = 1, 4 do
        names[#names + 1] = "PartyMemberFrame" .. i
    end
    for i = 1, 5 do
        names[#names + 1] = "Boss" .. i .. "TargetFrame"
    end
    for i = 1, #names do
        HookUnitClick(_G[names[i]])
    end
end

local function HookNameplate(unit)
    if not unit then
        return
    end
    pcall(function()
        local plate
        if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
            plate = C_NamePlate.GetNamePlateForUnit(unit)
        elseif GetNamePlateForUnit then
            plate = GetNamePlateForUnit(unit)
        end
        if not ReadableFrame(plate) then
            return
        end
        plateUnits[plate] = unit
        HookUnitClick(plate)
        local okUF, uf = pcall(function()
            return plate.UnitFrame
        end)
        if okUF and ReadableFrame(uf) then
            plateUnits[uf] = unit
            HookUnitClick(uf)
        end
    end)
end

local function HookExistingPlates()
    for n = 1, 40 do
        local token = "nameplate" .. n
        if UnitIsReal(token) then
            HookNameplate(token)
        end
    end
end

local function MigrateOldBindings()
    if InCombatLockdown() or not GetBindingKey or not SetBinding then
        return
    end
    pcall(function()
        local mapping = {
            XIUSMB_UNIT_WHEEL = "CLICK XiusMB_FlywheelToggle:LeftButton",
            XIUSMB_WORLD_WHEEL = "CLICK XiusMB_FlywheelWorldToggle:LeftButton",
        }
        local changed = false
        for oldCmd, newCmd in pairs(mapping) do
            local k1, k2 = GetBindingKey(oldCmd)
            if k1 and k1 ~= "" then
                SetBinding(k1, newCmd)
                changed = true
            end
            if k2 and k2 ~= "" then
                SetBinding(k2, newCmd)
                changed = true
            end
        end
        if changed and SaveBindings and GetCurrentBindingSet then
            local set = GetCurrentBindingSet()
            if set == 1 or set == 2 then
                SaveBindings(set)
            end
        end
    end)
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
        if wheel:IsShown() and not InCombatLockdown() then
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
            btn:SetScript("OnEnter", function(self)
                ShowTip(self, self.tipTitle, self.tipLine)
            end)
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
    local mask = unitCenter:CreateMaskTexture()
    mask:SetAllPoints(portrait)
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    portrait:AddMaskTexture(mask)
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
        XMB.flywheelOpenedAt = GetTime()
        if self:GetAttribute("mode") ~= "world" then
            XMB:RefreshFlywheelPortrait()
        end
        if not InCombatLockdown() and escFrame then
            escFrame:Show()
        end
    end)

    wheel:SetScript("OnHide", function()
        HideTip()
        ResetWheelIcons()
        if escFrame and escFrame:IsShown() then
            escFrame:Hide()
        end
        if not InCombatLockdown() then
            if block:IsShown() then
                block:Hide()
            end
            if XMB.markUnit and XMB.markUnit ~= "target" then
                XMB:UseMarkUnit("target")
            end
        end
    end)
end

local function OnPostSecureActionClick(self, button, down)
    if not self or down then
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
    local wheel = XMB.flywheel
    if not wheel or not wheel:IsShown() or InCombatLockdown() then
        return
    end
    wheel:Hide()
    local block = XMB.flywheelBlocker
    if block and block:IsShown() then
        block:Hide()
    end
end

if type(hooksecurefunc) == "function" then
    if SecureActionButton_OnClick then
        hooksecurefunc("SecureActionButton_OnClick", OnPostSecureActionClick)
    end
    if SecureActionButtonMixin and type(SecureActionButtonMixin.OnClick) == "function" then
        hooksecurefunc(SecureActionButtonMixin, "OnClick", OnPostSecureActionClick)
    end
end

local function OnUnitButtonClick(self, button)
    if InCombatLockdown() or button ~= "LeftButton" then
        return
    end
    pcall(function()
        local unit = UnitFromFrame(self)
        if UnitIsReal(unit) then
            XMB:NoteFlywheelClick("unit", unit)
        end
    end)
end

if type(hooksecurefunc) == "function" then
    if SecureUnitButton_OnClick then
        hooksecurefunc("SecureUnitButton_OnClick", OnUnitButtonClick)
    end
    if SecureUnitButtonMixin and type(SecureUnitButtonMixin.OnClick) == "function" then
        hooksecurefunc(SecureUnitButtonMixin, "OnClick", OnUnitButtonClick)
    end
end

if CompactUnitFrame_SetUnit then
    hooksecurefunc("CompactUnitFrame_SetUnit", function(frame)
        HookUnitClick(frame)
    end)
end

if WorldFrame and WorldFrame.HookScript then
    local function OnWorldClick(_, button)
        if InCombatLockdown() then
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
        pcall(function()
            local db = XMB.db
            if db and not db.flywheelUnits and not db.flywheelWorld then
                return
            end
            if UnitIsReal("mouseover") then
                XMB:NoteFlywheelClick("unit", "mouseover")
            else
                XMB:NoteFlywheelClick("world")
            end
        end)
    end
    local hooked = pcall(WorldFrame.HookScript, WorldFrame, "OnMouseUp", OnWorldClick)
    if not hooked then
        pcall(WorldFrame.HookScript, WorldFrame, "OnMouseDown", OnWorldClick)
    end
end

function XMB:EnsureFlywheel()
    if self.flywheel or self.flywheelFailed then
        return
    end
    if InCombatLockdown() then
        self.pendingFlywheel = true
        return
    end
    self.pendingFlywheel = nil
    local created, err = pcall(function()
        self:CreateFlywheel()
    end)
    if not created then
        self.flywheelFailed = true
        self:Print("Could not create the mark wheel. " .. tostring(err))
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("PLAYER_LEAVING_WORLD")
watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
pcall(watcher.RegisterEvent, watcher, "NAME_PLATE_UNIT_ADDED")
pcall(watcher.RegisterEvent, watcher, "GLOBAL_MOUSE_UP")
local hookedCompact = CompactUnitFrame_SetUnit and true or false

watcher:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            XMB:EnsureFlywheel()
            HookStaticUnitFrames()
        end
        if not hookedCompact and CompactUnitFrame_SetUnit then
            hookedCompact = true
            hooksecurefunc("CompactUnitFrame_SetUnit", function(frame)
                HookUnitClick(frame)
            end)
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        HookNameplate(arg1)
    elseif event == "PLAYER_ENTERING_WORLD" then
        MigrateOldBindings()
        HookStaticUnitFrames()
        HookExistingPlates()
    elseif event == "PLAYER_LEAVING_WORLD" then
        hasPendingClick = false
        lastClick.kind = nil
        XMB:CloseFlywheel()
    elseif event == "PLAYER_TARGET_CHANGED" then
        if not UnitIsReal("target") and lastClick.kind == "unit" then
            lastClick.kind = nil
        end
        if XMB.flywheel and XMB.flywheel:IsShown() and XMB.flywheel:GetAttribute("mode") == "unit" then
            XMB:RefreshFlywheelPortrait()
        end
    elseif event == "GLOBAL_MOUSE_UP" then
        if InCombatLockdown() then
            return
        end
        if arg1 ~= "LeftButton" and arg1 ~= "RightButton" then
            return
        end
        if XMB.flywheel and XMB.flywheel:IsShown() then
            if (GetTime() - (XMB.flywheelOpenedAt or 0)) > 0.05 and not IsOverWheel() then
                XMB:CloseFlywheel()
            end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        hasPendingClick = false
        lastClick.kind = nil
        if XMB.flywheelEsc and XMB.flywheelEsc:IsShown() then
            XMB.flywheelEsc:Hide()
        end
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
