-- ============================================================
-- VRILZHUB FEATURES — RIDE A FISH
-- Speed · Auto Steal · Auto Return · Auto Deposit · Auto Hatch
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
    AutoHatch_Enabled = true,
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
-- SMOOTH TP (STEP BY STEP)
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

    if char:FindFirstChild("CarriedSeaEgg") then
        return true, char.CarriedSeaEgg
    end

    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool.Name ~= "Milkfish" then
            return true, tool
        end
    end

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
-- HATCHRACK HELPERS
-- ============================================================
local function getPromptPart(prompt)
    local p = prompt.Parent
    while p and not p:IsA("BasePart") do
        p = p.Parent
    end
    return p
end

-- Fire prompt (TP instant biar cepet + fire)
local function firePrompt(prompt)
    if not prompt then return false end
    local part = getPromptPart(prompt)
    if not part then return false end

    local hrp = getHRP()
    if not hrp then return false end

    pcall(function()
        hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
    end)
    task.wait(0.15)

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

    return true
end

-- Cari slot dengan status tertentu
local function findSlotByStatus(status)
    local plot = getMyPlot()
    if not plot then return nil end
    local rack = plot:FindFirstChild("HatchRack")
    if not rack then return nil end

    for _, eggInteract in ipairs(rack:GetDescendants()) do
        if eggInteract:IsA("BasePart") and eggInteract.Name == "EggHatchInteraction" then
            local slotStatus = eggInteract:GetAttribute("Status")
            if slotStatus == status then
                return eggInteract
            end
        end
    end
    return nil
end

-- Cari prompt spesifik di slot
local function getPromptFromSlot(eggInteract, promptName)
    if not eggInteract then return nil end
    for _, p in ipairs(eggInteract:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.Name == promptName and p.Enabled then
            return p
        end
    end
    return nil
end

-- ⭐ GET SLOT STATUS (buat UI counter)
Features.getSlotStatus = function()
    local result = { Empty = 0, Growing = 0, Ready = 0, Other = 0 }
    local plot = getMyPlot()
    if not plot then return result end
    local rack = plot:FindFirstChild("HatchRack")
    if not rack then return result end

    for _, eggInteract in ipairs(rack:GetDescendants()) do
        if eggInteract:IsA("BasePart") and eggInteract.Name == "EggHatchInteraction" then
            local status = eggInteract:GetAttribute("Status") or "Other"
            if result[status] then
                result[status] = result[status] + 1
            else
                result.Other = result.Other + 1
            end
        end
    end
    return result
end

-- ============================================================
-- AUTO HATCH — LOOP SEMUA SLOT READY + GROWING
-- ============================================================
local function hatchAllReady()
    local count = 0
    -- Loop sampe ga ada slot Ready lagi
    for i = 1, 30 do
        local readySlot = findSlotByStatus("Ready")
        if not readySlot then break end

        local hatchPrompt = getPromptFromSlot(readySlot, "HatchEggPrompt")
        if not hatchPrompt then break end

        print("[AutoHatch] 🐣 Hatching slot " .. tostring(readySlot:GetAttribute("HatchSlot")))
        firePrompt(hatchPrompt)
        count = count + 1
        task.wait(0.3)
    end
    return count
end

local function skipAllGrowing()
    local count = 0
    -- Loop sampe ga ada slot Growing lagi
    for i = 1, 30 do
        local growingSlot = findSlotByStatus("Growing")
        if not growingSlot then break end

        local skipPrompt = getPromptFromSlot(growingSlot, "SkipGrowPrompt")
        if not skipPrompt then break end

        print("[AutoHatch] ⏩ Skip grow slot " .. tostring(growingSlot:GetAttribute("HatchSlot")))
        firePrompt(skipPrompt)
        count = count + 1
        task.wait(0.3)
    end
    return count
end

-- Background loop Auto Hatch (tiap 2s)
task.spawn(function()
    while task.wait(2) do
        if not State.AutoHatch_Enabled then continue end

        -- Skip semua growing dulu (biar cepet jadi Ready)
        skipAllGrowing()

        -- Hatch semua ready
        hatchAllReady()
    end
end)

-- ============================================================
-- DEPOSIT
-- ============================================================
Features.depositEgg = function()
    local hrp = getHRP()
    if not hrp then return false end

    if not isHoldingEgg() then
        print("[Deposit] ❌ Ga bawa egg")
        return false
    end

    local emptySlot = findSlotByStatus("Empty")
    if not emptySlot then
        print("[Deposit] ⚠️ Ga ada slot kosong — auto hatch dulu...")
        -- Coba hatch dulu
        skipAllGrowing()
        hatchAllReady()
        task.wait(1)
        emptySlot = findSlotByStatus("Empty")
    end

    if not emptySlot then
        print("[Deposit] ❌ Masih ga ada slot kosong")
        return false
    end

    local prompt = getPromptFromSlot(emptySlot, "DepositSeaEgg")
    if not prompt then
        print("[Deposit] ❌ Prompt DepositSeaEgg ga ketemu")
        return false
    end

    print("[Deposit] 📦 Depositing to slot " .. tostring(emptySlot:GetAttribute("HatchSlot")))
    firePrompt(prompt)
    return true
end

-- ============================================================
-- STEAL
-- ============================================================
local function stealEgg(egg, hrp)
    if not egg or not egg.Parent then return false end
    local eggRoot = egg:FindFirstChild("EggRoot")
    if not eggRoot then return false end
    local prompt = eggRoot:FindFirstChild("TakeSeaEgg")
    if not prompt then return false end

    print("[Steal] 🚶 TP ke egg (" .. egg.Name .. ")")
    smoothTp(hrp, eggRoot.Position + Vector3.new(0, 3, 0))
    task.wait(0.3)

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
                print("[AutoFarm] ⚠️ Ga ada egg yang match filter")
                task.wait(0.5)
                return
            end

            -- STEP 2: STEAL
            print("[AutoFarm] ════════════════════")
            print("[AutoFarm] 🥚 Target: " .. target.Name)

            local stealOk = stealEgg(target, hrp)

            if not stealOk then
                print("[AutoFarm] ⚠️ Steal gagal, SKIP return + deposit")
                print("[AutoFarm] ════════════════════")
                return
            end

            print("[AutoFarm] ✅ Steal sukses")
            task.wait(0.3)

            -- STEP 3: RETURN
            if State.AutoReturn_Enabled and State.AutoReturn_AfterSteal then
                print("[AutoFarm] 🏠 Returning...")
                Features.returnToPlot()
                task.wait(0.3)
            end

            -- STEP 4: DEPOSIT
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
-- SETTERS (dipanggil dari UI)
-- ============================================================
Features.setAutoStealEnabled = function(v) State.AutoSteal_Enabled = v end
Features.setAutoStealTier = function(tier, enabled) State.AutoSteal_Tiers[tier] = enabled end
Features.setAutoStealDelay = function(v) State.AutoSteal_Delay = v end
Features.setAutoReturnEnabled = function(v) State.AutoReturn_Enabled = v end
Features.setAutoReturnAfterSteal = function(v) State.AutoReturn_AfterSteal = v end
Features.setAutoDepositEnabled = function(v) State.AutoDeposit_Enabled = v end
Features.setAutoHatchEnabled = function(v) State.AutoHatch_Enabled = v end

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
print("[Features] Step: " .. STEP_SIZE .. " studs")

return Features
