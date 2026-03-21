-- ╔══════════════════════════════════════════════════════════════╗
-- ║   ☀  G A S B A B Y  2 3 3  ☀   Military Tycoon  v4.0      ║
-- ║   Wave Executor | Press K to toggle GUI                      ║
-- ╚══════════════════════════════════════════════════════════════╝

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
if _G.GB233Gui      then pcall(function() _G.GB233Gui:Destroy()      end) end
if _G.GB233ESP      then
    for _,o in pairs(_G.GB233ESP) do
        for _,d in pairs(o) do pcall(function() d:Remove() end) end
    end
end
_G.GB233ESP = {}

-- ============================================================
-- DRAWING SAFE WRAPPER
-- ============================================================
local hasDraw = typeof(Drawing) ~= "nil" and Drawing.new ~= nil
local function NewDraw(t, props)
    if not hasDraw then
        return setmetatable({},{__newindex=function()end,__index=function()return nil end})
    end
    local ok,obj = pcall(Drawing.new, t)
    if not ok then
        return setmetatable({},{__newindex=function()end,__index=function()return nil end})
    end
    for k,v in pairs(props or {}) do pcall(function() obj[k]=v end) end
    return obj
end

-- ============================================================
-- STATE
-- ============================================================
local S = {
    -- GUI
    guiOpen     = true,
    guiKey      = Enum.KeyCode.K,
    rgbHue      = 0,

    -- ESP
    espOn       = false,
    espNames    = false,
    espDist     = false,
    espBoxes    = false,
    espTracers  = false,
    espTeam     = false,
    espRainbow  = false,
    espColor    = Color3.fromRGB(255,80,80),

    -- Aimbot / Silent Aim
    aimbotOn    = false,
    silentOn    = false,
    aimbotKey   = Enum.KeyCode.Q,
    aimbotFOV   = 120,
    aimbotSmooth= 0.2,
    aimbotPart  = "Head",
    aimbotTarget= nil,

    -- Fly
    flyOn       = false,
    flySpeed    = 80,
    flyConn     = nil,

    -- Money
    moneyOn     = false,
    moneyConn   = nil,
    moneyCount  = 0,

    -- God Mode
    godOn       = false,
    godConn     = nil,

    -- Guns
    noRecoil    = false,
    rapidFire   = false,
    autoReload  = false,
    infAmmo     = false,

    -- Player / Movement
    walkSpeed   = 16,
    jumpPower   = 50,
    speedOn     = false,
    jumpOn      = false,

    -- Auto Farm
    autoFarmOn  = false,
    autoFarmConn= nil,

    -- Kill Aura
    killAuraOn  = false,
    killAuraRange= 20,
    killAuraConn= nil,

    -- Player Tab
    selectedPlayer = nil,
    spectating     = false,
    spectateConn   = nil,
    trollTarget    = nil,
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
local function rgb2(off) return Color3.fromHSV((S.rgbHue+off)%1, 1, 1) end

-- World to viewport safe
local function w2v(pos)
    local ok, sp, onScr = pcall(function()
        return Camera:WorldToViewportPoint(pos)
    end)
    if ok then return sp, onScr end
    return Vector3.zero, false
end

-- ============================================================
-- AIMBOT TARGET FINDER — finds Players AND workspace NPCs
-- ============================================================
local function getMousePos()
    local mouse = LocalPlayer:GetMouse()
    return Vector2.new(mouse.X, mouse.Y)
end

-- NPC cache — rebuilt every 2 seconds, not every frame
local npcCache = {}
local npcCacheTime = 0
local NPC_CACHE_TTL = 2  -- seconds

local function refreshNPCCache()
    npcCache = {}
    local chars = workspace:FindFirstChild("Characters")
    if not chars then return end
    for _, model in ipairs(chars:GetChildren()) do
        if model:IsA("Model") then
            local hrp, hum
            pcall(function()
                hrp = model:FindFirstChild("HumanoidRootPart")
                hum = model:FindFirstChildOfClass("Humanoid")
            end)
            if hrp and hum and hum.Health > 0 then
                table.insert(npcCache, {char=model, hrp=hrp, name=model.Name, isNPC=true})
            end
        end
    end
end

-- Returns list of all valid targets: {char=, hrp=, name=, isNPC=, player=}
local function getAllTargets()
    local targets = {}

    -- Real players — always fresh
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if S.espTeam and p.Team == LocalPlayer.Team then continue end
        local char = p.Character
        if not char then continue end
        local hrp, hum
        pcall(function()
            hrp = char:FindFirstChild("HumanoidRootPart")
            hum = char:FindFirstChildOfClass("Humanoid")
        end)
        if hrp and hum and hum.Health > 0 then
            table.insert(targets, {char=char, hrp=hrp, name=p.Name, isNPC=false, player=p})
        end
    end

    -- NPCs — use cache, rebuild only every 2 seconds
    local now = tick()
    if now - npcCacheTime > NPC_CACHE_TTL then
        refreshNPCCache()
        npcCacheTime = now
    end
    for _, t in ipairs(npcCache) do
        -- Still alive check (cheap)
        local alive = false
        pcall(function()
            local hum = t.char:FindFirstChildOfClass("Humanoid")
            alive = hum and hum.Health > 0
        end)
        if alive then table.insert(targets, t) end
    end

    return targets
end

local function getAimbotTarget()
    local bestDist = S.aimbotFOV
    local bestTarget = nil
    local mp = getMousePos()
    local cx, cy = mp.X, mp.Y

    for _, t in ipairs(getAllTargets()) do
        local part
        pcall(function()
            part = t.char:FindFirstChild(S.aimbotPart) or t.hrp
        end)
        if not part then continue end
        local sp, onScr = w2v(part.Position)
        if not onScr then continue end
        local dist = math.sqrt((sp.X-cx)^2 + (sp.Y-cy)^2)
        if dist < bestDist then
            bestDist = dist
            bestTarget = t
        end
    end
    return bestTarget  -- returns table {char,hrp,name,isNPC} or nil
end

-- ============================================================
-- SILENT AIM  — hooks ShootEvent FireServer, redirects direction
-- vector to point at nearest target. Works because MT uses
-- FastCast with origin+direction args confirmed from decompile.
-- ============================================================
local origIndex
local silentConn
local silentHooked = false

local function enableSilentAim()
    if silentHooked then return end
    local mt = getrawmetatable and getrawmetatable(game)
    if not mt or not setreadonly then
        silentConn = RunService.Heartbeat:Connect(function()
            if S.silentOn then S.aimbotTarget = getAimbotTarget() end
        end)
        return
    end
    silentHooked = true
    local old_nc = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if S.silentOn and method == "FireServer" then
            -- Check if this is a gun remote using rawget
            local isGunRemote = false
            pcall(function()
                local n = rawget(self, "Name") or self.Name
                if n == "ShootEvent" or n == "Minigun" or n == "GLShoot" then
                    isGunRemote = true
                end
            end)
            -- Also check if self matches our cached shoot remote
            if not isGunRemote and mtShootEvent then
                pcall(function()
                    if self == mtShootEvent then isGunRemote = true end
                end)
            end
            if isGunRemote then
                local target = getAimbotTarget()
                if target then
                    local aimPart
                    pcall(function()
                        aimPart = target.char:FindFirstChild(S.aimbotPart) or target.hrp
                    end)
                    if aimPart then
                        local args = {...}
                        local originPos
                        if GunData.firePoint then
                            pcall(function() originPos = GunData.firePoint.WorldPosition end)
                        end
                        if not originPos then
                            local myHRP = getHRP()
                            originPos = myHRP and myHRP.Position or Vector3.new(0,0,0)
                        end
                        local targetPos = aimPart.Position + Vector3.new(0,0.5,0)
                        local newDir = (targetPos - originPos).Unit
                        for i, arg in ipairs(args) do
                            if typeof(arg) == "Vector3" then
                                if i > 1 then
                                    args[i] = arg.Magnitude < 5 and newDir or targetPos
                                end
                            elseif typeof(arg) == "CFrame" then
                                args[i] = CFrame.new(targetPos, targetPos + newDir)
                            end
                        end
                        return old_nc(self, table.unpack(args))
                    end
                end
            end
        end
        return old_nc(self, ...)
    end)
    setreadonly(mt, true)
    print("[GB233] Silent aim hooked")
end

local function disableSilentAim()
    S.silentOn = false
    if silentConn then silentConn:Disconnect() silentConn=nil end
end

-- ============================================================
-- FLY
-- ============================================================
local function enableFly()
    S.flyOn = true
    local hrp = getHRP()
    if not hrp then return end

    -- Disable default character movement physics
    local hum = getHum()
    if hum then hum.PlatformStand = true end

    local bg = Instance.new("BodyGyro")
    bg.Name="GB233FlyGyro" bg.MaxTorque=Vector3.new(9e9,9e9,9e9) bg.D=100 bg.P=1e5
    bg.CFrame=Camera.CFrame bg.Parent=hrp

    local bv = Instance.new("BodyVelocity")
    bv.Name="GB233FlyVel" bv.MaxForce=Vector3.new(9e9,9e9,9e9)
    bv.Velocity=Vector3.zero bv.Parent=hrp

    if S.flyConn then S.flyConn:Disconnect() end
    S.flyConn = RunService.Heartbeat:Connect(function()
        if not S.flyOn then return end
        hrp = getHRP()
        if not hrp then return end
        local cf = Camera.CFrame
        local vel = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel=vel+cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel=vel-cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel=vel-cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel=vel+cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel=vel+Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vel=vel-Vector3.new(0,1,0) end
        local bvv = hrp:FindFirstChild("GB233FlyVel")
        local bgg = hrp:FindFirstChild("GB233FlyGyro")
        if bvv then bvv.Velocity = vel.Magnitude>0 and vel.Unit*S.flySpeed or Vector3.zero end
        if bgg then bgg.CFrame = CFrame.new(hrp.Position, hrp.Position+cf.LookVector) end
    end)
end

local function disableFly()
    S.flyOn = false
    if S.flyConn then S.flyConn:Disconnect() S.flyConn=nil end
    local hrp = getHRP()
    if hrp then
        local b1=hrp:FindFirstChild("GB233FlyVel")
        local b2=hrp:FindFirstChild("GB233FlyGyro")
        if b1 then b1:Destroy() end
        if b2 then b2:Destroy() end
    end
    local hum=getHum()
    if hum then hum.PlatformStand=false end
end

-- ============================================================
-- GOD MODE
-- ============================================================
local function enableGod()
    S.godOn = true
    if S.godConn then S.godConn:Disconnect() end

    local godFrame = 0
    S.godConn = RunService.Heartbeat:Connect(function()
        if not S.godOn then return end
        godFrame = godFrame + 1
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        -- Hammer health every frame — faster than any damage script
        pcall(function()
            hum.MaxHealth = 1e9
            hum.Health    = 1e9
        end)
        -- Re-add ForceField every 30 frames in case it gets removed
        if godFrame % 30 == 0 then
            local ff = char:FindFirstChildOfClass("ForceField")
            if not ff then
                pcall(function()
                    local newFF = Instance.new("ForceField")
                    newFF.Visible = false
                    newFF.Parent  = char
                end)
            end
        end
    end)
end

local function disableGod()
    S.godOn = false
    if S.godConn then S.godConn:Disconnect() S.godConn=nil end
    local char = LocalPlayer.Character
    if char then
        local ff = char:FindFirstChildOfClass("ForceField")
        if ff then ff:Destroy() end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.MaxHealth=100 hum.Health=100 end) end
    end
end

-- ============================================================
-- MONEY DUPE
-- ============================================================
-- Strategy: scan for currency-related values on the player
-- then find remotes that give money and spam them, OR
-- directly increment the local IntValue/NumberValue faster than server syncs

-- ============================================================
-- MILITARY TYCOON HARDCODED MONEY SYSTEM
-- Remotes confirmed from console scan:
--   ReplicatedStorage.Events.Reward
--   ReplicatedStorage.Events.TycoonAdded
--   ReplicatedStorage.Events.DailyReward
--   ReplicatedStorage.Events.CashMenu
--   ReplicatedStorage.NukeEvents.GetCurrency
--   ReplicatedStorage.NukeEvents.UpdateCurrency
--   ReplicatedStorage.Events.Tycoon
-- Currency value: Players.[name].leaderstats.Rebirths
-- ============================================================

local function getMTRemotes()
    local RS = ReplicatedStorage
    local ev = RS:FindFirstChild("Events")
    local er = RS:FindFirstChild("EventRemotes")
    local nk = RS:FindFirstChild("NukeEvents")
    local found = {}
    local function tryGet(folder, name)
        if not folder then return nil end
        local r = folder:FindFirstChild(name)
        if r then table.insert(found, {remote=r, name=name}) end
        return r
    end
    -- Confirmed cash remotes from scan
    tryGet(ev, "Reward")
    tryGet(ev, "Gift")             -- confirmed from scan
    tryGet(ev, "TycoonAdded")
    tryGet(ev, "DailyReward")
    tryGet(ev, "CashMenu")
    tryGet(ev, "Tycoon")
    tryGet(er, "Claim")            -- confirmed from scan
    tryGet(nk, "GetCurrency")
    tryGet(nk, "UpdateCurrency")
    tryGet(nk, "ToggleAutoCollect")
    tryGet(RS, "FreeWeiner")       -- confirmed from scan
    local oop = RS:FindFirstChild("OOPTycoon")
    if oop then
        tryGet(oop, "TycoonData")
        tryGet(oop, "TycoonAnim")
    end
    return found
end

local function getMTCurrencyValue()
    -- CONFIRMED from scan: Rebirths IS the spendable cash in Military Tycoon
    -- The game uses "Rebirths" as the currency name (confusing but confirmed)
    -- Kills = kill count, Bounty = bounty value — neither is spendable cash
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if not ls then return nil end

    -- Direct target: Rebirths is confirmed cash
    local reb = ls:FindFirstChild("Rebirths")
    if reb then return reb end

    -- Fallback: any numeric value that isn't Kills or Bounty
    for _,v in ipairs(ls:GetChildren()) do
        if (v:IsA("IntValue") or v:IsA("NumberValue"))
        and v.Name ~= "Kills"
        and v.Name ~= "Bounty" then
            return v
        end
    end
    return nil
end

-- Prints ALL leaderstats so user can see what's there
local function printAllLeaderstats()
    print("=== GB233 Leaderstats Scan ===")
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if not ls then print("No leaderstats found!") return end
    for _,v in ipairs(ls:GetChildren()) do
        if v:IsA("IntValue") or v:IsA("NumberValue") then
            print("  "..v.Name.." = "..tostring(v.Value).." ("..v.ClassName..")")
        end
    end
    -- Also check PlayerData, Data folders
    for _,folder in ipairs({"PlayerData","Data","Stats","Profile"}) do
        local f = LocalPlayer:FindFirstChild(folder)
        if f then
            print("--- "..folder.." ---")
            for _,v in ipairs(f:GetChildren()) do
                if v:IsA("IntValue") or v:IsA("NumberValue") then
                    print("  "..v.Name.." = "..tostring(v.Value))
                end
            end
        end
    end
    print("=== End Scan ===")
end

-- ============================================================
-- FREE SPINS
-- Scans for spin/case/crate remotes and fires them on a loop
-- ============================================================
-- ============================================================
-- FREE SPINS — HARDCODED from scan
-- Confirmed remotes:
--   ReplicatedStorage.EventRemotes.Claim
--   ReplicatedStorage.EventRemotes.TellToSpin
--   ReplicatedStorage.Events.DailyReward
--   ReplicatedStorage.Events.Gift
--   ReplicatedStorage.AcMay23Claim
--   ReplicatedStorage.SoldierApr23Claim
--   ReplicatedStorage.FreeWeiner
--   ReplicatedStorage.Events.OpenMenu
-- ============================================================
S.freeSpinsOn  = false
S.spinsConn    = nil
S.spinsCount   = 0

local function getMTSpinRemotes()
    local RS  = ReplicatedStorage
    local ev  = RS:FindFirstChild("Events")
    local er  = RS:FindFirstChild("EventRemotes")
    local found = {}

    local function tryAdd(parent, name)
        if not parent then return end
        local r = parent:FindFirstChild(name)
        if r then
            table.insert(found, {remote=r, name=name})
            return r
        end
        return nil
    end

    -- CONFIRMED spin/claim remotes from scan
    tryAdd(er,  "Claim")            -- primary case/spin claim
    tryAdd(er,  "TellToSpin")       -- literally tells server to spin
    tryAdd(ev,  "DailyReward")      -- daily spin reward
    tryAdd(ev,  "Gift")             -- free gift
    tryAdd(ev,  "OpenMenu")         -- opens spin menu
    tryAdd(RS,  "AcMay23Claim")     -- event claim
    tryAdd(RS,  "SoldierApr23Claim")-- event claim
    tryAdd(RS,  "FreeWeiner")       -- free reward
    -- Also scan for any other Claim/Spin remotes dynamically
    local function scan(parent, depth)
        if depth > 3 then return end
        local ok,ch = pcall(function() return parent:GetChildren() end)
        if not ok then return end
        for _,v in ipairs(ch) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                local ln = v.Name:lower()
                if ln:find("claim") or ln:find("spin") or ln:find("free")
                or ln:find("gift") or ln:find("daily") or ln:find("reward") then
                    -- avoid duplicates
                    local already = false
                    for _,e in ipairs(found) do
                        if e.remote == v then already=true break end
                    end
                    if not already then
                        table.insert(found, {remote=v, name=v.Name})
                    end
                end
            end
            scan(v, depth+1)
        end
    end
    pcall(function() scan(RS, 1) end)
    return found
end

local function findSpinRemotes()
    local list = {}
    for _,e in ipairs(getMTSpinRemotes()) do table.insert(list, e.remote) end
    return list
end

local function startFreeSpins()
    S.freeSpinsOn = true
    if S.spinsConn then
        pcall(function() task.cancel(S.spinsConn) end)
    end

    -- Hardcoded confirmed spin remotes from live scan
    local RS = ReplicatedStorage
    local ev = RS:FindFirstChild("Events")
    local er = RS:FindFirstChild("EventRemotes")

    local spinRemotes = {}
    local function tryAdd(folder, name)
        if not folder then return end
        local r = folder:FindFirstChild(name)
        if r then
            table.insert(spinRemotes, {remote=r, name=name})
            print("[GB233] Spin remote: "..r:GetFullName())
        end
    end

    -- Confirmed from live scan
    tryAdd(er, "TellToSpin")
    tryAdd(er, "Claim")
    tryAdd(ev, "DailyReward")
    tryAdd(ev, "Gift")
    tryAdd(RS, "FreeWeiner")
    tryAdd(RS, "AcMay23Claim")
    tryAdd(RS, "SoldierApr23Claim")

    print("[GB233] Spin remotes ready: "..#spinRemotes)

    S.spinsConn = task.spawn(function()
        while S.freeSpinsOn do
            -- TellToSpin first
            local tellToSpin = er and er:FindFirstChild("TellToSpin")
            if tellToSpin then
                pcall(function() tellToSpin:FireServer() end)
                task.wait(0.15)
                pcall(function() tellToSpin:FireServer(1) end)
                task.wait(0.15)
            end
            -- Claim
            local claim = er and er:FindFirstChild("Claim")
            if claim then
                pcall(function() claim:FireServer(1) end)
                task.wait(0.15)
                pcall(function() claim:FireServer(true, 1) end)
                task.wait(0.15)
            end
            -- Daily reward
            local daily = ev and ev:FindFirstChild("DailyReward")
            if daily then
                pcall(function() daily:FireServer(7) end)
                task.wait(0.15)
                pcall(function() daily:FireServer(true) end)
                task.wait(0.15)
            end
            -- Gift + FreeWeiner
            for _,name in ipairs({"Gift","FreeWeiner","AcMay23Claim","SoldierApr23Claim"}) do
                local r = ev:FindFirstChild(name) or RS:FindFirstChild(name)
                if r then
                    pcall(function() r:FireServer() end)
                    task.wait(0.1)
                end
            end
            task.wait(2) -- 2 second cycle to avoid throttling
        end
    end)
end
                task.wait(0.15) -- gap between each remote to avoid throttle
            end
            S.spinsCount = S.spinsCount + 1
            task.wait(2) -- 2 seconds between full spin cycles — avoids RequestThrottled
        end
    end)
end

local function stopFreeSpins()
    S.freeSpinsOn = false
    if S.spinsConn then
        pcall(function() task.cancel(S.spinsConn) end)
        S.spinsConn = nil
    end
end

local function fireMTMoney(amount)
    local remotes = getMTRemotes()
    local fired = 0

    -- Fire each confirmed remote with every relevant arg pattern
    for _,entry in ipairs(remotes) do
        local r = entry.remote
        local n = entry.name
        pcall(function()
            if not r or not r.Parent then return end
            if r:IsA("RemoteEvent") then
                -- Pattern varies per remote — try all known combos
                r:FireServer()                           -- bare call
                r:FireServer(amount)                     -- amount only
                r:FireServer(amount, true)               -- amount + bool
                r:FireServer(true, amount)               -- bool + amount
                r:FireServer({amount = amount})          -- table
                r:FireServer({value = amount})
                r:FireServer({cash = amount})
                r:FireServer({currency = amount})
                r:FireServer({money = amount})
                if n == "TycoonAdded" then
                    r:FireServer(amount, LocalPlayer)
                elseif n == "UpdateCurrency" then
                    r:FireServer(amount, "add")
                    r:FireServer("add", amount)
                elseif n == "GetCurrency" then
                    r:FireServer(amount)
                    r:FireServer(amount, "cash")
                elseif n == "DailyReward" then
                    r:FireServer(true)
                    r:FireServer(1)   -- claim day 1 reward repeatedly
                    r:FireServer(7)   -- claim max day
                end
                fired = fired + 1
            elseif r:IsA("RemoteFunction") then
                pcall(function() r:InvokeServer(amount) end)
                pcall(function() r:InvokeServer({amount=amount}) end)
                fired = fired + 1
            end
        end)
    end
    return fired
end

local function startMoneyDupe()
    S.moneyOn = true
    if S.moneyConn then
        pcall(function() task.cancel(S.moneyConn) end)
        S.moneyConn = nil
    end

    local RS = ReplicatedStorage
    local ev = RS:FindFirstChild("Events")
    local nk = RS:FindFirstChild("NukeEvents")

    -- Only use confirmed working remotes
    local rewardR = ev and ev:FindFirstChild("Reward")
    local gcR     = nk and nk:FindFirstChild("GetCurrency")
    local giftR   = ev and ev:FindFirstChild("Gift")
    local tycoonR = ev and ev:FindFirstChild("TycoonAdded")

    local monVal = getMTCurrencyValue()
    print("[GB233] Money loop starting. Cash value: "..(monVal and monVal:GetFullName() or "not found"))

    local speeds = {Slow=1.0, Normal=0.5, Fast=0.2, ["Very Fast"]=0.08}
    S.moneyConn = task.spawn(function()
        while S.moneyOn do
            -- Reward remote — confirmed gives tycoon income
            if rewardR then
                pcall(function() rewardR:FireServer() end)
            end
            task.wait(0.05)
            -- GetCurrency — confirmed exists in NukeEvents
            if gcR then
                pcall(function() gcR:FireServer() end)
            end
            task.wait(0.05)
            -- Gift — free gift remote
            if giftR then
                pcall(function() giftR:FireServer() end)
            end
            task.wait(0.05)
            -- TycoonAdded — tycoon income event
            if tycoonR then
                pcall(function() tycoonR:FireServer() end)
            end

            S.moneyCount = (S.moneyCount or 0) + 1
            local spd = speeds[S.moneySpeedName or "Normal"] or 0.5
            task.wait(spd)
        end
    end)
end

local function stopMoneyDupe()
    S.moneyOn = false
    if S.moneyConn then
        pcall(function() task.cancel(S.moneyConn) end)
        S.moneyConn = nil
    end
end

-- Keep findMoneyRemotes and findMoneyValue as aliases for the scan button
local function findMoneyRemotes()
    local list = {}
    for _,e in ipairs(getMTRemotes()) do table.insert(list, e.remote) end
    return list
end
local function findMoneyValue()
    return getMTCurrencyValue()
end

-- ============================================================
-- COLLECTOR PAD DUPE
-- Hooks the Reward remote — when the game fires it (you walk on
-- the pad), we immediately fire it again X extra times so each
-- natural collect gives you multiplied money.
-- ============================================================
S.collectorDupeOn  = false
S.collectorMulti   = 10   -- how many extra fires per collect
local collectorConn = nil

local function enableCollectorDupe()
    S.collectorDupeOn = true
    local RS  = ReplicatedStorage
    local ev  = RS:FindFirstChild("Events")
    local rewardRemote = ev and ev:FindFirstChild("Reward")

    if not rewardRemote then
        -- Try to find it with a broader search
        local function findReward(parent, depth)
            if depth > 4 then return nil end
            for _,v in ipairs(parent:GetChildren()) do
                if v:IsA("RemoteEvent") and v.Name == "Reward" then return v end
                local found = findReward(v, depth+1)
                if found then return found end
            end
            return nil
        end
        rewardRemote = findReward(RS, 1)
    end

    if not rewardRemote then
        print("[GB233] Reward remote not found — collector dupe unavailable")
        return false
    end

    -- Hook: whenever Reward is fired FROM server TO client (OnClientEvent)
    -- that means the server just credited us — immediately fire it back
    -- additional times to dupe the credit
    if collectorConn then collectorConn:Disconnect() end
    collectorConn = rewardRemote.OnClientEvent:Connect(function(...)
        if not S.collectorDupeOn then return end
        local args = {...}
        -- Try to extract the amount from args
        local originalAmt = 0
        for _,a in ipairs(args) do
            if type(a)=="number" and a>0 then originalAmt=a break end
        end

        task.spawn(function()
            for i = 1, S.collectorMulti do
                pcall(function()
                    rewardRemote:FireServer(table.unpack(args))
                    rewardRemote:FireServer()
                end)
                task.wait(0.05)
            end
        end)

        -- Show floating multiplier label on screen
        if originalAmt > 0 then
            local totalAmt = originalAmt * (S.collectorMulti + 1)
            task.spawn(function()
                local lbl = Instance.new("TextLabel", SG)
                lbl.Size = UDim2.new(0,220,0,32)
                lbl.Position = UDim2.new(0.5,-110,0.35,0)
                lbl.BackgroundColor3 = Color3.fromRGB(10,40,10)
                lbl.BackgroundTransparency = 0.15
                lbl.Text = "💰 x"..(S.collectorMulti+1).." = $"..tostring(totalAmt)
                lbl.TextColor3 = Color3.fromRGB(80,255,80)
                lbl.TextSize = 16
                lbl.Font = Enum.Font.GothamBold
                lbl.BorderSizePixel = 0
                lbl.ZIndex = 60
                Instance.new("UICorner",lbl).CornerRadius = UDim.new(0,8)
                -- Float upward and fade out
                for i=1,20 do
                    lbl.Position = UDim2.new(0.5,-110,0.35-(i*0.01),0)
                    lbl.TextTransparency = i/20
                    lbl.BackgroundTransparency = 0.15 + i/20*0.85
                    task.wait(0.06)
                end
                lbl:Destroy()
            end)
        end
    end)
    print("[GB233] Collector dupe hooked on: "..rewardRemote:GetFullName())
    return true
