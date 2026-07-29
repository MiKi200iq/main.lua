getgenv().Farm = not getgenv().Farm

local p = game.Players.LocalPlayer
local char = p.Character or p.CharacterAdded:Wait()
local hum = char:FindFirstChildOfClass("Humanoid")
local hrp = char:FindFirstChild("HumanoidRootPart")

-- 🛑 Блок сброса при ВЫКЛЮЧЕНИИ фарма
if not getgenv().Farm then
    if hum and hrp then
        hum:MoveTo(hrp.Position) -- Останавливаем движение
        hum.AutoRotate = true    -- Возвращаем стандартный поворот персонажа
    end
    print("Farm OFF")
    return
end

print("Farm ON")

task.spawn(function()
    local cam = workspace.CurrentCamera
    local vim = game:GetService("VirtualInputManager")
    local lastAttackTime = 0
    local attackCooldown = 0.3

    while getgenv().Farm do
        task.wait(0.05)
        pcall(function()
            local currentChar = p.Character
            local currentHrp = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
            local currentHum = currentChar and currentChar:FindFirstChild("Humanoid")
            if not currentHrp or not currentHum or currentHum.Health <= 0 then return end

            -- Отключаем автоповорот персонажа правильно (через Humanoid)
            currentHum.AutoRotate = false

            -- Экипировка оружия
            if not currentChar:FindFirstChildOfClass("Tool") then
                for _, t in pairs(p.Backpack:GetChildren()) do
                    if t:IsA("Tool") then
                        currentHum:EquipTool(t)
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
                    local dist = (currentHrp.Position - mHrp.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        target = m
                    end
                end
            end

            if target and target:FindFirstChild("HumanoidRootPart") then
                local mPos = target.HumanoidRootPart.Position
                local hrpPos = currentHrp.Position
                local distance = (hrpPos - mPos).Magnitude

                -- Плавный поворот камеры к цели
                local targetFocus = mPos + Vector3.new(0, 2.5, 0)
                cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, targetFocus), 0.1)

                -- ДВИЖЕНИЕ: Бежим к цели
                currentHum:MoveTo(mPos)

                -- АТАКА (проверка угла обзора камеры)
                if distance <= 8 and tick() - lastAttackTime >= attackCooldown then
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
                -- Нет целей — стоим на месте
                currentHum:MoveTo(currentHrp.Position)
            end
        end)
    end
end)
