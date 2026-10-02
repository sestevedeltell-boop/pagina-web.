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
	Disasters = { "Meteors", "Fire", "Earthquake", "Radiation" },
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
