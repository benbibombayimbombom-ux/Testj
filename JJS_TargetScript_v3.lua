-- ╔══════════════════════════════════════════════════════════╗
-- ║     JJS TARGET SYSTEM v3.0  |  Mobile + PC Full          ║
-- ║     Jujutsu Shenanigans  —  Smart Combat Script          ║
-- ║     LocalScript → StarterPlayerScripts                   ║
-- ╚══════════════════════════════════════════════════════════╝

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local GuiService         = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

-- ============================================================
-- DEVICE DETECTION
-- ============================================================
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Responsive scale: telefon için büyük, PC için normal
local S = IsMobile and {
    UIW=320, UIH=520,
    TopH=52, BtnH=44, BtnFont=15,
    SmallFont=13, TinyFont=11,
    IconSize=44, Pad=12, Radius=14,
    ChipW=80, ChipH=30,
} or {
    UIW=340, UIH=480,
    TopH=44, BtnH=32, BtnFont=13,
    SmallFont=12, TinyFont=10,
    IconSize=38, Pad=10, Radius=12,
    ChipW=72, ChipH=24,
}

-- ============================================================
-- CONFIG
-- ============================================================
local CFG = {
    PunchRange     = 6,
    SkillRanges    = {[1]=15,[2]=20,[3]=25,[4]=30},
    SkillCooldowns = {[1]=1.2,[2]=3.0,[3]=5.0,[4]=8.0},
    SkillDamageEst = {[1]=25,[2]=60,[3]=90,[4]=150},
    PunchCooldown  = 0.35,
    ChaseSpeed     = 16,
    OrbitRadius    = 5,
    OrbitSpeed     = 1.5,
    NoclipEnabled  = false,
    ScanInterval   = 10,
    MaxScanDist    = 500,
}

-- ============================================================
-- STATE
-- ============================================================
local State = {
    Running    = false,
    Target     = nil,
    Mode       = "Smart",
    SkillLast  = {[1]=0,[2]=0,[3]=0,[4]=0},
    PunchLast  = 0,
    TotalDmg   = 0,
    KillCount  = 0,
}

-- ============================================================
-- PALETTE
-- ============================================================
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
    LoadBG   = Color3.fromHex("#05070D"),
}

-- ============================================================
-- HELPERS
-- ============================================================
local function mkCorner(r,p) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r);c.Parent=p end
local function mkStroke(t,col,p) local s=Instance.new("UIStroke");s.Thickness=t;s.Color=col;s.Parent=p end
local function mkPad(l,r,t,b,p)
    local pad=Instance.new("UIPadding")
    pad.PaddingLeft=UDim.new(0,l);pad.PaddingRight=UDim.new(0,r)
    pad.PaddingTop=UDim.new(0,t);pad.PaddingBottom=UDim.new(0,b)
    pad.Parent=p
end

local function getChar()  return LocalPlayer.Character end
local function getRoot()  local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHRP(m)  return m and m:FindFirstChild("HumanoidRootPart") end
local function getHum(m)  return m and m:FindFirstChildOfClass("Humanoid") end
local function dist(a,b)  if not a or not b then return math.huge end; return (a.Position-b.Position).Magnitude end
local function isAlive(m) local h=getHum(m); return h and h.Health>0 end

-- Mobile-safe input
local function fireKey(key)
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, key, false, game); task.wait(0.05)
        vim:SendKeyEvent(false, key, false, game)
    end)
end
local function fireClick()
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(Mouse.X,Mouse.Y,0,true,game,0); task.wait(0.05)
        vim:SendMouseButtonEvent(Mouse.X,Mouse.Y,0,false,game,0)
    end)
end

-- ============================================================
-- SCREEN GUI
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name="JJS_TargetUI_v3"; ScreenGui.ResetOnSpawn=false
ScreenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset=true
ScreenGui.Parent=LocalPlayer.PlayerGui

-- ============================================================
-- ░░░  LOADING SCREEN  ░░░
-- ============================================================
local LoadScreen = Instance.new("Frame")
LoadScreen.Size=UDim2.new(1,0,1,0); LoadScreen.BackgroundColor3=C.LoadBG
LoadScreen.ZIndex=100; LoadScreen.Parent=ScreenGui

-- Animated BG grid lines
local GridCanvas = Instance.new("Frame")
GridCanvas.Size=UDim2.new(1,0,1,0); GridCanvas.BackgroundTransparency=1
GridCanvas.ZIndex=100; GridCanvas.Parent=LoadScreen
for i=1,12 do
    local line=Instance.new("Frame")
    line.Size=UDim2.new(0,1,1,0); line.Position=UDim2.new(i/12,0,0,0)
    line.BackgroundColor3=C.Accent; line.BackgroundTransparency=0.9
    line.ZIndex=100; line.Parent=GridCanvas
end
for i=1,8 do
    local line=Instance.new("Frame")
    line.Size=UDim2.new(1,0,0,1); line.Position=UDim2.new(0,0,i/8,0)
    line.BackgroundColor3=C.Accent; line.BackgroundTransparency=0.9
    line.ZIndex=100; line.Parent=GridCanvas
end

-- Center logo container
local LogoFrame=Instance.new("Frame")
LogoFrame.Size=UDim2.new(0,260,0,220); LogoFrame.AnchorPoint=Vector2.new(.5,.5)
LogoFrame.Position=UDim2.new(.5,0,.42,0); LogoFrame.BackgroundTransparency=1
LogoFrame.ZIndex=101; LogoFrame.Parent=LoadScreen

-- Glow ring
local GlowRing=Instance.new("ImageLabel")
GlowRing.Size=UDim2.new(0,200,0,200); GlowRing.AnchorPoint=Vector2.new(.5,.5)
GlowRing.Position=UDim2.new(.5,0,.5,-10); GlowRing.BackgroundTransparency=1
GlowRing.Image="rbxassetid://5028857472"; GlowRing.ImageColor3=C.Accent
GlowRing.ImageTransparency=0.5; GlowRing.ZIndex=101; GlowRing.Parent=LogoFrame

