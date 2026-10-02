-- RisingLiquid: un liquido que sube desde el suelo de la isla (inundacion, lava).
local RisingLiquid = {}

-- opts: name, color, material, transparency, maxHeight, lethal (bool), dps
function RisingLiquid.run(ctx, opts)
	local b = ctx.bounds
	local pad = 120
	local cx, cz = (b.x1 + b.x2) / 2, (b.z1 + b.z2) / 2
	local sx = math.min(2048, (b.x2 - b.x1) + pad * 2)
	local sz = math.min(2048, (b.z2 - b.z1) + pad * 2)
	local part = ctx.build:Box(opts.name, Vector3.new(sx, 1, sz), Vector3.new(cx, b.floor - 0.5, cz), opts.color, opts.material, {
		transparency = opts.transparency,
		canCollide = false,
	})
	local maxHeight = ctx.config.maxHeight or opts.maxHeight
	local riseTime = ctx.duration * 0.85
	local dt = 0.2

	while ctx.active() do
		local level = b.floor + maxHeight * math.min(1, ctx.elapsed() / riseTime)
		part.Position = Vector3.new(cx, level - 0.5, cz)
		for _, entry in ipairs(ctx.players()) do
			if entry.root.Position.Y - 2.5 < level then
				if opts.lethal then
					entry.humanoid.Health = 0
				else
					ctx.damage(entry, opts.dps * dt)
				end
			end
		end
		task.wait(dt)
	end
end

return RisingLiquid
