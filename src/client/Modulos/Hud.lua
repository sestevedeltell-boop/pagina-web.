-- Hud: barra superior (fase, tiempo, vivos, desastres, modificador), monedas, nivel con barra de XP
-- y botones del menu.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Format"))

local Hud = {}
local C = Color3.fromRGB

local PHASE_TEXT = {
	Waiting = "ESPERANDO JUGADORES",
	Intermission = "DESCANSO",
	Vote = "VOTACION",
	Loading = "CARGANDO MAPA",
	Round = "¡SOBREVIVE!",
	Results = "RESULTADOS",
}

function Hud.Init(modules)
	local UI, State, SoundFX = modules.UI, modules.State, modules.SoundFX
	local T = UI.Theme
	local gui = UI.Gui("HudGui", 2)

	-- ===== Barra superior =====
	local top = UI.Panel(gui, {
		Size = UDim2.new(0, 420, 0, 62),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.15,
	})
	UI.Stroke(top, T.Accent, 2, 0.3)
	local phase = UI.Label(top, { Font = T.Black, TextSize = 20, Size = UDim2.new(1, -110, 0, 26), Position = UDim2.new(0, 14, 0, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Accent })
	local status = UI.Label(top, { Font = T.Body, TextSize = 14, Size = UDim2.new(1, -110, 0, 22), Position = UDim2.new(0, 14, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Muted, TextTruncate = Enum.TextTruncate.AtEnd })
	local timer = UI.Label(top, { Font = T.Black, TextSize = 32, Size = UDim2.new(0, 100, 1, 0), Position = UDim2.new(1, -108, 0, 0), TextXAlignment = Enum.TextXAlignment.Right })
	UI.TextStroke(timer, 2)

	local chips = UI.New("Frame", {
		Size = UDim2.new(0, 600, 0, 30),
		Position = UDim2.new(0.5, 0, 0, 76),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), Parent = chips })

	local function chip(text, color)
		local f = UI.Panel(chips, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = color or T.Panel2, BackgroundTransparency = 0.1 })
		UI.Padding(f, 4)
		UI.Label(f, { Text = "  " .. text .. "  ", Font = T.Black, TextSize = 14, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = C(255, 255, 255) })
		return f
	end

	-- ===== Monedas y nivel (izquierda arriba) =====
	local left = UI.New("Frame", { Size = UDim2.new(0, 200, 0, 110), Position = UDim2.new(0, 10, 0, 8), BackgroundTransparency = 1, Parent = gui })
	local coinBox = UI.Panel(left, { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.15 })
	UI.Stroke(coinBox, T.Accent, 2, 0.3)
	UI.Label(coinBox, { Text = "🪙", TextSize = 26, Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(0, 4, 0, 0) })
	local coins = UI.Label(coinBox, { Text = "0", Font = T.Black, TextSize = 26, TextColor3 = T.Accent, Size = UDim2.new(1, -52, 1, 0), Position = UDim2.new(0, 44, 0, 0), TextXAlignment = Enum.TextXAlignment.Left })
	local levelBox = UI.Panel(left, { Size = UDim2.new(1, 0, 0, 56), Position = UDim2.new(0, 0, 0, 50), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.15 })
	local levelBadge = UI.Panel(levelBox, { Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0, 6, 0, 6), BackgroundColor3 = T.Info })
	local levelText = UI.Label(levelBadge, { Text = "1", Font = T.Black, TextSize = 22, Size = UDim2.fromScale(1, 1) })
	local titleText = UI.Label(levelBox, { Text = "Novato", Font = T.Font, TextSize = 15, Size = UDim2.new(1, -60, 0, 20), Position = UDim2.new(0, 56, 0, 6), TextXAlignment = Enum.TextXAlignment.Left })
	local barBg = UI.Panel(levelBox, { Size = UDim2.new(1, -62, 0, 12), Position = UDim2.new(0, 56, 0, 30), BackgroundColor3 = T.Panel3 })
	local bar = UI.Panel(barBg, { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.Info })
	local xpText = UI.Label(levelBox, { Text = "", Font = T.Body, TextSize = 11, TextColor3 = T.Muted, Size = UDim2.new(1, -62, 0, 12), Position = UDim2.new(0, 56, 0, 42), TextXAlignment = Enum.TextXAlignment.Left })

	-- contador de monedas que sube poco a poco (mas satisfactorio)
	local shownCoins, targetCoins = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		if shownCoins ~= targetCoins then
			local diff = targetCoins - shownCoins
			local step = math.max(1, math.abs(diff) * math.min(1, dt * 6))
			if math.abs(diff) <= step then
				shownCoins = targetCoins
			else
				shownCoins = shownCoins + (diff > 0 and step or -step)
			end
			coins.Text = Format.Number(shownCoins)
		end
	end)

	State.OnData(function(data, old)
		targetCoins = data.Coins or 0
		if old and data.Coins > old.Coins then
			UI.Pop(coinBox, 0.12)
		end
		levelText.Text = tostring(data.Level)
		titleText.Text = data.Title or ""
		titleText.TextColor3 = data.TitleColor or T.Text
		levelBadge.BackgroundColor3 = data.TitleColor or T.Info
		bar.BackgroundColor3 = data.TitleColor or T.Info
		local k = data.LevelNeed and data.LevelNeed > 0 and (data.LevelXP / data.LevelNeed) or 0
		UI.Tween(bar, 0.4, { Size = UDim2.new(math.clamp(k, 0, 1), 0, 1, 0) })
		xpText.Text = (data.LevelXP or 0) .. " / " .. (data.LevelNeed or 0) .. " XP"
	end)

	-- ===== Menu (izquierda, centro) =====
	local menu = UI.New("Frame", { Size = UDim2.new(0, 64, 0, 330), Position = UDim2.new(0, 10, 0.5, -150), BackgroundTransparency = 1, Parent = gui })
	UI.New("UIListLayout", { Padding = UDim.new(0, 8), Parent = menu })
	local function menuButton(icon, label, color, onClick)
		local b = UI.Button(menu, icon, { Size = UDim2.new(0, 60, 0, 60), BackgroundColor3 = color, TextSize = 28, TextColor3 = C(255, 255, 255) }, onClick)
		UI.Stroke(b, C(0, 0, 0), 2, 0.4)
		local l = UI.Label(b, { Text = label, Font = T.Black, TextSize = 11, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -16) })
		UI.TextStroke(l, 1.5)
		return b
	end
	menuButton("🛒", "TIENDA", C(255, 160, 40), function()
		if modules.ShopUI then
			modules.ShopUI.Toggle()
		end
	end)
	local dailyBtn = menuButton("🎁", "DIARIO", C(80, 200, 120), function()
		if modules.DailyUI then
			modules.DailyUI.Toggle()
		end
	end)
	local dailyDot = UI.Panel(dailyBtn, { Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(1, -12, 0, -4), BackgroundColor3 = T.Bad, Visible = false })
	UI.Corner(dailyDot, 8)
	menuButton("🏆", "LOGROS", C(200, 150, 40), function()
		if modules.AchievementsUI then
			modules.AchievementsUI.Toggle()
		end
	end)
	menuButton("⚙️", "AJUSTES", C(110, 120, 150), function()
		if modules.SettingsUI then
			modules.SettingsUI.Toggle()
		end
	end)
	State.OnData(function(data)
		dailyDot.Visible = data.DailyAvailable == true
	end)

	-- ===== Estado de ronda =====
	local function refreshRound(st)
		phase.Text = PHASE_TEXT[st.Phase] or st.Phase or ""
		status.Text = st.Status or ""
		for _, c in ipairs(chips:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		if st.Phase == "Round" or st.Phase == "Results" then
			if st.Total and st.Total > 0 then
				chip("👥 " .. (st.Alive or 0) .. "/" .. st.Total, T.Panel2)
			end
			for _, d in ipairs(st.Disasters or {}) do
				chip((d.Icon or "⚠️") .. " " .. (d.Title or ""), C(150, 40, 40))
			end
		end
		if st.Modifier then
			chip("✨ " .. st.Modifier.Title, st.Modifier.Color)
		end
	end
	State.OnRound(refreshRound)

	local lastSecond = -1
	RunService.Heartbeat:Connect(function()
		local st = State.Round
		if st and st.EndsAt and st.EndsAt > 0 then
			local left = st.EndsAt - workspace:GetServerTimeNow()
			timer.Text = Format.Time(left)
			local s = math.ceil(left)
			if st.Phase == "Round" and s <= 10 and s > 0 and s ~= lastSecond then
				lastSecond = s
				timer.TextColor3 = C(255, 90, 90)
				UI.Pop(timer, 0.25)
				SoundFX.Play("Click", 0.4, 1.4)
			elseif s > 10 then
				timer.TextColor3 = T.Text
			end
		else
			timer.Text = ""
		end
	end)

	Hud.Gui = gui
end

return Hud
