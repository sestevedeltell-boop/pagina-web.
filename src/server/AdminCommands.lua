-- AdminCommands: comandos de chat para probar el juego (solo en Studio, para el dueno del juego
-- o para los UserId de Config.Admins si existe).
--   !mapa castillo     la proxima ronda sera en ese mapa (sin votacion); vale el nombre en espanol o el interno
--   !desastre tornado  el proximo desastre sera ese
--   !saltar            salta el descanso o termina la ronda actual
--   !monedas 1000      te da monedas
--   !nivel 500         te da XP
--   !lista             muestra mapas y desastres disponibles
--   !stats             estado de la destruccion
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local S = script.Parent
local PlayerData = require(S.PlayerData)
local MapService = require(S.MapService)
local DisasterService = require(S.DisasterService)
local Destruction = require(S.Destruction)
local GameLoop = require(S.GameLoop)

local Toast = Net.Event("Toast")

local AdminCommands = {}

local function isAdmin(player)
	if RunService:IsStudio() or player.UserId == game.CreatorId then
		return true
	end
	for _, id in ipairs(Config.Admins or {}) do
		if id == player.UserId then
			return true
		end
	end
	return false
end

local function reply(player, text)
	Toast:FireClient(player, { Title = "Admin", Text = text })
end

-- Busca por nombre interno (City) o por titulo en espanol (Ciudad), completo o en parte
local function findName(list, query, titleOf)
	query = string.lower(query or "")
	if query == "" then
		return nil
	end
	local function keys(n)
		local k = { string.lower(n) }
		if titleOf then
			local ok, t = pcall(titleOf, n)
			if ok and t then
				k[2] = string.lower(t)
			end
		end
		return k
	end
	for _, n in ipairs(list) do
		for _, k in ipairs(keys(n)) do
			if k == query then
				return n
			end
		end
	end
	for _, n in ipairs(list) do
		for _, k in ipairs(keys(n)) do
			if string.find(k, query, 1, true) then
				return n
			end
		end
	end
	return nil
end

local commands = {}

commands.mapa = function(player, arg)
	local name = findName(MapService.GetMapNames(), arg, function(n)
		return MapService.GetInfo(n).Title
	end)
	if not name then
		return reply(player, "No existe ese mapa. Usa !lista")
	end
	GameLoop.ForceMap(name)
	reply(player, "Proxima ronda: " .. name)
end

commands.desastre = function(player, arg)
	local name = findName(DisasterService.GetNames(), arg, DisasterService.TitleOf)
	if not name then
		return reply(player, "No existe ese desastre. Usa !lista")
	end
	GameLoop.ForceDisaster(name)
	reply(player, "Proximo desastre: " .. name)
end

commands.saltar = function(player)
	GameLoop.Skip()
	reply(player, "Saltando fase...")
end

commands.monedas = function(player, arg)
	local n = tonumber(arg) or 1000
	PlayerData.AddCoins(player, n)
	reply(player, "+" .. n .. " monedas")
end

commands.nivel = function(player, arg)
	local n = tonumber(arg) or 500
	PlayerData.AddXP(player, n)
	reply(player, "+" .. n .. " XP")
end

commands.lista = function(player)
	reply(player, "Mapas: " .. table.concat(MapService.GetMapNames(), ", "))
	reply(player, "Desastres: " .. table.concat(DisasterService.GetNames(), ", "))
end

commands.stats = function(player)
	local st = Destruction.Stats()
	reply(player, string.format("Piezas %d · rotas %d · derrumbadas %d · fisicas %d · escombros %d",
		st.parts or 0, st.broken or 0, st.collapsed or 0, st.physics or 0, st.rubble or 0))
end

function AdminCommands.Handle(player, message)
	if typeof(message) ~= "string" or message:sub(1, 1) ~= "!" or not isAdmin(player) then
		return false
	end
	local cmd, arg = message:match("^!(%S+)%s*(.*)$")
	local fn = cmd and commands[string.lower(cmd)]
	if fn then
		local ok, err = pcall(fn, player, arg)
		if not ok then
			reply(player, "Error: " .. tostring(err))
		end
		return true
	end
	return false
end

function AdminCommands.Init()
	local function onPlayer(player)
		player.Chatted:Connect(function(message)
			AdminCommands.Handle(player, message)
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return AdminCommands
