-- INSTALADOR de Islas de Desastres.
-- Crea (o reemplaza) estas carpetas: ReplicatedStorage.IslasShared, ServerStorage.IslasMapas,
-- ServerScriptService.IslasServer y StarterPlayer.StarterPlayerScripts.IslasClient.
-- No toca nada mas de tu juego.
-- PARTE 2 DE 5. Pega las partes en la Barra de comandos EN ORDEN (1, 2, 3...).

local services = {
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerStorage = game:GetService("ServerStorage"),
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"),
}

local function folderAt(service, path)
	local parent = services[service]
	for _, name in ipairs(path) do
		local f = parent:FindFirstChild(name)
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = parent
		end
		parent = f
	end
	return parent
end

local function add(service, path, name, className, source)
	local parent = folderAt(service, path)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Source = source
	inst.Parent = parent
end

add("ServerStorage", { "IslasMapas", "Builders" }, "SkiResort", "ModuleScript", [[
-- Estacion de esqui: montana nevada por terrazas, pistas, refugio de madera de 2 plantas en la base,
-- torre del funicular con ascensor hasta la cima, cabanas, telesilla decorativo y muchos abetos.
local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Buildings = require(Lib.Buildings)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local SkiResort = {
	Title = "Estacion de esqui",
	Description = "Montana nevada con refugio, cabanas y una torre-ascensor que sube hasta la cima.",
	Lighting = { ClockTime = 11, Brightness = 2.4, OutdoorAmbient = C(170, 180, 200) },
	Bounds = { x1 = -150, x2 = 150, z1 = -150, z2 = 150, top = 120, floor = 0 },
	Disasters = { "Blizzard", "Earthquake", "Lightning", "Meteors", "Tornado", "Fire", "Volcano", "UFO", "AcidRain", "Virus" },
}

local SNOW = C(245, 248, 255)
local ICE = C(190, 220, 245)

function SkiResort.Build(b)
	b:Box("Isla", V(330, 10, 330), V(0, -5.5, 0), SNOW, M.Snow, { indestructible = true })
	b:Sea(-6, 2048, C(40, 80, 120))

	-- montana por terrazas (lado norte)
	local mountain = b:Group("Montana")
	local terraces = { { 200, 16, -60 }, { 160, 14, -75 }, { 120, 14, -88 }, { 80, 14, -100 }, { 46, 12, -110 } }
	local y = 0
	for i, t in ipairs(terraces) do
		local w, h, cz = t[1], t[2], t[3]
		mountain:Box("Terraza", V(w, h, w * 0.6), V(0, y + h / 2, cz), SNOW, M.Snow, { indestructible = true })
		-- rampa de pista para subir andando
		mountain:Wedge("Pista", V(14, h, 24), V(-w / 2 + 14 + i * 4, y + h / 2, cz + w * 0.3 + 12), ICE, M.Ice, 180, { indestructible = true })
		y = y + h
	end
	local summit = y
	mountain:Box("Cima", V(30, 1, 20), V(0, summit + 0.5, -110), C(120, 110, 100), M.Rock, { indestructible = true })
	mountain:Board("CartelCima", "CIMA · 3.000 m", V(14, 3, 0.4), V(0, summit + 5, -100.4), C(40, 60, 100), Colors.White)

	-- torre del funicular: ascensor desde la base hasta la cima
	local liftTower = b:Group("Funicular")
	local lift = { name = "AscensorCima", x = 110, z = -40, floors = { 0, 30, summit }, labels = { "Base", "Medio", "Cima" }, wallColor = C(200, 60, 50), wallMaterial = M.Metal }
	Elevator.build(liftTower, lift)
	liftTower:Slab("PlataformaMedio", 103, 117, -33.9, -26, 30, 1.2, Colors.DarkMetal, M.DiamondPlate)
	liftTower:Wall("Barandilla", "x", -26, 103, 117, 30, 33.5, 0.3, Colors.Glass, M.Glass, {})
	-- pasarela desde lo alto de la torre hasta la cima
	liftTower:Slab("Pasarela", 103, 117, -33.9, -22, summit, 1.2, Colors.DarkMetal, M.DiamondPlate)
	liftTower:Box("PuenteCima", V(100, 1.2, 6), V(60, summit - 0.6, -25), Colors.DarkMetal, M.DiamondPlate)
	liftTower:Box("PuenteCima2", V(6, 1.2, 72), V(10, summit - 0.6, -61), Colors.DarkMetal, M.DiamondPlate)
	liftTower:Board("CartelFunicular", "FUNICULAR", V(12, 3, 0.4), V(110, 12, -33.6), C(200, 60, 50), Colors.White)

	-- refugio de madera (2 plantas) en la base
	Buildings.House(b, -40, 40, 34, 26, 2, { name = "Refugio", color = C(150, 100, 60), material = M.WoodPlanks, roofColor = SNOW })
	b:Board("CartelRefugio", "REFUGIO", V(14, 3, 0.4), V(-40, 9, 53.6), C(80, 50, 30), C(255, 230, 180))
	local fire = b:Box("Hoguera", V(4, 1, 4), V(-40, 1, 65), C(90, 60, 40), M.Wood)
	local f = Instance.new("Fire")
	f.Size = 6
	f.Parent = fire
	Util.AddLight(fire, 20, 2, C(255, 170, 80))

	-- cabanas
	for i, p in ipairs({ { 30, 60 }, { 60, 70 }, { 100, 40 }, { -100, 60 } }) do
		Buildings.House(b, p[1], p[2], 16, 14, 1, { name = "Cabana" .. i, color = C(130, 85, 50), material = M.WoodPlanks, roofColor = SNOW })
	end

	-- telesilla decorativo con postes
	for i = 0, 4 do
		local z = 30 - i * 30
		local py = math.max(0, -z * 0.6)
		b:Pillar("PosteTelesilla", -90, z, 0, 25 + py, 1.2, Colors.DarkMetal, M.Metal)
		b:Box("Silla", V(4, 0.6, 2), V(-90, 20 + py, z), Colors.Red, M.Metal)
	end
	b:Box("Cable", V(0.3, 0.3, 130), V(-90, 26 + 30, -35), Colors.DarkMetal, M.Metal, { rot = V(-15, 0, 0), canCollide = false })

	-- bosque de abetos
	local forest = b:Group("Bosque")
	for i = 0, 34 do
		local a = i * 2.39996
		local r = 70 + (i % 7) * 10
		local x, z = math.cos(a) * r, math.sin(a) * r * 0.9 + 30
		if z > -20 then
			forest:Pine(x, z, 0, 1.3 + (i % 3) * 0.3)
		end
	end
	-- muneco de nieve
	b:Ball("MunecoBase", 5, V(10, 2.5, 30), SNOW, M.Snow)
	b:Ball("MunecoCuerpo", 3.6, V(10, 6.3, 30), SNOW, M.Snow)
	b:Ball("MunecoCabeza", 2.6, V(10, 9, 30), SNOW, M.Snow)

	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-10 + ix * 12, 1, 70 + iz * 12))
		end
	end
end

return SkiResort
]])

