-- Tornado: recorre el mapa siguiendo puntos de paso (los clientes lo dibujan con el mismo recorrido),
-- arrastra jugadores, arranca piezas y lanza por los aires los escombros sueltos.
return {
	Run = function(ctx)
		local cfg = ctx.config
		local radius = cfg.radius or 42
		local speed = (cfg.speed or 11) * math.min(ctx.intensity, 1.5)
		local points = {}
		for i = 1, 7 do
			local x, z = ctx.randomPoint()
			points[i] = { x, z }
		end
		local path = ctx.Paths.Make(points, speed, ctx.time(), true)
		ctx.fx("path", "Tornado", { points = points, speed = speed, t0 = path.t0, loop = true, radius = radius })
		ctx.setLighting({ Brightness = 0.9, FogEnd = 700, FogColor = Color3.fromRGB(110, 110, 115) })

		local baseY = ctx.bounds.floor
		local tick = 0
		local dt = 0.1
		while ctx.active() do
			tick = tick + 1
			local px, pz = ctx.Paths.At(path, ctx.time())
			if tick % 5 == 1 then
				baseY = ctx.groundY(px, pz) or baseY
			end
			local core = Vector3.new(px, baseY, pz)

			for _, entry in ipairs(ctx.players()) do
				local pos = entry.root.Position
				local off = Vector3.new(pos.X - px, 0, pos.Z - pz)
				local d = off.Magnitude
				if d < radius and pos.Y - baseY < 140 then
					local k = 1 - d / radius
					local inward = d > 0.1 and -off.Unit or Vector3.zero
					local tangent = d > 0.1 and Vector3.new(-off.Z, 0, off.X).Unit or Vector3.zero
					entry.root.AssemblyLinearVelocity = tangent * (32 * k + 8) + inward * (15 * k) + Vector3.new(0, 30 * k + 8, 0)
					ctx.damage(entry, 6 * dt * k)
				end
			end

			if tick % 3 == 0 then
				ctx.D.DamageSphere(core + Vector3.new(0, 10, 0), 22, 70 * ctx.intensity, { fling = 80, maxParts = 30 })
				ctx.PB.ForEachBody(function(root)
					local p = root.Position
					local ox, oz = p.X - px, p.Z - pz
					local dd = math.sqrt(ox * ox + oz * oz)
					if dd > 0.5 and dd < radius * 1.2 then
						root.AssemblyLinearVelocity = Vector3.new(-oz, 0, ox).Unit * 45 + Vector3.new(-ox, 0, -oz).Unit * 12 + Vector3.new(0, 35, 0)
					end
				end)
			end
			task.wait(dt)
		end
	end,
}
