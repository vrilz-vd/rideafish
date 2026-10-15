-- ============================================================
-- VRILZHUB FEATURES — RIDE A FISH (FIXED)
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

-- Prioritas tier (1 = paling tinggi, 99 = fallback)
local TIER_PRIORITY = {
    Eternal = 1, Celestial = 2, Sovereign = 3, Trench = 4, Abyss = 5,
    Deep = 6, Tidal = 7, Reef = 8, Coral = 9, Common = 10,
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
    -- Debug mode (print verbose)
    Debug = true,
}

local isBusy = false

-- ============================================================
-- LOGGER
-- ============================================================
local function log(...)
    if State.Debug then
        print("[VRILZ]", ...)
    end
end

-- ============================================================
-- HELPER
-- ============================================================
local function getChar()
    local char = LP.Character
    if not char then
        local ok, c = pcall(function() return LP.CharacterAdded:Wait() end)
        if ok then char = c end
    end
    return char
end

local function getHRP()
    local char = getChar()
    if not char then return nil end
    local ok, hrp = pcall(function() return char:WaitForChild("HumanoidRootPart", 5) end)
    if ok then return hrp end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local char = getChar()
    if not char then return nil end
    local ok, hum = pcall(function() return char:WaitForChild("Humanoid", 5) end)
    if ok then return hum end
    return char:FindFirstChild("Humanoid")
end

-- ============================================================
-- SMOOTH TP (STEP BY STEP) — Anti-stuck
-- ============================================================
local function smoothTp(hrp, targetPos, stepSize, stepTime)
    stepSize = stepSize or STEP_SIZE
    stepTime = stepTime or STEP_TIME

    if not hrp or not hrp.Parent then return false end

    local totalDist = (targetPos - hrp.Position).Magnitude
    local steps = math.ceil(totalDist / stepSize)
    log("[TP] 🚶 " .. math.floor(totalDist) .. " studs | " .. steps .. " steps")

    for i = 1, steps do
        local h = getHRP()
        if not h or not h.Parent then
            log("[TP] ❌ HRP hilang di step " .. i)
            return false
        end

        local currentPos = h.Position
        local delta = targetPos - currentPos
        local dist = delta.Magnitude

        if dist < 5 then break end

        local stepDist = math.min(stepSize, dist)
        local nextPos = currentPos + delta.Unit * stepDist

        local ok = pcall(function()
            local tween = TweenService:Create(
                h,
                TweenInfo.new(stepTime, Enum.EasingStyle.Linear),
                { CFrame = CFrame.new(nextPos) }
            )
            tween:Play()
            tween.Completed:Wait()
        end)

        if not ok then
            log("[TP] ⚠️ Tween error di step " .. i)
            return false
        end
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

-- Auto-detect nama attribute tier (beberapa kemungkinan)
local TIER_ATTR_NAMES = { "EggTier", "Tier", "Rarity", "EggRarity", "TierName" }

local function getEggTier(egg)
    if not egg or not egg.Parent then return "Unknown" end
    for _, attrName in ipairs(TIER_ATTR_NAMES) do
        local ok, val = pcall(function() return egg:GetAttribute(attrName) end)
        if ok and type(val) == "string" and val ~= "" then
            -- Normalize case: "eternal" → "Eternal"
            local normalized = val:sub(1,1):upper() .. val:sub(2):lower()
            return normalized
        end
    end
    return "Unknown"
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
-- PLOT — Robust detection
-- ============================================================
local function getMyPlot()
    -- Strategi 1: nama standar "Player Pot X"
    for i = 1, 20 do
        local pot = workspace:FindFirstChild("Player Pot " .. i)
        if pot then
            local ok, owner = pcall(function() return pot:GetAttribute("OwnerUserId") end)
            if ok and owner == LP.UserId then
                return pot
            end
        end
    end

    -- Strategi 2: scan semua Model/BasePart yang punya attribute OwnerUserId
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("Folder") then
            local ok, owner = pcall(function() return obj:GetAttribute("OwnerUserId") end)
            if ok and owner == LP.UserId then
                -- Pastikan ini plot (bukan misc)
                local nameLower = obj.Name:lower()
                if nameLower:find("pot") or nameLower:find("plot") or nameLower:find("base") then
                    return obj
                end
            end
        end
    end

    return nil
