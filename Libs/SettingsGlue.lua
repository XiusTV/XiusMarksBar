--[[
    Register the Marks Bar settings page with XiusCore using top sub-tabs:
    General, Marks & Wheels, and Timers & Checks.
]]

local addonName, ns = ...
local XMB = ns

if XMB.disabled then
    return
end

local type = type
local tostring = tostring
local floor = math.floor

local Lib = _G.XiusCoreSettingsLib
if not Lib or type(Lib.RegisterModule) ~= "function" then
    return
end

local SUB_TABS = {
    { id = "general", text = "General" },
    { id = "marks", text = "Marks & Wheels" },
    { id = "timers", text = "Timers & Checks" },
}

local VISIBILITY_ITEMS = {
    { value = "always", text = "Always" },
    { value = "group", text = "Group or instance" },
    { value = "leader", text = "Leader or assistant" },
}

local ORIENTATION_ITEMS = {
    { value = "AUTO", text = "Auto (Screen Position)" },
    { value = "UP", text = "Always Expand Up" },
    { value = "DOWN", text = "Always Expand Down" },
}

local MODIFIER_ITEMS = {
    { value = "NONE", text = "Double-click" },
    { value = "SHIFT", text = "Shift + double-click" },
    { value = "ALT", text = "Alt + double-click" },
    { value = "CTRL", text = "Ctrl + double-click" },
}

local TARGET_MARK_KEYS = XMB.TARGET_MARK_KEYS or {}
local WORLD_MARK_KEYS = XMB.WORLD_MARK_KEYS or {}

local function FlagDefaultTrue(key)
    local db = XMB.db
    return not db or db[key] ~= false
end

local function Flag(key)
    local db = XMB.db
    return db and db[key] and true or false
end

local function SetFlag(key, value)
    if XMB.SetDBValue then
        XMB:SetDBValue(key, value and true or false)
    end
end

local function MarkIconLabel(tex, index, name)
    if type(tex) == "string" and tex ~= "" then
        return "|T" .. tex .. ":14:14:0:0|t " .. tostring(index) .. ". " .. tostring(name)
    end
    return tostring(index) .. ". " .. tostring(name)
end

local function BuildGeneralTab(_, api)
    api:AddSection("Bar & Visibility")
    api:AddNote("Click the flag for world marks and the star for target marks. Key bindings are under Key Bindings, AddOns, Xius Marks Bar.")
    api:AddCheckbox("Show the bar", function()
        return FlagDefaultTrue("enabled")
    end, function(value)
        SetFlag("enabled", value)
    end, "Hides the whole bar. Key bindings and the mark wheels stay available.")

    api:AddDropdown("Visibility", VISIBILITY_ITEMS, function()
        local db = XMB.db
        local mode = db and db.visibility
        if mode == "group" or mode == "leader" then
            return mode
        end
        if db and db.onlyInGroup then
            return "group"
        end
        return "always"
    end, function(value)
        if XMB.SetDBValue then
            XMB:SetDBValue("visibility", value)
        end
    end, "Leader or assistant hides the bar until you can mark for the group.")

    api:AddCheckbox("Lock bar (blocks dragging)", function()
        return Flag("isLocked")
    end, function(value)
        if XMB.SetLocked then
            XMB:SetLocked(value)
        else
            SetFlag("isLocked", value)
        end
        if value and Lib.NoteFramesLocked then
            Lib:NoteFramesLocked()
        end
    end, "Keeps the bar in place. The grip stays visible and turns red while locked.")

    api:AddCheckbox("Show tooltips", function()
        return FlagDefaultTrue("showTooltips")
    end, function(value)
        SetFlag("showTooltips", value)
    end, "Shows button tooltips above or below the bar and on the mark wheel.")

    api:AddSection("Scale & Layout Orientation")
    api:AddSlider("Bar scale (%)", 60, 160, 5, function()
        return floor((((XMB.db and XMB.db.scale) or 1) * 100) + 0.5)
    end, function(value)
        if XMB.SetDBValue then
            XMB:SetDBValue("scale", value / 100)
        end
    end, "60% to 160%.")

    api:AddDropdown("Layout orientation", ORIENTATION_ITEMS, function()
        local db = XMB.db
        local mode = db and db.growthDirection or "AUTO"
        if mode ~= "UP" and mode ~= "DOWN" then
            return "AUTO"
        end
        return mode
    end, function(value)
        if XMB.SetDBValue then
            XMB:SetDBValue("growthDirection", value)
        end
    end, "Controls which direction the target and world mark rows expand from the main bar. Auto grows toward the middle of the screen.")

    api:AddSection("Actions")
    api:AddButtonGroup({
        gap = 6,
        buttons = {
            {
                text = "Reset Position",
                width = 112,
                onClick = function()
                    if XMB.ResetPosition then
                        XMB:ResetPosition()
                    end
                end,
            },
            {
                text = "Collapse Marks",
                width = 112,
                onClick = function()
                    if XMB.SetRows then
                        XMB:SetRows(false, false)
                    end
                end,
            },
            {
                text = "Defaults",
                width = 112,
                onClick = function()
                    if XMB.ResetToDefaults then
                        XMB:ResetToDefaults()
                    end
                end,
            },
            {
                text = "Unlock Frames",
                width = 112,
                onClick = function()
                    if Lib.ToggleFramesUnlocked then
                        Lib:ToggleFramesUnlocked()
                    elseif XMB.UnlockFrames then
                        XMB:UnlockFrames()
                    end
                    if Lib.RefreshPage then
                        Lib:RefreshPage()
                    end
                end,
            },
        },
    })
