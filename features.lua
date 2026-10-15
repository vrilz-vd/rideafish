-- ============================================================
-- VRILZHUB FEATURES — RIDE A FISH
-- Speed · Auto Steal · Auto Return · Auto Deposit
-- ============================================================

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local Features = {}
_G.VRILZ_Features = Features

local TIER_ORDER = {
    "Common", "Coral", "Reef", "Tidal", "Deep",
    "Abyss", "Trench", "Sovereign", "Celestial", "Eternal"
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
        Common = false, Coral = false, Reef = false, Tidal = false, Deep = false,
        Abyss = false, Trench = true, Sovereign = true, Celestial = true, Eternal = true,
    },

    AutoReturn_Enabled = true,
    AutoReturn_AfterSteal = true,

    AutoDeposit_Enabled = true,
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
-- SPEED
-- ============================================================
Features.setSpeedEnabled = function(v)
    State.Speed_Enabled = v
    if not v then
        local hum = getHum()
        if hum then hum.WalkSpeed = 16 end
    end
end

Features.setSpeedValue = function(v)
    State.Speed_Value = v
    if State.Speed_Enabled then
        local hum = getHum()
        if hum then hum.WalkSpeed = v end
    end
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
-- WILDEGGS
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

local function isTierEnabled(tier)
    return State.AutoSteal_Tiers[tier] == true
end

-- ============================================================
-- PLOT & HATCHRACK
-- ============================================================
local function getMyPlot()
    for i = 1, 10 do
        local pot = workspace:FindFirstChild("Player Pot " .. i)
        if pot and pot:GetAttribute("OwnerUserId") == LP.UserId then
            return pot
        end
    end
    return nil
end

local function getPlotPosition()
    local plot = getMyPlot()
    if plot then return plot:GetPivot().Position end
    local hp = workspace:FindFirstChild("HomepointMarker")
    if hp then return hp:GetPivot().Position end
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

-- Cek apakah karakter lagi bawa egg (Tool "Common Egg" dll)
local function isHoldingEgg()
    local char = LP.Character
    if not char then return false end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local nameLower = tool.Name:lower()
            if nameLower:find("egg") and not nameLower:find("milkfish") then
                return true, tool
            end
        end
    end
    return false, nil
end

-- Cari prompt DepositSeaEgg di slot kosong
local function findEmptyHatchPrompt()
    local plot = getMyPlot()
    if not plot then return nil end
    local rack = plot:FindFirstChild("HatchRack")
    if not rack then return nil end

    for _, prompt in ipairs(rack:GetDescendants()) do
        if prompt:IsA("ProximityPrompt")
           and prompt.Name == "DepositSeaEgg"
           and prompt.Enabled
        then
            -- Cek apakah slot kosong (ga ada model egg di dalam Box Telur)
            local eggInteract = prompt.Parent
            local slotBox = eggInteract and eggInteract.Parent
            if slotBox then
                local hasEgg = false
                for _, child in ipairs(slotBox:GetChildren()) do
                    if child:IsA("Model") and child:FindFirstChild("EggRoot") then
                        hasEgg = true
                        break
                    end
                end
                if not hasEgg then
                    return prompt
                end
            end
        end
    end
    return nil
end

-- Get BasePart dari prompt buat TP
local function getPromptPart(prompt)
    local p = prompt.Parent
    while p and not p:IsA("BasePart") do
        p = p.Parent
    end
    return p
end

-- Deposit egg ke HatchRack
Features.depositEgg = function()
    local hrp = getHRP()
    if not hrp then return false, "no hrp" end

    -- Cek bener-bener bawa egg
    local holding, tool = isHoldingEgg()
    if not holding then return false, "not holding egg" end

    local prompt = findEmptyHatchPrompt()
    if not prompt then return false, "no empty slot" end

    local part = getPromptPart(prompt)
    if not part then return false, "no prompt part" end

    hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
    task.wait(0.15)

    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()
            task.wait(0.35)
            prompt:InputHoldEnd()
        end
    end)

    return true, "deposited"
end

-- ============================================================
-- STEAL 1 EGG
-- ============================================================
local function stealEgg(egg, hrp)
    if not egg or not egg.Parent then return false end
    local eggRoot = egg:FindFirstChild("EggRoot")
    if not eggRoot then return false end
    local prompt = eggRoot:FindFirstChild("TakeSeaEgg")
    if not prompt then return false end

    hrp.CFrame = CFrame.new(eggRoot.Position + Vector3.new(0, 3, 0))
    task.wait(0.08)

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

-- ============================================================
-- MAIN LOOP
-- ============================================================
task.spawn(function()
    while task.wait(0.1) do
        if not State.AutoSteal_Enabled then continue end

        local hrp = getHRP()
        if not hrp then continue end

        -- STEP 1: Cari egg target
        local eggs = getWildEggs()
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

        if not target then
            task.wait(0.5)
            continue
        end

        -- STEP 2: Steal egg
        stealEgg(target, hrp)
        task.wait(State.AutoSteal_Delay)

        -- STEP 3: Return ke plot
        if State.AutoReturn_Enabled and State.AutoReturn_AfterSteal then
            Features.returnToPlot()
            task.wait(0.4)

            -- STEP 4: Deposit ke HatchRack
            if State.AutoDeposit_Enabled then
                Features.depositEgg()
                task.wait(0.5)
            end
        end
    end
end)

-- ============================================================
-- SETTERS
-- ============================================================
Features.setAutoStealEnabled = function(v)
    State.AutoSteal_Enabled = v
end

Features.setAutoStealTier = function(tier, enabled)
    State.AutoSteal_Tiers[tier] = enabled
end

Features.setAutoStealDelay = function(v)
    State.AutoSteal_Delay = v
end

Features.setAutoReturnEnabled = function(v)
    State.AutoReturn_Enabled = v
end

Features.setAutoReturnAfterSteal = function(v)
    State.AutoReturn_AfterSteal = v
end

Features.setAutoDepositEnabled = function(v)
    State.AutoDeposit_Enabled = v
end

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

Features.getState = function()
    return State
end

Features.isHoldingEgg = isHoldingEgg
Features.getMyPlot = getMyPlot

print("[Features] Ride a Fish loaded ✅")
print("[Features] WildEggs: " .. #getWildEggs())
print("[Features] My plot: " .. tostring(getMyPlot() and getMyPlot().Name or "not found"))

return Features
