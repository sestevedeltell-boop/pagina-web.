-- INSTALADOR de Islas de Desastres.
-- Crea (o reemplaza) estas carpetas: ReplicatedStorage.IslasShared, ServerStorage.IslasMapas,
-- ServerScriptService.IslasServer y StarterPlayer.StarterPlayerScripts.IslasClient.
-- No toca nada mas de tu juego.
-- PARTE 4 DE 5. Pega las partes en la Barra de comandos EN ORDEN (1, 2, 3...).

local services = {
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerStorage = game:GetService("ServerStorage"),
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"),
}

local function folderAt(service, path)
	local parent = services[service]
	for _, name in ipairs(path) do
		local f = parent:FindFirstChild(name)
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = parent
		end
		parent = f
	end
	return parent
end

local function add(service, path, name, className, source)
	local parent = folderAt(service, path)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Source = source
	inst.Parent = parent
end

add("ServerScriptService", { "IslasServer" }, "Hazards", "ModuleScript", [[
-- Hazards: piezas comunes de los desastres.
--   Hazards.Strike(ctx, x, z, opts)   impacto avisado (meteorito, rayo, bomba de lava, laser)
--   Hazards.Zones(ctx, opts)          zonas que aparecen y crecen (fuego, radiacion, lava)
--   Hazards.Liquid(ctx, opts)         liquido que sube (inundacion, lava)
-- Todo lo visual se dibuja en los clientes (ctx.fx); aqui solo se calcula el dano.
local Hazards = {}

local function push(entry, velocity)
	entry.root.AssemblyLinearVelocity = velocity
end
Hazards.Push = push

-- opts: kind ("meteor", "bolt", "bomb", "laser"), radius, damage, warn (s), fall (s), from (Vector3 opcional),
--       partDamage, fling, ignite (prob), color, size
function Hazards.Strike(ctx, x, z, opts)
	opts = opts or {}
	local radius = opts.radius or 12
	local y = ctx.groundY(x, z) or ctx.bounds.floor
	local target = Vector3.new(x, y, z)
	local warn = opts.warn or 1.5
	local kind = opts.kind or "meteor"
	local color = opts.color or Color3.fromRGB(255, 70, 40)
	ctx.fx("marker", target, radius, color, warn)
	if kind == "meteor" or kind == "bomb" then
		local from = opts.from or (target + Vector3.new(math.random(-70, 70), ctx.bounds.top - y + 140, math.random(-70, 70)))
		ctx.fx("meteor", from, target, warn, opts.color or Color3.fromRGB(255, 120, 30), opts.size or 7)
	end
	task.delay(warn, function()
		if ctx.stopped then
			return
		end
		if kind == "bolt" or kind == "laser" then
			local from = opts.from or (target + Vector3.new(0, ctx.bounds.top - y + 160, 0))
			ctx.fx("bolt", from, target, kind == "laser" and Color3.fromRGB(80, 255, 140) or Color3.fromRGB(230, 240, 255))
		end
		ctx.fx("explosion", target, radius, color)
		for _, entry in ipairs(ctx.players()) do
			local off = entry.root.Position - target
			local d = off.Magnitude
			if d <= radius then
				ctx.damage(entry, (opts.damage or 60) * (1 - 0.6 * d / radius))
				if d > 0.5 and (opts.knockback or 50) > 0 then
					push(entry, off.Unit * (opts.knockback or 50) + Vector3.new(0, 35, 0))
				end
			end
		end
		if opts.partDamage ~= 0 then
			ctx.D.DamageSphere(target + Vector3.new(0, 2, 0), radius * 1.1, opts.partDamage or 200, { fling = opts.fling or 55 })
		end
		if opts.ignite and math.random() < opts.ignite then
			ctx.D.IgniteSphere(target, radius, 0.5)
		end
	end)
end

-- opts: color, fire, dps, startRadius, maxRadius, growth, interval, maxZones, ignite (bool), partDamage (por s)
function Hazards.Zones(ctx, opts)
	local zones = {}
	local lastSpawn = -math.huge
	local lastSync = 0
	local dt = 0.25
	local cfg = ctx.config
	local maxZones = math.floor((cfg.maxZones or opts.maxZones) * math.min(ctx.intensity, 1.6))
	local interval = ctx.rate(cfg.interval or opts.interval)
	local key = 0

	local function addZone()
		local x, z
		if opts.center then
			local a = math.random() * math.pi * 2
			local r = math.random() * (opts.spread or 30)
			x, z = opts.center.X + math.cos(a) * r, opts.center.Z + math.sin(a) * r
		else
			x, z = ctx.targetPoint(0.5, 30)
		end
		local y = ctx.groundY(x, z) or ctx.bounds.floor
		key = key + 1
		local zone = { key = key, pos = Vector3.new(x, y, z), radius = opts.startRadius }
		zones[#zones + 1] = zone
		ctx.fx("zone", key, zone.pos, zone.radius, opts.color, opts.fire == true)
	end

	while ctx.active() do
		local now = ctx.time()
		if #zones < maxZones and now - lastSpawn >= interval then
			lastSpawn = now
			addZone()
		end
		for _, z in ipairs(zones) do
			z.radius = math.min(opts.maxRadius, z.radius + opts.growth * ctx.intensity * dt)
		end
		if now - lastSync >= 1 then
			lastSync = now
			for _, z in ipairs(zones) do
				ctx.fx("zone", z.key, z.pos, z.radius, opts.color, opts.fire == true)
				if opts.ignite then
					ctx.D.IgniteSphere(z.pos, z.radius * 0.7, 0.35)
				end
				if opts.partDamage then
					ctx.D.DamageSphere(z.pos, z.radius * 0.8, opts.partDamage, { fling = 10, maxParts = 25 })
				end
			end
		end
		for _, entry in ipairs(ctx.players()) do
			local pos = entry.root.Position
			for _, z in ipairs(zones) do
				if (pos - z.pos).Magnitude <= z.radius then
					ctx.damage(entry, opts.dps * dt)
					break
				end
			end
		end
		task.wait(dt)
	end
end

-- opts: color, material (nombre), transparency, maxHeight, lethal, dps, melt (dano a piezas por s), rise (s)
function Hazards.Liquid(ctx, opts)
	local b = ctx.bounds
	local pad = 160
	local cx, cz = (b.x1 + b.x2) / 2, (b.z1 + b.z2) / 2
	local sx = math.min(2048, (b.x2 - b.x1) + pad * 2)
	local sz = math.min(2048, (b.z2 - b.z1) + pad * 2)
	local maxHeight = (ctx.config.maxHeight or opts.maxHeight)
	local y0 = b.floor - 2
	local y1 = b.floor + maxHeight
	local t0 = ctx.time()
	local rise = (opts.rise or ctx.duration * 0.85) / math.min(ctx.intensity, 1.5)
	ctx.fx("liquid", {
		cx = cx, cz = cz, sx = sx, sz = sz, y0 = y0, y1 = y1, t0 = t0, rise = rise,
		color = opts.color, material = opts.material or "SmoothPlastic", transparency = opts.transparency or 0.3,
	})
	local dt = 0.2
	local meltAcc = 0
	while ctx.active() do
		local level = ctx.Paths.Level(y0, y1, t0, rise, ctx.time())
		for _, entry in ipairs(ctx.players()) do
			if entry.root.Position.Y - 2.5 < level then
				if opts.lethal then
					ctx.kill(entry)
				else
					ctx.damage(entry, opts.dps * dt)
				end
			end
		end
		meltAcc = meltAcc + dt
		if opts.melt and meltAcc >= 1 then
			meltAcc = 0
			ctx.D.DamageBox(CFrame.new(cx, level - 1, cz), Vector3.new(sx, 3, sz), opts.melt, { maxParts = 60, shatter = true })
		end
		task.wait(dt)
	end
end

return Hazards
]])

add("ServerScriptService", { "IslasServer" }, "Leaderboards", "ModuleScript", [[
-- Leaderboards: rellena las pantallas de clasificacion del lobby (servidor y mundial).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Levels = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Levels"))
local PlayerData = require(script.Parent.PlayerData)
local Lobby = require(script.Parent.Lobby)

local Leaderboards = {}

local function lines(list, fmt)
	local out = {}
	for i, e in ipairs(list) do
		if i > 10 then
			break
		end
		local medal = (i == 1 and "🥇") or (i == 2 and "🥈") or (i == 3 and "🥉") or (i .. ".")
		out[#out + 1] = medal .. " " .. e.name .. "  " .. fmt(e)
	end
	if #out == 0 then
		return "Todavia nadie..."
	end
	return table.concat(out, "\n")
end

function Leaderboards.UpdateServer()
	local wins, levels = {}, {}
	for _, p in ipairs(Players:GetPlayers()) do
		local data = PlayerData.Get(p)
		if data then
			local level = Levels.FromTotal(data.XP)
			wins[#wins + 1] = { name = p.DisplayName, value = data.Stats.Wins }
			levels[#levels + 1] = { name = p.DisplayName, value = level }
		end
	end
	table.sort(wins, function(a, b)
		return a.value > b.value
	end)
	table.sort(levels, function(a, b)
		return a.value > b.value
	end)
	local boards = Lobby.Boards
	if boards[1] then
		boards[1].Lines.Text = lines(wins, function(e)
			return e.value .. " 🏆"
		end)
	end
	if boards[2] then
		boards[2].Lines.Text = lines(levels, function(e)
			return "Nv " .. e.value
		end)
	end
end

local nameCache = {}
local function nameOf(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or ("Jugador " .. userId)
	return nameCache[userId]
end

function Leaderboards.UpdateGlobal()
	local store = PlayerData.GetOrderedStore()
	local board = Lobby.Boards[3]
	if not store or not board then
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, 10):GetCurrentPage()
	end)
	if not ok then
		board.Lines.Text = "No disponible"
		return
	end
	local list = {}
	for _, entry in ipairs(page) do
		local id = tonumber(tostring(entry.key):match("%d+"))
		list[#list + 1] = { name = id and nameOf(id) or tostring(entry.key), value = entry.value }
	end
	board.Lines.Text = lines(list, function(e)
		return e.value .. " 🏆"
	end)
end

function Leaderboards.Init()
	task.spawn(function()
		local tick = 0
		while true do
			Leaderboards.UpdateServer()
			if tick % 4 == 0 then
				task.spawn(Leaderboards.UpdateGlobal)
			end
			tick = tick + 1
			task.wait(30)
		end
	end)
end

return Leaderboards
]])

add("ServerScriptService", { "IslasServer" }, "Lobby", "ModuleScript", [[
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
]])

add("ServerScriptService", { "IslasServer" }, "Main", "Script", [[
-- Main: punto de entrada del servidor. Arranca todos los sistemas en orden.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
require(Shared:WaitForChild("Net")) -- crea los RemoteEvents

local S = script.Parent
require(S.CollisionGroups).Setup()
require(S.PlayerData).Init()
require(S.Rewards).Init()
require(S.Gear).Init()
require(S.ShopService).Init()
require(S.CoinDrops).Init()

local Lobby = require(S.Lobby)
local MapService = require(S.MapService)
if Lobby.ShouldBuild() then
	-- mientras se construye el lobby no aparecen personajes (si no, caerian al vacio)
	local autoLoads = Players.CharacterAutoLoads
	Players.CharacterAutoLoads = false
	Lobby.Build()
	Players.CharacterAutoLoads = autoLoads
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			MapService.ReturnToLobby({ player })
		elseif autoLoads then
			task.spawn(function()
				player:LoadCharacter()
			end)
		end
	end
end
require(S.Leaderboards).Init()
require(S.AdminCommands).Init()

if Config.RunDefaultLoop then
	task.spawn(require(S.GameLoop).Run)
end
]])

add("ServerScriptService", { "IslasServer" }, "MapService", "ModuleScript", [[
-- MapService: construye un mapa SOLO cuando se necesita, teletransporta jugadores y lo borra despues.
-- Mientras un mapa no se ha votado no existe en el workspace, asi que no consume nada.
--
-- Mapas disponibles:
--   * Los generados por codigo en ServerStorage.IslasMapas.Builders
--   * Tus propios modelos: mete un Model en ServerStorage.IslasMapasPropios y aparece en la votacion.
--     Atributos opcionales del modelo: Title (texto), Description (texto), Disasters ("Earthquake,Fire,...").
--     Las piezas llamadas "Spawn"/"SpawnPoint" (o SpawnLocation) son los puntos de aparicion.
--
-- API:
--   MapService.GetMapNames()            -> lista de nombres de mapas disponibles
--   MapService.GetInfo(name)            -> { Name, Title, Description, Disasters }
--   MapService.Load(name)               -> construye el mapa (bloquea hasta terminar)
--   MapService.GetCurrent()             -> { Name, Folder, Spawns, Def, Bounds } o nil
--   MapService.TeleportToMap(players)   -> manda jugadores a los spawns del mapa cargado
--   MapService.ReturnToLobby(players)   -> los devuelve al lobby
--   MapService.Unload()                 -> borra el mapa (poco a poco, sin tirones) y restaura la luz

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Config"))
local MapsRoot = ServerStorage:WaitForChild("IslasMapas")
local Util = require(MapsRoot:WaitForChild("Lib"):WaitForChild("Util"))
local Builders = MapsRoot:WaitForChild("Builders")
local Destruction = require(script.Parent.Destruction)

Util.ChunkSize = Config.ChunkSize
Util.BuildBudget = Config.BuildBudgetMs / 1000

local MapService = {}

local current = nil
local savedLighting = nil
local savedGravity = nil
local lobbySpawns = nil

local LIGHT_PROPS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "FogColor", "FogStart", "FogEnd" }
local ALL_DISASTERS = { "Earthquake", "Fire", "Meteors", "Flood", "Lightning", "Tornado", "AcidRain", "Tsunami", "Volcano", "BlackHole", "UFO", "Virus" }

local function customFolder()
	return ServerStorage:FindFirstChild("IslasMapasPropios")
end

local function customDef(model)
	local disasters = ALL_DISASTERS
	local attr = model:GetAttribute("Disasters")
	if typeof(attr) == "string" and #attr > 0 then
		disasters = {}
		for _, d in ipairs(string.split(attr, ",")) do
			d = d:gsub("^%s+", ""):gsub("%s+$", "")
			if #d > 0 then
				disasters[#disasters + 1] = d
			end
		end
	end
	local _, size = model:GetBoundingBox()
	local hx, hz = size.X / 2 + 10, size.Z / 2 + 10
	return {
		Title = model:GetAttribute("Title") or model.Name,
		Description = model:GetAttribute("Description") or "Mapa personalizado.",
		Disasters = disasters,
		Bounds = { x1 = -hx, x2 = hx, z1 = -hz, z2 = hz, top = size.Y + 40, floor = 0 },
		Custom = model,
	}
end

local function getDef(name)
	local module = Builders:FindFirstChild(name)
	if module then
		return require(module)
	end
	local cf = customFolder()
	local model = cf and cf:FindFirstChild(name)
	if model then
		return customDef(model)
	end
	error("MapService: no existe el mapa '" .. tostring(name) .. "'")
end
MapService.GetDef = getDef

function MapService.GetMapNames()
	local names = {}
	for _, child in ipairs(Builders:GetChildren()) do
		if child:IsA("ModuleScript") then
			names[#names + 1] = child.Name
		end
	end
	local cf = customFolder()
	if cf then
		for _, child in ipairs(cf:GetChildren()) do
			if (child:IsA("Model") or child:IsA("Folder")) and not table.find(names, child.Name) then
				names[#names + 1] = child.Name
			end
		end
	end
	table.sort(names)
	return names
end

function MapService.GetInfo(name)
	local def = getDef(name)
	return {
		Name = name,
		Title = def.Title or name,
		Description = def.Description or "",
		Disasters = def.Disasters or {},
	}
end

local function applyLighting(settings)
	if not settings then
		return
	end
	if not savedLighting then
		savedLighting = {}
		for _, prop in ipairs(LIGHT_PROPS) do
			savedLighting[prop] = Lighting[prop]
		end
	end
	for prop, value in pairs(settings) do
		Lighting[prop] = value
	end
end

local function restoreLighting()
	if savedLighting then
		for prop, value in pairs(savedLighting) do
			Lighting[prop] = value
		end
		savedLighting = nil
	end
end

-- Borra un arbol de instancias poco a poco para no dar tirones
local function destroyGradually(folder)
	folder.Name = "MapaBorrandose"
	task.spawn(function()
		local budget = 0.004
		local start = os.clock()
		local function clear(inst)
			for _, child in ipairs(inst:GetChildren()) do
				if #child:GetChildren() > 40 then
					clear(child)
				end
				child:Destroy()
				if os.clock() - start > budget then
					task.wait()
					start = os.clock()
				end
			end
		end
		clear(folder)
		folder:Destroy()
	end)
end

function MapService.Unload()
	Destruction.Reset()
	if current then
		destroyGradually(current.Folder)
		current = nil
	end
	restoreLighting()
	if savedGravity then
		workspace.Gravity = savedGravity
		savedGravity = nil
	end
end

-- Coloca un modelo propio en el origen del mapa y saca sus puntos de aparicion
local function placeCustom(def, folder, origin)
	local clone = def.Custom:Clone()
	local cf, size = clone:GetBoundingBox()
	local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Position = d.Position - bottom + origin
		end
	end
	clone.Parent = folder
	local spawns = {}
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("SpawnLocation") then
			d.Enabled = false
			spawns[#spawns + 1] = d
		elseif d:IsA("BasePart") and (d.Name == "Spawn" or d.Name == "SpawnPoint") then
			d.Transparency = 1
			d.CanCollide = false
			spawns[#spawns + 1] = d
		end
	end
	for _, s in ipairs(spawns) do
		s:SetAttribute("Indestructible", true)
	end
	if #spawns == 0 then
		-- sin spawns: buscar suelo en una rejilla sobre el modelo
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { clone }
		for ix = -1, 1 do
			for iz = -1, 1 do
				local p = origin + Vector3.new(ix * size.X * 0.3, size.Y + 20, iz * size.Z * 0.3)
				local hit = workspace:Raycast(p, Vector3.new(0, -(size.Y + 60), 0), params)
				if hit then
					local marker = Instance.new("Part")
					marker.Name = "SpawnPoint"
					marker.Anchored = true
					marker.CanCollide = false
					marker.Transparency = 1
					marker.Size = Vector3.new(4, 1, 4)
					marker.Position = hit.Position + Vector3.new(0, 0.5, 0)
					marker:SetAttribute("Indestructible", true)
					marker.Parent = folder
					spawns[#spawns + 1] = marker
				end
			end
		end
	end
	return spawns
end

function MapService.Load(name)
	MapService.Unload()
	local def = getDef(name)
	local origin = Config.MapOrigin

	-- Se construye directamente en el workspace pero repartido entre frames (Util.BuildBudget):
	-- los clientes reciben la isla poco a poco en lugar de un unico golpe enorme.
	local folder = Instance.new("Folder")
	folder.Name = "MapaActual_" .. name
	folder.Parent = workspace

	local spawns
	local ok, err = pcall(function()
		if def.Custom then
			spawns = placeCustom(def, folder, origin)
		else
			local b = Util.newBuilder(folder, origin)
			def.Build(b)
			spawns = b:Spawns()
		end
	end)
	if not ok then
		folder:Destroy()
		error("MapService: fallo construyendo '" .. name .. "': " .. tostring(err), 0)
	end
	applyLighting(def.Lighting)
	if def.Gravity then
		savedGravity = workspace.Gravity
		workspace.Gravity = def.Gravity
	end

	local b = def.Bounds or { x1 = -100, x2 = 100, z1 = -100, z2 = 100, top = 100, floor = 0 }
	local bounds = {
		x1 = origin.X + b.x1,
		x2 = origin.X + b.x2,
		z1 = origin.Z + b.z1,
		z2 = origin.Z + b.z2,
		top = origin.Y + (b.top or 100),
		floor = origin.Y + (b.floor or 0),
	}
	Destruction.Begin(folder, bounds.floor)

	current = { Name = name, Folder = folder, Spawns = spawns, Def = def, Bounds = bounds }
	return folder
end

function MapService.GetCurrent()
	return current
end

-- ===== Lobby =====

local function findLobbySpawns()
	if lobbySpawns then
		local valid = true
		for _, s in ipairs(lobbySpawns) do
			if not s.Parent then
				valid = false
			end
		end
		if valid then
			return lobbySpawns
		end
	end
	local found = {}
	local lobby = workspace:FindFirstChild("Lobby")
	local scope = lobby or workspace
	for _, inst in ipairs(scope:GetDescendants()) do
		if inst:IsA("SpawnLocation") and not (current and inst:IsDescendantOf(current.Folder)) then
			found[#found + 1] = inst
		end
	end
	if #found == 0 then
		local p = Instance.new("SpawnLocation")
		p.Name = "SpawnLobbyPorDefecto"
		p.Anchored = true
		p.Size = Vector3.new(30, 1, 30)
		p.Position = Vector3.new(0, 0, 0)
		p.Parent = workspace
		found = { p }
	end
	lobbySpawns = found
	return found
end
MapService.GetLobbySpawns = findLobbySpawns

-- ===== Teletransporte =====

local function shuffled(list)
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.random(i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function moveTo(player, position)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	-- Con StreamingEnabled hay que pedir que se cargue la zona antes de llegar
	pcall(function()
		player:RequestStreamAroundAsync(position, 3)
	end)
	char:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
	root.AssemblyLinearVelocity = Vector3.zero
	return true
end

local function teleport(list, spawns)
	if #spawns == 0 then
		warn("MapService: no hay puntos de aparicion")
		return
	end
	local order = shuffled(spawns)
	for i, player in ipairs(list) do
		local sp = order[(i - 1) % #order + 1]
		local s = sp.Size
		local jitter = Vector3.new((math.random() - 0.5) * math.min(s.X, 10), 0, (math.random() - 0.5) * math.min(s.Z, 10))
		task.spawn(moveTo, player, sp.Position + jitter)
	end
end

function MapService.TeleportToMap(list)
	if not current then
		warn("MapService: no hay ningun mapa cargado")
		return
	end
	teleport(list or Players:GetPlayers(), current.Spawns)
end

function MapService.ReturnToLobby(list)
	teleport(list or Players:GetPlayers(), findLobbySpawns())
end

-- Esta este jugador dentro del mapa actual?
function MapService.IsOnMap(player)
	if not current then
		return false
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	local b = current.Bounds
	local p = hrp.Position
	return p.X > b.x1 - 80 and p.X < b.x2 + 80 and p.Z > b.z1 - 80 and p.Z < b.z2 + 80 and p.Y > b.floor - 100 and p.Y < b.top + 200
end

return MapService
]])

add("ServerScriptService", { "IslasServer" }, "PhysicsBudget", "ModuleScript", [[
-- PhysicsBudget: controla cuantos cuerpos fisicos sueltos hay a la vez para que no caiga el rendimiento.
--  * Como mucho Config.MaxPhysicsBodies cuerpos simulandose (un "cuerpo" puede ser un bloque soldado de muchas piezas).
--  * Cuando un escombro se para (o lleva demasiado tiempo cayendo) se ANCLA: sigue viendose como escombro pero
--    ya no cuesta nada de fisica.
--  * Se guardan como mucho Config.MaxRubbleParts escombros; los mas viejos se borran.
--  * Los escombros rapidos hacen dano a los jugadores que golpean.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Config"))
local CollisionGroups = require(script.Parent.CollisionGroups)

local PhysicsBudget = {}

local bodies = {} -- { parts = {...}, root = part, welds = {...}, born = t, still = 0 }
local rubble = {} -- cola FIFO de piezas ancladas
local rubbleHead = 1
local killY = -math.huge
local hitCooldown = {} -- [humanoid] = t
local onRemove -- callback para borrar piezas (Destruction.Remove), evita tirones

local CHECK_EVERY = 0.15

local function clock()
	return workspace:GetServerTimeNow()
end

function PhysicsBudget.SetKillY(y)
	killY = y
end

function PhysicsBudget.SetRemover(fn)
	onRemove = fn
end

function PhysicsBudget.Count()
	return #bodies
end

function PhysicsBudget.RubbleCount()
	return #rubble - rubbleHead + 1
end

function PhysicsBudget.CanAdd(n)
	return #bodies + (n or 1) <= Config.MaxPhysicsBodies
end

local function removePart(part)
	if onRemove then
		onRemove(part)
	elseif part.Parent then
		part:Destroy()
	end
end

-- parts: lista de piezas (ya desancladas o no); la primera es la raiz del cuerpo
function PhysicsBudget.Add(parts, welds)
	local root = parts[1]
	if not root then
		return
	end
	for _, p in ipairs(parts) do
		p.CollisionGroup = CollisionGroups.Debris
		p.CanTouch = false
		p.CanQuery = false
		p.Anchored = false
	end
	bodies[#bodies + 1] = { parts = parts, root = root, welds = welds or {}, born = clock(), still = 0 }
end

local function settle(body)
	for _, w in ipairs(body.welds) do
		if w.Parent then
			w:Destroy()
		end
	end
	for _, p in ipairs(body.parts) do
		if p.Parent then
			p.Anchored = true
			p.AssemblyLinearVelocity = Vector3.zero
			rubble[#rubble + 1] = p
		end
	end
	-- limite de escombros: se quitan los mas viejos
	while #rubble - rubbleHead + 1 > Config.MaxRubbleParts do
		local old = rubble[rubbleHead]
		rubble[rubbleHead] = nil
		rubbleHead = rubbleHead + 1
		if old and old.Parent then
			removePart(old)
		end
	end
end

local function harmPlayers(body, speed)
	local root = body.root
	local s = root.Size
	local reach = math.max(s.X, s.Y, s.Z) / 2 + 3
	local pos = root.Position
	local now = clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 and (hrp.Position - pos).Magnitude < reach then
			if not hitCooldown[hum] or now - hitCooldown[hum] > 0.7 then
				hitCooldown[hum] = now
				hum:SetAttribute("Causa", "Escombros")
				hum:TakeDamage(math.clamp(speed * 0.6, 10, 45))
			end
		end
	end
end

function PhysicsBudget.Step(dt)
	local now = clock()
	for i = #bodies, 1, -1 do
		local b = bodies[i]
		local root = b.root
		if not root.Parent or root.Anchored then
			table.remove(bodies, i)
		elseif root.Position.Y < killY then
			for _, p in ipairs(b.parts) do
				removePart(p)
			end
			table.remove(bodies, i)
		else
			local speed = root.AssemblyLinearVelocity.Magnitude
			if speed > 28 then
				harmPlayers(b, speed)
			end
			if speed < 3 then
				b.still = b.still + dt
			else
				b.still = 0
			end
			if b.still >= Config.DebrisSettleTime or now - b.born > Config.DebrisMaxLife then
				settle(b)
				table.remove(bodies, i)
			end
		end
	end
end

-- Mueve los cuerpos activos hacia un punto (agujero negro, tornado)
function PhysicsBudget.ForEachBody(fn)
	for _, b in ipairs(bodies) do
		if b.root.Parent and not b.root.Anchored then
			fn(b.root, b)
		end
	end
end

function PhysicsBudget.Reset()
	table.clear(bodies)
	table.clear(rubble)
	rubbleHead = 1
	table.clear(hitCooldown)
	killY = -math.huge
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc = acc + dt
	if acc >= CHECK_EVERY then
		PhysicsBudget.Step(acc)
		acc = 0
	end
end)

return PhysicsBudget
]])

add("ServerScriptService", { "IslasServer" }, "PlayerData", "ModuleScript", [[
-- PlayerData: datos persistentes de cada jugador (DataStore) con guardado automatico.
-- Si el DataStore no esta disponible (por ejemplo en Studio sin "Enable Studio Access to API Services"),
-- se juega con datos temporales y NO se sobrescribe nada.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Levels = require(Shared:WaitForChild("Levels"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Net = require(Shared:WaitForChild("Net"))

local DataUpdate = Net.Event("DataUpdate")

local PlayerData = {}

local profiles = {} -- [player] = { data = {...}, noSave = bool, dirty = bool }
local changedHandlers = {}
local store
local orderedStore

local function defaultData()
	return {
		Version = 2,
		Coins = 0,
		XP = 0,
		Owned = {},
		Equipped = { Gears = {}, Trail = nil },
		Stats = {
			Wins = 0, Rounds = 0, Deaths = 0, BestStreak = 0, Streak = 0, CoinsEarned = 0, CoinsPicked = 0,
			Purchases = 0, ObbyCompleted = 0, SoleSurvivor = 0, DoubleSurvived = 0, MapsSurvived = 0,
			DisastersSurvived = 0, DailyStreak = 0, Level = 1,
		},
		MapsDone = {},
		DisastersDone = {},
		Achievements = {},
		LastDaily = 0,
		LastObby = 0,
		Settings = { Quality = 0, Shake = 1, Music = true, Sounds = true },
	}
end

-- rellena campos nuevos en datos antiguos
local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			if type(v) == "table" then
				data[k] = {}
				reconcile(data[k], v)
			else
				data[k] = v
			end
		elseif type(v) == "table" and type(data[k]) == "table" and k ~= "Owned" and k ~= "Achievements" and k ~= "MapsDone" and k ~= "DisastersDone" then
			reconcile(data[k], v)
		end
	end
	return data
end

local function keyFor(player)
	return "u_" .. player.UserId
end

function PlayerData.OnChanged(fn)
	changedHandlers[#changedHandlers + 1] = fn
end

local function fireChanged(player, key)
	for _, fn in ipairs(changedHandlers) do
		task.spawn(fn, player, key)
	end
end

function PlayerData.Get(player)
	local p = profiles[player]
	return p and p.data or nil
end

function PlayerData.WaitFor(player, timeout)
	local limit = os.clock() + (timeout or 15)
	while not profiles[player] and player.Parent and os.clock() < limit do
		task.wait(0.1)
	end
	return PlayerData.Get(player)
end

function PlayerData.LevelInfo(data)
	local level, into, need = Levels.FromTotal(data.XP)
	return level, into, need
end

function PlayerData.Snapshot(player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	local level, into, need = PlayerData.LevelInfo(data)
	local title, color = Levels.Title(level)
	local now = os.time()
	return {
		Coins = data.Coins,
		XP = data.XP,
		Level = level,
		LevelXP = into,
		LevelNeed = need,
		Title = title,
		TitleColor = color,
		Owned = data.Owned,
		Equipped = data.Equipped,
		Stats = data.Stats,
		Achievements = data.Achievements,
		Settings = data.Settings,
		GearSlots = Catalog.GearSlots(data.Owned),
		DailyAvailable = now - (data.LastDaily or 0) >= 20 * 3600,
		DailyStreak = data.Stats.DailyStreak,
		Temporary = profiles[player].noSave,
	}
end

local function updateLeaderstats(player)
	local data = PlayerData.Get(player)
	local ls = player:FindFirstChild("leaderstats")
	if not data or not ls then
		return
	end
	ls.Monedas.Value = data.Coins
	ls.Victorias.Value = data.Stats.Wins
	ls.Nivel.Value = (PlayerData.LevelInfo(data))
end

-- Envia los datos al cliente (agrupado: como mucho una vez por frame)
local pushPending = {}
function PlayerData.Push(player)
	if pushPending[player] then
		return
	end
	pushPending[player] = true
	task.defer(function()
		pushPending[player] = nil
		if player.Parent and profiles[player] then
			DataUpdate:FireClient(player, PlayerData.Snapshot(player))
			updateLeaderstats(player)
		end
	end)
end

function PlayerData.MarkDirty(player, key)
	local p = profiles[player]
	if p then
		p.dirty = true
		PlayerData.Push(player)
		fireChanged(player, key)
	end
end

function PlayerData.AddCoins(player, amount)
	local data = PlayerData.Get(player)
	if not data then
		return 0
	end
	amount = math.floor(amount + 0.5)
	data.Coins = math.max(0, data.Coins + amount)
	if amount > 0 then
		data.Stats.CoinsEarned = data.Stats.CoinsEarned + amount
	end
	PlayerData.MarkDirty(player, "Coins")
	return amount
end

function PlayerData.Spend(player, amount)
	local data = PlayerData.Get(player)
	if not data or data.Coins < amount then
		return false
	end
	data.Coins = data.Coins - amount
	PlayerData.MarkDirty(player, "Coins")
	return true
end

-- Devuelve nivelAntes, nivelDespues
function PlayerData.AddXP(player, amount)
	local data = PlayerData.Get(player)
	if not data then
		return 1, 1
	end
	local before = PlayerData.LevelInfo(data)
	data.XP = data.XP + math.floor(amount + 0.5)
	local after = PlayerData.LevelInfo(data)
	data.Stats.Level = after
	PlayerData.MarkDirty(player, "XP")
	return before, after
end

-- ======================================================================
-- Carga / guardado
-- ======================================================================
local function load(player)
	local data, ok
	if store then
		for attempt = 1, 3 do
			ok, data = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				break
			end
			task.wait(attempt)
		end
	end
	local noSave = not store or not ok
	if noSave and store then
		warn("PlayerData: no se pudieron cargar los datos de " .. player.Name .. "; se usan datos temporales")
	end
	data = reconcile(type(data) == "table" and data or defaultData(), defaultData())
	if not player.Parent then
		return
	end
	profiles[player] = { data = data, noSave = noSave, dirty = false }

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, n in ipairs({ "Victorias", "Nivel", "Monedas" }) do
		local v = Instance.new("IntValue")
		v.Name = n
		v.Parent = ls
	end
	ls.Parent = player
	updateLeaderstats(player)
	PlayerData.Push(player)
	fireChanged(player, "Loaded")
end

local function save(player, final)
	local p = profiles[player]
	if not p or p.noSave or not store then
		return true
	end
	if not p.dirty and not final then
		return true
	end
	local data = p.data
	local ok, err
	for attempt = 1, 3 do
		ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function()
				return data
			end)
		end)
		if ok then
			break
		end
		task.wait(attempt)
	end
	if ok then
		p.dirty = false
		if orderedStore then
			pcall(function()
				orderedStore:SetAsync(keyFor(player), data.Stats.Wins)
			end)
		end
	else
		warn("PlayerData: error guardando a " .. player.Name .. ": " .. tostring(err))
	end
	return ok
end
PlayerData.Save = save

function PlayerData.GetOrderedStore()
	return orderedStore
end

local started = false
function PlayerData.Init()
	if started then
		return
	end
	started = true
	local ok = pcall(function()
		store = DataStoreService:GetDataStore(Config.DataStoreName)
		orderedStore = DataStoreService:GetOrderedDataStore(Config.LeaderboardStoreName)
	end)
	if not ok then
		store, orderedStore = nil, nil
		warn("PlayerData: DataStore no disponible, los datos no se guardaran")
	end

	Players.PlayerAdded:Connect(function(player)
		load(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player, true)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		for player in pairs(profiles) do
			task.spawn(save, player, true)
		end
		task.wait(3)
	end)
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in pairs(profiles) do
				task.spawn(save, player, false)
			end
		end
	end)

	Net.Function("GetData").OnServerInvoke = function(player)
		PlayerData.WaitFor(player, 10)
		return PlayerData.Snapshot(player)
	end

	Net.Event("SettingsChanged").OnServerEvent:Connect(function(player, settings)
		local data = PlayerData.Get(player)
		if not data or typeof(settings) ~= "table" then
			return
		end
		local s = data.Settings
		if typeof(settings.Quality) == "number" then
			s.Quality = math.clamp(math.floor(settings.Quality), 0, 3)
		end
		if typeof(settings.Shake) == "number" then
			s.Shake = math.clamp(settings.Shake, 0, 1)
		end
		if typeof(settings.Music) == "boolean" then
			s.Music = settings.Music
		end
		if typeof(settings.Sounds) == "boolean" then
			s.Sounds = settings.Sounds
		end
		profiles[player].dirty = true
	end)
end

return PlayerData
]])

add("ServerScriptService", { "IslasServer" }, "Rewards", "ModuleScript", [[
-- Rewards: monedas, experiencia, estadisticas, logros y recompensa diaria, con avisos al cliente
-- (numeros que saltan, subida de nivel, logro desbloqueado...).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Achievements = require(Shared:WaitForChild("Achievements"))
local Levels = require(Shared:WaitForChild("Levels"))
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)

local Popup = Net.Event("Popup")
local Toast = Net.Event("Toast")
local PlaySound = Net.Event("PlaySound")

local Rewards = {}

Rewards.Multiplier = 1 -- lo cambia GameLoop (monedas x2, modo hiper...)

local function checkAchievements(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	for _, a in ipairs(Achievements) do
		if not data.Achievements[a.Id] then
			local value = data.Stats[a.Stat] or 0
			if value >= a.Goal then
				data.Achievements[a.Id] = os.time()
				PlayerData.AddCoins(player, a.Reward)
				Toast:FireClient(player, {
					Kind = "Achievement",
					Title = "🏆 Logro: " .. a.Name,
					Text = a.Desc .. "  (+" .. a.Reward .. " monedas)",
				})
				PlaySound:FireClient(player, "Win", nil, 0.8)
			end
		end
	end
end
Rewards.CheckAchievements = checkAchievements

-- coins/xp: cantidades base. opts.noMultiplier, opts.text (motivo), opts.position (Vector3: popup en el mundo)
function Rewards.Give(player, coins, xp, opts)
	opts = opts or {}
	local data = PlayerData.Get(player)
	if not data then
		return 0, 0
	end
	local mult = opts.noMultiplier and 1 or Rewards.Multiplier
	if opts.lucky and data.Owned.Suerte then
		mult = mult * 1.25
	end
	local c = math.floor((coins or 0) * mult + 0.5)
	local x = math.floor((xp or 0) * (opts.noMultiplier and 1 or math.max(1, Rewards.Multiplier * 0.75)) + 0.5)
	if c ~= 0 then
		PlayerData.AddCoins(player, c)
	end
	local before, after = 1, 1
	if x > 0 then
		before, after = PlayerData.AddXP(player, x)
	end
	if c > 0 or x > 0 then
		Popup:FireClient(player, { Coins = c, XP = x, Text = opts.text, Position = opts.position })
	end
	if after > before then
		local title = Levels.Title(after)
		Toast:FireClient(player, { Kind = "LevelUp", Title = "¡NIVEL " .. after .. "!", Text = "Rango: " .. title, Level = after })
		PlaySound:FireClient(player, "LevelUp", nil, 1)
		-- recompensa por subir de nivel
		PlayerData.AddCoins(player, 25 + after * 5)
	end
	checkAchievements(player)
	return c, x
end

-- Suma (o fija con set=true) una estadistica y revisa logros
function Rewards.Stat(player, stat, delta, set)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	if set then
		data.Stats[stat] = delta
	else
		data.Stats[stat] = (data.Stats[stat] or 0) + delta
	end
	PlayerData.MarkDirty(player, stat)
	checkAchievements(player)
end

-- Apunta algo en una coleccion (mapas/desastres sobrevividos) y actualiza el contador
function Rewards.Collect(player, setName, key, statName)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local set = data[setName]
	if not set[key] then
		set[key] = true
		local n = 0
		for _ in pairs(set) do
			n = n + 1
		end
		data.Stats[statName] = n
		PlayerData.MarkDirty(player, statName)
		checkAchievements(player)
	end
end

function Rewards.DailyInfo(player)
	local data = PlayerData.Get(player)
	if not data then
		return false, 0, 0
	end
	local now = os.time()
	local available = now - (data.LastDaily or 0) >= 20 * 3600
	local streak = data.Stats.DailyStreak or 0
	if now - (data.LastDaily or 0) > 48 * 3600 then
		streak = 0
	end
	local nextDay = math.min(streak + 1, Config.DailyRewardMaxDays)
	return available, nextDay, Config.DailyRewardBase * nextDay
end

function Rewards.ClaimDaily(player)
	local data = PlayerData.Get(player)
	if not data then
		return false
	end
	local available, day, amount = Rewards.DailyInfo(player)
	if not available then
		return false
	end
	data.LastDaily = os.time()
	data.Stats.DailyStreak = day
	Rewards.Give(player, amount, 20, { noMultiplier = true, text = "Recompensa diaria (dia " .. day .. ")" })
	Rewards.Stat(player, "DailyStreak", day, true)
	return true, amount, day
end

function Rewards.Init()
	Net.Event("DailyClaim").OnServerEvent:Connect(function(player)
		Rewards.ClaimDaily(player)
	end)
end

return Rewards
]])

add("ServerScriptService", { "IslasServer" }, "ShopService", "ModuleScript", [[
-- ShopService: compras y equipamiento (RemoteFunction "ShopRequest").
--   ShopRequest:InvokeServer("buy", id)   -> ok, mensaje
--   ShopRequest:InvokeServer("equip", id) -> ok, mensaje   (gears: pone/quita; estela: cambia)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)
local Gear = require(script.Parent.Gear)

local PlaySound = Net.Event("PlaySound")

local ShopService = {}

local busy = {}

local function equip(player, data, item)
	if item.Kind == "Gear" then
		local list = data.Equipped.Gears
		local idx = table.find(list, item.Id)
		if idx then
			table.remove(list, idx)
			return true, item.Name .. " quitado"
		end
		local slots = Catalog.GearSlots(data.Owned)
		while #list >= slots do
			table.remove(list, 1)
		end
		list[#list + 1] = item.Id
		return true, item.Name .. " equipado"
	elseif item.Kind == "Trail" then
		if data.Equipped.Trail == item.Id then
			data.Equipped.Trail = nil
			return true, "Estela quitada"
		end
		data.Equipped.Trail = item.Id
		return true, item.Name .. " equipada"
	end
	return false, "No se puede equipar"
end

function ShopService.Handle(player, action, id)
	local data = PlayerData.Get(player)
	local item = typeof(id) == "string" and Catalog.ById[id]
	if not data or not item then
		return false, "Objeto no valido"
	end
	if busy[player] then
		return false, "Espera un momento"
	end
	busy[player] = true
	local ok, msg = false, "Accion no valida"
	if action == "buy" then
		if data.Owned[id] then
			ok, msg = false, "Ya lo tienes"
		elseif not PlayerData.Spend(player, item.Price) then
			ok, msg = false, "Te faltan " .. (item.Price - data.Coins) .. " monedas"
		else
			data.Owned[id] = true
			Rewards.Stat(player, "Purchases", 1)
			if item.Kind ~= "Upgrade" then
				equip(player, data, item)
			end
			ok, msg = true, "¡Comprado: " .. item.Name .. "!"
			PlaySound:FireClient(player, "Win", nil, 0.8)
		end
	elseif action == "equip" then
		if not data.Owned[id] then
			ok, msg = false, "Primero tienes que comprarlo"
		else
			ok, msg = equip(player, data, item)
		end
	end
	if ok then
		PlayerData.MarkDirty(player, "Shop")
		-- en el lobby se aplica al momento; en la ronda, los gears nuevos llegan en la siguiente
		if player:GetAttribute("EnRonda") ~= true then
			Gear.Refresh(player)
		else
			Gear.ApplyTrail(player)
		end
	end
	busy[player] = nil
	return ok, msg
end

function ShopService.Init()
	Net.Function("ShopRequest").OnServerInvoke = function(player, action, id)
		local ok, a, b = pcall(ShopService.Handle, player, action, id)
		if not ok then
			warn("ShopService: " .. tostring(a))
			busy[player] = nil
			return false, "Error"
		end
		return a, b
	end
end

return ShopService
]])

add("ServerScriptService", { "IslasServer" }, "VoteService", "ModuleScript", [[
-- VoteService: votacion de mapa entre rondas.
--   local winner = VoteService.Run(VoteService.PickOptions(3), segundos)
-- Bloquea hasta que acaba el tiempo (o hasta que han votado todos) y devuelve el nombre del mapa ganador.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))
local MapService = require(script.Parent.MapService)
local DisasterService = require(script.Parent.DisasterService)

local VoteOptions = Net.Event("VoteOptions")
local VoteUpdate = Net.Event("VoteUpdate")
local VoteEnd = Net.Event("VoteEnd")
local CastVote = Net.Event("CastVote")

local VoteService = {}

local active = nil -- { set, list, votes = { [userId] = nombre } }
local lastWinner = nil

local function tally(options)
	local counts = {}
	for _, name in ipairs(options) do
		counts[name] = 0
	end
	for _, name in pairs(active.votes) do
		if counts[name] then
			counts[name] = counts[name] + 1
		end
	end
	return counts
end

CastVote.OnServerEvent:Connect(function(player, name)
	if not active or typeof(name) ~= "string" or not active.set[name] then
		return
	end
	active.votes[player.UserId] = name
	VoteUpdate:FireAllClients(tally(active.list))
end)

Players.PlayerRemoving:Connect(function(player)
	if active then
		active.votes[player.UserId] = nil
		VoteUpdate:FireAllClients(tally(active.list))
	end
end)

-- Elige `n` mapas distintos al azar (sin repetir el ultimo jugado si hay suficientes)
function VoteService.PickOptions(n)
	local names = MapService.GetMapNames()
	if #names > n and lastWinner then
		local i = table.find(names, lastWinner)
		if i then
			table.remove(names, i)
		end
	end
	for i = #names, 2, -1 do
		local j = math.random(i)
		names[i], names[j] = names[j], names[i]
	end
	local picked = {}
	for i = 1, math.min(n, #names) do
		picked[i] = names[i]
	end
	return picked
end

function VoteService.Run(options, seconds)
	local set = {}
	local infos = {}
	for _, name in ipairs(options) do
		set[name] = true
		local info = MapService.GetInfo(name)
		info.DisasterTitles = {}
		info.DisasterIcons = {}
		for _, d in ipairs(info.Disasters) do
			local di = DisasterService.Info(d)
			info.DisasterTitles[#info.DisasterTitles + 1] = di.Title
			info.DisasterIcons[#info.DisasterIcons + 1] = di.Icon
		end
		infos[#infos + 1] = info
	end
	active = { set = set, list = options, votes = {} }

	local endTime = workspace:GetServerTimeNow() + seconds
	VoteOptions:FireAllClients(infos, endTime)
	VoteUpdate:FireAllClients(tally(options))

	-- termina antes si ya han votado todos (y hay mas de uno)
	while workspace:GetServerTimeNow() < endTime do
		task.wait(0.25)
		local n, voted = #Players:GetPlayers(), 0
		for _ in pairs(active.votes) do
			voted = voted + 1
		end
		if n > 1 and voted >= n and endTime - workspace:GetServerTimeNow() > 2 then
			endTime = workspace:GetServerTimeNow() + 2
		end
	end

	local counts = tally(options)
	local best, bestCount = {}, -1
	for _, name in ipairs(options) do
		if counts[name] > bestCount then
			best, bestCount = { name }, counts[name]
		elseif counts[name] == bestCount then
			best[#best + 1] = name
		end
	end
	local winner = best[math.random(#best)]

	active = nil
	lastWinner = winner
	VoteEnd:FireAllClients(winner, MapService.GetInfo(winner).Title)
	return winner
end

return VoteService
]])

add("StarterPlayerScripts", { "IslasClient" }, "Cliente", "LocalScript", [[
-- Cliente: punto de entrada del jugador. Carga todos los modulos de la carpeta Modulos en orden.
local modulesFolder = script.Parent:WaitForChild("Modulos")

local ORDER = {
	"UI", "Quality", "SoundFX", "State", "Popups", "DebrisFX", "DisasterFX", "MapAnimator", "Hud",
	"VoteUI", "ResultsUI", "ShopUI", "DailyUI", "AchievementsUI", "SettingsUI", "SpectateUI",
	"ElevatorUI", "GearClient", "Music",
}

local modules = {}
for _, name in ipairs(ORDER) do
	local m = modulesFolder:FindFirstChild(name)
	if m then
		local ok, result = pcall(require, m)
		if ok then
			modules[name] = result
		else
			warn("Cliente: no se pudo cargar " .. name .. ": " .. tostring(result))
		end
	end
end
for _, name in ipairs(ORDER) do
	local m = modules[name]
	if type(m) == "table" and m.Init then
		local ok, err = pcall(m.Init, modules)
		if not ok then
			warn("Cliente: error iniciando " .. name .. ": " .. tostring(err))
		end
	end
end
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "AchievementsUI", "ModuleScript", [[
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
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "DailyUI", "ModuleScript", [[
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
]])

add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "DebrisFX", "ModuleScript", [[
-- DebrisFX: fragmentos visuales cuando algo se rompe. Solo existen en este cliente:
--   * el servidor no simula ni replica nada (cero coste de red y de fisica en el servidor),
--   * se reutilizan piezas de un pool (no se crean/destruyen sin parar),
--   * el numero de fragmentos depende de la calidad (Quality) y la distancia,
--   * no chocan entre si ni con los jugadores (grupo de colision IslasFx).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local DebrisFX = {}

local Quality, SoundFX
local folder
local pool = {} -- piezas libres
local active = {} -- { part, born, life, fading }
local total = 0

local function getPart()
	local p = table.remove(pool)
	if p then
		return p
	end
	local settings = Quality.Settings()
	if total >= settings.MaxFragments then
		-- reciclar el fragmento mas viejo
		local oldest = table.remove(active, 1)
		if oldest then
			return oldest.part
		end
		return nil
	end
	total = total + 1
	p = Instance.new("Part")
	p.Name = "Fragmento"
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	pcall(function()
		p.CollisionGroup = "IslasFx"
	end)
	return p
end

local function release(entry)
	local p = entry.part
	p.Anchored = true
	p.Parent = nil
	pool[#pool + 1] = p
end

local function spawnFragments(rec, camPos, settings)
	local center, size = rec.p, rec.s
	if typeof(center) ~= "Vector3" or typeof(size) ~= "Vector3" then
		return
	end
	local dist = (center - camPos).Magnitude
	if dist > settings.Distance then
		return
	end
	local vol = size.X * size.Y * size.Z
	local n = math.clamp(math.floor(math.sqrt(vol) / 2) + 1, 1, settings.PerBreak)
	if dist > settings.Distance * 0.6 then
		n = math.max(1, math.floor(n / 2))
	end
	local scale = 1 / (n ^ (1 / 3))
	local mat = Enum.Material.SmoothPlastic
	pcall(function()
		mat = Enum.Material[rec.m]
	end)
	local glass = rec.m == "Glass"
	for _ = 1, n do
		local p = getPart()
		if not p then
			return
		end
		local r = 0.6 + math.random() * 0.5
		p.Size = Vector3.new(
			math.clamp(size.X * scale * r, 0.3, 6),
			math.clamp(size.Y * scale * r, 0.3, 6),
			math.clamp(size.Z * scale * r, 0.3, 6)
		)
		local off = Vector3.new((math.random() - 0.5) * size.X, (math.random() - 0.5) * size.Y, (math.random() - 0.5) * size.Z) * 0.8
		p.CFrame = CFrame.new(center + off) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		p.Color = rec.c or Color3.new(0.6, 0.6, 0.6)
		p.Material = mat
		p.Transparency = glass and 0.45 or 0
		p.CanCollide = true
		p.Anchored = false
		p.Parent = folder
		local dir = off.Magnitude > 0.1 and off.Unit or Vector3.yAxis
		p.AssemblyLinearVelocity = dir * (8 + math.random() * 14) + Vector3.new(0, 10 + math.random() * 12, 0)
		p.AssemblyAngularVelocity = Vector3.new(math.random() * 10 - 5, math.random() * 10 - 5, math.random() * 10 - 5)
		active[#active + 1] = { part = p, born = os.clock(), life = settings.Life * (0.7 + math.random() * 0.6) }
	end
end

function DebrisFX.Burst(batch)
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local settings = Quality.Settings()
	local sumPos, count, glassCount = Vector3.zero, 0, 0
	for _, rec in ipairs(batch) do
		spawnFragments(rec, camPos, settings)
		if typeof(rec.p) == "Vector3" then
			sumPos = sumPos + rec.p
			count = count + 1
			if rec.m == "Glass" then
				glassCount = glassCount + 1
			end
		end
	end
	if count > 0 and SoundFX then
		local center = sumPos / count
		if (center - camPos).Magnitude < 250 then
			SoundFX.PlayAt(glassCount > count / 2 and "Glass" or "Crumble", center, math.clamp(0.3 + count * 0.05, 0.3, 1))
		end
	end
end

function DebrisFX.Init(modules)
	Quality = modules.Quality
	SoundFX = modules.SoundFX
	folder = Instance.new("Folder")
	folder.Name = "FragmentosLocales"
	folder.Parent = workspace

	Net.Event("Shatter").OnClientEvent:Connect(function(batch)
		if typeof(batch) == "table" then
			DebrisFX.Burst(batch)
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local now = os.clock()
		for i = #active, 1, -1 do
			local e = active[i]
			local age = now - e.born
			if age > e.life then
				local t = math.clamp((age - e.life) / 0.6, 0, 1)
				e.part.Transparency = math.max(e.part.Transparency, t)
				if t >= 1 or e.part.Position.Y < -400 then
					table.remove(active, i)
					release(e)
				end
			end
		end
	end)

	-- si baja la calidad, se sueltan fragmentos sobrantes
	Quality.OnChanged(function()
		local max = Quality.Settings().MaxFragments
		while #active > max do
			release(table.remove(active, 1))
		end
	end)
end

return DebrisFX
]])

print("Islas de Desastres: parte 4 de 5 instalada")