end

local function getPlotPosition()
    local plot = getMyPlot()
    if plot then
        -- Coba pivot
        local ok, pivot = pcall(function() return plot:GetPivot() end)
        if ok and pivot and pivot.Position.Magnitude > 0 then
            return pivot.Position
        end

        -- Fallback: cari PrimaryPart
        if plot.PrimaryPart then
            return plot.PrimaryPart.Position
        end

        -- Fallback: cari BasePart pertama
        for _, part in ipairs(plot:GetDescendants()) do
            if part:IsA("BasePart") then
                return part.Position
            end
        end
    end

    -- Fallback: HomepointMarker
    local hp = workspace:FindFirstChild("HomepointMarker")
    if hp then
        local ok, pivot = pcall(function() return hp:GetPivot() end)
        if ok and pivot then return pivot.Position end
        if hp:IsA("BasePart") then return hp.Position end
    end

    return nil
end

Features.returnToPlot = function()
    local hrp = getHRP()
    if not hrp then
        warn("[Return] ❌ No HRP")
        return false
    end

    local plot = getMyPlot()
    log("[Return] Plot:", plot and plot:GetFullName() or "NIL")

    local pos = getPlotPosition()
    log("[Return] Target pos:", tostring(pos))

    if not pos then
        warn("[Return] ❌ No plot position — cek nama plot / attribute OwnerUserId")
        return false
    end

    log("[Return] 🏠 Returning step-by-step...")
    local ok = smoothTp(hrp, pos + Vector3.new(0, 5, 0))
    if ok then
        log("[Return] ✅ Done")
    end
    return ok
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

