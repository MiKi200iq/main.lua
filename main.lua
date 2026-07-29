--[[
    Фарм босса "Король Горилл" (King Gorilla) для Blox Fruits
    Подходит для большинства исполнителей, включая Delta
]]

getgenv().FarmKingGorilla = false -- Ставим false, чтобы скрипт не стартовал сразу, или true, если нужно

local player = game.Players.LocalPlayer
local cam = workspace.CurrentCamera

-- Настройки
local ATTACK_DISTANCE = 8
local ATTACK_COOLDOWN = 0.4
local BOSS_NAME = "King Gorilla" -- Название босса

local targetBoss = nil
local lastAttackTime = 0

-- Функция для поиска босса
local function findBoss()
    local boss = nil
    for _, v in pairs(workspace:GetChildren()) do
        if v:IsA("Model") and v.Name == BOSS_NAME then
            local hum = v:FindFirstChildOfClass("Humanoid")
            local hrp = v:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                boss = v
                break
            end
        end
    end
    return boss
end

-- Функция атаки
local function attack()
    local char = player.Character
    if not char then return end

    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        tool:Activate()
    end

    pcall(function()
        local VirtualInput = game:GetService("VirtualInputManager")
        VirtualInput:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        wait(0.02)
        VirtualInput:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
end

-- Основной цикл
spawn(function()
    while wait(0.1) do
        if not getgenv().FarmKingGorilla then
            targetBoss = nil
            continue
        end

        pcall(function()
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if not hrp or not hum or hum.Health <= 0 then
                targetBoss = nil
                return
            end

            -- Ищем босса
            targetBoss = findBoss()

            if targetBoss then
                local bossHrp = targetBoss:FindFirstChild("HumanoidRootPart")
                if not bossHrp then return end

                local bossPos = bossHrp.Position
                local distance = (hrp.Position - bossPos).Magnitude

                -- Плавная камера
                local focus = bossPos + Vector3.new(0, 2.5, 0)
                cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, focus), 0.12)

                -- Движение к боссу
                if distance > 3 then
                    hum:MoveTo(bossPos)
                else
                    hum:MoveTo(hrp.Position)
                end

                -- Атака
                if distance <= ATTACK_DISTANCE and tick() - lastAttackTime >= ATTACK_COOLDOWN then
                    attack()
                    lastAttackTime = tick()
                end
            else
                -- Если босса нет, стоим на месте
                hum:MoveTo(hrp.Position)
            end
        end)
    end
end)

print("✅ Скрипт для фарма Короля Горилл загружен.")
print("➡️ Введите в консоли: getgenv().FarmKingGorilla = true")
