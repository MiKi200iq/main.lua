getgenv().Farm = not getgenv().Farm

task.spawn(function()
    local p = game.Players.LocalPlayer
    local cam = workspace.CurrentCamera
    local vim = game:GetService("VirtualInputManager")

    while getgenv().Farm do
        task.wait(0.1) -- Увеличен интервал, чтобы физика ходьбы успевала срабатывать
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

            -- 3. Движение, Камера и Атака
            if target and target:FindFirstChild("HumanoidRootPart") then
                local mPos = target.HumanoidRootPart.Position
                local hrpPos = hrp.Position

                -- ПЛАВНАЯ КАМЕРА (следит за врагом)
                local targetFocus = mPos + Vector3.new(0, 2.5, 0)
                cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, targetFocus), 0.08)

                -- 🔥 ЧИСТАЯ ХОДЬБА (Без жесткого поворота CFrame, который блокировал бег)
                if minDist > 3 then
                    hum:MoveTo(mPos) -- Персонаж сам повернется и побежит к цели
                end

                -- Прыжок если уперся в стеночку
                local wall = workspace:Raycast(hrpPos, hrp.CFrame.LookVector * 4)
                if wall then
                    hum.Jump = true
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
