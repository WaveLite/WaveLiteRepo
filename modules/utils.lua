-- modules/utils.lua
local TweenService = game:GetService("TweenService")

local Utils = {}

function Utils.make(className, props)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do obj[k] = v end
    return obj
end

function Utils.tween(obj, t, props)
    TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

function Utils.inputToKeyName(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        return input.KeyCode.Name
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then return "M1"
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then return "M2"
    elseif input.UserInputType == Enum.UserInputType.MouseButton3 then return "M3"
    end
    return nil
end

function Utils.getHRP()
    local char = game:GetService("Players").LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

return Utils
