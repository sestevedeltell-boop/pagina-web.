-- Buildings: piezas grandes reutilizables para los mapas (casas, torres con ascensor, arboles, coches...).
-- Todas las medidas son relativas al origen del builder; el suelo del mapa esta en y = 0.
local Util = require(script.Parent.Util)
local Elevator = require(script.Parent.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors
local windows = Util.Windows

local Buildings = {}

local FURNITURE_COLORS = { C(200, 70, 70), C(70, 110, 200), C(90, 160, 90), C(200, 170, 80), C(150, 90, 170) }

-- Muebles sencillos en una planta (madera y tela: arden)
function Buildings.Furnish(b, x1, x2, z1, z2, y, seed)
	local r = Random.new(seed or 1)
	local w, d = x2 - x1, z2 - z1
	if w < 10 or d < 10 then
		return
	end
	local col = FURNITURE_COLORS[r:NextInteger(1, #FURNITURE_COLORS)]
	local tx, tz = x1 + w * 0.35, z1 + d * 0.55
	b:Box("Mesa", V(4, 0.4, 3), V(tx, y + 3, tz), Colors.Wood, M.Wood)
	b:Box("PataMesa", V(0.5, 3, 0.5), V(tx, y + 1.5, tz), Colors.Wood, M.Wood)
	for _, o in ipairs({ -2.6, 2.6 }) do
		b:Box("Silla", V(1.5, 1.6, 1.5), V(tx + o, y + 0.8, tz), col, M.Fabric)
	end
	if r:NextNumber() < 0.6 then
		b:Box("Sofa", V(6, 1.6, 2.6), V(x1 + w * 0.7, y + 0.8, z1 + 2.5), col, M.Fabric)
		b:Box("RespaldoSofa", V(6, 2.2, 0.8), V(x1 + w * 0.7, y + 1.9, z1 + 1.6), col, M.Fabric)
	else
		b:Box("Cama", V(5, 1.4, 7), V(x1 + w * 0.72, y + 0.7, z1 + 4.5), C(240, 240, 245), M.Fabric)
	end
	b:Box("Estanteria", V(4, 6, 1.2), V(x2 - 3, y + 3, z2 - 1.6), Colors.Wood, M.Wood)
end

-- Casa de 1-3 plantas con puerta delante (+Z), ventanas, escalera interior y tejado.
-- opts: color, roofColor, story (12), roof ("pitched"/"flat"), furnish (true), material
function Buildings.House(b, cx, cz, w, d, floors, opts)
	opts = opts or {}
	local story = opts.story or 12
	local color = opts.color or C(230, 220, 200)
	local mat = opts.material or M.SmoothPlastic
	local x1, x2, z1, z2 = cx - w / 2, cx + w / 2, cz - d / 2, cz + d / 2
	local g = b:Group(opts.name or "Casa")
	local stairLen = story * 1.3
	local stairHole = { x1 + 1.5, x1 + 1.5 + stairLen, z1 + 1, z1 + 5 }
	for i = 0, floors - 1 do
		local y = i * story
		local holes = (i > 0) and { stairHole } or nil
		g:Slab("Suelo", x1, x2, z1, z2, y + (i == 0 and 0.4 or 0), i == 0 and 0.4 or 1, i == 0 and C(150, 110, 80) or C(170, 130, 95), M.WoodPlanks, holes)
		local front = windows(x1 + 1, x2 - 1, 8, 4, 4, 9, i == 0 and cx - 3 or nil, i == 0 and cx + 3 or nil)
		if i == 0 then
			front[#front + 1] = { from = cx - 2.5, to = cx + 2.5, bottom = 0, top = 8 }
		end
		g:Wall("Pared", "x", z2, x1, x2, y, y + story, 0.8, color, mat, front)
		g:Wall("Pared", "x", z1, x1, x2, y, y + story, 0.8, color, mat, windows(x1 + 1, x2 - 1, 8, 4, 4, 9))
		g:Wall("Pared", "z", x1, z1, z2, y, y + story, 0.8, color, mat, windows(z1 + 1, z2 - 1, 8, 4, 4, 9))
		g:Wall("Pared", "z", x2, z1, z2, y, y + story, 0.8, color, mat, windows(z1 + 1, z2 - 1, 8, 4, 4, 9))
		if i < floors - 1 then
			g:Stairs("Escalera", x1 + 1.5, z1 + 3, y, y + story, 4, stairLen, "+x", Colors.Wood, M.Wood)
		end
		if opts.furnish ~= false then
			Buildings.Furnish(g, x1 + 1, x2 - 1, z1 + 6, z2 - 1, y + (i == 0 and 0.4 or 0), math.floor(cx * 7 + cz * 13 + i))
		end
	end
	local top = floors * story
	local roofColor = opts.roofColor or C(170, 70, 50)
	if opts.roof == "flat" then
		g:Slab("Tejado", x1 - 0.5, x2 + 0.5, z1 - 0.5, z2 + 0.5, top + 1, 1, roofColor, M.Slate)
	else
		g:Slab("Techo", x1, x2, z1, z2, top + 0.6, 0.6, color, mat)
		local h = math.min(d, w) * 0.35
		-- dos aguas a lo largo de X
		g:Wedge("Tejado", V(w + 1, h, d / 2 + 0.5), V(cx, top + 0.6 + h / 2, z1 + d / 4 - 0.25), roofColor, M.Slate, 0)
		g:Wedge("Tejado", V(w + 1, h, d / 2 + 0.5), V(cx, top + 0.6 + h / 2, z2 - d / 4 + 0.25), roofColor, M.Slate, 180)
	end
	return g
end

-- Torre de varias plantas con ascensor (pared de atras) y escalera en zigzag (esquina delantera derecha).
-- Requiere w, d >= 30. Devuelve la lista de alturas de planta (incluida la azotea).
-- opts: color, glassColor, story (14), name, labels, furnish, wallColor (hueco del ascensor), roofRail (true)
function Buildings.Tower(b, cx, cz, w, d, floors, opts)
	opts = opts or {}
	local story = opts.story or 14
	local color = opts.color or C(200, 200, 205)
	local x1, x2, z1, z2 = cx - w / 2, cx + w / 2, cz - d / 2, cz + d / 2
	local g = b:Group(opts.name or "Torre")
	local levels, labels = {}, {}
	for i = 1, floors + 1 do
		levels[i] = (i - 1) * story
		labels[i] = (i == 1 and "PB") or (i == floors + 1 and "A") or tostring(i - 1)
	end
	local elev = { name = (opts.name or "Torre") .. "Ascensor", x = cx, z = z1 + 6.4, floors = levels, labels = opts.labels or labels, wallColor = opts.wallColor or C(90, 92, 100) }
	local hole = Elevator.hole(elev)
	local L = story * 1.25
	local sx2 = x2 - 3
	local sx1 = sx2 - L
	local function stairHole(i)
		if i % 2 == 1 then
			return { sx1, sx2, z2 - 10, z2 - 4 }
		end
		return { sx1, sx2, z2 - 16, z2 - 10 }
	end
	for i = 1, floors + 1 do
		local holes = { hole }
		if i > 1 then
			holes[#holes + 1] = stairHole(i - 1)
		end
		g:Slab("Planta", x1, x2, z1, z2, levels[i], i == 1 and 0.5 or 1.2, i == 1 and C(215, 210, 200) or C(205, 200, 195), M.Marble, holes)
	end
	for i = 1, floors do
		local y = levels[i]
		local front = windows(x1 + 1, x2 - 1, 10, 8, 2, story - 2)
		if i == 1 then
			front = windows(x1 + 1, x2 - 1, 10, 8, 2, story - 2, cx - 6, cx + 6)
			front[#front + 1] = { from = cx - 5, to = cx + 5, bottom = 0, top = 9 }
		end
		g:Wall("Fachada", "x", z2, x1, x2, y, y + story, 1, color, M.Concrete, front)
		g:Wall("Fachada", "x", z1, x1, x2, y, y + story, 1, color, M.Concrete)
		g:Wall("Fachada", "z", x1, z1, z2, y, y + story, 1, color, M.Concrete, windows(z1 + 1, z2 - 1, 10, 8, 2, story - 2))
		g:Wall("Fachada", "z", x2, z1, z2, y, y + story, 1, color, M.Concrete, windows(z1 + 1, z2 - 1, 10, 8, 2, story - 2))
		if i % 2 == 1 then
			g:Stairs("Escalera", sx1, z2 - 7, y, y + story, 6, L, "+x", C(180, 180, 185), M.Concrete)
		else
			g:Stairs("Escalera", sx2, z2 - 13, y, y + story, 6, L, "-x", C(180, 180, 185), M.Concrete)
		end
		if opts.furnish ~= false and i > 1 then
			Buildings.Furnish(g, x1 + 2, sx1 - 2, z1 + 14, z2 - 2, y, i * 31 + math.floor(cx))
		end
	end
	Elevator.build(g, elev)
	local roofY = levels[#levels]
	if opts.roofRail ~= false then
		for _, wdef in ipairs({ { "x", z2, x1, x2 }, { "x", z1, x1, x2 }, { "z", x1, z1, z2 }, { "z", x2, z1, z2 } }) do
			g:Wall("Barandilla", wdef[1], wdef[2], wdef[3], wdef[4], roofY, roofY + 3.5, 0.4, Colors.Glass, M.Glass, {})
		end
	end
	return levels, g
end

function Buildings.Palm(b, x, z, y, scale)
	scale = scale or 1
	local h = 14 * scale
	b:Pillar("TroncoPalmera", x, z, y, y + h, 1.4 * scale, C(140, 105, 70), M.Wood)
	for i = 0, 5 do
		local a = i / 6 * 360
		local rad = math.rad(a)
		b:Box("Hoja", V(9 * scale, 0.4, 2.4 * scale), V(x + math.cos(rad) * 4 * scale, y + h - 0.6, z + math.sin(rad) * 4 * scale), C(60, 150, 60), M.Grass, { rot = V(0, -a, -18) })
	end
end

function Buildings.Car(b, x, z, y, color, rotY)
	local g = b:At(V(x, y, z), "Coche")
	local along = (rotY or 0) % 180 == 0
	local size = along and V(5, 1.6, 10) or V(10, 1.6, 5)
	local cab = along and V(4.4, 1.5, 5) or V(5, 1.5, 4.4)
	g:Box("Carroceria", size, V(0, 1.4, 0), color, M.Metal)
	g:Box("Cabina", cab, V(0, 2.9, 0), Colors.Glass, M.Glass, { transparency = 0.35 })
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local px = along and sx * 2.4 or sz * 3.4
			local pz = along and sz * 3.4 or sx * 2.4
			g:Box("Rueda", V(1, 1.8, 1.8), V(px, 0.9, pz), C(25, 25, 25), M.Rubber, { shape = Enum.PartType.Cylinder, rot = along and V(0, 0, 0) or V(0, 90, 0) })
		end
	end
	return g
end

function Buildings.Lamp(b, x, z, y, h)
	h = h or 10
	b:Pillar("Farola", x, z, y, y + h, 0.6, Colors.DarkMetal, M.Metal)
	local lamp = b:Ball("Bombilla", 1.6, V(x, y + h + 0.6, z), C(255, 240, 200), M.Neon)
	Util.AddLight(lamp, 22, 1.1)
	return lamp
end

return Buildings
