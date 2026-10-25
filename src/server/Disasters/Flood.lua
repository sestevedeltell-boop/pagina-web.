-- Inundacion: el agua sube hasta la altura que diga el mapa. Abajo te ahogas poco a poco.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		Hazards.Liquid(ctx, {
			color = Color3.fromRGB(40, 120, 200),
			material = "SmoothPlastic",
			transparency = 0.35,
			maxHeight = 40,
			lethal = false,
			dps = 15,
		})
	end,
}
