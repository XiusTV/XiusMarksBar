--[[
    Xius Marks Bar - Config.lua
    Defaults, saved variables, and slash commands.
    The options window lives in XiusCore.
]]

local ADDON, XMB = ...

local coreLoaded = (_G.XiusUI and _G.XiusUI.isCore)
    or _G.XiusCoreSettingsLib
    or _G.XiusUISettingsLib
if not coreLoaded and type(C_AddOns) == "table" and type(C_AddOns.IsAddOnLoaded) == "function" then
    local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "XiusCore")
    coreLoaded = ok and loaded
end
if not coreLoaded and type(IsAddOnLoaded) == "function" then
    local ok, loaded = pcall(IsAddOnLoaded, "XiusCore")
    coreLoaded = ok and loaded
end
if not coreLoaded then
    XMB.disabled = true
    return
end

XMB.ADDON = ADDON
XMB.TITLE = "Xius Marks Bar"
XMB.VERSION = "1.3.8"
XMB.DB_VERSION = 1

local function IsSecret(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret == true then
            return true
        end
    end
    if type(canaccessvalue) == "function" then
        local ok, access = pcall(canaccessvalue, value)
        if ok and access == false then
            return true
        end
    end
    return false
end

local function IsFiniteNumber(value)
    if IsSecret(value) or type(value) ~= "number" then
        return false
    end
    return value == value and value > -math.huge and value < math.huge
end

function XMB:CombatLocked()
    if type(InCombatLockdown) ~= "function" then
        return true
    end
    local ok, locked = pcall(InCombatLockdown)
    if not ok or IsSecret(locked) then
        return true
    end
    return locked == true
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
    enabled = true,
    isLocked = false,
    showTooltips = true,
    onlyInGroup = false,
    visibility = "always",
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
    flywheelModifier = "NONE",
    growthDirection = "AUTO",
    scale = 1,
}

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

-- Xius Core copies this addon into XiusUIDB.marks for profiles, then
-- points the saved-variable name at that table. The saved file loads later
-- and splits them. Join them again so a profile switch changes this bar.
local function AdoptCoreDB()
    if type(XiusUIDB) ~= "table" then
        return
    end
    local profile = XiusUIDB.marks
    if type(profile) ~= "table" then
        profile = {}
        XiusUIDB.marks = profile
    end
    local saved = XiusMarksBarDB
    if type(saved) ~= "table" then
        XiusMarksBarDB = profile
        return
    end
    if saved == profile then
        return
    end
    -- The addon's own file is the bar the player has been using.
    -- Core's copy was taken before that file loaded, so keep the live table.
    XiusUIDB.marks = saved
    XiusMarksBarDB = saved
end

function XMB:InitDB()
    AdoptCoreDB()
    local saved = XiusMarksBarDB
    local hadPull5 = type(saved) == "table" and saved.showPull5 ~= nil
    local hadPull10 = type(saved) == "table" and saved.showPull10 ~= nil
    local hadPull20 = type(saved) == "table" and saved.showPull20 ~= nil
    local oldCountdown = type(saved) == "table" and saved.showCountdown
    local hadVisibility = type(saved) == "table" and type(saved.visibility) == "string"
    local wasGrouped = type(saved) == "table" and saved.onlyInGroup == true
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

    if not hadVisibility then
        db.visibility = wasGrouped and "group" or "always"
    elseif db.visibility ~= "group" and db.visibility ~= "leader" then
        db.visibility = "always"
    end
    db.onlyInGroup = db.visibility == "group"
    if db.enabled == nil then
        db.enabled = true
    end
    if db.growthDirection ~= "UP" and db.growthDirection ~= "DOWN" then
        db.growthDirection = "AUTO"
    end
    if db.flywheelModifier ~= "SHIFT" and db.flywheelModifier ~= "ALT" and db.flywheelModifier ~= "CTRL" then
        db.flywheelModifier = "NONE"
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
    flywheelModifier = true,
}

function XMB:SetDBValue(key, value)
    local db = self.db
    if not db then
        return
    end
    if key == "visibility" then
        if value ~= "group" and value ~= "leader" then
            value = "always"
        end
        db.visibility = value
        db.onlyInGroup = value == "group"
    elseif key == "onlyInGroup" then
        local on = value and true or false
        db.onlyInGroup = on
        db.visibility = on and "group" or "always"
    elseif key == "enabled" then
        db.enabled = value ~= false
    else
        db[key] = value
    end
    if FLYWHEEL_KEYS[key] then
        if self.ApplyFlywheelSettings then
            self:ApplyFlywheelSettings()
        end
        return
    end
    self:NotifySettingsChanged()
end

function XMB:ResetToDefaults()
    if not self.db then
        self:InitDB()
    end
    local db = self.db
    for k, v in pairs(self.defaults) do
        db[k] = v
    end
    if self.ApplyFlywheelSettings then
        self:ApplyFlywheelSettings()
    end
    self:NotifySettingsChanged()
    local Lib = _G.XiusCoreSettingsLib
    if Lib and Lib.RefreshPage then
        Lib:RefreshPage()
    end
end

function XMB:UnlockFrames()
    if self.db then
        self.db.isLocked = false
    end
    self:NotifySettingsChanged()
end

function XMB:OpenOptions()
    if InCombatLockdown and XMB:CombatLocked() then
        self:Print("Leave combat to open options.")
        return
    end
    local Lib = _G.XiusCoreSettingsLib
    if Lib and type(Lib.OpenModule) == "function" then
        Lib:OpenModule("Marks")
        return
    end
    self:Print("Xius Core is required to open options.")
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
        self:SetDBValue("isLocked", cmd == "lock")
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
        self:SetDBValue("scale", val)
        self:Print(string.format("Scale set to %d%%.", math.floor(val * 100 + 0.5)))
    elseif cmd == "help" then
        self:Print("Commands: /xmb, /xmb reset, /xmb lock, /xmb unlock, /xmb scale 60-160, /xmb collapse")
    else
        self:OpenOptions()
    end
end

if XiusUI and XiusUI.RegisterModule then
    XiusUI:RegisterModule("Marks", XMB)
end

SLASH_XIUSMARKSBAR1 = "/xmb"
SlashCmdList.XIUSMARKSBAR = function(msg)
    XMB:HandleSlash(msg)
end
