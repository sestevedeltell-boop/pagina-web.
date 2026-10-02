-- INSTALADOR de Islas de Desastres.
-- Pegalo en la Barra de comandos de Studio (pestana Ver > Barra de comandos) y pulsa Enter.
-- Crea (o reemplaza) estas carpetas: ReplicatedStorage.IslasShared, ServerStorage.IslasMapas,
-- ServerScriptService.IslasServer y StarterPlayer.StarterPlayerScripts.IslasClient.
-- No toca nada de tu juego salvo esas 4 carpetas.

local services = {
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerStorage = game:GetService("ServerStorage"),
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"),
}

-- borra las carpetas raiz antiguas para reinstalar limpio
for _, pair in ipairs({
	{ "ReplicatedStorage", "IslasShared" },
	{ "ServerStorage", "IslasMapas" },
	{ "ServerScriptService", "IslasServer" },
	{ "StarterPlayerScripts", "IslasClient" },
}) do
	local old = services[pair[1]]:FindFirstChild(pair[2])
	if old then
		old:Destroy()
	end
end

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
	local inst = Instance.new(className)
	inst.Name = name
	inst.Source = source
	inst.Parent = folderAt(service, path)
end

add("ReplicatedStorage", { "IslasShared" }, "Config", "ModuleScript", [[
-- Config: ajustes del sistema de islas. Cambia lo que quieras aqui.
return {
	-- Donde se construye el mapa elegido: lejos del lobby, y alto para no acercarse a FallenPartsDestroyHeight
	MapOrigin = Vector3.new(8000, 1000, 0),

	-- Tiempos (segundos)
	IntermissionTime = 15,
	VoteTime = 15,
	RoundTime = 180,

	-- Cuantos mapas salen en la votacion
	OptionsPerVote = 3,

	-- Minimo de jugadores para empezar una ronda
	MinPlayers = 1,

	-- true = el script RoundLoop de este proyecto lleva las rondas.
	-- Pon false si ya tienes tu propio bucle de rondas y quieres llamar tu a MapService / VoteService.
	RunDefaultLoop = true,
}
]])

