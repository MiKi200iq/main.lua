getgenv().Farm = not getgenv().Farm

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local p = Players.LocalPlayer
local cam = workspace.CurrentCamera
local CommF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")

local currentTarget = nil
local lastFruitSpin = 0

-- Координаты спавна
local Waypoints = {
    ["Monkey"] = Vector3.new(-1600, 36, 150),
    ["Gorilla"] = Vector3.new(-1240, 6, -490),
    ["GorillaKing"] = Vector3.new(-1130, 14, -480)
}

local JungleQuests = {
    {Min = 10, Max = 14, Name = "JungleQuest", Level = 1, Mob = "Monkey"},
    {Min = 15, Max = 99, Name = "JungleQuest", Level = 2, Mob = "Gorilla"},
}

-- Выбивание и прятание фрукта
local function trySpinAndStoreFruit()
    local currentTime = os.time()
    if currentTime - lastFruitSpin >= 7200 or lastFruitSpin == 0 then
        pcall(function()
            CommF:InvokeServer("Cousin", "Buy")
            lastFruitSpin = os.time()
            task.wait(1)
            for _, item in pairs(p.Backpack:GetChildren()) do
                if item:IsA("Tool") and item.Name:find("Fruit") then
                    CommF:InvokeServer("StoreFruit", item.Name, item)
                end
            end
        end)
    end
end

-- Взятие квеста
local function takeQuest(questName, questLevel)
    local questGui = p:FindFirstChild("PlayerGui") and p.PlayerGui:FindFirstChild("Main") and p.PlayerGui.Main:FindFirstChild("Quest")
    if not (questGui and questGui.Visible) then
        CommF:InvokeServer("StartQuest", questName, questLevel)
    end
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

-- Поиск обычных мобов
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

-- Отключение старой подписки
if getgenv().FarmConnection then
    getgenv().FarmConnection:Disconnect()
    getgenv().FarmConnection = nil
end

-- 1. Плавная камера
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

    -- 2. Логика боя с защитой при смерти
    task.spawn(function()
        while getgenv().Farm do
            task.wait(0.04)
            pcall(function()
                local char = p.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")
                
                -- Если персонаж умер — ждем спавна
                if not hrp or not hum or hum.Health <= 0 then 
                    currentTarget = nil
                    task.wait(2)
                    return 
                end

                hum.AutoRotate = true

                -- Проверка кручения фрукта
                trySpinAndStoreFruit()

                -- Экипировка оружия
                if not char:FindFirstChildOfClass("Tool") then
                    for _, t in pairs(p.Backpack:GetChildren()) do
                        if t:IsA("Tool") then
                            hum:EquipTool(t)
                            break
                        end
                    end
                end

                -- Поиск целей
                local boss = checkGorillaKing()
                local isBossFight = false

                if boss then
                    takeQuest("JungleQuest", 3)
                    currentTarget = boss
                    isBossFight = true
                else
                    local qData = getJungleQuestData()
                    takeQuest(qData.Name, qData.Level)
                    currentTarget = getEnemy(qData.Mob, hrp)

                    if not currentTarget and Waypoints[qData.Mob] then
                        hum:MoveTo(Waypoints[qData.Mob])
                    end
                end

                -- Движение и атака
                if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
                    local mHrp = currentTarget.HumanoidRootPart
                    local mHum = currentTarget:FindFirstChild("Humanoid")
                    local dist = (hrp.Position - mHrp.Position).Magnitude

                    -- Бег к цели (останавливаемся чуть дальше на 5 студах)
                    if dist > 5 then
                        hum:MoveTo(mHrp.Position)
                    end

                    -- Авто-уклонение при бое с БОССОМ (постоянные прыжки от ударов по земле)
                    if isBossFight and dist <= 12 then
                        hum.Jump = true
                    else
                        -- Обычный прыжок через препятствия
                        local rayParams = RaycastParams.new()
                        rayParams.FilterDescendantsInstances = {char}
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        local wall = workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 4, rayParams)
                        if wall then
                            hum.Jump = true
                        end
                    end

                    -- Удар
                    if dist <= 9 and mHum and mHum.Health > 0 then
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                    end
                end
            end)
        end
    end)
end
