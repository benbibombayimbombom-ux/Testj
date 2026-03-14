-- ╔══════════════════════════════════════════════════════════╗
-- ║     JJS TARGET SYSTEM v3.1  |  FIXED - Mobile+PC        ║
-- ║     LocalScript → StarterPlayerScripts                   ║
-- ╚══════════════════════════════════════════════════════════╝

-- Services
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

-- ── Device detect ────────────────────────────────────────────
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ── Palette ──────────────────────────────────────────────────
local C = {
    BG       = Color3.fromHex("#080A10"),
    Panel    = Color3.fromHex("#10131C"),
    Card     = Color3.fromHex("#161923"),
    Border   = Color3.fromHex("#1E2535"),
    Accent   = Color3.fromHex("#7C3AED"),
    AccentHi = Color3.fromHex("#A855F7"),
    Danger   = Color3.fromHex("#EF4444"),
    Success  = Color3.fromHex("#22C55E"),
    Warn     = Color3.fromHex("#F59E0B"),
    TextHi   = Color3.fromHex("#F1F5F9"),
    TextMid  = Color3.fromHex("#94A3B8"),
    TextLow  = Color3.fromHex("#475569"),
}

-- ── Config ───────────────────────────────────────────────────
local CFG = {
    PunchRange     = 6,
    SkillRanges    = {15, 20, 25, 30},
    SkillCooldowns = {1.2, 3.0, 5.0, 8.0},
    SkillDamageEst = {25, 60, 90, 150},
    PunchCooldown  = 0.35,
    ChaseSpeed     = 16,
    OrbitRadius    = 5,
    OrbitSpeed     = 1.5,
    NoclipEnabled  = false,
    ScanInterval   = 10,
}

-- ── State ────────────────────────────────────────────────────
local State = {
    Running   = false,
    Target    = nil,
    Mode      = "Smart",
    SkillLast = {0, 0, 0, 0},
    PunchLast = 0,
    TotalDmg  = 0,
    KillCount = 0,
}

local ScannedTargets = {}

-- ── Helpers ──────────────────────────────────────────────────
local function mkCorner(r, p)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = p
end
local function mkStroke(t, col, p)
    local s = Instance.new("UIStroke")
    s.Thickness = t
    s.Color = col
    s.Parent = p
end
local function getChar()  return LocalPlayer.Character end
local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHRP(m)  return m and m:FindFirstChild("HumanoidRootPart") end
local function getHum(m)  return m and m:FindFirstChildOfClass("Humanoid") end
local function vDist(a, b)
    if not a or not b then return 999 end
    return (a.Position - b.Position).Magnitude
end
local function isAlive(m)
    local h = getHum(m)
    return h and h.Health > 0
end
local function fireKey(key)
    pcall(function()
        local v = game:GetService("VirtualInputManager")
        v:SendKeyEvent(true, key, false, game)
        task.wait(0.05)
        v:SendKeyEvent(false, key, false, game)
    end)
end
local function fireClick()
    pcall(function()
        local v = game:GetService("VirtualInputManager")
        v:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, true, game, 0)
        task.wait(0.05)
        v:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 0)
    end)
end

-- ════════════════════════════════════════════════════════════
-- SCREEN GUI  (tek, kalıcı)
-- ════════════════════════════════════════════════════════════
local SG = Instance.new("ScreenGui")
SG.Name            = "JJS_v31"
SG.ResetOnSpawn    = false
SG.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset  = true
SG.Parent          = LocalPlayer.PlayerGui

-- ════════════════════════════════════════════════════════════
-- LOADING SCREEN
-- ════════════════════════════════════════════════════════════
local LS = Instance.new("Frame")
LS.Name               = "LoadScreen"
LS.Size               = UDim2.new(1, 0, 1, 0)
LS.BackgroundColor3   = Color3.fromHex("#05070D")
LS.ZIndex             = 50
LS.Parent             = SG

-- Grid lines
for i = 1, 10 do
    local l = Instance.new("Frame", LS)
    l.Size = UDim2.new(0, 1, 1, 0)
    l.Position = UDim2.new(i / 10, 0, 0, 0)
    l.BackgroundColor3 = C.Accent
    l.BackgroundTransparency = 0.88
    l.ZIndex = 51
end
for i = 1, 7 do
    local l = Instance.new("Frame", LS)
    l.Size = UDim2.new(1, 0, 0, 1)
    l.Position = UDim2.new(0, 0, i / 7, 0)
    l.BackgroundColor3 = C.Accent
    l.BackgroundTransparency = 0.88
    l.ZIndex = 51
end

-- Glow ring
local LGlow = Instance.new("ImageLabel", LS)
LGlow.Size               = UDim2.new(0, 180, 0, 180)
LGlow.AnchorPoint        = Vector2.new(0.5, 0.5)
LGlow.Position           = UDim2.new(0.5, 0, 0.38, 0)
LGlow.BackgroundTransparency = 1
LGlow.Image              = "rbxassetid://5028857472"
LGlow.ImageColor3        = C.Accent
LGlow.ImageTransparency  = 0.5
LGlow.ZIndex             = 52

-- Lightning icon
local LIcon = Instance.new("TextLabel", LS)
LIcon.Size               = UDim2.new(0, 70, 0, 70)
LIcon.AnchorPoint        = Vector2.new(0.5, 0.5)
LIcon.Position           = UDim2.new(0.5, 0, 0.36, 0)
LIcon.BackgroundTransparency = 1
LIcon.Text               = "⚡"
LIcon.TextSize           = 56
LIcon.Font               = Enum.Font.GothamBold
LIcon.TextColor3         = C.AccentHi
LIcon.ZIndex             = 53

-- Title
local LTitle = Instance.new("TextLabel", LS)
LTitle.Size              = UDim2.new(0, 280, 0, 38)
LTitle.AnchorPoint       = Vector2.new(0.5, 0)
LTitle.Position          = UDim2.new(0.5, 0, 0.50, 0)
LTitle.BackgroundTransparency = 1
LTitle.Text              = "JJS TARGET"
LTitle.TextSize          = 30
LTitle.Font              = Enum.Font.GothamBold
LTitle.TextColor3        = C.TextHi
LTitle.ZIndex            = 53