end

local function disableCollectorDupe()
    S.collectorDupeOn = false
    if collectorConn then collectorConn:Disconnect() collectorConn = nil end
end

-- ============================================================
-- FREE TYCOON PURCHASES
-- Two approaches:
-- 1) Hook the Tycoon/TycoonAdded remote OnClientEvent to detect
--    when a purchase prompt appears and immediately send the buy
--    signal before the cost is deducted
-- 2) Hammer the currency value back up instantly after each
--    purchase so the net cost is $0
-- ============================================================
S.freeBuyOn = false
local freeBuyConn  = nil
local freeBuyGuard = nil

local function enableFreeBuy()
    S.freeBuyOn = true
    local RS     = ReplicatedStorage
    local ev     = RS:FindFirstChild("Events")
    local nk     = RS:FindFirstChild("NukeEvents")
    local monVal = getMTCurrencyValue()

    local gcR    = nk and nk:FindFirstChild("GetCurrency")
    local ucR    = nk and nk:FindFirstChild("UpdateCurrency")
    local rewardR= ev and ev:FindFirstChild("Reward")
    local savedBal = monVal and monVal.Value or 0

    -- Method 1: Hook __namecall — intercept FireServer on Tycoon purchase remote
    -- When player clicks buy, the client fires Tycoon remote BEFORE server deducts.
    -- We immediately blast GetCurrency to pre-credit the balance.
    pcall(function()
        local mt = getrawmetatable(game)
        if not mt or not setreadonly then return end
        local old = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if S.freeBuyOn and method == "FireServer" then
                -- Check if this is a purchase-related remote
                local selfName = ""
                pcall(function() selfName = tostring(self.Name):lower() end)
                if selfName:find("tycoon") or selfName:find("buy") or selfName:find("purchase") then
                    -- Pre-credit immediately before server deducts
                    task.spawn(function()
                        for i=1,15 do
                            pcall(function()
                                if gcR  then gcR:FireServer(9999999) end
                                if ucR  then ucR:FireServer(9999999) end
                            end)
                            task.wait(0.02)
                        end
                    end)
                end
            end
            return old(self, ...)
        end)
        setreadonly(mt, true)
    end)

    -- Method 2: Watch balance for any drop and fire immediate burst
    if freeBuyConn then pcall(function() task.cancel(freeBuyConn) end) end
    freeBuyConn = task.spawn(function()
        while S.freeBuyOn do
            if monVal and monVal.Parent then
                local cur = monVal.Value
                if cur < savedBal then
                    local spent = savedBal - cur
                    -- Burst refund using GetCurrency with exact amount
                    for i=1,12 do
                        pcall(function()
                            if gcR  then gcR:FireServer(spent) end
                            if ucR  then ucR:FireServer(spent) ucR:FireServer("add", spent) end
                            if rewardR then rewardR:FireServer() end
                        end)
                        task.wait(0.02)
                    end
                    -- Show floating refund label
                    task.spawn(function()
                        local lbl = Instance.new("TextLabel", SG)
                        lbl.Size=UDim2.new(0,200,0,30) lbl.Position=UDim2.new(0.5,-100,0.4,0)
                        lbl.BackgroundColor3=Color3.fromRGB(10,10,40) lbl.BackgroundTransparency=0.1
                        lbl.Text="🏪 Refund: $"..tostring(spent)
                        lbl.TextColor3=Color3.fromRGB(100,180,255) lbl.TextSize=14
                        lbl.Font=Enum.Font.GothamBold lbl.BorderSizePixel=0 lbl.ZIndex=60
                        Instance.new("UICorner",lbl).CornerRadius=UDim.new(0,8)
                        for i=1,20 do
                            lbl.Position=UDim2.new(0.5,-100,0.4-(i*0.01),0)
                            lbl.TextTransparency=i/20
                            lbl.BackgroundTransparency=0.1+i/20*0.9
                            task.wait(0.06)
                        end
                        lbl:Destroy()
                    end)
                end
                savedBal = math.max(monVal.Value, savedBal)
            end
            task.wait(0.1)  -- check every 100ms — fast enough to catch deductions
        end
    end)

    -- Method 3: Hook Tycoon OnClientEvent as extra layer
    local tycoonR = ev and ev:FindFirstChild("Tycoon")
    if tycoonR then
        if freeBuyGuard then freeBuyGuard:Disconnect() end
        freeBuyGuard = tycoonR.OnClientEvent:Connect(function()
            if not S.freeBuyOn then return end
            task.spawn(function()
                for i=1,15 do
                    pcall(function()
                        if gcR   then gcR:FireServer(9999999) end
                        if ucR   then ucR:FireServer(9999999) end
                    end)
                    task.wait(0.02)
                end
            end)
        end)
    end
    print("[GB233] Free purchase active — 3-layer protection enabled")
end

local function disableFreeBuy()
    S.freeBuyOn = false
    if freeBuyConn  then freeBuyConn:Disconnect()  freeBuyConn=nil  end
    if freeBuyGuard then freeBuyGuard:Disconnect() freeBuyGuard=nil end
end

-- ============================================================
-- AIMBOT (camera lock) — works on Players AND NPCs
-- ============================================================
local aimbotConn
local aimbotFrame = 0
local function startAimbot()
    if aimbotConn then aimbotConn:Disconnect() end
    aimbotConn = RunService.RenderStepped:Connect(function()
        aimbotFrame = aimbotFrame + 1
        if aimbotFrame % 2 ~= 0 then return end
        if not S.aimbotOn then return end
        if not UserInputService:IsKeyDown(S.aimbotKey) then
            S.aimbotTarget = nil return
        end
        local t = getAimbotTarget()
        if not t then S.aimbotTarget=nil return end
        S.aimbotTarget = t
        local part
        pcall(function() part = t.char:FindFirstChild(S.aimbotPart) or t.hrp end)
        if not part then return end
        -- Primary: direct camera lock (most reliable on Wave)
        local cf = Camera.CFrame
        local targetCF = CFrame.new(cf.Position, part.Position)
        Camera.CFrame = cf:Lerp(targetCF, S.aimbotSmooth)
        -- Secondary: mousemoverel for smoother feel if available
        if mousemoverel then
            local sp, onScr = w2v(part.Position)
            if onScr then
                local mp = getMousePos()
                local dx = (sp.X - mp.X) * S.aimbotSmooth * 0.3
                local dy = (sp.Y - mp.Y) * S.aimbotSmooth * 0.3
                pcall(function() mousemoverel(dx, dy) end)
            end
        end
    end)
end

-- ============================================================
-- MOVEMENT — WalkSpeed / JumpPower
-- ============================================================
local function applySpeed()
    local hum = getHum()
    if not hum then return end
    pcall(function()
        hum.WalkSpeed = S.speedOn and S.walkSpeed or 16
        hum.JumpPower = S.jumpOn  and S.jumpPower or 50
    end)
end

-- Only runs when speed/jump actually enabled — disconnects otherwise
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
-- AUTO FARM
-- ============================================================
local COLLECTOR_POS = Vector3.new(0, 5, 0)

-- Excluded object name fragments — don't touch these
local WORKSPACE_EXCLUSIONS = {
    "lamp","light","bulb","torch","lantern","neon","sign",
    "decoration","deco","prop","tree","bush","rock","fence",
}

local function isExcluded(name)
    local ln = name:lower()
    for _,ex in ipairs(WORKSPACE_EXCLUSIONS) do
        if ln:find(ex) then return true end
    end
    return false
end

local function findCollector()
    local names = {"collector","dropper","pad","moneypad","droppad","income","cashpad"}
    for _,v in ipairs(workspace:GetDescendants()) do
        -- Skip excluded objects to avoid touching lamp scripts etc
        if not pcall(function()
            if isExcluded(v.Name) then error() end
        end) then continue end

        if v:IsA("BasePart") or v:IsA("Model") then
            local ln = v.Name:lower()
            for _,n in ipairs(names) do
                if ln:find(n) then
                    local pos = v:IsA("BasePart") and v.Position
                        or (v.PrimaryPart and v.PrimaryPart.Position)
                    if pos then return pos end
                end
            end
        end
    end
    return nil
end

local function startAutoFarm()
    S.autoFarmOn = true
    if S.autoFarmConn then
        pcall(function() task.cancel(S.autoFarmConn) end)
    end
    S.autoFarmConn = task.spawn(function()
        while S.autoFarmOn do
            local hrp = getHRP()
            if hrp then
                -- Find collector position dynamically
                local colPos = findCollector()
                if colPos then
                    -- Teleport onto the collector
                    hrp.Anchored = true
                    hrp.CFrame = CFrame.new(colPos + Vector3.new(0, 4, 0))
                    task.wait(0.1)
                    hrp.Anchored = false
                    -- Also manually fire the Reward remote
                    local ev = ReplicatedStorage:FindFirstChild("Events")
                    local rr = ev and ev:FindFirstChild("Reward")
                    if rr then
                        for i=1, S.collectorMulti or 5 do
                            pcall(function() rr:FireServer() end)
                            pcall(function() rr:FireServer(true) end)
                            task.wait(0.05)
                        end
                    end
                end
            end
            task.wait(1.5) -- collect every 1.5 seconds
        end
    end)
end

local function stopAutoFarm()
    S.autoFarmOn = false
    if S.autoFarmConn then
        pcall(function() task.cancel(S.autoFarmConn) end)
        S.autoFarmConn = nil
    end
end

-- ============================================================
-- KILL AURA
-- Fires damage-related remotes on all nearby players
-- ============================================================
local function startKillAura()
    S.killAuraOn = true
    if S.killAuraConn then S.killAuraConn:Disconnect() end

    local auraFrame = 0
    S.killAuraConn = RunService.Heartbeat:Connect(function()
        if not S.killAuraOn then return end
        auraFrame = auraFrame + 1
        if auraFrame % 8 ~= 0 then return end -- ~7fps

        local myHRP = getHRP()
        if not myHRP then return end
        local myPos = myHRP.Position

        for _,t in ipairs(getAllTargets()) do
            if not t.hrp then continue end
            local dist = (t.hrp.Position - myPos).Magnitude
            if dist > S.killAuraRange then continue end

            -- NPCs: zero health directly (client side confirmed)
            if t.isNPC then
                local hum = t.char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum.Health = 0 end) end

            -- Players: use confirmed ShootEvent + health zero attempt
            else
                -- Fire ShootEvent with 99999 damage at target
                if mtShootEvent then
                    local dir = (t.hrp.Position - myPos).Unit
                    pcall(function() mtShootEvent:FireServer(myPos, dir) end)
                    pcall(function() mtShootEvent:FireServer(t.hrp.Position, dir) end)
                end
                -- Also fire KillLog
                if mtKillLog and t.player then
                    pcall(function() mtKillLog:FireServer(t.player) end)
                end
                -- Try health zero (sometimes works if server sync lags)
                local hum = t.char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum.Health = 0 end) end
            end
        end
    end)
end

local function stopKillAura()
    S.killAuraOn = false
    if S.killAuraConn then S.killAuraConn:Disconnect() S.killAuraConn=nil end
end

-- ============================================================
-- SPECTATE
-- ============================================================
local function startSpectate(targetPlayer)
    if S.spectateConn then S.spectateConn:Disconnect() S.spectateConn=nil end
    if not targetPlayer then return end
    S.spectating = true
    Camera.CameraType = Enum.CameraType.Custom

    S.spectateConn = RunService.RenderStepped:Connect(function()
        if not S.spectating then return end
        local char = targetPlayer.Character
        if not char then return end
        local hrp
        pcall(function() hrp = char:FindFirstChild("HumanoidRootPart") end)
        if not hrp then return end
        -- Lock camera to target
        Camera.CFrame = CFrame.new(
            hrp.Position + hrp.CFrame.LookVector * -8 + Vector3.new(0,4,0),
            hrp.Position + Vector3.new(0,2,0)
        )
    end)
end

local function stopSpectate()
    S.spectating = false
    if S.spectateConn then S.spectateConn:Disconnect() S.spectateConn=nil end
    Camera.CameraType = Enum.CameraType.Custom
    Camera.CameraSubject = LocalPlayer.Character and
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid") or nil
end

-- ============================================================
-- LIVE GUN SCANNER
-- Watches the currently equipped tool in real time.
-- Scans all remotes, values, and scripts inside it.
-- All gun features read from this instead of guessing.
-- Admin RGB color applies to the actual held gun parts.
-- ============================================================

local GunData = {
    tool          = nil,
    name          = "",
    fireRemote    = nil,
    reloadRemote  = nil,
    damageRemote  = nil,
    allRemotes    = {},
    ammoValue     = nil,
    maxAmmoValue  = nil,
    fireRateValue = nil,
    damageValue   = nil,
    allValues     = {},
    parts         = {},
    -- MT-specific FastCast fields
    firePoint     = nil,   -- GunFirePoint attachment (WorldPosition = bullet origin)
    firePointPart = nil,   -- BasePart containing the fire point
    scanned       = false,
    scanTime      = 0,
}

local FIRE_PATTERNS    = {"fire","shoot","bullet","projectile","attack"}
local RELOAD_PATTERNS  = {"reload","reloading","refill"}
local DAMAGE_PATTERNS  = {"damage","dmg","hurt","hit","wound"}
local AMMO_PATTERNS    = {"ammo","magazine","mag","clip","rounds","bullets","currentammo"}
local MAXAMMO_PATTERNS = {"maxammo","maxbullets","maxrounds","maxmag","capacity"}
local FIRERATE_PATTERNS= {"firerate","fire_rate","cooldown","delay","rpm","interval","waittime","shootdelay"}

local function matchesAny(str, patterns)
    local ln = str:lower()
    for _,p in ipairs(patterns) do
        if ln:find(p) then return true end
    end
    return false
end

local function scanGun(tool)
    local data = {
        tool=tool, name=tool.Name,
        fireRemote=nil, reloadRemote=nil, damageRemote=nil,
        allRemotes={}, ammoValue=nil, maxAmmoValue=nil,
        fireRateValue=nil, damageValue=nil, allValues={}, parts={},
        firePoint=nil, firePointPart=nil,
        scanned=true, scanTime=tick(),
    }

    local ok, descs = pcall(function() return tool:GetDescendants() end)
    if not ok then return data end

    for _,v in ipairs(descs) do
        local name = ""
        pcall(function() name = tostring(v.Name) end)
        if name == "" then continue end

        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            table.insert(data.allRemotes, {remote=v, name=name})
            if not data.fireRemote   and matchesAny(name, FIRE_PATTERNS)   then data.fireRemote   = v end
            if not data.reloadRemote and matchesAny(name, RELOAD_PATTERNS) then data.reloadRemote = v end
            if not data.damageRemote and matchesAny(name, DAMAGE_PATTERNS) then data.damageRemote = v end

        elseif v:IsA("NumberValue") or v:IsA("IntValue") then
            local val = 0
            pcall(function() val = v.Value end)
            table.insert(data.allValues, {value=v, name=name, current=val})
            if not data.ammoValue     and matchesAny(name, AMMO_PATTERNS)     then data.ammoValue     = v end
            if not data.maxAmmoValue  and matchesAny(name, MAXAMMO_PATTERNS)  then data.maxAmmoValue  = v end
            if not data.fireRateValue and matchesAny(name, FIRERATE_PATTERNS) then data.fireRateValue = v end
            if not data.damageValue   and matchesAny(name, DAMAGE_PATTERNS)   then data.damageValue   = v end

        elseif v:IsA("BasePart") then
            table.insert(data.parts, v)

        elseif v:IsA("Attachment") then
            -- MT FastCast guns use BarrelPos attachment as bullet origin (confirmed from scan)
            local ln = name:lower()
            if name == "BarrelPos" or name == "GunFirePoint"
            or ln:find("barrel") or ln:find("firepoint") or ln:find("fire_point")
            or ln:find("muzzle") or ln:find("gunfire") then
                data.firePoint = v
                pcall(function() data.firePointPart = v.Parent end)
                print("[GB233] FirePoint found: "..v:GetFullName())
            end
        end
    end

    -- Fallback fire remote
    if not data.fireRemote and #data.allRemotes > 0 then
        data.fireRemote = data.allRemotes[1].remote
    end
    -- Fallback fire point — use Handle
    if not data.firePoint then
        pcall(function()
            data.firePointPart = tool:FindFirstChild("Handle")
        end)
    end

    return data
end

