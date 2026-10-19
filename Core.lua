--[[
    Xius Marks Bar - Core.lua
    Compact raid marking bar for World of Warcraft Forever.
    Flag opens world marks, star opens target marks.
    Pull timers, ready check, and role check stay on the bar.
]]

local ADDON, XMB = ...

local PAD = 3
local HEADER_H = 20
local BTN = 20
local GAP = 2
local GROUP_GAP = 5
local ROW_GAP = 5
local GRIP_W = 8
local NUM_W = 20
local RC_W = 26
local ROLE_W = 20
local COLLAPSED_H = PAD + HEADER_H + PAD
local ROW_W = (9 * BTN) + (8 * GAP)

local COLOR = {
    cardBg = { 0.015, 0.015, 0.015, 0.78 },
    cardEdge = { 0.22, 0.19, 0.13, 0.70 },
    rule = { 0.45, 0.36, 0.16, 0.60 },
    btnTop = { 0.075, 0.068, 0.058, 0.95 },
    btnBottom = { 0.025, 0.025, 0.025, 0.95 },
    btnTopHot = { 0.13, 0.11, 0.07, 1 },
    btnBottomHot = { 0.04, 0.035, 0.03, 1 },
    btnTopOn = { 0.20, 0.16, 0.07, 1 },
    btnBottomOn = { 0.07, 0.055, 0.03, 1 },
    btnEdge = { 0.40, 0.32, 0.15, 0.90 },
    btnEdgeHot = { 0.72, 0.58, 0.24, 1 },
    btnEdgeOn = { 0.85, 0.68, 0.26, 1 },
    gold = { 0.92, 0.76, 0.28 },
    text = { 0.86, 0.72, 0.32 },
    good = { 0.45, 0.78, 0.45 },
    role = { 0.50, 0.68, 0.88 },
    grip = { 0.40, 0.32, 0.15, 0.85 },
    gripLocked = { 0.38, 0.24, 0.20, 0.7 },
    iconAlpha = 0.88,
}

local MARK_TEXTURES = {}
for i = 1, 8 do
    MARK_TEXTURES[i] = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i
end

local MARK_NAMES = {
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
local WORLD_ICON = { 6, 4, 3, 7, 1, 2, 5, 8 }
local WORLD_NAMES = {
    "Blue Square",
    "Green Triangle",
    "Purple Diamond",
    "Red Cross",
    "Yellow Star",
    "Orange Circle",
    "Silver Moon",
    "White Skull",
}

local PULL_TIMES = { 5, 10, 20 }

local pullSerial = 0
local layoutQueued = false

-- WoW lowercases attribute names before OnAttributeChanged sees them.
local HOST_SNIPPET = [[
if name ~= "panel" and name ~= "relayout" then
  return
end
local trow = self:GetFrameRef("trow")
local wrow = self:GetFrameRef("wrow")
if not trow or not wrow then
  return
end
local pad = self:GetAttribute("pad") or 5
local headerH = self:GetAttribute("headerh") or 22
local rowH = self:GetAttribute("rowh") or 22
local gap = self:GetAttribute("rowgap") or 4
local up = self:GetAttribute("growup") == 1
local panel = self:GetAttribute("panel") or 0
local showT = panel == 1
local showW = panel == 2
local y = pad + headerH
if showT then
  y = y + gap
  trow:ClearAllPoints()
  if up then
    trow:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", pad, y)
  else
    trow:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -y)
  end
  y = y + rowH
  trow:Show()
else
  trow:Hide()
end
if showW then
  y = y + gap
  wrow:ClearAllPoints()
  if up then
    wrow:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", pad, y)
  else
    wrow:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -y)
  end
  y = y + rowH
  wrow:Show()
else
  wrow:Hide()
end
self:SetHeight(y + pad)
]]

local TOGGLE_TARGET = [[
local host = self:GetFrameRef("host")
if not host then
  return
end
if host:GetAttribute("panel") == 1 then
  host:SetAttribute("panel", 0)
else
  host:SetAttribute("panel", 1)
end
]]

