-- Удаляем старое меню при перезапуске
if game:GetService("CoreGui"):FindFirstChild("FarmHUD") then
    game:GetService("CoreGui"):FindFirstChild("FarmHUD"):Destroy()
end

getgenv().Farm = false
getgenv().SelectedIsland = "Starter"

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

local lastZTime, lastXTime, lastCTime, lastVTime, lastFTime = 0, 0, 0, 0, 0
local lastHrpPos = Vector3.new(0, 0, 0)
local stuckTimer = 0

-- ТОЧНЫЕ КВЕСТЫ И КООРДИНАТЫ (Подтверждено логами `PirateTownQuest`)
local IslandsData = {
    ["Starter"] = {
        Name = "Начальный",
        QuestNPC = Vector3.new(1060, 16, 1545),
        Quests = {
            {Req = 1, Name = "BanditQuest", Level = 1, Mob = "Bandit"}
        },
        Waypoints = {
            ["Bandit"] = Vector3.new(1050, 16, 1400)
        }
    },
    ["Jungle"] = {
        Name = "Джунгли",
        QuestNPC = Vector3.new(-1600, 36, 150),
        Quests = {
            {Req = 20, Name = "JungleQuest", Level = 3, Mob = "Gorilla King"},
            {Req = 15, Name = "JungleQuest", Level = 2, Mob = "Gorilla"},
            {Req = 10, Name = "JungleQuest", Level = 1, Mob = "Monkey"},
        },
        Waypoints = {
            ["Monkey"] = Vector3.new(-1600, 36, 150),
            ["Gorilla"] = Vector3.new(-1240, 6, -490),
            ["Gorilla King"] = Vector3.new(-1130, 15, -490),
        }
    },
    ["Pirate"] = {
        Name = "Пираты",
        QuestNPC = Vector3.new(-1140, 4, 3830),
        Quests = {
            {Req = 55, Name = "PirateTownQuest", Level = 3, Mob = "Bobby"},
            {Req = 40, Name = "PirateTownQuest", Level = 2, Mob = "Brute"},
            {Req = 30, Name = "PirateTownQuest", Level = 1, Mob = "Pirate"},
        },
        Waypoints = {
            ["Pirate"] = Vector3.new(-1215, 15, 3910),
            ["Brute"] = Vector3.new(-1145, 15, 3780),
            ["Bobby"] = Vector3.new(-1130, 15, 4080),
        }
    }
}

---------------------------------------------------------
-- СОЗДАНИЕ ГРАФИЧЕСКОГО ИНТЕРФЕЙСА (HUD)
---------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FarmHUD"
ScreenGui.ResetOnSpawn = false

local parentContainer = game:GetService("CoreGui") or p:WaitForChild("PlayerGui")
ScreenGui.Parent = parentContainer

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 320, 0, 220)
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 38)
Title.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
Title.Text = "  🛡️ Blox Fruits Auto Farm"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.Font = Enum.Font.SourceSansBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = Title

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -32, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "❌"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.TextSize = 12
CloseBtn.Parent = Title

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0.92, 0, 0, 38)
ToggleBtn.Position = UDim2.new(0.04, 0, 0.23, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
ToggleBtn.Text = "ФАРМ: ВЫКЛ"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 15
ToggleBtn.Font = Enum.Font.SourceSansBold
ToggleBtn.Parent = MainFrame

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 8)
ToggleCorner.Parent = ToggleBtn

local IslandFrame = Instance.new("Frame")
IslandFrame.Size = UDim2.new(0.92, 0, 0, 36)
IslandFrame.Position = UDim2.new(0.04, 0, 0.46, 0)
IslandFrame.BackgroundTransparency = 1
IslandFrame.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.FillDirection = Enum.FillDirection.Horizontal
UIList.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0.02, 0)
UIList.Parent = IslandFrame

local IslandButtons = {}

local function createIslandBtn(id, label, order)
    local btn = Instance.new("TextButton")
    btn.Name = id .. "Btn"
    btn.Size = UDim2.new(0.31, 0, 1, 0)
    btn.LayoutOrder = order
    btn.Text = label
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.Font = Enum.Font.SourceSansBold
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    btn.Parent = IslandFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        getgenv().SelectedIsland = id
        updateUI()
    end)

    IslandButtons[id] = btn
end

createIslandBtn("Starter", "🏝️ Начальный", 1)
createIslandBtn("Jungle", "🌴 Джунгли", 2)
createIslandBtn("Pirate", "🏴‍☠️ Пираты", 3)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0.92, 0, 0, 30)
StatusLabel.Position = UDim2.new(0.04, 0, 0.72, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Остров: Начальный | Фарм остановлен"
StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
StatusLabel.TextSize = 12
StatusLabel.Font = Enum.Font.SourceSans
StatusLabel.Parent = MainFrame

function updateUI()
    if getgenv().Farm then
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 165, 80)
        ToggleBtn.Text = "ФАРМ: ВКЛ"
        StatusLabel.Text = "Остров: " .. IslandsData[getgenv().SelectedIsland].Name .. " | Активен"
    else
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        ToggleBtn.Text = "ФАРМ: ВЫКЛ"
        StatusLabel.Text = "Остров: " .. IslandsData[getgenv().SelectedIsland].Name .. " | Остановлен"
    end

    for id, btn in pairs(IslandButtons) do
        if id == getgenv().SelectedIsland then
            btn.BackgroundColor3 = Color3.fromRGB(60, 130, 240)
        else
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        end
    end