end

local function BuildMarksAndWheelsTab(_, api)
    api:AddSection("Bar Mark Rows & Clear Buttons")
    api:AddCheckbox("Target marks row (star)", function()
        return FlagDefaultTrue("enableTargetMarks")
    end, function(value)
        SetFlag("enableTargetMarks", value)
    end, "Shows the star button on the bar to expand target marks.")

    api:AddCheckbox("Clear target mark button", function()
        return FlagDefaultTrue("showTargetClear")
    end, function(value)
        SetFlag("showTargetClear", value)
    end, "Shows the Clear Target Mark button at the end of the target marks row.")

    api:AddCheckbox("World markers row (flag)", function()
        return FlagDefaultTrue("enableWorldMarks")
    end, function(value)
        SetFlag("enableWorldMarks", value)
    end, "Shows the flag button on the bar to expand ground world markers.")

    api:AddCheckbox("Clear world markers button", function()
        return FlagDefaultTrue("showWorldClear")
    end, function(value)
        SetFlag("showWorldClear", value)
    end, "Shows the Clear World Markers button at the end of the world markers row.")

    api:AddSection("Target Marks (1-8)")
    local markTextures = XMB.MARK_TEXTURES or {}
    local markNames = XMB.MARK_NAMES or {}
    for i = 1, 8 do
        local key = TARGET_MARK_KEYS[i] or ("showTargetMark" .. i)
        local name = markNames[i] or ("Mark " .. i)
        local label = MarkIconLabel(markTextures[i], i, name)
        api:AddCheckbox(label, function()
            return FlagDefaultTrue(key)
        end, function(value)
            SetFlag(key, value)
        end, "Shows " .. name .. " on the target marks row.")
    end

    api:AddSection("World Markers (1-8)")
    local worldIcon = XMB.WORLD_ICON or {}
    local worldNames = XMB.WORLD_NAMES or {}
    for i = 1, 8 do
        local key = WORLD_MARK_KEYS[i] or ("showWorldMark" .. i)
        local name = worldNames[i] or ("World Marker " .. i)
        local tex = markTextures[worldIcon[i] or i]
        local label = MarkIconLabel(tex, i, name)
        api:AddCheckbox(label, function()
            return FlagDefaultTrue(key)
        end, function(value)
            SetFlag(key, value)
        end, "Shows " .. name .. " on the world markers row.")
    end

    api:AddSection("Radial Mark Wheel")
    api:AddCheckbox("Unit mark wheel (mobs, players, frames)", function()
        return FlagDefaultTrue("flywheelUnits")
    end, function(value)
        SetFlag("flywheelUnits", value)
    end, "Double-click a unit, nameplate, or unit frame to open the radial target mark wheel at your cursor.")

    api:AddCheckbox("World-marker wheel (the ground)", function()
        return FlagDefaultTrue("flywheelWorld")
    end, function(value)
        SetFlag("flywheelWorld", value)
    end, "Double-click the ground to open the radial world marker wheel at your cursor.")

    api:AddDropdown("Wheel modifier", MODIFIER_ITEMS, function()
        local db = XMB.db
        local mode = db and db.flywheelModifier or "NONE"
        if mode ~= "SHIFT" and mode ~= "ALT" and mode ~= "CTRL" then
            return "NONE"
        end
        return mode
    end, function(value)
        if XMB.SetDBValue then
            XMB:SetDBValue("flywheelModifier", value)
        end
    end, "Hold that key and double-click a unit or the ground outside combat. Key bindings open the wheels during combat.")
