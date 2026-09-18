--[[
    MurderMystery2HUB | main.lua
    ==================================================================
    Точка входа. Именно этот файл грузит executor:

        loadstring(game:HttpGet("https://raw.githubusercontent.com/ffffddggt277-debug/CheatHub/main/MurderMystery2HUB/main.lua"))()

    Дальше всё подтягивается автоматом по RAW-ссылкам:
        modules/ui.lua        - окно Rayfield и вкладки
        modules/core.lua      - роли игроков, объекты, телепорт, уведомления
        modules/esp.lua       - подсветка игроков/монет/пушки, трейсеры
        modules/aimbot.lua    - silent aim, авто-выстрел, нож (reach, kill aura)
        modules/farming.lua   - авто-фарм монет и подбор пушки
        modules/movement.lua  - скорость, прыжок, полёт, noclip
        modules/misc.lua      - anti-AFK, кол-ауты, server hop, перезапуск
]]

-- ======================== НАСТРОЙКИ СБОРКИ ========================

local REPO   = "ffffddggt277-debug/CheatHub"
local BRANCH = "main"
local FOLDER = "MurderMystery2HUB"
local BUILD  = "1.0.0"

-- BASE - общий префикс всех RAW-ссылок (модули и картинки берём отсюда).
local BASE = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH .. "/" .. FOLDER .. "/"

-- Зеркало картинок: если executor не пускает raw.githubusercontent.com.
local CDN = "https://cdn.jsdelivr.net/gh/" .. REPO .. "@" .. BRANCH .. "/" .. FOLDER .. "/"

-- Список модулей: порядок важен - ui и core грузятся первыми.
local FILES = {
    UI       = "modules/ui.lua",
    Core     = "modules/core.lua",
    Esp      = "modules/esp.lua",
    Aimbot   = "modules/aimbot.lua",
    Farming  = "modules/farming.lua",
    Movement = "modules/movement.lua",
    Misc     = "modules/misc.lua",
}

-- =========================== СЛУЖЕБНОЕ ===========================

local function notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 8,
        })
    end)
    warn("[MM2HUB] " .. title .. " | " .. text)
end

-- Скачиваем файл из репозитория и выполняем его.
local function loadModule(path)
    local ok, result = pcall(function()
        local code = game:HttpGet(BASE .. path)

        if type(code) ~= "string" or #code == 0 then
            error("пустой ответ для " .. path .. " (404? проверь ветку и имя папки)", 0)
        end

        local chunk, err = loadstring(code, "MM2HUB/" .. path)
        if not chunk then
            error("синтаксическая ошибка в " .. path .. ": " .. tostring(err), 0)
        end

        return chunk()
    end)

    return ok, result
end

-- Повторный запуск поверх старого - сначала выгружаем прошлую сборку.
if type(_G.MM2HUB) == "table" and type(_G.MM2HUB.Unload) == "function" then
    pcall(_G.MM2HUB.Unload)
end

-- ======================== ЗАГРУЗКА МОДУЛЕЙ ========================

local modules = {}
local failed = {}

for name, path in pairs(FILES) do
    local ok, result = loadModule(path)

    if ok and type(result) == "table" then
        modules[name] = result
    else
        failed[name] = tostring(result)
        warn("[MM2HUB] Модуль " .. name .. " не загрузился: " .. tostring(result))
    end
end

if not modules.UI or not modules.Core then
    notify("MurderMystery2HUB", "Не загрузились базовые модули (ui/core). Проверь ссылки RAW.")
    return
end

if next(failed) then
    notify("MurderMystery2HUB", "Часть модулей не загрузилась: " .. (next(failed) or ""))
end

local UI       = modules.UI
local Core     = modules.Core
local Esp      = modules.Esp
local Aimbot   = modules.Aimbot
local Farming  = modules.Farming
local Movement = modules.Movement
local Misc     = modules.Misc

-- ============================ СБОРКА ============================

-- Логотип: сначала RAW, потом зеркало jsDelivr (ui.lua сам скачает картинку).
local LOGO = {
    BASE .. "assets/icon.png",
    CDN .. "assets/icon.png",
}

UI.Version = BUILD

local built, err = pcall(function()
    UI.Build(LOGO)                                   -- окно + вкладки

    Core.base = BASE                                 -- нужно модулю misc для перезапуска
    Core.Init(UI)                                    -- роли, объекты, уведомления

    if Esp then Esp.Init(UI.GetTab("visuals"), Core) end
    if Aimbot then Aimbot.Init(UI.GetTab("combat"), Core) end
    if Farming then Farming.Init(UI.GetTab("farm"), Core) end
    if Movement then Movement.Init(UI.GetTab("movement"), Core) end
    if Misc then Misc.Init(UI.GetTab("main"), Core) end
end)

if not built then
    notify("MurderMystery2HUB: ошибка сборки", tostring(err))
    return
end

-- ====================== ДОСТУП ИЗВНЕ (F9) ======================
-- Например: _G.MM2HUB.Core.murderer()  или  _G.MM2HUB.Unload()
_G.MM2HUB = {
    Version  = BUILD,
    Base     = BASE,
    UI       = UI,
    Core     = Core,
    Modules  = modules,

    Unload = function()
        for _, module in pairs(modules) do
            if type(module.Destroy) == "function" then
                pcall(module.Destroy)
            end
        end

        pcall(UI.Destroy)
        _G.MM2HUB = nil
    end,
}

notify("MurderMystery2HUB", "Сборка " .. BUILD .. " загружена. Клавиша окна: RightShift")
