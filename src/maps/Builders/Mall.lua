-- Centro comercial: 4 plantas alrededor de un gran atrio con claraboya, ascensores panoramicos de cristal,
-- escaleras, tiendas, fuente central, cine en la ultima planta y aparcamiento.

local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local Mall = {
	Title = "Centro Comercial",
	Description = "4 plantas con atrio, ascensores de cristal, escaleras, tiendas, fuente y cine.",
	Lighting = { ClockTime = 12, Brightness = 2 },
	Bounds = { x1 = -110, x2 = 110, z1 = -90, z2 = 150, top = 80, floor = 0 },
	Disasters = { "Earthquake", "Fire", "Meteors", "AcidRain", "Lava" },
	DisasterConfig = { Lava = { maxHeight = 40 } }, -- hay que llegar a la ultima planta
}

local FLOOR_H = 16
local SHOP_COLORS = { Colors.Red, Colors.Blue, Colors.Orange, Colors.Green, Colors.Yellow, C(170, 90, 200), C(60, 180, 190) }
local SHOP_NAMES = { "MODA", "TECH", "JUGUETES", "LIBROS", "DEPORTES", "ZAPATOS", "MUSICA", "CAFE" }

function Mall.Build(b)
	b:Box("Isla", V(420, 10, 360), V(0, -5.5, 0), Colors.Grass, M.Grass)
	b:Sea(-6)
	b:Box("Aparcamiento", V(300, 0.5, 70), V(0, -0.25, 110), Colors.Asphalt, M.Asphalt)
	for x = -135, 135, 15 do
		b:Box("PlazaAparcamiento", V(0.4, 0.1, 12), V(x, 0.02, 112), Colors.White, M.SmoothPlastic, { canCollide = false })
	end

	local mall = b:Group("Edificio")
	-- planta rectangular: x[-100,100], z[-80,80]. Atrio central x[-30,30], z[-30,30]
	local x1, x2, z1, z2 = -100, 100, -80, 80
	local floors = { 0, FLOOR_H, FLOOR_H * 2, FLOOR_H * 3 }
	local roofY = FLOOR_H * 4
	local atrium = { -30, 30, -30, 30 }

	-- ascensores de cristal en el lado norte del atrio, mirando a +Z hacia el atrio
	local elevL = { name = "AscensorCristalA", x = -14, z = -50, floors = floors, labels = { "PB", "1", "2", "3" }, glass = true }
	local elevR = { name = "AscensorCristalB", x = 14, z = -50, floors = floors, labels = { "PB", "1", "2", "3" }, glass = true }
	local hL, hR = Elevator.hole(elevL), Elevator.hole(elevR)
	-- escalera de la PB a la 1 y de la 1 a la 2 y de la 2 a la 3 en el lado sur
	local stairHoles = {
		{ -30, -2, 40, 48 },
		{ 2, 30, 56, 64 },
		{ -30, -2, 40, 48 },
	}

	mall:Slab("SueloPB", x1, x2, z1, z2, 0, 0.5, C(225, 225, 230), M.Marble, { hL, hR })
	for i = 2, 4 do
		local holes = { hL, hR, atrium }
		if i - 1 <= #stairHoles then
			holes[#holes + 1] = stairHoles[i - 1]
		end
		mall:Slab("Suelo" .. (i - 1), x1, x2, z1, z2, floors[i], 1.5, C(225, 225, 230), M.Marble, holes)
	end
	-- claraboya del atrio
	mall:Slab("Techo", x1 - 4, x2 + 4, z1 - 4, z2 + 4, roofY + 2, 2, Colors.DarkMetal, M.Metal, { { -28, 28, -28, 28 } })
	mall:Box("Claraboya", V(56, 0.6, 56), V(0, roofY + 1.5, 0), Colors.Glass, M.Glass, { transparency = 0.6 })

	-- muros exteriores con grandes cristaleras
	for i, y in ipairs(floors) do
		local top = y + FLOOR_H
		local function glassBand(a1, a2, skipFrom, skipTo)
			local list = {}
			local c = a1 + 7
			while c + 5 <= a2 do
				if not (skipFrom and c + 5 > skipFrom and c - 5 < skipTo) then
					list[#list + 1] = { from = c - 5, to = c + 5, bottom = 2, top = 13, glass = true }
				end
				c = c + 14
			end
			return list
		end
		local entrance = (i == 1) and { { from = -8, to = 8, bottom = 0, top = 11 } } or {}
		local frontList = glassBand(x1 + 2, x2 - 2, -8, 8)
		for _, e in ipairs(entrance) do
			frontList[#frontList + 1] = e
		end
		mall:Wall("FachadaSur" .. i, "x", z2, x1, x2, y, top, 1, C(235, 235, 240), M.Concrete, frontList)
		mall:Wall("FachadaNorte" .. i, "x", z1, x1, x2, y, top, 1, C(235, 235, 240), M.Concrete)
		mall:Wall("FachadaOeste" .. i, "z", x1, z1, z2, y, top, 1, C(235, 235, 240), M.Concrete, glassBand(z1 + 2, z2 - 2))
		mall:Wall("FachadaEste" .. i, "z", x2, z1, z2, y, top, 1, C(235, 235, 240), M.Concrete, glassBand(z1 + 2, z2 - 2))
	end
	mall:Board("Letrero", "GRAN CENTRO COMERCIAL", V(80, 7, 1), V(0, roofY + 8, z2 + 3), Colors.Red, C(255, 255, 255))

	-- barandillas de cristal alrededor del atrio en plantas 1-3
	for i = 2, 4 do
		local y = floors[i]
		mall:Wall("BarandillaN", "x", atrium[3], atrium[1], atrium[2], y, y + 4, 0.3, Colors.Glass, M.Glass, {})
		mall:Wall("BarandillaS", "x", atrium[4], atrium[1], atrium[2], y, y + 4, 0.3, Colors.Glass, M.Glass, {})
		mall:Wall("BarandillaO", "z", atrium[1], atrium[3], atrium[4], y, y + 4, 0.3, Colors.Glass, M.Glass, {})
		mall:Wall("BarandillaE", "z", atrium[2], atrium[3], atrium[4], y, y + 4, 0.3, Colors.Glass, M.Glass, {})
	end

	Elevator.build(mall, elevL)
	Elevator.build(mall, elevR)

	-- escaleras (cada tramo en su hueco)
	mall:Stairs("EscaleraPB", -30, 44, 0, FLOOR_H, 8, 28, "+x", C(210, 210, 215), M.Concrete)
	mall:Stairs("Escalera1", 30, 60, FLOOR_H, FLOOR_H * 2, 8, 28, "-x", C(210, 210, 215), M.Concrete)
	mall:Stairs("Escalera2", -30, 44, FLOOR_H * 2, FLOOR_H * 3, 8, 28, "+x", C(210, 210, 215), M.Concrete)

	-- fuente central en planta baja
	local fountain = mall:Group("Fuente")
	fountain:Pillar("Base", 0, 0, 0, 1.5, 22, Colors.Concrete, M.Marble)
	fountain:Pillar("Agua", 0, 0, 1.5, 1.8, 19, Colors.Water, M.SmoothPlastic)
	fountain:Pillar("Columna", 0, 0, 1.8, 8, 3, Colors.Concrete, M.Marble)
	fountain:Pillar("Cuenco", 0, 0, 8, 9, 10, Colors.Concrete, M.Marble)
	fountain:Ball("Esfera", 5, V(0, 11.5, 0), Colors.Glass, M.Glass)

	-- tiendas: bloques pegados a las paredes en cada planta (dejando libres ascensores y atrio)
	local shops = mall:Group("Tiendas")
	local n = 0
	for i, y in ipairs(floors) do
		local base = y
		local function shop(x, z, w, d, faceBack)
			n = n + 1
			local col = SHOP_COLORS[(n - 1) % #SHOP_COLORS + 1]
			local name = SHOP_NAMES[(n - 1) % #SHOP_NAMES + 1]
			shops:Box("Tienda", V(w, 3.5, d), V(x, base + 1.75, z), C(250, 250, 250), M.SmoothPlastic)
			shops:Box("Vitrina", V(w - 2, 5, 0.5), V(x, base + 6, z + (faceBack and -d / 2 or d / 2)), Colors.Glass, M.Glass, { transparency = 0.5 })
			shops:Board("Cartel", name, V(w - 1, 3, 0.5), V(x, base + 11, z + d / 2 + 0.3), col, C(255, 255, 255))
		end
		for k = 0, 3 do
			shop(-80 + k * 16, 70, 12, 8)
			shop(80 - k * 16, 70, 12, 8)
		end
		-- tiendas laterales (este y oeste)
		for k = 0, 2 do
			shop(-92, -10 + k * 22, 8, 14)
			shop(92, -10 + k * 22, 8, 14)
		end
	end

	-- bancos y plantas en cada planta
	local decor = mall:Group("Decoracion")
	for i, y in ipairs(floors) do
		local base = y
		for _, p in ipairs({ { -45, -20 }, { 45, -20 }, { -45, 20 }, { 45, 20 } }) do
			decor:Box("Banco", V(7, 1.2, 2), V(p[1], base + 0.6, p[2]), Colors.Wood, M.Wood)
			decor:Pillar("Maceta", p[1] + 6, p[2], base, base + 2, 2.6, Colors.Wood, M.Wood)
			decor:Ball("Planta", 4, V(p[1] + 6, base + 4, p[2]), Colors.Green, M.Grass)
		end
	end

	-- cine en la ultima planta (zona sur-oeste): sala con butacas y pantalla
	local cine = mall:Group("Cine")
	local cy = floors[4]
	cine:Box("Pantalla", V(26, 11, 0.6), V(-65, cy + 7.5, 47), C(240, 240, 255), M.SmoothPlastic)
	cine:Board("CartelCine", "CINE", V(8, 3, 0.4), V(-65, cy + 14, 20.7), Colors.DarkMetal, C(255, 220, 90))
	for row = 0, 4 do
		for col = 0, 5 do
			cine:Box("Butaca", V(3, 2, 2.4), V(-76 + col * 4.4, cy + 1 + row * 0.7, 20 + row * 4), Colors.Red, M.Fabric)
		end
	end

	-- aparcamiento: coches decorativos
	local cars = b:Group("Coches")
	for i = 0, 9 do
		local x = -135 + i * 30
		if i % 3 ~= 1 then
			cars:Box("Coche", V(5, 1.6, 10), V(x + 7.5, 1.4, 112), SHOP_COLORS[i % #SHOP_COLORS + 1], M.Metal)
			cars:Box("Cabina", V(4.2, 1.4, 5), V(x + 7.5, 2.9, 111), Colors.Glass, M.Glass, { transparency = 0.4 })
		end
	end

	-- arboles en la isla
	local trees = b:Group("Arboles")
	for i = 0, 11 do
		trees:Pine(-170 + i * 31, 160, 0, 1.2)
		trees:Pine(-170 + i * 31, -150, 0, 1.2)
	end

	-- puntos de aparicion: a la entrada, planta baja
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-50 + ix * 33, 1, 88 + iz * 14))
		end
	end
end

return Mall
