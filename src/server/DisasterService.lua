-- DisasterService: lanza desastres en la isla actual (uno o varios a la vez).
--   DisasterService.Start(MapService.GetCurrent(), duracion [, "Earthquake" [, opts]])
--       opts: intensity (1 = normal), delay (segundos de aviso), mystery (oculta el nombre hasta que empieza)
--       -> { Id, Name, Title, Icon, Description }
--   DisasterService.StopAll()   -- limpia efectos y restaura la luz (llamalo antes de MapService.Unload)
--   DisasterService.Pick(current, exclude) -> nombre al azar de los que admite el mapa
--
-- Cada desastre es un ModuleScript en IslasServer/Disasters con Run(ctx). Run se ejecuta en su propio hilo
-- y hace un bucle `while ctx.active() do ... end`. Los efectos visuales se dibujan en los clientes con ctx.fx
-- (sin piezas replicadas) y el dano/destruccion se calcula en el servidor.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local DisasterInfo = require(Shared:WaitForChild("DisasterInfo"))
local Paths = require(Shared:WaitForChild("Paths"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(ServerStorage:WaitForChild("IslasMapas"):WaitForChild("Lib"):WaitForChild("Util"))
local Destruction = require(script.Parent.Destruction)
local PhysicsBudget = require(script.Parent.PhysicsBudget)
local Disasters = script.Parent:WaitForChild("Disasters")

local DisasterFX = Net.Event("DisasterFX")

local DisasterService = {}

local active = {} -- contextos en curso
local nextId = 0

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

function DisasterService.Info(name)
	local info = DisasterInfo[name]
	if info then
		return info
	end
	return { Title = name, Icon = "⚠️", Desc = "", Color = Color3.new(1, 1, 1) }
end

function DisasterService.TitleOf(name)
	return DisasterService.Info(name).Title
end

function DisasterService.Pick(current, exclude)
	local options = {}
	for _, n in ipairs(current.Def.Disasters or {}) do
		if n ~= exclude and Disasters:FindFirstChild(n) then
			options[#options + 1] = n
		end
	end
	if #options == 0 then
		return nil
	end
	return options[math.random(#options)]
end

function DisasterService.Active()
	return active
end

-- Lleva este jugador el gear `name` equipado (en la mano)?
local function holding(char, name)
	local tool = char and char:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool.Name == name
end
DisasterService.Holding = holding

local function buildContext(current, duration, name, opts)
	nextId = nextId + 1
	local info = DisasterService.Info(name)
	local ctx = {
		id = nextId,
		name = name,
		info = info,
		Util = Util,
		D = Destruction,
		PB = PhysicsBudget,
		Paths = Paths,
		map = current,
		duration = duration,
		intensity = opts.intensity or 1,
		config = (current.Def.DisasterConfig and current.Def.DisasterConfig[name]) or {},
		stopped = false,
		bounds = current.Bounds,
	}
	ctx.startTime = workspace:GetServerTimeNow()
	ctx.endTime = ctx.startTime + duration

	local folder = Instance.new("Folder")
	folder.Name = "EfectosDesastre"
	folder.Parent = workspace
	ctx.folder = folder
	ctx.build = Util.newBuilder(folder, Vector3.new(0, 0, 0))

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
		return math.clamp(ctx.elapsed() / ctx.duration, 0, 1)
	end
	function ctx.active()
		return not ctx.stopped and workspace:GetServerTimeNow() < ctx.endTime
	end
	-- intervalo ajustado por intensidad (mas intensidad = mas a menudo)
	function ctx.rate(seconds)
		return seconds / ctx.intensity
	end

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
					list[#list + 1] = { player = p, humanoid = hum, root = root, char = char }
				end
			end
		end
		return list
	end

	function ctx.damage(entry, amount)
		if entry.humanoid.Health > 0 and amount > 0 then
			entry.humanoid:SetAttribute("Causa", info.Title)
			entry.humanoid:TakeDamage(amount)
		end
	end
	function ctx.kill(entry)
		if entry.humanoid.Health > 0 and not entry.char:FindFirstChildOfClass("ForceField") then
			entry.humanoid:SetAttribute("Causa", info.Title)
			entry.humanoid.Health = 0
		end
	end
	function ctx.holding(entry, gear)
		return holding(entry.char, gear)
	end

	function ctx.randomPoint()
		local bb = ctx.bounds
		return bb.x1 + math.random() * (bb.x2 - bb.x1), bb.z1 + math.random() * (bb.z2 - bb.z1)
	end
	-- punto cerca de un jugador al azar (con probabilidad prob) o al azar en el mapa
	function ctx.targetPoint(prob, spread)
		local list = ctx.players()
		if #list > 0 and math.random() < (prob or 0.5) then
			local p = list[math.random(#list)].root.Position
			local bb = ctx.bounds
			local s = spread or 20
			return math.clamp(p.X + (math.random() - 0.5) * 2 * s, bb.x1, bb.x2), math.clamp(p.Z + (math.random() - 0.5) * 2 * s, bb.z1, bb.z2)
		end
		return ctx.randomPoint()
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { current.Folder }
	rayParams.RespectCanCollide = true
	ctx.rayParams = rayParams

	function ctx.groundY(x, z)
		local bb = ctx.bounds
		local hit = workspace:Raycast(Vector3.new(x, bb.top + 30, z), Vector3.new(0, -(bb.top - bb.floor + 200), 0), rayParams)
		return hit and hit.Position.Y or nil
	end
	-- hay techo encima de este jugador?
	function ctx.covered(entry, height)
		local origin = entry.root.Position + Vector3.new(0, 2.5, 0)
		return workspace:Raycast(origin, Vector3.new(0, height or 300, 0), rayParams) ~= nil
	end

	function ctx.fx(kind, ...)
		DisasterFX:FireAllClients(kind, ctx.id, ...)
	end

	function ctx.tween(inst, seconds, goal)
		TweenService:Create(inst, TweenInfo.new(seconds, Enum.EasingStyle.Linear), goal):Play()
	end

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

	return ctx
end

local function stopContext(ctx)
	if ctx.stopped then
		return
	end
	ctx.stopped = true
	for i = #ctx.stopCallbacks, 1, -1 do
		pcall(ctx.stopCallbacks[i])
	end
	ctx.folder:Destroy()
	DisasterFX:FireAllClients("end", ctx.id)
	for i, c in ipairs(active) do
		if c == ctx then
			table.remove(active, i)
			break
		end
	end
end

function DisasterService.StopAll()
	for i = #active, 1, -1 do
		stopContext(active[i])
	end
	DisasterFX:FireAllClients("clear")
end
DisasterService.Stop = DisasterService.StopAll

function DisasterService.Start(current, duration, name, opts)
	opts = opts or {}
	if not current or not current.Def then
		return nil
	end
	name = name or DisasterService.Pick(current)
	if not name then
		return nil
	end
	local module = Disasters:FindFirstChild(name)
	if not module then
		warn("DisasterService: no existe el desastre '" .. tostring(name) .. "'")
		return nil
	end
	local disaster = require(module)
	local delay = opts.delay or Config.DisasterDelay
	local ctx = buildContext(current, duration + delay, name, opts)
	active[#active + 1] = ctx
	local info = ctx.info

	local shown = opts.mystery and DisasterInfo.Mystery or info
	DisasterFX:FireAllClients("banner", ctx.id, {
		Title = shown.Title,
		Desc = shown.Desc,
		Icon = shown.Icon,
		Color = shown.Color,
	}, delay)

	task.spawn(function()
		task.wait(delay)
		if ctx.stopped then
			return
		end
		ctx.startTime = workspace:GetServerTimeNow()
		ctx.duration = math.max(1, ctx.endTime - ctx.startTime)
		if opts.mystery then
			DisasterFX:FireAllClients("banner", ctx.id, { Title = info.Title, Desc = info.Desc, Icon = info.Icon, Color = info.Color }, 0)
		end
		DisasterFX:FireAllClients("start", ctx.id, name)
		local ok, err = pcall(disaster.Run, ctx)
		if not ok then
			warn("DisasterService: error en el desastre " .. name .. ": " .. tostring(err))
		end
	end)

	return { Id = ctx.id, Name = name, Title = info.Title, Icon = info.Icon, Description = info.Desc, Color = info.Color }
end

return DisasterService
