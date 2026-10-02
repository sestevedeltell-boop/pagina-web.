-- VoteGui: pantalla de votacion y cuenta atras de la ronda (se crea por codigo, sin StarterGui).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("IslasRemotes")
local VoteOptions = Remotes:WaitForChild("VoteOptions")
local VoteUpdate = Remotes:WaitForChild("VoteUpdate")
local VoteEnd = Remotes:WaitForChild("VoteEnd")
local CastVote = Remotes:WaitForChild("CastVote")
local RoundStatus = Remotes:WaitForChild("RoundStatus")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "IslasGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- ===== Barra de estado (arriba) =====
local statusBar = Instance.new("TextLabel")
statusBar.Size = UDim2.new(0, 420, 0, 44)
statusBar.Position = UDim2.new(0.5, -210, 0, 12)
statusBar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
statusBar.BackgroundTransparency = 0.25
statusBar.TextColor3 = Color3.new(1, 1, 1)
statusBar.Font = Enum.Font.GothamBold
statusBar.TextSize = 20
statusBar.Text = ""
statusBar.Parent = gui
Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 10)

local statusText, statusEnd = "", nil
RoundStatus.OnClientEvent:Connect(function(text, endTime)
	statusText, statusEnd = text, endTime
	statusBar.Text = text
end)

-- ===== Panel de votacion (centro) =====
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 560, 0, 250)
panel.Position = UDim2.new(0.5, -280, 0.5, -125)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.1
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Vota el siguiente mapa"
title.Parent = panel

local cards = Instance.new("Frame")
cards.Size = UDim2.new(1, -20, 1, -56)
cards.Position = UDim2.new(0, 10, 0, 46)
cards.BackgroundTransparency = 1
cards.Parent = panel
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 10)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = cards

local voteEnd = nil
local countLabels, buttons = {}, {}
local myVote = nil
local titles = {}

local function clearCards()
	for _, child in ipairs(cards:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	countLabels, buttons, myVote = {}, {}, nil
end

local function refreshHighlight()
	for name, btn in pairs(buttons) do
		btn.BackgroundColor3 = (name == myVote) and Color3.fromRGB(60, 130, 80) or Color3.fromRGB(45, 48, 64)
	end
end

VoteOptions.OnClientEvent:Connect(function(infos, endTime)
	clearCards()
	voteEnd = endTime
	titles = {}
	local width = (540 - 10 * (#infos - 1)) / #infos
	for _, info in ipairs(infos) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, width, 1, 0)
		btn.BackgroundColor3 = Color3.fromRGB(45, 48, 64)
		btn.AutoButtonColor = true
		btn.Text = ""
		btn.Parent = cards
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -10, 0, 34)
		name.Position = UDim2.new(0, 5, 0, 8)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextSize = 20
		name.TextWrapped = true
		name.TextColor3 = Color3.new(1, 1, 1)
		name.Text = info.Title
		name.Parent = btn

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -14, 0, 60)
		desc.Position = UDim2.new(0, 7, 0, 44)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.Gotham
		desc.TextSize = 14
		desc.TextWrapped = true
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.TextColor3 = Color3.fromRGB(200, 205, 220)
		desc.Text = info.Description
		desc.Parent = btn

		local disasters = Instance.new("TextLabel")
		disasters.Size = UDim2.new(1, -14, 0, 50)
		disasters.Position = UDim2.new(0, 7, 0, 106)
		disasters.BackgroundTransparency = 1
		disasters.Font = Enum.Font.GothamMedium
		disasters.TextSize = 12
		disasters.TextWrapped = true
		disasters.TextYAlignment = Enum.TextYAlignment.Top
		disasters.TextColor3 = Color3.fromRGB(255, 160, 90)
		disasters.Text = "Desastres: " .. table.concat(info.DisasterTitles or {}, ", ")
		disasters.Parent = btn

		local count = Instance.new("TextLabel")
		count.Size = UDim2.new(1, 0, 0, 30)
		count.Position = UDim2.new(0, 0, 1, -34)
		count.BackgroundTransparency = 1
		count.Font = Enum.Font.GothamBold
		count.TextSize = 20
		count.TextColor3 = Color3.fromRGB(255, 220, 90)
		count.Text = "0 votos"
		count.Parent = btn

		titles[info.Name] = info.Title
		buttons[info.Name] = btn
		countLabels[info.Name] = count
		btn.Activated:Connect(function()
			myVote = info.Name
			refreshHighlight()
			CastVote:FireServer(info.Name)
		end)
	end
	refreshHighlight()
	panel.Visible = true
end)

VoteUpdate.OnClientEvent:Connect(function(counts)
	for name, label in pairs(countLabels) do
		local n = counts[name] or 0
		label.Text = n .. (n == 1 and " voto" or " votos")
	end
end)

VoteEnd.OnClientEvent:Connect(function(winner)
	voteEnd = nil
	title.Text = "Ganador: " .. tostring(titles[winner] or winner)
	task.delay(2, function()
		panel.Visible = false
		title.Text = "Vota el siguiente mapa"
	end)
end)

-- cuenta atras
RunService.Heartbeat:Connect(function()
	if voteEnd then
		title.Text = "Vota el siguiente mapa (" .. math.max(0, math.ceil(voteEnd - workspace:GetServerTimeNow())) .. ")"
	end
	if statusEnd then
		local left = math.max(0, math.ceil(statusEnd - workspace:GetServerTimeNow()))
		statusBar.Text = statusText .. " " .. left .. "s"
	end
end)