local TOGGLE_WORLD = [[
local host = self:GetFrameRef("host")
if not host then
  return
end
if host:GetAttribute("panel") == 2 then
  host:SetAttribute("panel", 0)
else
  host:SetAttribute("panel", 2)
end
]]

local fontPath

local function SetFont(fs, size)
    if not fontPath and GameFontNormal then
        fontPath = GameFontNormal:GetFont()
    end
    if fontPath then
        fs:SetFont(fontPath, size, "OUTLINE")
    end
end

local function MakeEdges(frame, layer, r, g, b, a)
    local edges = {}
    local specs = {
        { "TOPLEFT", "TOPRIGHT", true },
        { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT", false },
        { "TOPRIGHT", "BOTTOMRIGHT", false },
    }
    for i = 1, 4 do
        local spec = specs[i]
        local t = frame:CreateTexture(nil, layer)
        t:SetColorTexture(r, g, b, a)
        t:SetPoint(spec[1], frame, spec[1], 0, 0)
        t:SetPoint(spec[2], frame, spec[2], 0, 0)
        if spec[3] then
            t:SetHeight(1)
        else
            t:SetWidth(1)
        end
        edges[i] = t
    end
    return edges
end

local function PaintEdges(edges, c)
    for i = 1, #edges do
        edges[i]:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    end
end

local gradientPairs

local function SetVerticalGradient(tex, top, bottom)
    if not gradientPairs then
        gradientPairs = {}
    end
    local pair = gradientPairs[top]
    if not pair then
        pair = {
            CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1),
            CreateColor(top[1], top[2], top[3], top[4] or 1),
        }
        gradientPairs[top] = pair
    end
    tex:SetGradient("VERTICAL", pair[1], pair[2])
end

-- Gold edges stop one pixel short of each corner so the frame reads as rounded.
local function MakeRoundedEdges(frame, layer)
    local edges = {}
    local top = frame:CreateTexture(nil, layer)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, 0)
    top:SetHeight(1)
    local bottom = frame:CreateTexture(nil, layer)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 0)
    bottom:SetHeight(1)
    local left = frame:CreateTexture(nil, layer)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 1)
    left:SetWidth(1)
    local right = frame:CreateTexture(nil, layer)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -1)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 1)
    right:SetWidth(1)
    edges[1], edges[2], edges[3], edges[4] = top, bottom, left, right
    return edges
end

local function PaintButton(btn)
    local state = 0
    if btn.isOn then
        state = 2
    elseif btn.isHot then
        state = 1
    end
    if btn.paintState == state then
        return
    end
    btn.paintState = state
    local top, bottom, edge = COLOR.btnTop, COLOR.btnBottom, COLOR.btnEdge
    if state == 2 then
        top, bottom, edge = COLOR.btnTopOn, COLOR.btnBottomOn, COLOR.btnEdgeOn
    elseif state == 1 then
        top, bottom, edge = COLOR.btnTopHot, COLOR.btnBottomHot, COLOR.btnEdgeHot
    end
    SetVerticalGradient(btn.fill, top, bottom)
    PaintEdges(btn.edges, edge)
end

local function SkinButton(btn)
    local fill = btn:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)
    fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    btn.fill = fill

    local inner = MakeEdges(btn, "BORDER", 0, 0, 0, 0.55)
    for i = 1, 4 do
        inner[i]:ClearAllPoints()
    end
    inner[1]:SetPoint("TOPLEFT", 1, -1)
    inner[1]:SetPoint("TOPRIGHT", -1, -1)
    inner[2]:SetPoint("BOTTOMLEFT", 1, 1)
    inner[2]:SetPoint("BOTTOMRIGHT", -1, 1)
    inner[3]:SetPoint("TOPLEFT", 1, -1)
    inner[3]:SetPoint("BOTTOMLEFT", 1, 1)
    inner[4]:SetPoint("TOPRIGHT", -1, -1)
    inner[4]:SetPoint("BOTTOMRIGHT", -1, 1)

    btn.edges = MakeRoundedEdges(btn, "ARTWORK")

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 2, -2)
    hl:SetPoint("BOTTOMRIGHT", -2, 2)
    hl:SetColorTexture(1, 0.85, 0.45, 0.06)

    PaintButton(btn)
