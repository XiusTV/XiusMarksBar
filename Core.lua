--[[
    Xius Marks Bar - Core.lua
    Compact raid marking bar for modern World of Warcraft and World of Warcraft Forever.
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

local IsSecret = XMB.IsSecret
local IsFiniteNumber = XMB.IsFiniteNumber
local MARK_TEXTURES = XMB.MARK_TEXTURES
local MARK_NAMES = XMB.MARK_NAMES
local WORLD_ICON = XMB.WORLD_ICON
local WORLD_NAMES = XMB.WORLD_NAMES

local PULL_TIMES = { 5, 10, 20 }

local pullSerial = 0
local activePullSec = nil
local activePullEnd = 0
local layoutQueued = false
local lastWorldNoticeAt = -10

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
    if not fontPath and GameFontNormal and GameFontNormal.GetFont then
        local ok, face = pcall(GameFontNormal.GetFont, GameFontNormal)
        if ok and type(face) == "string" and face ~= "" then
            fontPath = face
        end
    end
    if not fontPath then
        fontPath = "Fonts\\FRIZQT__.TTF"
    end
    pcall(fs.SetFont, fs, fontPath, size, "OUTLINE")
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
    if not tex.SetGradient or not CreateColor then
        tex:SetColorTexture(top[1], top[2], top[3], top[4] or 1)
        return
    end
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
    if not XMB.db or not XMB.db.showTooltips or not GameTooltip then
        return
    end
    local host = XMB.host
    if host then
        pcall(GameTooltip.SetOwner, GameTooltip, owner, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        if XMB.growUp then
            GameTooltip:SetPoint("BOTTOMLEFT", host, "TOPLEFT", 0, 4)
        else
            GameTooltip:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, -4)
        end
    else
        pcall(GameTooltip.SetOwner, GameTooltip, owner, "ANCHOR_TOP")
    end
    GameTooltip:SetText(title, COLOR.gold[1], COLOR.gold[2], COLOR.gold[3])
    if line then
        GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true)
    end
    GameTooltip:Show()
end

local function HideTip()
    if GameTooltip then
        GameTooltip:Hide()
    end
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

local function SafeBool(fn, ...)
    if type(fn) ~= "function" then
        return false
    end
    local ok, val = pcall(fn, ...)
    if not ok or IsSecret(val) then
        return false
    end
    return val and true or false
end

local function TryChannel(msg, channel)
    if not channel then
        return false
    end
    local sendFn = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if type(sendFn) ~= "function" then
        return false
    end
    local ok, sent = pcall(sendFn, msg, channel)
    if not ok then
        return false
    end
    -- A false return means that channel refused the message. nil means it was sent.
    return sent ~= false
end

local function Say(msg)
    local instCat = LE_PARTY_CATEGORY_INSTANCE or 2
    local homeCat = LE_PARTY_CATEGORY_HOME or 1
    local inInstanceGroup = SafeBool(IsInGroup, instCat)
    local inHomeRaid = SafeBool(IsInRaid, homeCat)
    local inAnyRaid = SafeBool(IsInRaid)
    local inHomeGroup = SafeBool(IsInGroup, homeCat)
    local inAnyGroup = SafeBool(IsInGroup)
    local leader = SafeBool(UnitIsGroupLeader, "player") or SafeBool(UnitIsGroupAssistant, "player")

    if inAnyRaid and leader and TryChannel(msg, "RAID_WARNING") then
        return
    end
    if inInstanceGroup and TryChannel(msg, "INSTANCE_CHAT") then
        return
    end
    if inHomeRaid and TryChannel(msg, "RAID") then
        return
    end
    if inHomeGroup and TryChannel(msg, "PARTY") then
        return
    end
    if not inInstanceGroup and inAnyRaid and TryChannel(msg, "RAID") then
        return
    end
    if not inInstanceGroup and inAnyGroup and TryChannel(msg, "PARTY") then
        return
    end
    XMB:Print(msg)
end

function XMB:NotifyWorldMarkerRequirement()
    local now = (GetTime and GetTime()) or 0
    if now - lastWorldNoticeAt < 3 then
        return
    end
    if IsInGroup and not SafeBool(IsInGroup) then
        lastWorldNoticeAt = now
        self:Print("World markers require being in a party or raid.")
        return
    end
    if IsInRaid and SafeBool(IsInRaid) then
        local canMark = SafeBool(UnitIsGroupLeader, "player") or SafeBool(UnitIsGroupAssistant, "player")
        if not canMark then
            lastWorldNoticeAt = now
            self:Print("World markers in a raid require leader or assistant permission.")
        end
    end
end

local pullTicker

local function CancelPull()
    pullSerial = pullSerial + 1
    local hadTicker = pullTicker ~= nil
    if pullTicker then
        pullTicker:Cancel()
        pullTicker = nil
    end
    activePullSec = nil
    activePullEnd = 0
    if C_PartyInfo and C_PartyInfo.DoCountdown then
        local ok = pcall(C_PartyInfo.DoCountdown, 0)
        if ok and not hadTicker then
            return
        end
    end
    if hadTicker then
        Say("Pull cancelled!")
    end
end

local function DoPull(seconds, button)
    local now = (GetTime and GetTime()) or 0
    local isRunning = (pullTicker ~= nil) or (activePullEnd > now)
    if button == "RightButton" or (isRunning and activePullSec == seconds) then
        if isRunning then
            CancelPull()
        end
        return
    end

    pullSerial = pullSerial + 1
    local serial = pullSerial
    if pullTicker then
        pullTicker:Cancel()
        pullTicker = nil
    end
    activePullSec = seconds
    activePullEnd = now + seconds

    local canBlizzCountdown = C_PartyInfo and type(C_PartyInfo.DoCountdown) == "function"
    if canBlizzCountdown and SafeBool(IsInRaid) then
        if not SafeBool(UnitIsGroupLeader, "player") and not SafeBool(UnitIsGroupAssistant, "player") then
            canBlizzCountdown = false
        end
    end
    if canBlizzCountdown then
        local ok, started = pcall(C_PartyInfo.DoCountdown, seconds)
        if ok and started ~= false then
            return
        end
    end

    Say(string.format("Pull in %d", seconds))
    if not C_Timer or not C_Timer.NewTicker then
        if C_Timer and C_Timer.After then
            for step = 1, seconds do
                local stepElapsed = step
                C_Timer.After(stepElapsed, function()
                    if serial ~= pullSerial then
                        return
                    end
                    local left = seconds - stepElapsed
                    if left <= 0 then
                        activePullSec = nil
                        activePullEnd = 0
                        Say("GO!")
                    else
                        Say(tostring(left))
                    end
                end)
            end
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
        activePullSec = nil
        activePullEnd = 0
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
    if db and IsFiniteNumber(db.headerBottom) and IsFiniteNumber(db.headerTop) then
        local mid = (db.headerBottom + db.headerTop) / 2
        local uiH = UIParent:GetHeight()
        if IsFiniteNumber(uiH) and uiH > 0 then
            return mid < (uiH * 0.5)
        end
    end
    return true
end

function XMB:EnsurePosition()
    local db, host = self.db, self.host
    if IsFiniteNumber(db.headerLeft) and IsFiniteNumber(db.headerBottom) and IsFiniteNumber(db.headerTop) then
        return
    end
    local s = host:GetScale() or 1
    if not IsFiniteNumber(s) or s <= 0 then
        s = 1
    end
    local w = (host:GetWidth() or 300) * s
    local uiW = UIParent:GetWidth() or 1024
    db.headerLeft = math.floor((uiW - w) / 2 + 0.5)
    db.headerBottom = 200
    db.headerTop = db.headerBottom + COLLAPSED_H * s
end

local function SafeScale(frame)
    local scale = frame:GetEffectiveScale()
    if not IsFiniteNumber(scale) or scale <= 0 then
        scale = frame:GetScale() or 1
    end
    if not IsFiniteNumber(scale) or scale <= 0 then
        return 1
    end
    return scale
end

-- GetLeft is in the frame's effective scale. Saved coordinates are stored in UIParent space.
local function ToParentCoord(host, value)
    return value * SafeScale(host) / SafeScale(UIParent)
end

local function ParentPixel()
    local _, physH = GetPhysicalScreenSize()
    local eff = SafeScale(UIParent)
    if IsFiniteNumber(physH) and physH > 0 then
        return 768 / physH / eff
    end
    return 1
end

local function SnapToPixel(value, pixel)
    if not IsFiniteNumber(value) or not IsFiniteNumber(pixel) or pixel <= 0 then
        return value or 0
    end
    return math.floor(value / pixel + 0.5) * pixel
end

function XMB:RestorePosition()
    local db, host = self.db, self.host
    if not db or not host then
        return
    end
    self:EnsurePosition()
    local s = host:GetScale() or 1
    if not IsFiniteNumber(s) or s <= 0 then
        s = 1
    end
    local pixel = ParentPixel()
    local x = SnapToPixel(db.headerLeft, pixel) / s
    host:ClearAllPoints()
    if self.growUp then
        host:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, SnapToPixel(db.headerBottom, pixel) / s)
    else
        host:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, SnapToPixel(db.headerTop, pixel) / s)
    end
    self.positionApplied = true
    self.positionDirty = nil
