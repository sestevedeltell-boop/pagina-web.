-- INSTALADOR de Islas de Desastres.
-- Crea (o reemplaza) estas carpetas: ReplicatedStorage.IslasShared, ServerStorage.IslasMapas,
-- ServerScriptService.IslasServer y StarterPlayer.StarterPlayerScripts.IslasClient.
-- No toca nada mas de tu juego.
-- PARTE 5 DE 5. Pega las partes en la Barra de comandos EN ORDEN (1, 2, 3...).

local services = {
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerStorage = game:GetService("ServerStorage"),
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"),
}

local function folderAt(service, path)
	local parent = services[service]
	for _, name in ipairs(path) do
		local f = parent:FindFirstChild(name)
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = parent
		end
		parent = f
	end
	return parent
end

local function add(service, path, name, className, source)
	local parent = folderAt(service, path)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Source = source
	inst.Parent = parent
end

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "DisasterFX", "ModuleScript", [[
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
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "ElevatorUI", "ModuleScript", [[
-- ElevatorUI: menu de plantas al pulsar el boton dentro de un ascensor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local ElevatorUI = {}
local C = Color3.fromRGB

function ElevatorUI.Init(modules)
	local UI = modules.UI
	local T = UI.Theme
	local gui = UI.Gui("AscensorGui", 9)
	local panel = UI.Panel(gui, {
		Size = UDim2.new(0, 260, 0, 100),
		Position = UDim2.new(1, -280, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = C(30, 32, 40),
		Visible = false,
	})
	UI.Stroke(panel, C(120, 255, 140), 2)
	UI.Label(panel, { Text = "▲▼ ELIGE PLANTA", Font = T.Black, TextSize = 16, TextColor3 = C(120, 255, 140), Size = UDim2.new(1, 0, 0, 30) })
	local grid = UI.New("Frame", { Size = UDim2.new(1, -16, 1, -70), Position = UDim2.new(0, 8, 0, 32), BackgroundTransparency = 1, Parent = panel })
	UI.New("UIGridLayout", { CellSize = UDim2.new(0, 54, 0, 44), CellPadding = UDim2.new(0, 6, 0, 6), Parent = grid })
	UI.Button(panel, "CERRAR", { Size = UDim2.new(1, -16, 0, 28), Position = UDim2.new(0, 8, 1, -34), BackgroundColor3 = T.Panel3, TextColor3 = T.Text, TextSize = 13 }, function()
		panel.Visible = false
	end)

	Net.Event("ElevatorMenu").OnClientEvent:Connect(function(id, labels, current)
		for _, c in ipairs(grid:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, label in ipairs(labels) do
			UI.Button(grid, tostring(label), {
				BackgroundColor3 = i == current and C(120, 255, 140) or C(60, 64, 80),
				TextColor3 = i == current and C(20, 40, 20) or C(255, 255, 255),
				TextSize = 18,
			}, function()
				Net.Event("ElevatorRequest"):FireServer(id, i)
				panel.Visible = false
			end)
		end
		local rows = math.ceil(#labels / 4)
		panel.Size = UDim2.new(0, 260, 0, 70 + rows * 50)
		panel.Visible = true
		UI.Pop(panel, 0.1)
	end)
end

return ElevatorUI
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "GearClient", "ModuleScript", [[
-- GearClient: entrada del jugador para los gears que necesitan saber a donde apuntas (garfio)
-- y aviso visual de recarga.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local GearClient = {}

function GearClient.Init(modules)
	local player = Players.LocalPlayer
	local mouse = player:GetMouse()
	local Popups = modules.Popups

	local function hook(tool)
		if not tool:IsA("Tool") or not tool:GetAttribute("IslasGear") or tool:GetAttribute("HookCliente") then
			return
		end
		tool:SetAttribute("HookCliente", true)
		tool.Activated:Connect(function()
			if tool.Name == "Garfio" then
				local hit = mouse.Hit
				if hit then
					Net.Event("GearAction"):FireServer("Garfio", hit.Position)
				end
			end
			local untilT = tool:GetAttribute("RecargaHasta")
			if untilT and untilT > workspace:GetServerTimeNow() and Popups then
				Popups.Toast("Recargando: " .. math.ceil(untilT - workspace:GetServerTimeNow()) .. " s")
			end
		end)
	end

	local function watch(container)
		for _, c in ipairs(container:GetChildren()) do
			hook(c)
		end
		container.ChildAdded:Connect(hook)
	end

	local backpack = player:WaitForChild("Backpack")
	watch(backpack)
	player.CharacterAdded:Connect(function(char)
		watch(char)
		local bp = player:WaitForChild("Backpack")
		if bp ~= backpack then
			backpack = bp
			watch(bp)
		end
	end)
	if player.Character then
		watch(player.Character)
	end
end

return GearClient
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "Hud", "ModuleScript", [[
-- Hud: barra superior (fase, tiempo, vivos, desastres, modificador), monedas, nivel con barra de XP
-- y botones del menu.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Format"))

local Hud = {}
local C = Color3.fromRGB

local PHASE_TEXT = {
	Waiting = "ESPERANDO JUGADORES",
	Intermission = "DESCANSO",
	Vote = "VOTACION",
	Loading = "CARGANDO MAPA",
	Round = "¡SOBREVIVE!",
	Results = "RESULTADOS",
}

function Hud.Init(modules)
	local UI, State, SoundFX = modules.UI, modules.State, modules.SoundFX
	local T = UI.Theme
	local gui = UI.Gui("HudGui", 2)

	-- ===== Barra superior =====
	local top = UI.Panel(gui, {
		Size = UDim2.new(0, 420, 0, 62),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.15,
	})
	UI.Stroke(top, T.Accent, 2, 0.3)
	local phase = UI.Label(top, { Font = T.Black, TextSize = 20, Size = UDim2.new(1, -110, 0, 26), Position = UDim2.new(0, 14, 0, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Accent })
	local status = UI.Label(top, { Font = T.Body, TextSize = 14, Size = UDim2.new(1, -110, 0, 22), Position = UDim2.new(0, 14, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Muted, TextTruncate = Enum.TextTruncate.AtEnd })
	local timer = UI.Label(top, { Font = T.Black, TextSize = 32, Size = UDim2.new(0, 100, 1, 0), Position = UDim2.new(1, -108, 0, 0), TextXAlignment = Enum.TextXAlignment.Right })
	UI.TextStroke(timer, 2)

	local chips = UI.New("Frame", {
		Size = UDim2.new(0, 600, 0, 30),
		Position = UDim2.new(0.5, 0, 0, 76),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), Parent = chips })

	local function chip(text, color)
		local f = UI.Panel(chips, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = color or T.Panel2, BackgroundTransparency = 0.1 })
		UI.Padding(f, 4)
		UI.Label(f, { Text = "  " .. text .. "  ", Font = T.Black, TextSize = 14, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = C(255, 255, 255) })
		return f
	end

	-- ===== Monedas y nivel (izquierda arriba) =====
	local left = UI.New("Frame", { Size = UDim2.new(0, 200, 0, 110), Position = UDim2.new(0, 10, 0, 8), BackgroundTransparency = 1, Parent = gui })
	local coinBox = UI.Panel(left, { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.15 })
	UI.Stroke(coinBox, T.Accent, 2, 0.3)
	UI.Label(coinBox, { Text = "🪙", TextSize = 26, Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(0, 4, 0, 0) })
	local coins = UI.Label(coinBox, { Text = "0", Font = T.Black, TextSize = 26, TextColor3 = T.Accent, Size = UDim2.new(1, -52, 1, 0), Position = UDim2.new(0, 44, 0, 0), TextXAlignment = Enum.TextXAlignment.Left })
	local streak = UI.Label(coinBox, { Text = "", Font = T.Black, TextSize = 18, TextColor3 = C(255, 140, 60), Size = UDim2.new(0, 70, 1, 0), Position = UDim2.new(1, 6, 0, 0), TextXAlignment = Enum.TextXAlignment.Left })
	UI.TextStroke(streak, 2)
	local levelBox = UI.Panel(left, { Size = UDim2.new(1, 0, 0, 56), Position = UDim2.new(0, 0, 0, 50), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.15 })
	local levelBadge = UI.Panel(levelBox, { Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0, 6, 0, 6), BackgroundColor3 = T.Info })
	local levelText = UI.Label(levelBadge, { Text = "1", Font = T.Black, TextSize = 22, Size = UDim2.fromScale(1, 1) })
	local titleText = UI.Label(levelBox, { Text = "Novato", Font = T.Font, TextSize = 15, Size = UDim2.new(1, -60, 0, 20), Position = UDim2.new(0, 56, 0, 6), TextXAlignment = Enum.TextXAlignment.Left })
	local barBg = UI.Panel(levelBox, { Size = UDim2.new(1, -62, 0, 12), Position = UDim2.new(0, 56, 0, 30), BackgroundColor3 = T.Panel3 })
	local bar = UI.Panel(barBg, { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.Info })
	local xpText = UI.Label(levelBox, { Text = "", Font = T.Body, TextSize = 11, TextColor3 = T.Muted, Size = UDim2.new(1, -62, 0, 12), Position = UDim2.new(0, 56, 0, 42), TextXAlignment = Enum.TextXAlignment.Left })

	-- contador de monedas que sube poco a poco (mas satisfactorio)
	local shownCoins, targetCoins = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		if shownCoins ~= targetCoins then
			local diff = targetCoins - shownCoins
			local step = math.max(1, math.abs(diff) * math.min(1, dt * 6))
			if math.abs(diff) <= step then
				shownCoins = targetCoins
			else
				shownCoins = shownCoins + (diff > 0 and step or -step)
			end
			coins.Text = Format.Number(shownCoins)
		end
	end)

	State.OnData(function(data, old)
		targetCoins = data.Coins or 0
		if old and data.Coins > old.Coins then
			UI.Pop(coinBox, 0.12)
		end
		local st = data.Stats and data.Stats.Streak or 0
		streak.Text = st >= 2 and ("🔥x" .. st) or ""
		if old and old.Stats and st > (old.Stats.Streak or 0) and st >= 2 then
			UI.Pop(streak, 0.4)
		end
		levelText.Text = tostring(data.Level)
		titleText.Text = data.Title or ""
		titleText.TextColor3 = data.TitleColor or T.Text
		levelBadge.BackgroundColor3 = data.TitleColor or T.Info
		bar.BackgroundColor3 = data.TitleColor or T.Info
		local k = data.LevelNeed and data.LevelNeed > 0 and (data.LevelXP / data.LevelNeed) or 0
		UI.Tween(bar, 0.4, { Size = UDim2.new(math.clamp(k, 0, 1), 0, 1, 0) })
		xpText.Text = (data.LevelXP or 0) .. " / " .. (data.LevelNeed or 0) .. " XP"
	end)

	-- ===== Menu (izquierda, centro) =====
	local menu = UI.New("Frame", { Size = UDim2.new(0, 64, 0, 330), Position = UDim2.new(0, 10, 0.5, -150), BackgroundTransparency = 1, Parent = gui })
	UI.New("UIListLayout", { Padding = UDim.new(0, 8), Parent = menu })
	local function menuButton(icon, label, color, onClick)
		local b = UI.Button(menu, icon, { Size = UDim2.new(0, 60, 0, 60), BackgroundColor3 = color, TextSize = 28, TextColor3 = C(255, 255, 255) }, onClick)
		UI.Stroke(b, C(0, 0, 0), 2, 0.4)
		local l = UI.Label(b, { Text = label, Font = T.Black, TextSize = 11, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -16) })
		UI.TextStroke(l, 1.5)
		return b
	end
	menuButton("🛒", "TIENDA", C(255, 160, 40), function()
		if modules.ShopUI then
			modules.ShopUI.Toggle()
		end
	end)
	local dailyBtn = menuButton("🎁", "DIARIO", C(80, 200, 120), function()
		if modules.DailyUI then
			modules.DailyUI.Toggle()
		end
	end)
	local dailyDot = UI.Panel(dailyBtn, { Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(1, -12, 0, -4), BackgroundColor3 = T.Bad, Visible = false })
	UI.Corner(dailyDot, 8)
	menuButton("🏆", "LOGROS", C(200, 150, 40), function()
		if modules.AchievementsUI then
			modules.AchievementsUI.Toggle()
		end
	end)
	menuButton("⚙️", "AJUSTES", C(110, 120, 150), function()
		if modules.SettingsUI then
			modules.SettingsUI.Toggle()
		end
	end)
	State.OnData(function(data)
		dailyDot.Visible = data.DailyAvailable == true
	end)

	-- ===== Estado de ronda =====
	local lastPhase = nil
	local function refreshRound(st)
		-- fundido al ir a la isla y al volver al lobby
		if lastPhase and st.Phase ~= lastPhase and modules.Popups and (st.Phase == "Round" or (lastPhase == "Results" and st.Phase ~= "Results")) then
			modules.Popups.Fade()
		end
		lastPhase = st.Phase
		phase.Text = PHASE_TEXT[st.Phase] or st.Phase or ""
		status.Text = st.Status or ""
		for _, c in ipairs(chips:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		if st.Phase == "Round" or st.Phase == "Results" then
			if st.Total and st.Total > 0 then
				chip("👥 " .. (st.Alive or 0) .. "/" .. st.Total, T.Panel2)
			end
			for _, d in ipairs(st.Disasters or {}) do
				chip((d.Icon or "⚠️") .. " " .. (d.Title or ""), C(150, 40, 40))
			end
		end
		if st.Modifier then
			chip("✨ " .. st.Modifier.Title, st.Modifier.Color)
		end
	end
	State.OnRound(refreshRound)

	local lastSecond = -1
	RunService.Heartbeat:Connect(function()
		local st = State.Round
		if st and st.EndsAt and st.EndsAt > 0 then
			local left = st.EndsAt - workspace:GetServerTimeNow()
			timer.Text = Format.Time(left)
			local s = math.ceil(left)
			if st.Phase == "Round" and s <= 10 and s > 0 and s ~= lastSecond then
				lastSecond = s
				timer.TextColor3 = C(255, 90, 90)
				UI.Pop(timer, 0.25)
				SoundFX.Play("Click", 0.4, 1.4)
			elseif s > 10 then
				timer.TextColor3 = T.Text
			end
		else
			timer.Text = ""
		end
	end)

	Hud.Gui = gui
end

return Hud
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "MapAnimator", "ModuleScript", [[
-- MapAnimator: hace girar en el cliente lo que el servidor marca con la etiqueta "IslasGira"
-- (norias, molinos, carruseles, monedas...). Coste cero para el servidor y movimiento suave.
-- Atributos: GiroRPM (vueltas por minuto) y GiroEje ("X", "Y" o "Z").
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local MapAnimator = {}

local spinning = {} -- [inst] = { pivot, rpm, axis }

local function add(inst)
	if spinning[inst] then
		return
	end
	local pivot = inst:GetPivot()
	spinning[inst] = { pivot = pivot, rpm = inst:GetAttribute("GiroRPM") or 10, axis = inst:GetAttribute("GiroEje") or "Y", angle = 0 }
end

local function remove(inst)
	spinning[inst] = nil
end

function MapAnimator.Init(modules)
	local Quality = modules.Quality
	for _, inst in ipairs(CollectionService:GetTagged("IslasGira")) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal("IslasGira"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("IslasGira"):Connect(remove)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		-- en calidad baja se actualiza a 20 fps para ahorrar
		acc = acc + dt
		if Quality.Level == 1 and acc < 0.05 then
			return
		end
		local step = acc
		acc = 0
		for inst, s in pairs(spinning) do
			if not inst.Parent then
				spinning[inst] = nil
			else
				s.angle = s.angle + step * s.rpm / 60 * math.pi * 2
				local rot
				if s.axis == "X" then
					rot = CFrame.Angles(s.angle, 0, 0)
				elseif s.axis == "Z" then
					rot = CFrame.Angles(0, 0, s.angle)
				else
					rot = CFrame.Angles(0, s.angle, 0)
				end
				inst:PivotTo(s.pivot * rot)
			end
		end
	end)
end

return MapAnimator
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "Music", "ModuleScript", [[
-- Music: musica de fondo del lobby y de las rondas (ids en Sounds.LobbyMusic / Sounds.RoundMusic).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Sounds"))

local Music = {}
local enabled = true
local sound

function Music.SetEnabled(on)
	enabled = on
	if sound then
		sound.Volume = on and 0.3 or 0
	end
end

function Music.Init(modules)
	if (Sounds.LobbyMusic or "") == "" and (Sounds.RoundMusic or "") == "" then
		return
	end
	sound = Instance.new("Sound")
	sound.Name = "MusicaIslas"
	sound.Looped = true
	sound.Volume = 0.3
	sound.Parent = SoundService
	local current
	modules.State.OnRound(function(st)
		local id = (st.Phase == "Round") and Sounds.RoundMusic or Sounds.LobbyMusic
		if id ~= "" and id ~= current then
			current = id
			sound.SoundId = id
			sound.Volume = enabled and 0.3 or 0
			sound:Play()
		end
	end)
end

return Music
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "Popups", "ModuleScript", [[
-- Popups: numeros de monedas/XP que saltan, avisos (logros, subida de nivel) y lista de muertes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local Popups = {}
local UI, SoundFX
local gui, toastList, feed, bigText
local C = Color3.fromRGB

-- "+5" flotando en el mundo donde se recogio la moneda
local function worldPopup(amount, position)
	local att = Instance.new("Attachment")
	att.WorldPosition = position
	att.Parent = workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 120, 0, 40)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Adornee = att
	bb.Parent = att
	local label = UI.Label(bb, {
		Text = "+" .. amount,
		Font = UI.Theme.Black,
		TextSize = 30,
		TextColor3 = amount >= 25 and C(255, 120, 220) or UI.Theme.Accent,
		Size = UDim2.fromScale(1, 1),
	})
	UI.TextStroke(label, 2)
	UI.Tween(bb, 1, { StudsOffset = Vector3.new(0, 5, 0) })
	UI.Tween(label, 1, { TextTransparency = 1 })
	task.delay(1.1, function()
		att:Destroy()
	end)
end

-- Fundido a blanco (al teletransportar)
local fadeFrame
function Popups.Fade()
	if not fadeFrame then
		return
	end
	fadeFrame.BackgroundTransparency = 0
	UI.Tween(fadeFrame, 0.7, { BackgroundTransparency = 1 })
end

-- "+5 🪙" que sale cerca del contador de monedas y sube
function Popups.Coin(amount, xp, text, position)
	if typeof(position) == "Vector3" and amount > 0 then
		worldPopup(amount, position)
	end
	local T = UI.Theme
	local label = UI.Label(gui, {
		Text = (amount > 0 and ("+" .. amount .. " 🪙") or "") .. (xp and xp > 0 and ("  +" .. xp .. " XP") or ""),
		Font = T.Black,
		TextSize = amount >= 25 and 34 or 26,
		TextColor3 = amount >= 25 and C(255, 120, 220) or T.Accent,
		Size = UDim2.new(0, 320, 0, 40),
		Position = UDim2.new(0, 210 + math.random(-20, 20), 0, 70),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	UI.TextStroke(label, 2.5)
	if text then
		local sub = UI.Label(label, {
			Text = text,
			Font = T.Font,
			TextSize = 16,
			TextColor3 = T.Text,
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.new(0, 0, 1, -4),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		UI.TextStroke(sub, 1.5)
	end
	UI.Pop(label, 0.4)
	UI.Tween(label, 1.6, { Position = label.Position - UDim2.new(0, 0, 0, 50), TextTransparency = 1 })
	task.delay(1.7, function()
		label:Destroy()
	end)
end

-- Aviso en el lateral (logros, compras, informacion)
function Popups.Toast(text, color, title)
	local T = UI.Theme
	local frame = UI.Panel(toastList, {
		Size = UDim2.new(1, 0, 0, title and 64 or 44),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.05,
	})
	UI.Stroke(frame, color or T.Accent, 2)
	if title then
		UI.Label(frame, { Text = title, Font = T.Black, TextSize = 18, TextColor3 = color or T.Accent, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0, 8, 0, 4), TextXAlignment = Enum.TextXAlignment.Left })
	end
	UI.Label(frame, {
		Text = text,
		Font = T.Body,
		TextSize = 15,
		TextWrapped = true,
		Size = UDim2.new(1, -16, 0, title and 30 or 40),
		Position = UDim2.new(0, 8, 0, title and 30 or 2),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	UI.Pop(frame, 0.1)
	task.delay(5, function()
		UI.Tween(frame, 0.4, { BackgroundTransparency = 1 })
		task.wait(0.4)
		frame:Destroy()
	end)
end

-- Texto enorme en el centro (subida de nivel, sobreviviste...)
function Popups.Big(text, color, seconds)
	bigText.Text = text
	bigText.TextColor3 = color or UI.Theme.Accent
	bigText.Visible = true
	bigText.TextTransparency = 0
	UI.Pop(bigText, 0.5)
	task.delay(seconds or 2, function()
		if bigText.Text == text then
			UI.Tween(bigText, 0.5, { TextTransparency = 1 })
		end
	end)
end

function Popups.Kill(name, cause)
	local T = UI.Theme
	local row = UI.Panel(feed, { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C(40, 10, 10), BackgroundTransparency = 0.3 })
	UI.Label(row, {
		Text = "💀 " .. name .. "  ·  " .. cause,
		Font = T.Font,
		TextSize = 15,
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	task.delay(7, function()
		row:Destroy()
	end)
end

function Popups.Init(modules)
	UI, SoundFX = modules.UI, modules.SoundFX
	gui = UI.Gui("AvisosGui", 8)
	toastList = UI.New("Frame", {
		Size = UDim2.new(0, 300, 0.6, 0),
		Position = UDim2.new(1, -310, 0.25, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.New("UIListLayout", { Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = toastList })
	feed = UI.New("Frame", {
		Size = UDim2.new(0, 280, 0, 200),
		Position = UDim2.new(1, -290, 0, 60),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.New("UIListLayout", { Padding = UDim.new(0, 4), Parent = feed })
	bigText = UI.Label(gui, {
		Font = UI.Theme.Black,
		TextSize = 64,
		Size = UDim2.new(1, 0, 0, 90),
		Position = UDim2.new(0, 0, 0.32, 0),
		Visible = false,
	})
	UI.TextStroke(bigText, 4)
	local fadeGui = UI.Gui("FundidoGui", 20, true)
	fadeFrame = UI.New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, Parent = fadeGui })

	Net.Event("Popup").OnClientEvent:Connect(function(p)
		if typeof(p) == "table" then
			Popups.Coin(p.Coins or 0, p.XP, p.Text, p.Position)
		end
	end)
	Net.Event("Toast").OnClientEvent:Connect(function(t)
		if typeof(t) ~= "table" then
			return
		end
		if t.Kind == "LevelUp" then
			Popups.Big(t.Title, C(120, 220, 255), 2.5)
			Popups.Toast(t.Text, C(120, 220, 255), t.Title)
		elseif t.Kind == "Achievement" then
			Popups.Toast(t.Text, C(255, 196, 50), t.Title)
		else
			Popups.Toast(t.Text or "", t.Color, t.Title)
		end
	end)
	Net.Event("KillFeed").OnClientEvent:Connect(function(k)
		if typeof(k) == "table" then
			Popups.Kill(k.Name or "?", k.Cause or "?")
			if k.UserId == Players.LocalPlayer.UserId then
				Popups.Big("HAS MUERTO", C(255, 80, 80), 2)
			end
		end
	end)
end

return Popups
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "Quality", "ModuleScript", [[
-- Quality: calidad de efectos automatica segun los FPS del jugador (1 = baja, 2 = media, 3 = alta).
-- Si el juego va lento se reducen fragmentos, particulas y efectos; si va sobrado se suben.
-- El jugador puede fijarla a mano desde Ajustes.
local RunService = game:GetService("RunService")

local Quality = {}

Quality.Level = 3
Quality.Auto = true
Quality.FPS = 60

local listeners = {}
function Quality.OnChanged(fn)
	listeners[#listeners + 1] = fn
end

local function set(level)
	level = math.clamp(level, 1, 3)
	if level ~= Quality.Level then
		Quality.Level = level
		for _, fn in ipairs(listeners) do
			task.spawn(fn, level)
		end
	end
end

function Quality.Set(level, auto)
	Quality.Auto = auto
	if level then
		set(level)
	end
end

local PRESETS = {
	{ MaxFragments = 70, PerBreak = 2, Life = 2.2, Particles = false, Distance = 220 },
	{ MaxFragments = 200, PerBreak = 4, Life = 3.2, Particles = true, Distance = 320 },
	{ MaxFragments = 420, PerBreak = 7, Life = 4.5, Particles = true, Distance = 450 },
}
function Quality.Settings()
	return PRESETS[Quality.Level]
end

function Quality.Init()
	local frames, acc, lowFor, highFor = 0, 0, 0, 0
	RunService.RenderStepped:Connect(function(dt)
		frames = frames + 1
		acc = acc + dt
		if acc >= 2 then
			local fps = frames / acc
			Quality.FPS = fps
			frames, acc = 0, 0
			if not Quality.Auto then
				return
			end
			if fps < 38 then
				lowFor = lowFor + 2
				highFor = 0
				if lowFor >= 4 then
					set(Quality.Level - 1)
					lowFor = 0
				end
			elseif fps > 56 then
				highFor = highFor + 2
				lowFor = 0
				if highFor >= 20 then
					set(Quality.Level + 1)
					highFor = 0
				end
			else
				lowFor, highFor = 0, 0
			end
		end
	end)
end

return Quality
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "ResultsUI", "ModuleScript", [[
-- ResultsUI: pantalla de final de ronda (sobreviviste o no, monedas que cuentan hacia arriba, racha)
-- con confeti cuando sobrevives.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local ResultsUI = {}
local C = Color3.fromRGB

function ResultsUI.Init(modules)
	local UI, SoundFX, Quality = modules.UI, modules.SoundFX, modules.Quality
	local T = UI.Theme
	local gui = UI.Gui("ResultadosGui", 7, true)

	local panel = UI.Panel(gui, {
		Size = UDim2.new(0, 460, 0, 300),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.05,
		Visible = false,
	})
	local stroke = UI.Stroke(panel, T.Good, 4)
	local headline = UI.Label(panel, { Font = T.Black, TextSize = 40, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0, 10) })
	UI.TextStroke(headline, 3)
	local sub = UI.Label(panel, { Font = T.Body, TextSize = 16, TextColor3 = T.Muted, TextWrapped = true, Size = UDim2.new(1, -30, 0, 40), Position = UDim2.new(0, 15, 0, 68) })
	local coinsLabel = UI.Label(panel, { Font = T.Black, TextSize = 46, TextColor3 = T.Accent, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0, 112) })
	UI.TextStroke(coinsLabel, 3)
	local xpLabel = UI.Label(panel, { Font = T.Black, TextSize = 22, TextColor3 = T.Info, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 172) })
	local streakLabel = UI.Label(panel, { Font = T.Black, TextSize = 22, TextColor3 = C(255, 140, 60), Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 204) })
	local survivorsLabel = UI.Label(panel, { Font = T.Body, TextSize = 14, TextColor3 = T.Muted, TextWrapped = true, Size = UDim2.new(1, -30, 0, 50), Position = UDim2.new(0, 15, 0, 238) })

	local confettiLayer = UI.New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local confetti = {}
	local function burstConfetti()
		local n = ({ 30, 70, 120 })[Quality.Level]
		for _ = 1, n do
			local f = UI.New("Frame", {
				Size = UDim2.new(0, math.random(6, 12), 0, math.random(10, 18)),
				Position = UDim2.new(math.random(), 0, -0.05 - math.random() * 0.3, 0),
				BackgroundColor3 = Color3.fromHSV(math.random(), 0.8, 1),
				BorderSizePixel = 0,
				Rotation = math.random(0, 360),
				Parent = confettiLayer,
			})
			confetti[#confetti + 1] = { f = f, vy = 0.25 + math.random() * 0.35, vx = (math.random() - 0.5) * 0.1, spin = math.random(-300, 300), born = os.clock() }
		end
	end
	RunService.RenderStepped:Connect(function(dt)
		for i = #confetti, 1, -1 do
			local c = confetti[i]
			local p = c.f.Position
			c.f.Position = UDim2.new(p.X.Scale + c.vx * dt, 0, p.Y.Scale + c.vy * dt, 0)
			c.f.Rotation = c.f.Rotation + c.spin * dt
			if p.Y.Scale > 1.1 or os.clock() - c.born > 6 then
				c.f:Destroy()
				table.remove(confetti, i)
			end
		end
	end)

	Net.Event("RoundResults").OnClientEvent:Connect(function(r)
		if typeof(r) ~= "table" then
			return
		end
		if r.Survived then
			headline.Text = "¡SOBREVIVISTE!"
			headline.TextColor3 = T.Good
			stroke.Color = T.Good
			burstConfetti()
			SoundFX.Play("Win", 0.9)
		else
			headline.Text = "NO SOBREVIVISTE"
			headline.TextColor3 = T.Bad
			stroke.Color = T.Bad
		end
		sub.Text = (r.Map or "") .. "  ·  " .. table.concat(r.Disasters or {}, " + ") .. (r.Modifier and ("  ·  " .. r.Modifier) or "")
		xpLabel.Text = "+" .. (r.XP or 0) .. " XP"
		streakLabel.Text = (r.Streak and r.Streak > 1) and ("🔥 RACHA x" .. r.Streak) or ""
		local names = r.Survivors or {}
		survivorsLabel.Text = #names > 0 and ("Supervivientes: " .. table.concat(names, ", ")) or "Nadie sobrevivio"
		panel.Visible = true
		UI.Pop(panel, 0.15)
		-- las monedas cuentan hacia arriba
		local target = r.Coins or 0
		task.spawn(function()
			local steps = 20
			for i = 1, steps do
				coinsLabel.Text = "+" .. math.floor(target * i / steps) .. " 🪙"
				if i % 4 == 0 then
					SoundFX.Play("Coin", 0.25, 1 + i / steps)
				end
				task.wait(0.04)
			end
			UI.Pop(coinsLabel, 0.3)
		end)
		task.delay(6, function()
			panel.Visible = false
		end)
	end)
end

return ResultsUI
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "SettingsUI", "ModuleScript", [[
-- SettingsUI: calidad de efectos (auto/baja/media/alta), temblor de camara, musica y sonidos.
-- Se guarda en tus datos (SettingsChanged).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local SettingsUI = {}
local C = Color3.fromRGB

function SettingsUI.Init(modules)
	local UI, State, Quality, SoundFX, DisasterFX = modules.UI, modules.State, modules.Quality, modules.SoundFX, modules.DisasterFX
	local T = UI.Theme
	local gui = UI.Gui("AjustesGui", 10)
	local win = UI.Window(gui, "⚙️ AJUSTES", UDim2.new(0, 480, 0, 360), C(110, 120, 150))
	local layout = UI.New("UIListLayout", { Padding = UDim.new(0, 10), Parent = win.Content })

	local settings = { Quality = 0, Shake = 1, Music = true, Sounds = true }

	local function apply()
		if settings.Quality == 0 then
			Quality.Set(nil, true)
		else
			Quality.Set(settings.Quality, false)
		end
		if DisasterFX then
			DisasterFX.ShakeScale = settings.Shake
		end
		SoundFX.Muted = not settings.Sounds
		if modules.Music then
			modules.Music.SetEnabled(settings.Music)
		end
	end

	local function save()
		apply()
		Net.Event("SettingsChanged"):FireServer(settings)
	end

	local function row(title)
		local r = UI.New("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, Parent = win.Content })
		UI.Label(r, { Text = title, Font = T.Black, TextSize = 17, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left })
		local buttons = UI.New("Frame", { Size = UDim2.new(1, 0, 0, 32), Position = UDim2.new(0, 0, 0, 24), BackgroundTransparency = 1, Parent = r })
		UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = buttons })
		return buttons
	end

	local groups = {}
	local function choice(title, key, options)
		local holder = row(title)
		local btns = {}
		for _, opt in ipairs(options) do
			btns[#btns + 1] = { value = opt[2], button = UI.Button(holder, opt[1], { Size = UDim2.new(0, 100, 1, 0), TextSize = 14 }, function()
				settings[key] = opt[2]
				save()
				for _, g in ipairs(groups) do
					g()
				end
			end) }
		end
		groups[#groups + 1] = function()
			for _, b in ipairs(btns) do
				local on = settings[key] == b.value
				b.button.BackgroundColor3 = on and T.Accent or T.Panel2
				b.button.TextColor3 = on and C(30, 25, 10) or T.Text
			end
		end
	end

	choice("Calidad de efectos", "Quality", { { "AUTO", 0 }, { "BAJA", 1 }, { "MEDIA", 2 }, { "ALTA", 3 } })
	choice("Temblor de camara", "Shake", { { "NO", 0 }, { "SUAVE", 0.5 }, { "NORMAL", 1 } })
	choice("Musica", "Music", { { "SI", true }, { "NO", false } })
	choice("Sonidos", "Sounds", { { "SI", true }, { "NO", false } })
	local fps = UI.Label(win.Content, { Font = T.Body, TextSize = 13, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left })

	win.OnOpen = function()
		for _, g in ipairs(groups) do
			g()
		end
		fps.Text = string.format("FPS: %d  ·  calidad actual: %d", math.floor(Quality.FPS), Quality.Level)
	end

	local loaded = false
	State.OnData(function(data)
		if loaded or not data.Settings then
			return
		end
		loaded = true
		for k, v in pairs(data.Settings) do
			settings[k] = v
		end
		apply()
	end)
	SettingsUI.Toggle = win.Toggle
	local _ = layout
end

return SettingsUI
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "ShopUI", "ModuleScript", [[
-- ShopUI: tienda con pestanas (Gears, Estelas, Mejoras). Comprar y equipar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))

local ShopUI = {}
local C = Color3.fromRGB

local TABS = {
	{ Kind = "Gear", Title = "GEARS" },
	{ Kind = "Trail", Title = "ESTELAS" },
	{ Kind = "Upgrade", Title = "MEJORAS" },
}

function ShopUI.Init(modules)
	local UI, State, Popups, SoundFX = modules.UI, modules.State, modules.Popups, modules.SoundFX
	local T = UI.Theme
	local gui = UI.Gui("TiendaGui", 10)
	local win = UI.Window(gui, "🛒 TIENDA", UDim2.new(0.7, 0, 0.75, 0), C(255, 160, 40))
	local content = win.Content

	local header = UI.New("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = content })
	UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = header })
	local coinsLabel = UI.Label(content, { Text = "", Font = T.Black, TextSize = 22, TextColor3 = T.Accent, Size = UDim2.new(0, 200, 0, 40), Position = UDim2.new(1, -200, 0, 0), TextXAlignment = Enum.TextXAlignment.Right })
	local slotsLabel = UI.Label(content, { Text = "", Font = T.Body, TextSize = 14, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 42), TextXAlignment = Enum.TextXAlignment.Left })

	local list = UI.New("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -70),
		Position = UDim2.new(0, 0, 0, 66),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = content,
	})
	UI.New("UIGridLayout", { CellSize = UDim2.new(0, 190, 0, 210), CellPadding = UDim2.new(0, 10, 0, 10), Parent = list })

	local currentKind = "Gear"
	local tabButtons = {}

	local function request(action, id)
		local ok, a, b = pcall(function()
			return Net.Function("ShopRequest"):InvokeServer(action, id)
		end)
		local success, msg = ok and a, ok and b or "Error de conexion"
		Popups.Toast(msg or "", success and T.Good or T.Bad)
		if not success then
			SoundFX.Play("Hit", 0.5)
		end
	end

	local function render()
		local data = State.Data
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if not data then
			return
		end
		coinsLabel.Text = "🪙 " .. Format.Number(data.Coins)
		slotsLabel.Text = currentKind == "Gear" and ("Puedes llevar " .. (data.GearSlots or 1) .. " gear(s) a la vez en las rondas. Pulsa EQUIPAR para elegir.") or ""
		for k, b in pairs(tabButtons) do
			b.BackgroundColor3 = k == currentKind and T.Accent or T.Panel2
			b.TextColor3 = k == currentKind and C(30, 25, 10) or T.Text
		end
		for _, item in ipairs(Catalog.Items) do
			if item.Kind == currentKind then
				local owned = data.Owned and data.Owned[item.Id]
				local equipped = false
				if item.Kind == "Gear" then
					equipped = table.find(data.Equipped.Gears or {}, item.Id) ~= nil
				elseif item.Kind == "Trail" then
					equipped = data.Equipped.Trail == item.Id
				end
				local card = UI.Panel(list, { BackgroundColor3 = equipped and C(40, 80, 55) or T.Panel })
				UI.Stroke(card, equipped and T.Good or (owned and T.Info or T.Panel3), 2)
				UI.Label(card, { Text = item.Icon or "?", TextSize = 46, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0, 6) })
				UI.Label(card, { Text = item.Name, Font = T.Black, TextSize = 17, TextWrapped = true, Size = UDim2.new(1, -10, 0, 22), Position = UDim2.new(0, 5, 0, 66) })
				UI.Label(card, { Text = item.Desc or "Estela cosmetica que te sigue al correr.", Font = T.Body, TextSize = 12, TextWrapped = true, TextColor3 = T.Muted, Size = UDim2.new(1, -14, 0, 64), Position = UDim2.new(0, 7, 0, 90), TextYAlignment = Enum.TextYAlignment.Top })
				local text, color, action
				if not owned then
					local affordable = data.Coins >= item.Price
					text = "🪙 " .. Format.Number(item.Price)
					color = affordable and T.Accent or C(90, 90, 100)
					action = "buy"
				elseif item.Kind == "Upgrade" then
					text, color = "✔ COMPRADO", T.Good
				else
					text = equipped and "QUITAR" or "EQUIPAR"
					color = equipped and T.Bad or T.Info
					action = "equip"
				end
				local btn = UI.Button(card, text, { Size = UDim2.new(1, -20, 0, 36), Position = UDim2.new(0, 10, 1, -44), BackgroundColor3 = color, TextSize = 16 }, function()
					if action then
						request(action, item.Id)
					end
				end)
				if not action then
					btn.Active = false
				end
			end
		end
	end

	for _, tab in ipairs(TABS) do
		tabButtons[tab.Kind] = UI.Button(header, tab.Title, { Size = UDim2.new(0, 120, 1, 0), BackgroundColor3 = T.Panel2, TextColor3 = T.Text, TextSize = 16 }, function()
			currentKind = tab.Kind
			render()
		end)
	end

	State.OnData(function()
		if win.IsOpen() then
			render()
		end
	end)
	win.OnOpen = render

	Net.Event("OpenUI").OnClientEvent:Connect(function(what)
		if what == "Shop" then
			win.Open()
		end
	end)

	ShopUI.Toggle = win.Toggle
	ShopUI.Open = win.Open
end

return ShopUI
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "SoundFX", "ModuleScript", [[
-- SoundFX: sonidos en el cliente (en la posicion del mundo o en la interfaz), con limite por segundo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Sounds = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Sounds"))
local Net = require(ReplicatedStorage.IslasShared:WaitForChild("Net"))

local SoundFX = {}
SoundFX.Volume = 1
SoundFX.Muted = false

local budget, budgetReset = 0, 0
local MAX_PER_SECOND = 10

local function allowed()
	local now = os.clock()
	if now - budgetReset > 1 then
		budget, budgetReset = 0, now
	end
	if budget >= MAX_PER_SECOND then
		return false
	end
	budget = budget + 1
	return true
end

local function idFor(name)
	return Sounds[name] or name
end

-- Sonido de interfaz (no posicional)
function SoundFX.Play(name, volume, pitch)
	if SoundFX.Muted or not allowed() then
		return
	end
	local id = idFor(name)
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = (volume or 0.5) * SoundFX.Volume
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 4)
end

-- Sonido en un punto del mundo
function SoundFX.PlayAt(name, position, volume, pitch)
	if SoundFX.Muted or not allowed() then
		return
	end
	local id = idFor(name)
	if not id or id == "" then
		return
	end
	local att = Instance.new("Attachment")
	att.WorldPosition = position
	att.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = (volume or 0.6) * SoundFX.Volume
	s.PlaybackSpeed = pitch or (0.9 + math.random() * 0.2)
	s.RollOffMaxDistance = 400
	s.Parent = att
	s:Play()
	Debris:AddItem(att, 4)
end

function SoundFX.Init()
	Net.Event("PlaySound").OnClientEvent:Connect(function(name, position, volume)
		if typeof(position) == "Vector3" then
			SoundFX.PlayAt(name, position, volume)
		else
			SoundFX.Play(name, volume)
		end
	end)
end

return SoundFX
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "SpectateUI", "ModuleScript", [[
-- SpectateUI: mirar a los supervivientes cuando estas muerto o esperando en el lobby durante una ronda.
local Players = game:GetService("Players")

local SpectateUI = {}
local C = Color3.fromRGB

function SpectateUI.Init(modules)
	local UI, State = modules.UI, modules.State
	local T = UI.Theme
	local player = Players.LocalPlayer
	local gui = UI.Gui("EspectarGui", 3)

	local openBtn = UI.Button(gui, "👁 ESPECTAR", { Size = UDim2.new(0, 150, 0, 40), Position = UDim2.new(0.5, -75, 1, -110), BackgroundColor3 = C(90, 110, 200), TextColor3 = C(255, 255, 255), Visible = false })
	local bar = UI.Panel(gui, { Size = UDim2.new(0, 420, 0, 54), Position = UDim2.new(0.5, -210, 1, -120), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.1, Visible = false })
	UI.Stroke(bar, C(90, 110, 200), 2)
	local name = UI.Label(bar, { Font = T.Black, TextSize = 18, Size = UDim2.new(1, -200, 1, 0), Position = UDim2.new(0, 100, 0, 0) })

	local targets, index, spectating = {}, 1, false

	local function camera()
		return workspace.CurrentCamera
	end

	local function stop()
		spectating = false
		bar.Visible = false
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and camera() then
			camera().CameraSubject = hum
		end
	end

	local function refreshTargets()
		targets = {}
		for _, id in ipairs(State.Round.AliveIds or {}) do
			local p = Players:GetPlayerByUserId(id)
			if p and p ~= player and p.Character then
				targets[#targets + 1] = p
			end
		end
	end

	local function show()
		refreshTargets()
		if #targets == 0 then
			stop()
			return
		end
		index = ((index - 1) % #targets) + 1
		local target = targets[index]
		local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if hum and camera() then
			camera().CameraSubject = hum
			name.Text = target.DisplayName .. "  (" .. index .. "/" .. #targets .. ")"
		end
	end

	UI.Button(bar, "◀", { Size = UDim2.new(0, 44, 0, 40), Position = UDim2.new(0, 8, 0, 7), BackgroundColor3 = T.Panel2, TextColor3 = T.Text }, function()
		index = index - 1
		show()
	end)
	UI.Button(bar, "▶", { Size = UDim2.new(0, 44, 0, 40), Position = UDim2.new(0, 54, 0, 7), BackgroundColor3 = T.Panel2, TextColor3 = T.Text }, function()
		index = index + 1
		show()
	end)
	UI.Button(bar, "SALIR", { Size = UDim2.new(0, 90, 0, 40), Position = UDim2.new(1, -98, 0, 7), BackgroundColor3 = T.Bad, TextColor3 = T.Text }, stop)

	openBtn.Activated:Connect(function()
		spectating = true
		bar.Visible = true
		openBtn.Visible = false
		show()
	end)

	State.OnRound(function(st)
		local inRound = st.Phase == "Round"
		local alive = table.find(st.AliveIds or {}, player.UserId) ~= nil
		openBtn.Visible = inRound and not alive and not spectating and #(st.AliveIds or {}) > 0
		if spectating then
			if not inRound then
				stop()
			else
				show()
			end
		end
	end)
end

return SpectateUI
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "State", "ModuleScript", [[
-- State: ultimo estado conocido del jugador (monedas, nivel, inventario...) y de la ronda.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local State = {
	Data = nil, -- snapshot de PlayerData
	Round = { Phase = "Intermission", EndsAt = 0, Disasters = {}, Alive = 0, Total = 0, AliveIds = {} },
}

local dataListeners, roundListeners = {}, {}

function State.OnData(fn)
	dataListeners[#dataListeners + 1] = fn
	if State.Data then
		task.spawn(fn, State.Data, nil)
	end
end

function State.OnRound(fn)
	roundListeners[#roundListeners + 1] = fn
	task.spawn(fn, State.Round)
end

local function setData(data)
	if typeof(data) ~= "table" then
		return
	end
	local old = State.Data
	State.Data = data
	for _, fn in ipairs(dataListeners) do
		task.spawn(fn, data, old)
	end
end

function State.Init()
	Net.Event("DataUpdate").OnClientEvent:Connect(setData)
	Net.Event("RoundState").OnClientEvent:Connect(function(st)
		if typeof(st) ~= "table" then
			return
		end
		State.Round = st
		for _, fn in ipairs(roundListeners) do
			task.spawn(fn, st)
		end
	end)
	task.spawn(function()
		local ok, data = pcall(function()
			return Net.Function("GetData"):InvokeServer()
		end)
		if ok and data and not State.Data then
			setData(data)
		end
	end)
end

return State
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "UI", "ModuleScript", [[
-- UI: utilidades para construir la interfaz por codigo con un estilo comun.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local C = Color3.fromRGB

local UI = {}

UI.Theme = {
	Bg = C(14, 16, 26),
	Panel = C(26, 29, 44),
	Panel2 = C(38, 42, 62),
	Panel3 = C(52, 57, 82),
	Accent = C(255, 196, 50),
	Accent2 = C(255, 120, 40),
	Good = C(80, 220, 120),
	Bad = C(255, 80, 80),
	Info = C(80, 170, 255),
	Text = C(255, 255, 255),
	Muted = C(170, 178, 200),
	Font = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
	Black = Enum.Font.GothamBlack,
}
local T = UI.Theme

local clickSound

function UI.New(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.Corner(inst, radius)
	return UI.New("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = inst })
end

function UI.Stroke(inst, color, thickness, transparency)
	return UI.New("UIStroke", {
		Color = color or C(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

function UI.TextStroke(inst, thickness)
	return UI.New("UIStroke", { Color = C(0, 0, 0), Thickness = thickness or 2, Transparency = 0.3, Parent = inst })
end

function UI.Padding(inst, px)
	return UI.New("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = inst,
	})
end

function UI.Gradient(inst, c1, c2, rotation)
	return UI.New("UIGradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(1, c2) }),
		Rotation = rotation or 90,
		Parent = inst,
	})
end

function UI.Tween(inst, seconds, goal, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

-- ScreenGui en PlayerGui
function UI.Gui(name, order, ignoreInset)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = order or 1
	gui.IgnoreGuiInset = ignoreInset == true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function UI.Label(parent, props)
	local p = {
		BackgroundTransparency = 1,
		Font = T.Font,
		TextColor3 = T.Text,
		TextSize = 18,
		Text = "",
		Size = UDim2.new(1, 0, 0, 24),
		Parent = parent,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return UI.New("TextLabel", p)
end

function UI.Panel(parent, props)
	local p = { BackgroundColor3 = T.Panel, BorderSizePixel = 0, Parent = parent }
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	local f = UI.New("Frame", p)
	UI.Corner(f, 12)
	return f
end

-- Rebote rapido (se usa al ganar monedas, abrir ventanas...)
function UI.Pop(inst, amount)
	local scale = inst:FindFirstChildOfClass("UIScale") or UI.New("UIScale", { Parent = inst })
	scale.Scale = 1 + (amount or 0.15)
	UI.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

function UI.PlayClick()
	if not clickSound then
		local ok, Sounds = pcall(function()
			return require(game:GetService("ReplicatedStorage"):WaitForChild("IslasShared"):WaitForChild("Sounds"))
		end)
		clickSound = Instance.new("Sound")
		clickSound.Volume = 0.35
		clickSound.SoundId = ok and Sounds.Click or ""
		clickSound.Parent = game:GetService("SoundService")
	end
	clickSound:Play()
end

-- Boton con animacion al pasar el raton y al pulsar
function UI.Button(parent, text, props, onClick)
	local p = {
		BackgroundColor3 = T.Accent,
		AutoButtonColor = false,
		Font = T.Black,
		TextColor3 = C(30, 25, 10),
		TextSize = 18,
		Text = text,
		Size = UDim2.new(0, 140, 0, 40),
		Parent = parent,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	local b = UI.New("TextButton", p)
	UI.Corner(b, 10)
	local scale = UI.New("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		UI.Tween(scale, 0.12, { Scale = 1.05 })
	end)
	b.MouseLeave:Connect(function()
		UI.Tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		UI.Tween(scale, 0.08, { Scale = 0.95 })
	end)
	b.Activated:Connect(function()
		UI.Tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
		UI.PlayClick()
		if onClick then
			onClick()
		end
	end)
	return b
end

-- Ventana modal con titulo y boton de cerrar. Devuelve window, content
local openWindows = {}
function UI.Window(gui, title, size, accent)
	local win = UI.Panel(gui, {
		Name = "Ventana_" .. title,
		Size = size or UDim2.new(0, 560, 0, 420),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.05,
		Visible = false,
	})
	UI.Stroke(win, accent or T.Accent, 3)
	UI.New("UISizeConstraint", { MaxSize = Vector2.new(900, 700), Parent = win })
	local bar = UI.New("Frame", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = accent or T.Accent,
		BorderSizePixel = 0,
		Parent = win,
	})
	UI.Corner(bar, 12)
	local titleLabel = UI.Label(bar, {
		Text = title,
		Font = T.Black,
		TextSize = 24,
		TextColor3 = C(30, 25, 10),
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = UI.Button(bar, "X", {
		Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(1, -42, 0, 6),
		BackgroundColor3 = T.Bad,
		TextColor3 = T.Text,
	})
	local content = UI.New("Frame", {
		Name = "Contenido",
		Size = UDim2.new(1, -24, 1, -64),
		Position = UDim2.new(0, 12, 0, 56),
		BackgroundTransparency = 1,
		Parent = win,
	})
	local api = {}
	function api.Open()
		for _, w in ipairs(openWindows) do
			if w ~= api then
				w.Close()
			end
		end
		win.Visible = true
		UI.Pop(win, 0.08)
		if api.OnOpen then
			api.OnOpen()
		end
	end
	function api.Close()
		win.Visible = false
	end
	function api.Toggle()
		if win.Visible then
			api.Close()
		else
			api.Open()
		end
	end
	function api.IsOpen()
		return win.Visible
	end
	close.Activated:Connect(api.Close)
	api.Frame, api.Content, api.Title = win, content, titleLabel
	openWindows[#openWindows + 1] = api
	return api
end

function UI.IsMobile()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

return UI
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "VoteUI", "ModuleScript", [[
-- VoteUI: tarjetas de votacion de mapa con votos en directo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local VoteUI = {}
local C = Color3.fromRGB

function VoteUI.Init(modules)
	local UI, SoundFX = modules.UI, modules.SoundFX
	local T = UI.Theme
	local gui = UI.Gui("VotacionGui", 6)
	local panel = UI.Panel(gui, {
		Size = UDim2.new(0, 720, 0, 330),
		Position = UDim2.new(0.5, 0, 0.55, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.08,
		Visible = false,
	})
	UI.Stroke(panel, T.Accent, 3)
	UI.New("UISizeConstraint", { MaxSize = Vector2.new(720, 330), Parent = panel })
	local title = UI.Label(panel, { Text = "VOTA EL SIGUIENTE MAPA", Font = T.Black, TextSize = 26, Size = UDim2.new(1, 0, 0, 44), TextColor3 = T.Accent })
	local cards = UI.New("Frame", { Size = UDim2.new(1, -24, 1, -60), Position = UDim2.new(0, 12, 0, 50), BackgroundTransparency = 1, Parent = panel })
	UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), Parent = cards })

	local voteEnd = nil
	local buttons, counts, titles = {}, {}, {}
	local myVote = nil

	local function highlight()
		for name, b in pairs(buttons) do
			local mine = name == myVote
			b.BackgroundColor3 = mine and C(50, 120, 70) or T.Panel2
			local stroke = b:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = mine and T.Good or T.Panel3
			end
		end
	end

	Net.Event("VoteOptions").OnClientEvent:Connect(function(infos, endTime)
		for _, c in ipairs(cards:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		buttons, counts, titles, myVote = {}, {}, {}, nil
		voteEnd = endTime
		local width = math.floor((696 - 10 * (#infos - 1)) / math.max(1, #infos))
		for _, info in ipairs(infos) do
			local b = UI.Button(cards, "", { Size = UDim2.new(0, width, 1, 0), BackgroundColor3 = T.Panel2, TextColor3 = T.Text }, function()
				myVote = info.Name
				highlight()
				Net.Event("CastVote"):FireServer(info.Name)
			end)
			UI.Stroke(b, T.Panel3, 2)
			UI.Label(b, { Text = info.Title, Font = T.Black, TextSize = 22, TextWrapped = true, Size = UDim2.new(1, -12, 0, 50), Position = UDim2.new(0, 6, 0, 8) })
			UI.Label(b, { Text = info.Description, Font = T.Body, TextSize = 13, TextWrapped = true, TextColor3 = T.Muted, Size = UDim2.new(1, -16, 0, 70), Position = UDim2.new(0, 8, 0, 58), TextYAlignment = Enum.TextYAlignment.Top })
			local icons = table.concat(info.DisasterIcons or {}, " ")
			UI.Label(b, { Text = icons, TextSize = 20, TextWrapped = true, Size = UDim2.new(1, -16, 0, 56), Position = UDim2.new(0, 8, 0, 132), TextYAlignment = Enum.TextYAlignment.Top })
			local count = UI.Label(b, { Text = "0 votos", Font = T.Black, TextSize = 20, TextColor3 = T.Accent, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -36) })
			buttons[info.Name], counts[info.Name], titles[info.Name] = b, count, info.Title
		end
		highlight()
		panel.Visible = true
		UI.Pop(panel, 0.08)
		SoundFX.Play("Whoosh", 0.5)
	end)

	Net.Event("VoteUpdate").OnClientEvent:Connect(function(c)
		for name, label in pairs(counts) do
			local n = c[name] or 0
			local before = label.Text
			label.Text = n .. (n == 1 and " voto" or " votos")
			if before ~= label.Text then
				UI.Pop(label, 0.3)
			end
		end
	end)

	Net.Event("VoteEnd").OnClientEvent:Connect(function(winner, winnerTitle)
		voteEnd = nil
		title.Text = "GANADOR: " .. string.upper(winnerTitle or titles[winner] or tostring(winner))
		local b = buttons[winner]
		if b then
			UI.Pop(b, 0.15)
			b.BackgroundColor3 = C(200, 150, 40)
		end
		SoundFX.Play("Win", 0.6)
		task.delay(2.5, function()
			panel.Visible = false
			title.Text = "VOTA EL SIGUIENTE MAPA"
		end)
	end)

	RunService.Heartbeat:Connect(function()
		if voteEnd and panel.Visible then
			title.Text = "VOTA EL SIGUIENTE MAPA  (" .. math.max(0, math.ceil(voteEnd - workspace:GetServerTimeNow())) .. ")"
		end
	end)
end

return VoteUI
]])

print("Islas de Desastres: parte 5 de 5 instalada. ¡Terminado! Dale a Play.")
