-- Ciudad: manzanas con casas de 1-3 plantas, tiendas, una torre de apartamentos con ascensor,
-- gasolinera, parque, deposito de agua, calles con coches y farolas.
local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Buildings = require(Lib.Buildings)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local City = {
	Title = "Ciudad",
	Description = "Calles con casas, tiendas, gasolinera, parque y una torre de apartamentos con ascensor.",
	Lighting = { ClockTime = 13, Brightness = 2 },
	Bounds = { x1 = -170, x2 = 170, z1 = -170, z2 = 170, top = 110, floor = 0 },
	Disasters = { "Earthquake", "Fire", "Tornado", "Meteors", "Flood", "AcidRain", "Lightning", "Tsunami", "Virus", "UFO", "Volcano", "BlackHole" },
	DisasterConfig = { Flood = { maxHeight = 26 }, Tsunami = { height = 30 } },
}

local HOUSE_COLORS = { C(235, 220, 190), C(200, 220, 235), C(240, 200, 190), C(210, 235, 200), C(240, 235, 210), C(220, 205, 235) }
local ROOF_COLORS = { C(170, 70, 50), C(90, 90, 100), C(120, 60, 40), C(60, 90, 140) }

function City.Build(b)
	b:Box("Isla", V(420, 10, 420), V(0, -5.5, 0), Colors.Grass, M.Grass, { indestructible = true })
	b:Sea(-6)

	-- calles: cruz principal y anillo
	local streets = b:Group("Calles")
	for _, s in ipairs({ { V(340, 0.5, 18), V(0, -0.25, 0) }, { V(18, 0.5, 340), V(0, -0.25, 0) }, { V(340, 0.5, 14), V(0, -0.25, -120) }, { V(340, 0.5, 14), V(0, -0.25, 120) }, { V(14, 0.5, 340), V(-120, -0.25, 0) }, { V(14, 0.5, 340), V(120, -0.25, 0) } }) do
		streets:Box("Calle", s[1], s[2], Colors.Asphalt, M.Asphalt, { indestructible = true })
	end
	for x = -160, 160, 16 do
		streets:Box("Linea", V(7, 0.1, 0.6), V(x, 0.02, 0), Colors.White, M.SmoothPlastic, { canCollide = false, indestructible = true })
		streets:Box("Linea", V(0.6, 0.1, 7), V(0, 0.02, x), Colors.White, M.SmoothPlastic, { canCollide = false, indestructible = true })
	end

	-- casas en las cuatro manzanas (cuadrantes)
	local houses = b:Group("Casas")
	local n = 0
	for _, qx in ipairs({ -1, 1 }) do
		for _, qz in ipairs({ -1, 1 }) do
			for row = 0, 1 do
				for col = 0, 1 do
					n = n + 1
					local cx = qx * (35 + col * 45)
					local cz = qz * (35 + row * 45)
					-- la manzana noreste es la de la torre y el parque
					if not (qx == 1 and qz == -1) then
						local floors = (n % 3 == 0) and 3 or ((n % 2 == 0) and 2 or 1)
						Buildings.House(houses, cx, cz, 24, 22, floors, {
							name = "Casa" .. n,
							color = HOUSE_COLORS[n % #HOUSE_COLORS + 1],
							roofColor = ROOF_COLORS[n % #ROOF_COLORS + 1],
							roof = floors == 3 and "flat" or "pitched",
						})
						-- valla del jardin
						houses:Box("Seto", V(26, 2.5, 1.2), V(cx, 1.25, cz + qz * -14), C(50, 120, 50), M.Grass)
					end
				end
			end
		end
	end

	-- torre de apartamentos con ascensor (manzana noreste)
	Buildings.Tower(b, 58, -58, 34, 34, 6, { name = "Apartamentos", story = 12, color = C(190, 195, 210) })
	b:Board("CartelTorre", "APARTAMENTOS SOL", V(20, 3, 0.4), V(58, 10, -40.6), C(40, 50, 80), C(255, 220, 120))

	-- parque con fuente y arboles (al lado de la torre)
	local park = b:Group("Parque")
	park:Box("Cesped", V(40, 0.3, 40), V(100, 0.15, -100), C(80, 160, 70), M.Grass, { indestructible = true })
	park:Pillar("Fuente", 100, -100, 0.3, 1.6, 10, Colors.Concrete, M.Marble)
	park:Pillar("Agua", 100, -100, 1.6, 1.9, 8, Colors.Water, M.SmoothPlastic)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		park:Pine(100 + math.cos(a) * 15, -100 + math.sin(a) * 15, 0.3, 1.1)
	end

	-- gasolinera (sur-este): explota con el fuego
	local gas = b:Group("Gasolinera")
	gas:Box("Marquesina", V(30, 1, 18), V(140, 10, 140), C(230, 50, 50), M.Metal)
	for _, p in ipairs({ { 128, 133 }, { 152, 133 }, { 128, 147 }, { 152, 147 } }) do
		gas:Pillar("Columna", p[1], p[2], 0, 10, 1, Colors.White, M.Metal)
	end
	for _, x in ipairs({ 134, 146 }) do
		gas:Box("Surtidor", V(2, 4, 1.4), V(x, 2, 140), Colors.Red, M.Plastic)
	end
	gas:Box("Tienda24h", V(16, 9, 12), V(140, 4.5, 157), C(240, 240, 240), M.SmoothPlastic)
	gas:Board("CartelGas", "GASOLINERA 24H", V(16, 2.4, 0.4), V(140, 7, 150.8), C(230, 50, 50), Colors.White)

	-- tiendas (fila al oeste de la calle principal)
	local shops = b:Group("Tiendas")
	for i, name in ipairs({ "PANADERIA", "FARMACIA", "CAFE" }) do
		local cz = -50 + i * 30
		Buildings.House(shops, -150, cz, 20, 22, 1, { name = "Tienda" .. i, color = HOUSE_COLORS[i], roof = "flat", roofColor = Colors.DarkMetal, furnish = false })
		shops:Board("Rotulo" .. i, name, V(14, 2.4, 0.4), V(-150, 10, cz + 11.4), C(40, 40, 50), C(255, 220, 120))
	end

	-- deposito de agua
	local tank = b:Group("Deposito")
	for _, p in ipairs({ { -100, -150 }, { -88, -150 }, { -100, -138 }, { -88, -138 } }) do
		tank:Pillar("Pata", p[1], p[2], 0, 30, 1.2, Colors.DarkMetal, M.Metal)
	end
	tank:Pillar("Tanque", -94, -144, 30, 42, 16, C(150, 180, 210), M.Metal)
	tank:Board("Nombre", "CIUDAD", V(10, 3, 0.4), V(-94, 36, -135.8), C(150, 180, 210), C(40, 50, 80))

	-- coches y farolas
	local cols = { Colors.Red, Colors.Blue, Colors.Yellow, Colors.Green, C(240, 240, 240) }
	for i = 0, 7 do
		Buildings.Car(b, -140 + i * 40, 4, 0, cols[i % #cols + 1], 90)
	end
	for i = -3, 3 do
		if i ~= 0 then
			Buildings.Lamp(b, i * 45, 12, 0)
		end
		Buildings.Lamp(b, 12, i * 45 + 20, 0)
	end
	-- semaforos en el cruce
	for _, p in ipairs({ { 11, 11 }, { -11, -11 } }) do
		b:Pillar("Semaforo", p[1], p[2], 0, 8, 0.5, Colors.DarkMetal, M.Metal)
		b:Box("Luces", V(1.2, 3, 1.2), V(p[1], 9, p[2]), C(30, 30, 30), M.Metal)
		b:Ball("Verde", 0.9, V(p[1], 8.2, p[2] + 0.6), C(60, 255, 90), M.Neon)
	end

	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-18 + ix * 12, 1, -18 + iz * 18))
		end
	end
end

return City
