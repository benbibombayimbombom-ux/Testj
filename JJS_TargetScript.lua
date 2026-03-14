-- ============================================================
--  JJS TARGET SYSTEM v2.0 | by Claude
--  Jujutsu Shenanigans - Smart Combat + UI Script
--  LocalScript → StarterPlayerScripts içine koy
-- ============================================================

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UserInputService= game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local HttpService     = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

-- ============================================================
-- CONFIG
-- ============================================================
local CFG = {
    -- Combat
    PunchRange        = 6,
    SkillRanges       = {[1]=15, [2]=20, [3]=25, [4]=30},
    SkillKeys         = {[Enum.KeyCode.One]=1, [Enum.KeyCode.Two]=2,
                         [Enum.KeyCode.Three]=3, [Enum.KeyCode.Four]=4},
    SkillCooldowns    = {[1]=1.2, [2]=3.0, [3]=5.0, [4]=8.0},
    SkillDamageEst    = {[1]=25, [2]=60, [3]=90, [4]=150},
    PunchCooldown     = 0.35,
    ChaseSpeed        = 16,
    OrbitRadius       = 5,
    OrbitSpeed        = 1.5,

    -- Pathfinding
    PathRetryDelay    = 0.8,
    StuckThreshold    = 2.5,
    StuckDistance     = 1.5,

    -- Noclip (engel yoksa)
    NoclipEnabled     = false,

    -- Scan
    ScanInterval      = 1.0,
    MaxScanDistance   = 500,
}

-- ============================================================
-- STATE
-- ============================================================
local State = {
    Running      = false,
    Target       = nil,   -- Model
    TargetHP     = 0,
    Mode         = "Smart",  -- "Smart" | "Orbit" | "Chase"
    SkillLast    = {[1]=0,[2]=0,[3]=0,[4]=0},
    PunchLast    = 0,
    Path         = nil,
    LastPos      = nil,
    LastPosTime  = 0,
    StuckCount   = 0,
    TotalDmg     = 0,
    KillCount    = 0,
    Connections  = {},
    NotifQueue   = {},
}

-- ============================================================
-- UTILITY
-- ============================================================
local function getChar()   return LocalPlayer.Character end
local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHRP(model)
    return model and model:FindFirstChild("HumanoidRootPart")
end
local function getHum(model)
    return model and model:FindFirstChildOfClass("Humanoid")
end
local function dist(a,b)
    if not a or not b then return math.huge end
    return (a.Position - b.Position).Magnitude
end
local function isAlive(model)
    local h = getHum(model)
    return h and h.Health > 0
end
local function fireKey(key)
    -- VirtualInputManager (executor'da varsa)
    if game:GetService("VirtualInputManager") then
        pcall(function()
            game:GetService("VirtualInputManager"):SendKeyEvent(true, key, false, game)
            task.wait(0.05)
            game:GetService("VirtualInputManager"):SendKeyEvent(false, key, false, game)
        end)
    end
end
local function fireClick()
    pcall(function()
        if game:GetService("VirtualInputManager") then
            game:GetService("VirtualInputManager"):SendMouseButtonEvent(
                Mouse.X, Mouse.Y, 0, true, game, 0)
            task.wait(0.05)
            game:GetService("VirtualInputManager"):SendMouseButtonEvent(
                Mouse.X, Mouse.Y, 0, false, game, 0)
        end
    end)
end

-- ============================================================
-- PLAYER / NPC SCANNER
-- ============================================================
local ScannedTargets = {}  -- {name, model, isPlayer}

local function scanTargets()
    ScannedTargets = {}
    -- Players
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local h = getHum(p.Character)
            if h and h.Health > 0 then
                table.insert(ScannedTargets, {
                    name=p.Name, model=p.Character,
                    isPlayer=true, player=p
                })
            end
        end
    end
    -- NPC / Dummy
    local chars = workspace:FindFirstChild("Characters")
    if chars then
        for _, child in ipairs(chars:GetChildren()) do
            local h = getHum(child)
            if h and h.Health > 0 then
                -- duplicate kontrolü
                local found = false
                for _, t in ipairs(ScannedTargets) do
                    if t.model == child then found=true; break end
                end
                if not found then
                    table.insert(ScannedTargets, {
                        name=child.Name, model=child,
                        isPlayer=false
                    })
                end
            end
        end
    end
    return ScannedTargets
end

-- ============================================================
-- UI BUILDER
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "JJS_TargetUI"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent         = LocalPlayer.PlayerGui

-- ── PALETTE ──────────────────────────────────────────────────
local C = {
    BG       = Color3.fromHex("#0D0F14"),
    Panel    = Color3.fromHex("#13161E"),
    Border   = Color3.fromHex("#1E2330"),
    Accent   = Color3.fromHex("#7C3AED"),
    AccentHi = Color3.fromHex("#A855F7"),
    Danger   = Color3.fromHex("#EF4444"),
    Success  = Color3.fromHex("#22C55E"),
    Warn     = Color3.fromHex("#F59E0B"),
    TextHi   = Color3.fromHex("#F8FAFC"),
    TextMid  = Color3.fromHex("#94A3B8"),
    TextLow  = Color3.fromHex("#475569"),
    Stroke   = Color3.fromHex("#6D28D9"),
}

local function mkCorner(r, p)
    local c = Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r); c.Parent=p
