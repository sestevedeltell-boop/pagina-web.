-- Lluvia acida: quema a quien este a cielo abierto (el paraguas protege) y corroe los tejados poco a poco,
-- abriendo agujeros: los refugios dejan de ser seguros con el tiempo.
return {
	Run = function(ctx)
		ctx.setLighting({ FogColor = Color3.fromRGB(90, 140, 60), FogEnd = 450, Brightness = 1 })
		ctx.fx("tint", Color3.fromRGB(80, 200, 60), 0.86)
		ctx.fx("weather", "acid")
		local dt = 0.5
		local corrodeAcc = 0
		while ctx.active() do
			for _, entry in ipairs(ctx.players()) do
				if not ctx.holding(entry, "Paraguas") and not ctx.covered(entry) then
					ctx.damage(entry, (ctx.config.dps or 7) * dt * ctx.intensity)
				end
			end
			corrodeAcc = corrodeAcc + dt
			if corrodeAcc >= 0.6 then
				corrodeAcc = 0
				for _ = 1, math.ceil(4 * ctx.intensity) do
					local x, z = ctx.randomPoint()
					local part = ctx.D.RandomTopPart(x, z, ctx.bounds.top + 40)
					if part then
						ctx.D.Damage(part, 45, nil, { shatter = true })
					end
				end
			end
			task.wait(dt)
		end
	end,
}