add("ServerStorage", { "IslasMapas", "Builders" }, "Skyscraper", "ModuleScript", [[
-- Rascacielos "Torre Cumbre": 12 plantas + azotea con helipuerto y piscina.
-- 3 ascensores en el nucleo central (13 paradas), escalera de emergencia en zigzag y vestibulo.

local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors
local windows = Util.Windows

local Skyscraper = {
	Title = "Rascacielos",
	Description = "Torre de 12 plantas con 3 ascensores, escalera de emergencia, helipuerto y piscina en la azotea.",
	Lighting = { ClockTime = 17.5, Brightness = 2, OutdoorAmbient = C(120, 110, 130) },
	Bounds = { x1 = -60, x2 = 60, z1 = -60, z2 = 100, top = 190, floor = 0 },
	Disasters = { "Earthquake", "Fire", "Lightning", "AcidRain", "Tornado", "Lava", "UFO", "Meteors", "Blizzard" },
	DisasterConfig = { Lava = { maxHeight = 112 } },
}

local STORY = 14
local LEVELS = 13 -- 12 plantas + azotea

function Skyscraper.Build(b)
	b:Box("Isla", V(300, 10, 300), V(0, -5.5, 0), Colors.Grass, M.Grass)
	b:Sea(-6)

	local tower = b:Group("Torre")
	local x1, x2, z1, z2 = -30, 30, -30, 30
	local lvl, labels = {}, {}
	for i = 1, LEVELS do
		lvl[i] = (i - 1) * STORY
		labels[i] = (i == 1 and "PB") or (i == LEVELS and "R") or tostring(i - 1)
	end

	local elevs = {}
	for _, x in ipairs({ -15, 0, 15 }) do
		elevs[#elevs + 1] = { name = "Ascensor" .. (#elevs + 1), x = x, z = -24, floors = lvl, labels = labels, wallColor = C(70, 74, 88) }
	end
	local elevHoles = {}
	for _, e in ipairs(elevs) do
		elevHoles[#elevHoles + 1] = Elevator.hole(e)
	end

	-- Escalera de emergencia en zigzag (vuelo i sube del nivel i al i+1)
	local function stairHole(i)
		if i % 2 == 1 then
			return { 8, 26, 12, 20 }
		end
		return { 8, 26, 20, 28 }
	end

	-- Forjados
	for i = 1, LEVELS do
		local holes = {}
		for _, h in ipairs(elevHoles) do
			holes[#holes + 1] = h
		end
		if i > 1 then
			holes[#holes + 1] = stairHole(i - 1)
		end
		local th = (i == 1) and 0.5 or 1.5
		tower:Slab("Planta" .. (i - 1), x1, x2, z1, z2, lvl[i], th, i == 1 and C(235, 230, 220) or C(225, 222, 215), M.Marble, holes)
	end

	-- Muros con cristaleras por planta
	for i = 1, LEVELS - 1 do
		local y, top = lvl[i], lvl[i] + STORY
		local front = windows(x1 + 2, x2 - 2, 12, 10, 2, 12)
		if i == 1 then
			front = windows(x1 + 2, x2 - 2, 12, 10, 3, 12, -8, 8)
			front[#front + 1] = { from = -8, to = 8, bottom = 0, top = 11 }
		end
		tower:Wall("FachadaSur" .. i, "x", z2, x1, x2, y, top, 1, C(60, 64, 78), M.Concrete, front)
		tower:Wall("FachadaNorte" .. i, "x", z1, x1, x2, y, top, 1, C(60, 64, 78), M.Concrete)
		tower:Wall("FachadaOeste" .. i, "z", x1, z1, z2, y, top, 1, C(60, 64, 78), M.Concrete, windows(z1 + 2, z2 - 2, 12, 10, 2, 12))
		tower:Wall("FachadaEste" .. i, "z", x2, z1, z2, y, top, 1, C(60, 64, 78), M.Concrete, windows(z1 + 2, z2 - 2, 12, 10, 2, 12))
	end
	-- pilares de esquina
	for _, p in ipairs({ { x1, z1 }, { x1, z2 }, { x2, z1 }, { x2, z2 } }) do
		tower:Chunked("PilarEsquina", V(2.4, STORY * (LEVELS - 1), 2.4), V(p[1], STORY * (LEVELS - 1) / 2, p[2]), Colors.DarkMetal, M.Metal)
	end

	for _, e in ipairs(elevs) do
		Elevator.build(tower, e)
	end

	-- Escaleras de emergencia
	for i = 1, LEVELS - 1 do
		if i % 2 == 1 then
			tower:Stairs("Escalera" .. i, 8, 16, lvl[i], lvl[i + 1], 8, 18, "+x", C(190, 190, 195), M.Concrete)
		else
			tower:Stairs("Escalera" .. i, 26, 24, lvl[i], lvl[i + 1], 8, 18, "-x", C(190, 190, 195), M.Concrete)
		end
	end

	-- Mobiliario por planta
	local rooms = tower:Group("Plantas")
	for i = 2, LEVELS - 1 do
		local y = lvl[i]
		local g = rooms:Group("Planta" .. (i - 1))
		-- dos "habitaciones": cama + mesita + sofa
		for k, x in ipairs({ -22, -6 }) do
			g:Box("Cama", V(6, 1.6, 8), V(x, y + 0.8, 8 + (k - 1) * 4), C(240, 240, 250), M.Fabric)
			g:Box("Almohada", V(4.5, 0.6, 1.6), V(x, y + 1.9, 8 + (k - 1) * 4 - 3), C(250, 250, 255), M.Fabric)
			g:Box("Mesita", V(2, 2, 2), V(x + 5, y + 1, 4 + (k - 1) * 4), Colors.Wood, M.Wood)
		end
		g:Box("Sofa", V(8, 1.6, 3), V(-14, y + 0.8, 24), Colors.Red, M.Fabric)
		g:Box("RespaldoSofa", V(8, 2.4, 0.8), V(-14, y + 1.8, 25.4), Colors.Red, M.Fabric)
		g:Pillar("Maceta", -26, 26, y, y + 2, 2.8, Colors.Wood, M.Wood)
		g:Ball("Planta", 4, V(-26, y + 4.4, 26), Colors.Green, M.Grass)
		g:Board("Numero", "PLANTA " .. (i - 1), V(14, 3, 0.4), V(0, y + 9, 29.3), Colors.DarkMetal, C(255, 220, 90), Enum.NormalId.Front)
	end
	-- la planta 12 es el Sky Lounge
	local lounge = rooms:Group("SkyLounge")
	local ly = lvl[LEVELS - 1]
	lounge:Box("Barra", V(24, 4, 3), V(-12, ly + 2, 10), Colors.Wood, M.Wood)
	lounge:Board("CartelBar", "SKY BAR", V(10, 2.4, 0.4), V(-12, ly + 6.5, 11.7), Colors.DarkMetal, C(255, 190, 60))
	for k = 0, 3 do
		lounge:Pillar("Mesa", -20 + k * 8, 22, ly, ly + 3.5, 0.8, Colors.DarkMetal, M.Metal)
		lounge:Pillar("MesaTop", -20 + k * 8, 22, ly + 3.5, ly + 4, 5, C(250, 250, 250), M.Marble)
	end

	-- Vestibulo (planta baja)
	local lobby = tower:Group("Vestibulo")
	lobby:Box("Recepcion", V(16, 4, 3), V(18, 2, 4), Colors.Wood, M.Wood)
	lobby:Board("CartelRecepcion", "RECEPCION", V(14, 2.4, 0.4), V(18, 6.3, 5.8), Colors.DarkMetal, C(255, 255, 255))
	lobby:Board("CartelTorre", "TORRE CUMBRE", V(40, 5, 0.6), V(0, 20, z2 + 0.8), Colors.DarkMetal, C(255, 220, 90))
	for _, p in ipairs({ { -26, 20 }, { 26, -6 } }) do
		lobby:Pillar("Maceta", p[1], p[2], 0, 2, 3, Colors.Wood, M.Wood)
		lobby:Ball("Planta", 5, V(p[1], 4.6, p[2]), Colors.Green, M.Grass)
	end

	-- Azotea
	local roof = b:Group("Azotea")
	local ry = lvl[LEVELS]
	for _, w in ipairs({
		{ "x", z2, x1, x2 }, { "x", z1, x1, x2 }, { "z", x1, z1, z2 }, { "z", x2, z1, z2 },
	}) do
		roof:Wall("Barandilla", w[1], w[2], w[3], w[4], ry, ry + 4, 0.4, Colors.Glass, M.Glass, {})
	end
	-- helipuerto
	roof:Pillar("Helipuerto", -14, 12, ry, ry + 0.8, 22, C(70, 70, 75), M.Concrete)
	roof:Pillar("AroHelipuerto", -14, 12, ry + 0.8, ry + 0.9, 18, Colors.Yellow, M.SmoothPlastic)
	roof:Pillar("CentroHelipuerto", -14, 12, ry + 0.9, ry + 1.0, 15, C(70, 70, 75), M.Concrete)
	roof:Board("H", "H", V(8, 0.2, 8), V(-14, ry + 1.1, 12), C(70, 70, 75), C(255, 255, 255), Enum.NormalId.Top)
	-- piscina
	roof:Box("BordePiscina", V(22, 1.6, 14), V(14, ry + 0.8, -6), Colors.Concrete, M.Concrete)
	roof:Box("Agua", V(20, 0.2, 12), V(14, ry + 1.7, -6), Colors.Water, M.SmoothPlastic, { transparency = 0.35, canCollide = false })
	for k = 0, 2 do
		roof:Box("Tumbona", V(2.4, 1, 6), V(-24 + k * 5, ry + 0.5, -2), Colors.White, M.Fabric)
	end
	-- antena y luz
	roof:Pillar("Antena", 24, -24, ry, ry + 26, 1.2, Colors.Red, M.Metal)
	roof:Ball("LuzAntena", 2.4, V(24, ry + 27, -24), Colors.Red, M.Neon)

	-- Plaza y entorno
	local plaza = b:Group("Plaza")
	plaza:Box("Plaza", V(120, 0.5, 70), V(0, -0.25, 62), C(200, 198, 192), M.Concrete)
	plaza:Pillar("Fuente", 0, 55, 0, 1.2, 14, Colors.Concrete, M.Marble)
	plaza:Pillar("AguaFuente", 0, 55, 1.2, 1.5, 11, Colors.Water, M.SmoothPlastic)
	for i = 0, 6 do
		plaza:Pine(-100 + i * 33, 120, 0, 1.3)
		plaza:Pine(-100 + i * 33, -120, 0, 1.3)
	end
	for _, x in ipairs({ -60, -40, 40, 60 }) do
		plaza:Box("Banco", V(7, 1.2, 2), V(x, 0.6, 70), Colors.Wood, M.Wood)
	end

	-- aparicion en la plaza
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-40 + ix * 26, 1, 40 + iz * 16))
		end
	end
end

return Skyscraper
]])

add("ServerStorage", { "IslasMapas", "Builders" }, "SpaceStation", "ModuleScript", [[
-- Estacion espacial: nucleo de 4 plantas con 2 ascensores, cuatro brazos con modulos (laboratorio, invernadero,
-- reactor, hangar con lanzadera), paneles solares y planeta al fondo. Gravedad reducida.
-- Si te sales de la estacion, caes al vacio y mueres.

local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors
local windows = Util.Windows

local SpaceStation = {
	Title = "Estacion Espacial",
	Description = "Nucleo de 4 plantas con ascensores, brazos con laboratorio, invernadero y hangar. Gravedad baja.",
	Lighting = { ClockTime = 0, Brightness = 1, Ambient = C(60, 65, 90), OutdoorAmbient = C(40, 45, 70) },
	Bounds = { x1 = -130, x2 = 130, z1 = -130, z2 = 130, top = 110, floor = 0 },
	Disasters = { "Meteors", "Fire", "Earthquake", "Radiation", "BlackHole", "UFO", "Virus" },
	Gravity = 70,
}

local HULL = C(215, 220, 228)
local DARK = C(55, 58, 70)
local STORY = 20

-- pasillo (brazo) a lo largo de un eje, a nivel de la planta 1
local function corridor(g, axis, sign, from, to)
	-- axis "x": sale hacia +-X. from/to son distancias (>0) desde el centro
	local len = to - from
	local mid = sign * (from + to) / 2
	local w = 12
	local function pos(a, b, y) -- a = coordenada a lo largo del brazo, b = lateral
		if axis == "x" then return V(a, y, b) end
		return V(b, y, a)
	end
	local function size(along, lateral, h)
		if axis == "x" then return V(along, h, lateral) end
		return V(lateral, h, along)
	end
	g:Box("SueloBrazo", size(len, w, 1), pos(mid, 0, -0.5), DARK, M.DiamondPlate)
	g:Box("TechoBrazo", size(len, w + 2, 1), pos(mid, 0, 12.5), HULL, M.Metal)
	for _, side in ipairs({ -1, 1 }) do
		-- paredes laterales con ventanas
		local a1, a2 = sign * from, sign * to
		if a1 > a2 then a1, a2 = a2, a1 end
		g:Wall("ParedBrazo", axis, side * (w / 2), a1, a2, 0, 12, 0.8, HULL, M.Metal, windows(a1 + 1, a2 - 1, 9, 5, 3, 9))
	end
	for k = 1, math.floor(len / 14) do
		local a = sign * (from + k * 14 - 7)
		g:Box("Luz", size(2, 8, 0.2), pos(a, 0, 11.8), C(255, 250, 230), M.Neon, { canCollide = false })
	end
end

function SpaceStation.Build(b)
	b:KillPlane(-250)

	-- planeta y estrellas decorativas
	local sky = b:Group("Cielo")
	sky:Ball("Planeta", 900, V(900, -450, 700), C(40, 110, 190), M.SmoothPlastic).CanCollide = false
	sky:Ball("Atmosfera", 940, V(900, -450, 700), C(120, 180, 255), M.Neon).CanCollide = false
	sky:Ball("Luna", 120, V(-700, 260, -900), C(200, 200, 205), M.Slate).CanCollide = false

	local hub = b:Group("Nucleo")
	local x1, x2, z1, z2 = -30, 30, -30, 30
	local lvl = { 0, STORY, STORY * 2, STORY * 3 }

	local elevs = {}
	for _, x in ipairs({ -18, 18 }) do
		elevs[#elevs + 1] = { name = "Ascensor" .. (#elevs + 1), x = x, z = -22, floors = lvl, labels = { "1", "2", "3", "4" }, wallColor = DARK }
	end
	local holes = {}
	for _, e in ipairs(elevs) do
		holes[#holes + 1] = Elevator.hole(e)
	end
	-- escalera de la planta 1 a la 2 (y de la 2 a la 3, de la 3 a la 4) en la esquina este
	local stairHoles = { { 8, 26, 8, 16 }, { 8, 26, 16, 24 }, { 8, 26, 8, 16 } }

	hub:Slab("Planta1", x1, x2, z1, z2, 0, 1, DARK, M.DiamondPlate, holes)
	for i = 2, 4 do
		local hs = { holes[1], holes[2], stairHoles[i - 1] }
		hub:Slab("Planta" .. i, x1, x2, z1, z2, lvl[i], 1.5, i == 4 and C(40, 44, 60) or DARK, M.DiamondPlate, hs)
	end
	hub:Slab("Techo", x1 - 2, x2 + 2, z1 - 2, z2 + 2, STORY * 4 + 2, 2, HULL, M.Metal)

	-- muros del nucleo: ventanas grandes (vista al espacio); abiertos en los 4 brazos de la planta 1
	for i = 1, 4 do
		local y, top = lvl[i], lvl[i] + STORY
		local gap = (i == 1) and { { from = -6, to = 6, bottom = 0, top = 12 } } or {}
		local function band(a1, a2)
			local list = windows(a1 + 2, a2 - 2, 14, 11, 3, 16)
			for _, g in ipairs(gap) do
				-- quitar ventanas que choquen con el hueco del brazo
				for k = #list, 1, -1 do
					if list[k].to > g.from and list[k].from < g.to then
						table.remove(list, k)
					end
				end
				list[#list + 1] = g
			end
			return list
		end
		hub:Wall("MuroSur" .. i, "x", z2, x1, x2, y, top, 1, HULL, M.Metal, band(x1, x2))
		hub:Wall("MuroNorte" .. i, "x", z1, x1, x2, y, top, 1, HULL, M.Metal, i == 1 and { { from = -6, to = 6, bottom = 0, top = 12 } } or {})
		hub:Wall("MuroOeste" .. i, "z", x1, z1, z2, y, top, 1, HULL, M.Metal, band(z1, z2))
		hub:Wall("MuroEste" .. i, "z", x2, z1, z2, y, top, 1, HULL, M.Metal, band(z1, z2))
	end

	for _, e in ipairs(elevs) do
		Elevator.build(hub, e)
	end
	for i = 1, 3 do
		if i % 2 == 1 then
			hub:Stairs("Escalera" .. i, 8, 12, lvl[i], lvl[i + 1], 8, 18, "+x", C(190, 195, 205), M.Metal)
		else
			hub:Stairs("Escalera" .. i, 26, 20, lvl[i], lvl[i + 1], 8, 18, "-x", C(190, 195, 205), M.Metal)
		end
	end

	-- decoracion de cada planta del nucleo
	local decks = hub:Group("Plantas")
	-- 2: dormitorios
	for k = 0, 3 do
		decks:Box("Litera", V(4, 2, 9), V(-24 + k * 8, lvl[2] + 1.5, 22), C(70, 110, 190), M.Fabric)
		decks:Box("Taquilla", V(3, 8, 3), V(-24 + k * 8, lvl[2] + 4, 28), Colors.Metal, M.Metal)
	end
	decks:Board("Cartel2", "DORMITORIOS", V(16, 3, 0.4), V(-12, lvl[2] + 14, 29.3), DARK, C(120, 200, 255), Enum.NormalId.Front)
	-- 3: laboratorio
	for k = 0, 3 do
		decks:Box("Consola", V(6, 3, 2.5), V(-24 + k * 8, lvl[3] + 1.5, 26), DARK, M.Metal)
		decks:Box("Pantalla", V(5, 2.4, 0.2), V(-24 + k * 8, lvl[3] + 4.4, 24.9), C(70, 230, 160), M.Neon, { canCollide = false })
	end
	decks:Board("Cartel3", "LABORATORIO", V(16, 3, 0.4), V(-12, lvl[3] + 14, 29.3), DARK, C(120, 200, 255), Enum.NormalId.Front)
	-- 4: observatorio con telescopio
	decks:Pillar("PedestalTelescopio", -14, 14, lvl[4], lvl[4] + 4, 5, DARK, M.Metal)
	decks:Box("Telescopio", V(14, 3, 3), V(-14, lvl[4] + 6, 14), Colors.White, M.Metal, { shape = Enum.PartType.Cylinder, rot = V(0, 35, 28) })
	decks:Board("Cartel4", "OBSERVATORIO", V(16, 3, 0.4), V(-12, lvl[4] + 14, 29.3), DARK, C(120, 200, 255), Enum.NormalId.Front)

	-- brazos con modulos
	local arms = b:Group("Brazos")
	corridor(arms:Group("BrazoEste"), "x", 1, 30, 80)
	corridor(arms:Group("BrazoOeste"), "x", -1, 30, 80)
	corridor(arms:Group("BrazoSur"), "z", 1, 30, 80)
	corridor(arms:Group("BrazoNorte"), "z", -1, 30, 80)

	-- Modulo cuadrado de 40x40; `facing` es el lado que mira al nucleo (ahi se abre la puerta del pasillo).
	local function moduleOpen(name, cx, cz, color, facing)
		local g = arms:Group(name)
		local s = 40
		g:Slab("Suelo", cx - s / 2, cx + s / 2, cz - s / 2, cz + s / 2, 0, 1, DARK, M.DiamondPlate)
		g:Slab("Techo", cx - s / 2 - 1, cx + s / 2 + 1, cz - s / 2 - 1, cz + s / 2 + 1, 18, 1, HULL, M.Metal)
		local door = { from = -6, to = 6, bottom = 0, top = 12 }
		local function openings(a1, a2, center, isDoor)
			local list = windows(a1 + 1, a2 - 1, 10, 6, 4, 14, center - 7, center + 7)
			if isDoor then
				list[#list + 1] = { from = center - 6, to = center + 6, bottom = 0, top = 12 }
			end
			return list
		end
		g:Wall("MuroN", "x", cz - s / 2, cx - s / 2, cx + s / 2, 0, 18, 0.8, color, M.Metal, openings(cx - s / 2, cx + s / 2, cx, facing == "S"))
		g:Wall("MuroS", "x", cz + s / 2, cx - s / 2, cx + s / 2, 0, 18, 0.8, color, M.Metal, openings(cx - s / 2, cx + s / 2, cx, facing == "N"))
		g:Wall("MuroO", "z", cx - s / 2, cz - s / 2, cz + s / 2, 0, 18, 0.8, color, M.Metal, openings(cz - s / 2, cz + s / 2, cz, facing == "E"))
		g:Wall("MuroE", "z", cx + s / 2, cz - s / 2, cz + s / 2, 0, 18, 0.8, color, M.Metal, openings(cz - s / 2, cz + s / 2, cz, facing == "W"))
		return g
	end

	-- facing = lado del modulo que mira al nucleo
	local lab = moduleOpen("Laboratorio", 100, 0, C(205, 225, 240), "W")
	for k = 0, 3 do
		lab:Box("MesaLab", V(14, 3, 3), V(92 + (k % 2) * 16, 1.5, -10 + math.floor(k / 2) * 18), Colors.White, M.Metal)
		lab:Box("Matraz", V(1.4, 2, 1.4), V(92 + (k % 2) * 16, 4, -10 + math.floor(k / 2) * 18), C(120, 255, 170), M.Neon, { canCollide = false })
	end
	lab:Board("CartelLab", "LABORATORIO", V(16, 3, 0.4), V(100, 14, 19.3), DARK, C(120, 200, 255), Enum.NormalId.Front)

	local gh = moduleOpen("Invernadero", -100, 0, C(190, 235, 200), "E")
	for k = 0, 5 do
		local x, z = -112 + (k % 3) * 12, -10 + math.floor(k / 3) * 18
		gh:Box("Bancal", V(8, 1.4, 8), V(x, 0.7, z), C(90, 60, 40), M.Ground)
		gh:Ball("Arbusto", 6, V(x, 4.6, z), Colors.Green, M.Grass)
	end
	gh:Board("CartelInv", "INVERNADERO", V(16, 3, 0.4), V(-100, 14, 19.3), DARK, C(140, 255, 160), Enum.NormalId.Front)

	local rx = moduleOpen("Reactor", 0, 100, C(235, 200, 190), "N")
	rx:Pillar("Nucleo", 0, 100, 0, 15, 8, C(40, 40, 50), M.Metal)
	rx:Pillar("NucleoLuz", 0, 100, 1, 14, 5, C(255, 140, 60), M.Neon)
	for k = 0, 3 do
		local a = k * math.pi / 2
		rx:Pillar("Soporte", math.cos(a) * 12, 100 + math.sin(a) * 12, 0, 15, 2, DARK, M.Metal)
	end
	rx:Board("CartelReactor", "REACTOR", V(16, 3, 0.4), V(0, 14, 119.3), DARK, C(255, 150, 80), Enum.NormalId.Front)

	local hangar = moduleOpen("Hangar", 0, -100, C(200, 205, 215), "S")
	-- lanzadera
	local sh = hangar:At(V(0, 0, -102), "Lanzadera")
	sh:Box("Fuselaje", V(8, 6, 22), V(0, 5, 0), Colors.White, M.Metal)
	sh:Box("Morro", V(7, 5, 6), V(0, 5, 13), Colors.White, M.Metal, { rot = V(18, 0, 0) })
	sh:Box("Cristal", V(5, 2, 3), V(0, 7, 12), Colors.Glass, M.Glass, { transparency = 0.4 })
	sh:Box("AlaIzq", V(10, 0.6, 10), V(-9, 3.5, -2), Colors.Blue, M.Metal)
	sh:Box("AlaDer", V(10, 0.6, 10), V(9, 3.5, -2), Colors.Blue, M.Metal)
	sh:Box("Motor", V(5, 4, 4), V(0, 5, -12), DARK, M.Metal, { shape = Enum.PartType.Cylinder, rot = V(0, 90, 0) })
	sh:Box("Pata1", V(1, 3, 1), V(-3, 1.5, 6), DARK, M.Metal)
	sh:Box("Pata2", V(1, 3, 1), V(3, 1.5, 6), DARK, M.Metal)
	sh:Box("Pata3", V(1, 3, 1), V(0, 1.5, -8), DARK, M.Metal)
	hangar:Board("CartelHangar", "HANGAR", V(16, 3, 0.4), V(0, 14, -80.7), DARK, C(255, 220, 90), Enum.NormalId.Back)

	-- paneles solares sobre los brazos de este y oeste
	local solar = b:Group("PanelesSolares")
	for _, sx in ipairs({ -1, 1 }) do
		solar:Box("MastilSolar", V(2, 2, 80), V(sx * 55, 20, 0), DARK, M.Metal)
		for k = 0, 2 do
			solar:Box("PanelSolar", V(18, 0.6, 30), V(sx * (40 + k * 20), 20, 36), C(35, 70, 150), M.Glass, { reflectance = 0.2 })
			solar:Box("PanelSolar", V(18, 0.6, 30), V(sx * (40 + k * 20), 20, -36), C(35, 70, 150), M.Glass, { reflectance = 0.2 })
		end
		solar:Box("PuntalSolar", V(2, 7, 2), V(sx * 55, 16.5, 0), DARK, M.Metal)
	end
	-- antena parabolica sobre el nucleo
	local dish = b:Group("Antena")
	dish:Pillar("Soporte", 20, 20, STORY * 4 + 2, STORY * 4 + 14, 2, DARK, M.Metal)
	dish:Box("Plato", V(2, 14, 14), V(20, STORY * 4 + 17, 20), Colors.White, M.Metal, { shape = Enum.PartType.Cylinder, rot = V(0, 0, 40) })
	dish:Ball("LuzAntena", 2, V(20, STORY * 4 + 24, 20), Colors.Red, M.Neon)

	-- puntos de aparicion: planta 1 del nucleo
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-12 + ix * 8, 1, -2 + iz * 8))
		end
	end
end

return SpaceStation
]])

add("ServerStorage", { "IslasMapas", "Builders" }, "TropicalIsland", "ModuleScript", [[
-- Isla tropical: playa con palmeras, cabanas de madera, chiringuito, muelle con barca, barco pirata
-- encallado, montana con cascada y un faro con ascensor y luz giratoria.
local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local Buildings = require(Lib.Buildings)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local TropicalIsland = {
	Title = "Isla tropical",
	Description = "Playa con cabanas, barco pirata encallado, montana con cascada y un faro con ascensor.",
	Lighting = { ClockTime = 14.5, Brightness = 2.5, OutdoorAmbient = C(160, 150, 130) },
	Bounds = { x1 = -150, x2 = 150, z1 = -150, z2 = 150, top = 110, floor = 0 },
	Disasters = { "Tsunami", "Volcano", "Flood", "Lightning", "Tornado", "Meteors", "Fire", "Sandstorm", "AcidRain", "UFO" },
	DisasterConfig = { Flood = { maxHeight = 22 } },
}

local SAND = C(235, 215, 160)
local STRAW = C(200, 170, 90)

function TropicalIsland.Build(b)
	b:Pillar("Isla", 0, 0, -10, 0, 320, SAND, M.Sand)
	b:Pillar("Hierba", 0, 0, -9.6, 0.3, 230, C(100, 170, 70), M.Grass)
	b:Sea(-4, 2048, C(30, 170, 190), 0.25)
	-- no se rompen
	for _, d in ipairs(b.parent:GetChildren()) do
		if d.Name == "Isla" or d.Name == "Hierba" then
			d:SetAttribute("Indestructible", true)
		end
	end

	-- montana central con cascada
	local mountain = b:Group("Montana")
	for i, d in ipairs({ 90, 70, 52, 36 }) do
		local y1 = (i - 1) * 10
		mountain:Pillar("Roca", -30, -20, y1, y1 + 10.3, d, i == 4 and C(90, 140, 70) or C(120, 110, 95), i == 4 and M.Grass or M.Rock)
	end
	mountain:Box("Cascada", V(6, 30, 1), V(-30, 15, 5.5), C(120, 200, 255), M.Neon, { transparency = 0.35, canCollide = false })
	mountain:Pillar("Laguna", -30, 18, 0.3, 0.6, 20, C(60, 160, 220), M.SmoothPlastic)
	-- escalera tallada para subir
	mountain:Stairs("Sendero", -2, -20, 0, 40, 6, 46, "-x", C(140, 120, 95), M.Rock)

	-- faro con ascensor y luz giratoria
	local light = b:Group("Faro")
	local fx, fz = 100, -90
	local lift = { name = "AscensorFaro", x = fx, z = fz, floors = { 0, 30, 60 }, labels = { "PB", "30", "Luz" }, wallColor = C(240, 240, 240), wallMaterial = M.SmoothPlastic }
	Elevator.build(light, lift)
	light:Box("FranjaRoja", V(13.4, 6, 12.4), V(fx, 24, fz), C(210, 50, 50), M.SmoothPlastic)
	light:Box("FranjaRoja", V(13.4, 6, 12.4), V(fx, 48, fz), C(210, 50, 50), M.SmoothPlastic)
	for _, y in ipairs({ 30, 60 }) do
		light:Slab("Balcon", fx - 10, fx + 10, fz + 6.1, fz + 15, y, 1.2, Colors.DarkMetal, M.DiamondPlate)
		light:Wall("Barandilla", "x", fz + 15, fx - 10, fx + 10, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
		light:Wall("Barandilla", "z", fx - 10, fz + 6.1, fz + 15, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
		light:Wall("Barandilla", "z", fx + 10, fz + 6.1, fz + 15, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
	end
	local beam = b:Group("LuzFaro", "Model")
	beam:Ball("Lampara", 5, V(fx, 78, fz), C(255, 245, 180), M.Neon)
	beam:Box("Haz", V(40, 2, 2), V(fx + 20, 78, fz), C(255, 245, 180), M.Neon, { transparency = 0.6, canCollide = false })
	beam:Box("Haz", V(40, 2, 2), V(fx - 20, 78, fz), C(255, 245, 180), M.Neon, { transparency = 0.6, canCollide = false })
	b:Spin(beam.parent, 8, "Y")
	light:Pillar("Linterna", fx, fz, 75, 81, 10, Colors.Glass, M.Glass)

	-- cabanas de playa (madera con tejado de paja: arden)
	for i, p in ipairs({ { 60, 70 }, { 85, 40 }, { 30, 95 }, { -10, 100 }, { -60, 80 } }) do
		Buildings.House(b, p[1], p[2], 14, 12, 1, { name = "Cabana" .. i, color = C(160, 110, 70), material = M.WoodPlanks, roofColor = STRAW })
	end
	-- chiringuito
	local bar = b:Group("Chiringuito")
	bar:Box("Barra", V(14, 4, 4), V(-90, 2, 20), C(140, 95, 60), M.Wood)
	bar:Box("TejadoPaja", V(18, 1, 12), V(-90, 10, 22), STRAW, M.Grass)
	for _, s in ipairs({ { -98, 16 }, { -82, 16 }, { -98, 28 }, { -82, 28 } }) do
		bar:Pillar("Poste", s[1], s[2], 0, 10, 0.8, C(140, 95, 60), M.Wood)
	end
	bar:Board("CartelBar", "TIKI BAR", V(10, 2.4, 0.4), V(-90, 8, 16), C(255, 140, 60), Colors.White)
	-- hoguera
	local fire = b:Box("Hoguera", V(4, 1, 4), V(-70, 0.8, 45), C(90, 60, 40), M.Wood)
	local f = Instance.new("Fire")
	f.Size = 6
	f.Parent = fire

	-- muelle y barca
	local pier = b:Group("Muelle")
	pier:Box("Pasarela", V(8, 1, 60), V(-20, 1, 175), C(150, 110, 70), M.WoodPlanks)
	for k = 0, 5 do
		pier:Pillar("Pilote", -24, 150 + k * 10, -8, 1, 1, C(120, 85, 55), M.Wood)
		pier:Pillar("Pilote", -16, 150 + k * 10, -8, 1, 1, C(120, 85, 55), M.Wood)
	end
	pier:Box("Barca", V(6, 2.4, 14), V(-8, 0.6, 190), C(220, 80, 60), M.Wood)

	-- barco pirata encallado (inclinado)
	local wreck = b:At(V(110, 0, 90), "BarcoPirata")
	wreck:Box("Casco", V(40, 10, 14), V(0, 3, 0), C(110, 75, 45), M.WoodPlanks, { rot = V(8, 25, 0) })
	wreck:Box("Cubierta", V(38, 1, 12), V(0, 8.5, 0), C(140, 100, 60), M.WoodPlanks, { rot = V(8, 25, 0) })
	wreck:Box("Mastil", V(1.4, 30, 1.4), V(0, 23, 0), C(100, 70, 40), M.Wood, { rot = V(8, 25, 0) })
	wreck:Box("Vela", V(14, 12, 0.4), V(0, 24, 1), C(235, 230, 215), M.Fabric, { rot = V(8, 25, 0) })
	wreck:Box("Cofre", V(4, 3, 3), V(-6, 10.5, 0), C(200, 160, 40), M.Wood)

	-- palmeras
	local palms = b:Group("Palmeras")
	for i = 0, 27 do
		local a = i * 2.39996
		local r = 60 + (i % 5) * 18
		local x, z = math.cos(a) * r, math.sin(a) * r
		if math.abs(x - fx) > 20 or math.abs(z - fz) > 20 then
			Buildings.Palm(palms, x, z, 0, 0.9 + (i % 3) * 0.2)
		end
	end
	-- hamacas
	for k = 0, 2 do
		b:Box("Hamaca", V(2, 0.4, 7), V(40 + k * 8, 2, 120), C(255, 100 + k * 50, 80), M.Fabric)
	end

	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(20 + ix * 12, 1, 30 + iz * 12))
		end
	end
end

return TropicalIsland
]])

add("ServerStorage", { "IslasMapas", "Lib" }, "Buildings", "ModuleScript", [[
-- Buildings: piezas grandes reutilizables para los mapas (casas, torres con ascensor, arboles, coches...).
-- Todas las medidas son relativas al origen del builder; el suelo del mapa esta en y = 0.
local Util = require(script.Parent.Util)
local Elevator = require(script.Parent.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors
local windows = Util.Windows

local Buildings = {}

local FURNITURE_COLORS = { C(200, 70, 70), C(70, 110, 200), C(90, 160, 90), C(200, 170, 80), C(150, 90, 170) }

-- Muebles sencillos en una planta (madera y tela: arden)
function Buildings.Furnish(b, x1, x2, z1, z2, y, seed)
	local r = Random.new(seed or 1)
	local w, d = x2 - x1, z2 - z1
	if w < 10 or d < 10 then
		return
	end
	local col = FURNITURE_COLORS[r:NextInteger(1, #FURNITURE_COLORS)]
	local tx, tz = x1 + w * 0.35, z1 + d * 0.55
	b:Box("Mesa", V(4, 0.4, 3), V(tx, y + 3, tz), Colors.Wood, M.Wood)
	b:Box("PataMesa", V(0.5, 3, 0.5), V(tx, y + 1.5, tz), Colors.Wood, M.Wood)
	for _, o in ipairs({ -2.6, 2.6 }) do
		b:Box("Silla", V(1.5, 1.6, 1.5), V(tx + o, y + 0.8, tz), col, M.Fabric)
	end
	if r:NextNumber() < 0.6 then
		b:Box("Sofa", V(6, 1.6, 2.6), V(x1 + w * 0.7, y + 0.8, z1 + 2.5), col, M.Fabric)
		b:Box("RespaldoSofa", V(6, 2.2, 0.8), V(x1 + w * 0.7, y + 1.9, z1 + 1.6), col, M.Fabric)
	else
		b:Box("Cama", V(5, 1.4, 7), V(x1 + w * 0.72, y + 0.7, z1 + 4.5), C(240, 240, 245), M.Fabric)
	end
	b:Box("Estanteria", V(4, 6, 1.2), V(x2 - 3, y + 3, z2 - 1.6), Colors.Wood, M.Wood)
end

-- Casa de 1-3 plantas con puerta delante (+Z), ventanas, escalera interior y tejado.
-- opts: color, roofColor, story (12), roof ("pitched"/"flat"), furnish (true), material
function Buildings.House(b, cx, cz, w, d, floors, opts)
	opts = opts or {}
	local story = opts.story or 12
	local color = opts.color or C(230, 220, 200)
	local mat = opts.material or M.SmoothPlastic
	local x1, x2, z1, z2 = cx - w / 2, cx + w / 2, cz - d / 2, cz + d / 2
	local g = b:Group(opts.name or "Casa")
	local stairLen = story * 1.3
	local stairHole = { x1 + 1.5, x1 + 1.5 + stairLen, z1 + 1, z1 + 5 }
	for i = 0, floors - 1 do
		local y = i * story
		local holes = (i > 0) and { stairHole } or nil
		g:Slab("Suelo", x1, x2, z1, z2, y + (i == 0 and 0.4 or 0), i == 0 and 0.4 or 1, i == 0 and C(150, 110, 80) or C(170, 130, 95), M.WoodPlanks, holes)
		local front = windows(x1 + 1, x2 - 1, 8, 4, 4, 9, i == 0 and cx - 3 or nil, i == 0 and cx + 3 or nil)
		if i == 0 then
			front[#front + 1] = { from = cx - 2.5, to = cx + 2.5, bottom = 0, top = 8 }
		end
		g:Wall("Pared", "x", z2, x1, x2, y, y + story, 0.8, color, mat, front)
		g:Wall("Pared", "x", z1, x1, x2, y, y + story, 0.8, color, mat, windows(x1 + 1, x2 - 1, 8, 4, 4, 9))
		g:Wall("Pared", "z", x1, z1, z2, y, y + story, 0.8, color, mat, windows(z1 + 1, z2 - 1, 8, 4, 4, 9))
		g:Wall("Pared", "z", x2, z1, z2, y, y + story, 0.8, color, mat, windows(z1 + 1, z2 - 1, 8, 4, 4, 9))
		if i < floors - 1 then
			g:Stairs("Escalera", x1 + 1.5, z1 + 3, y, y + story, 4, stairLen, "+x", Colors.Wood, M.Wood)
		end
		if opts.furnish ~= false then
			Buildings.Furnish(g, x1 + 1, x2 - 1, z1 + 6, z2 - 1, y + (i == 0 and 0.4 or 0), math.floor(cx * 7 + cz * 13 + i))
		end
	end
	local top = floors * story
	local roofColor = opts.roofColor or C(170, 70, 50)
	if opts.roof == "flat" then
		g:Slab("Tejado", x1 - 0.5, x2 + 0.5, z1 - 0.5, z2 + 0.5, top + 1, 1, roofColor, M.Slate)
	else
		g:Slab("Techo", x1, x2, z1, z2, top + 0.6, 0.6, color, mat)
		local h = math.min(d, w) * 0.35
		-- dos aguas a lo largo de X
		g:Wedge("Tejado", V(w + 1, h, d / 2 + 0.5), V(cx, top + 0.6 + h / 2, z1 + d / 4 - 0.25), roofColor, M.Slate, 0)
		g:Wedge("Tejado", V(w + 1, h, d / 2 + 0.5), V(cx, top + 0.6 + h / 2, z2 - d / 4 + 0.25), roofColor, M.Slate, 180)
	end
	return g
end

-- Torre de varias plantas con ascensor (pared de atras) y escalera en zigzag (esquina delantera derecha).
-- Requiere w, d >= 30. Devuelve la lista de alturas de planta (incluida la azotea).
-- opts: color, glassColor, story (14), name, labels, furnish, wallColor (hueco del ascensor), roofRail (true)
function Buildings.Tower(b, cx, cz, w, d, floors, opts)
	opts = opts or {}
	local story = opts.story or 14
	local color = opts.color or C(200, 200, 205)
	local x1, x2, z1, z2 = cx - w / 2, cx + w / 2, cz - d / 2, cz + d / 2
	local g = b:Group(opts.name or "Torre")
	local levels, labels = {}, {}
	for i = 1, floors + 1 do
		levels[i] = (i - 1) * story
		labels[i] = (i == 1 and "PB") or (i == floors + 1 and "A") or tostring(i - 1)
	end
	local elev = { name = (opts.name or "Torre") .. "Ascensor", x = cx, z = z1 + 6.4, floors = levels, labels = opts.labels or labels, wallColor = opts.wallColor or C(90, 92, 100) }
	local hole = Elevator.hole(elev)
	local L = story * 1.25
	local sx2 = x2 - 3
	local sx1 = sx2 - L
	local function stairHole(i)
		if i % 2 == 1 then
			return { sx1, sx2, z2 - 10, z2 - 4 }
		end
		return { sx1, sx2, z2 - 16, z2 - 10 }
	end
	for i = 1, floors + 1 do
		local holes = { hole }
		if i > 1 then
			holes[#holes + 1] = stairHole(i - 1)
		end
		g:Slab("Planta", x1, x2, z1, z2, levels[i], i == 1 and 0.5 or 1.2, i == 1 and C(215, 210, 200) or C(205, 200, 195), M.Marble, holes)
	end
	for i = 1, floors do
		local y = levels[i]
		local front = windows(x1 + 1, x2 - 1, 10, 8, 2, story - 2)
		if i == 1 then
			front = windows(x1 + 1, x2 - 1, 10, 8, 2, story - 2, cx - 6, cx + 6)
			front[#front + 1] = { from = cx - 5, to = cx + 5, bottom = 0, top = 9 }
		end
		g:Wall("Fachada", "x", z2, x1, x2, y, y + story, 1, color, M.Concrete, front)
		g:Wall("Fachada", "x", z1, x1, x2, y, y + story, 1, color, M.Concrete)
		g:Wall("Fachada", "z", x1, z1, z2, y, y + story, 1, color, M.Concrete, windows(z1 + 1, z2 - 1, 10, 8, 2, story - 2))
		g:Wall("Fachada", "z", x2, z1, z2, y, y + story, 1, color, M.Concrete, windows(z1 + 1, z2 - 1, 10, 8, 2, story - 2))
		if i % 2 == 1 then
			g:Stairs("Escalera", sx1, z2 - 7, y, y + story, 6, L, "+x", C(180, 180, 185), M.Concrete)
		else
			g:Stairs("Escalera", sx2, z2 - 13, y, y + story, 6, L, "-x", C(180, 180, 185), M.Concrete)
		end
		if opts.furnish ~= false and i > 1 then
			Buildings.Furnish(g, x1 + 2, sx1 - 2, z1 + 14, z2 - 2, y, i * 31 + math.floor(cx))
		end
	end
	Elevator.build(g, elev)
	local roofY = levels[#levels]
	if opts.roofRail ~= false then
		for _, wdef in ipairs({ { "x", z2, x1, x2 }, { "x", z1, x1, x2 }, { "z", x1, z1, z2 }, { "z", x2, z1, z2 } }) do
			g:Wall("Barandilla", wdef[1], wdef[2], wdef[3], wdef[4], roofY, roofY + 3.5, 0.4, Colors.Glass, M.Glass, {})
		end
	end
	return levels, g
end

function Buildings.Palm(b, x, z, y, scale)
	scale = scale or 1
	local h = 14 * scale
	b:Pillar("TroncoPalmera", x, z, y, y + h, 1.4 * scale, C(140, 105, 70), M.Wood)
	for i = 0, 5 do
		local a = i / 6 * 360
		local rad = math.rad(a)
		b:Box("Hoja", V(9 * scale, 0.4, 2.4 * scale), V(x + math.cos(rad) * 4 * scale, y + h - 0.6, z + math.sin(rad) * 4 * scale), C(60, 150, 60), M.Grass, { rot = V(0, -a, -18) })
	end
end

function Buildings.Car(b, x, z, y, color, rotY)
	local g = b:At(V(x, y, z), "Coche")
	local along = (rotY or 0) % 180 == 0
	local size = along and V(5, 1.6, 10) or V(10, 1.6, 5)
	local cab = along and V(4.4, 1.5, 5) or V(5, 1.5, 4.4)
	g:Box("Carroceria", size, V(0, 1.4, 0), color, M.Metal)
	g:Box("Cabina", cab, V(0, 2.9, 0), Colors.Glass, M.Glass, { transparency = 0.35 })
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local px = along and sx * 2.4 or sz * 3.4
			local pz = along and sz * 3.4 or sx * 2.4
			g:Box("Rueda", V(1, 1.8, 1.8), V(px, 0.9, pz), C(25, 25, 25), M.Rubber, { shape = Enum.PartType.Cylinder, rot = along and V(0, 0, 0) or V(0, 90, 0) })
		end
	end
	return g
end

function Buildings.Lamp(b, x, z, y, h)
	h = h or 10
	b:Pillar("Farola", x, z, y, y + h, 0.6, Colors.DarkMetal, M.Metal)
	local lamp = b:Ball("Bombilla", 1.6, V(x, y + h + 0.6, z), C(255, 240, 200), M.Neon)
	Util.AddLight(lamp, 22, 1.1)
	return lamp
end

return Buildings
]])

add("ServerStorage", { "IslasMapas", "Lib" }, "Elevator", "ModuleScript", [[
-- Elevator: ascensor funcional por codigo.
--
-- Mira hacia +Z (la puerta esta en la cara +Z del hueco). Se llama desde un mapa asi:
--   Elevator.build(b, { name = "AscensorA", x = 0, z = -40, floors = { 0, 20, 40 } })
-- floors = alturas (Y) del suelo de cada planta, de menor a mayor.
--
-- Hueco interior: 12 (X) x 11 (Z). Los agujeros de los forjados de cada planta deben coincidir
-- con Elevator.hole(cfg), que devuelve {x1, x2, z1, z2}.
--
-- Rendimiento: la cabina tiene pocas piezas (se mueve entera cada frame). Dentro hay un unico boton
-- (ProximityPrompt) que abre un menu de plantas en la pantalla del jugador.
-- Los ascensores no se rompen (Destruction ignora las carpetas *_Hueco y *_Cabina).

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(script.Parent.Util)
local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))
local V, C, M = Util.V, Util.C, Util.M

local Elevator = {}

local SHAFT_W, SHAFT_D = 12, 11 -- hueco interior
local CAB = 9 -- lado de la cabina
local DOOR_W, DOOR_H = 6, 8 -- hueco de la puerta
local WALL = 0.6
local SPEED = 16 -- studs por segundo

local registry = {} -- [id] = { request, labels, cabin, state }
local nextId = 0

local MenuEvent = Net.Event("ElevatorMenu")
local RequestEvent = Net.Event("ElevatorRequest")

RequestEvent.OnServerEvent:Connect(function(player, id, floor)
	local e = registry[id]
	if not e or typeof(floor) ~= "number" or floor ~= math.floor(floor) or floor < 1 or floor > #e.labels then
		return
	end
	-- solo si el jugador esta dentro o cerca de la cabina
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or not e.cabin.Parent or (hrp.Position - e.cabin:GetPivot().Position).Magnitude > 20 then
		return
	end
	e.request(floor)
end)

-- Rectangulo (x1, x2, z1, z2) que hay que dejar vacio en cada forjado
function Elevator.hole(cfg)
	return { cfg.x - SHAFT_W / 2, cfg.x + SHAFT_W / 2, cfg.z - SHAFT_D / 2, cfg.z + SHAFT_D / 2 }
end

function Elevator.build(b, cfg)
	local floors = cfg.floors
	local count = #floors
	local cx, cz = cfg.x, cfg.z
	local y0, yTop = floors[1], floors[count]
	local wallColor = cfg.wallColor or Util.Colors.Concrete
	local wallMat = cfg.wallMaterial or M.Concrete
	local metal = Util.Colors.Metal
	local labels = {}
	for i = 1, count do
		labels[i] = (cfg.labels and cfg.labels[i]) or tostring(i)
	end

	local shaft = b:Group(cfg.name .. "_Hueco")

	-- ===== Hueco (estatico) =====
	local sTop = yTop + CAB + 3
	local sBottom = y0 - 1
	local sH = sTop - sBottom
	local sMid = (sTop + sBottom) / 2
	local sm, shaftT = wallMat, nil
	if cfg.glass then
		sm, shaftT = M.Glass, 0.5
	end
	local frontZ = cz + SHAFT_D / 2 + WALL / 2

	shaft:Box("Fondo", V(SHAFT_W + WALL * 2, sH, WALL), V(cx, sMid, cz - SHAFT_D / 2 - WALL / 2), wallColor, sm, { transparency = shaftT })
	shaft:Box("LateralIzq", V(WALL, sH, SHAFT_D), V(cx - SHAFT_W / 2 - WALL / 2, sMid, cz), wallColor, sm, { transparency = shaftT })
	shaft:Box("LateralDer", V(WALL, sH, SHAFT_D), V(cx + SHAFT_W / 2 + WALL / 2, sMid, cz), wallColor, sm, { transparency = shaftT })
	shaft:Box("Techo", V(SHAFT_W + WALL * 2, 1, SHAFT_D + WALL * 2), V(cx, sTop + 0.5, cz), wallColor, M.Concrete)
	shaft:Box("Foso", V(SHAFT_W, 1, SHAFT_D), V(cx, sBottom - 0.5, cz), Util.Colors.DarkConcrete, M.Concrete)

	-- Frente: pilares a los lados de la puerta, y paneles entre plantas
	local pillarW = (SHAFT_W + WALL * 2 - DOOR_W) / 2
	for _, side in ipairs({ -1, 1 }) do
		shaft:Box("PilarPuerta", V(pillarW, sH, WALL), V(cx + side * (DOOR_W / 2 + pillarW / 2), sMid, frontZ), wallColor, wallMat)
	end
	for i = 1, count do
		local from = floors[i] + DOOR_H
		local to = floors[i + 1] or sTop
		if to > from then
			shaft:Box("PanelPuerta", V(DOOR_W, to - from, WALL), V(cx, (from + to) / 2, frontZ), wallColor, wallMat)
		end
		if floors[i + 1] == nil or floors[i + 1] - from > 1.4 then
			shaft:Board("Indicador", labels[i], V(2.2, 0.9, 0.2), V(cx, from + 0.7, frontZ + WALL / 2 + 0.1), Util.Colors.DarkMetal, C(120, 255, 140))
		end
	end

	-- ===== Cabina (se mueve como modelo: pocas piezas) =====
	local cabin = b:Group(cfg.name .. "_Cabina", "Model")
	local cabZ = cz + 0.9 -- su frente queda casi a ras del borde del hueco
	local cabFront = cabZ + CAB / 2
	local cabSide = cfg.glass and M.Glass or M.Metal
	local cabSideT = cfg.glass and 0.5 or nil

	local floorPart = cabin:Box("SueloCabina", V(CAB, 1, CAB), V(cx, y0 - 0.5, cabZ), Util.Colors.DarkMetal, M.DiamondPlate)
	cabin:Box("TechoCabina", V(CAB + 0.8, 0.6, CAB + 0.8), V(cx, y0 + CAB + 0.3, cabZ), metal, M.Metal)
	local lamp = cabin:Box("Luz", V(5, 0.2, 5), V(cx, y0 + CAB - 0.1, cabZ), C(255, 250, 220), M.Neon, { canCollide = false })
	Util.AddLight(lamp, 16, 1.2)
	cabin:Box("FondoCabina", V(CAB + 0.8, CAB, 0.4), V(cx, y0 + CAB / 2, cabZ - CAB / 2 - 0.2), metal, M.Metal)
	for _, side in ipairs({ -1, 1 }) do
		cabin:Box("LateralCabina", V(0.4, CAB, CAB), V(cx + side * (CAB / 2 + 0.2), y0 + CAB / 2, cabZ), metal, cabSide, { transparency = cabSideT })
	end
	local cabPillar = (CAB + 0.8 - DOOR_W) / 2
	for _, side in ipairs({ -1, 1 }) do
		cabin:Box("PilarCabina", V(cabPillar, DOOR_H, 0.4), V(cx + side * (DOOR_W / 2 + cabPillar / 2), y0 + DOOR_H / 2, cabFront - 0.2), metal, M.Metal)
	end
	cabin:Box("DintelCabina", V(CAB + 0.8, CAB - DOOR_H, 0.4), V(cx, y0 + DOOR_H + (CAB - DOOR_H) / 2, cabFront - 0.2), metal, M.Metal)

	local doorW = DOOR_W / 2
	local cabDoors = {}
	for k, side in ipairs({ -1, 1 }) do
		cabDoors[k] = cabin:Box("PuertaCabina", V(doorW, DOOR_H, 0.3), V(cx + side * doorW / 2, y0 + DOOR_H / 2, cabFront + 0.15), C(200, 205, 210), M.Metal)
	end

	-- botonera: un solo boton que abre el menu de plantas
	local panel = cabin:Board("Botonera", "▲▼", V(0.3, 2.2, 1.6), V(cx - CAB / 2 + 0.15, y0 + 4.4, cabZ + 2.3), Util.Colors.DarkMetal, C(120, 255, 140), Enum.NormalId.Right)
	local panelPrompt = Instance.new("ProximityPrompt")
	panelPrompt.ActionText = count == 2 and "Ir a la otra planta" or "Elegir planta"
	panelPrompt.ObjectText = "Ascensor"
	panelPrompt.HoldDuration = 0
	panelPrompt.MaxActivationDistance = 9
	panelPrompt.RequiresLineOfSight = false
	panelPrompt.Parent = panel

	cabin.parent.PrimaryPart = floorPart

	-- ===== Puertas de cada planta =====
	local floorDoors = {}
	for i = 1, count do
		local y = floors[i]
		local pair = {}
		for k, side in ipairs({ -1, 1 }) do
			pair[k] = shaft:Box("PuertaPlanta" .. i, V(doorW, DOOR_H, 0.3), V(cx + side * doorW / 2, y + DOOR_H / 2, frontZ + WALL / 2 + 0.15), C(200, 205, 210), M.Metal)
		end
		floorDoors[i] = pair
	end

	-- ===== Logica =====
	local originX = b.origin.X
	local st = { floor = 1, busy = false, queue = {}, alive = true, open = false }

	local function slide(door, absX)
		local goal = Vector3.new(absX, door.Position.Y, door.Position.Z)
		TweenService:Create(door, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Position = goal }):Play()
	end

	local function setDoors(open)
		if st.open == open then
			return
		end
		st.open = open
		local pairFloor = floorDoors[st.floor]
		for k, side in ipairs({ -1, 1 }) do
			local closedX = originX + cx + side * doorW / 2
			local openX = originX + cx + side * (doorW / 2 + doorW - 0.2)
			local target = open and openX or closedX
			slide(cabDoors[k], target)
			slide(pairFloor[k], target)
		end
		task.wait(0.9)
	end

	local function travel(idx)
		local fromY, toY = floors[st.floor], floors[idx]
		local model = cabin.parent
		local pivot = model:GetPivot()
		local cfv = Instance.new("CFrameValue")
		cfv.Value = pivot
		local conn = cfv.Changed:Connect(function(v)
			if st.alive then
				model:PivotTo(v)
			end
		end)
		local t = math.max(1.5, math.abs(toY - fromY) / SPEED)
		local tw = TweenService:Create(cfv, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Value = pivot + Vector3.new(0, toY - fromY, 0),
		})
		tw:Play()
		tw.Completed:Wait()
		conn:Disconnect()
		cfv:Destroy()
		if st.alive then
			model:PivotTo(pivot + Vector3.new(0, toY - fromY, 0))
		end
		st.floor = idx
	end

	local function process()
		while st.alive and #st.queue > 0 do
			local idx = table.remove(st.queue, 1)
			if idx ~= st.floor then
				setDoors(false)
				if not st.alive then
					return
				end
				travel(idx)
			end
			setDoors(true)
			task.wait(4)
		end
		if st.alive then
			setDoors(false)
		end
		st.busy = false
	end

	local function request(idx)
		if not st.alive then
			return
		end
		for _, q in ipairs(st.queue) do
			if q == idx then
				return
			end
		end
		if idx == st.floor and st.busy then
			return
		end
		st.queue[#st.queue + 1] = idx
		if not st.busy then
			st.busy = true
			task.spawn(process)
		end
	end

	nextId = nextId + 1
	local id = nextId
	registry[id] = { request = request, labels = labels, cabin = cabin.parent, state = st }

	-- botones de llamada en cada planta
	for i = 1, count do
		local call = shaft:Box("BotonLlamada", V(0.7, 1, 0.3), V(cx + DOOR_W / 2 + 1, floors[i] + 3.5, frontZ + WALL / 2 + 0.15), C(255, 190, 60), M.Neon)
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = "Llamar ascensor"
		pp.ObjectText = "Planta " .. labels[i]
		pp.HoldDuration = 0
		pp.MaxActivationDistance = 8
		pp.RequiresLineOfSight = false
		pp.Parent = call
		pp.Triggered:Connect(function()
			request(i)
		end)
	end

	panelPrompt.Triggered:Connect(function(player)
		if count == 2 then
			request(st.floor == 1 and 2 or 1)
		else
			MenuEvent:FireClient(player, id, labels, st.floor)
		end
	end)

	cabin.parent.Destroying:Connect(function()
		st.alive = false
		registry[id] = nil
	end)

	task.defer(function()
		request(1)
	end)

	return { Cabin = cabin.parent, Request = request, Id = id }
end

return Elevator
]])

add("ServerStorage", { "IslasMapas", "Lib" }, "Util", "ModuleScript", [[
-- Util: herramientas para construir mapas por codigo.
-- Todo es relativo al "origin" del builder, asi un mapa se puede construir en cualquier sitio.

local Util = {}

local V = Vector3.new
local C = Color3.fromRGB
local M = Enum.Material

Util.V = V
Util.C = C
Util.M = M

Util.Colors = {
	White = C(240, 240, 240),
	Concrete = C(160, 160, 165),
	DarkConcrete = C(95, 95, 100),
	Asphalt = C(45, 45, 50),
	Glass = C(170, 215, 235),
	Metal = C(180, 185, 190),
	DarkMetal = C(70, 72, 78),
	Red = C(200, 50, 50),
	Blue = C(50, 100, 200),
	Yellow = C(240, 200, 50),
	Orange = C(235, 130, 40),
	Green = C(70, 150, 70),
	Grass = C(90, 140, 70),
	Sand = C(220, 200, 150),
	Wood = C(140, 100, 60),
	Snow = C(245, 250, 255),
	Water = C(40, 110, 175),
}

-- Tiempo maximo seguido construyendo antes de ceder el hilo (para no congelar el servidor)
Util.BuildBudget = 0.006
-- Tamano maximo de cada trozo de pared/suelo: las paredes grandes se trocean para que se rompan por partes
Util.ChunkSize = 12

local Builder = {}
Builder.__index = Builder

-- parent: donde van las piezas, origin: Vector3 donde esta el (0,0,0) del mapa
function Util.newBuilder(parent, origin)
	return setmetatable({
		parent = parent,
		origin = origin,
		state = { count = 0, spawns = {} }, -- compartido con todos los builders hijos
	}, Builder)
end

function Builder:Count()
	return self.state.count
end

function Builder:Spawns()
	return self.state.spawns
end

-- Carpeta (o modelo) nueva dentro de este builder
function Builder:Group(name, className)
	local inst = Instance.new(className or "Folder")
	inst.Name = name
	inst.Parent = self.parent
	return setmetatable({ parent = inst, origin = self.origin, state = self.state }, Builder)
end

-- Igual que Group pero ademas desplaza el origen (para construir algo reutilizable en otro sitio)
function Builder:At(offset, name, className)
	local g = self:Group(name, className)
	g.origin = self.origin + offset
	return g
end

-- Pieza basica. size/pos son Vector3 (pos = centro, relativo al origen)
-- opts: shape, transparency, canCollide, rot (grados, Vector3), velocity, reflectance,
--       touch (true = puede disparar Touched), indestructible (no se rompe con los desastres)
function Builder:Box(name, size, pos, color, material, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Color = color or Util.Colors.Concrete
	p.Material = material or M.SmoothPlastic
	if opts.shape then
		p.Shape = opts.shape
	end
	if opts.transparency then
		p.Transparency = opts.transparency
	end
	if opts.canCollide == false then
		p.CanCollide = false
	end
	if opts.reflectance then
		p.Reflectance = opts.reflectance
	end
	-- rendimiento: las piezas del mapa no necesitan eventos Touched, y las pequenas no necesitan sombra
	if not opts.touch then
		p.CanTouch = false
	end
	if math.max(size.X, size.Y, size.Z) < 3 then
		p.CastShadow = false
	end
	if opts.indestructible then
		p:SetAttribute("Indestructible", true)
	end
	local cf = CFrame.new(self.origin + pos)
	if opts.rot then
		cf = cf * CFrame.Angles(math.rad(opts.rot.X), math.rad(opts.rot.Y), math.rad(opts.rot.Z))
	end
	p.CFrame = cf
	if opts.velocity then
		p.AssemblyLinearVelocity = opts.velocity
	end
	p.Parent = self.parent

	local s = self.state
	s.count = s.count + 1
	if os.clock() - (s.lastYield or 0) > Util.BuildBudget then
		task.wait()
		s.lastYield = os.clock()
	end
	return p
end

-- Como Box pero troceando en bloques de como mucho Util.ChunkSize (solo piezas sin rotar).
-- Asi una pared de 80 studs no se rompe entera de golpe sino por trozos.
function Builder:Chunked(name, size, pos, color, material, opts)
	local c = Util.ChunkSize
	local function count(v)
		return v > c * 1.25 and math.ceil(v / c) or 1
	end
	local nx, ny, nz = count(size.X), count(size.Y), count(size.Z)
	if nx * ny * nz == 1 then
		return self:Box(name, size, pos, color, material, opts)
	end
	local sx, sy, sz = size.X / nx, size.Y / ny, size.Z / nz
	local x0 = pos.X - size.X / 2 + sx / 2
	local y0 = pos.Y - size.Y / 2 + sy / 2
	local z0 = pos.Z - size.Z / 2 + sz / 2
	local first
	for i = 0, nx - 1 do
		for j = 0, ny - 1 do
			for k = 0, nz - 1 do
				local part = self:Box(name, V(sx, sy, sz), V(x0 + i * sx, y0 + j * sy, z0 + k * sz), color, material, opts)
				first = first or part
			end
		end
	end
	return first
end

-- Columna vertical redonda (las altas se trocean para que puedan romperse por tramos)
function Builder:Pillar(name, x, z, y1, y2, diameter, color, material)
	local h = y2 - y1
	local n = h > Util.ChunkSize * 1.5 and math.ceil(h / (Util.ChunkSize * 1.5)) or 1
	local seg = h / n
	local first
	for i = 0, n - 1 do
		local a = y1 + i * seg
		local part = self:Box(name, V(seg, diameter, diameter), V(x, a + seg / 2, z), color, material, {
			shape = Enum.PartType.Cylinder,
			rot = V(0, 0, 90),
		})
		first = first or part
	end
	return first
end

function Builder:Ball(name, diameter, pos, color, material)
	return self:Box(name, V(diameter, diameter, diameter), pos, color, material, { shape = Enum.PartType.Ball })
end

-- Pared recta con huecos.
-- axis "x": la pared corre a lo largo de X, situada en z = fixed (a1..a2 son coordenadas X)
-- axis "z": la pared corre a lo largo de Z, situada en x = fixed (a1..a2 son coordenadas Z)
-- openings: lista de { from, to, bottom, top, glass } (bottom/top relativos a y1)
function Builder:Wall(name, axis, fixed, a1, a2, y1, y2, th, color, material, openings)
	openings = openings or {}
	table.sort(openings, function(p, q)
		return p.from < q.from
	end)
	local h = y2 - y1

	local function seg(from, to, bottom, top, segColor, segMat, transp, segName)
		if to - from < 0.05 or top - bottom < 0.05 then
			return
		end
		local len = to - from
		local cy = y1 + (bottom + top) / 2
		local mid = (from + to) / 2
		local size, pos
		if axis == "x" then
			size = V(len, top - bottom, th)
			pos = V(mid, cy, fixed)
		else
			size = V(th, top - bottom, len)
			pos = V(fixed, cy, mid)
		end
		local useMat = segMat or material
		if useMat == M.Glass and transp == nil then
			transp = 0.55 -- el cristal siempre es translucido
		end
		self:Chunked(segName or name, size, pos, segColor or color, useMat, { transparency = transp })
	end

	local cursor = a1
	for _, o in ipairs(openings) do
		seg(cursor, o.from, 0, h)
		local bottom = o.bottom or 0
		local top = o.top or h
		seg(o.from, o.to, 0, bottom)
		seg(o.from, o.to, top, h)
		if o.glass then
			seg(o.from, o.to, bottom, top, Util.Colors.Glass, M.Glass, 0.55, name .. "Glass")
		end
		cursor = o.to
	end
	seg(cursor, a2, 0, h)
end

-- Lista de huecos de ventana para Builder:Wall: centros cada `step`, ancho `w`.
-- skipFrom/skipTo (opcional) dejan sin ventanas un tramo de la pared.
function Util.Windows(a1, a2, step, w, bottom, top, skipFrom, skipTo)
	local list = {}
	local c = a1 + step / 2
	while c + w / 2 <= a2 do
		local from, to = c - w / 2, c + w / 2
		if not (skipFrom and to > skipFrom and from < skipTo) then
			list[#list + 1] = { from = from, to = to, bottom = bottom, top = top, glass = true }
		end
		c = c + step
	end
	return list
end

-- Suelo/techo rectangular con agujeros. holes = { {x1, x2, z1, z2}, ... }
function Builder:Slab(name, x1, x2, z1, z2, ytop, th, color, material, holes)
	local rects = { { x1, x2, z1, z2 } }
	for _, h in ipairs(holes or {}) do
		local out = {}
		for _, r in ipairs(rects) do
			if h[2] <= r[1] or h[1] >= r[2] or h[4] <= r[3] or h[3] >= r[4] then
				out[#out + 1] = r
			else
				local hx1, hx2 = math.max(h[1], r[1]), math.min(h[2], r[2])
				local hz1, hz2 = math.max(h[3], r[3]), math.min(h[4], r[4])
				if hx1 > r[1] then
					out[#out + 1] = { r[1], hx1, r[3], r[4] }
				end
				if hx2 < r[2] then
					out[#out + 1] = { hx2, r[2], r[3], r[4] }
				end
				if hz1 > r[3] then
					out[#out + 1] = { hx1, hx2, r[3], hz1 }
				end
				if hz2 < r[4] then
					out[#out + 1] = { hx1, hx2, hz2, r[4] }
				end
			end
		end
		rects = out
	end
	for _, r in ipairs(rects) do
		self:Chunked(
			name,
			V(r[2] - r[1], th, r[4] - r[3]),
			V((r[1] + r[2]) / 2, ytop - th / 2, (r[3] + r[4]) / 2),
			color,
			material
		)
	end
end

-- Escalera de escalones macizos. (x, z) = pie de la escalera (centro del ancho).
-- dir = hacia donde se sube: "+x", "-x", "+z", "-z"
function Builder:Stairs(name, x, z, y1, y2, width, length, dir, color, material)
	local n = math.max(2, math.ceil(y2 - y1))
	local rise, run = (y2 - y1) / n, length / n
	for i = 1, n do
		local hgt = rise * i
		local off = run * (i - 0.5)
		local size, pos
		if dir == "+x" then
			size, pos = V(run, hgt, width), V(x + off, y1 + hgt / 2, z)
		elseif dir == "-x" then
			size, pos = V(run, hgt, width), V(x - off, y1 + hgt / 2, z)
		elseif dir == "+z" then
			size, pos = V(width, hgt, run), V(x, y1 + hgt / 2, z + off)
		else
			size, pos = V(width, hgt, run), V(x, y1 + hgt / 2, z - off)
		end
		self:Box(name, size, pos, color, material)
	end
end

-- Cuna (rampa/tejado). La parte alta queda hacia +Z; rotY gira alrededor del eje vertical (grados).
function Builder:Wedge(name, size, pos, color, material, rotY, opts)
	opts = opts or {}
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.Size = size
	w.Color = color or Util.Colors.Concrete
	w.Material = material or M.SmoothPlastic
	w.CanTouch = false
	if opts.indestructible then
		w:SetAttribute("Indestructible", true)
	end
	w.CFrame = CFrame.new(self.origin + pos) * CFrame.Angles(0, math.rad(rotY or 0), 0)
	w.Parent = self.parent
	local s = self.state
	s.count = s.count + 1
	if os.clock() - (s.lastYield or 0) > Util.BuildBudget then
		task.wait()
		s.lastYield = os.clock()
	end
	return w
end

-- Escalera de mano (se trepa)
function Builder:Ladder(name, x, z, y1, y2)
	local t = Instance.new("TrussPart")
	t.Name = name
	t.Anchored = true
	t.Size = V(2, y2 - y1, 2)
	t.CFrame = CFrame.new(self.origin + V(x, (y1 + y2) / 2, z))
	t.CanTouch = false
	t.Parent = self.parent
	self.state.count = self.state.count + 1
	return t
end

-- Texto en una cara de una pieza
function Builder:Sign(part, text, face, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Back -- Back = cara +Z: el cartel se lee mirando hacia -Z
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.Parent = gui
	return label
end

-- Cartel: caja con texto en la cara +Z por defecto
function Builder:Board(name, text, size, pos, bg, fg, face)
	local p = self:Box(name, size, pos, bg or Util.Colors.DarkMetal, M.SmoothPlastic)
	self:Sign(p, text, face, fg)
	return p
end

function Util.AddLight(part, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Range = range or 20
	l.Brightness = brightness or 1
	if color then
		l.Color = color
	end
	l.Parent = part
	return l
end

-- Punto de aparicion de jugadores (invisible)
function Builder:Spawn(pos)
	local p = self:Box("SpawnPoint", V(4, 1, 4), pos, Util.Colors.White, M.SmoothPlastic, {
		transparency = 1,
		canCollide = false,
		indestructible = true,
	})
	local list = self.state.spawns
	list[#list + 1] = p
	return p
end

-- Mar con plano de muerte: tocar el agua mata al jugador
function Builder:Sea(y, extent, color, transparency)
	extent = math.min(extent or 2048, 2048) -- una pieza mide como mucho 2048 studs
	local p = self:Box("Mar", V(extent, 2, extent), V(0, y - 1, 0), color or Util.Colors.Water, M.SmoothPlastic, {
		transparency = transparency or 0.15,
		canCollide = false,
		touch = true,
		indestructible = true,
	})
	p.CastShadow = false
	p.Touched:Connect(function(hit)
		local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.Health = 0
		end
	end)
	return p
end

-- Plano de muerte invisible (vacio): tocarlo mata al jugador
function Builder:KillPlane(y, extent)
	return self:Sea(y, extent, Util.Colors.DarkMetal, 1)
end

-- Marca un modelo para que los clientes lo hagan girar (sin coste para el servidor).
-- axis = "X", "Y" o "Z"; rpm = vueltas por minuto. El giro es alrededor del centro del modelo.
function Builder:Spin(model, rpm, axis)
	-- lo que gira no se rompe (el giro es solo visual en cada cliente)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d:SetAttribute("Indestructible", true)
		end
	end
	model:SetAttribute("GiroRPM", rpm)
	model:SetAttribute("GiroEje", axis or "Y")
	game:GetService("CollectionService"):AddTag(model, "IslasGira")
end

-- Abeto simple (tronco + 3 pisos)
function Builder:Pine(x, z, y, scale)
	scale = scale or 1
	self:Pillar("Tronco", x, z, y, y + 5 * scale, 1.2 * scale, Util.Colors.Wood, M.Wood)
	for i = 0, 2 do
		local d = (8 - i * 2.2) * scale
		self:Pillar("Copa", x, z, y + (3 + i * 2.2) * scale, y + (5.4 + i * 2.2) * scale, d, C(35, 95, 50), M.Grass)
	end
end

return Util
]])

add("ServerScriptService", { "IslasServer" }, "CoinDrops", "ModuleScript", [[
-- CoinDrops: monedas repartidas por el mapa durante la ronda (y en el lobby). Al tocarlas se cobran.
-- Con el "Iman de monedas" se recogen desde lejos. Los clientes las hacen girar (etiqueta IslasGira).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)

local PlaySound = Net.Event("PlaySound")

local CoinDrops = {}

local folder
local coins = {} -- [part] = value

local function ensureFolder()
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "MonedasRonda"
		folder.Parent = workspace
	end
	return folder
end

local function collect(coin, player)
	local value = coins[coin]
	if not value then
		return
	end
	coins[coin] = nil
	local pos = coin.Position
	coin:Destroy()
	Rewards.Give(player, value, 1, { text = value >= Config.BigCoinValue and "¡Moneda grande!" or nil, position = pos })
	Rewards.Stat(player, "CoinsPicked", value)
	PlaySound:FireClient(player, "Coin", pos, value >= Config.BigCoinValue and 1 or 0.6)
end

function CoinDrops.Spawn(position, value, parent)
	local big = value >= Config.BigCoinValue
	local coin = Instance.new("Part")
	coin.Name = big and "MonedaGrande" or "Moneda"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = big and Vector3.new(0.5, 4, 4) or Vector3.new(0.35, 2.4, 2.4)
	coin.Color = big and Color3.fromRGB(255, 120, 220) or Color3.fromRGB(255, 205, 50)
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CastShadow = false
	coin.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	coin:SetAttribute("GiroRPM", 40)
	coin:SetAttribute("GiroEje", "X")
	coin.Parent = parent or ensureFolder()
	CollectionService:AddTag(coin, "IslasGira")
	coins[coin] = value
	coin.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if player and hum and hum.Health > 0 then
			collect(coin, player)
		end
	end)
	return coin
end

-- Reparte monedas por la superficie del mapa
function CoinDrops.SpawnRound(current, count)
	CoinDrops.Clear()
	local b = current.Bounds
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { current.Folder }
	params.RespectCanCollide = true
	local placed = 0
	for _ = 1, count * 3 do
		if placed >= count then
			break
		end
		local x = b.x1 + math.random() * (b.x2 - b.x1)
		local z = b.z1 + math.random() * (b.z2 - b.z1)
		local hit = workspace:Raycast(Vector3.new(x, b.top + 30, z), Vector3.new(0, -(b.top - b.floor + 120), 0), params)
		if hit and hit.Position.Y > b.floor - 1 then
			local big = math.random() < Config.BigCoinChance
			CoinDrops.Spawn(hit.Position + Vector3.new(0, 2.5, 0), big and Config.BigCoinValue or Config.CoinValue)
			placed = placed + 1
		end
	end
	return placed
end

function CoinDrops.Clear()
	for coin in pairs(coins) do
		if coin.Parent and coin:IsDescendantOf(ensureFolder()) then
			coins[coin] = nil
			coin:Destroy()
		end
	end
end

function CoinDrops.Count()
	local n = 0
	for _ in pairs(coins) do
		n = n + 1
	end
	return n
end

function CoinDrops.Init()
	-- iman: recoge monedas cercanas
	task.spawn(function()
		while true do
			task.wait(0.3)
			if next(coins) then
				for _, player in ipairs(Players:GetPlayers()) do
					local data = PlayerData.Get(player)
					local char = player.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if data and data.Owned.Iman and hrp and hum and hum.Health > 0 then
						for coin in pairs(coins) do
							if coin.Parent and (coin.Position - hrp.Position).Magnitude < 16 then
								collect(coin, player)
							end
						end
					end
				end
			end
		end
	end)
end

return CoinDrops
]])

add("ServerScriptService", { "IslasServer" }, "CollisionGroups", "ModuleScript", [[
-- CollisionGroups: grupos de colision para que los escombros no choquen entre si (lo mas caro de la fisica)
-- y los fragmentos visuales del cliente no empujen a los jugadores.
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local CollisionGroups = {
	Debris = "IslasDebris", -- escombros fisicos del servidor
	Fx = "IslasFx", -- fragmentos visuales del cliente
	Players = "IslasPlayers",
}

local done = false

function CollisionGroups.Setup()
	if done then
		return
	end
	done = true
	local ok, err = pcall(function()
		for _, g in ipairs({ CollisionGroups.Debris, CollisionGroups.Fx, CollisionGroups.Players }) do
			if not PhysicsService:IsCollisionGroupRegistered(g) then
				PhysicsService:RegisterCollisionGroup(g)
			end
		end
		PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Debris, CollisionGroups.Debris, false)
		PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Fx, CollisionGroups.Fx, false)
		PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Fx, CollisionGroups.Players, false)
		PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Fx, CollisionGroups.Debris, false)
		PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Players, CollisionGroups.Players, false)
	end)
	if not ok then
		warn("CollisionGroups: no se pudieron crear los grupos: " .. tostring(err))
	end

	local function setGroup(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = CollisionGroups.Players
		end
	end
	local function onCharacter(char)
		for _, d in ipairs(char:GetDescendants()) do
			setGroup(d)
		end
		char.DescendantAdded:Connect(setGroup)
	end
	local function onPlayer(player)
		if player.Character then
			onCharacter(player.Character)
		end
		player.CharacterAdded:Connect(onCharacter)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return CollisionGroups
]])

print("Islas de Desastres: parte 2 de 5 instalada")
