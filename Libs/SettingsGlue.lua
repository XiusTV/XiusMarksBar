--[[
    Register the Marks Bar settings page with XiusCore.
]]

local _, XMB = ...

if XMB.disabled then
    return
end

local Lib = _G.XiusCoreSettingsLib
if not Lib or type(Lib.RegisterModule) ~= "function" then
    return
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

Lib:RegisterModule({
    id = "Marks",
    title = "Xius Marks Bar",
    menuTitle = "Marks Bar",
    group = "HUD & Combat",
    order = 30,
    slashCommands = { "/xmb" },
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
        if XMB.SetDBValue then
            XMB:SetDBValue("isLocked", not unlocked)
        end
    end,
    onUnlockFrames = function()
        if XMB.UnlockFrames then
            XMB:UnlockFrames()
        end
    end,
    buildContent = function(_, api)
        api:Header("Marks Bar")
        api:Note("Click the flag for world marks and the star for target marks. Key bindings are under Key Bindings, AddOns, Xius Marks Bar.")

        api:Header("Bar")
        api:Checkbox("Show the bar", function()
            local db = XMB.db
            return not db or db.enabled ~= false
        end, function(value)
            SetFlag("enabled", value)
        end, "Hides the whole bar. Key bindings and the mark wheels stay available.")
        api:Checkbox("Lock bar (blocks dragging)", function()
            return Flag("isLocked")
        end, function(value)
            SetFlag("isLocked", value)
            if value and Lib.NoteFramesLocked then
                Lib:NoteFramesLocked()
            end
        end, "Keeps the bar in place. The grip stays visible and turns red while locked.")
        api:Dropdown("Visibility", {
            { value = "always", text = "Always" },
            { value = "group", text = "Group or instance" },
            { value = "leader", text = "Leader or assistant" },
        }, function()
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
        api:Checkbox("Show tooltips", function()
            local db = XMB.db
            return not db or db.showTooltips ~= false
        end, function(value)
            SetFlag("showTooltips", value)
        end)

        api:Header("Marks On The Bar")
        api:Checkbox("NPC and target marks (star)", function()
            local db = XMB.db
            return not db or db.enableTargetMarks ~= false
        end, function(value)
            SetFlag("enableTargetMarks", value)
        end)
        api:Checkbox("World markers (flag)", function()
            local db = XMB.db
            return not db or db.enableWorldMarks ~= false
        end, function(value)
            SetFlag("enableWorldMarks", value)
        end)

        api:Header("Countdown")
        api:Checkbox("5 second countdown", function()
            return Flag("showPull5")
        end, function(value)
            SetFlag("showPull5", value)
        end)
        api:Checkbox("10 second countdown", function()
            return Flag("showPull10")
        end, function(value)
            SetFlag("showPull10", value)
        end)
        api:Checkbox("20 second countdown", function()
            return Flag("showPull20")
        end, function(value)
            SetFlag("showPull20", value)
        end)

        api:Header("Group Checks")
        api:Checkbox("Ready check", function()
            return Flag("showReady")
        end, function(value)
            SetFlag("showReady", value)
        end)
        api:Checkbox("Role check", function()
            return Flag("showRole")
        end, function(value)
            SetFlag("showRole", value)
        end)

        api:Header("Mark Wheel")
        api:Checkbox("Unit mark wheel (mobs, players, frames)", function()
            local db = XMB.db
            return not db or db.flywheelUnits ~= false
        end, function(value)
            SetFlag("flywheelUnits", value)
        end)
        api:Checkbox("World-marker wheel (the ground)", function()
            local db = XMB.db
            return not db or db.flywheelWorld ~= false
        end, function(value)
            SetFlag("flywheelWorld", value)
        end)
        api:Dropdown("Wheel modifier", {
            { value = "NONE", text = "Double-click" },
            { value = "SHIFT", text = "Shift + double-click" },
            { value = "ALT", text = "Alt + double-click" },
            { value = "CTRL", text = "Ctrl + double-click" },
        }, function()
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
        end, "Hold that key and double-click a unit or the ground. Outside combat.")

        api:Header("Expand Direction")
        api:Dropdown("Grow", {
            { value = "AUTO", text = "Auto (Screen Position)" },
            { value = "UP", text = "Always Expand Up" },
            { value = "DOWN", text = "Always Expand Down" },
        }, function()
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
        end, "Auto grows toward the middle of the screen.")

        api:Header("Size")
        api:Slider("Size", 60, 160, 5, function()
            return math.floor((((XMB.db and XMB.db.scale) or 1) * 100) + 0.5)
        end, function(value)
            if XMB.SetDBValue then
                XMB:SetDBValue("scale", value / 100)
            end
        end, "60% to 160%.")

        api:ButtonGroup({
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
                        if XMB.UnlockFrames then
                            XMB:UnlockFrames()
                        end
                        if Lib.RefreshPage then
                            Lib:RefreshPage()
                        end
                    end,
                },
            },
        })
    end,
})
