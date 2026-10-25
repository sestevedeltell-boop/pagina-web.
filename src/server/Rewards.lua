-- Rewards: monedas, experiencia, estadisticas, logros y recompensa diaria, con avisos al cliente
-- (numeros que saltan, subida de nivel, logro desbloqueado...).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Achievements = require(Shared:WaitForChild("Achievements"))
local Levels = require(Shared:WaitForChild("Levels"))
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)

local Popup = Net.Event("Popup")
local Toast = Net.Event("Toast")
local PlaySound = Net.Event("PlaySound")

local Rewards = {}

Rewards.Multiplier = 1 -- lo cambia GameLoop (monedas x2, modo hiper...)

local function checkAchievements(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	for _, a in ipairs(Achievements) do
		if not data.Achievements[a.Id] then
			local value = data.Stats[a.Stat] or 0
			if value >= a.Goal then
				data.Achievements[a.Id] = os.time()
				PlayerData.AddCoins(player, a.Reward)
				Toast:FireClient(player, {
					Kind = "Achievement",
					Title = "🏆 Logro: " .. a.Name,
					Text = a.Desc .. "  (+" .. a.Reward .. " monedas)",
				})
				PlaySound:FireClient(player, "Win", nil, 0.8)
			end
		end
	end
end
Rewards.CheckAchievements = checkAchievements

-- coins/xp: cantidades base. opts.noMultiplier, opts.text (motivo), opts.position (Vector3: popup en el mundo)
function Rewards.Give(player, coins, xp, opts)
	opts = opts or {}
	local data = PlayerData.Get(player)
	if not data then
		return 0, 0
	end
	local mult = opts.noMultiplier and 1 or Rewards.Multiplier
	if opts.lucky and data.Owned.Suerte then
		mult = mult * 1.25
	end
	local c = math.floor((coins or 0) * mult + 0.5)
	local x = math.floor((xp or 0) * (opts.noMultiplier and 1 or math.max(1, Rewards.Multiplier * 0.75)) + 0.5)
	if c ~= 0 then
		PlayerData.AddCoins(player, c)
	end
	local before, after = 1, 1
	if x > 0 then
		before, after = PlayerData.AddXP(player, x)
	end
	if c > 0 or x > 0 then
		Popup:FireClient(player, { Coins = c, XP = x, Text = opts.text, Position = opts.position })
	end
	if after > before then
		local title = Levels.Title(after)
		Toast:FireClient(player, { Kind = "LevelUp", Title = "¡NIVEL " .. after .. "!", Text = "Rango: " .. title, Level = after })
		PlaySound:FireClient(player, "LevelUp", nil, 1)
		-- recompensa por subir de nivel
		PlayerData.AddCoins(player, 25 + after * 5)
	end
	checkAchievements(player)
	return c, x
end

-- Suma (o fija con set=true) una estadistica y revisa logros
function Rewards.Stat(player, stat, delta, set)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	if set then
		data.Stats[stat] = delta
	else
		data.Stats[stat] = (data.Stats[stat] or 0) + delta
	end
	PlayerData.MarkDirty(player, stat)
	checkAchievements(player)
end

-- Apunta algo en una coleccion (mapas/desastres sobrevividos) y actualiza el contador
function Rewards.Collect(player, setName, key, statName)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local set = data[setName]
	if not set[key] then
		set[key] = true
		local n = 0
		for _ in pairs(set) do
			n = n + 1
		end
		data.Stats[statName] = n
		PlayerData.MarkDirty(player, statName)
		checkAchievements(player)
	end
end

function Rewards.DailyInfo(player)
	local data = PlayerData.Get(player)
	if not data then
		return false, 0, 0
	end
	local now = os.time()
	local available = now - (data.LastDaily or 0) >= 20 * 3600
	local streak = data.Stats.DailyStreak or 0
	if now - (data.LastDaily or 0) > 48 * 3600 then
		streak = 0
	end
	local nextDay = math.min(streak + 1, Config.DailyRewardMaxDays)
	return available, nextDay, Config.DailyRewardBase * nextDay
end

function Rewards.ClaimDaily(player)
	local data = PlayerData.Get(player)
	if not data then
		return false
	end
	local available, day, amount = Rewards.DailyInfo(player)
	if not available then
		return false
	end
	data.LastDaily = os.time()
	data.Stats.DailyStreak = day
	Rewards.Give(player, amount, 20, { noMultiplier = true, text = "Recompensa diaria (dia " .. day .. ")" })
	Rewards.Stat(player, "DailyStreak", day, true)
	return true, amount, day
end

function Rewards.Init()
	Net.Event("DailyClaim").OnServerEvent:Connect(function(player)
		Rewards.ClaimDaily(player)
	end)
end

return Rewards
