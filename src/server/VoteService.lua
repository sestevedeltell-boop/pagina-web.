-- VoteService: votacion de mapa al terminar la ronda.
--   local winner = VoteService.Run(options, seconds)   -- options = { "Airport", "Mall", ... }
-- Bloquea hasta que acaba el tiempo y devuelve el nombre del mapa ganador.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapService = require(script.Parent.MapService)

local Remotes = ReplicatedStorage:WaitForChild("IslasRemotes")
local VoteOptions = Remotes:WaitForChild("VoteOptions") -- servidor -> clientes: {options, endTime}
local VoteUpdate = Remotes:WaitForChild("VoteUpdate") -- servidor -> clientes: {nombre = votos}
local VoteEnd = Remotes:WaitForChild("VoteEnd") -- servidor -> clientes: ganador
local CastVote = Remotes:WaitForChild("CastVote") -- cliente -> servidor: nombre

local VoteService = {}

local active = nil -- { options = set, votes = { [userId] = nombre } }

local function tally(options)
	local counts = {}
	for _, name in ipairs(options) do
		counts[name] = 0
	end
	for _, name in pairs(active.votes) do
		if counts[name] then
			counts[name] = counts[name] + 1
		end
	end
	return counts
end

CastVote.OnServerEvent:Connect(function(player, name)
	if not active or typeof(name) ~= "string" or not active.set[name] then
		return
	end
	active.votes[player.UserId] = name
	VoteUpdate:FireAllClients(tally(active.list))
end)

Players.PlayerRemoving:Connect(function(player)
	if active then
		active.votes[player.UserId] = nil
		VoteUpdate:FireAllClients(tally(active.list))
	end
end)

-- Elige `n` mapas distintos al azar
function VoteService.PickOptions(n)
	local names = MapService.GetMapNames()
	for i = #names, 2, -1 do
		local j = math.random(i)
		names[i], names[j] = names[j], names[i]
	end
	local picked = {}
	for i = 1, math.min(n, #names) do
		picked[i] = names[i]
	end
	return picked
end

function VoteService.Run(options, seconds)
	local set = {}
	local infos = {}
	for _, name in ipairs(options) do
		set[name] = true
		infos[#infos + 1] = MapService.GetInfo(name)
	end
	active = { set = set, list = options, votes = {} }

	local endTime = workspace:GetServerTimeNow() + seconds
	VoteOptions:FireAllClients(infos, endTime)
	VoteUpdate:FireAllClients(tally(options))

	task.wait(seconds)

	local counts = tally(options)
	local best, bestCount = {}, -1
	for _, name in ipairs(options) do
		if counts[name] > bestCount then
			best, bestCount = { name }, counts[name]
		elseif counts[name] == bestCount then
			best[#best + 1] = name
		end
	end
	local winner = best[math.random(#best)]

	active = nil
	VoteEnd:FireAllClients(winner)
	return winner
end

return VoteService
