-- Lobby: construye el lobby (si tu juego no tiene ya uno llamado "Lobby" en el workspace).
-- Tiene: puntos de aparicion alrededor de una fuente, pantalla de estado, tienda, cofre diario,
-- clasificaciones, camas elasticas y un obby con recompensa al final.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(ServerStorage:WaitForChild("IslasMapas"):WaitForChild("Lib"):WaitForChild("Util"))
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)

local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors
local OpenUI = Net.Event("OpenUI")

local Lobby = {}

Lobby.Folder = nil
Lobby.Boards = {} -- { Title = TextLabel, Lines = TextLabel }
Lobby.StatusLabel = nil
Lobby.TimerLabel = nil

local function prompt(part, action, object, fn)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.Parent = part
	pp.Triggered:Connect(fn)
	return pp
end

local function screen(b, name, size, pos, face)
	local p = b:Box(name, size, pos, C(20, 22, 32), M.SmoothPlastic, { indestructible = true })
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = p
	return p, gui
end

local function boardGui(gui, title, accent)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0.16, 0)
	t.BackgroundColor3 = accent
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = C(30, 25, 10)
	t.Text = title
	t.Parent = gui
	local lines = Instance.new("TextLabel")
	lines.Size = UDim2.new(0.92, 0, 0.8, 0)
	lines.Position = UDim2.new(0.04, 0, 0.18, 0)
	lines.BackgroundTransparency = 1
	lines.Font = Enum.Font.GothamBold
	lines.TextScaled = true
	lines.TextXAlignment = Enum.TextXAlignment.Left
	lines.TextYAlignment = Enum.TextYAlignment.Top
	lines.TextColor3 = C(255, 255, 255)
	lines.Text = "Cargando..."
	lines.Parent = gui
	return { Title = t, Lines = lines }
end

local obbyCheckpoint = {} -- [player] = Vector3

function Lobby.ShouldBuild()
	if Config.BuildLobby == true then
		return true
	end
	if Config.BuildLobby == "auto" then
		return workspace:FindFirstChild("Lobby") == nil
	end
	return false
end

