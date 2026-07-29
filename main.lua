getgenv().Farm = true
getgenv().SelectedIsland = "Auto"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local p = Players.LocalPlayer
local cam = workspace.CurrentCamera
local CommF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

local currentTarget = nil
local lastFruitSpin = 0
local lastDashTime = 0
local isRecoveringHP = false

-- Кулдауны скиллов Света (Z, X, C, V, F)
local lastZTime = 0
local lastXTime = 0
local lastCTime = 0
local lastVTime = 0
local lastFTime = 0

local lastHrpPos = Vector3.new(0, 0, 0)
local stuckTimer = 0

-- БЕЗОПАСНАЯ СИСТЕМА КВЕСТОВ ДЖУНГЛЕЙ
local Islands = {
    ["Jungle"] = {
        Pos = Vector3.new(-1240, 6, -490),
        Quests = {
            {Req = 20, Name = "JungleQuest", Level = 3, Mob = "Gorilla King"},
            {Req = 15, Name = "JungleQuest", Level = 2, Mob = "Gorilla"},
            {Req = 10, Name = "JungleQuest", Level = 1, Mob = "Monkey"},
        }
    }
}

local Waypoints = {
    ["Monkey"] = Vector3.new(-1600, 36, 150),
    ["Gorilla"] = Vector3.new(-1240, 6, -490),
    ["Gorilla King"] = Vector3.new(-1130, 15, -490),
}

if getgenv().FarmConnection then
    getgenv().FarmConnection:Disconnect()
    getgenv().FarmConnection = nil
end

local function pressKey(keyCode, charCode)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        if keypress then keypress(charCode) end
        task.wait(0.08)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
        if keyrelease then keyrelease(charCode) end
    end)
end

local function doubleJump()
    task.spawn(function()
        pcall(function()
            local char = p.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if hum then
                hum.Jump = true
                pressKey(Enum.KeyCode.Space, 0x20)
                task.wait(0.15)
                hum.Jump = true
                pressKey(Enum.KeyCode.Space, 0x20)
            end
        end)
    end)
end

-- Проверка наличия моба/босса на карте
local function isMobAlive(mobName)
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return false end
    for _, m in pairs(enemiesFolder:GetChildren()) do
        if m.Name:find(mobName) then
            local mHum = m:FindFirstChild("Humanoid")
            if mHum and mHum.Health > 0 then
                return true
            end
        end
    end
    return false
end

-- Авто-прокачка Demon Fruit + Defense
local function autoAddStats()
    pcall(function()
        local points = p.Data.Points.Value
        if points and points > 0 then
            CommF:InvokeServer("AddPoint", "Demon Fruit", 1)
            CommF:InvokeServer("AddPoint", "Defense", 1)
        end
    end)
end

-- Убиралка фруктов в инвентарь
local function autoStoreAllFruits()
    pcall(function()
        for _, item in pairs(p.Backpack:GetChildren()) do
            if item:IsA("Tool") and item.Name:find("Fruit") and not item.Name:find("-") then
                CommF:InvokeServer("StoreFruit", item.Name, item)
            end
        end
        if p.Character then
            for _, item in pairs(p.Character:GetChildren()) do
                if item:IsA("Tool") and item.Name:find("Fruit") and not item.Name:find("-") then
                    CommF:InvokeServer("StoreFruit", item.Name, item)
                end
            end
        end
    end)
end

local function getLightTool()
    if p.Character then
        for _, item in pairs(p.Character:GetChildren()) do
            if item:IsA("Tool") then
                local tt = item:FindFirstChild("ToolTip") and item.ToolTip.Value or ""
                if item.Name:find("Light") or tt == "Blox Fruit" or tt == "Demon Fruit" then
                    return item
                end
            end
        end
    end
    for _, item in pairs(p.Backpack:GetChildren()) do
        if item:IsA("Tool") then
            local tt = item:FindFirstChild("ToolTip") and item.ToolTip.Value or ""
            if item.Name:find("Light") or tt == "Blox Fruit" or tt == "Demon Fruit" then
                return item
            end
        end
    end
    return nil
end

