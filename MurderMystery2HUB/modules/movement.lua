--[[
    MurderMystery2HUB | modules/movement.lua
    ==================================================================
    Движение: скорость, сила прыжка, бесконечный прыжок, полёт (BodyVelocity),
    проход сквозь стены (noclip).

    Все значения применяются заново после респавна - за это отвечает CharacterAdded.
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

local M = {}

local Core

local state = {
    speed    = 16,
    jump     = 50,
    infJump  = false,
    fly      = false,
    flySpeed = 60,
    noclip   = false,
}

local flyVelocity, flyConnection, noclipConnection, jumpConnection
local alive = false

--[[ ---------------------------- скорость ---------------------------- ]]

-- Применяем скорость/прыжок к текущему персонажу.
local function applyMovement()
    local _, _, humanoid = Core.getCharacter(localPlayer)
    if not humanoid then
        return
    end

    humanoid.WalkSpeed = state.speed

    pcall(function()
        humanoid.UseJumpPower = true
    end)
    humanoid.JumpPower = state.jump
end

--[[ --------------------------- полёт --------------------------- ]]

local function stopFly()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end

    if flyVelocity then
        flyVelocity:Destroy()
        flyVelocity = nil
    end

    local _, _, humanoid = Core.getCharacter(localPlayer)
    if humanoid then
        humanoid.PlatformStand = false
    end
end

local function startFly()
    local _, root, humanoid = Core.getCharacter(localPlayer)
    if not root or not humanoid then
        Core.Notify("Полёт", "персонаж не найден")
        return
    end

    humanoid.PlatformStand = true

    local ok, bodyVelocity = pcall(Instance.new, "BodyVelocity")
    if not ok or not bodyVelocity then
        Core.Notify("Полёт", "executor не даёт создать BodyVelocity")
        return
    end

    bodyVelocity.Name = "MM2HUB_Fly"
    bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = root
    flyVelocity = bodyVelocity

    flyConnection = RunService.RenderStepped:Connect(function()
        if not alive or not state.fly then
            return
        end

        local _, currentRoot, currentHumanoid = Core.getCharacter(localPlayer)
        if not currentRoot or not flyVelocity then
            return
        end

        local camera = Workspace.CurrentCamera
        if not camera then
            return
        end

        local direction = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            direction = direction + camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            direction = direction - camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            direction = direction - camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            direction = direction + camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            direction = direction + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            direction = direction - Vector3.new(0, 1, 0)
        end

        if direction.Magnitude > 0 then
            flyVelocity.Velocity = direction.Unit * state.flySpeed
        else
            flyVelocity.Velocity = Vector3.zero
        end

        if currentHumanoid then
            currentHumanoid.PlatformStand = true
        end
    end)
end

--[[ --------------------------- noclip --------------------------- ]]

local function startNoclip()
    if noclipConnection then
        return
    end

    noclipConnection = RunService.Stepped:Connect(function()
        if not alive or not state.noclip then
            return
        end

        local character = Core.getCharacter(localPlayer)
        if not character then
            return
        end

        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)
end

local function stopNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end

    local character = Core.getCharacter(localPlayer)
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

--[[ ----------------------- бесконечный прыжок ----------------------- ]]

local function startInfJump()
    if jumpConnection then
        return
    end

    jumpConnection = UserInputService.JumpRequest:Connect(function()
        if not alive or not state.infJump then
            return
        end

        local _, _, humanoid = Core.getCharacter(localPlayer)
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

local function stopInfJump()
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
end

--[[ ------------------------------ init ------------------------------ ]]

function M.Init(tab, core)
    Core = core
    alive = true

    -- после респавна возвращаем свои настройки
    localPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        pcall(applyMovement)
    end)

    tab:CreateSection("Скорость и прыжок")

    tab:CreateSlider({
        Name = "Скорость ходьбы",
        Range = {16, 250},
        Increment = 1,
        Suffix = "Speed",
        CurrentValue = 16,
        Flag = "Move_Speed",
        Callback = function(value)
            state.speed = value
            applyMovement()
        end,
    })

    tab:CreateSlider({
        Name = "Сила прыжка",
        Range = {50, 250},
        Increment = 5,
        Suffix = "Jump",
        CurrentValue = 50,
        Flag = "Move_Jump",
        Callback = function(value)
            state.jump = value
            applyMovement()
        end,
    })

    tab:CreateToggle({
        Name = "Бесконечный прыжок",
        CurrentValue = false,
        Flag = "Move_InfJump",
        Callback = function(value)
            state.infJump = value

            if value then
                startInfJump()
            else
                stopInfJump()
            end
        end,
    })

    tab:CreateSection("Полёт и noclip")

    tab:CreateToggle({
        Name = "Полёт (WASD + Space / LeftCtrl)",
        CurrentValue = false,
        Flag = "Move_Fly",
        Callback = function(value)
            state.fly = value

            if value then
                startFly()
            else
                stopFly()
            end
        end,
    })

    tab:CreateSlider({
        Name = "Скорость полёта",
        Range = {10, 300},
        Increment = 5,
        Suffix = "studs",
        CurrentValue = 60,
        Flag = "Move_FlySpeed",
        Callback = function(value)
            state.flySpeed = value
        end,
    })

    tab:CreateToggle({
        Name = "Noclip (проход сквозь стены)",
        CurrentValue = false,
        Flag = "Move_Noclip",
        Callback = function(value)
            state.noclip = value

            if value then
                startNoclip()
            else
                stopNoclip()
            end
        end,
    })

    tab:CreateButton({
        Name = "Сбросить скорость и прыжок",
        Callback = function()
            state.speed, state.jump = 16, 50
            applyMovement()
            Core.Notify("Движение", "вернул 16 скорость / 50 прыжок")
        end,
    })

    return M
end

function M.Destroy()
    alive = false
    state.fly = false
    state.infJump = false
    state.noclip = false

    stopFly()
    stopNoclip()
    stopInfJump()
end

return M