end
local function mkStroke(t,c,p)
    local s=Instance.new("UIStroke"); s.Thickness=t; s.Color=c; s.Parent=p
end
local function mkLabel(txt, size, color, parent, bold)
    local l = Instance.new("TextLabel")
    l.Text=txt; l.TextSize=size; l.TextColor3=color
    l.BackgroundTransparency=1; l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.Size=UDim2.new(1,0,1,0); l.Parent=parent
    return l
end
local function mkBtn(txt, size, parent)
    local b = Instance.new("TextButton")
    b.Text=txt; b.TextSize=size or 13
    b.Font=Enum.Font.GothamBold; b.TextColor3=C.TextHi
    b.BackgroundColor3=C.Accent; b.AutoButtonColor=false
    b.Parent=parent; mkCorner(6,b)
    b.MouseEnter:Connect(function()
        TweenService:Create(b,TweenInfo.new(.15),{BackgroundColor3=C.AccentHi}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b,TweenInfo.new(.15),{BackgroundColor3=C.Accent}):Play()
    end)
    return b
end

-- ── MAIN FRAME ───────────────────────────────────────────────
local MainFrame = Instance.new("Frame")
MainFrame.Name              = "Main"
MainFrame.Size              = UDim2.new(0,340,0,480)
MainFrame.Position          = UDim2.new(0,20,0,60)
MainFrame.BackgroundColor3  = C.BG
MainFrame.ClipDescendants   = false
MainFrame.Parent            = ScreenGui
mkCorner(14, MainFrame)
mkStroke(1.5, C.Border, MainFrame)

-- Glow
local Glow = Instance.new("ImageLabel")
Glow.Size=UDim2.new(1,60,1,60); Glow.Position=UDim2.new(0,-30,0,-30)
Glow.BackgroundTransparency=1; Glow.ZIndex=0
Glow.Image="rbxassetid://5028857472"
Glow.ImageColor3=C.Accent; Glow.ImageTransparency=0.82
Glow.Parent=MainFrame

-- ── TOPBAR ───────────────────────────────────────────────────
local TopBar = Instance.new("Frame")
TopBar.Size=UDim2.new(1,0,0,44); TopBar.BackgroundColor3=C.Panel; TopBar.Parent=MainFrame
mkCorner(14,TopBar)
-- fix bottom corners
local TopFix = Instance.new("Frame")
TopFix.Size=UDim2.new(1,0,0,14); TopFix.Position=UDim2.new(0,0,1,-14)
TopFix.BackgroundColor3=C.Panel; TopFix.BorderSizePixel=0; TopFix.Parent=TopBar

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size=UDim2.new(1,-100,1,0); TitleLbl.Position=UDim2.new(0,14,0,0)
TitleLbl.BackgroundTransparency=1; TitleLbl.Text="⚡ JJS TARGET"
TitleLbl.TextSize=15; TitleLbl.Font=Enum.Font.GothamBold
TitleLbl.TextColor3=C.TextHi; TitleLbl.TextXAlignment=Enum.TextXAlignment.Left
TitleLbl.Parent=TopBar

local SubLbl = Instance.new("TextLabel")
SubLbl.Size=UDim2.new(1,-100,0,14); SubLbl.Position=UDim2.new(0,14,1,-18)
SubLbl.BackgroundTransparency=1; SubLbl.Text="Smart Combat System v2.0"
SubLbl.TextSize=10; SubLbl.Font=Enum.Font.Gotham
SubLbl.TextColor3=C.TextMid; SubLbl.TextXAlignment=Enum.TextXAlignment.Left
SubLbl.Parent=TopBar

-- Close / Minimize
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size=UDim2.new(0,26,0,26); CloseBtn.Position=UDim2.new(1,-36,0,9)
CloseBtn.BackgroundColor3=C.Danger; CloseBtn.Text="✕"
CloseBtn.TextSize=12; CloseBtn.Font=Enum.Font.GothamBold; CloseBtn.TextColor3=C.TextHi
CloseBtn.Parent=TopBar; mkCorner(6,CloseBtn)

local MinBtn = Instance.new("TextButton")
MinBtn.Size=UDim2.new(0,26,0,26); MinBtn.Position=UDim2.new(1,-66,0,9)
MinBtn.BackgroundColor3=C.TextLow; MinBtn.Text="–"
MinBtn.TextSize=14; MinBtn.Font=Enum.Font.GothamBold; MinBtn.TextColor3=C.TextHi
MinBtn.Parent=TopBar; mkCorner(6,MinBtn)

