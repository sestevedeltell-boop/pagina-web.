-- MapService: construye un mapa SOLO cuando se necesita, teletransporta jugadores y lo borra despues.
-- Mientras un mapa no se ha votado no existe en el workspace, asi que no consume nada.
--
-- API:
--   MapService.GetMapNames()            -> lista de nombres de mapas disponibles
--   MapService.GetInfo(name)            -> { Name, Title, Description, Disasters }
--   MapService.GetCurrent()             -> { Name, Folder, Spawns, Def } o nil
--   MapService.Load(name)               -> construye el mapa (bloquea hasta terminar)
--   MapService.TeleportToMap(players)   -> manda jugadores a los spawns del mapa cargado
--   MapService.ReturnToLobby(players)   -> los devuelve al lobby
--   MapService.Unload()                 -> destruye el mapa cargado y restaura la iluminacion

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Config"))
local MapsRoot = ServerStorage:WaitForChild("IslasMapas")
local Util = require(MapsRoot:WaitForChild("Lib"):WaitForChild("Util"))
local Builders = MapsRoot:WaitForChild("Builders")

local MapService = {}

local current = nil -- { Name, Folder, Spawns }
local savedLighting = nil
local savedGravity = nil
local lobbySpawns = nil

local LIGHT_PROPS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "FogColor", "FogStart", "FogEnd" }

local function getBuilder(name)
	local module = Builders:FindFirstChild(name)
	if not module then
		error("MapService: no existe el mapa '" .. tostring(name) .. "'")
	end
	return require(module)
end

function MapService.GetMapNames()
	local names = {}
	for _, child in ipairs(Builders:GetChildren()) do
		if child:IsA("ModuleScript") then
			names[#names + 1] = child.Name
		end
	end
	table.sort(names)
	return names
end

function MapService.GetInfo(name)
	local def = getBuilder(name)
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

local function restoreGravity()
	if savedGravity then
		workspace.Gravity = savedGravity
		savedGravity = nil
	end
end

function MapService.Unload()
	if current then
		current.Folder:Destroy()
		current = nil
	end
	restoreLighting()
	restoreGravity()
end

function MapService.Load(name)
	MapService.Unload()
	local def = getBuilder(name)

	local folder = Instance.new("Folder")
	folder.Name = "MapaActual_" .. name
	local b = Util.newBuilder(folder, Config.MapOrigin)

	-- Se construye fuera del workspace y se cuelga al final: los clientes reciben la isla de una vez
	-- en lugar de ver aparecer piezas sueltas mientras se construye.
	local ok, err = pcall(def.Build, b)
	if not ok then
		folder:Destroy()
		error("MapService: fallo construyendo '" .. name .. "': " .. tostring(err), 0)
	end
	folder.Parent = workspace
	applyLighting(def.Lighting)
	if def.Gravity then
		savedGravity = workspace.Gravity
		workspace.Gravity = def.Gravity
	end

	current = { Name = name, Folder = folder, Spawns = b:Spawns(), Def = def }
	return folder
end

function MapService.GetCurrent()
	return current
end

-- ===== Lobby =====

local function buildDefaultLobby()
	local folder = Instance.new("Folder")
	folder.Name = "LobbyPorDefecto"
	folder.Parent = workspace
	local b = Util.newBuilder(folder, Vector3.new(0, 0, 0))
	b:Box("SueloLobby", Vector3.new(80, 2, 80), Vector3.new(0, -1, 0), Util.Colors.Grass, Enum.Material.Grass)
	b:Board("CartelLobby", "LOBBY", Vector3.new(24, 8, 1), Vector3.new(0, 6, -36), Util.Colors.DarkMetal, Color3.new(1, 1, 1))
	local sp = b:Spawn(Vector3.new(0, 1, 0))
	return { sp }
end

local function findLobbySpawns()
	if lobbySpawns then
		return lobbySpawns
	end
	local found = {}
	local lobby = workspace:FindFirstChild("Lobby")
	local scope = lobby or workspace
	for _, inst in ipairs(scope:GetDescendants()) do
		if inst:IsA("SpawnLocation") then
			found[#found + 1] = inst
		end
	end
	if #found == 0 then
		found = buildDefaultLobby()
	end
	lobbySpawns = found
	return found
end

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
		player:RequestStreamAroundAsync(position)
	end)
	char:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
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
		local jitter = Vector3.new(math.random(-10, 10) / 10, 0, math.random(-10, 10) / 10)
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

return MapService