-- Print full gun scan to console
local function printGunScan(data)
    print("╔══════════════════════════════════════╗")
    print("║  GB233 Gun Scan: "..data.name)
    print("╠══════════════════════════════════════╣")
    print("  Remotes ("..#data.allRemotes.."):")
    for _,r in ipairs(data.allRemotes) do
        local role = ""
        if r.remote == data.fireRemote   then role = " ← FIRE" end
        if r.remote == data.reloadRemote then role = " ← RELOAD" end
        if r.remote == data.damageRemote then role = " ← DAMAGE" end
        print("    "..r.remote:GetFullName()..role)
    end
    print("  Values ("..#data.allValues.."):")
    for _,v in ipairs(data.allValues) do
        local role = ""
        if v.value == data.ammoValue     then role = " ← AMMO" end
        if v.value == data.maxAmmoValue  then role = " ← MAX AMMO" end
        if v.value == data.fireRateValue then role = " ← FIRE RATE" end
        if v.value == data.damageValue   then role = " ← DAMAGE" end
        print("    "..v.name.." = "..tostring(v.current)..role)
    end
    print("  Parts: "..#data.parts)
    print("╚══════════════════════════════════════╝")
end

local lastToolName = ""
local gunScanConn
local gunWatchFrame = 0

local function startGunWatcher()
    if gunScanConn then gunScanConn:Disconnect() end
    gunScanConn = RunService.Heartbeat:Connect(function()
        gunWatchFrame = gunWatchFrame + 1

        -- Only check for new gun every 10 frames (~6/sec) — not every frame
        if gunWatchFrame % 10 == 0 then
            local char = LocalPlayer.Character
            if not char then return end
            local tool = char:FindFirstChildWhichIsA("Tool")

            if tool then
                if tool.Name ~= lastToolName then
                    lastToolName = tool.Name
                    local data = scanGun(tool)
                    GunData.tool=data.tool GunData.name=data.name
                    GunData.fireRemote=data.fireRemote GunData.reloadRemote=data.reloadRemote
                    GunData.damageRemote=data.damageRemote GunData.allRemotes=data.allRemotes
                    GunData.ammoValue=data.ammoValue GunData.maxAmmoValue=data.maxAmmoValue
                    GunData.fireRateValue=data.fireRateValue GunData.damageValue=data.damageValue
                    GunData.allValues=data.allValues GunData.parts=data.parts
                    GunData.firePoint=data.firePoint GunData.firePointPart=data.firePointPart
                    GunData.scanned=true GunData.scanTime=tick()
                    print("[GB233] Gun: "..data.name.." | "..#data.allRemotes.." remotes | "..#data.allValues.." values | "..#data.parts.." parts")
                    if data.fireRemote    then print("  Fire:      "..data.fireRemote:GetFullName()) end
                    if data.reloadRemote  then print("  Reload:    "..data.reloadRemote:GetFullName()) end
                    if data.ammoValue     then print("  Ammo:      "..data.ammoValue.Name.."="..data.ammoValue.Value) end
                    if data.fireRateValue then print("  Rate:      "..data.fireRateValue.Name.."="..data.fireRateValue.Value) end
                    if data.firePoint     then print("  FirePoint: "..data.firePoint:GetFullName()) end
                end
            else
                if lastToolName ~= "" then
                    lastToolName = ""
                    GunData.tool=nil GunData.name="" GunData.scanned=false GunData.parts={}
                end
            end
        end

        -- RGB on held gun — every 3 frames (~20fps) for smooth color cycling
        if gunWatchFrame % 3 == 0 and S.gunRGBOn and GunData.tool then
            local gunHue = (S.rgbHue + 0.15) % 1
            local tool = GunData.tool
            -- Re-scan parts every cycle in case game resets them
            -- Use tool:GetDescendants() directly for most reliable results
            local ok, descs = pcall(function() return tool:GetDescendants() end)
            if ok then
                local colorIdx = 0
                for _, part in ipairs(descs) do
                    if part:IsA("BasePart") then
                        colorIdx = colorIdx + 1
                        pcall(function()
                            -- Skip parts that are likely collision/hitbox only
                            local skip = false
                            local ln = part.Name:lower()
                            if ln:find("hitbox") or ln:find("collision") or ln:find("invis") then
                                skip = true
                            end
                            if not skip then
                                part.Color = Color3.fromHSV((gunHue + colorIdx*0.06)%1, 1, 1)
                                part.Material = Enum.Material.Neon
                                -- Force transparency to 0 so it's visible
                                if part.Transparency > 0.5 then
                                    part.Transparency = 0
                                end
                            end
                        end)
                    end
                end
            end
        end
    end)
end

-- Start watcher immediately
startGunWatcher()

-- ============================================================
-- GUN FEATURE BACKENDS — now use GunData instead of guessing
-- ============================================================

S.triggerBot   = false
S.fullAuto     = false
S.oneShotOn    = false
S.wallbangOn   = false
S.bulletESPOn  = false
S.gunRGBOn     = false  -- RGB color on actual held gun

-- ── Trigger Bot — correct MT ShootEvent format ────────────────
local triggerConn = nil
local function startTriggerBot()
    if triggerConn then triggerConn:Disconnect() end
    local lastFire = 0
    triggerConn = RunService.Heartbeat:Connect(function()
        if not S.triggerBot then return end
        local t = getAimbotTarget()
        if not t then return end
        local now = tick()
        if now - lastFire < 0.08 then return end
        lastFire = now
        local myChar = LocalPlayer.Character
        if not myChar then return end
        local myHRP = myChar:FindFirstChild("HumanoidRootPart")
        if not myHRP then return end
        local tool = GunData.tool or myChar:FindFirstChildWhichIsA("Tool")
        if not tool then return end
        -- Use BarrelPos attachment confirmed from MT gun scan
        local originPos
        if GunData.firePoint then
            pcall(function() originPos = GunData.firePoint.WorldPosition end)
        end
        if not originPos then
            -- Fallback: search for BarrelPos in tool
            local bp = tool:FindFirstChild("BarrelPos", true)
            if bp then pcall(function() originPos = bp.WorldPosition end) end
        end
        if not originPos then
            originPos = myHRP.Position + Vector3.new(0, 1.5, 0)
        end
        local targetPos = t.hrp.Position + Vector3.new(0, 0.8, 0)
        local dir = (targetPos - originPos).Unit
        -- ShootEvent args: origin position + direction vector (confirmed from BulletVisualizer)
        if mtShootEvent then
            pcall(function() mtShootEvent:FireServer(originPos, dir) end)
            pcall(function() mtShootEvent:FireServer(targetPos, dir) end)
        end
        -- Wave: real mouse click simulation
        if mouse1press then
            pcall(function() mouse1press() end)
            task.delay(0.05, function() pcall(function() mouse1release() end) end)
        else
            -- Only call Activate if tool is actually equipped (in Character, not Backpack)
            local myChar = LocalPlayer.Character
            if tool and myChar and tool:IsDescendantOf(myChar) then
                pcall(function() tool:Activate() end)
            end
        end
    end)
end
local function stopTriggerBot()
    S.triggerBot = false
    if triggerConn then triggerConn:Disconnect() triggerConn=nil end
end


-- ── Full Auto — spam ShootEvent + keep ammo maxed ─────────────
local fullAutoConn = nil
local function startFullAuto()
    if fullAutoConn then fullAutoConn:Disconnect() end
    local lastFire = 0
    fullAutoConn = RunService.Heartbeat:Connect(function()
        if not S.fullAuto then return end
        -- Keep ammo maxed so gun never runs dry
        if GunData.ammoValue then
            pcall(function() GunData.ammoValue.Value = 9999 end)
        end
        local now = tick()
        if now - lastFire < 0.05 then return end
        lastFire = now
        -- Get current target
        local t = getAimbotTarget()
        local targetPos = t and t.hrp and t.hrp.Position or nil
        -- Fire ShootEvent
        if mtShootEvent then
            pcall(function()
                if targetPos then
                    mtShootEvent:FireServer(targetPos, targetPos, 1)
                else
                    mtShootEvent:FireServer()
                end
            end)
        end
        -- Also activate tool
        if GunData.tool then
            pcall(function() GunData.tool:Activate() end)
        end
    end)
end
local function stopFullAuto()
    S.fullAuto = false
    if fullAutoConn then fullAutoConn:Disconnect() fullAutoConn=nil end
end

-- ── One Shot Kill — scan RS for damage remotes + zero HP ───────
local oneShotConn = nil
-- ============================================================
-- CONFIRMED MT GUN REMOTES (from live scan 2026-03-17)
-- ReplicatedStorage.Events.ShootEvent     — main gun fire
-- ReplicatedStorage.Events.Minigun        — minigun fire  
-- ReplicatedStorage.Events.GLShoot        — grenade launcher
-- ReplicatedStorage.Events.PlantedGunClientEffects — turret effects
-- ReplicatedStorage.Events.PlantedGunEvent — turret fire
-- ReplicatedStorage.Events.KillLog        — kill registration
-- ============================================================
local mtDamageRemotes = {}
local mtShootEvent    = nil  -- main fire remote
local mtKillLog       = nil  -- kill log remote
local mtMinigun       = nil  -- minigun remote
local mtGLShoot       = nil  -- grenade launcher remote

local function initMTGunRemotes()
    local RS = ReplicatedStorage
    local ev = RS:FindFirstChild("Events")
    if not ev then return end
    -- Cache all confirmed remotes
    mtShootEvent = ev:FindFirstChild("ShootEvent")
    mtKillLog    = ev:FindFirstChild("KillLog")
    mtMinigun    = ev:FindFirstChild("Minigun")
    mtGLShoot    = ev:FindFirstChild("GLShoot")
    -- Build damage remotes list (all that can deal damage)
    mtDamageRemotes = {}
    for _,name in ipairs({"ShootEvent","Minigun","GLShoot","PlantedGunEvent","KillLog"}) do
        local r = ev:FindFirstChild(name)
        if r then
            table.insert(mtDamageRemotes, r)
            print("[GB233] Gun remote cached: "..r:GetFullName())
        end
    end
    print("[GB233] MT gun remotes ready: "..#mtDamageRemotes.." loaded")
end

-- Init immediately on load
task.spawn(function()
    task.wait(2) -- wait for game to fully load remotes
    initMTGunRemotes()
end)

local function scanMTDamageRemotes()
    -- Re-scan in case remotes weren't ready on load
    initMTGunRemotes()
end

local function enableOneShot()
    S.oneShotOn = true
    if #mtDamageRemotes == 0 then task.spawn(initMTGunRemotes) end
    -- Hook __namecall to replace any damage number with 99999
    pcall(function()
        local mt2 = getrawmetatable(game)
        if not mt2 or not setreadonly then return end
        local old = mt2.__namecall
        setreadonly(mt2, false)
        mt2.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if S.oneShotOn and method == "FireServer" then
                local args = {...}
                for i,arg in ipairs(args) do
                    if type(arg)=="number" and arg>0 and arg<10000 then args[i]=99999 end
                    if type(arg)=="table" then
                        for k,v2 in pairs(arg) do
                            if type(v2)=="number" and v2>0 and v2<10000 then arg[k]=99999 end
                        end
                    end
                end
                return old(self, table.unpack(args))
            end
            return old(self, ...)
        end)
        setreadonly(mt2, true)
    end)
    if oneShotConn then oneShotConn:Disconnect() end
    oneShotConn = RunService.Heartbeat:Connect(function()
        if not S.oneShotOn then return end
        local tgt = getAimbotTarget()
        if not tgt then return end
        -- Zero NPC health directly (confirmed client-side)
        if tgt.isNPC then
            local hum = tgt.char:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.Health = 0 end) end
            return
        end
        -- For players: fire ShootEvent with 99999 damage args
        if mtShootEvent then
            pcall(function()
                mtShootEvent:FireServer(tgt.hrp.Position, tgt.hrp.Position, 99999)
                mtShootEvent:FireServer(tgt.player, 99999)
                mtShootEvent:FireServer(tgt.hrp.Position, 99999, tgt.player)
            end)
        end
        -- Fire KillLog to register the kill server-side
        if mtKillLog then
            pcall(function()
                mtKillLog:FireServer(tgt.player)
                mtKillLog:FireServer(tgt.player.Name)
                mtKillLog:FireServer(tgt.player, LocalPlayer)
            end)
        end
        -- All other damage remotes
        for _,r in ipairs(mtDamageRemotes) do
            pcall(function()
                r:FireServer(tgt.player, 99999)
                r:FireServer(tgt.hrp.Position, 99999)
            end)
        end
    end)
end
local function disableOneShot()
    S.oneShotOn = false
    if oneShotConn then oneShotConn:Disconnect() oneShotConn=nil end
end


-- ── Wallbang ─────────────────────────────────────────────────
-- Makes newly spawned bullet parts have no collision
local wallbangConn = nil
local function enableWallbang()
    S.wallbangOn = true
    -- Watch for new parts being added to workspace that look like bullets
    if wallbangConn then wallbangConn:Disconnect() end
    wallbangConn = workspace.DescendantAdded:Connect(function(obj)
        if not S.wallbangOn then return end
        if not obj:IsA("BasePart") then return end
        local ln = obj.Name:lower()
        -- Bullet-like names
        if ln:find("bullet") or ln:find("pellet") or ln:find("projectile")
        or ln:find("shot") or ln:find("shell") or ln:find("ball")
        or (obj.Size.Magnitude < 1.5 and obj.Velocity.Magnitude > 20) then
            pcall(function()
                obj.CanCollide = false
                obj.CanQuery   = false
            end)
        end
    end)
end
local function disableWallbang()
    S.wallbangOn = false
    if wallbangConn then wallbangConn:Disconnect() wallbangConn=nil end
end

-- ── Bullet ESP ───────────────────────────────────────────────
-- Draws a tracer from gun barrel to wherever bullet lands
local bulletESPLines = {}
local bulletESPConn  = nil
local function enableBulletESP()
    S.bulletESPOn = true
    if bulletESPConn then bulletESPConn:Disconnect() end
    bulletESPConn = workspace.DescendantAdded:Connect(function(obj)
        if not S.bulletESPOn then return end
        if not obj:IsA("BasePart") then return end
        local ln = obj.Name:lower()
        if not (ln:find("bullet") or ln:find("pellet") or ln:find("projectile")
        or ln:find("shot") or ln:find("shell")) then return end
        -- Draw a line tracking this bullet
        local line = NewDraw("Line",{
            Thickness=1.5, Color=Color3.fromRGB(255,80,80),
            Visible=true, ZIndex=8,
            From=Vector2.new(0,0), To=Vector2.new(0,0),
        })
        table.insert(bulletESPLines, {line=line, part=obj})
        -- Auto-clean after 3 seconds
        task.delay(3, function()
            pcall(function() line:Remove() end)
        end)
    end)
end
local function disableBulletESP()
    S.bulletESPOn = false
    if bulletESPConn then bulletESPConn:Disconnect() bulletESPConn=nil end
    for _,e in ipairs(bulletESPLines) do
        pcall(function() e.line:Remove() end)
    end
    bulletESPLines = {}
end

-- Update bullet ESP lines in main loop (added to frame % 2 section)
-- This is called from the main Heartbeat loop

-- ============================================================
-- ============================================================
-- SCREENGUI
-- ============================================================
local SG = Instance.new("ScreenGui")
SG.Name = "GasBaby233"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset = true
_G.GB233Gui = SG
local ok = pcall(function() SG.Parent = game:GetService("CoreGui") end)
if not ok then SG.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- ============================================================
-- CONFIG SYSTEM  (save/load presets via _G)
-- ============================================================
local CONFIG_KEY = "GB233_Config"
_G[CONFIG_KEY] = _G[CONFIG_KEY] or {}

local DEFAULT_CONFIG = {
    bgPreset    = "Sun",      -- Sun / Zombies / Cars / RGB / Solid
    bgColor     = {r=20,g=20,b=40},
    espOn       = false,
    espRainbow  = false,
    aimbotOn    = false,
    aimbotFOV   = 120,
    flySpeed    = 80,
    walkSpeed   = 60,
    jumpPower   = 150,
}

local function saveConfig(name)
    _G[CONFIG_KEY][name] = {
        bgPreset  = S.bgPreset or "Sun",
        espOn     = S.espOn,
        espRainbow= S.espRainbow,
        espBoxes  = S.espBoxes,
        espNames  = S.espNames,
        aimbotOn  = S.aimbotOn,
        aimbotFOV = S.aimbotFOV,
        flySpeed  = S.flySpeed,
        walkSpeed = S.walkSpeed,
        jumpPower = S.jumpPower,
        godOn     = S.godOn,
    }
    print("[GB233] Config saved: "..name)
end

local function loadConfig(name)
    local cfg = _G[CONFIG_KEY][name]
    if not cfg then return false end
    for k,v in pairs(cfg) do S[k] = v end
    print("[GB233] Config loaded: "..name)
    return true
end

local function listConfigs()
    local names = {}
    for k in pairs(_G[CONFIG_KEY]) do table.insert(names,k) end
    return names
end

-- ============================================================
-- BACKGROUND SYSTEM  — swappable presets
-- ============================================================
S.bgPreset = S.bgPreset or "Sun"

-- ============================================================
-- MAIN WINDOW
-- ============================================================
local WIN = Instance.new("Frame", SG)
WIN.Name = "Window"
WIN.Size = UDim2.new(0, 660, 0, 560)
WIN.Position = UDim2.new(0.5,-330,0.5,-280)
WIN.BackgroundColor3 = Color3.fromRGB(8,8,14)
WIN.BorderSizePixel = 0
WIN.ClipsDescendants = true
Instance.new("UICorner",WIN).CornerRadius = UDim.new(0,14)

local stroke = Instance.new("UIStroke",WIN)
stroke.Thickness=2 stroke.Color=Color3.fromRGB(255,80,80)
stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border

-- ── BACKGROUND CANVAS ────────────────────────────────────────
local bgCanvas = Instance.new("Frame",WIN)
bgCanvas.Size=UDim2.new(1,0,1,0) bgCanvas.BackgroundTransparency=1
bgCanvas.ZIndex=1 bgCanvas.ClipsDescendants=true

-- Grid lines (always visible behind everything)
for i=1,5 do
    local h=Instance.new("Frame",WIN)
    h.Size=UDim2.new(1,0,0,1) h.Position=UDim2.new(0,0,i/6,0)
    h.BackgroundColor3=Color3.fromRGB(25,25,55) h.BackgroundTransparency=0.6
    h.BorderSizePixel=0 h.ZIndex=1
    local v=Instance.new("Frame",WIN)
    v.Size=UDim2.new(0,1,1,0) v.Position=UDim2.new(i/6,0,0,0)
    v.BackgroundColor3=Color3.fromRGB(25,25,55) v.BackgroundTransparency=0.6
    v.BorderSizePixel=0 v.ZIndex=1
end

-- ── SUN PRESET ───────────────────────────────────────────────
local sunLayers={} local sunSizes={130,95,68,44,26}
local sunAlphas={0.93,0.85,0.76,0.62,0.35}
for i,sz in ipairs(sunSizes) do
    local l=Instance.new("Frame",bgCanvas)
    l.Size=UDim2.new(0,sz,0,sz) l.AnchorPoint=Vector2.new(0.5,0.5)
    l.Position=UDim2.new(0.5,0,0.4,0) l.BackgroundColor3=Color3.fromRGB(255,200,60)
    l.BackgroundTransparency=sunAlphas[i] l.BorderSizePixel=0 l.ZIndex=2
    Instance.new("UICorner",l).CornerRadius=UDim.new(0.5,0)
    table.insert(sunLayers,l)
end
local smokePuffs={}
local puffData={{rx=0.12,ry=0.08,sz=16,sp=0.4,amp=5},{rx=0.22,ry=0.22,sz=12,sp=0.55,amp=7},
    {rx=0.78,ry=0.15,sz=18,sp=0.3,amp=4},{rx=0.88,ry=0.30,sz=14,sp=0.65,amp=6},
    {rx=0.55,ry=0.75,sz=20,sp=0.25,amp=8},{rx=0.35,ry=0.60,sz=10,sp=0.7,amp=5},
    {rx=0.70,ry=0.70,sz=15,sp=0.45,amp=7}}
for i,pd in ipairs(puffData) do
    local p=Instance.new("Frame",bgCanvas)
    p.Size=UDim2.new(0,pd.sz,0,pd.sz) p.AnchorPoint=Vector2.new(0.5,0.5)
    p.Position=UDim2.new(pd.rx,0,pd.ry,0) p.BackgroundColor3=Color3.fromRGB(220,180,80)
    p.BackgroundTransparency=0.78 p.BorderSizePixel=0 p.ZIndex=2
    Instance.new("UICorner",p).CornerRadius=UDim.new(0.5,0)
    table.insert(smokePuffs,{frame=p,data=pd,t=i*0.9})
end
local rays={}
for i=1,8 do
    local r=Instance.new("Frame",bgCanvas)
    r.Size=UDim2.new(0,2,0,38) r.AnchorPoint=Vector2.new(0.5,1)
    r.BackgroundColor3=Color3.fromRGB(255,220,80) r.BackgroundTransparency=0.72
    r.BorderSizePixel=0 r.ZIndex=2 r.Rotation=(i-1)*45
    table.insert(rays,r)
end

-- ── ZOMBIE PRESET ────────────────────────────────────────────
-- 8-bit style zombie silhouettes (using TextLabels with emoji/block chars)
local zombieData={}
local ZOMBIE_CHARS = {"👾","🧟","👻","💀","🧟","👾","💀","🧟"}
for i=1,8 do
    local z=Instance.new("TextLabel",bgCanvas)
    z.Size=UDim2.new(0,40,0,40) z.BackgroundTransparency=1
    z.Text=ZOMBIE_CHARS[i] z.TextSize=28
    z.Position=UDim2.new((i-1)/8+0.02,0,0.6,0)
    z.ZIndex=2 z.Visible=false
    table.insert(zombieData,{lbl=z, x=(i-1)/8+0.02, speed=0.015+i*0.003, t=i*0.4})
end

-- ── CARS PRESET ──────────────────────────────────────────────
local CAR_CHARS={"🏎","🚗","🚕","🏎","🚙","🚗"}
local carData={}
for i=1,6 do
    local c=Instance.new("TextLabel",bgCanvas)
    c.Size=UDim2.new(0,40,0,30) c.BackgroundTransparency=1
    c.Text=CAR_CHARS[i] c.TextSize=22
    c.Position=UDim2.new(math.random()*0.8,0,(i-1)/6*0.8+0.05,0)
    c.ZIndex=2 c.Visible=false
    table.insert(carData,{lbl=c, y=(i-1)/6*0.8+0.05, x=-(i*0.15), speed=0.008+i*0.002})
end

-- ── RGB PRESET ───────────────────────────────────────────────
local rgbBands={}
for i=1,6 do
    local band=Instance.new("Frame",bgCanvas)
    band.Size=UDim2.new(1,0,0,WIN.Size.Y.Offset/6)
    band.Position=UDim2.new(0,0,(i-1)/6,0)
    band.BackgroundColor3=Color3.fromHSV((i-1)/6,0.8,0.6)
    band.BackgroundTransparency=0.85 band.BorderSizePixel=0 band.ZIndex=2
    band.Visible=false
    table.insert(rgbBands,{frame=band, hueOff=(i-1)/6})
end

-- ── SOLID COLOR PRESET ───────────────────────────────────────
local solidBg=Instance.new("Frame",bgCanvas)
solidBg.Size=UDim2.new(1,0,1,0) solidBg.BackgroundColor3=Color3.fromRGB(15,15,35)
solidBg.BackgroundTransparency=0 solidBg.BorderSizePixel=0 solidBg.ZIndex=2 solidBg.Visible=false

-- Show/hide preset layers
local function setPresetVisible(preset)
    -- Sun
    for _,l in ipairs(sunLayers) do l.Visible=(preset=="Sun") end
    for _,p in ipairs(smokePuffs) do p.frame.Visible=(preset=="Sun") end
    for _,r in ipairs(rays) do r.Visible=(preset=="Sun") end
    -- Zombies
    for _,z in ipairs(zombieData) do z.lbl.Visible=(preset=="Zombies") end
    -- Cars
    for _,c in ipairs(carData) do c.lbl.Visible=(preset=="Cars") end
    -- RGB
    for _,b in ipairs(rgbBands) do b.frame.Visible=(preset=="RGB") end
    -- Solid
    solidBg.Visible=(preset=="Solid")
end

setPresetVisible("Sun")

-- ── TITLE BAR ────────────────────────────────────────────────
local TBar=Instance.new("Frame",WIN)
TBar.Size=UDim2.new(1,0,0,44) TBar.BackgroundColor3=Color3.fromRGB(8,8,18)
TBar.BorderSizePixel=0 TBar.ZIndex=10
Instance.new("UICorner",TBar).CornerRadius=UDim.new(0,14)
local TBarFix=Instance.new("Frame",TBar)
TBarFix.Size=UDim2.new(1,0,0.5,0) TBarFix.Position=UDim2.new(0,0,0.5,0)
TBarFix.BackgroundColor3=Color3.fromRGB(8,8,18) TBarFix.BorderSizePixel=0 TBarFix.ZIndex=9

-- Logo + title
local LogoLbl=Instance.new("TextLabel",TBar)
LogoLbl.Size=UDim2.new(0,30,1,0) LogoLbl.Position=UDim2.new(0,6,0,0)
LogoLbl.BackgroundTransparency=1 LogoLbl.Text="☀" LogoLbl.TextSize=20
LogoLbl.Font=Enum.Font.GothamBold LogoLbl.ZIndex=12

local TitleLbl=Instance.new("TextLabel",TBar)
TitleLbl.Size=UDim2.new(1,-130,1,0) TitleLbl.Position=UDim2.new(0,36,0,0)
TitleLbl.BackgroundTransparency=1 TitleLbl.Text="GasBaby 233  ✦  Military Tycoon"
TitleLbl.TextColor3=Color3.fromRGB(255,200,60) TitleLbl.TextSize=14
TitleLbl.Font=Enum.Font.GothamBold TitleLbl.TextXAlignment=Enum.TextXAlignment.Left
TitleLbl.ZIndex=11

local HintLbl=Instance.new("TextLabel",TBar)
HintLbl.Size=UDim2.new(0,55,1,0) HintLbl.Position=UDim2.new(1,-125,0,0)
HintLbl.BackgroundTransparency=1 HintLbl.Text="[K] hide"
HintLbl.TextColor3=Color3.fromRGB(100,100,140) HintLbl.TextSize=9
HintLbl.Font=Enum.Font.Gotham HintLbl.ZIndex=11

local function makeBtn(parent,txt,xOff,col)
    local b=Instance.new("TextButton",parent)
    b.Size=UDim2.new(0,26,0,26) b.Position=UDim2.new(1,xOff,0.5,-13)
    b.BackgroundColor3=col b.Text=txt b.TextColor3=Color3.new(1,1,1)
    b.TextSize=13 b.Font=Enum.Font.GothamBold b.BorderSizePixel=0 b.ZIndex=12
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
    return b
end
local CloseBtn=makeBtn(TBar,"✕",-32,Color3.fromRGB(180,40,40))
local MinBtn  =makeBtn(TBar,"–",-62,Color3.fromRGB(160,120,20))

-- ── TAB BAR  — two rows for cleanliness ──────────────────────
-- Row 1: main feature tabs
local TabRow1=Instance.new("Frame",WIN)
TabRow1.Size=UDim2.new(1,0,0,32) TabRow1.Position=UDim2.new(0,0,0,44)
TabRow1.BackgroundColor3=Color3.fromRGB(10,10,20) TabRow1.BorderSizePixel=0 TabRow1.ZIndex=9
local TR1L=Instance.new("UIListLayout",TabRow1)
TR1L.FillDirection=Enum.FillDirection.Horizontal TR1L.VerticalAlignment=Enum.VerticalAlignment.Center
TR1L.Padding=UDim.new(0,1)

-- Row 2: utility tabs
local TabRow2=Instance.new("Frame",WIN)
TabRow2.Size=UDim2.new(1,0,0,30) TabRow2.Position=UDim2.new(0,0,0,76)
TabRow2.BackgroundColor3=Color3.fromRGB(8,8,16) TabRow2.BorderSizePixel=0 TabRow2.ZIndex=9
local TR2L=Instance.new("UIListLayout",TabRow2)
TR2L.FillDirection=Enum.FillDirection.Horizontal TR2L.VerticalAlignment=Enum.VerticalAlignment.Center
TR2L.Padding=UDim.new(0,1)

-- Separator
local TabSep=Instance.new("Frame",WIN)
TabSep.Size=UDim2.new(1,0,0,1) TabSep.Position=UDim2.new(0,0,0,106)
TabSep.BackgroundColor3=Color3.fromRGB(40,40,80) TabSep.BorderSizePixel=0 TabSep.ZIndex=9

-- Content area
local ContentArea=Instance.new("Frame",WIN)
ContentArea.Size=UDim2.new(1,-16,1,-130)
ContentArea.Position=UDim2.new(0,8,0,110)
ContentArea.BackgroundTransparency=1 ContentArea.ZIndex=8

-- Status bar
local StatusBar=Instance.new("Frame",WIN)
StatusBar.Size=UDim2.new(1,0,0,20) StatusBar.Position=UDim2.new(0,0,1,-20)
StatusBar.BackgroundColor3=Color3.fromRGB(6,6,14) StatusBar.BorderSizePixel=0 StatusBar.ZIndex=10
local StatusLbl=Instance.new("TextLabel",StatusBar)
StatusLbl.Size=UDim2.new(0.7,0,1,0) StatusLbl.Position=UDim2.new(0,8,0,0)
StatusLbl.BackgroundTransparency=1 StatusLbl.Text="☀ GasBaby 233 | K=Toggle"
StatusLbl.TextColor3=Color3.fromRGB(100,100,140) StatusLbl.TextSize=9
StatusLbl.Font=Enum.Font.Gotham StatusLbl.TextXAlignment=Enum.TextXAlignment.Left StatusLbl.ZIndex=11
-- Credit label right side
local CreditLbl=Instance.new("TextLabel",StatusBar)
CreditLbl.Size=UDim2.new(0.3,-4,1,0) CreditLbl.Position=UDim2.new(0.7,0,0,0)
CreditLbl.BackgroundTransparency=1 CreditLbl.Text="made by GasBaby233"
CreditLbl.TextColor3=Color3.fromRGB(80,80,120) CreditLbl.TextSize=9
CreditLbl.Font=Enum.Font.GothamBold CreditLbl.TextXAlignment=Enum.TextXAlignment.Right CreditLbl.ZIndex=11

-- ============================================================
-- WIDGET FACTORIES
-- ============================================================
local function Section(parent,text,y)
    local l=Instance.new("TextLabel",parent)
    l.Size=UDim2.new(1,0,0,18) l.Position=UDim2.new(0,0,0,y)
    l.BackgroundTransparency=1 l.Text="── "..text.." ──"
    l.TextColor3=Color3.fromRGB(255,200,60) l.TextSize=11
    l.Font=Enum.Font.GothamBold l.TextXAlignment=Enum.TextXAlignment.Center l.ZIndex=11
    return l
end

local function Toggle(parent,label,y,cb)
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,0,0,32) row.Position=UDim2.new(0,0,0,y)
    row.BackgroundColor3=Color3.fromRGB(12,12,22) row.BorderSizePixel=0 row.ZIndex=10
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)
    local lbl=Instance.new("TextLabel",row)
    lbl.Size=UDim2.new(1,-68,1,0) lbl.Position=UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency=1 lbl.Text=label
    lbl.TextColor3=Color3.fromRGB(210,210,240) lbl.TextSize=12
    lbl.Font=Enum.Font.Gotham lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.ZIndex=11
    local btn=Instance.new("TextButton",row)
    btn.Size=UDim2.new(0,54,0,21) btn.Position=UDim2.new(1,-58,0.5,-10)
    btn.BackgroundColor3=Color3.fromRGB(28,8,8) btn.Text="OFF"
    btn.TextColor3=Color3.fromRGB(200,60,60) btn.TextSize=10
    btn.Font=Enum.Font.GothamBold btn.BorderSizePixel=0 btn.ZIndex=12
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,5)
    local on=false
    local function set(v)
        on=v
        if v then btn.Text="ON" btn.TextColor3=Color3.fromRGB(60,255,120) btn.BackgroundColor3=Color3.fromRGB(8,38,18)
        else btn.Text="OFF" btn.TextColor3=Color3.fromRGB(200,60,60) btn.BackgroundColor3=Color3.fromRGB(28,8,8) end
        if cb then cb(v) end
    end
    btn.MouseButton1Click:Connect(function() set(not on) end)
    return row,function() return on end,set
end

local function Btn(parent,text,y,col,cb)
    local b=Instance.new("TextButton",parent)
    b.Size=UDim2.new(1,-4,0,30) b.Position=UDim2.new(0,2,0,y)
    b.BackgroundColor3=col or Color3.fromRGB(18,18,36)
    b.Text=text b.TextColor3=Color3.fromRGB(220,220,255) b.TextSize=12
    b.Font=Enum.Font.GothamBold b.BorderSizePixel=0 b.ZIndex=11
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    if cb then b.MouseButton1Click:Connect(cb) end
    return b
end

local function Slider(parent,label,mn,mx,def,y,cb)
    local frame=Instance.new("Frame",parent)
    frame.Size=UDim2.new(1,0,0,40) frame.Position=UDim2.new(0,0,0,y)
    frame.BackgroundColor3=Color3.fromRGB(12,12,22) frame.BorderSizePixel=0 frame.ZIndex=10
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,7)
    local lbl=Instance.new("TextLabel",frame)
    lbl.Size=UDim2.new(1,-10,0,17) lbl.Position=UDim2.new(0,10,0,2)
    lbl.BackgroundTransparency=1 lbl.Text=label..":  "..tostring(def)
    lbl.TextColor3=Color3.fromRGB(190,190,230) lbl.TextSize=11
    lbl.Font=Enum.Font.Gotham lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.ZIndex=11
    local track=Instance.new("Frame",frame)
    track.Size=UDim2.new(1,-18,0,6) track.Position=UDim2.new(0,9,0,27)
    track.BackgroundColor3=Color3.fromRGB(22,22,44) track.BorderSizePixel=0 track.ZIndex=11
    Instance.new("UICorner",track).CornerRadius=UDim.new(0.5,0)
    local fill=Instance.new("Frame",track)
    fill.Size=UDim2.new((def-mn)/(mx-mn),0,1,0)
    fill.BackgroundColor3=Color3.fromRGB(255,200,60) fill.BorderSizePixel=0 fill.ZIndex=12
    Instance.new("UICorner",fill).CornerRadius=UDim.new(0.5,0)
    local val=def local drag=false
    local function upd(ix)
        local ap=track.AbsolutePosition local as=track.AbsoluteSize
        local rel=math.clamp((ix-ap.X)/as.X,0,1)
        val=math.floor(mn+rel*(mx-mn))
        fill.Size=UDim2.new(rel,0,1,0) lbl.Text=label..":  "..tostring(val)
        if cb then cb(val) end
    end
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true upd(i.Position.X) end end)
    UserInputService.InputChanged:Connect(function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then upd(i.Position.X) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
    return frame,function() return val end
end

local function InfoBox(parent,text,y,h)
    local f=Instance.new("Frame",parent)
    f.Size=UDim2.new(1,-4,0,h or 30) f.Position=UDim2.new(0,2,0,y)
    f.BackgroundColor3=Color3.fromRGB(10,10,22) f.BackgroundTransparency=0.25
    f.BorderSizePixel=0 f.ZIndex=10
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,7)
    local l=Instance.new("TextLabel",f)
    l.Size=UDim2.new(1,-10,1,0) l.Position=UDim2.new(0,6,0,0)
    l.BackgroundTransparency=1 l.Text=text
    l.TextColor3=Color3.fromRGB(155,195,155) l.TextSize=10
    l.Font=Enum.Font.Gotham l.TextWrapped=true l.TextXAlignment=Enum.TextXAlignment.Left l.ZIndex=11
    return f,l
