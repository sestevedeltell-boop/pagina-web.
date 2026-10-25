-- DebrisFX: fragmentos visuales cuando algo se rompe. Solo existen en este cliente:
--   * el servidor no simula ni replica nada (cero coste de red y de fisica en el servidor),
--   * se reutilizan piezas de un pool (no se crean/destruyen sin parar),
--   * el numero de fragmentos depende de la calidad (Quality) y la distancia,
--   * no chocan entre si ni con los jugadores (grupo de colision IslasFx).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local DebrisFX = {}

local Quality, SoundFX
local folder
local pool = {} -- piezas libres
local active = {} -- { part, born, life, fading }
local total = 0

local function getPart()
	local p = table.remove(pool)
	if p then
		return p
	end
	local settings = Quality.Settings()
	if total >= settings.MaxFragments then
		-- reciclar el fragmento mas viejo
		local oldest = table.remove(active, 1)
		if oldest then
			return oldest.part
		end
		return nil
	end
	total = total + 1
	p = Instance.new("Part")
	p.Name = "Fragmento"
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	pcall(function()
		p.CollisionGroup = "IslasFx"
	end)
	return p
end

local function release(entry)
	local p = entry.part
	p.Anchored = true
	p.Parent = nil
	pool[#pool + 1] = p
end

local function spawnFragments(rec, camPos, settings)
	local center, size = rec.p, rec.s
	if typeof(center) ~= "Vector3" or typeof(size) ~= "Vector3" then
		return
	end
	local dist = (center - camPos).Magnitude
	if dist > settings.Distance then
		return
	end
	local vol = size.X * size.Y * size.Z
	local n = math.clamp(math.floor(math.sqrt(vol) / 2) + 1, 1, settings.PerBreak)
	if dist > settings.Distance * 0.6 then
		n = math.max(1, math.floor(n / 2))
	end
	local scale = 1 / (n ^ (1 / 3))
	local mat = Enum.Material.SmoothPlastic
	pcall(function()
		mat = Enum.Material[rec.m]
	end)
	local glass = rec.m == "Glass"
	for _ = 1, n do
		local p = getPart()
		if not p then
			return
		end
		local r = 0.6 + math.random() * 0.5
		p.Size = Vector3.new(
			math.clamp(size.X * scale * r, 0.3, 6),
			math.clamp(size.Y * scale * r, 0.3, 6),
			math.clamp(size.Z * scale * r, 0.3, 6)
		)
		local off = Vector3.new((math.random() - 0.5) * size.X, (math.random() - 0.5) * size.Y, (math.random() - 0.5) * size.Z) * 0.8
		p.CFrame = CFrame.new(center + off) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		p.Color = rec.c or Color3.new(0.6, 0.6, 0.6)
		p.Material = mat
		p.Transparency = glass and 0.45 or 0
		p.CanCollide = true
		p.Anchored = false
		p.Parent = folder
		local dir = off.Magnitude > 0.1 and off.Unit or Vector3.yAxis
		p.AssemblyLinearVelocity = dir * (8 + math.random() * 14) + Vector3.new(0, 10 + math.random() * 12, 0)
		p.AssemblyAngularVelocity = Vector3.new(math.random() * 10 - 5, math.random() * 10 - 5, math.random() * 10 - 5)
		active[#active + 1] = { part = p, born = os.clock(), life = settings.Life * (0.7 + math.random() * 0.6) }
	end
end

function DebrisFX.Burst(batch)
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local settings = Quality.Settings()
	local sumPos, count, glassCount = Vector3.zero, 0, 0
	for _, rec in ipairs(batch) do
		spawnFragments(rec, camPos, settings)
		if typeof(rec.p) == "Vector3" then
			sumPos = sumPos + rec.p
			count = count + 1
			if rec.m == "Glass" then
				glassCount = glassCount + 1
			end
		end
	end
	if count > 0 and SoundFX then
		local center = sumPos / count
		if (center - camPos).Magnitude < 250 then
			SoundFX.PlayAt(glassCount > count / 2 and "Glass" or "Crumble", center, math.clamp(0.3 + count * 0.05, 0.3, 1))
		end
	end
end

function DebrisFX.Init(modules)
	Quality = modules.Quality
	SoundFX = modules.SoundFX
	folder = Instance.new("Folder")
	folder.Name = "FragmentosLocales"
	folder.Parent = workspace

	Net.Event("Shatter").OnClientEvent:Connect(function(batch)
		if typeof(batch) == "table" then
			DebrisFX.Burst(batch)
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local now = os.clock()
		for i = #active, 1, -1 do
			local e = active[i]
			local age = now - e.born
			if age > e.life then
				local t = math.clamp((age - e.life) / 0.6, 0, 1)
				e.part.Transparency = math.max(e.part.Transparency, t)
				if t >= 1 or e.part.Position.Y < -400 then
					table.remove(active, i)
					release(e)
				end
			end
		end
	end)

	-- si baja la calidad, se sueltan fragmentos sobrantes
	Quality.OnChanged(function()
		local max = Quality.Settings().MaxFragments
		while #active > max do
			release(table.remove(active, 1))
		end
	end)
end

return DebrisFX
