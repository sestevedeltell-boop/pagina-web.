-- Escuela: edificio de 3 plantas con ascensor y escaleras, aulas con pupitres, gimnasio, patio con
-- columpios y tobogan, pista de baloncesto y autobus escolar.
local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Buildings = require(Lib.Buildings)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local School = {
	Title = "Escuela",
	Description = "Colegio de 3 plantas con ascensor, gimnasio, patio con columpios y pista de baloncesto.",
	Lighting = { ClockTime = 12, Brightness = 2 },
	Bounds = { x1 = -150, x2 = 150, z1 = -150, z2 = 150, top = 100, floor = 0 },
	Disasters = { "Earthquake", "Fire", "Meteors", "Tornado", "Flood", "Lightning", "AcidRain", "Hail", "Virus", "BlackHole", "Tsunami", "Avalanche" },
	DisasterConfig = { Flood = { maxHeight = 20 } },
}

function School.Build(b)
	b:Box("Isla", V(330, 10, 330), V(0, -5.5, 0), Colors.Grass, M.Grass, { indestructible = true })
	b:Sea(-6)
	b:Box("Patio", V(160, 0.4, 70), V(0, -0.1, 50), C(190, 185, 175), M.Pavement, { indestructible = true })

	-- edificio principal con ascensor
	local levels = Buildings.Tower(b, 0, -40, 60, 40, 3, { name = "Colegio", story = 13, color = C(235, 200, 150) })
	b:Board("CartelColegio", "COLEGIO SAN DESASTRE", V(36, 4, 0.4), V(0, 34, -19.4), C(40, 80, 140), Colors.White)
	-- pupitres en cada planta
	local desks = b:Group("Aulas")
	for i = 1, 3 do
		local y = levels[i]
		for row = 0, 2 do
			for col = 0, 3 do
				local x, z = -24 + col * 6, -44 + row * 6
				desks:Box("Pupitre", V(3.5, 0.4, 2.4), V(x, y + 2.6, z), Colors.Wood, M.Wood)
				desks:Box("PataPupitre", V(0.4, 2.4, 0.4), V(x, y + 1.3, z), Colors.DarkMetal, M.Metal)
				desks:Box("Silla", V(1.6, 1.4, 1.6), V(x, y + 0.9, z + 2), C(60, 110, 200), M.Plastic)
			end
		end
		desks:Board("Pizarra", "2 + 2 = ¡CORRE!", V(14, 5, 0.3), V(-22, y + 6, -59.2), C(30, 70, 40), Colors.White)
	end

	-- gimnasio
	local gym = b:Group("Gimnasio")
	local gx1, gx2, gz1, gz2 = 45, 105, -60, -10
	gym:Slab("SueloGimnasio", gx1, gx2, gz1, gz2, 0.4, 0.4, C(200, 150, 90), M.WoodPlanks)
	gym:Wall("Pared", "x", gz2, gx1, gx2, 0, 18, 1, C(220, 220, 225), M.Concrete, { { from = 70, to = 80, bottom = 0, top = 10 } })
	gym:Wall("Pared", "x", gz1, gx1, gx2, 0, 18, 1, C(220, 220, 225), M.Concrete, Util.Windows(gx1 + 1, gx2 - 1, 10, 6, 11, 16))
	gym:Wall("Pared", "z", gx1, gz1, gz2, 0, 18, 1, C(220, 220, 225), M.Concrete)
	gym:Wall("Pared", "z", gx2, gz1, gz2, 0, 18, 1, C(220, 220, 225), M.Concrete, Util.Windows(gz1 + 1, gz2 - 1, 10, 6, 11, 16))
	gym:Slab("TechoGimnasio", gx1 - 1, gx2 + 1, gz1 - 1, gz2 + 1, 19, 1, C(120, 120, 130), M.Metal)
	gym:Box("Canasta", V(0.4, 4, 6), V(gx1 + 2, 10, -35), Colors.White, M.Plastic)
	gym:Box("Canasta", V(0.4, 4, 6), V(gx2 - 2, 10, -35), Colors.White, M.Plastic)
	for k = 0, 2 do
		gym:Box("Grada", V(30, 1 + k, 3), V(75, 0.5 + k / 2, gz1 + 2 + k * 3), Colors.Wood, M.WoodPlanks)
	end

	-- patio: columpios, tobogan, pista
	local play = b:Group("Parque")
	for _, x in ipairs({ -60, -48 }) do
		play:Box("PosteColumpio", V(0.6, 10, 0.6), V(x, 5, 40), Colors.Red, M.Metal)
	end
	play:Box("BarraColumpio", V(13, 0.6, 0.6), V(-54, 10, 40), Colors.Red, M.Metal)
	play:Box("Asiento", V(2, 0.4, 1.2), V(-57, 3, 40), Colors.Yellow, M.Plastic)
	play:Box("Asiento", V(2, 0.4, 1.2), V(-51, 3, 40), Colors.Yellow, M.Plastic)
	play:Ladder("EscaleraTobogan", -30, 30, 0, 9)
	play:Box("PlataformaTobogan", V(4, 0.6, 4), V(-30, 9, 33), Colors.Blue, M.Plastic)
	play:Wedge("Tobogan", V(3, 9, 14), V(-30, 4.5, 42), Colors.Yellow, M.Plastic, 180)
	play:Box("Pista", V(40, 0.2, 24), V(40, 0.2, 60), C(200, 90, 60), M.SmoothPlastic)
	play:Box("Canasta", V(6, 4, 0.4), V(40, 10, 47), Colors.White, M.Plastic)
	play:Pillar("PosteCanasta", 40, 46, 0, 10, 0.6, Colors.DarkMetal, M.Metal)

	-- autobus escolar
	local bus = b:At(V(-90, 0, 100), "Autobus")
	bus:Box("Carroceria", V(10, 8, 34), V(0, 5, 0), C(250, 200, 40), M.Metal)
	bus:Box("Ventanas", V(10.2, 2.5, 30), V(0, 7, 0), Colors.Glass, M.Glass, { transparency = 0.4 })
	for _, z in ipairs({ -11, 11 }) do
		for _, x in ipairs({ -5, 5 }) do
			bus:Box("Rueda", V(1.2, 3, 3), V(x, 1.5, z), C(25, 25, 25), M.Rubber, { shape = Enum.PartType.Cylinder })
		end
	end
	for i = -3, 3 do
		b:Pine(i * 40, 140, 0, 1.2)
	end

	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-20 + ix * 12, 1, 20 + iz * 10))
		end
	end
end

return School
