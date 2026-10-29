-- Pueblo del Oeste: calle principal con saloon de 2 plantas, banco, sheriff, tienda y herreria de madera,
-- deposito de agua, molino de viento, carretas, cactus y una mina con ascensor hasta lo alto de la meseta.
local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Buildings = require(Lib.Buildings)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local WildWest = {
	Title = "Pueblo del Oeste",
	Description = "Saloon, banco, sheriff, carretas y una mina con ascensor hasta lo alto de la meseta.",
	Lighting = { ClockTime = 17.2, Brightness = 2.4, OutdoorAmbient = C(190, 150, 110) },
	Bounds = { x1 = -150, x2 = 150, z1 = -150, z2 = 150, top = 100, floor = 0 },
	Disasters = { "Sandstorm", "Tornado", "Fire", "Meteors", "Earthquake", "Lightning", "UFO", "Flood", "Volcano", "Hail", "Virus" },
	DisasterConfig = { Flood = { maxHeight = 16 } },
}

local SAND = C(220, 180, 120)
local WOODS = { C(150, 100, 60), C(130, 85, 50), C(170, 120, 75), C(120, 80, 55), C(160, 110, 70) }

function WildWest.Build(b)
	b:Box("Isla", V(330, 10, 330), V(0, -5.5, 0), SAND, M.Sand, { indestructible = true })
	b:Sea(-6, 2048, C(60, 130, 170))

	-- meseta (terreno indestructible) con mina y ascensor
	b:Box("Meseta", V(120, 40, 60), V(0, 20, -115), C(185, 110, 70), M.Sandstone, { indestructible = true })
	b:Box("EntradaMina", V(10, 10, 2), V(-30, 5, -84.5), C(40, 30, 25), M.Slate, { indestructible = true })
	Buildings.LiftTower(b, 30, -78.6, { 0, 20, 40 }, { name = "MinaAscensor", labels = { "PB", "1", "Meseta" }, color = C(120, 85, 55), material = M.WoodPlanks })
	b:Board("CartelMina", "MINA DE ORO", V(14, 3, 0.4), V(-30, 12, -83.3), C(40, 30, 25), C(255, 210, 80))

	-- calle principal: edificios a los dos lados
	local names = { "SALOON", "BANCO", "SHERIFF", "TIENDA", "HERRERIA", "HOTEL" }
	for i = 0, 5 do
		local side = (i % 2 == 0) and -1 or 1
		local cz = -40 + math.floor(i / 2) * 40
		local cx = side * 40
		local floors = (i == 0 or i == 5) and 2 or 1
		Buildings.House(b, cx, cz, 26, 22, floors, { name = names[i + 1], color = WOODS[i % #WOODS + 1], material = M.WoodPlanks, roof = "flat", roofColor = C(90, 60, 40) })
		-- fachada falsa tipica del oeste
		local fz = cz + side * -11.4
		b:Box("Fachada", V(26, 6, 0.6), V(cx, floors * 12 + 3, cz + 11.4), WOODS[(i + 2) % #WOODS + 1], M.WoodPlanks)
		b:Board("Rotulo", names[i + 1], V(18, 3, 0.4), V(cx, floors * 12 + 3, cz + 11.8), C(60, 40, 25), C(255, 230, 170))
		b:Box("Porche", V(26, 0.5, 6), V(cx, 0.25, cz + 14), C(120, 80, 50), M.WoodPlanks)
		local _ = fz
	end

	-- deposito de agua y molino
	for _, p in ipairs({ { 95, 60 }, { 105, 60 }, { 95, 70 }, { 105, 70 } }) do
		b:Pillar("PataDeposito", p[1], p[2], 0, 22, 1, Colors.Wood, M.Wood)
	end
	b:Pillar("Deposito", 100, 65, 22, 32, 14, C(140, 95, 60), M.WoodPlanks)
	b:Pillar("TorreMolino", -100, 70, 0, 26, 2, Colors.DarkMetal, M.Metal)
	local wheel = b:Group("RuedaMolino", "Model")
	for i = 0, 7 do
		local a = i * 45
		wheel:Box("Pala", V(7, 1.5, 0.2), V(-100 + math.cos(math.rad(a)) * 3.5, 26 + math.sin(math.rad(a)) * 3.5, 71.5), C(200, 200, 205), M.Metal, { rot = V(0, 0, a) })
	end
	b:Spin(wheel.parent, 30, "Z")

	-- carretas, barriles y cactus
	for i, p in ipairs({ { -10, 10 }, { 12, 50 } }) do
		local w = b:At(V(p[1], 0, p[2]), "Carreta" .. i)
		w:Box("Caja", V(5, 3, 10), V(0, 3, 0), C(140, 95, 60), M.WoodPlanks)
		w:Box("Lona", V(5.4, 4, 8), V(0, 6.5, 0), C(240, 235, 220), M.Fabric)
		for _, z in ipairs({ -3.5, 3.5 }) do
			w:Box("Rueda", V(0.6, 4, 4), V(-2.8, 2, z), C(90, 60, 40), M.Wood, { shape = Enum.PartType.Cylinder })
			w:Box("Rueda", V(0.6, 4, 4), V(2.8, 2, z), C(90, 60, 40), M.Wood, { shape = Enum.PartType.Cylinder })
		end
	end
	for k = 0, 9 do
		b:Pillar("Barril", -20 + (k % 5) * 2.4, -10 + math.floor(k / 5) * 2.4, 0, 3, 2, C(120, 80, 45), M.Wood)
	end
	for i = 0, 15 do
		local a = i * 2.39996
		local r = 90 + (i % 4) * 12
		local x, z = math.cos(a) * r, math.sin(a) * r
		if z > -70 then
			b:Pillar("Cactus", x, z, 0, 9, 2, C(70, 130, 60), M.Grass)
			b:Pillar("BrazoCactus", x + 1.8, z, 4, 7, 1.2, C(70, 130, 60), M.Grass)
		end
	end

	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-12 + ix * 8, 1, -20 + iz * 20))
		end
	end
end

return WildWest
