-- Crucero: barco enorme en alta mar con 4 cubiertas, 2 ascensores, escaleras, piscina en la cubierta
-- de sol, chimenea, puente de mando y botes salvavidas. Caer al mar es morir.
local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local Buildings = require(Lib.Buildings)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors
local windows = Util.Windows

local CruiseShip = {
	Title = "Crucero",
	Description = "Un crucero gigante en alta mar: 4 cubiertas, ascensores, piscina y botes salvavidas.",
	Lighting = { ClockTime = 17, Brightness = 2, FogEnd = 3000 },
	Bounds = { x1 = -120, x2 = 140, z1 = -40, z2 = 40, top = 90, floor = 0 },
	Disasters = { "Tsunami", "Flood", "Lightning", "Tornado", "Meteors", "Fire", "Virus", "UFO", "BlackHole", "AcidRain", "Hail" },
	DisasterConfig = { Flood = { maxHeight = 40 }, Tsunami = { height = 30, maxHeight = 14 } },
}

local WHITE = C(240, 242, 245)
local HULL = C(30, 50, 90)

function CruiseShip.Build(b)
	b:Sea(0, 2048, C(30, 90, 150), 0.1)

	local ship = b:Group("Barco")
	local X1, X2, Z = -110, 110, 25
	local decks = { 10, 22, 34, 46 }

	-- casco
	ship:Wall("Casco", "x", Z, X1, X2, -10, 10, 1.5, HULL, M.Metal)
	ship:Wall("Casco", "x", -Z, X1, X2, -10, 10, 1.5, HULL, M.Metal)
	ship:Wall("Popa", "z", X1, -Z, Z, -10, 10, 1.5, HULL, M.Metal)
	ship:Box("Fondo", V(X2 - X1, 1.5, Z * 2), V(0, -10, 0), HULL, M.Metal)
	ship:Box("FranjaRoja", V(X2 - X1, 2, Z * 2 + 0.4), V(0, -1, 0), C(180, 40, 40), M.Metal, { transparency = 0 })
	-- proa en punta
	ship:Wedge("Proa", V(Z * 2, 20, 30), V(X2 + 15, 0, 0), HULL, M.Metal, -90)

	-- elevadores y escaleras
	local elevA = { name = "AscensorProa", x = 30, z = -13.6, floors = decks, labels = { "1", "2", "3", "Sol" }, wallColor = C(200, 200, 205) }
	local elevB = { name = "AscensorPopa", x = -30, z = -13.6, floors = decks, labels = { "1", "2", "3", "Sol" }, wallColor = C(200, 200, 205) }
	local hA, hB = Elevator.hole(elevA), Elevator.hole(elevB)
	local SX1, SX2 = -78, -62
	local function stairHole(i)
		if i % 2 == 1 then
			return { SX1, SX2, 10, 16 }
		end
		return { SX1, SX2, 4, 10 }
	end

	-- cubiertas
	for i, y in ipairs(decks) do
		local holes = { hA, hB }
		if i > 1 then
			holes[#holes + 1] = stairHole(i - 1)
		end
		local x1, x2, z = X1, X2, Z
		ship:Slab("Cubierta" .. i, x1, x2, -z, z, y, 1.2, i == 4 and C(170, 130, 90) or C(200, 190, 175), i == 4 and M.WoodPlanks or M.SmoothPlastic, holes)
	end
	-- superestructura (camarotes) entre cubiertas
	local SX, EX, SZ = -82, 72, 20
	for i = 1, 3 do
		local y = decks[i]
		local top = decks[i + 1]
		local win = windows(SX + 1, EX - 1, 7, 4, 4, 9)
		ship:Wall("Camarotes", "x", SZ, SX, EX, y, top, 0.8, WHITE, M.SmoothPlastic, win)
		local back = windows(SX + 1, EX - 1, 7, 4, 4, 9, -38, 38)
		ship:Wall("Camarotes", "x", -SZ, SX, EX, y, top, 0.8, WHITE, M.SmoothPlastic, back)
		local door = { { from = -4, to = 4, bottom = 0, top = 9 } }
		ship:Wall("Camarotes", "z", SX, -SZ, SZ, y, top, 0.8, WHITE, M.SmoothPlastic, door)
		ship:Wall("Camarotes", "z", EX, -SZ, SZ, y, top, 0.8, WHITE, M.SmoothPlastic, { { from = -4, to = 4, bottom = 0, top = 9 } })
		if i % 2 == 1 then
			ship:Stairs("Escalera", SX1, 13, y, top, 6, SX2 - SX1, "+x", C(180, 180, 185), M.Metal)
		else
			ship:Stairs("Escalera", SX2, 7, y, top, 6, SX2 - SX1, "-x", C(180, 180, 185), M.Metal)
		end
		Buildings.Furnish(ship, -50, 10, 0, 18, y, i * 11)
		Buildings.Furnish(ship, 40, 70, 0, 18, y, i * 17)
	end
	Elevator.build(ship, elevA)
	Elevator.build(ship, elevB)

	-- barandillas de la cubierta principal y de la de sol
	for _, y in ipairs({ decks[1], decks[4] }) do
		ship:Wall("Barandilla", "x", Z, X1, X2, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
		ship:Wall("Barandilla", "x", -Z, X1, X2, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
		ship:Wall("Barandilla", "z", X1, -Z, Z, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
		ship:Wall("Barandilla", "z", X2, -Z, Z, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
	end

	-- cubierta de sol: piscina, tumbonas, chimenea y puente de mando
	local sun = b:Group("CubiertaSol")
	local ys = decks[4]
	sun:Box("BordePiscina", V(30, 1.6, 16), V(5, ys + 0.8, 4), C(230, 230, 235), M.Marble)
	sun:Box("Agua", V(28, 0.2, 14), V(5, ys + 1.7, 4), Colors.Water, M.SmoothPlastic, { transparency = 0.3, canCollide = false })
	for k = 0, 5 do
		sun:Box("Tumbona", V(2.4, 1, 6), V(-20 + k * 4, ys + 0.5, 16), C(240, 240, 240), M.Fabric)
	end
	sun:Box("Chimenea", V(14, 22, 10), V(-55, ys + 11, 0), C(200, 40, 40), M.Metal)
	sun:Box("ChimeneaTop", V(14.4, 4, 10.4), V(-55, ys + 20, 0), C(20, 20, 25), M.Metal)
	sun:Box("PuenteMando", V(20, 10, 36), V(80, ys + 5, 0), WHITE, M.SmoothPlastic)
	sun:Box("Ventanal", V(0.4, 4, 34), V(90.2, ys + 6, 0), Colors.Glass, M.Glass, { transparency = 0.4 })
	sun:Board("Nombre", "ISLA DORADA", V(30, 5, 0.4), V(0, 4, Z + 1), HULL, C(255, 220, 120))
	sun:Pillar("Mastil", 95, 0, ys, ys + 24, 0.8, WHITE, M.Metal)
	sun:Box("Radar", V(8, 0.6, 1.4), V(95, ys + 25, 0), Colors.DarkMetal, M.Metal)

	-- botes salvavidas
	for k = 0, 5 do
		local x = -90 + k * 32
		for _, side in ipairs({ -1, 1 }) do
			b:Box("BoteSalvavidas", V(12, 3, 4), V(x, 27, side * (Z + 3)), C(255, 130, 30), M.SmoothPlastic)
			b:Box("Pescante", V(1, 6, 1), V(x, 30, side * (Z + 1)), Colors.DarkMetal, M.Metal)
		end
	end

	-- aparicion: cubierta de proa
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(76 + ix * 8, decks[1] + 1, -16 + iz * 16))
		end
	end
end

return CruiseShip
