-- PlayerData: datos persistentes de cada jugador (DataStore) con guardado automatico.
-- Si el DataStore no esta disponible (por ejemplo en Studio sin "Enable Studio Access to API Services"),
-- se juega con datos temporales y NO se sobrescribe nada.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Levels = require(Shared:WaitForChild("Levels"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Net = require(Shared:WaitForChild("Net"))

local DataUpdate = Net.Event("DataUpdate")

local PlayerData = {}

local profiles = {} -- [player] = { data = {...}, noSave = bool, dirty = bool }
local changedHandlers = {}
local store
local orderedStore

local function defaultData()
	return {
		Version = 2,
		Coins = 0,
		XP = 0,
		Owned = {},
		Equipped = { Gears = {}, Trail = nil },
		Stats = {
			Wins = 0, Rounds = 0, Deaths = 0, BestStreak = 0, Streak = 0, CoinsEarned = 0, CoinsPicked = 0,
			Purchases = 0, ObbyCompleted = 0, SoleSurvivor = 0, DoubleSurvived = 0, MapsSurvived = 0,
			DisastersSurvived = 0, DailyStreak = 0, Level = 1,
		},
		MapsDone = {},
		DisastersDone = {},
		Achievements = {},
		LastDaily = 0,
		LastObby = 0,
		Settings = { Quality = 0, Shake = 1, Music = true, Sounds = true },
	}
end

-- rellena campos nuevos en datos antiguos
local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			if type(v) == "table" then
				data[k] = {}
				reconcile(data[k], v)
			else
				data[k] = v
			end
		elseif type(v) == "table" and type(data[k]) == "table" and k ~= "Owned" and k ~= "Achievements" and k ~= "MapsDone" and k ~= "DisastersDone" then
			reconcile(data[k], v)
		end
	end
	return data
end

local function keyFor(player)
	return "u_" .. player.UserId
end

function PlayerData.OnChanged(fn)
	changedHandlers[#changedHandlers + 1] = fn
end

local function fireChanged(player, key)
	for _, fn in ipairs(changedHandlers) do
		task.spawn(fn, player, key)
	end
end

function PlayerData.Get(player)
	local p = profiles[player]
	return p and p.data or nil
end

function PlayerData.WaitFor(player, timeout)
	local limit = os.clock() + (timeout or 15)
	while not profiles[player] and player.Parent and os.clock() < limit do
		task.wait(0.1)
	end
	return PlayerData.Get(player)
end

function PlayerData.LevelInfo(data)
	local level, into, need = Levels.FromTotal(data.XP)
	return level, into, need
end

function PlayerData.Snapshot(player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	local level, into, need = PlayerData.LevelInfo(data)
	local title, color = Levels.Title(level)
	local now = os.time()
	return {
		Coins = data.Coins,
		XP = data.XP,
		Level = level,
		LevelXP = into,
		LevelNeed = need,
		Title = title,
		TitleColor = color,
		Owned = data.Owned,
		Equipped = data.Equipped,
		Stats = data.Stats,
		Achievements = data.Achievements,
		Settings = data.Settings,
		GearSlots = Catalog.GearSlots(data.Owned),
		DailyAvailable = now - (data.LastDaily or 0) >= 20 * 3600,
		DailyStreak = data.Stats.DailyStreak,
		Temporary = profiles[player].noSave,
	}
end

local function updateLeaderstats(player)
	local data = PlayerData.Get(player)
	local ls = player:FindFirstChild("leaderstats")
	if not data or not ls then
		return
	end
	ls.Monedas.Value = data.Coins
	ls.Victorias.Value = data.Stats.Wins
	ls.Nivel.Value = (PlayerData.LevelInfo(data))
end

-- Envia los datos al cliente (agrupado: como mucho una vez por frame)
local pushPending = {}
function PlayerData.Push(player)
	if pushPending[player] then
		return
	end
	pushPending[player] = true
	task.defer(function()
		pushPending[player] = nil
		if player.Parent and profiles[player] then
			DataUpdate:FireClient(player, PlayerData.Snapshot(player))
			updateLeaderstats(player)
		end
	end)
end

function PlayerData.MarkDirty(player, key)
	local p = profiles[player]
	if p then
		p.dirty = true
		PlayerData.Push(player)
		fireChanged(player, key)
	end
end

function PlayerData.AddCoins(player, amount)
	local data = PlayerData.Get(player)
	if not data then
		return 0
	end
	amount = math.floor(amount + 0.5)
	data.Coins = math.max(0, data.Coins + amount)
	if amount > 0 then
		data.Stats.CoinsEarned = data.Stats.CoinsEarned + amount
	end
	PlayerData.MarkDirty(player, "Coins")
	return amount
end

function PlayerData.Spend(player, amount)
	local data = PlayerData.Get(player)
	if not data or data.Coins < amount then
		return false
	end
	data.Coins = data.Coins - amount
	PlayerData.MarkDirty(player, "Coins")
	return true
end

-- Devuelve nivelAntes, nivelDespues
function PlayerData.AddXP(player, amount)
	local data = PlayerData.Get(player)
	if not data then
		return 1, 1
	end
	local before = PlayerData.LevelInfo(data)
	data.XP = data.XP + math.floor(amount + 0.5)
	local after = PlayerData.LevelInfo(data)
	data.Stats.Level = after
	PlayerData.MarkDirty(player, "XP")
	return before, after
end

-- ======================================================================
-- Carga / guardado
-- ======================================================================
local function load(player)
	local data, ok
	if store then
		for attempt = 1, 3 do
			ok, data = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				break
			end
			task.wait(attempt)
		end
	end
	local noSave = not store or not ok
	if noSave and store then
		warn("PlayerData: no se pudieron cargar los datos de " .. player.Name .. "; se usan datos temporales")
	end
	data = reconcile(type(data) == "table" and data or defaultData(), defaultData())
	if not player.Parent then
		return
	end
	profiles[player] = { data = data, noSave = noSave, dirty = false }

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, n in ipairs({ "Victorias", "Nivel", "Monedas" }) do
		local v = Instance.new("IntValue")
		v.Name = n
		v.Parent = ls
	end
	ls.Parent = player
	updateLeaderstats(player)
	PlayerData.Push(player)
	fireChanged(player, "Loaded")
end

local function save(player, final)
	local p = profiles[player]
	if not p or p.noSave or not store then
		return true
	end
	if not p.dirty and not final then
		return true
	end
	local data = p.data
	local ok, err
	for attempt = 1, 3 do
		ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function()
				return data
			end)
		end)
		if ok then
			break
		end
		task.wait(attempt)
	end
	if ok then
		p.dirty = false
		if orderedStore then
			pcall(function()
				orderedStore:SetAsync(keyFor(player), data.Stats.Wins)
			end)
		end
	else
		warn("PlayerData: error guardando a " .. player.Name .. ": " .. tostring(err))
	end
	return ok
end
PlayerData.Save = save

function PlayerData.GetOrderedStore()
	return orderedStore
end

local started = false
function PlayerData.Init()
	if started then
		return
	end
	started = true
	local ok = pcall(function()
		store = DataStoreService:GetDataStore(Config.DataStoreName)
		orderedStore = DataStoreService:GetOrderedDataStore(Config.LeaderboardStoreName)
	end)
	if not ok then
		store, orderedStore = nil, nil
		warn("PlayerData: DataStore no disponible, los datos no se guardaran")
	end

	Players.PlayerAdded:Connect(function(player)
		load(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player, true)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		for player in pairs(profiles) do
			task.spawn(save, player, true)
		end
		task.wait(3)
	end)
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in pairs(profiles) do
				task.spawn(save, player, false)
			end
		end
	end)

	Net.Function("GetData").OnServerInvoke = function(player)
		PlayerData.WaitFor(player, 10)
		return PlayerData.Snapshot(player)
	end

	Net.Event("SettingsChanged").OnServerEvent:Connect(function(player, settings)
		local data = PlayerData.Get(player)
		if not data or typeof(settings) ~= "table" then
			return
		end
		local s = data.Settings
		if typeof(settings.Quality) == "number" then
			s.Quality = math.clamp(math.floor(settings.Quality), 0, 3)
		end
		if typeof(settings.Shake) == "number" then
			s.Shake = math.clamp(settings.Shake, 0, 1)
		end
		if typeof(settings.Music) == "boolean" then
			s.Music = settings.Music
		end
		if typeof(settings.Sounds) == "boolean" then
			s.Sounds = settings.Sounds
		end
		profiles[player].dirty = true
	end)
end

return PlayerData
