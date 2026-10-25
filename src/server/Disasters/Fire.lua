-- Incendio: focos que crecen y prenden fuego a la madera, la tela y la hierba. El fuego se propaga por los
-- edificios (Destruction) y lo que se quema acaba cayendo.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		task.spawn(function()
			while ctx.active() do
				-- chispas que prenden cerca de los jugadores
				local x, z = ctx.targetPoint(0.6, 25)
				local y = ctx.groundY(x, z) or ctx.bounds.floor
				ctx.D.IgniteSphere(Vector3.new(x, y, z), 12, 0.6)
				task.wait(ctx.rate(3))
			end
		end)
		Hazards.Zones(ctx, {
			color = Color3.fromRGB(255, 110, 30),
			fire = true,
			dps = 14,
			startRadius = 5,
			maxRadius = 22,
			growth = 0.8,
			interval = 6,
			maxZones = 8,
			ignite = true,
			partDamage = 15,
		})
	end,
}