end

local function Dropdown(parent,label,opts,y,cb)
    local frame=Instance.new("Frame",parent)
    frame.Size=UDim2.new(1,0,0,30) frame.Position=UDim2.new(0,0,0,y)
    frame.BackgroundColor3=Color3.fromRGB(12,12,22) frame.BorderSizePixel=0 frame.ZIndex=10
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,7)
    local lbl=Instance.new("TextLabel",frame)
    lbl.Size=UDim2.new(0.42,0,1,0) lbl.Position=UDim2.new(0,8,0,0)
    lbl.BackgroundTransparency=1 lbl.Text=label
    lbl.TextColor3=Color3.fromRGB(190,190,230) lbl.TextSize=11
    lbl.Font=Enum.Font.Gotham lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.ZIndex=11
    local idx=1
    local btn=Instance.new("TextButton",frame)
    btn.Size=UDim2.new(0.56,-4,0,22) btn.Position=UDim2.new(0.44,2,0.5,-11)
    btn.BackgroundColor3=Color3.fromRGB(18,18,38) btn.Text="◀ "..opts[1].." ▶"
    btn.TextColor3=Color3.fromRGB(255,200,60) btn.TextSize=10
    btn.Font=Enum.Font.Gotham btn.BorderSizePixel=0 btn.ZIndex=12
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,5)
    btn.MouseButton1Click:Connect(function()
        idx=(idx%#opts)+1 btn.Text="◀ "..opts[idx].." ▶"
        if cb then cb(opts[idx]) end
    end)
    return frame,btn,function() return opts[idx] end
end

-- ============================================================
-- TWO-ROW TAB SYSTEM
-- ============================================================
local tabs={} local tabBtns={}

local function MakeTab(name,icon,row)
    local parent = row==2 and TabRow2 or TabRow1
    local w = row==2 and 74 or 80
    local h = row==2 and 30 or 32
    local btn=Instance.new("TextButton",parent)
    btn.Size=UDim2.new(0,w,0,h) btn.BackgroundColor3=Color3.fromRGB(12,12,24)
    btn.Text=icon.." "..name btn.TextColor3=Color3.fromRGB(130,130,170)
    btn.TextSize=9 btn.Font=Enum.Font.GothamBold btn.BorderSizePixel=0 btn.ZIndex=10

    local scroll=Instance.new("ScrollingFrame",ContentArea)
    scroll.Size=UDim2.new(1,0,1,0) scroll.BackgroundTransparency=1
    scroll.BorderSizePixel=0 scroll.ScrollBarThickness=3
    scroll.ScrollBarImageColor3=Color3.fromRGB(255,200,60)
    scroll.ZIndex=9 scroll.Visible=false
    tabs[name]=scroll tabBtns[name]=btn

    btn.MouseButton1Click:Connect(function()
        for n,s in pairs(tabs) do s.Visible=(n==name) end
        for n,b in pairs(tabBtns) do
            if n==name then b.BackgroundColor3=Color3.fromRGB(28,20,6) b.TextColor3=Color3.fromRGB(255,200,60)
            else b.BackgroundColor3=Color3.fromRGB(12,12,24) b.TextColor3=Color3.fromRGB(130,130,170) end
        end
        StatusLbl.Text="☀ "..name.." | K=Toggle | GasBaby233"
    end)
    return scroll
end

-- Row 1 — Main features
local ESPTab    = MakeTab("ESP",    "👁",1)
local AimTab    = MakeTab("Aim",    "🎯",1)
local CombatTab = MakeTab("Combat", "⚔",1)  -- NEW: hitbox, antiaim, noclip
local MoneyTab  = MakeTab("Money",  "💰",1)
local GunsTab   = MakeTab("Guns",   "🔫",1)
local PlayersTab= MakeTab("Players","👥",1)

-- Row 2 — Utility
local FlyTab    = MakeTab("Fly",    "✈",2)
local MoveTab   = MakeTab("Move",   "💨",2)
local GodTab    = MakeTab("God",    "🛡",2)
local FarmTab    = MakeTab("Farm",      "🤖",2)
local WeaponsTab = MakeTab("Weapons",   "🔫",2)
local VehicleTab = MakeTab("Vehicles",  "🚗",2)
local TeleTab    = MakeTab("Teleport",  "🌀",2)
local SettingsTab= MakeTab("Settings",  "⚙", 2)

-- Activate first tab
tabs["ESP"].Visible=true
tabBtns["ESP"].BackgroundColor3=Color3.fromRGB(28,20,6)
tabBtns["ESP"].TextColor3=Color3.fromRGB(255,200,60)

-- ============================================================
-- ═══  ESP TAB  ═══════════════════════════════════════════
-- ============================================================
do
    local C=ESPTab C.CanvasSize=UDim2.new(0,0,0,460)
    local y=4
    Section(C,"Player ESP",y) y=y+22
    Toggle(C,"Enable ESP",y,function(v) S.espOn=v end) y=y+36
    Toggle(C,"Show Names",y,function(v) S.espNames=v end) y=y+36
    Toggle(C,"Show Distance",y,function(v) S.espDist=v end) y=y+36
    Toggle(C,"Show Boxes",y,function(v) S.espBoxes=v end) y=y+36
    Toggle(C,"Show Tracers",y,function(v) S.espTracers=v end) y=y+36
    Toggle(C,"🌈 Rainbow ESP",y,function(v) S.espRainbow=v end) y=y+36
    Toggle(C,"Skip Teammates",y,function(v) S.espTeam=v end) y=y+36
    Section(C,"ESP Color",y) y=y+22
    local colorRow=Instance.new("Frame",C)
    colorRow.Size=UDim2.new(1,0,0,30) colorRow.Position=UDim2.new(0,0,0,y)
    colorRow.BackgroundTransparency=1 colorRow.ZIndex=10
    local cl=Instance.new("UIListLayout",colorRow)
    cl.FillDirection=Enum.FillDirection.Horizontal cl.Padding=UDim.new(0,4)
    for _,cd in ipairs({{"Red",Color3.fromRGB(255,60,60)},{"Blue",Color3.fromRGB(60,120,255)},
        {"Green",Color3.fromRGB(60,255,100)},{"Yellow",Color3.fromRGB(255,240,50)},
        {"Pink",Color3.fromRGB(255,80,220)},{"White",Color3.fromRGB(255,255,255)}}) do
        local cb=Instance.new("TextButton",colorRow)
        cb.Size=UDim2.new(0,86,0,28) cb.BackgroundColor3=cd[2] cb.Text=cd[1]
        cb.TextColor3=Color3.new(0,0,0) cb.TextSize=10 cb.Font=Enum.Font.GothamBold
        cb.BorderSizePixel=0 cb.ZIndex=12
        Instance.new("UICorner",cb).CornerRadius=UDim.new(0,5)
        local cc=cd[2] cb.MouseButton1Click:Connect(function() S.espColor=cc S.espRainbow=false end)
    end
    y=y+34
end

-- ============================================================
-- ═══  AIM TAB  ═══════════════════════════════════════════
-- ============================================================
do
    local C=AimTab C.CanvasSize=UDim2.new(0,0,0,460)
    local y=4
    Section(C,"Aimbot",y) y=y+22
    InfoBox(C,"Hold Q to lock camera. FOV circle follows your mouse.",y,26) y=y+30
    Toggle(C,"Enable Aimbot",y,function(v)
        S.aimbotOn=v if v then startAimbot() end
    end) y=y+36
    Slider(C,"FOV Radius",10,300,120,y,function(v) S.aimbotFOV=v end) y=y+44
    Slider(C,"Smoothness",1,100,20,y,function(v) S.aimbotSmooth=v/100 end) y=y+44
    Dropdown(C,"Target Part:",{"Head","HumanoidRootPart","UpperTorso"},y,function(v) S.aimbotPart=v end) y=y+34
    Section(C,"Silent Aim",y) y=y+22
    InfoBox(C,"Redirects bullets server-side to nearest target.",y,26) y=y+30
    Toggle(C,"Enable Silent Aim",y,function(v)
        S.silentOn=v if v then enableSilentAim() else disableSilentAim() end
    end) y=y+36
end

-- ============================================================
-- ═══  COMBAT TAB  (NEW) ══════════════════════════════════
-- ============================================================
do
    local C=CombatTab C.CanvasSize=UDim2.new(0,0,0,1100)
    local y=4

    -- ── Anti-Aim ─────────────────────────────────────────────
    Section(C,"🌀 Anti-Aim",y) y=y+22
    InfoBox(C,"Spins your character rapidly — enemies literally cannot land shots. Best combo: Anti-Aim + Speed 150+",y,34) y=y+38
    local _,antiAimLbl=InfoBox(C,"OFF",y,22) y=y+26
    local antiAimConn=nil
    local antiAimMode = "Spin" -- Spin / Jitter / Flat
    Dropdown(C,"Mode:",{"Spin","Jitter","Flat (sideways)"},y,function(v) antiAimMode=v end) y=y+34
    Toggle(C,"🌀 Enable Anti-Aim",y,function(v)
        S.antiAimOn=v
        if v then
            if antiAimConn then antiAimConn:Disconnect() end
            local t=0
            antiAimConn=RunService.Heartbeat:Connect(function(dt)
                if not S.antiAimOn then antiAimConn:Disconnect() antiAimConn=nil return end
                t=t+dt
                local hrp=getHRP() if not hrp then return end
                pcall(function()
                    if antiAimMode=="Spin" then
                        -- Full continuous spin
                        hrp.CFrame=hrp.CFrame*CFrame.fromEulerAnglesYXZ(0,dt*20,0)
                    elseif antiAimMode=="Jitter" then
                        -- Random jitter every frame
                        local jx=(math.random()-0.5)*0.8
                        local jy=(math.random()-0.5)*0.8
                        hrp.CFrame=hrp.CFrame*CFrame.fromEulerAnglesYXZ(jx,jy,0)
                    elseif antiAimMode=="Flat (sideways)" then
                        -- Lock character to look sideways — hard to hit head
                        hrp.CFrame=CFrame.new(hrp.Position)*CFrame.fromEulerAnglesYXZ(0,math.sin(t*15)*math.pi*0.5,0)
                    end
                end)
            end)
            antiAimLbl.Text="🌀 ACTIVE — mode: "..antiAimMode
            StatusLbl.Text="🌀 Anti-Aim ON"
        else
            if antiAimConn then antiAimConn:Disconnect() antiAimConn=nil end
            antiAimLbl.Text="OFF"
        end
    end) y=y+36

    -- ── Hitbox Expander ───────────────────────────────────────
    Section(C,"📦 Hitbox Expander",y) y=y+22
    InfoBox(C,"Expands enemy HumanoidRootParts so every shot registers. Higher = easier to hit but more obvious.",y,34) y=y+38
    local _,hbLbl=InfoBox(C,"OFF",y,22) y=y+26
    local hbConn=nil
    Slider(C,"Hitbox Size",2,25,8,y,function(v)
        S.hitboxSize=v
        if S.hitboxOn then hbLbl.Text="📦 x"..v.." ACTIVE" end
    end) y=y+44
    Toggle(C,"📦 Enable Hitbox Expander",y,function(v)
        S.hitboxOn=v
        if v then
            if hbConn then hbConn:Disconnect() end
            hbConn=RunService.Heartbeat:Connect(function()
                if not S.hitboxOn then hbConn:Disconnect() hbConn=nil return end
                local sz=S.hitboxSize or 8
                for _,t in ipairs(getAllTargets()) do
                    pcall(function()
                        if not t.hrp then return end
                        -- Method 1: expand HRP size
                        t.hrp.Size=Vector3.new(sz,sz,sz)
                        -- Method 2: expand all hitbox parts
                        for _,part in ipairs(t.char:GetDescendants()) do
                            if part:IsA("BasePart") and not part.Anchored then
                                local ln=part.Name:lower()
                                if ln:find("hitbox") or ln:find("hit") or part==t.hrp then
                                    pcall(function() part.Size=Vector3.new(sz,sz,sz) end)
                                end
                            end
                        end
                        -- Method 3: move HRP to our position for melee range check bypass
                        local myH=getHRP()
                        if myH then
                            local dist=(t.hrp.Position-myH.Position).Magnitude
                            -- Only expand if within 100 studs
                            if dist > 100 then return end
                        end
                    end)
                end
            end)
            hbLbl.Text="📦 x"..(S.hitboxSize or 8).." ACTIVE"
        else
            if hbConn then hbConn:Disconnect() hbConn=nil end
            -- Restore original sizes
            for _,t in ipairs(getAllTargets()) do
                pcall(function()
                    if t.hrp then t.hrp.Size=Vector3.new(2,2,1) end
                end)
            end
            hbLbl.Text="OFF"
        end
    end) y=y+36

    -- ── Chams ─────────────────────────────────────────────────
    Section(C,"✨ Chams (Glow Through Walls)",y) y=y+22
    InfoBox(C,"Makes all players glow solid neon colors visible through walls. Way cleaner than box ESP.",y,34) y=y+38
    local _,chamsLbl=InfoBox(C,"OFF",y,22) y=y+26
    local chamsConn=nil
    local chamsOriginals={} -- store original material/color to restore
    Dropdown(C,"Chams Color:",{"Rainbow","Red","Blue","Green","Pink","White"},y,function(v) S.chamsColor=v end) y=y+34
    Toggle(C,"✨ Enable Chams",y,function(v)
        S.chamsOn=v
        if v then
            if chamsConn then chamsConn:Disconnect() end
            chamsConn=RunService.Heartbeat:Connect(function()
                if not S.chamsOn then chamsConn:Disconnect() chamsConn=nil return end
                local colorMap={Red=Color3.fromRGB(255,50,50),Blue=Color3.fromRGB(50,100,255),
                    Green=Color3.fromRGB(50,255,100),Pink=Color3.fromRGB(255,80,220),
                    White=Color3.fromRGB(255,255,255)}
                local col2 = S.chamsColor=="Rainbow" and Color3.fromHSV(S.rgbHue,1,1)
                    or (colorMap[S.chamsColor or "Red"] or Color3.fromRGB(255,50,50))
                for _,t in ipairs(getAllTargets()) do
                    pcall(function()
                        for _,p in ipairs(t.char:GetDescendants()) do
                            if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then
                                p.Material=Enum.Material.Neon
                                p.Color=col2
                                p.LocalTransparencyModifier=0 -- visible through walls
                            end
                        end
                    end)
                end
            end)
            chamsLbl.Text="✨ ACTIVE — "..(S.chamsColor or "Rainbow")
        else
            if chamsConn then chamsConn:Disconnect() chamsConn=nil end
            -- Restore original appearance
            for _,t in ipairs(getAllTargets()) do
                pcall(function()
                    for _,p in ipairs(t.char:GetDescendants()) do
                        if p:IsA("BasePart") then
                            p.Material=Enum.Material.SmoothPlastic
                            p.LocalTransparencyModifier=0
                        end
                    end
                end)
            end
            chamsLbl.Text="OFF"
        end
    end) y=y+36

    -- ── Health Bars on ESP ───────────────────────────────────
    Section(C,"❤ Health Bars + Name Tags",y) y=y+22
    InfoBox(C,"Draws HP bars above player boxes. Updates live with their actual health value.",y,30) y=y+34
    Toggle(C,"❤ Show Health Bars",y,function(v) S.espHealthBars=v end) y=y+36
    Toggle(C,"🏷 Show Name Tags (big)",y,function(v) S.espBigNames=v end) y=y+36

    -- ── Kill Counter Overlay ─────────────────────────────────
    Section(C,"💀 Kill Counter",y) y=y+22
    InfoBox(C,"Tracks kills this session. Counts when an enemy's health hits 0 while in FOV.",y,30) y=y+34
    local killCount=0
    local _,killLbl=InfoBox(C,"Kills this session: 0",y,22) y=y+26
    -- Kill counter overlay on screen
    local killOverlay=Instance.new("TextLabel",SG)
    killOverlay.Size=UDim2.new(0,120,0,28) killOverlay.Position=UDim2.new(0,10,0,10)
    killOverlay.BackgroundColor3=Color3.fromRGB(8,8,18) killOverlay.BackgroundTransparency=0.25
    killOverlay.Text="💀 Kills: 0" killOverlay.TextColor3=Color3.fromRGB(255,80,80)
    killOverlay.TextSize=13 killOverlay.Font=Enum.Font.GothamBold
    killOverlay.BorderSizePixel=0 killOverlay.ZIndex=55 killOverlay.Visible=false
    Instance.new("UICorner",killOverlay).CornerRadius=UDim.new(0,8)
    local prevHealths={}
    Toggle(C,"💀 Enable Kill Counter",y,function(v)
        S.killCountOn=v killOverlay.Visible=v
        if v then
            task.spawn(function()
                while S.killCountOn do
                    for _,t in ipairs(getAllTargets()) do
                        pcall(function()
                            local hum=t.char:FindFirstChildOfClass("Humanoid")
                            if not hum then return end
                            local key=tostring(t.char)
                            local prev=prevHealths[key] or hum.Health
                            if prev>0 and hum.Health<=0 then
                                killCount=killCount+1
                                killLbl.Text="Kills: "..killCount
                                killOverlay.Text="💀 Kills: "..killCount
                                -- Flash red
                                killOverlay.TextColor3=Color3.fromRGB(255,255,80)
                                task.delay(0.3,function() killOverlay.TextColor3=Color3.fromRGB(255,80,80) end)
                            end
                            prevHealths[key]=hum.Health
                        end)
                    end
                    task.wait(0.2)
                end
                killOverlay.Visible=false
            end)
        end
    end) y=y+36
    Btn(C,"🔄 Reset Kill Count",y,Color3.fromRGB(35,10,10),function()
        killCount=0 killLbl.Text="Kills: 0" killOverlay.Text="💀 Kills: 0"
    end) y=y+34

    -- ── Combat Speed (always on when armed) ──────────────────
    Section(C,"💨 Combat Speed",y) y=y+22
    InfoBox(C,"Auto-applies high speed whenever you're in combat (gun equipped). No toggle needed — just equip a gun.",y,34) y=y+38
    local _,combatSpLbl=InfoBox(C,"OFF",y,22) y=y+26
    Slider(C,"Combat Speed",50,250,150,y,function(v)
        S.combatSpeed=v
        if S.combatSpeedOn then combatSpLbl.Text="⚡ "..v.." when armed" end
    end) y=y+44
    Toggle(C,"⚡ Auto Speed When Armed",y,function(v)
        S.combatSpeedOn=v
        if v then
            task.spawn(function()
                while S.combatSpeedOn do
                    local hum=getHum()
                    if hum then
                        local armed=GunData.tool~=nil
                        pcall(function()
                            hum.WalkSpeed=armed and (S.combatSpeed or 150)
                                or (S.speedOn and S.walkSpeed or 16)
                        end)
                    end
                    task.wait(0.15)
                end
            end)
            combatSpLbl.Text="⚡ AUTO — "..(S.combatSpeed or 150).." when armed"
        else combatSpLbl.Text="OFF" end
    end) y=y+36

    -- ── Base Protector ────────────────────────────────────────
    Section(C,"🏠 Base Protector",y) y=y+22
    InfoBox(C,"Teleports you back to your base when someone enters it. Watches for players entering your tycoon area.",y,34) y=y+38
    local _,baseLbl=InfoBox(C,"OFF — set your base position first",y,22) y=y+26
    local basePos=nil
    Btn(C,"📍 Set Base Position (stand here)",y,Color3.fromRGB(14,35,14),function()
        local hrp=getHRP()
        if hrp then
            basePos=hrp.Position
            baseLbl.Text="Base set: "..math.floor(basePos.X)..","..math.floor(basePos.Z)
        end
    end) y=y+34
    Toggle(C,"🏠 Enable Base Protector",y,function(v)
        S.baseProtOn=v
        if v and basePos then
            task.spawn(function()
                while S.baseProtOn do
                    for _,p in ipairs(Players:GetPlayers()) do
                        if p==LocalPlayer then continue end
                        local char=p.Character
                        local hrp=char and char:FindFirstChild("HumanoidRootPart")
                        if hrp and basePos then
                            local dist=(hrp.Position-basePos).Magnitude
                            if dist<60 then
                                -- Someone in base — teleport to them
                                local myH=getHRP()
                                if myH then
                                    myH.Anchored=true
                                    myH.CFrame=hrp.CFrame*CFrame.new(0,4,3)
                                    task.wait(0.05) myH.Anchored=false
                                end
                                baseLbl.Text="⚠ "..p.Name.." in base! TP'd to them"
                                break
                            end
                        end
                    end
                    task.wait(1)
                end
            end)
            baseLbl.Text="🏠 Protecting — "..math.floor(basePos.X)..","..math.floor(basePos.Z)
        elseif v and not basePos then
            baseLbl.Text="⚠ Stand in base first and set position"
            S.baseProtOn=false
        end
    end) y=y+36

    -- ── Noclip ───────────────────────────────────────────────
    Section(C,"👻 Noclip",y) y=y+22
    InfoBox(C,"Walk through all walls and objects.",y,24) y=y+28
    local noclipConn=nil
    Toggle(C,"👻 Enable Noclip",y,function(v)
        S.noclipOn=v
        if v then
            if noclipConn then noclipConn:Disconnect() end
            noclipConn=RunService.Stepped:Connect(function()
                if not S.noclipOn then noclipConn:Disconnect() noclipConn=nil return end
                local char=LocalPlayer.Character if not char then return end
                for _,p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then
                        pcall(function() p.CanCollide=false end)
                    end
                end
            end)
            StatusLbl.Text="👻 Noclip ON"
        else
            if noclipConn then noclipConn:Disconnect() noclipConn=nil end
            local char=LocalPlayer.Character
            if char then
                for _,p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then pcall(function() p.CanCollide=true end) end
                end
            end
        end
    end) y=y+36
end

-- ============================================================
-- ═══  MONEY TAB  ═════════════════════════════════════════
-- ============================================================
do
    local C=MoneyTab C.CanvasSize=UDim2.new(0,0,0,1200)
    local y=4

    -- ── Live Balance ──────────────────────────────────────────
    Section(C,"💰 Live Balance",y) y=y+22
    local _,balLbl=InfoBox(C,"Balance: checking...",y,22) y=y+26
    local _,gemLbl=InfoBox(C,"Gems: checking...",y,20) y=y+24
    local _,rebLbl=InfoBox(C,"Rebirths: checking...",y,20) y=y+24
    task.spawn(function()
        while task.wait(1) do
            if not balLbl or not balLbl.Parent then break end
            pcall(function()
                local rs=game:GetService("ReplicatedStorage")
                local knit=require(rs.Packages.Knit)
                local dc=knit.GetController("DataController")
                local data=dc:Get()
                if data then
                    balLbl.Text="💰 Cash: "..tostring(math.floor(data.Cash or 0))
                    gemLbl.Text="💎 Gems: "..tostring(math.floor(data.Gems or 0))
                    rebLbl.Text="🔄 Rebirths: "..tostring(data.Rebirth or 0)
                end
            end)
        end
    end)

    -- ── Rebirth System ────────────────────────────────────────
    -- CONFIRMED: workspace.PlayerTycoons.[name].Rebirth = RemoteFunction
    -- Pattern 1 (bare InvokeServer) returned true true — works with no args
    -- MasteryUtil formula: rebirth 1 = 150k, rebirth 2 = 200k, etc
    Section(C,"🔄 Rebirth (CONFIRMED WORKING)",y) y=y+22
    InfoBox(C,"Uses workspace.PlayerTycoons.[you].Rebirth:InvokeServer() — confirmed returns true. Check rebirth count after.",y,34) y=y+38
    local _,rebStatusLbl=InfoBox(C,"Ready — click to rebirth",y,20) y=y+24

    local function getTycoonRemote(name)
        local pt=workspace:FindFirstChild("PlayerTycoons")
        if not pt then return nil end
        local myT=pt:FindFirstChild(LocalPlayer.Name)
        if not myT then return nil end
        return myT:FindFirstChild(name)
    end

    -- Single rebirth
    Btn(C,"🔄 DO REBIRTH NOW",y,Color3.fromRGB(20,40,60),function()
        task.spawn(function()
            local rebRF=getTycoonRemote("Rebirth")
            if not rebRF then
                rebStatusLbl.Text="⚠ Rebirth remote not found"
                return
            end
            local ok,result=pcall(function() return rebRF:InvokeServer() end)
            if ok and result then
                rebStatusLbl.Text="✅ Rebirth success! Check count"
            else
                rebStatusLbl.Text="⚠ Result: "..tostring(ok).." "..tostring(result)
            end
        end)
    end) y=y+34

    -- Auto rebirth loop
    local rebirthLoopActive=false
    local rebirthLoopConn=nil
    local rebirthCount=0

    -- Speed slider for rebirth loop
    local rebirthDelay = 0.5
    Slider(C,"Speed (seconds between)",0.1,3,0.5,y,function(v)
        rebirthDelay=v
    end) y=y+44

    Toggle(C,"🔄 Auto Rebirth Loop",y,function(v)
        rebirthLoopActive=v
        if v then
            if rebirthLoopConn then pcall(function() task.cancel(rebirthLoopConn) end) end
            -- Cache remote once for speed
            local rebRF=getTycoonRemote("Rebirth")
            if not rebRF then
                rebStatusLbl.Text="⚠ Rebirth remote not found"
                rebirthLoopActive=false
                return
            end
            rebirthLoopConn=task.spawn(function()
                while rebirthLoopActive do
                    local ok,result=pcall(function() return rebRF:InvokeServer() end)
                    if ok and result then
                        rebirthCount=rebirthCount+1
                        pcall(function()
                            rebStatusLbl.Text="🔄 Rebirths: "..rebirthCount.." (total session)"
                        end)
                    else
                        -- Remote rejected — slow down temporarily
                        task.wait(1)
                    end
                    task.wait(rebirthDelay)
                end
            end)
            rebStatusLbl.Text="🔄 Running... (every "..rebirthDelay.."s)"
        else
            rebirthLoopActive=false
            if rebirthLoopConn then
                pcall(function() task.cancel(rebirthLoopConn) end)
                rebirthLoopConn=nil
            end
            rebStatusLbl.Text="✅ Stopped — "..rebirthCount.." rebirths this session"
        end
    end) y=y+36

    -- Also try tycoon RemoteFunction with rebirth string
    Btn(C,"⚙ Try Tycoon RF Rebirth",y,Color3.fromRGB(15,25,40),function()
        task.spawn(function()
            local rf=getTycoonRemote("RemoteFunction")
            local re=getTycoonRemote("RemoteEvent")
            if rf then
                local ok1,r1=pcall(function() return rf:InvokeServer("Rebirth") end)
                local ok2,r2=pcall(function() return rf:InvokeServer("Rebirth",true) end)
                rebStatusLbl.Text="RF: "..tostring(ok1).."|"..tostring(r1).." / "..tostring(ok2).."|"..tostring(r2)
            end
            if re then
                pcall(function() re:FireServer("Rebirth") end)
                pcall(function() re:FireServer("Rebirth",true) end)
            end
        end)
    end) y=y+34

    -- ── TycoonVals Multiplier ─────────────────────────────────
    -- Confirmed: workspace.PlayerTycoons.[name].TycoonVals
    -- Contains: Multiplier(1), Multiplier2(1), CashCollect(0), Enemies(0)
    -- Setting these client-side gets server confirmed when Reward remote fires
    Section(C,"⚙ Tycoon Multiplier Hack",y) y=y+22
    InfoBox(C,"Sets Multiplier + Multiplier2 + CashCollect in TycoonVals to max. Combine with Money Loop for best effect.",y,34) y=y+38
    local _,multiLbl=InfoBox(C,"Multiplier: checking...",y,20) y=y+24

    local function getTycoonVals()
        local pt=workspace:FindFirstChild("PlayerTycoons")
        if not pt then return nil end
        local myT=pt:FindFirstChild(LocalPlayer.Name)
        if not myT then return nil end
        return myT:FindFirstChild("TycoonVals")
    end

    local function setMultipliers(val)
        local tv=getTycoonVals()
        if not tv then multiLbl.Text="⚠ TycoonVals not found" return false end
        local set=0
        local names={"Multiplier","Multiplier2","CashCollect","Enemies"}
        for _,n in ipairs(names) do
            local v=tv:FindFirstChild(n)
            if v then
                pcall(function()
                    v.Value=val
                    set=set+1
                end)
            end
        end
        multiLbl.Text="✅ Set "..set.." values to "..tostring(val)
        return set>0
    end

    -- Watch multiplier live
    task.spawn(function()
        while task.wait(2) do
            if not multiLbl or not multiLbl.Parent then break end
            local tv=getTycoonVals()
            if tv then
                local m=tv:FindFirstChild("Multiplier")
                local m2=tv:FindFirstChild("Multiplier2")
                local cc=tv:FindFirstChild("CashCollect")
                if m and m2 then
                    pcall(function()
                        multiLbl.Text="x"..m.Value.." | x"..m2.Value.." | CC:"..tostring(cc and cc.Value or 0)
                    end)
                end
            end
        end
    end)

    Btn(C,"⚡ SET MAX MULTIPLIERS (9999)",y,Color3.fromRGB(40,25,5),function()
        setMultipliers(9999)
    end) y=y+34
    Btn(C,"🔁 Reset Multipliers (1)",y,Color3.fromRGB(20,10,10),function()
        setMultipliers(1)
        multiLbl.Text="Reset to 1"
    end) y=y+34

    -- Keep multipliers maxed in a loop (server might reset them)
    local multiLoop=false
    local multiConn=nil
    Toggle(C,"🔄 Keep Multipliers Maxed",y,function(v)
        multiLoop=v
        if v then
            if multiConn then pcall(function() task.cancel(multiConn) end) end
            multiConn=task.spawn(function()
                while multiLoop do
                    setMultipliers(9999)
                    task.wait(3) -- re-apply every 3s in case server resets
                end
            end)
            multiLbl.Text="🔄 Auto-maxing every 3s"
        else
            multiLoop=false
            if multiConn then pcall(function() task.cancel(multiConn) end) multiConn=nil end
            multiLbl.Text="Stopped"
        end
    end) y=y+36

    -- ── CashDrop Auto-Collect ─────────────────────────────────
    -- Confirmed from source:
    -- Remote is inside ReplicatedStorage.Assets.Models.AdminEventAssets.CashDrop (or similar)
    -- FireServer("Pickup", "MeteorSpawn"..i) — server validates 45 stud range
    -- Rewards: 40% = 75k-100k, 10% = 150k-200k, 10% = 200k-250k, 40% = 100 SeasonPoints
    Section(C,"☄ CashDrop Auto-Collect",y) y=y+22
    InfoBox(C,"Watches for CashDrop meteor events. Teleports to each meteor and fires pickup remote. Server validates 45 stud range.",y,40) y=y+44
    local _,dropLbl=InfoBox(C,"Status: watching...",y,22) y=y+26

    local cashDropActive=false
    local cashDropConn=nil
    local cashDropPickupRemote=nil
    local cashDropCollected=0

    -- Find the CashDrop pickup remote from source
    local function findCashDropRemote()
        if cashDropPickupRemote then return cashDropPickupRemote end
        local rs=game:GetService("ReplicatedStorage")
        -- Known path from source code
        local paths={
            {"Assets","Models","AdminEventAssets","CashDrop"},
            {"Assets","Models","CashDrop"},
            {"AdminEventAssets","CashDrop"},
        }
        for _,path in ipairs(paths) do
            local obj=rs
            for _,part in ipairs(path) do
                obj=obj:FindFirstChild(part)
                if not obj then break end
            end
            if obj then
                for _,v in ipairs(obj:GetDescendants()) do
                    if v:IsA("RemoteEvent") then
                        cashDropPickupRemote=v
                        print("[GB233] CashDrop remote: "..v:GetFullName())
                        return v
                    end
                end
            end
        end
        -- Fallback: scan all remotes for "pickup"
        for _,v in ipairs(rs:GetDescendants()) do
            if v:IsA("RemoteEvent") and v.Name:lower():find("pickup") then
                cashDropPickupRemote=v
                return v
            end
        end
        return nil
    end

    -- Collect a single meteor by teleporting to it and firing pickup
    local function collectMeteor(meteorName, meteorPart)
        local hrp=getHRP()
        if not hrp then return false end
        local remote=findCashDropRemote()
        if not remote then return false end

        -- Teleport to meteor
        if meteorPart then
            local targetPos=meteorPart.Position+Vector3.new(0,3,0)
            local hum=getHum()
            if hum then pcall(function() hum.WalkSpeed=0 end) end
            -- Repeat teleport to beat anti-teleport
            for i=1,6 do
                pcall(function()
                    hrp.Anchored=true
                    hrp.CFrame=CFrame.new(targetPos)
                    LocalPlayer.Character:PivotTo(CFrame.new(targetPos))
                end)
                task.wait(0.05)
            end
            hrp.Anchored=false
            if hum then pcall(function() hum.WalkSpeed=S.speedOn and S.walkSpeed or 16 end) end
            task.wait(0.1)
        end

        -- Fire pickup remote with confirmed format
        local ok=pcall(function() remote:FireServer("Pickup", meteorName) end)
        return ok
    end

    -- Auto-collect all active meteors
    local function collectAllMeteors()
        local collected=0
        -- Method 1: find MeteorSpawn parts in workspace
        for _,v in ipairs(workspace:GetDescendants()) do
            local ln=v.Name:lower()
            if (ln:find("meteor") or ln:find("cashdrop") or ln:find("cashcrate")) 
            and (v:IsA("BasePart") or v:IsA("Model")) then
                local name=v.Name
                if collectMeteor(name, v:IsA("Model") and v.PrimaryPart or v) then
                    collected=collected+1
                    cashDropCollected=cashDropCollected+1
                end
                task.wait(0.2)
            end
        end
        -- Method 2: fire all known spawn names blindly (no distance check needed if teleported)
        local remote=findCashDropRemote()
        if remote then
            for i=1,25 do
                pcall(function() remote:FireServer("Pickup","MeteorSpawn"..i) end)
                task.wait(0.05)
            end
        end
        return collected
    end

    Toggle(C,"☄ Auto-Collect CashDrops",y,function(v)
        cashDropActive=v
        if v then
            cashDropPickupRemote=nil -- refresh remote
            local remote=findCashDropRemote()
            if not remote then
                dropLbl.Text="⚠ Pickup remote not found yet — will retry"
            else
                dropLbl.Text="✅ Watching for meteors... collected: "..cashDropCollected
            end
            -- Watch workspace for new meteor parts
            if cashDropConn then cashDropConn:Disconnect() end
            cashDropConn=workspace.DescendantAdded:Connect(function(obj)
                if not cashDropActive then return end
                local ln=obj.Name:lower()
                if ln:find("meteor") or ln:find("cashdrop") then
                    task.wait(0.3) -- let it fully load
                    if obj:IsA("BasePart") or obj:IsA("Model") then
                        local part=obj:IsA("Model") and obj.PrimaryPart or obj
                        if collectMeteor(obj.Name, part) then
                            cashDropCollected=cashDropCollected+1
                            pcall(function() dropLbl.Text="✅ Collected "..cashDropCollected.." meteors!" end)
                        end
                    end
                end
            end)
        else
            cashDropActive=false
            if cashDropConn then cashDropConn:Disconnect() cashDropConn=nil end
            dropLbl.Text="Stopped — collected: "..cashDropCollected
        end
    end) y=y+36

    Btn(C,"☄ Collect NOW (Manual)",y,Color3.fromRGB(35,20,5),function()
        task.spawn(function()
            dropLbl.Text="Scanning for meteors..."
            local n=collectAllMeteors()
            dropLbl.Text="Collected "..n.." meteors! ("..cashDropCollected.." total)"
        end)
    end) y=y+34

    -- Also trigger CashDrop admin event (fires server-side CashDrop for everyone)
    Btn(C,"☄ Fire CashDrop Event",y,Color3.fromRGB(25,15,5),function()
        local rs=game:GetService("ReplicatedStorage")
        local ae=rs:FindFirstChild("AdminEvents")
        if ae then
            local cd=ae:FindFirstChild("CashDrop")
            if cd then
                pcall(function() cd:FireServer() end)
                pcall(function() cd:FireServer(LocalPlayer) end)
                pcall(function() cd:FireServer(true) end)
                dropLbl.Text="Fired CashDrop event!"
            else
                dropLbl.Text="⚠ CashDrop not in AdminEvents"
            end
        else
            dropLbl.Text="⚠ AdminEvents not found"
        end
    end) y=y+34

    -- ── Other Admin Events ────────────────────────────────────
    Section(C,"👑 Admin Events",y) y=y+22
    InfoBox(C,"All confirmed from AdminEvents folder scan. GoldenCrate confirmed exists.",y,28) y=y+32
    local _,adminLbl=InfoBox(C,"Click to fire event",y,20) y=y+24

    local ADMIN_EVENTS={
        {"GoldenCrate","🏆 Golden Crate"},
        {"AlienInvasion","👾 Alien Invasion"},
        {"Giant","👹 Spawn Giant"},
        {"Drill","⛏ Drill Event"},
        {"MeteorShower","☄ Meteor Shower"},
        {"PresentDrop","🎁 Present Drop"},
        {"PumpkinRain","🎃 Pumpkin Rain"},
        {"GrantSoldier","💂 Grant Soldier"},
    }

    for _,ae in ipairs(ADMIN_EVENTS) do
        local evName=ae[1] local evLabel=ae[2]
        local row=Instance.new("Frame",C)
        row.Size=UDim2.new(1,0,0,28) row.Position=UDim2.new(0,0,0,y)
        row.BackgroundColor3=Color3.fromRGB(12,12,24) row.BorderSizePixel=0 row.ZIndex=10
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,5)
        local lbl=Instance.new("TextLabel",row)
        lbl.Size=UDim2.new(0.65,0,1,0) lbl.Position=UDim2.new(0,8,0,0)
        lbl.BackgroundTransparency=1 lbl.Text=evLabel
        lbl.TextColor3=Color3.fromRGB(200,180,255) lbl.TextSize=11
        lbl.Font=Enum.Font.GothamBold lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.ZIndex=11
        local btn=Instance.new("TextButton",row)
        btn.Size=UDim2.new(0.33,0,0,24) btn.Position=UDim2.new(0.66,0,0,2)
        btn.BackgroundColor3=Color3.fromRGB(30,15,40) btn.Text="🔥 Fire"
        btn.TextColor3=Color3.fromRGB(200,150,255) btn.TextSize=10
        btn.Font=Enum.Font.GothamBold btn.BorderSizePixel=0 btn.ZIndex=11
        Instance.new("UICorner",btn).CornerRadius=UDim.new(0,4)
        local n=evName
        btn.MouseButton1Click:Connect(function()
            local rs=game:GetService("ReplicatedStorage")
            local adminEv=rs:FindFirstChild("AdminEvents")
            if not adminEv then adminLbl.Text="⚠ No AdminEvents folder" return end
            local ev=adminEv:FindFirstChild(n)
            if not ev then adminLbl.Text="⚠ "..n.." not found" return end
            pcall(function() ev:FireServer() end)
            pcall(function() ev:FireServer(LocalPlayer) end)
            pcall(function() ev:FireServer(true) end)
            adminLbl.Text="Fired: "..n
            btn.BackgroundColor3=Color3.fromRGB(10,30,10)
            task.delay(2,function() pcall(function() btn.BackgroundColor3=Color3.fromRGB(30,15,40) end) end)
        end)
        y=y+30
    end
    y=y+6

    -- ── Collector Dupe ────────────────────────────────────────
    Section(C,"💎 Collector Dupe",y) y=y+22
    InfoBox(C,"Hooks Reward remote. Walk on pad = multiplied cash.",y,28) y=y+32
    local _,colLbl=InfoBox(C,"Status: OFF",y,22) y=y+26
    Slider(C,"Multiplier",2,50,10,y,function(v) S.collectorMulti=v end) y=y+44
    Toggle(C,"💎 Collector Dupe",y,function(v)
        if v then
            local ok=enableCollectorDupe()
            if ok then colLbl.Text="✅ Hooked x"..(S.collectorMulti+1)
            else colLbl.Text="⚠ Reward remote not found" end
        else disableCollectorDupe() colLbl.Text="OFF" end
    end) y=y+36

    -- ── Infinite Spins ────────────────────────────────────────
    Section(C,"🎰 Infinite Spins",y) y=y+22
    local _,spinLbl=InfoBox(C,"Spins: 0",y,22) y=y+26
    Toggle(C,"🎰 Enable Spin Loop",y,function(v)
        if v then
            startFreeSpins()
            task.spawn(function()
                while S.freeSpinsOn do
                    task.wait(1)
                    pcall(function() spinLbl.Text="🎰 Spins: "..(S.spinsCount or 0) end)
                end
            end)
        else stopFreeSpins() spinLbl.Text="Stopped: "..(S.spinsCount or 0) end
    end) y=y+36

    -- ── Money Loop ────────────────────────────────────────────
    Section(C,"♾ Money Loop",y) y=y+22
    local _,monLbl=InfoBox(C,"Status: Idle",y,22) y=y+26
    Dropdown(C,"Speed:",{"Slow (1s)","Normal (0.5s)","Fast (0.25s)","Very Fast (0.1s)"},y,function(v)
        local m={["Slow (1s)"]=1,["Normal (0.5s)"]=0.5,["Fast (0.25s)"]=0.25,["Very Fast (0.1s)"]=0.1}
        S.moneySpeed=m[v] or 0.5
        if S.moneyOn then stopMoneyDupe() task.wait(0.1) startMoneyDupe() end
    end) y=y+34
    Toggle(C,"💰 Money Loop",y,function(v)
        if v then
            startMoneyDupe()
            monLbl.Text="RUNNING 💰"
        else
            stopMoneyDupe()
            monLbl.Text="Stopped: "..(S.moneyCount or 0).." loops"
        end
    end) y=y+36

    -- ── Free Purchases ────────────────────────────────────────
    Section(C,"🏪 Free Purchases",y) y=y+22
    local _,buyLbl=InfoBox(C,"Status: OFF",y,22) y=y+26
    Toggle(C,"🏪 Free Purchases",y,function(v)
        if v then enableFreeBuy() buyLbl.Text="✅ Active — buy freely"
        else disableFreeBuy() buyLbl.Text="OFF" end
    end) y=y+36

    C.CanvasSize=UDim2.new(0,0,0,y+20)
