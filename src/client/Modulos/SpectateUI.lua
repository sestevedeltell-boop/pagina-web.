-- SpectateUI: mirar a los supervivientes cuando estas muerto o esperando en el lobby durante una ronda.
local Players = game:GetService("Players")

local SpectateUI = {}
local C = Color3.fromRGB

function SpectateUI.Init(modules)
	local UI, State = modules.UI, modules.State
	local T = UI.Theme
	local player = Players.LocalPlayer
	local gui = UI.Gui("EspectarGui", 3)

	local openBtn = UI.Button(gui, "👁 ESPECTAR", { Size = UDim2.new(0, 150, 0, 40), Position = UDim2.new(0.5, -75, 1, -110), BackgroundColor3 = C(90, 110, 200), TextColor3 = C(255, 255, 255), Visible = false })
	local bar = UI.Panel(gui, { Size = UDim2.new(0, 420, 0, 54), Position = UDim2.new(0.5, -210, 1, -120), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.1, Visible = false })
	UI.Stroke(bar, C(90, 110, 200), 2)
	local name = UI.Label(bar, { Font = T.Black, TextSize = 18, Size = UDim2.new(1, -200, 1, 0), Position = UDim2.new(0, 100, 0, 0) })

	local targets, index, spectating = {}, 1, false

	local function camera()
		return workspace.CurrentCamera
	end

	local function stop()
		spectating = false
		bar.Visible = false
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and camera() then
			camera().CameraSubject = hum
		end
	end

	local function refreshTargets()
		targets = {}
		for _, id in ipairs(State.Round.AliveIds or {}) do
			local p = Players:GetPlayerByUserId(id)
			if p and p ~= player and p.Character then
				targets[#targets + 1] = p
			end
		end
	end

	local function show()
		refreshTargets()
		if #targets == 0 then
			stop()
			return
		end
		index = ((index - 1) % #targets) + 1
		local target = targets[index]
		local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if hum and camera() then
			camera().CameraSubject = hum
			name.Text = target.DisplayName .. "  (" .. index .. "/" .. #targets .. ")"
		end
	end

	UI.Button(bar, "◀", { Size = UDim2.new(0, 44, 0, 40), Position = UDim2.new(0, 8, 0, 7), BackgroundColor3 = T.Panel2, TextColor3 = T.Text }, function()
		index = index - 1
		show()
	end)
	UI.Button(bar, "▶", { Size = UDim2.new(0, 44, 0, 40), Position = UDim2.new(0, 54, 0, 7), BackgroundColor3 = T.Panel2, TextColor3 = T.Text }, function()
		index = index + 1
		show()
	end)
	UI.Button(bar, "SALIR", { Size = UDim2.new(0, 90, 0, 40), Position = UDim2.new(1, -98, 0, 7), BackgroundColor3 = T.Bad, TextColor3 = T.Text }, stop)

	openBtn.Activated:Connect(function()
		spectating = true
		bar.Visible = true
		openBtn.Visible = false
		show()
	end)

	State.OnRound(function(st)
		local inRound = st.Phase == "Round"
		local alive = table.find(st.AliveIds or {}, player.UserId) ~= nil
		openBtn.Visible = inRound and not alive and not spectating and #(st.AliveIds or {}) > 0
		if spectating then
			if not inRound then
				stop()
			else
				show()
			end
		end
	end)
end

return SpectateUI
