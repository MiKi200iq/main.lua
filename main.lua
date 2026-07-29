getgenv().Farm = not getgenv().Farm

local p = game.Players.LocalPlayer
local char = p.Character or p.CharacterAdded:Wait()
local hum = char:FindFirstChildOfClass("Humanoid")
local hrp = char:FindFirstChild("HumanoidRootPart")

-- При выключении моментально останавливаем ходьбу
if not getgenv().Farm then
    if hum and hrp then hum:MoveTo(hrp.Position) end
    print("Farm OFF")
    return
end

print("Farm ON")

task.spawn(function()
    local cam = workspace.CurrentCamera
    local vim = game:GetService("VirtualInputManager")
    local lastAttackTime = 0
    local attackCooldown = 0.25
    
    -- Переменные для отслеживания застревания
    local lastHrpPos = Vector3.new()
    local stuckTime = 0

    while getgenv().Farm do
        task.wait(0.05)
        pcall(function()
            local currentChar = p.Character
            local currentHrp = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
            local currentHum = currentChar and currentChar:FindFirstChild("Humanoid")
            if not currentHrp or not currentHum or currentHum.Health <= 0 then return end

            -- Экипировка оружия
            if not currentChar:FindFirstChildOfClass("Tool") then
                for _, t in pairs(p.Backpack:GetChildren()) do
                    if t:IsA("Tool") then
                        currentHum:EquipTool(t)
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

                -- ПЛАВНАЯ КАМЕРА
                local targetFocus = mPos + Vector3.new(0, 2.5, 0)
                local newCF = CFrame.new(cam.CFrame.Position, targetFocus)
                cam.CFrame = cam.CFrame:Lerp(newCF, 0.08)

                -- ДВИЖЕНИЕ И ПРОВЕРКА НА СТЕНУ
                if distance > 5 then
                    -- Проверяем, двигается ли персонаж с прошлого кадра
                    if (currentHrp.Position - lastHrpPos).Magnitude < 0.2 then
                        stuckTime = stuckTime + 0.05
                    else
                        stuckTime = 0
                    end
                    lastHrpPos = currentHrp.Position

                    -- Если застрял больше чем на 0.3 сек
                    if stuckTime > 0.3 then
                        currentHum.Jump = true -- Прыгаем через забор/препятствие
                        local sidePos = mPos + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
                        currentHum:MoveTo(sidePos)
                        stuckTime = 0
                    else
                        currentHum:MoveTo(mPos)
                    end
                else
                    currentHum:MoveTo(hrpPos) -- Остановка у цели
                end

                -- АТАКА
                if distance <= 7 and tick() - lastAttackTime >= attackCooldown then
                    vim:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    task.wait(0.01)
                    vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                    lastAttackTime = tick()
                end
            end
        end)
    end
end)
