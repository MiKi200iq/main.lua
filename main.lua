getgenv().Farm = not getgenv().Farm

task.spawn(function()
    while getgenv().Farm do task.wait(0.1) pcall(function()
        local p, c, cam = game.Players.LocalPlayer, game.Players.LocalPlayer.Character, workspace.CurrentCamera
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hrp or c.Humanoid.Health <= 0 then return end
        
        -- Взять оружие
        if not c:FindFirstChildOfClass("Tool") then for _,t in pairs(p.Backpack:GetChildren()) do if t:IsA("Tool") then c.Humanoid:EquipTool(t) break end end end
        
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
            
            -- Плавная камера + поворот тела
            hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(pos.X, hrp.Position.Y, pos.Z))
            cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, hrp.Position + hrp.CFrame.LookVector * 10), 0.1)
            
            -- УМНЫЙ ОБХОД (Raycast прямо и по бокам)
            local frontWall = workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 4)
            if frontWall then
                -- Если впереди стена, проверяем где свободно — слева или справа
                local leftWall = workspace:Raycast(hrp.Position, -hrp.CFrame.RightVector * 4)
                local detourSide = leftWall and hrp.CFrame.RightVector or -hrp.CFrame.RightVector
                
                -- Шаг вбок для обхода + прыжок
                c.Humanoid:MoveTo(hrp.Position + detourSide * 5)
                c.Humanoid.Jump = true
            else
                -- Если путь чист — бежим прямиком к мобу
                c.Humanoid:MoveTo(pos)
            end
            
            -- Авто-атака
            if minDist <= 7.5 then
                game:GetService("VirtualInputManager"):SendMouseButtonEvent(0,0,0,true,game,1)
                game:GetService("VirtualInputManager"):SendMouseButtonEvent(0,0,0,false,game,1)
            end
        end
    end) end
end)