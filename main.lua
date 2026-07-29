--[[
    БЛОКС ФРУИТС: ФАРМ + РАБОЧИЙ АВТОУДАР + АВТОПРОКАЧКА С GUI
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Инициализация состояния
getgenv().Farm = false

-- Настройки статов
local statConfig = {
    Melee = true,
    Defense = true,
    Sword = false,
    Gun = false,
    Fruit = false
}

-- ========== 1. СОЗДАНИЕ GUI ==========
local function createGUI()
    local oldGui = player.PlayerGui:FindFirstChild("FarmGUI")
    if oldGui then oldGui:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FarmGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player.PlayerGui

    -- Главное окно
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 250, 0, 320)
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

    -- Заголовок
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.8, 0, 0, 30)
    title.Position = UDim2.new(0, 5, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "⚡ FARM CONTROLLER"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    -- Кнопка закрытия [X]
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -28, 0, 3)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextScaled = true
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = frame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        getgenv().Farm = false
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = true end
        screenGui:Destroy()
    end)

    -- Кнопка ВКЛ / ВЫКЛ
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0.8, 0, 0, 35)
    toggleBtn.Position = UDim2.new(0.1, 0, 0, 40)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    toggleBtn.Text = "▶ START FARM"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.TextScaled = true
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.Parent = frame

    local cornerBtn = Instance.new("UICorner")
    cornerBtn.CornerRadius = UDim.new(0, 4)
    cornerBtn.Parent = toggleBtn

    -- Статус
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 20)
    statusLabel.Position = UDim2.new(0, 0, 0, 80)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Status: OFF"
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = frame

    -- Чекбоксы статов
    local function createCheckbox(parent, yPos, text, default)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(0.9, 0, 0, 25)
        container.Position = UDim2.new(0.05, 0, 0, yPos)
        container.BackgroundTransparency = 1
        container.Parent = parent

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.7, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextScaled = true
        label.Font = Enum.Font.Gotham
        label.Parent = container

        local check = Instance.new("ImageButton")
        check.Size = UDim2.new(0, 20, 0, 20)
        check.Position = UDim2.new(0.8, 0, 0.1, 0)
        check.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        check.BorderSizePixel = 0
        check.Image = (default and "rbxassetid://7355369040") or ""
        check.ImageColor3 = Color3.fromRGB(0, 200, 100)
        check.ScaleType = Enum.ScaleType.Fit
        check.Parent = container

        local checkCorner = Instance.new("UICorner")
        checkCorner.CornerRadius = UDim.new(0, 3)
        checkCorner.Parent = check

        local state = default or false
        check.MouseButton1Click:Connect(function()
            state = not state
            check.Image = state and "rbxassetid://7355369040" or ""
        end)

        return container, function() return state end
    end

    local checkboxes = {}
    local yOffset = 110
    local statNames = {"Melee", "Defense", "Sword", "Gun", "Fruit"}
    local defaultStates = {true, true, false, false, false}

    for i, name in ipairs(statNames) do
        local _, getState = createCheckbox(frame, yOffset, name, defaultStates[i])
        checkboxes[name] = getState
        yOffset = yOffset + 28
    end

    -- Кнопка "Применить"
    local applyBtn = Instance.new("TextButton")
    applyBtn.Size = UDim2.new(0.8, 0, 0, 25)
    applyBtn.Position = UDim2.new(0.1, 0, 0, yOffset + 5)
    applyBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 200)
    applyBtn.Text = "✅ Применить"
    applyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    applyBtn.TextScaled = true
    applyBtn.Font = Enum.Font.GothamBold
    applyBtn.Parent = frame

    local cornerApply = Instance.new("UICorner")
    cornerApply.CornerRadius = UDim.new(0, 4)
    cornerApply.Parent = applyBtn

    -- Информация
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, 0, 0, 20)
    infoLabel.Position = UDim2.new(0, 0, 0, yOffset + 35)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "Уровень: -- | Очки: --"
    infoLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
    infoLabel.TextScaled = true
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Parent = frame

    local function updateInfo()
        if player:FindFirstChild("Data") and player.Data:FindFirstChild("Level") then
            local level = player.Data.Level.Value or 0
            local points = (player.Data:FindFirstChild("Points") and player.Data.Points.Value) or 0
            infoLabel.Text = "Уровень: " .. level .. " | Очки: " .. points
        end
    end

    RunService.Heartbeat:Connect(updateInfo)

    return {
        ToggleButton = toggleBtn,
        StatusLabel = statusLabel,
        Checkboxes = checkboxes,
        ApplyButton = applyBtn,
        UpdateInfo = updateInfo
    }
end

local gui = createGUI()

local function updateConfigFromGUI()
    for name, getState in pairs(gui.Checkboxes) do
        statConfig[name] = getState()
    end
end

gui.ApplyButton.MouseButton1Click:Connect(updateConfigFromGUI)
updateConfigFromGUI()

