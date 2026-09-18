-- Точка входа. Именно её грузит executor.
-- BASE — общий префикс всех RAW-ссылок, чтобы не дублировать путь.
-- ⚠️ Сейчас BASE указывает на ветку arena/01a0b539-cheathub (всё уже работает прямо сейчас).
-- После того как PR будет смержен в main, замени ветку в BASE на main:
-- local BASE = "https://raw.githubusercontent.com/ffffddggt277-debug/CheatHub/main/"

local BASE = "https://raw.githubusercontent.com/ffffddggt277-debug/CheatHub/arena/01a0b539-cheathub/"

-- Загружаем модули из репозитория
local UI       = loadstring(game:HttpGet(BASE .. "modules/ui.lua"))()
local Features = loadstring(game:HttpGet(BASE .. "modules/features.lua"))()

-- Строим интерфейс, передаём ссылку на картинку
UI.Build(BASE .. "assets/logo.png")

-- Запускаем логику (кнопки интерфейса будут дёргать функции оттуда)
Features.Init(UI.GetTab())
