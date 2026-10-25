-- Virus mortal: algunos jugadores se infectan y pierden vida poco a poco. Contagian a quien este cerca.
-- Las estaciones de cura (cruz verde) curan y quitan el virus. Con un solo jugador, el virus va mas lento.
local Players = game:GetService("Players")

return {
	Run = function(ctx)
		local infected = {} -- [player] = true
		local exposure = {} -- [player] = segundos cerca de un infectado
		local highlights = {}

		local function setInfected(player, on)
			if on == (infected[player] == true) then
				return
			end
			infected[player] = on or nil
			local char = player.Character
			if highlights[player] then
				highlights[player]:Destroy()
				highlights[player] = nil
			end
			if on and char then
				local h = Instance.new("Highlight")
				h.Name = "Virus"
				h.FillColor = Color3.fromRGB(110, 255, 90)
				h.OutlineColor = Color3.fromRGB(30, 120, 20)
				h.FillTransparency = 0.55
				h.Parent = char
				highlights[player] = h
			end
			ctx.fx("infected", player.UserId, on == true)
		end
		ctx.onStop(function()
			for p in pairs(infected) do
				setInfected(p, false)
			end
		end)

		-- estaciones de cura
		local stations = {}
		for i = 1, 3 do
			local x, z = ctx.randomPoint()
			local y = ctx.groundY(x, z)
			if y then
				local pad = ctx.build:Box("EstacionCura", Vector3.new(6, 0.6, 6), Vector3.new(x, y + 0.3, z), Color3.fromRGB(80, 255, 120), Enum.Material.Neon, { indestructible = true })
				ctx.build:Board("Cruz", "✚", Vector3.new(3, 3, 0.4), Vector3.new(x, y + 4, z), Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 200, 80))
				stations[#stations + 1] = pad.Position
			end
		end
		ctx.fx("markers", stations, Color3.fromRGB(80, 255, 120))

		-- paciente cero
		local list = ctx.players()
		local n = math.max(1, math.ceil(#list / 4))
		for i = 1, math.min(n, #list) do
			local j = math.random(#list)
			setInfected(list[j].player, true)
			table.remove(list, j)
		end

		local dt = 0.5
		local solo = #Players:GetPlayers() <= 1
		while ctx.active() do
			local entries = ctx.players()
			local sick = {}
			for _, e in ipairs(entries) do
				if infected[e.player] then
					sick[#sick + 1] = e
					ctx.damage(e, (solo and 0.9 or 1.6) * dt * ctx.intensity)
				end
			end
			for _, e in ipairs(entries) do
				local pos = e.root.Position
				-- curarse
				for _, s in ipairs(stations) do
					if (pos - s).Magnitude < 7 then
						if infected[e.player] then
							setInfected(e.player, false)
						end
						e.humanoid.Health = math.min(e.humanoid.MaxHealth, e.humanoid.Health + 6 * dt)
					end
				end
				-- contagio
				if not infected[e.player] then
					local near = false
					for _, s in ipairs(sick) do
						if (s.root.Position - pos).Magnitude < 9 then
							near = true
							break
						end
					end
					exposure[e.player] = near and (exposure[e.player] or 0) + dt or 0
					if exposure[e.player] >= 1.5 then
						setInfected(e.player, true)
						exposure[e.player] = 0
					end
				end
			end
			-- si se cura todo el mundo, vuelve a aparecer
			if #sick == 0 and #entries > 0 and math.random() < 0.08 then
				setInfected(entries[math.random(#entries)].player, true)
			end
			task.wait(dt)
		end
	end,
}