local function equipLight(char, hum)
    if not char or not hum then return false end
    local light = getLightTool()
    if light then
        if light.Parent == char then
            return true
        else
            hum:EquipTool(light)
            return true
        end
    end
    return false
end

-- Отмена текущего квеста
local function abandonQuest()
    pcall(function()
        CommF:InvokeServer("AbandonQuest")
    end)
end

local function takeQuest(questName, questLevel)
    pcall(function()
        local questGui = p:FindFirstChild("PlayerGui") and p.PlayerGui:FindFirstChild("Main") and p.PlayerGui.Main:FindFirstChild("Quest")
        if not (questGui and questGui.Visible) then
            CommF:InvokeServer("StartQuest", questName, questLevel)
        end
    end)
end

local function getActiveQuestMob()
    local questGui = p:FindFirstChild("PlayerGui") and p.PlayerGui:FindFirstChild("Main") and p.PlayerGui.Main:FindFirstChild("Quest")
    if questGui and questGui.Visible then
        for _, v in pairs(questGui:GetDescendants()) do
            if v:IsA("TextLabel") and v.Visible and v.Text ~= "" then
                local txt = v.Text
                if txt:find("Defeat") or txt:find("Убить") or txt:find("%(%d+/%d+%)") then
                    if txt:find("Gorilla King") then return "Gorilla King" end
                    if txt:find("Gorilla") then return "Gorilla" end
                    if txt:find("Monkey") then return "Monkey" end
                end
            end
        end
    end
    return nil
end

-- Динамический выбор квеста (проверяет наличие Босса)
local function getTargetQuestData()
    local myLevel = 10
    pcall(function()
        if p:FindFirstChild("Data") and p.Data:FindFirstChild("Level") then
            myLevel = p.Data.Level.Value
        end
    end)

    local jungleQuests = Islands["Jungle"].Quests

    if myLevel >= 20 then
        -- Берём квест на Короля только если он сейчас жив
        if isMobAlive("Gorilla King") then
            return jungleQuests[1]
        else
            return jungleQuests[2] -- Обычные горилы
        end
    elseif myLevel >= 15 then
        return jungleQuests[2]
    else
        return jungleQuests[3]
    end
end

local function getEnemy(mobName, fallbackMob, hrp)
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil end

    local target, minDist = nil, math.huge
    local fallbackTarget, fallbackMinDist = nil, math.huge

    for _, m in pairs(enemiesFolder:GetChildren()) do
        local mHum = m:FindFirstChild("Humanoid")
        local mHrp = m:FindFirstChild("HumanoidRootPart")

        if mHum and mHrp and mHum.Health > 0 then
            local dist = (hrp.Position - mHrp.Position).Magnitude

            if m.Name:find(mobName) then
                local isKing = m.Name:find("King")
                if mobName == "Gorilla" and isKing then
                    -- пропуск босса, если квест на обычных мобов
                else
                    if dist < minDist then
                        minDist = dist
                        target = m
                    end
                end
            end

            if fallbackMob and m.Name:find(fallbackMob) and not m.Name:find("King") then
                if dist < fallbackMinDist then
                    fallbackMinDist = dist
                    fallbackTarget = m
                end
            end
        end
    end

    return target or fallbackTarget
end

-- Фоновый поток (крутка фруктов и прокачка)
task.spawn(function()
    while getgenv().Farm do
        autoStoreAllFruits()
        autoAddStats()

        local currentTime = os.time()
        if currentTime - lastFruitSpin >= 7200 or lastFruitSpin == 0 then
            pcall(function()
                CommF:InvokeServer("Cousin", "Buy")
                lastFruitSpin = os.time()
                task.wait(1)
                autoStoreAllFruits()
            end)
        end
        task.wait(3)
    end
end)

-- Плавный поворот камеры на цель
getgenv().FarmConnection = RunService.RenderStepped:Connect(function()
    if not getgenv().Farm then return end
    if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
        local mHum = currentTarget:FindFirstChild("Humanoid")
        if not mHum or mHum.Health <= 0 then
            currentTarget = nil
            return
        end
        local mPos = currentTarget.HumanoidRootPart.Position
        cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, mPos + Vector3.new(0, 2.5, 0)), 0.15)
    end
end)

