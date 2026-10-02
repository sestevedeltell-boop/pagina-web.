-- Util: herramientas para construir mapas por codigo.
-- Todo es relativo al "origin" del builder, asi un mapa se puede construir en cualquier sitio.

local Util = {}

local V = Vector3.new
local C = Color3.fromRGB
local M = Enum.Material

Util.V = V
Util.C = C
Util.M = M

Util.Colors = {
	White = C(240, 240, 240),
	Concrete = C(160, 160, 165),
	DarkConcrete = C(95, 95, 100),
	Asphalt = C(45, 45, 50),
	Glass = C(170, 215, 235),
	Metal = C(180, 185, 190),
	DarkMetal = C(70, 72, 78),
	Red = C(200, 50, 50),
	Blue = C(50, 100, 200),
	Yellow = C(240, 200, 50),
	Orange = C(235, 130, 40),
	Green = C(70, 150, 70),
	Grass = C(90, 140, 70),
	Sand = C(220, 200, 150),
	Wood = C(140, 100, 60),
	Snow = C(245, 250, 255),
	Water = C(40, 110, 175),
}

local YIELD_EVERY = 80 -- cada tantas piezas se cede el hilo para no congelar el servidor

local Builder = {}
Builder.__index = Builder

-- parent: donde van las piezas, origin: Vector3 donde esta el (0,0,0) del mapa
function Util.newBuilder(parent, origin)
	return setmetatable({
		parent = parent,
		origin = origin,
		state = { count = 0, spawns = {} }, -- compartido con todos los builders hijos
	}, Builder)
end

function Builder:Count()
	return self.state.count
end

function Builder:Spawns()
	return self.state.spawns
end

-- Carpeta (o modelo) nueva dentro de este builder
function Builder:Group(name, className)
	local inst = Instance.new(className or "Folder")
	inst.Name = name
	inst.Parent = self.parent
	return setmetatable({ parent = inst, origin = self.origin, state = self.state }, Builder)
end

-- Igual que Group pero ademas desplaza el origen (para construir algo reutilizable en otro sitio)
function Builder:At(offset, name, className)
	local g = self:Group(name, className)
	g.origin = self.origin + offset
	return g
end