end

function XMB:SavePosition()
    local db, host = self.db, self.host
    if not db or not host then
        return
    end
    local left, bottom, top = host:GetLeft(), host:GetBottom(), host:GetTop()
    if not IsFiniteNumber(left) or not IsFiniteNumber(bottom) or not IsFiniteNumber(top) then
        return
    end
    local s = host:GetScale() or 1
    if not IsFiniteNumber(s) or s <= 0 then
        s = 1
    end
    local span = COLLAPSED_H * s
    db.headerLeft = ToParentCoord(host, left)
    if self.growUp then
        db.headerBottom = ToParentCoord(host, bottom)
        db.headerTop = db.headerBottom + span
    else
        db.headerTop = ToParentCoord(host, top)
        db.headerBottom = db.headerTop - span
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
    if not host or not db or not self.pulls or not self.ready or not self.role or not self.grip then
        return
    end

    local growUp = self:ResolveGrowUp()
    local growChanged = (self.growUp ~= growUp)
    self.growUp = growUp

    local showFlag = db.enableWorldMarks ~= false
    local showStar = db.enableTargetMarks ~= false
    local function PullOn(sec)
        local value = db["showPull" .. sec]
        if value == nil then
            return db.showCountdown ~= false
        end
        return value and true or false
    end
    local pull5 = PullOn(5)
    local pull10 = PullOn(10)
    local pull20 = PullOn(20)

    local headerSig = (growUp and 1 or 0)
        + (pull5 and 2 or 0)
        + (pull10 and 4 or 0)
        + (pull20 and 8 or 0)
        + (db.showReady and 16 or 0)
        + (db.showRole and 32 or 0)
        + (showStar and 64 or 0)
        + (showFlag and 128 or 0)

    if headerSig ~= self.headerSig then
        local panel = host:GetAttribute("panel") or 0
        if (panel == 1 and not showStar) or (panel == 2 and not showFlag) then
            host:SetAttribute("panel", 0)
            self:UpdateActive()
        end

        self.flag:SetShown(showFlag)
        self.star:SetShown(showStar)

        local x = PAD
        local placedMark = false
        if showFlag then
            self:PlaceHeader(self.flag, x, BTN)
            x = x + BTN
            placedMark = true
        end
        if showStar then
            if placedMark then
                x = x + GAP
            end
            self:PlaceHeader(self.star, x, BTN)
            x = x + BTN
            placedMark = true
        end

        local anyUtil = pull5 or pull10 or pull20 or db.showReady or db.showRole
        if anyUtil and placedMark then
            x = x + GROUP_GAP
        end

        local placed = false
        for i = 1, #self.pulls do
            local btn = self.pulls[i]
            local sec = btn.seconds or PULL_TIMES[i]
            local on = (sec == 5 and pull5) or (sec == 10 and pull10) or (sec == 20 and pull20)
            btn:SetShown(on and true or false)
            if on then
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
    if not IsFiniteNumber(scale) or scale < 0.6 or scale > 1.6 then
        scale = 1
    end
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
    if self.db and not self.db.showTooltips then
        HideTip()
    end
    self:UpdateGrip()
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
    local host = self.host
    pcall(host.StopMovingOrSizing, host)
    if not InCombatLockdown() then
        pcall(host.SetUserPlaced, host, false)
    end
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
    -- OnMouseUp stays off the secure OnClick script, so combat toggles stay protected.
    flag:SetScript("OnMouseUp", function(_, button)
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
    star:SetScript("OnMouseUp", function(_, button)
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
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetScript("OnClick", function(_, button)
            DoPull(sec, button)
        end)
        btn.seconds = sec
        BindHover(btn, "Pull in " .. sec .. " seconds", "Left-click starts a countdown. Click again or right-click to cancel.")
        self.pulls[#self.pulls + 1] = btn
    end

    local ready = MakeButton(host, "XiusMB_Ready", "SecureActionButtonTemplate", RC_W)
    AddLabel(ready, "RC", COLOR.good)
    ready:RegisterForClicks("AnyUp", "AnyDown")
    ready:SetAttribute("useOnKeyDown", false)
    ready:SetAttribute("type", "macro")
    ready:SetAttribute("macrotext", "/readycheck")
    ready:SetAttribute("type1", "macro")
    ready:SetAttribute("*type1", "macro")
    ready:SetAttribute("macrotext1", "/readycheck")
    ready:SetAttribute("*macrotext1", "/readycheck")
    BindHover(ready, "Ready check", "Asks the group if they are ready. Leader or assistant only.")
    self.ready = ready

    local role = MakeButton(host, nil, nil, ROLE_W)
    AddLabel(role, "R", COLOR.role)
    role:RegisterForClicks("LeftButtonUp")
    role:SetScript("OnClick", function()
        if IsInGroup and not SafeBool(IsInGroup) then
            XMB:Print("Join a party or raid to start a role check.")
            return
        end
        if not InitiateRolePoll then
            XMB:Print("Role check is not available right now.")
            return
        end
        local ok = pcall(InitiateRolePoll)
        if not ok then
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
    grip:SetScript("OnHide", function()
        if XMB.moving then
            XMB:StopMove()
        end
    end)
    grip:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            XMB:OpenOptions()
        end
    end)
    grip:SetScript("OnEnter", function(self)
        if XMB.db and XMB.db.isLocked then
            ShowTip(self, "Locked", "Unlock the bar from /xmb.")
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

    -- SetRaidTarget is protected. Left click toggles that icon. Right click and the clear button always remove it.
    local function ArmRaidTarget(btn, marker, clearOnRight)
        btn:RegisterForClicks("AnyUp", "AnyDown")
        btn:SetAttribute("useOnKeyDown", false)
        btn:SetAttribute("checkselfcast", false)
        btn:SetAttribute("checkfocuscast", false)
        btn:SetAttribute("type", "raidtarget")
        btn:SetAttribute("type1", "raidtarget")
        btn:SetAttribute("*type1", "raidtarget")
        btn:SetAttribute("unit", "target")
        btn:SetAttribute("unit1", "target")
        btn:SetAttribute("*unit1", "target")
        local action = marker == 0 and "clear" or "toggle"
        btn:SetAttribute("marker", marker)
        btn:SetAttribute("marker1", marker)
        btn:SetAttribute("*marker1", marker)
        btn:SetAttribute("action", action)
        btn:SetAttribute("action1", action)
        btn:SetAttribute("*action1", action)
        if clearOnRight then
            btn:SetAttribute("type2", "raidtarget")
            btn:SetAttribute("*type2", "raidtarget")
            btn:SetAttribute("unit2", "target")
            btn:SetAttribute("*unit2", "target")
            btn:SetAttribute("marker2", 0)
            btn:SetAttribute("*marker2", 0)
            btn:SetAttribute("action2", "clear")
            btn:SetAttribute("*action2", "clear")
        end
    end

    for i = 1, 8 do
        local btn = MakeButton(targetRow, "XiusMB_TM" .. i, "SecureActionButtonTemplate")
        ArmRaidTarget(btn, i, true)
        AddIcon(btn, MARK_TEXTURES[i])
        PlaceInRow(targetRow, btn, i)
        BindHover(btn, MARK_NAMES[i], "Left click marks your target. Click the same mark again to remove it. Right click clears it.")
    end

    local clearTarget = MakeButton(targetRow, "XiusMB_TClear", "SecureActionButtonTemplate")
    ArmRaidTarget(clearTarget, 0, false)
    AddIcon(clearTarget, "Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    PlaceInRow(targetRow, clearTarget, 9)
    BindHover(clearTarget, "Clear target mark", "Removes the mark from your current target.")

    -- World marks stay on the secure worldmarker action. Left toggles, right clears that flare.
    local function ArmWorldMarker(btn, marker, clearOnRight)
        btn:RegisterForClicks("AnyUp", "AnyDown")
        btn:SetAttribute("useOnKeyDown", false)
        btn:SetAttribute("checkselfcast", false)
        btn:SetAttribute("checkfocuscast", false)
        btn:SetAttribute("type", "worldmarker")
        btn:SetAttribute("type1", "worldmarker")
        btn:SetAttribute("*type1", "worldmarker")
        if marker and marker > 0 then
            btn:SetAttribute("marker", marker)
            btn:SetAttribute("marker1", marker)
            btn:SetAttribute("*marker1", marker)
            btn:SetAttribute("action", "toggle")
            btn:SetAttribute("action1", "toggle")
            btn:SetAttribute("*action1", "toggle")
            if clearOnRight then
                btn:SetAttribute("type2", "worldmarker")
                btn:SetAttribute("*type2", "worldmarker")
                btn:SetAttribute("marker2", marker)
                btn:SetAttribute("*marker2", marker)
                btn:SetAttribute("action2", "clear")
                btn:SetAttribute("*action2", "clear")
            end
            btn.xmbWorldMarker = marker
        else
            btn:SetAttribute("action", "clear")
            btn:SetAttribute("action1", "clear")
            btn:SetAttribute("*action1", "clear")
        end
    end

    for i = 1, 8 do
        local btn = MakeButton(worldRow, "XiusMB_WM" .. i, "SecureActionButtonTemplate")
        ArmWorldMarker(btn, i, true)
        AddIcon(btn, MARK_TEXTURES[WORLD_ICON[i]])
        local flare = btn:CreateTexture(nil, "OVERLAY")
        flare:SetTexture("Interface\\RaidFrame\\Raid-WorldPing")
        flare:SetSize(10, 10)
        flare:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        PlaceInRow(worldRow, btn, i)
        BindHover(btn, WORLD_NAMES[i], "Left click places or removes the world marker. Right click removes it.")
    end

    local clearWorld = MakeButton(worldRow, "XiusMB_WClear", "SecureActionButtonTemplate")
    ArmWorldMarker(clearWorld, 0, false)
    AddIcon(clearWorld, "Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    PlaceInRow(worldRow, clearWorld, 9)
    BindHover(clearWorld, "Clear world marks", "Removes every world marker.")

    if not self.keybindButtonsCreated then
        self.keybindButtonsCreated = true
        local function MakeKeyButton(name)
            local btn = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
            btn:SetSize(1, 1)
            btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
            btn:SetAlpha(0)
            btn:EnableMouse(false)
            btn:Show()
            return btn
        end
        for i = 1, 8 do
            local tBtn = MakeKeyButton("XiusMB_Key_TM" .. i)
            ArmRaidTarget(tBtn, i, false)
            local wBtn = MakeKeyButton("XiusMB_Key_WM" .. i)
            ArmWorldMarker(wBtn, i, false)
        end
        local tClearKey = MakeKeyButton("XiusMB_Key_TClear")
        ArmRaidTarget(tClearKey, 0, false)
        local wClearKey = MakeKeyButton("XiusMB_Key_WClear")
        ArmWorldMarker(wClearKey, 0, false)
    end

    host:SetFrameRef("trow", targetRow)
    host:SetFrameRef("wrow", worldRow)
    self.growUp = self:ResolveGrowUp()
    host:SetAttribute("pad", PAD)
    host:SetAttribute("headerh", HEADER_H)
    host:SetAttribute("rowh", BTN)
    host:SetAttribute("rowgap", ROW_GAP)
    host:SetAttribute("growup", self.growUp and 1 or 0)
    host:SetAttribute("_onattributechanged", HOST_SNIPPET)
    local panel = 0
    if db.showTarget then
        panel = 1
    elseif db.showWorld then
        panel = 2
    end
    host:SetAttribute("panel", panel)

    self:ApplyScale()
    self:ApplyVisibility()
    self:Layout()
end

local eventFrame = CreateFrame("Frame")
local LOADED_TEXT = "Loaded. Click the flag for world marks, the star for target marks. /xmb for options."

local function CreateBar()
    if XMB.host then
        XMB.pendingCreate = nil
        return "ready"
    end
    if XMB.barFailed then
        return "failed"
    end
    if InCombatLockdown() then
        XMB.pendingCreate = true
        return "combat"
    end
    XMB.pendingCreate = nil
    local created, err = pcall(function()
        XMB:CreateUI()
    end)
    if not created then
        XMB.barFailed = true
        XMB:Print("Could not create the bar. " .. tostring(err))
        return "failed"
    end
    return "ready"
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        eventFrame:UnregisterEvent("ADDON_LOADED")
        XMB:InitDB()
        local optionsOk, optionsErr = pcall(function()
            XMB:CreateOptions()
        end)
        if not optionsOk then
            XMB:Print("Could not create options. " .. tostring(optionsErr))
        end
        local state = CreateBar()
        if state == "combat" then
            XMB:Print("Loaded. The bar will appear when combat ends.")
        elseif state == "ready" then
            XMB:Print(LOADED_TEXT)
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "UI_SCALE_CHANGED" then
        if not XMB.host then
            return
        end
        XMB.positionDirty = true
        XMB:RequestLayout()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if XMB.moving then
            XMB:StopMove()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if XMB.pendingCreate then
            local hadHost = XMB.host and true or false
            local state = CreateBar()
            if state == "ready" and not hadHost then
                XMB:Print(LOADED_TEXT)
            end
        end
        if XMB.pendingLayout and XMB.host then
            XMB.pendingLayout = nil
            XMB:ApplyScale()
            XMB:ApplyVisibility()
            XMB:Layout()
        end
    end
end)
