getgenv().Farm = not getgenv().Farm

task.spawn(function()
    local p = game.Players.LocalPlayer
    local cam = workspace.CurrentCamera
    
    -- Настройки естественности камеры
    local camSpeed = 0.04 -- Чем МЕНЬШЕ число (от 0.02 до 0.05), тем МЯГЧЕ и естественнее поворот
    
    while getgenv().Farm do 
        task.wait(0.03) -- Небольшой интервал, чтобы избавиться от дергания при high FPS
        pcall(function()
            local c = p.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if not hrp or c.Humanoid.Health <= 0 then return end
            
            -- Экипировка оружия
            if not c:FindFirstChildOfClass("Tool") then 
                for _,t in pairs(p.Backpack:GetChildren()) do 
                    if t:IsA("Tool") then c.Humanoid:EquipTool(t) break end 
                end 
            end
            
            -- Поиск моба
            local target, minDist = nil, math.huge
            for _,m in pairs(workspace.Enemies:GetChildren()) do
                if m:FindFirstChild("Humanoid") and m.Humanoid.Health > 0 then
                    local d = (hrp.Position - m.HumanoidRootPart.Position).Magnitude
                    if d < minDist then minDist = d; target = m end
                end
            end
            
            if target then
                local pos = target.HumanoidRootPart.Position
                local hrpPos = hrp.Position
                
                -- 1. Персонаж смотрит на моба
                hrp.CFrame = CFrame.lookAt(hrpPos, Vector3.new(pos.X, hrpPos.Y, pos.Z))
                
                -- 2. 🔥 ЕСТЕСТВЕННАЯ ТРАССИРОВКА КАМЕРЫ
                -- Вычисляем идеальную точку взгляда (чуть выше моба, как смотрит реальный игрок)
                local targetCamFocus = pos + Vector3.new(0, 2.5, 0)
                local desiredCamCFrame = CFrame.new(cam.CFrame.Position, targetCamFocus)
                
                -- Плавное сглаживание движения
                cam.CFrame = cam.CFrame:Lerp(desiredCamCFrame, camSpeed)
                
                -- 3. Бег и обход препятствий вбок
                local frontWall = workspace:Raycast(hrpPos, hrp.CFrame.LookVector * 4)
                if frontWall then
                    local leftWall = workspace:Raycast(hrpPos, -hrp.CFrame.RightVector * 4)
                    local side = leftWall and hrp.CFrame.RightVector or -hrp.CFrame.RightVector
                    c.Humanoid:MoveTo(hrpPos + side * 5)
                    c.Humanoid.Jump = true
                else
                    c.Humanoid:MoveTo(pos)
                end
                
                -- 4. Автоудар
                if minDist <= 7.5 then
                    game:GetService("VirtualInputManager"):SendMouseButtonEvent(0,0,0,true,game,1)
                    game:GetService("VirtualInputManager"):SendMouseButtonEvent(0,0,0,false,game,1)
                end
            end
        end) 
    end
end)
