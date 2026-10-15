-- ============================================================
-- VRILZHUB FEATURES — RIDE A FISH
-- ============================================================

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local Features = {}
_G.VRILZ_Features = Features

local TIER_ORDER = {
    "Common", "Coral", "Reef", "Tidal", "Deep",
    "Abyss", "Trench", "Sovereign", "Celestial", "Eternal"
}

local RETURN_STEP = 100
local RETURN_DELAY = 0.08

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
-- STEP-BY-STEP TP
-- ============================================================
local function tpStepByStep(hrp, targetPos, stepSize, delay)
    stepSize = stepSize or RETURN_STEP
    delay = delay or RETURN_DELAY

    local startPos = hrp.Position
    local delta = targetPos - startPos
    local totalDist = delta.Magnitude

    if totalDist <= stepSize then
        pcall(function() hrp.CFrame = CFrame.new(targetPos) end)
        return true
    end

    local steps = math.ceil(totalDist / stepSize)
    local dir = delta.Unit

    for i = 1, steps do
        local stepDist = math.min(stepSize * i, totalDist)
        local nextPos = startPos + dir * stepDist
        pcall(function() hrp.CFrame = CFrame.new(nextPos) end)
        task.wait(delay)
    end

    pcall(function() hrp.CFrame = CFrame.new(targetPos) end)
    return true
end

Features.tpStepByStep = tpStepByStep

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
-- PLOT
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
    if not pos then return false end
    tpStepByStep(hrp, pos + Vector3.new(0, 5, 0))
    return true
end

-- ============================================================
-- HATCHRACK
-- ============================================================
local function isHoldingEgg()
    local char = LP.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find("egg") and not tool.Name:lower():find("milkfish") then
                return true, tool
            end
        end
    end
    local backpack = LP:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find("egg") and not tool.Name:lower():find("milkfish") then
                return true, tool
            end
        end
    end
    return false, nil
end

local function findEmptyHatchPrompt()
    local plot = getMyPlot()
    if not plot then return nil end
    local rack = plot:FindFirstChild("HatchRack")
    if not rack then return nil end

    for _, prompt in ipairs(rack:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Name == "DepositSeaEgg" and prompt.Enabled then
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

local function getPromptPart(prompt)
    local p = prompt.Parent
    while p and not p:IsA("BasePart") do
        p = p.Parent
    end
    return p
end

Features.depositEgg = function()
    local hrp = getHRP()
    if not hrp then return false end

    local holding = isHoldingEgg()
    if not holding then return false end

    local prompt = findEmptyHatchPrompt()
    if not prompt then return false end

    local part = getPromptPart(prompt)
    if not part then return false end

    tpStepByStep(hrp, part.Position + Vector3.new(0, 3, 0))
    task.wait(0.15)

    local holdTime = (prompt.HoldDuration > 0) and prompt.HoldDuration or 0.3
    if fireproximityprompt then
        pcall(function() fireproximityprompt(prompt) end)
        task.wait(holdTime + 0.15)
    else
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(holdTime + 0.1)
            prompt:InputHoldEnd()
        end)
        task.wait(0.15)
    end

    return true
end

-- ============================================================
-- STEAL — TUNGGU SAMPE EGG MASUK
-- ============================================================
local function stealEgg(egg, hrp)
    if not egg or not egg.Parent then return false end
    local eggRoot = egg:FindFirstChild("EggRoot")
    if not eggRoot then return false end
    local prompt = eggRoot:FindFirstChild("TakeSeaEgg")
    if not prompt then return false end

    -- TP instant ke egg
    pcall(function()
        hrp.CFrame = CFrame.new(eggRoot.Position + Vector3.new(0, 3, 0))
    end)
    task.wait(0.15)

    -- Fire prompt + tunggu hold
    local holdTime = (prompt.HoldDuration > 0) and prompt.HoldDuration or 0.3
    if fireproximityprompt then
        pcall(function() fireproximityprompt(prompt) end)
    else
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(holdTime + 0.15)
            prompt:InputHoldEnd()
        end)
    end

    -- Tunggu sampe egg beneran masuk (max 2s)
    local startTime = tick()
    while tick() - startTime < 2 do
        if isHoldingEgg() then
            return true
        end
        task.wait(0.1)
    end

    return false
end

-- ============================================================
-- MAIN LOOP — STEAL → RETURN → DEPOSIT → REPEAT
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

        -- STEP 2: STEAL
        stealEgg(target, hrp)

        -- STEP 3: RETURN (SELALU — ga peduli steal sukses/gagal)
        if State.AutoReturn_Enabled and State.AutoReturn_AfterSteal then
            Features.returnToPlot()
            task.wait(0.3)

            -- STEP 4: DEPOSIT (cuma kalau bawa egg)
            if State.AutoDeposit_Enabled then
                Features.depositEgg()
                task.wait(0.5)
            end
        end

        task.wait(State.AutoSteal_Delay)
    end
end)

-- ============================================================
-- SETTERS
-- ============================================================
Features.setAutoStealEnabled = function(v) State.AutoSteal_Enabled = v end
Features.setAutoStealTier = function(tier, enabled) State.AutoSteal_Tiers[tier] = enabled end
Features.setAutoStealDelay = function(v) State.AutoSteal_Delay = v end
Features.setAutoReturnEnabled = function(v) State.AutoReturn_Enabled = v end
Features.setAutoReturnAfterSteal = function(v) State.AutoReturn_AfterSteal = v end
Features.setAutoDepositEnabled = function(v) State.AutoDeposit_Enabled = v end

Features.getEggCountByTier = function()
    local counts = {}
    for _, tier in ipairs(TIER_ORDER) do counts[tier] = 0 end
    for _, egg in ipairs(getWildEggs()) do
        local t = getEggTier(egg)
        counts[t] = (counts[t] or 0) + 1
    end
    return counts
end

Features.getTierOrder = function() return TIER_ORDER end
Features.getState = function() return State end
Features.isHoldingEgg = isHoldingEgg
Features.getMyPlot = getMyPlot

print("[Features] Ride a Fish loaded ✅")
print("[Features] WildEggs: " .. #getWildEggs())
print("[Features] TP Step: " .. RETURN_STEP)

return Features
