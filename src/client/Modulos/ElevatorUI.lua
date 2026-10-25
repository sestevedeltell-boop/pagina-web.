-- ElevatorUI: menu de plantas al pulsar el boton dentro de un ascensor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local ElevatorUI = {}
local C = Color3.fromRGB

function ElevatorUI.Init(modules)
	local UI = modules.UI
	local T = UI.Theme
	local gui = UI.Gui("AscensorGui", 9)
	local panel = UI.Panel(gui, {
		Size = UDim2.new(0, 260, 0, 100),
		Position = UDim2.new(1, -280, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = C(30, 32, 40),
		Visible = false,
	})
	UI.Stroke(panel, C(120, 255, 140), 2)
	UI.Label(panel, { Text = "▲▼ ELIGE PLANTA", Font = T.Black, TextSize = 16, TextColor3 = C(120, 255, 140), Size = UDim2.new(1, 0, 0, 30) })
	local grid = UI.New("Frame", { Size = UDim2.new(1, -16, 1, -70), Position = UDim2.new(0, 8, 0, 32), BackgroundTransparency = 1, Parent = panel })
	UI.New("UIGridLayout", { CellSize = UDim2.new(0, 54, 0, 44), CellPadding = UDim2.new(0, 6, 0, 6), Parent = grid })
	UI.Button(panel, "CERRAR", { Size = UDim2.new(1, -16, 0, 28), Position = UDim2.new(0, 8, 1, -34), BackgroundColor3 = T.Panel3, TextColor3 = T.Text, TextSize = 13 }, function()
		panel.Visible = false
	end)

	Net.Event("ElevatorMenu").OnClientEvent:Connect(function(id, labels, current)
		for _, c in ipairs(grid:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, label in ipairs(labels) do
			UI.Button(grid, tostring(label), {
				BackgroundColor3 = i == current and C(120, 255, 140) or C(60, 64, 80),
				TextColor3 = i == current and C(20, 40, 20) or C(255, 255, 255),
				TextSize = 18,
			}, function()
				Net.Event("ElevatorRequest"):FireServer(id, i)
				panel.Visible = false
			end)
		end
		local rows = math.ceil(#labels / 4)
		panel.Size = UDim2.new(0, 260, 0, 70 + rows * 50)
		panel.Visible = true
		UI.Pop(panel, 0.1)
	end)
end

return ElevatorUI
