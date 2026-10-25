-- SettingsUI: calidad de efectos (auto/baja/media/alta), temblor de camara, musica y sonidos.
-- Se guarda en tus datos (SettingsChanged).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local SettingsUI = {}
local C = Color3.fromRGB

function SettingsUI.Init(modules)
	local UI, State, Quality, SoundFX, DisasterFX = modules.UI, modules.State, modules.Quality, modules.SoundFX, modules.DisasterFX
	local T = UI.Theme
	local gui = UI.Gui("AjustesGui", 10)
	local win = UI.Window(gui, "⚙️ AJUSTES", UDim2.new(0, 480, 0, 360), C(110, 120, 150))
	local layout = UI.New("UIListLayout", { Padding = UDim.new(0, 10), Parent = win.Content })

	local settings = { Quality = 0, Shake = 1, Music = true, Sounds = true }

	local function apply()
		if settings.Quality == 0 then
			Quality.Set(nil, true)
		else
			Quality.Set(settings.Quality, false)
		end
		if DisasterFX then
			DisasterFX.ShakeScale = settings.Shake
		end
		SoundFX.Muted = not settings.Sounds
		if modules.Music then
			modules.Music.SetEnabled(settings.Music)
		end
	end

	local function save()
		apply()
		Net.Event("SettingsChanged"):FireServer(settings)
	end

	local function row(title)
		local r = UI.New("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, Parent = win.Content })
		UI.Label(r, { Text = title, Font = T.Black, TextSize = 17, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left })
		local buttons = UI.New("Frame", { Size = UDim2.new(1, 0, 0, 32), Position = UDim2.new(0, 0, 0, 24), BackgroundTransparency = 1, Parent = r })
		UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = buttons })
		return buttons
	end

	local groups = {}
	local function choice(title, key, options)
		local holder = row(title)
		local btns = {}
		for _, opt in ipairs(options) do
			btns[#btns + 1] = { value = opt[2], button = UI.Button(holder, opt[1], { Size = UDim2.new(0, 100, 1, 0), TextSize = 14 }, function()
				settings[key] = opt[2]
				save()
				for _, g in ipairs(groups) do
					g()
				end
			end) }
		end
		groups[#groups + 1] = function()
			for _, b in ipairs(btns) do
				local on = settings[key] == b.value
				b.button.BackgroundColor3 = on and T.Accent or T.Panel2
				b.button.TextColor3 = on and C(30, 25, 10) or T.Text
			end
		end
	end

	choice("Calidad de efectos", "Quality", { { "AUTO", 0 }, { "BAJA", 1 }, { "MEDIA", 2 }, { "ALTA", 3 } })
	choice("Temblor de camara", "Shake", { { "NO", 0 }, { "SUAVE", 0.5 }, { "NORMAL", 1 } })
	choice("Musica", "Music", { { "SI", true }, { "NO", false } })
	choice("Sonidos", "Sounds", { { "SI", true }, { "NO", false } })
	local fps = UI.Label(win.Content, { Font = T.Body, TextSize = 13, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left })

	win.OnOpen = function()
		for _, g in ipairs(groups) do
			g()
		end
		fps.Text = string.format("FPS: %d  ·  calidad actual: %d", math.floor(Quality.FPS), Quality.Level)
	end

	local loaded = false
	State.OnData(function(data)
		if loaded or not data.Settings then
			return
		end
		loaded = true
		for k, v in pairs(data.Settings) do
			settings[k] = v
		end
		apply()
	end)
	SettingsUI.Toggle = win.Toggle
	local _ = layout
end

return SettingsUI
