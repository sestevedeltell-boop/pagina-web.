-- Popups: numeros de monedas/XP que saltan, avisos (logros, subida de nivel) y lista de muertes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local Popups = {}
local UI, SoundFX
local gui, toastList, feed, bigText
local C = Color3.fromRGB

-- "+5" flotando en el mundo donde se recogio la moneda
local function worldPopup(amount, position)
	local att = Instance.new("Attachment")
	att.WorldPosition = position
	att.Parent = workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 120, 0, 40)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Adornee = att
	bb.Parent = att
	local label = UI.Label(bb, {
		Text = "+" .. amount,
		Font = UI.Theme.Black,
		TextSize = 30,
		TextColor3 = amount >= 25 and C(255, 120, 220) or UI.Theme.Accent,
		Size = UDim2.fromScale(1, 1),
	})
	UI.TextStroke(label, 2)
	UI.Tween(bb, 1, { StudsOffset = Vector3.new(0, 5, 0) })
	UI.Tween(label, 1, { TextTransparency = 1 })
	task.delay(1.1, function()
		att:Destroy()
	end)
end

-- Fundido a blanco (al teletransportar)
local fadeFrame
function Popups.Fade()
	if not fadeFrame then
		return
	end
	fadeFrame.BackgroundTransparency = 0
	UI.Tween(fadeFrame, 0.7, { BackgroundTransparency = 1 })
end

-- "+5 🪙" que sale cerca del contador de monedas y sube
function Popups.Coin(amount, xp, text, position)
	if typeof(position) == "Vector3" and amount > 0 then
		worldPopup(amount, position)
	end
	local T = UI.Theme
	local label = UI.Label(gui, {
		Text = (amount > 0 and ("+" .. amount .. " 🪙") or "") .. (xp and xp > 0 and ("  +" .. xp .. " XP") or ""),
		Font = T.Black,
		TextSize = amount >= 25 and 34 or 26,
		TextColor3 = amount >= 25 and C(255, 120, 220) or T.Accent,
		Size = UDim2.new(0, 320, 0, 40),
		Position = UDim2.new(0, 210 + math.random(-20, 20), 0, 70),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	UI.TextStroke(label, 2.5)
	if text then
		local sub = UI.Label(label, {
			Text = text,
			Font = T.Font,
			TextSize = 16,
			TextColor3 = T.Text,
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.new(0, 0, 1, -4),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		UI.TextStroke(sub, 1.5)
	end
	UI.Pop(label, 0.4)
	UI.Tween(label, 1.6, { Position = label.Position - UDim2.new(0, 0, 0, 50), TextTransparency = 1 })
	task.delay(1.7, function()
		label:Destroy()
	end)
end

-- Aviso en el lateral (logros, compras, informacion)
function Popups.Toast(text, color, title)
	local T = UI.Theme
	local frame = UI.Panel(toastList, {
		Size = UDim2.new(1, 0, 0, title and 64 or 44),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.05,
	})
	UI.Stroke(frame, color or T.Accent, 2)
	if title then
		UI.Label(frame, { Text = title, Font = T.Black, TextSize = 18, TextColor3 = color or T.Accent, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0, 8, 0, 4), TextXAlignment = Enum.TextXAlignment.Left })
	end
	UI.Label(frame, {
		Text = text,
		Font = T.Body,
		TextSize = 15,
		TextWrapped = true,
		Size = UDim2.new(1, -16, 0, title and 30 or 40),
		Position = UDim2.new(0, 8, 0, title and 30 or 2),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	UI.Pop(frame, 0.1)
	task.delay(5, function()
		UI.Tween(frame, 0.4, { BackgroundTransparency = 1 })
		task.wait(0.4)
		frame:Destroy()
	end)
end

-- Texto enorme en el centro (subida de nivel, sobreviviste...)
function Popups.Big(text, color, seconds)
	bigText.Text = text
	bigText.TextColor3 = color or UI.Theme.Accent
	bigText.Visible = true
	bigText.TextTransparency = 0
	UI.Pop(bigText, 0.5)
	task.delay(seconds or 2, function()
		if bigText.Text == text then
			UI.Tween(bigText, 0.5, { TextTransparency = 1 })
		end
	end)
end

function Popups.Kill(name, cause)
	local T = UI.Theme
	local row = UI.Panel(feed, { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C(40, 10, 10), BackgroundTransparency = 0.3 })
	UI.Label(row, {
		Text = "💀 " .. name .. "  ·  " .. cause,
		Font = T.Font,
		TextSize = 15,
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	task.delay(7, function()
		row:Destroy()
	end)
end

function Popups.Init(modules)
	UI, SoundFX = modules.UI, modules.SoundFX
	gui = UI.Gui("AvisosGui", 8)
	toastList = UI.New("Frame", {
		Size = UDim2.new(0, 300, 0.6, 0),
		Position = UDim2.new(1, -310, 0.25, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.New("UIListLayout", { Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = toastList })
	feed = UI.New("Frame", {
		Size = UDim2.new(0, 280, 0, 200),
		Position = UDim2.new(1, -290, 0, 60),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.New("UIListLayout", { Padding = UDim.new(0, 4), Parent = feed })
	bigText = UI.Label(gui, {
		Font = UI.Theme.Black,
		TextSize = 64,
		Size = UDim2.new(1, 0, 0, 90),
		Position = UDim2.new(0, 0, 0.32, 0),
		Visible = false,
	})
	UI.TextStroke(bigText, 4)
	local fadeGui = UI.Gui("FundidoGui", 20, true)
	fadeFrame = UI.New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, Parent = fadeGui })

	Net.Event("Popup").OnClientEvent:Connect(function(p)
		if typeof(p) == "table" then
			Popups.Coin(p.Coins or 0, p.XP, p.Text, p.Position)
		end
	end)
	Net.Event("Toast").OnClientEvent:Connect(function(t)
		if typeof(t) ~= "table" then
			return
		end
		if t.Kind == "LevelUp" then
			Popups.Big(t.Title, C(120, 220, 255), 2.5)
			Popups.Toast(t.Text, C(120, 220, 255), t.Title)
		elseif t.Kind == "Achievement" then
			Popups.Toast(t.Text, C(255, 196, 50), t.Title)
		else
			Popups.Toast(t.Text or "", t.Color, t.Title)
		end
	end)
	Net.Event("KillFeed").OnClientEvent:Connect(function(k)
		if typeof(k) == "table" then
			Popups.Kill(k.Name or "?", k.Cause or "?")
			if k.UserId == Players.LocalPlayer.UserId then
				Popups.Big("HAS MUERTO", C(255, 80, 80), 2)
			end
		end
	end)
end

return Popups
