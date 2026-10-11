--[[
    Xius Marks Bar - Config.lua
    Defaults, saved variables, options panel, and slash commands.
]]

local ADDON, XMB = ...
_G.XiusMarksBar = XMB

XMB.ADDON = ADDON
XMB.TITLE = "Xius Marks Bar"
XMB.DB_VERSION = 1

XMB.defaults = {
    dbVersion = 1,
    isLocked = false,
    showTooltips = true,
    onlyInGroup = false,
    showCountdown = true,
    showReady = true,
    showRole = true,
    showTarget = false,
    showWorld = false,
    growthDirection = "AUTO",
    scale = 1,
}

local optionWidgets = {}
local optionsCategory
local optionsPanel
local syncingOptions = false

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then
        dst = {}
    end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function XMB:GetDB()
    return self.db
end

function XMB:InitDB()
    XiusMarksBarDB = CopyDefaults(self.defaults, XiusMarksBarDB)
    self.db = XiusMarksBarDB
    local db = self.db

    if db.growthDirection ~= "UP" and db.growthDirection ~= "DOWN" then
        db.growthDirection = "AUTO"
    end
    if type(db.scale) ~= "number" then
        db.scale = 1
    end
    if db.scale < 0.6 then
        db.scale = 0.6
    end
    if db.scale > 1.6 then
        db.scale = 1.6
    end
    db.dbVersion = self.DB_VERSION
end

function XMB:NotifySettingsChanged()
    if self.ApplySettings then
        self:ApplySettings()
    end
end

function XMB:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffe6c866Xius Marks Bar|r: " .. tostring(msg))
end

local function SetDBValue(key, value)
    local db = XMB.db
    if not db then
        return
    end
    db[key] = value
    XMB:NotifySettingsChanged()
end

local function MakeCheck(parent, label, key, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetHitRectInsets(0, -420, 0, 0)
    local text = cb.Text or cb.text
    if not text then
        text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        cb.Text = text
    end
    text:ClearAllPoints()
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)
    cb:SetScript("OnClick", function(self)
        if syncingOptions then
            return
        end
        SetDBValue(key, self:GetChecked() and true or false)
    end)
    optionWidgets[key] = cb
    return cb
end

