-- VoteService: votacion de mapa entre rondas.
--   local winner = VoteService.Run(VoteService.PickOptions(3), segundos)
-- Bloquea hasta que acaba el tiempo (o hasta que han votado todos) y devuelve el nombre del mapa ganador.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))
local MapService = require(script.Parent.MapService)
local DisasterService = require(script.Parent.DisasterService)

local VoteOptions = Net.Event("VoteOptions")
local VoteUpdate = Net.Event("VoteUpdate")
local VoteEnd = Net.Event("VoteEnd")
local CastVote = Net.Event("CastVote")

local VoteService = {}

local active = nil -- { set, list, votes = { [userId] = nombre } }
local lastWinner = nil

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

-- Elige `n` mapas distintos al azar (sin repetir el ultimo jugado si hay suficientes)
function VoteService.PickOptions(n)
	local names = MapService.GetMapNames()
	if #names > n and lastWinner then
		local i = table.find(names, lastWinner)
		if i then
			table.remove(names, i)
		end
	end
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
		local info = MapService.GetInfo(name)
		info.DisasterTitles = {}
		info.DisasterIcons = {}
		for _, d in ipairs(info.Disasters) do
			local di = DisasterService.Info(d)
			info.DisasterTitles[#info.DisasterTitles + 1] = di.Title
			info.DisasterIcons[#info.DisasterIcons + 1] = di.Icon
		end
		infos[#infos + 1] = info
	end
	active = { set = set, list = options, votes = {} }

	local endTime = workspace:GetServerTimeNow() + seconds
	VoteOptions:FireAllClients(infos, endTime)
	VoteUpdate:FireAllClients(tally(options))

	-- termina antes si ya han votado todos (y hay mas de uno)
	while workspace:GetServerTimeNow() < endTime do
		task.wait(0.25)
		local n, voted = #Players:GetPlayers(), 0
		for _ in pairs(active.votes) do
			voted = voted + 1
		end
		if n > 1 and voted >= n and endTime - workspace:GetServerTimeNow() > 2 then
			endTime = workspace:GetServerTimeNow() + 2
		end
	end

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
	lastWinner = winner
	VoteEnd:FireAllClients(winner, MapService.GetInfo(winner).Title)
	return winner
end

return VoteService
