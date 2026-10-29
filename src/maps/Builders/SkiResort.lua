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
	Disasters = { "Blizzard", "Earthquake", "Lightning", "Meteors", "Tornado", "Fire", "Volcano", "UFO", "AcidRain", "Virus", "Avalanche", "Hail" },
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
