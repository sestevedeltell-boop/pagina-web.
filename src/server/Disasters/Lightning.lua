local Debris = game:GetService("Debris")

return {
	Title = "Tormenta electrica",
	Description = "Caen rayos. Un anillo amarillo avisa del impacto: no te quedes en el.",
	Run = function(ctx)
		local C, V = Color3.fromRGB, Vector3.new
		local b = ctx.build
		local radius = ctx.config.radius or 9
		local damage = ctx.config.damage or 65
		local interval = ctx.config.interval or 1.3
		local warn = 1.2

		ctx.setLighting({ Brightness = 0.6, FogEnd = 450, FogColor = C(55, 60, 75), Ambient = C(40, 40, 55) })

		local function strike(x, z)
			local y = ctx.groundY(x, z) or ctx.bounds.floor
			local target = V(x, y, z)
			local ring = b:Box("AvisoRayo", V(0.2, radius * 2, radius * 2), target + V(0, 0.2, 0), C(255, 235, 90), Enum.Material.Neon, {
				shape = Enum.PartType.Cylinder,
				rot = V(0, 0, 90),
				transparency = 0.5,
				canCollide = false,
			})
			task.delay(warn, function()
				if ctx.stopped then
					return
				end
				ring:Destroy()
				local height = ctx.bounds.top + 150 - y
				local bolt = b:Box("Rayo", V(1.2, height, 1.2), V(x, y + height / 2, z), C(235, 245, 255), Enum.Material.Neon, {
					canCollide = false,
				})
				Debris:AddItem(bolt, 0.2)
				ctx.fx("flash")
				for _, entry in ipairs(ctx.players()) do
					if (entry.root.Position - target).Magnitude <= radius then
						ctx.damage(entry, damage)
					end
				end
			end)
		end

		while ctx.active() do
			local players = ctx.players()
			local x, z
			if #players > 0 and math.random() < 0.7 then
				local p = players[math.random(#players)].root.Position
				x = math.clamp(p.X + math.random(-8, 8), ctx.bounds.x1, ctx.bounds.x2)
				z = math.clamp(p.Z + math.random(-8, 8), ctx.bounds.z1, ctx.bounds.z2)
			else
				x, z = ctx.randomPoint()
			end
			strike(x, z)
			task.wait(math.max(0.45, interval - ctx.progress() * 0.7))
		end
	end,
}