end

local function ShowTip(owner, title, line)
    if not XMB.db or not XMB.db.showTooltips then
        return
    end
    local host = XMB.host
    if host then
        GameTooltip:SetOwner(owner, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        if XMB.growUp then
            GameTooltip:SetPoint("BOTTOMLEFT", host, "TOPLEFT", 0, 4)
        else
            GameTooltip:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, -4)
        end
    else
        GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    end
    GameTooltip:SetText(title, COLOR.gold[1], COLOR.gold[2], COLOR.gold[3])
    if line then
        GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true)
    end
    GameTooltip:Show()
end

local function HideTip()
    GameTooltip:Hide()
end

-- One shared enter/leave pair for every skinned button (avoids dozens of closures).
local function HoverEnter(self)
    self.isHot = true
    PaintButton(self)
    if self.icon then
        self.icon:SetAlpha(1)
    end
    ShowTip(self, self.tipTitle, self.tipLine)
end

local function HoverLeave(self)
    self.isHot = false
    PaintButton(self)
    if self.icon then
        self.icon:SetAlpha(COLOR.iconAlpha)
    end
    HideTip()
end

local function BindHover(btn, title, line)
    btn.tipTitle = title
    btn.tipLine = line
    btn:SetScript("OnEnter", HoverEnter)
    btn:SetScript("OnLeave", HoverLeave)
end

local function MakeButton(parent, name, template, width)
    local btn = CreateFrame("Button", name, parent, template)
    btn:SetSize(width or BTN, BTN)
    SkinButton(btn)
    return btn
end

local function AddLabel(btn, text, color)
    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("CENTER", 1, 0)
    SetFont(fs, 10)
    fs:SetText(text)
    fs:SetTextColor(color[1], color[2], color[3], 1)
    btn.label = fs
    return fs
end

local function AddIcon(btn, texture, size)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(size or (BTN - 6), size or (BTN - 6))
    icon:SetTexture(texture)
    icon:SetAlpha(COLOR.iconAlpha)
    btn.icon = icon
    return icon
end

local function Say(msg)
    local channel
    if IsInRaid() and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        channel = "RAID_WARNING"
    elseif IsInRaid() then
        channel = "RAID"
    elseif IsInGroup() then
        channel = "PARTY"
    end
    if channel then
        local ok = pcall(SendChatMessage, msg, channel)
        if ok then
            return
        end
    end
    XMB:Print(msg)
end

local pullTicker

local function DoPull(seconds)
    pullSerial = pullSerial + 1
    local serial = pullSerial
    if pullTicker then
        pullTicker:Cancel()
        pullTicker = nil
    end
    if C_PartyInfo and C_PartyInfo.DoCountdown then
        local ok = pcall(C_PartyInfo.DoCountdown, seconds)
        if ok then
            return
        end
    end
    Say(string.format("Pull in %d", seconds))
    if not C_Timer.NewTicker then
        for step = 1, seconds do
            local stepElapsed = step
            C_Timer.After(stepElapsed, function()
                if serial ~= pullSerial then
                    return
                end
                local left = seconds - stepElapsed
                if left <= 0 then
                    Say("GO!")
                else
                    Say(tostring(left))
                end
            end)
        end
        return
    end
    local elapsed = 0
    pullTicker = C_Timer.NewTicker(1, function(ticker)
        if serial ~= pullSerial then
            if pullTicker == ticker then
                pullTicker = nil
            end
            ticker:Cancel()
            return
        end
        elapsed = elapsed + 1
        local left = seconds - elapsed
        if left > 0 then
            Say(tostring(left))
            return
        end
        Say("GO!")
        if pullTicker == ticker then
            pullTicker = nil
        end
        ticker:Cancel()
    end, seconds)
end

function XMB:ResolveGrowUp()
    local db = self.db
    local mode = db and db.growthDirection or "AUTO"
    if mode == "UP" then
        return true
    end
    if mode == "DOWN" then
        return false
    end
    if db and db.headerBottom and db.headerTop then
        local mid = (db.headerBottom + db.headerTop) / 2
        return mid < (UIParent:GetHeight() * 0.5)
    end
    return true
end

