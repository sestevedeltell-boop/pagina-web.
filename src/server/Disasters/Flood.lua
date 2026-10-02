local RisingLiquid = require(script.Parent.Parent.RisingLiquid)

return {
	Title = "Inundacion",
	Description = "El agua sube sin parar. Busca un lugar alto: abajo te ahogas.",
	Run = function(ctx)
		RisingLiquid.run(ctx, {
			name = "Inundacion",
			color = Color3.fromRGB(40, 120, 200),
			material = Enum.Material.SmoothPlastic,
			transparency = 0.4,
			maxHeight = 40,
			lethal = false,
			dps = 14,
		})
	end,
}