end

ToggleBtn.MouseButton1Click:Connect(function()
    getgenv().Farm = not getgenv().Farm
    updateUI()
end)

CloseBtn.MouseButton1Click:Connect(function()
    getgenv().Farm = false
    if getgenv().FarmConnection then
        getgenv().FarmConnection:Disconnect()
        getgenv().FarmConnection = nil
    end
    ScreenGui:Destroy()
end)

updateUI()

---------------------------------------------------------
-- ВСПАТЫВАНИЕ КВЕСТОВ И ФАРМ
---------------------------------------------------------
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

local function getSafeFleePos(hrpPos, enemyPos)
    local baseDir = (hrpPos - enemyPos).Unit
    local angles = {0, 45, -45, 90, -90, 135, -135, 180}

    for _, angle in ipairs(angles) do
        local rad = math.rad(angle)
        local cosA, sinA = math.cos(rad), math.sin(rad)
        local dirX = baseDir.X * cosA - baseDir.Z * sinA
        local dirZ = baseDir.X * sinA + baseDir.Z * cosA
        local testPos = hrpPos + Vector3.new(dirX * 40, 0, dirZ * 40)

        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {p.Character}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude

        local rayResult = workspace:Raycast(testPos + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), rayParams)
        if rayResult and rayResult.Material ~= Enum.Material.Water then
            return rayResult.Position + Vector3.new(0, 2.5, 0)
        end
    end
    return nil
end

local function isMobAlive(mobName)
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return false end
    for _, m in pairs(enemiesFolder:GetChildren()) do
        if m.Name:find(mobName) then
            local mHum = m:FindFirstChild("Humanoid")
            if mHum and mHum.Health > 0 then return true end
        end
    end
    return false
end

local function autoAddStats()
    pcall(function()
        local points = p.Data.Points.Value
        if points and points > 0 then
            CommF:InvokeServer("AddPoint", "Demon Fruit", 1)
            CommF:InvokeServer("AddPoint", "Defense", 1)
        end
    end)
end

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

local function getWeaponTool()
    if p.Character then
        for _, item in pairs(p.Character:GetChildren()) do
            if item:IsA("Tool") then return item end
        end
    end
    for _, item in pairs(p.Backpack:GetChildren()) do
        if item:IsA("Tool") then return item end
    end
    return nil
end

local function equipWeapon(char, hum)
    if not char or not hum then return false end
    local weapon = getWeaponTool()
    if weapon then
        if weapon.Parent ~= char then hum:EquipTool(weapon) end
        return true
    end
    return false
end

local function abandonQuest()
    pcall(function() CommF:InvokeServer("AbandonQuest") end)
end

-- ПРОВЕРКА АКТИВНОГО КВЕСТА В ИНТЕРФЕЙСЕ
local function getActiveQuestMob()
    local questGui = p:FindFirstChild("PlayerGui") and p.PlayerGui:FindFirstChild("Main") and p.PlayerGui.Main:FindFirstChild("Quest")
    if questGui and (questGui.Visible or questGui:FindFirstChild("Container")) then
        for _, v in pairs(questGui:GetDescendants()) do
            if v:IsA("TextLabel") and v.Text ~= "" then
                local txt = v.Text
                if txt:find("Defeat") or txt:find("Убить") or txt:find("%(%d+/%d+%)") or txt:find("0/") or txt:find("1/") or txt:find("2/") or txt:find("3/") or txt:find("4/") or txt:find("5/") then
                    if txt:find("Gorilla King") then return "Gorilla King" end
                    if txt:find("Gorilla") then return "Gorilla" end
                    if txt:find("Monkey") then return "Monkey" end
                    if txt:find("Bandit") then return "Bandit" end
                    if txt:find("Bobby") then return "Bobby" end
                    if txt:find("Brute") then return "Brute" end
                    if txt:find("Pirate") then return "Pirate" end
                end
            end
        end
    end
    return nil
end

