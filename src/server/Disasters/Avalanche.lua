-- Avalancha: bolas de nieve gigantes que cruzan el mapa en linea recta (cada vez mas grandes y rapidas).
-- Aplastan a quien pillan y destrozan los edificios a su paso. El recorrido es determinista: los clientes
-- dibujan la bola con el mismo calculo, sin replicar nada.
return {
	Run = function(ctx)
		local bb = ctx.bounds
		ctx.setLighting({ FogColor = Color3.fromRGB(230, 238, 248), FogEnd = 700, Brightness = 2 })
		ctx.fx("weather", "snow")
		local balls = {}
		local nextBall = ctx.time()
		local dt = 0.15
		while ctx.active() do
			local now = ctx.time()
			if now >= nextBall then
				local p = ctx.progress()
				local radius = (9 + p * 8) * math.min(ctx.intensity, 1.4)
				local speed = (28 + p * 18) * math.min(ctx.intensity, 1.4)
				-- entra por un lado y apunta cerca de un jugador
				local tx, tz = ctx.targetPoint(0.7, 20)
				local angle = math.random() * math.pi * 2
				local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
				local span = math.max(bb.x2 - bb.x1, bb.z2 - bb.z1)
				local start = Vector3.new(tx, 0, tz) - dir * span
				local y = (ctx.groundY(tx, tz) or bb.floor) + radius
				start = Vector3.new(start.X, y, start.Z)
				local length = span * 2
				local ball = { start = start, dir = dir, speed = speed, t0 = now + 1.5, radius = radius, duration = length / speed }
				balls[#balls + 1] = ball
				ctx.fx("roller", ball)
				ctx.fx("shake", 0.5, 1.5)
				nextBall = now + ctx.rate(math.max(2.2, 6 - p * 3.5))
			end
			for i = #balls, 1, -1 do
				local b = balls[i]
				local t = now - b.t0
				if t > b.duration then
					table.remove(balls, i)
				elseif t >= 0 then
					local pos = b.start + b.dir * b.speed * t
					for _, entry in ipairs(ctx.players()) do
						local off = entry.root.Position - pos
						local d = off.Magnitude
						if d < b.radius + 3 then
							ctx.damage(entry, 60)
							entry.root.AssemblyLinearVelocity = b.dir * 80 + Vector3.new(0, 45, 0)
						end
					end
					ctx.D.DamageSphere(pos, b.radius * 1.15, 160 * ctx.intensity, { fling = 70, maxParts = 40 })
				end
			end
			task.wait(dt)
		end
	end,
}
