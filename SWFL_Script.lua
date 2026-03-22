-- ╔══════════════════════════════════════════════════════════╗
-- ║   🌴  S O U T H W E S T  F L O R I D A  B E T A  🌴   ║
-- ║   Wave Executor | Press M to toggle GUI                  ║
-- ║   Made by GasBaby233                                     ║
-- ╚══════════════════════════════════════════════════════════╝

-- ============================================================
-- SERVICES
-- ============================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera

-- ============================================================
-- CLEANUP
-- ============================================================
if _G.SWFLGui then pcall(function() _G.SWFLGui:Destroy() end) end

-- ============================================================
-- REMOTES (all confirmed from live scan)
-- ============================================================
local RS = ReplicatedStorage
local JobEvent        = RS:WaitForChild("JobEvent", 10)
local SpawnCar        = RS:WaitForChild("SpawnCar", 10)
local TeamEvent       = RS:WaitForChild("TeamEvent", 10)
local ShopEvent       = RS:WaitForChild("ShopEvent", 10)
local Twitter         = RS:WaitForChild("Twitter", 10)
local PromptEvent     = RS:WaitForChild("PromptEvent", 10)
local Misc            = RS:WaitForChild("Misc", 10)
local MiscEvent       = RS:WaitForChild("MiscEvent", 10)
local PhoneRemote     = RS:WaitForChild("phoneRemote", 10)
local CommandEvent    = RS:WaitForChild("CommandEvent", 10)
local PvpEvent        = RS:WaitForChild("pvpManagerEvent", 10)
local InflictTarget   = RS:WaitForChild("Remotes", 10) and
                        RS.Remotes:WaitForChild("InflictTarget", 10)

-- ============================================================
-- STATE
-- ============================================================
local S = {
    guiOpen      = true,
    guiKey       = Enum.KeyCode.M,
    rgbHue       = 0,

    -- Job Farm
    farmOn       = false,
    farmConn     = nil,
    farmJob      = "Dealership Employee",
    farmDelay    = 0.5,
    farmCount    = 0,
    totalEarned  = 0,

    -- Movement
    flyOn        = false,
    flySpeed     = 80,
    flyConn      = nil,
    walkSpeed    = 16,
    jumpPower    = 50,
    speedOn      = false,
    jumpOn       = false,
    noclipOn     = false,
    noclipConn   = nil,

    -- God
    godOn        = false,
    godConn      = nil,

    -- Car
    selectedCar  = "SportsCar",
}

-- ============================================================
-- HELPERS
-- ============================================================
local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function rgb() return Color3.fromHSV(S.rgbHue, 1, 1) end

local function getMoney()
    for _, v in pairs(LocalPlayer:GetDescendants()) do
        if v.Name == "Money" and (v:IsA("IntValue") or v:IsA("NumberValue")) then
            return v
        end
    end
    return nil
end

-- ============================================================
-- ALL CONFIRMED JOB ZONES from live scan
-- ============================================================
local JOBS = {
    "Dealership Employee",
    "Sales Manager",
    "Firefighter",
    "Waterpark Employee",
    "Fintech Employee",
    "Mirage Employee",
    "McBloxxer's Employee",
    "Paramedic",
    "Automart Employee",
    "Apartment Concierge",
    "Dippin' Donuts Employee",
    "Seaside Bar and Grill",
    "Cafe Worker",
    "Bubmart Employee",
    "Sunset Performance",
    "Community Service Aide",
    "Hospital Worker",
    "Jeff's Pizza Employee",
    "CVC Pharmacy Employee",
    "RW Bank Employee",
    "Sheriff",
    "Sussy's Mechanic Shop",
    "Police",
    "Criminal",
    "Vorzen Employee",
    "Rift Driver",
    "FL Fitness Employee",
    "Southwest Speed Employee",
    "StudRac Employee",
}

-- ============================================================
-- JOB FARM — confirmed working
-- false/true cycle on JobEvent gives pay each cycle
-- ============================================================
local function startJobFarm()
    S.farmOn = true
    if S.farmConn then pcall(function() task.cancel(S.farmConn) end) end

    local monVal = getMoney()
    local startMoney = monVal and monVal.Value or 0

    S.farmConn = task.spawn(function()
        while S.farmOn do
            -- Confirmed working cycle: false → wait → true → wait
            pcall(function() JobEvent:FireServer(false) end)
            task.wait(0.3)
            pcall(function() JobEvent:FireServer(true) end)
            S.farmCount = S.farmCount + 1

            -- Track earnings
            if monVal then
                local current = monVal.Value
                S.totalEarned = current - startMoney
            end

            task.wait(S.farmDelay)
        end
    end)
end

local function stopJobFarm()
    S.farmOn = false
    if S.farmConn then
        pcall(function() task.cancel(S.farmConn) end)
        S.farmConn = nil
    end
    -- Fire false to cleanly exit job zone
    pcall(function() JobEvent:FireServer(false) end)
end

-- ============================================================
-- CHANGE JOB/TEAM
-- ============================================================
local function changeJob(jobName)
    pcall(function()
        TeamEvent:FireServer(jobName)
    end)
    pcall(function()
        for _, t in pairs(game.Teams:GetChildren()) do
            if t.Name == jobName then
                LocalPlayer.Team = t
                break
            end
        end
    end)
end

-- ============================================================
-- FLY
-- ============================================================
local function enableFly()
    S.flyOn = true
    local hrp = getHRP()
    if not hrp then return end
    local hum = getHum()
    if hum then hum.PlatformStand = true end

    local bg = Instance.new("BodyGyro")
    bg.Name = "SWFLFlyGyro"
    bg.MaxTorque = Vector3.new(9e9,9e9,9e9)
    bg.D = 100 bg.P = 1e5
    bg.CFrame = Camera.CFrame bg.Parent = hrp

    local bv = Instance.new("BodyVelocity")
    bv.Name = "SWFLFlyVel"
    bv.MaxForce = Vector3.new(9e9,9e9,9e9)
    bv.Velocity = Vector3.zero bv.Parent = hrp

    if S.flyConn then S.flyConn:Disconnect() end
    S.flyConn = RunService.Heartbeat:Connect(function()
        if not S.flyOn then return end
        hrp = getHRP() if not hrp then return end
        local cf = Camera.CFrame
        local vel = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel=vel+cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel=vel-cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel=vel-cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel=vel+cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel=vel+Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vel=vel-Vector3.new(0,1,0) end
        local bvv = hrp:FindFirstChild("SWFLFlyVel")
        local bgg = hrp:FindFirstChild("SWFLFlyGyro")
        if bvv then bvv.Velocity = vel.Magnitude>0 and vel.Unit*S.flySpeed or Vector3.zero end
        if bgg then bgg.CFrame = CFrame.new(hrp.Position, hrp.Position+cf.LookVector) end
    end)
end

local function disableFly()
    S.flyOn = false
    if S.flyConn then S.flyConn:Disconnect() S.flyConn=nil end
    local hrp = getHRP()
    if hrp then
        local b1=hrp:FindFirstChild("SWFLFlyVel")
        local b2=hrp:FindFirstChild("SWFLFlyGyro")
        if b1 then b1:Destroy() end
        if b2 then b2:Destroy() end
    end
    local hum = getHum()
    if hum then hum.PlatformStand = false end
end

-- ============================================================
-- GOD MODE
-- ============================================================
local function enableGod()
    S.godOn = true
    if S.godConn then S.godConn:Disconnect() end
    S.godConn = RunService.Heartbeat:Connect(function()
        if not S.godOn then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                hum.MaxHealth = 1e9
                hum.Health = 1e9
            end)
        end
    end)
end

local function disableGod()
    S.godOn = false
    if S.godConn then S.godConn:Disconnect() S.godConn=nil end
    local hum = getHum()
    if hum then pcall(function() hum.MaxHealth=100 hum.Health=100 end) end
end

-- ============================================================
-- MOVEMENT
-- ============================================================
local function applySpeed()
    local hum = getHum()
    if not hum then return end
    pcall(function()
        hum.WalkSpeed = S.speedOn and S.walkSpeed or 16
        hum.JumpPower = S.jumpOn and S.jumpPower or 50
    end)
end

local moveConn
local function startMoveLoop()
    if moveConn then moveConn:Disconnect() end
    moveConn = RunService.Heartbeat:Connect(function()
        if not S.speedOn and not S.jumpOn then
            moveConn:Disconnect() moveConn=nil return
        end
        applySpeed()
    end)
end

-- ============================================================
-- NOCLIP
-- ============================================================
local noclipConn
local function enableNoclip()
    S.noclipOn = true
    if noclipConn then noclipConn:Disconnect() end
    noclipConn = RunService.Heartbeat:Connect(function()
        if not S.noclipOn then noclipConn:Disconnect() noclipConn=nil return end
        local char = LocalPlayer.Character
        if not char then return end
        -- Set ALL parts including HRP to no collision
        for _, p in pairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function() p.CanCollide = false end)
            end
        end
        -- Also disable via Humanoid
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
        end
    end)
end

local function disableNoclip()
    S.noclipOn = false
    if noclipConn then noclipConn:Disconnect() noclipConn=nil end
    -- Restore collision
    local char = LocalPlayer.Character
    if char then
        for _, p in pairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function() p.CanCollide = true end)
            end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
    end
end

-- ============================================================
-- TELEPORT
-- ============================================================
local SWF_LOCATIONS = {
    -- Confirmed from live jobsMain scan + Y offset corrected (+8 above zone)
    {"🚗 Dealership",          Vector3.new(8817.9, 56.6, 3115.8)},
    {"🍔 McBloxxers",          Vector3.new(9624.9, 42.1, 1228.1)},
    {"🏥 Hospital",            Vector3.new(8980.6, 57.9, -4723.4)},
    {"🏦 RW Bank",             Vector3.new(6368.0, 42.2, 22.8)},
    {"🚒 Fire Station 1",      Vector3.new(2661.6, 30.0, 1014.7)},
    {"🚒 Fire Station 2",      Vector3.new(7876.4, 30.0, 114.6)},
    {"🏪 Automart",            Vector3.new(9081.9, 43.1, -879.3)},
    {"🍩 Dippin Donuts",       Vector3.new(9676.3, 39.6, 715.2)},
    {"🍕 Jeff's Pizza",        Vector3.new(8546.0, 44.6, -638.9)},
    {"💊 CVC Pharmacy",        Vector3.new(9572.7, 46.4, -920.4)},
    {"☕ Cafe Worker",         Vector3.new(9569.2, 43.0, -4124.8)},
    {"🛒 Bubmart",             Vector3.new(8733.5, 48.6, -699.7)},
    {"🌊 Waterpark",           Vector3.new(4746.7, 94.9, 3669.8)},
    {"🏋 FL Fitness",          Vector3.new(10206.4, 52.1, 1994.9)},
    {"🏎 Southwest Speed",     Vector3.new(5802.3, 63.6, 4203.6)},
    {"🔧 Sussy's Mechanic",    Vector3.new(9100.8, 40.4, -1453.2)},
    {"🏨 Apartment Concierge", Vector3.new(-2501.9, 36.9, -7761.8)},
    {"🌅 Seaside Bar & Grill", Vector3.new(-1741.4, 50.3, -7598.8)},
    {"🎵 Sunset Performance",  Vector3.new(6960.4, 39.4, -10.4)},
    {"💻 Fintech",             Vector3.new(8849.6, 71.3, -2726.4)},
    {"🏪 Vorzen Employee",     Vector3.new(8898.3, 42.3, -283.8)},
    {"🏁 StudRac",             Vector3.new(3322.3, 40.3, -355.0)},
    {"🏢 Mirage Employee",     Vector3.new(8650.5, 45.6, 934.9)},
}

local function doTeleport(pos)
    local hrp = getHRP()
    if not hrp then return end
    local lp = LocalPlayer
    pcall(function() lp:SetAttribute("SpawnCF", CFrame.new(pos + Vector3.new(0,4,0))) end)
    local hum = getHum()
    if hum then pcall(function() hum.WalkSpeed=0 end) end
    task.spawn(function()
        local cf = CFrame.new(pos + Vector3.new(0,4,0))
        for i=1,10 do
            pcall(function() hrp.Anchored=true hrp.CFrame=cf end)
            pcall(function() lp.Character:PivotTo(cf) end)
            task.wait(0.05)
        end
        hrp.Anchored=false
        if hum then pcall(function() hum.WalkSpeed=S.speedOn and S.walkSpeed or 16 end) end
    end)
