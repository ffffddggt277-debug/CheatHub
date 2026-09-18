# MurderMystery2HUB

Модульная сборка для Roblox-игры **Murder Mystery 2** на UI-библиотеке [Rayfield](https://docs.sirius.menu/rayfield).
Executor грузит один файл, остальное подтягивается по RAW-ссылкам автоматически.

![icon](MurderMystery2HUB/assets/icon.png)

---

## Структура

```
CheatHub/
└── MurderMystery2HUB/
    ├── main.lua               <-- точка входа, её грузит executor
    ├── modules/
    │   ├── ui.lua             <-- окно Rayfield и вкладки
    │   ├── core.lua           <-- роли игроков, объекты игры, телепорт, уведомления
    │   ├── esp.lua            <-- подсветка игроков/монет/пушки, трейсеры, текст над головой
    │   ├── aimbot.lua         <-- silent aim, авто-выстрел, нож (reach, kill aura)
    │   ├── farming.lua        <-- авто-фарм монет, авто-подбор пушки
    │   ├── movement.lua       <-- скорость, прыжок, полёт, noclip
    │   └── misc.lua           <-- anti-AFK, кол-ауты ролей, server hop, перезапуск
    └── assets/
        └── icon.png           <-- логотип хаба
```

## Запуск

Одна строка — её и раздаёшь:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ffffddggt277-debug/CheatHub/main/MurderMystery2HUB/main.lua"))()
```

Что происходит дальше: `main.lua` качает модули из папки `modules/`, `ui.lua` поднимает Rayfield
и подтягивает `assets/icon.png` через `getcustomasset()`, `core.lua` подписывается на игровые
события и определяет роли, потом включаются остальные модули.

Окно скрывается/показывается клавишей **RightShift**. Для отладки: `_G.MM2HUB`
(например `_G.MM2HUB.Core.murderer()`, выгрузка — `_G.MM2HUB.Unload()`).

## Что внутри

| Вкладка | Функции |
| --- | --- |
| **Главное** | телепорт к убийце/шерифу, кол-аут ролей в чат, статус, быстрые действия |
| **Визуал** | ESP игроков по ролям, текст над головой (роль + дистанция), трейсеры, ESP монет и дропнутой пушки, цвета ролей |
| **Оружие** | Silent Aim (+ бинд на клавишу), целиться только в убийцу, предсказание движения, авто-выстрел, довод камеры, Reach ножа, Kill Aura, авто-телепорт к цели |
| **Фарм** | авто-фарм монет (телепорт к `Coin_Server`), авто-подбор пушки (`GunDrop`), телепорты, счётчик монет |
| **Движение** | скорость ходьбы, сила прыжка, бесконечный прыжок, полёт (WASD + Space/Ctrl), noclip |
| **Разное** | уведомления о ролях, авто-кол-аут, anti-AFK, server hop, перезапуск и выгрузка хаба |

## Внутренности MM2, на которых всё держится

Всё это лежит в `modules/core.lua`, и если игра что-то переименует — править надо там:

* роли приходят событиями `ReplicatedStorage.Fade`, `UpdatePlayerData` (таблица `{ [ник] = { Role = "Murderer" } }`),
  своя роль — `RoleSelect`, конец раунда — `Remotes.Gameplay.RoundEndFade`;
* запасной вариант определения роли: у убийцы в руках `Knife`, у шерифа — `Gun`;
* монета для автофарма — `workspace.CoinContainer` → `Coin_Server`;
* дропнутая пушка — `workspace.GunDrop`;
* удар ножом делается через `firetouchinterest(enemyRoot, knife.Handle, 1/0)`;
* выстрел — remote `ShootGun` (`InvokeServer`), координата выстрела подменяется в `__namecall`.

## Как добавить свой модуль

1. Создай `modules/моймодуль.lua`, в конце обязательно `return M`.
2. В `main.lua` добавь файл в таблицу `FILES` и вызов:

```lua
if MyModule then MyModule.Init(UI.GetTab("misc"), Core) end
```

3. Внутри модуля работай через `Core`: `Core.getCharacter()`, `Core.murderer()`, `Core.Notify()`,
   `Core.onRoleChanged()`, `Core.getCoin()`, `Core.teleport()`.

## Частые проблемы

| Проблема | Что делать |
| --- | --- |
| HTTP 404 при загрузке | Репозиторий должен быть **Public**, ветка `main`, папка `MurderMystery2HUB` на месте |
| `attempt to call a nil value` | В модуле нет `return M` в конце файла |
| `loadstring is disabled` | Executor не поддерживает loadstring — Solara / Wave / Xeno / Delta |
| Silent Aim / Reach не работают | Нужны `hookmetamethod` и `firetouchinterest` (не все executor'ы) |
| Трейсеры не рисуются | Нужен Drawing API в executor'е |
| Логотип не виден | Не скачался PNG — проверь ссылку или формат файла |
| Роли определяются с задержкой | Включён запасной скан по предметам в руках (раз в секунду) |

## Обновление

Правишь любой файл в репозитории → Commit. Ссылка для запуска не меняется, при следующем
запуске подтянутся свежие модули.

> Скрипт для локальной игры/тестов. Используешь на свой страх: любые ограничения игры
> и бан-риски — твоя ответственность.
