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

-- Высота зависания над мобом (7 студов — оптимально для боя без урона)
local HOVER_HEIGHT = 7

local JungleQuests = {
    {Min = 10, Max = 14, Name = "JungleQuest", Level = 1, Mob = "Monkey"},
    {Min = 15, Max = 99, Name = "JungleQuest", Level = 2, Mob = "Gorilla"},
}

if getgenv().FarmConnection then
    getgenv().FarmConnection:Disconnect()
    getgenv().FarmConnection = nil
end

-- Автоматическое удерживание тела в воздухе без падения
local function applyFloat(hrp)
    local bv = hrp:FindFirstChild("AirFarmBV")
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "AirFarmBV"
        bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = hrp
    end
    return bv
end

local function removeFloat(hrp)
    if hrp and hrp:FindFirstChild("AirFarmBV") then
        hrp.AirFarmBV:Destroy()
    end
end

-- Мгновенное сохранение фруктов
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

-- 1. Выбивание и прятание фруктов в фоновом режиме
task.spawn(function()
    while getgenv().Farm do
        autoStoreAllFruits()
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

-- 2. ОСНОВНОЙ ЦИКЛ БЕЗОПАСНОГО ФАРМА В ВОЗДУХЕ
task.spawn(function()
    while getgenv().Farm do
        task.wait(0.03)
        pcall(function()
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            
            if not hrp or not hum or hum.Health <= 0 then 
                currentTarget = nil
                return 
            end

            -- Экипировка боевого оружия
            if not char:FindFirstChildOfClass("Tool") then
                for _, t in pairs(p.Backpack:GetChildren()) do
                    if t:IsA("Tool") and not t.Name:find("Fruit") then
                        hum:EquipTool(t)
                        break
                    end
                end
            end

            -- Получаем текущий квест и ищем моба
            local qData = getJungleQuestData()
            takeQuest(qData.Name, qData.Level)
            currentTarget = getEnemy(qData.Mob, hrp)

            -- 🔥 ФАРМ В ВОЗДУХЕ
            if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
                local mHrp = currentTarget.HumanoidRootPart
                local mHum = currentTarget:FindFirstChild("Humanoid")

                -- Фиксируем позицию персонажа РОВНО НАД МОБОМ
                local hoverPos = mHrp.Position + Vector3.new(0, HOVER_HEIGHT, 0)
                hrp.CFrame = CFrame.new(hoverPos, mHrp.Position)
                
                -- Держим физику в воздухе
                applyFloat(hrp)

                -- Атакуем вниз по мобу
                if mHum and mHum.Health > 0 then
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end
            else
                -- Если моба нет, убираем фиксацию воздуха
                removeFloat(hrp)
            end
        end)
    end
end)
