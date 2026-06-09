-- main.lua  ← execute this one
local Players   = game:GetService("Players")
local CoreGui   = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- Clean up any previous instance
local function destroyIfExists(parent, name)
    pcall(function()
        local obj = parent:FindFirstChild(name)
        if obj then obj:Destroy() end
    end)
end
destroyIfExists(CoreGui, "WaveLite_UI")
pcall(function() if gethui then destroyIfExists(gethui(), "WaveLite_UI") end end)
pcall(function()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then destroyIfExists(pg, "WaveLite_UI") end
end)

-- Load modules in dependency order
local Utils    = loadstring(game:HttpGet("https://raw.githubusercontent.com/WaveLite/WaveLiteRepo/main/modules/utils.lua"))()
local StateLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/WaveLite/WaveLiteRepo/main/modules/state.lua"))()
local Firebase = loadstring(game:HttpGet("https://raw.githubusercontent.com/WaveLite/WaveLiteRepo/main/modules/firebase.lua"))()

-- Start session keepalive
task.spawn(function()
    Firebase.fetchMyModerationStatus()
    pcall(Firebase.registerSession)
    pcall(Firebase.pruneStaleSessions)
end)
task.spawn(function()
    while true do task.wait(25) pcall(Firebase.registerSession) end
end)

-- Load UI, features, chat
loadstring(game:HttpGet("https://raw.githubusercontent.com/WaveLite/WaveLiteRepo/main/modules/features.lua"))()
loadstring(game:HttpGet("https://raw.githubusercontent.com/WaveLite/WaveLiteRepo/main/modules/ui.lua"))()
loadstring(game:HttpGet("https://raw.githubusercontent.com/WaveLite/WaveLiteRepo/main/modules/chat.lua"))()