function XMB:EnsurePosition()
    local db, host = self.db, self.host
    if db.headerLeft and db.headerBottom and db.headerTop then
        return
    end
    local s = host:GetScale() or 1
    local w = (host:GetWidth() or 300) * s
    db.headerLeft = math.floor((UIParent:GetWidth() - w) / 2 + 0.5)
    db.headerBottom = 200
    db.headerTop = db.headerBottom + COLLAPSED_H * s
end

local function SnapToPixel(value, scale, pixel)
    return math.floor((value / scale) / pixel + 0.5) * pixel
end

local function ScreenPixel(host)
    local pixel = 1
    local _, physH = GetPhysicalScreenSize()
    local eff = host:GetEffectiveScale()
    if physH and physH > 0 and eff and eff > 0 then
        pixel = 768 / physH / eff
    end
    return pixel
end

function XMB:RestorePosition()
    local db, host = self.db, self.host
    if not db or not host then
        return
    end
    self:EnsurePosition()
    local scale = host:GetScale() or 1
    local pixel = ScreenPixel(host)
    host:ClearAllPoints()
    if self.growUp then
        host:SetPoint(
            "BOTTOMLEFT", UIParent, "BOTTOMLEFT",
            SnapToPixel(db.headerLeft, scale, pixel),
            SnapToPixel(db.headerBottom, scale, pixel)
        )
    else
        host:SetPoint(
            "TOPLEFT", UIParent, "BOTTOMLEFT",
            SnapToPixel(db.headerLeft, scale, pixel),
            SnapToPixel(db.headerTop, scale, pixel)
        )
    end
    self.positionApplied = true
    self.positionDirty = nil
end

function XMB:SavePosition()
    local db, host = self.db, self.host
    if not db or not host then
        return
    end
    local s = host:GetScale() or 1
    local left, bottom, top = host:GetLeft(), host:GetBottom(), host:GetTop()
    if not left or not bottom or not top then
        return
    end
    db.headerLeft = left * s
    if self.growUp then
        db.headerBottom = bottom * s
        db.headerTop = db.headerBottom + COLLAPSED_H * s
    else
        db.headerTop = top * s
        db.headerBottom = db.headerTop - COLLAPSED_H * s
    end
end

function XMB:PlaceHeader(btn, x, h)
    btn:ClearAllPoints()
    local y = PAD + math.floor((HEADER_H - h) / 2)
    if self.growUp then
        btn:SetPoint("BOTTOMLEFT", self.host, "BOTTOMLEFT", x, y)
    else
        btn:SetPoint("TOPLEFT", self.host, "TOPLEFT", x, -y)
    end
end

function XMB:UpdateActive()
    local showT = (self.targetRow and self.targetRow:IsShown()) and true or false
    local showW = (self.worldRow and self.worldRow:IsShown()) and true or false
    if showT == self.lastShowT and showW == self.lastShowW then
        return
    end
    self.lastShowT = showT
    self.lastShowW = showW
    if self.star then
        self.star.isOn = showT
        PaintButton(self.star)
    end
    if self.flag then
        self.flag.isOn = showW
        PaintButton(self.flag)
    end
    if self.rule then
        self.rule:SetShown(showT or showW)
    end
    if self.db then
        self.db.showTarget = showT
        self.db.showWorld = showW
    end
end

function XMB:UpdateGrip()
    local grip = self.grip
    if not grip then
        return
    end
    local locked = (self.db and self.db.isLocked) and true or false
    if grip.paintLocked == locked then
        return
    end
    grip.paintLocked = locked
    local c = locked and COLOR.gripLocked or COLOR.grip
    grip.b1:SetColorTexture(c[1], c[2], c[3], c[4])
    grip.b2:SetColorTexture(c[1], c[2], c[3], c[4])
end

function XMB:RequestLayout()
    if layoutQueued then
        return
    end
    layoutQueued = true
    C_Timer.After(0, function()
        layoutQueued = false
        if not XMB.host then
            return
        end
        if InCombatLockdown() then
            XMB.pendingLayout = true
            return
        end
        XMB:Layout()
    end)
end

