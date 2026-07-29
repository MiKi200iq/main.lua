getgenv().Farm = not getgenv().Farm

task.spawn(function()
    local p = game.Players.LocalPlayer
    local cam = workspace.CurrentCamera
    local vim = game:GetService("VirtualInputManager")
    local lastAttackTime = 0
    local attackCooldown = 0.3

    -- Отключаем автоповорот персонажа (чтобы камера управляла направлением)
    p.CharacterAutoRotate = false

    while getgenv().Farm do
        task.wait(0.05)
        pcall(function()
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then return end

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

                -- Плавный поворот камеры к цели
                local targetFocus = mPos + Vector3.new(0, 2.5, 0)
                cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, targetFocus), 0.1)

                -- ДВИЖЕНИЕ: ВСЕГДА бежим к цели, НЕ останавливаемся
                hum:MoveTo(mPos)

                -- АТАКА, если цель в радиусе (даже на ходу)
                if distance <= 8 and tick() - lastAttackTime >= attackCooldown then
                    -- Проверяем, что камера смотрит примерно на цель (чтобы атака была точной)
                    local lookVec = cam.CFrame.LookVector
                    local toTarget = (mPos - hrpPos).Unit
                    if lookVec:Dot(toTarget) > 0.5 then
                        vim:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                        task.wait(0.02)
                        vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                        lastAttackTime = tick()
                    end
                end
            else
                -- Нет целей – стоим на месте
                hum:MoveTo(hrp.Position)
            end
        end)
    end
end)

print("Farm " .. (getgenv().Farm and "ON" or "OFF"))
