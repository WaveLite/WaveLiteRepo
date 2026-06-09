local Players     = game:GetService("Players")
local CoreGui     = game:GetService("CoreGui")
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
 
local BASE = "https://raw.githubusercontent.com/WaveLite/WaveLiteRepo/main/modules/"
 
-- Load in order: state first, then features, then ui, then chat
loadstring(game:HttpGet(BASE.."state.lua"))()
loadstring(game:HttpGet(BASE.."features.lua"))()
loadstring(game:HttpGet(BASE.."ui.lua"))()
loadstring(game:HttpGet(BASE.."chat.lua"))()
