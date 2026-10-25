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
	-- comandos de administrador (en el simulador cuenta como Studio)
	local Admin = require(TEST.server.AdminCommands)
	local before = PlayerData.Get(p2).Coins
	check(Admin.Handle(p2, "!monedas 100"), "no reconocio !monedas")
	SimAdvance(0.2)
	check(PlayerData.Get(p2).Coins == before + 100, "!monedas no dio monedas")
	check(Admin.Handle(p2, "!mapa castil"), "no reconocio !mapa")
	check(Admin.Handle(p2, "!desastre tornad"), "no reconocio !desastre")
	local lastMap
	remotes.RoundState.OnClientEvent:Connect(function(st) if st.Map then lastMap = st.Map end end)
	check(Admin.Handle(p2, "!saltar"), "no reconocio !saltar")
	-- puede que ya hubiera una votacion en marcha: el forzado vale para la siguiente ronda
	local seen = {}
	remotes.RoundState.OnClientEvent:Connect(function(st) if st.Map and seen[#seen] ~= st.Map then seen[#seen + 1] = st.Map end end)
	for _ = 1, 400 do
		SimAdvance(1)
		if table.find(seen, "Castillo") then lastMap = "Castillo" break end
	end
	check(lastMap == "Castillo", "!mapa no forzo el mapa (" .. tostring(lastMap) .. ")")
	check(not Admin.Handle(p2, "hola"), "trato un mensaje normal como comando")
	RemovePlayer(p1)
	RemovePlayer(p2)
end)

test("fusion", function()
	local SS = game:GetService("ServerStorage")
	local SSS = game:GetService("ServerScriptService")
	local MapService = require(TEST.server.MapService)
	local DisasterService = require(TEST.server.DisasterService)
	local Destruction = require(TEST.server.Destruction)
	-- juego "viejo" de mentira
	local function makeMap(name, class, parent, offset)
		local m = Instance.new(class)
		m.Name = name
		local floor = Instance.new("Part")
		floor.Anchored = true
		floor.Size = Vector3.new(120, 2, 120)
		floor.Position = offset + Vector3.new(0, -1, 0)
		floor.Parent = m
		for i = 1, 6 do
			local w = Instance.new("Part")
			w.Anchored = (i % 2 == 0) -- algunas sueltas (muebles con fisica)
			w.Size = Vector3.new(10, 10, 1)
			w.Position = offset + Vector3.new(-30 + i * 9, 5, 0)
			w.Parent = m
		end
		local sp = Instance.new("SpawnLocation")
		sp.Size = Vector3.new(6, 1, 6)
		sp.Position = offset + Vector3.new(0, 0.5, 30)
		sp.Parent = m
		local spawns = Instance.new("Folder")
		spawns.Name = "Spawns"
		spawns.Parent = m
		local s2 = Instance.new("Part")
		s2.Anchored = true
		s2.Position = offset + Vector3.new(20, 1, 30)
		s2.Parent = spawns
		m.Parent = parent
		return m
	end
	local mapsFolder = Instance.new("Folder")
	mapsFolder.Name = "Maps"
	mapsFolder.Parent = SS
	makeMap("Granja", "Model", mapsFolder, Vector3.new(500, 0, 0))
	makeMap("Desierto", "Folder", mapsFolder, Vector3.new(-500, 0, 300))
	makeMap("City", "Model", mapsFolder, Vector3.new(0, 0, 900)) -- mismo nombre que un mapa generado
	local loose = makeMap("PuebloSuelto", "Model", workspace, Vector3.new(1500, 0, 0)) -- puesto en el workspace
	local round = Instance.new("Script")
	round.Name = "RoundSystem"
	round.Source = "local Intermission = 15\nwhile true do\n -- disaster round\n local maps = game.ServerStorage.Maps:GetChildren()\nend"
	round.Parent = SSS
	local harmless = Instance.new("Script")
	harmless.Name = "Saludo"
	harmless.Source = "print('hola')"
	harmless.Parent = SSS

	-- 1) exportar
	local exportSrc = TOOL_EXPORT
	local okE, errE = pcall(load(exportSrc, "=exportar", "t", _G))
	check(okE, "la exportacion fallo: " .. tostring(errE))
	local exp = SS:FindFirstChild("IslasExportacion")
	check(exp and #exp:GetChildren() >= 1, "no creo IslasExportacion")
	if exp then
		local txt = exp:GetChildren()[1].Source
		check(txt:find("RoundSystem", 1, true) and txt:find("Granja", 1, true), "la exportacion no incluye scripts o mapas")
		print("  exportacion: " .. #txt .. " caracteres")
	end

	-- 2) preparar fusion (aplicando)
	local src = TOOL_MERGE:gsub("local APLICAR = false", "local APLICAR = true"):gsub('local MAPAS_SUELTOS = {}', 'local MAPAS_SUELTOS = { "Workspace.PuebloSuelto" }')
	local okM, errM = pcall(load(src, "=fusion", "t", _G))
	check(okM, "preparar fusion fallo: " .. tostring(errM))
	local target = SS:FindFirstChild("IslasMapasPropios")
	check(target and target:FindFirstChild("Granja") and target:FindFirstChild("Desierto") and target:FindFirstChild("City_Propio") and target:FindFirstChild("PuebloSuelto"), "no movio los mapas")
	check(loose.Parent == target, "el mapa del workspace sigue cargado")
	check(round.Disabled == true, "no desactivo el bucle de rondas viejo")
	check(harmless.Disabled == false, "desactivo un script que no tenia que ver")

	-- 3) los mapas propios salen en la votacion y solo existen al cargarlos
	local names = MapService.GetMapNames()
	for _, n in ipairs({ "Granja", "Desierto", "City_Propio", "PuebloSuelto", "City" }) do
		check(table.find(names, n), "falta el mapa " .. n .. " en la votacion")
	end
	local player = MakePlayer("Fusion")
	for _, n in ipairs({ "Granja", "Desierto" }) do
		check(workspace:FindFirstChild("MapaActual_" .. n) == nil, n .. " ya estaba cargado antes de votarlo")
		runAsync(function() return MapService.Load(n) end, 120)
		local cur = MapService.GetCurrent()
		check(cur and #cur.Spawns >= 2, n .. ": no encontro los spawns (" .. (cur and #cur.Spawns or 0) .. ")")
		check(target:FindFirstChild(n) ~= nil, n .. ": el original desaparecio de ServerStorage")
		MapService.TeleportToMap({ player })
		SimAdvance(0.5)
		check(MapService.IsOnMap(player), n .. ": el jugador no llego")
		for _ = 1, 60 do
			if Destruction.Stats().graphReady then break end
			SimAdvance(1)
		end
		local anchoredAll = true
		for _, d in ipairs(cur.Folder:GetDescendants()) do
			if d:IsA("BasePart") and not d.Anchored then anchoredAll = false end
		end
		check(anchoredAll, n .. ": quedaron piezas sueltas con fisica")
		DisasterService.Start(cur, 10, "Meteors", { delay = 0.5 })
		SimAdvance(12)
		DisasterService.StopAll()
		print(string.format("  %s: %d spawns, rotas=%d", n, #cur.Spawns, Destruction.Stats().broken))
		MapService.ReturnToLobby({ player })
		MapService.Unload()
		SimAdvance(3)
		check(workspace:FindFirstChild("MapaActual_" .. n) == nil, n .. ": no se descargo")
	end
	RemovePlayer(player)
end)