-- Logo icon (lightning)
local LogoIcon=Instance.new("TextLabel")
LogoIcon.Size=UDim2.new(0,80,0,80); LogoIcon.AnchorPoint=Vector2.new(.5,.5)
LogoIcon.Position=UDim2.new(.5,0,.4,0); LogoIcon.BackgroundTransparency=1
LogoIcon.Text="⚡"; LogoIcon.TextSize=64; LogoIcon.Font=Enum.Font.GothamBold
LogoIcon.TextColor3=C.AccentHi; LogoIcon.ZIndex=102; LogoIcon.Parent=LogoFrame

-- Title
local LoadTitle=Instance.new("TextLabel")
LoadTitle.Size=UDim2.new(1,0,0,36); LoadTitle.Position=UDim2.new(0,0,0,130)
LoadTitle.BackgroundTransparency=1; LoadTitle.Text="JJS TARGET"
LoadTitle.TextSize=28; LoadTitle.Font=Enum.Font.GothamBold
LoadTitle.TextColor3=C.TextHi; LoadTitle.ZIndex=102; LoadTitle.Parent=LogoFrame

local LoadSub=Instance.new("TextLabel")
LoadSub.Size=UDim2.new(1,0,0,20); LoadSub.Position=UDim2.new(0,0,0,166)
LoadSub.BackgroundTransparency=1; LoadSub.Text="Smart Combat System v3.0"
LoadSub.TextSize=13; LoadSub.Font=Enum.Font.Gotham
LoadSub.TextColor3=C.Accent; LoadSub.ZIndex=102; LoadSub.Parent=LogoFrame

-- Progress bar
local PBarBG=Instance.new("Frame")
PBarBG.Size=UDim2.new(0,260,0,6); PBarBG.AnchorPoint=Vector2.new(.5,0)
PBarBG.Position=UDim2.new(.5,0,.62,0); PBarBG.BackgroundColor3=C.Card
PBarBG.ZIndex=101; PBarBG.Parent=LoadScreen; mkCorner(3,PBarBG)

local PBarFill=Instance.new("Frame")
PBarFill.Size=UDim2.new(0,0,1,0); PBarFill.BackgroundColor3=C.Accent
PBarFill.ZIndex=102; PBarFill.Parent=PBarBG; mkCorner(3,PBarFill)

-- Progress glow
local PBarGlow=Instance.new("Frame")
PBarGlow.Size=UDim2.new(0,20,3,0); PBarGlow.Position=UDim2.new(0,-10,-.5,0)
PBarGlow.BackgroundColor3=C.AccentHi; PBarGlow.BackgroundTransparency=0.6
PBarGlow.ZIndex=103; PBarGlow.Parent=PBarFill; mkCorner(10,PBarGlow)

-- Status text
local LoadStatus=Instance.new("TextLabel")
LoadStatus.Size=UDim2.new(0,260,0,20); LoadStatus.AnchorPoint=Vector2.new(.5,0)
LoadStatus.Position=UDim2.new(.5,0,.66,0); LoadStatus.BackgroundTransparency=1
LoadStatus.Text="Initializing..."; LoadStatus.TextSize=12; LoadStatus.Font=Enum.Font.Gotham
LoadStatus.TextColor3=C.TextMid; LoadStatus.ZIndex=101; LoadStatus.Parent=LoadScreen

-- Version badge
local VerBadge=Instance.new("TextLabel")
VerBadge.Size=UDim2.new(0,120,0,18); VerBadge.AnchorPoint=Vector2.new(.5,0)
VerBadge.Position=UDim2.new(.5,0,.78,0); VerBadge.BackgroundTransparency=1
VerBadge.Text=(IsMobile and "📱 Mobile Mode" or "🖥️ PC Mode").." | v3.0"
VerBadge.TextSize=11; VerBadge.Font=Enum.Font.GothamBold
VerBadge.TextColor3=C.TextLow; VerBadge.ZIndex=101; VerBadge.Parent=LoadScreen

-- Loading steps
local loadSteps = {
    {t="Scanning workspace...",    p=0.15},
    {t="Building UI components...", p=0.35},
    {t="Initializing combat AI...", p=0.55},
    {t="Loading mobile input...",   p=0.72},
    {t="Connecting scanner...",     p=0.88},
    {t="Ready!",                    p=1.0},
}

