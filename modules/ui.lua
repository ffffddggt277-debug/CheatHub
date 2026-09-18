-- Модуль интерфейса. Создаёт окно Rayfield и одну вкладку.
-- Возвращает таблицу с функциями Build и GetTab.

local M = {}
local tab = nil

function M.Build(logoUrl)
    -- Загружаем библиотеку Rayfield
    local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

    local Window = Rayfield:CreateWindow({
        Name = "CheatHub",
        Icon = logoUrl,             -- сюда идёт RAW-ссылка на assets/logo.png
        LoadingTitle = "Загрузка...",
        LoadingSubtitle = "multi-file build",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "CheatHub",
            FileName = "config",
        },
    })

    tab = Window:CreateTab("Главное", 4483362458) -- 4483362458 — ID иконки вкладки

    return Window
end

function M.GetTab()
    return tab
end

return M