end


-- ============================================================
-- ═══  GUNS TAB  ══════════════════════════════════════════
-- ============================================================
do
    local C=GunsTab C.CanvasSize=UDim2.new(0,0,0,860)
    local y=4

    Section(C,"🔍 Live Gun Scanner",y) y=y+22
    local _,gunNameL=InfoBox(C,"No gun equipped",y,22) y=y+26
    local _,gunInfoL=InfoBox(C,"Remotes: -- | Ammo: -- | Rate: --",y,22) y=y+26
    local _,gunFireL=InfoBox(C,"Fire remote: --",y,20) y=y+24
    task.spawn(function()
        while task.wait(0.5) do
            if not gunNameL or not gunNameL.Parent then break end
            if GunData.scanned and GunData.name~="" then
                pcall(function()
                    gunNameL.Text="🔫 "..GunData.name
                    gunInfoL.Text="Remotes: "..#GunData.allRemotes.." | Parts: "..#GunData.parts
                    gunFireL.Text="Fire: "..(GunData.fireRemote and GunData.fireRemote.Name or "❌")
                        .."  Ammo: "..(GunData.ammoValue and GunData.ammoValue.Name or "❌")
                end)
            else
                pcall(function() gunNameL.Text="Equip any gun to scan it" end)
            end
        end
    end)
    Btn(C,"📋 Print Full Scan to Console",y,Color3.fromRGB(10,10,40),function()
        if GunData.scanned then printGunScan(GunData) else gunInfoL.Text="Equip a gun first" end
    end) y=y+34

    Section(C,"🌈 RGB on Held Gun",y) y=y+22
    Toggle(C,"🌈 RGB Gun Color",y,function(v)
        S.gunRGBOn=v
        if not v then
            -- Restore original look on all parts
            local tool = GunData.tool
            if tool then
                local ok, descs = pcall(function() return tool:GetDescendants() end)
                if ok then
                    for _,p in ipairs(descs) do
                        if p:IsA("BasePart") then
                            pcall(function()
                                p.Material = Enum.Material.SmoothPlastic
                                p.Color = Color3.fromRGB(80,80,80)
                            end)
                        end
                    end
                end
            end
        end
    end) y=y+36

    Section(C,"🎯 Combat Features",y) y=y+22
    Toggle(C,"🔫 Trigger Bot",y,function(v) S.triggerBot=v if v then startTriggerBot() else stopTriggerBot() end end) y=y+36
    Toggle(C,"🔁 Full Auto",y,function(v) S.fullAuto=v if v then startFullAuto() else stopFullAuto() end end) y=y+36
    Toggle(C,"💀 One Shot Kill",y,function(v) S.oneShotOn=v if v then enableOneShot() else disableOneShot() end end) y=y+36
    Btn(C,"🔍 Reload Gun Remotes",y,Color3.fromRGB(10,10,40),function()
        task.spawn(initMTGunRemotes)
        StatusLbl.Text="✅ Gun remotes reloaded — check F9 console"
    end) y=y+34
    Toggle(C,"🧱 Wallbang",y,function(v) S.wallbangOn=v if v then enableWallbang() else disableWallbang() end end) y=y+36

    Section(C,"⚡ Classic Mods",y) y=y+22
    Toggle(C,"⚡ No Recoil",y,function(v)
        S.noRecoil=v
        if v then
            local sx=nil
            if _G.GB233NRC then _G.GB233NRC:Disconnect() end
            _G.GB233NRC=RunService.RenderStepped:Connect(function()
                if not S.noRecoil then _G.GB233NRC:Disconnect() _G.GB233NRC=nil return end
                local cur=Camera.CFrame local rx,ry,rz=cur:ToEulerAnglesYXZ()
                if sx and rx-sx<-0.015 then
                    Camera.CFrame=CFrame.new(cur.Position)*CFrame.fromEulerAnglesYXZ(sx,ry,rz)
                end
                sx=rx
            end)
        else if _G.GB233NRC then _G.GB233NRC:Disconnect() _G.GB233NRC=nil end end
    end) y=y+36
    Toggle(C,"🔁 Rapid Fire",y,function(v)
        S.rapidFire=v
        if v then task.spawn(function()
            while S.rapidFire do
                if GunData.fireRateValue then pcall(function() GunData.fireRateValue.Value=0.01 end) end
                for _,sv in ipairs(GunData.allValues) do
                    local ok,ln=pcall(function() return sv.value.Name:lower() end)
                    if ok and (ln:find("cooldown") or ln:find("delay") or ln:find("firerate") or ln:find("interval")) then
                        pcall(function() sv.value.Value=0.01 end)
                    end
                end
                task.wait(0.5)
            end
        end) end
    end) y=y+36
    Toggle(C,"♾ Infinite Ammo",y,function(v)
        S.infAmmo=v
        if v then task.spawn(function()
            while S.infAmmo do
                if GunData.ammoValue then pcall(function() GunData.ammoValue.Value=9999 end) end
                if GunData.maxAmmoValue then pcall(function() GunData.maxAmmoValue.Value=9999 end) end
                task.wait(0.5)
            end
        end) end
    end) y=y+36
    Toggle(C,"🔃 Auto Reload",y,function(v)
        S.autoReload=v
        if v then task.spawn(function()
            while S.autoReload do
                if GunData.reloadRemote then
                    pcall(function()
                        if GunData.reloadRemote:IsA("RemoteEvent") then GunData.reloadRemote:FireServer()
                        else GunData.reloadRemote:InvokeServer() end
                    end)
                end
                if GunData.ammoValue then pcall(function() if GunData.ammoValue.Value<3 then GunData.ammoValue.Value=9999 end end) end
                task.wait(0.5)
            end
        end) end
    end) y=y+36
    Slider(C,"Spread Reduction %",0,100,0,y,function(v)
        for _,sv in ipairs(GunData.allValues) do
            local ok,ln=pcall(function() return sv.value.Name:lower() end)
            if ok and (ln:find("spread") or ln:find("accuracy")) then
                pcall(function() sv.value.Value=sv.value.Value*(1-v/100) end)
            end
        end
    end) y=y+44

    -- Admin gun
    Section(C,"☀ Admin Ghost Gun",y) y=y+22
    local _,adminL=InfoBox(C,"OFF",y,20) y=y+24
    Toggle(C,"☀ Admin RGB Gun",y,function(v)
        S.adminGunOn=v
        if v then createAdminGun() adminL.Text="✅ In backpack — equip it!"
        else removeAdminGun() adminL.Text="OFF" end
    end) y=y+36
    Btn(C,"🔄 Recreate",y,Color3.fromRGB(28,18,6),function()
        if S.adminGunOn then createAdminGun() adminL.Text="✅ Recreated" end
    end) y=y+34
end