-- Pieza basica. size/pos son Vector3 (pos = centro, relativo al origen)
-- opts: shape, transparency, canCollide, rot (grados, Vector3), velocity, reflectance
function Builder:Box(name, size, pos, color, material, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Color = color or Util.Colors.Concrete
	p.Material = material or M.SmoothPlastic
	if opts.shape then
		p.Shape = opts.shape
	end
	if opts.transparency then
		p.Transparency = opts.transparency
	end
	if opts.canCollide == false then
		p.CanCollide = false
	end
	if opts.reflectance then
		p.Reflectance = opts.reflectance
	end
	local cf = CFrame.new(self.origin + pos)
	if opts.rot then
		cf = cf * CFrame.Angles(math.rad(opts.rot.X), math.rad(opts.rot.Y), math.rad(opts.rot.Z))
	end
	p.CFrame = cf
	if opts.velocity then
		p.AssemblyLinearVelocity = opts.velocity
	end
	p.Parent = self.parent

	local s = self.state
	s.count = s.count + 1
	if s.count % YIELD_EVERY == 0 then
		task.wait()
	end
	return p
end

-- Columna vertical redonda
function Builder:Pillar(name, x, z, y1, y2, diameter, color, material)
	return self:Box(name, V(y2 - y1, diameter, diameter), V(x, (y1 + y2) / 2, z), color, material, {
		shape = Enum.PartType.Cylinder,
		rot = V(0, 0, 90),
	})
end

function Builder:Ball(name, diameter, pos, color, material)
	return self:Box(name, V(diameter, diameter, diameter), pos, color, material, { shape = Enum.PartType.Ball })
end

-- Pared recta con huecos.
-- axis "x": la pared corre a lo largo de X, situada en z = fixed (a1..a2 son coordenadas X)
-- axis "z": la pared corre a lo largo de Z, situada en x = fixed (a1..a2 son coordenadas Z)
-- openings: lista de { from, to, bottom, top, glass } (bottom/top relativos a y1)
function Builder:Wall(name, axis, fixed, a1, a2, y1, y2, th, color, material, openings)
	openings = openings or {}
	table.sort(openings, function(p, q)
		return p.from < q.from
	end)
	local h = y2 - y1

	local function seg(from, to, bottom, top, segColor, segMat, transp, segName)
		if to - from < 0.05 or top - bottom < 0.05 then
			return
		end
		local len = to - from
		local cy = y1 + (bottom + top) / 2
		local mid = (from + to) / 2
		local size, pos
		if axis == "x" then
			size = V(len, top - bottom, th)
			pos = V(mid, cy, fixed)
		else
			size = V(th, top - bottom, len)
			pos = V(fixed, cy, mid)
		end
		local useMat = segMat or material
		if useMat == M.Glass and transp == nil then
			transp = 0.55 -- el cristal siempre es translucido
		end
		self:Box(segName or name, size, pos, segColor or color, useMat, { transparency = transp })
	end

	local cursor = a1
	for _, o in ipairs(openings) do
		seg(cursor, o.from, 0, h)
		local bottom = o.bottom or 0
		local top = o.top or h
		seg(o.from, o.to, 0, bottom)
		seg(o.from, o.to, top, h)
		if o.glass then
			seg(o.from, o.to, bottom, top, Util.Colors.Glass, M.Glass, 0.55, name .. "Glass")
		end
		cursor = o.to
	end
	seg(cursor, a2, 0, h)
end

-- Lista de huecos de ventana para Builder:Wall: centros cada `step`, ancho `w`.
-- skipFrom/skipTo (opcional) dejan sin ventanas un tramo de la pared.
function Util.Windows(a1, a2, step, w, bottom, top, skipFrom, skipTo)
	local list = {}
	local c = a1 + step / 2
	while c + w / 2 <= a2 do
		local from, to = c - w / 2, c + w / 2
		if not (skipFrom and to > skipFrom and from < skipTo) then
			list[#list + 1] = { from = from, to = to, bottom = bottom, top = top, glass = true }
		end
		c = c + step
	end
	return list
end

-- Suelo/techo rectangular con agujeros. holes = { {x1, x2, z1, z2}, ... }
function Builder:Slab(name, x1, x2, z1, z2, ytop, th, color, material, holes)
	local rects = { { x1, x2, z1, z2 } }
	for _, h in ipairs(holes or {}) do
		local out = {}
		for _, r in ipairs(rects) do
			if h[2] <= r[1] or h[1] >= r[2] or h[4] <= r[3] or h[3] >= r[4] then
				out[#out + 1] = r
			else
				local hx1, hx2 = math.max(h[1], r[1]), math.min(h[2], r[2])
				local hz1, hz2 = math.max(h[3], r[3]), math.min(h[4], r[4])
				if hx1 > r[1] then
					out[#out + 1] = { r[1], hx1, r[3], r[4] }
				end
				if hx2 < r[2] then
					out[#out + 1] = { hx2, r[2], r[3], r[4] }
				end
				if hz1 > r[3] then
					out[#out + 1] = { hx1, hx2, r[3], hz1 }
				end
				if hz2 < r[4] then
					out[#out + 1] = { hx1, hx2, hz2, r[4] }
				end
			end
		end
		rects = out
	end
	for _, r in ipairs(rects) do
		self:Box(
			name,
			V(r[2] - r[1], th, r[4] - r[3]),
			V((r[1] + r[2]) / 2, ytop - th / 2, (r[3] + r[4]) / 2),
			color,
			material
		)
	end
end

-- Escalera de escalones macizos. (x, z) = pie de la escalera (centro del ancho).
-- dir = hacia donde se sube: "+x", "-x", "+z", "-z"
function Builder:Stairs(name, x, z, y1, y2, width, length, dir, color, material)
	local n = math.max(2, math.ceil(y2 - y1))
	local rise, run = (y2 - y1) / n, length / n
	for i = 1, n do
		local hgt = rise * i
		local off = run * (i - 0.5)
		local size, pos
		if dir == "+x" then
			size, pos = V(run, hgt, width), V(x + off, y1 + hgt / 2, z)
		elseif dir == "-x" then
			size, pos = V(run, hgt, width), V(x - off, y1 + hgt / 2, z)
		elseif dir == "+z" then
			size, pos = V(width, hgt, run), V(x, y1 + hgt / 2, z + off)
		else
			size, pos = V(width, hgt, run), V(x, y1 + hgt / 2, z - off)
		end
		self:Box(name, size, pos, color, material)
	end
end

-- Escalera de mano (se trepa)
function Builder:Ladder(name, x, z, y1, y2)
	local t = Instance.new("TrussPart")
	t.Name = name
	t.Anchored = true
	t.Size = V(2, y2 - y1, 2)
	t.CFrame = CFrame.new(self.origin + V(x, (y1 + y2) / 2, z))
	t.Parent = self.parent
	self.state.count = self.state.count + 1
	return t
end

-- Texto en una cara de una pieza
function Builder:Sign(part, text, face, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Back -- Back = cara +Z: el cartel se lee mirando hacia -Z
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.Parent = gui
	return label
end

-- Cartel: caja con texto en la cara +Z por defecto
function Builder:Board(name, text, size, pos, bg, fg, face)
	local p = self:Box(name, size, pos, bg or Util.Colors.DarkMetal, M.SmoothPlastic)
	self:Sign(p, text, face, fg)
	return p
end

function Util.AddLight(part, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Range = range or 20
	l.Brightness = brightness or 1
	if color then
		l.Color = color
	end
	l.Parent = part
	return l
end

-- Punto de aparicion de jugadores (invisible)
function Builder:Spawn(pos)
	local p = self:Box("SpawnPoint", V(4, 1, 4), pos, Util.Colors.White, M.SmoothPlastic, {
		transparency = 1,
		canCollide = false,
	})
	local list = self.state.spawns
	list[#list + 1] = p
	return p
end

-- Mar con plano de muerte: tocar el agua mata al jugador
function Builder:Sea(y, extent, color, transparency)
	extent = math.min(extent or 2048, 2048) -- una pieza mide como mucho 2048 studs
	local p = self:Box("Mar", V(extent, 2, extent), V(0, y - 1, 0), color or Util.Colors.Water, M.SmoothPlastic, {
		transparency = transparency or 0.15,
		canCollide = false,
	})
	p.Touched:Connect(function(hit)
		local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.Health = 0
		end
	end)
	return p
end

-- Plano de muerte invisible (vacio): tocarlo mata al jugador
function Builder:KillPlane(y, extent)
	return self:Sea(y, extent, Util.Colors.DarkMetal, 1)
end

-- Abeto simple (tronco + 3 pisos)
function Builder:Pine(x, z, y, scale)
	scale = scale or 1
	self:Pillar("Tronco", x, z, y, y + 5 * scale, 1.2 * scale, Util.Colors.Wood, M.Wood)
	for i = 0, 2 do
		local d = (8 - i * 2.2) * scale
		self:Pillar("Copa", x, z, y + (3 + i * 2.2) * scale, y + (5.4 + i * 2.2) * scale, d, C(35, 95, 50), M.Grass)
	end
end

return Util
