getgenv().Farm = not getgenv().Farm

task.spawn(function()
    local p = game.Players.LocalPlayer
    local cam = workspace.CurrentCamera
    local vim = game:GetService("VirtualInputManager")

    while getgenv().Farm do
        task.wait(0.05) -- Частая и стабильная обнова (без задержек для ходьбы)
        pcall(function()
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then return end

            -- 1. Экипировка оружия/кулаков
            if not char:FindFirstChildOfClass("Tool") then
                for _, t in pairs(p.Backpack:GetChildren()) do
                    if t:IsA("Tool") then
                        hum:EquipTool(t)
                        break
                    end
                end
            end

            -- 2. Поиск ближайшего живого моба
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

            -- 3. Действие при наличии моба
            if target and target:FindFirstChild("HumanoidRootPart") then
                local mPos = target.HumanoidRootPart.Position
                local hrpPos = hrp.Position

                -- Поворот тела персонажа к мобу
                hrp.CFrame = CFrame.lookAt(hrpPos, Vector3.new(mPos.X, hrpPos.Y, mPos.Z))

                -- ПЛАВНАЯ КАМЕРА (Lerp)
                local targetFocus = mPos + Vector3.new(0, 2.5, 0)
                cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, targetFocus), 0.08)

                -- ДВИЖЕНИЕ К МОБУ
                hum:MoveTo(mPos)

                -- Проверка препятствий (обход стеночек)
                local wall = workspace:Raycast(hrpPos, hrp.CFrame.LookVector * 4)
                if wall then
                    hum.Jump = true
                end

                -- АТАКА (если подошли достаточно близко)
                if minDist <= 8 then
                    vim:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end
            end
        end)
    end
end)
