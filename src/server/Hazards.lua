-- Hazards: piezas comunes de los desastres.
--   Hazards.Strike(ctx, x, z, opts)   impacto avisado (meteorito, rayo, bomba de lava, laser)
--   Hazards.Zones(ctx, opts)          zonas que aparecen y crecen (fuego, radiacion, lava)
--   Hazards.Liquid(ctx, opts)         liquido que sube (inundacion, lava)
-- Todo lo visual se dibuja en los clientes (ctx.fx); aqui solo se calcula el dano.
local Hazards = {}

local function push(entry, velocity)
	entry.root.AssemblyLinearVelocity = velocity
end
Hazards.Push = push

-- opts: kind ("meteor", "bolt", "bomb", "laser"), radius, damage, warn (s), fall (s), from (Vector3 opcional),
--       partDamage, fling, ignite (prob), color, size
function Hazards.Strike(ctx, x, z, opts)
	opts = opts or {}
	local radius = opts.radius or 12
	local y = ctx.groundY(x, z) or ctx.bounds.floor
	local target = Vector3.new(x, y, z)
	local warn = opts.warn or 1.5
	local kind = opts.kind or "meteor"
	local color = opts.color or Color3.fromRGB(255, 70, 40)
	ctx.fx("marker", target, radius, color, warn)
	if kind == "meteor" or kind == "bomb" then
		local from = opts.from or (target + Vector3.new(math.random(-70, 70), ctx.bounds.top - y + 140, math.random(-70, 70)))
		ctx.fx("meteor", from, target, warn, opts.color or Color3.fromRGB(255, 120, 30), opts.size or 7)
	end
	task.delay(warn, function()
		if ctx.stopped then
			return
		end
		if kind == "bolt" or kind == "laser" then
			local from = opts.from or (target + Vector3.new(0, ctx.bounds.top - y + 160, 0))
			ctx.fx("bolt", from, target, kind == "laser" and Color3.fromRGB(80, 255, 140) or Color3.fromRGB(230, 240, 255))
		end
		ctx.fx("explosion", target, radius, color)
		for _, entry in ipairs(ctx.players()) do
			local off = entry.root.Position - target
			local d = off.Magnitude
			if d <= radius then
				ctx.damage(entry, (opts.damage or 60) * (1 - 0.6 * d / radius))
				if d > 0.5 and (opts.knockback or 50) > 0 then
					push(entry, off.Unit * (opts.knockback or 50) + Vector3.new(0, 35, 0))
				end
			end
		end
		if opts.partDamage ~= 0 then
			ctx.D.DamageSphere(target + Vector3.new(0, 2, 0), radius * 1.1, opts.partDamage or 200, { fling = opts.fling or 55 })
		end
		if opts.ignite and math.random() < opts.ignite then
			ctx.D.IgniteSphere(target, radius, 0.5)
		end
	end)
end

-- opts: color, fire, dps, startRadius, maxRadius, growth, interval, maxZones, ignite (bool), partDamage (por s)
function Hazards.Zones(ctx, opts)
	local zones = {}
	local lastSpawn = -math.huge
	local lastSync = 0
	local dt = 0.25
	local cfg = ctx.config
	local maxZones = math.floor((cfg.maxZones or opts.maxZones) * math.min(ctx.intensity, 1.6))
	local interval = ctx.rate(cfg.interval or opts.interval)
	local key = 0

	local function addZone()
		local x, z
		if opts.center then
			local a = math.random() * math.pi * 2
			local r = math.random() * (opts.spread or 30)
			x, z = opts.center.X + math.cos(a) * r, opts.center.Z + math.sin(a) * r
		else
			x, z = ctx.targetPoint(0.5, 30)
		end
		local y = ctx.groundY(x, z) or ctx.bounds.floor
		key = key + 1
		local zone = { key = key, pos = Vector3.new(x, y, z), radius = opts.startRadius }
		zones[#zones + 1] = zone
		ctx.fx("zone", key, zone.pos, zone.radius, opts.color, opts.fire == true)
	end

	while ctx.active() do
		local now = ctx.time()
		if #zones < maxZones and now - lastSpawn >= interval then
			lastSpawn = now
			addZone()
		end
		for _, z in ipairs(zones) do
			z.radius = math.min(opts.maxRadius, z.radius + opts.growth * ctx.intensity * dt)
		end
		if now - lastSync >= 1 then
			lastSync = now
			for _, z in ipairs(zones) do
				ctx.fx("zone", z.key, z.pos, z.radius, opts.color, opts.fire == true)
				if opts.ignite then
					ctx.D.IgniteSphere(z.pos, z.radius * 0.7, 0.35)
				end
				if opts.partDamage then
					ctx.D.DamageSphere(z.pos, z.radius * 0.8, opts.partDamage, { fling = 10, maxParts = 25 })
				end
			end
		end
		for _, entry in ipairs(ctx.players()) do
			local pos = entry.root.Position
			for _, z in ipairs(zones) do
				if (pos - z.pos).Magnitude <= z.radius then
					ctx.damage(entry, opts.dps * dt)
					break
				end
			end
		end
		task.wait(dt)
	end
end

-- opts: color, material (nombre), transparency, maxHeight, lethal, dps, melt (dano a piezas por s), rise (s)
function Hazards.Liquid(ctx, opts)
	local b = ctx.bounds
	local pad = 160
	local cx, cz = (b.x1 + b.x2) / 2, (b.z1 + b.z2) / 2
	local sx = math.min(2048, (b.x2 - b.x1) + pad * 2)
	local sz = math.min(2048, (b.z2 - b.z1) + pad * 2)
	local maxHeight = (ctx.config.maxHeight or opts.maxHeight)
	local y0 = b.floor - 2
	local y1 = b.floor + maxHeight
	local t0 = ctx.time()
	local rise = (opts.rise or ctx.duration * 0.85) / math.min(ctx.intensity, 1.5)
	ctx.fx("liquid", {
		cx = cx, cz = cz, sx = sx, sz = sz, y0 = y0, y1 = y1, t0 = t0, rise = rise,
		color = opts.color, material = opts.material or "SmoothPlastic", transparency = opts.transparency or 0.3,
	})
	local dt = 0.2
	local meltAcc = 0
	while ctx.active() do
		local level = ctx.Paths.Level(y0, y1, t0, rise, ctx.time())
		for _, entry in ipairs(ctx.players()) do
			if entry.root.Position.Y - 2.5 < level then
				if opts.lethal then
					ctx.kill(entry)
				else
					ctx.damage(entry, opts.dps * dt)
				end
			end
		end
		meltAcc = meltAcc + dt
		if opts.melt and meltAcc >= 1 then
			meltAcc = 0
			ctx.D.DamageBox(CFrame.new(cx, level - 1, cz), Vector3.new(sx, 3, sz), opts.melt, { maxParts = 60, shatter = true })
		end
		task.wait(dt)
	end
end

return Hazards
