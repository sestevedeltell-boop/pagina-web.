-- Ventisca: frio extremo. A la intemperie pierdes vida (el paraguas ayuda); bajo techo o cerca de una
-- hoguera estas a salvo (las hogueras ademas curan). La nieve tapa la vista.
return {
	Run = function(ctx)
		ctx.setLighting({ FogColor = Color3.fromRGB(225, 235, 245), FogEnd = 180, FogStart = 10, Brightness = 1.4, ClockTime = 15 })
		ctx.fx("weather", "snow")
		ctx.fx("tint", Color3.fromRGB(200, 225, 255), 0.88)

		-- hogueras repartidas por el mapa
		local fires = {}
		for i = 1, 4 do
			local x, z = ctx.randomPoint()
			local y = ctx.groundY(x, z)
			if y then
				local base = ctx.build:Box("Hoguera", Vector3.new(4, 1, 4), Vector3.new(x, y + 0.5, z), Color3.fromRGB(90, 60, 40), Enum.Material.Wood, { indestructible = true })
				local f = Instance.new("Fire")
				f.Size = 8
				f.Heat = 12
				f.Parent = base
				ctx.Util.AddLight(base, 26, 3, Color3.fromRGB(255, 170, 80))
				fires[#fires + 1] = base.Position
			end
		end
		ctx.fx("markers", fires, Color3.fromRGB(255, 170, 80))

		local dt = 0.5
		while ctx.active() do
			local cold = (3 + ctx.progress() * 4) * ctx.intensity
			for _, entry in ipairs(ctx.players()) do
				local pos = entry.root.Position
				local warm = false
				for _, f in ipairs(fires) do
					if (pos - f).Magnitude < 13 then
						warm = true
						break
					end
				end
				if warm then
					entry.humanoid.Health = math.min(entry.humanoid.MaxHealth, entry.humanoid.Health + 4 * dt)
				elseif not ctx.covered(entry) then
					local k = ctx.holding(entry, "Paraguas") and 0.35 or 1
					ctx.damage(entry, cold * k * dt)
				end
			end
			-- el hielo rompe cristales y piezas finas
			if math.random() < 0.5 then
				local x, z = ctx.randomPoint()
				local part = ctx.D.RandomTopPart(x, z, ctx.bounds.top + 40)
				if part and part.Material == Enum.Material.Glass then
					ctx.D.Break(part, nil, { shatter = true })
				end
			end
			task.wait(dt)
		end
	end,
}
