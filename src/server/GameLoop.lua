-- GameLoop: el ciclo de partida.
--   Descanso en el lobby -> votacion -> se construye la isla -> aviso -> ronda con desastre(s) -> resultados
-- Cada ronda puede traer un modificador (doble desastre, monedas x2, noche, gravedad baja...), un desastre
-- sorpresa o un segundo desastre a mitad de ronda. Sobrevivir da monedas, XP y racha.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Modifiers = require(Shared:WaitForChild("Modifiers"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))

local S = script.Parent
local MapService = require(S.MapService)
local VoteService = require(S.VoteService)
local DisasterService = require(S.DisasterService)
local Destruction = require(S.Destruction)
local PlayerData = require(S.PlayerData)
local Rewards = require(S.Rewards)
local Gear = require(S.Gear)
local CoinDrops = require(S.CoinDrops)
local Lobby = require(S.Lobby)

local RoundState = Net.Event("RoundState")
local RoundStatus = Net.Event("RoundStatus")
local RoundResults = Net.Event("RoundResults")
local KillFeed = Net.Event("KillFeed")
local PlaySound = Net.Event("PlaySound")

local GameLoop = {}

local state = {
	Phase = "Intermission",
	Status = "",
	EndsAt = 0,
	Map = nil,
	Disasters = {},
	Modifier = nil,
	Alive = 0,
	Total = 0,
	AliveIds = {},
}
GameLoop.State = state

local participants = {} -- [player] = { alive = bool, conn }

local function now()
	return workspace:GetServerTimeNow()
end

local function broadcast()
	RoundState:FireAllClients(state)
end

local function setPhase(phase, seconds, status)
	state.Phase = phase
	state.Status = status or ""
	state.EndsAt = seconds and (now() + seconds) or 0
	broadcast()
	RoundStatus:FireAllClients(status, seconds and state.EndsAt or nil)
	Lobby.SetStatus(status, seconds and Format.Time(seconds) or "")
end

-- espera actualizando el temporizador del lobby
local function countdown(seconds, status)
	local endAt = now() + seconds
	while now() < endAt do
		Lobby.SetStatus(status, Format.Time(endAt - now()))
		task.wait(math.min(1, math.max(0.05, endAt - now())))
	end
end

