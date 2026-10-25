-- Agujero negro: se mueve despacio por el mapa, atrae jugadores y piezas, arranca trozos de los edificios
-- y se traga todo lo que llega a su centro. Crece con el tiempo.
return {
	Run = function(ctx)
		local bb = ctx.bounds
		local points = {}
		for i = 1, 5 do
			local x, z = ctx.randomPoint()
			points[i] = { x, z }
		end
		local speed = 5 * math.min(ctx.intensity, 1.5)
		local path = ctx.Paths.Make(points, speed, ctx.time(), true)
		local height = ctx.config.height or 25
		ctx.fx("path", "BlackHole", { points = points, speed = speed, t0 = path.t0, loop = true, height = height })
		ctx.setLighting({ Brightness = 0.7, Ambient = Color3.fromRGB(60, 40, 90) })
		local dt = 0.1
		local tick = 0
		local baseY = bb.floor
		while ctx.active() do
			tick = tick + 1
			local x, z = ctx.Paths.At(path, ctx.time())
			if tick % 10 == 1 then
				baseY = ctx.groundY(x, z) or baseY
			end
			local center = Vector3.new(x, baseY + height, z)
			local grow = 1 + ctx.progress() * 0.8
			local pull = 80 * grow
			local horizon = 7 * grow
			for _, entry in ipairs(ctx.players()) do
				local off = center - entry.root.Position
				local d = off.Magnitude
				if d < horizon then
					ctx.kill(entry)
				elseif d < pull then
					local k = 1 - d / pull
					entry.root.AssemblyLinearVelocity = entry.root.AssemblyLinearVelocity * 0.6 + off.Unit * (25 + 60 * k) * ctx.intensity
				end
			end
			if tick % 3 == 0 then
				-- arranca piezas cerca y las atrae
				ctx.D.DamageSphere(center, 26 * grow, 90 * ctx.intensity, { fling = -60, maxParts = 30 })
				ctx.PB.ForEachBody(function(root)
					local off = center - root.Position
					local d = off.Magnitude
					if d < 8 then
						ctx.D.Remove(root)
					elseif d < pull * 1.3 then
						root.AssemblyLinearVelocity = off.Unit * (50 + 40 * (1 - d / (pull * 1.3)))
					end
				end)
			end
			task.wait(dt)
		end
	end,
}
