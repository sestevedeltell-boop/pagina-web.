return {
	Title = "Tornado",
	Description = "Un tornado recorre la isla y lo arrastra todo. Alejate de el.",
	Run = function(ctx)
		local C, V = Color3.fromRGB, Vector3.new
		local b = ctx.build
		local bb = ctx.bounds
		local radius = ctx.config.radius or 42
		local speed = ctx.config.speed or 11
		local dt = 0.05
		local LAYERS, LAYER_H = 8, 15

		local px, pz = ctx.randomPoint()
		local wx, wz = ctx.randomPoint()
		local baseY = ctx.groundY(px, pz) or bb.floor

		ctx.setLighting({ Brightness = 0.9, FogEnd = 700, FogColor = C(110, 110, 115) })

		local layers = {}
		for i = 1, LAYERS do
			local d = 8 + i * 5
			layers[i] = b:Box("Embudo", V(LAYER_H, d, d), V(px, baseY + (i - 0.5) * LAYER_H, pz), C(120, 120, 125), Enum.Material.SmoothPlastic, {
				shape = Enum.PartType.Cylinder,
				rot = V(0, 0, 90),
				transparency = 0.55,
				canCollide = false,
			})
		end
		local debris = {}
		for i = 1, 28 do
			local part = b:Box("Escombro", V(2, 2, 2), V(px, baseY, pz), i % 2 == 0 and C(140, 100, 60) or C(150, 150, 155), Enum.Material.Wood, {
				canCollide = false,
			})
			debris[i] = { part = part, a0 = math.random() * math.pi * 2, h = math.random() }
		end

		local fragile = ctx.fragileParts()
		local tick = 0
		while ctx.active() do
			tick = tick + 1
			-- movimiento hacia un punto de paso
			local dx, dz = wx - px, wz - pz
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist < 6 then
				wx, wz = ctx.randomPoint()
			else
				px, pz = px + dx / dist * speed * dt, pz + dz / dist * speed * dt
			end
			if tick % 5 == 0 then
				baseY = ctx.groundY(px, pz) or baseY
			end

			for i, l in ipairs(layers) do
				l.Position = V(px, baseY + (i - 0.5) * LAYER_H, pz)
			end
			local t = ctx.time()
			for _, d in ipairs(debris) do
				local ang = d.a0 + t * (3.2 - d.h * 1.6)
				local r = (6 + d.h * 30)
				d.part.Position = V(px + math.cos(ang) * r, baseY + d.h * LAYERS * LAYER_H, pz + math.sin(ang) * r)
			end

			-- arrastra jugadores
			for _, entry in ipairs(ctx.players()) do
				local pos = entry.root.Position
				local off = V(pos.X - px, 0, pos.Z - pz)
				local d = off.Magnitude
				if d < radius and pos.Y - baseY < LAYERS * LAYER_H + 20 then
					local k = 1 - d / radius
					local inward = d > 0.1 and off.Unit * -1 or V(0, 0, 0)
					local tangent = d > 0.1 and V(-off.Z, 0, off.X).Unit or V(0, 0, 0)
					entry.root.AssemblyLinearVelocity = tangent * (30 * k + 8) + inward * (14 * k) + V(0, 30 * k + 8, 0)
					ctx.damage(entry, 5 * dt * k)
				end
			end

			-- arranca piezas cercanas
			if tick % 4 == 0 then
				local freed = 0
				for i = #fragile, 1, -1 do
					local p = fragile[i]
					if not p.Parent then
						table.remove(fragile, i)
					elseif p.Anchored then
						local pp = p.Position
						local ddx, ddz = pp.X - px, pp.Z - pz
						if ddx * ddx + ddz * ddz < 30 * 30 and pp.Y - baseY < 40 then
							p.Anchored = false
							p.AssemblyLinearVelocity = V(-ddz * 0.8, 40, ddx * 0.8)
							table.remove(fragile, i)
							freed = freed + 1
							if freed >= 3 then
								break
							end
						end
					end
				end
			end
			task.wait(dt)
		end
	end,
}
