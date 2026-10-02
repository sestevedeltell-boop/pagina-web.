return {
	Title = "Lluvia acida",
	Description = "Llueve acido: quema a quien este a cielo abierto. ¡Ponte bajo techo!",
	Run = function(ctx)
		ctx.setLighting({ FogColor = Color3.fromRGB(90, 140, 60), FogEnd = 450, Brightness = 1 })
		ctx.fx("tint", Color3.fromRGB(80, 200, 60), 0.86)
		local dt = 0.5
		while ctx.active() do
			for _, entry in ipairs(ctx.players()) do
				-- si hay algo encima (techo, cristal, balcon) estas a cubierto
				local origin = entry.root.Position + Vector3.new(0, 2, 0)
				local cover = workspace:Raycast(origin, Vector3.new(0, 400, 0), ctx.rayParams)
				if not cover then
					ctx.damage(entry, (ctx.config.dps or 7) * dt)
				end
			end
			task.wait(dt)
		end
	end,
}
