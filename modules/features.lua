-- Модуль логики. Принимает вкладку из ui.lua и создаёт на ней кнопки.

local M = {}

function M.Init(tab)
    -- Кнопка-пример
    tab:CreateButton({
        Name = "Привет",
        Callback = function()
            print("Кнопка нажата, скрипт работает")
        end,
    })

    -- Тумблер-пример
    tab:CreateToggle({
        Name = "Бесконечный прыжок",
        CurrentValue = false,
        Flag = "InfJump",
        Callback = function(state)
            if state then
                _G.InfJumpConn = game:GetService("UserInputService").JumpRequest:Connect(function()
                    game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
                end)
            else
                if _G.InfJumpConn then _G.InfJumpConn:Disconnect() end
            end
        end,
    })

    -- Слайдер-пример
    tab:CreateSlider({
        Name = "Скорость",
        Range = {16, 200},
        Increment = 1,
        Suffix = "Speed",
        CurrentValue = 16,
        Flag = "WalkSpeed",
        Callback = function(value)
            local char = game.Players.LocalPlayer.Character
            if char and char:FindFirstChildOfClass("Humanoid") then
                char:FindFirstChildOfClass("Humanoid").WalkSpeed = value
            end
        end,
    })
end

return M
