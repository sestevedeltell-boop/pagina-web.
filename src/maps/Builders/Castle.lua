-- Castillo: murallas almenadas con cuatro torres, foso con puente levadizo, patio con pozo y mercado,
-- y la torre del homenaje de 3 plantas con montacargas (ascensor) hasta la azotea.
local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Buildings = require(Lib.Buildings)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local Castle = {
	Title = "Castillo",
	Description = "Murallas, torres, foso con puente levadizo, mercado y torre del homenaje con montacargas.",
	Lighting = { ClockTime = 16.5, Brightness = 1.8 },
	Bounds = { x1 = -110, x2 = 110, z1 = -110, z2 = 130, top = 110, floor = 0 },
	Disasters = { "Earthquake", "Fire", "Meteors", "Lightning", "Tornado", "Volcano", "Flood", "Virus", "Blizzard", "UFO" },
	DisasterConfig = { Flood = { maxHeight = 20 } },
}

local STONE = C(150, 145, 135)
local DARK_STONE = C(110, 105, 98)

local function crenellatedWall(b, axis, fixed, a1, a2, h, th)
	b:Wall("Muralla", axis, fixed, a1, a2, 0, h, th, STONE, M.Cobblestone)
	-- almenas
	local step = 4
	local a = a1 + 1
	while a + 2 <= a2 do
		local pos = axis == "x" and V(a + 1, h + 1.5, fixed) or V(fixed, h + 1.5, a + 1)
		local size = axis == "x" and V(2, 3, th) or V(th, 3, 2)
		b:Box("Almena", size, pos, STONE, M.Cobblestone)
		a = a + step
	end
	-- adarve (pasillo encima de la muralla)
	local mid = (a1 + a2) / 2
	local len = a2 - a1
	local walk = axis == "x" and V(len, 1, 5) or V(5, 1, len)
	local wpos = axis == "x" and V(mid, h - 0.5, fixed + (fixed < 0 and 3 or -3)) or V(fixed + (fixed < 0 and 3 or -3), h - 0.5, mid)
	b:Box("Adarve", walk, wpos, DARK_STONE, M.Slate)
end

