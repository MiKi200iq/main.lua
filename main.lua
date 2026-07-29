getgenv().Farm = not getgenv().Farm

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local p = Players.LocalPlayer
local cam = workspace.CurrentCamera
local CommF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

local currentTarget = nil
local lastFruitSpin = 0 -- Время последнего кручения фрукта

-- 1. Таблица обычных квестов (1 Море)
local Quests = {
    {Min = 1,   Max = 9,   Name = "BanditQuest1",  Level = 1, Mob = "Bandit"},
    {Min = 10,  Max = 14,  Name = "JungleQuest",   Level = 1, Mob = "Monkey"},
    {Min = 15,  Max = 29,  Name = "JungleQuest",   Level = 2, Mob = "Gorilla"},
    {Min = 30,  Max = 39,  Name = "PirateQuest",   Level = 1, Mob = "Pirate"},
    {Min = 40,  Max = 59,  Name = "PirateQuest",   Level = 2, Mob = "Brute"},
    {Min = 60,  Max = 89,  Name = "DesertQuest",   Level = 1, Mob = "Desert Bandit"},
    {Min = 90,  Max = 119, Name = "SnowQuest",     Level = 1, Mob = "Snow Bandit"},
}

-- 2. Таблица Боссов и их квестов
local Bosses = {
    ["The Gorilla King"] = {Quest = "JungleQuest", Level = 3},
    ["Bobby"]            = {Quest = "PirateQuest", Level = 3},
    ["The Saw"]          = {Quest = "SawQuest",    Level = 1},
    ["Yeti"]             = {Quest = "SnowQuest",   Level = 3},
    ["Mob Leader"]       = {Quest = "MobLeaderQuest", Level = 1},
    ["Vice Admiral"]     = {Quest = "MarineQuest2", Level = 2},
    ["Wysper"]           = {Quest = "SkyExp1Quest", Level = 3},
    ["Thunder God"]      = {Quest = "SkyExp2Quest", Level = 3},
    ["Cyborg"]           = {Quest = "FountainQuest", Level = 3},
}

-- Функция выбивания случайного фрукта у Cousin (раз в 2 часа)
local function trySpinFruit()
    local currentTime = os.time()
    -- 7200 секунд = 2 часа
    if currentTime - lastFruitSpin >= 7200 or lastFruitSpin == 0 then
        pcall(function()
            local response = CommF:InvokeServer("Cousin", "Buy")
            if response then
                print("[Auto-Farm] Выбит фрукт или куплен случайный фрукт!")
                lastFruitSpin = os.time()
            end
        end)
    end
end

-- Взятие квеста через сервер
local function takeQuest(questName, questLevel)
    local questGui = p:FindFirstChild("PlayerGui") and p.PlayerGui:FindFirstChild("Main") and p.PlayerGui.Main:FindFirstChild("Quest")
    if not (questGui and questGui.Visible) then
        CommF:InvokeServer("StartQuest", questName, questLevel)
    end
end

-- Поиск спавна босса на сервере
local function findActiveBoss(hrp)
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil, nil end

    for bossName, bossInfo in pairs(Bosses) do
        local boss = enemiesFolder:FindFirstChild(bossName)
        if boss then
            local bHum = boss:FindFirstChild("Humanoid")
            local bHrp = boss:FindFirstChild("HumanoidRootPart")
            if bHum and bHrp and bHum.Health > 0 then
                return boss, bossInfo
            end
        end
    end
    return nil, nil
end

-- Поиск обычного моба под уровень
local function getCurrentQuestData()
    local myLevel = p:FindFirstChild("Data") and p.Data:FindFirstChild("Level") and p.Data.Level.Value or 1
    for _, q in ipairs(Quests) do
        if myLevel >= q.Min and myLevel <= q.Max then
            return q
        end
    end
    return nil
end

local function getQuestEnemy(mobName, hrp)
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil, math.huge end

    local target, minDist = nil, math.huge
    for _, m in pairs(enemiesFolder:GetChildren()) do
        local mHum = m:FindFirstChild("Humanoid")
        local mHrp = m:FindFirstChild("HumanoidRootPart")
        if m.Name == mobName and mHum and mHrp and mHum.Health > 0 then
            local dist = (hrp.Position - mHrp.Position).Magnitude
            if dist < minDist then
                minDist = dist
                target = m
            end
        end
    end
    return target, minDist
end

-- Отключаем RenderStepped при переключении
if getgenv().FarmConnection then
    getgenv().FarmConnection:Disconnect()
    getgenv().FarmConnection = nil
end

-- 1. Наведение камеры на цель
if getgenv().Farm then
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

    -- 2. ОСНОВНОЙ ЦИКЛ ФАРМА
    task.spawn(function()
        while getgenv().Farm do
            task.wait(0.05)
            pcall(function()
                local char = p.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")
                if not hrp or not hum or hum.Health <= 0 then return end

                hum.AutoRotate = true

                -- Проверка 1: Авто-выбивание фрукта (раз в 2 часа)
                trySpinFruit()

                -- Экипировка оружия
                if not char:FindFirstChildOfClass("Tool") then
                    for _, t in pairs(p.Backpack:GetChildren()) do
                        if t:IsA("Tool") then
                            hum:EquipTool(t)
                            break
                        end
                    end
                end

                -- Проверка 2: Есть ли заспавненный БОСС на карте?
                local activeBoss, bossInfo = findActiveBoss(hrp)

                if activeBoss and bossInfo then
                    -- Если босс найден — берем квест на босса и фармим его
                    takeQuest(bossInfo.Quest, bossInfo.Level)
                    currentTarget = activeBoss
                else
                    -- Проверка 3: Если босса нет — фармим обычные квесты
                    local qData = getCurrentQuestData()
                    if qData then
                        takeQuest(qData.Name, qData.Level)
                        local mobName = qData.Mob
                        if mobName then
                            currentTarget, _ = getQuestEnemy(mobName, hrp)
                        end
                    end
                end

                -- Логика передвижения и атаки
                if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
                    local mHrp = currentTarget.HumanoidRootPart
                    local mHum = currentTarget:FindFirstChild("Humanoid")
                    local dist = (hrp.Position - mHrp.Position).Magnitude

                    -- Бег ногами к цели
                    if dist > 3 then
                        hum:MoveTo(mHrp.Position)
                    end

                    -- Преодоление стен
                    local rayParams = RaycastParams.new()
                    rayParams.FilterDescendantsInstances = {char}
                    rayParams.FilterType = Enum.RaycastFilterType.Exclude
                    local wall = workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 4, rayParams)
                    if wall then
                        hum.Jump = true
                    end

                    -- Атака
                    if dist <= 8 and mHum and mHum.Health > 0 then
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                    end
                end
            end)
        end
    end)
end
