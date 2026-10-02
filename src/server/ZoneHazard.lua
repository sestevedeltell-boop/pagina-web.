-- ZoneHazard: zonas peligrosas que aparecen, crecen y hacen dano a quien este dentro (fuego, radiacion...).
local ZoneHazard = {}

-- opts: color, fire (bool), dps, startRadius, maxRadius, growth (studs/s), interval (s entre zonas), maxZones
function ZoneHazard.run(ctx, opts)
	local Util = ctx.Util
	local zones = {}
	local lastSpawn = -math.huge
	local dt = 0.25
	local cfg = ctx.config
	local maxZones = cfg.maxZones or opts.maxZones
	local interval = cfg.interval or opts.interval

	local function addZone()
		local x, z
		local list = ctx.players()
		if #list > 0 and math.random() < 0.5 then
			-- la mitad de las veces aparece cerca de un jugador
			local p = list[math.random(#list)].root.Position
			x = math.clamp(p.X + math.random(-30, 30), ctx.bounds.x1, ctx.bounds.x2)
			z = math.clamp(p.Z + math.random(-30, 30), ctx.bounds.z1, ctx.bounds.z2)
		else
			x, z = ctx.randomPoint()
		end
		local y = ctx.groundY(x, z) or ctx.bounds.floor
		local d = opts.startRadius * 2
		local part = ctx.build:Box("Zona", Vector3.new(d, d, d), Vector3.new(x, y + 1, z), opts.color, Enum.Material.Neon, {
			shape = Enum.PartType.Ball,
			transparency = 0.45,
			canCollide = false,
		})
		if opts.fire then
			local f = Instance.new("Fire")
			f.Size = 24
			f.Heat = 12
			f.Parent = part
		end
		Util.AddLight(part, 35, 2, opts.color)
		zones[#zones + 1] = { pos = Vector3.new(x, y, z), radius = opts.startRadius, part = part }
	end

	while ctx.active() do
		local now = ctx.time()
		if #zones < maxZones and now - lastSpawn >= interval then
			lastSpawn = now
			addZone()
		end
		for _, z in ipairs(zones) do
			z.radius = math.min(opts.maxRadius, z.radius + opts.growth * dt)
			local d = z.radius * 2
			z.part.Size = Vector3.new(d, d, d)
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

return ZoneHazard
