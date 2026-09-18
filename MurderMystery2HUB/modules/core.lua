--[[
    MurderMystery2HUB | modules/core.lua
    ==================================================================
    Ядро: роли игроков, поиск персонажа/оружия/монеты, телепорт, уведомления.
    Остальные модули (esp, aimbot, farming, movement, misc) работают через Core,
    поэтому игровая логика лежит в одном месте и её легко править.

    Роли в MM2 приходят с сервера событиями:
        ReplicatedStorage.Fade.OnClientEvent            -> { [имя игрока] = { Role = "Murderer" } }
        ReplicatedStorage.UpdatePlayerData.OnClientEvent
        ReplicatedStorage.RoleSelect.OnClientEvent      -> роль локального игрока
        ReplicatedStorage.Remotes.Gameplay.RoundEndFade -> конец раунда, роли сбрасываются
    Плюс запасной вариант: у убийцы в руках "Knife", у шерифа - "Gun".
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

local Core = {}

Core.ui      = nil               -- ссылка на модуль ui (уведомления)
Core.roles   = {}                -- [player] = "Murderer" / "Sheriff" / "Hero" / "Innocent" / "Unknown"
Core.ready   = false
Core.state   = { coins = 0, round = 0 }

local connections = {}           -- все соединения ядра
local roleListeners = {}         -- колбэки на смену роли

--[[ ---------------------------- утилиты ---------------------------- ]]

-- Запоминаем соединение, чтобы отключить его в Destroy().
local function track(connection)
    table.insert(connections, connection)
    return connection
end

-- Ищем вложенный объект по цепочке имён: getChildChain(RS, {"Remotes", "Gameplay"})
local function getChildChain(root, names)
    local node = root

    for _, name in ipairs(names) do
        if not node then
            return nil
        end
        node = node:FindFirstChild(name)
    end

    return node
end

Core.getChildChain = getChildChain

-- Уведомление: и в интерфейс, и в консоль (F9).
function Core.Notify(title, text)
    if Core.ui and Core.ui.Notify then
        Core.ui.Notify(title, text)
    end
    print("[MM2HUB] " .. tostring(title) .. " | " .. tostring(text))
end

--[[ ------------------------- игровые объекты ------------------------- ]]

-- Возвращает character, root (HumanoidRootPart), humanoid
function Core.getCharacter(player)
    player = player or localPlayer
    if not player then
        return nil, nil, nil
    end

    local character = player.Character
    if not character or not character.Parent then
        return nil, nil, nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart

    return character, root, humanoid
end

function Core.isAlive(player)
    local character, root, humanoid = Core.getCharacter(player)
    return (character and root and humanoid and humanoid.Health > 0) or false
end

-- Локальный игрок и все остальные живые игроки
function Core.getPlayers(includeLocal)
    local list = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if (includeLocal or player ~= localPlayer) and Core.isAlive(player) then
            table.insert(list, player)
        end
    end

    return list
end

-- Оружие в руках (Tool): "Knife" у убийцы, "Gun"/"Revolver" у шерифа
function Core.getTool(player, names)
    local character = Core.getCharacter(player)

    if not character then
        return nil
    end

    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            if not names then
                return tool
            end

            for _, name in ipairs(names) do
                if tool.Name:lower():find(name:lower(), 1, true) then
                    return tool
                end
            end
        end
    end

    return nil
end

function Core.getKnife(player)
    return Core.getTool(player, { "Knife" })
end

function Core.getGun(player)
    return Core.getTool(player, { "Gun", "Revolver", "Pistol" })
end

-- Монета для автофарма: она лежит в workspace.CoinContainer и зовётся Coin_Server
function Core.getCoin()
    local container = Workspace:FindFirstChild("CoinContainer", true)

    if not container then
        return nil
    end

    local coin = container:FindFirstChild("Coin_Server")

    if coin then
        return coin
    end

    -- запасной вариант: любая часть с "coin" в имени
    for _, child in ipairs(container:GetDescendants()) do
        if child:IsA("BasePart") and child.Name:lower():find("coin", 1, true) then
            return child
        end
    end

    return nil
end

-- Дропнутая пушка шерифа
function Core.getGunDrop()
    return Workspace:FindFirstChild("GunDrop")
end

--[[ ---------------------------- телепорт ---------------------------- ]]

-- Мягкий телепорт: двигаем только HumanoidRootPart, персонаж остаётся живым.
-- Цель - CFrame, Vector3 или BasePart.
function Core.teleport(target)
    local character, root = Core.getCharacter()

    if not character or not root then
        return false
    end

    local cframe
    if typeof(target) == "CFrame" then
        cframe = target
    elseif typeof(target) == "Vector3" then
        cframe = CFrame.new(target)
    elseif typeof(target) == "Instance" and target:IsA("BasePart") then
        cframe = CFrame.new(target.Position + Vector3.new(0, 2, 0))
    else
        return false
    end

    root.CFrame = cframe
    return true
end

--[[ ------------------------------ роли ------------------------------ ]]

function Core.roleOf(player)
    if not player then
        return "Unknown"
    end
    return Core.roles[player] or "Unknown"
end

function Core.localRole()
    return Core.roleOf(localPlayer)
end

function Core.findByRole(role)
    for player, value in pairs(Core.roles) do
        if value == role and player.Parent == Players and Core.isAlive(player) then
            return player
        end
    end
    return nil
end

function Core.murderer()
    return Core.findByRole("Murderer")
end

function Core.sheriff()
    return Core.findByRole("Sheriff")
end

-- Подписка на смену роли: Core.onRoleChanged(function(player, role) end)
function Core.onRoleChanged(callback)
    table.insert(roleListeners, callback)
end

function Core.setRole(player, role)
    if not player or type(role) ~= "string" then
        return
    end

    role = role:gsub("^%l", string.upper) -- "murderer" -> "Murderer"
    if Core.roles[player] == role then
        return
    end

    Core.roles[player] = role

    for _, callback in ipairs(roleListeners) do
        pcall(callback, player, role)
    end
end

-- Событие отдаёт таблицу вида { ["Nick"] = { Role = "Sheriff" } }
local function applyRoleData(data)
    if type(data) ~= "table" then
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        local info = data[player.Name]

        if info ~= nil then
            local role = type(info) == "table" and info.Role or info

            if type(role) == "string" then
                pcall(Core.setRole, player, role)
            end
        end
    end
end

-- Запасное определение ролей по предметам в руках (если события не поймали).
local function scanRolesByTools()
    for _, player in ipairs(Players:GetPlayers()) do
        if Core.isAlive(player) then
            if Core.getKnife(player) then
                Core.setRole(player, "Murderer")
            elseif Core.getGun(player) then
                Core.setRole(player, "Sheriff")
            end
        end
    end
end

local function onRoundEnd()
    Core.roles = {}
    Core.state.round = Core.state.round + 1

    for _, callback in ipairs(roleListeners) do
        pcall(callback, nil, "RoundEnd")
    end
end

-- Подписываемся на событие по цепочке имён. Работает и с RemoteEvent, и с BindableEvent.
local function bindEvent(path, handler)
    local event = getChildChain(ReplicatedStorage, path)

    if not event then
        return false
    end

    local signal = event.OnClientEvent or event.Event
    if not signal then
        return false
    end

    track(signal:Connect(function(...)
        pcall(handler, ...)
    end))

    print("[MM2HUB] Подписался на " .. table.concat(path, "."))
    return true
end

local function bindRoles()
    -- 1) события сервера
    local events = {
        { { "Fade" }, applyRoleData },
        { { "UpdatePlayerData" }, applyRoleData },
        { { "RoleSelect" }, function(role)
            pcall(Core.setRole, localPlayer, role or "Unknown")
        end },
        { { "Remotes", "Gameplay", "RoundEndFade" }, onRoundEnd },
    }

    local pending = {}

    for _, entry in ipairs(events) do
        if not bindEvent(entry[1], entry[2]) then
            table.insert(pending, entry)
        end
    end

    -- Если события не нашлись сразу (игра ещё догружает объекты) - пробуем позже.
    if #pending > 0 then
        print("[MM2HUB] Не все события найдены сразу, буду искать дальше: " .. #pending)

        task.spawn(function()
            for _ = 1, 15 do
                task.wait(2)

                if not Core.ready then
                    return
                end

                local rest = {}

                for _, entry in ipairs(pending) do
                    if not bindEvent(entry[1], entry[2]) then
                        table.insert(rest, entry)
                    end
                end

                pending = rest
                if #pending == 0 then
                    return
                end
            end
        end)
    end

    -- 2) запасной скан предметов раз в секунду
    task.spawn(function()
        while Core.ready do
            pcall(scanRolesByTools)
            task.wait(1)
        end
    end)

    -- 3) чистим ушедших игроков
    track(Players.PlayerRemoving:Connect(function(player)
        Core.roles[player] = nil
    end))
end

--[[ ------------------------------ init ------------------------------ ]]

function Core.Init(ui)
    Core.ui = ui
    Core.ready = true

    bindRoles()

    return Core
end

-- Отключить всё: соединения ядра и подсветки/циклы модулей вызываются их Destroy().
function Core.Destroy()
    Core.ready = false

    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    connections = {}
    roleListeners = {}
    Core.roles = {}
end

return Core
