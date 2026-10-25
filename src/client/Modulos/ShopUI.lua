-- ShopUI: tienda con pestanas (Gears, Estelas, Mejoras). Comprar y equipar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))

local ShopUI = {}
local C = Color3.fromRGB

local TABS = {
	{ Kind = "Gear", Title = "GEARS" },
	{ Kind = "Trail", Title = "ESTELAS" },
	{ Kind = "Upgrade", Title = "MEJORAS" },
}

function ShopUI.Init(modules)
	local UI, State, Popups, SoundFX = modules.UI, modules.State, modules.Popups, modules.SoundFX
	local T = UI.Theme
	local gui = UI.Gui("TiendaGui", 10)
	local win = UI.Window(gui, "🛒 TIENDA", UDim2.new(0.7, 0, 0.75, 0), C(255, 160, 40))
	local content = win.Content

	local header = UI.New("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = content })
	UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = header })
	local coinsLabel = UI.Label(content, { Text = "", Font = T.Black, TextSize = 22, TextColor3 = T.Accent, Size = UDim2.new(0, 200, 0, 40), Position = UDim2.new(1, -200, 0, 0), TextXAlignment = Enum.TextXAlignment.Right })
	local slotsLabel = UI.Label(content, { Text = "", Font = T.Body, TextSize = 14, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 42), TextXAlignment = Enum.TextXAlignment.Left })

	local list = UI.New("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -70),
		Position = UDim2.new(0, 0, 0, 66),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = content,
	})
	UI.New("UIGridLayout", { CellSize = UDim2.new(0, 190, 0, 210), CellPadding = UDim2.new(0, 10, 0, 10), Parent = list })

	local currentKind = "Gear"
	local tabButtons = {}

	local function request(action, id)
		local ok, a, b = pcall(function()
			return Net.Function("ShopRequest"):InvokeServer(action, id)
		end)
		local success, msg = ok and a, ok and b or "Error de conexion"
		Popups.Toast(msg or "", success and T.Good or T.Bad)
		if not success then
			SoundFX.Play("Hit", 0.5)
		end
	end

	local function render()
		local data = State.Data
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if not data then
			return
		end
		coinsLabel.Text = "🪙 " .. Format.Number(data.Coins)
		slotsLabel.Text = currentKind == "Gear" and ("Puedes llevar " .. (data.GearSlots or 1) .. " gear(s) a la vez en las rondas. Pulsa EQUIPAR para elegir.") or ""
		for k, b in pairs(tabButtons) do
			b.BackgroundColor3 = k == currentKind and T.Accent or T.Panel2
			b.TextColor3 = k == currentKind and C(30, 25, 10) or T.Text
		end
		for _, item in ipairs(Catalog.Items) do
			if item.Kind == currentKind then
				local owned = data.Owned and data.Owned[item.Id]
				local equipped = false
				if item.Kind == "Gear" then
					equipped = table.find(data.Equipped.Gears or {}, item.Id) ~= nil
				elseif item.Kind == "Trail" then
					equipped = data.Equipped.Trail == item.Id
				end
				local card = UI.Panel(list, { BackgroundColor3 = equipped and C(40, 80, 55) or T.Panel })
				UI.Stroke(card, equipped and T.Good or (owned and T.Info or T.Panel3), 2)
				UI.Label(card, { Text = item.Icon or "?", TextSize = 46, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0, 6) })
				UI.Label(card, { Text = item.Name, Font = T.Black, TextSize = 17, TextWrapped = true, Size = UDim2.new(1, -10, 0, 22), Position = UDim2.new(0, 5, 0, 66) })
				UI.Label(card, { Text = item.Desc or "Estela cosmetica que te sigue al correr.", Font = T.Body, TextSize = 12, TextWrapped = true, TextColor3 = T.Muted, Size = UDim2.new(1, -14, 0, 64), Position = UDim2.new(0, 7, 0, 90), TextYAlignment = Enum.TextYAlignment.Top })
				local text, color, action
				if not owned then
					local affordable = data.Coins >= item.Price
					text = "🪙 " .. Format.Number(item.Price)
					color = affordable and T.Accent or C(90, 90, 100)
					action = "buy"
				elseif item.Kind == "Upgrade" then
					text, color = "✔ COMPRADO", T.Good
				else
					text = equipped and "QUITAR" or "EQUIPAR"
					color = equipped and T.Bad or T.Info
					action = "equip"
				end
				local btn = UI.Button(card, text, { Size = UDim2.new(1, -20, 0, 36), Position = UDim2.new(0, 10, 1, -44), BackgroundColor3 = color, TextSize = 16 }, function()
					if action then
						request(action, item.Id)
					end
				end)
				if not action then
					btn.Active = false
				end
			end
		end
	end

	for _, tab in ipairs(TABS) do
		tabButtons[tab.Kind] = UI.Button(header, tab.Title, { Size = UDim2.new(0, 120, 1, 0), BackgroundColor3 = T.Panel2, TextColor3 = T.Text, TextSize = 16 }, function()
			currentKind = tab.Kind
			render()
		end)
	end

	State.OnData(function()
		if win.IsOpen() then
			render()
		end
	end)
	win.OnOpen = render

	Net.Event("OpenUI").OnClientEvent:Connect(function(what)
		if what == "Shop" then
			win.Open()
		end
	end)

	ShopUI.Toggle = win.Toggle
	ShopUI.Open = win.Open
end

return ShopUI
