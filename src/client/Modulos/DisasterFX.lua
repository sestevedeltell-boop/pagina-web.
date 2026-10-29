-- DisasterFX: dibuja en el cliente todos los efectos de los desastres (no se replican piezas desde el servidor).
-- Mensajes del servidor: (tipo, idDesastre, ...). Ver Hazards.lua y Disasters/*.lua en el servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Net = require(Shared:WaitForChild("Net"))
local Paths = require(Shared:WaitForChild("Paths"))

local player = Players.LocalPlayer
local C = Color3.fromRGB
local V = Vector3.new

local DisasterFX = {}

local UI, Quality, SoundFX, Popups
local folder
local buckets = {} -- [id] = { inst = {}, update = {}, zones = {}, ufos = {} }
local overlay, banner
local shakeIntensity, shakeEnd = 0, 0
DisasterFX.ShakeScale = 1

local function now()
	return workspace:GetServerTimeNow()
end

local function bucket(id)
	local b = buckets[id]
	if not b then
		b = { inst = {}, update = {}, zones = {}, ufos = {} }
		buckets[id] = b
	end
	return b
end

local function track(id, inst)
	table.insert(bucket(id).inst, inst)
	return inst
end

local function onUpdate(id, fn)
	table.insert(bucket(id).update, fn)
end

local function clearId(id)
	local b = buckets[id]
	if not b then
		return
	end
	for _, inst in ipairs(b.inst) do
		if inst.Parent then
			inst:Destroy()
		end
	end
	buckets[id] = nil
	if b.tinted then
		overlay.BackgroundTransparency = 1
	end
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = folder
	return p
end

local function currentMap()
	for _, c in ipairs(workspace:GetChildren()) do
		if c.Name:sub(1, 11) == "MapaActual_" then
			return c
		end
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local function groundAt(x, z, fallback)
	local map = currentMap()
	if not map then
		return fallback
	end
	rayParams.FilterDescendantsInstances = { map }
	local hit = workspace:Raycast(V(x, fallback + 600, z), V(0, -1400, 0), rayParams)
	return hit and hit.Position.Y or fallback
end

local function camPos()
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame.Position or Vector3.zero
end

local function shake(intensity, seconds)
	if intensity * DisasterFX.ShakeScale >= shakeIntensity or os.clock() >= shakeEnd then
		shakeIntensity = intensity * DisasterFX.ShakeScale
	end
	shakeEnd = math.max(shakeEnd, os.clock() + seconds)
end
DisasterFX.Shake = shake

-- ======================================================================
-- Cartel de aviso
-- ======================================================================
local bannerToken = 0
local function showBanner(info, delay)
	bannerToken = bannerToken + 1
	local token = bannerToken
	banner.Icon.Text = info.Icon or "⚠️"
	banner.Title.Text = string.upper(info.Title or "")
	banner.Title.TextColor3 = info.Color or C(255, 230, 120)
	banner.Desc.Text = info.Desc or ""
	banner.Frame.Visible = true
	UI.Pop(banner.Frame, 0.2)
	SoundFX.Play("Warning", 0.7)
	local endAt = os.clock() + (delay or 0)
	task.spawn(function()
		while token == bannerToken and os.clock() < endAt do
			banner.Count.Text = "Empieza en " .. math.ceil(endAt - os.clock())
			task.wait(0.2)
		end
		if token == bannerToken then
			banner.Count.Text = "¡YA!"
			task.wait(3)
			if token == bannerToken then
				banner.Frame.Visible = false
			end
		end
	end)
end

-- ======================================================================
-- Clima (particulas alrededor de la camara)
-- ======================================================================
local WEATHER = {
	rain = { color = C(170, 190, 230), rate = 400, speed = 90, size = 0.25, length = 3, transparency = 0.4 },
	acid = { color = C(140, 255, 90), rate = 400, speed = 80, size = 0.25, length = 3, transparency = 0.3 },
	snow = { color = C(255, 255, 255), rate = 300, speed = 12, size = 0.5, length = 0.5, transparency = 0.1, spread = 30 },
	sand = { color = C(220, 180, 110), rate = 500, speed = 40, size = 0.6, length = 1, transparency = 0.35, sideways = true },
	hail = { color = C(220, 240, 255), rate = 250, speed = 110, size = 0.5, length = 1, transparency = 0.1 },
}

local function weather(id, kind)
	local w = WEATHER[kind]
	if not w then
		return
	end
	local emitterPart = track(id, part({ Name = "Clima", Size = V(120, 1, 120), Transparency = 1 }))
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(w.color)
	e.LightEmission = 0.2
	e.Size = NumberSequence.new(w.size)
	e.Transparency = NumberSequence.new(w.transparency)
	e.Lifetime = NumberRange.new(1.5, 2.2)
	e.Speed = NumberRange.new(w.speed * 0.8, w.speed)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(w.spread or 5, w.spread or 5)
	if w.length > 1 then
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new(w.length)
	end
	e.Parent = emitterPart
	local function applyRate()
		e.Rate = w.rate * ({ 0.25, 0.6, 1 })[Quality.Level]
	end
	applyRate()
	Quality.OnChanged(applyRate)
	local t = 0
	onUpdate(id, function()
		local p = camPos()
		t = t + 1
		local off = w.sideways and V(math.sin(t * 0.01) * 30, 0, 0) or Vector3.zero
		emitterPart.CFrame = CFrame.new(p + V(0, 40, 0) + off)
		return true
	end)
end

-- ======================================================================
-- Visuales con recorrido (tornado, agujero negro, ovni)
-- ======================================================================
local function tornadoVisual(id, data)
	local path = Paths.Make(data.points, data.speed, data.t0, data.loop)
	local layers = {}
	for i = 1, 9 do
		local d = 8 + i * 5.5
		layers[i] = track(id, part({
			Name = "Embudo",
			Shape = Enum.PartType.Cylinder,
			Size = V(15, d, d),
			Color = C(120 + i * 3, 120 + i * 3, 125 + i * 3),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.45 + i * 0.03,
		}))
	end
	local bits = {}
	local nBits = ({ 8, 18, 30 })[Quality.Level]
	for i = 1, nBits do
		bits[i] = {
			p = track(id, part({ Name = "Escombro", Size = V(1.5, 1.5, 1.5), Color = i % 2 == 0 and C(130, 95, 60) or C(140, 140, 145), Material = Enum.Material.Wood })),
			a = math.random() * math.pi * 2,
			h = math.random(),
		}
	end
	local base = groundAt(path.points[1][1], path.points[1][2], 0)
	local lastRay = 0
	local smoothBase = base
	onUpdate(id, function(t)
		local x, z = Paths.At(path, t)
		if os.clock() - lastRay > 0.25 then
			lastRay = os.clock()
			base = groundAt(x, z, smoothBase)
		end
		smoothBase = smoothBase + (base - smoothBase) * 0.1
		for i, l in ipairs(layers) do
			local wob = math.sin(t * 2 + i * 0.6) * i * 0.4
			l.CFrame = CFrame.new(x + wob, smoothBase + (i - 0.5) * 15, z) * CFrame.Angles(0, t * 3 + i, math.rad(90))
		end
		for _, b in ipairs(bits) do
			local ang = b.a + t * (3.4 - b.h * 1.8)
			local r = 6 + b.h * 32
			b.p.CFrame = CFrame.new(x + math.cos(ang) * r, smoothBase + b.h * 130, z + math.sin(ang) * r) * CFrame.Angles(t * 3, t * 2, 0)
		end
		local d = (camPos() - V(x, smoothBase, z)).Magnitude
		if d < 120 then
			shake(0.6 * (1 - d / 120), 0.3)
		end
		return true
	end)
end

local function blackHoleVisual(id, data)
	local path = Paths.Make(data.points, data.speed, data.t0, data.loop)
	local core = track(id, part({ Name = "AgujeroNegro", Shape = Enum.PartType.Ball, Size = V(12, 12, 12), Color = C(0, 0, 0), Material = Enum.Material.SmoothPlastic }))
	local glow = track(id, part({ Name = "Halo", Shape = Enum.PartType.Ball, Size = V(18, 18, 18), Color = C(140, 80, 255), Transparency = 0.7 }))
	local rings = {}
	for i = 1, 3 do
		rings[i] = track(id, part({ Name = "Anillo", Shape = Enum.PartType.Cylinder, Size = V(0.4, 26 + i * 10, 26 + i * 10), Color = C(160 + i * 20, 90, 255), Transparency = 0.5 + i * 0.1 }))
	end
	local light = Instance.new("PointLight")
	light.Color = C(160, 90, 255)
	light.Range = 60
	light.Brightness = 3
	light.Parent = glow
	local base = groundAt(path.points[1][1], path.points[1][2], 0)
	local lastRay = 0
	local t0 = now()
	onUpdate(id, function(t)
		local x, z = Paths.At(path, t)
		if os.clock() - lastRay > 0.5 then
			lastRay = os.clock()
			base = groundAt(x, z, base)
		end
		local grow = 1 + math.clamp((t - t0) / 150, 0, 1) * 0.8
		local center = V(x, base + (data.height or 25), z)
		core.Size = V(12, 12, 12) * grow
		core.CFrame = CFrame.new(center)
		glow.Size = V(18, 18, 18) * grow * (1 + math.sin(t * 4) * 0.05)
		glow.CFrame = CFrame.new(center)
		for i, r in ipairs(rings) do
			r.CFrame = CFrame.new(center) * CFrame.Angles(math.sin(t * 0.7 + i) * 0.4, t * (1.5 + i * 0.4), math.rad(90))
		end
		return true
	end)
end

local function ufoVisual(id, data)
	local path = Paths.Make(data.points, data.speed, data.t0, data.loop)
	local disc = track(id, part({ Name = "Ovni", Shape = Enum.PartType.Cylinder, Size = V(3, 26, 26), Color = C(160, 165, 175), Material = Enum.Material.Metal }))
	local dome = track(id, part({ Name = "Cupula", Shape = Enum.PartType.Ball, Size = V(11, 11, 11), Color = C(120, 255, 200), Material = Enum.Material.Glass, Transparency = 0.3 }))
	local ring = track(id, part({ Name = "Luces", Shape = Enum.PartType.Cylinder, Size = V(1, 28, 28), Color = C(120, 255, 200), Transparency = 0.2 }))
	local beam = track(id, part({ Name = "Rayo", Shape = Enum.PartType.Cylinder, Size = V(1, 20, 20), Color = C(120, 255, 170), Transparency = 1 }))
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 80
	light.Angle = 40
	light.Color = C(120, 255, 200)
	light.Brightness = 4
	light.Parent = disc
	local entry = { beamUntil = 0 }
	bucket(id).ufos[data.index or 1] = entry
	local base = groundAt(path.points[1][1], path.points[1][2], 0)
	onUpdate(id, function(t)
		local x, z = Paths.At(path, t)
		local y = base + (data.height or 70) + math.sin(t * 1.5 + (data.index or 1)) * 2
		local cf = CFrame.new(x, y, z)
		disc.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
		dome.CFrame = cf + V(0, 2.5, 0)
		ring.CFrame = cf * CFrame.Angles(0, t * 2, math.rad(90)) - V(0, 1, 0)
		if os.clock() < entry.beamUntil then
			local h = y - base
			beam.Size = V(h, 20, 20)
			beam.CFrame = CFrame.new(x, base + h / 2, z) * CFrame.Angles(0, 0, math.rad(90))
			beam.Transparency = 0.55 + math.sin(t * 10) * 0.1
		else
			beam.Transparency = 1
		end
		return true
	end)
end

-- ======================================================================
-- Mensajes
-- ======================================================================
local handlers = {}

handlers.banner = function(id, info, delay)
	showBanner(info, delay)
end

handlers["end"] = function(id)
	clearId(id)
end

handlers.clear = function()
	for id in pairs(buckets) do
		clearId(id)
	end
	overlay.BackgroundTransparency = 1
	shakeIntensity = 0
	banner.Frame.Visible = false
end

handlers.shake = function(id, intensity, seconds)
	shake(intensity, seconds)
end

handlers.flash = function()
	overlay.BackgroundColor3 = Color3.new(1, 1, 1)
	overlay.BackgroundTransparency = 0.3
	UI.Tween(overlay, 0.35, { BackgroundTransparency = 1 })
end

handlers.tint = function(id, color, transparency)
	overlay.BackgroundColor3 = color
	overlay.BackgroundTransparency = transparency
	bucket(id).tinted = true
end

handlers.weather = weather

handlers.marker = function(id, pos, radius, color, seconds)
	local p = track(id, part({
		Name = "Aviso",
		Shape = Enum.PartType.Cylinder,
		Size = V(0.3, radius * 2, radius * 2),
		CFrame = CFrame.new(pos + V(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.6,
	}))
	local born = os.clock()
	onUpdate(id, function()
		local age = os.clock() - born
		if age >= seconds or not p.Parent then
			p:Destroy()
			return false
		end
		p.Transparency = 0.35 + 0.3 * math.abs(math.sin(age * (4 + age * 4)))
		return true
	end)
end

handlers.markers = function(id, list, color)
	for _, pos in ipairs(list or {}) do
		track(id, part({
			Name = "Baliza",
			Size = V(1, 60, 1),
			CFrame = CFrame.new(pos + V(0, 30, 0)),
			Color = color,
			Transparency = 0.4,
		}))
	end
end

handlers.meteor = function(id, from, to, seconds, color, size)
	local m = track(id, part({ Name = "Meteoro", Shape = Enum.PartType.Ball, Size = V(size, size, size), Color = color, CFrame = CFrame.new(from) }))
	if Quality.Level >= 2 then
		local a0 = Instance.new("Attachment")
		a0.Position = V(0, size * 0.4, 0)
		a0.Parent = m
		local a1 = Instance.new("Attachment")
		a1.Position = V(0, -size * 0.4, 0)
		a1.Parent = m
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.5
		trail.Color = ColorSequence.new(color, C(80, 60, 50))
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.LightEmission = 1
		trail.Parent = m
		local fire = Instance.new("Fire")
		fire.Size = size * 1.5
		fire.Heat = 0
		fire.Parent = m
	end
	local born = os.clock()
	onUpdate(id, function()
		local k = (os.clock() - born) / seconds
		if k >= 1 or not m.Parent then
			m:Destroy()
			return false
		end
		local pos = from:Lerp(to, k * k)
		m.CFrame = CFrame.new(pos)
		return true
	end)
end

handlers.explosion = function(id, pos, radius, color)
	local e = track(id, part({ Name = "Explosion", Shape = Enum.PartType.Ball, Size = V(3, 3, 3), Color = color, CFrame = CFrame.new(pos + V(0, 2, 0)), Transparency = 0.15 }))
	local big = radius * 2.3
	UI.Tween(e, 0.45, { Size = V(big, big, big), Transparency = 1 })
	task.delay(0.5, function()
		e:Destroy()
	end)
	local d = (camPos() - pos).Magnitude
	if d < radius * 5 then
		shake(math.clamp(1.4 * (1 - d / (radius * 5)), 0.1, 1.4), 0.45)
	end
	if d < 300 then
		SoundFX.PlayAt("Explosion", pos, 0.8)
	end
end

handlers.bolt = function(id, from, to, color)
	local segments = 6
	local prev = from
	for i = 1, segments do
		local k = i / segments
		local target = from:Lerp(to, k)
		if i < segments then
			target = target + V((math.random() - 0.5) * 10, 0, (math.random() - 0.5) * 10)
		end
		local mid = (prev + target) / 2
		local len = (target - prev).Magnitude
		local seg = track(id, part({ Name = "Rayo", Size = V(0.8, 0.8, len), Color = color, CFrame = CFrame.lookAt(mid, target) }))
		task.delay(0.18, function()
			seg:Destroy()
		end)
		prev = target
	end
	local d = (camPos() - to).Magnitude
	if d < 200 then
		handlers.flash()
	end
	if d < 400 then
		SoundFX.PlayAt("Thunder", to, 1)
	end
end

handlers.zone = function(id, key, pos, radius, color, fire)
	local b = bucket(id)
	local z = b.zones[key]
	if not z then
		local p = track(id, part({
			Name = "Zona",
			Shape = Enum.PartType.Ball,
			Size = V(1, 1, 1),
			CFrame = CFrame.new(pos + V(0, 1, 0)),
			Color = color,
			Transparency = 0.55,
		}))
		if fire and Quality.Level >= 2 then
			local f = Instance.new("Fire")
			f.Size = 20
			f.Heat = 12
			f.Parent = p
		end
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 30
		light.Brightness = 2
		light.Parent = p
		z = { part = p }
		b.zones[key] = z
	end
	local d = radius * 2
	UI.Tween(z.part, 1, { Size = V(d, d, d) }, Enum.EasingStyle.Linear)
end

handlers.liquid = function(id, data)
	local mat = Enum.Material.SmoothPlastic
	pcall(function()
		mat = Enum.Material[data.material]
	end)
	local p = track(id, part({
		Name = "Liquido",
		Size = V(data.sx, 4, data.sz),
		CFrame = CFrame.new(data.cx, data.y0 - 2, data.cz),
		Color = data.color,
		Material = mat,
		Transparency = data.transparency,
	}))
	onUpdate(id, function(t)
		local level = Paths.Level(data.y0, data.y1, data.t0, data.rise, t)
		p.CFrame = CFrame.new(data.cx, level - 2, data.cz)
		return true
	end)
end

handlers.path = function(id, kind, data)
	if kind == "Tornado" then
		tornadoVisual(id, data)
	elseif kind == "BlackHole" then
		blackHoleVisual(id, data)
	elseif kind == "UFO" then
		ufoVisual(id, data)
	end
end

handlers.beam = function(id, index, seconds)
	local entry = bucket(id).ufos[index]
	if entry then
		entry.beamUntil = os.clock() + seconds
	end
end

handlers.wave = function(id, data)
	local dir = data.dir
	local horizontal = dir.X ~= 0
	local size = horizontal and V(data.thick, data.height, data.width) or V(data.width, data.height, data.thick)
	local w = track(id, part({ Name = "Ola", Size = size, Color = C(40, 120, 210), Material = Enum.Material.SmoothPlastic, Transparency = 0.25 }))
	local foamSize = horizontal and V(data.thick * 0.6, 2, data.width) or V(data.width, 2, data.thick * 0.6)
	local foam = track(id, part({ Name = "Espuma", Size = foamSize, Color = C(235, 245, 255), Transparency = 0.2, Material = Enum.Material.SmoothPlastic }))
	onUpdate(id, function(t)
		local k = t - data.t0
		if k > data.duration + 2 then
			w:Destroy()
			foam:Destroy()
			return false
		end
		local front = data.start + dir * data.speed * math.max(0, k)
		local center = front - dir * data.thick / 2 + V(0, data.height / 2, 0)
		w.CFrame = CFrame.new(center)
		foam.CFrame = CFrame.new(center + V(0, data.height / 2, 0) + dir * data.thick * 0.2)
		local d = (camPos() - center).Magnitude
		if d < 150 then
			shake(0.7 * (1 - d / 150), 0.3)
		end
		return true
	end)
end

-- bola de nieve de la avalancha: misma trayectoria que en el servidor, rodando
handlers.roller = function(id, data)
	local d = data.radius * 2
	local ball = track(id, part({
		Name = "BolaNieve",
		Shape = Enum.PartType.Ball,
		Size = V(d, d, d),
		Color = C(245, 250, 255),
		Material = Enum.Material.Snow,
		CFrame = CFrame.new(data.start),
	}))
	local axis = V(data.dir.Z, 0, -data.dir.X)
	onUpdate(id, function(t)
		local k = t - data.t0
		if k > data.duration + 1 then
			ball:Destroy()
			return false
		end
		local pos = data.start + data.dir * data.speed * math.max(0, k)
		local spin = data.speed * math.max(0, k) / data.radius
		ball.CFrame = CFrame.new(pos) * CFrame.fromAxisAngle(axis, -spin)
		local dist = (camPos() - pos).Magnitude
		if dist < 120 and k >= 0 then
			shake(0.8 * (1 - dist / 120), 0.3)
		end
		return true
	end)
end

handlers.infected = function(id, userId, on)
	if userId == player.UserId and Popups then
		if on then
			Popups.Toast("🦠 ¡Estas infectado! Busca una estacion de cura (cruz verde)", C(110, 255, 90))
		else
			Popups.Toast("✚ Te has curado", C(80, 255, 140))
		end
	end
end

function DisasterFX.Init(modules)
	UI, Quality, SoundFX, Popups = modules.UI, modules.Quality, modules.SoundFX, modules.Popups
	folder = Instance.new("Folder")
	folder.Name = "EfectosLocales"
	folder.Parent = workspace

	local gui = UI.Gui("DesastresGui", 4, true)
	overlay = UI.New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		Parent = gui,
	})

	local frame = UI.Panel(gui, {
		Name = "Aviso",
		Size = UDim2.new(0, 560, 0, 120),
		Position = UDim2.new(0.5, 0, 0, 96),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C(70, 12, 12),
		BackgroundTransparency = 0.1,
		Visible = false,
	})
	UI.Stroke(frame, C(255, 90, 60), 3)
	UI.New("UISizeConstraint", { MaxSize = Vector2.new(560, 120), Parent = frame })
	local icon = UI.Label(frame, { Text = "⚠️", TextSize = 56, Size = UDim2.new(0, 90, 1, 0), Position = UDim2.new(0, 6, 0, 0) })
	local title = UI.Label(frame, { Font = UI.Theme.Black, TextSize = 32, Size = UDim2.new(1, -110, 0, 40), Position = UDim2.new(0, 96, 0, 8), TextXAlignment = Enum.TextXAlignment.Left })
	UI.TextStroke(title, 2)
	local desc = UI.Label(frame, { Font = UI.Theme.Body, TextSize = 16, TextWrapped = true, Size = UDim2.new(1, -110, 0, 44), Position = UDim2.new(0, 96, 0, 46), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	local count = UI.Label(frame, { Font = UI.Theme.Black, TextSize = 16, TextColor3 = C(255, 220, 120), Size = UDim2.new(1, -110, 0, 20), Position = UDim2.new(0, 96, 1, -26), TextXAlignment = Enum.TextXAlignment.Left })
	banner = { Frame = frame, Icon = icon, Title = title, Desc = desc, Count = count }

	Net.Event("DisasterFX").OnClientEvent:Connect(function(kind, id, ...)
		local h = handlers[kind]
		if h then
			local ok, err = pcall(h, id, ...)
			if not ok then
				warn("DisasterFX " .. tostring(kind) .. ": " .. tostring(err))
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		local t = now()
		for id, b in pairs(buckets) do
			local list = b.update
			for i = #list, 1, -1 do
				local ok, keep = pcall(list[i], t)
				if not ok or keep == false then
					table.remove(list, i)
				end
			end
		end
		-- temblor de camara
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			if shakeIntensity > 0 and os.clock() < shakeEnd then
				hum.CameraOffset = V((math.random() - 0.5) * shakeIntensity, (math.random() - 0.5) * shakeIntensity, 0)
			elseif hum.CameraOffset ~= Vector3.zero then
				hum.CameraOffset = Vector3.zero
				shakeIntensity = 0
			end
		end
	end)
end

return DisasterFX
