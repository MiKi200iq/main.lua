getgenv().Farm = true
getgenv().WeaponType = "Hybrid" -- "Hybrid" (Меч + Скиллы фрукта) или "Sword" (Только Меч)

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
local lastZTime = tick()
local lastXTime = tick()
local lastCTime = tick()
local isRecoveringHP = false

local lastHrpPos = Vector3.new(0, 0, 0)
local stuckTimer = 0

-- ТОЧКИ СПАВНА МОБОВ
local Waypoints = {
    -- Джунгли
    ["Monkey"] = Vector3.new(-1600, 36, 150),
    ["Gorilla"] = Vector3.new(-1240, 6, -490),
    ["Gorilla King"] = Vector3.new(-1130, 15, -490),
    -- Остров Пиратов
    ["Pirate"] = Vector3.new(-1115, 14, 3850),
    ["Brute"] = Vector3.new(-1145, 15, 4350),
    ["Bobby"] = Vector3.new(-1130, 14, 4080),
}

-- КВЕСТЫ ПО УРОВНЮ
local QuestList = {
    -- Джунгли
    {Min = 10, Max = 14, Name = "JungleQuest", Level = 1, Mob = "Monkey"},
    {Min = 15, Max = 19, Name = "JungleQuest", Level = 2, Mob = "Gorilla"},
    {Min = 20, Max = 29, Name = "JungleQuest", Level = 3, Mob = "Gorilla King"},
    -- Остров Пиратов
    {Min = 30, Max = 39, Name = "BuggyQuest1", Level = 1, Mob = "Pirate"},
    {Min = 40, Max = 54, Name = "BuggyQuest1", Level = 2, Mob = "Brute"},
    {Min = 55, Max = 59, Name = "BuggyQuest1", Level = 3, Mob = "Bobby"},
}

if getgenv().FarmConnection then
    getgenv().FarmConnection:Disconnect()
    getgenv().FarmConnection = nil
end

-- НАДЕЖНОЕ НАЖАТИЕ КЛАВИШ
local function pressKey(keyCode, charCode)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        if keypress then keypress(charCode) end
        task.wait(0.08)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
        if keyrelease then keyrelease(charCode) end
    end)
end

-- ФУНКЦИЯ ДВОЙНОГО ПРЫЖКА
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

-- 🔥 ТОЧНОЕ ОПРЕДЕЛЕНИЕ ТИПА ПРЕДМЕТА
local function isFruitTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local tt = tool:FindFirstChild("ToolTip")
    if tt and tt.Value == "Blox Fruit" then return true end
    local name = tool.Name:lower()
    return name:find("rocket") or name:find("fruit") or name:find("-")
end

local function isSwordTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local tt = tool:FindFirstChild("ToolTip")
    if tt and tt.Value == "Sword" then return true end
    return not isFruitTool(tool)
end

-- НАДЕЖНАЯ ЭКИПИРОВКА ОРУЖИЯ
local function equipSpecificTool(char, hum, category)
    local current = char:FindFirstChildOfClass("Tool")
    if current then
        if category == "Fruit" and isFruitTool(current) then return true end
        if category == "Sword" and isSwordTool(current) then return true end
    end

    for _, t in pairs(p.Backpack:GetChildren()) do
        if t:IsA("Tool") then
            if category == "Fruit" and isFruitTool(t) then
                hum:EquipTool(t)
                return true
            elseif category == "Sword" and isSwordTool(t) then
                hum:EquipTool(t)
                return true
            end
        end
    end
    return false
end

-- АВТО-ПРОКАЧКА СТАТОВ
local function autoAddStats()
    pcall(function()
        local points = p.Data.Points.Value
        if points and points > 0 then
            CommF:InvokeServer("AddPoint", "Sword", 1)
            CommF:InvokeServer("AddPoint", "Defense", 1)
            CommF:InvokeServer("AddPoint", "Demon Fruit", 1)
        end
    end)
end

-- Авто-сохранение физических фруктов из рулетки на склад
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

-- ОПРЕДЕЛЕНИЕ ЦЕЛИ ПО ВИДИМОМУ КВЕСТУ В UI
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
                    if txt:find("Pirate") then return "Pirate" end
                    if txt:find("Brute") then return "Brute" end
                    if txt:find("Bobby") then return "Bobby" end
                end
            end
        end
    end
    return nil
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

-- УМНЫЙ ПОИСК ЦЕЛИ В ПАПКЕ ВРАГОВ
local function getEnemy(mobName, hrp)
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil end

    local target, minDist = nil, math.huge
    for _, m in pairs(enemiesFolder:GetChildren()) do
        if m.Name:find(mobName) then
            local isKing = m.Name:find("King")
            if mobName == "Gorilla" and isKing then
                -- пропускаем Босса Горилл, если квест на обычных горилл
            else
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
    end
    return target
end

-- ПОЛУЧЕНИЕ ДАННЫХ КВЕСТА ПО УРОВНЮ
local function getCurrentQuestData()
    local myLevel = p:FindFirstChild("Data") and p.Data:FindFirstChild("Level") and p.Data.Level.Value or 10
    for _, q in ipairs(QuestList) do
        if myLevel >= q.Min and myLevel <= q.Max then
            return q
        end
    end
    return QuestList[1]
