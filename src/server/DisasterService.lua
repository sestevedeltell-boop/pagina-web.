-- DisasterService: lanza un desastre en la isla actual.
--   DisasterService.Start(MapService.GetCurrent(), duracion [, "Earthquake"])  -> { Name, Title, Description }
--   DisasterService.Stop()                                                      -- limpia efectos y restaura la luz
--
-- Cada mapa dice que desastres admite (Disasters = {...}), sus limites (Bounds) y ajustes (DisasterConfig).
-- Los desastres viven en IslasServer/Disasters: cada uno es un ModuleScript { Title, Description, Run(ctx) }.
-- Run(ctx) se ejecuta en su propio hilo y debe hacer un bucle `while ctx.active() do ... end`.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Config"))
local Util = require(ServerStorage:WaitForChild("IslasMapas"):WaitForChild("Lib"):WaitForChild("Util"))
local DisasterFX = ReplicatedStorage:WaitForChild("IslasRemotes"):WaitForChild("DisasterFX")
local Disasters = script.Parent:WaitForChild("Disasters")

local DisasterService = {}

local active = nil -- el contexto del desastre en curso

function DisasterService.GetNames()
	local names = {}
	for _, child in ipairs(Disasters:GetChildren()) do
		if child:IsA("ModuleScript") then
			names[#names + 1] = child.Name
		end
	end
	table.sort(names)
	return names
end

function DisasterService.TitleOf(name)
	local module = Disasters:FindFirstChild(name)
	return module and require(module).Title or name
end

local function inElevator(part, root)
	local p = part.Parent
	while p and p ~= root do
		if p.Name:match("_Cabina$") or p.Name:match("_Hueco$") then
			return true
		end
		p = p.Parent
	end
	return false
end

local NOT_FRAGILE = { Isla = true, Mar = true, SpawnPoint = true, Roca = true }

local function buildContext(current, duration, name)
	local def = current.Def
	local origin = Config.MapOrigin
	local b = def.Bounds or { x1 = -100, x2 = 100, z1 = -100, z2 = 100, top = 100, floor = 0 }
	local ctx = {
		Util = Util,
		name = name,
		map = current,
		duration = duration,
		config = (def.DisasterConfig and def.DisasterConfig[name]) or {},
		stopped = false,
		startTime = workspace:GetServerTimeNow(),
		bounds = {
			x1 = origin.X + b.x1,
			x2 = origin.X + b.x2,
			z1 = origin.Z + b.z1,
			z2 = origin.Z + b.z2,
			top = origin.Y + (b.top or 100),
			floor = origin.Y + (b.floor or 0),
		},
	}
	ctx.endTime = ctx.startTime + duration

	local folder = Instance.new("Folder")
	folder.Name = "EfectosDesastre"
	folder.Parent = workspace
	ctx.folder = folder
	ctx.build = Util.newBuilder(folder, Vector3.new(0, 0, 0)) -- posiciones en coordenadas de mundo

	local stopCallbacks = {}
	function ctx.onStop(fn)
		stopCallbacks[#stopCallbacks + 1] = fn
	end
	ctx.stopCallbacks = stopCallbacks

	function ctx.time()
		return workspace:GetServerTimeNow()
	end
	function ctx.elapsed()
		return workspace:GetServerTimeNow() - ctx.startTime
	end
	function ctx.progress()
		return math.clamp(ctx.elapsed() / duration, 0, 1)
	end
	function ctx.active()
		return not ctx.stopped and workspace:GetServerTimeNow() < ctx.endTime
	end

	-- Jugadores vivos que estan en la isla (los que esperan en el lobby no cuentan)
	function ctx.players()
		local list = {}
		local bb = ctx.bounds
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				local pos = root.Position
				if pos.X > bb.x1 - 60 and pos.X < bb.x2 + 60 and pos.Z > bb.z1 - 60 and pos.Z < bb.z2 + 60
					and pos.Y > bb.floor - 80 and pos.Y < bb.top + 150 then
					list[#list + 1] = { player = p, humanoid = hum, root = root }
				end
			end
		end
		return list
	end

	function ctx.damage(entry, amount)
		if entry.humanoid.Health > 0 then
			entry.humanoid:TakeDamage(amount)
		end
	end

	function ctx.randomPoint()
		local bb = ctx.bounds
		return bb.x1 + math.random() * (bb.x2 - bb.x1), bb.z1 + math.random() * (bb.z2 - bb.z1)
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { current.Folder }
	rayParams.RespectCanCollide = true
	ctx.rayParams = rayParams

	-- Altura de la superficie en (x, z) mirando desde el cielo (nil si no hay nada)
	function ctx.groundY(x, z)
		local bb = ctx.bounds
		local hit = workspace:Raycast(Vector3.new(x, bb.top + 30, z), Vector3.new(0, -(bb.top - bb.floor + 200), 0), rayParams)
		return hit and hit.Position.Y or nil
	end

	function ctx.fx(kind, ...)
		DisasterFX:FireAllClients(kind, ...)
	end

	function ctx.tween(inst, seconds, goal)
		TweenService:Create(inst, TweenInfo.new(seconds, Enum.EasingStyle.Linear), goal):Play()
	end

	-- Cambia la iluminacion y la restaura al parar
	local savedLight = {}
	function ctx.setLighting(props)
		for prop, value in pairs(props) do
			if savedLight[prop] == nil then
				savedLight[prop] = Lighting[prop]
			end
			Lighting[prop] = value
		end
	end
	ctx.onStop(function()
		for prop, value in pairs(savedLight) do
			Lighting[prop] = value
		end
	end)

	-- Piezas pequenas que pueden romperse/salir volando (se calcula una vez)
	local fragileCache
	function ctx.fragileParts()
		if fragileCache then
			return fragileCache
		end
		fragileCache = {}
		for _, d in ipairs(current.Folder:GetDescendants()) do
			if d:IsA("Part") and d.Anchored and d.CanCollide and not NOT_FRAGILE[d.Name] then
				local s = d.Size
				if s.X * s.Y * s.Z < 450 and math.max(s.X, s.Y, s.Z) < 30 and not inElevator(d, current.Folder) then
					fragileCache[#fragileCache + 1] = d
				end
			end
		end
		return fragileCache
	end

	return ctx
end

function DisasterService.Stop()
	local ctx = active
	if not ctx then
		return
	end
	active = nil
	ctx.stopped = true
	for _, fn in ipairs(ctx.stopCallbacks) do
		pcall(fn)
	end
	ctx.folder:Destroy()
	DisasterFX:FireAllClients("clear")
end

function DisasterService.Start(current, duration, name)
	DisasterService.Stop()
	local def = current.Def
	local options = def.Disasters or {}
	if #options == 0 then
		return nil
	end
	name = name or options[math.random(#options)]
	local module = Disasters:FindFirstChild(name)
	if not module then
		warn("DisasterService: no existe el desastre '" .. tostring(name) .. "'")
		return nil
	end
	local disaster = require(module)

	local ctx = buildContext(current, duration, name)
	active = ctx
	ctx.fx("banner", disaster.Title, disaster.Description, Config.DisasterDelay)

	task.spawn(function()
		task.wait(Config.DisasterDelay)
		if ctx.stopped then
			return
		end
		local ok, err = pcall(disaster.Run, ctx)
		if not ok then
			warn("DisasterService: error en el desastre " .. name .. ": " .. tostring(err))
		end
	end)

	return { Name = name, Title = disaster.Title, Description = disaster.Description }
end

return DisasterService
