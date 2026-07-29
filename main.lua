getgenv().Farm = not getgenv().Farm

task.spawn(function()
    local p = game.Players.LocalPlayer
    local cam = workspace.CurrentCamera
    local vim = game:GetService("VirtualInputManager")
    local PathfindingService = game:GetService("PathfindingService")
    local lastAttackTime = 0
    local attackCooldown = 0.3
    local lastMoveTime = 0
    local moveInterval = 0.15 -- Интервал обновления пути

    while getgenv().Farm do
        task.wait(0.05)
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

            if target and target:FindFirstChild("HumanoidRootPart") then
                local mPos = target.HumanoidRootPart.Position
                local hrpPos = hrp.Position
                local distance = (hrpPos - mPos).Magnitude

                -- ПЛАВНЫЙ ПОВОРОТ КАМЕРЫ (без резких движений)
                local targetFocus = mPos + Vector3.new(0, 2.5, 0)
                local currentCF = cam.CFrame
                local targetCF = CFrame.new(currentCF.Position, targetFocus)
                cam.CFrame = currentCF:Lerp(targetCF, 0.15) -- Увеличен Lerp для плавности

                -- 🔥 ДВИЖЕНИЕ С ОБХОДОМ ПРЕПЯТСТВИЙ
                if distance > 4 then -- Двигаемся только если далеко
                    local currentTime = tick()
                    
                    -- Обновляем путь не чаще чем раз в moveInterval секунд
                    if currentTime - lastMoveTime >= moveInterval then
                        local path = PathfindingService:CreatePath({
                            AgentRadius = 2.5, -- Увеличен радиус
                            AgentHeight = 5,
                            AgentCanJump = true,
                            AgentMaxSlope = 45,
                            WaypointSpacing = 2,
                            Costs = {
                                Water = 5,
                                Jump = 10,
                                Enemy = 10
                            }
                        })
                        
                        local success = pcall(function()
                            path:ComputeAsync(hrpPos, mPos)
                        end)
                        
                        if success and path.Status == Enum.PathStatus.Success then
                            local waypoints = path:GetWaypoints()
                            
                            -- Ищем первую достижимую точку (не слишком далеко)
                            for i = 1, math.min(#waypoints, 5) do
                                local wp = waypoints[i]
                                local wpDist = (hrpPos - wp.Position).Magnitude
                                
                                -- Если точка слишком далеко - берем промежуточную
                                if wpDist > 15 and i < #waypoints then
                                    -- Пропускаем
                                elseif wpDist > 2 then
                                    if wp.Action == Enum.PathWaypointAction.Jump then
                                        hum.Jump = true
                                    end
                                    hum:MoveTo(wp.Position)
                                    lastMoveTime = currentTime
                                    break
                                end
                            end
                        else
                            -- Если Pathfinding не работает - просто бежим к цели
                            hum:MoveTo(mPos)
                            lastMoveTime = currentTime
                        end
                    end
                else
                    -- Если близко к цели - останавливаемся
                    if hum.MoveDirection.Magnitude > 0 then
                        hum:MoveTo(hrpPos) -- Останавливаем движение
                    end
                end

                -- АТАКА (только когда близко и смотрим на цель)
                if distance <= 8 then
                    -- Проверяем, смотрит ли игрок на цель
                    local lookVector = cam.CFrame.LookVector
                    local toTarget = (mPos - hrpPos).Unit
                    local dotProduct = lookVector:Dot(toTarget)
                    
                    -- Атакуем только если смотрим примерно на цель
                    if dotProduct > 0.7 and tick() - lastAttackTime >= attackCooldown then
                        vim:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                        task.wait(0.02)
                        vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                        lastAttackTime = tick()
                    end
                end
            else
                -- Нет целей - стоим
                if hum.MoveDirection.Magnitude > 0 then
                    hum:MoveTo(hrpPos)
                end
            end
        end)
    end
end)

print("Farm " .. (getgenv().Farm and "ON" or "OFF"))
