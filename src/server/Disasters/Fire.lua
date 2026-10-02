local ZoneHazard = require(script.Parent.Parent.ZoneHazard)

return {
	Title = "Incendio",
	Description = "Aparecen focos de fuego que se extienden. Huye de las llamas y sube o aléjate.",
	Run = function(ctx)
		ZoneHazard.run(ctx, {
			color = Color3.fromRGB(255, 110, 30),
			fire = true,
			dps = 14,
			startRadius = 5,
			maxRadius = 24,
			growth = 0.9,
			interval = 7,
			maxZones = 9,
		})
	end,
}
