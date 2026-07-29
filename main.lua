getgenv().Farm = true
-- 🔥 ВЫБОР ОСТРОВА: "Jungle", "Pirate Village", "Desert" или "Auto"
getgenv().SelectedIsland = "Jungle"

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

local lastZTime = 0
local lastXTime = 0
local lastCTime = 0
local lastVTime = 0

local lastHrpPos = Vector3.new(0, 0, 0)
local stuckTimer = 0

-- ЕДИНАЯ СИСТЕМА ОСТРОВОВ
local Islands = {
    ["Jungle"] = {
        Pos = Vector3.new(-1240, 6, -490),
        Quests = {
            {Req = 20, Name = "JungleQuest", Level = 3, Mob = "Gorilla King", FallbackMob = "Gorilla"},
            {Req = 15, Name = "JungleQuest", Level = 2, Mob = "Gorilla", FallbackMob = "Monkey"},
            {Req = 10, Name = "JungleQuest", Level = 1, Mob = "Monkey", FallbackMob = "Monkey"},
        }
    },
    ["Pirate Village"] = {
        Pos = Vector3.new(-1115, 14, 3850),
        Quests = {
            {Req = 55, Name = "BuggyQuest1", Level = 3, Mob = "Bobby", FallbackMob = "Brute"},
            {Req = 40, Name = "BuggyQuest1", Level = 2, Mob = "Brute", FallbackMob = "Pirate"},
            {Req = 30, Name = "BuggyQuest1", Level = 1, Mob = "Pirate", FallbackMob = "Pirate"},
        }
    },
    ["Desert"] = {
        Pos = Vector3.new(895, 7, 4370),
        Quests = {
            {Req = 75, Name = "DesertQuest", Level = 2, Mob = "Desert Officer", FallbackMob = "Desert Bandit"},
            {Req = 60, Name = "DesertQuest", Level = 1, Mob = "Desert Bandit", FallbackMob = "Desert Bandit"},
        }
    }
}

local Waypoints = {
    ["Monkey"] = Vector3.new(-1600, 36, 150),
    ["Gorilla"] = Vector3.new(-1240, 6, -490),
    ["Gorilla King"] = Vector3.new(-1130, 15, -490),
    ["Pirate"] = Vector3.new(-1115, 14, 3850),
    ["Brute"] = Vector3.new(-1145, 15, 4350),
    ["Bobby"] = Vector3.new(-1130, 14, 4080),
    ["Desert Bandit"] = Vector3.new(895, 7, 4370),
    ["Desert Officer"] = Vector3.new(950, 7, 4450),
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

-- 🔥 ИСПРАВЛЕННЫЙ СБРОС КВЕСТА (без :lower() и безопасный)
local function abandonQuest()
    pcall(function()
        CommF:InvokeServer("AbandonQuest")
        local questGui = p:FindFirstChild("PlayerGui") and p.PlayerGui:FindFirstChild("Main") and p.PlayerGui.Main:FindFirstChild("Quest")
        if questGui then
            for _, v in pairs(questGui:GetDescendants()) do
                if v:IsA("TextButton") then
                    local name = v.Name and string.lower(v.Name) or ""
                    local text = v.Text and string.lower(v.Text) or ""
                    if name:find("cancel") or name:find("abandon") or text:find("отмена") then
                        -- Безопасный вызов события
                        pcall(function()
                            v:Activate()
                        end)
                        pcall(function()
                            if getconnections then
                                for _, conn in pairs(getconnections(v.MouseButton1Click)) do
                                    conn:Fire()
                                end
                            end
                        end)
                    end
                end
            end
        end
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
                    if txt:find("Pirate") then return "Pirate" end
                    if txt:find("Brute") then return "Brute" end
                    if txt:find("Bobby") then return "Bobby" end
                    if txt:find("Desert Officer") then return "Desert Officer" end
                    if txt:find("Desert Bandit") then return "Desert Bandit" end
                end
            end
        end
    end
    return nil
end

local function getTargetIslandData(hrp)
    local targetIslandName = getgenv().SelectedIsland or "Jungle"
    if targetIslandName == "Auto" then
        local minDist = math.huge
        local selected = Islands["Jungle"]
        for _, island in pairs(Islands) do
            local dist = (hrp.Position - island.Pos).Magnitude
            if dist < minDist then
                minDist = dist
                selected = island
            end
        end
        return selected
    end
    return Islands[targetIslandName] or Islands["Jungle"]
end

local function getTargetQuestData(hrp)
    local myLevel = p:FindFirstChild("Data") and p.Data:FindFirstChild("Level") and p.Data.Level.Value or 10
    local islandData = getTargetIslandData(hrp)
    
    for _, q in ipairs(islandData.Quests) do
        if myLevel >= q.Req then
            return q
        end
    end
    return islandData.Quests[#islandData.Quests]
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
                    -- пропускаем
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

            if hum.Health < hum.MaxHealth * 0.35 then
                isRecoveringHP = true
            elseif hum.Health >= hum.MaxHealth * 0.85 then
                isRecoveringHP = false
            end

            if isRecoveringHP then
                currentTarget = nil
                local qData = getTargetQuestData(hrp)
                local enemy = getEnemy(qData.Mob, qData.FallbackMob, hrp)
                
                if enemy and enemy:FindFirstChild("HumanoidRootPart") then
                    local eHrp = enemy.HumanoidRootPart
                    local fleeDir = (hrp.Position - eHrp.Position).Unit
                    local fleePos = hrp.Position + Vector3.new(fleeDir.X * 45, 0, fleeDir.Z * 45)
                    hum:MoveTo(fleePos)
                else
                    hum:MoveTo(hrp.Position)
                end
                return
            end

            equipLight(char, hum)

            local currentIslandData = getTargetIslandData(hrp)
            local currentQuestData = getTargetQuestData(hrp)
            local activeMob = getActiveQuestMob()

            -- Сброс квеста, если он не для текущего острова
            if activeMob and activeMob ~= currentQuestData.Mob and activeMob ~= currentQuestData.FallbackMob then
                abandonQuest()
                task.wait(0.3)
                activeMob = nil
            end

            -- Если мы далеко от острова — идём к нему
            local distToIsland = (hrp.Position - currentIslandData.Pos).Magnitude
            if distToIsland > 350 then
                hum:MoveTo(currentIslandData.Pos)
                return
            end

            -- Взятие квеста
            if not activeMob then
                takeQuest(currentQuestData.Name, currentQuestData.Level)
                activeMob = currentQuestData.Mob
            end

            currentTarget = getEnemy(activeMob, currentQuestData.FallbackMob, hrp)

            if not currentTarget and Waypoints[activeMob] then
                hum:MoveTo(Waypoints[activeMob])
            end

            -- Движение и бой
            if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
                local mHrp = currentTarget.HumanoidRootPart
                local mHum = currentTarget:FindFirstChild("Humanoid")
                local dist = (hrp.Position - mHrp.Position).Magnitude

                if dist > 5 then
                    hum:MoveTo(mHrp.Position)
                    local movedDist = (hrp.Position - lastHrpPos).Magnitude
                    if movedDist < 0.4 then
                        stuckTimer = stuckTimer + 0.04
                        if stuckTimer >= 0.25 then doubleJump() end
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

                if dist <= 12 and mHum and mHum.Health > 0 then
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

print("✅ Скрипт загружен! Остров: " .. getgenv().SelectedIsland)
