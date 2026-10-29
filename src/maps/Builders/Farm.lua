-- Granja: granero de dos plantas, casa de campo, molino que gira, silo con ascensor de grano, campos de
-- cultivo, balas de heno, tractor, estanque y vallas. Casi todo es madera: arde muy bien.
local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Buildings = require(Lib.Buildings)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local Farm = {
	Title = "Granja",
	Description = "Granero, casa de campo, molino, silo con ascensor, campos y tractores. Casi todo arde.",
	Lighting = { ClockTime = 9.5, Brightness = 2.2, OutdoorAmbient = C(170, 160, 130) },
	Bounds = { x1 = -150, x2 = 150, z1 = -150, z2 = 150, top = 90, floor = 0 },
	Disasters = { "Tornado", "Fire", "Meteors", "Flood", "Lightning", "Earthquake", "AcidRain", "Hail", "UFO", "Sandstorm", "Virus", "Avalanche" },
	DisasterConfig = { Flood = { maxHeight = 18 } },
}

local BARN_RED = C(170, 45, 40)

function Farm.Build(b)
	b:Box("Isla", V(330, 10, 330), V(0, -5.5, 0), C(105, 150, 70), M.Grass, { indestructible = true })
	b:Sea(-6)

	-- campos de cultivo
	local fields = b:Group("Campos")
	for i = 0, 5 do
		local x = -120 + i * 16
		fields:Box("Surco", V(12, 0.6, 90), V(x, 0.1, 70), C(110, 75, 45), M.Ground, { indestructible = true })
		for k = 0, 8 do
			local crop = (i % 2 == 0) and C(230, 200, 70) or C(80, 160, 60)
			fields:Box("Cultivo", V(3, 2.5, 3), V(x, 1.6, 30 + k * 10), crop, M.Grass)
		end
	end

	-- granero (2 plantas, madera roja)
	Buildings.House(b, 40, -40, 40, 30, 2, { name = "Granero", color = BARN_RED, material = M.WoodPlanks, roofColor = C(90, 80, 75), story = 14, furnish = false })
	b:Board("CartelGranero", "GRANJA LA ESPIGA", V(22, 3.5, 0.4), V(40, 12, -24.4), C(250, 240, 220), BARN_RED)
	for k = 0, 7 do
		b:Box("Heno", V(4, 3, 4), V(26 + (k % 4) * 5, 1.5 + math.floor(k / 4) * 3, -48), C(225, 195, 95), M.Grass)
	end
	for k = 0, 3 do
		b:Box("HenoArriba", V(4, 3, 4), V(30 + k * 5, 15.5, -48), C(225, 195, 95), M.Grass)
	end

	-- casa de campo
	Buildings.House(b, -50, -60, 28, 22, 2, { name = "CasaCampo", color = C(240, 230, 200), roofColor = C(80, 60, 50) })
	b:Box("Porche", V(28, 0.6, 8), V(-50, 0.3, -45), Colors.Wood, M.WoodPlanks)

	-- silo con ascensor de grano
	b:Pillar("Silo", 95, -95, 0, 46, 22, C(200, 200, 205), M.Metal)
	b:Ball("CupulaSilo", 22, V(95, 46, -95), C(170, 175, 180), M.Metal)
	Buildings.LiftTower(b, 95, -70, { 0, 22, 44 }, { name = "ElevadorGrano", labels = { "PB", "1", "2" }, color = C(150, 150, 155), material = M.CorrodedMetal })

	-- molino que gira
	b:Pillar("TorreMolino", -100, 40, 0, 30, 7, C(230, 225, 210), M.Brick)
	b:Wedge("TejadoMolino", V(8, 5, 8), V(-100, 32.5, 40), C(120, 70, 50), M.Slate, 0)
	local blades = b:Group("Aspas", "Model")
	for i = 0, 3 do
		local a = i * 90
		blades:Box("Aspa", V(24, 2.5, 0.4), V(-100 + math.cos(math.rad(a)) * 12, 30 + math.sin(math.rad(a)) * 12, 44.2), C(245, 240, 225), M.WoodPlanks, { rot = V(0, 0, a) })
	end
	blades:Pillar("EjeMolino", -100, 44, 29.4, 30.6, 2, Colors.DarkMetal, M.Metal)
	b:Spin(blades.parent, 6, "Z")

	-- tractor
	local tractor = b:At(V(0, 0, -10), "Tractor")
	tractor:Box("Cuerpo", V(6, 3, 9), V(0, 3, 0), C(60, 150, 60), M.Metal)
	tractor:Box("CabinaTractor", V(5, 4, 4), V(0, 6.5, -2), Colors.Glass, M.Glass, { transparency = 0.4 })
	for _, p in ipairs({ { -3.5, -3, 4.5 }, { 3.5, -3, 4.5 }, { -3.2, 3.5, 2.6 }, { 3.2, 3.5, 2.6 } }) do
		tractor:Box("Rueda", V(1.2, p[3], p[3]), V(p[1], p[3] / 2, p[2]), C(25, 25, 25), M.Rubber, { shape = Enum.PartType.Cylinder })
	end

	-- estanque y vallas
	b:Pillar("Estanque", 60, 60, 0, 0.3, 40, Colors.Water, M.SmoothPlastic)
	for i = 0, 18 do
		b:Box("Valla", V(8, 3, 0.5), V(-140 + i * 8, 1.5, 120), Colors.Wood, M.WoodPlanks)
	end
	for i = 0, 9 do
		b:Pine(130, -130 + i * 26, 0, 1.3)
	end
	-- gallinero
	Buildings.House(b, -10, -100, 14, 10, 1, { name = "Gallinero", color = C(200, 170, 120), material = M.WoodPlanks, furnish = false })

	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-30 + ix * 12, 1, -10 + iz * 12))
		end
	end
end

return Farm