-- ── DRAG ─────────────────────────────────────────────────────
do
    local dragging, dragStart, startPos
    TopBar.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or
           inp.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=inp.Position
            startPos=MainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement or
           inp.UserInputType==Enum.UserInputType.Touch) then
            local delta = inp.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset+delta.X,
                startPos.Y.Scale, startPos.Y.Offset+delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or
           inp.UserInputType==Enum.UserInputType.Touch then
            dragging=false
        end
    end)
end

-- ── CONTENT FRAME ────────────────────────────────────────────
local Content = Instance.new("Frame")
Content.Size=UDim2.new(1,0,1,-44); Content.Position=UDim2.new(0,0,0,44)
Content.BackgroundTransparency=1; Content.ClipDescendants=true; Content.Parent=MainFrame

-- Minimize logic
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(MainFrame, TweenInfo.new(.25,Enum.EasingStyle.Quad),
        {Size=minimized and UDim2.new(0,340,0,44) or UDim2.new(0,340,0,480)}):Play()
    Content.Visible = not minimized
end)
CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

local pad = Instance.new("UIPadding")
pad.PaddingLeft=UDim.new(0,12); pad.PaddingRight=UDim.new(0,12)
pad.PaddingTop=UDim.new(0,10); pad.Parent=Content

-- ── SECTION HELPER ───────────────────────────────────────────
local function section(title, yOff, height)
    local f = Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,height); f.Position=UDim2.new(0,0,0,yOff)
    f.BackgroundColor3=C.Panel; f.Parent=Content; mkCorner(8,f)
    mkStroke(1,C.Border,f)
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-10,0,14); lbl.Position=UDim2.new(0,8,0,6)
    lbl.BackgroundTransparency=1; lbl.Text=title
    lbl.TextSize=10; lbl.Font=Enum.Font.GothamBold
    lbl.TextColor3=C.AccentHi; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.Parent=f
    return f
end

-- ── TARGET SECTION (y=0) ─────────────────────────────────────
local TargetSec = section("TARGET", 0, 90)

local TargetIcon = Instance.new("ImageLabel")
TargetIcon.Size=UDim2.new(0,38,0,38); TargetIcon.Position=UDim2.new(0,8,0,24)
TargetIcon.BackgroundColor3=C.Border; TargetIcon.Image=""
TargetIcon.Parent=TargetSec; mkCorner(6,TargetIcon)

local TargetNameLbl = Instance.new("TextLabel")
TargetNameLbl.Size=UDim2.new(1,-60,0,18); TargetNameLbl.Position=UDim2.new(0,54,0,24)
TargetNameLbl.BackgroundTransparency=1; TargetNameLbl.Text="No Target"
TargetNameLbl.TextSize=14; TargetNameLbl.Font=Enum.Font.GothamBold
TargetNameLbl.TextColor3=C.TextHi; TargetNameLbl.TextXAlignment=Enum.TextXAlignment.Left
TargetNameLbl.Parent=TargetSec

local TargetHPLbl = Instance.new("TextLabel")
TargetHPLbl.Size=UDim2.new(1,-60,0,14); TargetHPLbl.Position=UDim2.new(0,54,0,46)
TargetHPLbl.BackgroundTransparency=1; TargetHPLbl.Text="HP: — | Dist: —"
TargetHPLbl.TextSize=11; TargetHPLbl.Font=Enum.Font.Gotham
TargetHPLbl.TextColor3=C.TextMid; TargetHPLbl.TextXAlignment=Enum.TextXAlignment.Left
TargetHPLbl.Parent=TargetSec

local HPBarBG = Instance.new("Frame")
HPBarBG.Size=UDim2.new(1,-16,0,5); HPBarBG.Position=UDim2.new(0,8,0,74)
HPBarBG.BackgroundColor3=C.Border; HPBarBG.Parent=TargetSec; mkCorner(3,HPBarBG)
local HPBar = Instance.new("Frame")
HPBar.Size=UDim2.new(0,0,1,0); HPBar.BackgroundColor3=C.Success
HPBar.Parent=HPBarBG; mkCorner(3,HPBar)

-- ── SCANNER (y=98) ───────────────────────────────────────────
local ScanSec = section("PLAYER & NPC SCANNER", 98, 140)

local DropBtn = Instance.new("TextButton")
DropBtn.Size=UDim2.new(1,-16,0,26); DropBtn.Position=UDim2.new(0,8,0,22)
DropBtn.BackgroundColor3=C.Border; DropBtn.Text="▾  Select Target..."
DropBtn.TextSize=12; DropBtn.Font=Enum.Font.Gotham; DropBtn.TextColor3=C.TextMid
DropBtn.TextXAlignment=Enum.TextXAlignment.Left; DropBtn.Parent=ScanSec; mkCorner(6,DropBtn)
mkStroke(1,C.Border,DropBtn)