end

-- ============================================================
-- FIRE ALL NEARBY PROMPTS
-- ============================================================
local function fireNearbyPrompts(radius, filter)
    local hrp = getHRP()
    if not hrp then return 0 end
    local count = 0
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local part = v.Parent
            if part and part:IsA("BasePart") then
                local dist = (part.Position - hrp.Position).Magnitude
                if dist <= (radius or 20) then
                    local action = v.ActionText:lower()
                    -- Skip car seats unless filter says include
                    if filter or (action ~= "sit" and action ~= "drive") then
                        pcall(function() fireproximityprompt(v) end)
                        count = count + 1
                        task.wait(0.1)
                    end
                end
            end
        end
    end
    return count
end

-- ============================================================
-- SPAWN CAR
-- ============================================================
local function spawnCar(carName)
    pcall(function()
        SpawnCar:FireServer(carName)
    end)
end

-- ============================================================
-- TWITTER CODES
-- ============================================================
-- Confirmed working codes from community
local SWF_CODES = {
    {"REVAMP",       "$50,000 Cash"},
    {"10MIL",        "$100,000 Cash"},
    {"YABOII",       "Free Reward"},
    {"KAM",          "Free Reward"},
    {"SWFL2024",     "Possible Reward"},
    {"southwestfl",  "Possible Reward"},
    {"update",       "Possible Reward"},
}

local function tryAllCodes()
    for _, cd in ipairs(SWF_CODES) do
        pcall(function() Twitter:FireServer(cd[1]) end)
        task.wait(0.3)
    end
end

-- ============================================================
-- SCREENGUI — Fresh tropical design
-- ============================================================
local SG = Instance.new("ScreenGui")
SG.Name = "SWFLScript"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset = true
_G.SWFLGui = SG
local ok = pcall(function() SG.Parent = game:GetService("CoreGui") end)
if not ok then SG.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Main window — tropical gradient style
local WIN = Instance.new("Frame", SG)
WIN.Name = "Window"
WIN.Size = UDim2.new(0, 620, 0, 560)
WIN.Position = UDim2.new(0.5,-310,0.5,-280)
WIN.BackgroundColor3 = Color3.fromRGB(8,14,22)
WIN.BorderSizePixel = 0
WIN.ClipsDescendants = true
Instance.new("UICorner",WIN).CornerRadius = UDim.new(0,16)

local stroke = Instance.new("UIStroke",WIN)
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(0,200,255)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Animated gradient background
local gradBg = Instance.new("Frame",WIN)
gradBg.Size = UDim2.new(1,0,1,0)
gradBg.BackgroundColor3 = Color3.fromRGB(8,14,22)
gradBg.BorderSizePixel = 0 gradBg.ZIndex = 1
gradBg.ClipsDescendants = true  -- CRITICAL: clips all children inside window

-- Wave decorations
local waves = {}
for i=1,3 do
    local w = Instance.new("Frame",gradBg)
    w.Size = UDim2.new(1.2,0,0,40)
    w.Position = UDim2.new(-0.1,0,0.6+i*0.12,0)
    w.BackgroundColor3 = Color3.fromRGB(0,80+i*30,150+i*20)
    w.BackgroundTransparency = 0.7
    w.BorderSizePixel = 0 w.ZIndex = 2 w.Rotation = -2
    Instance.new("UICorner",w).CornerRadius = UDim.new(0,20)
    table.insert(waves,{frame=w, base=0.6+i*0.12, speed=0.3+i*0.1})
end

-- Sun
local sun = Instance.new("Frame",gradBg)
sun.Size = UDim2.new(0,80,0,80)
sun.Position = UDim2.new(0.8,0,0.05,0)
sun.BackgroundColor3 = Color3.fromRGB(255,200,50)
sun.BackgroundTransparency = 0.3
sun.BorderSizePixel = 0 sun.ZIndex = 2
Instance.new("UICorner",sun).CornerRadius = UDim.new(0.5,0)

-- Palm trees — use AnchorPoint to keep them at bottom corners
local palmL = Instance.new("TextLabel",gradBg)
palmL.Size = UDim2.new(0,40,0,55)
palmL.Position = UDim2.new(0,4,1,-58)  -- bottom left corner
palmL.AnchorPoint = Vector2.new(0,1)
palmL.BackgroundTransparency = 1
palmL.Text = "🌴" palmL.TextSize = 38
palmL.ZIndex = 3 palmL.TextYAlignment = Enum.TextYAlignment.Bottom

local palmR = Instance.new("TextLabel",gradBg)
palmR.Size = UDim2.new(0,40,0,55)
palmR.Position = UDim2.new(1,-44,1,-58)  -- bottom right corner
palmR.AnchorPoint = Vector2.new(1,1)
palmR.BackgroundTransparency = 1
palmR.Text = "🌴" palmR.TextSize = 38
palmR.ZIndex = 3 palmR.TextYAlignment = Enum.TextYAlignment.Bottom

-- Title bar
local TBar = Instance.new("Frame",WIN)
TBar.Size = UDim2.new(1,0,0,48)
TBar.BackgroundColor3 = Color3.fromRGB(5,10,18)
TBar.BackgroundTransparency = 0.1
TBar.BorderSizePixel = 0 TBar.ZIndex = 10
Instance.new("UICorner",TBar).CornerRadius = UDim.new(0,16)
local TBarFix = Instance.new("Frame",TBar)
TBarFix.Size = UDim2.new(1,0,0.5,0)
TBarFix.Position = UDim2.new(0,0,0.5,0)
TBarFix.BackgroundColor3 = Color3.fromRGB(5,10,18)
TBarFix.BorderSizePixel = 0 TBarFix.ZIndex = 9

-- Title
local TitleLbl = Instance.new("TextLabel",TBar)
TitleLbl.Size = UDim2.new(1,-90,1,0)
TitleLbl.Position = UDim2.new(0,46,0,0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "🌴 Southwest Florida Beta"
TitleLbl.TextColor3 = Color3.fromRGB(0,220,255)
TitleLbl.TextSize = 15 TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.ZIndex = 11

-- Hint
local HintLbl = Instance.new("TextLabel",TBar)
HintLbl.Size = UDim2.new(0,50,1,0)
HintLbl.Position = UDim2.new(1,-115,0,0)
HintLbl.BackgroundTransparency = 1
HintLbl.Text = "[M] hide"
HintLbl.TextColor3 = Color3.fromRGB(80,120,160)
HintLbl.TextSize = 9 HintLbl.Font = Enum.Font.Gotham
HintLbl.ZIndex = 11

-- Close/Min buttons
local function makeTBtn(txt, xOff, col)
    local b = Instance.new("TextButton",TBar)
    b.Size = UDim2.new(0,26,0,26)
    b.Position = UDim2.new(1,xOff,0.5,-13)
    b.BackgroundColor3 = col
    b.Text = txt b.TextColor3 = Color3.new(1,1,1)
    b.TextSize = 12 b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0 b.ZIndex = 12
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,6)
    return b
end
local CloseBtn = makeTBtn("✕", -32, Color3.fromRGB(180,40,40))
local MinBtn   = makeTBtn("–", -62, Color3.fromRGB(30,80,120))

-- Tab bar row 1
local TabBar = Instance.new("Frame",WIN)
TabBar.Size = UDim2.new(1,0,0,32)
TabBar.Position = UDim2.new(0,0,0,48)
TabBar.BackgroundColor3 = Color3.fromRGB(5,12,20)
TabBar.BorderSizePixel = 0 TabBar.ZIndex = 9
local TabLayout = Instance.new("UIListLayout",TabBar)
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabLayout.Padding = UDim.new(0,2)

-- Tab bar row 2
local TabBar2 = Instance.new("Frame",WIN)
TabBar2.Size = UDim2.new(1,0,0,30)
TabBar2.Position = UDim2.new(0,0,0,80)
TabBar2.BackgroundColor3 = Color3.fromRGB(4,10,18)
TabBar2.BorderSizePixel = 0 TabBar2.ZIndex = 9
local TabLayout2 = Instance.new("UIListLayout",TabBar2)
TabLayout2.FillDirection = Enum.FillDirection.Horizontal
TabLayout2.VerticalAlignment = Enum.VerticalAlignment.Center
TabLayout2.Padding = UDim.new(0,2)

-- Separator
local Sep = Instance.new("Frame",WIN)
Sep.Size = UDim2.new(1,0,0,1)
Sep.Position = UDim2.new(0,0,0,110)
Sep.BackgroundColor3 = Color3.fromRGB(0,100,180)
Sep.BorderSizePixel = 0 Sep.ZIndex = 9

-- Content area — adjusted for 2 row tabs
local ContentArea = Instance.new("Frame",WIN)
ContentArea.Size = UDim2.new(1,-14,1,-134)
ContentArea.Position = UDim2.new(0,7,0,114)
ContentArea.BackgroundTransparency = 1 ContentArea.ZIndex = 8

-- Status bar
local StatusBar = Instance.new("Frame",WIN)
StatusBar.Size = UDim2.new(1,0,0,22)
StatusBar.Position = UDim2.new(0,0,1,-22)
StatusBar.BackgroundColor3 = Color3.fromRGB(4,8,16)
StatusBar.BorderSizePixel = 0 StatusBar.ZIndex = 10
local StatusLbl = Instance.new("TextLabel",StatusBar)
StatusLbl.Size = UDim2.new(0.65,0,1,0)
StatusLbl.Position = UDim2.new(0,8,0,0)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text = "🌴 Southwest Florida | M=Toggle"
StatusLbl.TextColor3 = Color3.fromRGB(0,180,220)
StatusLbl.TextSize = 9 StatusLbl.Font = Enum.Font.Gotham
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
StatusLbl.ZIndex = 11
local CreditLbl = Instance.new("TextLabel",StatusBar)
CreditLbl.Size = UDim2.new(0.35,0,1,0)
CreditLbl.Position = UDim2.new(0.65,0,0,0)
CreditLbl.BackgroundTransparency = 1
CreditLbl.Text = "made by GasBaby233"
CreditLbl.TextColor3 = Color3.fromRGB(0,100,140)
CreditLbl.TextSize = 9 CreditLbl.Font = Enum.Font.GothamBold
CreditLbl.TextXAlignment = Enum.TextXAlignment.Right
CreditLbl.ZIndex = 11

-- ============================================================
-- WIDGET FACTORIES
-- ============================================================
local function Section(parent, text, y)
    local l = Instance.new("TextLabel",parent)
    l.Size = UDim2.new(1,0,0,18) l.Position = UDim2.new(0,0,0,y)
    l.BackgroundTransparency = 1
    l.Text = "── "..text.." ──"
    l.TextColor3 = Color3.fromRGB(0,200,255)
    l.TextSize = 11 l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Center l.ZIndex = 11
    return l
end

local function Toggle(parent, label, y, cb)
    local row = Instance.new("Frame",parent)
    row.Size = UDim2.new(1,0,0,32) row.Position = UDim2.new(0,0,0,y)
    row.BackgroundColor3 = Color3.fromRGB(8,16,28)
    row.BorderSizePixel = 0 row.ZIndex = 10
    Instance.new("UICorner",row).CornerRadius = UDim.new(0,8)
    local lbl = Instance.new("TextLabel",row)
    lbl.Size = UDim2.new(1,-68,1,0) lbl.Position = UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency = 1 lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(200,220,240)
    lbl.TextSize = 12 lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.ZIndex = 11
    local btn = Instance.new("TextButton",row)
    btn.Size = UDim2.new(0,54,0,22) btn.Position = UDim2.new(1,-58,0.5,-11)
    btn.BackgroundColor3 = Color3.fromRGB(8,20,35)
    btn.Text = "OFF" btn.TextColor3 = Color3.fromRGB(80,140,180)
    btn.TextSize = 10 btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0 btn.ZIndex = 12
    Instance.new("UICorner",btn).CornerRadius = UDim.new(0,5)
    local on = false
    local function set(v)
        on = v
        if v then
            btn.Text = "ON"
            btn.TextColor3 = Color3.fromRGB(0,255,180)
            btn.BackgroundColor3 = Color3.fromRGB(0,30,20)
        else
            btn.Text = "OFF"
            btn.TextColor3 = Color3.fromRGB(80,140,180)
            btn.BackgroundColor3 = Color3.fromRGB(8,20,35)
        end
        if cb then cb(v) end
    end
    btn.MouseButton1Click:Connect(function() set(not on) end)
    return row, function() return on end, set
