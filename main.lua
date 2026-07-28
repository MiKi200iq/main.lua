getgenv().Farm = not getgenv().Farm

local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local p = game.Players.LocalPlayer
local cam = workspace.CurrentCamera

-- Настройки естественности камеры
local camSpeed = 0.05 -- Чем меньше (0.02-0.05), тем мягче и естественнее поворот
getgenv().CurrentTargetHRP = nil -- Глобальная переменная для передачи цели между циклами

-- Поиск оружия/кулаков
local function equipTool(char, hum)
    if not char:FindFirstChildOfClass("Tool") then 
        for _,t in pairs(p.Backpack:GetChildren()) do 
            if t:IsA("Tool") then hum:EquipTool(t) break end 
        end 
    end
end

---------------------------------------------------
-- 🔥 ЦИКЛ ПЛАВНОЙ КАМЕРЫ (Привязан к каждому кадру)
---------------------------------------------------
local connectionName = "SmoothFarmCam"
-- Отключаем старую связь, если она была, чтобы не стакались
if RunService:IsStudio() then -- Для теста в студии
    local oldConn = getgenv()[connectionName]
    if oldConn then oldConn:Disconnect() end
end

if getgenv().Farm then
    getgenv()[connectionName] = RunService.RenderStepped:Connect(function()
        pcall(function()
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp or char.Humanoid.Health <= 0 then return end

            -- Берём цель, которую нашёл основной цикл фарма
            local targetHRP = getgenv().CurrentTargetHRP

            if targetHRP and targetHRP.Parent and targetHRP.Parent:FindFirstChild("Humanoid") and targetHRP.Parent.Humanoid.Health > 0 then
                local pos = targetHRP.Position
                local hrpPos = hrp.Position
                
                -- 1. СТРОГО КОРПУСОМ ПЕРСОНАЖА НА МОБА
                -- Это нужно для правильной анимации ходьбы и прыжков
                hrp.CFrame = CFrame.lookAt(hrpPos, Vector3.new(pos.X, hrpPos.Y, pos.Z))
                
                -- 2. 🔥 ИДЕАЛЬНО ПЛАВНАЯ ТРАССИРОВКА КАМЕРЫ (Привязана к RenderStepped)
                -- Точка фокуса чуть выше моба
                local targetCamFocus = pos + Vector3.new(0, 3, 0)
                local desiredCamCFrame = CFrame.new(cam.CFrame.Position, targetCamFocus)
                
                -- Интерполяция CFrame без привязки к wait()
                cam.CFrame = cam.CFrame:Lerp(desiredCamCFrame, camSpeed)
            end
        end)
    end)
else
    -- Если фарм выключен, отключаем связь RenderStepped
    local conn = getgenv()[connectionName]
    if conn then conn:Disconnect(); getgenv()[connectionName] = nil end
    getgenv().CurrentTargetHRP = nil
end


---------------------------------------------------
-- ⚔️ ОСНОВНОЙ ЦИКЛ ФАРМА (Поиск, Бег, Атака)
---------------------------------------------------
task.spawn(function()
    while getgenv().Farm do 
        task.wait(0.1) -- Частота обновления поиска целей и атаки
        pcall(function()
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp or char.Humanoid.Health <= 0 then 
                getgenv().CurrentTargetHRP = nil -- Сброс цели при смерти
                return 
            end
            
            -- Экипировка
            equipTool(char, char.Humanoid)
            
            -- Поиск моба
            local target, minDist = nil, math.huge
            for _,m in pairs(workspace.Enemies:GetChildren()) do
                if m:FindFirstChild("Humanoid") and m.Humanoid.Health > 0 then
                    local d = (hrp.Position - m.HumanoidRootPart.Position).Magnitude
                    if d < minDist then minDist = d; target = m end
                end
            end
            
            if target then
                -- 🔥 Передаём HumanoidRootPart моба в цикл камеры
                getgenv().CurrentTargetHRP = target.HumanoidRootPart
                local pos = target.HumanoidRootPart.Position
                
                -- Бег и обход препятствий вбок (без телепортов)
                local frontWall = workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 5)
                if frontWall then
                    local leftWall = workspace:Raycast(hrp.Position, -hrp.CFrame.RightVector * 5)
                    local side = leftWall and hrp.CFrame.RightVector or -hrp.CFrame.RightVector
                    char.Humanoid:MoveTo(hrp.Position + side * 6)
                    char.Humanoid.Jump = true
                else
                    char.Humanoid:MoveTo(pos)
                end
                
                -- Автоудар
                if minDist <= 8 then
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,1)
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,1)
                end
            else
                getgenv().CurrentTargetHRP = nil -- Мобов нет
            end
        end) 
    end
end)
