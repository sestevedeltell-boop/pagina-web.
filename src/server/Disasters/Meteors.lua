local Debris = game:GetService("Debris")

return {
	Title = "Lluvia de meteoritos",
	Description = "Caen meteoritos: un circulo rojo avisa donde van a impactar. ¡Sal de el!",
	Run = function(ctx)
		local Util = ctx.Util
		local C, V = Color3.fromRGB, Vector3.new
		local b = ctx.build
		local radius = ctx.config.radius or 16
		local damage = ctx.config.damage or 75
		local interval = ctx.config.interval or 1.6
		local fall = 1.8

		local function strike(x, z)
			local y = ctx.groundY(x, z) or ctx.bounds.floor
			local target = V(x, y, z)
			local marker = b:Box("Aviso", V(0.3, radius * 1.6, radius * 1.6), target + V(0, 0.3, 0), C(255, 60, 40), Enum.Material.Neon, {
				shape = Enum.PartType.Cylinder,
				rot = V(0, 0, 90),
				transparency = 0.55,
				canCollide = false,
			})
			local start = V(x + math.random(-60, 60), ctx.bounds.top + 120, z + math.random(-60, 60))
			local meteor = b:Box("Meteoro", V(7, 7, 7), start, C(255, 120, 30), Enum.Material.Neon, {
				shape = Enum.PartType.Ball,
				canCollide = false,
			})
			Util.AddLight(meteor, 40, 3, C(255, 150, 60))
			ctx.tween(meteor, fall, { Position = target + V(0, 3.5, 0) })

			task.delay(fall, function()
				if ctx.stopped then
					return
				end
				meteor:Destroy()
				marker:Destroy()
				local boom = b:Box("Explosion", V(4, 4, 4), target + V(0, 3, 0), C(255, 170, 60), Enum.Material.Neon, {
					shape = Enum.PartType.Ball,
					transparency = 0.2,
					canCollide = false,
				})
				local big = radius * 2.4
				ctx.tween(boom, 0.5, { Size = V(big, big, big), Transparency = 1 })
				Debris:AddItem(boom, 1)
				for _, entry in ipairs(ctx.players()) do
					local off = entry.root.Position - target
					local d = off.Magnitude
					if d <= radius then
						ctx.damage(entry, damage * (1 - 0.6 * d / radius))
						if d > 0.1 then
							entry.root.AssemblyLinearVelocity = off.Unit * 60 + V(0, 40, 0)
						end
					end
				end
			end)
		end

		while ctx.active() do
			local volley = 1 + math.floor(ctx.progress() * 2)
			local players = ctx.players()
			for _ = 1, volley do
				local x, z
				if #players > 0 and math.random() < 0.6 then
					-- apuntan cerca de un jugador para que no se quede quieto
					local p = players[math.random(#players)].root.Position
					x = math.clamp(p.X + math.random(-18, 18), ctx.bounds.x1, ctx.bounds.x2)
					z = math.clamp(p.Z + math.random(-18, 18), ctx.bounds.z1, ctx.bounds.z2)
				else
					x, z = ctx.randomPoint()
				end
				strike(x, z)
			end
			task.wait(math.max(0.5, interval - ctx.progress() * 0.9))
		end
	end,
}