local function MakeLabel(parent, text, template, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function SyncOptionsPanel()
    local db = XMB.db
    if not db then
        return
    end
    syncingOptions = true
    for key, widget in pairs(optionWidgets) do
        if key == "growthDirection" then
            local labels = {
                AUTO = "Auto (Screen Position)",
                UP = "Always Expand Up",
                DOWN = "Always Expand Down",
            }
            widget:SetText(labels[db.growthDirection or "AUTO"] or labels.AUTO)
        elseif key == "scale" then
            local pct = math.floor((db.scale or 1) * 100 + 0.5)
            widget:SetValue(pct)
            local label = _G[widget:GetName() .. "Text"]
            if label then
                label:SetText("Size: " .. pct .. "%")
            end
        elseif widget:IsObjectType("CheckButton") then
            widget:SetChecked(db[key] and true or false)
        end
    end
    syncingOptions = false
end

function XMB:CreateOptions()
    if optionsPanel then
        return
    end

    local panel = CreateFrame("Frame")
    panel.name = XMB.TITLE
    optionsPanel = panel

    local y = -16
    MakeLabel(panel, "Xius Marks Bar", "GameFontNormalLarge", 16, y)
    y = y - 28
    local sub = MakeLabel(
        panel,
        "Compact bar for target marks, world marks, pull timers, ready check, and role check. Click the flag for world marks. Click the star for target marks. Drag the grip after the R button to move the bar.",
        "GameFontHighlightSmall",
        16,
        y
    )
    sub:SetWidth(520)
    sub:SetJustifyH("LEFT")
    sub:SetWordWrap(true)
    y = y - 48

    MakeLabel(panel, "Bar", "GameFontNormal", 16, y)
    y = y - 26
    MakeCheck(panel, "Lock bar (blocks dragging)", "isLocked", 12, y)
    y = y - 28
    MakeCheck(panel, "Only show in a group or instance", "onlyInGroup", 12, y)
    y = y - 28
    MakeCheck(panel, "Show tooltips", "showTooltips", 12, y)

    y = y - 36
    MakeLabel(panel, "Always On The Bar", "GameFontNormal", 16, y)
    y = y - 26
    MakeCheck(panel, "Pull timers (5, 10, 20)", "showCountdown", 12, y)
    y = y - 28
    MakeCheck(panel, "Ready check", "showReady", 12, y)
    y = y - 28
    MakeCheck(panel, "Role check", "showRole", 12, y)

    y = y - 36
    MakeLabel(panel, "Expand Direction", "GameFontNormal", 16, y)
    y = y - 24
    local growthLabels = {
        AUTO = "Auto (Screen Position)",
        UP = "Always Expand Up",
        DOWN = "Always Expand Down",
    }
    local growthOrder = { "AUTO", "UP", "DOWN" }
    local growthBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    growthBtn:SetSize(220, 24)
    growthBtn:SetPoint("TOPLEFT", 16, y)
    optionWidgets.growthDirection = growthBtn
    local function GrowthLabel()
        local mode = XMB.db and XMB.db.growthDirection or "AUTO"
        return growthLabels[mode] or growthLabels.AUTO
    end
    growthBtn:SetText(GrowthLabel())
    growthBtn:SetScript("OnClick", function()
        if syncingOptions or not XMB.db then
            return
        end
        local current = XMB.db.growthDirection or "AUTO"
        local nextMode = "AUTO"
        for i = 1, #growthOrder do
            if growthOrder[i] == current then
                nextMode = growthOrder[(i % #growthOrder) + 1]
                break
            end
        end
        SetDBValue("growthDirection", nextMode)
        growthBtn:SetText(GrowthLabel())
    end)
    local growthHint = MakeLabel(panel, "Click to cycle. Auto grows toward the middle of the screen.", "GameFontHighlightSmall", 246, y + 4)
    growthHint:SetWidth(280)

    y = y - 40
    MakeLabel(panel, "Size", "GameFontNormal", 16, y)
    y = y - 36
    local scale = CreateFrame("Slider", "XiusMarksBar_ScaleSlider", panel, "OptionsSliderTemplate")
    scale:SetPoint("TOPLEFT", 20, y)
    scale:SetWidth(220)
    scale:SetMinMaxValues(60, 160)
    scale:SetValueStep(5)
    scale:SetObeyStepOnDrag(true)
    scale:SetValue(100)
    optionWidgets.scale = scale
    local scaleName = scale:GetName()
    if _G[scaleName .. "Low"] then
        _G[scaleName .. "Low"]:SetText("60%")
    end
    if _G[scaleName .. "High"] then
        _G[scaleName .. "High"]:SetText("160%")
    end
    if _G[scaleName .. "Text"] then
        _G[scaleName .. "Text"]:SetText("Size: 100%")
    end
    scale:SetScript("OnValueChanged", function(self, value)
        if syncingOptions or not XMB.db then
            return
        end
        local pct = math.floor((value or 100) + 0.5)
        if pct < 60 then
            pct = 60
        end
        if pct > 160 then
            pct = 160
        end
        local label = _G[self:GetName() .. "Text"]
        if label then
            label:SetText("Size: " .. pct .. "%")
        end
        local newScale = pct / 100
        if math.abs((XMB.db.scale or 1) - newScale) < 0.001 then
            return
        end
        XMB.db.scale = newScale
        XMB:NotifySettingsChanged()
    end)

    y = y - 36
    local resetPos = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetPos:SetSize(160, 24)
    resetPos:SetPoint("TOPLEFT", 16, y)
    resetPos:SetText("Reset Position")
    resetPos:SetScript("OnClick", function()
        if XMB.ResetPosition then
            XMB:ResetPosition()
        end
    end)

    local collapse = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    collapse:SetSize(160, 24)
    collapse:SetPoint("LEFT", resetPos, "RIGHT", 8, 0)
    collapse:SetText("Collapse Marks")
    collapse:SetScript("OnClick", function()
        if XMB.SetRows then
            XMB:SetRows(false, false)
        end
    end)

    panel:SetScript("OnShow", SyncOptionsPanel)

    optionsCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(optionsCategory)
end

function XMB:OpenOptions()
    if InCombatLockdown() then
        self:Print("Leave combat to open options.")
        return
    end
    self:CreateOptions()
    Settings.OpenToCategory(optionsCategory:GetID())
end

function XMB:HandleSlash(msg)
    if not self.db then
        self:InitDB()
    end
    msg = (msg or ""):match("^%s*(.-)%s*$") or ""
    msg = string.lower(msg)
    if msg == "config" or msg == "opt" or msg == "options" or msg == "settings" then
        self:OpenOptions()
    elseif msg == "lock" then
        self.db.isLocked = true
        self:NotifySettingsChanged()
        self:Print("Bar locked.")
    elseif msg == "unlock" then
        self.db.isLocked = false
        self:NotifySettingsChanged()
        self:Print("Bar unlocked. Drag the grip after the R button to move it.")
    elseif msg == "reset" then
        if self.ResetPosition then
            self:ResetPosition()
        end
    elseif msg == "show" then
        if self.SetRows then
            self:SetRows(true, false)
        end
    elseif msg == "hide" then
        if self.SetRows then
            self:SetRows(false, false)
        end
    else
        self:Print("Click the flag for world marks. Click the star for target marks.")
        self:Print("Commands: /xmb config  |  /xmb lock  |  /xmb unlock  |  /xmb reset  |  /xmb show  |  /xmb hide")
    end
end

SLASH_XIUSMARKSBAR1 = "/xmb"
SLASH_XIUSMARKSBAR2 = "/xiusmarks"
SlashCmdList.XIUSMARKSBAR = function(msg)
    XMB:HandleSlash(msg)
end
