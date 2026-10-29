-- Granizo: piedras de hielo por todo el mapa. A la intemperie hacen dano (el paraguas protege), rompen
-- los cristales enseguida y van picando los tejados. De vez en cuando cae una piedra gorda avisada.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		ctx.setLighting({ Brightness = 0.8, FogEnd = 600, FogColor = Color3.fromRGB(150, 160, 175), Ambient = Color3.fromRGB(70, 75, 90) })
		ctx.fx("weather", "hail")
		local dt = 0.4
		local acc = 0
		while ctx.active() do
			local k = (0.6 + ctx.progress()) * ctx.intensity
			for _, entry in ipairs(ctx.players()) do
				if not ctx.holding(entry, "Paraguas") and not ctx.covered(entry) and math.random() < 0.5 then
					ctx.damage(entry, 3 * k)
				end
			end
			-- piedras que golpean el mapa
			for _ = 1, math.ceil(5 * k) do
				local x, z = ctx.randomPoint()
				local part = ctx.D.RandomTopPart(x, z, ctx.bounds.top + 40)
				if part then
					local glass = part.Material == Enum.Material.Glass
					ctx.D.Damage(part, glass and 100 or 25 * k, Vector3.new(0, -20, 0), { shatter = glass })
				end
			end
			acc = acc + dt
			if acc >= 2.5 then
				acc = 0
				local x, z = ctx.targetPoint(0.5, 15)
				Hazards.Strike(ctx, x, z, {
					kind = "meteor",
					radius = 7,
					damage = 35,
					warn = 1.2,
					partDamage = 160,
					fling = 25,
					color = Color3.fromRGB(200, 230, 255),
					size = 4,
					knockback = 20,
				})
			end
			task.wait(dt)
		end
	end,
}
