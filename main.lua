--[[
    Blox Fruits Farm + Улучшенный обход препятствий + GUI (Delta)
]]

getgenv().Farm = getgenv().Farm or false

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local p = Players.LocalPlayer
local cam = workspace.CurrentCamera

local currentTarget = nil

-- ==================== GUI ====================
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FarmGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = p.PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 220, 0, 100)
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
    title.Text = "⚡ FARM"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0.8, 0, 0, 35)
    toggleBtn.Position = UDim2.new(0.1, 0, 0, 35)
    toggleBtn.BackgroundColor3 = getgenv().Farm and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(0, 200, 100)
    toggleBtn.Text = getgenv().Farm and "⏹ STOP" or "▶ START"
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
    statusLabel.Text = getgenv().Farm and "▶ RUNNING" or "⏹ OFF"
    statusLabel.TextColor3 = getgenv().Farm and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(200, 200, 200)
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = frame

    toggleBtn.MouseButton1Click:Connect(function()
        getgenv().Farm = not getgenv().Farm
        if getgenv().Farm then
            toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            toggleBtn.Text = "⏹ STOP"
            statusLabel.Text = "▶ RUNNING"
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
            startFarm()
        else
            toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
            toggleBtn.Text = "▶ START"
            statusLabel.Text = "⏹ OFF"
            statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            stopFarm()
        end
    end)

    return toggleBtn
end

-- ==================== УПРАВЛЕНИЕ ====================
local function stopFarm()
    if getgenv().FarmConnection then
        getgenv().FarmConnection:Disconnect()
        getgenv().FarmConnection = nil
    end
    currentTarget = nil
    local char = p.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hum and hrp then
        hum:MoveTo(hrp.Position)
    end
end

local function startFarm()
    if getgenv().FarmConnection then
        getgenv().FarmConnection:Disconnect()
        getgenv().FarmConnection = nil
    end

    -- Плавная камера (RenderStepped)
    getgenv().FarmConnection = RunService.RenderStepped:Connect(function()
        if not getgenv().Farm then return end
        if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
            local mPos = currentTarget.HumanoidRootPart.Position
            local targetFocus = mPos + Vector3.new(0, 2.5, 0)
            cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, targetFocus), 0.15)
        end
    end)

    -- Основной цикл фарма
    spawn(function()
        while getgenv().Farm do
            wait(0.05)
            pcall(function()
                local char = p.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")
                if not hrp or not hum or hum.Health <= 0 then
                    currentTarget = nil
                    return
                end

                hum.AutoRotate = true

                -- Экипировка оружия
                if not char:FindFirstChildOfClass("Tool") then
                    for _, t in pairs(p.Backpack:GetChildren()) do
                        if t:IsA("Tool") then
                            hum:EquipTool(t)
                            break
                        end
                    end
                end

                -- Поиск ближайшего моба
                local target, minDist = nil, math.huge
                local enemiesFolder = workspace:FindFirstChild("Enemies")
                if enemiesFolder then
                    for _, m in pairs(enemiesFolder:GetChildren()) do
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
                currentTarget = target

                if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
                    local mPos = currentTarget.HumanoidRootPart.Position
                    local hrpPos = hrp.Position
                    local distance = (hrpPos - mPos).Magnitude

                    -- Движение с обходом препятствий (улучшенный Raycast)
                    if distance > 3 then
                        local direction = (mPos - hrpPos).Unit
                        local rayParams = RaycastParams.new()
                        rayParams.FilterDescendantsInstances = {char}
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude

                        local wall = workspace:Raycast(hrpPos, direction * 4, rayParams)
                        if wall then
                            -- Определяем свободную сторону
                            local right = hrp.CFrame.RightVector
                            local left = -right

                            local hitRight = workspace:Raycast(hrpPos, right * 4, rayParams)
                            local hitLeft = workspace:Raycast(hrpPos, left * 4, rayParams)

                            local side
                            if hitLeft and not hitRight then
                                side = right
                            elseif hitRight and not hitLeft then
                                side = left
                            else
                                side = right -- если обе свободны или обе заняты, выбираем правую
                            end

                            -- Новая точка: вбок + немного вперёд
                            local newTarget = hrpPos + side * 5 + direction * 3
                            hum:MoveTo(newTarget)
                            hum.Jump = true
                        else
                            hum:MoveTo(mPos)
                        end
                    else
                        -- Если близко – стоим
                        hum:MoveTo(hrpPos)
                    end

                    -- Атака
                    if minDist <= 8 then
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                    end
                end
            end)
        end
    end)
end

-- ==================== ЗАПУСК ====================
createGUI()
if getgenv().Farm then
    startFarm()
end

print("✅ Скрипт загружен. Используйте GUI для управления.")
