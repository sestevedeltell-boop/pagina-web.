-- VoteUI: tarjetas de votacion de mapa con votos en directo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local VoteUI = {}
local C = Color3.fromRGB

function VoteUI.Init(modules)
	local UI, SoundFX = modules.UI, modules.SoundFX
	local T = UI.Theme
	local gui = UI.Gui("VotacionGui", 6)
	local panel = UI.Panel(gui, {
		Size = UDim2.new(0, 720, 0, 330),
		Position = UDim2.new(0.5, 0, 0.55, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.08,
		Visible = false,
	})
	UI.Stroke(panel, T.Accent, 3)
	UI.New("UISizeConstraint", { MaxSize = Vector2.new(720, 330), Parent = panel })
	local title = UI.Label(panel, { Text = "VOTA EL SIGUIENTE MAPA", Font = T.Black, TextSize = 26, Size = UDim2.new(1, 0, 0, 44), TextColor3 = T.Accent })
	local cards = UI.New("Frame", { Size = UDim2.new(1, -24, 1, -60), Position = UDim2.new(0, 12, 0, 50), BackgroundTransparency = 1, Parent = panel })
	UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), Parent = cards })

	local voteEnd = nil
	local buttons, counts, titles = {}, {}, {}
	local myVote = nil

	local function highlight()
		for name, b in pairs(buttons) do
			local mine = name == myVote
			b.BackgroundColor3 = mine and C(50, 120, 70) or T.Panel2
			local stroke = b:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = mine and T.Good or T.Panel3
			end
		end
	end

	Net.Event("VoteOptions").OnClientEvent:Connect(function(infos, endTime)
		for _, c in ipairs(cards:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		buttons, counts, titles, myVote = {}, {}, {}, nil
		voteEnd = endTime
		local width = math.floor((696 - 10 * (#infos - 1)) / math.max(1, #infos))
		for _, info in ipairs(infos) do
			local b = UI.Button(cards, "", { Size = UDim2.new(0, width, 1, 0), BackgroundColor3 = T.Panel2, TextColor3 = T.Text }, function()
				myVote = info.Name
				highlight()
				Net.Event("CastVote"):FireServer(info.Name)
			end)
			UI.Stroke(b, T.Panel3, 2)
			UI.Label(b, { Text = info.Title, Font = T.Black, TextSize = 22, TextWrapped = true, Size = UDim2.new(1, -12, 0, 50), Position = UDim2.new(0, 6, 0, 8) })
			UI.Label(b, { Text = info.Description, Font = T.Body, TextSize = 13, TextWrapped = true, TextColor3 = T.Muted, Size = UDim2.new(1, -16, 0, 70), Position = UDim2.new(0, 8, 0, 58), TextYAlignment = Enum.TextYAlignment.Top })
			local icons = table.concat(info.DisasterIcons or {}, " ")
			UI.Label(b, { Text = icons, TextSize = 20, TextWrapped = true, Size = UDim2.new(1, -16, 0, 56), Position = UDim2.new(0, 8, 0, 132), TextYAlignment = Enum.TextYAlignment.Top })
			local count = UI.Label(b, { Text = "0 votos", Font = T.Black, TextSize = 20, TextColor3 = T.Accent, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -36) })
			buttons[info.Name], counts[info.Name], titles[info.Name] = b, count, info.Title
		end
		highlight()
		panel.Visible = true
		UI.Pop(panel, 0.08)
		SoundFX.Play("Whoosh", 0.5)
	end)

	Net.Event("VoteUpdate").OnClientEvent:Connect(function(c)
		for name, label in pairs(counts) do
			local n = c[name] or 0
			local before = label.Text
			label.Text = n .. (n == 1 and " voto" or " votos")
			if before ~= label.Text then
				UI.Pop(label, 0.3)
			end
		end
	end)

	Net.Event("VoteEnd").OnClientEvent:Connect(function(winner, winnerTitle)
		voteEnd = nil
		title.Text = "GANADOR: " .. string.upper(winnerTitle or titles[winner] or tostring(winner))
		local b = buttons[winner]
		if b then
			UI.Pop(b, 0.15)
			b.BackgroundColor3 = C(200, 150, 40)
		end
		SoundFX.Play("Win", 0.6)
		task.delay(2.5, function()
			panel.Visible = false
			title.Text = "VOTA EL SIGUIENTE MAPA"
		end)
	end)

	RunService.Heartbeat:Connect(function()
		if voteEnd and panel.Visible then
			title.Text = "VOTA EL SIGUIENTE MAPA  (" .. math.max(0, math.ceil(voteEnd - workspace:GetServerTimeNow())) .. ")"
		end
	end)
end

return VoteUI
