--[[
    MurderMystery2HUB | modules/farming.lua
    ==================================================================
    Фарм:
      * авто-сбор монет - телепорт к монете, пока она не исчезнет
        (монета лежит в workspace.CoinContainer и зовётся Coin_Server)
      * авто-подбор пушки - если ты мирный/герой и валяется GunDrop,
        скрипт прыгает к ней и возвращается назад

    Всё через Core, поэтому имена объектов правятся в одном месте - core.lua.
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

local M = {}

local Core

local state = {
    coins  = false,
    gun    = false,
    notify = true,
}

local stats = { coins = 0 }
local busy = {}
local alive = false
local savedCFrame

local function coinExists(coin)
    return coin ~= nil and coin.Parent ~= nil and coin:IsDescendantOf(Workspace)
end

--[[ --------------------------- монеты --------------------------- ]]

local function farmCoins()
    if busy.coins then
        return
    end
    busy.coins = true

    task.spawn(function()
        while alive and state.coins do
            local coin = Core.getCoin()
            local _, root, humanoid = Core.getCharacter(localPlayer)

            if coinExists(coin) and root and humanoid and humanoid.Health > 0 then
                local guard = os.clock() + 8 -- страховка: не залипнуть на одной монете

                while alive and state.coins and coinExists(coin) and os.clock() < guard do
                    root.CFrame = CFrame.new(coin.Position + Vector3.new(0, 1, 0))
                    RunService.Stepped:Wait()
                end

                if not coinExists(coin) then
                    stats.coins = stats.coins + 1

                    if state.notify and stats.coins % 5 == 0 then
                        Core.Notify("Фарм монет", "собрано монет: " .. stats.coins)
                    end
                end
            end

            task.wait(0.2)
        end

        busy.coins = false
    end)
end

local function stopCoinFarm()
    state.coins = false
end

--[[ ------------------------ дропнутая пушка ------------------------ ]]

local function farmGun()
    if busy.gun then
        return
    end
    busy.gun = true

    task.spawn(function()
        while alive and state.gun do
            local gunDrop = Core.getGunDrop()
            local role = Core.localRole()
            local _, root, humanoid = Core.getCharacter(localPlayer)

            local canPickup = role == "Innocent" or role == "Hero" or role == "Unknown"

            if gunDrop and canPickup and root and humanoid and humanoid.Health > 0 then
                savedCFrame = root.CFrame
                local guard = os.clock() + 10

                while alive and state.gun and gunDrop.Parent ~= nil and os.clock() < guard do
                    root.CFrame = CFrame.new(gunDrop.Position + Vector3.new(0, 1, 0))
                    RunService.Stepped:Wait()
                end

                if savedCFrame then
                    pcall(function()
                        root.CFrame = savedCFrame
                    end)
                end

                savedCFrame = nil
                Core.Notify("Пушка", "подбор завершён")
            end

            task.wait(0.3)
        end

        busy.gun = false
    end)
end

--[[ ---------------------------- действия ---------------------------- ]]

local function teleportToCoin()
    local coin = Core.getCoin()

    if not coin then
        Core.Notify("Телепорт", "монета не найдена (CoinContainer пустой)")
        return
    end

    if Core.teleport(coin) then
        Core.Notify("Телепорт", "к монете")
    end
end

local function teleportToGun()
    local gunDrop = Core.getGunDrop()

    if not gunDrop then
        Core.Notify("Телепорт", "дропнутой пушки нет")
        return
    end

    if Core.teleport(gunDrop) then
        Core.Notify("Телепорт", "к пушке")
    end
end

--[[ ------------------------------ init ------------------------------ ]]

function M.Init(tab, core)
    Core = core

    tab:CreateSection("Монеты")

    tab:CreateToggle({
        Name = "Авто-фарм монет (телепорт к монете)",
        CurrentValue = false,
        Flag = "Farm_Coins",
        Callback = function(value)
            state.coins = value

            if value then
                farmCoins()
            else
                stopCoinFarm()
            end
        end,
    })

    tab:CreateToggle({
        Name = "Уведомления о фарме",
        CurrentValue = true,
        Flag = "Farm_Notify",
        Callback = function(value)
            state.notify = value
        end,
    })

    tab:CreateButton({
        Name = "Телепорт к монете",
        Callback = teleportToCoin,
    })

    tab:CreateButton({
        Name = "Сбросить счётчик монет",
        Callback = function()
            stats.coins = 0
            Core.Notify("Фарм монет", "счётчик сброшен")
        end,
    })

    tab:CreateLabel("Счётчик показывается уведомлением каждые 5 монет")

    tab:CreateSection("Пушка")

    tab:CreateToggle({
        Name = "Авто-подбор пушки (если ты мирный)",
        CurrentValue = false,
        Flag = "Farm_Gun",
        Callback = function(value)
            state.gun = value

            if value then
                farmGun()
            end
        end,
    })

    tab:CreateButton({
        Name = "Телепорт к пушке",
        Callback = teleportToGun,
    })

    alive = true
    return M
end

function M.Destroy()
    alive = false
    state.coins = false
    state.gun = false
    busy = {}
end

return M
