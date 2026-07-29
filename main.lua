getgenv().Farm = not getgenv().Farm

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local p = Players.LocalPlayer
local cam = workspace.CurrentCamera

local currentTarget = nil

-- Отключаем прошлую связку с RenderStepped при перезапуске
if getgenv().FarmConnection then
    getgenv().FarmConnection:Disconnect()
    getgenv().FarmConnection = nil
end

-- 1. ПЛАВНАЯ КАМЕРА (60+ FPS) — следит за мобом и не ломает физику ходьбы
if getgenv().Farm then
    getgenv().FarmConnection = RunService.RenderStepped:Connect(function()
        if not getgenv().Farm then return end
        
        if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
            local mPos = currentTarget.HumanoidRootPart.Position
            local targetFocus = mPos + Vector3.new(0, 2.5, 0)
            cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, targetFocus), 0.15)
        end
    end)

    -- 2. ОСНОВНАЯ ЛОГИКА (Поиск, ходьба, атака)
    task.spawn(function()
        while getgenv().Farm do
            task.wait(0.05)
            pcall(function()
                local char = p.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")
                if not hrp or not hum or hum.Health <= 0 then 
                    currentTarget = nil
                    return 
                end

                -- Включаем стандартный поворот физики Roblox
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

                -- Движение и атака
                if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
                    local mPos = currentTarget.HumanoidRootPart.Position

                    -- Бег к мобу
                    if minDist > 3 then
                        hum:MoveTo(mPos)
                    end

                    -- Прыжок при препятствии (исключая самого игрока из луча)
                    local rayParams = RaycastParams.new()
                    rayParams.FilterDescendantsInstances = {char}
                    rayParams.FilterType = Enum.RaycastFilterType.Exclude

                    local wall = workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 4, rayParams)
                    if wall then
                        hum.Jump = true
                    end

                    -- Удар
                    if minDist <= 8 then
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                    end
                end
            end)
        end
    end)
end
