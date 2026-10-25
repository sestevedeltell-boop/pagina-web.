-- UI: utilidades para construir la interfaz por codigo con un estilo comun.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local C = Color3.fromRGB

local UI = {}

UI.Theme = {
	Bg = C(14, 16, 26),
	Panel = C(26, 29, 44),
	Panel2 = C(38, 42, 62),
	Panel3 = C(52, 57, 82),
	Accent = C(255, 196, 50),
	Accent2 = C(255, 120, 40),
	Good = C(80, 220, 120),
	Bad = C(255, 80, 80),
	Info = C(80, 170, 255),
	Text = C(255, 255, 255),
	Muted = C(170, 178, 200),
	Font = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
	Black = Enum.Font.GothamBlack,
}
local T = UI.Theme

local clickSound

function UI.New(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.Corner(inst, radius)
	return UI.New("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = inst })
end

function UI.Stroke(inst, color, thickness, transparency)
	return UI.New("UIStroke", {
		Color = color or C(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

function UI.TextStroke(inst, thickness)
	return UI.New("UIStroke", { Color = C(0, 0, 0), Thickness = thickness or 2, Transparency = 0.3, Parent = inst })
end

function UI.Padding(inst, px)
	return UI.New("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = inst,
	})
end

function UI.Gradient(inst, c1, c2, rotation)
	return UI.New("UIGradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(1, c2) }),
		Rotation = rotation or 90,
		Parent = inst,
	})
end

function UI.Tween(inst, seconds, goal, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

-- ScreenGui en PlayerGui
function UI.Gui(name, order, ignoreInset)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = order or 1
	gui.IgnoreGuiInset = ignoreInset == true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function UI.Label(parent, props)
	local p = {
		BackgroundTransparency = 1,
		Font = T.Font,
		TextColor3 = T.Text,
		TextSize = 18,
		Text = "",
		Size = UDim2.new(1, 0, 0, 24),
		Parent = parent,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return UI.New("TextLabel", p)
end

function UI.Panel(parent, props)
	local p = { BackgroundColor3 = T.Panel, BorderSizePixel = 0, Parent = parent }
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	local f = UI.New("Frame", p)
	UI.Corner(f, 12)
	return f
end

-- Rebote rapido (se usa al ganar monedas, abrir ventanas...)
function UI.Pop(inst, amount)
	local scale = inst:FindFirstChildOfClass("UIScale") or UI.New("UIScale", { Parent = inst })
	scale.Scale = 1 + (amount or 0.15)
	UI.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

function UI.PlayClick()
	if not clickSound then
		local ok, Sounds = pcall(function()
			return require(game:GetService("ReplicatedStorage"):WaitForChild("IslasShared"):WaitForChild("Sounds"))
		end)
		clickSound = Instance.new("Sound")
		clickSound.Volume = 0.35
		clickSound.SoundId = ok and Sounds.Click or ""
		clickSound.Parent = game:GetService("SoundService")
	end
	clickSound:Play()
end

-- Boton con animacion al pasar el raton y al pulsar
function UI.Button(parent, text, props, onClick)
	local p = {
		BackgroundColor3 = T.Accent,
		AutoButtonColor = false,
		Font = T.Black,
		TextColor3 = C(30, 25, 10),
		TextSize = 18,
		Text = text,
		Size = UDim2.new(0, 140, 0, 40),
		Parent = parent,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	local b = UI.New("TextButton", p)
	UI.Corner(b, 10)
	local scale = UI.New("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		UI.Tween(scale, 0.12, { Scale = 1.05 })
	end)
	b.MouseLeave:Connect(function()
		UI.Tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		UI.Tween(scale, 0.08, { Scale = 0.95 })
	end)
	b.Activated:Connect(function()
		UI.Tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
		UI.PlayClick()
		if onClick then
			onClick()
		end
	end)
	return b
end

-- Ventana modal con titulo y boton de cerrar. Devuelve window, content
local openWindows = {}
function UI.Window(gui, title, size, accent)
	local win = UI.Panel(gui, {
		Name = "Ventana_" .. title,
		Size = size or UDim2.new(0, 560, 0, 420),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.05,
		Visible = false,
	})
	UI.Stroke(win, accent or T.Accent, 3)
	UI.New("UISizeConstraint", { MaxSize = Vector2.new(900, 700), Parent = win })
	local bar = UI.New("Frame", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = accent or T.Accent,
		BorderSizePixel = 0,
		Parent = win,
	})
	UI.Corner(bar, 12)
	local titleLabel = UI.Label(bar, {
		Text = title,
		Font = T.Black,
		TextSize = 24,
		TextColor3 = C(30, 25, 10),
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = UI.Button(bar, "X", {
		Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(1, -42, 0, 6),
		BackgroundColor3 = T.Bad,
		TextColor3 = T.Text,
	})
	local content = UI.New("Frame", {
		Name = "Contenido",
		Size = UDim2.new(1, -24, 1, -64),
		Position = UDim2.new(0, 12, 0, 56),
		BackgroundTransparency = 1,
		Parent = win,
	})
	local api = {}
	function api.Open()
		for _, w in ipairs(openWindows) do
			if w ~= api then
				w.Close()
			end
		end
		win.Visible = true
		UI.Pop(win, 0.08)
		if api.OnOpen then
			api.OnOpen()
		end
	end
	function api.Close()
		win.Visible = false
	end
	function api.Toggle()
		if win.Visible then
			api.Close()
		else
			api.Open()
		end
	end
	function api.IsOpen()
		return win.Visible
	end
	close.Activated:Connect(api.Close)
	api.Frame, api.Content, api.Title = win, content, titleLabel
	openWindows[#openWindows + 1] = api
	return api
end

function UI.IsMobile()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

return UI
