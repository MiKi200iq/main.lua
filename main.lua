getgenv().Farm = not getgenv().Farm

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local p = Players.LocalPlayer
local cam = workspace.CurrentCamera

local currentTarget = nil

-- Отключаем прошлую связку при перезапуске
if getgenv().FarmConnection then
    getgenv().FarmConnection:Disconnect()
    getgenv().FarmConnection = nil
end

-- Функция быстрого поиска ближайшего живого моба
local function getClosestEnemy(hrp)
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return nil, math.huge end

    local target, minDist = nil, math.huge
    for _, m in pairs(enemiesFolder:GetChildren()) do
        local mHum = m:FindFirstChild("Humanoid")
        local mHrp = m:FindFirstChild("HumanoidRootPart")
        
        -- Проверяем, что моб жив и его здоровье > 0
        if mHum and mHrp and mHum.Health > 0 then
            local dist = (hrp.Position - mHrp.Position).Magnitude
            if dist < minDist then
                minDist = dist
                target = m
            end
        end
    end
    return target, minDist
end

-- 1. ПЛАВНАЯ КАМЕРА (60+ FPS)
if getgenv().Farm then
    getgenv().FarmConnection = RunService.RenderStepped:Connect(function()
        if not getgenv().Farm then return end
        
        if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
            local mHum = currentTarget:FindFirstChild("Humanoid")
            -- Если моб умер прямо во время кадра — сбрасываем камеру
            if not mHum or mHum.Health <= 0 then
                currentTarget = nil
                return
            end

            local mPos = currentTarget.HumanoidRootPart.Position
            local targetFocus = mPos + Vector3.new(0, 2.5, 0)
            cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, targetFocus), 0.15)
        end
    end)

    -- 2. ОСНОВНОЙ ЦИКЛ ФАРМА
    task.spawn(function()
        while getgenv().Farm do
            task.wait(0.02) -- Минимальная задержка для максимальной отзывчивости
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

                -- Проверяем текущую цель: если она умерла или отсутствует — ищем новую МГНОВЕННО
                local targetHrp = currentTarget and currentTarget:FindFirstChild("HumanoidRootPart")
                local targetHum = currentTarget and currentTarget:FindFirstChild("Humanoid")

                if not currentTarget or not targetHrp or not targetHum or targetHum.Health <= 0 then
                    currentTarget, _ = getClosestEnemy(hrp)
                end

                -- Логика движения и атаки к найденной цели
                if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
                    local mHrp = currentTarget.HumanoidRootPart
                    local mHum = currentTarget:FindFirstChild("Humanoid")

                    -- Если цель жива
                    if mHum and mHum.Health > 0 then
                        local dist = (hrp.Position - mHrp.Position).Magnitude

                        -- Мгновенное возобновление бега
                        if dist > 3 then
                            hum:MoveTo(mHrp.Position)
                        end

                        -- Преодоление препятствий
                        local rayParams = RaycastParams.new()
                        rayParams.FilterDescendantsInstances = {char}
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude

                        local wall = workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 4, rayParams)
                        if wall then
                            hum.Jump = true
                        end

                        -- Атака (строго только пока у моба есть ХП)
                        if dist <= 8 then
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                        end
                    else
                        currentTarget = nil
                    end
                end
            end)
        end
    end)
end
