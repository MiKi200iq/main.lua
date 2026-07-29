getgenv().Farm = not getgenv().Farm

task.spawn(function()
    local p = game.Players.LocalPlayer
    local cam = workspace.CurrentCamera
    local vim = game:GetService("VirtualInputManager")
    local lastAttackTime = 0
    local attackCooldown = 0.25
    
    -- Отключаем автоматическое вращение камеры
    p.CameraMinZoomDistance = 0.5
    p.CameraMaxZoomDistance = 50

    while getgenv().Farm do
        task.wait(0.05)
        pcall(function()
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then return end

            -- Экипировка
            if not char:FindFirstChildOfClass("Tool") then
                for _, t in pairs(p.Backpack:GetChildren()) do
                    if t:IsA("Tool") then
                        hum:EquipTool(t)
                        break
                    end
                end
            end

            -- Поиск цели
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

                -- ПЛАВНАЯ КАМЕРА (медленный поворот)
                local targetFocus = mPos + Vector3.new(0, 2.5, 0)
                local newCF = CFrame.new(cam.CFrame.Position, targetFocus)
                cam.CFrame = cam.CFrame:Lerp(newCF, 0.08) -- Очень медленный поворот

                -- ПРОСТОЕ ДВИЖЕНИЕ (без Pathfinding, чтобы не упираться)
                if distance > 5 then
                    -- Двигаемся к цели, но с остановкой перед препятствием
                    hum:MoveTo(mPos)
                    
                    -- Проверяем, не уперлись ли мы в стену
                    task.wait(0.02)
                    local newPos = hrp.Position
                    if (newPos - hrpPos).Magnitude < 0.1 and distance > 10 then
                        -- Если не двигаемся - пробуем обойти в сторону
                        local sidePos = mPos + Vector3.new(
                            math.random(-5, 5), 
                            0, 
                            math.random(-5, 5)
                        )
                        hum:MoveTo(sidePos)
                    end
                else
                    -- Останавливаемся рядом с целью
                    hum:MoveTo(hrpPos)
                end

                -- АТАКА
                if distance <= 7 and tick() - lastAttackTime >= attackCooldown then
                    vim:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    task.wait(0.02)
                    vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                    lastAttackTime = tick()
                end
            end
        end)
    end
end)

print("Farm " .. (getgenv().Farm and "ON" or "OFF"))
