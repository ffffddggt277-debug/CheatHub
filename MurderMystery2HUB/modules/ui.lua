--[[
    MurderMystery2HUB | modules/ui.lua
    ==================================================================
    Интерфейс (Rayfield): окно + вкладки.
    Возвращает таблицу M с функциями Build / GetTab / Notify / GetWindow / Destroy.

    В конце файла обязательно "return M" - иначе loadstring(...)() вернёт nil.
]]

local M = {}

-- main.lua кладёт сюда номер сборки, он попадает в подзаголовок окна.
M.Version = nil

local RAYFIELD_URL = "https://sirius.menu/rayfield"

-- Иконки вкладок: Roblox asset id (числа). Можно поменять на свои.
local TAB_ICONS = {
    main     = 4483362458,
    visuals  = 4483362748,
    combat   = 4483362748,
    farm     = 4483362458,
    movement = 4483362458,
    misc     = 4483362748,
}

local library, window
local tabs = {}
local ready = false

--[[
    Картинку качаем сами в workspace/CheatHub/ и подключаем через getcustomasset().
    Так логотип показывается даже у executor'ов, которые режут доступ к GitHub
    внутри интерфейса. urlOrList - строка или список запасных ссылок.
]]
local function loadCustomImage(urlOrList)
    if type(getcustomasset) ~= "function"
        or type(writefile) ~= "function"
        or type(isfile) ~= "function"
        or type(makefolder) ~= "function" then
        return nil
    end

    local urls = type(urlOrList) == "table" and urlOrList or { urlOrList }
    local folder = "CheatHub"

    for _, url in ipairs(urls) do
        if type(url) == "string" and url ~= "" then
            local name = url:match("([^/]+)$")

            if name and name ~= "" then
                local path = folder .. "/" .. name
                pcall(makefolder, folder)

                local ok, body = pcall(game.HttpGet, game, url)

                if ok and type(body) == "string" and #body > 0
                    and pcall(writefile, path, body) and isfile(path) then
                    local got, asset = pcall(getcustomasset, path)

                    if got and type(asset) == "string" and asset ~= "" then
                        return asset
                    end
                end
            end
        end
    end

    return nil
end

-- Создаём окно и все вкладки. logo - ссылка (или список ссылок) на картинку.
function M.Build(logo)
    library = loadstring(game:HttpGet(RAYFIELD_URL))()

    local logoAsset = logo and loadCustomImage(logo) or nil

    window = library:CreateWindow({
        Name = "MurderMystery2HUB",
        Icon = logoAsset or 0, -- 0 = без иконки, если картинку достать не удалось
        LoadingTitle = "MurderMystery2HUB",
        LoadingSubtitle = "build " .. tostring(M.Version or "dev"),
        Theme = "Default", -- темы: docs.sirius.menu/rayfield/configuration/themes
        ToggleUIKeybind = "RightShift", -- клавиша скрыть/показать окно

        ConfigurationSaving = {
            Enabled = true,
            FolderName = "MurderMystery2HUB",
            FileName = "config",
        },

        Discord = {
            Enabled = false,
            Invite = "noinvitelink",
            RememberJoins = true,
        },

        KeySystem = false,
    })

    tabs.main     = window:CreateTab("Главное", TAB_ICONS.main)
    tabs.visuals  = window:CreateTab("Визуал", TAB_ICONS.visuals)
    tabs.combat   = window:CreateTab("Оружие", TAB_ICONS.combat)
    tabs.farm     = window:CreateTab("Фарм", TAB_ICONS.farm)
    tabs.movement = window:CreateTab("Движение", TAB_ICONS.movement)
    tabs.misc     = window:CreateTab("Разное", TAB_ICONS.misc)

    ready = true
    return window
end

-- GetTab() без аргумента вернёт вкладку "Главное".
function M.GetTab(name)
    return tabs[name or "main"] or tabs.main
end

function M.GetWindow()
    return window
end

-- Уведомление в стиле Rayfield. Безопасно вызывать когда угодно.
function M.Notify(title, content, image)
    if not ready or not library then
        return false
    end

    return pcall(function()
        library:Notify({
            Title = title,
            Content = content,
            Duration = 6,
            Image = image or 4483362748,
        })
    end)
end

-- Выгрузка: закрываем окно и сбрасываем состояние.
function M.Destroy()
    if library and type(library.Destroy) == "function" then
        pcall(library.Destroy, library)
    end

    tabs = {}
    library, window, ready = nil, nil, false
end

return M