function Lobby.Build()
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	local O = Config.LobbyOrigin
	local b = Util.newBuilder(folder, O)

	-- isla
	b:Box("Isla", V(280, 10, 280), V(0, -5, 0), Colors.Grass, M.Grass, { indestructible = true })
	b:Box("Orilla", V(300, 6, 300), V(0, -8, 0), Colors.Sand, M.Sand, { indestructible = true })
	b:Box("Agua", V(1400, 1, 1400), V(0, -9, 0), Colors.Water, M.SmoothPlastic, { transparency = 0.2, canCollide = false, indestructible = true })
	b:KillPlane(-40, 2048)
	b:Pillar("Plaza", 0, 0, -0.4, 0.1, 90, C(205, 200, 190), M.Slate)

	-- fuente central y spawns alrededor
	b:Pillar("FuenteBase", 0, 0, 0, 1.6, 16, Colors.Concrete, M.Marble)
	b:Pillar("FuenteAgua", 0, 0, 1.6, 1.9, 13, Colors.Water, M.SmoothPlastic)
	b:Pillar("FuenteColumna", 0, 0, 1.9, 7, 2.4, Colors.Concrete, M.Marble)
	b:Ball("FuenteBola", 4, V(0, 8.5, 0), C(255, 200, 60), M.Neon)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local s = Instance.new("SpawnLocation")
		s.Name = "SpawnLobby"
		s.Anchored = true
		s.Neutral = true
		s.Duration = 0
		s.Size = V(6, 1, 6)
		s.Color = C(255, 196, 50)
		s.Material = M.Neon
		s.Transparency = 0.3
		s.TopSurface = Enum.SurfaceType.Smooth
		s.CFrame = CFrame.new(O + V(math.cos(a) * 20, 0.5, math.sin(a) * 20))
		s:SetAttribute("Indestructible", true)
		s.Parent = folder
	end

	-- titulo y pantalla de estado
	local title = b:Board("Titulo", "ISLAS DE DESASTRES", V(90, 14, 2), V(0, 34, -92), C(255, 196, 50), C(30, 25, 10))
	title:SetAttribute("Indestructible", true)
	b:Box("PosteTitulo", V(3, 27, 3), V(-40, 13.5, -92), Colors.DarkMetal, M.Metal, { indestructible = true })
	b:Box("PosteTitulo", V(3, 27, 3), V(40, 13.5, -92), Colors.DarkMetal, M.Metal, { indestructible = true })
	local _, statusGui = screen(b, "PantallaEstado", V(56, 16, 1), V(0, 17, -92))
	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, 0, 0.6, 0)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBlack
	status.TextScaled = true
	status.TextColor3 = C(255, 255, 255)
	status.Text = "Bienvenido"
	status.Parent = statusGui
	local timer = Instance.new("TextLabel")
	timer.Size = UDim2.new(1, 0, 0.4, 0)
	timer.Position = UDim2.new(0, 0, 0.6, 0)
	timer.BackgroundTransparency = 1
	timer.Font = Enum.Font.GothamBlack
	timer.TextScaled = true
	timer.TextColor3 = C(255, 196, 50)
	timer.Text = ""
	timer.Parent = statusGui
	Lobby.StatusLabel, Lobby.TimerLabel = status, timer

	-- clasificaciones
	local boardDefs = {
		{ "TOP VICTORIAS", C(255, 196, 50), -62 },
		{ "TOP NIVEL", C(120, 200, 255), 62 },
		{ "TOP MUNDIAL", C(255, 120, 200), 0 },
	}
	for i, def in ipairs(boardDefs) do
		local x, z, face = def[3], -70, Enum.NormalId.Back
		if i == 3 then
			-- la mundial, al otro lado de la plaza mirando hacia la fuente
			z, face = 85, Enum.NormalId.Front
		end
		local _, gui = screen(b, "Clasificacion", V(30, 34, 1), V(x, 19, z), face)
		b:Box("PieClasificacion", V(32, 2, 3), V(x, 1, z), Colors.DarkMetal, M.Metal, { indestructible = true })
		Lobby.Boards[i] = boardGui(gui, def[1], def[2])
	end

	-- tienda
	local shop = b:Group("Tienda")
	shop:Box("Mostrador", V(18, 4, 4), V(52, 2, -18), Colors.Wood, M.Wood, { indestructible = true })
	shop:Box("TechoTienda", V(22, 1, 12), V(52, 11, -22), Colors.Red, M.Fabric, { indestructible = true })
	for _, x in ipairs({ 42, 62 }) do
		shop:Box("PosteTienda", V(1, 11, 1), V(x, 5.5, -17), Colors.Wood, M.Wood, { indestructible = true })
	end
	local shopSign = shop:Board("CartelTienda", "🛒 TIENDA", V(18, 4, 0.6), V(52, 14, -16.8), C(255, 196, 50), C(30, 25, 10))
	shopSign:SetAttribute("Indestructible", true)
	local counter = shop:Box("ZonaTienda", V(18, 6, 2), V(52, 3, -15.5), C(0, 0, 0), M.SmoothPlastic, { transparency = 1, canCollide = false, indestructible = true })
	prompt(counter, "Abrir tienda", "Tienda", function(player)
		OpenUI:FireClient(player, "Shop")
	end)

	-- cofre diario
	local chest = b:Box("CofreDiario", V(6, 4, 4), V(-52, 2, -18), C(255, 196, 50), M.Neon, { indestructible = true })
	b:Box("TapaCofre", V(6.4, 1.2, 4.4), V(-52, 4.6, -18), C(160, 100, 40), M.Wood, { indestructible = true })
	b:Board("CartelCofre", "🎁 RECOMPENSA DIARIA", V(20, 3, 0.6), V(-52, 9, -16), C(120, 255, 160), C(20, 40, 20))
	Util.AddLight(chest, 18, 2, C(255, 220, 120))
	prompt(chest, "Reclamar", "Recompensa diaria", function(player)
		OpenUI:FireClient(player, "Daily")
	end)

	-- camas elasticas
	for i, p in ipairs({ { -30, 40 }, { 0, 50 }, { 30, 40 } }) do
		local pad = b:Box("CamaElastica", V(10, 1, 10), V(p[1], 0.6, p[2]), C(80 + i * 40, 120, 255), M.Neon, { touch = true, indestructible = true })
		local cooldown = {}
		pad.Touched:Connect(function(hit)
			local char = hit.Parent
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and (not cooldown[char] or os.clock() - cooldown[char] > 0.8) then
				cooldown[char] = os.clock()
				hrp.AssemblyLinearVelocity = V(hrp.AssemblyLinearVelocity.X, 120, hrp.AssemblyLinearVelocity.Z)
			end
		end)
	end

	-- obby: plataformas que suben hasta un trofeo
	local obby = b:Group("Obby")
	local start = V(95, 0, 60)
	obby:Board("CartelObby", "OBBY → premio al final", V(16, 3, 0.6), V(start.X, 6, start.Z - 8), C(255, 120, 60), C(255, 255, 255))
	local positions = {}
	local pos = start
	for i = 1, 18 do
		local dir = (math.floor((i - 1) / 6) % 2 == 0) and V(0, 0, 9) or V(0, 0, -9)
		if i % 6 == 0 then
			dir = V(-10, 0, 0)
		end
		pos = pos + dir + V(0, 2.2, 0)
		positions[i] = pos
		local size = (i % 4 == 0) and V(3, 1, 3) or V(5, 1, 5)
		local color = Color3.fromHSV((i / 18) % 1, 0.7, 1)
		local plat = obby:Box("Plataforma" .. i, size, pos, color, M.SmoothPlastic, { indestructible = true, touch = i % 6 == 0 })
		if i % 6 == 0 then
			-- punto de control
			plat.Material = M.Neon
			plat.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player then
					obbyCheckpoint[player] = plat.Position + V(0, 3, 0)
				end
			end)
		end
	end
	local finalPos = positions[#positions] + V(-10, 2, 0)
	local finish = obby:Box("Meta", V(10, 1, 10), finalPos, C(255, 196, 50), M.Neon, { indestructible = true, touch = true })
	obby:Ball("Trofeo", 4, finalPos + V(0, 4, 0), C(255, 210, 60), M.Neon)
	finish.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local data = player and PlayerData.Get(player)
		if data and os.time() - (data.LastObby or 0) >= 600 then
			data.LastObby = os.time()
			Rewards.Give(player, 30, 15, { noMultiplier = true, text = "¡Obby completado!" })
			Rewards.Stat(player, "ObbyCompleted", 1)
		end
	end)
	-- suelo bajo el obby: si caes vuelves al ultimo punto de control
	local fall = obby:Box("CaidaObby", V(40, 1, 80), V(start.X - 5, 0.6, start.Z + 20), C(255, 80, 80), M.Neon, { transparency = 0.7, canCollide = false, touch = true, indestructible = true })
	fall.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local cp = player and obbyCheckpoint[player]
		if cp and player.Character then
			player.Character:PivotTo(CFrame.new(cp))
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		obbyCheckpoint[p] = nil
	end)

	-- decoracion
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local r = 115
		b:Pine(math.cos(a) * r, math.sin(a) * r, 0, 1.4)
	end
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.3
		local x, z = math.cos(a) * 36, math.sin(a) * 36
		b:Pillar("Farola", x, z, 0, 9, 0.6, Colors.DarkMetal, M.Metal)
		local lamp = b:Ball("LuzFarola", 1.6, V(x, 9.6, z), C(255, 240, 200), M.Neon)
		Util.AddLight(lamp, 24, 1.2)
		b:Box("Banco", V(5, 1, 1.6), V(x * 0.85, 0.8, z * 0.85), Colors.Wood, M.Wood)
	end

	folder.Parent = workspace
	Lobby.Folder = folder
	return folder
end

function Lobby.SetStatus(text, timerText)
	if Lobby.StatusLabel then
		Lobby.StatusLabel.Text = text or ""
	end
	if Lobby.TimerLabel then
		Lobby.TimerLabel.Text = timerText or ""
	end
end

return Lobby