-- ============================================================
-- ═══  PLAYERS TAB  — dropdown list style ═════════════════
-- ============================================================
do
    local C=PlayersTab C.CanvasSize=UDim2.new(0,0,0,700)
    local y=4

    -- Header
    Section(C,"👥 Players",y) y=y+22
    local _,selLbl=InfoBox(C,"No player selected — open list below",y,22) y=y+26
    local _,specLbl=InfoBox(C,"Spectate: OFF",y,20) y=y+24

    -- Toggle button
    local listOpen=false
    local listToggleBtn=Instance.new("TextButton",C)
    listToggleBtn.Size=UDim2.new(1,-4,0,32)
    listToggleBtn.Position=UDim2.new(0,2,0,y)
    listToggleBtn.BackgroundColor3=Color3.fromRGB(20,20,45)
    listToggleBtn.Text="▼  Show Players  ▼"
    listToggleBtn.TextColor3=Color3.fromRGB(255,200,60)
    listToggleBtn.TextSize=12 listToggleBtn.Font=Enum.Font.GothamBold
    listToggleBtn.BorderSizePixel=0 listToggleBtn.ZIndex=12
    Instance.new("UICorner",listToggleBtn).CornerRadius=UDim.new(0,7)
    y=y+36

    -- List frame (ScrollingFrame, starts at height 0)
    local LIST_ITEM_H = 36
    local LIST_MAX_H  = 180

    local listFrame=Instance.new("ScrollingFrame",C)
    listFrame.Size=UDim2.new(1,-4,0,0)
    listFrame.Position=UDim2.new(0,2,0,y)
    listFrame.BackgroundColor3=Color3.fromRGB(10,10,22)
    listFrame.BackgroundTransparency=0.1
    listFrame.BorderSizePixel=0
    listFrame.ClipsDescendants=true
    listFrame.ScrollBarThickness=4
    listFrame.ScrollBarImageColor3=Color3.fromRGB(255,200,60)
    listFrame.ZIndex=11
    Instance.new("UICorner",listFrame).CornerRadius=UDim.new(0,8)

    local playerBtns={}

    local function buildList()
        -- Clear old entries
        for _,b in ipairs(playerBtns) do
            pcall(function() b:Destroy() end)
        end
        playerBtns={}

        local allP={}
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer then table.insert(allP,p) end
        end

        local count=#allP
        local totalH=count*LIST_ITEM_H+6
        local showH=math.min(totalH, LIST_MAX_H)

        -- Only resize if open
        if listOpen then
            listFrame.Size=UDim2.new(1,-4,0,showH)
        end
        listFrame.CanvasSize=UDim2.new(0,0,0,totalH)

        local py=3
        for _,p in ipairs(allP) do
            -- Row
            local row=Instance.new("Frame",listFrame)
            row.Size=UDim2.new(1,-6,0,LIST_ITEM_H-4)
            row.Position=UDim2.new(0,3,0,py)
            row.BackgroundColor3=Color3.fromRGB(16,16,30)
            row.BorderSizePixel=0 row.ZIndex=12
            Instance.new("UICorner",row).CornerRadius=UDim.new(0,6)

            -- Invisible button over row
            local btn=Instance.new("TextButton",row)
            btn.Size=UDim2.new(1,0,1,0)
            btn.BackgroundTransparency=1
            btn.Text="" btn.ZIndex=16

            -- Team dot
            local dot=Instance.new("Frame",row)
            dot.Size=UDim2.new(0,8,0,8)
            dot.Position=UDim2.new(0,6,0.5,-4)
            dot.BackgroundColor3=Color3.fromRGB(100,100,220)
            pcall(function()
                if p.Team then dot.BackgroundColor3=p.TeamColor.Color end
            end)
            dot.BorderSizePixel=0 dot.ZIndex=13
            Instance.new("UICorner",dot).CornerRadius=UDim.new(0.5,0)

            -- Name
            local nameL=Instance.new("TextLabel",row)
            nameL.Size=UDim2.new(0.65,0,1,0)
            nameL.Position=UDim2.new(0,18,0,0)
            nameL.BackgroundTransparency=1
            nameL.Text=p.Name
            nameL.TextColor3=Color3.fromRGB(225,225,255)
            nameL.TextSize=12 nameL.Font=Enum.Font.GothamBold
            nameL.TextXAlignment=Enum.TextXAlignment.Left
            nameL.TextTruncate=Enum.TextTruncate.AtEnd
            nameL.ZIndex=13

            -- Distance
            local distL=Instance.new("TextLabel",row)
            distL.Size=UDim2.new(0.33,0,1,0)
            distL.Position=UDim2.new(0.66,0,0,0)
            distL.BackgroundTransparency=1
            distL.Text="--m"
            distL.TextColor3=Color3.fromRGB(120,120,160)
            distL.TextSize=10 distL.Font=Enum.Font.Gotham
            distL.TextXAlignment=Enum.TextXAlignment.Right
            distL.ZIndex=13

            local cp=p

            -- Click to select
            btn.MouseButton1Click:Connect(function()
                S.selectedPlayer=cp
                S.trollTarget=cp
                -- Highlight
                for _,b2 in ipairs(playerBtns) do
                    pcall(function() b2.BackgroundColor3=Color3.fromRGB(16,16,30) end)
                end
                row.BackgroundColor3=Color3.fromRGB(30,22,6)
                selLbl.Text="✅ Selected: "..cp.Name
                -- Close list
                listOpen=false
                listFrame.Size=UDim2.new(1,-4,0,0)
                listToggleBtn.Text="▼  "..cp.Name.."  ▼"
                listToggleBtn.TextColor3=Color3.fromRGB(80,255,80)
                C.CanvasSize=UDim2.new(0,0,0,700)
            end)

            -- Live distance update
            task.spawn(function()
                while row and row.Parent do
                    local myH=getHRP()
                    local char=cp.Character
                    local tH=char and char:FindFirstChild("HumanoidRootPart")
                    if myH and tH then
                        local d=math.floor((tH.Position-myH.Position).Magnitude)
                        pcall(function() distL.Text=d.."m" end)
                    else
                        pcall(function() distL.Text="--m" end)
                    end
                    task.wait(0.5)
                end
            end)

            table.insert(playerBtns, row)
            py=py+LIST_ITEM_H
        end

        if count==0 then
            local el=Instance.new("TextLabel",listFrame)
            el.Size=UDim2.new(1,0,0,36)
            el.BackgroundTransparency=1
            el.Text="No other players in server"
            el.TextColor3=Color3.fromRGB(100,100,130)
            el.TextSize=11 el.Font=Enum.Font.Gotham
            el.ZIndex=13
        end
    end

    -- Build immediately (collapsed)
    buildList()

    -- Toggle open/close
    listToggleBtn.MouseButton1Click:Connect(function()
        listOpen=not listOpen
        if listOpen then
            buildList()
            listToggleBtn.Text="▲  Close List  ▲"
            listToggleBtn.TextColor3=Color3.fromRGB(255,200,60)
            -- Expand canvas to fit list + actions below
            C.CanvasSize=UDim2.new(0,0,0,950)
        else
            listFrame.Size=UDim2.new(1,-4,0,0)
            if S.selectedPlayer then
                listToggleBtn.Text="▼  "..S.selectedPlayer.Name.."  ▼"
                listToggleBtn.TextColor3=Color3.fromRGB(80,255,80)
            else
                listToggleBtn.Text="▼  Show Players  ▼"
                listToggleBtn.TextColor3=Color3.fromRGB(255,200,60)
            end
            C.CanvasSize=UDim2.new(0,0,0,700)
        end
    end)

    -- Refresh button - fixed position AFTER list area
    local REFRESH_Y = y + LIST_MAX_H + 6
    Btn(C,"🔄 Refresh List",REFRESH_Y,Color3.fromRGB(12,12,32),function()
        buildList()
        selLbl.Text="List refreshed — click a player"
    end)

    -- Actions - fixed position below refresh
    local actY = REFRESH_Y + 38
    Section(C,"📡 Actions on Selected",actY) actY=actY+22

    Btn(C,"🌀 Teleport To Player",actY,Color3.fromRGB(20,12,50),function()
        local p=S.selectedPlayer
        if not p then selLbl.Text="⚠ Select first" return end
        local tH=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        local myH=getHRP()
        if myH and tH then
            local targetCF=tH.CFrame*CFrame.new(0,4,3)
            -- Set SpawnCF so next respawn lands here
            pcall(function() LocalPlayer:SetAttribute("SpawnCF", targetCF) end)
            local hum=getHum()
            if hum then pcall(function() hum.WalkSpeed=0 hum.JumpPower=0 end) end
            task.spawn(function()
                for i=1,10 do
                    pcall(function() myH.Anchored=true myH.CFrame=targetCF end)
                    pcall(function() LocalPlayer.Character:PivotTo(targetCF) end)
                    task.wait(0.05)
                end
                myH.Anchored=false
                local s=S.speedOn and S.walkSpeed or 16
                if hum then pcall(function() hum.WalkSpeed=s hum.JumpPower=50 end) end
            end)
            selLbl.Text="→ "..p.Name
        else selLbl.Text="⚠ "..p.Name.." no character" end
    end) actY=actY+34

    Btn(C,"👻 Spawn ON Player",actY,Color3.fromRGB(50,12,12),function()
        local p=S.selectedPlayer
        if not p then selLbl.Text="⚠ Select first" return end
        local tH=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        local myH=getHRP()
        if myH and tH then
            local targetCF=tH.CFrame
            pcall(function() LocalPlayer:SetAttribute("SpawnCF", targetCF) end)
            local hum=getHum()
            if hum then pcall(function() hum.WalkSpeed=0 hum.JumpPower=0 end) end
            task.spawn(function()
                for i=1,10 do
                    pcall(function() myH.Anchored=true myH.CFrame=targetCF end)
                    pcall(function() LocalPlayer.Character:PivotTo(targetCF) end)
                    task.wait(0.05)
                end
                myH.Anchored=false
                if hum then pcall(function() hum.WalkSpeed=16 hum.JumpPower=50 end) end
            end)
        end
    end) actY=actY+34



    Toggle(C,"📷 Spectate",actY,function(v)
        if v then
            if not S.selectedPlayer then selLbl.Text="⚠ Select first" return end
            startSpectate(S.selectedPlayer)
            specLbl.Text="📷 "..S.selectedPlayer.Name
        else
            stopSpectate()
            specLbl.Text="OFF"
        end
    end) actY=actY+36

    local fzActive=false
    Btn(C,"❄ Freeze / Unfreeze",actY,Color3.fromRGB(12,12,50),function()
        local p=S.selectedPlayer
        if not p then selLbl.Text="⚠ Select first" return end
        local hrp=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then selLbl.Text="⚠ No character" return end
        fzActive=not fzActive
        if fzActive then
            local bp=Instance.new("BodyPosition")
            bp.MaxForce=Vector3.new(1e9,1e9,1e9)
            bp.Position=hrp.Position bp.D=500 bp.P=1e5
            bp.Name="GB233Fz" bp.Parent=hrp
            selLbl.Text="❄ Froze "..p.Name
        else
            local ex=hrp:FindFirstChild("GB233Fz")
            if ex then ex:Destroy() end
            selLbl.Text="Unfroze "..p.Name
        end
    end) actY=actY+34

    Section(C,"🔊 Sounds",actY) actY=actY+22
    local sndList={
        {"Air Horn",9120421830},{"Vine Boom",4612165787},
        {"Bruh",1190826553},{"Oof",9123340919},
        {"Siren",2865927823},{"Anime Wow",292479946}
    }
    local activeSounds={}
    local sndRow=Instance.new("Frame",C)
    sndRow.Size=UDim2.new(1,0,0,64)
    sndRow.Position=UDim2.new(0,0,0,actY)
    sndRow.BackgroundTransparency=1 sndRow.ZIndex=10
    local sl=Instance.new("UIListLayout",sndRow)
    sl.FillDirection=Enum.FillDirection.Horizontal
    sl.Padding=UDim.new(0,3) sl.Wraps=true
    for _,sd in ipairs(sndList) do
        local sid=sd[2]
        local sb=Instance.new("TextButton",sndRow)
        sb.Size=UDim2.new(0,100,0,28)
        sb.BackgroundColor3=Color3.fromRGB(32,10,48)
        sb.Text="▶ "..sd[1]
        sb.TextColor3=Color3.fromRGB(200,150,255)
        sb.TextSize=9 sb.Font=Enum.Font.GothamBold
        sb.BorderSizePixel=0 sb.ZIndex=11
        Instance.new("UICorner",sb).CornerRadius=UDim.new(0,5)
        sb.MouseButton1Click:Connect(function()
            local s=Instance.new("Sound")
            s.SoundId="rbxassetid://"..sid
            s.Volume=10 s.Looped=true
            s.RollOffMaxDistance=1e9 s.Parent=workspace
            task.delay(0.1,function() pcall(function() s:Play() end) end)
            table.insert(activeSounds,s)
        end)
    end
    actY=actY+68
    Btn(C,"🔇 Stop All Sounds",actY,Color3.fromRGB(50,12,12),function()
        for _,s in ipairs(activeSounds) do
            pcall(function() s:Stop() s:Destroy() end)
        end
        activeSounds={}
    end)

    -- Auto refresh on join/leave
    Players.PlayerAdded:Connect(function()
        task.wait(0.5) buildList()
    end)
    Players.PlayerRemoving:Connect(function()
        task.wait(0.5) buildList()
        if S.selectedPlayer and not S.selectedPlayer.Parent then
            S.selectedPlayer=nil
            selLbl.Text="Player left"
            listToggleBtn.Text="▼  Show Players  ▼"
            listToggleBtn.TextColor3=Color3.fromRGB(255,200,60)
        end
    end)
end


-- ============================================================
-- ═══  FLY TAB  ═══════════════════════════════════════════
-- ============================================================
do
    local C=FlyTab C.CanvasSize=UDim2.new(0,0,0,260)
    local y=4
    Section(C,"✈ Fly",y) y=y+22
    InfoBox(C,"W/A/S/D + Space/LCtrl | Uses camera direction",y,26) y=y+30
    Slider(C,"Fly Speed",10,500,80,y,function(v) S.flySpeed=v end) y=y+44
    Toggle(C,"✈ Enable Fly",y,function(v) if v then enableFly() else disableFly() end end) y=y+36
    Btn(C,"🏠 Land",y,Color3.fromRGB(14,28,14),function()
        disableFly()
        local hrp=getHRP() if not hrp then return end
        local rp=RaycastParams.new()
        rp.FilterDescendantsInstances={LocalPlayer.Character} rp.FilterType=Enum.RaycastFilterType.Exclude
        local res=workspace:Raycast(Vector3.new(hrp.Position.X,500,hrp.Position.Z),Vector3.new(0,-1000,0),rp)
        if res then hrp.Anchored=true hrp.CFrame=CFrame.new(res.Position+Vector3.new(0,5,0)) task.wait(0.05) hrp.Anchored=false end
    end) y=y+34
end

-- ============================================================
-- ═══  MOVE TAB  ══════════════════════════════════════════
-- ============================================================
do
    local C=MoveTab C.CanvasSize=UDim2.new(0,0,0,360)
    local y=4
    local _,spLbl=InfoBox(C,"WalkSpeed: 16",y,22) y=y+26
    Slider(C,"Walk Speed",16,250,60,y,function(v)
        S.walkSpeed=v if S.speedOn then applySpeed() end
        spLbl.Text="WalkSpeed: "..v..(S.speedOn and " ✅" or "")
    end) y=y+44
    Toggle(C,"💨 Speed",y,function(v) S.speedOn=v applySpeed() if v then startMoveLoop() end
        spLbl.Text="WalkSpeed: "..S.walkSpeed..(v and " ✅" or "")
    end) y=y+36
    Btn(C,"⚡ 100",y,Color3.fromRGB(18,18,45),function() S.walkSpeed=100 S.speedOn=true startMoveLoop() applySpeed() spLbl.Text="100 ✅" end) y=y+34
    Btn(C,"🚀 250",y,Color3.fromRGB(28,8,45),function() S.walkSpeed=250 S.speedOn=true startMoveLoop() applySpeed() spLbl.Text="250 ✅" end) y=y+34
    Btn(C,"🚶 Reset",y,Color3.fromRGB(18,18,18),function() S.walkSpeed=16 S.speedOn=false applySpeed() spLbl.Text="Reset" end) y=y+34
    local _,jpLbl=InfoBox(C,"JumpPower: 50",y,22) y=y+26
    Slider(C,"Jump Power",50,500,150,y,function(v)
        S.jumpPower=v if S.jumpOn then applySpeed() end
        jpLbl.Text="JumpPower: "..v..(S.jumpOn and " ✅" or "")
    end) y=y+44
    Toggle(C,"🦘 High Jump",y,function(v) S.jumpOn=v applySpeed() if v then startMoveLoop() end end) y=y+36
end

-- ============================================================
-- ═══  GOD TAB  ═══════════════════════════════════════════
-- ============================================================
do
    local C=GodTab C.CanvasSize=UDim2.new(0,0,0,320)
    local y=4
    local _,godLbl=InfoBox(C,"Status: OFF",y,22) y=y+26
    Toggle(C,"🛡 God Mode",y,function(v)
        if v then enableGod() godLbl.Text="🛡 GOD MODE ACTIVE"
        else disableGod() godLbl.Text="OFF" end
    end) y=y+36
    Btn(C,"💊 Max Health Now",y,Color3.fromRGB(14,40,14),function()
        local h=getHum() if h then pcall(function() h.MaxHealth=1e9 h.Health=1e9 end) godLbl.Text="Maxed ✅" end
    end) y=y+34
    Btn(C,"❤ Reset Health",y,Color3.fromRGB(38,12,12),function()
        local h=getHum() if h then pcall(function() h.MaxHealth=100 h.Health=100 end) godLbl.Text="Reset" end
    end) y=y+34
    Btn(C,"🔰 Add ForceField",y,Color3.fromRGB(10,10,40),function()
        local c=LocalPlayer.Character
        if c and not c:FindFirstChildOfClass("ForceField") then
            local ff=Instance.new("ForceField") ff.Visible=false ff.Parent=c
            godLbl.Text="FF added ✅"
        end
    end) y=y+34
end

-- ============================================================
-- ═══  FARM TAB  ══════════════════════════════════════════
-- ============================================================
do
    local C=FarmTab C.CanvasSize=UDim2.new(0,0,0,400)
    local y=4
    Section(C,"🤖 Auto Farm",y) y=y+22
    local _,farmLbl=InfoBox(C,"OFF",y,22) y=y+26
    Btn(C,"🔍 Find Collector",y,Color3.fromRGB(10,10,40),function()
        local pos=findCollector()
        if pos then farmLbl.Text="✅ "..math.floor(pos.X)..","..math.floor(pos.Z)
        else farmLbl.Text="⚠ Not found — be in your tycoon" end
    end) y=y+34
    Toggle(C,"🤖 Auto Farm",y,function(v)
        if v then startAutoFarm() farmLbl.Text="🤖 Running..."
        else stopAutoFarm() farmLbl.Text="Stopped" end
    end) y=y+36
    Section(C,"⚔ Kill Aura",y) y=y+22
    local _,auraLbl=InfoBox(C,"OFF",y,22) y=y+26
    Slider(C,"Range (studs)",5,80,20,y,function(v) S.killAuraRange=v end) y=y+44
    Toggle(C,"⚔ Kill Aura",y,function(v)
        if v then startKillAura() auraLbl.Text="⚔ ACTIVE r:"..(S.killAuraRange or 20)
        else stopKillAura() auraLbl.Text="OFF" end
    end) y=y+36
end

-- ============================================================

-- ============================================================
-- ═══  WEAPONS TAB  ═══════════════════════════════════════
-- ============================================================
do
    local C=WeaponsTab C.CanvasSize=UDim2.new(0,0,0,900)
    local y=4
    Section(C,"⚔ MT Weapons",y) y=y+22
    InfoBox(C,"All confirmed MT weapons from live scan. Clones to backpack + persists.",y,28) y=y+32
    local _,wepLbl=InfoBox(C,"Click any weapon to get it",y,20) y=y+24

    -- All confirmed weapons - packed
    local AW={"Glock","UZI","Bizon","P90","MP5","MP7","TEC-9","Snowball SMG","Vector","AK","AUG","FAMAS","G36C","SCAR","M16","Railgun","Flamethrower","Barrett","LE Sniper","Explosive Sniper","Assassin Sniper","Scout","SPAS-12","Sawed Off","AA12","Desert Eagle","Taser","M249","Minigun","SantaMinigun","RPG","Bazooka","Nuke Launcher","NukeRPG","GrumpyRPG","Ravage-RPG","Grenade Launcher","Fireworks RPG","PresentLauncher","Mortar","PortableNuke","AA-RPG","Grenade","Gas Grenade","Smoke Grenade","SnowGrenade","EMP Grenade","C4","PortableEMP","PortableGas","PortableLandmine","Flare Gun","Organic Chemistry","AntiTank UAV","Bird UAV","Bomb UAV","DogDrone UAV","DogDrone2 UAV","Gun UAV","Recon UAV","NukeCar UAV","HammerheadSMV","SeacraftDPC","Knife","HeatKnife","Katana","Machete","Scythe","Sentry","SentryAntiAir","Road Spikes","RIOT Shield","Medkit","FirstAid","Revive","NVG","Parachute","RepairTool","Vehicle Repair"}

    local persistWeapons={}
    local weaponPersistActive=false

    local function giveWeaponNow(name)
        local rs=game:GetService("ReplicatedStorage")
        local weapons=rs:FindFirstChild("Weapons")
        if not weapons then return false end
        local wep=weapons:FindFirstChild(name)
        if not wep then return false end
        local lp=game.Players.LocalPlayer
        -- Re-add to backpack if missing
        if not lp.Backpack:FindFirstChild(name) and
           not (lp.Character and lp.Character:FindFirstChild(name)) then
            pcall(function() wep:Clone().Parent=lp.Backpack end)
        end
        -- Keep InvData unlocked (client-side unlock state)
        pcall(function()
            local inv=lp:FindFirstChild("InvData")
            if inv then
                local slot=inv:FindFirstChild(name)
                if slot then slot.Value=1 end
            end
        end)
        return true
    end

    local function giveWeapon(name)
        local rs=game:GetService("ReplicatedStorage")
        local weapons=rs:FindFirstChild("Weapons")
        if not weapons then wepLbl.Text="⚠ Weapons folder not found" return false end
        local wep=weapons:FindFirstChild(name)
        if not wep then wepLbl.Text="⚠ "..name.." not found" return false end
        local lp=game.Players.LocalPlayer

        -- Step 1: clone to backpack
        local ok=pcall(function() wep:Clone().Parent=lp.Backpack end)

        -- Step 2: unlock in InvData (client-side gun unlock registry)
        pcall(function()
            local inv=lp:FindFirstChild("InvData")
            if inv then
                local slot=inv:FindFirstChild(name)
                if slot then
                    slot.Value=1
                else
                    -- Create the slot if it doesn't exist
                    local iv=Instance.new("IntValue")
                    iv.Name=name iv.Value=1 iv.Parent=inv
                end
            end
        end)

        -- Step 3: try to register via tycoon RemoteEvent
        -- Confirmed: workspace.PlayerTycoons.[name].RemoteEvent exists
        pcall(function()
            local pt=workspace:FindFirstChild("PlayerTycoons")
            local myT=pt and pt:FindFirstChild(lp.Name)
            local re=myT and myT:FindFirstChild("RemoteEvent")
            if re then
                re:FireServer("GiveWeapon", name)
                re:FireServer("UnlockWeapon", name)
                re:FireServer(name)
            end
        end)

        -- Step 4: try via Knit InventoryService
        pcall(function()
            local knit=require(rs.Packages.Knit)
            local inv=knit.GetService("InventoryService")
            inv:GrantItem(lp, name)
            inv:GrantWeapon(lp, name)
        end)

        -- Track for persistence loop
        if not table.find(persistWeapons,name) then
            table.insert(persistWeapons,name)
        end
        if not weaponPersistActive then
            weaponPersistActive=true
            task.spawn(function()
                while weaponPersistActive do
                    task.wait(0.5)
                    for _,n in ipairs(persistWeapons) do giveWeaponNow(n) end
                end
            end)
        end
        wepLbl.Text=ok and ("✅ "..name) or ("⚠ Check hotbar: "..name)
        return ok
    end

    -- Get All
    Btn(C,"💥 GET ALL WEAPONS",y,Color3.fromRGB(60,15,15),function()
        task.spawn(function()
            local got=0
            for _,n in ipairs(AW) do if giveWeapon(n) then got=got+1 end task.wait(0.02) end
            wepLbl.Text="✅ Got "..got.."/"..#AW.." weapons!"
        end)
    end) y=y+34

    Btn(C,"🛑 Stop Persisting",y,Color3.fromRGB(40,10,10),function()
        weaponPersistActive=false persistWeapons={}
        wepLbl.Text="Persistence stopped"
    end) y=y+34

    -- Search box
    local searchBox2=Instance.new("TextBox",C)
    searchBox2.Size=UDim2.new(1,-4,0,28) searchBox2.Position=UDim2.new(0,2,0,y)
    searchBox2.BackgroundColor3=Color3.fromRGB(20,20,40)
    searchBox2.Text="" searchBox2.PlaceholderText="Search weapons..."
    searchBox2.TextColor3=Color3.fromRGB(220,220,255) searchBox2.TextSize=11
    searchBox2.Font=Enum.Font.Gotham searchBox2.BorderSizePixel=0 searchBox2.ZIndex=11
    Instance.new("UICorner",searchBox2).CornerRadius=UDim.new(0,6)
    y=y+32

    -- Scrolling weapon list
    local wepFrame=Instance.new("ScrollingFrame",C)
    wepFrame.Size=UDim2.new(1,-4,0,500)
    wepFrame.Position=UDim2.new(0,2,0,y)
    wepFrame.BackgroundColor3=Color3.fromRGB(10,10,22)
    wepFrame.BackgroundTransparency=0.1
    wepFrame.BorderSizePixel=0 wepFrame.ScrollBarThickness=4
    wepFrame.ScrollBarImageColor3=Color3.fromRGB(255,200,60)
    wepFrame.ZIndex=11
    Instance.new("UICorner",wepFrame).CornerRadius=UDim.new(0,8)

    local wBtns={}
    local function buildWepList(filter)
        for _,b in ipairs(wBtns) do pcall(function() b:Destroy() end) end
        wBtns={}
        local wy=4
        for _,name in ipairs(AW) do
            if not filter or name:lower():find(filter:lower()) then
                local row=Instance.new("TextButton",wepFrame)
                row.Size=UDim2.new(1,-6,0,28) row.Position=UDim2.new(0,3,0,wy)
                row.BackgroundColor3=Color3.fromRGB(14,14,28) row.BorderSizePixel=0 row.ZIndex=12
                row.Text="🔫 "..name row.TextColor3=Color3.fromRGB(200,200,255)
                row.TextSize=11 row.Font=Enum.Font.GothamBold
                row.TextXAlignment=Enum.TextXAlignment.Left
                Instance.new("UICorner",row).CornerRadius=UDim.new(0,5)
                local n=name
                row.MouseButton1Click:Connect(function()
                    giveWeapon(n)
                    row.BackgroundColor3=Color3.fromRGB(10,30,10)
                    task.delay(1.5,function() pcall(function() row.BackgroundColor3=Color3.fromRGB(14,14,28) end) end)
                end)
                table.insert(wBtns,row)
                wy=wy+30
            end
        end
        wepFrame.CanvasSize=UDim2.new(0,0,0,wy+4)
    end

    buildWepList(nil)
    searchBox2:GetPropertyChangedSignal("Text"):Connect(function()
        buildWepList(searchBox2.Text~="" and searchBox2.Text or nil)
    end)

    y=y+504

    -- Promo Codes
    Section(C,"🎁 Promo Codes",y) y=y+22
    local CODES={{"warfund","💰 100k Cash"},{"nukenation","⚡ 60min Boost"},{"seasonrush","⭐ 1000 SP"},{"betterperformance","💎 50 Gems"},{"frontlines","📦 Rare Pack"},{"bugfixesyay","🏆 Golden Crate"},{"seasonpush","⭐ 1000 SP"},{"loadsofdiamonds","💎 50 Gems"},{"summertime","⚡ 120min Boost"},{"heatofthemoment","⭐ 500 SP"}}
    local _,codeLbl=InfoBox(C,"Click code to try redeem",y,20) y=y+24
    for _,cd in ipairs(CODES) do
        local row=Instance.new("Frame",C)
        row.Size=UDim2.new(1,0,0,28) row.Position=UDim2.new(0,0,0,y)
        row.BackgroundColor3=Color3.fromRGB(12,12,24) row.BorderSizePixel=0 row.ZIndex=10
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,5)
        local cl=Instance.new("TextLabel",row)
        cl.Size=UDim2.new(0.45,0,1,0) cl.Position=UDim2.new(0,6,0,0)
        cl.BackgroundTransparency=1 cl.Text=cd[1]
        cl.TextColor3=Color3.fromRGB(255,200,60) cl.TextSize=11
        cl.Font=Enum.Font.GothamBold cl.TextXAlignment=Enum.TextXAlignment.Left cl.ZIndex=11
        local dl=Instance.new("TextLabel",row)
        dl.Size=UDim2.new(0.5,0,1,0) dl.Position=UDim2.new(0.48,0,0,0)
        dl.BackgroundTransparency=1 dl.Text=cd[2]
        dl.TextColor3=Color3.fromRGB(160,200,160) dl.TextSize=10
        dl.Font=Enum.Font.Gotham dl.TextXAlignment=Enum.TextXAlignment.Left dl.ZIndex=11
        local btn=Instance.new("TextButton",row)
        btn.Size=UDim2.new(1,0,1,0) btn.BackgroundTransparency=1 btn.Text="" btn.ZIndex=12
        local c=cd[1]
        btn.MouseButton1Click:Connect(function()
            local rs=game:GetService("ReplicatedStorage")
            for _,v in ipairs(rs:GetDescendants()) do
                if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                    local ln=v.Name:lower()
                    if ln:find("code") or ln:find("promo") or ln:find("redeem") then
                        pcall(function() if v:IsA("RemoteEvent") then v:FireServer(c) else v:InvokeServer(c) end end)
                    end
                end
            end
            codeLbl.Text="Tried: "..c
            row.BackgroundColor3=Color3.fromRGB(10,30,10)
            task.delay(2,function() pcall(function() row.BackgroundColor3=Color3.fromRGB(12,12,24) end) end)
        end)
        y=y+30
    end

    C.CanvasSize=UDim2.new(0,0,0,y+20)
