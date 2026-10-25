-- Invasion alienigena: ovnis que patrullan el mapa. Disparan laseres avisados y encienden rayos abductores:
-- quien se queda debajo sube hacia la nave y, si llega arriba, desaparece.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		local bb = ctx.bounds
		local count = math.clamp(math.floor(2 * ctx.intensity + 0.5), 1, 4)
		local height = ctx.config.height or 70
		local ufos = {}
		for u = 1, count do
			local points = {}
			for i = 1, 5 do
				local x, z = ctx.randomPoint()
				points[i] = { x, z }
			end
			local speed = 14 + math.random() * 6
			local path = ctx.Paths.Make(points, speed, ctx.time(), true)
			ufos[u] = { path = path, beamUntil = 0 }
			ctx.fx("path", "UFO", { points = points, speed = speed, t0 = path.t0, loop = true, height = height, index = u })
		end
		ctx.setLighting({ Ambient = Color3.fromRGB(70, 100, 90), Brightness = 1 })
		local dt = 0.2
		local nextLaser, nextBeam = 0, 4
		while ctx.active() do
			local now = ctx.time()
			for u, ufo in ipairs(ufos) do
				local x, z = ctx.Paths.At(ufo.path, now)
				local top = bb.floor + height
				-- rayo abductor
				if now < ufo.beamUntil then
					for _, entry in ipairs(ctx.players()) do
						local p = entry.root.Position
						local dx, dz = p.X - x, p.Z - z
						if dx * dx + dz * dz < 10 * 10 then
							entry.root.AssemblyLinearVelocity = Vector3.new(-dx * 0.5, 28, -dz * 0.5)
							ctx.damage(entry, 10 * dt)
							if p.Y > top - 8 then
								ctx.kill(entry)
							end
						end
					end
				end
				ufo.x, ufo.z = x, z
			end
			if now >= nextBeam then
				local ufo = ufos[math.random(#ufos)]
				ufo.beamUntil = now + 4.5
				ctx.fx("beam", table.find(ufos, ufo), 4.5)
				nextBeam = now + ctx.rate(math.max(3, 7 - ctx.progress() * 3))
			end
			if now >= nextLaser then
				local ufo = ufos[math.random(#ufos)]
				if ufo.x then
					local tx, tz = ctx.targetPoint(0.7, 12)
					Hazards.Strike(ctx, tx, tz, {
						kind = "laser",
						from = Vector3.new(ufo.x, bb.floor + height - 4, ufo.z),
						radius = 7,
						damage = 35,
						warn = 1,
						partDamage = 110,
						fling = 30,
						color = Color3.fromRGB(80, 255, 140),
						knockback = 25,
					})
				end
				nextLaser = now + ctx.rate(math.max(0.5, 1.4 - ctx.progress() * 0.8))
			end
			task.wait(dt)
		end
	end,
}