local LSub = Instance.new("TextLabel", LS)
LSub.Size                = UDim2.new(0, 280, 0, 22)
LSub.AnchorPoint         = Vector2.new(0.5, 0)
LSub.Position            = UDim2.new(0.5, 0, 0.58, 0)
LSub.BackgroundTransparency = 1
LSub.Text                = "Smart Combat System v3.1"
LSub.TextSize            = 13
LSub.Font                = Enum.Font.Gotham
LSub.TextColor3          = C.Accent
LSub.ZIndex              = 53

-- Progress bar
local LBarBG = Instance.new("Frame", LS)
LBarBG.Size              = UDim2.new(0, 260, 0, 6)
LBarBG.AnchorPoint       = Vector2.new(0.5, 0)
LBarBG.Position          = UDim2.new(0.5, 0, 0.65, 0)
LBarBG.BackgroundColor3  = C.Card
LBarBG.ZIndex            = 52
mkCorner(3, LBarBG)

local LBarFill = Instance.new("Frame", LBarBG)
LBarFill.Size            = UDim2.new(0, 0, 1, 0)
LBarFill.BackgroundColor3 = C.Accent
LBarFill.ZIndex          = 53
mkCorner(3, LBarFill)

-- Status
local LStatus = Instance.new("TextLabel", LS)
LStatus.Size             = UDim2.new(0, 260, 0, 20)
LStatus.AnchorPoint      = Vector2.new(0.5, 0)
LStatus.Position         = UDim2.new(0.5, 0, 0.69, 0)
LStatus.BackgroundTransparency = 1
LStatus.Text             = "Starting..."
LStatus.TextSize         = 12
LStatus.Font             = Enum.Font.Gotham
LStatus.TextColor3       = C.TextMid
LStatus.ZIndex           = 53

-- Device badge
local LBadge = Instance.new("TextLabel", LS)
LBadge.Size              = UDim2.new(0, 220, 0, 18)
LBadge.AnchorPoint       = Vector2.new(0.5, 0)
LBadge.Position          = UDim2.new(0.5, 0, 0.77, 0)
LBadge.BackgroundTransparency = 1
LBadge.Text              = IsMobile and "📱 Mobile Mode Detected" or "🖥️ PC Mode Detected"
LBadge.TextSize          = 11
LBadge.Font              = Enum.Font.GothamBold
LBadge.TextColor3        = C.TextLow
LBadge.ZIndex            = 53

-- Glow pulse
task.spawn(function()
    while LS and LS.Parent do
        TweenService:Create(LGlow, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {ImageTransparency = 0.15, Size = UDim2.new(0, 210, 0, 210)}):Play()
        task.wait(1)
        TweenService:Create(LGlow, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {ImageTransparency = 0.6, Size = UDim2.new(0, 160, 0, 160)}):Play()
        task.wait(1)
    end
end)

-- ── Loading steps (blocking wait) ────────────────────────────
local steps = {
    {txt = "Scanning workspace...",     pct = 0.18},
    {txt = "Building UI panels...",     pct = 0.36},
    {txt = "Loading combat engine...",  pct = 0.55},
    {txt = "Configuring mobile input...",pct = 0.73},
    {txt = "Connecting player scanner...",pct = 0.90},
    {txt = "✓ Ready!",                  pct = 1.00},
}

for _, s in ipairs(steps) do
    LStatus.Text = s.txt
    TweenService:Create(LBarFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad),
        {Size = UDim2.new(s.pct, 0, 1, 0)}):Play()
    task.wait(0.38)
end

task.wait(0.3)

-- Fade out loading screen
TweenService:Create(LS, TweenInfo.new(0.5, Enum.EasingStyle.Quad),
    {BackgroundTransparency = 1}):Play()
