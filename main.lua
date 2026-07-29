getgenv().Farm = true

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
local lastZTime = 0
local lastXTime = 0

-- Координаты точек спавна мобов в Джунглях
local Waypoints = {
    ["Monkey"] = Vector3.new(-1600, 36, 150),
    ["Gorilla"] = Vector3.new(-1240, 6, -490),
}

local JungleQuests = {
    {Min = 10, Max = 14, Name = "JungleQuest", Level = 1, Mob = "Monkey"},
    {Min = 15, Max = 99, Name = "JungleQuest", Level = 2, Mob = "Gorilla"},
}

if getgenv().FarmConnection then
    getgenv().FarmConnection:Disconnect()
    getgenv().FarmConnection = nil
end

-- НАДЕЖНОЕ НАЖАТИЕ КЛАВИШ (ДЛЯ DELTA И EXECUTOR-ОВ)
local function pressKey(keyCode, charCode)
    pcall(function()
        -- Метод 1: Через VirtualInputManager
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        
        -- Метод 2: Нативная функция исполнителя (если поддерживается)
        if keypress then keypress(charCode) end
        
        task.wait(0.1) -- Держим кнопку 0.1 секунды, чтобы Blox Fruits успел зафиксировать
        
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
        if keyrelease then keyrelease(charCode) end
    end)
end

-- 🔥 АВТО-ПРОКАЧКА СТАТОВ (Распределяет очки в Меч и Защиту)
local function autoAddStats()
    pcall(function()
        local points = p.Data.Points.Value
        if points and points > 0 then
            -- Вкладываем очки в Sword (Меч) и Defense (Защиту)
            CommF:InvokeServer("AddPoint", "Sword", 1)
            CommF:InvokeServer("AddPoint", "Defense", 1)
        end
    end)
end

-- Авто-сохранение фруктов в инвентарь
local function autoStoreAllFruits()
    pcall(function()
        for _, item in pairs(p.Backpack:GetChildren()) do
            if item:IsA("Tool") and (item.Name:find("Fruit") or item.Name:find("Фрукт")) then
                CommF:InvokeServer("StoreFruit", item.Name, item)
            end
        end
        if p.Character then
            for _, item in pairs(p.Character:GetChildren()) do
                if item:IsA("Tool") and (item.Name:find("Fruit") or item.Name:find("Фрукт")) then
                    CommF:InvokeServer("StoreFruit", item.Name, item)
                end
            end
        end
    end)
end

-- Взятие квеста
local function takeQuest(questName, questLevel)
    pcall(function()
        local questGui = p:FindFirstChild("PlayerGui") and p.PlayerGui:FindFirstChild("Main") and p.PlayerGui.Main:FindFirstChild("Quest")
        if not (questGui and questGui.Visible) then
            CommF:InvokeServer("StartQuest", questName, questLevel)
        end
    end)
end

-- Поиск ТОЛЬКО обычных мобов (без Босса)
local function getEnemy(mobName, hrp)
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil end

    local target, minDist = nil, math.huge
    for _, m in pairs(enemiesFolder:GetChildren()) do
        if m.Name:find(mobName) and not m.Name:find("King") then
            local mHum = m:FindFirstChild("Humanoid")
            local mHrp = m:FindFirstChild("HumanoidRootPart")
            if mHum and mHrp and mHum.Health > 0 then
                local dist = (hrp.Position - mHrp.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    target = m
                end
            end
        end
    end
    return target
end

local function getJungleQuestData()
    local myLevel = p:FindFirstChild("Data") and p.Data:FindFirstChild("Level") and p.Data.Level.Value or 10
    for _, q in ipairs(JungleQuests) do
        if myLevel >= q.Min and myLevel <= q.Max then
            return q
        end
    end
    return JungleQuests[1]
end

-- Фоновый поток для фруктов и авто-статов
task.spawn(function()
    while getgenv().Farm do
        autoStoreAllFruits()
        autoAddStats() -- Прокачка характеристик
        
        local currentTime = os.time()
        if currentTime - lastFruitSpin >= 7200 or lastFruitSpin == 0 then
            pcall(function()
                CommF:InvokeServer("Cousin", "Buy")
                lastFruitSpin = os.time()
                task.wait(1)
                autoStoreAllFruits()
            end)
        end
        task.wait(2)
    end
end)

-- Плавное наведение камеры
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

-- ОСНОВНОЙ ЦИКЛ БОЯ И ДВИЖЕНИЯ
task.spawn(function()
    while getgenv().Farm do
        task.wait(0.04)
        pcall(function()
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            
            if not hrp or not hum or hum.Health <= 0 then 
                currentTarget = nil
                return 
            end

            hum.AutoRotate = true

            -- Экипировка оружия (Катана / Sword)
            if not char:FindFirstChildOfClass("Tool") then
                for _, t in pairs(p.Backpack:GetChildren()) do
                    if t:IsA("Tool") and not t.Name:find("Fruit") then
                        hum:EquipTool(t)
                        break
                    end
                end
            end

            -- Взятие квеста и поиск моба
            local qData = getJungleQuestData()
            takeQuest(qData.Name, qData.Level)
            currentTarget = getEnemy(qData.Mob, hrp)

            -- Бег в точку спавна, если нет мобов рядом
            if not currentTarget and Waypoints[qData.Mob] then
                hum:MoveTo(Waypoints[qData.Mob])
            end

            -- Боевая логика
            if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
                local mHrp = currentTarget.HumanoidRootPart
                local mHum = currentTarget:FindFirstChild("Humanoid")
                local dist = (hrp.Position - mHrp.Position).Magnitude

                if dist > 5 then
                    hum:MoveTo(mHrp.Position)
                end

                local now = tick()

                -- 1. РЫВОК НА Q (при сближении на расстоянии 10-35 студов)
                if dist > 10
                    if now - lastDashTime >= 0.8 then
                        lastDashTime = now
                        pressKey(Enum.KeyCode.Q, 0x51)
                    end
                end

                -- 2. АТАКА И СКИЛЛЫ
                if dist <= 10 and mHum and mHum.Health > 0 then
                    -- Скилл Z (Тихий порыв) — кулдаун 3.5 сек
                    if now - lastZTime >= 3.5 then
                        lastZTime = now
                        pressKey(Enum.KeyCode.Z, 0x5A)
                    -- Скилл X (Воздушный удар) — кулдаун 5.5 сек
                    elseif now - lastXTime >= 5.5 then
                        lastXTime = now
                        pressKey(Enum.KeyCode.X, 0x58)
                    else
                        -- Обычный удар ЛКМ
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                    end
                end
            end

            -- ПЛАВАНИЕ И ПРЕДОТВРАЩЕНИЕ ЗАТРЕВАНИЙ
            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Swimming then
                hum.Jump = true
            end

            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {char}
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            local wall = workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 4, rayParams)
            if wall then
                hum.Jump = true
            end
        end)
    end
end)
