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
local isRecoveringHP = false

-- Точки спавна в Джунглях
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

-- 🔥 МГНОВЕННОЕ СОХРАНЕНИЕ ЛЮБЫХ ФРУКТОВ ИЗ РЮКЗАКА И РУК
local function autoStoreAllFruits()
    pcall(function()
        -- Проверяем Backpack
        for _, item in pairs(p.Backpack:GetChildren()) do
            if item:IsA("Tool") and (item.Name:find("Fruit") or item.Name:find("Фрукт")) then
                CommF:InvokeServer("StoreFruit", item.Name, item)
            end
        end
        -- Проверяем руки (Character)
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

-- Поиск Короля Горилл
local function checkGorillaKing()
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil end

    for _, m in pairs(enemiesFolder:GetChildren()) do
        if m.Name:find("Gorilla King") then
            local bHum = m:FindFirstChild("Humanoid")
            local bHrp = m:FindFirstChild("HumanoidRootPart")
            if bHum and bHrp and bHum.Health > 0 then
                return m
            end
        end
    end
    return nil
end

-- Поиск мобов
local function getEnemy(mobName, hrp)
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil end

    local target, minDist = nil, math.huge
    for _, m in pairs(enemiesFolder:GetChildren()) do
        local mHum = m:FindFirstChild("Humanoid")
        local mHrp = m:FindFirstChild("HumanoidRootPart")
        if m.Name:find(mobName) and mHum and mHrp and mHum.Health > 0 then
            local dist = (hrp.Position - mHrp.Position).Magnitude
            if dist < minDist then
                minDist = dist
                target = m
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

-- 1. ПОТОК ДЛЯ ВЫБИВАНИЯ И АВТО-СОХРАНЕНИЯ ФРУКТОВ
task.spawn(function()
    while getgenv().Farm do
        autoStoreAllFruits() -- Проверяем каждые 2 секунды

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

-- 2. ПЛАВНАЯ КАМЕРА
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

-- 3. ОСНОВНОЙ ЦИКЛ БЕЗОПАСНОГО ФАРМА
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

            -- 🔥 ЗАЩИТА ОТ СМЕРТИ: Проверка здоровья
            if hum.Health < hum.MaxHealth * 0.4 then
                isRecoveringHP = true
            elseif hum.Health >= hum.MaxHealth * 0.85 then
                isRecoveringHP = false
            end

            -- Если HP мало — ждём регенерации
            if isRecoveringHP then
                currentTarget = nil
                hum:MoveTo(hrp.Position) -- Стоим на месте / отдыхаем
                return
            end

            hum.AutoRotate = true

            -- Экипировка оружия (только боевого, не фруктов)
            if not char:FindFirstChildOfClass("Tool") then
                for _, t in pairs(p.Backpack:GetChildren()) do
                    if t:IsA("Tool") and not t.Name:find("Fruit") then
                        hum:EquipTool(t)
                        break
                    end
                end
            end

            -- Логика выбора цели
            local boss = checkGorillaKing()

            -- Не идем на босса, если наш уровень ниже 25 (чтобы не умирать)
            local myLevel = p:FindFirstChild("Data") and p.Data:FindFirstChild("Level") and p.Data.Level.Value or 1
            
            if boss and myLevel >= 25 then
                takeQuest("JungleQuest", 3)
                currentTarget = boss
            else
                local qData = getJungleQuestData()
                takeQuest(qData.Name, qData.Level)
                currentTarget = getEnemy(qData.Mob, hrp)

                if not currentTarget and Waypoints[qData.Mob] then
                    hum:MoveTo(Waypoints[qData.Mob])
                end
            end

            -- Ходьба и урон
            if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
                local mHrp = currentTarget.HumanoidRootPart
                local mHum = currentTarget:FindFirstChild("Humanoid")
                local dist = (hrp.Position - mHrp.Position).Magnitude

                if dist > 5 then
                    hum:MoveTo(mHrp.Position)
                end

                -- Преодоление препятствий
                local rayParams = RaycastParams.new()
                rayParams.FilterDescendantsInstances = {char}
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                local wall = workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 4, rayParams)
                if wall then
                    hum.Jump = true
                end

                -- Удар
                if dist <= 8 and mHum and mHum.Health > 0 then
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end
            end
        end)
    end
end)
