-- Tormenta electrica: rayos avisados con un anillo. Rompen lo que tocan y pueden prender fuego.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		ctx.setLighting({ Brightness = 0.5, FogEnd = 500, FogColor = Color3.fromRGB(55, 60, 75), Ambient = Color3.fromRGB(40, 40, 55), ClockTime = 19 })
		ctx.fx("weather", "rain")
		local cfg = ctx.config
		while ctx.active() do
			local x, z = ctx.targetPoint(0.7, 8)
			Hazards.Strike(ctx, x, z, {
				kind = "bolt",
				radius = cfg.radius or 9,
				damage = cfg.damage or 70,
				warn = 1.1,
				partDamage = 140,
				fling = 35,
				ignite = 0.5,
				color = Color3.fromRGB(255, 235, 90),
				knockback = 30,
			})
			task.wait(ctx.rate(math.max(0.45, 1.3 - ctx.progress() * 0.7)))
		end
	end,
}