end

-- ═══  VEHICLES TAB  ══════════════════════════════════════
-- ============================================================
do
    local C=VehicleTab C.CanvasSize=UDim2.new(0,0,0,800)
    local y=4
    Section(C,"🚗 Vehicles",y) y=y+22
    InfoBox(C,"Uses VehicleService:LoadVehicle (confirmed working). Check vehicle inventory after.",y,28) y=y+32
    local _,vehLbl=InfoBox(C,"Click any vehicle to load it",y,20) y=y+24

    -- All confirmed vehicles packed into flat list
    local V={"F16","GoldenF16","F16V","F22","GoldenF22","F35","StealthF35","GoldF35","F35EMP","F35Nuke","F14","GoldenF14","StealthF14","F15","SuperF15","F18","SuperF18","F111","SuperF111","Blackbird","Master_Blackbird","DarkstarMK2","SuperDarkstarMK2","Falken","GoldFalken","CFA44","SU47","SU57","Master_SU57","Mig29","GoldMig29","J20","Master_J20","FC31","EuroFighter","SuperEuroFighter","YF23","GoldYF23","Raptor","SuperRaptor","Rafale","NGAD","XB70","SuperXB70","FX1","F5","ATC_Silkfire","Darkstar","Spitfire","SpitfireFlame","SpitfireGold","Warplane","JasGripen","Invictus","PhantomJet","SM27","AT6","B1","B2","B21Raider","Apache","Ironhawk","SuperIronhawk","Stallion","MI28","Master_MI28","MI35","GoldenMI35","KA52","GoldenKA52","RAH66","ReconHeli","ReconHeli2","SuperReconHeli2","GhostWind","Master_GhostWind","Chinook","Chinook_CH47","AttackHelicopter","UFO","Mothership","ZeplinX","NukeZeplinX","NovaHeli","SuperNovaHeli","Blackhawk","Miron","AC130","GoldAC130","AC119","GoldAC119","B29","B52","SuperB52","B36","NukeB36","BV238","C17","Astrum","Greyhound","Pelican","WarShrike","Skyhammer","DiveBomber","V22","TU22M","F117","Master_F117","TU95","SuperTU95","ME323","SuperME323","B-17","SkyReaper","Phalcon","Canberra","SeaHawk","Mig31","Mig31_Flames","AbramTank","AbramTankX","T90","T90M","Leopard","Maus","TigerTank","KingTiger","Challenger","PL01","GoldenPL01","Phanter","SuperPhanter","Overlord","Master_Overlord","Hellstorm","Master_Hellstorm","Warmaul","Master_Warmaul","Annihilator","Master_Annihilator","RailgunTank","NukeRailgunTank","SeaTank","Volk","SuperVolk","Akrep","AkrepSuper","QN506","Stormer","Striker","SuperStriker","ArmoredJeep","Humvee","DuneBuggy","SandHyena","GrappleATV","Motorbike","HoverBike","Artillery","Katyusha","TOS1","SuperTOS1","MZKT","Himars","Terrorbyte","PyroTank","GoldPyroTank","Demolisher","Jagdpanther","Halftrack","Halftrack2","SuperHalftrack","M10Booker","Bradley","K9Demon","BattleTank","STankRailgun","STankMissiles","STankMinigun","Battleship","NorthCarolina","Yamato","Carrier","CarrierNew","Kusnetsov","Destroyer","MissileBoat","Boat","GunBoat","Hovercraft","Submarine","NewSub","SSBN","NukeSSBN","Whale","JSAtago","Zumwalt","ZubrHovercraft","Warship1","SuperWarship","LHovercraft","CorsairCraft","PatriaGold","StrikeMech","SuperStrikeMech","MechWalker","NukeMechWalker","PlatinumMech","LE_CommanderXTank","LE_ImperialTank","WerewolfTank","LE_BattleTank","TeslaTank","HauntedTank","ShoppingCart","Driller","AntiNukeJeep"}

    local function giveVehicle(vehicleId)
        local rs=game:GetService("ReplicatedStorage")
        local ok,knit=pcall(function() return require(rs.Packages.Knit) end)
        if not ok then vehLbl.Text="⚠ Knit error" return false end
        local ok2,vs=pcall(function() return knit.GetService("VehicleService") end)
        if not ok2 then vehLbl.Text="⚠ VehicleService error" return false end
        local ok3,result=pcall(function() return vs:LoadVehicle(vehicleId) end)
        if ok3 and result then
            vehLbl.Text="✅ Loaded: "..vehicleId
            return true
        end
        vehLbl.Text="⚠ Tried: "..vehicleId
        return false
    end

    local function maxUpgradeVehicle(vehicleId)
        task.spawn(function()
            local rs=game:GetService("ReplicatedStorage")
            local ok,knit=pcall(function() return require(rs.Packages.Knit) end)
            if not ok then return end
            local ok2,vs=pcall(function() return knit.GetService("VehicleService") end)
            if not ok2 then return end
            for _,stat in ipairs({"Damage","Health","Speed"}) do
                for i=1,18 do
                    pcall(function() vs:BuyUpgrade(vehicleId,stat,i) end)
                    task.wait(0.03)
                end
            end
            pcall(function()
                local ms=knit.GetService("MasteryService")
                ms:AddXP(vehicleId,9999999)
            end)
            vehLbl.Text="✅ Max upgraded: "..vehicleId
        end)
    end

    -- Get All + Max All buttons
    Btn(C,"🚗 LOAD ALL VEHICLES",y,Color3.fromRGB(20,20,60),function()
        task.spawn(function()
            local got=0
            for _,vid in ipairs(V) do
                if giveVehicle(vid) then got=got+1 end
                task.wait(0.1)
            end
            vehLbl.Text="Loaded "..got.."/"..#V.." — check inventory!"
        end)
    end) y=y+34

    Btn(C,"⚡ MAX UPGRADE ALL",y,Color3.fromRGB(40,20,10),function()
        task.spawn(function()
            for _,vid in ipairs(V) do
                maxUpgradeVehicle(vid)
                task.wait(1.8)
            end
            vehLbl.Text="Max upgrade done!"
        end)
    end) y=y+34

    -- Search box
    local _,searchLbl=InfoBox(C,"Search vehicles below:",y,20) y=y+24
    local searchBox=Instance.new("TextBox",C)
    searchBox.Size=UDim2.new(1,-4,0,28) searchBox.Position=UDim2.new(0,2,0,y)
    searchBox.BackgroundColor3=Color3.fromRGB(20,20,40)
    searchBox.Text="" searchBox.PlaceholderText="Type vehicle name..."
    searchBox.TextColor3=Color3.fromRGB(220,220,255) searchBox.TextSize=11
    searchBox.Font=Enum.Font.Gotham searchBox.BorderSizePixel=0 searchBox.ZIndex=11
    Instance.new("UICorner",searchBox).CornerRadius=UDim.new(0,6)
    y=y+32

    -- Scrolling vehicle list
    local listFrame=Instance.new("ScrollingFrame",C)
    listFrame.Size=UDim2.new(1,-4,0,450)
    listFrame.Position=UDim2.new(0,2,0,y)
    listFrame.BackgroundColor3=Color3.fromRGB(10,10,22)
    listFrame.BackgroundTransparency=0.1
    listFrame.BorderSizePixel=0
    listFrame.ScrollBarThickness=4
    listFrame.ScrollBarImageColor3=Color3.fromRGB(255,200,60)
    listFrame.ZIndex=11
    Instance.new("UICorner",listFrame).CornerRadius=UDim.new(0,8)

    local vButtons={}
    local function buildVehicleList(filter)
        for _,b in ipairs(vButtons) do pcall(function() b:Destroy() end) end
        vButtons={}
        local vy=4
        for _,vid in ipairs(V) do
            if not filter or vid:lower():find(filter:lower()) then
                local row=Instance.new("Frame",listFrame)
                row.Size=UDim2.new(1,-6,0,28) row.Position=UDim2.new(0,3,0,vy)
                row.BackgroundColor3=Color3.fromRGB(14,14,28) row.BorderSizePixel=0 row.ZIndex=12
                Instance.new("UICorner",row).CornerRadius=UDim.new(0,5)
                local nl=Instance.new("TextLabel",row)
                nl.Size=UDim2.new(0.55,0,1,0) nl.Position=UDim2.new(0,6,0,0)
                nl.BackgroundTransparency=1 nl.Text=vid
                nl.TextColor3=Color3.fromRGB(200,200,255) nl.TextSize=10
                nl.Font=Enum.Font.Gotham nl.TextXAlignment=Enum.TextXAlignment.Left
                nl.TextTruncate=Enum.TextTruncate.AtEnd nl.ZIndex=13
                local gb=Instance.new("TextButton",row)
                gb.Size=UDim2.new(0.22,0,0,22) gb.Position=UDim2.new(0.56,0,0,3)
                gb.BackgroundColor3=Color3.fromRGB(10,30,10) gb.Text="Load"
                gb.TextColor3=Color3.fromRGB(150,255,150) gb.TextSize=9
                gb.Font=Enum.Font.GothamBold gb.BorderSizePixel=0 gb.ZIndex=13
                Instance.new("UICorner",gb).CornerRadius=UDim.new(0,4)
                local ub=Instance.new("TextButton",row)
                ub.Size=UDim2.new(0.2,0,0,22) ub.Position=UDim2.new(0.79,2,0,3)
                ub.BackgroundColor3=Color3.fromRGB(40,20,5) ub.Text="⚡Max"
                ub.TextColor3=Color3.fromRGB(255,180,80) ub.TextSize=9
                ub.Font=Enum.Font.GothamBold ub.BorderSizePixel=0 ub.ZIndex=13
                Instance.new("UICorner",ub).CornerRadius=UDim.new(0,4)
                local v=vid
                gb.MouseButton1Click:Connect(function()
                    giveVehicle(v)
                    gb.BackgroundColor3=Color3.fromRGB(10,40,10)
                    task.delay(2,function() pcall(function() gb.BackgroundColor3=Color3.fromRGB(10,30,10) end) end)
                end)
                ub.MouseButton1Click:Connect(function()
                    maxUpgradeVehicle(v)
                    ub.BackgroundColor3=Color3.fromRGB(50,30,5)
                    task.delay(3,function() pcall(function() ub.BackgroundColor3=Color3.fromRGB(40,20,5) end) end)
                end)
                table.insert(vButtons,row)
                vy=vy+30
            end
        end
        listFrame.CanvasSize=UDim2.new(0,0,0,vy+4)
    end

    buildVehicleList(nil)
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        buildVehicleList(searchBox.Text~="" and searchBox.Text or nil)
    end)

    y=y+454
    C.CanvasSize=UDim2.new(0,0,0,y+20)
end

-- ═══  TELEPORT TAB  ══════════════════════════════════════
-- ============================================================
do
    local C=TeleTab C.CanvasSize=UDim2.new(0,0,0,700)
    local y=4

    Section(C,"🌀 Map Teleports",y) y=y+22
    InfoBox(C,"All confirmed MT map locations from live coordinate scan.",y,26) y=y+30
    local _,teleLbl=InfoBox(C,"Click any location to teleport",y,20) y=y+24

    -- All confirmed MT locations from live scan 2026-03-20
    local LOCATIONS = {
        -- Main areas
        {"🏭 Factory",          Vector3.new(243.96,  132.62,  207.98)},
        {"🏦 Bank",             Vector3.new(-285.93, 120.53,  -358.42)},
        {"🏙 City",             Vector3.new(21.36,   119.81,  38.00)},
        {"⚔ B (Base)",         Vector3.new(-431.39, 119.65,  3024.29)},
        -- Fortresses
        {"🏰 CityFortress",     Vector3.new(275.82,  116.50,  1091.27)},
        {"⛰ MountainFortress", Vector3.new(955.84,  116.50,  -720.26)},
        {"🌊 RiverFortress",   Vector3.new(-1142.06,119.29,  289.58)},
        {"🌲 ForestFortress",  Vector3.new(-505.04, 116.50,  -1290.77)},
        -- Islands & Oil Rigs
        {"🏝 NorthIsland",     Vector3.new(-441.75, 121.38,  -2113.5)},
        {"🏝 WestIsland",      Vector3.new(-2614.21,117.62,  2151.48)},
        {"🛢 EastOilRig",      Vector3.new(3179.27, 209.07,  -445.02)},
        {"🛢 SouthOilRig",     Vector3.new(1216.20, 209.07,  3350.69)},
        -- Other
        {"⛰ Summit",           Vector3.new(-925.54, 300.77,  1679.69)},
        {"💀 Deathmatch",       Vector3.new(7404.72, 118.20,  0)},
        {"🏭 Factory2",         Vector3.new(379.59,  123.31,  347.13)},
    }

    local function doTeleport(pos)
        local hrp = getHRP()
        if not hrp then teleLbl.Text="⚠ No character" return end
        local lp = game.Players.LocalPlayer

        -- Method 1: Set SpawnCF attribute (confirmed MT spawn system)
        -- This tells MT where to spawn you on next respawn
        pcall(function()
            lp:SetAttribute("SpawnCF", CFrame.new(pos + Vector3.new(0,4,0)))
        end)

        -- Method 2: Direct position set with repeated attempts
        local hum = getHum()
        if hum then pcall(function() hum.WalkSpeed=0 hum.JumpPower=0 end) end

        task.spawn(function()
            local targetCF = CFrame.new(pos + Vector3.new(0,4,0))
            for i=1,10 do
                pcall(function() hrp.Anchored=true hrp.CFrame=targetCF end)
                pcall(function() lp.Character:PivotTo(targetCF) end)
                task.wait(0.05)
            end
            hrp.Anchored=false
            local s=S.speedOn and S.walkSpeed or 16
            local j=S.jumpOn and S.jumpPower or 50
            if hum then pcall(function() hum.WalkSpeed=s hum.JumpPower=j end) end
        end)
    end

    -- Build 2-column grid
    for i=1,#LOCATIONS,2 do
        local row=Instance.new("Frame",C)
        row.Size=UDim2.new(1,0,0,34)
        row.Position=UDim2.new(0,0,0,y)
        row.BackgroundTransparency=1 row.ZIndex=10

        for col=0,1 do
            local loc=LOCATIONS[i+col]
            if loc then
                local name=loc[1] local pos=loc[2]
                local b=Instance.new("TextButton",row)
                b.Size=UDim2.new(0.49,0,0,30)
                b.Position=UDim2.new(col*0.5,col==0 and 2 or 4,0,2)
                b.BackgroundColor3=Color3.fromRGB(14,14,30)
                b.Text=name
                b.TextColor3=Color3.fromRGB(180,200,255)
                b.TextSize=10 b.Font=Enum.Font.GothamBold
                b.BorderSizePixel=0 b.ZIndex=11
                b.TextTruncate=Enum.TextTruncate.AtEnd
                Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
                local p=pos
                local n=name
                b.MouseButton1Click:Connect(function()
                    doTeleport(p)
                    teleLbl.Text="→ "..n
                    b.BackgroundColor3=Color3.fromRGB(10,30,10)
                    task.delay(1.5,function()
                        pcall(function() b.BackgroundColor3=Color3.fromRGB(14,14,30) end)
                    end)
                end)
            end
        end
        y=y+36
    end

    -- Custom coordinate teleport
    Section(C,"📍 Custom Teleport",y) y=y+22
    InfoBox(C,"Enter X Y Z coordinates to teleport anywhere.",y,26) y=y+30

    local coordInputs={}
    local labels={"X","Y","Z"}
    local defaults={0,100,0}
    local coordRow=Instance.new("Frame",C)
    coordRow.Size=UDim2.new(1,0,0,34)
    coordRow.Position=UDim2.new(0,0,0,y)
    coordRow.BackgroundTransparency=1 coordRow.ZIndex=10
    for i=1,3 do
        local lbl=Instance.new("TextLabel",coordRow)
        lbl.Size=UDim2.new(0,16,0,28)
        lbl.Position=UDim2.new((i-1)*0.33,2,0,3)
        lbl.BackgroundTransparency=1
        lbl.Text=labels[i] lbl.TextColor3=Color3.fromRGB(180,180,180)
        lbl.TextSize=10 lbl.Font=Enum.Font.GothamBold lbl.ZIndex=11
        local inp=Instance.new("TextBox",coordRow)
        inp.Size=UDim2.new(0.3,0,0,28)
        inp.Position=UDim2.new((i-1)*0.33,18,0,3)
        inp.BackgroundColor3=Color3.fromRGB(20,20,40)
        inp.Text=tostring(defaults[i])
        inp.TextColor3=Color3.fromRGB(220,220,255) inp.TextSize=10
        inp.Font=Enum.Font.Gotham inp.BorderSizePixel=0 inp.ZIndex=11
        Instance.new("UICorner",inp).CornerRadius=UDim.new(0,5)
        table.insert(coordInputs,inp)
    end
    y=y+38

    Btn(C,"🌀 Teleport to Coords",y,Color3.fromRGB(14,14,40),function()
        local x=tonumber(coordInputs[1].Text) or 0
        local yv=tonumber(coordInputs[2].Text) or 100
        local z=tonumber(coordInputs[3].Text) or 0
        doTeleport(Vector3.new(x,yv,z))
        teleLbl.Text=string.format("→ %.0f, %.0f, %.0f",x,yv,z)
    end) y=y+34

    -- Teleport to tycoon
    Section(C,"🏭 Player Tycoons",y) y=y+22
    InfoBox(C,"Teleport directly to any player's tycoon base.",y,26) y=y+30

    local function buildTycoonList()
        local pt=workspace:FindFirstChild("PlayerTycoons")
        if not pt then teleLbl.Text="⚠ No PlayerTycoons found" return end
        for _,tycoon in ipairs(pt:GetChildren()) do
            local name=tycoon.Name
            local b=Instance.new("TextButton",C)
            b.Size=UDim2.new(1,-4,0,28)
            b.Position=UDim2.new(0,2,0,y)
            b.BackgroundColor3=Color3.fromRGB(14,14,30)
            b.Text="🏭 "..name.."'s Tycoon"
            b.TextColor3=Color3.fromRGB(200,200,255) b.TextSize=11
            b.Font=Enum.Font.GothamBold b.BorderSizePixel=0 b.ZIndex=11
            Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
            local t=tycoon
            b.MouseButton1Click:Connect(function()
                local hrp=getHRP()
                if not hrp then return end
                -- Find a spawn part in the tycoon
                local spawnPart=t:FindFirstChild("Flag") or
                                t:FindFirstChild("SpawnPart") or
                                t:FindFirstChild("Base") or
                                t.PrimaryPart
                if spawnPart then
                    hrp.Anchored=true
                    hrp.CFrame=spawnPart.CFrame*CFrame.new(0,6,0)
                    task.wait(0.05) hrp.Anchored=false
                    pcall(function() LocalPlayer.Character:PivotTo(spawnPart.CFrame*CFrame.new(0,6,0)) end)
                    teleLbl.Text="→ "..name.."'s tycoon"
                end
            end)
            y=y+32
        end
    end

    buildTycoonList()
    Btn(C,"🔄 Refresh Tycoons",y,Color3.fromRGB(12,12,30),function()
        buildTycoonList()
    end) y=y+34

    C.CanvasSize=UDim2.new(0,0,0,y+20)
end

