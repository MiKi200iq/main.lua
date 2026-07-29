--[[
    БЛОКС ФРУИТС ФАРМ + АВТОПРОКАЧКА С GUI
    Управление: включить/выключить фарм, выбрать статы для прокачки
]]

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- ========== СОЗДАНИЕ GUI ==========
local function createGUI()
    local oldGui = player.PlayerGui:FindFirstChild("FarmGUI")
    if oldGui then oldGui:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FarmGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player.PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 250, 0, 320)
    frame.Position = UDim2.new(0, 10, 0, 50)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
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

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 20)
    statusLabel.Position = UDim2.new(0, 0, 0, 80)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Status: OFF"
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = frame

    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(0.9, 0, 0, 2)
    sep.Position = UDim2.new(0.05, 0, 0, 105)
    sep.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
    sep.BorderSizePixel = 0
    sep.Parent = frame

    local statTitle = Instance.new("TextLabel")
    statTitle.Size = UDim2.new(1, 0, 0, 20)
    statTitle.Position = UDim2.new(0, 0, 0, 115)
    statTitle.BackgroundTransparency = 1
    statTitle.Text = "📊 Выберите статы для прокачки:"
    statTitle.TextColor3 = Color3.fromRGB(200, 200, 220)
    statTitle.TextScaled = true
    statTitle.Font = Enum.Font.Gotham
    statTitle.Parent = frame

    local function createCheckbox(parent, yPos, text, default)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(0.9, 0, 0, 25)
        container.Position = UDim2.new(0.05, 0, 0, yPos)
        container.BackgroundTransparency = 1
        container.Parent = parent

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.7, 0, 1, 0)
        label.Position = UDim2.new(0, 0, 0, 0)
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
    local yOffset = 145
    local statNames = {"Melee", "Defense", "Sword", "Gun", "Fruit"}
    local defaultStates = {true, true, false, false, false}

    for i, name in ipairs(statNames) do
        local _, getState = createCheckbox(frame, yOffset, name, defaultStates[i])
        checkboxes[name] = getState
        yOffset = yOffset + 30
    end

    local applyBtn = Instance.new("TextButton")
    applyBtn.Size = UDim2.new(0.8, 0, 0, 30)
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

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, 0, 0, 20)
    infoLabel.Position = UDim2.new(0, 0, 0, yOffset + 45)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "Уровень: -- | Очки: --"
    infoLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
    infoLabel.TextScaled = true
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Parent = frame

    local function updateInfo()
        if player.Data and player.Data.Level then
            local level = player.Data.Level.Value or 0
            local points = (player.Data:FindFirstChild("Points") and player.Data.Points.Value) or 0
            infoLabel.Text = "Уровень: " .. level .. " | Очки: " .. points
        end
    end

    game:GetService("RunService").Heartbeat:Connect(updateInfo)

    return {
        Frame = frame,
        ToggleButton = toggleBtn,
        StatusLabel = statusLabel,
        Checkboxes = checkboxes,
        ApplyButton = applyBtn,
        UpdateInfo = updateInfo
    }
end

-- ========== ИНИЦИАЛИЗАЦИЯ ==========
local gui = createGUI()

-- Конфиг статов (синхронизируется с GUI)
local statConfig = {
    Melee = true,
    Defense = true,
    Sword = false,
    Gun = false,
    Fruit = false
}

local function updateConfigFromGUI()
    for name, getState in pairs(gui.Checkboxes) do
        statConfig[name] = getState()
    end
end

gui.ApplyButton.MouseButton1Click:Connect(updateConfigFromGUI)
updateConfigFromGUI() -- при старте

-- Переменная состояния фарма
getgenv().Farm = getgenv().Farm or false

-- ========== АВТОПРОКАЧКА ==========
local function autoStat()
    if not player.Data then return end

    local points = player.Data:FindFirstChild("Points")
    if not points then return end
    local available = points.Value
    if available <= 0 then return end

    local statsToUp = {}
    if statConfig.Melee  then table.insert(statsToUp, "Melee") end
    if statConfig.Defense then table.insert(statsToUp, "Defense") end
    if statConfig.Sword  then table.insert(statsToUp, "Sword") end
    if statConfig.Gun    then table.insert(statsToUp, "Gun") end
    if statConfig.Fruit  then table.insert(statsToUp, "Blox Fruit") end

    if #statsToUp == 0 then return end

    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    if not remote then return end
    local commF = remote:FindFirstChild("CommF_")
    if not commF then return end

    local idx = 1
    while available > 0 do
        local statName = statsToUp[idx]
        if not statName then break end
        if player.Data:FindFirstChild(statName) then
            commF:InvokeServer("AddPoint", statName)
            available = available - 1
        end
        idx = idx + 1
        if idx > #statsToUp then idx = 1 end
        task.wait(0.1)
    end
    gui.UpdateInfo()
end

-- ========== ОБРАБОТЧИК КНОПКИ ==========
gui.ToggleButton.MouseButton1Click:Connect(function()
    getgenv().Farm = not getgenv().Farm
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
    end
end)

-- ========== ОСНОВНОЙ ЦИКЛ ФАРМА ==========
local lastLevel = 0
if player.Data and player.Data.Level then
    lastLevel = player.Data.Level.Value
end

task.spawn(function()
    local cam = workspace.CurrentCamera
    local camSpeed = 0.04

    while true do
        task.wait(0.03)
        if not getgenv().Farm then
            continue
        end

        pcall(function()
            local c = player.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if not hrp or c.Humanoid.Health <= 0 then return end

            -- Экипировка оружия
            if not c:FindFirstChildOfClass("Tool") then
                for _, t in pairs(player.Backpack:GetChildren()) do
                    if t:IsA("Tool") then
                        c.Humanoid:EquipTool(t)
                        break
                    end
                end
            end

            -- Поиск ближайшего моба
            local target, minDist = nil, math.huge
            for _, m in pairs(workspace.Enemies:GetChildren()) do
                if m:FindFirstChild("Humanoid") and m.Humanoid.Health > 0 then
                    local d = (hrp.Position - m.HumanoidRootPart.Position).Magnitude
                    if d < minDist then
                        minDist = d
                        target = m
                    end
                end
            end

            if target then
                local pos = target.HumanoidRootPart.Position
                local hrpPos = hrp.Position

                -- Поворот персонажа к цели
                hrp.CFrame = CFrame.lookAt(hrpPos, Vector3.new(pos.X, hrpPos.Y, pos.Z))

                -- Плавная камера
                local targetCamFocus = pos + Vector3.new(0, 2.5, 0)
                cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, targetCamFocus), camSpeed)

                -- Движение с обходом препятствий
                local frontWall = workspace:Raycast(hrpPos, hrp.CFrame.LookVector * 4)
                if frontWall then
                    local leftWall = workspace:Raycast(hrpPos, -hrp.CFrame.RightVector * 4)
                    local side = leftWall and hrp.CFrame.RightVector or -hrp.CFrame.RightVector
                    c.Humanoid:MoveTo(hrpPos + side * 5)
                    c.Humanoid.Jump = true
                else
                    c.Humanoid:MoveTo(pos)
                end

                -- Автоудар
                if minDist <= 7.5 then
                    game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end
            end

            -- Проверка уровня для автопрокачки
            if player.Data and player.Data.Level then
                local currentLevel = player.Data.Level.Value
                if currentLevel > lastLevel then
                    lastLevel = currentLevel
                    autoStat()
                end
            end
        end)
    end
end)

print("✅ Скрипт загружен. Используйте GUI для управления.")
