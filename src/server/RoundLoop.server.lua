-- RoundLoop: bucle de rondas de ejemplo: espera -> votacion -> construye isla -> teletransporta -> ronda -> vuelta al lobby.
-- Si ya tienes tu propio bucle, pon Config.RunDefaultLoop = false y llama a MapService / VoteService desde el tuyo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Config"))

-- Los RemoteEvents los crea el servidor antes de cargar los demas modulos
local Remotes = Instance.new("Folder")
Remotes.Name = "IslasRemotes"
for _, name in ipairs({ "VoteOptions", "VoteUpdate", "VoteEnd", "CastVote", "RoundStatus" }) do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = Remotes
end
Remotes.Parent = ReplicatedStorage

local MapService = require(script.Parent.MapService)
local VoteService = require(script.Parent.VoteService)
local RoundStatus = Remotes.RoundStatus

if not Config.RunDefaultLoop then
	return
end

local function status(text, seconds)
	RoundStatus:FireAllClients(text, seconds and (workspace:GetServerTimeNow() + seconds) or nil)
end

local function countdown(text, seconds)
	status(text, seconds)
	task.wait(seconds)
end

local function alivePlayers(list)
	local n = 0
	for _, p in ipairs(list) do
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if p.Parent and hum and hum.Health > 0 then
			n = n + 1
		end
	end
	return n
end

while true do
	while #Players:GetPlayers() < Config.MinPlayers do
		status("Esperando jugadores...")
		task.wait(1)
	end

	countdown("Siguiente votacion en", Config.IntermissionTime)

	-- Votacion: las islas siguen SIN existir
	status("Vota el siguiente mapa")
	local winner = VoteService.Run(VoteService.PickOptions(Config.OptionsPerVote), Config.VoteTime)

	-- Solo ahora se construye la isla ganadora
	local title = MapService.GetInfo(winner).Title
	status("Construyendo " .. title .. "...")
	local ok, err = pcall(MapService.Load, winner)
	if not ok then
		warn("Error construyendo el mapa " .. winner .. ": " .. tostring(err))
		MapService.Unload()
		task.wait(3)
	else
		local participants = Players:GetPlayers()
		MapService.TeleportToMap(participants)

		-- Ronda
		local endTime = os.clock() + Config.RoundTime
		status("Sobrevive en " .. title, Config.RoundTime)
		while os.clock() < endTime and alivePlayers(participants) > 0 do
			task.wait(0.5)
		end

		-- Fin: vuelta al lobby y se borra la isla (el siguiente mapa no existe hasta votarlo)
		status("Fin de la ronda")
		MapService.ReturnToLobby(Players:GetPlayers())
		task.wait(2)
		MapService.Unload()
	end
end