function XMB:Layout()
    if InCombatLockdown() then
        self.pendingLayout = true
        return
    end
    local host, db = self.host, self.db
    if not host or not db then
        return
    end

    local growUp = self:ResolveGrowUp()
    local growChanged = (self.growUp ~= growUp)
    self.growUp = growUp

    local headerSig = (growUp and 1 or 0)
        + (db.showCountdown and 2 or 0)
        + (db.showReady and 4 or 0)
        + (db.showRole and 8 or 0)

    if headerSig ~= self.headerSig then
        local x = PAD
        self:PlaceHeader(self.flag, x, BTN)
        x = x + BTN + GAP
        self:PlaceHeader(self.star, x, BTN)
        x = x + BTN

        local anyUtil = db.showCountdown or db.showReady or db.showRole
        if anyUtil then
            x = x + GROUP_GAP
        end

        local placed = false
        for i = 1, #self.pulls do
            local btn = self.pulls[i]
            btn:SetShown(db.showCountdown and true or false)
            if db.showCountdown then
                if placed then
                    x = x + GAP
                end
                self:PlaceHeader(btn, x, BTN)
                x = x + NUM_W
                placed = true
            end
        end

        self.ready:SetShown(db.showReady and true or false)
        if db.showReady then
            if placed then
                x = x + GAP
            end
            self:PlaceHeader(self.ready, x, BTN)
            x = x + RC_W
            placed = true
        end

        self.role:SetShown(db.showRole and true or false)
        if db.showRole then
            if placed then
                x = x + GAP
            end
            self:PlaceHeader(self.role, x, BTN)
            x = x + ROLE_W
        end

        x = x + GAP
        self:PlaceHeader(self.grip, x, HEADER_H)
        x = x + GRIP_W

        local headerW = x - PAD
        host:SetWidth(PAD + math.max(headerW, ROW_W) + PAD)

        local ruleY = PAD + HEADER_H + math.floor(ROW_GAP / 2)
        self.rule:ClearAllPoints()
        if growUp then
            self.rule:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", PAD, ruleY)
            self.rule:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -PAD, ruleY)
        else
            self.rule:SetPoint("TOPLEFT", host, "TOPLEFT", PAD, -ruleY)
            self.rule:SetPoint("TOPRIGHT", host, "TOPRIGHT", -PAD, -ruleY)
        end
        self.rule:SetHeight(1)

        self.headerSig = headerSig
    end

    -- Mark rows are anchored by the secure handler. Rerun it only when the
    -- grow direction changes. Header toggles and zone changes do not move them.
    if growChanged or not self.rowsReady then
        if growChanged then
            host:SetAttribute("growup", growUp and 1 or 0)
        end
        self.relayoutCount = (self.relayoutCount or 0) + 1
        host:SetAttribute("relayout", self.relayoutCount)
        self.rowsReady = true
    end

    if self.positionDirty or growChanged or not self.positionApplied then
        self:RestorePosition()
    end

    self:UpdateGrip()
    self:UpdateActive()
end

function XMB:ApplyScale()
    if not self.host then
        return
    end
    if InCombatLockdown() then
        self.pendingLayout = true
        return
    end
    local scale = (self.db and self.db.scale) or 1
    local current = self.host:GetScale() or 1
    if math.abs(current - scale) < 0.001 then
        return
    end
    self.host:SetScale(scale)
    if self.positionApplied then
        self:RestorePosition()
    end
end

function XMB:ApplyVisibility()
    if not self.host then
        return
    end
    if InCombatLockdown() then
        self.pendingLayout = true
        return
    end
    local only = (self.db and self.db.onlyInGroup) and true or false
    if only == self.visibilityApplied then
        return
    end
    self.visibilityApplied = only
    if only then
        RegisterStateDriver(self.host, "visibility", "[group][instance] show; hide")
    else
        UnregisterStateDriver(self.host, "visibility")
        self.host:Show()
    end
end

function XMB:ApplySettings()
    if not self.host then
        return
    end
    if InCombatLockdown() then
        self.pendingLayout = true
        self:Print("Saved. The bar will update when combat ends.")
        return
    end
    self:ApplyScale()
    self:ApplyVisibility()
    self:Layout()