-- Основной цикл фарминга
task.spawn(function()
    while getgenv().Farm do
        task.wait(0.05)
        pcall(function()
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")

            if not hrp or not hum or hum.Health <= 0 then 
                currentTarget = nil
                return 
            end

            hum.AutoRotate = true

            -- Отступ при низком Здоровье
            if hum.Health < hum.MaxHealth * 0.35 then
                isRecoveringHP = true
            elseif hum.Health >= hum.MaxHealth * 0.85 then
                isRecoveringHP = false
            end

            if isRecoveringHP then
                currentTarget = nil
                local qData = getTargetQuestData()
                local enemy = getEnemy(qData.Mob, qData.Mob, hrp)

                if enemy and enemy:FindFirstChild("HumanoidRootPart") then
                    local eHrp = enemy.HumanoidRootPart
                    local fleeDir = (hrp.Position - eHrp.Position).Unit
                    local fleePos = hrp.Position + Vector3.new(fleeDir.X * 45, 0, fleeDir.Z * 45)
                    hum:MoveTo(fleePos)
                end
                return
            end

            equipLight(char, hum)

            local currentQuestData = getTargetQuestData()
            local activeMob = getActiveQuestMob()

            -- Сброс квеста Короля, если он отсутствует на карте
            if activeMob == "Gorilla King" and not isMobAlive("Gorilla King") then
                abandonQuest()
                task.wait(0.3)
                activeMob = nil
            end

            -- Взятие соответствующего квеста
            if not activeMob then
                takeQuest(currentQuestData.Name, currentQuestData.Level)
                task.wait(0.2)
                activeMob = getActiveQuestMob()
            end

            currentTarget = getEnemy(activeMob or currentQuestData.Mob, currentQuestData.Mob, hrp)

            if not currentTarget and Waypoints[activeMob or currentQuestData.Mob] then
                hum:MoveTo(Waypoints[activeMob or currentQuestData.Mob])
            end

            -- Движение к цели
            if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
                local mHrp = currentTarget.HumanoidRootPart
                local mHum = currentTarget:FindFirstChild("Humanoid")
                local dist = (hrp.Position - mHrp.Position).Magnitude

                if dist > 5 then
                    hum:MoveTo(mHrp.Position)
                    local movedDist = (hrp.Position - lastHrpPos).Magnitude
                    if movedDist < 0.4 then
                        stuckTimer = stuckTimer + 0.05
                        if stuckTimer >= 0.3 then doubleJump() end
                    else
                        stuckTimer = 0
                    end
                    lastHrpPos = hrp.Position
                else
                    stuckTimer = 0
                    lastHrpPos = hrp.Position
                end

                local now = tick()
                if dist > 10 and dist < 35 then
                    if now - lastDashTime >= 1.0 then
                        lastDashTime = now
                        pressKey(Enum.KeyCode.Q, 0x51)
                    end
                end

                -- Полная ротация скиллов (Z, X, C, V, F)
                if dist <= 15 and mHum and mHum.Health > 0 then
                    if now - lastZTime >= 3.5 then
                        lastZTime = now
                        pressKey(Enum.KeyCode.Z, 0x5A)
                    elseif now - lastXTime >= 5.5 then
                        lastXTime = now
                        pressKey(Enum.KeyCode.X, 0x58)
                    elseif now - lastCTime >= 7.5 then
                        lastCTime = now
                        pressKey(Enum.KeyCode.C, 0x43)
                    elseif now - lastVTime >= 12.0 then
                        lastVTime = now
                        pressKey(Enum.KeyCode.V, 0x56)
                    elseif now - lastFTime >= 10.0 then
                        lastFTime = now
                        pressKey(Enum.KeyCode.F, 0x46)
                    else
                        local centerX = cam.ViewportSize.X / 2
                        local centerY = cam.ViewportSize.Y / 2
                        VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
                        VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
                    end
                end
            end

            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Swimming then hum.Jump = true end

            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {char}
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            local wall = workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 4, rayParams)
            if wall then doubleJump() end
        end)
    end
end)

print("🛡️ Скрипт обновлен: оптимизирован выбор квестов Джунглей и добавлены все скиллы (Z, X, C, V, F).")
