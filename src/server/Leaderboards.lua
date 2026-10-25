-- Leaderboards: rellena las pantallas de clasificacion del lobby (servidor y mundial).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Levels = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Levels"))
local PlayerData = require(script.Parent.PlayerData)
local Lobby = require(script.Parent.Lobby)

local Leaderboards = {}

local function lines(list, fmt)
	local out = {}
	for i, e in ipairs(list) do
		if i > 10 then
			break
		end
		local medal = (i == 1 and "🥇") or (i == 2 and "🥈") or (i == 3 and "🥉") or (i .. ".")
		out[#out + 1] = medal .. " " .. e.name .. "  " .. fmt(e)
	end
	if #out == 0 then
		return "Todavia nadie..."
	end
	return table.concat(out, "\n")
end

function Leaderboards.UpdateServer()
	local wins, levels = {}, {}
	for _, p in ipairs(Players:GetPlayers()) do
		local data = PlayerData.Get(p)
		if data then
			local level = Levels.FromTotal(data.XP)
			wins[#wins + 1] = { name = p.DisplayName, value = data.Stats.Wins }
			levels[#levels + 1] = { name = p.DisplayName, value = level }
		end
	end
	table.sort(wins, function(a, b)
		return a.value > b.value
	end)
	table.sort(levels, function(a, b)
		return a.value > b.value
	end)
	local boards = Lobby.Boards
	if boards[1] then
		boards[1].Lines.Text = lines(wins, function(e)
			return e.value .. " 🏆"
		end)
	end
	if boards[2] then
		boards[2].Lines.Text = lines(levels, function(e)
			return "Nv " .. e.value
		end)
	end
end

local nameCache = {}
local function nameOf(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or ("Jugador " .. userId)
	return nameCache[userId]
end

function Leaderboards.UpdateGlobal()
	local store = PlayerData.GetOrderedStore()
	local board = Lobby.Boards[3]
	if not store or not board then
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, 10):GetCurrentPage()
	end)
	if not ok then
		board.Lines.Text = "No disponible"
		return
	end
	local list = {}
	for _, entry in ipairs(page) do
		local id = tonumber(tostring(entry.key):match("%d+"))
		list[#list + 1] = { name = id and nameOf(id) or tostring(entry.key), value = entry.value }
	end
	board.Lines.Text = lines(list, function(e)
		return e.value .. " 🏆"
	end)
end

function Leaderboards.Init()
	task.spawn(function()
		local tick = 0
		while true do
			Leaderboards.UpdateServer()
			if tick % 4 == 0 then
				task.spawn(Leaderboards.UpdateGlobal)
			end
			tick = tick + 1
			task.wait(30)
		end
	end)
end

return Leaderboards