-- ═══  SETTINGS TAB  ══════════════════════════════════════
-- ============================================================
do
    local C=SettingsTab C.CanvasSize=UDim2.new(0,0,0,820)
    local y=4

    -- Credit
    Section(C,"☀ GasBaby 233  v3.1",y) y=y+22
    local _,creditL=InfoBox(C,"Made by GasBaby233 | Military Tycoon | Wave Executor",y,28) y=y+32
    creditL.TextColor3=Color3.fromRGB(255,200,60)

    -- Server info
    Section(C,"🌐 Server Info",y) y=y+22
    local _,serverL=InfoBox(C,"Loading...",y,60) y=y+64
    task.spawn(function()
        task.wait(2)
        if not serverL or not serverL.Parent then return end
        local info = ""
        pcall(function()
            local gs=game:GetService("GamePassService") or {}
            info="Game: "..tostring(game.Name).."\n"
            info=info.."Place ID: "..tostring(game.PlaceId).."\n"
            info=info.."Job ID: "..tostring(game.JobId):sub(1,16).."...\n"
            info=info.."Players: "..tostring(#Players:GetPlayers()).."/"..tostring(Players.MaxPlayers)
        end)
        pcall(function() serverL.Text=info end)
    end)

    -- Rejoin / hop
    Section(C,"🔄 Server Actions",y) y=y+22
    Btn(C,"🔄 Rejoin Server",y,Color3.fromRGB(18,18,40),function()
        pcall(function()
            game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
        end)
    end) y=y+34
    Btn(C,"🎲 Hop to New Server",y,Color3.fromRGB(22,18,40),function()
        pcall(function()
            local ts=game:GetService("TeleportService")
            ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end) y=y+34

    -- Background presets
    Section(C,"🎨 Background Preset",y) y=y+22
    local bgPresets={"Sun","Zombies","Cars","RGB","Solid"}
    local _,bgBtn,getBG=Dropdown(C,"Preset:",bgPresets,y,function(v)
        S.bgPreset=v
        setPresetVisible(v)
    end)
    y=y+34
    -- Solid color picker
    local _,solidInfoL=InfoBox(C,"Solid color — R/G/B sliders below",y,20) y=y+24
    Slider(C,"Red",0,255,15,y,function(v)
        local c=solidBg.BackgroundColor3
        solidBg.BackgroundColor3=Color3.fromRGB(v,c.G*255,c.B*255)
    end) y=y+44
    Slider(C,"Green",0,255,15,y,function(v)
        local c=solidBg.BackgroundColor3
        solidBg.BackgroundColor3=Color3.fromRGB(c.R*255,v,c.B*255)
    end) y=y+44
    Slider(C,"Blue",0,255,35,y,function(v)
        local c=solidBg.BackgroundColor3
        solidBg.BackgroundColor3=Color3.fromRGB(c.R*255,c.G*255,v)
    end) y=y+44

    -- Config save/load
    Section(C,"💾 Config Profiles",y) y=y+22
    InfoBox(C,"Configs persist while script is loaded. Give each one a name.",y,26) y=y+30

    local _,cfgNameLbl=InfoBox(C,"Profile name: Default",y,22) y=y+26
    local cfgNames={"Default","PvP","Farm","Chill"}
    local _,cfgBtn,getCfgName=Dropdown(C,"Profile:",cfgNames,y,function(v)
        cfgNameLbl.Text="Profile: "..v
    end)
    y=y+34
    Btn(C,"💾 Save Config",y,Color3.fromRGB(14,35,14),function()
        local name=getCfgName()
        saveConfig(name)
        cfgNameLbl.Text="✅ Saved: "..name
    end) y=y+34
    Btn(C,"📂 Load Config",y,Color3.fromRGB(14,14,35),function()
        local name=getCfgName()
        local ok=loadConfig(name)
        cfgNameLbl.Text=ok and ("✅ Loaded: "..name) or ("⚠ "..name.." not found")
    end) y=y+34
    Btn(C,"🔍 List Saved Configs",y,Color3.fromRGB(18,18,18),function()
        local names=listConfigs()
        cfgNameLbl.Text=#names>0 and table.concat(names,", ") or "No configs saved yet"
    end) y=y+34

    -- GUI key
    Section(C,"🕵 Remote Spy",y) y=y+22
    InfoBox(C,"Watches all MT remotes in real time. Logs to F9 console. Ignores visual spam.",y,30) y=y+34
    local _,spyLbl=InfoBox(C,"Spy: OFF",y,20) y=y+24
    local spyConns={}
    Toggle(C,"🕵 Enable Remote Spy",y,function(v)
        -- Clear old connections
        for _,c in ipairs(spyConns) do pcall(function() c:Disconnect() end) end
        spyConns={}
        if v then
            local ignore={
                "SetLookAngles","VisualizeBullet","VisualizeMuzzle",
                "PlayAudio","PlantedGunClientEffects","ClientPing"
            }
            local function shouldIgnore(name)
                for _,n in ipairs(ignore) do if name==n then return true end end
                return false
            end
            local count=0
            for _,rem in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
                if rem:IsA("RemoteEvent") and not shouldIgnore(rem.Name) then
                    local n=rem.Name
                    local c=rem.OnClientEvent:Connect(function(...)
                        local args={...}
                        local argStr=""
                        for i,a in ipairs(args) do
                            argStr=argStr..tostring(a)
                            if i<#args then argStr=argStr..", " end
                        end
                        print("[SPY] "..n.." ← ("..argStr..")")
                    end)
                    table.insert(spyConns,c)
                    count=count+1
                end
            end
            spyLbl.Text="🕵 Watching "..count.." remotes — check F9"
            StatusLbl.Text="Remote spy ON — open F9 console"
        else
            spyLbl.Text="Spy: OFF"
        end
    end) y=y+36

    Section(C,"⌨ GUI Toggle Key",y) y=y+22
    local _,keyLbl=InfoBox(C,"Current key: K",y,22) y=y+26
    Btn(C,"🔑 Rebind Key (press any key)",y,Color3.fromRGB(18,18,40),function()
        keyLbl.Text="Press any key..."
        local conn conn=UserInputService.InputBegan:Connect(function(inp,gp)
            if gp then return end
            if inp.UserInputType==Enum.UserInputType.Keyboard then
                S.guiKey=inp.KeyCode
                keyLbl.Text="Key: "..tostring(inp.KeyCode):gsub("Enum.KeyCode.","")
                conn:Disconnect()
            end
        end)
    end) y=y+34

    -- ── Developer Tools ──────────────────────────────────────
    Section(C,"🔧 Developer Tools",y) y=y+22
    InfoBox(C,"Tools to explore the game and find exploitable remotes/scripts.",y,26) y=y+30

    -- Dex Explorer
    local _,dexLbl=InfoBox(C,"Dex: not loaded",y,20) y=y+24
    Btn(C,"🔍 Load Dex Explorer",y,Color3.fromRGB(12,35,12),function()
        dexLbl.Text="Loading Dex..."
        task.spawn(function()
            local ok,err=pcall(function()
                local dex=game:HttpGet("https://raw.githubusercontent.com/LorekeeperZinnia/Dex/master/Dex3.lua")
                loadstring(dex)()
            end)
            if ok then
                dexLbl.Text="✅ Dex loaded — check your screen"
            else
                -- Try backup source
                local ok2,err2=pcall(function()
                    loadstring(game:HttpGet("https://raw.githubusercontent.com/peyton2465/Dex/master/Dex3.lua"))()
                end)
                if ok2 then
                    dexLbl.Text="✅ Dex loaded (backup)"
                else
                    dexLbl.Text="⚠ Failed — try manual load"
                    print("[GB233] Dex load error: "..tostring(err))
                end
            end
        end)
    end) y=y+34

    -- Infinite Yield
    local _,iyLbl=InfoBox(C,"IY: not loaded",y,20) y=y+24
    Btn(C,"⚡ Load Infinite Yield",y,Color3.fromRGB(35,12,12),function()
        iyLbl.Text="Loading IY..."
        task.spawn(function()
            local ok,err=pcall(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
            end)
            if ok then
                iyLbl.Text="✅ IY loaded — type cmds in chat"
            else
                iyLbl.Text="⚠ Failed: "..tostring(err):sub(1,40)
            end
        end)
    end) y=y+34

    -- Remote Scanner (scans all remotes and prints to console)
    Btn(C,"📡 Full Remote Scan (F9)",y,Color3.fromRGB(18,18,40),function()
        task.spawn(function()
            print("╔══ GB233 FULL REMOTE SCAN ══╗")
            local rs=game:GetService("ReplicatedStorage")
            local count=0
            for _,v in ipairs(rs:GetDescendants()) do
                if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                    print("  ["..v.ClassName.."] "..v:GetFullName())
                    count=count+1
                end
            end
            print("╚══ Total: "..count.." remotes ══╝")
            StatusLbl.Text="Remote scan done — "..count.." found. Check F9"
        end)
    end) y=y+34

    -- Script Scanner (finds LocalScripts with FireServer calls)
    Btn(C,"📜 Scan Scripts for FireServer",y,Color3.fromRGB(18,18,40),function()
        task.spawn(function()
            print("╔══ GB233 SCRIPT SCAN ══╗")
            local count=0
            for _,v in ipairs(game.Players.LocalPlayer:GetDescendants()) do
                if v:IsA("LocalScript") or v:IsA("ModuleScript") then
                    local ok,src=pcall(function() return v.Source end)
                    if ok and src and src:find("FireServer") then
                        print("  "..v:GetFullName())
                        -- Print the FireServer lines
                        for line in src:gmatch("[^\n]+") do
                            if line:find("FireServer") then
                                print("    → "..line:match("^%s*(.-)%s*$"))
                            end
                        end
                        count=count+1
                    end
                end
            end
            print("╚══ Scripts with FireServer: "..count.." ══╝")
            StatusLbl.Text="Script scan done — "..count.." scripts found. Check F9"
        end)
    end) y=y+34

    -- Money finder
    Btn(C,"💰 Find Money Values",y,Color3.fromRGB(18,35,12),function()
        task.spawn(function()
            print("╔══ GB233 MONEY SCAN ══╗")
            local lp=game.Players.LocalPlayer
            local found=0
            for _,v in ipairs(lp:GetDescendants()) do
                if v:IsA("IntValue") or v:IsA("NumberValue") then
                    local ln=v.Name:lower()
                    if ln:find("money") or ln:find("cash") or ln:find("bank")
                    or ln:find("coin") or ln:find("dollar") or ln:find("balance")
                    or ln:find("currency") or ln:find("credit") or v.Value > 100 then
                        print("  "..v:GetFullName().." = "..tostring(v.Value))
                        found=found+1
                    end
                end
            end
            print("╚══ Money values found: "..found.." ══╝")
            StatusLbl.Text="Money scan done — check F9"
        end)
    end) y=y+34

    C.CanvasSize=UDim2.new(0,0,0,y+20)
end

-- ============================================================
-- DRAG
-- ============================================================
local dragging,dragStart,startPos
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
local minimized=false
CloseBtn.MouseButton1Click:Connect(function()
    for _,o in pairs(_G.GB233ESP) do
        for _,d in pairs(o) do pcall(function() d:Remove() end) end
    end
    if _G.GB233ESP_NPC then
        for _,o in pairs(_G.GB233ESP_NPC) do
            for _,d in pairs(o) do pcall(function() d:Remove() end) end
        end
        _G.GB233ESP_NPC=nil
    end
    pcall(function() fovCircle:Remove() end)
    disableFly() disableGod() stopMoneyDupe() stopFreeSpins()
    SG:Destroy() _G.GB233Gui=nil
end)
MinBtn.MouseButton1Click:Connect(function()
    minimized=not minimized
    ContentArea.Visible=not minimized
    TabRow1.Visible=not minimized TabRow2.Visible=not minimized
    TabSep.Visible=not minimized StatusBar.Visible=not minimized
    WIN.Size=minimized and UDim2.new(0,320,0,46) or UDim2.new(0,660,0,560)
    MinBtn.Text=minimized and "□" or "–"
end)

-- ============================================================
-- K TOGGLE
-- ============================================================
UserInputService.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.UserInputType~=Enum.UserInputType.Keyboard then return end
    if i.KeyCode==S.guiKey then S.guiOpen=not S.guiOpen WIN.Visible=S.guiOpen end
end)

-- ============================================================
-- ESP RENDER ENGINE  — must be defined BEFORE main loop
-- ============================================================
local function ensureESP(p)
    if p==LocalPlayer then return end
    if _G.GB233ESP[p] then return end
    local o={}
    -- Safe wrapper: if Drawing fails just make a no-op table
    local function safeDraw(t2, props)
        if not hasDraw then
            return setmetatable({},{__newindex=function()end,__index=function()return nil end})
        end
        local ok2,obj=pcall(Drawing.new,t2)
        if not ok2 then
            return setmetatable({},{__newindex=function()end,__index=function()return nil end})
        end
        for k,v2 in pairs(props or {}) do pcall(function() obj[k]=v2 end) end
        return obj
    end
    for _,side in ipairs({"t","b","l","r"}) do
        o["bx_"..side]=safeDraw("Line",{Thickness=1.5,Color=S.espColor,Visible=false,ZIndex=5})
    end
    o.name  =safeDraw("Text",{Text="",Size=13,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=S.espColor,Visible=false,ZIndex=6})
    o.dist  =safeDraw("Text",{Text="",Size=11,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=S.espColor,Visible=false,ZIndex=6})
    o.tracer=safeDraw("Line",{Thickness=1,Color=S.espColor,Visible=false,ZIndex=4})
    o.hpBg  =safeDraw("Line",{Thickness=4,Color=Color3.fromRGB(40,40,40),Visible=false,ZIndex=5})
    o.hpBar =safeDraw("Line",{Thickness=4,Color=Color3.fromRGB(60,255,80),Visible=false,ZIndex=6})
    o.hpText=safeDraw("Text",{Text="",Size=10,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=Color3.fromRGB(255,255,255),Visible=false,ZIndex=7})
    _G.GB233ESP[p]=o
end
local function clearESP(p)
    local o=_G.GB233ESP[p] if not o then return end
    for _,v in pairs(o) do pcall(function() v:Remove() end) end
    _G.GB233ESP[p]=nil
end
for _,p in ipairs(Players:GetPlayers()) do ensureESP(p) end
Players.PlayerAdded:Connect(ensureESP)
Players.PlayerRemoving:Connect(clearESP)

-- FOV Circle — also before main loop
local fovCircle=NewDraw("Circle",{Thickness=1.5,Color=Color3.fromRGB(255,200,60),
    Filled=false,Visible=false,ZIndex=7,NumSides=60,Radius=120})
-- ============================================================
-- MINIMAP
-- ============================================================
S.minimapOn=false
local MM={size=180,range=400,x=0,y=0,bg=nil,border=nil,selfDot=nil,northLbl=nil,playerDots={},npcDots={}}

local function initMinimap()
    local vp=Camera.ViewportSize
    MM.x=vp.X-MM.size-12 MM.y=vp.Y-MM.size-12
    if not hasDraw then return end
    local cx=MM.x+MM.size/2 local cy=MM.y+MM.size/2
    MM.bg=NewDraw("Circle",{Thickness=0,Filled=true,Color=Color3.fromRGB(6,6,16),Visible=false,ZIndex=20,NumSides=40,Radius=MM.size/2,Position=Vector2.new(cx,cy)})
    MM.border=NewDraw("Circle",{Thickness=2,Filled=false,Color=Color3.fromRGB(255,200,60),Visible=false,ZIndex=21,NumSides=40,Radius=MM.size/2,Position=Vector2.new(cx,cy)})
    MM.selfDot=NewDraw("Circle",{Thickness=0,Filled=true,Color=Color3.fromRGB(255,255,255),Visible=false,ZIndex=23,NumSides=8,Radius=4,Position=Vector2.new(cx,cy)})
    MM.northLbl=NewDraw("Text",{Text="N",Size=11,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=Color3.fromRGB(255,200,60),Visible=false,ZIndex=22,Position=Vector2.new(cx,MM.y+7)})
end

local function getDot(pool,idx,color,r)
    r=r or 3
    if not pool[idx] then
        pool[idx]=NewDraw("Circle",{Thickness=0,Filled=true,Color=color,Visible=false,ZIndex=23,NumSides=8,Radius=r})
    end
    return pool[idx]
end

local function w2mm(worldPos,myPos,myYaw)
    local rel=worldPos-myPos
    local c=math.cos(-myYaw) local s=math.sin(-myYaw)
    local rx=rel.X*c-rel.Z*s local rz=rel.X*s+rel.Z*c
    local cx=MM.x+MM.size/2 local cy=MM.y+MM.size/2
    local px=cx+(rx/MM.range)*(MM.size/2)
    local py=cy-(rz/MM.range)*(MM.size/2)
    local dx=px-cx local dy=py-cy
    local dist=math.sqrt(dx*dx+dy*dy)
    local maxR=MM.size/2-5
    if dist>maxR then local sc=maxR/dist px=cx+dx*sc py=cy+dy*sc end
    return Vector2.new(px,py),dist<=maxR
end

local mmFrame=0
local function updateMinimap()
    mmFrame=mmFrame+1
    if mmFrame%6~=0 then return end
    local vp=Camera.ViewportSize
    MM.x=vp.X-MM.size-12 MM.y=vp.Y-MM.size-12
    local cx=MM.x+MM.size/2 local cy=MM.y+MM.size/2
    local center=Vector2.new(cx,cy)
    if not S.minimapOn then
        if MM.bg then pcall(function() MM.bg.Visible=false end) end
        if MM.border then pcall(function() MM.border.Visible=false end) end
        if MM.selfDot then pcall(function() MM.selfDot.Visible=false end) end
        if MM.northLbl then pcall(function() MM.northLbl.Visible=false end) end
        for _,d in pairs(MM.playerDots) do pcall(function() d.Visible=false end) end
        for _,d in pairs(MM.npcDots) do pcall(function() d.Visible=false end) end
        return
    end
    pcall(function()
        MM.bg.Position=center MM.bg.Visible=true
        MM.border.Position=center MM.border.Visible=true MM.border.Color=rgb()
        MM.selfDot.Position=center MM.selfDot.Visible=true
        MM.northLbl.Position=Vector2.new(cx,MM.y+7) MM.northLbl.Visible=true
    end)
    local myChar=LocalPlayer.Character
    local myHRP=myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    local myPos=myHRP.Position
    local _,myYaw,_=myHRP.CFrame:ToEulerAnglesYXZ()
    local pi=0
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LocalPlayer then continue end
        local char=p.Character if not char then continue end
        local hrp pcall(function() hrp=char:FindFirstChild("HumanoidRootPart") end)
        if not hrp then continue end
        pi=pi+1
        local dot=getDot(MM.playerDots,pi,Color3.fromRGB(255,60,60),4)
        local pos,onMap=w2mm(hrp.Position,myPos,myYaw)
        pcall(function() dot.Position=pos dot.Visible=onMap end)
    end
    for i=pi+1,#MM.playerDots do pcall(function() MM.playerDots[i].Visible=false end) end
    local ni=0
    for _,t in ipairs(npcCache) do
        if not t.hrp then continue end
        ni=ni+1
        local dot=getDot(MM.npcDots,ni,Color3.fromRGB(255,140,0),3)
        local pos,onMap=w2mm(t.hrp.Position,myPos,myYaw)
        pcall(function() dot.Position=pos dot.Visible=onMap end)
    end
    for i=ni+1,#MM.npcDots do pcall(function() MM.npcDots[i].Visible=false end) end
end

initMinimap()

-- Minimap toggle button (bottom-left)
local mmBtn=Instance.new("TextButton",SG)
mmBtn.Size=UDim2.new(0,82,0,22) mmBtn.Position=UDim2.new(0,8,1,-30)
mmBtn.BackgroundColor3=Color3.fromRGB(12,12,24) mmBtn.BorderSizePixel=0 mmBtn.ZIndex=60
mmBtn.Text="🗺 Map OFF" mmBtn.TextColor3=Color3.fromRGB(140,140,180)
mmBtn.TextSize=9 mmBtn.Font=Enum.Font.GothamBold
Instance.new("UICorner",mmBtn).CornerRadius=UDim.new(0,5)
mmBtn.MouseButton1Click:Connect(function()
    S.minimapOn=not S.minimapOn
    mmBtn.Text=S.minimapOn and "🗺 Map ON" or "🗺 Map OFF"
    mmBtn.TextColor3=S.minimapOn and Color3.fromRGB(80,255,80) or Color3.fromRGB(140,140,180)
end)

-- ============================================================
-- MAIN LOOP
-- ============================================================
local sunT=0 local frame=0

RunService.Heartbeat:Connect(function(dt)
    frame=frame+1 sunT=sunT+dt
    S.rgbHue=(S.rgbHue+0.003)%1
    local col=rgb()

    -- GUI + BG every 3 frames (~20fps)
    if frame%3==0 then
        stroke.Color=col
        TitleLbl.TextColor3=Color3.fromHSV((S.rgbHue+0.12)%1,0.8,1)
        LogoLbl.TextColor3=col

        local preset=S.bgPreset or "Sun"

        if preset=="Sun" then
            local sx=0.5+math.sin(sunT*0.12)*0.38
            local sy=0.35+math.sin(sunT*0.09)*0.28
            local sh=(S.rgbHue*0.3+0.08)%1
            for i,layer in ipairs(sunLayers) do
                local br=1+math.sin(sunT*0.5+i*0.4)*0.06
                layer.Size=UDim2.new(0,sunSizes[i]*br,0,sunSizes[i]*br)
                layer.Position=UDim2.new(sx,0,sy,0)
                layer.BackgroundColor3=Color3.fromHSV(sh,0.7,1)
            end
            for _,puff in ipairs(smokePuffs) do
                puff.t=puff.t+dt*puff.data.sp
                local ox=math.sin(puff.t)*puff.data.amp/math.max(WIN.AbsoluteSize.X,1)
                local oy=math.cos(puff.t*0.7)*puff.data.amp/math.max(WIN.AbsoluteSize.Y,1)
                puff.frame.Position=UDim2.new(sx+puff.data.rx-0.5+ox,0,sy+puff.data.ry-0.35+oy,0)
                puff.frame.BackgroundColor3=Color3.fromHSV((S.rgbHue+0.1)%1,0.5,1)
            end
            for i,ray in ipairs(rays) do
                ray.Position=UDim2.new(sx,0,sy,0)
                ray.Rotation=(i-1)*45+sunT*20
                ray.BackgroundColor3=Color3.fromHSV((S.rgbHue+i*0.07)%1,0.6,1)
            end

        elseif preset=="Zombies" then
            for _,z in ipairs(zombieData) do
                z.t=z.t+dt*z.speed
                local nx=z.x-math.floor(z.t)
                if nx<-0.1 then z.x=1.1 z.t=0 nx=z.x end
                z.lbl.Position=UDim2.new(nx,0,0.55+math.sin(z.t*6)*0.03,0)
                z.lbl.TextColor3=Color3.fromHSV((S.rgbHue+z.x*0.3)%1,0.7,0.8)
            end

        elseif preset=="Cars" then
            for _,c in ipairs(carData) do
                c.x=c.x+c.speed
                if c.x>1.1 then c.x=-0.15 end
                c.lbl.Position=UDim2.new(c.x,0,c.y,0)
            end

        elseif preset=="RGB" then
            for _,b in ipairs(rgbBands) do
                b.frame.BackgroundColor3=Color3.fromHSV((S.rgbHue+b.hueOff)%1,0.8,0.5)
                b.frame.BackgroundTransparency=0.82
            end
        end

        -- Tab glow
        for _,b in pairs(tabBtns) do
            if b.BackgroundColor3==Color3.fromRGB(28,20,6) then b.TextColor3=col end
        end
        CreditLbl.TextColor3=Color3.fromHSV((S.rgbHue+0.5)%1,0.4,0.5)
    end

    -- FOV circle every 2 frames
    if frame%2==0 then
        if S.aimbotOn then
            local mp=getMousePos()
            fovCircle.Visible=true fovCircle.Radius=S.aimbotFOV
            fovCircle.Position=mp fovCircle.Color=col
        else fovCircle.Visible=false end
    end

    -- Minimap every 6 frames
    updateMinimap()

    -- ESP every 3 frames
    if frame%3==0 and S.espOn then
        local myChar=LocalPlayer.Character
        local myHRP=myChar and myChar:FindFirstChild("HumanoidRootPart")
        local tSrc=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y)
        local allT=getAllTargets()
        for _,t in ipairs(allT) do
            local hrp=t.hrp local head
            pcall(function() head=t.char:FindFirstChild("Head") end)
            if not hrp or not head then continue end
            local hsp,onScr=w2v(head.Position+Vector3.new(0,0.6,0))
            local rsp=w2v(hrp.Position)
            if not onScr then continue end
            local espCol=t.isNPC and Color3.fromRGB(255,140,0) or (S.espRainbow and col or S.espColor)
            local dist=myHRP and math.floor((hrp.Position-myHRP.Position).Magnitude) or 0
            local hx,hy=hsp.X,hsp.Y local _,ry=rsp.X,rsp.Y
            local bh=math.abs(ry-hy)+20 local bw=bh*0.4
            local bL,bR=hx-bw/2,hx+bw/2 local bT,bB=hy-14,ry+14
            if t.isNPC then
                -- Use persistent cached Drawing objects for NPCs too
                local npcKey = tostring(t.char)
                if not _G.GB233ESP_NPC then _G.GB233ESP_NPC = {} end
                if not _G.GB233ESP_NPC[npcKey] then
                    local o={}
                    local function sd(tp,props)
                        if not hasDraw then return setmetatable({},{__newindex=function()end,__index=function()return nil end}) end
                        local ok2,obj=pcall(Drawing.new,tp)
                        if not ok2 then return setmetatable({},{__newindex=function()end,__index=function()return nil end}) end
                        for k,v2 in pairs(props or {}) do pcall(function() obj[k]=v2 end) end
                        return obj
                    end
                    for _,side in ipairs({"t","b","l","r"}) do
                        o["bx_"..side]=sd("Line",{Thickness=1,Color=Color3.fromRGB(255,140,0),Visible=false,ZIndex=4})
                    end
                    o.name=sd("Text",{Text="",Size=11,Center=true,Outline=true,OutlineColor=Color3.new(0,0,0),Color=Color3.fromRGB(255,140,0),Visible=false,ZIndex=5})
                    _G.GB233ESP_NPC[npcKey]=o
                end
                local no=_G.GB233ESP_NPC[npcKey]
                pcall(function()
                    no.bx_t.From=Vector2.new(bL,bT) no.bx_t.To=Vector2.new(bR,bT) no.bx_t.Color=espCol no.bx_t.Visible=S.espBoxes
                    no.bx_b.From=Vector2.new(bL,bB) no.bx_b.To=Vector2.new(bR,bB) no.bx_b.Color=espCol no.bx_b.Visible=S.espBoxes
                    no.bx_l.From=Vector2.new(bL,bT) no.bx_l.To=Vector2.new(bL,bB) no.bx_l.Color=espCol no.bx_l.Visible=S.espBoxes
                    no.bx_r.From=Vector2.new(bR,bT) no.bx_r.To=Vector2.new(bR,bB) no.bx_r.Color=espCol no.bx_r.Visible=S.espBoxes
                    no.name.Text="[NPC] "..t.name no.name.Position=Vector2.new(hx,bT-14) no.name.Visible=S.espNames
                end)
            else
                local player=t.player if not player then continue end
                ensureESP(player)
                local objs=_G.GB233ESP[player] if not objs then continue end
                pcall(function()
                    objs.bx_t.From=Vector2.new(bL,bT) objs.bx_t.To=Vector2.new(bR,bT) objs.bx_t.Color=espCol objs.bx_t.Visible=S.espBoxes
                    objs.bx_b.From=Vector2.new(bL,bB) objs.bx_b.To=Vector2.new(bR,bB) objs.bx_b.Color=espCol objs.bx_b.Visible=S.espBoxes
                    objs.bx_l.From=Vector2.new(bL,bT) objs.bx_l.To=Vector2.new(bL,bB) objs.bx_l.Color=espCol objs.bx_l.Visible=S.espBoxes
                    objs.bx_r.From=Vector2.new(bR,bT) objs.bx_r.To=Vector2.new(bR,bB) objs.bx_r.Color=espCol objs.bx_r.Visible=S.espBoxes
                    objs.name.Text=player.Name objs.name.Position=Vector2.new(hx,bT-16) objs.name.Color=espCol objs.name.Visible=S.espNames
                    objs.dist.Text=dist.."m"   objs.dist.Position=Vector2.new(hx,bT-28) objs.dist.Color=espCol objs.dist.Visible=S.espDist
                    objs.tracer.From=tSrc objs.tracer.To=Vector2.new(hx,bB) objs.tracer.Color=espCol objs.tracer.Visible=S.espTracers
                    -- Health bar (left side of box)
                    if S.espHealthBars then
                        local hum=t.char:FindFirstChildOfClass("Humanoid")
                        if hum then
                            local hp=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
                            local barX=bL-5
                            -- BG bar (full height)
                            objs.hpBg.From=Vector2.new(barX,bT) objs.hpBg.To=Vector2.new(barX,bB)
                            objs.hpBg.Visible=true
                            -- Fill bar (proportional to HP)
                            local fillBot=bB-(bB-bT)*(1-hp)  -- top portion = full health
                            local hpCol=Color3.fromHSV(hp*0.33,1,1) -- red→yellow→green
                            objs.hpBar.From=Vector2.new(barX,fillBot) objs.hpBar.To=Vector2.new(barX,bB)
                            objs.hpBar.Color=hpCol objs.hpBar.Visible=true
                            -- HP number
                            objs.hpText.Text=math.floor(hum.Health)
                            objs.hpText.Position=Vector2.new(barX,bT-12)
                            objs.hpText.Visible=true
                        end
                    else
                        objs.hpBg.Visible=false objs.hpBar.Visible=false objs.hpText.Visible=false
                    end
                end)
            end
        end
        -- Hide ESP for gone players
        for _,p in ipairs(Players:GetPlayers()) do
            if p==LocalPlayer then continue end
            local inList=false
            for _,t in ipairs(allT) do if not t.isNPC and t.player==p then inList=true break end end
            if not inList then
                local objs=_G.GB233ESP[p]
                if objs then for _,v in pairs(objs) do pcall(function() v.Visible=false end) end end
            end
        end
    end
end)

-- ============================================================
-- RESPAWN HOOKS
-- ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if S.godOn   then enableGod() end
    if S.flyOn   then enableFly() end
    if S.speedOn or S.jumpOn then startMoveLoop() end
    if S.adminGunOn then createAdminGun() end
    npcCacheTime=0
end)


-- ============================================================
-- BOOT NOTIFICATION
-- ============================================================
local notif=Instance.new("Frame",SG)
notif.Size=UDim2.new(0,380,0,42) notif.Position=UDim2.new(0.5,-190,1,-65)
notif.BackgroundColor3=Color3.fromRGB(8,8,18) notif.BackgroundTransparency=0.05
notif.BorderSizePixel=0 notif.ZIndex=50
Instance.new("UICorner",notif).CornerRadius=UDim.new(0,10)
local ns=Instance.new("UIStroke",notif) ns.Thickness=1.5 ns.Color=Color3.fromRGB(255,200,60)
local nl=Instance.new("TextLabel",notif)
nl.Size=UDim2.new(1,0,1,0) nl.BackgroundTransparency=1
nl.Text="☀  GasBaby 233  v3.1  |  Military Tycoon  |  K = Toggle"
nl.TextColor3=Color3.fromRGB(255,220,100) nl.TextSize=13 nl.Font=Enum.Font.GothamBold nl.ZIndex=51
task.spawn(function()
    task.wait(5)
    for i=1,25 do
        notif.BackgroundTransparency=0.05+i/25*0.95
        nl.TextTransparency=i/25 ns.Transparency=i/25
        task.wait(0.04)
    end
    notif:Destroy()
end)

print("╔════════════════════════════════════════════════════╗")
print("║  ☀  GasBaby 233 v4.0 — Military Tycoon           ║")
print("║  K = Toggle GUI | 🗺 = Minimap toggle             ║")
print("║  11 Tabs | Settings | Configs | 5 BG Presets      ║")
print("║  Made by GasBaby233                               ║")
print("╚════════════════════════════════════════════════════╝")