for _, d in ipairs(LS:GetDescendants()) do
    pcall(function()
        if d:IsA("Frame") then
            TweenService:Create(d, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        elseif d:IsA("TextLabel") then
            TweenService:Create(d, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
        elseif d:IsA("ImageLabel") then
            TweenService:Create(d, TweenInfo.new(0.4), {ImageTransparency = 1}):Play()
        end
    end)
end
task.wait(0.55)
LS:Destroy()

-- ════════════════════════════════════════════════════════════
-- MAIN PANEL  (oluşuyor, loading bitti)
-- ════════════════════════════════════════════════════════════
local UIW = IsMobile and 320 or 340
local UIH = IsMobile and 560 or 520

local Main = Instance.new("Frame")
Main.Name             = "MainPanel"
Main.Size             = UDim2.new(0, UIW, 0, UIH)
Main.Position         = IsMobile
    and UDim2.new(0.5, -UIW/2, 0, 50)  -- mobil: üst orta
    or  UDim2.new(0, 20, 0, 60)         -- pc: sol üst
Main.BackgroundColor3 = C.BG
Main.ClipDescendants  = false
Main.ZIndex           = 10
Main.Parent           = SG  -- Direkt SG'ye parent
mkCorner(14, Main)
mkStroke(1.5, C.Border, Main)

-- Ambient glow
local Glow = Instance.new("ImageLabel", Main)
Glow.Size               = UDim2.new(1, 100, 1, 100)
Glow.Position           = UDim2.new(0, -50, 0, -50)
Glow.BackgroundTransparency = 1
Glow.ZIndex             = 9
Glow.Image              = "rbxassetid://5028857472"
Glow.ImageColor3        = C.Accent
Glow.ImageTransparency  = 0.85

-- ── Topbar ───────────────────────────────────────────────────
local TopH = IsMobile and 52 or 44

local Top = Instance.new("Frame", Main)
Top.Size             = UDim2.new(1, 0, 0, TopH)
Top.BackgroundColor3 = C.Panel
Top.ZIndex           = 11
mkCorner(14, Top)
-- fix bottom corners of topbar
local TopFix = Instance.new("Frame", Top)
TopFix.Size             = UDim2.new(1, 0, 0, 14)
TopFix.Position         = UDim2.new(0, 0, 1, -14)
TopFix.BackgroundColor3 = C.Panel
TopFix.BorderSizePixel  = 0
TopFix.ZIndex           = 11

local TitleLbl = Instance.new("TextLabel", Top)
TitleLbl.Size               = UDim2.new(1, -90, 1, 0)
TitleLbl.Position           = UDim2.new(0, 14, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text               = "⚡ JJS TARGET"
TitleLbl.TextSize           = IsMobile and 17 or 15
TitleLbl.Font               = Enum.Font.GothamBold
TitleLbl.TextColor3         = C.TextHi
TitleLbl.TextXAlignment     = Enum.TextXAlignment.Left
TitleLbl.ZIndex             = 12

local SubLbl = Instance.new("TextLabel", Top)
SubLbl.Size               = UDim2.new(1, -90, 0, 14)
SubLbl.Position           = UDim2.new(0, 14, 1, -18)
SubLbl.BackgroundTransparency = 1
SubLbl.Text               = (IsMobile and "📱 Mobile" or "🖥️ PC").." · v3.1"
SubLbl.TextSize           = 10
SubLbl.Font               = Enum.Font.Gotham
SubLbl.TextColor3         = C.Accent
SubLbl.TextXAlignment     = Enum.TextXAlignment.Left
SubLbl.ZIndex             = 12

local BtnSz = IsMobile and 32 or 26

local CloseBtn = Instance.new("TextButton", Top)
CloseBtn.Size               = UDim2.new(0, BtnSz, 0, BtnSz)
CloseBtn.Position           = UDim2.new(1, -(BtnSz + 8), 0.5, -BtnSz / 2)
CloseBtn.BackgroundColor3   = C.Danger
CloseBtn.Text               = "✕"
CloseBtn.TextSize           = IsMobile and 15 or 12
CloseBtn.Font               = Enum.Font.GothamBold
CloseBtn.TextColor3         = C.TextHi
CloseBtn.AutoButtonColor    = false
CloseBtn.ZIndex             = 13
mkCorner(8, CloseBtn)

local MinBtn = Instance.new("TextButton", Top)
MinBtn.Size               = UDim2.new(0, BtnSz, 0, BtnSz)
MinBtn.Position           = UDim2.new(1, -(BtnSz * 2 + 14), 0.5, -BtnSz / 2)
MinBtn.BackgroundColor3   = C.TextLow
MinBtn.Text               = "–"
MinBtn.TextSize           = IsMobile and 16 or 14
MinBtn.Font               = Enum.Font.GothamBold
MinBtn.TextColor3         = C.TextHi
MinBtn.AutoButtonColor    = false
MinBtn.ZIndex             = 13
mkCorner(8, MinBtn)

-- ── Drag ─────────────────────────────────────────────────────
do
    local dragging, dragStart, startPos
    Top.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = inp.Position
            startPos  = Main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging
        and (inp.UserInputType == Enum.UserInputType.MouseMovement
          or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ── Minimize / Close ─────────────────────────────────────────
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(Main, TweenInfo.new(0.25, Enum.EasingStyle.Quad),
        {Size = UDim2.new(0, UIW, 0, minimized and TopH or UIH)}):Play()
end)
CloseBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
end)

-- ── Scroll content ───────────────────────────────────────────
local Scroll = Instance.new("ScrollingFrame", Main)
Scroll.Size                 = UDim2.new(1, 0, 1, -TopH)
Scroll.Position             = UDim2.new(0, 0, 0, TopH)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness   = 3
Scroll.ScrollBarImageColor3 = C.Accent
Scroll.CanvasSize           = UDim2.new(0, 0, 0, 0)
Scroll.ZIndex               = 11

local Layout = Instance.new("UIListLayout", Scroll)
Layout.Padding           = UDim.new(0, 8)
Layout.SortOrder         = Enum.SortOrder.LayoutOrder
Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local Pad = Instance.new("UIPadding", Scroll)
Pad.PaddingLeft   = UDim.new(0, 10)
Pad.PaddingRight  = UDim.new(0, 10)
Pad.PaddingTop    = UDim.new(0, 8)
Pad.PaddingBottom = UDim.new(0, 8)

Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Scroll.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 20)
end)

-- Card factory
local function Card(height, order)
    local f = Instance.new("Frame", Scroll)
    f.Size             = UDim2.new(1, 0, 0, height)
    f.BackgroundColor3 = C.Card
    f.LayoutOrder      = order
    f.ZIndex           = 12
    mkCorner(10, f)
    mkStroke(1, C.Border, f)
    return f
end
local function CardLabel(txt, card)
    local l = Instance.new("TextLabel", card)
    l.Size               = UDim2.new(1, -10, 0, 16)
    l.Position           = UDim2.new(0, 8, 0, 5)
    l.BackgroundTransparency = 1
    l.Text               = txt
    l.TextSize           = 10
    l.Font               = Enum.Font.GothamBold
    l.TextColor3         = C.AccentHi
    l.TextXAlignment     = Enum.TextXAlignment.Left
    l.ZIndex             = 13
end

-- ════════════ CARD 1 — TARGET INFO ══════════════════════════
local c1 = Card(88, 1)
CardLabel("TARGET", c1)

local TgtIcon = Instance.new("ImageLabel", c1)
TgtIcon.Size               = UDim2.new(0, 42, 0, 42)
TgtIcon.Position           = UDim2.new(0, 8, 0, 24)
TgtIcon.BackgroundColor3   = C.Border
TgtIcon.Image              = ""
TgtIcon.ZIndex             = 13
mkCorner(8, TgtIcon)

local TgtName = Instance.new("TextLabel", c1)
TgtName.Size               = UDim2.new(1, -62, 0, 20)
TgtName.Position           = UDim2.new(0, 58, 0, 24)
TgtName.BackgroundTransparency = 1
TgtName.Text               = "No Target"
TgtName.TextSize           = IsMobile and 15 or 13
TgtName.Font               = Enum.Font.GothamBold
TgtName.TextColor3         = C.TextHi
TgtName.TextXAlignment     = Enum.TextXAlignment.Left
TgtName.ZIndex             = 13