add("ServerStorage", { "IslasMapas", "Builders" }, "Airport", "ModuleScript", [[
-- Aeropuerto: terminal de 3 plantas con ascensores y escaleras, torre de control (ascensor + 3 paradas),
-- dos aviones con interior, hangar, camiones de combustible y pista.

local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local Airport = {
	Title = "Aeropuerto",
	Description = "Terminal de 3 plantas con ascensores, torre de control, aviones, hangar y pista.",
	Lighting = { ClockTime = 15, Brightness = 2 },
}

local WHITE = C(235, 238, 242)
local TILE = C(205, 208, 214)

local windows = Util.Windows

local function buildPlane(g)
	-- Avion de pasajeros mirando a +X, con puerta en el lado +Z. Origen = centro del avion en el suelo.
	local L = 56
	g:Box("Suelo", V(L, 0.6, 7), V(0, 3.2, 0), TILE, M.SmoothPlastic)
	g:Box("Techo", V(L, 0.6, 8), V(0, 9.8, 0), WHITE, M.SmoothPlastic)
	local door = { from = -20, to = -15, bottom = 0, top = 6.2 }
	g:Wall("ParedFrente", "x", 3.75, -L / 2, L / 2, 3.5, 9.5, 0.5, WHITE, M.SmoothPlastic, (function()
		local o = windows(-L / 2 + 6, L / 2 - 6, 4.5, 2, 2, 4.5, -22, -13)
		o[#o + 1] = door
		return o
	end)())
	g:Wall("ParedFondo", "x", -3.75, -L / 2, L / 2, 3.5, 9.5, 0.5, WHITE, M.SmoothPlastic, windows(-L / 2 + 6, L / 2 - 6, 4.5, 2, 2, 4.5))
	g:Wall("MamparaTrasera", "z", -L / 2, -3.5, 3.5, 3.5, 9.5, 0.5, WHITE, M.SmoothPlastic)
	-- morro y cabina
	g:Ball("Morro", 9.5, V(L / 2 + 1.5, 6.5, 0), WHITE, M.SmoothPlastic)
	g:Box("Cabina", V(3, 2, 7), V(L / 2 - 1.5, 8.6, 0), Colors.Glass, M.Glass, { transparency = 0.4 })
	-- cola
	g:Box("Deriva", V(6, 13, 0.8), V(-L / 2 + 1, 15, 0), Colors.Blue, M.SmoothPlastic, { rot = V(0, 0, -12) })
	g:Box("AlaCola", V(5, 0.6, 18), V(-L / 2 + 1, 10.5, 0), WHITE, M.SmoothPlastic)
	-- alas y motores
	g:Box("Ala", V(14, 0.8, 46), V(3, 3, 0), C(200, 204, 210), M.Metal)
	for _, side in ipairs({ -1, 1 }) do
		g:Box("Motor", V(8, 3.6, 3.6), V(6, 1.5, side * 13), Colors.DarkMetal, M.Metal, { shape = Enum.PartType.Cylinder })
		g:Box("PuntaAla", V(4, 1.5, 0.8), V(-1, 4, side * 23), Colors.Blue, M.SmoothPlastic)
	end
	-- tren de aterrizaje
	g:Box("Rueda", V(1, 3.4, 3.4), V(L / 2 - 6, 1.7, 0), Colors.DarkMetal, M.Rubber, { shape = Enum.PartType.Cylinder, rot = V(0, 90, 0) })
	-- asientos
	for row = 0, 9 do
		local x = -12 + row * 3.2
		for _, z in ipairs({ -2.6, -1.0, 1.0, 2.6 }) do
			g:Box("Asiento", V(1.6, 1.4, 1.4), V(x, 4.2, z), Colors.Blue, M.Fabric)
			g:Box("Respaldo", V(0.4, 2, 1.4), V(x - 0.7, 5.2, z), Colors.Blue, M.Fabric)
		end
	end
	-- escalerilla en la puerta (dirige hacia -Z)
	g:Stairs("Escalerilla", -17.5, 3.75 + 5.6, 0, 3.5, 4, 5.6, "-z", Colors.Metal, M.Metal)
end

local function buildTruck(g, x, z)
	local t = g:At(V(x, 0, z), "CamionCombustible")
	t:Box("Chasis", V(14, 1.4, 5.6), V(0, 1.9, 0), Colors.DarkMetal, M.Metal)
	t:Box("Cabina", V(4, 4, 5.6), V(6, 4.6, 0), Colors.Red, M.SmoothPlastic)
	t:Box("Parabrisas", V(0.3, 2, 4.8), V(8.1, 5.2, 0), Colors.Glass, M.Glass, { transparency = 0.4 })
	t:Box("Tanque", V(10, 4.4, 4.4), V(-2, 5, 0), Colors.White, M.Metal, { shape = Enum.PartType.Cylinder })
	for _, wx in ipairs({ -5, 0, 6 }) do
		for _, side in ipairs({ -1, 1 }) do
			t:Box("Rueda", V(1.2, 2.8, 2.8), V(wx, 1.4, side * 2.9), C(25, 25, 25), M.Rubber, { shape = Enum.PartType.Cylinder, rot = V(0, 90, 0) })
		end
	end
end

function Airport.Build(b)
	-- ===== Isla y mar =====
	b:Box("Isla", V(560, 10, 400), V(0, -5.5, 0), Colors.Grass, M.Grass)
	b:Sea(-6)

	-- ===== Pavimentos =====
	local ground = b:Group("Pavimentos")
	ground:Box("Plataforma", V(240, 0.5, 70), V(0, -0.25, -55), Colors.DarkConcrete, M.Concrete)
	ground:Box("Calle", V(18, 0.5, 70), V(0, -0.25, 15), Colors.Asphalt, M.Asphalt)
	ground:Box("Pista", V(540, 0.5, 40), V(0, -0.25, 70), Colors.Asphalt, M.Asphalt)
	for x = -250, 250, 30 do
		ground:Box("MarcaPista", V(14, 0.1, 1.2), V(x, 0.02, 70), WHITE, M.SmoothPlastic, { canCollide = false })
	end
	for _, z in ipairs({ 52.5, 87.5 }) do
		ground:Box("LineaPista", V(540, 0.1, 0.6), V(0, 0.02, z), WHITE, M.SmoothPlastic, { canCollide = false })
	end

	-- ===== Terminal =====
	local term = b:Group("Terminal")
	local x1, x2, z1, z2 = -80, 80, -170, -90
	local levels = { 0, 18, 36 }
	local roofY = 54
	local elevA = { name = "AscensorA", x = -8, z = -163.5, floors = levels, labels = { "PB", "1", "2" } }
	local elevB = { name = "AscensorB", x = 8, z = -163.5, floors = levels, labels = { "PB", "1", "2" } }
	local hA, hB = Elevator.hole(elevA), Elevator.hole(elevB)
	local stairHole1 = { 30, 59, -129, -121 } -- sube de PB a la 1
	local stairHole2 = { 43, 72, -144, -136 } -- sube de la 1 a la 2

	term:Slab("SueloPB", x1, x2, z1, z2, 0, 0.5, TILE, M.Marble, { hA, hB })
	term:Slab("Suelo1", x1, x2, z1, z2, 18, 1.5, TILE, M.Marble, { hA, hB, stairHole1 })
	term:Slab("Suelo2", x1, x2, z1, z2, 36, 1.5, TILE, M.Marble, { hA, hB, stairHole2 })
	term:Slab("Cubierta", x1 - 10, x2 + 10, z1 - 10, z2 + 10, roofY + 2, 2, Colors.DarkMetal, M.Metal)

	for i, y in ipairs(levels) do
		local top = y + 18
		-- fachada frontal (+Z)
		local front
		if i == 1 then
			front = windows(x1 + 2, x2 - 2, 14, 10, 3, 15, -14, 14)
			front[#front + 1] = { from = -10, to = 10, bottom = 0, top = 12 }
		else
			front = windows(x1 + 2, x2 - 2, 14, 11, 2, 16)
		end
		term:Wall("Fachada" .. i, "x", z2, x1, x2, y, top, 1, WHITE, M.Concrete, front)
		term:Wall("Trasera" .. i, "x", z1, x1, x2, y, top, 1, WHITE, M.Concrete)
		term:Wall("LateralIzq" .. i, "z", x1, z1, z2, y, top, 1, WHITE, M.Concrete, windows(z1 + 2, z2 - 2, 14, 10, 3, 15))
		term:Wall("LateralDer" .. i, "z", x2, z1, z2, y, top, 1, WHITE, M.Concrete, windows(z1 + 2, z2 - 2, 14, 10, 3, 15))
	end
	term:Board("Letrero", "AEROPUERTO INTERNACIONAL", V(90, 8, 1), V(0, roofY + 7, z2 + 3), Colors.Blue, WHITE)
	for x = -60, 60, 30 do
		term:Pillar("Columna", x, -118, 0, roofY, 2.4, WHITE, M.Concrete)
	end

	Elevator.build(term, elevA)
	Elevator.build(term, elevB)
	term:Stairs("EscaleraPB", 30, -125, 0, 18, 8, 29, "+x", WHITE, M.Concrete)
	term:Stairs("Escalera1", 72, -140, 18, 36, 8, 29, "-x", WHITE, M.Concrete)

	-- --- Planta baja ---
	local pb = term:Group("PlantaBaja")
	for i, x in ipairs({ -66, -52, -38, -24, 24, 38, 52, 66 }) do
		pb:Board("Mostrador", "CHECK-IN " .. i, V(10, 3.6, 3), V(x, 1.8, -105), Colors.Blue, WHITE)
		pb:Box("Cinta", V(8, 0.6, 1.4), V(x, 3.9, -105), Colors.DarkMetal, M.Metal)
	end
	for _, x in ipairs({ -48, -36, -24 }) do
		pb:Box("PorticoSeguridadIzq", V(0.6, 9, 1.5), V(x - 2.5, 4.5, -135), Colors.DarkMetal, M.Metal)
		pb:Box("PorticoSeguridadDer", V(0.6, 9, 1.5), V(x + 2.5, 4.5, -135), Colors.DarkMetal, M.Metal)
		pb:Box("PortcoSeguridadTop", V(5.6, 0.8, 1.5), V(x, 9.4, -135), Colors.DarkMetal, M.Metal)
		pb:Box("LuzSeguridad", V(4, 0.3, 0.3), V(x, 8.6, -135), C(90, 255, 120), M.Neon, { canCollide = false })
	end
	pb:Board("CartelSeguridad", "CONTROL DE SEGURIDAD", V(24, 3, 0.4), V(-36, 11.5, -135), Colors.Yellow, C(20, 20, 20))
	for r = 0, 1 do
		for x = -60, -30, 10 do
			pb:Box("Banco", V(8, 1.2, 2.2), V(x, 0.6 + 0.6, -150 + r * 6), Colors.Wood, M.Wood)
		end
	end
	pb:Box("TiendaMostrador", V(10, 4, 10), V(-70, 2, -150), Colors.Orange, M.SmoothPlastic)
	pb:Board("CartelTienda", "TIENDA", V(10, 3, 0.4), V(-70, 6.5, -144.7), Colors.Orange, WHITE)
	-- cinta de equipajes: empuja a los jugadores
	pb:Box("CintaEquipaje", V(36, 1.2, 6), V(45, 0.6, -160), Colors.DarkMetal, M.Metal, { velocity = V(7, 0, 0) })
	pb:Board("CartelEquipaje", "RECOGIDA DE EQUIPAJE", V(26, 3, 0.4), V(45, 8, -169.3), Colors.DarkMetal, WHITE)
	for i = 0, 5 do
		pb:Box("Maleta", V(2.4, 1.8, 1.4), V(32 + i * 5, 2.1, -160), C(60 + i * 25, 70, 140 - i * 15), M.Fabric, { canCollide = false })
	end
	for _, p in ipairs({ { -75, -95 }, { 75, -95 }, { -75, -165 }, { 75, -165 } }) do
		pb:Pillar("Maceta", p[1], p[2], 0, 2, 3, Colors.Wood, M.Wood)
		pb:Ball("Planta", 5, V(p[1], 4.5, p[2]), Colors.Green, M.Grass)
	end

	-- --- Planta 1: restaurantes y sala de embarque ---
	local p1 = term:Group("Planta1")
	for ix = 0, 3 do
		for iz = 0, 2 do
			local x, z = -66 + ix * 11, -155 + iz * 14
			p1:Pillar("PataMesa", x, z, 18, 21, 0.8, Colors.DarkMetal, M.Metal)
			p1:Pillar("MesaComedor", x, z, 21, 21.5, 5, WHITE, M.Marble)
			for _, o in ipairs({ { 3.4, 0 }, { -3.4, 0 }, { 0, 3.4 }, { 0, -3.4 } }) do
				p1:Box("Silla", V(1.6, 1.6, 1.6), V(x + o[1], 18.8, z + o[2]), Colors.Red, M.Fabric)
			end
		end
	end
	p1:Board("CartelComida", "ZONA DE RESTAURANTES", V(30, 3, 0.4), V(-45, 29, -169.3), Colors.Red, WHITE)
	for x = -66, 66, 16 do
		p1:Box("AsientoEmbarque", V(8, 1.4, 2), V(x, 18.7, -98), Colors.Blue, M.Fabric)
		p1:Box("RespaldoEmbarque", V(8, 2, 0.5), V(x, 20, -99.2), Colors.Blue, M.Fabric)
	end
	p1:Box("DutyFree", V(12, 4, 6), V(50, 20, -108), Colors.Yellow, M.SmoothPlastic)
	p1:Board("CartelDutyFree", "DUTY FREE", V(12, 3, 0.4), V(50, 24.5, -104.9), Colors.Yellow, C(20, 20, 20))
	p1:Board("PanelSalidas", "SALIDAS\nMAD   10:45   PUERTA 4\nJFK   11:20   PUERTA 7\nTYO   12:05   PUERTA 2\nLON   12:40   PUERTA 5", V(30, 11, 0.6), V(40, 29, -169.2), Colors.DarkMetal, C(255, 190, 60))

	-- --- Planta 2: mirador ---
	local p2 = term:Group("Planta2")
	p2:Board("CartelMirador", "MIRADOR · LOUNGE VIP", V(30, 3, 0.4), V(-40, 47, -169.3), Colors.Blue, WHITE)
	for ix = 0, 2 do
		for iz = 0, 1 do
			local x, z = -66 + ix * 14, -112 + iz * -10
			p2:Box("Sofa", V(8, 1.6, 3), V(x, 36.8, z), Colors.Red, M.Fabric)
			p2:Box("RespaldoSofa", V(8, 2.4, 0.8), V(x, 38, z - 1.4), Colors.Red, M.Fabric)
			p2:Box("MesaBaja", V(3, 1, 3), V(x, 36.5, z + 3.5), Colors.Wood, M.Wood)
		end
	end
	p2:Box("Barra", V(24, 4, 3), V(50, 38, -112), Colors.Wood, M.Wood)
	p2:Board("CartelBar", "BAR", V(6, 2, 0.4), V(50, 41.5, -110.4), Colors.DarkMetal, WHITE)

	-- ===== Torre de control =====
	local tw = b:Group("TorreDeControl")
	local tcfg = { name = "AscensorTorre", x = 150, z = -20, floors = { 0, 30, 60, 90 }, labels = { "PB", "1", "2", "3" } }
	local tx, tz = tcfg.x, tcfg.z
	local tHole = Elevator.hole(tcfg)
	tw:Slab("BaseTorre", tx - 14, tx + 14, tz - 8, tz + 18, 0, 0.5, TILE, M.Concrete, { tHole })
	Elevator.build(tw, tcfg)
	for _, y in ipairs({ 30, 60 }) do
		tw:Slab("Balcon", tx - 9, tx + 9, tz + 6.1, tz + 15, y, 1.5, WHITE, M.Concrete)
		tw:Wall("BarandillaFrente", "x", tz + 15, tx - 9, tx + 9, y, y + 4, 0.3, Colors.Glass, M.Glass, {})
		tw:Wall("BarandillaIzq", "z", tx - 9, tz + 6.1, tz + 15, y, y + 4, 0.3, Colors.Glass, M.Glass, {})
		tw:Wall("BarandillaDer", "z", tx + 9, tz + 6.1, tz + 15, y, y + 4, 0.3, Colors.Glass, M.Glass, {})
	end
	tw:Slab("SalaControl", tx - 14, tx + 14, tz - 14, tz + 14, 90, 1.5, WHITE, M.Concrete, { tHole })
	local ring = { { from = tx - 13, to = tx + 13, bottom = 1, top = 14, glass = true } }
	tw:Wall("VentanalFrente", "x", tz + 14, tx - 14, tx + 14, 90, 106, 0.6, Colors.DarkMetal, M.Metal, ring)
	tw:Wall("VentanalFondo", "x", tz - 14, tx - 14, tx + 14, 90, 106, 0.6, Colors.DarkMetal, M.Metal, ring)
	local ringZ = { { from = tz - 13, to = tz + 13, bottom = 1, top = 14, glass = true } }
	tw:Wall("VentanalIzq", "z", tx - 14, tz - 14, tz + 14, 90, 106, 0.6, Colors.DarkMetal, M.Metal, ringZ)
	tw:Wall("VentanalDer", "z", tx + 14, tz - 14, tz + 14, 90, 106, 0.6, Colors.DarkMetal, M.Metal, ringZ)
	tw:Slab("TechoTorre", tx - 16, tx + 16, tz - 16, tz + 16, 108, 2, Colors.DarkMetal, M.Metal)
	tw:Pillar("Antena", tx + 8, tz - 8, 108, 124, 1, Colors.Red, M.Metal)
	tw:Ball("LuzAntena", 2, V(tx + 8, 124.5, tz - 8), Colors.Red, M.Neon)
	for i = 0, 3 do
		tw:Box("Consola", V(6, 3, 2.5), V(tx - 10.5 + i * 7, 91.5 + 1.5, tz + 9), Colors.DarkMetal, M.Metal)
		tw:Box("Pantalla", V(5, 2, 0.2), V(tx - 10.5 + i * 7, 96.5, tz + 8), C(40, 220, 140), M.Neon, { canCollide = false })
		tw:Box("SillaControl", V(2, 2, 2), V(tx - 10.5 + i * 7, 92.5, tz + 5.5), Colors.Red, M.Fabric)
	end

	-- ===== Aviones =====
	buildPlane(b:At(V(-60, 0, -55), "AvionA"))
	buildPlane(b:At(V(58, 0, -55), "AvionB"))
	buildTruck(b, 100, -40)
	buildTruck(b, 100, -70)

	-- ===== Hangar =====
	local hg = b:Group("Hangar")
	local hx1, hx2, hz1, hz2 = -200, -150, -20, 20
	hg:Wall("HangarFrente", "x", hz2, hx1, hx2, 0, 22, 1, Colors.Metal, M.CorrodedMetal, { { from = -188, to = -162, bottom = 0, top = 16 } })
	hg:Wall("HangarFondo", "x", hz1, hx1, hx2, 0, 22, 1, Colors.Metal, M.CorrodedMetal)
	hg:Wall("HangarIzq", "z", hx1, hz1, hz2, 0, 22, 1, Colors.Metal, M.CorrodedMetal, windows(hz1 + 2, hz2 - 2, 10, 6, 14, 20))
	hg:Wall("HangarDer", "z", hx2, hz1, hz2, 0, 22, 1, Colors.Metal, M.CorrodedMetal, windows(hz1 + 2, hz2 - 2, 10, 6, 14, 20))
	hg:Slab("HangarSuelo", hx1, hx2, hz1, hz2, 0, 0.5, Colors.DarkConcrete, M.Concrete)
	hg:Slab("HangarTecho", hx1 - 2, hx2 + 2, hz1 - 2, hz2 + 2, 23, 1, Colors.DarkMetal, M.Metal)
	hg:Ladder("EscalerillaHangar", hx2 + 1.2, 0, 0, 24.5)
	for i = 0, 5 do
		local cx, cz = -194 + (i % 3) * 5, -14 + math.floor(i / 3) * 5
		hg:Box("Caja", V(4, 4, 4), V(cx, 2, cz), Colors.Wood, M.Wood)
		if i % 2 == 0 then
			hg:Box("CajaAlta", V(4, 4, 4), V(cx, 6, cz), Colors.Orange, M.Wood)
		end
	end
	hg:Board("CartelHangar", "HANGAR 1", V(26, 4, 0.4), V(-175, 19, hz2 + 0.7), Colors.Yellow, C(20, 20, 20))

	-- ===== Puntos de aparicion (plataforma, entre los dos aviones) =====
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-15 + ix * 10, 1, -78 + iz * 14))
		end
	end
end

return Airport
]])