end

local function Btn(parent, text, y, col, cb)
    local b = Instance.new("TextButton",parent)
    b.Size = UDim2.new(1,-4,0,30) b.Position = UDim2.new(0,2,0,y)
    b.BackgroundColor3 = col or Color3.fromRGB(8,20,40)
    b.Text = text b.TextColor3 = Color3.fromRGB(200,230,255)
    b.TextSize = 12 b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0 b.ZIndex = 11
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,8)
    if cb then b.MouseButton1Click:Connect(cb) end
    return b
end

local function Slider(parent, label, mn, mx, def, y, cb)
    local frame = Instance.new("Frame",parent)
    frame.Size = UDim2.new(1,0,0,42) frame.Position = UDim2.new(0,0,0,y)
    frame.BackgroundColor3 = Color3.fromRGB(8,16,28)
    frame.BorderSizePixel = 0 frame.ZIndex = 10
    Instance.new("UICorner",frame).CornerRadius = UDim.new(0,8)
    local lbl = Instance.new("TextLabel",frame)
    lbl.Size = UDim2.new(1,-10,0,18) lbl.Position = UDim2.new(0,10,0,2)
    lbl.BackgroundTransparency = 1
    lbl.Text = label..":  "..tostring(def)
    lbl.TextColor3 = Color3.fromRGB(160,200,230)
    lbl.TextSize = 11 lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.ZIndex = 11
    local track = Instance.new("Frame",frame)
    track.Size = UDim2.new(1,-18,0,6) track.Position = UDim2.new(0,9,0,28)
    track.BackgroundColor3 = Color3.fromRGB(15,30,50)
    track.BorderSizePixel = 0 track.ZIndex = 11
    Instance.new("UICorner",track).CornerRadius = UDim.new(0.5,0)
    local fill = Instance.new("Frame",track)
    fill.Size = UDim2.new((def-mn)/(mx-mn),0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(0,200,255)
    fill.BorderSizePixel = 0 fill.ZIndex = 12
    Instance.new("UICorner",fill).CornerRadius = UDim.new(0.5,0)
    local val = def local drag = false
    local function upd(ix)
        local ap = track.AbsolutePosition local as = track.AbsoluteSize
        local rel = math.clamp((ix-ap.X)/as.X,0,1)
        val = math.floor(mn+rel*(mx-mn))
        fill.Size = UDim2.new(rel,0,1,0)
        lbl.Text = label..":  "..tostring(val)
        if cb then cb(val) end
    end
    track.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true upd(i.Position.X) end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then upd(i.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end)
    return frame
end

local function InfoBox(parent, text, y, h)
    local f = Instance.new("Frame",parent)
    f.Size = UDim2.new(1,-4,0,h or 28) f.Position = UDim2.new(0,2,0,y)
    f.BackgroundColor3 = Color3.fromRGB(5,14,24)
    f.BackgroundTransparency = 0.2
    f.BorderSizePixel = 0 f.ZIndex = 10
    Instance.new("UICorner",f).CornerRadius = UDim.new(0,8)
    local l = Instance.new("TextLabel",f)
    l.Size = UDim2.new(1,-10,1,0) l.Position = UDim2.new(0,6,0,0)
    l.BackgroundTransparency = 1 l.Text = text
    l.TextColor3 = Color3.fromRGB(100,180,220)
    l.TextSize = 10 l.Font = Enum.Font.Gotham
    l.TextWrapped = true
    l.TextXAlignment = Enum.TextXAlignment.Left l.ZIndex = 11
    return f, l
end

local function Dropdown(parent, label, opts, y, cb)
    local frame = Instance.new("Frame",parent)
    frame.Size = UDim2.new(1,0,0,30) frame.Position = UDim2.new(0,0,0,y)
    frame.BackgroundColor3 = Color3.fromRGB(8,16,28)
    frame.BorderSizePixel = 0 frame.ZIndex = 10
    Instance.new("UICorner",frame).CornerRadius = UDim.new(0,8)
    local lbl = Instance.new("TextLabel",frame)
    lbl.Size = UDim2.new(0.38,0,1,0) lbl.Position = UDim2.new(0,8,0,0)
    lbl.BackgroundTransparency = 1 lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(160,200,230)
    lbl.TextSize = 11 lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.ZIndex = 11
    local idx = 1
    local btn = Instance.new("TextButton",frame)
    btn.Size = UDim2.new(0.6,-4,0,22) btn.Position = UDim2.new(0.4,2,0.5,-11)
    btn.BackgroundColor3 = Color3.fromRGB(0,40,70)
    btn.Text = "◀ "..opts[1].." ▶"
    btn.TextColor3 = Color3.fromRGB(0,200,255)
    btn.TextSize = 9 btn.Font = Enum.Font.Gotham
    btn.BorderSizePixel = 0 btn.ZIndex = 12
    Instance.new("UICorner",btn).CornerRadius = UDim.new(0,5)
    btn.MouseButton1Click:Connect(function()
        idx = (idx%#opts)+1
        btn.Text = "◀ "..opts[idx].." ▶"
        if cb then cb(opts[idx]) end
    end)
    return frame, btn, function() return opts[idx] end
end

-- ============================================================
-- TAB SYSTEM
-- ============================================================
local tabs = {} local tabBtns = {}

local function MakeTab(name, icon, row)
    local parent = (row == 2) and TabBar2 or TabBar
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0,76,0,(row==2) and 28 or 32)
    btn.BackgroundColor3 = Color3.fromRGB(8,16,28)
    btn.Text = icon.." "..name
    btn.TextColor3 = Color3.fromRGB(80,130,170)
    btn.TextSize = 9 btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0 btn.ZIndex = 10

    local scroll = Instance.new("ScrollingFrame",ContentArea)
    scroll.Size = UDim2.new(1,0,1,0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(0,200,255)
    scroll.ZIndex = 9 scroll.Visible = false
    tabs[name] = scroll tabBtns[name] = btn

    btn.MouseButton1Click:Connect(function()
        for n,s in pairs(tabs) do s.Visible=(n==name) end
        for n,b in pairs(tabBtns) do
            if n==name then
                b.BackgroundColor3 = Color3.fromRGB(0,40,70)
                b.TextColor3 = Color3.fromRGB(0,220,255)
            else
                b.BackgroundColor3 = Color3.fromRGB(8,16,28)
                b.TextColor3 = Color3.fromRGB(80,130,170)
            end
        end
        StatusLbl.Text = "🌴 "..name.." | M=Toggle | GasBaby233"
    end)
    return scroll
end

-- Row 1
local FarmTab     = MakeTab("Farm",     "💰", 1)
local MoveTab     = MakeTab("Move",     "💨", 1)
local TeleTab     = MakeTab("Tele",     "🌀", 1)
local JobsTab     = MakeTab("Jobs",     "💼", 1)
local CarsTab     = MakeTab("Cars",     "🚗", 1)
-- Row 2
local ESPTab      = MakeTab("ESP",      "👁", 2)
local PlayersTab  = MakeTab("Players",  "👥", 2)
local MiscTab     = MakeTab("Misc",     "🔧", 2)
local SettingsTab = MakeTab("Settings", "⚙",  2)

-- Activate first tab
tabs["Farm"].Visible = true
tabBtns["Farm"].BackgroundColor3 = Color3.fromRGB(0,40,70)
tabBtns["Farm"].TextColor3 = Color3.fromRGB(0,220,255)

-- ============================================================
-- FARM TAB
-- ============================================================
do
    local C = FarmTab C.CanvasSize = UDim2.new(0,0,0,600)
    local y = 4

    Section(C,"💰 Job Money Farm",y) y=y+22
    InfoBox(C,"CONFIRMED: JobEvent false/true cycle gives pay each loop. Works on any job you're assigned to.",y,34) y=y+38

    -- Live balance display
    local _,balLbl = InfoBox(C,"💰 Balance: checking...",y,22) y=y+26
    local _,earnLbl = InfoBox(C,"Earned this session: $0",y,20) y=y+24

    task.spawn(function()
        while task.wait(0.5) do
            if not balLbl or not balLbl.Parent then break end
            local mv = getMoney()
            if mv then
                pcall(function()
                    balLbl.Text = "💰 Balance: $"..tostring(math.floor(mv.Value))
                    earnLbl.Text = "📈 Earned: $"..tostring(math.floor(S.totalEarned)).." | Cycles: "..S.farmCount
                end)
            end
        end
    end)

    -- Job selector
    Dropdown(C,"Job:",JOBS,y,function(v)
        S.farmJob = v
        if S.farmOn then
            stopJobFarm()
            task.wait(0.2)
            changeJob(v)
            task.wait(0.5)
            startJobFarm()
        end
    end) y=y+34

    -- Speed
    Slider(C,"Farm Speed (delay)",0.1,3,0.5,y,function(v)
        S.farmDelay = v
    end) y=y+46

    -- Start/stop
    local _,farmStatusLbl = InfoBox(C,"Status: OFF",y,22) y=y+26

    Toggle(C,"💰 Auto Job Farm",y,function(v)
        if v then
            changeJob(S.farmJob)
            task.wait(0.5)
            startJobFarm()
            farmStatusLbl.Text = "✅ FARMING: "..S.farmJob
            StatusLbl.Text = "💰 Farming: "..S.farmJob
        else
            stopJobFarm()
            farmStatusLbl.Text = "Stopped — earned $"..math.floor(S.totalEarned)
        end
    end) y=y+36

    -- Rapid dupe — fires false/true as fast as possible
    Section(C,"⚡ Rapid Dupe",y) y=y+22
    InfoBox(C,"Fires false/true as fast as server allows. More cycles = more money per second. May get slower over time.",y,34) y=y+38
    local _,dupeLbl = InfoBox(C,"OFF",y,20) y=y+24
    local dupeActive = false
    local dupeConn = nil
    local dupeCount = 0
    Toggle(C,"⚡ Rapid Fire Dupe",y,function(v)
        dupeActive = v
        if v then
            changeJob(S.farmJob)
            task.wait(0.3)
            if dupeConn then pcall(function() task.cancel(dupeConn) end) end
            local je = RS:FindFirstChild("JobEvent")
            if not je then dupeLbl.Text="⚠ JobEvent not found" return end
            local monVal = getMoney()
            local startMoney = monVal and monVal.Value or 0
            dupeConn = task.spawn(function()
                while dupeActive do
                    pcall(function() je:FireServer(false) end)
                    task.wait(0.1)
                    pcall(function() je:FireServer(true) end)
                    dupeCount = dupeCount + 1
                    if monVal then
                        local earned = monVal.Value - startMoney
                        pcall(function()
                            dupeLbl.Text = "⚡ Cycles: "..dupeCount.." | +$"..math.floor(earned)
                        end)
                    end
                    task.wait(0.1)
                end
            end)
            dupeLbl.Text = "⚡ RAPID FIRING..."
        else
            dupeActive = false
            if dupeConn then pcall(function() task.cancel(dupeConn) end) dupeConn=nil end
            local je = RS:FindFirstChild("JobEvent")
            if je then pcall(function() je:FireServer(false) end) end
            dupeLbl.Text = "Stopped — "..dupeCount.." cycles"
        end
    end) y=y+36

    -- Quick job buttons
    Section(C,"⚡ Quick Jobs",y) y=y+22
    local quickJobs = {
        {"🚗 Dealership","Dealership Employee"},
        {"🏦 Bank","RW Bank Employee"},
        {"🍔 McBloxxers","McBloxxer's Employee"},
        {"🚒 Firefighter","Firefighter"},
        {"👮 Police","Police"},
        {"🏥 Hospital","Hospital Worker"},
    }
    for i=1,#quickJobs,2 do
        local row = Instance.new("Frame",C)
        row.Size = UDim2.new(1,0,0,30)
        row.Position = UDim2.new(0,0,0,y)
        row.BackgroundTransparency = 1 row.ZIndex = 10
        for col=0,1 do
            local qj = quickJobs[i+col]
            if qj then
                local b = Instance.new("TextButton",row)
                b.Size = UDim2.new(0.49,0,0,28)
                b.Position = UDim2.new(col*0.51,col==0 and 0 or 4,0,1)
                b.BackgroundColor3 = Color3.fromRGB(0,30,55)
                b.Text = qj[1]
                b.TextColor3 = Color3.fromRGB(0,200,255)
                b.TextSize = 10 b.Font = Enum.Font.GothamBold
                b.BorderSizePixel = 0 b.ZIndex = 11
                Instance.new("UICorner",b).CornerRadius = UDim.new(0,7)
                local jname = qj[2]
                b.MouseButton1Click:Connect(function()
                    S.farmJob = jname
                    changeJob(jname)
                    if S.farmOn then
                        stopJobFarm()
                        task.wait(0.3)
                        startJobFarm()
                    end
                    farmStatusLbl.Text = "Job: "..jname
                    b.BackgroundColor3 = Color3.fromRGB(0,50,30)
                    task.delay(1,function() pcall(function() b.BackgroundColor3=Color3.fromRGB(0,30,55) end) end)
                end)
            end
        end
        y=y+32
    end

    C.CanvasSize = UDim2.new(0,0,0,y+20)
end

-- ============================================================
-- MOVE TAB
-- ============================================================
do
    local C = MoveTab C.CanvasSize = UDim2.new(0,0,0,480)
    local y = 4

    Section(C,"✈ Fly",y) y=y+22
    InfoBox(C,"W/A/S/D + Space/LCtrl to fly",y,22) y=y+26
    Slider(C,"Fly Speed",10,300,80,y,function(v) S.flySpeed=v end) y=y+46
    Toggle(C,"✈ Fly",y,function(v)
        if v then enableFly() else disableFly() end
    end) y=y+36
    Btn(C,"🏠 Land",y,Color3.fromRGB(0,25,45),function()
        disableFly()
        local hrp = getHRP() if not hrp then return end
        local rp = RaycastParams.new()
        rp.FilterDescendantsInstances = {LocalPlayer.Character}
        rp.FilterType = Enum.RaycastFilterType.Exclude
        local res = workspace:Raycast(hrp.Position, Vector3.new(0,-500,0), rp)
        if res then
            hrp.Anchored = true
            hrp.CFrame = CFrame.new(res.Position+Vector3.new(0,4,0))
            task.wait(0.05) hrp.Anchored = false
        end
    end) y=y+34

    Section(C,"💨 Speed",y) y=y+22
    local _,spLbl = InfoBox(C,"WalkSpeed: 16",y,22) y=y+26
    Slider(C,"Walk Speed",16,250,80,y,function(v)
        S.walkSpeed=v if S.speedOn then applySpeed() end
        spLbl.Text="WalkSpeed: "..v..(S.speedOn and " ✅" or "")
    end) y=y+46
    Toggle(C,"💨 Speed Hack",y,function(v)
        S.speedOn=v applySpeed() if v then startMoveLoop() end
        spLbl.Text="WalkSpeed: "..S.walkSpeed..(v and " ✅" or "")
    end) y=y+36
    Slider(C,"Jump Power",50,300,150,y,function(v)
        S.jumpPower=v if S.jumpOn then applySpeed() end
    end) y=y+46
    Toggle(C,"🦘 High Jump",y,function(v)
        S.jumpOn=v applySpeed() if v then startMoveLoop() end
    end) y=y+36

    Section(C,"👻 Noclip",y) y=y+22
    Toggle(C,"👻 Noclip",y,function(v)
        if v then enableNoclip() else disableNoclip() end
    end) y=y+36

    Section(C,"🛡 God Mode",y) y=y+22
    Toggle(C,"🛡 God Mode",y,function(v)
        if v then enableGod() else disableGod() end
    end) y=y+36

    C.CanvasSize = UDim2.new(0,0,0,y+20)
end

-- ============================================================
-- TELEPORT TAB
-- ============================================================
do
    local C = TeleTab C.CanvasSize = UDim2.new(0,0,0,600)
    local y = 4

    Section(C,"🌀 Map Locations",y) y=y+22
    InfoBox(C,"Teleport anywhere on the map instantly.",y,22) y=y+26
    local _,teleLbl = InfoBox(C,"Click to teleport",y,20) y=y+24

    for i=1,#SWF_LOCATIONS,2 do
        local row = Instance.new("Frame",C)
        row.Size = UDim2.new(1,0,0,32)
        row.Position = UDim2.new(0,0,0,y)
        row.BackgroundTransparency = 1 row.ZIndex = 10
        for col=0,1 do
            local loc = SWF_LOCATIONS[i+col]
            if loc then
                local b = Instance.new("TextButton",row)
                b.Size = UDim2.new(0.49,0,0,30)
                b.Position = UDim2.new(col*0.51,col==0 and 0 or 4,0,1)
                b.BackgroundColor3 = Color3.fromRGB(0,25,45)
                b.Text = loc[1]
                b.TextColor3 = Color3.fromRGB(0,200,255)
                b.TextSize = 10 b.Font = Enum.Font.GothamBold
                b.BorderSizePixel = 0 b.ZIndex = 11
                b.TextTruncate = Enum.TextTruncate.AtEnd
                Instance.new("UICorner",b).CornerRadius = UDim.new(0,7)
                local p = loc[2] local n = loc[1]
                b.MouseButton1Click:Connect(function()
                    doTeleport(p)
                    teleLbl.Text = "→ "..n
                    b.BackgroundColor3 = Color3.fromRGB(0,40,20)
                    task.delay(1.5,function() pcall(function() b.BackgroundColor3=Color3.fromRGB(0,25,45) end) end)
                end)
            end
        end
        y=y+34
    end

    -- Custom coords
    Section(C,"📍 Custom Coords",y) y=y+22
    local coordInputs = {}
    local coordRow = Instance.new("Frame",C)
    coordRow.Size = UDim2.new(1,0,0,32)
    coordRow.Position = UDim2.new(0,0,0,y)
    coordRow.BackgroundTransparency = 1 coordRow.ZIndex = 10
    for i,label in ipairs({"X","Y","Z"}) do
        local lbl = Instance.new("TextLabel",coordRow)
        lbl.Size = UDim2.new(0,14,0,28) lbl.Position = UDim2.new((i-1)*0.33,2,0,2)
        lbl.BackgroundTransparency = 1 lbl.Text = label
        lbl.TextColor3 = Color3.fromRGB(100,180,220)
        lbl.TextSize = 10 lbl.Font = Enum.Font.GothamBold lbl.ZIndex = 11
        local inp = Instance.new("TextBox",coordRow)
        inp.Size = UDim2.new(0.28,0,0,28) inp.Position = UDim2.new((i-1)*0.33,16,0,2)
        inp.BackgroundColor3 = Color3.fromRGB(5,15,28)
        inp.Text = "0" inp.TextColor3 = Color3.fromRGB(200,230,255)
        inp.TextSize = 10 inp.Font = Enum.Font.Gotham
        inp.BorderSizePixel = 0 inp.ZIndex = 11
        Instance.new("UICorner",inp).CornerRadius = UDim.new(0,5)
        table.insert(coordInputs,inp)
    end
    y=y+36
    Btn(C,"🌀 Go to Coords",y,Color3.fromRGB(0,25,50),function()
        local x=tonumber(coordInputs[1].Text) or 0
        local yv=tonumber(coordInputs[2].Text) or 18
        local z=tonumber(coordInputs[3].Text) or 0
        doTeleport(Vector3.new(x,yv,z))
        teleLbl.Text=string.format("→ %.0f, %.0f, %.0f",x,yv,z)
    end) y=y+34

    -- Teleport to player
    Section(C,"👥 Teleport to Player",y) y=y+22
    local _,ptpLbl = InfoBox(C,"Select player below",y,20) y=y+24
    local function buildPlayerList()
        for _, v in pairs(C:GetChildren()) do
            if v.Name == "PlayerBtn" then v:Destroy() end
        end
        for _, p in pairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            local b = Instance.new("TextButton",C)
            b.Name = "PlayerBtn"
            b.Size = UDim2.new(1,-4,0,28) b.Position = UDim2.new(0,2,0,y)
            b.BackgroundColor3 = Color3.fromRGB(0,25,45)
            b.Text = "→ "..p.Name
            b.TextColor3 = Color3.fromRGB(0,200,255)
            b.TextSize = 11 b.Font = Enum.Font.GothamBold
            b.BorderSizePixel = 0 b.ZIndex = 11
            Instance.new("UICorner",b).CornerRadius = UDim.new(0,7)
            b.MouseButton1Click:Connect(function()
                local tHRP = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if tHRP then
                    doTeleport(tHRP.Position)
                    ptpLbl.Text = "→ "..p.Name
                end
            end)
            y=y+30
        end
        C.CanvasSize = UDim2.new(0,0,0,y+20)
    end
    buildPlayerList()
    Btn(C,"🔄 Refresh Players",y,Color3.fromRGB(0,20,40),function()
        buildPlayerList()
    end) y=y+34

    C.CanvasSize = UDim2.new(0,0,0,y+20)
end

-- ============================================================
-- JOBS TAB
-- ============================================================
do
    local C = JobsTab C.CanvasSize = UDim2.new(0,0,0,700)
    local y = 4

    Section(C,"💼 Change Job",y) y=y+22
    InfoBox(C,"Changes your team/job. Use with Farm tab to farm any job's salary.",y,28) y=y+32
    local _,jobStatusLbl = InfoBox(C,"Current job: "..tostring(LocalPlayer.Team and LocalPlayer.Team.Name or "None"),y,20) y=y+24

    -- Update job display
    task.spawn(function()
        while task.wait(2) do
            if not jobStatusLbl or not jobStatusLbl.Parent then break end
            pcall(function()
                jobStatusLbl.Text = "Current: "..(LocalPlayer.Team and LocalPlayer.Team.Name or "None")
            end)
        end
    end)

    -- All jobs as buttons
    for _, jname in ipairs(JOBS) do
        local b = Instance.new("TextButton",C)
        b.Size = UDim2.new(1,-4,0,28) b.Position = UDim2.new(0,2,0,y)
        b.BackgroundColor3 = Color3.fromRGB(0,20,38)
        b.Text = "💼 "..jname
        b.TextColor3 = Color3.fromRGB(0,180,220)
        b.TextSize = 10 b.Font = Enum.Font.GothamBold
        b.BorderSizePixel = 0 b.ZIndex = 11
        b.TextTruncate = Enum.TextTruncate.AtEnd
        Instance.new("UICorner",b).CornerRadius = UDim.new(0,7)
        local jn = jname
        b.MouseButton1Click:Connect(function()
            changeJob(jn)
            jobStatusLbl.Text = "→ "..jn
            b.BackgroundColor3 = Color3.fromRGB(0,40,20)
            task.delay(1.5,function() pcall(function() b.BackgroundColor3=Color3.fromRGB(0,20,38) end) end)
        end)
        y=y+30
    end

    C.CanvasSize = UDim2.new(0,0,0,y+20)
end

-- ============================================================
-- ESP TAB — BillboardGui based (Drawing not available on Wave)
-- ============================================================
do
    local C = ESPTab C.CanvasSize = UDim2.new(0,0,0,500)
    local y = 4

    Section(C,"👁 Player ESP",y) y=y+22
    InfoBox(C,"Uses BillboardGui tags above players since Wave doesn't support Drawing API. Shows names, health, distance.",y,34) y=y+38

    local espObjects = {} -- keyed by player
    local _,espStatusLbl = InfoBox(C,"ESP: OFF",y,20) y=y+24

    local function createESPTag(player)
        if espObjects[player] then return end
        local char = player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- Billboard above head
        local bb = Instance.new("BillboardGui")
        bb.Name = "SWFL_ESP"
        bb.Size = UDim2.new(0,120,0,40)
        bb.StudsOffset = Vector3.new(0,3,0)
        bb.AlwaysOnTop = true
        bb.Adornee = hrp
        bb.Parent = hrp

        -- Name label
        local nameL = Instance.new("TextLabel",bb)
        nameL.Size = UDim2.new(1,0,0.5,0)
        nameL.BackgroundTransparency = 1
        nameL.Text = player.Name
        nameL.TextColor3 = Color3.fromRGB(0,220,255)
        nameL.TextSize = 13 nameL.Font = Enum.Font.GothamBold
        nameL.TextStrokeTransparency = 0.5
        nameL.TextStrokeColor3 = Color3.new(0,0,0)

        -- Health/distance label
        local infoL = Instance.new("TextLabel",bb)
        infoL.Size = UDim2.new(1,0,0.5,0)
        infoL.Position = UDim2.new(0,0,0.5,0)
        infoL.BackgroundTransparency = 1
        infoL.TextColor3 = Color3.fromRGB(100,255,100)
        infoL.TextSize = 10 infoL.Font = Enum.Font.Gotham
        infoL.TextStrokeTransparency = 0.5
        infoL.TextStrokeColor3 = Color3.new(0,0,0)

        espObjects[player] = {bb=bb, nameL=nameL, infoL=infoL}

        -- Update info live
        task.spawn(function()
            while bb and bb.Parent and S.espOn do
                pcall(function()
                    local myH = getHRP()
                    local tH = char:FindFirstChild("HumanoidRootPart")
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if myH and tH then
                        local dist = math.floor((tH.Position-myH.Position).Magnitude)
                        local hp = hum and math.floor(hum.Health) or "?"
                        local maxhp = hum and math.floor(hum.MaxHealth) or "?"
                        infoL.Text = "❤ "..hp.."/"..maxhp.." | "..dist.."m"
                        -- Color by health
                        if hum then
                            local pct = hum.Health/math.max(hum.MaxHealth,1)
                            infoL.TextColor3 = Color3.fromHSV(pct*0.33,1,1)
                        end
                    end
                end)
                task.wait(0.2)
            end
        end)
    end

    local function removeESPTag(player)
        if espObjects[player] then
            pcall(function() espObjects[player].bb:Destroy() end)
            espObjects[player] = nil
        end
    end

    local function refreshESP()
        if not S.espOn then
            for p,_ in pairs(espObjects) do removeESPTag(p) end
            return
        end
        for _,p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                createESPTag(p)
            end
        end
    end

    -- ESP options
    Toggle(C,"👁 Enable ESP",y,function(v)
        S.espOn = v
        if v then
            refreshESP()
            -- Watch for character spawns
            for _,p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    p.CharacterAdded:Connect(function()
                        task.wait(0.5)
                        if S.espOn then createESPTag(p) end
                    end)
                end
            end
            Players.PlayerAdded:Connect(function(p)
                if S.espOn then
                    p.CharacterAdded:Connect(function()
                        task.wait(0.5)
                        if S.espOn then createESPTag(p) end
                    end)
                end
            end)
            Players.PlayerRemoving:Connect(function(p)
                removeESPTag(p)
            end)
            espStatusLbl.Text = "✅ ESP ACTIVE"
        else
            for p,_ in pairs(espObjects) do removeESPTag(p) end
            espStatusLbl.Text = "ESP: OFF"
        end
    end) y=y+36

    -- ESP color options
    Section(C,"🎨 ESP Color",y) y=y+22
    local colors = {
        {"🔵 Cyan",   Color3.fromRGB(0,220,255)},
        {"🔴 Red",    Color3.fromRGB(255,60,60)},
        {"🟢 Green",  Color3.fromRGB(60,255,100)},
        {"🟡 Yellow", Color3.fromRGB(255,230,50)},
        {"🟣 Purple", Color3.fromRGB(180,80,255)},
        {"⚪ White",  Color3.fromRGB(255,255,255)},
    }
    local colorRow = Instance.new("Frame",C)
    colorRow.Size = UDim2.new(1,0,0,32)
    colorRow.Position = UDim2.new(0,0,0,y)
    colorRow.BackgroundTransparency = 1 colorRow.ZIndex = 10
    local cl = Instance.new("UIListLayout",colorRow)
    cl.FillDirection = Enum.FillDirection.Horizontal
    cl.Padding = UDim.new(0,3)
    for _,cd in ipairs(colors) do
        local cb = Instance.new("TextButton",colorRow)
        cb.Size = UDim2.new(0,90,0,28)
        cb.BackgroundColor3 = cd[2]
        cb.Text = cd[1]
        cb.TextColor3 = Color3.new(0,0,0)
        cb.TextSize = 9 cb.Font = Enum.Font.GothamBold
        cb.BorderSizePixel = 0 cb.ZIndex = 11
        Instance.new("UICorner",cb).CornerRadius = UDim.new(0,5)
        local col = cd[2]
        cb.MouseButton1Click:Connect(function()
            S.espColor = col
            -- Update all existing tags
            for _,obj in pairs(espObjects) do
                pcall(function() obj.nameL.TextColor3 = col end)
            end
        end)
    end
    y=y+36

    -- Chams — make players glow neon
    Section(C,"✨ Chams",y) y=y+22
    InfoBox(C,"Makes players glow neon through walls.",y,22) y=y+26
    local chamsConn = nil
    Toggle(C,"✨ Enable Chams",y,function(v)
        S.chamsOn = v
        if v then
            if chamsConn then chamsConn:Disconnect() end
            chamsConn = RunService.Heartbeat:Connect(function()
                if not S.chamsOn then chamsConn:Disconnect() chamsConn=nil return end
                for _,p in pairs(Players:GetPlayers()) do
                    if p == LocalPlayer then continue end
                    local char = p.Character if not char then continue end
                    pcall(function()
                        for _,part in pairs(char:GetDescendants()) do
                            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                                part.Material = Enum.Material.Neon
                                part.Color = S.espColor or Color3.fromRGB(0,220,255)
                                part.LocalTransparencyModifier = 0
                            end
                        end
                    end)
                end
            end)
        else
            if chamsConn then chamsConn:Disconnect() chamsConn=nil end
            -- Restore
            for _,p in pairs(Players:GetPlayers()) do
                if p == LocalPlayer then continue end
                local char = p.Character if not char then continue end
                pcall(function()
                    for _,part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.Material = Enum.Material.SmoothPlastic
                            part.LocalTransparencyModifier = 0
                        end
                    end
                end)
            end
        end
    end) y=y+36

    C.CanvasSize = UDim2.new(0,0,0,y+20)
end

-- ============================================================
-- PLAYERS TAB
-- ============================================================
do
    local C = PlayersTab C.CanvasSize = UDim2.new(0,0,0,800)
    local y = 4

    Section(C,"👥 Players",y) y=y+22
    local _,selLbl = InfoBox(C,"No player selected",y,20) y=y+24

    -- Player list
    local listOpen = false
    local listToggle = Instance.new("TextButton",C)
    listToggle.Size = UDim2.new(1,-4,0,30)
    listToggle.Position = UDim2.new(0,2,0,y)
    listToggle.BackgroundColor3 = Color3.fromRGB(0,25,50)
    listToggle.Text = "▼  Show Players  ▼"
    listToggle.TextColor3 = Color3.fromRGB(0,200,255)
    listToggle.TextSize = 12 listToggle.Font = Enum.Font.GothamBold
    listToggle.BorderSizePixel = 0 listToggle.ZIndex = 12
    Instance.new("UICorner",listToggle).CornerRadius = UDim.new(0,7)
    y=y+34

    local listFrame = Instance.new("ScrollingFrame",C)
    listFrame.Size = UDim2.new(1,-4,0,0)
    listFrame.Position = UDim2.new(0,2,0,y)
    listFrame.BackgroundColor3 = Color3.fromRGB(5,12,22)
    listFrame.BackgroundTransparency = 0.1
    listFrame.BorderSizePixel = 0
    listFrame.ScrollBarThickness = 3
    listFrame.ScrollBarImageColor3 = Color3.fromRGB(0,200,255)
    listFrame.ZIndex = 11
    Instance.new("UICorner",listFrame).CornerRadius = UDim.new(0,8)

    local playerBtns = {}
    local function buildPlayerList()
        for _,b in ipairs(playerBtns) do pcall(function() b:Destroy() end) end
        playerBtns = {}
        local py = 3
        for _,p in pairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            local row = Instance.new("Frame",listFrame)
            row.Size = UDim2.new(1,-6,0,32)
            row.Position = UDim2.new(0,3,0,py)
            row.BackgroundColor3 = Color3.fromRGB(0,20,38)
            row.BorderSizePixel = 0 row.ZIndex = 12
            Instance.new("UICorner",row).CornerRadius = UDim.new(0,6)

            -- Name
            local nl = Instance.new("TextLabel",row)
            nl.Size = UDim2.new(0.55,0,1,0) nl.Position = UDim2.new(0,8,0,0)
            nl.BackgroundTransparency = 1 nl.Text = p.Name
            nl.TextColor3 = Color3.fromRGB(200,230,255)
            nl.TextSize = 11 nl.Font = Enum.Font.GothamBold
            nl.TextXAlignment = Enum.TextXAlignment.Left
            nl.TextTruncate = Enum.TextTruncate.AtEnd nl.ZIndex = 13

            -- Distance
            local dl = Instance.new("TextLabel",row)
            dl.Size = UDim2.new(0.4,0,1,0) dl.Position = UDim2.new(0.58,0,0,0)
            dl.BackgroundTransparency = 1 dl.Text = "--m"
            dl.TextColor3 = Color3.fromRGB(80,140,180)
            dl.TextSize = 10 dl.Font = Enum.Font.Gotham
            dl.TextXAlignment = Enum.TextXAlignment.Right dl.ZIndex = 13

            -- Click to select
            local btn = Instance.new("TextButton",row)
            btn.Size = UDim2.new(1,0,1,0)
            btn.BackgroundTransparency = 1 btn.Text = "" btn.ZIndex = 14
            local cp = p
            btn.MouseButton1Click:Connect(function()
                S.selectedPlayer = cp
                selLbl.Text = "✅ Selected: "..cp.Name
                for _,b2 in ipairs(playerBtns) do
                    pcall(function() b2.BackgroundColor3=Color3.fromRGB(0,20,38) end)
                end
                row.BackgroundColor3 = Color3.fromRGB(0,40,20)
                listOpen = false
                listFrame.Size = UDim2.new(1,-4,0,0)
                listToggle.Text = "▼  "..cp.Name.."  ▼"
                listToggle.TextColor3 = Color3.fromRGB(80,255,80)
            end)

            -- Live distance
            task.spawn(function()
                while row and row.Parent do
                    local myH = getHRP()
                    local tH = cp.Character and cp.Character:FindFirstChild("HumanoidRootPart")
                    if myH and tH then
                        pcall(function() dl.Text=math.floor((tH.Position-myH.Position).Magnitude).."m" end)
                    end
                    task.wait(0.5)
                end
            end)

            table.insert(playerBtns,row)
            py = py+34
        end
        listFrame.CanvasSize = UDim2.new(0,0,0,py+4)
        if listOpen then
            listFrame.Size = UDim2.new(1,-4,0,math.min(py+4,180))
        end
    end

    buildPlayerList()

    listToggle.MouseButton1Click:Connect(function()
        listOpen = not listOpen
        if listOpen then
            buildPlayerList()
            listFrame.Size = UDim2.new(1,-4,0,180)
            listToggle.Text = "▲  Close  ▲"
            listToggle.TextColor3 = Color3.fromRGB(0,200,255)
        else
            listFrame.Size = UDim2.new(1,-4,0,0)
            listToggle.Text = S.selectedPlayer and ("▼  "..S.selectedPlayer.Name.."  ▼") or "▼  Show Players  ▼"
            listToggle.TextColor3 = S.selectedPlayer and Color3.fromRGB(80,255,80) or Color3.fromRGB(0,200,255)
        end
    end)

    Players.PlayerAdded:Connect(function() task.wait(0.5) buildPlayerList() end)
    Players.PlayerRemoving:Connect(function(p)
        task.wait(0.5) buildPlayerList()
        if S.selectedPlayer == p then
            S.selectedPlayer = nil
            selLbl.Text = "Player left"
        end
    end)

    y = y + 184

    -- Actions
    Section(C,"⚡ Actions",y) y=y+22

    -- Teleport to player
    Btn(C,"🌀 Teleport To Player",y,Color3.fromRGB(0,25,50),function()
        local p = S.selectedPlayer
        if not p then selLbl.Text="⚠ Select a player first" return end
        local tH = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if not tH then selLbl.Text="⚠ No character" return end
        doTeleport(tH.Position)
        selLbl.Text="→ "..p.Name
    end) y=y+34

    -- Spectate
    local spectating = false
    local spectateConn = nil
    Toggle(C,"📷 Spectate",y,function(v)
        spectating = v
        if v then
            local p = S.selectedPlayer
            if not p then selLbl.Text="⚠ Select first" return end
            if spectateConn then spectateConn:Disconnect() end
            spectateConn = RunService.RenderStepped:Connect(function()
                if not spectating then return end
                local char = p.Character if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart") if not hrp then return end
                Camera.CFrame = CFrame.new(
                    hrp.Position + hrp.CFrame.LookVector*-8 + Vector3.new(0,4,0),
                    hrp.Position + Vector3.new(0,2,0)
                )
            end)
            Camera.CameraType = Enum.CameraType.Scriptable
            selLbl.Text = "📷 Spectating: "..p.Name
        else
            if spectateConn then spectateConn:Disconnect() spectateConn=nil end
            Camera.CameraType = Enum.CameraType.Custom
        end
    end) y=y+36

    -- Freeze
    local frozenPlayers = {}
    Btn(C,"❄ Freeze / Unfreeze",y,Color3.fromRGB(0,20,45),function()
        local p = S.selectedPlayer
        if not p then selLbl.Text="⚠ Select first" return end
        local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then selLbl.Text="⚠ No character" return end
        if frozenPlayers[p] then
            local bp = hrp:FindFirstChild("SWFLFreeze")
            if bp then bp:Destroy() end
            frozenPlayers[p] = nil
            selLbl.Text = "Unfroze: "..p.Name
        else
            local bp = Instance.new("BodyPosition")
            bp.Name = "SWFLFreeze"
            bp.MaxForce = Vector3.new(1e9,1e9,1e9)
            bp.Position = hrp.Position
            bp.D = 500 bp.P = 1e5
            bp.Parent = hrp
            frozenPlayers[p] = true
            selLbl.Text = "❄ Froze: "..p.Name
        end
    end) y=y+34

    -- PvP / Inflict
    Section(C,"⚔ PvP",y) y=y+22
    InfoBox(C,"InflictTarget RemoteFunction confirmed. Tries to damage selected player.",y,28) y=y+32
    local _,pvpLbl = InfoBox(C,"Select player then attack",y,20) y=y+24

    Btn(C,"💀 Attack Player",y,Color3.fromRGB(35,0,0),function()
        local p = S.selectedPlayer
        if not p then pvpLbl.Text="⚠ Select first" return end
        local char = p.Character if not char then pvpLbl.Text="⚠ No char" return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        -- Method 1: InflictTarget RemoteFunction
        if InflictTarget then
            local ok,r = pcall(function()
                return InflictTarget:InvokeServer(p, 999, "Headshot")
            end)
            pvpLbl.Text = "InflictTarget: "..tostring(ok).." "..tostring(r)
        end
        -- Method 2: pvpManagerEvent
        if PvpEvent then
            pcall(function() PvpEvent:FireServer(p, 999) end)
            pcall(function() PvpEvent:FireServer({target=p, damage=999}) end)
        end
        -- Method 3: zero health client side
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.Health = 0 end) end
    end) y=y+34

    Btn(C,"💀 Kill Aura (all nearby)",y,Color3.fromRGB(30,0,0),function()
        local hrp = getHRP() if not hrp then return end
        for _,p in pairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            local char = p.Character if not char then continue end
            local tHRP = char:FindFirstChild("HumanoidRootPart") if not tHRP then continue end
            if (tHRP.Position-hrp.Position).Magnitude > 50 then continue end
            if InflictTarget then
                pcall(function() InflictTarget:InvokeServer(p,999,"Melee") end)
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.Health=0 end) end
        end
        pvpLbl.Text = "Kill aura fired!"
    end) y=y+34

    -- Character mods
    Section(C,"🏃 Character Mods",y) y=y+22

    Toggle(C,"♾ Infinite Stamina",y,function(v)
        S.staminaOn = v
        if v then
            task.spawn(function()
                while S.staminaOn do
                    local char = LocalPlayer.Character if not char then task.wait(0.5) continue end
                    -- Find stamina value
                    for _,val in pairs(char:GetDescendants()) do
                        local ln = val.Name:lower()
                        if ln:find("stamina") or ln:find("energy") or ln:find("sprint") then
                            pcall(function()
                                if val:IsA("NumberValue") or val:IsA("IntValue") then
                                    val.Value = 9999
                                end
                            end)
                        end
                    end
                    -- Also check player values
                    for _,val in pairs(LocalPlayer:GetDescendants()) do
                        local ln = val.Name:lower()
                        if ln:find("stamina") or ln:find("energy") or ln:find("sprint") then
                            pcall(function()
                                if val:IsA("NumberValue") or val:IsA("IntValue") then
                                    val.Value = 9999
                                end
                            end)
                        end
                    end
                    task.wait(0.3)
                end
            end)
        end
    end) y=y+36

    Toggle(C,"🪂 No Fall Damage",y,function(v)
        S.noFallDmg = v
        if v then
            task.spawn(function()
                while S.noFallDmg do
                    local hum = getHum()
                    if hum then
                        pcall(function()
                            -- Keep health up to counter fall damage
                            if hum.Health < hum.MaxHealth*0.9 then
                                hum.Health = hum.MaxHealth
                            end
                        end)
                    end
                    task.wait(0.1)
                end
            end)
        end
    end) y=y+36

    Toggle(C,"🔇 Anti-AFK",y,function(v)
        S.antiAfkOn = v
        if v then
            -- Keep sending false to AfkEvent so server never marks us AFK
            task.spawn(function()
                while S.antiAfkOn do
                    local ae = RS:FindFirstChild("AfkEvent")
                    if ae then pcall(function() ae:FireServer(false) end) end
                    task.wait(10)
                end
            end)
        end
    end) y=y+36

    C.CanvasSize = UDim2.new(0,0,0,y+20)
