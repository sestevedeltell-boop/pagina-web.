-- AchievementsUI: lista de logros con progreso y estadisticas.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Achievements = require(Shared:WaitForChild("Achievements"))
local Format = require(Shared:WaitForChild("Format"))

local AchievementsUI = {}
local C = Color3.fromRGB

function AchievementsUI.Init(modules)
	local UI, State = modules.UI, modules.State
	local T = UI.Theme
	local gui = UI.Gui("LogrosGui", 10)
	local win = UI.Window(gui, "🏆 LOGROS", UDim2.new(0.6, 0, 0.75, 0), C(200, 150, 40))
	local stats = UI.Label(win.Content, { Font = T.Body, TextSize = 14, TextColor3 = T.Muted, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Left })
	local list = UI.New("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -46),
		Position = UDim2.new(0, 0, 0, 44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = win.Content,
	})
	UI.New("UIListLayout", { Padding = UDim.new(0, 6), Parent = list })

	local function render()
		local data = State.Data
		if not data then
			return
		end
		local s = data.Stats or {}
		stats.Text = string.format("Victorias: %d  ·  Rondas: %d  ·  Mejor racha: %d  ·  Monedas ganadas: %s  ·  Mapas: %d  ·  Desastres: %d",
			s.Wins or 0, s.Rounds or 0, s.BestStreak or 0, Format.Number(s.CoinsEarned or 0), s.MapsSurvived or 0, s.DisastersSurvived or 0)
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local done = 0
		for _, a in ipairs(Achievements) do
			local got = data.Achievements and data.Achievements[a.Id]
			if got then
				done = done + 1
			end
			local value = math.min(s[a.Stat] or 0, a.Goal)
			local row = UI.Panel(list, { Size = UDim2.new(1, -10, 0, 58), BackgroundColor3 = got and C(60, 55, 25) or T.Panel })
			UI.Stroke(row, got and T.Accent or T.Panel3, got and 2 or 1)
			UI.Label(row, { Text = got and "🏆" or "🔒", TextSize = 28, Size = UDim2.new(0, 50, 1, 0) })
			UI.Label(row, { Text = a.Name, Font = T.Black, TextSize = 17, Size = UDim2.new(1, -200, 0, 22), Position = UDim2.new(0, 52, 0, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = got and T.Accent or T.Text })
			UI.Label(row, { Text = a.Desc, Font = T.Body, TextSize = 13, TextColor3 = T.Muted, Size = UDim2.new(1, -200, 0, 20), Position = UDim2.new(0, 52, 0, 30), TextXAlignment = Enum.TextXAlignment.Left })
			UI.Label(row, { Text = got and "¡Hecho!" or (value .. " / " .. a.Goal), Font = T.Black, TextSize = 15, Size = UDim2.new(0, 140, 0, 22), Position = UDim2.new(1, -146, 0, 6), TextXAlignment = Enum.TextXAlignment.Right })
			UI.Label(row, { Text = "+" .. a.Reward .. " 🪙", Font = T.Black, TextSize = 14, TextColor3 = T.Accent, Size = UDim2.new(0, 140, 0, 20), Position = UDim2.new(1, -146, 0, 30), TextXAlignment = Enum.TextXAlignment.Right })
		end
		win.Title.Text = "🏆 LOGROS  " .. done .. "/" .. #Achievements
	end
	win.OnOpen = render
	State.OnData(function()
		if win.IsOpen() then
			render()
		end
	end)
	AchievementsUI.Toggle = win.Toggle
end

return AchievementsUI
