-- Pruebas adicionales (se cargan desde test.lua)
local server = TEST.server
local MapService = require(server.MapService)
local DisasterService = require(server.DisasterService)
local Destruction = require(server.Destruction)
local DisasterInfo = require(game:GetService("ReplicatedStorage").IslasShared.DisasterInfo)

test("desastres", function()
	local names = DisasterService.GetNames()
	print("Desastres: " .. #names .. " -> " .. table.concat(names, ", "))
	check(#names >= 16, "deberia haber 16 desastres")
	for _, n in ipairs(names) do
		check(DisasterInfo[n] ~= nil, "falta DisasterInfo de " .. n)
	end
	local fxCount = {}
	game:GetService("ReplicatedStorage").IslasRemotes.DisasterFX.OnClientEvent:Connect(function(kind)
		fxCount[kind] = (fxCount[kind] or 0) + 1
	end)
	local players = { MakePlayer("A"), MakePlayer("B"), MakePlayer("C") }
	for _, mapName in ipairs(MapService.GetMapNames()) do
		if not SOLO or SOLO == mapName then
			runAsync(function() return MapService.Load(mapName) end, 600)
			SimAdvance(20)
			local cur = MapService.GetCurrent()
			local list = {}
			for _, d in ipairs(cur.Def.Disasters) do
				check(table.find(names, d) ~= nil, mapName .. ": desastre inexistente " .. d)
				list[#list + 1] = d
			end
			for _, d in ipairs(list) do
				for _, p in ipairs(players) do
					local hum = p.Character:FindFirstChildOfClass("Humanoid")
					hum.Health = 100
				end
				MapService.TeleportToMap(players)
				SimAdvance(0.5)
				local before = Destruction.Stats().broken
				local info = DisasterService.Start(cur, 25, d, { delay = 1, intensity = 1.3 })
				check(info and info.Name == d, mapName .. ": no arranco " .. d)
				SimAdvance(27)
				DisasterService.StopAll()
				SimAdvance(1)
				local hurt = 0
				for _, p in ipairs(players) do
					if p.Character:FindFirstChildOfClass("Humanoid").Health < 100 then hurt = hurt + 1 end
				end
				local broken = Destruction.Stats().broken - before
				print(string.format("  %s / %-10s rotas=%4d heridos=%d", mapName, d, broken, hurt))
				check(workspace:FindFirstChild("EfectosDesastre") == nil, mapName .. "/" .. d .. ": no limpio efectos")
				check(#DisasterService.Active() == 0, mapName .. "/" .. d .. ": quedo activo")
			end
			MapService.Unload()
			SimAdvance(2)
		end
	end
	local kinds = {}
	for k, v in pairs(fxCount) do kinds[#kinds + 1] = k .. "=" .. v end
	table.sort(kinds)
	print("  efectos enviados: " .. table.concat(kinds, " "))
	for _, p in ipairs(players) do RemovePlayer(p) end
end)

test("partida", function()
	local Config = TEST.Config
	Config.IntermissionTime = 3
	Config.VoteTime = 3
	Config.RoundTime = 40
	Config.ResultsTime = 2
	Config.DisasterDelay = 2
	Config.AliveTickInterval = 5
	local RS = game:GetService("ReplicatedStorage")
	local phases, results, popups, kills, toasts = {}, {}, 0, 0, 0
	local remotes = RS.IslasRemotes
	remotes.RoundState.OnClientEvent:Connect(function(st)
		if phases[#phases] ~= st.Phase then phases[#phases + 1] = st.Phase end
	end)
	remotes.RoundResults.OnClientEvent:Connect(function(r) results[#results + 1] = r end)
	remotes.Popup.OnClientEvent:Connect(function() popups = popups + 1 end)
	remotes.KillFeed.OnClientEvent:Connect(function() kills = kills + 1 end)
	remotes.Toast.OnClientEvent:Connect(function() toasts = toasts + 1 end)

	local p1 = MakePlayer("Ana")
	local p2 = MakePlayer("Beto")
	RunScript(TEST.server.Main)
	SimAdvance(5)
	check(workspace:FindFirstChild("Lobby") ~= nil, "no se construyo el lobby")
	check(p1:FindFirstChild("leaderstats") ~= nil, "sin leaderstats")
	local PlayerData = require(TEST.server.PlayerData)
	check(PlayerData.Get(p1) ~= nil, "datos no cargados")

	-- votar
	SimAdvance(4)
	local CastVote = remotes.CastVote
	local opts
	remotes.VoteOptions.OnClientEvent:Connect(function(o) opts = o end)
	SimAdvance(1)
	-- tres rondas
	local roundsSeen = 0
	for i = 1, 600 do
		SimAdvance(1)
		roundsSeen = #results
		if #results >= 4 then break end
	end
	print("  fases: " .. table.concat(phases, " > "))
	print(string.format("  resultados=%d popups=%d muertes=%d avisos=%d", #results, popups, kills, toasts))
	check(#results >= 2, "no llegaron resultados de ronda")
	check(table.find(phases, "Round") ~= nil and table.find(phases, "Vote") ~= nil and table.find(phases, "Results") ~= nil, "faltan fases")
	local d1 = PlayerData.Get(p1)
	print(string.format("  Ana: monedas=%d xp=%d victorias=%d rondas=%d racha=%d", d1.Coins, d1.XP, d1.Stats.Wins, d1.Stats.Rounds, d1.Stats.Streak))
	check(d1.Stats.Rounds >= 1, "no conto rondas")
	check(d1.Coins > 0, "no gano monedas")

	-- tienda
	local Shop = RS.IslasRemotes.ShopRequest
	d1.Coins = 5000
	_G.LOCAL_PLAYER = p1
	local ok, msg = Shop:InvokeServer("buy", "GloboVerde")
	check(ok, "no pudo comprar: " .. tostring(msg))
	ok, msg = Shop:InvokeServer("buy", "GloboVerde")
	check(not ok, "compro dos veces")
	ok = Shop:InvokeServer("buy", "EstelaFuego")
	check(ok, "no compro estela")
	ok = Shop:InvokeServer("buy", "RanuraExtra")
	ok = Shop:InvokeServer("buy", "Jetpack")
	check(#d1.Equipped.Gears == 2, "deberia llevar 2 gears con la ranura extra (" .. #d1.Equipped.Gears .. ")")
	SimAdvance(5) -- por si la ronda aun no habia devuelto a los jugadores al lobby
	local tools = 0
	for _, t in ipairs(p1.Backpack:GetChildren()) do if t:IsA("Tool") then tools = tools + 1 end end
	print("  herramientas en la mochila: " .. tools)
	check(tools >= 1, "no recibio gears")
	d1.Coins = 3000
	ok = Shop:InvokeServer("buy", "Escudo")
	check(ok, "no compro escudo")
	check(d1.Coins == 650, "no cobro bien el escudo (" .. d1.Coins .. "): 3000 - 2500 + 150 del logro De compras")
	check(d1.Achievements.Comprador ~= nil, "no dio el logro De compras")
	_G.LOCAL_PLAYER = nil

	-- recompensa diaria
	local Rewards = require(TEST.server.Rewards)
	local okD, amount = Rewards.ClaimDaily(p2)
	check(okD and amount > 0, "no dio recompensa diaria")
	check(not Rewards.ClaimDaily(p2), "dio la diaria dos veces")
	RemovePlayer(p1)
	RemovePlayer(p2)
end)
