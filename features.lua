-- ============================================================
-- VRILZHUB FEATURES — RIDE A FISH
-- Speed · Auto Steal · Auto Return (200 studs step) · Auto Deposit
-- ============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer

local Features = {}
_G.VRILZ_Features = Features

local TIER_ORDER = {
    "Common", "Coral", "Reef", "Tidal", "Deep",
    "Abyss", "Trench", "Sovereign", "Celestial", "Eternal"
}

-- ⭐ STEP SETTING (200 studs per step)
local STEP_SIZE = 200
local STEP_TIME = 0.15

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

local isBusy = false

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
-- SMOOTH TP STEP BY STEP (TWEEN)
-- ============================================================
local function smoothTp(hrp, targetPos, stepSize, stepTime)
    stepSize = stepSize or STEP_SIZE
    stepTime = stepTime or STEP_TIME

    if not hrp or not hrp.Parent then return false end

    local totalDist = (targetPos - hrp.Position).Magnitude
    local steps = math.ceil(totalDist / stepSize)

    print("[TP] 🚶 " .. math.floor(totalDist) .. " studs | " .. steps .. " steps")

    for i = 1, steps do
        local h = getHRP()
        if not h or not h.Parent then break end

        local currentPos = h.Position
        local delta = targetPos - currentPos
        local dist = delta.Magnitude

        if dist < 5 then break end

        local stepDist = math.min(stepSize, dist)
        local nextPos = currentPos + delta.Unit * stepDist

        local tween = TweenService:Create(
            h,
            TweenInfo.new(stepTime, Enum.EasingStyle.Linear),
            { CFrame = CFrame.new(nextPos) }
        )
        tween:Play()
        tween.Completed:Wait()
    end

    return true
end

Features.smoothTp = smoothTp

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
-- IS HOLDING EGG
-- ============================================================
local function isHoldingEgg()
    local char = LP.Character
    if not char then return false end

    -- Cek 1: Model CarriedSeaEgg di character
    if char:FindFirstChild("CarriedSeaEgg") then
        return true, char.CarriedSeaEgg
    end

    -- Cek 2: Tool apapun di character (kecuali Milkfish)
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool.Name ~= "Milkfish" then
            return true, tool
        end
    end

    -- Cek 3: Tool di backpack (kecuali Milkfish)
    local backpack = LP:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name ~= "Milkfish" then
                return true, tool
            end
        end
    end

    return false, nil
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
    if plot then
        local ok, pivot = pcall(function() return plot:GetPivot() end)
        if ok and pivot then return pivot.Position end
    end
    local hp = workspace:FindFirstChild("HomepointMarker")
    if hp then
        local ok, pivot = pcall(function() return hp:GetPivot() end)
        if ok and pivot then return pivot.Position end
    end
    return nil
end

Features.returnToPlot = function()
    local hrp = getHRP()
    if not hrp then
        print("[Return] ❌ No HRP")
        return false
    end
    local pos = getPlotPosition()
    if not pos then
        print("[Return] ❌ No plot position")
        return false
    end

    print("[Return] 🏠 Returning step-by-step...")
    smoothTp(hrp, pos + Vector3.new(0, 5, 0))
    print("[Return] ✅ Done")
    return true
end

-- ============================================================
-- HATCHRACK
-- ============================================================
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

    if not isHoldingEgg() then
        print("[Deposit] ❌ Ga bawa egg")
        return false
    end

    local prompt = findEmptyHatchPrompt()
    if not prompt then
        print("[Deposit] ❌ Ga ada slot kosong")
        return false
    end

    local part = getPromptPart(prompt)
    if not part then return false end

    print("[Deposit] 📦 TP ke slot...")
    smoothTp(hrp, part.Position + Vector3.new(0, 3, 0))
    task.wait(0.3)

    local holdTime = (prompt.HoldDuration > 0) and prompt.HoldDuration or 0.3
    if fireproximityprompt then
        pcall(function() fireproximityprompt(prompt) end)
        task.wait(holdTime + 0.2)
    else
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(holdTime + 0.15)
            prompt:InputHoldEnd()
        end)
        task.wait(0.2)
    end

    print("[Deposit] ✅ Done")
    return true
