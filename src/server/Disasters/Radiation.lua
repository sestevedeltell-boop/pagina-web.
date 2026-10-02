local ZoneHazard = require(script.Parent.Parent.ZoneHazard)

return {
	Title = "Fuga de radiacion",
	Description = "Nubes radiactivas verdes recorren la estación. No te quedes dentro.",
	Run = function(ctx)
		ZoneHazard.run(ctx, {
			color = Color3.fromRGB(110, 255, 80),
			fire = false,
			dps = 11,
			startRadius = 6,
			maxRadius = 28,
			growth = 1.1,
			interval = 6,
			maxZones = 8,
		})
	end,
}
