-- Lava: sube, derrite lo que toca (los edificios se hunden desde abajo) y mata al instante.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		ctx.setLighting({ OutdoorAmbient = Color3.fromRGB(150, 90, 60) })
		Hazards.Liquid(ctx, {
			color = Color3.fromRGB(255, 90, 20),
			material = "Neon",
			transparency = 0.05,
			maxHeight = 40,
			lethal = true,
			melt = 90,
		})
	end,
}
