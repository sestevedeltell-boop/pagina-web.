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
