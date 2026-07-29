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

-- Квесты Джунглей и босс
local JungleQuests = {
    {Min = 10, Max = 14, Name = "JungleQuest", Level = 1, Mob = "Monkey"},
    {Min = 15, Max = 99, Name = "JungleQuest", Level = 2, Mob = "Gorilla"},
}

-- Функция покупки и прятания фрукта в инвентарь
local function trySpinAndStoreFruit()
    local currentTime = os.time()
    if currentTime - lastFruitSpin >= 7200 or lastFruitSpin == 0 then
        pcall(function()
            -- 1. Выбиваем фрукт у торговца в Джунглях
            local result = CommF:InvokeServer("Cousin", "Buy")
            lastFruitSpin = os.time()
            
            -- 2. Если фрукт получен — сразу убираем его в хранилище (Store)
            task.wait(1)
            for _, item in pairs(p.Backpack:GetChildren()) do
                if item:IsA("Tool") and item.Name:find("Fruit") then
                    CommF:InvokeServer("StoreFruit", item.Name, item)
                end
            end
            if p.Character:FindFirstChildOfClass("Tool") and p.Character:FindFirstChildOfClass("Tool").Name:find("Fruit") then
                local tool = p.Character:FindFirstChildOfClass("Tool")
                CommF:InvokeServer("StoreFruit", tool.Name, tool)
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

-- Поиск спавна Короля Горилл
local function checkGorillaKing()
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil end

    local boss = enemiesFolder:FindFirstChild("The Gorilla King")
    if boss then
        local bHum = boss:FindFirstChild("Humanoid")
        local bHrp = boss:FindFirstChild("HumanoidRootPart")
        if bHum and bHrp and bHum.Health > 0 then
            return boss
        end
    end
    return nil
end

-- Поиск обычных мобов в Джунглях
local function getJungleQuestData()
    local myLevel = p:FindFirstChild("Data") and p.Data:FindFirstChild("Level") and p.Data.Level.Value or 10
    for _, q in ipairs(JungleQuests) do
        if myLevel >= q.Min and myLevel <= q.Max then
            return q
        end
    end
    return JungleQuests[1]
end

local function getEnemy(mobName, hrp)
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil end

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
    return target
end

-- Отключение старого потока
if getgenv().FarmConnection then
    getgenv().FarmConnection:Disconnect()
    getgenv().FarmConnection = nil
end

-- 1. Наведение камеры
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

    -- 2. Основной поток автофарма
    task.spawn(function()
        while getgenv().Farm do
            task.wait(0.04)
            pcall(function()
                local char = p.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")
                if not hrp or not hum or hum.Health <= 0 then return end

                hum.AutoRotate = true

                -- Проверка кручения фрукта у Cousin
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

                -- Проверяем Короля Горилл
                local boss = checkGorillaKing()

                if boss then
                    takeQuest("JungleQuest", 3) -- Квест на Короля Горилл
                    currentTarget = boss
                else
                    -- Если босса нет — фармим обычные квесты Джунглей
                    local qData = getJungleQuestData()
                    takeQuest(qData.Name, qData.Level)
                    currentTarget = getEnemy(qData.Mob, hrp)
                end

                -- Движение ногами и атака
                if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
                    local mHrp = currentTarget.HumanoidRootPart
                    local mHum = currentTarget:FindFirstChild("Humanoid")
                    local dist = (hrp.Position - mHrp.Position).Magnitude

                    if dist > 3 then
                        hum:MoveTo(mHrp.Position)
                    end

                    -- Преодоление ступеней и деревьев Джунглей
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
end
