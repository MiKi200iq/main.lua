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
local lastFruitComboTime = 0
local isUsingFruitCombo = false
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

-- АВТО-ПРОКАЧКА СТАТОВ
local function autoAddStats()
    pcall(function()
        local points = p.Data.Points.Value
        if points and points > 0 then
            CommF:InvokeServer("AddPoint", "Sword", 1)
            CommF:InvokeServer("AddPoint", "Defense", 1)
        end
    end)
end

-- Авто-сохранение физических фруктов на склад
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

-- ЭКИПИРОВКА МЕЧА
local function equipSword(char, hum)
    if not char or not hum then return end
    local current = char:FindFirstChildOfClass("Tool")
    if current and not current.Name:find("Fruit") and not current.Name:find("Rocket") then
        return true
    end
    for _, t in pairs(p.Backpack:GetChildren()) do
        if t:IsA("Tool") and not t.Name:find("Fruit") and not t.Name:find("Rocket") then
            hum:EquipTool(t)
            return true
        end
    end
    return false
end

-- ЭКИПИРОВКА РАКЕТЫ
local function equipRocket(char, hum)
    if not char or not hum then return end
    local current = char:FindFirstChildOfClass("Tool")
    if current and (current.Name:find("Rocket") or current.Name:find("Fruit")) then
        return true
    end
    for _, t in pairs(p.Backpack:GetChildren()) do
        if t:IsA("Tool") and (t.Name:find("Rocket") or t.Name:find("Fruit")) then
            hum:EquipTool(t)
            return true
        end
    end
    return false
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
                -- пропускаем
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

            -- ОПРЕДЕЛЕНИЕ ЦЕЛИ ПО КВЕСТУ В UI
            local activeMob = getActiveQuestMob()
            if not activeMob then
                local qData = getCurrentQuestData()
                takeQuest(qData.Name, qData.Level)
                activeMob = qData.Mob
            end

            currentTarget = getEnemy(activeMob, hrp)

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

                if dist > 10 and dist < 35 then
                    if now - lastDashTime >= 0.8 then
                        lastDashTime = now
                        pressKey(Enum.KeyCode.Q, 0x51)
                    end
                end

                -- 🔥 ПРОВЕРКА: КАЖДЫЕ 7 СЕКУНД БЕРЕМ РАКЕТУ И ПРОЖИМАЕМ СКИЛЛЫ (Z, X, C)
                if dist <= 30 and not isUsingFruitCombo and (now - lastFruitComboTime >= 7.0) then
                    lastFruitComboTime = now
                    isUsingFruitCombo = true

                    task.spawn(function()
                        pcall(function()
                            -- 1. Берем Ракету
                            equipRocket(char, hum)
                            task.wait(0.15)

                            -- 2. Прожимаем скиллы Ракеты
                            pressKey(Enum.KeyCode.Z, 0x5A)
                            task.wait(0.1)
                            pressKey(Enum.KeyCode.X, 0x58)
                            task.wait(0.1)
                            pressKey(Enum.KeyCode.C, 0x43)
                            task.wait(0.2)

                            -- 3. Возвращаем Меч обратно
                            equipSword(char, hum)
                        end)
                        isUsingFruitCombo = false
                    end)
                end

                -- ОСНОВНОЙ БОЙ МЕЧОМ (Если сейчас не идёт прокаст Ракеты)
                if not isUsingFruitCombo and dist <= 10 and mHum and mHum.Health > 0 then
                    equipSword(char, hum)
                    if now - lastZTime >= 4.0 then
                        lastZTime = now
                        pressKey(Enum.KeyCode.Z, 0x5A)
                    elseif now - lastXTime >= 6.0 then
                        lastXTime = now
                        pressKey(Enum.KeyCode.X, 0x58)
                    else
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
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