end

local function BuildTimersAndChecksTab(_, api)
    api:AddSection("Pull Timers")
    api:AddNote("Left-click a pull timer button on the bar to start a countdown. Click again or right-click to cancel.")
    api:AddCheckbox("5 second countdown", function()
        return Flag("showPull5")
    end, function(value)
        SetFlag("showPull5", value)
    end, "Shows the 5 second pull timer button on the bar.")

    api:AddCheckbox("10 second countdown", function()
        return Flag("showPull10")
    end, function(value)
        SetFlag("showPull10", value)
    end, "Shows the 10 second pull timer button on the bar.")

    api:AddCheckbox("20 second countdown", function()
        return Flag("showPull20")
    end, function(value)
        SetFlag("showPull20", value)
    end, "Shows the 20 second pull timer button on the bar.")

    api:AddSection("Group Checks")
    api:AddCheckbox("Ready Check button (RC)", function()
        return Flag("showReady")
    end, function(value)
        SetFlag("showReady", value)
    end, "Shows the Ready Check button on the bar. Leader or assistant only.")

    api:AddCheckbox("Role Check button (R)", function()
        return Flag("showRole")
    end, function(value)
        SetFlag("showRole", value)
    end, "Shows the Role Check button on the bar to ask everyone to pick a role.")
end

Lib:RegisterModule({
    id = "Marks",
    title = "Xius Marks Bar",
    menuTitle = "Marks Bar",
    group = "HUD & Combat",
    order = 30,
    slashCommands = { "/xmb" },
    hidePageTitle = true,
    activeSubTab = "general",
    subTabs = SUB_TABS,
    defaults = XMB.defaults,
    getDB = function()
        return XMB.db
    end,
    onResetDefaults = function()
        if XMB.ResetToDefaults then
            XMB:ResetToDefaults()
        end
    end,
    onUnlock = function(unlocked)
        if XMB.SetLocked then
            XMB:SetLocked(not unlocked)
        elseif XMB.SetDBValue then
            XMB:SetDBValue("isLocked", not unlocked)
        end
    end,
    onUnlockFrames = function()
        if XMB.UnlockFrames then
            XMB:UnlockFrames()
        end
    end,
    buildContent = function(host, api, spec, tabId)
        local subTab = tabId or (spec and spec.activeSubTab) or "general"
        if subTab == "marks" then
            BuildMarksAndWheelsTab(host, api)
        elseif subTab == "timers" then
            BuildTimersAndChecksTab(host, api)
        else
            BuildGeneralTab(host, api)
        end
    end,
})