end

-- ============================================================
-- STEAL — TUNGGU SAMPE EGG BENERAN MASUK
-- ============================================================
local function stealEgg(egg, hrp)
    if not egg or not egg.Parent then
        print("[Steal] ❌ Egg invalid")
        return false
    end

    local eggRoot = egg:FindFirstChild("EggRoot")
    if not eggRoot then
        print("[Steal] ❌ EggRoot ga ketemu")
        return false
    end

    local prompt = eggRoot:FindFirstChild("TakeSeaEgg")
    if not prompt then
        print("[Steal] ❌ Prompt TakeSeaEgg ga ketemu")
        return false
    end

    -- ⭐ STEP 1: TP smooth ke egg
    print("[Steal] 🚶 TP ke egg (" .. egg.Name .. ")")
    smoothTp(hrp, eggRoot.Position + Vector3.new(0, 3, 0))

    -- ⭐ STEP 2: Tunggu 0.3s biar server detect posisi
    task.wait(0.3)

    -- ⭐ STEP 3: Fire prompt
    print("[Steal] 🎯 Fire prompt...")
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

    -- ⭐ STEP 4: TUNGGU SAMPE EGG BENERAN MASUK (max 3s)
    print("[Steal] ⏳ Nunggu egg masuk...")
    local waitStart = tick()
    while tick() - waitStart < 3 do
        if isHoldingEgg() then
            print("[Steal] ✅ Egg masuk!")
            return true
        end
        task.wait(0.1)
    end

    print("[Steal] ❌ Egg ga masuk (timeout)")
    return false
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
task.spawn(function()
    while true do
        task.wait(0.3)

        if not State.AutoSteal_Enabled then
            task.wait(0.5)
            continue
        end

        if isBusy then
            task.wait(0.2)
            continue
        end

        isBusy = true

        local success, err = pcall(function()

            local hrp = getHRP()
            if not hrp then return end

            -- ═══════════════════════════════════════
            -- STEP 1: Cari egg target
            -- ═══════════════════════════════════════
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
                print("[AutoFarm] ⚠️ Ga ada egg yang match filter")
                task.wait(0.5)
                return
            end

            -- ═══════════════════════════════════════
            -- STEP 2: STEAL
            -- ═══════════════════════════════════════
            print("[AutoFarm] ════════════════════")
            print("[AutoFarm] 🥚 Target: " .. target.Name)

            local stealOk = stealEgg(target, hrp)

            -- ⭐ STEP 3: KALO STEAL GAGAL, JANGAN RETURN
            if not stealOk then
                print("[AutoFarm] ⚠️ Steal gagal, SKIP return + deposit")
                print("[AutoFarm] ════════════════════")
                return
            end

            print("[AutoFarm] ✅ Steal sukses")
            task.wait(0.3)

            -- ═══════════════════════════════════════
            -- STEP 4: RETURN (cuma kalo steal sukses)
            -- ═══════════════════════════════════════
            if State.AutoReturn_Enabled and State.AutoReturn_AfterSteal then
                print("[AutoFarm] 🏠 Returning...")
                Features.returnToPlot()
                task.wait(0.3)
            end

            -- ═══════════════════════════════════════
            -- STEP 5: DEPOSIT
            -- ═══════════════════════════════════════
            if State.AutoDeposit_Enabled and isHoldingEgg() then
                print("[AutoFarm] 📦 Depositing...")
                Features.depositEgg()
                task.wait(0.5)
            end

            print("[AutoFarm] ════════════════════")

        end)

        if not success then
            warn("[AutoFarm] ❌ Error: " .. tostring(err))
        end

        isBusy = false
        task.wait(0.3)
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
print("[Features] Step: " .. STEP_SIZE .. " studs | Time: " .. STEP_TIME .. "s")

return Features
