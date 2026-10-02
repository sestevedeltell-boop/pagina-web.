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
