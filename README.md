# CheatHub

Multi-file скрипт для Roblox executor'а: `main.lua` грузит executor, остальное подтягивается по RAW-ссылкам.

## Структура

```
CheatHub/
├── main.lua              <-- точка входа (её грузит executor)
├── modules/
│   ├── ui.lua            <-- интерфейс (Rayfield)
│   └── features.lua      <-- логика (функции скрипта)
└── assets/
    └── logo.png          <-- картинка окна
```

## Запуск

Одна строка в консоли executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ffffddggt277-debug/CheatHub/arena/01a0b539-cheathub/main/main.lua"))()
```

> После мерджа PR в `main` ссылка и `BASE` внутри `main.lua` меняются на ветку `main`:
> `https://raw.githubusercontent.com/ffffddggt277-debug/CheatHub/main/main.lua`

## RAW-ссылки

| Файл | RAW-ссылка |
|---|---|
| main.lua | https://raw.githubusercontent.com/ffffddggt277-debug/CheatHub/arena/01a0b539-cheathub/main.lua |
| modules/ui.lua | https://raw.githubusercontent.com/ffffddggt277-debug/CheatHub/arena/01a0b539-cheathub/modules/ui.lua |
| modules/features.lua | https://raw.githubusercontent.com/ffffddggt277-debug/CheatHub/arena/01a0b539-cheathub/modules/features.lua |
| assets/logo.png | https://raw.githubusercontent.com/ffffddggt277-debug/CheatHub/arena/01a0b539-cheathub/assets/logo.png |

## Как менять скрипт

1. Отредактируй нужный файл (кнопка Edit ✏️ на GitHub).
2. Commit — RAW-ссылка остаётся прежней, executor подтянет новую версию при следующем запуске.

## Масштабирование

Новый модуль = новый файл в `modules/` + одна строка в `main.lua`:

```lua
local Aimbot = loadstring(game:HttpGet(BASE .. "modules/aimbot.lua"))()
```

## Чек-лист

- [x] Репозиторий Public
- [x] Структура папок: `modules/`, `assets/`
- [x] `BASE` в `main.lua` — правильный (ник + репо)
- [x] В каждом модуле есть `return M`
- [x] `logo.png` — именно .png, путь `assets/logo.png`
