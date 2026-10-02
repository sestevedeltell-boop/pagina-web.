-- Rascacielos "Torre Cumbre": 12 plantas + azotea con helipuerto y piscina.
-- 3 ascensores en el nucleo central (13 paradas), escalera de emergencia en zigzag y vestibulo.

local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors
local windows = Util.Windows

local Skyscraper = {
	Title = "Rascacielos",
	Description = "Torre de 12 plantas con 3 ascensores, escalera de emergencia, helipuerto y piscina en la azotea.",
	Lighting = { ClockTime = 17.5, Brightness = 2, OutdoorAmbient = C(120, 110, 130) },
}

local STORY = 14
local LEVELS = 13 -- 12 plantas + azotea

function Skyscraper.Build(b)
	b:Box("Isla", V(300, 10, 300), V(0, -5.5, 0), Colors.Grass, M.Grass)
	b:Sea(-6)

	local tower = b:Group("Torre")
	local x1, x2, z1, z2 = -30, 30, -30, 30
	local lvl, labels = {}, {}
	for i = 1, LEVELS do
		lvl[i] = (i - 1) * STORY
		labels[i] = (i == 1 and "PB") or (i == LEVELS and "R") or tostring(i - 1)
	end

	local elevs = {}
	for _, x in ipairs({ -15, 0, 15 }) do
		elevs[#elevs + 1] = { name = "Ascensor" .. (#elevs + 1), x = x, z = -24, floors = lvl, labels = labels, wallColor = C(70, 74, 88) }
	end
	local elevHoles = {}
	for _, e in ipairs(elevs) do
		elevHoles[#elevHoles + 1] = Elevator.hole(e)
	end

	-- Escalera de emergencia en zigzag (vuelo i sube del nivel i al i+1)
	local function stairHole(i)
		if i % 2 == 1 then
			return { 8, 26, 12, 20 }
		end
		return { 8, 26, 20, 28 }
	end

	-- Forjados
	for i = 1, LEVELS do
		local holes = {}
		for _, h in ipairs(elevHoles) do
			holes[#holes + 1] = h
		end
		if i > 1 then
			holes[#holes + 1] = stairHole(i - 1)
		end
		local th = (i == 1) and 0.5 or 1.5
		tower:Slab("Planta" .. (i - 1), x1, x2, z1, z2, lvl[i], th, i == 1 and C(235, 230, 220) or C(225, 222, 215), M.Marble, holes)
	end

	-- Muros con cristaleras por planta
	for i = 1, LEVELS - 1 do
		local y, top = lvl[i], lvl[i] + STORY
		local front = windows(x1 + 2, x2 - 2, 12, 10, 2, 12)
		if i == 1 then
			front = windows(x1 + 2, x2 - 2, 12, 10, 3, 12, -8, 8)
			front[#front + 1] = { from = -8, to = 8, bottom = 0, top = 11 }
		end
		tower:Wall("FachadaSur" .. i, "x", z2, x1, x2, y, top, 1, C(60, 64, 78), M.Concrete, front)
		tower:Wall("FachadaNorte" .. i, "x", z1, x1, x2, y, top, 1, C(60, 64, 78), M.Concrete)
		tower:Wall("FachadaOeste" .. i, "z", x1, z1, z2, y, top, 1, C(60, 64, 78), M.Concrete, windows(z1 + 2, z2 - 2, 12, 10, 2, 12))
		tower:Wall("FachadaEste" .. i, "z", x2, z1, z2, y, top, 1, C(60, 64, 78), M.Concrete, windows(z1 + 2, z2 - 2, 12, 10, 2, 12))
	end
	-- pilares de esquina
	for _, p in ipairs({ { x1, z1 }, { x1, z2 }, { x2, z1 }, { x2, z2 } }) do
		tower:Box("PilarEsquina", V(2.4, STORY * (LEVELS - 1), 2.4), V(p[1], STORY * (LEVELS - 1) / 2, p[2]), Colors.DarkMetal, M.Metal)
	end

	for _, e in ipairs(elevs) do
		Elevator.build(tower, e)
	end

	-- Escaleras de emergencia
	for i = 1, LEVELS - 1 do
		if i % 2 == 1 then
			tower:Stairs("Escalera" .. i, 8, 16, lvl[i], lvl[i + 1], 8, 18, "+x", C(190, 190, 195), M.Concrete)
		else
			tower:Stairs("Escalera" .. i, 26, 24, lvl[i], lvl[i + 1], 8, 18, "-x", C(190, 190, 195), M.Concrete)
		end
	end

	-- Mobiliario por planta
	local rooms = tower:Group("Plantas")
	for i = 2, LEVELS - 1 do
		local y = lvl[i]
		local g = rooms:Group("Planta" .. (i - 1))
		-- dos "habitaciones": cama + mesita + sofa
		for k, x in ipairs({ -22, -6 }) do
			g:Box("Cama", V(6, 1.6, 8), V(x, y + 0.8, 8 + (k - 1) * 4), C(240, 240, 250), M.Fabric)
			g:Box("Almohada", V(4.5, 0.6, 1.6), V(x, y + 1.9, 8 + (k - 1) * 4 - 3), C(250, 250, 255), M.Fabric)
			g:Box("Mesita", V(2, 2, 2), V(x + 5, y + 1, 4 + (k - 1) * 4), Colors.Wood, M.Wood)
		end
		g:Box("Sofa", V(8, 1.6, 3), V(-14, y + 0.8, 24), Colors.Red, M.Fabric)
		g:Box("RespaldoSofa", V(8, 2.4, 0.8), V(-14, y + 1.8, 25.4), Colors.Red, M.Fabric)
		g:Pillar("Maceta", -26, 26, y, y + 2, 2.8, Colors.Wood, M.Wood)
		g:Ball("Planta", 4, V(-26, y + 4.4, 26), Colors.Green, M.Grass)
		g:Board("Numero", "PLANTA " .. (i - 1), V(14, 3, 0.4), V(0, y + 9, 29.3), Colors.DarkMetal, C(255, 220, 90), Enum.NormalId.Front)
	end
	-- la planta 12 es el Sky Lounge
	local lounge = rooms:Group("SkyLounge")
	local ly = lvl[LEVELS - 1]
	lounge:Box("Barra", V(24, 4, 3), V(-12, ly + 2, 10), Colors.Wood, M.Wood)
	lounge:Board("CartelBar", "SKY BAR", V(10, 2.4, 0.4), V(-12, ly + 6.5, 11.7), Colors.DarkMetal, C(255, 190, 60))
	for k = 0, 3 do
		lounge:Pillar("Mesa", -20 + k * 8, 22, ly, ly + 3.5, 0.8, Colors.DarkMetal, M.Metal)
		lounge:Pillar("MesaTop", -20 + k * 8, 22, ly + 3.5, ly + 4, 5, C(250, 250, 250), M.Marble)
	end

	-- Vestibulo (planta baja)
	local lobby = tower:Group("Vestibulo")
	lobby:Box("Recepcion", V(16, 4, 3), V(18, 2, 4), Colors.Wood, M.Wood)
	lobby:Board("CartelRecepcion", "RECEPCION", V(14, 2.4, 0.4), V(18, 6.3, 5.8), Colors.DarkMetal, C(255, 255, 255))
	lobby:Board("CartelTorre", "TORRE CUMBRE", V(40, 5, 0.6), V(0, 20, z2 + 0.8), Colors.DarkMetal, C(255, 220, 90))
	for _, p in ipairs({ { -26, 20 }, { 26, -6 } }) do
		lobby:Pillar("Maceta", p[1], p[2], 0, 2, 3, Colors.Wood, M.Wood)
		lobby:Ball("Planta", 5, V(p[1], 4.6, p[2]), Colors.Green, M.Grass)
	end

	-- Azotea
	local roof = b:Group("Azotea")
	local ry = lvl[LEVELS]
	for _, w in ipairs({
		{ "x", z2, x1, x2 }, { "x", z1, x1, x2 }, { "z", x1, z1, z2 }, { "z", x2, z1, z2 },
	}) do
		roof:Wall("Barandilla", w[1], w[2], w[3], w[4], ry, ry + 4, 0.4, Colors.Glass, M.Glass, {})
	end
	-- helipuerto
	roof:Pillar("Helipuerto", -14, 12, ry, ry + 0.8, 22, C(70, 70, 75), M.Concrete)
	roof:Pillar("AroHelipuerto", -14, 12, ry + 0.8, ry + 0.9, 18, Colors.Yellow, M.SmoothPlastic)
	roof:Pillar("CentroHelipuerto", -14, 12, ry + 0.9, ry + 1.0, 15, C(70, 70, 75), M.Concrete)
	roof:Board("H", "H", V(8, 0.2, 8), V(-14, ry + 1.1, 12), C(70, 70, 75), C(255, 255, 255), Enum.NormalId.Top)
	-- piscina
	roof:Box("BordePiscina", V(22, 1.6, 14), V(14, ry + 0.8, -6), Colors.Concrete, M.Concrete)
	roof:Box("Agua", V(20, 0.2, 12), V(14, ry + 1.7, -6), Colors.Water, M.SmoothPlastic, { transparency = 0.35, canCollide = false })
	for k = 0, 2 do
		roof:Box("Tumbona", V(2.4, 1, 6), V(-24 + k * 5, ry + 0.5, -2), Colors.White, M.Fabric)
	end
	-- antena y luz
	roof:Pillar("Antena", 24, -24, ry, ry + 26, 1.2, Colors.Red, M.Metal)
	roof:Ball("LuzAntena", 2.4, V(24, ry + 27, -24), Colors.Red, M.Neon)

	-- Plaza y entorno
	local plaza = b:Group("Plaza")
	plaza:Box("Plaza", V(120, 0.5, 70), V(0, -0.25, 62), C(200, 198, 192), M.Concrete)
	plaza:Pillar("Fuente", 0, 55, 0, 1.2, 14, Colors.Concrete, M.Marble)
	plaza:Pillar("AguaFuente", 0, 55, 1.2, 1.5, 11, Colors.Water, M.SmoothPlastic)
	for i = 0, 6 do
		plaza:Pine(-100 + i * 33, 120, 0, 1.3)
		plaza:Pine(-100 + i * 33, -120, 0, 1.3)
	end
	for _, x in ipairs({ -60, -40, 40, 60 }) do
		plaza:Box("Banco", V(7, 1.2, 2), V(x, 0.6, 70), Colors.Wood, M.Wood)
	end

	-- aparicion en la plaza
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-40 + ix * 26, 1, 40 + iz * 16))
		end
	end
end

return Skyscraper