local TgtHP = Instance.new("TextLabel", c1)
TgtHP.Size               = UDim2.new(1, -62, 0, 14)
TgtHP.Position           = UDim2.new(0, 58, 0, 46)
TgtHP.BackgroundTransparency = 1
TgtHP.Text               = "HP: — | Dist: —"
TgtHP.TextSize           = IsMobile and 12 or 10
TgtHP.Font               = Enum.Font.Gotham
TgtHP.TextColor3         = C.TextMid
TgtHP.TextXAlignment     = Enum.TextXAlignment.Left
TgtHP.ZIndex             = 13

local HPbg = Instance.new("Frame", c1)
HPbg.Size             = UDim2.new(1, -16, 0, IsMobile and 7 or 5)
HPbg.Position         = UDim2.new(0, 8, 0, 74)
HPbg.BackgroundColor3 = C.Border
HPbg.ZIndex           = 13
mkCorner(3, HPbg)

local HPfill = Instance.new("Frame", HPbg)
HPfill.Size             = UDim2.new(0, 0, 1, 0)
HPfill.BackgroundColor3 = C.Success
HPfill.ZIndex           = 14
mkCorner(3, HPfill)

-- ════════════ CARD 2 — SCANNER ══════════════════════════════
local BH = IsMobile and 44 or 34    -- button height
local c2H = 26 + BH + 8 + BH + 8 + 16 + 8 + (IsMobile and 34 or 28) + 6
local c2 = Card(c2H, 2)
CardLabel("PLAYER & NPC SCANNER", c2)

-- Dropdown trigger button
local DropTrig = Instance.new("TextButton", c2)
DropTrig.Size               = UDim2.new(1, -16, 0, BH)
DropTrig.Position           = UDim2.new(0, 8, 0, 22)
DropTrig.BackgroundColor3   = C.Border
DropTrig.Text               = "▾   Select Target..."
DropTrig.TextSize           = IsMobile and 14 or 12
DropTrig.Font               = Enum.Font.Gotham
DropTrig.TextColor3         = C.TextMid
DropTrig.TextXAlignment     = Enum.TextXAlignment.Left
DropTrig.AutoButtonColor    = false
DropTrig.ZIndex             = 13
mkCorner(8, DropTrig)
mkStroke(1, C.Accent, DropTrig)
local dp = Instance.new("UIPadding", DropTrig)
dp.PaddingLeft = UDim.new(0, 10)

-- Scan / Clear row
local y2 = 22 + BH + 8
local ScanBtn = Instance.new("TextButton", c2)
ScanBtn.Size             = UDim2.new(0.5, -12, 0, BH)
ScanBtn.Position         = UDim2.new(0, 8, 0, y2)
ScanBtn.BackgroundColor3 = C.Accent
ScanBtn.Text             = "🔍 Scan"
ScanBtn.TextSize         = IsMobile and 14 or 12
ScanBtn.Font             = Enum.Font.GothamBold
ScanBtn.TextColor3       = C.TextHi
ScanBtn.AutoButtonColor  = false
ScanBtn.ZIndex           = 13
mkCorner(8, ScanBtn)

local ClearBtn = Instance.new("TextButton", c2)
ClearBtn.Size             = UDim2.new(0.5, -12, 0, BH)
ClearBtn.Position         = UDim2.new(0.5, 4, 0, y2)
ClearBtn.BackgroundColor3 = C.Danger
ClearBtn.Text             = "✕ Clear"
ClearBtn.TextSize         = IsMobile and 14 or 12
ClearBtn.Font             = Enum.Font.GothamBold
ClearBtn.TextColor3       = C.TextHi
ClearBtn.AutoButtonColor  = false
ClearBtn.ZIndex           = 13
mkCorner(8, ClearBtn)

-- Scan status
local y3 = y2 + BH + 6
local ScanLbl = Instance.new("TextLabel", c2)
ScanLbl.Size               = UDim2.new(1, -16, 0, 16)
ScanLbl.Position           = UDim2.new(0, 8, 0, y3)
ScanLbl.BackgroundTransparency = 1
ScanLbl.Text               = "Press Scan to find targets"
ScanLbl.TextSize           = IsMobile and 12 or 10
ScanLbl.Font               = Enum.Font.Gotham
ScanLbl.TextColor3         = C.TextMid
ScanLbl.TextXAlignment     = Enum.TextXAlignment.Left
ScanLbl.ZIndex             = 13

-- Mode chips
local chipH = IsMobile and 34 or 28
local y4 = y3 + 20
local Modes = {"Smart", "Orbit", "Chase"}
local ModeChips = {}
for i, m in ipairs(Modes) do
    local chip = Instance.new("TextButton", c2)
    chip.Size             = UDim2.new(0, IsMobile and 86 or 74, 0, chipH)
    chip.Position         = UDim2.new(0, 8 + (i - 1) * (IsMobile and 92 or 80), 0, y4)
    chip.BackgroundColor3 = (m == "Smart") and C.Accent or C.Border
    chip.Text             = m
    chip.TextSize         = IsMobile and 13 or 11
    chip.Font             = Enum.Font.GothamBold
    chip.TextColor3       = C.TextHi
    chip.AutoButtonColor  = false
    chip.ZIndex           = 13
    mkCorner(chipH / 2, chip)
    ModeChips[m] = chip
    chip.MouseButton1Click:Connect(function()
        State.Mode = m
        for _, c in pairs(ModeChips) do
            TweenService:Create(c, TweenInfo.new(0.15), {BackgroundColor3 = C.Border}):Play()
        end
        TweenService:Create(chip, TweenInfo.new(0.15), {BackgroundColor3 = C.Accent}):Play()
    end)
end

