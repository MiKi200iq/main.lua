getgenv().Farm = not getgenv().Farm

-- ===== НАСТРОЙКИ АВТОПРОКАЧКИ =====
local STAT_CONFIG = {
    Melee   = true,   -- качать рукопашный бой
    Defense = true,   -- качать защиту
    Sword   = false,  -- качать меч
    Gun     = false,  -- качать оружие
    Fruit   = false,  -- качать дьявольский плод (Blox Fruit)
}
-- ===================================

task.spawn(function()
    local p = game.Players.LocalPlayer
    local cam = workspace.CurrentCamera
    
    -- Настройки камеры
    local camSpeed = 0.04
    
    -- Переменная для отслеживания уровня
    local lastLevel = 0
    if p.Data and p.Data.Level then
        lastLevel = p.Data.Level.Value
    end

    -- ФУНКЦИЯ АВТОРАСПРЕДЕЛЕНИЯ СТАТОВ
    local function autoStat()
        if not p.Data then return end

        -- Проверяем наличие очков
        local points = p.Data:FindFirstChild("Points")
        if not points then return end
        local available = points.Value
        if available <= 0 then return end

        -- Собираем статы, которые нужно качать
        local statsToUp = {}
        if STAT_CONFIG.Melee  then table.insert(statsToUp, "Melee") end
        if STAT_CONFIG.Defense then table.insert(statsToUp, "Defense") end
        if STAT_CONFIG.Sword  then table.insert(statsToUp, "Sword") end
        if STAT_CONFIG.Gun    then table.insert(statsToUp, "Gun") end
        if STAT_CONFIG.Fruit  then table.insert(statsToUp, "Blox Fruit") end

        if #statsToUp == 0 then return end

        -- Находим удалённый ремоут для добавления очков
        local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        if not remote then return end
        local commF = remote:FindFirstChild("CommF_")
        if not commF then return end

        -- Распределяем все доступные очки по кругу
        local idx = 1
        while available > 0 do
            local statName = statsToUp[idx]
            if not statName then break end

            -- Проверяем, существует ли такой стат у игрока
            if p.Data:FindFirstChild(statName) then
                commF:InvokeServer("AddPoint", statName)
                available = available - 1
            end

            idx = idx + 1
            if idx > #statsToUp then idx = 1 end
            task.wait(0.1) -- небольшая задержка
        end
    end

    -- ОСНОВНОЙ ЦИКЛ ФАРМА
    while getgenv().Farm do 
        task.wait(0.03)
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
                
                -- 2. Естественная трассировка камеры
                local targetCamFocus = pos + Vector3.new(0, 2.5, 0)
                local desiredCamCFrame = CFrame.new(cam.CFrame.Position, targetCamFocus)
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

            -- ===== АВТОПРОКАЧКА (проверка уровня) =====
            if p.Data and p.Data.Level then
                local currentLevel = p.Data.Level.Value
                if currentLevel > lastLevel then
                    lastLevel = currentLevel
                    autoStat()
                end
            end
            -- =========================================
        end) 
    end
end)

print("Farm " .. (getgenv().Farm and "ON" or "OFF"))