local function refreshAlive()
	local alive, ids, total = 0, {}, 0
	for player, p in pairs(participants) do
		total = total + 1
		if p.alive then
			alive = alive + 1
			ids[#ids + 1] = player.UserId
		end
	end
	if alive ~= state.Alive or total ~= state.Total then
		state.Alive, state.Total, state.AliveIds = alive, total, ids
		broadcast()
	end
	return alive
end

local function pickModifier()
	if math.random() > Config.ModifierChance then
		return nil
	end
	local total = 0
	for _, m in ipairs(Modifiers) do
		total = total + (m.Weight or 1)
	end
	local r = math.random() * total
	for _, m in ipairs(Modifiers) do
		r = r - (m.Weight or 1)
		if r <= 0 then
			return m
		end
	end
	return Modifiers[1]
end

-- ======================================================================
-- Modificadores
-- ======================================================================
local revert = {}

local function applyModifier(mod, list)
	table.clear(revert)
	Rewards.Multiplier = 1
	if not mod then
		return 1
	end
	local intensity = 1
	if mod.Id == "Monedas2" then
		Rewards.Multiplier = 2
	elseif mod.Id == "Hiper" then
		intensity = 1.6
		Rewards.Multiplier = 1.5
	elseif mod.Id == "Noche" then
		local old = { ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, OutdoorAmbient = Lighting.OutdoorAmbient }
		Lighting.ClockTime = 0
		Lighting.Brightness = 0.2
		Lighting.OutdoorAmbient = Color3.fromRGB(25, 25, 40)
		revert[#revert + 1] = function()
			for k, v in pairs(old) do
				Lighting[k] = v
			end
		end
	elseif mod.Id == "GravedadBaja" then
		local old = workspace.Gravity
		workspace.Gravity = 75
		revert[#revert + 1] = function()
			workspace.Gravity = old
		end
	elseif mod.Id == "Velocidad" then
		for _, player in ipairs(list) do
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:SetAttribute("VelocidadBase", 26)
				hum.WalkSpeed = 26
			end
		end
		revert[#revert + 1] = function()
			for _, player in ipairs(list) do
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum:SetAttribute("VelocidadBase", nil)
					hum.WalkSpeed = 16
				end
			end
		end
	elseif mod.Id == "Niebla" then
		local old = { FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor }
		Lighting.FogStart = 0
		Lighting.FogEnd = 90
		Lighting.FogColor = Color3.fromRGB(190, 190, 200)
		revert[#revert + 1] = function()
			for k, v in pairs(old) do
				Lighting[k] = v
			end
		end
	elseif mod.Id == "Fragil" then
		Destruction.SetToughness(0.35)
	end
	return intensity
end

local function revertModifier()
	for i = #revert, 1, -1 do
		pcall(revert[i])
	end
	table.clear(revert)
	Rewards.Multiplier = 1
end

-- ======================================================================
-- Ronda
-- ======================================================================
local function onDeath(player)
	local p = participants[player]
	if not p or not p.alive then
		return
	end
	p.alive = false
	player:SetAttribute("EnRonda", nil)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local cause = hum and hum:GetAttribute("Causa") or "Caida"
	KillFeed:FireAllClients({ Name = player.DisplayName, Cause = cause, UserId = player.UserId })
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		PlaySound:FireAllClients("Death", hrp.Position, 0.8)
	end
	refreshAlive()
end

local function prepareParticipant(player, mod)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false
	end
	local data = PlayerData.Get(player)
	hum.MaxHealth = (data and data.Owned.VidaExtra) and 125 or 100
	hum.Health = hum.MaxHealth
	hum:SetAttribute("Causa", nil)
	player:SetAttribute("EnRonda", true)
	Gear.Give(player, (mod and mod.Id == "Noche") and { "Linterna" } or nil)
	local conn = hum.Died:Connect(function()
		onDeath(player)
	end)
	participants[player] = { alive = true, conn = conn }
	return true
end

local function playRound(winner)
	local info = MapService.GetInfo(winner)
	setPhase("Loading", nil, "Construyendo " .. info.Title .. "...")
	local ok, err = pcall(MapService.Load, winner)
	if not ok then
		warn("GameLoop: error construyendo " .. winner .. ": " .. tostring(err))
		MapService.Unload()
		task.wait(2)
		return
	end
	local current = MapService.GetCurrent()

	local mod = pickModifier()
	state.Map = info.Title
	state.Modifier = mod and { Id = mod.Id, Title = mod.Title, Desc = mod.Desc, Color = mod.Color } or nil
	state.Disasters = {}

	-- participantes: todos los que estan vivos en el lobby
	table.clear(participants)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if prepareParticipant(player, mod) then
			list[#list + 1] = player
		end
	end
	local intensity = applyModifier(mod, list)
	MapService.TeleportToMap(list)
	refreshAlive()

	-- desastres
	local disasters = {}
	if Config.EnableDisasters then
		local mystery = math.random() < Config.MysteryChance
		local first = DisasterService.Start(current, Config.RoundTime, nil, { intensity = intensity, mystery = mystery })
		if first then
			disasters[#disasters + 1] = first
			state.Disasters[#state.Disasters + 1] = mystery and { Title = "???", Icon = "❓" } or { Title = first.Title, Icon = first.Icon }
		end
		if mod and mod.Id == "Doble" and first then
			local second = DisasterService.Start(current, Config.RoundTime, DisasterService.Pick(current, first.Name), { intensity = intensity, delay = Config.DisasterDelay + 4 })
			if second then
				disasters[#disasters + 1] = second
				state.Disasters[#state.Disasters + 1] = { Title = second.Title, Icon = second.Icon }
			end
		end
	end
	CoinDrops.SpawnRound(current, Config.CoinPickups)

	local total = Config.DisasterDelay + Config.RoundTime
	setPhase("Round", total, mod and (mod.Title .. " · " .. info.Title) or ("Sobrevive en " .. info.Title))

	local startT = now()
	local endT = startT + total
	local secondTried = false
	local nextTick = startT + Config.DisasterDelay + Config.AliveTickInterval
	while now() < endT do
		task.wait(0.5)
		-- revisar vivos (por si alguien salio del mapa o del juego)
		for player, p in pairs(participants) do
			if not player.Parent then
				if p.conn then
					p.conn:Disconnect()
				end
				participants[player] = nil
			elseif p.alive then
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if not hum or hum.Health <= 0 then
					onDeath(player)
				elseif not MapService.IsOnMap(player) then
					-- fuera del mapa (por ejemplo, cayo al vacio y reaparecio en el lobby)
					p.alive = false
					refreshAlive()
				end
			end
		end
		if refreshAlive() == 0 then
			break
		end
		-- monedas por seguir vivo
		if now() >= nextTick then
			nextTick = nextTick + Config.AliveTickInterval
			for player, p in pairs(participants) do
				if p.alive then
					Rewards.Give(player, Config.AliveTickCoins, 2, { text = "Sigues vivo" })
				end
			end
		end
		-- segundo desastre a mitad de ronda
		if not secondTried and Config.EnableDisasters and now() > startT + Config.DisasterDelay + Config.RoundTime * 0.45 then
			secondTried = true
			if #disasters == 1 and math.random() < Config.SecondDisasterChance then
				local remaining = endT - now()
				local extra = DisasterService.Start(current, remaining - 5, DisasterService.Pick(current, disasters[1].Name), { intensity = intensity, delay = 5 })
				if extra then
					disasters[#disasters + 1] = extra
					state.Disasters[#state.Disasters + 1] = { Title = extra.Title, Icon = extra.Icon }
					broadcast()
				end
			end
		end
	end

	DisasterService.StopAll()
	CoinDrops.Clear()

	-- ===== Resultados =====
	local survivors, names = {}, {}
	for player, p in pairs(participants) do
		if p.alive and player.Parent then
			survivors[#survivors + 1] = player
			names[#names + 1] = player.DisplayName
		end
	end
	local titles = {}
	for _, d in ipairs(disasters) do
		titles[#titles + 1] = d.Title
	end
	setPhase("Results", Config.ResultsTime, #survivors > 0 and ("Sobrevivieron " .. #survivors .. " de " .. state.Total) or "No sobrevivio nadie")

	local count = state.Total
	for player, p in pairs(participants) do
		if p.conn then
			p.conn:Disconnect()
		end
		local data = PlayerData.Get(player)
		if data and player.Parent then
			local result = { Map = info.Title, Disasters = titles, Survivors = names, Total = count, Modifier = mod and mod.Title or nil }
			Rewards.Stat(player, "Rounds", 1)
			if p.alive then
				local streak = data.Stats.Streak + 1
				data.Stats.Streak = streak
				data.Stats.BestStreak = math.max(data.Stats.BestStreak, streak)
				local coins = Config.SurviveCoins + math.min(streak - 1, Config.MaxStreakBonus) * Config.StreakBonusCoins
				local c, x = Rewards.Give(player, coins, Config.SurviveXP, { text = "¡Sobreviviste!", lucky = true })
				Rewards.Stat(player, "Wins", 1)
				Rewards.Collect(player, "MapsDone", winner, "MapsSurvived")
				for _, d in ipairs(disasters) do
					Rewards.Collect(player, "DisastersDone", d.Name, "DisastersSurvived")
				end
				if #survivors == 1 and count >= 3 then
					Rewards.Stat(player, "SoleSurvivor", 1)
				end
				if #disasters >= 2 then
					Rewards.Stat(player, "DoubleSurvived", 1)
				end
				result.Survived, result.Coins, result.XP, result.Streak = true, c, x, streak
			else
				data.Stats.Streak = 0
				Rewards.Stat(player, "Deaths", 1)
				local c, x = Rewards.Give(player, Config.ParticipationCoins, Config.ParticipationXP, { text = "Participacion" })
				result.Survived, result.Coins, result.XP, result.Streak = false, c, x, 0
			end
			RoundResults:FireClient(player, result)
		end
	end
	task.wait(Config.ResultsTime)

	-- vuelta al lobby
	local back = {}
	for player in pairs(participants) do
		if player.Parent then
			back[#back + 1] = player
			player:SetAttribute("EnRonda", nil)
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.MaxHealth = 100
				hum.Health = 100
			end
		end
	end
	revertModifier()
	MapService.ReturnToLobby(back)
	for _, player in ipairs(back) do
		task.spawn(Gear.Refresh, player)
	end
	table.clear(participants)
	state.Map, state.Modifier, state.Disasters = nil, nil, {}
	state.Alive, state.Total, state.AliveIds = 0, 0, {}
	task.wait(1)
	MapService.Unload()
end

function GameLoop.Run()
	while true do
		while #Players:GetPlayers() < Config.MinPlayers do
			setPhase("Waiting", nil, "Esperando jugadores...")
			task.wait(2)
		end
		setPhase("Intermission", Config.IntermissionTime, "Descanso: compra en la tienda o haz el obby")
		countdown(Config.IntermissionTime, "Siguiente ronda en")

		setPhase("Vote", Config.VoteTime, "¡Vota el siguiente mapa!")
		local winner = VoteService.Run(VoteService.PickOptions(Config.OptionsPerVote), Config.VoteTime)

		local ok, err = pcall(playRound, winner)
		if not ok then
			warn("GameLoop: error en la ronda: " .. tostring(err))
			pcall(DisasterService.StopAll)
			pcall(revertModifier)
			pcall(MapService.ReturnToLobby)
			pcall(MapService.Unload)
			table.clear(participants)
			task.wait(3)
		end
	end
end

return GameLoop
