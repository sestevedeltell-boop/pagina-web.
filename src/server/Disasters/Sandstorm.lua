-- Tormenta de arena: viento que cambia de direccion y empuja a quien este fuera; la arena hace dano a la
-- intemperie (el paraguas reduce el dano) y arranca piezas ligeras de los tejados.
return {
	Run = function(ctx)
		ctx.setLighting({ FogColor = Color3.fromRGB(215, 175, 110), FogEnd = 160, FogStart = 5, Brightness = 1.6 })
		ctx.fx("weather", "sand")
		ctx.fx("tint", Color3.fromRGB(230, 180, 110), 0.85)
		local angle = math.random() * math.pi * 2
		local dt = 0.25
		local acc = 0
		while ctx.active() do
			angle = angle + (math.random() - 0.5) * 0.15
			local wind = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local strength = (18 + 22 * math.abs(math.sin(ctx.elapsed() * 0.4))) * ctx.intensity
			for _, entry in ipairs(ctx.players()) do
				if not ctx.covered(entry) then
					local v = entry.root.AssemblyLinearVelocity
					entry.root.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, v.Z) + wind * strength * dt * 2.2
					local k = ctx.holding(entry, "Paraguas") and 0.4 or 1
					ctx.damage(entry, 5 * k * dt * ctx.intensity)
				end
			end
			acc = acc + dt
			if acc >= 1 then
				acc = 0
				for _ = 1, 3 do
					local x, z = ctx.randomPoint()
					local part = ctx.D.RandomTopPart(x, z, ctx.bounds.top + 40)
					if part then
						ctx.D.Damage(part, 25 * ctx.intensity, wind * 60 + Vector3.new(0, 20, 0))
					end
				end
			end
			task.wait(dt)
		end
	end,
}
