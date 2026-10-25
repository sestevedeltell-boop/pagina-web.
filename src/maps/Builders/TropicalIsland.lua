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
