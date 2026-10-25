-- Main: punto de entrada del servidor. Arranca todos los sistemas en orden.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
require(Shared:WaitForChild("Net")) -- crea los RemoteEvents

local S = script.Parent
require(S.CollisionGroups).Setup()
require(S.PlayerData).Init()
require(S.Rewards).Init()
require(S.Gear).Init()
require(S.ShopService).Init()
require(S.CoinDrops).Init()

local Lobby = require(S.Lobby)
local MapService = require(S.MapService)
if Lobby.ShouldBuild() then
	-- mientras se construye el lobby no aparecen personajes (si no, caerian al vacio)
	local autoLoads = Players.CharacterAutoLoads
	Players.CharacterAutoLoads = false
	Lobby.Build()
	Players.CharacterAutoLoads = autoLoads
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			MapService.ReturnToLobby({ player })
		elseif autoLoads then
			task.spawn(function()
				player:LoadCharacter()
			end)
		end
	end
end
require(S.Leaderboards).Init()

if Config.RunDefaultLoop then
	task.spawn(require(S.GameLoop).Run)
end
