-- [[ BLOX FRUITS ФАРМ (Delta Fix - БЕЗ Pathfinding) ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

print("🚀 ЗАПУСК АВТО-ФАРМА (Delta)!")

-- Глобальная переменная
_G.Farm = false

-- Настройки
local ATTACK_COOLDOWN = 0.4
local ATTACK_DISTANCE = 8
local CAMERA_SMOOTHNESS = 10

local currentTargetPart = nil
local lastAttack = 0

-- Поиск детали моба
local function getMorpPart(model)
    return model:FindFirstChild("HumanoidRootPart") 
        or model:FindFirstChild("Torso") 
        or model:FindFirstChild("UpperTorso") 
        or model:FindFirstChild("Head") 
        or model:FindFirstChildOfClass("Part")
end

-- ========== GUI ==========
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FarmGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player.PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 220, 0, 120)
    frame.Position = UDim2.new(0, 10, 0, 50)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "⚡ FARM CONTROLLER"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0.8, 0, 0, 35)
    toggleBtn.Position = UDim2.new(0.1, 0, 0, 35)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    toggleBtn.Text = "▶ START FARM"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.TextScaled = true
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = toggleBtn

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 20)
    statusLabel.Position = UDim2.new(0, 0, 0, 75)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "⏹ OFF"
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = frame

    toggleBtn.MouseButton1Click:Connect(function()
        _G.Farm = not _G.Farm
        
        if _G.Farm then
            toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            toggleBtn.Text = "⏹ STOP FARM"
            statusLabel.Text = "▶ RUNNING"
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
            print("✅ Фарм ВКЛЮЧЕН")
        else
            toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
            toggleBtn.Text = "▶ START FARM"
            statusLabel.Text = "⏹ OFF"
            statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            print("⏹ Фарм ВЫКЛЮЧЕН")
            
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hum and hrp then
                hum:MoveTo(hrp.Position)
            end
        end
    end)

    return toggleBtn
end

createGUI()

-- ========== КАМЕРА ==========
RunService.RenderStepped:Connect(function(deltaTime)
    if _G.Farm and currentTargetPart and currentTargetPart.Parent then
        local cam = workspace.CurrentCamera
        local camPos = cam.CFrame.Position
        local targetPos = currentTargetPart.Position + Vector3.new(0, 1.5, 0)

        local desiredCFrame = CFrame.lookAt(camPos, targetPos)
        local alpha = math.clamp(deltaTime * CAMERA_SMOOTHNESS, 0, 1)
        cam.CFrame = cam.CFrame:Lerp(desiredCFrame, alpha)
    end
end)

-- ========== ФУНКЦИЯ АТАКИ ==========
local function attackMob(target)
    local char = player.Character
    if not char then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    -- 1. Экипируем оружие
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then
        for _, t in pairs(player.Backpack:GetChildren()) do
            if t:IsA("Tool") then
                hum:EquipTool(t)
                tool = t
                break
            end
        end
    end
    
    -- 2. Атакуем через Activate
    if tool then
        tool:Activate()
    end
    
    -- 3. Альтернативный способ атаки (для Blox Fruits)
    pcall(function()
        local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        if remote then
            local attackRemote = remote:FindFirstChild("Attack")
            if attackRemote then
                attackRemote:FireServer()
            end
        end
    end)
    
    -- 4. Имитация клика (если ничего не работает)
    pcall(function()
        local VirtualInput = game:GetService("VirtualInputManager")
        VirtualInput:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        wait(0.02)
        VirtualInput:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
end

-- ========== ОСНОВНОЙ ЦИКЛ (БЕЗ PATHFINDING) ==========
spawn(function()
    local lastTargetCheck = 0
    
    while true do
        wait(0.05)
        
        if not _G.Farm then
            currentTargetPart = nil
            wait(0.1)
            continue
        end
        
        pcall(function()
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            
            if not char or not hum or not hrp or hum.Health <= 0 then
                currentTargetPart = nil
                return
            end
            
            -- Поиск ближайшего моба
            local target = nil
            local targetPart = nil
            local minDist = math.huge
            
            for _, m in pairs(workspace:GetChildren()) do
                -- Пропускаем игроков и не-мобов
                if m:IsA("Model") and m ~= char and m:FindFirstChild("Humanoid") then
                    local mHum = m:FindFirstChildOfClass("Humanoid")
                    local mainPart = getMorpPart(m)
                    
                    if mHum and mainPart and mHum.Health > 0 then
                        local dist = (hrp.Position - mainPart.Position).Magnitude
                        if dist < minDist then
                            minDist = dist
                            target = m
                            targetPart = mainPart
                        end
                    end
                end
            end
            
            currentTargetPart = targetPart
            
            -- Движение и атака
            if target and targetPart then
                local targetPos = targetPart.Position
                local hrpPos = hrp.Position
                local distance = (hrpPos - targetPos).Magnitude
                
                -- ВСЕГДА двигаемся к цели (если расстояние > 1)
                if distance > 1.5 then
                    hum:MoveTo(targetPos)
                    
                    -- Если уперлись в стену - прыгаем
                    local wall = workspace:Raycast(hrpPos, (targetPos - hrpPos).Unit * 5)
                    if wall then
                        hum.Jump = true
                        -- Пробуем обойти в сторону
                        local sidePos = targetPos + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
                        hum:MoveTo(sidePos)
                    end
                else
                    -- Останавливаемся, если очень близко
                    hum:MoveTo(hrpPos)
                end
                
                -- АТАКА (каждый кадр проверяем)
                if distance <= ATTACK_DISTANCE and (tick() - lastAttack) >= ATTACK_COOLDOWN then
                    attackMob(target)
                    lastAttack = tick()
                    
                    -- Наносим урон (для отображения)
                    local mHum = target:FindFirstChildOfClass("Humanoid")
                    if mHum then
                        mHum:TakeDamage(15)
                        print("⚔️ Атака! HP: " .. math.floor(mHum.Health))
                    end
                end
            else
                -- Нет целей - стоим
                hum:MoveTo(hrp.Position)
                currentTargetPart = nil
            end
        end)
    end
end)

print("✅ Скрипт загружен! Нажмите START FARM в GUI.")
print("📌 Если не атакует - проверьте оружие в руке")
