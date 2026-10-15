-- ============================================================
-- VRILZHUB FEATURES — RIDE A FISH
-- Speed · Auto Steal (by Tier) · Auto Return
-- ============================================================

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local Features = {}
_G.VRILZ_Features = Features

-- ============================================================
-- TIER LIST (dari rendah ke tinggi)
-- ============================================================
local TIER_ORDER = {
    "Common", "Coral", "Reef", "Tidal", "Deep",
    "Abyss", "Trench", "Sovereign", "Celestial", "Eternal"
}

local TIER_LUCK = {
    Common = 1, Coral = 20, Reef = 400, Tidal = 8000, Deep = 160000,
    Abyss = 3000000, Trench = 60000000, Sovereign = 1000000000,
    Celestial = 20000000000, Eternal = 70000000000
}

-- ============================================================
-- STATE
-- ============================================================
local State = {
    Speed_Enabled = false,
    Speed_Value = 40,
    AutoSteal_Enabled = false,
    AutoSteal_Delay = 0.4,
    AutoSteal_Tiers = {
        Common = false,
        Coral = false,
        Reef = false,
        Tidal = false,
        Deep = false,
        Abyss = false,
        Trench = true,
        Sovereign = true,
        Celestial = true,
        Eternal = true,
    },
    AutoReturn_Enabled = false,
    AutoReturn_Interval = 30,
    AutoReturn_Mode = "Plot",
}

-- ============================================================
-- HELPER
-- ============================================================
local function getChar()
    local char = LP.Character
    if not char then char = LP.CharacterAdded:Wait() end
    return char
end

local function getHRP()
    local char = getChar()
    return char:WaitForChild("HumanoidRootPart", 5)
end

local function getHum()
    local char = getChar()
    return char:WaitForChild("Humanoid", 5)
end

-- ============================================================
-- 1. SPEED
-- ============================================================
Features.setSpeed = function(value)
    local hum = getHum()
    if hum then hum.WalkSpeed = value end
end

Features.setSpeedEnabled = function(v)
    State.Speed_Enabled = v
    if not v then
        local hum = getHum()
        if hum then hum.WalkSpeed = 16 end
    end
end

Features.setSpeedValue = function(v)
    State.Speed_Value = v
    if State.Speed_Enabled then Features.setSpeed(v) end
end

task.spawn(function()
    while task.wait(0.5) do
        if State.Speed_Enabled then
            local hum = getHum()
            if hum and hum.WalkSpeed ~= State.Speed_Value then
                hum.WalkSpeed = State.Speed_Value
            end
        end
    end
end)

-- ============================================================
-- 2. AUTO STEAL — by Tier
-- ============================================================
local function getWildEggs()
    local eggRT = workspace:FindFirstChild("EggRuntime")
    if not eggRT then return {} end
    local wildEggs = eggRT:FindFirstChild("WildEggs")
    if not wildEggs then return {} end
    return wildEggs:GetChildren()
end

local function getEggTier(egg)
    return egg:GetAttribute("EggTier") or "Unknown"
end

local function getEggKg(egg)
    return egg:GetAttribute("EggKg") or 0
end

local function getEggLuck(egg)
    return egg:GetAttribute("EggLuck") or 0
end

-- Cek apakah tier egg aktif di filter
local function isTierEnabled(tier)
    return State.AutoSteal_Tiers[tier] == true
end

-- Ambil 1 egg
local function stealEgg(egg, hrp)
    if not egg or not egg.Parent then return false end
    local eggRoot = egg:FindFirstChild("EggRoot")
    if not eggRoot then return false end
    local prompt = eggRoot:FindFirstChild("TakeSeaEgg")
    if not prompt then return false end

    -- TP
    hrp.CFrame = CFrame.new(eggRoot.Position + Vector3.new(0, 3, 0))
    task.wait(0.08)

    -- Fire prompt
    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()
            task.wait(0.35)
            prompt:InputHoldEnd()
        end
    end)
    return true
end

-- Loop Auto Steal
task.spawn(function()
    while task.wait(0.1) do
        if not State.AutoSteal_Enabled then continue end

        local hrp = getHRP()
        if not hrp then continue end

        local eggs = getWildEggs()
        if #eggs == 0 then continue end

        -- Cari egg yang tiernya enabled + terdekat
        local target = nil
        local closestDist = math.huge

        for _, egg in ipairs(eggs) do
            local tier = getEggTier(egg)
            if not isTierEnabled(tier) then continue end

            local eggRoot = egg:FindFirstChild("EggRoot")
            if not eggRoot then continue end

            local dist = (eggRoot.Position - hrp.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                target = egg
            end
        end

        if target then
            stealEgg(target, hrp)
            task.wait(State.AutoSteal_Delay)
        else
            task.wait(0.3)
        end
    end
end)

Features.setAutoStealEnabled = function(v)
    State.AutoSteal_Enabled = v
end

Features.setAutoStealTier = function(tier, enabled)
    State.AutoSteal_Tiers[tier] = enabled
end

Features.setAutoStealDelay = function(v)
    State.AutoSteal_Delay = v
end

-- Hitung egg per tier (buat UI counter)
Features.getEggCountByTier = function()
    local counts = {}
    for _, tier in ipairs(TIER_ORDER) do counts[tier] = 0 end
    for _, egg in ipairs(getWildEggs()) do
        local t = getEggTier(egg)
        counts[t] = (counts[t] or 0) + 1
    end
    return counts
end

Features.getTierOrder = function()
    return TIER_ORDER
end

-- ============================================================
-- 3. AUTO RETURN
-- ============================================================
local function getMyPlot()
    local myId = LP.UserId
    for i = 1, 10 do
        local pot = workspace:FindFirstChild("Player Pot " .. i)
        if pot and pot:GetAttribute("OwnerUserId") == myId then
            return pot
        end
    end
    return nil
end

local function getPlotPosition()
    local plot = getMyPlot()
    if plot then
        return plot:GetPivot().Position
    end
    -- Fallback: homepoint
    local hp = workspace:FindFirstChild("HomepointMarker")
    if hp then
        return hp:GetPivot().Position
    end
    return nil
end

Features.returnToPlot = function()
    local hrp = getHRP()
    if not hrp then return false end
    local pos = getPlotPosition()
    if pos then
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
        return true
    end
    return false
end

Features.setAutoReturnEnabled = function(v)
    State.AutoReturn_Enabled = v
end

Features.setAutoReturnInterval = function(v)
    State.AutoReturn_Interval = v
end

-- Loop Auto Return
task.spawn(function()
    local lastReturn = 0
    while task.wait(1) do
        if not State.AutoReturn_Enabled then
            lastReturn = tick()
            continue
        end
        if tick() - lastReturn >= State.AutoReturn_Interval then
            Features.returnToPlot()
            lastReturn = tick()
        end
    end
end)

Features.getState = function()
    return State
end

print("[Features] Ride a Fish loaded ✅")
print("[Features] WildEggs: " .. #getWildEggs())
print("[Features] Tier list: " .. table.concat(TIER_ORDER, ", "))

return Features
