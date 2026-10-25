-- Fuga de radiacion: nubes verdes que aparecen y crecen. No rompen nada pero hacen dano dentro.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		ctx.setLighting({ Ambient = Color3.fromRGB(70, 110, 60) })
		Hazards.Zones(ctx, {
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
