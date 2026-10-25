-- Net: todos los RemoteEvent/RemoteFunction del juego en un sitio.
-- En el servidor se crean al primer require; en el cliente se esperan.
--   local Net = require(ReplicatedStorage.IslasShared.Net)
--   Net.Event("Popup"):FireClient(player, ...)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"VoteOptions", "VoteUpdate", "VoteEnd", "CastVote", -- votacion
	"RoundState", "RoundStatus", "RoundResults", -- estado de la ronda
	"DisasterFX", "Shatter", "PlaySound", -- efectos
	"DataUpdate", "Popup", "Toast", "KillFeed", -- jugador / HUD
	"ElevatorMenu", "ElevatorRequest", -- ascensores
	"GearAction", "OpenUI", "DailyClaim", "SettingsChanged",
}
local FUNCTIONS = { "ShopRequest", "GetData" }

local Net = {}
local folder

if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("IslasRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "IslasRemotes"
		for _, name in ipairs(EVENTS) do
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
		for _, name in ipairs(FUNCTIONS) do
			local r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("IslasRemotes")
end

function Net.Event(name)
	return folder:WaitForChild(name)
end

function Net.Function(name)
	return folder:WaitForChild(name)
end

Net.Folder = folder
return Net