function Castle.Build(b)
	b:Box("Isla", V(320, 10, 340), V(0, -5.5, 10), Colors.Grass, M.Grass, { indestructible = true })
	b:Sea(-6)
	-- foso
	b:Box("Foso", V(200, 0.6, 10), V(0, -0.2, 92), Colors.Water, M.SmoothPlastic, { transparency = 0.2, canCollide = false, indestructible = true })

	local castle = b:Group("Castillo")
	local half, H = 80, 18
	castle:Slab("Patio", -half, half, -half, half, 0.3, 0.3, C(170, 160, 140), M.Pebble)
	crenellatedWall(castle, "x", -half, -half, half, H, 3)
	crenellatedWall(castle, "z", -half, -half, half, H, 3)
	crenellatedWall(castle, "z", half, -half, half, H, 3)
	-- muralla frontal con puerta
	castle:Wall("Muralla", "x", half, -half, half, 0, H, 3, STONE, M.Cobblestone, { { from = -8, to = 8, bottom = 0, top = 12 } })
	castle:Box("Puente", V(16, 1, 14), V(0, 0.5, 92), C(120, 85, 55), M.WoodPlanks)
	castle:Box("Rastrillo", V(16, 0.6, 1), V(0, 15, half + 2), Colors.DarkMetal, M.Metal)
	-- escaleras para subir al adarve
	castle:Stairs("EscaleraMuralla", -half + 8, half - 8, 0, H - 0.5, 6, 22, "-z", DARK_STONE, M.Slate)
	castle:Stairs("EscaleraMuralla", half - 8, -half + 8, 0, H - 0.5, 6, 22, "+z", DARK_STONE, M.Slate)

	-- torres de esquina
	for _, p in ipairs({ { -half, -half }, { half, -half }, { -half, half }, { half, half } }) do
		castle:Pillar("TorreEsquina", p[1], p[2], 0, 30, 16, STONE, M.Cobblestone)
		castle:Pillar("CoronaTorre", p[1], p[2], 30, 33, 18, DARK_STONE, M.Cobblestone)
		castle:Box("Bandera", V(0.3, 6, 4), V(p[1], 38, p[2] + 2), Colors.Red, M.Fabric)
		castle:Pillar("Mastil", p[1], p[2], 33, 41, 0.4, Colors.Wood, M.Wood)
	end

	-- torre del homenaje (3 plantas) con montacargas
	local keep = b:Group("TorreHomenaje")
	local x1, x2, z1, z2 = -30, 30, -70, -20
	local levels = { 0, 16, 32, 48 }
	local lift = { name = "Montacargas", x = 0, z = z1 + 6.4, floors = levels, labels = { "PB", "1", "2", "A" }, wallColor = DARK_STONE, wallMaterial = M.Cobblestone }
	local hole = Elevator.hole(lift)
	local stairHoles = { { 12, 28, z2 - 9, z2 - 3 }, { 12, 28, z2 - 15, z2 - 9 }, { 12, 28, z2 - 9, z2 - 3 } }
	for i, y in ipairs(levels) do
		local holes = { hole }
		if i > 1 then
			holes[#holes + 1] = stairHoles[i - 1]
		end
		keep:Slab("Planta", x1, x2, z1, z2, y + (i == 1 and 0.4 or 0), 1.2, C(120, 90, 60), M.WoodPlanks, holes)
	end
	for i = 1, 3 do
		local y = levels[i]
		local front = Util.Windows(x1 + 1, x2 - 1, 10, 3, 6, 12)
		if i == 1 then
			front = Util.Windows(x1 + 1, x2 - 1, 10, 3, 6, 12, -6, 6)
			front[#front + 1] = { from = -5, to = 5, bottom = 0, top = 10 }
		end
		keep:Wall("Muro", "x", z2, x1, x2, y, y + 16, 2, STONE, M.Cobblestone, front)
		keep:Wall("Muro", "x", z1, x1, x2, y, y + 16, 2, STONE, M.Cobblestone)
		keep:Wall("Muro", "z", x1, z1, z2, y, y + 16, 2, STONE, M.Cobblestone, Util.Windows(z1 + 1, z2 - 1, 10, 3, 6, 12))
		keep:Wall("Muro", "z", x2, z1, z2, y, y + 16, 2, STONE, M.Cobblestone, Util.Windows(z1 + 1, z2 - 1, 10, 3, 6, 12))
		if i % 2 == 1 then
			keep:Stairs("Escalera", 12, z2 - 6, y, y + 16, 6, 16, "+x", DARK_STONE, M.Slate)
		else
			keep:Stairs("Escalera", 28, z2 - 12, y, y + 16, 6, 16, "-x", DARK_STONE, M.Slate)
		end
	end
	Elevator.build(keep, lift)
	-- salon del trono
	keep:Box("Alfombra", V(6, 0.2, 30), V(-14, 0.6, -45), C(160, 30, 40), M.Fabric)
	keep:Box("Trono", V(5, 7, 4), V(-14, 3.5, -62), C(200, 160, 40), M.Wood)
	keep:Box("Mesa", V(16, 3, 5), V(-14, 17.5, -45), Colors.Wood, M.Wood)
	for k = 0, 3 do
		keep:Box("Barril", V(3, 4, 3), V(-24 + k * 4, 34, -60), C(120, 80, 40), M.Wood)
	end
	-- almenas de la azotea
	for k = 0, 14 do
		keep:Box("AlmenaTorre", V(2, 3, 2), V(x1 + 2 + k * 4, 49.5, z2 - 1), STONE, M.Cobblestone)
		keep:Box("AlmenaTorre", V(2, 3, 2), V(x1 + 2 + k * 4, 49.5, z1 + 1), STONE, M.Cobblestone)
	end

	-- patio: pozo y mercado (madera: arde)
	local yard = b:Group("Patio")
	yard:Pillar("Pozo", 40, 30, 0.3, 3, 6, STONE, M.Cobblestone)
	yard:Pillar("AguaPozo", 40, 30, 2.6, 2.8, 4.6, Colors.Water, M.SmoothPlastic)
	yard:Box("TejadoPozo", V(8, 0.6, 8), V(40, 8, 30), Colors.Wood, M.WoodPlanks)
	for _, x in ipairs({ 36.5, 43.5 }) do
		yard:Box("PostePozo", V(0.6, 5, 0.6), V(x, 5.5, 30), Colors.Wood, M.Wood)
	end
	local stallColors = { Colors.Red, Colors.Blue, Colors.Yellow, Colors.Green }
	for k = 0, 3 do
		local x = -60 + k * 18
		yard:Box("Puesto", V(10, 3.5, 5), V(x, 2, 40), Colors.Wood, M.Wood)
		yard:Box("Toldo", V(12, 0.4, 8), V(x, 8, 41), stallColors[k + 1], M.Fabric)
		for _, sx in ipairs({ -5, 5 }) do
			yard:Box("PostePuesto", V(0.5, 8, 0.5), V(x + sx, 4, 44), Colors.Wood, M.Wood)
		end
		yard:Box("Mercancia", V(3, 1.5, 2), V(x, 4.5, 40), C(200, 120, 60), M.Fabric)
	end
	-- establos y heno
	yard:Box("Establo", V(26, 10, 14), V(55, 5, -40), C(140, 90, 55), M.WoodPlanks)
	for k = 0, 4 do
		yard:Box("Heno", V(3, 2.5, 3), V(48 + k * 3.5, 1.5, -28), C(220, 190, 90), M.Grass)
	end

	-- bosque alrededor
	local trees = b:Group("Bosque")
	for i = 0, 19 do
		local a = i / 20 * math.pi * 2
		trees:Pine(math.cos(a) * 125, 10 + math.sin(a) * 125, 0, 1.5)
	end

	-- aparicion: en el patio
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-30 + ix * 20, 1.3, -4 + iz * 12))
		end
	end
end

return Castle