end

-- Фоновый поток для фруктов и статов
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
        task.wait(2)
    end
end)

-- Наведение камеры
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

-- ОСНОВНОЙ ЦИКЛ ФАРМА
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

            -- УБЕГАНИЕ ПРИ НИЗКОМ ЗДОРОВЬЕ (< 35%)
            if hum.Health < hum.MaxHealth * 0.35 then
                isRecoveringHP = true
            elseif hum.Health >= hum.MaxHealth * 0.85 then
                isRecoveringHP = false
            end

            if isRecoveringHP then
                currentTarget = nil
                local targetMob = getActiveQuestMob() or getCurrentQuestData().Mob
                local enemy = getEnemy(targetMob, hrp)
                
                if enemy and enemy:FindFirstChild("HumanoidRootPart") then
                    local eHrp = enemy.HumanoidRootPart
                    local fleeDir = (hrp.Position - eHrp.Position).Unit
                    local fleePos = hrp.Position + Vector3.new(fleeDir.X * 45, 0, fleeDir.Z * 45)
                    
                    hum:MoveTo(fleePos)

                    local now = tick()
                    if now - lastDashTime >= 1.0 then
                        lastDashTime = now
                        pressKey(Enum.KeyCode.Q, 0x51)
                    end
                else
                    hum:MoveTo(hrp.Position)
                end

                local state = hum:GetState()
                if state == Enum.HumanoidStateType.Swimming then hum.Jump = true end
                local rayParams = RaycastParams.new()
                rayParams.FilterDescendantsInstances = {char}
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                if workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 4, rayParams) then
                    doubleJump()
                end

                return
            end

            -- ОПРЕДЕЛЕНИЕ ЦЕЛИ ПО АКТИВНОМУ КВЕСТУ В UI
            local activeMob = getActiveQuestMob()
            
            -- Если задание ещё не взято — берем по уровню
            if not activeMob then
                local qData = getCurrentQuestData()
                takeQuest(qData.Name, qData.Level)
                activeMob = qData.Mob
            end

            -- Ищем моба строго под текущий квест
            currentTarget = getEnemy(activeMob, hrp)

            -- Если моба нет поблизости — ищем на спавне
            if not currentTarget and Waypoints[activeMob] then
                hum:MoveTo(Waypoints[activeMob])
            end

            -- Движение и атака
            if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
                local mHrp = currentTarget.HumanoidRootPart
                local mHum = currentTarget:FindFirstChild("Humanoid")
                local dist = (hrp.Position - mHrp.Position).Magnitude

                if dist > 5 then
                    hum:MoveTo(mHrp.Position)

                    -- ДВОЙНОЙ ПРЫЖОК ПРИ ЗАТРЕВАНИИ
                    local movedDist = (hrp.Position - lastHrpPos).Magnitude
                    if movedDist < 0.4 then
                        stuckTimer = stuckTimer + 0.04
                        if stuckTimer >= 0.25 then
                            doubleJump()
                        end
                    else
                        stuckTimer = 0
                    end
                    lastHrpPos = hrp.Position
                else
                    stuckTimer = 0
                    lastHrpPos = hrp.Position
                end

                local now = tick()

                -- 1. Рывок на Q (при приближении)
                if dist > 10 and dist < 35 then
                    if now - lastDashTime >= 0.8 then
                        lastDashTime = now
                        pressKey(Enum.KeyCode.Q, 0x51)
                    end
                end

                -- 🔥 2. ГИБРИДНАЯ АТАКА (Катана M1 + Короткий свич на Ракету для Z, X, C)
                if dist <= 10 and mHum and mHum.Health > 0 then
                    if getgenv().WeaponType == "Hybrid" then
                        if now - lastZTime >= 4.0 then
                            equipSpecificTool(char, hum, "Fruit")
                            task.wait(0.05)
                            pressKey(Enum.KeyCode.Z, 0x5A)
                            lastZTime = now
                            task.wait(0.08)
                            equipSpecificTool(char, hum, "Sword")
                        elseif now - lastXTime >= 6.0 then
                            equipSpecificTool(char, hum, "Fruit")
                            task.wait(0.05)
                            pressKey(Enum.KeyCode.X, 0x58)
                            lastXTime = now
                            task.wait(0.08)
                            equipSpecificTool(char, hum, "Sword")
                        elseif now - lastCTime >= 8.0 then
                            equipSpecificTool(char, hum, "Fruit")
                            task.wait(0.05)
                            pressKey(Enum.KeyCode.C, 0x43)
                            lastCTime = now
                            task.wait(0.08)
                            equipSpecificTool(char, hum, "Sword")
                        else
                            equipSpecificTool(char, hum, "Sword")
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                        end
                    else
                        equipSpecificTool(char, hum, "Sword")
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                    end
                end
            end

            -- Всплытие в воде и Raycast стен
            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Swimming then
                hum.Jump = true
            end

            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {char}
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            local wall = workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 4, rayParams)
            if wall then
                doubleJump()
            end
        end)
    end
end)