-- ========== 2. АВТОПРОКАЧКА СТАТОВ ==========
local function autoStat()
    if not player:FindFirstChild("Data") then return end

    local points = player.Data:FindFirstChild("Points")
    if not points or points.Value <= 0 then return end
    local available = points.Value

    local statsToUp = {}
    if statConfig.Melee   then table.insert(statsToUp, "Melee") end
    if statConfig.Defense then table.insert(statsToUp, "Defense") end
    if statConfig.Sword   then table.insert(statsToUp, "Sword") end
    if statConfig.Gun     then table.insert(statsToUp, "Gun") end
    if statConfig.Fruit   then table.insert(statsToUp, "Blox Fruit") end

    if #statsToUp == 0 then return end

    local remote = ReplicatedStorage:FindFirstChild("Remotes")
    local commF = remote and remote:FindFirstChild("CommF_")
    if not commF then return end

    local idx = 1
    while available > 0 and getgenv().Farm do
        local statName = statsToUp[idx]
        if statName and player.Data:FindFirstChild(statName) then
            commF:InvokeServer("AddPoint", statName)
            available = available - 1
        end
        idx = idx + 1
        if idx > #statsToUp then idx = 1 end
        task.wait(0.05)
    end
    gui.UpdateInfo()
end

-- ========== 3. УПРАВЛЕНИЕ ВКЛ / ВЫКЛ ==========
gui.ToggleButton.MouseButton1Click:Connect(function()
    getgenv().Farm = not getgenv().Farm
    
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if getgenv().Farm then
        gui.ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        gui.ToggleButton.Text = "⏹ STOP FARM"
        gui.StatusLabel.Text = "Status: ON"
        gui.StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    else
        gui.ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        gui.ToggleButton.Text = "▶ START FARM"
        gui.StatusLabel.Text = "Status: OFF"
        gui.StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)

        if hum and hrp then
            hum:MoveTo(hrp.Position)
            hum.AutoRotate = true
        end
    end
end)

-- ========== 4. ПРЯМАЯ ФУНКЦИЯ АТАКИ BLOX FRUITS ==========
local function attack()
    local char = player.Character
    if not char then return end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        tool:Activate() -- Включаем анимацию
    end

    -- Отправка сетевого пакета атаки Blox Fruits
    pcall(function()
        local net = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Net")
        if net then
            if net:FindFirstChild("RE/RegisterAttack") then
                net["RE/RegisterAttack"]:FireServer()
            elseif net:FindFirstChild("RE/RegisterBlade") then
                net["RE/RegisterBlade"]:FireServer()
            end
        end
    end)
end

-- ========== 5. ОСНОВНОЙ ЦИКЛ ==========
task.spawn(function()
    local cam = workspace.CurrentCamera
    local camSpeed = 0.08
    local lastAttackTime = 0
    local attackCooldown = 0.2
    
    local lastLevel = 0
    if player:FindFirstChild("Data") and player.Data:FindFirstChild("Level") then
        lastLevel = player.Data.Level.Value
    end

    while true do
        task.wait(0.05)
        
        if getgenv().Farm then
            pcall(function()
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                
                if not hrp or not hum or hum.Health <= 0 then return end

                -- Экипировка оружия
                if not char:FindFirstChildOfClass("Tool") then 
                    for _, t in pairs(player.Backpack:GetChildren()) do 
                        if t:IsA("Tool") then hum:EquipTool(t) break end 
                    end 
                end

                -- Поиск ближайшего моба
                local target, minDist = nil, math.huge
                for _, m in pairs(workspace.Enemies:GetChildren()) do
                    local mHum = m:FindFirstChild("Humanoid")
                    local mHrp = m:FindFirstChild("HumanoidRootPart")
                    if mHum and mHrp and mHum.Health > 0 then
                        local d = (hrp.Position - mHrp.Position).Magnitude
                        if d < minDist then minDist = d; target = m end
                    end
                end

                -- Движение и атака
                if target and target:FindFirstChild("HumanoidRootPart") then
                    local mPos = target.HumanoidRootPart.Position
                    local hrpPos = hrp.Position

                    -- Наводка камеры
                    local targetCamFocus = mPos + Vector3.new(0, 2.5, 0)
                    cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, targetCamFocus), camSpeed)

                    -- Движение
                    if minDist > 4 then
                        hum:MoveTo(mPos)
                        local wall = workspace:Raycast(hrpPos, hrp.CFrame.LookVector * 4)
                        if wall then hum.Jump = true end
                    else
                        hum:MoveTo(hrpPos)
                    end

                    --🔥 ВЫЗОВ АТАКИ
                    if minDist <= 8 and tick() - lastAttackTime >= attackCooldown then
                        attack()
                        lastAttackTime = tick()
                    end
                else
                    hum:MoveTo(hrp.Position)
                end

                -- Автопрокачка
                if player:FindFirstChild("Data") and player.Data:FindFirstChild("Level") then
                    local currentLevel = player.Data.Level.Value
                    if currentLevel > lastLevel or (player.Data:FindFirstChild("Points") and player.Data.Points.Value > 0) then
                        lastLevel = currentLevel
                        autoStat()
                    end
                end
            end)
        end
    end
end)