-- ════════════ DROPDOWN LIST (SG'ye direkt) ══════════════════
local DropList = Instance.new("Frame", SG)
DropList.Size             = UDim2.new(0, UIW - 20, 0, 0)
DropList.BackgroundColor3 = C.Panel
DropList.ClipDescendants  = true
DropList.Visible          = false
DropList.ZIndex           = 40
mkCorner(10, DropList)
mkStroke(1.5, C.Accent, DropList)

local DScroll = Instance.new("ScrollingFrame", DropList)
DScroll.Size              = UDim2.new(1, 0, 1, 0)
DScroll.BackgroundTransparency = 1
DScroll.ScrollBarThickness = 3
DScroll.ScrollBarImageColor3 = C.Accent
DScroll.CanvasSize        = UDim2.new(0, 0, 0, 0)
DScroll.ZIndex            = 41

local DLayout = Instance.new("UIListLayout", DScroll)
DLayout.SortOrder = Enum.SortOrder.LayoutOrder

local dropOpen = false
local function closeDropdown()
    dropOpen = false
    TweenService:Create(DropList, TweenInfo.new(0.2, Enum.EasingStyle.Quad),
        {Size = UDim2.new(0, UIW - 20, 0, 0)}):Play()
    task.delay(0.21, function() DropList.Visible = false end)
end
local function openDropdown()
    local ab = DropTrig.AbsolutePosition
    DropList.Position = UDim2.new(0, ab.X, 0, ab.Y + BH + 4)
    DropList.Visible  = true
    local itemH = IsMobile and 42 or 34
    local h = math.min(#ScannedTargets * itemH + 8, 200)
    if h < 10 then h = 44 end
    TweenService:Create(DropList, TweenInfo.new(0.2, Enum.EasingStyle.Quad),
        {Size = UDim2.new(0, UIW - 20, 0, h)}):Play()
    dropOpen = true
end

local function populateDropdown()
    for _, ch in ipairs(DScroll:GetChildren()) do
        if not ch:IsA("UIListLayout") then ch:Destroy() end
    end
    local itemH = IsMobile and 42 or 34
    if #ScannedTargets == 0 then
        local e = Instance.new("TextLabel", DScroll)
        e.Size = UDim2.new(1, 0, 0, itemH)
        e.BackgroundTransparency = 1
        e.Text = "  No targets found"
        e.TextSize = 12; e.Font = Enum.Font.Gotham
        e.TextColor3 = C.TextLow; e.ZIndex = 42
        e.TextXAlignment = Enum.TextXAlignment.Left
    end
    for _, t in ipairs(ScannedTargets) do
        local btn = Instance.new("TextButton", DScroll)
        btn.Size             = UDim2.new(1, 0, 0, itemH)
        btn.BackgroundTransparency = 1
        btn.Text             = "  " .. (t.isPlayer and "👤 " or "🤖 ") .. t.name
        btn.TextSize         = IsMobile and 14 or 12
        btn.Font             = Enum.Font.Gotham
        btn.TextColor3       = C.TextHi
        btn.TextXAlignment   = Enum.TextXAlignment.Left
        btn.AutoButtonColor  = false
        btn.ZIndex           = 42
        local div = Instance.new("Frame", btn)
        div.Size             = UDim2.new(1, -16, 0, 1)
        div.Position         = UDim2.new(0, 8, 1, -1)
        div.BackgroundColor3 = C.Border
        div.ZIndex           = 43
        btn.MouseEnter:Connect(function()
            btn.BackgroundTransparency = 0
            btn.BackgroundColor3 = C.Border
        end)
        btn.MouseLeave:Connect(function()
            btn.BackgroundTransparency = 1
        end)
        btn.MouseButton1Click:Connect(function()
            State.Target  = t.model
            TgtName.Text  = t.name
            DropTrig.Text = "▾   " .. t.name
            if t.isPlayer then
                TgtIcon.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="
                    .. t.player.UserId .. "&width=48&height=48&format=png"
            else
                TgtIcon.Image = ""
            end
            closeDropdown()
        end)
    end
    DScroll.CanvasSize = UDim2.new(0, 0, 0, #ScannedTargets * itemH + 8)
end

DropTrig.MouseButton1Click:Connect(function()
    if dropOpen then closeDropdown() else openDropdown() end
end)

-- ════════════ CARD 3 — COMBAT STATS ═════════════════════════
local c3 = Card(68, 3)
CardLabel("COMBAT STATS", c3)

local statDefs = {
    {k="dmg",  lbl="Total Dmg",  val="0",  col=C.Danger},
    {k="kil",  lbl="Kills",      val="0",  col=C.AccentHi},
    {k="cd",   lbl="Next Skill", val="--", col=C.Warn},
}
local SL = {}
for i, s in ipairs(statDefs) do
    local col = Instance.new("Frame", c3)
    col.Size               = UDim2.new(0.333, 0, 1, -22)
    col.Position           = UDim2.new((i-1)*0.333, 0, 0, 22)
    col.BackgroundTransparency = 1
    col.ZIndex             = 13
    local vl = Instance.new("TextLabel", col)
    vl.Size               = UDim2.new(1, 0, 0, 24)
    vl.BackgroundTransparency = 1
    vl.Text               = s.val
    vl.TextSize           = IsMobile and 19 or 17
    vl.Font               = Enum.Font.GothamBold
    vl.TextColor3         = s.col
    vl.ZIndex             = 14
    local kl = Instance.new("TextLabel", col)
    kl.Size               = UDim2.new(1, 0, 0, 13)
    kl.Position           = UDim2.new(0, 0, 0, 24)
    kl.BackgroundTransparency = 1
    kl.Text               = s.lbl
    kl.TextSize           = 9
    kl.Font               = Enum.Font.Gotham
    kl.TextColor3         = C.TextLow
    kl.ZIndex             = 14
    SL[s.k] = vl
end

-- ════════════ CARD 4 — SKILL COOLDOWNS ══════════════════════
local rowH = IsMobile and 22 or 17
local c4H  = 22 + 4 * rowH + 6
local c4   = Card(c4H, 4)
CardLabel("SKILL COOLDOWNS", c4)

local SkillBars = {}
for i = 1, 4 do
    local row = Instance.new("Frame", c4)
    row.Size               = UDim2.new(1, -16, 0, rowH)
    row.Position           = UDim2.new(0, 8, 0, 20 + (i-1)*rowH)
    row.BackgroundTransparency = 1
    row.ZIndex             = 13

    local lbl = Instance.new("TextLabel", row)
    lbl.Size               = UDim2.new(0, 22, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text               = "[" .. i .. "]"
    lbl.TextSize           = 11
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextColor3         = C.AccentHi
    lbl.ZIndex             = 14

    local bg = Instance.new("Frame", row)
    bg.Size               = UDim2.new(1, -62, 0, IsMobile and 10 or 8)
    bg.Position           = UDim2.new(0, 24, 0.5, IsMobile and -5 or -4)
    bg.BackgroundColor3   = C.Border
    bg.ZIndex             = 14
    mkCorner(4, bg)

    local fill = Instance.new("Frame", bg)
    fill.Size             = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = C.Accent
    fill.ZIndex           = 15
    mkCorner(4, fill)

    local pct = Instance.new("TextLabel", row)
    pct.Size               = UDim2.new(0, 40, 1, 0)
    pct.Position           = UDim2.new(1, -40, 0, 0)
    pct.BackgroundTransparency = 1
    pct.Text               = "READY"
    pct.TextSize           = 9
    pct.Font               = Enum.Font.GothamBold
    pct.TextColor3         = C.Success
    pct.ZIndex             = 14

    SkillBars[i] = {fill = fill, lbl = pct}
end

-- ════════════ CARD 5 — MOBILE SKILL BUTTONS ════════════════
local MobileBtns = {}
if IsMobile then
    local c5 = Card(80, 5)
    CardLabel("QUICK SKILLS (tap to use)", c5)

    for i = 1, 4 do
        local sb = Instance.new("TextButton", c5)
        local bw = (UIW - 36) / 4
        sb.Size             = UDim2.new(0, bw, 0, 42)
        sb.Position         = UDim2.new(0, 8 + (i-1)*(bw+4), 0, 26)
        sb.BackgroundColor3 = C.Card
        sb.Text             = "[" .. i .. "]"
        sb.TextSize         = 17
        sb.Font             = Enum.Font.GothamBold
        sb.TextColor3       = C.TextHi
        sb.AutoButtonColor  = false
        sb.ZIndex           = 13
        mkCorner(8, sb)
        mkStroke(1.5, C.Accent, sb)
        MobileBtns[i] = sb

        local keyList = {Enum.KeyCode.One, Enum.KeyCode.Two,
                         Enum.KeyCode.Three, Enum.KeyCode.Four}
        sb.MouseButton1Click:Connect(function()
            fireKey(keyList[i])
            TweenService:Create(sb, TweenInfo.new(0.1),
                {BackgroundColor3 = C.Accent}):Play()
            task.delay(0.18, function()
                TweenService:Create(sb, TweenInfo.new(0.2),
                    {BackgroundColor3 = C.Card}):Play()
            end)
        end)
    end
end

-- ════════════ CARD 6 — START / STOP ═════════════════════════
local c6 = Card(BH + 16, IsMobile and 6 or 5)

local StartBtn = Instance.new("TextButton", c6)
StartBtn.Size             = UDim2.new(0.62, -6, 0, BH)
StartBtn.Position         = UDim2.new(0, 8, 0, 8)
StartBtn.BackgroundColor3 = C.Success
StartBtn.Text             = "▶  START"
StartBtn.TextSize         = IsMobile and 15 or 13
StartBtn.Font             = Enum.Font.GothamBold
StartBtn.TextColor3       = C.TextHi
StartBtn.AutoButtonColor  = false
StartBtn.ZIndex           = 13
mkCorner(8, StartBtn)

local StopBtn = Instance.new("TextButton", c6)
StopBtn.Size              = UDim2.new(0.38, -6, 0, BH)
StopBtn.Position          = UDim2.new(0.62, 4, 0, 8)
StopBtn.BackgroundColor3  = C.Danger
StopBtn.Text              = "■  STOP"
StopBtn.TextSize          = IsMobile and 15 or 13
StopBtn.Font              = Enum.Font.GothamBold
StopBtn.TextColor3        = C.TextHi
StopBtn.AutoButtonColor   = false
StopBtn.ZIndex            = 13
mkCorner(8, StopBtn)

-- ════════════════════════════════════════════════════════════
-- NOTIFICATION SYSTEM
-- ════════════════════════════════════════════════════════════
local NotifFrame = Instance.new("Frame", SG)
NotifFrame.Size               = UDim2.new(0, IsMobile and 290 or 300, 1, -20)
NotifFrame.Position           = IsMobile
    and UDim2.new(0, 8, 0, 10)
    or  UDim2.new(1, -310, 0, 10)
NotifFrame.BackgroundTransparency = 1
NotifFrame.ZIndex             = 30

local NLayout = Instance.new("UIListLayout", NotifFrame)
NLayout.SortOrder          = Enum.SortOrder.LayoutOrder
NLayout.Padding            = UDim.new(0, 6)
NLayout.VerticalAlignment  = Enum.VerticalAlignment.Bottom

local nIdx = 0
local function notify(title, body, icon, ntype)
    nIdx += 1
    local acc = (ntype == "success") and C.Success
             or (ntype == "danger")  and C.Danger
             or (ntype == "warn")    and C.Warn
             or C.Accent

    local bg = Instance.new("Frame", NotifFrame)
    bg.Size             = UDim2.new(1, 0, 0, 0)
    bg.BackgroundColor3 = C.Card
    bg.LayoutOrder      = -nIdx
    bg.ClipDescendants  = true
    bg.ZIndex           = 31
    mkCorner(10, bg)
    mkStroke(1, acc:Lerp(C.Border, 0.4), bg)

    local stripe = Instance.new("Frame", bg)
    stripe.Size             = UDim2.new(0, 3, 1, 0)
    stripe.BackgroundColor3 = acc
    stripe.ZIndex           = 32
    mkCorner(2, stripe)

    local ic = Instance.new("TextLabel", bg)
    ic.Size               = UDim2.new(0, 28, 0, 28)
    ic.Position           = UDim2.new(0, 10, 0, 8)
    ic.BackgroundTransparency = 1
    ic.Text               = icon
    ic.TextSize           = IsMobile and 20 or 18
    ic.Font               = Enum.Font.Gotham
    ic.ZIndex             = 33

    local t = Instance.new("TextLabel", bg)
    t.Size               = UDim2.new(1, -46, 0, 16)
    t.Position           = UDim2.new(0, 42, 0, 6)
    t.BackgroundTransparency = 1
    t.Text               = title
    t.TextSize           = IsMobile and 14 or 12
    t.Font               = Enum.Font.GothamBold
    t.TextColor3         = C.TextHi
    t.TextXAlignment     = Enum.TextXAlignment.Left
    t.ZIndex             = 33

    local b = Instance.new("TextLabel", bg)
    b.Size               = UDim2.new(1, -46, 0, 14)
    b.Position           = UDim2.new(0, 42, 0, 23)
    b.BackgroundTransparency = 1
    b.Text               = body
    b.TextSize           = IsMobile and 12 or 10
    b.Font               = Enum.Font.Gotham
    b.TextColor3         = C.TextMid
    b.TextXAlignment     = Enum.TextXAlignment.Left
    b.ZIndex             = 33

    TweenService:Create(bg, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.new(1, 0, 0, 48)}):Play()
    task.delay(3.5, function()
        TweenService:Create(bg, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        task.wait(0.35)
        bg:Destroy()
    end)
end

-- ════════════════════════════════════════════════════════════
-- SCANNER
-- ════════════════════════════════════════════════════════════
local function scanTargets()
    ScannedTargets = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local h = getHum(p.Character)
            if h and h.Health > 0 then
                table.insert(ScannedTargets, {
                    name = p.Name, model = p.Character,
                    isPlayer = true, player = p
                })
            end
        end
    end
    local ch = workspace:FindFirstChild("Characters")
    if ch then
        for _, child in ipairs(ch:GetChildren()) do
            local h = getHum(child)
            if h and h.Health > 0 then
                local dup = false
                for _, t in ipairs(ScannedTargets) do
                    if t.model == child then dup = true; break end
                end
                if not dup then
                    table.insert(ScannedTargets, {name = child.Name, model = child, isPlayer = false})
                end
            end
        end
    end
end

ScanBtn.MouseButton1Click:Connect(function()
    scanTargets()
    populateDropdown()
    ScanLbl.Text = "Found: " .. #ScannedTargets .. " target(s)"
    notify("🔍 Scan Complete", #ScannedTargets .. " target(s) found", "🔍", "accent")
end)

ClearBtn.MouseButton1Click:Connect(function()
    State.Target   = nil
    State.Running  = false
    TgtName.Text   = "No Target"
    TgtHP.Text     = "HP: — | Dist: —"
    HPfill.Size    = UDim2.new(0, 0, 1, 0)
    DropTrig.Text  = "▾   Select Target..."
    TgtIcon.Image  = ""
    notify("✕ Cleared", "Target removed", "❌", "danger")
end)

-- ════════════════════════════════════════════════════════════
-- PLAYER TRACKING
-- ════════════════════════════════════════════════════════════
Players.PlayerAdded:Connect(function(p)
    notify("👋 Player Joined", p.Name .. " entered", "➕", "accent")
    p.CharacterAdded:Connect(function()
        task.wait(1)
        scanTargets(); populateDropdown()
        ScanLbl.Text = "Found: " .. #ScannedTargets .. " target(s)"
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    notify("🚪 Player Left", p.Name .. " left", "🚪", "warn")
    if State.Target and State.Target.Parent == nil then
        State.Target = nil
        TgtName.Text = "No Target"
        notify("❌ Target Lost", p.Name .. " disconnected", "❌", "danger")
    end
    task.wait(0.5)
    scanTargets(); populateDropdown()
    ScanLbl.Text = "Found: " .. #ScannedTargets .. " target(s)"
end)

-- ════════════════════════════════════════════════════════════
-- COMBAT ENGINE
-- ════════════════════════════════════════════════════════════
local function tweenTo(pos)
    local root = getRoot(); if not root then return end
    local d = (root.Position - pos).Magnitude
    TweenService:Create(root, TweenInfo.new(d / CFG.ChaseSpeed, Enum.EasingStyle.Linear),
        {CFrame = CFrame.new(pos)}):Play()
end

local function pathTo(goalPos)
    local root = getRoot(); if not root then return end
    local path = PathfindingService:CreatePath({
        AgentRadius = 2, AgentHeight = 5,
        AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 4
    })
    local ok = pcall(function() path:ComputeAsync(root.Position, goalPos) end)
    if ok and path.Status == Enum.PathStatus.Success then
        for _, wp in ipairs(path:GetWaypoints()) do
            if not State.Running then break end
            if wp.Action == Enum.PathWaypointAction.Jump then
                local h = getHum(getChar()); if h then h.Jump = true end
            end
            tweenTo(wp.Position); task.wait(0.12)
        end
    else
        tweenTo(goalPos)
    end
end

local function lookAt()
    local root = getRoot(); local thrp = getHRP(State.Target)
    if root and thrp then
        root.CFrame = CFrame.lookAt(root.Position, thrp.Position)
    end
end

local function inRange(r)
    local root = getRoot(); local thrp = getHRP(State.Target)
    if not root or not thrp then return false end
    return (root.Position - thrp.Position).Magnitude <= r
end

local function doPunch()
    local now = tick()
    if now - State.PunchLast < CFG.PunchCooldown then return false end
    if not inRange(CFG.PunchRange) then return false end
    lookAt(); fireClick(); State.PunchLast = now
    return true
end

local function doSkill(id)
    local now = tick()
    if now - State.SkillLast[id] < CFG.SkillCooldowns[id] then return false end
    if not inRange(CFG.SkillRanges[id]) then return false end
    lookAt()
    local keys = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four}
    fireKey(keys[id])
    State.SkillLast[id] = now
    State.TotalDmg += CFG.SkillDamageEst[id]
    return true
end

local function smartCombo()
    local now = tick()
    for id = 4, 1, -1 do
        if now - State.SkillLast[id] >= CFG.SkillCooldowns[id] then
            if doSkill(id) then return end
        end
    end
    doPunch()
end

local orbitAngle = 0
local function orbitTarget()
    local thrp = getHRP(State.Target); if not thrp then return end
    orbitAngle += CFG.OrbitSpeed * 0.05
    local goal = thrp.Position + Vector3.new(
        math.cos(orbitAngle) * CFG.OrbitRadius, 0,
        math.sin(orbitAngle) * CFG.OrbitRadius)
    local root = getRoot()
    if root then root.CFrame = CFrame.new(goal) end
    lookAt(); smartCombo()
end

local function predictiveChase()
    local thrp = getHRP(State.Target); if not thrp then return end
    local hum  = getHum(State.Target)
    local vel  = (hum and hum.MoveDirection) or Vector3.zero
    pathTo(thrp.Position + vel * 2)
end

-- UI updater
local function updateUI()
    if State.Target then
        local hum = getHum(State.Target)
        if hum then
            local hp = math.floor(hum.Health)
            local mx = math.floor(hum.MaxHealth)
            local pct = hp / math.max(mx, 1)
            TgtHP.Text = "HP: " .. hp .. "/" .. mx .. " | Dist: " ..
                math.floor(vDist(getRoot(), getHRP(State.Target))) .. "u"
            TweenService:Create(HPfill, TweenInfo.new(0.3),
                {Size = UDim2.new(pct, 0, 1, 0)}):Play()
            HPfill.BackgroundColor3 = pct > 0.5 and C.Success
                                   or pct > 0.25 and C.Warn
                                   or C.Danger
        end
    end
    local now = tick()
    local minR = math.huge
    for i = 1, 4 do
        local cd  = CFG.SkillCooldowns[i]
        local ela = now - State.SkillLast[i]
        local pct = math.clamp(ela / cd, 0, 1)
        TweenService:Create(SkillBars[i].fill, TweenInfo.new(0.1),
            {Size = UDim2.new(pct, 0, 1, 0)}):Play()
        if pct >= 1 then
            SkillBars[i].lbl.Text = "READY"
            SkillBars[i].lbl.TextColor3 = C.Success
        else
            SkillBars[i].lbl.Text = string.format("%.1fs", cd - ela)
            SkillBars[i].lbl.TextColor3 = C.Warn
        end
        local rem = cd - ela; if rem < minR then minR = rem end
    end
    SL["dmg"].Text = tostring(State.TotalDmg)
    SL["kil"].Text = tostring(State.KillCount)
    SL["cd"].Text  = minR <= 0 and "NOW" or string.format("%.1fs", minR)

    if IsMobile then
        local now2 = tick()
        for i = 1, 4 do
            if MobileBtns[i] then
                local rdy = (now2 - State.SkillLast[i]) >= CFG.SkillCooldowns[i]
                MobileBtns[i].BackgroundColor3 = rdy and C.Card or C.Border
            end
        end
    end
end

-- Main combat loop
local function combatLoop()
    while State.Running do
        local tgt = State.Target
        if not tgt then task.wait(0.2); continue end

        if not isAlive(tgt) then
            State.KillCount += 1
            notify("💀 Target Killed!", tgt.Name .. " eliminated", "💀", "success")
            State.Target = nil
            TgtName.Text = "No Target"
            TgtHP.Text   = "HP: — | Dist: —"
            HPfill.Size  = UDim2.new(0, 0, 1, 0)
            task.wait(1); continue
        end

        local thrp = getHRP(tgt)
        local root = getRoot()
        if not thrp or not root then task.wait(0.2); continue end

        local d = vDist(root, thrp)

        if State.Mode == "Orbit" then
            orbitTarget()
        elseif State.Mode == "Chase" then
            predictiveChase()
            if d < CFG.PunchRange then smartCombo() end
        else -- Smart
            if d > CFG.PunchRange + 2 then
                if d > CFG.OrbitRadius * 4 then
                    predictiveChase()
                else
                    local dir = (root.Position - thrp.Position).Unit
                    pathTo(thrp.Position + dir * (CFG.PunchRange - 1))
                end
            else
                smartCombo()
            end
        end

        updateUI()
        task.wait(0.08)
    end
end

-- ════════════════════════════════════════════════════════════
-- BUTTONS
-- ════════════════════════════════════════════════════════════
StartBtn.MouseButton1Click:Connect(function()
    if not State.Target then
        notify("⚠️ No Target", "Select a target first!", "⚠️", "warn"); return
    end
    if State.Running then return end
    State.Running = true
    TweenService:Create(StartBtn, TweenInfo.new(0.2), {BackgroundColor3 = C.TextLow}):Play()
    notify("▶ Started", "Targeting: " .. State.Target.Name, "▶", "success")
    task.spawn(combatLoop)
end)

StopBtn.MouseButton1Click:Connect(function()
    State.Running = false
    TweenService:Create(StartBtn, TweenInfo.new(0.2), {BackgroundColor3 = C.Success}):Play()
    notify("■ Stopped", "Combat paused", "■", "danger")
end)

-- PC hotkeys
if not IsMobile then
    UserInputService.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if inp.KeyCode == Enum.KeyCode.F1 then
            Main.Visible = not Main.Visible
        end
        if inp.KeyCode == Enum.KeyCode.F2 then
            scanTargets(); populateDropdown()
            ScanLbl.Text = "Found: " .. #ScannedTargets .. " target(s)"
        end
        if inp.KeyCode == Enum.KeyCode.Delete then
            State.Running = false
            notify("■ Stopped", "Hotkey: DELETE", "■", "danger")
        end
    end)
end

-- Noclip
if CFG.NoclipEnabled then
    RunService.Stepped:Connect(function()
        local char = getChar()
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end)
end

-- ════════════════════════════════════════════════════════════
-- INITIAL SCAN + WELCOME NOTIF
-- ════════════════════════════════════════════════════════════
task.wait(0.3)
scanTargets()
populateDropdown()
ScanLbl.Text = "Found: " .. #ScannedTargets .. " target(s)"
notify("⚡ JJS Target v3.1", (IsMobile and "📱 Mobile" or "🖥️ PC") .. " · Ready!", "⚡", "success")

-- Auto re-scan
task.spawn(function()
    while true do
        task.wait(CFG.ScanInterval)
        if not State.Running then
            local prev = #ScannedTargets
            scanTargets()
            if #ScannedTargets ~= prev then
                populateDropdown()
                ScanLbl.Text = "Found: " .. #ScannedTargets .. " target(s)"
            end
        end
    end
end)

print("[JJS v3.1] OK | Mobile=" .. tostring(IsMobile))
