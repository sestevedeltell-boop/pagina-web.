-- DailyUI: recompensa diaria con racha de 7 dias.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local DailyUI = {}
local C = Color3.fromRGB

function DailyUI.Init(modules)
	local UI, State = modules.UI, modules.State
	local T = UI.Theme
	local gui = UI.Gui("DiarioGui", 10)
	local win = UI.Window(gui, "🎁 RECOMPENSA DIARIA", UDim2.new(0, 620, 0, 300), C(80, 200, 120))
	local content = win.Content
	local days = UI.New("Frame", { Size = UDim2.new(1, 0, 0, 130), BackgroundTransparency = 1, Parent = content })
	UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), Parent = days })
	local info = UI.Label(content, { Font = T.Body, TextSize = 15, TextColor3 = T.Muted, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 136) })
	local claim = UI.Button(content, "RECLAMAR", { Size = UDim2.new(0, 220, 0, 46), Position = UDim2.new(0.5, -110, 1, -50), BackgroundColor3 = T.Good, TextSize = 20 }, function()
		Net.Event("DailyClaim"):FireServer()
		task.delay(0.5, function()
			win.Close()
		end)
	end)

	local function render()
		local data = State.Data
		if not data then
			return
		end
		for _, c in ipairs(days:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local streak = data.DailyStreak or 0
		local nextDay = data.DailyAvailable and math.min(streak + 1, Config.DailyRewardMaxDays) or streak
		for d = 1, Config.DailyRewardMaxDays do
			local got = d < nextDay or (not data.DailyAvailable and d <= streak)
			local today = data.DailyAvailable and d == nextDay
			local box = UI.Panel(days, { Size = UDim2.new(0, 76, 1, 0), BackgroundColor3 = today and C(60, 120, 80) or (got and T.Panel3 or T.Panel) })
			UI.Stroke(box, today and T.Good or T.Panel3, today and 3 or 1)
			UI.Label(box, { Text = "Dia " .. d, Font = T.Black, TextSize = 15, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 6) })
			UI.Label(box, { Text = got and "✔" or "🪙", TextSize = 32, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 0, 32) })
			UI.Label(box, { Text = tostring(Config.DailyRewardBase * d), Font = T.Black, TextSize = 16, TextColor3 = T.Accent, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -30) })
		end
		claim.Visible = data.DailyAvailable == true
		info.Text = data.DailyAvailable and "¡Tu recompensa de hoy esta lista! Vuelve cada dia para que suba (si pasan mas de 48 h, la racha vuelve al dia 1)."
			or "Ya la has reclamado hoy. Vuelve manana para seguir la racha."
	end

	win.OnOpen = render
	State.OnData(function(data, old)
		if win.IsOpen() then
			render()
		end
		-- se abre sola la primera vez que entras si hay recompensa
		if not old and data.DailyAvailable then
			task.delay(4, win.Open)
		end
	end)
	Net.Event("OpenUI").OnClientEvent:Connect(function(what)
		if what == "Daily" then
			win.Open()
		end
	end)
	DailyUI.Toggle = win.Toggle
end

return DailyUI