end

-- ============================================================
-- MISC TAB
-- ============================================================
do
    local C = MiscTab C.CanvasSize = UDim2.new(0,0,0,600)
    local y = 4

    -- AFK Farm
    Section(C,"💤 AFK Farm",y) y=y+22
    InfoBox(C,"AfkEvent confirmed. Server gives AFK rewards including Golden Crates. Fire true to go AFK.",y,34) y=y+38
    local _,afkLbl = InfoBox(C,"AFK: OFF",y,20) y=y+24

    local afkActive = false
    local afkConn = nil
    Toggle(C,"💤 AFK Farm Loop",y,function(v)
        afkActive = v
        local ae = game:GetService("ReplicatedStorage"):FindFirstChild("AfkEvent")
        if not ae then afkLbl.Text="⚠ AfkEvent not found" return end
        if v then
            -- Go AFK
            pcall(function() ae:FireServer(true) end)
            -- Listen for rewards
            afkConn = ae.OnClientEvent:Connect(function(...)
                local args = {...}
                local str = ""
                for _,a in ipairs(args) do str=str..tostring(a).." " end
                pcall(function() afkLbl.Text="💰 AFK Reward: "..str end)
            end)
            afkLbl.Text="💤 AFK ACTIVE — waiting for rewards"
        else
            pcall(function() ae:FireServer(false) end)
            if afkConn then afkConn:Disconnect() afkConn=nil end
            afkLbl.Text="AFK: OFF"
        end
    end) y=y+36

    -- Admin Chat Reader
    Section(C,"👁 Admin Chat Reader",y) y=y+22
    InfoBox(C,"Reads admin chat logs using AdminChatEvent:FireServer('GetAll'). See what admins are saying.",y,34) y=y+38
    local _,adminLbl = InfoBox(C,"Click to fetch admin logs",y,20) y=y+24

    local adminLogFrame = Instance.new("ScrollingFrame",C)
    adminLogFrame.Size = UDim2.new(1,-4,0,120)
    adminLogFrame.Position = UDim2.new(0,2,0,y)
    adminLogFrame.BackgroundColor3 = Color3.fromRGB(4,10,18)
    adminLogFrame.BorderSizePixel = 0
    adminLogFrame.ScrollBarThickness = 3
    adminLogFrame.ScrollBarImageColor3 = Color3.fromRGB(0,200,255)
    adminLogFrame.ZIndex = 11
    adminLogFrame.CanvasSize = UDim2.new(0,0,0,0)
    Instance.new("UICorner",adminLogFrame).CornerRadius = UDim.new(0,8)
    local adminLogY = 4
    local function addAdminLog(text)
        local l = Instance.new("TextLabel",adminLogFrame)
        l.Size = UDim2.new(1,-8,0,18)
        l.Position = UDim2.new(0,4,0,adminLogY)
        l.BackgroundTransparency = 1
        l.Text = text l.TextColor3 = Color3.fromRGB(0,200,255)
        l.TextSize = 9 l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.ZIndex = 12
        adminLogY = adminLogY + 20
        adminLogFrame.CanvasSize = UDim2.new(0,0,0,adminLogY+4)
        adminLogFrame.CanvasPosition = Vector2.new(0,adminLogY)
    end
    y=y+124

    Btn(C,"👁 Fetch Admin Logs",y,Color3.fromRGB(0,25,50),function()
        local ace = game:GetService("ReplicatedStorage"):FindFirstChild("AdminChatEvent")
        if not ace then adminLbl.Text="⚠ AdminChatEvent not found" return end
        adminLbl.Text="Fetching..."
        -- Listen for response
        local conn conn = ace.OnClientEvent:Connect(function(logs)
            if type(logs) == "table" then
                for _,log in ipairs(logs) do
                    if type(log) == "table" then
                        local txt = (log.Executor or "?").." ["..((log.Timestamp or "?")).."] "..((log.Message or ""))
                        addAdminLog(txt)
                    end
                end
                adminLbl.Text="✅ Loaded "..(#logs).." logs"
            end
            conn:Disconnect()
        end)
        pcall(function() ace:FireServer("GetAll") end)
        task.delay(3, function()
            pcall(function() conn:Disconnect() end)
            if adminLbl.Text == "Fetching..." then
                adminLbl.Text = "No response — may need admin rank"
            end
        end)
    end) y=y+34

    -- JL Event (join/leave logger)
    Btn(C,"📋 Fetch Join/Leave Logs",y,Color3.fromRGB(0,20,40),function()
        local jle = game:GetService("ReplicatedStorage"):FindFirstChild("JLEvent")
        if not jle then adminLbl.Text="⚠ JLEvent not found" return end
        local conn conn = jle.OnClientEvent:Connect(function(logs)
            if type(logs) == "table" then
                for _,log in ipairs(logs) do
                    if type(log) == "table" then
                        local action = log.IsJoining and "joined" or "left"
                        addAdminLog((log.Executor or "?").." "..action.." @ "..(log.Timestamp or "?"))
                    end
                end
                adminLbl.Text="✅ Got "..(#logs).." join/leave events"
            end
            conn:Disconnect()
        end)
        pcall(function() jle:FireServer("GetAll") end)
        task.delay(3, function() pcall(function() conn:Disconnect() end) end)
    end) y=y+34
    Section(C,"🔘 Proximity Prompt Farm",y) y=y+22
    InfoBox(C,"Uses Wave's fireproximityprompt to trigger all nearby interactions. Works on ATMs, job stations, shops etc.",y,40) y=y+44
    local _,ppLbl = InfoBox(C,"Ready",y,20) y=y+24
    Slider(C,"Radius (studs)",5,100,30,y,function(v) S.ppRadius=v end) y=y+46

    local ppActive = false
    local ppConn = nil
    Toggle(C,"🔘 Auto Fire Prompts",y,function(v)
        ppActive = v
        if v then
            if ppConn then pcall(function() task.cancel(ppConn) end) end
            ppConn = task.spawn(function()
                while ppActive do
                    local count = fireNearbyPrompts(S.ppRadius or 30)
                    pcall(function() ppLbl.Text = "Fired "..count.." prompts" end)
                    task.wait(1)
                end
            end)
        else
            ppActive = false
            if ppConn then pcall(function() task.cancel(ppConn) end) ppConn=nil end
            ppLbl.Text = "Stopped"
        end
    end) y=y+36
    Btn(C,"🔘 Fire Once NOW",y,Color3.fromRGB(0,30,55),function()
        local count = fireNearbyPrompts(S.ppRadius or 30)
        ppLbl.Text = "Fired "..count.." prompts"
    end) y=y+34

    -- Twitter codes
    Section(C,"🐦 Twitter Codes",y) y=y+22
    InfoBox(C,"Tries all known active codes automatically.",y,22) y=y+26
    local _,codeLbl = InfoBox(C,"Ready",y,20) y=y+24
    Btn(C,"🐦 Try All Codes",y,Color3.fromRGB(0,30,60),function()
        task.spawn(function()
            codeLbl.Text = "Trying "..#SWF_CODES.." codes..."
            tryAllCodes()
            codeLbl.Text = "Done — check for notifications!"
        end)
    end) y=y+34

    -- Manual code entry
    local codeBox = Instance.new("TextBox",C)
    codeBox.Size = UDim2.new(0.68,-2,0,28) codeBox.Position = UDim2.new(0,2,0,y)
    codeBox.BackgroundColor3 = Color3.fromRGB(5,15,28)
    codeBox.Text = "" codeBox.PlaceholderText = "Enter code..."
    codeBox.TextColor3 = Color3.fromRGB(200,230,255)
    codeBox.TextSize = 11 codeBox.Font = Enum.Font.Gotham
    codeBox.BorderSizePixel = 0 codeBox.ZIndex = 11
    Instance.new("UICorner",codeBox).CornerRadius = UDim.new(0,7)
    local redeemBtn = Instance.new("TextButton",C)
    redeemBtn.Size = UDim2.new(0.3,-2,0,28) redeemBtn.Position = UDim2.new(0.7,2,0,y)
    redeemBtn.BackgroundColor3 = Color3.fromRGB(0,40,80)
    redeemBtn.Text = "Redeem"
    redeemBtn.TextColor3 = Color3.fromRGB(0,200,255)
    redeemBtn.TextSize = 11 redeemBtn.Font = Enum.Font.GothamBold
    redeemBtn.BorderSizePixel = 0 redeemBtn.ZIndex = 11
    Instance.new("UICorner",redeemBtn).CornerRadius = UDim.new(0,7)
    redeemBtn.MouseButton1Click:Connect(function()
        local code = codeBox.Text
        if code ~= "" then
            pcall(function() Twitter:FireServer(code) end)
            codeLbl.Text = "Tried: "..code
        end
    end)
    y=y+32

    -- Spawn Car
    Section(C,"🚗 Spawn Car",y) y=y+22
    InfoBox(C,"SpawnCar remote confirmed. Enter car name from the dealership.",y,28) y=y+32
    local carBox = Instance.new("TextBox",C)
    carBox.Size = UDim2.new(0.68,-2,0,28) carBox.Position = UDim2.new(0,2,0,y)
    carBox.BackgroundColor3 = Color3.fromRGB(5,15,28)
    carBox.Text = "" carBox.PlaceholderText = "Car name..."
    carBox.TextColor3 = Color3.fromRGB(200,230,255)
    carBox.TextSize = 11 carBox.Font = Enum.Font.Gotham
    carBox.BorderSizePixel = 0 carBox.ZIndex = 11
    Instance.new("UICorner",carBox).CornerRadius = UDim.new(0,7)
    local spawnBtn = Instance.new("TextButton",C)
    spawnBtn.Size = UDim2.new(0.3,-2,0,28) spawnBtn.Position = UDim2.new(0.7,2,0,y)
    spawnBtn.BackgroundColor3 = Color3.fromRGB(0,40,80)
    spawnBtn.Text = "Spawn"
    spawnBtn.TextColor3 = Color3.fromRGB(0,200,255)
    spawnBtn.TextSize = 11 spawnBtn.Font = Enum.Font.GothamBold
    spawnBtn.BorderSizePixel = 0 spawnBtn.ZIndex = 11
    Instance.new("UICorner",spawnBtn).CornerRadius = UDim.new(0,7)
    spawnBtn.MouseButton1Click:Connect(function()
        local car = carBox.Text
        if car ~= "" then
            spawnCar(car)
        end
    end) y=y+32

    -- Server actions
    Section(C,"🌐 Server",y) y=y+22
    Btn(C,"🔄 Rejoin",y,Color3.fromRGB(0,20,40),function()
        pcall(function()
            game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
        end)
    end) y=y+34

    C.CanvasSize = UDim2.new(0,0,0,y+20)
end

-- ============================================================
-- CARS TAB
-- ============================================================
do
    local C = CarsTab C.CanvasSize = UDim2.new(0,0,0,900)
    local y = 4

    -- Helper to find player's current car
    local function getMyCar()
        local cars = workspace:FindFirstChild("Cars")
        if not cars then return nil end
        local lp = LocalPlayer
        -- Method 1: check PlayerLoc ObjectValue
        for _, v in pairs(cars:GetChildren()) do
            local pl = v:FindFirstChild("PlayerLoc")
            if pl and pl.Value == lp.Character then return v end
        end
        -- Method 2: check DriveSeat occupant
        for _, v in pairs(cars:GetChildren()) do
            local body = v:FindFirstChild("Body")
            if body then
                local seat = body:FindFirstChild("DriveSeat") or
                             v:FindFirstChildOfClass("VehicleSeat")
                if seat and seat.Occupant then
                    local hum = seat.Occupant
                    if hum and hum.Parent == lp.Character then return v end
                end
            end
        end
        return nil
    end

    -- Get tune module from car
    local function getTune(car)
        if not car then return nil end
        local t = car:FindFirstChild("A-Chassis Tune") or car:FindFirstChild("Tuner")
        if not t then return nil end
        local ok, data = pcall(function() return require(t) end)
        return ok and type(data)=="table" and data or nil
    end

    -- Set tune value
    local function setTune(car, key, val)
        local t = car:FindFirstChild("A-Chassis Tune") or car:FindFirstChild("Tuner")
        if not t then return false end
        local ok, data = pcall(function() return require(t) end)
        if ok and type(data)=="table" then
            pcall(function() data[key] = val end)
            return true
        end
        return false
    end

    Section(C,"🚗 My Car",y) y=y+22
    local _,carStatusLbl = InfoBox(C,"No car — spawn one first",y,20) y=y+24

    -- Live car status
    task.spawn(function()
        while task.wait(1) do
            if not carStatusLbl or not carStatusLbl.Parent then break end
            local car = getMyCar()
            if car then
                local fuel = car:FindFirstChild("Fuel")
                local tune = getTune(car)
                local hp = tune and tune.Horsepower or "?"
                local torq = tune and tune.E_Torque or "?"
                pcall(function()
                    carStatusLbl.Text = "🚗 "..car.Name.." | HP:"..tostring(hp).." | Fuel:"..(fuel and math.floor(fuel.Value) or "?")
                end)
            else
                pcall(function() carStatusLbl.Text = "No car found" end)
            end
        end
    end)

    -- Infinite Fuel
    Section(C,"⛽ Fuel",y) y=y+22
    InfoBox(C,"Sets Fuel and GasCap to 9999 — confirmed works client-side.",y,26) y=y+30
    local _,fuelLbl = InfoBox(C,"Fuel: --",y,20) y=y+24

    local fuelLoop = false
    local fuelConn = nil
    Toggle(C,"⛽ Infinite Fuel",y,function(v)
        fuelLoop = v
        if v then
            if fuelConn then pcall(function() task.cancel(fuelConn) end) end
            fuelConn = task.spawn(function()
                while fuelLoop do
                    local car = getMyCar()
                    if car then
                        -- Directly set fuel values
                        local fuel = car:FindFirstChild("Fuel")
                        local cap = car:FindFirstChild("gasCap")
                        if fuel then
                            pcall(function() fuel.Value = cap and cap.Value or 100 end)
                        end
                        pcall(function() fuelLbl.Text = "⛽ INFINITE — car: "..car.Name end)
                    else
                        pcall(function() fuelLbl.Text = "⛽ Active — waiting for car..." end)
                    end
                    task.wait(1) -- every 1 second is plenty
                end
                fuelLbl.Text = "Stopped"
            end)
        else
            fuelLoop = false
            if fuelConn then pcall(function() task.cancel(fuelConn) end) fuelConn=nil end
            fuelLbl.Text = "OFF"
        end
    end) y=y+36

    -- Speed Hack via Tune
    Section(C,"⚡ Car Speed Hack",y) y=y+22
    InfoBox(C,"Modifies A-Chassis Tune values. Horsepower + Torque + FinalDrive = max speed.",y,34) y=y+38
    local _,speedLbl = InfoBox(C,"Ready — get in a car first",y,20) y=y+24

    Slider(C,"Horsepower",100,99999,9999,y,function(v)
        S.carHP = v
        local car = getMyCar()
        if car then setTune(car,"Horsepower",v) end
    end) y=y+46

    Slider(C,"Torque",100,99999,9999,y,function(v)
        S.carTorque = v
        local car = getMyCar()
        if car then setTune(car,"E_Torque",v) end
    end) y=y+46

    Btn(C,"⚡ MAX SPEED NOW",y,Color3.fromRGB(0,35,60),function()
        local car = getMyCar()
        if not car then speedLbl.Text="⚠ Get in a car first" return end
        -- Set all performance values to max
        local vals = {
            Horsepower=99999, E_Torque=99999,
            S_Boost=99, FinalDrive=9.9,
            Weight=100, ThrotAccel=1,
            BrakeDecel=0.01, E_Redline=99999,
        }
        local set = 0
        for k,v in pairs(vals) do
            if setTune(car,k,v) then set=set+1 end
        end
        -- Also set fuel
        local fuel = car:FindFirstChild("Fuel")
        local cap = car:FindFirstChild("gasCap")
        if fuel then pcall(function() fuel.Value=9999 end) end
        if cap then pcall(function() cap.Value=9999 end) end
        speedLbl.Text="✅ Maxed "..set.." tune values!"
    end) y=y+34

    -- Handling controls
    Section(C,"🎮 Handling",y) y=y+22
    InfoBox(C,"Tune steering and brakes for better control at high speed.",y,26) y=y+30

    Slider(C,"Steering Ratio (lower=tighter)",1,20,9,y,function(v)
        local car = getMyCar()
        if car then setTune(car,"SteerRatio",v) end
    end) y=y+46

    Slider(C,"Brake Bias (0.5=balanced)",1,100,57,y,function(v)
        local car = getMyCar()
        if car then setTune(car,"BrakeBias",v/100) end
    end) y=y+46

    Slider(C,"Steer Speed",1,20,7,y,function(v)
        local car = getMyCar()
        if car then setTune(car,"SteerSpeed",v/100) end
    end) y=y+46

    Btn(C,"🎮 BEST HANDLING PRESET",y,Color3.fromRGB(0,30,55),function()
        local car = getMyCar()
        if not car then speedLbl.Text="⚠ Get in car first" return end
        local vals = {
            SteerRatio=6, BrakeBias=0.55,
            SteerSpeed=0.12, ReturnSpeed=0.15,
            RAntiRoll=30, Ackerman=1.0,
            FCaster=3, RCamber=1.5, RToe=0.1,
        }
        for k,v in pairs(vals) do setTune(car,k,v) end
        speedLbl.Text="✅ Best handling applied!"
    end) y=y+34


    Btn(C,"🔁 Reset Tune",y,Color3.fromRGB(20,10,10),function()
        local car = getMyCar()
        if not car then speedLbl.Text="⚠ Get in a car first" return end
        local vals = {
            Horsepower=549, E_Torque=286,
            S_Boost=11.6, FinalDrive=3.7,
            Weight=5710, ThrotAccel=0.05,
            BrakeDecel=0.5, E_Redline=12700,
        }
        for k,v in pairs(vals) do setTune(car,k,v) end
        speedLbl.Text="Reset to default"
    end) y=y+34

    -- Car list to spawn
    Section(C,"🚗 Spawn Any Car",y) y=y+22
    InfoBox(C,"All confirmed car names from live carPrices scan. Click to spawn.",y,28) y=y+32
    local _,spawnLbl = InfoBox(C,"Click car to spawn",y,20) y=y+24

    -- Search box
    local carSearch = Instance.new("TextBox",C)
    carSearch.Size = UDim2.new(1,-4,0,28) carSearch.Position = UDim2.new(0,2,0,y)
    carSearch.BackgroundColor3 = Color3.fromRGB(5,15,28)
    carSearch.Text = "" carSearch.PlaceholderText = "Search cars..."
    carSearch.TextColor3 = Color3.fromRGB(200,230,255)
    carSearch.TextSize = 11 carSearch.Font = Enum.Font.Gotham
    carSearch.BorderSizePixel = 0 carSearch.ZIndex = 11
    Instance.new("UICorner",carSearch).CornerRadius = UDim.new(0,7)
    y=y+32

    -- Scrolling car list
    local carListFrame = Instance.new("ScrollingFrame",C)
    carListFrame.Size = UDim2.new(1,-4,0,300)
    carListFrame.Position = UDim2.new(0,2,0,y)
    carListFrame.BackgroundColor3 = Color3.fromRGB(4,10,18)
    carListFrame.BackgroundTransparency = 0.1
    carListFrame.BorderSizePixel = 0
    carListFrame.ScrollBarThickness = 3
    carListFrame.ScrollBarImageColor3 = Color3.fromRGB(0,200,255)
    carListFrame.ZIndex = 11
    Instance.new("UICorner",carListFrame).CornerRadius = UDim.new(0,8)

    -- All confirmed car names from live scan
    local ALL_CARS = {
        -- Hyper
        "p918Weissach","hVenomGT","aIntensaEmozione","pHuay",
        -- Super
        "nR35","nR35TS_kit","nR35LB_kit","fGT","f2020GT","fSF90",
        "m570GT","m650S","m675LT","m765LT","mGTRBS",
        "p911GT2RS","p911GT3RS","pGT2RS","p718CaymanGT4RS",
        "cC8Z06","cC8Z07","aNSXTypeS","fSN95Terminator",
        -- Classic
        "1Countach","1Delta","1Stratos","fTesta","mFCRX7",
        "bGNX","fFoxbody","fFoxbodyCobra","fBosstang","fF100",
        "gYukon","aGiuliaGTA","nR34RCM_kit","nR34CS_kit",
        -- Coupe
        "n350ZCWest_kit","n350ZRB_kit","n350ZVertex_kit",
        "mRX7ReAm_kit","mRX7RB_kit","mRX7BN_kit","mRX8",
        "tGT86Charge_kit","tGT86Modellista_kit","tGT86RB_kit",
        "b2023M240i","b2023M2","bE36M3RB_kit",
        "eG35Coupe","cCTSVCoupe","nS14","nSilviaK","n180SX",
        "n370ZEnds_kit","n370ZAvoidless_kit","n370ZAmuze_kit",
        "fSN95CobraR","fS197Must","fRS200","fMustSuperSnake",
        "fMustNFS","fMusGTTRT5","fMusGTTRT3","fMusGT500CR",
        "fMusGT500","fMusGT350R","fMusGT","f2013MusGTVert",
        "f2013MusGT","1340R","13Eleven","pGTO","gSyclone",
        "mGranTurismo","hS2000Amuze_kit","s22B",
        -- Sedan
        "mEvo4","nAltima","cCTSV","cCTSVWagon","m190E",
        "mQuattroporte","fTaurus","fFsion","fCrownVic","dNeon",
        -- Hatchback
        "lDelta","h23CivicTypeR","h23CivicTypeRFork_kit",
        "h95CivicMugen_kit","fFocusRS","fFiesta",
        -- SUV
        "vAtlas","gYukon","fBrnco2dr","fBrnco4dr","fBrnco4drTRT","fExpdtn",
        -- Pickup
        "gSierra2500","gSierra3500","jGlad","FRanger","fMaverick",
        "f95Lightning","f99Lightning",
        -- Motorcycles
        "hNR750","hRC30","kZXR750","SGSXR750","kZX7RR",
        -- Emergency
        "fTaurusSheriffUnd","fSheriffMusGT","fFsionUnd","fExpPolice","fExpPoliceUnd",
    }

    local carBtns = {}
    local function buildCarList(filter)
        for _,b in ipairs(carBtns) do pcall(function() b:Destroy() end) end
        carBtns = {}
        local cy = 4
        for _,name in ipairs(ALL_CARS) do
            if not filter or name:lower():find(filter:lower()) then
                local b = Instance.new("TextButton",carListFrame)
                b.Size = UDim2.new(1,-6,0,26)
                b.Position = UDim2.new(0,3,0,cy)
                b.BackgroundColor3 = Color3.fromRGB(0,20,38)
                b.Text = "🚗 "..name
                b.TextColor3 = Color3.fromRGB(0,180,220)
                b.TextSize = 10 b.Font = Enum.Font.GothamBold
                b.TextXAlignment = Enum.TextXAlignment.Left
                b.BorderSizePixel = 0 b.ZIndex = 12
                Instance.new("UICorner",b).CornerRadius = UDim.new(0,5)
                local n = name
                b.MouseButton1Click:Connect(function()
                    pcall(function() SpawnCar:FireServer(n) end)
                    spawnLbl.Text = "Spawned: "..n
                    b.BackgroundColor3 = Color3.fromRGB(0,40,20)
                    task.delay(1.5,function() pcall(function() b.BackgroundColor3=Color3.fromRGB(0,20,38) end) end)
                end)
                table.insert(carBtns,b)
                cy = cy+28
            end
        end
        carListFrame.CanvasSize = UDim2.new(0,0,0,cy+4)
    end

    buildCarList(nil)
    carSearch:GetPropertyChangedSignal("Text"):Connect(function()
        buildCarList(carSearch.Text~="" and carSearch.Text or nil)
    end)
    y=y+304

    C.CanvasSize = UDim2.new(0,0,0,y+20)
end

-- ============================================================
-- SETTINGS TAB
-- ============================================================
do
    local C = SettingsTab C.CanvasSize = UDim2.new(0,0,0,400)
    local y = 4

    Section(C,"🌴 SWF Script",y) y=y+22
    local _,verLbl = InfoBox(C,"Southwest Florida Beta | v1.0 | Made by GasBaby233",y,28) y=y+32
    verLbl.TextColor3 = Color3.fromRGB(0,200,255)

    -- Server info
    Section(C,"🌐 Server Info",y) y=y+22
    local _,serverLbl = InfoBox(C,"Loading...",y,60) y=y+64
    task.spawn(function()
        task.wait(2)
        pcall(function()
            serverLbl.Text =
                "Game: "..tostring(game.Name).."\n"..
                "Place: "..tostring(game.PlaceId).."\n"..
                "Players: "..#Players:GetPlayers().."/"..Players.MaxPlayers
        end)
    end)

    -- GUI key rebind
    Section(C,"⌨ Key Bind",y) y=y+22
    local _,keyLbl = InfoBox(C,"Toggle key: M",y,22) y=y+26
    Btn(C,"🔑 Rebind (press any key)",y,Color3.fromRGB(0,20,40),function()
        keyLbl.Text = "Press any key..."
        local conn conn = UserInputService.InputBegan:Connect(function(inp,gp)
            if gp then return end
            if inp.UserInputType == Enum.UserInputType.Keyboard then
                S.guiKey = inp.KeyCode
                keyLbl.Text = "Key: "..tostring(inp.KeyCode):gsub("Enum.KeyCode.","")
                conn:Disconnect()
            end
        end)
    end) y=y+34

    -- Save config
    Section(C,"💾 Config",y) y=y+22
    Btn(C,"💾 Save Config",y,Color3.fromRGB(0,25,20),function()
        local data = {
            farmJob=S.farmJob, farmDelay=S.farmDelay,
            flySpeed=S.flySpeed, walkSpeed=S.walkSpeed, jumpPower=S.jumpPower
        }
        pcall(function()
            writefile("swfl_config.json", game:GetService("HttpService"):JSONEncode(data))
            keyLbl.Text = "✅ Config saved!"
        end)
    end) y=y+34
    Btn(C,"📂 Load Config",y,Color3.fromRGB(0,20,35),function()
        pcall(function()
            local data = game:GetService("HttpService"):JSONDecode(readfile("swfl_config.json"))
            for k,v in pairs(data) do S[k]=v end
            keyLbl.Text = "✅ Config loaded!"
        end)
    end) y=y+34

    C.CanvasSize = UDim2.new(0,0,0,y+20)
end

-- ============================================================
-- DRAG
-- ============================================================
local dragging, dragStart, startPos
TBar.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true dragStart=i.Position startPos=WIN.Position
    end
end)
TBar.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-dragStart
        WIN.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)