end

function XMB:SetRows(showTarget, showWorld)
    if not self.host then
        return
    end
    if InCombatLockdown() then
        self:Print("Leave combat to show or hide the marks from a command.")
        return
    end
    local panel = 0
    if showTarget then
        panel = 1
    elseif showWorld then
        panel = 2
    end
    if self.host:GetAttribute("panel") ~= panel then
        self.host:SetAttribute("panel", panel)
    end
    self:UpdateActive()
end

function XMB:ResetPosition()
    if not self.db or not self.host then
        return
    end
    if InCombatLockdown() then
        self:Print("Leave combat to reset the position.")
        return
    end
    self.db.headerLeft = nil
    self.db.headerBottom = nil
    self.db.headerTop = nil
    self.positionDirty = true
    self:Layout()
    self:Print("Bar moved back above the action bar.")
end

function XMB:StartMove()
    if not self.host then
        return
    end
    if self.db and self.db.isLocked then
        return
    end
    if InCombatLockdown() then
        self:Print("You can't move the bar in combat.")
        return
    end
    self.moving = true
    self.host:StartMoving()
end

function XMB:StopMove()
    if not self.host or not self.moving then
        return
    end
    self.moving = false
    self.host:StopMovingOrSizing()
    self.host:SetUserPlaced(false)
    HideTip()
    self:SavePosition()
    self.positionDirty = true
    if InCombatLockdown() then
        self.pendingLayout = true
        return
    end
    self:Layout()
end