add("ServerStorage", { "IslasMapas", "Builders" }, "Mall", "ModuleScript", [[
-- Centro comercial: 4 plantas alrededor de un gran atrio con claraboya, ascensores panoramicos de cristal,
-- escaleras, tiendas, fuente central, cine en la ultima planta y aparcamiento.

local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local Mall = {
	Title = "Centro Comercial",
	Description = "4 plantas con atrio, ascensores de cristal, escaleras, tiendas, fuente y cine.",
	Lighting = { ClockTime = 12, Brightness = 2 },
}

local FLOOR_H = 16
local SHOP_COLORS = { Colors.Red, Colors.Blue, Colors.Orange, Colors.Green, Colors.Yellow, C(170, 90, 200), C(60, 180, 190) }
local SHOP_NAMES = { "MODA", "TECH", "JUGUETES", "LIBROS", "DEPORTES", "ZAPATOS", "MUSICA", "CAFE" }

function Mall.Build(b)
	b:Box("Isla", V(420, 10, 360), V(0, -5.5, 0), Colors.Grass, M.Grass)
	b:Sea(-6)
	b:Box("Aparcamiento", V(300, 0.5, 70), V(0, -0.25, 110), Colors.Asphalt, M.Asphalt)
	for x = -135, 135, 15 do
		b:Box("PlazaAparcamiento", V(0.4, 0.1, 12), V(x, 0.02, 112), Colors.White, M.SmoothPlastic, { canCollide = false })
	end

	local mall = b:Group("Edificio")
	-- planta rectangular: x[-100,100], z[-80,80]. Atrio central x[-30,30], z[-30,30]
	local x1, x2, z1, z2 = -100, 100, -80, 80
	local floors = { 0, FLOOR_H, FLOOR_H * 2, FLOOR_H * 3 }
	local roofY = FLOOR_H * 4
	local atrium = { -30, 30, -30, 30 }

	-- ascensores de cristal en el lado norte del atrio, mirando a +Z hacia el atrio
	local elevL = { name = "AscensorCristalA", x = -14, z = -50, floors = floors, labels = { "PB", "1", "2", "3" }, glass = true }
	local elevR = { name = "AscensorCristalB", x = 14, z = -50, floors = floors, labels = { "PB", "1", "2", "3" }, glass = true }
	local hL, hR = Elevator.hole(elevL), Elevator.hole(elevR)
	-- escalera de la PB a la 1 y de la 1 a la 2 y de la 2 a la 3 en el lado sur
	local stairHoles = {
		{ -30, -2, 40, 48 },
		{ 2, 30, 56, 64 },
		{ -30, -2, 40, 48 },
	}

	mall:Slab("SueloPB", x1, x2, z1, z2, 0, 0.5, C(225, 225, 230), M.Marble, { hL, hR })
	for i = 2, 4 do
		local holes = { hL, hR, atrium }
		if i - 1 <= #stairHoles then
			holes[#holes + 1] = stairHoles[i - 1]
		end
		mall:Slab("Suelo" .. (i - 1), x1, x2, z1, z2, floors[i], 1.5, C(225, 225, 230), M.Marble, holes)
	end
	-- claraboya del atrio
	mall:Slab("Techo", x1 - 4, x2 + 4, z1 - 4, z2 + 4, roofY + 2, 2, Colors.DarkMetal, M.Metal, { { -28, 28, -28, 28 } })
	mall:Box("Claraboya", V(56, 0.6, 56), V(0, roofY + 1.5, 0), Colors.Glass, M.Glass, { transparency = 0.6 })

	-- muros exteriores con grandes cristaleras
	for i, y in ipairs(floors) do
		local top = y + FLOOR_H
		local function glassBand(a1, a2, skipFrom, skipTo)
			local list = {}
			local c = a1 + 7
			while c + 5 <= a2 do
				if not (skipFrom and c + 5 > skipFrom and c - 5 < skipTo) then
					list[#list + 1] = { from = c - 5, to = c + 5, bottom = 2, top = 13, glass = true }
				end
				c = c + 14
			end
			return list
		end
		local entrance = (i == 1) and { { from = -8, to = 8, bottom = 0, top = 11 } } or {}
		local frontList = glassBand(x1 + 2, x2 - 2, -8, 8)
		for _, e in ipairs(entrance) do
			frontList[#frontList + 1] = e
		end
		mall:Wall("FachadaSur" .. i, "x", z2, x1, x2, y, top, 1, C(235, 235, 240), M.Concrete, frontList)
		mall:Wall("FachadaNorte" .. i, "x", z1, x1, x2, y, top, 1, C(235, 235, 240), M.Concrete)
		mall:Wall("FachadaOeste" .. i, "z", x1, z1, z2, y, top, 1, C(235, 235, 240), M.Concrete, glassBand(z1 + 2, z2 - 2))
		mall:Wall("FachadaEste" .. i, "z", x2, z1, z2, y, top, 1, C(235, 235, 240), M.Concrete, glassBand(z1 + 2, z2 - 2))
	end
	mall:Board("Letrero", "GRAN CENTRO COMERCIAL", V(80, 7, 1), V(0, roofY + 8, z2 + 3), Colors.Red, C(255, 255, 255))

	-- barandillas de cristal alrededor del atrio en plantas 1-3
	for i = 2, 4 do
		local y = floors[i]
		mall:Wall("BarandillaN", "x", atrium[3], atrium[1], atrium[2], y, y + 4, 0.3, Colors.Glass, M.Glass, {})
		mall:Wall("BarandillaS", "x", atrium[4], atrium[1], atrium[2], y, y + 4, 0.3, Colors.Glass, M.Glass, {})
		mall:Wall("BarandillaO", "z", atrium[1], atrium[3], atrium[4], y, y + 4, 0.3, Colors.Glass, M.Glass, {})
		mall:Wall("BarandillaE", "z", atrium[2], atrium[3], atrium[4], y, y + 4, 0.3, Colors.Glass, M.Glass, {})
	end

	Elevator.build(mall, elevL)
	Elevator.build(mall, elevR)

	-- escaleras (cada tramo en su hueco)
	mall:Stairs("EscaleraPB", -30, 44, 0, FLOOR_H, 8, 28, "+x", C(210, 210, 215), M.Concrete)
	mall:Stairs("Escalera1", 30, 60, FLOOR_H, FLOOR_H * 2, 8, 28, "-x", C(210, 210, 215), M.Concrete)
	mall:Stairs("Escalera2", -30, 44, FLOOR_H * 2, FLOOR_H * 3, 8, 28, "+x", C(210, 210, 215), M.Concrete)

	-- fuente central en planta baja
	local fountain = mall:Group("Fuente")
	fountain:Pillar("Base", 0, 0, 0, 1.5, 22, Colors.Concrete, M.Marble)
	fountain:Pillar("Agua", 0, 0, 1.5, 1.8, 19, Colors.Water, M.SmoothPlastic)
	fountain:Pillar("Columna", 0, 0, 1.8, 8, 3, Colors.Concrete, M.Marble)
	fountain:Pillar("Cuenco", 0, 0, 8, 9, 10, Colors.Concrete, M.Marble)
	fountain:Ball("Esfera", 5, V(0, 11.5, 0), Colors.Glass, M.Glass)

	-- tiendas: bloques pegados a las paredes en cada planta (dejando libres ascensores y atrio)
	local shops = mall:Group("Tiendas")
	local n = 0
	for i, y in ipairs(floors) do
		local base = y
		local function shop(x, z, w, d, faceBack)
			n = n + 1
			local col = SHOP_COLORS[(n - 1) % #SHOP_COLORS + 1]
			local name = SHOP_NAMES[(n - 1) % #SHOP_NAMES + 1]
			shops:Box("Tienda", V(w, 3.5, d), V(x, base + 1.75, z), C(250, 250, 250), M.SmoothPlastic)
			shops:Box("Vitrina", V(w - 2, 5, 0.5), V(x, base + 6, z + (faceBack and -d / 2 or d / 2)), Colors.Glass, M.Glass, { transparency = 0.5 })
			shops:Board("Cartel", name, V(w - 1, 3, 0.5), V(x, base + 11, z + d / 2 + 0.3), col, C(255, 255, 255))
		end
		for k = 0, 3 do
			shop(-80 + k * 16, 70, 12, 8)
			shop(80 - k * 16, 70, 12, 8)
		end
		-- tiendas laterales (este y oeste)
		for k = 0, 2 do
			shop(-92, -10 + k * 22, 8, 14)
			shop(92, -10 + k * 22, 8, 14)
		end
	end

	-- bancos y plantas en cada planta
	local decor = mall:Group("Decoracion")
	for i, y in ipairs(floors) do
		local base = y
		for _, p in ipairs({ { -45, -20 }, { 45, -20 }, { -45, 20 }, { 45, 20 } }) do
			decor:Box("Banco", V(7, 1.2, 2), V(p[1], base + 0.6, p[2]), Colors.Wood, M.Wood)
			decor:Pillar("Maceta", p[1] + 6, p[2], base, base + 2, 2.6, Colors.Wood, M.Wood)
			decor:Ball("Planta", 4, V(p[1] + 6, base + 4, p[2]), Colors.Green, M.Grass)
		end
	end

	-- cine en la ultima planta (zona sur-oeste): sala con butacas y pantalla
	local cine = mall:Group("Cine")
	local cy = floors[4]
	cine:Box("Pantalla", V(26, 11, 0.6), V(-65, cy + 7.5, 47), C(240, 240, 255), M.SmoothPlastic)
	cine:Board("CartelCine", "CINE", V(8, 3, 0.4), V(-65, cy + 14, 20.7), Colors.DarkMetal, C(255, 220, 90))
	for row = 0, 4 do
		for col = 0, 5 do
			cine:Box("Butaca", V(3, 2, 2.4), V(-76 + col * 4.4, cy + 1 + row * 0.7, 20 + row * 4), Colors.Red, M.Fabric)
		end
	end

	-- aparcamiento: coches decorativos
	local cars = b:Group("Coches")
	for i = 0, 9 do
		local x = -135 + i * 30
		if i % 3 ~= 1 then
			cars:Box("Coche", V(5, 1.6, 10), V(x + 7.5, 1.4, 112), SHOP_COLORS[i % #SHOP_COLORS + 1], M.Metal)
			cars:Box("Cabina", V(4.2, 1.4, 5), V(x + 7.5, 2.9, 111), Colors.Glass, M.Glass, { transparency = 0.4 })
		end
	end

	-- arboles en la isla
	local trees = b:Group("Arboles")
	for i = 0, 11 do
		trees:Pine(-170 + i * 31, 160, 0, 1.2)
		trees:Pine(-170 + i * 31, -150, 0, 1.2)
	end

	-- puntos de aparicion: a la entrada, planta baja
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-50 + ix * 33, 1, 88 + iz * 14))
		end
	end
end

return Mall
]])

add("ServerStorage", { "IslasMapas", "Builders" }, "OilRig", "ModuleScript", [[
-- Plataforma petrolifera en mitad del mar: cubierta principal sobre 4 patas, torre de perforacion,
-- modulo de alojamiento, helipuerto y muelle. Un ascensor une muelle, cubierta, modulo y helipuerto.
-- Si caes al mar, mueres.

local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local OilRig = {
	Title = "Plataforma Petrolifera",
	Description = "Plataforma en alta mar con torre de perforacion, helipuerto y ascensor desde el muelle.",
	Lighting = { ClockTime = 19.5, Brightness = 2, FogEnd = 2500, FogColor = C(120, 130, 150) },
}

local DECK = 30
local STEEL = C(110, 115, 125)
local RUST = C(150, 90, 60)

function OilRig.Build(b)
	b:Sea(0, 2048, C(25, 70, 120), 0.1)
	-- pequeno islote de roca bajo la plataforma, solo decorativo
	b:Box("Roca", V(18, 14, 18), V(-52, -3, 52), C(90, 90, 95), M.Slate)

	local rig = b:Group("Plataforma")
	local half = 45

	-- patas y cruces
	local legs = rig:Group("Patas")
	for _, p in ipairs({ { -36, -36 }, { 36, -36 }, { -36, 36 }, { 36, 36 } }) do
		legs:Pillar("Pata", p[1], p[2], -30, DECK, 8, STEEL, M.Metal)
		legs:Pillar("Anillo", p[1], p[2], 2, 6, 9, Colors.Yellow, M.Metal)
	end
	for _, y in ipairs({ 8, 18 }) do
		legs:Box("CruceX1", V(72, 1.6, 1.6), V(0, y, -36), STEEL, M.Metal)
		legs:Box("CruceX2", V(72, 1.6, 1.6), V(0, y, 36), STEEL, M.Metal)
		legs:Box("CruceZ1", V(1.6, 1.6, 72), V(-36, y, 0), STEEL, M.Metal)
		legs:Box("CruceZ2", V(1.6, 1.6, 72), V(36, y, 0), STEEL, M.Metal)
	end

	-- cubierta principal
	local elev = { name = "AscensorPlataforma", x = 0, z = -34, floors = { 3, DECK, 44, 58 }, labels = { "M", "1", "2", "H" }, wallColor = RUST }
	local hole = Elevator.hole(elev)
	rig:Slab("Cubierta", -half, half, -half, half, DECK, 2, STEEL, M.DiamondPlate, { hole })
	for _, w in ipairs({ { "x", half, -half, half }, { "x", -half, -half, half }, { "z", half, -half, half }, { "z", -half, -half, half } }) do
		rig:Wall("Barandilla", w[1], w[2], w[3], w[4], DECK, DECK + 3.5, 0.3, Colors.Yellow, M.Metal, {
			{ from = w[3] + 1, to = w[4] - 1, bottom = 1.2, top = 3.5, glass = true },
		})
	end

	Elevator.build(rig, elev)

	-- muelle flotante a nivel del mar, delante del ascensor
	local pier = rig:Group("Muelle")
	pier:Slab("Embarcadero", -15, 15, -28, 5, 3, 2.5, Colors.Wood, M.Wood)
	for _, p in ipairs({ { -13, -26 }, { 13, -26 }, { -13, 3 }, { 13, 3 } }) do
		pier:Pillar("Poste", p[1], p[2], -12, 3.5, 1.4, Colors.Wood, M.Wood)
	end
	pier:Wall("BarandillaMuelle", "x", 5, -15, 15, 3, 6, 0.3, Colors.Yellow, M.Metal, { { from = -14, to = 14, bottom = 1.2, top = 3, glass = true } })
	pier:Pillar("PataAscensor1", -9, -34, -12, 2, 1.6, STEEL, M.Metal)
	pier:Pillar("PataAscensor2", 9, -34, -12, 2, 1.6, STEEL, M.Metal)
	-- bote amarrado
	pier:Box("Bote", V(8, 2.4, 18), V(24, 1.2, -10), Colors.Red, M.SmoothPlastic)
	pier:Box("CabinaBote", V(5, 3, 6), V(24, 3.9, -12), Colors.White, M.SmoothPlastic)
	pier:Slab("PasarelaBote", 15, 20, -12, -8, 3, 1, Colors.Wood, M.Wood)

	-- plataformas del ascensor: nivel 44 (modulo) y 58 (helipuerto)
	local up = rig:Group("NivelesSuperiores")
	up:Slab("Rellano44", -9, 9, -28, -12, 44, 1.5, STEEL, M.DiamondPlate)
	for _, p in ipairs({ { -8, -13 }, { 8, -13 } }) do
		up:Pillar("Soporte", p[1], p[2], DECK, 44, 1.6, STEEL, M.Metal)
	end
	up:Wall("BarandillaRellano", "x", -12, -9, 9, 44, 47.5, 0.3, Colors.Yellow, M.Metal, { { from = -8, to = 8, bottom = 1.2, top = 3.5, glass = true } })
	up:Slab("Helipuerto", -26, 26, -28, 18, 58, 1.5, C(70, 72, 78), M.Concrete)
	for _, p in ipairs({ { -24, 16 }, { 24, 16 }, { -24, -20 }, { 24, -20 } }) do
		up:Pillar("SoporteHeli", p[1], p[2], DECK, 58, 2, STEEL, M.Metal)
	end
	up:Pillar("CirculoHeli", 0, -5, 58, 58.2, 30, Colors.Yellow, M.SmoothPlastic)
	up:Pillar("CirculoHeli2", 0, -5, 58.2, 58.4, 26, C(70, 72, 78), M.Concrete)
	up:Board("H", "H", V(14, 0.2, 14), V(0, 58.6, -5), C(70, 72, 78), C(255, 255, 255), Enum.NormalId.Top)
	for _, p in ipairs({ { -25, -27 }, { 25, -27 }, { -25, 17 }, { 25, 17 } }) do
		up:Ball("LuzHeli", 1.6, V(p[1], 59.6, p[2]), Colors.Green, M.Neon)
	end
	-- helicoptero decorativo
	local heli = up:At(V(0, 59, -5), "Helicoptero")
	heli:Box("Fuselaje", V(4, 3.4, 9), V(0, 2.2, 0), Colors.Red, M.SmoothPlastic)
	heli:Box("Cristal", V(3.4, 2, 3), V(0, 2.6, 4.2), Colors.Glass, M.Glass, { transparency = 0.4 })
	heli:Box("Cola", V(1, 1, 7), V(0, 2.6, -7.5), Colors.Red, M.SmoothPlastic)
	heli:Box("Rotor", V(18, 0.2, 1), V(0, 4.3, 0), Colors.DarkMetal, M.Metal, { canCollide = false })
	heli:Box("PatinIzq", V(0.4, 0.4, 8), V(-1.8, 0.4, 0), Colors.DarkMetal, M.Metal)
	heli:Box("PatinDer", V(0.4, 0.4, 8), V(1.8, 0.4, 0), Colors.DarkMetal, M.Metal)

	-- torre de perforacion (se sube por una escalera de mano hasta una plataforma a 70)
	local derrick = rig:Group("TorrePerforacion")
	local dx, dz = 22, 22
	for _, p in ipairs({ { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } }) do
		derrick:Box("Montante", V(1.4, 56, 1.4), V(dx + p[1] * 0.5, DECK + 28, dz + p[2] * 0.5), Colors.Yellow, M.Metal, { rot = V(-p[2] * 0.4, 0, p[1] * 0.4) })
	end
	for y = DECK + 8, DECK + 48, 10 do
		local s = 12 - (y - DECK) * 0.17
		derrick:Box("TravesanoX", V(s, 0.8, 0.8), V(dx, y, dz - s / 2), Colors.Yellow, M.Metal)
		derrick:Box("TravesanoX", V(s, 0.8, 0.8), V(dx, y, dz + s / 2), Colors.Yellow, M.Metal)
		derrick:Box("TravesanoZ", V(0.8, 0.8, s), V(dx - s / 2, y, dz), Colors.Yellow, M.Metal)
		derrick:Box("TravesanoZ", V(0.8, 0.8, s), V(dx + s / 2, y, dz), Colors.Yellow, M.Metal)
	end
	derrick:Slab("PlataformaTorre", dx - 6, dx + 6, dz - 6, dz + 6, DECK + 40, 1, STEEL, M.DiamondPlate)
	derrick:Wall("BarandillaTorreN", "x", dz - 6, dx - 6, dx + 6, DECK + 40, DECK + 43.5, 0.3, Colors.Yellow, M.Metal, { { from = dx - 5.5, to = dx + 5.5, bottom = 1.2, top = 3.5, glass = true } })
	derrick:Ladder("EscalerillaTorre", dx, dz - 6.4, DECK, DECK + 41.5)
	derrick:Pillar("Tuberia", dx, dz, DECK, DECK + 40, 2, Colors.DarkMetal, M.Metal)
	derrick:Ball("LuzTorre", 2, V(dx, DECK + 58, dz), Colors.Red, M.Neon)

	-- modulo de alojamiento (planta baja de cubierta)
	local hab = rig:Group("Alojamiento")
	local mx1, mx2, mz1, mz2 = -42, -14, 8, 40
	hab:Wall("ModuloN", "x", mz1, mx1, mx2, DECK, DECK + 12, 0.8, C(230, 230, 235), M.Metal)
	hab:Wall("ModuloS", "x", mz2, mx1, mx2, DECK, DECK + 12, 0.8, C(230, 230, 235), M.Metal, Util.Windows(mx1 + 1, mx2 - 1, 7, 4, 4, 9))
	hab:Wall("ModuloO", "z", mx1, mz1, mz2, DECK, DECK + 12, 0.8, C(230, 230, 235), M.Metal, Util.Windows(mz1 + 1, mz2 - 1, 8, 4, 4, 9))
	hab:Wall("ModuloE", "z", mx2, mz1, mz2, DECK, DECK + 12, 0.8, C(230, 230, 235), M.Metal, { { from = 18, to = 24, bottom = 0, top = 8 } })
	hab:Slab("TechoModulo", mx1 - 1, mx2 + 1, mz1 - 1, mz2 + 1, DECK + 13, 1, STEEL, M.Metal)
	hab:Board("CartelModulo", "ALOJAMIENTO", V(16, 2.6, 0.4), V(-28, DECK + 10.5, mz2 + 0.6), Colors.Red, C(255, 255, 255))
	for i = 0, 2 do
		hab:Box("Litera", V(3, 1.4, 7), V(mx1 + 3 + i * 7, DECK + 2.7, mz1 + 5), Colors.Blue, M.Fabric)
		hab:Box("Litera", V(3, 1.4, 7), V(mx1 + 3 + i * 7, DECK + 2.7, mz2 - 5), Colors.Blue, M.Fabric)
	end

	-- depositos, contenedores, grua, antorcha
	local deco = rig:Group("Equipamiento")
	for i, p in ipairs({ { 30, -30 }, { 30, -8 } }) do
		deco:Pillar("Deposito", p[1], p[2], DECK, DECK + 14, 14, C(210, 210, 215), M.Metal)
		deco:Pillar("TapaDeposito", p[1], p[2], DECK + 14, DECK + 15, 15, Colors.Red, M.Metal)
	end
	local cols = { Colors.Red, Colors.Blue, Colors.Orange, Colors.Green, Colors.Yellow }
	for i = 0, 7 do
		local x = -34 + (i % 4) * 7.5
		local z = -6 + math.floor(i / 4) * 14
		deco:Box("Contenedor", V(7, 6, 12), V(x, DECK + 3, z), cols[i % #cols + 1], M.CorrodedMetal)
		if i % 3 == 0 then
			deco:Box("ContenedorApilado", V(7, 6, 12), V(x, DECK + 9, z), cols[(i + 2) % #cols + 1], M.CorrodedMetal)
		end
	end
	-- grua
	deco:Pillar("MastilGrua", 38, 2, DECK, DECK + 22, 3, Colors.Yellow, M.Metal)
	deco:Box("Pluma", V(36, 2, 2), V(24, DECK + 22.5, 2), Colors.Yellow, M.Metal)
	deco:Box("CableGrua", V(0.2, 12, 0.2), V(8, DECK + 16, 2), Colors.DarkMetal, M.Metal, { canCollide = false })
	-- antorcha
	deco:Pillar("TorreAntorcha", -40, -40, DECK, DECK + 46, 2, STEEL, M.Metal)
	deco:Ball("Llama", 5, V(-40, DECK + 49, -40), Colors.Orange, M.Neon)
	-- botes salvavidas
	for _, x in ipairs({ -20, 20 }) do
		deco:Box("Salvavidas", V(6, 3, 12), V(x, DECK + 2.5, 41), Colors.Orange, M.SmoothPlastic)
	end
	-- luces
	for _, p in ipairs({ { -44, -44 }, { 44, -44 }, { -44, 44 }, { 44, 44 } }) do
		deco:Pillar("PosteLuz", p[1], p[2], DECK, DECK + 9, 0.8, STEEL, M.Metal)
		local lamp = deco:Box("Foco", V(2, 1, 2), V(p[1], DECK + 9.5, p[2]), C(255, 245, 200), M.Neon, { canCollide = false })
		Util.AddLight(lamp, 40, 1.4)
	end

	-- puntos de aparicion en cubierta
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-4 + ix * 6, DECK + 1, -24 + iz * 8))
		end
	end
end

return OilRig
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
		tower:Box("PilarEsquina", V(2.4, STORY * (LEVELS - 1), 2.4), V(p[1], STORY * (LEVELS - 1) / 2, p[2]), Colors.DarkMetal, M.Metal)
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

add("ServerStorage", { "IslasMapas", "Lib" }, "Elevator", "ModuleScript", [[
-- Elevator: ascensor funcional por codigo.
--
-- Mira hacia +Z (la puerta esta en la cara +Z del hueco). Se llama desde un mapa asi:
--   Elevator.build(b, { name = "AscensorA", x = 0, z = -40, floors = { 0, 20, 40 } })
-- floors = alturas (Y) del suelo de cada planta, de menor a mayor.
--
-- Hueco interior: 12 (X) x 11 (Z). Los agujeros de los forjados de cada planta deben coincidir
-- con Elevator.hole(cfg), que devuelve {x1, x2, z1, z2}.

local TweenService = game:GetService("TweenService")

local Util = require(script.Parent.Util)
local V, C, M = Util.V, Util.C, Util.M

local Elevator = {}

local SHAFT_W, SHAFT_D = 12, 11 -- hueco interior
local CAB = 9 -- lado de la cabina
local DOOR_W, DOOR_H = 6, 8 -- hueco de la puerta
local WALL = 0.6
local SPEED = 14 -- studs por segundo

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
	local labels = cfg.labels or {}

	local function label(i)
		return labels[i] or tostring(i)
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
	-- panel sobre la puerta de cada planta (hasta la planta siguiente o el techo)
	for i = 1, count do
		local from = floors[i] + DOOR_H
		local to = floors[i + 1] or sTop
		if to > from then
			shaft:Box("PanelPuerta", V(DOOR_W, to - from, WALL), V(cx, (from + to) / 2, frontZ), wallColor, wallMat)
		end
		-- indicador de planta sobre la puerta
		if floors[i + 1] == nil or floors[i + 1] - from > 1.4 then
			shaft:Board("Indicador", label(i), V(2.2, 0.9, 0.2), V(cx, from + 0.7, frontZ + WALL / 2 + 0.1), Util.Colors.DarkMetal, C(120, 255, 140))
		end
	end

	-- ===== Cabina (se mueve como modelo) =====
	local cabin = b:Group(cfg.name .. "_Cabina", "Model")
	local cabZ = cz + 0.9 -- centro de la cabina: su frente queda casi a ras del borde del hueco
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
	-- frente de la cabina: pilares + dintel
	local cabPillar = (CAB + 0.8 - DOOR_W) / 2
	for _, side in ipairs({ -1, 1 }) do
		cabin:Box("PilarCabina", V(cabPillar, DOOR_H, 0.4), V(cx + side * (DOOR_W / 2 + cabPillar / 2), y0 + DOOR_H / 2, cabFront - 0.2), metal, M.Metal)
	end
	cabin:Box("DintelCabina", V(CAB + 0.8, CAB - DOOR_H, 0.4), V(cx, y0 + DOOR_H + (CAB - DOOR_H) / 2, cabFront - 0.2), metal, M.Metal)

	-- puertas de la cabina
	local doorW = DOOR_W / 2
	local cabDoors = {}
	for k, side in ipairs({ -1, 1 }) do
		cabDoors[k] = cabin:Box("PuertaCabina", V(doorW, DOOR_H, 0.3), V(cx + side * doorW / 2, y0 + DOOR_H / 2, cabFront + 0.15), C(200, 205, 210), M.Metal)
	end

	-- botonera interior (clic en cada numero). Dos o tres columnas si hay muchas plantas.
	cabin:Box("Botonera", V(0.2, 6.2, 2.9), V(cx - CAB / 2 + 0.05, y0 + 4.2, cabZ + 1.4), Util.Colors.DarkMetal, M.Metal)
	local rowsPerCol = 6
	local buttons = {}
	for i = 1, count do
		local col = math.floor((i - 1) / rowsPerCol)
		local row = (i - 1) % rowsPerCol
		local btn = cabin:Box("Boton" .. i, V(0.2, 0.8, 0.8), V(cx - CAB / 2 + 0.2, y0 + 1.6 + row * 0.95, cabZ + 2.3 - col * 0.95), C(40, 40, 45), M.SmoothPlastic)
		cabin:Sign(btn, label(i), Enum.NormalId.Right, C(255, 255, 255))
		local cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 14
		cd.Parent = btn
		buttons[i] = { part = btn, click = cd }
	end
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
		local pivot = cabin.parent:GetPivot()
		local cfv = Instance.new("CFrameValue")
		cfv.Value = pivot
		local conn = cfv.Changed:Connect(function(v)
			if st.alive then
				cabin.parent:PivotTo(v)
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
			task.wait(5)
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

	-- botones de llamada en cada planta (ProximityPrompt) y de cabina (ClickDetector)
	for i = 1, count do
		local call = shaft:Box("BotonLlamada", V(0.7, 1, 0.3), V(cx + DOOR_W / 2 + 1, floors[i] + 3.5, frontZ + WALL / 2 + 0.15), C(255, 190, 60), M.Neon)
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = "Llamar ascensor"
		pp.ObjectText = "Planta " .. label(i)
		pp.HoldDuration = 0
		pp.MaxActivationDistance = 8
		pp.RequiresLineOfSight = false
		pp.Parent = call
		pp.Triggered:Connect(function()
			request(i)
		end)
		buttons[i].click.MouseClick:Connect(function()
			request(i)
		end)
	end

	cabin.parent.Destroying:Connect(function()
		st.alive = false
	end)

	-- la planta inferior arranca con las puertas abiertas
	task.defer(function()
		request(1)
	end)

	return { Cabin = cabin.parent, Request = request }
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

local YIELD_EVERY = 80 -- cada tantas piezas se cede el hilo para no congelar el servidor

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
-- opts: shape, transparency, canCollide, rot (grados, Vector3), velocity, reflectance
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
	if s.count % YIELD_EVERY == 0 then
		task.wait()
	end
	return p
end

-- Columna vertical redonda
function Builder:Pillar(name, x, z, y1, y2, diameter, color, material)
	return self:Box(name, V(y2 - y1, diameter, diameter), V(x, (y1 + y2) / 2, z), color, material, {
		shape = Enum.PartType.Cylinder,
		rot = V(0, 0, 90),
	})
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
		self:Box(segName or name, size, pos, segColor or color, useMat, { transparency = transp })
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
		self:Box(
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

-- Escalera de mano (se trepa)
function Builder:Ladder(name, x, z, y1, y2)
	local t = Instance.new("TrussPart")
	t.Name = name
	t.Anchored = true
	t.Size = V(2, y2 - y1, 2)
	t.CFrame = CFrame.new(self.origin + V(x, (y1 + y2) / 2, z))
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
	})
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

add("ServerScriptService", { "IslasServer" }, "MapService", "ModuleScript", [[
-- MapService: construye un mapa SOLO cuando se necesita, teletransporta jugadores y lo borra despues.
-- Mientras un mapa no se ha votado no existe en el workspace, asi que no consume nada.
--
-- API:
--   MapService.GetMapNames()            -> lista de nombres de mapas disponibles
--   MapService.GetInfo(name)            -> { Name, Title, Description }
--   MapService.Load(name)               -> construye el mapa (bloquea hasta terminar)
--   MapService.TeleportToMap(players)   -> manda jugadores a los spawns del mapa cargado
--   MapService.ReturnToLobby(players)   -> los devuelve al lobby
--   MapService.Unload()                 -> destruye el mapa cargado y restaura la iluminacion

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Config"))
local MapsRoot = ServerStorage:WaitForChild("IslasMapas")
local Util = require(MapsRoot:WaitForChild("Lib"):WaitForChild("Util"))
local Builders = MapsRoot:WaitForChild("Builders")

local MapService = {}

local current = nil -- { Name, Folder, Spawns }
local savedLighting = nil
local savedGravity = nil
local lobbySpawns = nil

local LIGHT_PROPS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "FogColor", "FogStart", "FogEnd" }

local function getBuilder(name)
	local module = Builders:FindFirstChild(name)
	if not module then
		error("MapService: no existe el mapa '" .. tostring(name) .. "'")
	end
	return require(module)
end

function MapService.GetMapNames()
	local names = {}
	for _, child in ipairs(Builders:GetChildren()) do
		if child:IsA("ModuleScript") then
			names[#names + 1] = child.Name
		end
	end
	table.sort(names)
	return names
end

function MapService.GetInfo(name)
	local def = getBuilder(name)
	return { Name = name, Title = def.Title or name, Description = def.Description or "" }
end

local function applyLighting(settings)
	if not settings then
		return
	end
	if not savedLighting then
		savedLighting = {}
		for _, prop in ipairs(LIGHT_PROPS) do
			savedLighting[prop] = Lighting[prop]
		end
	end
	for prop, value in pairs(settings) do
		Lighting[prop] = value
	end
end

local function restoreLighting()
	if savedLighting then
		for prop, value in pairs(savedLighting) do
			Lighting[prop] = value
		end
		savedLighting = nil
	end
end

local function restoreGravity()
	if savedGravity then
		workspace.Gravity = savedGravity
		savedGravity = nil
	end
end

function MapService.Unload()
	if current then
		current.Folder:Destroy()
		current = nil
	end
	restoreLighting()
	restoreGravity()
end

function MapService.Load(name)
	MapService.Unload()
	local def = getBuilder(name)

	local folder = Instance.new("Folder")
	folder.Name = "MapaActual_" .. name
	local b = Util.newBuilder(folder, Config.MapOrigin)

	-- Se construye fuera del workspace y se cuelga al final: los clientes reciben la isla de una vez
	-- en lugar de ver aparecer piezas sueltas mientras se construye.
	local ok, err = pcall(def.Build, b)
	if not ok then
		folder:Destroy()
		error("MapService: fallo construyendo '" .. name .. "': " .. tostring(err), 0)
	end
	folder.Parent = workspace
	applyLighting(def.Lighting)
	if def.Gravity then
		savedGravity = workspace.Gravity
		workspace.Gravity = def.Gravity
	end

	current = { Name = name, Folder = folder, Spawns = b:Spawns() }
	return folder
end

function MapService.GetCurrent()
	return current
end

-- ===== Lobby =====

local function buildDefaultLobby()
	local folder = Instance.new("Folder")
	folder.Name = "LobbyPorDefecto"
	folder.Parent = workspace
	local b = Util.newBuilder(folder, Vector3.new(0, 0, 0))
	b:Box("SueloLobby", Vector3.new(80, 2, 80), Vector3.new(0, -1, 0), Util.Colors.Grass, Enum.Material.Grass)
	b:Board("CartelLobby", "LOBBY", Vector3.new(24, 8, 1), Vector3.new(0, 6, -36), Util.Colors.DarkMetal, Color3.new(1, 1, 1))
	local sp = b:Spawn(Vector3.new(0, 1, 0))
	return { sp }
end

local function findLobbySpawns()
	if lobbySpawns then
		return lobbySpawns
	end
	local found = {}
	local lobby = workspace:FindFirstChild("Lobby")
	local scope = lobby or workspace
	for _, inst in ipairs(scope:GetDescendants()) do
		if inst:IsA("SpawnLocation") then
			found[#found + 1] = inst
		end
	end
	if #found == 0 then
		found = buildDefaultLobby()
	end
	lobbySpawns = found
	return found
end

-- ===== Teletransporte =====

local function shuffled(list)
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.random(i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function moveTo(player, position)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	-- Con StreamingEnabled hay que pedir que se cargue la zona antes de llegar
	pcall(function()
		player:RequestStreamAroundAsync(position)
	end)
	char:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
	return true
end

local function teleport(list, spawns)
	if #spawns == 0 then
		warn("MapService: no hay puntos de aparicion")
		return
	end
	local order = shuffled(spawns)
	for i, player in ipairs(list) do
		local sp = order[(i - 1) % #order + 1]
		local jitter = Vector3.new(math.random(-10, 10) / 10, 0, math.random(-10, 10) / 10)
		task.spawn(moveTo, player, sp.Position + jitter)
	end
end

function MapService.TeleportToMap(list)
	if not current then
		warn("MapService: no hay ningun mapa cargado")
		return
	end
	teleport(list or Players:GetPlayers(), current.Spawns)
end

function MapService.ReturnToLobby(list)
	teleport(list or Players:GetPlayers(), findLobbySpawns())
end

return MapService
]])

add("ServerScriptService", { "IslasServer" }, "RoundLoop", "Script", [[
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
]])

add("ServerScriptService", { "IslasServer" }, "VoteService", "ModuleScript", [[
-- VoteService: votacion de mapa al terminar la ronda.
--   local winner = VoteService.Run(options, seconds)   -- options = { "Airport", "Mall", ... }
-- Bloquea hasta que acaba el tiempo y devuelve el nombre del mapa ganador.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapService = require(script.Parent.MapService)

local Remotes = ReplicatedStorage:WaitForChild("IslasRemotes")
local VoteOptions = Remotes:WaitForChild("VoteOptions") -- servidor -> clientes: {options, endTime}
local VoteUpdate = Remotes:WaitForChild("VoteUpdate") -- servidor -> clientes: {nombre = votos}
local VoteEnd = Remotes:WaitForChild("VoteEnd") -- servidor -> clientes: ganador
local CastVote = Remotes:WaitForChild("CastVote") -- cliente -> servidor: nombre

local VoteService = {}

local active = nil -- { options = set, votes = { [userId] = nombre } }

local function tally(options)
	local counts = {}
	for _, name in ipairs(options) do
		counts[name] = 0
	end
	for _, name in pairs(active.votes) do
		if counts[name] then
			counts[name] = counts[name] + 1
		end
	end
	return counts
end

CastVote.OnServerEvent:Connect(function(player, name)
	if not active or typeof(name) ~= "string" or not active.set[name] then
		return
	end
	active.votes[player.UserId] = name
	VoteUpdate:FireAllClients(tally(active.list))
end)

Players.PlayerRemoving:Connect(function(player)
	if active then
		active.votes[player.UserId] = nil
		VoteUpdate:FireAllClients(tally(active.list))
	end
end)

-- Elige `n` mapas distintos al azar
function VoteService.PickOptions(n)
	local names = MapService.GetMapNames()
	for i = #names, 2, -1 do
		local j = math.random(i)
		names[i], names[j] = names[j], names[i]
	end
	local picked = {}
	for i = 1, math.min(n, #names) do
		picked[i] = names[i]
	end
	return picked
end

function VoteService.Run(options, seconds)
	local set = {}
	local infos = {}
	for _, name in ipairs(options) do
		set[name] = true
		infos[#infos + 1] = MapService.GetInfo(name)
	end
	active = { set = set, list = options, votes = {} }

	local endTime = workspace:GetServerTimeNow() + seconds
	VoteOptions:FireAllClients(infos, endTime)
	VoteUpdate:FireAllClients(tally(options))

	task.wait(seconds)

	local counts = tally(options)
	local best, bestCount = {}, -1
	for _, name in ipairs(options) do
		if counts[name] > bestCount then
			best, bestCount = { name }, counts[name]
		elseif counts[name] == bestCount then
			best[#best + 1] = name
		end
	end
	local winner = best[math.random(#best)]

	active = nil
	VoteEnd:FireAllClients(winner)
	return winner
end

return VoteService
]])

add("StarterPlayerScripts", { "IslasClient" }, "VoteGui", "LocalScript", [[
-- VoteGui: pantalla de votacion y cuenta atras de la ronda (se crea por codigo, sin StarterGui).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("IslasRemotes")
local VoteOptions = Remotes:WaitForChild("VoteOptions")
local VoteUpdate = Remotes:WaitForChild("VoteUpdate")
local VoteEnd = Remotes:WaitForChild("VoteEnd")
local CastVote = Remotes:WaitForChild("CastVote")
local RoundStatus = Remotes:WaitForChild("RoundStatus")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "IslasGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- ===== Barra de estado (arriba) =====
local statusBar = Instance.new("TextLabel")
statusBar.Size = UDim2.new(0, 420, 0, 44)
statusBar.Position = UDim2.new(0.5, -210, 0, 12)
statusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
statusBar.BackgroundTransparency = 0.25
statusBar.TextColor3 = Color3.new(1, 1, 1)
statusBar.Font = Enum.Font.GothamBold
statusBar.TextSize = 20
statusBar.Text = ""
statusBar.Parent = gui
Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 10)

local statusText, statusEnd = "", nil
RoundStatus.OnClientEvent:Connect(function(text, endTime)
	statusText, statusEnd = text, endTime
	statusBar.Text = text
end)

-- ===== Panel de votacion (centro) =====
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 560, 0, 250)
panel.Position = UDim2.new(0.5, -280, 0.5, -125)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.1
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Vota el siguiente mapa"
title.Parent = panel

local cards = Instance.new("Frame")
cards.Size = UDim2.new(1, -20, 1, -56)
cards.Position = UDim2.new(0, 10, 0, 46)
cards.BackgroundTransparency = 1
cards.Parent = panel
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 10)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = cards

local voteEnd = nil
local countLabels, buttons = {}, {}
local myVote = nil
local titles = {}

local function clearCards()
	for _, child in ipairs(cards:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	countLabels, buttons, myVote = {}, {}, nil
end

local function refreshHighlight()
	for name, btn in pairs(buttons) do
		btn.BackgroundColor3 = (name == myVote) and Color3.fromRGB(60, 130, 80) or Color3.fromRGB(45, 48, 64)
	end
end

VoteOptions.OnClientEvent:Connect(function(infos, endTime)
	clearCards()
	voteEnd = endTime
	titles = {}
	local width = (540 - 10 * (#infos - 1)) / #infos
	for _, info in ipairs(infos) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, width, 1, 0)
		btn.BackgroundColor3 = Color3.fromRGB(45, 48, 64)
		btn.AutoButtonColor = true
		btn.Text = ""
		btn.Parent = cards
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -10, 0, 34)
		name.Position = UDim2.new(0, 5, 0, 8)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextSize = 20
		name.TextWrapped = true
		name.TextColor3 = Color3.new(1, 1, 1)
		name.Text = info.Title
		name.Parent = btn

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -14, 1, -90)
		desc.Position = UDim2.new(0, 7, 0, 44)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextSize = 14
		desc.TextWrapped = true
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.TextColor3 = Color3.fromRGB(200, 205, 220)
		desc.Text = info.Description
		desc.Parent = btn

		local count = Instance.new("TextLabel")
		count.Size = UDim2.new(1, 0, 0, 30)
		count.Position = UDim2.new(0, 0, 1, -34)
		count.BackgroundTransparency = 1
		count.Font = Enum.Font.GothamBold
		count.TextSize = 20
		count.TextColor3 = Color3.fromRGB(255, 220, 90)
		count.Text = "0 votos"
		count.Parent = btn

		titles[info.Name] = info.Title
		buttons[info.Name] = btn
		countLabels[info.Name] = count
		btn.Activated:Connect(function()
			myVote = info.Name
			refreshHighlight()
			CastVote:FireServer(info.Name)
		end)
	end
	refreshHighlight()
	panel.Visible = true
end)

VoteUpdate.OnClientEvent:Connect(function(counts)
	for name, label in pairs(countLabels) do
		local n = counts[name] or 0
		label.Text = n .. (n == 1 and " voto" or " votos")
	end
end)

VoteEnd.OnClientEvent:Connect(function(winner)
	voteEnd = nil
	title.Text = "Ganador: " .. tostring(titles[winner] or winner)
	task.delay(2, function()
		panel.Visible = false
		title.Text = "Vota el siguiente mapa"
	end)
end)

-- cuenta atras
RunService.Heartbeat:Connect(function()
	if voteEnd then
		title.Text = "Vota el siguiente mapa (" .. math.max(0, math.ceil(voteEnd - workspace:GetServerTimeNow())) .. ")"
	end
	if statusEnd then
		local left = math.max(0, math.ceil(statusEnd - workspace:GetServerTimeNow()))
		statusBar.Text = statusText .. " " .. left .. "s"
	end
end)
]])

print("Islas de Desastres instalado: 12 scripts. Dale a Play para probar.")
