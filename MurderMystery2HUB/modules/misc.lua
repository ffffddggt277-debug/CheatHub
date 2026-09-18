--[[
    MurderMystery2HUB | modules/misc.lua
    ==================================================================
    Разное:
      * anti-AFK (не кикает за неактивность)
      * уведомления, когда раскрывается роль игрока
      * кол-аут ролей в чат (Murderer: ..., Sheriff: ...)
      * телепорт к убийце / шерифу
      * server hop (перейти на другой сервер)
      * перезапуск и выгрузка хаба
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

local M = {}

local Core

local state = {
    antiAfk     = false,
    roleNotify  = true,
    autoCallout = false,
    calloutText = "Murderer: ${murderer} | Sheriff: ${sheriff}",
}

local connections = {}
local alive = false

--[[ ------------------------- чат и кол-ауты ------------------------- ]]

local function sendChat(message)
    if type(message) ~= "string" or message == "" then
        return false
    end

    local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
    local sayRequest = chatEvents and chatEvents:FindFirstChild("SayMessageRequest")

    if not sayRequest then
        return false
    end

    return pcall(function()
        sayRequest:FireServer(message, "normalchat")
    end)
end

local function buildCallout()
    local murderer = Core.murderer()
    local sheriff = Core.sheriff()

    local text = state.calloutText or ""
    text = text:gsub("%${murderer}", murderer and murderer.Name or "?")
    text = text:gsub("%${sheriff}", sheriff and sheriff.Name or "?")

    return text
end

local function doCallout()
    local text = buildCallout()

    if sendChat(text) then
        Core.Notify("Кол-аут", text)
    else
        Core.Notify("Кол-аут", "чат недоступен на этом сервере")
    end
end

--[[ ---------------------------- телепорты ---------------------------- ]]

local function teleportToRole(role, label)
    local player = Core.findByRole(role)

    if not player then
        Core.Notify("Телепорт", label .. " сейчас не известен")
        return
    end

    local _, root = Core.getCharacter(player)

    if root and Core.teleport(root) then
        Core.Notify("Телепорт", label .. ": " .. player.Name)
    end
end

--[[ ---------------------------- server hop ---------------------------- ]]

local function serverHop()
    local placeId = game.PlaceId
    local url = "https://games.roblox.com/v1/games/" .. tostring(placeId) .. "/servers/Public?sortOrder=Asc&limit=100"

    local ok, response = pcall(function()
        return game:GetService("HttpService"):JSONDecode(game:HttpGet(url))
    end)

    if not ok or type(response) ~= "table" then
        Core.Notify("Server Hop", "не получилось получить список серверов")
        return
    end

    local servers = {}

    for _, server in ipairs(response.data or {}) do
        if server.id ~= game.JobId and (server.playing or 0) < (server.maxPlayers or 12) then
            table.insert(servers, server.id)
        end
    end

    if #servers == 0 then
        Core.Notify("Server Hop", "подходящих серверов не нашлось")
        return
    end

    local jobId = servers[math.random(1, #servers)]
    Core.Notify("Server Hop", "переходим на другой сервер...")

    pcall(function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(placeId, jobId, localPlayer)
    end)
end

--[[ ------------------------ перезапуск и выгрузка ------------------------ ]]

local function unloadHub()
    if _G.MM2HUB and type(_G.MM2HUB.Unload) == "function" then
        pcall(_G.MM2HUB.Unload)
    end
end

local function restartHub()
    if not Core.base then
        Core.Notify("Хаб", "BASE не передан из main.lua")
        return
    end

    Core.Notify("Хаб", "перезапускаем сборку...")
    unloadHub()
    task.wait(0.5)

    pcall(function()
        loadstring(game:HttpGet(Core.base .. "main.lua"))()
    end)
end

--[[ ------------------------------ anti-AFK ------------------------------ ]]

local function startAntiAfk()
    connections.antiAfk = localPlayer.Idled:Connect(function()
        local virtualUser = game:GetService("VirtualUser")

        pcall(function()
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new())
        end)
    end)
end

local function stopAntiAfk()
    if connections.antiAfk then
        connections.antiAfk:Disconnect()
        connections.antiAfk = nil
    end
end

--[[ ------------------------------ init ------------------------------ ]]

function M.Init(mainTab, core)
    Core = core
    alive = true

    local miscTab = core.ui and core.ui.GetTab and core.ui.GetTab("misc") or mainTab

    -- быстрые действия на вкладке "Главное"
    mainTab:CreateSection("Быстрые действия")

    mainTab:CreateButton({
        Name = "Телепорт к убийце",
        Callback = function()
            teleportToRole("Murderer", "убийца")
        end,
    })

    mainTab:CreateButton({
        Name = "Телепорт к шерифу",
        Callback = function()
            teleportToRole("Sheriff", "шериф")
        end,
    })

    mainTab:CreateButton({
        Name = "Сказать роли в чат",
        Callback = doCallout,
    })

    mainTab:CreateButton({
        Name = "Статус",
        Callback = function()
            local role = Core.localRole()
            local players = #Core.getPlayers(true)
            Core.Notify("Статус",
                "твоя роль: " .. role .. " | игроков: " .. players ..
                " | раунд: " .. tostring(Core.state.round))
        end,
    })

    -- вкладка "Разное"
    miscTab:CreateSection("Роли")

    miscTab:CreateToggle({
        Name = "Уведомлять о раскрытых ролях",
        CurrentValue = true,
        Flag = "Misc_RoleNotify",
        Callback = function(value)
            state.roleNotify = value
        end,
    })

    miscTab:CreateToggle({
        Name = "Авто-кол-аут ролей в чат",
        CurrentValue = false,
        Flag = "Misc_AutoCallout",
        Callback = function(value)
            state.autoCallout = value
        end,
    })

    miscTab:CreateInput({
        Name = "Текст кол-аута",
        CurrentValue = state.calloutText,
        PlaceholderText = "Murderer: ${murderer} | Sheriff: ${sheriff}",
        RemoveTextAfterFocusLost = false,
        Flag = "Misc_CalloutText",
        Callback = function(text)
            if type(text) == "string" and text ~= "" then
                state.calloutText = text
            end
        end,
    })

    miscTab:CreateSection("Сервер")

    miscTab:CreateToggle({
        Name = "Anti-AFK",
        CurrentValue = false,
        Flag = "Misc_AntiAfk",
        Callback = function(value)
            state.antiAfk = value

            if value then
                startAntiAfk()
            else
                stopAntiAfk()
            end
        end,
    })

    miscTab:CreateButton({
        Name = "Server Hop (другой сервер)",
        Callback = serverHop,
    })

    miscTab:CreateSection("Хаб")

    miscTab:CreateButton({
        Name = "Перезапустить сборку",
        Callback = restartHub,
    })

    miscTab:CreateButton({
        Name = "Выгрузить хаб",
        Callback = unloadHub,
    })

    miscTab:CreateLabel("Окно скрывается клавишей RightShift")

    -- уведомления и авто-кол-аут по ролям
    Core.onRoleChanged(function(player, role)
        if not alive then
            return
        end

        if role == "RoundEnd" then
            return
        end

        if state.roleNotify and player then
            Core.Notify("Роль", player.Name .. " -> " .. role)
        end

        if state.autoCallout and player then
            if role == "Murderer" or role == "Sheriff" then
                task.wait(0.3)
                doCallout()
            end
        end
    end)

    return M
end

function M.Destroy()
    alive = false
    stopAntiAfk()
end

return M
