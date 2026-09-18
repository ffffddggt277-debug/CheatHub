--[[
    MurderMystery2HUB | modules/esp.lua
    ==================================================================
    Визуал: подсветка игроков по ролям (Highlight), монеты, дропнутая пушка,
    трейсеры (Drawing) и текст над головой с ролью и дистанцией.

    Всё строится на Core: роли берём из Core.roles, объекты - через Core.getCoin()/getGunDrop().
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

local M = {}

local COLORS = {
    Murderer = Color3.fromRGB(255, 60, 60),
    Sheriff  = Color3.fromRGB(70, 140, 255),
    Hero     = Color3.fromRGB(255, 220, 60),
    Innocent = Color3.fromRGB(235, 235, 235),
    Unknown  = Color3.fromRGB(140, 140, 140),
}

local CoinColor = Color3.fromRGB(255, 200, 40)
local GunColor  = Color3.fromRGB(80, 255, 190)

local settings = {
    players  = true,   -- подсветка игроков
    coins    = true,   -- подсветка монет
    gun      = true,   -- подсветка дропнутой пушки
    tracers  = false,  -- линии до цели
    nametags = false,  -- текст над головой
}

local Core, ui

local highlights = {}   -- [player] = Highlight
local tracers = {}      -- [player] = Drawing.Line
local nametags = {}     -- [player] = BillboardGui
local coinHighlight, gunHighlight
local watchConn
local alive = false

--[[ --------------------------- утилиты --------------------------- ]]

-- Куда вешать GUI: gethui() прячет от игры, если executor это умеет.
local function getGuiParent()
    if type(gethui) == "function" then
        local ok, parent = pcall(gethui)
        if ok and parent then
            return parent
        end
    end
    return game:GetService("CoreGui")
end

local function protect(instance)
    if type(syn) == "table" and type(syn.protect_gui) == "function" then
        pcall(syn.protect_gui, instance)
    end
    if type(protectgui) == "function" then
        pcall(protectgui, instance)
    end
end

local function roleColor(player)
    return COLORS[Core.roleOf(player)] or COLORS.Unknown
end

local function makeHighlight(color)
    local highlight = Instance.new("Highlight")
    highlight.FillColor = color
    highlight.FillTransparency = 0.55
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = false
    pcall(function()
        highlight.RobloxLocked = true
    end)
    protect(highlight)
    highlight.Parent = getGuiParent()
    return highlight
end

--[[ --------------------------- игроки --------------------------- ]]

local function addPlayer(player)
    if player == localPlayer or highlights[player] then
        return
    end

    highlights[player] = makeHighlight(roleColor(player))

    local function onCharacter(character)
        local highlight = highlights[player]
        if highlight then
            highlight.Adornee = character
        end

        -- текст над головой
        if nametags[player] then
            nametags[player]:Destroy()
            nametags[player] = nil
        end
    end

    player.CharacterAdded:Connect(onCharacter)
    if player.Character then
        onCharacter(player.Character)
    end
end

local function removePlayer(player)
    if highlights[player] then
        highlights[player]:Destroy()
        highlights[player] = nil
    end

    if tracers[player] then
        pcall(function()
            tracers[player]:Remove()
        end)
        tracers[player] = nil
    end

    if nametags[player] then
        nametags[player]:Destroy()
        nametags[player] = nil
    end
end

--[[ -------------------------- трейсеры -------------------------- ]]

local function hasDrawing()
    return type(Drawing) == "table" and type(Drawing.new) == "function"
end

local function newTracer()
    if not hasDrawing() then
        return nil
    end

    local ok, line = pcall(Drawing.new, "Line")
    if not ok or not line then
        return nil
    end

    pcall(function()
        line.Thickness = 1
        line.Transparency = 0.4
        line.Visible = false
        line.From = Vector2.zero
        line.To = Vector2.zero
    end)

    return line
end

--[[ ------------------------ текст над головой ------------------------ ]]

local function makeNametag(player)
    local _, root = Core.getCharacter(player)
    if not root then
        return nil
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MM2HUB_Nametag"
    billboard.Size = UDim2.new(0, 200, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = root
    protect(billboard)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextStrokeTransparency = 0.3
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Text = ""
    label.Parent = billboard

    billboard.Parent = getGuiParent()
    return billboard
end

--[[ --------------------------- монеты --------------------------- ]]

local function refreshCoinHighlight()
    local coin = settings.coins and Core.getCoin() or nil

    if coin then
        if not coinHighlight then
            coinHighlight = makeHighlight(CoinColor)
        end
        coinHighlight.Adornee = coin
        coinHighlight.FillColor = CoinColor
        coinHighlight.OutlineColor = CoinColor
        coinHighlight.Enabled = true
    elseif coinHighlight then
        coinHighlight.Enabled = false
    end
end

local function refreshGunHighlight()
    local gun = settings.gun and Core.getGunDrop() or nil

    if gun then
        if not gunHighlight then
            gunHighlight = makeHighlight(GunColor)
        end
        gunHighlight.Adornee = gun
        gunHighlight.FillColor = GunColor
        gunHighlight.OutlineColor = GunColor
        gunHighlight.Enabled = true
    elseif gunHighlight then
        gunHighlight.Enabled = false
    end
end

--[[ ---------------------------- обновление ---------------------------- ]]

local function updatePlayers()
    local camera = Workspace.CurrentCamera

    for player, highlight in pairs(highlights) do
        if player.Parent ~= Players then
            removePlayer(player)
        else
            local character, root, humanoid = Core.getCharacter(player)
            local visible = settings.players and root ~= nil and humanoid ~= nil and humanoid.Health > 0

            highlight.Enabled = visible
            if visible then
                local color = roleColor(player)
                highlight.FillColor = color
                highlight.OutlineColor = color
                highlight.Adornee = character
            end

            -- текст над головой
            if settings.nametags and visible then
                if not nametags[player] then
                    nametags[player] = makeNametag(player)
                end

                local billboard = nametags[player]
                if billboard then
                    billboard.Enabled = true

                    if billboard.Adornee ~= root then
                        billboard.Adornee = root
                    end

                    local label = billboard:FindFirstChildOfClass("TextLabel")
                    local localRoot = select(2, Core.getCharacter(localPlayer))
                    local distance = localRoot and math.floor((root.Position - localRoot.Position).Magnitude) or 0

                    if label then
                        label.Text = string.format("%s | %s | %dm",
                            player.Name, Core.roleOf(player), distance)
                        label.TextColor3 = roleColor(player)
                    end
                end
            elseif nametags[player] then
                nametags[player].Enabled = false
            end

            -- трейсеры
            local line = tracers[player]
            if settings.tracers and hasDrawing() and visible and camera then
                if not line then
                    line = newTracer()
                    tracers[player] = line
                end

                if line then
                    local screen, onScreen = camera:WorldToViewportPoint(root.Position)
                    local viewport = camera.ViewportSize

                    pcall(function()
                        line.From = Vector2.new(viewport.X / 2, viewport.Y)
                        line.To = Vector2.new(screen.X, screen.Y)
                        line.Color = roleColor(player)
                        line.Visible = onScreen
                    end)
                end
            elseif line then
                pcall(function()
                    line.Visible = false
                end)
            end
        end
    end
end

--[[ ------------------------------ init ------------------------------ ]]

function M.Init(tab, core)
    Core = core
    ui = core and core.ui

    tab:CreateSection("Игроки")

    tab:CreateToggle({
        Name = "ESP игроков (по ролям)",
        CurrentValue = settings.players,
        Flag = "ESP_Players",
        Callback = function(value)
            settings.players = value
        end,
    })

    tab:CreateToggle({
        Name = "Текст над головой (роль + дистанция)",
        CurrentValue = settings.nametags,
        Flag = "ESP_Nametags",
        Callback = function(value)
            settings.nametags = value
        end,
    })

    tab:CreateToggle({
        Name = "Трейсеры (нужен Drawing)",
        CurrentValue = settings.tracers,
        Flag = "ESP_Tracers",
        Callback = function(value)
            settings.tracers = value
            if value and not hasDrawing() then
                Core.Notify("ESP", "Executor не поддерживает Drawing - трейсеры не будут работать")
            end
        end,
    })

    tab:CreateSection("Предметы")

    tab:CreateToggle({
        Name = "ESP монет",
        CurrentValue = settings.coins,
        Flag = "ESP_Coins",
        Callback = function(value)
            settings.coins = value
        end,
    })

    tab:CreateToggle({
        Name = "ESP дропнутой пушки",
        CurrentValue = settings.gun,
        Flag = "ESP_Gun",
        Callback = function(value)
            settings.gun = value
        end,
    })

    tab:CreateSection("Цвета ролей")

    tab:CreateLabel("Убийца - красный, шериф - синий, герой - жёлтый, мирный - белый")

    tab:CreateColorPicker({
        Name = "Цвет убийцы",
        Color = COLORS.Murderer,
        Flag = "ESP_Color_Murderer",
        Callback = function(color)
            COLORS.Murderer = color
        end,
    })

    tab:CreateColorPicker({
        Name = "Цвет шерифа",
        Color = COLORS.Sheriff,
        Flag = "ESP_Color_Sheriff",
        Callback = function(color)
            COLORS.Sheriff = color
        end,
    })

    -- подключаемся ко всем игрокам и к новым
    for _, player in ipairs(Players:GetPlayers()) do
        addPlayer(player)
    end

    Players.PlayerAdded:Connect(addPlayer)
    Players.PlayerRemoving:Connect(removePlayer)

    -- Цикл обновления. Полный проход делаем ~20 раз в секунду, иначе поиск монет
    -- и пересчёт дистанций каждый кадр просаживает FPS.
    local accumulator = 0

    alive = true
    watchConn = RunService.RenderStepped:Connect(function(delta)
        if not alive then
            return
        end

        accumulator = accumulator + (delta or 0)
        if accumulator < 0.05 then
            return
        end
        accumulator = 0

        pcall(function()
            updatePlayers()
            refreshCoinHighlight()
            refreshGunHighlight()
        end)
    end)

    return M
end

function M.Destroy()
    alive = false

    if watchConn then
        watchConn:Disconnect()
        watchConn = nil
    end

    -- сначала собираем список игроков, потом чистим: во время обхода менять таблицу нельзя
    local players = {}
    for player in pairs(highlights) do
        table.insert(players, player)
    end

    for _, player in ipairs(players) do
        removePlayer(player)
    end

    if coinHighlight then
        coinHighlight:Destroy()
        coinHighlight = nil
    end

    if gunHighlight then
        gunHighlight:Destroy()
        gunHighlight = nil
    end

    highlights, tracers, nametags = {}, {}, {}
end

return M