-- ============================================================
-- CLOSE / MINIMIZE
-- ============================================================
local minimized = false
CloseBtn.MouseButton1Click:Connect(function()
    stopJobFarm() disableFly() disableGod() disableNoclip()
    -- Clean up ESP tags
    for _,p in pairs(Players:GetPlayers()) do
        pcall(function()
            local char = p.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local bb = hrp:FindFirstChild("SWFL_ESP")
                    if bb then bb:Destroy() end
                end
            end
        end)
    end
    SG:Destroy() _G.SWFLGui=nil
end)
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    ContentArea.Visible = not minimized
    TabBar.Visible = not minimized
    TabBar2.Visible = not minimized
    Sep.Visible = not minimized
    StatusBar.Visible = not minimized
    WIN.Size = minimized and UDim2.new(0,300,0,50) or UDim2.new(0,620,0,560)
    MinBtn.Text = minimized and "□" or "–"
end)

-- ============================================================
-- KEY TOGGLE
-- ============================================================
UserInputService.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.UserInputType~=Enum.UserInputType.Keyboard then return end
    if i.KeyCode==S.guiKey then S.guiOpen=not S.guiOpen WIN.Visible=S.guiOpen end
end)

-- ============================================================
-- MAIN LOOP
-- ============================================================
local frame = 0
RunService.Heartbeat:Connect(function(dt)
    frame = frame+1
    S.rgbHue = (S.rgbHue+0.002)%1
    local col = rgb()

    -- Animate every 3 frames
    if frame%3==0 then
        stroke.Color = col
        TitleLbl.TextColor3 = Color3.fromHSV((S.rgbHue+0.55)%1,0.8,1)

        -- Animate waves
        for _,w in ipairs(waves) do
            local t = tick()
            local newY = w.base + math.sin(t*w.speed)*0.02
            w.frame.Position = UDim2.new(-0.1,0,newY,0)
            w.frame.BackgroundColor3 = Color3.fromHSV((S.rgbHue+0.55)%1,0.8,0.8)
        end

        -- Animate sun
        sun.BackgroundColor3 = Color3.fromHSV((S.rgbHue+0.08)%1,0.9,1)
        sun.Size = UDim2.new(0,75+math.sin(tick()*0.8)*5,0,75+math.sin(tick()*0.8)*5)

        -- Active tab glow
        for n,b in pairs(tabBtns) do
            if b.BackgroundColor3==Color3.fromRGB(0,40,70) then
                b.TextColor3=col
            end
        end
    end
end)

