-- ResultsUI: pantalla de final de ronda (sobreviviste o no, monedas que cuentan hacia arriba, racha)
-- con confeti cuando sobrevives.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local ResultsUI = {}
local C = Color3.fromRGB

function ResultsUI.Init(modules)
	local UI, SoundFX, Quality = modules.UI, modules.SoundFX, modules.Quality
	local T = UI.Theme
	local gui = UI.Gui("ResultadosGui", 7, true)

	local panel = UI.Panel(gui, {
		Size = UDim2.new(0, 460, 0, 300),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.05,
		Visible = false,
	})
	local stroke = UI.Stroke(panel, T.Good, 4)
	local headline = UI.Label(panel, { Font = T.Black, TextSize = 40, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0, 10) })
	UI.TextStroke(headline, 3)
	local sub = UI.Label(panel, { Font = T.Body, TextSize = 16, TextColor3 = T.Muted, TextWrapped = true, Size = UDim2.new(1, -30, 0, 40), Position = UDim2.new(0, 15, 0, 68) })
	local coinsLabel = UI.Label(panel, { Font = T.Black, TextSize = 46, TextColor3 = T.Accent, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0, 112) })
	UI.TextStroke(coinsLabel, 3)
	local xpLabel = UI.Label(panel, { Font = T.Black, TextSize = 22, TextColor3 = T.Info, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 172) })
	local streakLabel = UI.Label(panel, { Font = T.Black, TextSize = 22, TextColor3 = C(255, 140, 60), Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 204) })
	local survivorsLabel = UI.Label(panel, { Font = T.Body, TextSize = 14, TextColor3 = T.Muted, TextWrapped = true, Size = UDim2.new(1, -30, 0, 50), Position = UDim2.new(0, 15, 0, 238) })

	local confettiLayer = UI.New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local confetti = {}
	local function burstConfetti()
		local n = ({ 30, 70, 120 })[Quality.Level]
		for _ = 1, n do
			local f = UI.New("Frame", {
				Size = UDim2.new(0, math.random(6, 12), 0, math.random(10, 18)),
				Position = UDim2.new(math.random(), 0, -0.05 - math.random() * 0.3, 0),
				BackgroundColor3 = Color3.fromHSV(math.random(), 0.8, 1),
				BorderSizePixel = 0,
				Rotation = math.random(0, 360),
				Parent = confettiLayer,
			})
			confetti[#confetti + 1] = { f = f, vy = 0.25 + math.random() * 0.35, vx = (math.random() - 0.5) * 0.1, spin = math.random(-300, 300), born = os.clock() }
		end
	end
	RunService.RenderStepped:Connect(function(dt)
		for i = #confetti, 1, -1 do
			local c = confetti[i]
			local p = c.f.Position
			c.f.Position = UDim2.new(p.X.Scale + c.vx * dt, 0, p.Y.Scale + c.vy * dt, 0)
			c.f.Rotation = c.f.Rotation + c.spin * dt
			if p.Y.Scale > 1.1 or os.clock() - c.born > 6 then
				c.f:Destroy()
				table.remove(confetti, i)
			end
		end
	end)

	Net.Event("RoundResults").OnClientEvent:Connect(function(r)
		if typeof(r) ~= "table" then
			return
		end
		if r.Survived then
			headline.Text = "¡SOBREVIVISTE!"
			headline.TextColor3 = T.Good
			stroke.Color = T.Good
			burstConfetti()
			SoundFX.Play("Win", 0.9)
		else
			headline.Text = "NO SOBREVIVISTE"
			headline.TextColor3 = T.Bad
			stroke.Color = T.Bad
		end
		sub.Text = (r.Map or "") .. "  ·  " .. table.concat(r.Disasters or {}, " + ") .. (r.Modifier and ("  ·  " .. r.Modifier) or "")
		xpLabel.Text = "+" .. (r.XP or 0) .. " XP"
		streakLabel.Text = (r.Streak and r.Streak > 1) and ("🔥 RACHA x" .. r.Streak) or ""
		local names = r.Survivors or {}
		survivorsLabel.Text = #names > 0 and ("Supervivientes: " .. table.concat(names, ", ")) or "Nadie sobrevivio"
		panel.Visible = true
		UI.Pop(panel, 0.15)
		-- las monedas cuentan hacia arriba
		local target = r.Coins or 0
		task.spawn(function()
			local steps = 20
			for i = 1, steps do
				coinsLabel.Text = "+" .. math.floor(target * i / steps) .. " 🪙"
				if i % 4 == 0 then
					SoundFX.Play("Coin", 0.25, 1 + i / steps)
				end
				task.wait(0.04)
			end
			UI.Pop(coinsLabel, 0.3)
		end)
		task.delay(6, function()
			panel.Visible = false
		end)
	end)
end

return ResultsUI
