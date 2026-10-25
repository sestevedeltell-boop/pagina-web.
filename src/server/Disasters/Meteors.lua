-- Lluvia de meteoritos: cada vez mas frecuentes. Revientan tejados y paredes y a veces prenden fuego.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		local cfg = ctx.config
		while ctx.active() do
			local volley = 1 + math.floor(ctx.progress() * 2.5 * ctx.intensity)
			for _ = 1, volley do
				local x, z = ctx.targetPoint(0.6, 18)
				Hazards.Strike(ctx, x, z, {
					kind = "meteor",
					radius = cfg.radius or 14,
					damage = cfg.damage or 70,
					warn = 1.7,
					partDamage = 320,
					fling = 65,
					ignite = 0.25,
					size = 6 + math.random() * 4,
				})
			end
			task.wait(ctx.rate(math.max(0.6, 1.8 - ctx.progress() * 1.0)))
		end
	end,
}