-- Dropdown list (hidden by default)
local DropList = Instance.new("Frame")
DropList.Size=UDim2.new(0,316,0,0); DropList.Position=UDim2.new(0,0,0,170)
DropList.BackgroundColor3=C.Panel; DropList.ClipDescendants=true
DropList.Visible=false; DropList.ZIndex=10; DropList.Parent=ScreenGui
mkCorner(8,DropList); mkStroke(1,C.Border,DropList)

local DropScroll = Instance.new("ScrollingFrame")
DropScroll.Size=UDim2.new(1,0,1,0); DropScroll.BackgroundTransparency=1
DropScroll.ScrollBarThickness=3; DropScroll.CanvasSize=UDim2.new(0,0,0,0)
DropScroll.Parent=DropList
local DropLayout = Instance.new("UIListLayout")
DropLayout.SortOrder=Enum.SortOrder.LayoutOrder; DropLayout.Parent=DropScroll

local ScanBtn = mkBtn("🔍 Scan", 12, ScanSec)
ScanBtn.Size=UDim2.new(0.48,0,0,26); ScanBtn.Position=UDim2.new(0,8,0,56)

local ClearBtn = mkBtn("✕ Clear", 12, ScanSec)
ClearBtn.BackgroundColor3=C.Danger; ClearBtn.Size=UDim2.new(0.48,0,0,26)
ClearBtn.Position=UDim2.new(0.52,0,0,56)
ClearBtn.MouseEnter:Connect(function() end) -- override hover

local ScanStatusLbl = Instance.new("TextLabel")
ScanStatusLbl.Size=UDim2.new(1,-16,0,14); ScanStatusLbl.Position=UDim2.new(0,8,0,90)
ScanStatusLbl.BackgroundTransparency=1; ScanStatusLbl.Text="Scan to find targets"
ScanStatusLbl.TextSize=11; ScanStatusLbl.Font=Enum.Font.Gotham
ScanStatusLbl.TextColor3=C.TextMid; ScanStatusLbl.TextXAlignment=Enum.TextXAlignment.Left
ScanStatusLbl.Parent=ScanSec

-- Mode chips
local ModeFrame = Instance.new("Frame")
ModeFrame.Size=UDim2.new(1,-16,0,24); ModeFrame.Position=UDim2.new(0,8,0,112)
ModeFrame.BackgroundTransparency=1; ModeFrame.Parent=ScanSec
local ModeLayout=Instance.new("UIListLayout")
ModeLayout.FillDirection=Enum.FillDirection.Horizontal; ModeLayout.Padding=UDim.new(0,6)
ModeLayout.Parent=ModeFrame

local Modes = {"Smart","Orbit","Chase"}
local ModeChips = {}
for i,m in ipairs(Modes) do
    local chip = Instance.new("TextButton")
    chip.Size=UDim2.new(0,72,1,0); chip.Text=m; chip.TextSize=11
    chip.Font=Enum.Font.GothamBold; chip.AutoButtonColor=false
    chip.BackgroundColor3= (m=="Smart") and C.Accent or C.Border
    chip.TextColor3=C.TextHi; chip.Parent=ModeFrame; mkCorner(12,chip)
    ModeChips[m]=chip
    chip.MouseButton1Click:Connect(function()
        State.Mode=m
        for _,c in pairs(ModeChips) do
            TweenService:Create(c,TweenInfo.new(.15),{BackgroundColor3=C.Border}):Play()
        end
        TweenService:Create(chip,TweenInfo.new(.15),{BackgroundColor3=C.Accent}):Play()
    end)
end

-- ── COMBAT STATS (y=246) ─────────────────────────────────────
local StatSec = section("COMBAT STATS", 246, 70)

local statData = {
    {key="dmg",   lbl="Total Dmg", val="0",   color=C.Danger},
    {key="kills", lbl="Kills",     val="0",   color=C.AccentHi},
    {key="cd",    lbl="Next Skill",val="--",  color=C.Warn},
}
local StatLabels = {}
for i,s in ipairs(statData) do
    local col = Instance.new("Frame")
    col.Size=UDim2.new(0.33,0,1,-22); col.Position=UDim2.new((i-1)*0.333,0,0,22)
    col.BackgroundTransparency=1; col.Parent=StatSec
    local v=Instance.new("TextLabel"); v.Size=UDim2.new(1,0,0,22)
    v.BackgroundTransparency=1; v.Text=s.val; v.TextSize=16
    v.Font=Enum.Font.GothamBold; v.TextColor3=s.color; v.Parent=col
    local k=Instance.new("TextLabel"); k.Size=UDim2.new(1,0,0,14); k.Position=UDim2.new(0,0,0,22)
    k.BackgroundTransparency=1; k.Text=s.lbl; k.TextSize=9
    k.Font=Enum.Font.Gotham; k.TextColor3=C.TextLow; k.Parent=col
    StatLabels[s.key]={val=v}
