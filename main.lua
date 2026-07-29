getgenv().Farm = not getgenv().Farm

task.spawn(function()
    local p = game.Players.LocalPlayer
    local cam = workspace.CurrentCamera
    local vim = game:GetService("VirtualInputManager")
    local PathfindingService = game:GetService("PathfindingService")

    while getgenv().Farm do
        task.wait(0.1)
        pcall(function()
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then return end

            -- 1. Экипировка оружия
            if not char:FindFirstChildOfClass("Tool") then
                for _, t in pairs(p.Backpack:GetChildren()) do
                    if t:IsA("Tool") then
                        hum:EquipTool(t)
                        break
                    end
                end
            end

            -- 2. Поиск ближайшего моба
            local target, minDist = nil, math.huge
            for _, m in pairs(workspace.Enemies:GetChildren()) do
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

            -- 3. Навигация и Атака
            if target and target:FindFirstChild("HumanoidRootPart") then
                local mPos = target.HumanoidRootPart.Position
                local hrpPos = hrp.Position

                -- ПЛАВНАЯ КАМЕРА
                local targetFocus = mPos + Vector3.new(0, 2.5, 0)
                cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, targetFocus), 0.08)

                -- 🔥 УМНЫЙ ОБХОД СТЕН (PathfindingService)
                if minDist > 4 then
                    -- Создаем путь с учетом размера персонажа
                    local path = PathfindingService:CreatePath({
                        AgentRadius = 2,
                        AgentHeight = 5,
                        AgentCanJump = true
                    })
                    
                    path:ComputeAsync(hrpPos, mPos)

                    if path.Status == Enum.PathStatus.Success then
                        local waypoints = path:GetWaypoints()
                        -- Берем следующую точку пути для движения (waypoint[2])
                        if #waypoints >= 2 then
                            local nextWaypoint = waypoints[2]
                            
                            -- Если точка требует прыжка (высокая стена/уступ)
                            if nextWaypoint.Action == Enum.PathWaypointAction.Jump then
                                hum.Jump = true
                            end
                            
                            hum:MoveTo(nextWaypoint.Position)
                        else
                            hum:MoveTo(mPos)
                        end
                    else
                        -- Если прямой путь свободен или поиск сбоит — бежим прямо
                        hum:MoveTo(mPos)
                    end
                end

                -- АТАКА
                if minDist <= 8 then
                    vim:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end
            end
        end)
    end
end)
