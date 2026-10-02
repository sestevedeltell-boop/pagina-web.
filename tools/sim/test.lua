-- Prueba: construye cada mapa, comprueba ascensores, spawns, teletransporte y descarga.
local serverFolder = BuildTree()
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- RemoteEvents que crea RoundLoop en el juego real
local remotes = NewInstance("Folder")
remotes.Name = "IslasRemotes"
for _, n in ipairs({ "VoteOptions", "VoteUpdate", "VoteEnd", "CastVote", "RoundStatus", "DisasterFX" }) do
	local r = NewInstance("RemoteEvent")
	r.Name = n
	r.Parent = remotes
end
remotes.Parent = ReplicatedStorage

local Config = require(ReplicatedStorage.IslasShared.Config)
-- MapService y VoteService viven en ServerScriptService en el juego real
local function serverModule(name) return InstMethods.FindFirstChild(serverFolder, name) end
local MapService = require(serverModule("MapService"))
local VoteService = require(serverModule("VoteService"))
local DisasterService = require(serverModule("DisasterService"))
local roundLoopNode = serverModule("RoundLoop")

local failures = 0
local function check(cond, msg)
	if not cond then
		failures = failures + 1
		print("FALLO: " .. msg)
	end
end

local names = MapService.GetMapNames()
print("Mapas: " .. table.concat(names, ", "))
check(#names >= 1, "no hay mapas")

local function dump(name, folder)
	for _, d in ipairs(InstMethods.GetDescendants(folder)) do
		if d._p.ClassName == "Part" then
			local p = d._p
			local rot = p.CFrame and p.CFrame.Rot or { X = 0, Y = 0, Z = 0 }
			print(string.format("PART\t%s\t%s\t%.2f,%.2f,%.2f\t%.2f,%.2f,%.2f\t%.3f,%.3f,%.3f\t%.2f,%.2f,%.2f\t%s\t%s\t%s",
				name, p.Name, p.Size.X, p.Size.Y, p.Size.Z, p.Position.X, p.Position.Y, p.Position.Z,
				rot.X, rot.Y, rot.Z, p.Color.R, p.Color.G, p.Color.B, tostring(p.Transparency or 0),
				tostring(p.CanCollide), tostring(p.Shape)))
		end
	end
end

for _, name in ipairs(names) do
	-- antes de cargarlo, el mapa NO existe en el workspace
	check(#workspace._children == 0, "el workspace deberia estar vacio antes de cargar " .. name)
	local t0 = os.clock()
	local folder = MapService.Load(name)
	local cur = MapService.GetCurrent()
	local info = MapService.GetInfo(name)
	print(string.format("%s (%s): %d piezas, %d spawns, %.2fs", name, info.Title, #InstMethods.GetDescendants(folder), #cur.Spawns, os.clock() - t0))
	check(#cur.Spawns >= 8, name .. ": pocos spawns")
	for _, sp in ipairs(cur.Spawns) do
		local y = sp.Position.Y - Config.MapOrigin.Y
		check(y > -1 and y < 400, name .. ": spawn con altura rara " .. y)
	end

	-- NaN / tamanos invalidos
	for _, d in ipairs(InstMethods.GetDescendants(folder)) do
		if d._p.ClassName == "Part" or d._p.ClassName == "TrussPart" then
			local s, p = d._p.Size, d._p.Position
			for _, n in ipairs({ s.X, s.Y, s.Z, p.X, p.Y, p.Z }) do
				if n ~= n or n == math.huge or n == -math.huge then check(false, name .. ": NaN en " .. d._p.Name) break end
			end
			check(s.X > 0 and s.Y > 0 and s.Z > 0, name .. ": tamano <= 0 en " .. d._p.Name .. " " .. s.X .. "," .. s.Y .. "," .. s.Z)
		end
	end

	-- Ascensores: llamar a cada planta y comprobar donde queda la cabina
	local nElev = 0
	for _, d in ipairs(InstMethods.GetDescendants(folder)) do
		if d._p.ClassName == "Model" and d._p.Name:match("_Cabina$") then
			nElev = nElev + 1
			local floorPart = d._p.PrimaryPart
			check(floorPart ~= nil, name .. ": cabina sin PrimaryPart")
			local base = floorPart._p.Position.Y
			local prompts = {}
			for _, pp in ipairs(InstMethods.GetDescendants(folder)) do
				if pp._p.ClassName == "ProximityPrompt" and pp._p.Parent._p.Parent == d._p.Parent
					and pp._p.ObjectText then
					prompts[#prompts + 1] = pp
				end
			end
			-- los prompts de este ascensor estan en su carpeta _Hueco: mismo prefijo de nombre
			local prefix = d._p.Name:gsub("_Cabina$", "")
			local mine = {}
			for _, pp in ipairs(InstMethods.GetDescendants(folder)) do
				if pp._p.ClassName == "ProximityPrompt" then
					local anc = pp._p.Parent._p.Parent
					if anc and anc._p.Name == prefix .. "_Hueco" then mine[#mine + 1] = pp end
				end
			end
			check(#mine >= 2, name .. ": " .. prefix .. " con menos de 2 plantas")
			local lastY = base
			for i = #mine, 1, -1 do
				mine[i]._signals.Triggered:Fire()
				local y = floorPart._p.Position.Y
				check(y >= base - 0.01, name .. ": cabina bajo del suelo")
				lastY = y
			end
			-- tras visitar la planta 1 la cabina debe estar de vuelta en la base
			check(math.abs(floorPart._p.Position.Y - base) < 0.01, name .. ": " .. prefix .. " no vuelve a la planta 1 (" .. floorPart._p.Position.Y .. " vs " .. base .. ")")
			-- subir a la ultima planta
			mine[#mine]._signals.Triggered:Fire()
			check(floorPart._p.Position.Y > base + 5, name .. ": " .. prefix .. " no sube")
			print(string.format("  %s: %d plantas, sube %.1f", prefix, #mine, floorPart._p.Position.Y - base))
		end
	end
	check(nElev >= 1, name .. ": no tiene ascensores")

	if DUMP then dump(name, folder) end

	-- teletransporte de jugadores falsos
	local fake = {}
	for i = 1, 4 do
		local pl = NewInstance("Player")
		local char = NewInstance("Model")
		local root = NewInstance("Part")
		root.Name = "HumanoidRootPart"
		root.Position = Vector3.new(0, 5, 0)
		root.Parent = char
		char.PrimaryPart = root
		pl.Character = char
		fake[i] = pl
	end
	MapService.TeleportToMap(fake)
	for _, pl in ipairs(fake) do
		local pos = pl.Character.PrimaryPart.Position
		check(pos.X > Config.MapOrigin.X - 1000 and pos.X < Config.MapOrigin.X + 1000, name .. ": jugador no teletransportado a la isla (x=" .. pos.X .. ")")
	end
	-- ===== Desastres =====
	local lightingBefore = game:GetService("Lighting").Brightness
	check(#(cur.Def.Disasters or {}) >= 3, name .. ": deberia tener al menos 3 desastres")
	FAKE_PLAYERS = fake
	for _, pl in ipairs(fake) do
		local hum = NewInstance("Humanoid")
		hum.Health = 100
		hum.Parent = pl.Character
	end
	for _, dn in ipairs(cur.Def.Disasters or {}) do
		for _, pl in ipairs(fake) do InstMethods.FindFirstChildOfClass(pl.Character, "Humanoid").Health = 100 end
		local info = DisasterService.Start(cur, 180, dn)
		check(info and info.Name == dn, name .. ": no arranco el desastre " .. dn)
		local fxFolder = workspace:FindFirstChild("EfectosDesastre")
		local fxParts = fxFolder and #InstMethods.GetDescendants(fxFolder) or 0
		local hurt = false
		for _, pl in ipairs(fake) do
			if InstMethods.FindFirstChildOfClass(pl.Character, "Humanoid").Health < 100 then hurt = true end
		end
		local freed = 0
		if dn == "Earthquake" then
			for _, d in ipairs(InstMethods.GetDescendants(cur.Folder)) do
				if d._p.ClassName == "Part" and d._p.Anchored == false then freed = freed + 1 end
			end
			check(freed > 5, name .. "/" .. dn .. ": no rompio piezas")
		elseif dn ~= "AcidRain" then
			check(fxParts > 0, name .. "/" .. dn .. ": no creo efectos")
		end
		if dn == "Flood" or dn == "Lava" or dn == "AcidRain" then
			check(hurt, name .. "/" .. dn .. ": no hizo dano a nadie")
		end
		DisasterService.Stop()
		check(workspace:FindFirstChild("EfectosDesastre") == nil, name .. "/" .. dn .. ": no limpio los efectos")
		check(game:GetService("Lighting").Brightness == lightingBefore, name .. "/" .. dn .. ": no restauro la luz")
		print(string.format("  desastre %-10s ok (efectos=%d, rotas=%d, dano=%s)", dn, fxParts, freed, tostring(hurt)))
	end
	FAKE_PLAYERS = {}

	MapService.ReturnToLobby(fake)
	for _, pl in ipairs(fake) do
		local pos = pl.Character.PrimaryPart.Position
		check(math.abs(pos.X) < 200, name .. ": jugador no vuelve al lobby (x=" .. pos.X .. ")")
	end
	-- el lobby por defecto se crea una vez; lo quitamos del recuento
	MapService.Unload()
	local left = 0
	for _, c in ipairs(workspace._children) do
		if c._p.Name:match("^MapaActual") then left = left + 1 end
	end
	check(left == 0, name .. ": el mapa no se descargo")
	-- quitamos el lobby por defecto para que el siguiente chequeo "workspace vacio" sea valido
	for i = #workspace._children, 1, -1 do
		if workspace._children[i]._p.Name == "LobbyPorDefecto" then workspace._children[i]._p.Parent = nil table.remove(workspace._children, i) end
	end
end

-- Mapas sin tocar workspace antes: lobby recreado cada vez porque lobbySpawns se cachea, por eso arriba se reinyecta.
-- ===== Votacion =====
local picked = VoteService.PickOptions(3)
check(#picked == 3, "PickOptions deberia devolver 3 mapas")
local seen = {}
for _, n in ipairs(picked) do
	check(not seen[n], "PickOptions repite " .. n)
	seen[n] = true
end
local CastVote = remotes.CastVote
local voter1, voter2, voter3 = NewInstance("Player"), NewInstance("Player"), NewInstance("Player")
voter1.UserId, voter2.UserId, voter3.UserId = 1, 2, 3
local originalWait = task.wait
local fired = {}
remotes.VoteEnd.OnClientEvent:Connect(function(w) fired.winner = w end)
task.wait = function()
	-- los jugadores votan mientras dura la votacion
	CastVote.OnServerEvent:Fire(voter1, picked[2])
	CastVote.OnServerEvent:Fire(voter2, picked[2])
	CastVote.OnServerEvent:Fire(voter3, picked[1])
	CastVote.OnServerEvent:Fire(voter3, "MapaQueNoExiste") -- voto invalido: se ignora
	CastVote.OnServerEvent:Fire(voter1, 42) -- tipo invalido: se ignora
	return 0
end
local winner = VoteService.Run(picked, 15)
task.wait = originalWait
check(winner == picked[2], "gano " .. tostring(winner) .. " y deberia ganar " .. picked[2])

-- empate sin votos: devuelve alguna de las opciones
local w2 = VoteService.Run(picked, 15)
check(seen[w2], "sin votos deberia elegir una de las opciones")

-- ===== Bucle de rondas completo (RoundLoop): una vuelta y paramos =====
do
	Config.RoundTime = 0
	local players = {}
	for i = 1, 2 do
		local pl = NewInstance("Player")
		pl.Parent = ReplicatedStorage
		local char = NewInstance("Model")
		local root = NewInstance("Part")
		root.Name = "HumanoidRootPart"
		root.Position = Vector3.new(0, 5, 0)
		root.Parent = char
		char.PrimaryPart = root
		local hum = NewInstance("Humanoid")
		hum.Health = 100
		hum.Parent = char
		pl.Character = char
		players[i] = pl
	end
	FAKE_PLAYERS = players

	local unloads, loads, teleports = 0, 0, 0
	local origUnload, origLoad, origTp = MapService.Unload, MapService.Load, MapService.TeleportToMap
	MapService.Unload = function(...)
		unloads = unloads + 1
		origUnload(...)
		if unloads >= 3 then error("STOP_TEST", 0) end -- 1: al cargar, 2: fin de ronda, 3: siguiente vuelta
	end
	MapService.Load = function(...) loads = loads + 1 return origLoad(...) end
	MapService.TeleportToMap = function(...) teleports = teleports + 1 return origTp(...) end

	local ok, err = pcall(function() require(roundLoopNode) end)
	check(not ok and tostring(err):find("STOP_TEST"), "RoundLoop no completo una vuelta: " .. tostring(err))
	check(loads >= 1 and teleports >= 1, "RoundLoop deberia cargar y teletransportar")
	print("RoundLoop: " .. loads .. " carga(s), " .. teleports .. " teletransporte(s)")
	MapService.Unload, MapService.Load, MapService.TeleportToMap = origUnload, origLoad, origTp
end

print(failures == 0 and "TODO OK" or ("FALLOS: " .. failures))
