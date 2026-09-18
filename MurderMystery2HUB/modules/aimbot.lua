--[[
    MurderMystery2HUB | modules/aimbot.lua
    ==================================================================
    Боевая часть:
      * Silent Aim - подмена координаты выстрела в remote "ShootGun" (InvokeServer)
      * Авто-выстрел - довод камеры на цель + gun:Activate()
      * Нож - Reach (hitbox через firetouchinterest), Kill Aura, авто-телепорт к цели

    Важно: hookmetamethod / firetouchinterest есть не во всех executor'ах,
    поэтому всё обёрнуто в проверки и pcall - без них модуль просто ничего не делает.
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

local M = {}

local Core, ui

local state = {
    silentAim     = false,   -- подмена цели в ShootGun
    silentOnlyMurderer = true,
    prediction    = 10,      -- % предсказания движения цели
    autoShoot     = false,
    aimCamera     = true,
    shootDistance = 500,
    shootDelay    = 0.55,    -- пауза между выстрелами (у пушки есть откат)
    reach         = false,   -- увеличенный хитбокс ножа
    reachAngle    = 60,
    killAura      = false,
    auraRadius    = 12,
    teleportStab  = false,
}

local alive = false
local lastShot = 0
local lastStab = 0
local hookInstalled = false
local silentAimActive = false  -- флаг для клавиши-бинда

--[[ --------------------------- утилиты --------------------------- ]]

local unpackFn = table.unpack or unpack

local function rootOf(player)
    local _, root = Core.getCharacter(player)
    return root
end

-- Позиция цели с учётом её скорости (предсказание)
local function aimPosition(target)
    local root = target and rootOf(target)
    if not root then
        return nil
    end

    local velocity = root.AssemblyLinearVelocity or root.Velocity or Vector3.zero
    return root.Position + velocity * (state.prediction / 100)
end

-- Выбираем цель: убийца (если включено) или ближайший живой игрок
local function selectTarget()
    local localRoot = select(2, Core.getCharacter(localPlayer))
    if not localRoot then
        return nil
    end

    if state.silentOnlyMurderer then
        local murderer = Core.murderer()
        if murderer and rootOf(murderer) then
            return murderer
        end
    end

    local best, bestDistance = nil, math.huge

    for _, player in ipairs(Core.getPlayers(false)) do
        local root = rootOf(player)
        if root then
            local distance = (root.Position - localRoot.Position).Magnitude
            if distance < bestDistance then
                best, bestDistance = player, distance
            end
        end
    end

    return best
end

--[[ -------------------------- silent aim -------------------------- ]]

-- Перехватываем вызов remote'а ShootGun и подменяем координату выстрела.
local function installSilentAim()
    if hookInstalled then
        return true
    end

    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
        Core.Notify("Silent Aim", "Executor не поддерживает hookmetamethod")
        return false
    end

    local newcclosureFn = type(newcclosure) == "function" and newcclosure or function(fn)
        return fn
    end

    local ok = pcall(function()
        local original
        original = hookmetamethod(game, "__namecall", newcclosureFn(function(self, ...)
            local method = getnamecallmethod()

            if silentAimActive
                and type(checkcaller) == "function" and not checkcaller()
                and typeof(self) == "Instance" and self.Name == "ShootGun"
                and method == "InvokeServer" then
                local args = table.pack(...)
                local position = aimPosition(selectTarget())

                if position then
                    args[2] = position
                end

                return original(self, unpackFn(args, 1, args.n))
            end

            return original(self, ...)
        end))
    end)

    if not ok then
        Core.Notify("Silent Aim", "Не удалось поставить хук (executor защищает метаметоды)")
        return false
    end

    hookInstalled = true
    silentAimActive = state.silentAim
    return true
end

--[[ ------------------------- авто-выстрел ------------------------- ]]

local function doAutoShoot()
    if not state.autoShoot then
        return
    end

    if os.clock() - lastShot < state.shootDelay then
        return
    end

    local character, root, humanoid = Core.getCharacter(localPlayer)
    if not character or not root or not humanoid or humanoid.Health <= 0 then
        return
    end

    local gun = Core.getGun(localPlayer)
    if not gun then
        return
    end

    local target = selectTarget()
    local targetRoot = target and rootOf(target)
    if not target or not targetRoot then
        return
    end

    if (targetRoot.Position - root.Position).Magnitude > state.shootDistance then
        return
    end

    -- доводим камеру, чтобы выстрел ушёл в цель
    if state.aimCamera then
        local camera = Workspace.CurrentCamera
        if camera then
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetRoot.Position)
        end
    end

    lastShot = os.clock()
    pcall(function()
        gun:Activate()
    end)
end

--[[ ----------------------------- нож ----------------------------- ]]

-- Урон ножом идёт через касание: touchinterest включаем и сразу выключаем.
local function knifeTouch(otherPart)
    local knife = Core.getKnife(localPlayer)

    if not knife or not knife:FindFirstChild("Handle") or type(firetouchinterest) ~= "function" then
        return false
    end

    pcall(function()
        firetouchinterest(otherPart, knife.Handle, 1)
        firetouchinterest(otherPart, knife.Handle, 0)
    end)

    return true
end

local function doKnife()
    if not state.reach and not state.killAura and not state.teleportStab then
        return
    end

    local character, root = Core.getCharacter(localPlayer)
    if not character or not root then
        return
    end

    local knife = Core.getKnife(localPlayer)
    if not knife then
        return
    end

    local lookVector = root.CFrame.LookVector

    for _, player in ipairs(Core.getPlayers(false)) do
        local targetRoot = rootOf(player)
        if targetRoot then
            local offset = targetRoot.Position - root.Position
            local distance = offset.Magnitude

            -- угол между взглядом и целью
            local angle = 180
            if distance > 0 then
                angle = math.deg(math.acos(math.clamp(lookVector:Dot(offset.Unit), -1, 1)))
            end

            local normalHit = state.reach
                and distance <= 10 + state.reachAngle * 0.05
                and angle <= state.reachAngle

            if normalHit or (state.killAura and distance <= state.auraRadius) then
                knifeTouch(targetRoot)

            elseif state.teleportStab and distance <= 25 and os.clock() - lastStab > 0.35 then
                lastStab = os.clock()

                -- заходим в спину и бьём
                local behind = targetRoot.CFrame * CFrame.new(0, 0, 2.5)
                root.CFrame = CFrame.lookAt(behind.Position, targetRoot.Position)
                task.wait()
                knifeTouch(targetRoot)
            end
        end
    end
end

--[[ ------------------------------ init ------------------------------ ]]

function M.Init(tab, core)
    Core = core
    ui = core and core.ui

    tab:CreateSection("Шериф / стрельба")

    tab:CreateToggle({
        Name = "Silent Aim (выстрел всегда в цель)",
        CurrentValue = false,
        Flag = "Aim_Silent",
        Callback = function(value)
            if value and not installSilentAim() then
                return
            end
            state.silentAim = value
            silentAimActive = value
        end,
    })

    tab:CreateKeybind({
        Name = "Бинд Silent Aim",
        CurrentKeybind = "G",
        HoldToInteract = false,
        Flag = "Aim_Silent_Bind",
        Callback = function()
            state.silentAim = not state.silentAim
            silentAimActive = state.silentAim
            Core.Notify("Silent Aim", state.silentAim and "включён" or "выключен")
        end,
    })

    tab:CreateToggle({
        Name = "Целиться только в убийцу",
        CurrentValue = true,
        Flag = "Aim_OnlyMurderer",
        Callback = function(value)
            state.silentOnlyMurderer = value
        end,
    })

    tab:CreateSlider({
        Name = "Предсказание движения",
        Range = {0, 100},
        Increment = 1,
        Suffix = "%",
        CurrentValue = 10,
        Flag = "Aim_Prediction",
        Callback = function(value)
            state.prediction = value
        end,
    })

    tab:CreateToggle({
        Name = "Авто-выстрел (нужна пушка)",
        CurrentValue = false,
        Flag = "Aim_AutoShoot",
        Callback = function(value)
            state.autoShoot = value
        end,
    })

    tab:CreateToggle({
        Name = "Доводить камеру на цель",
        CurrentValue = true,
        Flag = "Aim_Camera",
        Callback = function(value)
            state.aimCamera = value
        end,
    })

    tab:CreateSlider({
        Name = "Дальность стрельбы",
        Range = {50, 2000},
        Increment = 50,
        Suffix = "studs",
        CurrentValue = 500,
        Flag = "Aim_Distance",
        Callback = function(value)
            state.shootDistance = value
        end,
    })

    tab:CreateSlider({
        Name = "Пауза между выстрелами",
        Range = {0.1, 3},
        Increment = 0.05,
        Suffix = "сек",
        CurrentValue = 0.55,
        Flag = "Aim_Delay",
        Callback = function(value)
            state.shootDelay = value
        end,
    })

    tab:CreateSection("Убийца / нож")

    tab:CreateToggle({
        Name = "Reach (хитбокс ножа)",
        CurrentValue = false,
        Flag = "Knife_Reach",
        Callback = function(value)
            state.reach = value
            if value and type(firetouchinterest) ~= "function" then
                Core.Notify("Нож", "Executor не поддерживает firetouchinterest")
            end
        end,
    })

    tab:CreateSlider({
        Name = "Угол удара ножом",
        Range = {10, 180},
        Increment = 5,
        Suffix = "°",
        CurrentValue = 60,
        Flag = "Knife_Angle",
        Callback = function(value)
            state.reachAngle = value
        end,
    })

    tab:CreateToggle({
        Name = "Kill Aura (бить всех рядом)",
        CurrentValue = false,
        Flag = "Knife_Aura",
        Callback = function(value)
            state.killAura = value
        end,
    })

    tab:CreateSlider({
        Name = "Радиус Kill Aura",
        Range = {5, 60},
        Increment = 1,
        Suffix = "studs",
        CurrentValue = 12,
        Flag = "Knife_AuraRadius",
        Callback = function(value)
            state.auraRadius = value
        end,
    })

    tab:CreateToggle({
        Name = "Авто-телепорт к цели (нож)",
        CurrentValue = false,
        Flag = "Knife_TeleportStab",
        Callback = function(value)
            state.teleportStab = value
            if value then
                Core.Notify("Нож", "Работает только когда у тебя нож убийцы")
            end
        end,
    })

    tab:CreateLabel("Silent Aim и Reach работают только у той роли, у которой есть оружие")

    alive = true
    local connection = RunService.RenderStepped:Connect(function()
        if not alive then
            return
        end
        local ok, err = pcall(function()
            doAutoShoot()
            doKnife()
        end)
        if not ok then
            warn("[MM2HUB] aimbot: " .. tostring(err))
        end
    end)

    -- вызывается в Destroy
    M._connection = connection

    return M
end

function M.Destroy()
    alive = false
    silentAimActive = false
    state.silentAim = false
    state.autoShoot = false

    if M._connection then
        M._connection:Disconnect()
        M._connection = nil
    end
end

return M
