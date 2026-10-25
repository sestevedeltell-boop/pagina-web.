-- Volcan: surge del suelo en un lado del mapa, tiembla y lanza bombas de lava cada vez mas a menudo.
-- Alrededor del crater se forman rios de lava (zonas mortales que crecen).
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		local bb = ctx.bounds
		-- en un borde del mapa
		local side = math.random(4)
		local x, z
		if side == 1 then
			x, z = bb.x1 + 15, bb.z1 + math.random() * (bb.z2 - bb.z1)
		elseif side == 2 then
			x, z = bb.x2 - 15, bb.z1 + math.random() * (bb.z2 - bb.z1)
		elseif side == 3 then
			x, z = bb.x1 + math.random() * (bb.x2 - bb.x1), bb.z1 + 15
		else
			x, z = bb.x1 + math.random() * (bb.x2 - bb.x1), bb.z2 - 15
		end
		local y = ctx.groundY(x, z) or bb.floor
		local height = ctx.config.height or 55
		local layers = 6
		local rock = Color3.fromRGB(70, 55, 50)
		local parts = {}
		for i = 1, layers do
			local d = 80 - (i - 1) * 12
			local h = height / layers
			-- sale de debajo del suelo
			local p = ctx.build:Box("Volcan", Vector3.new(h, d, d), Vector3.new(x, y - height + (i - 0.5) * h, z), rock, Enum.Material.Basalt, {
				shape = Enum.PartType.Cylinder,
				rot = Vector3.new(0, 0, 90),
				indestructible = true,
			})
			parts[i] = p
		end
		local crater = ctx.build:Box("Crater", Vector3.new(1, 18, 18), Vector3.new(x, y - 0.5, z), Color3.fromRGB(255, 90, 20), Enum.Material.Neon, {
			shape = Enum.PartType.Cylinder,
			rot = Vector3.new(0, 0, 90),
			canCollide = false,
		})
		for _, p in ipairs(parts) do
			ctx.tween(p, 6, { Position = p.Position + Vector3.new(0, height, 0) })
		end
		ctx.tween(crater, 6, { Position = crater.Position + Vector3.new(0, height + 0.6, 0) })
		ctx.fx("shake", 1.6, 6)
		-- lo que hubiera donde sale el volcan se rompe
		ctx.D.DamageSphere(Vector3.new(x, y + 10, z), 40, 1000, { fling = 80 })
		task.wait(6)
		ctx.setLighting({ OutdoorAmbient = Color3.fromRGB(150, 80, 60), FogColor = Color3.fromRGB(90, 50, 40), FogEnd = 900 })
		local top = Vector3.new(x, y + height + 2, z)

		-- rios de lava alrededor
		task.spawn(function()
			Hazards.Zones(ctx, {
				center = Vector3.new(x, y, z),
				spread = 45,
				color = Color3.fromRGB(255, 80, 20),
				fire = true,
				dps = 45,
				startRadius = 6,
				maxRadius = 18,
				growth = 0.5,
				interval = 9,
				maxZones = 6,
				ignite = true,
				partDamage = 40,
			})
		end)

		while ctx.active() do
			local n = 1 + math.floor(ctx.progress() * 3 * ctx.intensity)
			for _ = 1, n do
				local tx, tz = ctx.targetPoint(0.55, 25)
				Hazards.Strike(ctx, tx, tz, {
					kind = "bomb",
					from = top,
					radius = 11,
					damage = 60,
					warn = 2.2,
					partDamage = 220,
					fling = 50,
					ignite = 0.6,
					color = Color3.fromRGB(255, 80, 20),
					size = 5,
				})
			end
			if math.random() < 0.3 then
				ctx.fx("shake", 0.8, 1.5)
			end
			task.wait(ctx.rate(math.max(0.9, 2.4 - ctx.progress() * 1.4)))
		end
	end,
}
