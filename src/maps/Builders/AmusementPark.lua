-- Parque de atracciones: noria y tiovivo que giran (animados en el cliente), torre de caida con ascensor,
-- montana rusa, casa del terror, coches de choque, puestos de comida y arco de entrada.
local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local Buildings = require(Lib.Buildings)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local AmusementPark = {
	Title = "Parque de atracciones",
	Description = "Noria y tiovivo girando, torre de caida con ascensor, montana rusa y casa del terror.",
	Lighting = { ClockTime = 18.2, Brightness = 1.8 },
	Bounds = { x1 = -160, x2 = 160, z1 = -160, z2 = 170, top = 120, floor = 0 },
	Disasters = { "Earthquake", "Fire", "Meteors", "Tornado", "Lightning", "UFO", "BlackHole", "AcidRain", "Virus", "Tsunami", "Volcano", "Hail" },
}

local BRIGHT = { C(255, 80, 80), C(255, 200, 60), C(80, 200, 255), C(120, 255, 120), C(220, 110, 255), C(255, 140, 60) }

function AmusementPark.Build(b)
	b:Box("Isla", V(380, 10, 400), V(0, -5.5, 10), Colors.Grass, M.Grass, { indestructible = true })
	b:Sea(-6)
	local paths = b:Group("Caminos")
	paths:Box("CaminoCentral", V(16, 0.4, 300), V(0, 0.2, 20), C(210, 190, 160), M.Pavement, { indestructible = true })
	paths:Box("CaminoCruz", V(280, 0.4, 16), V(0, 0.2, -20), C(210, 190, 160), M.Pavement, { indestructible = true })

	-- arco de entrada
	local gate = b:Group("Entrada")
	for _, x in ipairs({ -14, 14 }) do
		gate:Box("TorreArco", V(6, 22, 6), V(x, 11, 160), BRIGHT[1], M.SmoothPlastic)
		gate:Ball("BolaArco", 6, V(x, 25, 160), BRIGHT[2], M.Neon)
	end
	gate:Board("CartelArco", "PARQUE DISASTRO", V(34, 6, 2), V(0, 20, 160), BRIGHT[3], Colors.White)
	gate:Box("Taquilla", V(8, 8, 6), V(26, 4, 150), BRIGHT[2], M.SmoothPlastic)

	-- noria (gira alrededor del eje Z en el cliente)
	local wheel = b:Group("Noria", "Model")
	local cx, cy, cz = -80, 42, -70
	local R = 32
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local x, y = cx + math.cos(a) * R, cy + math.sin(a) * R
		wheel:Box("Aro", V(9, 1.2, 1.2), V(x, y, cz - 2), BRIGHT[(i % #BRIGHT) + 1], M.Neon, { rot = V(0, 0, math.deg(a) + 90) })
		wheel:Box("Aro", V(9, 1.2, 1.2), V(x, y, cz + 2), BRIGHT[(i % #BRIGHT) + 1], M.Neon, { rot = V(0, 0, math.deg(a) + 90) })
		if i % 3 == 0 then
			wheel:Box("Radio", V(R, 0.6, 0.6), V(cx + math.cos(a) * R / 2, cy + math.sin(a) * R / 2, cz), Colors.White, M.Metal, { rot = V(0, 0, math.deg(a)) })
			wheel:Box("Cabina", V(4, 4, 5), V(x, y - 3, cz), BRIGHT[(i / 3) % #BRIGHT + 1], M.SmoothPlastic)
		end
	end
	wheel:Pillar("Eje", cx, cz, cy - 1.5, cy + 1.5, 4, Colors.DarkMetal, M.Metal)
	b:Spin(wheel.parent, 2, "Z")
	-- soportes (no giran)
	for _, s in ipairs({ -1, 1 }) do
		b:Box("SoporteNoria", V(2, 46, 2), V(cx + s * 12, 21, cz - 5), Colors.White, M.Metal, { rot = V(0, 0, -s * 15) })
		b:Box("SoporteNoria", V(2, 46, 2), V(cx + s * 12, 21, cz + 5), Colors.White, M.Metal, { rot = V(0, 0, -s * 15) })
	end
	b:Box("BaseNoria", V(36, 1, 16), V(cx, 0.5, cz), C(80, 80, 90), M.Concrete)

	-- tiovivo (gira en el eje Y)
	local carousel = b:Group("Tiovivo", "Model")
	local tx, tz = 70, -70
	carousel:Pillar("Plataforma", tx, tz, 0, 1.4, 30, C(230, 200, 150), M.WoodPlanks)
	carousel:Pillar("Centro", tx, tz, 1.4, 14, 4, BRIGHT[5], M.SmoothPlastic)
	carousel:Pillar("Techo", tx, tz, 14, 16, 32, BRIGHT[1], M.Fabric)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local x, z = tx + math.cos(a) * 11, tz + math.sin(a) * 11
		carousel:Pillar("Barra", x, z, 1.4, 14, 0.4, C(255, 215, 80), M.Metal)
		carousel:Box("Caballo", V(1.4, 2.6, 4), V(x, 4.5 + (i % 2), z), Colors.White, M.SmoothPlastic, { rot = V(0, -math.deg(a), 0) })
	end
	b:Spin(carousel.parent, 6, "Y")

	-- torre de caida con ascensor
	local drop = b:Group("TorreCaida")
	local dz = -120
	local lift = { name = "AscensorCaida", x = 0, z = dz, floors = { 0, 40, 80 }, labels = { "PB", "40", "80" }, wallColor = BRIGHT[4], wallMaterial = M.Metal }
	Elevator.build(drop, lift)
	for _, y in ipairs({ 40, 80 }) do
		drop:Slab("Mirador", -10, 10, dz + 6.1, dz + 16, y, 1.2, Colors.DarkMetal, M.DiamondPlate)
		drop:Wall("Barandilla", "x", dz + 16, -10, 10, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
		drop:Wall("Barandilla", "z", -10, dz + 6.1, dz + 16, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
		drop:Wall("Barandilla", "z", 10, dz + 6.1, dz + 16, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
	end
	drop:Ball("Corona", 8, V(0, 98, dz), BRIGHT[2], M.Neon)
	drop:Board("CartelCaida", "CAIDA LIBRE", V(14, 3, 0.4), V(0, 12, dz + 6.4), C(30, 30, 40), BRIGHT[2])

	-- montana rusa: circuito con subidas y bajadas sobre pilares
	local coaster = b:Group("MontanaRusa")
	local N = 40
	local prev
	for i = 0, N do
		local a = i / N * math.pi * 2
		local x, z = 90 + math.cos(a) * 45, 70 + math.sin(a) * 30
		local y = 10 + 14 * math.max(0, math.sin(a * 2)) + 6 * math.sin(a * 3)
		local p = V(x, y, z)
		if prev then
			local mid = (prev + p) / 2
			local len = (p - prev).Magnitude
			local dirAngle = math.deg(math.atan2(-(p.Z - prev.Z), p.X - prev.X))
			local slope = math.deg(math.atan2(p.Y - prev.Y, math.sqrt((p.X - prev.X) ^ 2 + (p.Z - prev.Z) ^ 2)))
			coaster:Box("Via", V(len + 0.4, 0.6, 4), mid, C(220, 40, 40), M.Metal, { rot = V(0, dirAngle, slope) })
			if i % 3 == 0 then
				coaster:Pillar("PilarVia", x, z, 0, y - 0.3, 0.8, Colors.White, M.Metal)
			end
		end
		prev = p
	end
	for k = 0, 2 do
		coaster:Box("Vagon", V(4, 2.4, 3.4), V(135 - k * 0.5, 12 + k * 0.2, 70 + k * 4.5), BRIGHT[k + 1], M.SmoothPlastic)
	end

	-- casa del terror (2 plantas)
	Buildings.House(b, -90, 70, 30, 26, 2, { name = "CasaTerror", color = C(70, 60, 80), roofColor = C(40, 30, 50) })
	b:Board("CartelTerror", "CASA DEL TERROR", V(18, 3, 0.4), V(-90, 9, 83.6), C(20, 10, 20), C(255, 80, 80))

	-- coches de choque
	local bump = b:Group("CochesChoque")
	bump:Box("Pista", V(40, 0.6, 30), V(70, 0.3, 10), C(60, 60, 70), M.DiamondPlate)
	bump:Box("TechoPista", V(42, 1, 32), V(70, 12, 10), BRIGHT[6], M.Fabric)
	for _, p in ipairs({ { 50, -5 }, { 90, -5 }, { 50, 25 }, { 90, 25 } }) do
		bump:Pillar("PostePista", p[1], p[2], 0, 12, 0.8, Colors.White, M.Metal)
	end
	for k = 0, 5 do
		bump:Box("Choque", V(5, 2, 3.5), V(56 + k * 6, 1.6, 4 + (k % 2) * 10), BRIGHT[k % #BRIGHT + 1], M.SmoothPlastic)
	end

	-- puestos de comida
	for k, name in ipairs({ "PALOMITAS", "ALGODON", "HELADOS", "PERRITOS" }) do
		local x = -60 + k * 22
		b:Box("Puesto", V(10, 4, 6), V(x, 2, 110), Colors.Wood, M.Wood)
		b:Box("Toldo", V(12, 0.5, 8), V(x, 9, 111), BRIGHT[k], M.Fabric)
		b:Board("CartelPuesto", name, V(10, 2, 0.4), V(x, 10.6, 115), C(30, 30, 40), Colors.White)
		for _, sx in ipairs({ -5, 5 }) do
			b:Box("PostePuesto", V(0.5, 9, 0.5), V(x + sx, 4.5, 114.5), Colors.Wood, M.Wood)
		end
	end
	for i = -3, 3 do
		Buildings.Lamp(b, 12, i * 40 + 20, 0)
	end
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		b:Pine(math.cos(a) * 165, 10 + math.sin(a) * 170, 0, 1.3)
	end

	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-15 + ix * 10, 1, 125 + iz * 9))
		end
	end
end

return AmusementPark
