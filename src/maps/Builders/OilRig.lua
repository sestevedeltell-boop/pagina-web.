-- Plataforma petrolifera en mitad del mar: cubierta principal sobre 4 patas, torre de perforacion,
-- modulo de alojamiento, helipuerto y muelle. Un ascensor une muelle, cubierta, modulo y helipuerto.
-- Si caes al mar, mueres.

local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local OilRig = {
	Title = "Plataforma Petrolifera",
	Description = "Plataforma en alta mar con torre de perforacion, helipuerto y ascensor desde el muelle.",
	Lighting = { ClockTime = 19.5, Brightness = 2, FogEnd = 2500, FogColor = C(120, 130, 150) },
	Bounds = { x1 = -50, x2 = 50, z1 = -50, z2 = 50, top = 110, floor = 0 },
	Disasters = { "Tornado", "Lightning", "Meteors", "Flood", "Fire", "AcidRain" },
	DisasterConfig = { Flood = { maxHeight = 46 } }, -- tsunami: inunda la cubierta, el modulo y el helipuerto quedan a salvo
}

local DECK = 30
local STEEL = C(110, 115, 125)
local RUST = C(150, 90, 60)

function OilRig.Build(b)
	b:Sea(0, 2048, C(25, 70, 120), 0.1)
	-- pequeno islote de roca bajo la plataforma, solo decorativo
	b:Box("Roca", V(18, 14, 18), V(-52, -3, 52), C(90, 90, 95), M.Slate)

	local rig = b:Group("Plataforma")
	local half = 45

	-- patas y cruces
	local legs = rig:Group("Patas")
	for _, p in ipairs({ { -36, -36 }, { 36, -36 }, { -36, 36 }, { 36, 36 } }) do
		legs:Pillar("Pata", p[1], p[2], -30, DECK, 8, STEEL, M.Metal)
		legs:Pillar("Anillo", p[1], p[2], 2, 6, 9, Colors.Yellow, M.Metal)
	end
	for _, y in ipairs({ 8, 18 }) do
		legs:Box("CruceX1", V(72, 1.6, 1.6), V(0, y, -36), STEEL, M.Metal)
		legs:Box("CruceX2", V(72, 1.6, 1.6), V(0, y, 36), STEEL, M.Metal)
		legs:Box("CruceZ1", V(1.6, 1.6, 72), V(-36, y, 0), STEEL, M.Metal)
		legs:Box("CruceZ2", V(1.6, 1.6, 72), V(36, y, 0), STEEL, M.Metal)
	end

	-- cubierta principal
	local elev = { name = "AscensorPlataforma", x = 0, z = -34, floors = { 3, DECK, 44, 58 }, labels = { "M", "1", "2", "H" }, wallColor = RUST }
	local hole = Elevator.hole(elev)
	rig:Slab("Cubierta", -half, half, -half, half, DECK, 2, STEEL, M.DiamondPlate, { hole })
	for _, w in ipairs({ { "x", half, -half, half }, { "x", -half, -half, half }, { "z", half, -half, half }, { "z", -half, -half, half } }) do
		rig:Wall("Barandilla", w[1], w[2], w[3], w[4], DECK, DECK + 3.5, 0.3, Colors.Yellow, M.Metal, {
			{ from = w[3] + 1, to = w[4] - 1, bottom = 1.2, top = 3.5, glass = true },
		})
	end

	Elevator.build(rig, elev)

	-- muelle flotante a nivel del mar, delante del ascensor
	local pier = rig:Group("Muelle")
	pier:Slab("Embarcadero", -15, 15, -28, 5, 3, 2.5, Colors.Wood, M.Wood)
	for _, p in ipairs({ { -13, -26 }, { 13, -26 }, { -13, 3 }, { 13, 3 } }) do
		pier:Pillar("Poste", p[1], p[2], -12, 3.5, 1.4, Colors.Wood, M.Wood)
	end
	pier:Wall("BarandillaMuelle", "x", 5, -15, 15, 3, 6, 0.3, Colors.Yellow, M.Metal, { { from = -14, to = 14, bottom = 1.2, top = 3, glass = true } })
	pier:Pillar("PataAscensor1", -9, -34, -12, 2, 1.6, STEEL, M.Metal)
	pier:Pillar("PataAscensor2", 9, -34, -12, 2, 1.6, STEEL, M.Metal)
	-- bote amarrado
	pier:Box("Bote", V(8, 2.4, 18), V(24, 1.2, -10), Colors.Red, M.SmoothPlastic)
	pier:Box("CabinaBote", V(5, 3, 6), V(24, 3.9, -12), Colors.White, M.SmoothPlastic)
	pier:Slab("PasarelaBote", 15, 20, -12, -8, 3, 1, Colors.Wood, M.Wood)

	-- plataformas del ascensor: nivel 44 (modulo) y 58 (helipuerto)
	local up = rig:Group("NivelesSuperiores")
	up:Slab("Rellano44", -9, 9, -28, -12, 44, 1.5, STEEL, M.DiamondPlate)
	for _, p in ipairs({ { -8, -13 }, { 8, -13 } }) do
		up:Pillar("Soporte", p[1], p[2], DECK, 44, 1.6, STEEL, M.Metal)
	end
	up:Wall("BarandillaRellano", "x", -12, -9, 9, 44, 47.5, 0.3, Colors.Yellow, M.Metal, { { from = -8, to = 8, bottom = 1.2, top = 3.5, glass = true } })
	up:Slab("Helipuerto", -26, 26, -28, 18, 58, 1.5, C(70, 72, 78), M.Concrete)
	for _, p in ipairs({ { -24, 16 }, { 24, 16 }, { -24, -20 }, { 24, -20 } }) do
		up:Pillar("SoporteHeli", p[1], p[2], DECK, 58, 2, STEEL, M.Metal)
	end
	up:Pillar("CirculoHeli", 0, -5, 58, 58.2, 30, Colors.Yellow, M.SmoothPlastic)
	up:Pillar("CirculoHeli2", 0, -5, 58.2, 58.4, 26, C(70, 72, 78), M.Concrete)
	up:Board("H", "H", V(14, 0.2, 14), V(0, 58.6, -5), C(70, 72, 78), C(255, 255, 255), Enum.NormalId.Top)
	for _, p in ipairs({ { -25, -27 }, { 25, -27 }, { -25, 17 }, { 25, 17 } }) do
		up:Ball("LuzHeli", 1.6, V(p[1], 59.6, p[2]), Colors.Green, M.Neon)
	end
	-- helicoptero decorativo
	local heli = up:At(V(0, 59, -5), "Helicoptero")
	heli:Box("Fuselaje", V(4, 3.4, 9), V(0, 2.2, 0), Colors.Red, M.SmoothPlastic)
	heli:Box("Cristal", V(3.4, 2, 3), V(0, 2.6, 4.2), Colors.Glass, M.Glass, { transparency = 0.4 })
	heli:Box("Cola", V(1, 1, 7), V(0, 2.6, -7.5), Colors.Red, M.SmoothPlastic)
	heli:Box("Rotor", V(18, 0.2, 1), V(0, 4.3, 0), Colors.DarkMetal, M.Metal, { canCollide = false })
	heli:Box("PatinIzq", V(0.4, 0.4, 8), V(-1.8, 0.4, 0), Colors.DarkMetal, M.Metal)
	heli:Box("PatinDer", V(0.4, 0.4, 8), V(1.8, 0.4, 0), Colors.DarkMetal, M.Metal)

	-- torre de perforacion (se sube por una escalera de mano hasta una plataforma a 70)
	local derrick = rig:Group("TorrePerforacion")
	local dx, dz = 22, 22
	for _, p in ipairs({ { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } }) do
		derrick:Box("Montante", V(1.4, 56, 1.4), V(dx + p[1] * 0.5, DECK + 28, dz + p[2] * 0.5), Colors.Yellow, M.Metal, { rot = V(-p[2] * 0.4, 0, p[1] * 0.4) })
	end
	for y = DECK + 8, DECK + 48, 10 do
		local s = 12 - (y - DECK) * 0.17
		derrick:Box("TravesanoX", V(s, 0.8, 0.8), V(dx, y, dz - s / 2), Colors.Yellow, M.Metal)
		derrick:Box("TravesanoX", V(s, 0.8, 0.8), V(dx, y, dz + s / 2), Colors.Yellow, M.Metal)
		derrick:Box("TravesanoZ", V(0.8, 0.8, s), V(dx - s / 2, y, dz), Colors.Yellow, M.Metal)
		derrick:Box("TravesanoZ", V(0.8, 0.8, s), V(dx + s / 2, y, dz), Colors.Yellow, M.Metal)
	end
	derrick:Slab("PlataformaTorre", dx - 6, dx + 6, dz - 6, dz + 6, DECK + 40, 1, STEEL, M.DiamondPlate)
	derrick:Wall("BarandillaTorreN", "x", dz - 6, dx - 6, dx + 6, DECK + 40, DECK + 43.5, 0.3, Colors.Yellow, M.Metal, { { from = dx - 5.5, to = dx + 5.5, bottom = 1.2, top = 3.5, glass = true } })
	derrick:Ladder("EscalerillaTorre", dx, dz - 6.4, DECK, DECK + 41.5)
	derrick:Pillar("Tuberia", dx, dz, DECK, DECK + 40, 2, Colors.DarkMetal, M.Metal)
	derrick:Ball("LuzTorre", 2, V(dx, DECK + 58, dz), Colors.Red, M.Neon)

	-- modulo de alojamiento (planta baja de cubierta)
	local hab = rig:Group("Alojamiento")
	local mx1, mx2, mz1, mz2 = -42, -14, 8, 40
	hab:Wall("ModuloN", "x", mz1, mx1, mx2, DECK, DECK + 12, 0.8, C(230, 230, 235), M.Metal)
	hab:Wall("ModuloS", "x", mz2, mx1, mx2, DECK, DECK + 12, 0.8, C(230, 230, 235), M.Metal, Util.Windows(mx1 + 1, mx2 - 1, 7, 4, 4, 9))
	hab:Wall("ModuloO", "z", mx1, mz1, mz2, DECK, DECK + 12, 0.8, C(230, 230, 235), M.Metal, Util.Windows(mz1 + 1, mz2 - 1, 8, 4, 4, 9))
	hab:Wall("ModuloE", "z", mx2, mz1, mz2, DECK, DECK + 12, 0.8, C(230, 230, 235), M.Metal, { { from = 18, to = 24, bottom = 0, top = 8 } })
	hab:Slab("TechoModulo", mx1 - 1, mx2 + 1, mz1 - 1, mz2 + 1, DECK + 13, 1, STEEL, M.Metal)
	hab:Board("CartelModulo", "ALOJAMIENTO", V(16, 2.6, 0.4), V(-28, DECK + 10.5, mz2 + 0.6), Colors.Red, C(255, 255, 255))
	for i = 0, 2 do
		hab:Box("Litera", V(3, 1.4, 7), V(mx1 + 3 + i * 7, DECK + 2.7, mz1 + 5), Colors.Blue, M.Fabric)
		hab:Box("Litera", V(3, 1.4, 7), V(mx1 + 3 + i * 7, DECK + 2.7, mz2 - 5), Colors.Blue, M.Fabric)
	end

	-- depositos, contenedores, grua, antorcha
	local deco = rig:Group("Equipamiento")
	for i, p in ipairs({ { 30, -30 }, { 30, -8 } }) do
		deco:Pillar("Deposito", p[1], p[2], DECK, DECK + 14, 14, C(210, 210, 215), M.Metal)
		deco:Pillar("TapaDeposito", p[1], p[2], DECK + 14, DECK + 15, 15, Colors.Red, M.Metal)
	end
	local cols = { Colors.Red, Colors.Blue, Colors.Orange, Colors.Green, Colors.Yellow }
	for i = 0, 7 do
		local x = -34 + (i % 4) * 7.5
		local z = -6 + math.floor(i / 4) * 14
		deco:Box("Contenedor", V(7, 6, 12), V(x, DECK + 3, z), cols[i % #cols + 1], M.CorrodedMetal)
		if i % 3 == 0 then
			deco:Box("ContenedorApilado", V(7, 6, 12), V(x, DECK + 9, z), cols[(i + 2) % #cols + 1], M.CorrodedMetal)
		end
	end
	-- grua
	deco:Pillar("MastilGrua", 38, 2, DECK, DECK + 22, 3, Colors.Yellow, M.Metal)
	deco:Box("Pluma", V(36, 2, 2), V(24, DECK + 22.5, 2), Colors.Yellow, M.Metal)
	deco:Box("CableGrua", V(0.2, 12, 0.2), V(8, DECK + 16, 2), Colors.DarkMetal, M.Metal, { canCollide = false })
	-- antorcha
	deco:Pillar("TorreAntorcha", -40, -40, DECK, DECK + 46, 2, STEEL, M.Metal)
	deco:Ball("Llama", 5, V(-40, DECK + 49, -40), Colors.Orange, M.Neon)
	-- botes salvavidas
	for _, x in ipairs({ -20, 20 }) do
		deco:Box("Salvavidas", V(6, 3, 12), V(x, DECK + 2.5, 41), Colors.Orange, M.SmoothPlastic)
	end
	-- luces
	for _, p in ipairs({ { -44, -44 }, { 44, -44 }, { -44, 44 }, { 44, 44 } }) do
		deco:Pillar("PosteLuz", p[1], p[2], DECK, DECK + 9, 0.8, STEEL, M.Metal)
		local lamp = deco:Box("Foco", V(2, 1, 2), V(p[1], DECK + 9.5, p[2]), C(255, 245, 200), M.Neon, { canCollide = false })
		Util.AddLight(lamp, 40, 1.4)
	end

	-- puntos de aparicion en cubierta
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-4 + ix * 6, DECK + 1, -24 + iz * 8))
		end
	end
end

return OilRig