end

-- ── SKILL BARS (y=324) ───────────────────────────────────────
local SkillSec = section("SKILL COOLDOWNS", 324, 90)
local SkillBars = {}
for i=1,4 do
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,-16,0,14); row.Position=UDim2.new(0,8,0,18+(i-1)*18)
    row.BackgroundTransparency=1; row.Parent=SkillSec
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0,20,1,0)
    lbl.BackgroundTransparency=1; lbl.Text="["..i.."]"; lbl.TextSize=10
    lbl.Font=Enum.Font.GothamBold; lbl.TextColor3=C.AccentHi; lbl.Parent=row
    local bg=Instance.new("Frame"); bg.Size=UDim2.new(1,-24,0,8); bg.Position=UDim2.new(0,22,0,3)
    bg.BackgroundColor3=C.Border; bg.Parent=row; mkCorner(4,bg)
    local fill=Instance.new("Frame"); fill.Size=UDim2.new(1,0,1,0)
    fill.BackgroundColor3=C.Accent; fill.Parent=bg; mkCorner(4,fill)
    local pct=Instance.new("TextLabel"); pct.Size=UDim2.new(0,36,1,0); pct.Position=UDim2.new(1,-36,0,0)
    pct.BackgroundTransparency=1; pct.Text="READY"; pct.TextSize=8
    pct.Font=Enum.Font.GothamBold; pct.TextColor3=C.Success; pct.Parent=row
    SkillBars[i]={fill=fill, lbl=pct}
end

-- ── CONTROL BUTTONS (y=422) ──────────────────────────────────
local CtrlSec = Instance.new("Frame")
CtrlSec.Size=UDim2.new(1,0,0,42); CtrlSec.Position=UDim2.new(0,0,0,422)
CtrlSec.BackgroundTransparency=1; CtrlSec.Parent=Content

local StartBtn = mkBtn("▶  START", 14, CtrlSec)
StartBtn.Size=UDim2.new(0.62,0,1,0); StartBtn.BackgroundColor3=C.Success

local StopBtn = mkBtn("■  STOP", 14, CtrlSec)
StopBtn.Size=UDim2.new(0.36,0,1,0); StopBtn.Position=UDim2.new(0.64,0,0,0)
StopBtn.BackgroundColor3=C.Danger

-- ── NOTIFICATION SYSTEM ──────────────────────────────────────
local NotifContainer = Instance.new("Frame")
NotifContainer.Size=UDim2.new(0,300,1,0); NotifContainer.Position=UDim2.new(1,-310,0,0)
NotifContainer.BackgroundTransparency=1; NotifContainer.Parent=ScreenGui
local NotifLayout=Instance.new("UIListLayout")
NotifLayout.SortOrder=Enum.SortOrder.LayoutOrder; NotifLayout.Padding=UDim.new(0,8)
NotifLayout.VerticalAlignment=Enum.VerticalAlignment.Bottom
NotifLayout.Parent=NotifContainer

