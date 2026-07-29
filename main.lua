local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

print("🚀 ЗАПУСК АВТО-ФАРМА (УЛЬТРА-ПЛАВНАЯ КАМЕРА RENDERSTEPPED)!")

_G.Farm = true

-- Настройки
local ATTACK_COOLDOWN = 0.65 -- Задержка атак
local ATTACK_DISTANCE = 7.5   -- Дистанция атаки
local CAMERA_SMOOTHNESS = 12 -- Скорость плавности (чем выше, тем отзывчивее, 10-15 идеально)

local currentTargetPart = nil -- Текущая деталь моба для фокуса камеры

-- Поиск детали моба
local function getMorpPart(model)
    return model:FindFirstChild("HumanoidRootPart") 
        or model:FindFirstChild("Torso") 
        or model:FindFirstChild("UpperTorso") 
        or model:FindFirstChild("Head") 
        or model:FindFirstChildOfClass("Part")
end

-- Настройки Pathfinding
local path = PathfindingService:CreatePath({
    AgentRadius = 2,
    AgentHeight = 5,
    AgentCanJump = true,
    WaypointSpacing = 4
})

-- 🎥 1. ИДЕАЛЬНО ПЛАВНЫЙ ПОВОРОТ КАМЕРЫ (Каждый кадр)
RunService.RenderStepped:Connect(function(deltaTime)
    if _G.Farm and currentTargetPart and currentTargetPart.Parent then
        local cam = workspace.CurrentCamera
        local camPos = cam.CFrame.Position
        local targetPos = currentTargetPart.Position + Vector3.new(0, 1.5, 0)

        -- Вычисляем идеальный угол
        local desiredCFrame = CFrame.lookAt(camPos, targetPos)

        -- Плавная интерполяция, независимая от FPS
        local alpha = math.clamp(deltaTime * CAMERA_SMOOTHNESS, 0, 1)
        cam.CFrame = cam.CFrame:Lerp(desiredCFrame, alpha)
    end
end)

-- 🏃‍♂️ 2. ЛОГИКА ДВИЖЕНИЯ И АТАКИ
task.spawn(function()
    local lastAttack = 0

    while _G.Farm do
        task.wait(0.05)

        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if char and hum and hrp and hum.Health > 0 then

            -- Подготовка папки Enemies
            local enemiesFolder = workspace:FindFirstChild("Enemies")
            if not enemiesFolder then
                enemiesFolder = Instance.new("Folder")
                enemiesFolder.Name = "Enemies"
                enemiesFolder.Parent = workspace
            end

            -- Поиск мобов
            for _, obj in pairs(workspace:GetChildren()) do
                if obj:FindFirstChild("Humanoid") and obj ~= char and obj.Name ~= "Terrain" then
                    if not obj:IsDescendantOf(enemiesFolder) then
                        obj.Parent = enemiesFolder
                    end
                end
            end

            -- Поиск ближайшего моба
            local target = nil
            local targetPart = nil
            local minDist = math.huge

            for _, m in pairs(enemiesFolder:GetChildren()) do
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

            -- Передаем цель в камеру
            currentTargetPart = targetPart

            -- Движение и Атака
            if target and targetPart then
                local targetHum = target:FindFirstChildOfClass("Humanoid")

                -- Обход препятствий
                if minDist > 5 then
                    local success = pcall(function()
                        path:ComputeAsync(hrp.Position, targetPart.Position)
                    end)

                    if success and path.Status == Enum.PathStatus.Success then
                        local waypoints = path:GetWaypoints()
                        if #waypoints > 1 then
                            local nextPoint = waypoints[2]
                            if nextPoint.Action == Enum.PathWaypointAction.Jump then
                                hum.Jump = true
                            end
                            hum:MoveTo(nextPoint.Position)
                        else
                            hum:MoveTo(targetPart.Position)
                        end
                    else
                        hum:MoveTo(targetPart.Position)
                    end
                else
                    hum:MoveTo(hrp.Position)
                end

                -- Контролируемая атака
                if minDist <= ATTACK_DISTANCE and (tick() - lastAttack) >= ATTACK_COOLDOWN then
                    local tool = char:FindFirstChildOfClass("Tool") or player.Backpack:FindFirstChildOfClass("Tool")
                    if tool and tool.Parent == player.Backpack then
                        hum:EquipTool(tool)
                    end

                    if tool then 
                        tool:Activate() 
                    end

                    lastAttack = tick()
                end
            else
                currentTargetPart = nil
            end
        end
    end
end)