function XMB:CreateUI()
    local db = self.db

    local host = CreateFrame("Frame", "XiusMarksBarFrame", UIParent, "SecureHandlerAttributeTemplate")
    host:SetSize(300, COLLAPSED_H)
    host:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200)
    host:SetFrameStrata("MEDIUM")
    host:SetFrameLevel(20)
    host:SetClampedToScreen(true)
    host:SetMovable(true)
    host:EnableMouse(false)
    self.host = host

    local bg = host:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(COLOR.cardBg[1], COLOR.cardBg[2], COLOR.cardBg[3], COLOR.cardBg[4])
    MakeEdges(host, "BORDER", COLOR.cardEdge[1], COLOR.cardEdge[2], COLOR.cardEdge[3], COLOR.cardEdge[4])

    local rule = host:CreateTexture(nil, "BORDER")
    rule:SetColorTexture(COLOR.rule[1], COLOR.rule[2], COLOR.rule[3], COLOR.rule[4])
    rule:Hide()
    self.rule = rule

    local flag = MakeButton(host, "XiusMB_Flag", "SecureHandlerClickTemplate")
    AddIcon(flag, "Interface\\Icons\\INV_BannerPVP_02", BTN - 6)
    flag.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    flag:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    flag:SetFrameRef("host", host)
    flag:SetAttribute("_onclick", [[
if button == "RightButton" then
  return
end
]] .. TOGGLE_WORLD)
    -- HookScript keeps SecureHandlerClickTemplate's OnClick intact.
    flag:HookScript("OnClick", function(_, button)
        if button == "RightButton" then
            XMB:OpenOptions()
        end
    end)
    BindHover(flag, "World marks", "Click to show or hide ground markers. Right-click for options.")
    self.flag = flag

    local star = MakeButton(host, "XiusMB_Star", "SecureHandlerClickTemplate")
    AddIcon(star, MARK_TEXTURES[1], BTN - 6)
    star:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    star:SetFrameRef("host", host)
    star:SetAttribute("_onclick", [[
if button == "RightButton" then
  return
end
]] .. TOGGLE_TARGET)
    star:HookScript("OnClick", function(_, button)
        if button == "RightButton" then
            XMB:OpenOptions()
        end
    end)
    BindHover(star, "Target marks", "Click to show or hide target markers. Right-click for options.")
    self.star = star

    self.pulls = {}
    for i = 1, #PULL_TIMES do
        local sec = PULL_TIMES[i]
        local btn = MakeButton(host, nil, nil, NUM_W)
        AddLabel(btn, tostring(sec), COLOR.text)
        btn:RegisterForClicks("LeftButtonUp")
        btn:SetScript("OnClick", function()
            DoPull(sec)
        end)
        BindHover(btn, "Pull in " .. sec .. " seconds", "Starts a countdown for the group.")
        self.pulls[#self.pulls + 1] = btn
    end

    local ready = MakeButton(host, "XiusMB_Ready", "SecureActionButtonTemplate", RC_W)
    AddLabel(ready, "RC", COLOR.good)
    ready:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    ready:SetAttribute("type", "macro")
    ready:SetAttribute("macrotext", "/readycheck")
    ready:SetAttribute("type1", "macro")
    ready:SetAttribute("macrotext1", "/readycheck")
    BindHover(ready, "Ready check", "Asks the group if they are ready. Leader or assistant only.")
    self.ready = ready

    local role = MakeButton(host, nil, nil, ROLE_W)
    AddLabel(role, "R", COLOR.role)
    role:RegisterForClicks("LeftButtonUp")
    role:SetScript("OnClick", function()
        if InitiateRolePoll then
            pcall(InitiateRolePoll)
        else
            XMB:Print("Role check is not available right now.")
        end
    end)
    BindHover(role, "Role check", "Asks everyone to pick a role.")
    self.role = role

    local grip = CreateFrame("Button", nil, host)
    grip:SetSize(GRIP_W, HEADER_H)
    local function GripBar(xOff)
        local t = grip:CreateTexture(nil, "ARTWORK")
        t:SetSize(1, 12)
        t:SetPoint("CENTER", grip, "CENTER", xOff, 0)
        return t
    end
    grip.b1 = GripBar(-1)
    grip.b2 = GripBar(2)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function()
        XMB:StartMove()
    end)
    grip:SetScript("OnDragStop", function()
        XMB:StopMove()
    end)
    grip:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            XMB:OpenOptions()
        end
    end)
    grip:SetScript("OnEnter", function(self)
        if XMB.db and XMB.db.isLocked then
            ShowTip(self, "Locked", "Unlock with /xmb unlock or in the options.")
        else
            ShowTip(self, "Move", "Drag to move the bar. Right-click for options.")
            self.paintLocked = nil
            self.b1:SetColorTexture(COLOR.gold[1], COLOR.gold[2], COLOR.gold[3], 1)
            self.b2:SetColorTexture(COLOR.gold[1], COLOR.gold[2], COLOR.gold[3], 1)
        end
    end)
    grip:SetScript("OnLeave", function()
        HideTip()
        XMB:UpdateGrip()
    end)
    self.grip = grip

    local function RowActiveChanged()
        XMB:UpdateActive()
    end

    local function MakeRow(name)
        local row = CreateFrame("Frame", name, host)
        row:SetSize(ROW_W, BTN)
        row:EnableMouse(false)
        row:Hide()
        row:SetScript("OnShow", RowActiveChanged)
        row:SetScript("OnHide", RowActiveChanged)
        return row
    end

    local targetRow = MakeRow("XiusMB_TargetRow")
    local worldRow = MakeRow("XiusMB_WorldRow")
    self.targetRow = targetRow
    self.worldRow = worldRow

    local function PlaceInRow(row, btn, index)
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", row, "LEFT", (index - 1) * (BTN + GAP), 0)
    end

    -- Target marks must use SecureActionButton macros: SetRaidTarget() is protected
    -- on this client. No empty [] fallback (avoids marking the wrong unit).
    -- No pressAndHoldAction (avoids down+up double fire).
    local clearTargetMacro = "/tm [@target,exists] 0"
    for i = 1, 8 do
        local btn = MakeButton(targetRow, "XiusMB_TM" .. i, "SecureActionButtonTemplate")
        local macro = "/tm [@target,exists,nodead] " .. i
        btn:RegisterForClicks("AnyUp", "AnyDown")
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", macro)
        btn:SetAttribute("type1", "macro")
        btn:SetAttribute("macrotext1", macro)
        btn:SetAttribute("type2", "macro")
        btn:SetAttribute("macrotext2", clearTargetMacro)
        AddIcon(btn, MARK_TEXTURES[i])
        PlaceInRow(targetRow, btn, i)
        BindHover(btn, MARK_NAMES[i], "Left click marks your target. Right click clears it.")
    end

    local clearTarget = MakeButton(targetRow, "XiusMB_TClear", "SecureActionButtonTemplate")
    clearTarget:RegisterForClicks("AnyUp", "AnyDown")
    clearTarget:SetAttribute("type", "macro")
    clearTarget:SetAttribute("macrotext", clearTargetMacro)
    clearTarget:SetAttribute("type1", "macro")
    clearTarget:SetAttribute("macrotext1", clearTargetMacro)
    AddIcon(clearTarget, "Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    PlaceInRow(targetRow, clearTarget, 9)
    BindHover(clearTarget, "Clear target mark", "Removes the mark from your current target.")

    -- World marks stay secure. No pressAndHoldAction (that fires on down and up).
    -- Left toggles the flare; right clears that flare only.
    for i = 1, 8 do
        local btn = MakeButton(worldRow, "XiusMB_WM" .. i, "SecureActionButtonTemplate")
        btn:RegisterForClicks("AnyUp", "AnyDown")
        btn:SetAttribute("type", "worldmarker")
        btn:SetAttribute("type1", "worldmarker")
        btn:SetAttribute("type2", "worldmarker")
        btn:SetAttribute("marker", i)
        btn:SetAttribute("marker1", i)
        btn:SetAttribute("marker2", i)
        btn:SetAttribute("action", "toggle")
        btn:SetAttribute("action1", "toggle")
        btn:SetAttribute("action2", "clear")
        AddIcon(btn, MARK_TEXTURES[WORLD_ICON[i]])
        local flare = btn:CreateTexture(nil, "OVERLAY")
        flare:SetTexture("Interface\\RaidFrame\\Raid-WorldPing")
        flare:SetSize(10, 10)
        flare:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        PlaceInRow(worldRow, btn, i)
        BindHover(btn, WORLD_NAMES[i], "Left click places or removes the world marker. Right click removes it.")
    end

    local clearWorld = MakeButton(worldRow, "XiusMB_WClear", "SecureActionButtonTemplate")
    clearWorld:RegisterForClicks("AnyUp", "AnyDown")
    clearWorld:SetAttribute("type", "worldmarker")
    clearWorld:SetAttribute("type1", "worldmarker")
    clearWorld:SetAttribute("action", "clear")
    clearWorld:SetAttribute("action1", "clear")
    AddIcon(clearWorld, "Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    PlaceInRow(worldRow, clearWorld, 9)
    BindHover(clearWorld, "Clear world marks", "Removes every world marker.")

    host:SetFrameRef("trow", targetRow)
    host:SetFrameRef("wrow", worldRow)
    self.growUp = self:ResolveGrowUp()
    host:SetAttribute("pad", PAD)
    host:SetAttribute("headerh", HEADER_H)
    host:SetAttribute("rowh", BTN)
    host:SetAttribute("rowgap", ROW_GAP)
    host:SetAttribute("growup", self.growUp and 1 or 0)
    local panel = 0
    if db.showTarget then
        panel = 1
    elseif db.showWorld then
        panel = 2
    end
    host:SetAttribute("panel", panel)
    host:SetAttribute("_onattributechanged", HOST_SNIPPET)

    self:ApplyScale()
    self:ApplyVisibility()
    self:Layout()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        eventFrame:UnregisterEvent("ADDON_LOADED")
        XMB:InitDB()
        local created, err = pcall(function()
            XMB:CreateUI()
            XMB:CreateOptions()
        end)
        if not created then
            XMB:Print("Could not create the bar. " .. tostring(err))
            return
        end
        XMB:Print("Loaded. Click the flag for world marks, the star for target marks. /xmb for options.")
    elseif event == "PLAYER_ENTERING_WORLD" or event == "UI_SCALE_CHANGED" then
        if not XMB.host then
            return
        end
        XMB.positionDirty = true
        XMB:RequestLayout()
    elseif event == "PLAYER_REGEN_ENABLED" and XMB.pendingLayout then
        XMB.pendingLayout = nil
        XMB:ApplyScale()
        XMB:ApplyVisibility()
        XMB:Layout()
    end
end)