local notifCount=0
local function notify(title, body, icon, ntype)
    notifCount+=1
    local nc=notifCount
    local bg=Instance.new("Frame")
    bg.Size=UDim2.new(1,0,0,0); bg.BackgroundColor3=C.Panel
    bg.LayoutOrder=-nc; bg.ClipDescendants=true; bg.Parent=NotifContainer
    mkCorner(10,bg); mkStroke(1,C.Border,bg)

    local accent=Instance.new("Frame")
    accent.Size=UDim2.new(0,3,1,0)
    accent.BackgroundColor3= (ntype=="success") and C.Success
                          or (ntype=="danger")  and C.Danger
                          or (ntype=="warn")    and C.Warn
                          or C.Accent
    accent.Parent=bg; mkCorner(2,accent)

    local ico=Instance.new("TextLabel"); ico.Size=UDim2.new(0,32,0,32)
    ico.Position=UDim2.new(0,10,0,10); ico.BackgroundTransparency=1
    ico.Text=icon; ico.TextSize=20; ico.Font=Enum.Font.Gotham; ico.Parent=bg

    local t=Instance.new("TextLabel"); t.Size=UDim2.new(1,-50,0,16)
    t.Position=UDim2.new(0,46,0,8); t.BackgroundTransparency=1
    t.Text=title; t.TextSize=13; t.Font=Enum.Font.GothamBold
    t.TextColor3=C.TextHi; t.TextXAlignment=Enum.TextXAlignment.Left; t.Parent=bg

    local b=Instance.new("TextLabel"); b.Size=UDim2.new(1,-50,0,14)
    b.Position=UDim2.new(0,46,0,26); b.BackgroundTransparency=1
    b.Text=body; b.TextSize=11; b.Font=Enum.Font.Gotham
    b.TextColor3=C.TextMid; b.TextXAlignment=Enum.TextXAlignment.Left; b.Parent=bg

    -- Animate in
    TweenService:Create(bg,TweenInfo.new(.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
        {Size=UDim2.new(1,0,0,52)}):Play()
    task.delay(4, function()
        TweenService:Create(bg,TweenInfo.new(.3),{BackgroundTransparency=1}):Play()
        task.wait(.35); bg:Destroy()
    end)
end

-- ── DROPDOWN LOGIC ───────────────────────────────────────────
local dropOpen = false
local function closeDropdown()
    dropOpen=false
    TweenService:Create(DropList,TweenInfo.new(.2),{Size=UDim2.new(0,316,0,0)}):Play()
    task.delay(.2,function() DropList.Visible=false end)
end
local function openDropdown()
    -- Position relative to DropBtn
    local abs = DropBtn.AbsolutePosition
    DropList.Position=UDim2.new(0,abs.X,0,abs.Y+30)
    DropList.Visible=true
    local items = #DropScroll:GetChildren()-1  -- minus layout
    local h = math.min(items*32, 160)
    TweenService:Create(DropList,TweenInfo.new(.2,Enum.EasingStyle.Quad),
        {Size=UDim2.new(0,316,0,h)}):Play()
    dropOpen=true
end

local function populateDropdown()
    for _,c in ipairs(DropScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for _,t in ipairs(ScannedTargets) do
        local btn=Instance.new("TextButton")
        btn.Size=UDim2.new(1,0,0,30); btn.BackgroundTransparency=1
        btn.Text=(t.isPlayer and "👤 " or "🤖 ")..t.name
        btn.TextSize=12; btn.Font=Enum.Font.Gotham
        btn.TextColor3=C.TextHi; btn.TextXAlignment=Enum.TextXAlignment.Left
        local lp=Instance.new("UIPadding"); lp.PaddingLeft=UDim.new(0,10); lp.Parent=btn
        btn.Parent=DropScroll
        btn.MouseEnter:Connect(function()
            btn.BackgroundTransparency=0; btn.BackgroundColor3=C.Border
        end)
        btn.MouseLeave:Connect(function() btn.BackgroundTransparency=1 end)
        btn.MouseButton1Click:Connect(function()
            State.Target = t.model
            TargetNameLbl.Text = t.name
            DropBtn.Text = "▾  "..t.name
            if t.isPlayer then
                TargetIcon.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="
                    ..t.player.UserId.."&width=48&height=48&format=png"
            else
                TargetIcon.Image = ""
            end
            notify("🎯 Target Set", t.name, "🎯","accent")
            closeDropdown()
        end)
    end
    DropScroll.CanvasSize=UDim2.new(0,0,0,#ScannedTargets*30)
end

DropBtn.MouseButton1Click:Connect(function()
    if dropOpen then closeDropdown()
    else scanTargets(); populateDropdown(); openDropdown() end
end)

ScanBtn.MouseButton1Click:Connect(function()
    scanTargets()
    populateDropdown()
    ScanStatusLbl.Text = "Found: "..#ScannedTargets.." target(s)"
    notify("🔍 Scan Complete", #ScannedTargets.." target(s) found","🔍","accent")
end)

ClearBtn.MouseButton1Click:Connect(function()
    State.Target=nil; State.Running=false
    TargetNameLbl.Text="No Target"; TargetHPLbl.Text="HP: — | Dist: —"
    HPBar.Size=UDim2.new(0,0,1,0); DropBtn.Text="▾  Select Target..."
    TargetIcon.Image=""
    notify("✕ Target Cleared","No target selected","❌","danger")
end)

-- ============================================================
-- COMBAT ENGINE
-- ============================================================

local function teleportTo(pos)
    local root = getRoot()
    if root then root.CFrame = CFrame.new(pos) end
end

local function tweenTo(targetPos, onDone)
    local root = getRoot()
    if not root then if onDone then onDone() end; return end
    local d = (root.Position - targetPos).Magnitude
    local t = TweenInfo.new(d/CFG.ChaseSpeed, Enum.EasingStyle.Linear)
    local tw = TweenService:Create(root, t, {CFrame=CFrame.new(targetPos)})
    tw:Play()
    tw.Completed:Connect(function() if onDone then onDone() end end)
end

local function pathTo(targetPos)
    local root = getRoot()
    if not root then return end
    local path = PathfindingService:CreatePath({
        AgentRadius=2, AgentHeight=5,
        AgentCanJump=true, AgentCanClimb=true,
        WaypointSpacing=4
    })
    local ok, err = pcall(function() path:ComputeAsync(root.Position, targetPos) end)
    if ok and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for _, wp in ipairs(waypoints) do
            if not State.Running then break end
            if wp.Action == Enum.PathWaypointAction.Jump then
                local hum = getHum(getChar())
                if hum then hum.Jump=true end
            end
            tweenTo(wp.Position)
            task.wait(0.15)
        end
    else
        -- Fallback: direct tween
        tweenTo(targetPos)
    end
end

local function isInRange(range)
    local root = getRoot()
    local thrp  = getHRP(State.Target)
    if not root or not thrp then return false end
    return (root.Position-thrp.Position).Magnitude <= range
end

local function lookAtTarget()
    local root = getRoot()
    local thrp  = getHRP(State.Target)
    if root and thrp then
        root.CFrame = CFrame.lookAt(root.Position, thrp.Position)
    end
end

local function doPunch()
    local now = tick()
    if now - State.PunchLast < CFG.PunchCooldown then return false end
    if not isInRange(CFG.PunchRange) then return false end
    lookAtTarget()
    fireClick()
    State.PunchLast = now
    return true
end

local function doSkill(id)
    local now = tick()
    local cd = CFG.SkillCooldowns[id]
    if now - State.SkillLast[id] < cd then return false end
    if not isInRange(CFG.SkillRanges[id]) then return false end
    lookAtTarget()
    local key = ({
        [1]=Enum.KeyCode.One, [2]=Enum.KeyCode.Two,
        [3]=Enum.KeyCode.Three, [4]=Enum.KeyCode.Four
    })[id]
    fireKey(key)
    State.SkillLast[id] = now
    State.TotalDmg += CFG.SkillDamageEst[id]
    return true
end

-- Smart combo: pick best available skill then punch
local function smartCombo()
    -- priority: 4>3>2>1>punch
    local now = tick()
    for id=4,1,-1 do
        if now-State.SkillLast[id] >= CFG.SkillCooldowns[id] then
            if doSkill(id) then return end
        end
    end
    doPunch()
end

-- Orbit position
local orbitAngle = 0
local function orbitTarget()
    local thrp = getHRP(State.Target)
    if not thrp then return end
    orbitAngle += CFG.OrbitSpeed * 0.05
    local ox = math.cos(orbitAngle)*CFG.OrbitRadius
    local oz = math.sin(orbitAngle)*CFG.OrbitRadius
    local goal = thrp.Position + Vector3.new(ox,0,oz)
    local root = getRoot()
    if root then root.CFrame = CFrame.new(goal) end
    lookAtTarget()
    smartCombo()
end

-- Predictive chase
local function predictiveChase()
    local thrp = getHRP(State.Target)
    if not thrp then return end
    local hum  = getHum(State.Target)
    local vel  = (hum and hum.MoveDirection or Vector3.zero)
    local predicted = thrp.Position + vel * 1.5
    pathTo(predicted)
end

-- Check if target is stuck / running away
local function detectEscape()
    local thrp = getHRP(State.Target)
    if not thrp then return false end
    local root = getRoot()
    if not root then return false end
    local d = dist(root, thrp)
    return d > CFG.OrbitRadius * 4
end

-- HP update
local function updateHP()
    if not State.Target then return end
    local hum = getHum(State.Target)
    if hum then
        local hp   = math.floor(hum.Health)
        local maxhp= math.floor(hum.MaxHealth)
        local pct  = hp/math.max(maxhp,1)
        TargetHPLbl.Text = "HP: "..hp.."/"..maxhp.." | Dist: "..
            math.floor(dist(getRoot(), getHRP(State.Target))).."st"
        TweenService:Create(HPBar,TweenInfo.new(.3),{Size=UDim2.new(pct,0,1,0)}):Play()
        HPBar.BackgroundColor3 = pct>0.5 and C.Success or pct>0.25 and C.Warn or C.Danger
    end
end

-- Skill bar update
local function updateSkillBars()
    local now = tick()
    for i=1,4 do
        local cd  = CFG.SkillCooldowns[i]
        local ela = now - State.SkillLast[i]
        local pct = math.clamp(ela/cd, 0, 1)
        TweenService:Create(SkillBars[i].fill,TweenInfo.new(.1),
            {Size=UDim2.new(pct,0,1,0)}):Play()
        if pct >= 1 then
            SkillBars[i].lbl.Text="READY"; SkillBars[i].lbl.TextColor3=C.Success
        else
            SkillBars[i].lbl.Text=string.format("%.1fs", cd-ela)
            SkillBars[i].lbl.TextColor3=C.Warn
        end
    end
    -- Stat labels
    StatLabels["dmg"].val.Text  = tostring(State.TotalDmg)
    StatLabels["kills"].val.Text= tostring(State.KillCount)
    -- Next available skill
    local minCD = math.huge
    for i=1,4 do
        local rem = CFG.SkillCooldowns[i]-(now-State.SkillLast[i])
        if rem < minCD then minCD=rem end
    end
    StatLabels["cd"].val.Text = minCD<=0 and "NOW" or string.format("%.1fs",minCD)
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local function combatLoop()
    while State.Running do
        local target = State.Target
        if not target then task.wait(0.2); continue end

        -- Dead?
        if not isAlive(target) then
            State.KillCount+=1
            notify("💀 Target Killed!", target.Name, "💀","success")
            State.Target=nil
            TargetNameLbl.Text="No Target"; TargetHPLbl.Text="HP: — | Dist: —"
            HPBar.Size=UDim2.new(0,0,1,0)
            task.wait(1); continue
        end

        updateHP()

        local thrp = getHRP(target)
        local root  = getRoot()
        if not thrp or not root then task.wait(0.2); continue end

        local d = dist(root, thrp)

        if State.Mode == "Orbit" then
            orbitTarget()
        elseif State.Mode == "Chase" then
            predictiveChase()
            if d < CFG.PunchRange then smartCombo() end
        else -- Smart
            if d > CFG.PunchRange + 2 then
                if detectEscape() then
                    -- Predictive
                    predictiveChase()
                else
                    -- Normal path
                    pathTo(thrp.Position + (root.Position-thrp.Position).Unit * (CFG.PunchRange-1))
                end
            else
                smartCombo()
            end
        end

        updateSkillBars()
        task.wait(0.08)
    end
end

-- ============================================================
-- PLAYER LEAVE / ENTER TRACKING
-- ============================================================
Players.PlayerAdded:Connect(function(p)
    notify("👋 Player Joined", p.Name.." entered", "➕","accent")
    p.CharacterAdded:Connect(function(char)
        task.wait(1)
        scanTargets(); populateDropdown()
        ScanStatusLbl.Text="Found: "..#ScannedTargets.." target(s)"
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    notify("🚪 Player Left", p.Name.." left the game","🚪","warn")
    if State.Target and State.Target.Parent==nil then
        State.Target=nil
        notify("❌ Target Lost", p.Name.." disconnected","❌","danger")
        TargetNameLbl.Text="No Target"
    end
    scanTargets(); populateDropdown()
    ScanStatusLbl.Text="Found: "..#ScannedTargets.." target(s)"
end)

-- ============================================================
-- START / STOP
-- ============================================================
StartBtn.MouseButton1Click:Connect(function()
    if not State.Target then
        notify("⚠️ No Target","Select a target first!","⚠️","warn")
        return
    end
    if State.Running then return end
    State.Running = true
    TweenService:Create(StartBtn,TweenInfo.new(.2),{BackgroundColor3=C.TextLow}):Play()
    notify("▶ Script Started","Targeting: "..State.Target.Name,"▶","success")
    task.spawn(combatLoop)
end)

StopBtn.MouseButton1Click:Connect(function()
    State.Running=false
    TweenService:Create(StartBtn,TweenInfo.new(.2),{BackgroundColor3=C.Success}):Play()
    notify("■ Script Stopped","Combat paused","■","danger")
end)

-- ============================================================
-- KEYBOARD SHORTCUTS
-- ============================================================
UserInputService.InputBegan:Connect(function(inp, gp)
    if gp then return end
    -- F1: toggle UI
    if inp.KeyCode==Enum.KeyCode.F1 then
        MainFrame.Visible = not MainFrame.Visible
    end
    -- F2: scan
    if inp.KeyCode==Enum.KeyCode.F2 then
        scanTargets(); populateDropdown()
        ScanStatusLbl.Text="Found: "..#ScannedTargets.." target(s)"
    end
    -- Delete: stop
    if inp.KeyCode==Enum.KeyCode.Delete then
        State.Running=false
        notify("■ Stopped","Hotkey: DELETE","■","danger")
    end
end)

-- ============================================================
-- NOCLIP (opsiyonel, CFG.NoclipEnabled)
-- ============================================================
if CFG.NoclipEnabled then
    RunService.Stepped:Connect(function()
        local char = getChar()
        if char then
            for _,p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide=false end
            end
        end
    end)
end

-- ============================================================
-- INITIAL SCAN
-- ============================================================
task.delay(2, function()
    scanTargets(); populateDropdown()
    ScanStatusLbl.Text="Found: "..#ScannedTargets.." target(s)"
    notify("⚡ JJS Target", "Script loaded! v2.0","⚡","success")
end)

-- Auto re-scan every CFG.ScanInterval * 10 seconds
task.spawn(function()
    while true do
        task.wait(CFG.ScanInterval * 10)
        if not State.Running then
            local prev = #ScannedTargets
            scanTargets()
            if #ScannedTargets ~= prev then
                populateDropdown()
                ScanStatusLbl.Text="Found: "..#ScannedTargets.." target(s)"
            end
        end
    end
end)

-- ============================================================
print("[JJS Target v2.0] Loaded | F1=Toggle UI | F2=Scan | DEL=Stop")