-- ============================================================
-- RESPAWN
-- ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if S.godOn then enableGod() end
    if S.flyOn then enableFly() end
    if S.speedOn or S.jumpOn then startMoveLoop() end
    if S.noclipOn then enableNoclip() end
    -- Re-enable job farm after respawn
    if S.farmOn then
        task.wait(0.5)
        startJobFarm()
    end
    -- Refresh ESP tags on respawn
    if S.espOn then
        task.wait(0.5)
        for _,p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local old = hrp:FindFirstChild("SWFL_ESP")
                    if old then old:Destroy() end
                end
            end
        end
    end
end)

-- ============================================================
-- BOOT
-- ============================================================
local notif = Instance.new("Frame",SG)
notif.Size = UDim2.new(0,360,0,44)
notif.Position = UDim2.new(0.5,-180,1,-70)
notif.BackgroundColor3 = Color3.fromRGB(5,12,22)
notif.BackgroundTransparency = 0.05
notif.BorderSizePixel = 0 notif.ZIndex = 50
Instance.new("UICorner",notif).CornerRadius = UDim.new(0,12)
local ns = Instance.new("UIStroke",notif)
ns.Thickness = 1.5 ns.Color = Color3.fromRGB(0,200,255)
local nl = Instance.new("TextLabel",notif)
nl.Size = UDim2.new(1,0,1,0) nl.BackgroundTransparency = 1
nl.Text = "🌴 SWF Script v1.0  |  M = Toggle  |  GasBaby233"
nl.TextColor3 = Color3.fromRGB(0,220,255)
nl.TextSize = 13 nl.Font = Enum.Font.GothamBold nl.ZIndex = 51
task.spawn(function()
    task.wait(5)
    for i=1,25 do
        notif.BackgroundTransparency=0.05+i/25*0.95
        nl.TextTransparency=i/25 ns.Transparency=i/25
        task.wait(0.04)
    end
    notif:Destroy()
end)

print("╔══════════════════════════════════════════╗")
print("║  🌴 SWF Script v1.0 — Southwest Florida  ║")
print("║  M = Toggle GUI | Job Farm = CONFIRMED   ║")
print("║  Made by GasBaby233                      ║")
print("╚══════════════════════════════════════════╝")