-- Pulse animation on icon
task.spawn(function()
    while LoadScreen.Parent do
        TweenService:Create(GlowRing,TweenInfo.new(1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
            {ImageTransparency=0.2,Size=UDim2.new(0,220,0,220)}):Play()
        task.wait(1)
        TweenService:Create(GlowRing,TweenInfo.new(1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
            {ImageTransparency=0.6,Size=UDim2.new(0,180,0,180)}):Play()
        task.wait(1)
    end
end)

local function runLoadingSequence(onComplete)
    task.spawn(function()
        for i,step in ipairs(loadSteps) do
            LoadStatus.Text = step.t
            TweenService:Create(PBarFill,TweenInfo.new(.4,Enum.EasingStyle.Quad),
                {Size=UDim2.new(step.p,0,1,0)}):Play()
            task.wait(0.38)
        end
        task.wait(0.3)
        -- Fade out
        TweenService:Create(LoadScreen,TweenInfo.new(.6,Enum.EasingStyle.Quad),
            {BackgroundTransparency=1}):Play()
        for _,d in ipairs(LoadScreen:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("Frame") or d:IsA("ImageLabel") then
                pcall(function()
                    TweenService:Create(d,TweenInfo.new(.5),
                        {BackgroundTransparency=1,TextTransparency=1,ImageTransparency=1}):Play()
                end)
            end
        end
        task.wait(.65)
        LoadScreen:Destroy()
        if onComplete then onComplete() end
    end)
end

-- ============================================================
-- MAIN UI (built after loading, passed via callback)
-- ============================================================
local ScannedTargets = {}
local DropOpen = false
local Minimized = false

local function buildMainUI()

    -- ── MAIN FRAME ──────────────────────────────────────────
    local Main = Instance.new("Frame")
    Main.Name="JJS_Main"
    -- Mobile: sağ üst köşe / PC: sol üst
    if IsMobile then
        Main.Size=UDim2.new(0,S.UIW,0,S.UIH)
        Main.Position=UDim2.new(1,-S.UIW-8,0,70)
    else
        Main.Size=UDim2.new(0,S.UIW,0,S.UIH)
        Main.Position=UDim2.new(0,20,0,60)
    end
    Main.BackgroundColor3=C.BG; Main.ClipDescendants=false
    Main.Parent=ScreenGui; mkCorner(S.Radius,Main); mkStroke(1.5,C.Border,Main)

    -- Accent glow
    local Glow=Instance.new("ImageLabel")
    Glow.Size=UDim2.new(1,80,1,80); Glow.Position=UDim2.new(0,-40,0,-40)
    Glow.BackgroundTransparency=1; Glow.ZIndex=0
    Glow.Image="rbxassetid://5028857472"
    Glow.ImageColor3=C.Accent; Glow.ImageTransparency=0.85; Glow.Parent=Main

    -- ── TOPBAR ──────────────────────────────────────────────
    local Top=Instance.new("Frame")
    Top.Size=UDim2.new(1,0,0,S.TopH); Top.BackgroundColor3=C.Panel; Top.Parent=Main
    mkCorner(S.Radius,Top)
    local TopFix=Instance.new("Frame"); TopFix.Size=UDim2.new(1,0,0,S.Radius)
    TopFix.Position=UDim2.new(0,0,1,-S.Radius); TopFix.BackgroundColor3=C.Panel
    TopFix.BorderSizePixel=0; TopFix.Parent=Top

    local TitleLbl=Instance.new("TextLabel")
    TitleLbl.Size=UDim2.new(1,-90,1,0); TitleLbl.Position=UDim2.new(0,12,0,0)
    TitleLbl.BackgroundTransparency=1; TitleLbl.Text="⚡ JJS TARGET"
    TitleLbl.TextSize=IsMobile and 16 or 14; TitleLbl.Font=Enum.Font.GothamBold
    TitleLbl.TextColor3=C.TextHi; TitleLbl.TextXAlignment=Enum.TextXAlignment.Left
    TitleLbl.Parent=Top

    local SubLbl=Instance.new("TextLabel")
    SubLbl.Size=UDim2.new(1,-90,0,14); SubLbl.Position=UDim2.new(0,12,1,-18)
    SubLbl.BackgroundTransparency=1; SubLbl.Text=(IsMobile and "📱" or "🖥️").." v3.0"
    SubLbl.TextSize=10; SubLbl.Font=Enum.Font.Gotham
    SubLbl.TextColor3=C.Accent; SubLbl.TextXAlignment=Enum.TextXAlignment.Left
    SubLbl.Parent=Top

    local function topBtn(txt,color,xOff)
        local b=Instance.new("TextButton")
        local bSize=IsMobile and 30 or 26
        b.Size=UDim2.new(0,bSize,0,bSize)
        b.Position=UDim2.new(1,-xOff,0.5,-bSize/2)
        b.BackgroundColor3=color; b.Text=txt
        b.TextSize=IsMobile and 14 or 12; b.Font=Enum.Font.GothamBold
        b.TextColor3=C.TextHi; b.Parent=Top; mkCorner(8,b)
        return b
    end
    local CloseBtn=topBtn("✕",C.Danger, IsMobile and 40 or 36)
    local MinBtn  =topBtn("–",C.TextLow,IsMobile and 76 or 68)

    -- ── DRAG ────────────────────────────────────────────────
    do
        local dragging,dragStart,startPos
        Top.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1
            or inp.UserInputType==Enum.UserInputType.Touch then
                dragging=true; dragStart=inp.Position; startPos=Main.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement
            or inp.UserInputType==Enum.UserInputType.Touch) then
                local d=inp.Position-dragStart
                Main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,
                    startPos.Y.Scale,startPos.Y.Offset+d.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1
            or inp.UserInputType==Enum.UserInputType.Touch then dragging=false end
        end)
    end

    -- ── CONTENT ─────────────────────────────────────────────
    local Content=Instance.new("ScrollingFrame")
    Content.Size=UDim2.new(1,0,1,-S.TopH); Content.Position=UDim2.new(0,0,0,S.TopH)
    Content.BackgroundTransparency=1; Content.ScrollBarThickness=2
    Content.ScrollBarImageColor3=C.Accent; Content.CanvasSize=UDim2.new(0,0,0,0)
    Content.ClipDescendants=true; Content.Parent=Main
    mkPad(S.Pad,S.Pad,8,8,Content)

    local ContentLayout=Instance.new("UIListLayout")
    ContentLayout.SortOrder=Enum.SortOrder.LayoutOrder
    ContentLayout.Padding=UDim.new(0,8); ContentLayout.Parent=Content
    ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Content.CanvasSize=UDim2.new(0,0,0,ContentLayout.AbsoluteContentSize.Y+16)
    end)

    -- Card helper
    local function mkCard(title, h, order)
        local f=Instance.new("Frame")
        f.Size=UDim2.new(1,0,0,h); f.BackgroundColor3=C.Card
        f.LayoutOrder=order; f.Parent=Content; mkCorner(10,f); mkStroke(1,C.Border,f)
        if title then
            local lbl=Instance.new("TextLabel")
            lbl.Size=UDim2.new(1,-10,0,16); lbl.Position=UDim2.new(0,8,0,6)
            lbl.BackgroundTransparency=1; lbl.Text=title
            lbl.TextSize=10; lbl.Font=Enum.Font.GothamBold
            lbl.TextColor3=C.AccentHi; lbl.TextXAlignment=Enum.TextXAlignment.Left
            lbl.Parent=f
        end
        return f
    end

    -- ── CARD 1: TARGET INFO ──────────────────────────────────
    local TargetCard=mkCard("TARGET",88,1)

    local TargetIcon=Instance.new("ImageLabel")
    TargetIcon.Size=UDim2.new(0,S.IconSize,0,S.IconSize)
    TargetIcon.Position=UDim2.new(0,8,0,24); TargetIcon.BackgroundColor3=C.Border
    TargetIcon.Image=""; TargetIcon.Parent=TargetCard; mkCorner(8,TargetIcon)

    local TargetNameLbl=Instance.new("TextLabel")
    TargetNameLbl.Size=UDim2.new(1,-S.IconSize-20,0,20)
    TargetNameLbl.Position=UDim2.new(0,S.IconSize+16,0,24)
    TargetNameLbl.BackgroundTransparency=1; TargetNameLbl.Text="No Target"
    TargetNameLbl.TextSize=IsMobile and 15 or 13; TargetNameLbl.Font=Enum.Font.GothamBold
    TargetNameLbl.TextColor3=C.TextHi; TargetNameLbl.TextXAlignment=Enum.TextXAlignment.Left
    TargetNameLbl.Parent=TargetCard

    local TargetHPLbl=Instance.new("TextLabel")
    TargetHPLbl.Size=UDim2.new(1,-S.IconSize-20,0,14)
    TargetHPLbl.Position=UDim2.new(0,S.IconSize+16,0,46)
    TargetHPLbl.BackgroundTransparency=1; TargetHPLbl.Text="HP: — | Dist: —"
    TargetHPLbl.TextSize=IsMobile and 12 or 10; TargetHPLbl.Font=Enum.Font.Gotham
    TargetHPLbl.TextColor3=C.TextMid; TargetHPLbl.TextXAlignment=Enum.TextXAlignment.Left
    TargetHPLbl.Parent=TargetCard

    local HPBarBG=Instance.new("Frame")
    HPBarBG.Size=UDim2.new(1,-16,0,IsMobile and 7 or 5); HPBarBG.Position=UDim2.new(0,8,0,74)
    HPBarBG.BackgroundColor3=C.Border; HPBarBG.Parent=TargetCard; mkCorner(3,HPBarBG)
    local HPBar=Instance.new("Frame"); HPBar.Size=UDim2.new(0,0,1,0)
    HPBar.BackgroundColor3=C.Success; HPBar.Parent=HPBarBG; mkCorner(3,HPBar)

    -- ── CARD 2: SCANNER ──────────────────────────────────────
    local ScanCard=mkCard("PLAYER & NPC SCANNER",148,2)

    -- Dropdown button
    local DropBtn=Instance.new("TextButton")
    DropBtn.Size=UDim2.new(1,-16,0,S.BtnH); DropBtn.Position=UDim2.new(0,8,0,24)
    DropBtn.BackgroundColor3=C.Border; DropBtn.Text="▾  Select Target..."
    DropBtn.TextSize=S.SmallFont; DropBtn.Font=Enum.Font.Gotham
    DropBtn.TextColor3=C.TextMid; DropBtn.TextXAlignment=Enum.TextXAlignment.Left
    DropBtn.Parent=ScanCard; mkCorner(8,DropBtn); mkStroke(1,C.Border,DropBtn)
    mkPad(10,0,0,0,DropBtn)

    -- Dropdown list
    local DropList=Instance.new("Frame")
    DropList.Size=UDim2.new(0,S.UIW-16,0,0)
    DropList.BackgroundColor3=C.Panel; DropList.ClipDescendants=true
    DropList.Visible=false; DropList.ZIndex=20; DropList.Parent=ScreenGui
    mkCorner(10,DropList); mkStroke(1,C.Accent,DropList)

    local DropScroll=Instance.new("ScrollingFrame")
    DropScroll.Size=UDim2.new(1,0,1,0); DropScroll.BackgroundTransparency=1
    DropScroll.ScrollBarThickness=3; DropScroll.CanvasSize=UDim2.new(0,0,0,0)
    DropScroll.Parent=DropList
    local DropLayout=Instance.new("UIListLayout")
    DropLayout.SortOrder=Enum.SortOrder.LayoutOrder; DropLayout.Parent=DropScroll

    -- Scan + Clear row
    local BtnRow=Instance.new("Frame")
    BtnRow.Size=UDim2.new(1,-16,0,S.BtnH); BtnRow.Position=UDim2.new(0,8,0,24+S.BtnH+8)
    BtnRow.BackgroundTransparency=1; BtnRow.Parent=ScanCard
    local RowLayout=Instance.new("UIListLayout")
    RowLayout.FillDirection=Enum.FillDirection.Horizontal
    RowLayout.Padding=UDim.new(0,8); RowLayout.Parent=BtnRow

    local function rowBtn(txt,col)
        local b=Instance.new("TextButton")
        b.Size=UDim2.new(0.5,-4,1,0); b.Text=txt
        b.TextSize=S.SmallFont; b.Font=Enum.Font.GothamBold
        b.TextColor3=C.TextHi; b.BackgroundColor3=col
        b.AutoButtonColor=false; b.Parent=BtnRow; mkCorner(8,b)
        b.MouseEnter:Connect(function()
            TweenService:Create(b,TweenInfo.new(.15),
                {BackgroundColor3=col:Lerp(Color3.new(1,1,1),.15)}):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b,TweenInfo.new(.15),{BackgroundColor3=col}):Play()
        end)
        return b
    end
    local ScanBtn  = rowBtn("🔍 Scan",  C.Accent)
    local ClearBtn = rowBtn("✕ Clear", C.Danger)

    local ScanStatusLbl=Instance.new("TextLabel")
    ScanStatusLbl.Size=UDim2.new(1,-16,0,16)
    ScanStatusLbl.Position=UDim2.new(0,8,0,24+S.BtnH+8+S.BtnH+6)
    ScanStatusLbl.BackgroundTransparency=1; ScanStatusLbl.Text="Scan to find targets"
    ScanStatusLbl.TextSize=S.TinyFont; ScanStatusLbl.Font=Enum.Font.Gotham
    ScanStatusLbl.TextColor3=C.TextMid; ScanStatusLbl.TextXAlignment=Enum.TextXAlignment.Left
    ScanStatusLbl.Parent=ScanCard

    -- Mode chips
    local ModeRow=Instance.new("Frame")
    ModeRow.Size=UDim2.new(1,-16,0,S.ChipH)
    ModeRow.Position=UDim2.new(0,8,0,24+S.BtnH+8+S.BtnH+8+18)
    ModeRow.BackgroundTransparency=1; ModeRow.Parent=ScanCard
    local ModeLayout=Instance.new("UIListLayout")
    ModeLayout.FillDirection=Enum.FillDirection.Horizontal
    ModeLayout.Padding=UDim.new(0,6); ModeLayout.Parent=ModeRow

    local ModeChips={}
    for _,m in ipairs({"Smart","Orbit","Chase"}) do
        local chip=Instance.new("TextButton")
        chip.Size=UDim2.new(0,S.ChipW,1,0); chip.Text=m
        chip.TextSize=S.TinyFont+1; chip.Font=Enum.Font.GothamBold
        chip.AutoButtonColor=false
        chip.BackgroundColor3=(m=="Smart") and C.Accent or C.Border
        chip.TextColor3=C.TextHi; chip.Parent=ModeRow; mkCorner(S.ChipH/2,chip)
        ModeChips[m]=chip
        chip.MouseButton1Click:Connect(function()
            State.Mode=m
            for _,c in pairs(ModeChips) do
                TweenService:Create(c,TweenInfo.new(.15),{BackgroundColor3=C.Border}):Play()
            end
            TweenService:Create(chip,TweenInfo.new(.15),{BackgroundColor3=C.Accent}):Play()
        end)
    end

    -- ── CARD 3: COMBAT STATS ─────────────────────────────────
    local StatCard=mkCard("COMBAT STATS",68,3)
    local statDef={{k="dmg",l="Total Dmg",v="0",c=C.Danger},
                   {k="kil",l="Kills",    v="0",c=C.AccentHi},
                   {k="cd", l="Next Skill",v="--",c=C.Warn}}
    local StatLabels={}
    for i,s in ipairs(statDef) do
        local col=Instance.new("Frame")
        col.Size=UDim2.new(0.333,0,1,-20); col.Position=UDim2.new((i-1)*0.333,0,0,20)
        col.BackgroundTransparency=1; col.Parent=StatCard
        local vl=Instance.new("TextLabel"); vl.Size=UDim2.new(1,0,0,22)
        vl.BackgroundTransparency=1; vl.Text=s.v; vl.TextSize=IsMobile and 18 or 16
        vl.Font=Enum.Font.GothamBold; vl.TextColor3=s.c; vl.Parent=col
        local kl=Instance.new("TextLabel"); kl.Size=UDim2.new(1,0,0,12); kl.Position=UDim2.new(0,0,0,22)
        kl.BackgroundTransparency=1; kl.Text=s.l; kl.TextSize=9
        kl.Font=Enum.Font.Gotham; kl.TextColor3=C.TextLow; kl.Parent=col
        StatLabels[s.k]={val=vl}
    end

    -- ── CARD 4: SKILL COOLDOWNS ──────────────────────────────
    local SkillCard=mkCard("SKILL COOLDOWNS",IsMobile and 100 or 90,4)
    local SkillBars={}
    for i=1,4 do
        local rowH=IsMobile and 20 or 16
        local row=Instance.new("Frame")
        row.Size=UDim2.new(1,-16,0,rowH); row.Position=UDim2.new(0,8,0,18+(i-1)*(rowH+3))
        row.BackgroundTransparency=1; row.Parent=SkillCard
        local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0,22,1,0)
        lbl.BackgroundTransparency=1; lbl.Text="["..i.."]"; lbl.TextSize=11
        lbl.Font=Enum.Font.GothamBold; lbl.TextColor3=C.AccentHi; lbl.Parent=row
        local bg=Instance.new("Frame"); bg.Size=UDim2.new(1,-58,0,IsMobile and 10 or 8)
        bg.Position=UDim2.new(0,24,0,IsMobile and 5 or 4)
        bg.BackgroundColor3=C.Border; bg.Parent=row; mkCorner(4,bg)
        local fill=Instance.new("Frame"); fill.Size=UDim2.new(1,0,1,0)
        fill.BackgroundColor3=C.Accent; fill.Parent=bg; mkCorner(4,fill)
        local pct=Instance.new("TextLabel"); pct.Size=UDim2.new(0,38,1,0)
        pct.Position=UDim2.new(1,-36,0,0); pct.BackgroundTransparency=1
        pct.Text="READY"; pct.TextSize=9; pct.Font=Enum.Font.GothamBold
        pct.TextColor3=C.Success; pct.Parent=row
        SkillBars[i]={fill=fill,lbl=pct}
    end

    -- ── CARD 5: MOBILE SKILL BUTTONS (sadece mobilse) ────────
    local MobileSkillBtns = {}
    if IsMobile then
        local MSkillCard=mkCard("QUICK SKILLS",80,5)
        local mRow=Instance.new("Frame")
        mRow.Size=UDim2.new(1,-16,0,48); mRow.Position=UDim2.new(0,8,0,24)
        mRow.BackgroundTransparency=1; mRow.Parent=MSkillCard
        local mLayout=Instance.new("UIListLayout")
        mLayout.FillDirection=Enum.FillDirection.Horizontal
        mLayout.Padding=UDim.new(0,6); mLayout.Parent=mRow
        for i=1,4 do
            local sb=Instance.new("TextButton")
            sb.Size=UDim2.new(0.25,-5,1,0); sb.Text="["..i.."]"
            sb.TextSize=16; sb.Font=Enum.Font.GothamBold
            sb.TextColor3=C.TextHi; sb.BackgroundColor3=C.Card
            sb.AutoButtonColor=false; sb.Parent=mRow; mkCorner(8,sb)
            mkStroke(1.5,C.Accent,sb)
            MobileSkillBtns[i]=sb
            sb.MouseButton1Click:Connect(function()
                local keyEnum={Enum.KeyCode.One,Enum.KeyCode.Two,
                               Enum.KeyCode.Three,Enum.KeyCode.Four}
                fireKey(keyEnum[i])
                TweenService:Create(sb,TweenInfo.new(.1),
                    {BackgroundColor3=C.Accent}):Play()
                task.delay(.15,function()
                    TweenService:Create(sb,TweenInfo.new(.2),
                        {BackgroundColor3=C.Card}):Play()
                end)
            end)
        end

        -- Mobile punch button
        local PunchLbl=Instance.new("TextLabel")
        PunchLbl.Size=UDim2.new(1,-16,0,14); PunchLbl.Position=UDim2.new(0,8,0,74)
        PunchLbl.BackgroundTransparency=1; PunchLbl.Text="Tap skills above to manually trigger | Auto handled in combat"
        PunchLbl.TextSize=9; PunchLbl.Font=Enum.Font.Gotham
        PunchLbl.TextColor3=C.TextLow; PunchLbl.TextXAlignment=Enum.TextXAlignment.Left
        PunchLbl.Parent=MSkillCard
    end

    -- ── CARD 6: CONTROL BUTTONS ──────────────────────────────
    local CtrlCard=mkCard(nil,S.BtnH+16,IsMobile and 6 or 5)
    local CtrlRow=Instance.new("Frame")
    CtrlRow.Size=UDim2.new(1,-16,0,S.BtnH); CtrlRow.Position=UDim2.new(0,8,0,8)
    CtrlRow.BackgroundTransparency=1; CtrlRow.Parent=CtrlCard
    local CtrlLayout=Instance.new("UIListLayout")
    CtrlLayout.FillDirection=Enum.FillDirection.Horizontal
    CtrlLayout.Padding=UDim.new(0,8); CtrlLayout.Parent=CtrlRow

    local StartBtn=rowBtn("▶  START",C.Success); StartBtn.Parent=CtrlRow
    StartBtn.Size=UDim2.new(0.62,-4,1,0)
    local StopBtn=rowBtn("■  STOP",C.Danger); StopBtn.Parent=CtrlRow
    StopBtn.Size=UDim2.new(0.38,-4,1,0)

    -- ── MINIMIZE / CLOSE ─────────────────────────────────────
    MinBtn.MouseButton1Click:Connect(function()
        Minimized=not Minimized
        local targetH=Minimized and S.TopH or S.UIH
        TweenService:Create(Main,TweenInfo.new(.25,Enum.EasingStyle.Quad),
            {Size=UDim2.new(0,S.UIW,0,targetH)}):Play()
        Content.Visible=not Minimized
    end)
    CloseBtn.MouseButton1Click:Connect(function()
        Main.Visible=false
    end)

    -- ── NOTIFICATION SYSTEM ──────────────────────────────────
    local NotifHolder=Instance.new("Frame")
    NotifHolder.Size=UDim2.new(0,IsMobile and 280 or 300,1,0)
    -- mobilse sol alt, PC'de sağ üst
    if IsMobile then
        NotifHolder.Position=UDim2.new(0,8,0,0)
    else
        NotifHolder.Position=UDim2.new(1,-310,0,0)
    end
    NotifHolder.BackgroundTransparency=1; NotifHolder.Parent=ScreenGui
    local NLayout=Instance.new("UIListLayout")
    NLayout.SortOrder=Enum.SortOrder.LayoutOrder
    NLayout.Padding=UDim.new(0,6)
    NLayout.VerticalAlignment=Enum.VerticalAlignment.Bottom
    NLayout.Parent=NotifHolder

    local notifIdx=0
    local function notify(title, body, icon, ntype)
        notifIdx+=1
        local col= ntype=="success" and C.Success
                or ntype=="danger"  and C.Danger
                or ntype=="warn"    and C.Warn
                or C.Accent
        local bg=Instance.new("Frame")
        bg.Size=UDim2.new(1,0,0,0); bg.BackgroundColor3=C.Card
        bg.LayoutOrder=-notifIdx; bg.ClipDescendants=true; bg.Parent=NotifHolder
        mkCorner(10,bg); mkStroke(1,col:Lerp(C.Border,.5),bg)

        local stripe=Instance.new("Frame"); stripe.Size=UDim2.new(0,3,1,0)
        stripe.BackgroundColor3=col; stripe.Parent=bg; mkCorner(2,stripe)

        local ic=Instance.new("TextLabel"); ic.Size=UDim2.new(0,28,0,28)
        ic.Position=UDim2.new(0,10,0,8); ic.BackgroundTransparency=1
        ic.Text=icon; ic.TextSize=18; ic.Font=Enum.Font.Gotham; ic.Parent=bg

        local t=Instance.new("TextLabel"); t.Size=UDim2.new(1,-44,0,16)
        t.Position=UDim2.new(0,42,0,6); t.BackgroundTransparency=1
        t.Text=title; t.TextSize=IsMobile and 13 or 12; t.Font=Enum.Font.GothamBold
        t.TextColor3=C.TextHi; t.TextXAlignment=Enum.TextXAlignment.Left; t.Parent=bg

        local b=Instance.new("TextLabel"); b.Size=UDim2.new(1,-44,0,14)
        b.Position=UDim2.new(0,42,0,22); b.BackgroundTransparency=1
        b.Text=body; b.TextSize=IsMobile and 11 or 10; b.Font=Enum.Font.Gotham
        b.TextColor3=C.TextMid; b.TextXAlignment=Enum.TextXAlignment.Left; b.Parent=bg

        TweenService:Create(bg,TweenInfo.new(.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
            {Size=UDim2.new(1,0,0,48)}):Play()
        task.delay(3.5,function()
            TweenService:Create(bg,TweenInfo.new(.3),{BackgroundTransparency=1}):Play()
            task.wait(.35); bg:Destroy()
        end)
    end

    -- ── DROPDOWN LOGIC ───────────────────────────────────────
    local function closeDropdown()
        DropOpen=false
        TweenService:Create(DropList,TweenInfo.new(.2),{Size=UDim2.new(0,S.UIW-16,0,0)}):Play()
        task.delay(.2,function() DropList.Visible=false end)
    end

    local function populateDropdown()
        for _,c in ipairs(DropScroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        if #ScannedTargets==0 then
            local empty=Instance.new("TextLabel")
            empty.Size=UDim2.new(1,0,0,36); empty.BackgroundTransparency=1
            empty.Text="No targets found"; empty.TextSize=12; empty.Font=Enum.Font.Gotham
            empty.TextColor3=C.TextLow; empty.Parent=DropScroll
        end
        for _,t in ipairs(ScannedTargets) do
            local btn=Instance.new("TextButton")
            btn.Size=UDim2.new(1,0,0,IsMobile and 40 or 32)
            btn.BackgroundTransparency=1
            btn.Text=(t.isPlayer and "👤 " or "🤖 ")..t.name
            btn.TextSize=IsMobile and 14 or 12; btn.Font=Enum.Font.Gotham
            btn.TextColor3=C.TextHi; btn.TextXAlignment=Enum.TextXAlignment.Left
            mkPad(10,0,0,0,btn); btn.Parent=DropScroll
            local div=Instance.new("Frame"); div.Size=UDim2.new(1,-20,0,1)
            div.Position=UDim2.new(0,10,1,-1); div.BackgroundColor3=C.Border; div.Parent=btn
            btn.MouseEnter:Connect(function()
                btn.BackgroundTransparency=0; btn.BackgroundColor3=C.Border
            end)
            btn.MouseLeave:Connect(function() btn.BackgroundTransparency=1 end)
            btn.MouseButton1Click:Connect(function()
                State.Target=t.model
                TargetNameLbl.Text=t.name
                DropBtn.Text="▾  "..t.name
                if t.isPlayer then
                    TargetIcon.Image="https://www.roblox.com/headshot-thumbnail/image?userId="
                        ..t.player.UserId.."&width=48&height=48&format=png"
                else TargetIcon.Image="" end
                notify("🎯 Target Set",t.name,"🎯","accent")
                closeDropdown()
            end)
        end
        DropScroll.CanvasSize=UDim2.new(0,0,0,#ScannedTargets*(IsMobile and 40 or 32)+10)
    end

    DropBtn.MouseButton1Click:Connect(function()
        if DropOpen then closeDropdown(); return end
        local abs=DropBtn.AbsolutePosition
        DropList.Position=UDim2.new(0,abs.X,0,abs.Y+S.BtnH+4)
        DropList.Visible=true
        local h=math.min(#ScannedTargets*(IsMobile and 40 or 32)+10, 200)
        TweenService:Create(DropList,TweenInfo.new(.2,Enum.EasingStyle.Quad),
            {Size=UDim2.new(0,S.UIW-16,0,h)}):Play()
        DropOpen=true
    end)

    -- ── SCAN FUNCTIONS ───────────────────────────────────────
    local function scanTargets()
        ScannedTargets={}
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character then
                local h=getHum(p.Character)
                if h and h.Health>0 then
                    table.insert(ScannedTargets,{name=p.Name,model=p.Character,
                        isPlayer=true,player=p})
                end
            end
        end
        local chars=workspace:FindFirstChild("Characters")
        if chars then
            for _,child in ipairs(chars:GetChildren()) do
                local h=getHum(child)
                if h and h.Health>0 then
                    local dup=false
                    for _,t in ipairs(ScannedTargets) do
                        if t.model==child then dup=true;break end
                    end
                    if not dup then
                        table.insert(ScannedTargets,{name=child.Name,model=child,isPlayer=false})
                    end
                end
            end
        end
        return ScannedTargets
    end

    ScanBtn.MouseButton1Click:Connect(function()
        scanTargets(); populateDropdown()
        ScanStatusLbl.Text="Found: "..#ScannedTargets.." target(s)"
        notify("🔍 Scan","Found "..#ScannedTargets.." target(s)","🔍","accent")
    end)

    ClearBtn.MouseButton1Click:Connect(function()
        State.Target=nil; State.Running=false
        TargetNameLbl.Text="No Target"; TargetHPLbl.Text="HP: — | Dist: —"
        HPBar.Size=UDim2.new(0,0,1,0); DropBtn.Text="▾  Select Target..."
        TargetIcon.Image=""
        notify("✕ Cleared","Target removed","❌","danger")
    end)

    -- ── PLAYER TRACKING ──────────────────────────────────────
    Players.PlayerAdded:Connect(function(p)
        notify("👋 Joined",p.Name.." entered","➕","accent")
        p.CharacterAdded:Connect(function()
            task.wait(1); scanTargets(); populateDropdown()
            ScanStatusLbl.Text="Found: "..#ScannedTargets.." target(s)"
        end)
    end)
    Players.PlayerRemoving:Connect(function(p)
        notify("🚪 Left",p.Name.." left","🚪","warn")
        if State.Target and State.Target.Parent==nil then
            State.Target=nil
            notify("❌ Target Lost",p.Name.." disconnected","❌","danger")
            TargetNameLbl.Text="No Target"
        end
        task.wait(.5); scanTargets(); populateDropdown()
        ScanStatusLbl.Text="Found: "..#ScannedTargets.." target(s)"
    end)

    -- ── COMBAT ENGINE ─────────────────────────────────────────
    local function tweenTo(pos, speed)
        local root=getRoot(); if not root then return end
        local d=(root.Position-pos).Magnitude
        local tw=TweenService:Create(root,TweenInfo.new(d/(speed or CFG.ChaseSpeed),
            Enum.EasingStyle.Linear),{CFrame=CFrame.new(pos)})
        tw:Play()
    end
    local function pathTo(targetPos)
        local root=getRoot(); if not root then return end
        local path=PathfindingService:CreatePath({AgentRadius=2,AgentHeight=5,
            AgentCanJump=true,AgentCanClimb=true,WaypointSpacing=4})
        local ok=pcall(function() path:ComputeAsync(root.Position,targetPos) end)
        if ok and path.Status==Enum.PathStatus.Success then
            for _,wp in ipairs(path:GetWaypoints()) do
                if not State.Running then break end
                if wp.Action==Enum.PathWaypointAction.Jump then
                    local h=getHum(getChar()); if h then h.Jump=true end
                end
                tweenTo(wp.Position); task.wait(0.12)
            end
        else tweenTo(targetPos) end
    end
    local function lookAt()
        local root=getRoot(); local thrp=getHRP(State.Target)
        if root and thrp then root.CFrame=CFrame.lookAt(root.Position,thrp.Position) end
    end
    local function inRange(r)
        local root=getRoot(); local thrp=getHRP(State.Target)
        if not root or not thrp then return false end
        return (root.Position-thrp.Position).Magnitude<=r
    end
    local function doPunch()
        local now=tick(); if now-State.PunchLast<CFG.PunchCooldown then return false end
        if not inRange(CFG.PunchRange) then return false end
        lookAt(); fireClick(); State.PunchLast=now; return true
    end
    local function doSkill(id)
        local now=tick(); if now-State.SkillLast[id]<CFG.SkillCooldowns[id] then return false end
        if not inRange(CFG.SkillRanges[id]) then return false end
        lookAt()
        local keys={Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,Enum.KeyCode.Four}
        fireKey(keys[id]); State.SkillLast[id]=now
        State.TotalDmg+=CFG.SkillDamageEst[id]; return true
    end
    local function smartCombo()
        local now=tick()
        for id=4,1,-1 do
            if now-State.SkillLast[id]>=CFG.SkillCooldowns[id] then
                if doSkill(id) then return end
            end
        end
        doPunch()
    end
    local orbitAngle=0
    local function orbitTarget()
        local thrp=getHRP(State.Target); if not thrp then return end
        orbitAngle+=CFG.OrbitSpeed*0.05
        local goal=thrp.Position+Vector3.new(math.cos(orbitAngle)*CFG.OrbitRadius,
            0,math.sin(orbitAngle)*CFG.OrbitRadius)
        local root=getRoot(); if root then root.CFrame=CFrame.new(goal) end
        lookAt(); smartCombo()
    end
    local function predictiveChase()
        local thrp=getHRP(State.Target); if not thrp then return end
        local hum=getHum(State.Target)
        local vel=(hum and hum.MoveDirection or Vector3.zero)
        pathTo(thrp.Position+vel*2)
    end

    -- HP + Skill bar update
    local function updateUI()
        -- HP
        if State.Target then
            local hum=getHum(State.Target)
            if hum then
                local hp=math.floor(hum.Health); local mx=math.floor(hum.MaxHealth)
                local pct=hp/math.max(mx,1)
                TargetHPLbl.Text="HP: "..hp.."/"..mx.." | Dist: "..
                    math.floor(dist(getRoot(),getHRP(State.Target))).."u"
                TweenService:Create(HPBar,TweenInfo.new(.3),{Size=UDim2.new(pct,0,1,0)}):Play()
                HPBar.BackgroundColor3=pct>.5 and C.Success or pct>.25 and C.Warn or C.Danger
            end
        end
        -- Skills
        local now=tick(); local minR=math.huge
        for i=1,4 do
            local cd=CFG.SkillCooldowns[i]; local ela=now-State.SkillLast[i]
            local pct=math.clamp(ela/cd,0,1)
            TweenService:Create(SkillBars[i].fill,TweenInfo.new(.1),
                {Size=UDim2.new(pct,0,1,0)}):Play()
            if pct>=1 then SkillBars[i].lbl.Text="READY"; SkillBars[i].lbl.TextColor3=C.Success
            else SkillBars[i].lbl.Text=string.format("%.1fs",cd-ela)
                SkillBars[i].lbl.TextColor3=C.Warn end
            local rem=cd-ela; if rem<minR then minR=rem end
        end
        StatLabels["dmg"].val.Text=tostring(State.TotalDmg)
        StatLabels["kil"].val.Text=tostring(State.KillCount)
        StatLabels["cd"].val.Text=minR<=0 and "NOW" or string.format("%.1fs",minR)
        -- Mobile skill button cooldown flash
        if IsMobile then
            for i=1,4 do
                if MobileSkillBtns[i] then
                    local ela=now-State.SkillLast[i]
                    local ready=ela>=CFG.SkillCooldowns[i]
                    MobileSkillBtns[i].BackgroundColor3=ready and C.Card or C.Border
                end
            end
        end
    end

    -- Main combat loop
    local function combatLoop()
        while State.Running do
            local target=State.Target
            if not target then task.wait(.2);continue end
            if not isAlive(target) then
                State.KillCount+=1
                notify("💀 Killed!",target.Name.." eliminated","💀","success")
                State.Target=nil; TargetNameLbl.Text="No Target"
                TargetHPLbl.Text="HP: — | Dist: —"; HPBar.Size=UDim2.new(0,0,1,0)
                task.wait(1);continue
            end
            local thrp=getHRP(target); local root=getRoot()
            if not thrp or not root then task.wait(.2);continue end
            local d=dist(root,thrp)
            if State.Mode=="Orbit" then orbitTarget()
            elseif State.Mode=="Chase" then
                predictiveChase(); if d<CFG.PunchRange then smartCombo() end
            else
                if d>CFG.PunchRange+2 then
                    if d>CFG.OrbitRadius*4 then predictiveChase()
                    else pathTo(thrp.Position+(root.Position-thrp.Position).Unit*(CFG.PunchRange-1)) end
                else smartCombo() end
            end
            updateUI(); task.wait(.08)
        end
    end

    StartBtn.MouseButton1Click:Connect(function()
        if not State.Target then notify("⚠️ No Target","Select a target first","⚠️","warn");return end
        if State.Running then return end
        State.Running=true
        TweenService:Create(StartBtn,TweenInfo.new(.2),{BackgroundColor3=C.TextLow}):Play()
        notify("▶ Started","Targeting: "..State.Target.Name,"▶","success")
        task.spawn(combatLoop)
    end)
    StopBtn.MouseButton1Click:Connect(function()
        State.Running=false
        TweenService:Create(StartBtn,TweenInfo.new(.2),{BackgroundColor3=C.Success}):Play()
        notify("■ Stopped","Combat paused","■","danger")
    end)

    -- Keyboard (PC only)
    if not IsMobile then
        UserInputService.InputBegan:Connect(function(inp,gp)
            if gp then return end
            if inp.KeyCode==Enum.KeyCode.F1 then Main.Visible=not Main.Visible end
            if inp.KeyCode==Enum.KeyCode.F2 then
                scanTargets();populateDropdown()
                ScanStatusLbl.Text="Found: "..#ScannedTargets.." target(s)"
            end
            if inp.KeyCode==Enum.KeyCode.Delete then State.Running=false
                notify("■ Stopped","Hotkey: DELETE","■","danger") end
        end)
    end

    -- Noclip
    if CFG.NoclipEnabled then
        RunService.Stepped:Connect(function()
            local char=getChar()
            if char then for _,p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide=false end
            end end
        end)
    end

    -- Auto re-scan
    task.spawn(function()
        while true do task.wait(CFG.ScanInterval)
            if not State.Running then
                local prev=#ScannedTargets; scanTargets()
                if #ScannedTargets~=prev then populateDropdown()
                    ScanStatusLbl.Text="Found: "..#ScannedTargets.." target(s)" end
            end
        end
    end)

    -- Initial scan
    task.delay(.5,function()
        scanTargets(); populateDropdown()
        ScanStatusLbl.Text="Found: "..#ScannedTargets.." target(s)"
        notify("⚡ Ready!",(IsMobile and "📱 Mobile" or "🖥️ PC").." mode active","⚡","success")
    end)

    print("[JJS Target v3.0] "..( IsMobile and "📱 MOBILE" or "🖥️ PC").." | Loaded OK")
end

-- ============================================================
-- LAUNCH: loading screen → main UI
-- ============================================================
runLoadingSequence(buildMainUI)