local function getTargetQuestData()
    local currentIsland = getgenv().SelectedIsland
    local islandObj = IslandsData[currentIsland]
    local myLevel = 1
    pcall(function() myLevel = p.Data.Level.Value end)

    if currentIsland == "Starter" then
        return islandObj.Quests[1]
    elseif currentIsland == "Jungle" then
        if myLevel >= 20 then
            if isMobAlive("Gorilla King") then return islandObj.Quests[1] else return islandObj.Quests[2] end
        elseif myLevel >= 15 then
            return islandObj.Quests[2]
        else
            return islandObj.Quests[3]
        end
    elseif currentIsland == "Pirate" then
        if myLevel >= 55 then
            if isMobAlive("Bobby") then return islandObj.Quests[1] else return islandObj.Quests[2] end
        elseif myLevel >= 40 then
            return islandObj.Quests[2]
        else
            return islandObj.Quests[3]
        end
    end
end

-- НАДЕЖНОЕ ВЗЯТИЕ КВЕСТА
local function safeTakeQuest(questName, questLevel, npcPos, hum, hrp)
    local active = getActiveQuestMob()
    if not active then
        local distToNpc = (hrp.Position - npcPos).Magnitude
        
        -- Если далеко от NPC, доходим до него
        if distToNpc > 12 then
            hum:MoveTo(npcPos)
            task.wait(0.1)
        else
            -- Прямой вызов сервера и пауза 0.5с для прорисовки UI
            CommF:InvokeServer("StartQuest", questName, questLevel)
            task.wait(0.5)
        end
    end
end

local function getEnemy(mobName, hrp)
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil end
    local target, minDist = nil, math.huge

    for _, m in pairs(enemiesFolder:GetChildren()) do
        local mHum = m:FindFirstChild("Humanoid")
        local mHrp = m:FindFirstChild("HumanoidRootPart")
        if mHum and mHrp and mHum.Health > 0 then
            local dist = (hrp.Position - mHrp.Position).Magnitude
            if m.Name:find(mobName) then
                if (mobName == "Gorilla" and m.Name:find("King")) or (mobName == "Pirate" and m.Name:find("Brute")) then
                    -- пропуск мобов
                elseif dist < minDist then
                    minDist = dist
                    target = m
                end
            end
        end
    end
    return target
end

-- Рулетка и статы
task.spawn(function()
    while true do
        if getgenv().Farm then
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
        end
        task.wait(3)
    end
end)

-- Камера
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

-- Основной цикл фарма
task.spawn(function()
    while true do
        task.wait(0.05)
        if getgenv().Farm then
            pcall(function()
                local char = p.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")

                if not hrp or not hum or hum.Health <= 0 then 
                    currentTarget = nil
                    return 
                end

                hum.AutoRotate = true

                if hum.Health < hum.MaxHealth * 0.35 then
                    isRecoveringHP = true
                elseif hum.Health >= hum.MaxHealth * 0.85 then
                    isRecoveringHP = false
                end

                if isRecoveringHP then
                    currentTarget = nil
                    local nearestEnemy = nil
                    local minDist = 100
                    local enemiesFolder = workspace:FindFirstChild("Enemies")

                    if enemiesFolder then
                        for _, m in pairs(enemiesFolder:GetChildren()) do
                            local mHum = m:FindFirstChild("Humanoid")
                            local mHrp = m:FindFirstChild("HumanoidRootPart")
                            if mHum and mHrp and mHum.Health > 0 then
                                local dist = (hrp.Position - mHrp.Position).Magnitude
                                if dist < minDist then
                                    minDist = dist
                                    nearestEnemy = m
                                end
                            end
                        end
                    end

                    if nearestEnemy and nearestEnemy:FindFirstChild("HumanoidRootPart") then
                        local safePos = getSafeFleePos(hrp.Position, nearestEnemy.HumanoidRootPart.Position)
                        if safePos then
                            hum:MoveTo(safePos)
                        else
                            local currentWaypoints = IslandsData[getgenv().SelectedIsland].Waypoints
                            local activeData = getTargetQuestData()
                            local fallbackWp = currentWaypoints[activeData.Mob] or hrp.Position
                            hum:MoveTo(fallbackWp)
                        end
                    else
                        hum:MoveTo(hrp.Position)
                    end
                    return
                end

                equipWeapon(char, hum)

                local islandObj = IslandsData[getgenv().SelectedIsland]
                local currentQuestData = getTargetQuestData()
                local activeMob = getActiveQuestMob()

                if (activeMob == "Gorilla King" and not isMobAlive("Gorilla King")) or (activeMob == "Bobby" and not isMobAlive("Bobby")) then
                    abandonQuest()
                    task.wait(0.3)
                    activeMob = nil
                end

                -- Если квеста еще нет в UI, берем его и ждем прорисовки
                if not activeMob then
                    safeTakeQuest(currentQuestData.Name, currentQuestData.Level, islandObj.QuestNPC, hum, hrp)
                    activeMob = getActiveQuestMob()
                    if not activeMob then return end
                end

                local targetMobName = activeMob or currentQuestData.Mob
                currentTarget = getEnemy(targetMobName, hrp)

                local currentWaypoints = islandObj.Waypoints
                if not currentTarget and currentWaypoints[targetMobName] then
                    hum:MoveTo(currentWaypoints[targetMobName])
                end

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
    end
end)
