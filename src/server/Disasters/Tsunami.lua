-- Tsunami: olas gigantes que cruzan el mapa de un lado a otro. Arrastran a los jugadores y destrozan los
-- edificios a su paso. Despues de cada ola el nivel del agua sube un poco.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		local bb = ctx.bounds
		local H = ctx.config.height or 34
		local thick = 30
		local speed = (ctx.config.speed or 32) * math.min(ctx.intensity, 1.4)
		local cx, cz = (bb.x1 + bb.x2) / 2, (bb.z1 + bb.z2) / 2
		local spanX, spanZ = bb.x2 - bb.x1, bb.z2 - bb.z1

		-- agua de fondo que va subiendo con cada ola
		task.spawn(function()
			Hazards.Liquid(ctx, {
				color = Color3.fromRGB(35, 110, 190),
				material = "SmoothPlastic",
				transparency = 0.35,
				maxHeight = ctx.config.maxHeight or (H * 0.45),
				lethal = false,
				dps = 12,
			})
		end)

		while ctx.active() do
			local dirs = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
			local dir = dirs[math.random(#dirs)]
			local along = dir.X ~= 0 and spanX or spanZ
			local width = (dir.X ~= 0 and spanZ or spanX) + 120
			local start = Vector3.new(cx, bb.floor, cz) - dir * (along / 2 + 60)
			local t0 = ctx.time() + 3
			local travel = (along + 140) / speed
			ctx.fx("wave", { start = start, dir = dir, speed = speed, t0 = t0, width = width, height = H, thick = thick, duration = travel })
			ctx.fx("shake", 0.6, 3)
			task.wait(3)
			local acc = 0
			while ctx.active() and ctx.time() < t0 + travel do
				local front = start + dir * speed * (ctx.time() - t0)
				-- jugadores dentro de la ola
				for _, entry in ipairs(ctx.players()) do
					local rel = entry.root.Position - front
					local behind = -(rel.X * dir.X + rel.Z * dir.Z)
					if behind > -2 and behind < thick and entry.root.Position.Y < bb.floor + H then
						Hazards.Push(entry, dir * 55 + Vector3.new(0, 18, 0))
						ctx.damage(entry, 40 * 0.2)
					end
				end
				acc = acc + 0.2
				if acc >= 0.4 then
					acc = 0
					local center = front - dir * 6 + Vector3.new(0, H / 2, 0)
					local size = dir.X ~= 0 and Vector3.new(12, H, width) or Vector3.new(width, H, 12)
					ctx.D.DamageBox(CFrame.new(center), size, 140 * ctx.intensity, { impulse = dir * 70 + Vector3.new(0, 15, 0), maxParts = 50 })
				end
				task.wait(0.2)
			end
			task.wait(ctx.rate(6))
		end
	end,
}