local function getPromptFromSlot(eggInteract, promptName)
    if not eggInteract then return nil end
    for _, p in ipairs(eggInteract:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.Name == promptName and p.Enabled then
            return p
        end
    end
    return nil
end

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
-- AUTO HATCH
-- ============================================================
local function hatchAllReady()
    local count = 0
    for i = 1, 30 do
        local readySlot = findSlotByStatus("Ready")
        if not readySlot then break end

        local hatchPrompt = getPromptFromSlot(readySlot, "HatchEggPrompt")
        if not hatchPrompt then break end

        log("[AutoHatch] 🐣 Hatching slot " .. tostring(readySlot:GetAttribute("HatchSlot")))
        firePrompt(hatchPrompt)
        count = count + 1
        task.wait(0.3)
    end
    return count
end

local function skipAllGrowing()
    local count = 0
    for i = 1, 30 do
        local growingSlot = findSlotByStatus("Growing")
        if not growingSlot then break end

        local skipPrompt = getPromptFromSlot(growingSlot, "SkipGrowPrompt")
        if not skipPrompt then break end

        log("[AutoHatch] ⏩ Skip grow slot " .. tostring(growingSlot:GetAttribute("HatchSlot")))
        firePrompt(skipPrompt)
        count = count + 1
        task.wait(0.3)
    end
    return count
end

task.spawn(function()
    while task.wait(2) do
        if not State.AutoHatch_Enabled then continue end
        skipAllGrowing()
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
        log("[Deposit] ❌ Ga bawa egg")
        return false
    end

    local emptySlot = findSlotByStatus("Empty")
    if not emptySlot then
        log("[Deposit] ⚠️ Ga ada slot kosong — auto hatch dulu...")
        skipAllGrowing()
        hatchAllReady()
        task.wait(1)
        emptySlot = findSlotByStatus("Empty")
    end

    if not emptySlot then
        log("[Deposit] ❌ Masih ga ada slot kosong")
        return false
    end

    local prompt = getPromptFromSlot(emptySlot, "DepositSeaEgg")
    if not prompt then
        log("[Deposit] ❌ Prompt DepositSeaEgg ga ketemu")
        return false
    end

    log("[Deposit] 📦 Depositing to slot " .. tostring(emptySlot:GetAttribute("HatchSlot")))
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
    if not prompt then
        -- Fallback: cari prompt apapun di EggRoot
        for _, p in ipairs(eggRoot:GetDescendants()) do
            if p:IsA("ProximityPrompt") then
                prompt = p
                break
            end
        end
    end
    if not prompt then return false end

    log("[Steal] 🚶 TP ke egg (" .. egg.Name .. ")")
    smoothTp(hrp, eggRoot.Position + Vector3.new(0, 3, 0))
    task.wait(0.3)

    log("[Steal] 🎯 Fire prompt...")
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

    log("[Steal] ⏳ Nunggu egg masuk...")
    local waitStart = tick()
    while tick() - waitStart < 3 do
        if isHoldingEgg() then
            log("[Steal] ✅ Egg masuk!")
            return true
        end
        task.wait(0.1)
    end

    log("[Steal] ❌ Egg ga masuk (timeout)")
    return false
end

-- ============================================================
-- TARGET SELECTION — Prioritas Tier > Jarak
-- ============================================================
local function findBestTarget(hrp)
    local eggs = getWildEggs()
    local target = nil
    local bestPriority = math.huge
    local bestDist = math.huge

    for _, egg in ipairs(eggs) do
        local tier = getEggTier(egg)
        if not isTierEnabled(tier) then continue end

        local eggRoot = egg:FindFirstChild("EggRoot")
        if not eggRoot then continue end

        local priority = TIER_PRIORITY[tier] or 99
        local dist = (eggRoot.Position - hrp.Position).Magnitude

        -- Pilih tier tertinggi dulu; kalau sama, pilih terdekat
        if priority < bestPriority or (priority == bestPriority and dist < bestDist) then
            bestPriority = priority
            bestDist = dist
            target = egg
        end
    end

    return target, bestPriority, bestDist
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

            -- STEP 1: Cari egg target (prioritas tier tertinggi)
            local target, prio, dist = findBestTarget(hrp)

            if not target then
                log("[AutoFarm] ⚠️ Ga ada egg yang match filter")
                task.wait(0.5)
                return
            end

            log("[AutoFarm] ════════════════════")
            log("[AutoFarm] 🥚 Target: " .. target.Name .. " | Tier: " .. getEggTier(target)
                .. " | Priority: " .. tostring(prio) .. " | Dist: " .. math.floor(dist))

            -- STEP 2: STEAL
            local stealOk = stealEgg(target, hrp)

            if not stealOk then
                log("[AutoFarm] ⚠️ Steal gagal, SKIP return + deposit")
                log("[AutoFarm] ════════════════════")
                return
            end

            log("[AutoFarm] ✅ Steal sukses")
            task.wait(0.3)

            -- STEP 3: RETURN
            if State.AutoReturn_Enabled and State.AutoReturn_AfterSteal then
                log("[AutoFarm] 🏠 Returning...")
                Features.returnToPlot()
                task.wait(0.3)
            end

            -- STEP 4: DEPOSIT
            if State.AutoDeposit_Enabled and isHoldingEgg() then
                log("[AutoFarm] 📦 Depositing...")
                Features.depositEgg()
                task.wait(0.5)
            end

            log("[AutoFarm] ════════════════════")

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
Features.setAutoHatchEnabled = function(v) State.AutoHatch_Enabled = v end
Features.setDebug = function(v) State.Debug = v end

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
Features.getPlotPosition = getPlotPosition

-- ============================================================
-- DEBUG DUMP — panggil manual kalau perlu
-- ============================================================
Features.dumpEggInfo = function()
    local eggs = getWildEggs()
    print("[DEBUG] Total wild eggs:", #eggs)
    for i, egg in ipairs(eggs) do
        if i > 10 then break end
        print("  Egg[" .. i .. "]:", egg.Name, "| Tier:", getEggTier(egg))
        for k, v in pairs(egg:GetAttributes()) do
            print("     attr:", k, "=", v)
        end
    end
end

Features.dumpPlotInfo = function()
    local plot = getMyPlot()
    print("[DEBUG] My plot:", plot and plot:GetFullName() or "NIL")
    if plot then
        print("  Pivot:", tostring(getPlotPosition()))
        print("  Attributes:")
        for k, v in pairs(plot:GetAttributes()) do
            print("     ", k, "=", v)
        end
    end
end

print("[Features] Ride a Fish loaded ✅")
print("[Features] WildEggs: " .. #getWildEggs())
print("[Features] Step: " .. STEP_SIZE .. " studs")
print("[Features] Tier priority: Eternal > Celestial > Sovereign > Trench > ...")

return Features
