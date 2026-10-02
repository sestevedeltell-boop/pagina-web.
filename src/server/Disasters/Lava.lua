local RisingLiquid = require(script.Parent.Parent.RisingLiquid)

return {
	Title = "Lava",
	Description = "¡El suelo es lava! Sube: tocarla es morir al instante.",
	Run = function(ctx)
		RisingLiquid.run(ctx, {
			name = "Lava",
			color = Color3.fromRGB(255, 90, 20),
			material = Enum.Material.Neon,
			transparency = 0.1,
			maxHeight = 40,
			lethal = true,
			dps = 0,
		})
	end,
}
