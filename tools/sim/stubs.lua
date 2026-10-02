-- Simulador minimo de la API de Roblox para probar los scripts fuera de Studio.
-- Solo cubre lo que usan los scripts de este proyecto.

local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ handlers = {} }, Signal) end
function Signal:Connect(fn)
	table.insert(self.handlers, fn)
	return { Disconnect = function() end }
end
function Signal:Fire(...)
	for _, h in ipairs(self.handlers) do h(...) end
end
function Signal:Wait() end

-- Vector3
local V3 = {}
V3.__index = V3
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3 = { new = v3 }

-- CFrame (solo posicion + angulos, suficiente para pruebas)
local CF = {}
CF.__index = CF
local function cf(pos, rot) return setmetatable({ Position = pos, Rot = rot or v3(0, 0, 0) }, CF) end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then return a.Position + b end
	return cf(a.Position, v3(a.Rot.X + b.Rot.X, a.Rot.Y + b.Rot.Y, a.Rot.Z + b.Rot.Z))
end
CF.__add = function(a, b) return cf(a.Position + b, a.Rot) end
CFrame = {
	new = function(a, b, c)
		if getmetatable(a) == V3 then return cf(a) end
		return cf(v3(a or 0, b or 0, c or 0))
	end,
	Angles = function(x, y, z) return cf(v3(0, 0, 0), v3(x, y, z)) end,
}

Color3 = {
	new = function(r, g, b) return { R = r, G = g, B = b } end,
	fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end,
}
UDim = { new = function(a, b) return { Scale = a, Offset = b } end }
UDim2 = {
	new = function(a, b, c, d) return { a, b, c, d } end,
	fromScale = function(a, b) return { a, 0, b, 0 } end,
}
TweenInfo = { new = function(t) return { Time = t } end }

Enum = setmetatable({}, { __index = function(t, k)
	local e = setmetatable({}, { __index = function(_, n) return k .. "." .. n end })
	rawset(t, k, e)
	return e
end })

-- Instance
local Inst = {}
local methods = {}
local EVENTS = {
	Touched = 1, Changed = 1, Destroying = 1, MouseClick = 1, Triggered = 1, Activated = 1, Completed = 1,
	OnServerEvent = 1, OnClientEvent = 1, PlayerRemoving = 1, PlayerAdded = 1, ChildAdded = 1, Heartbeat = 1,
}
local CLASS_PARTS = { Part = 1, TrussPart = 1, SpawnLocation = 1 }

local function newInstance(class)
	return setmetatable({ _p = { ClassName = class, Name = class }, _children = {}, _signals = {} }, Inst)
end

Inst.__index = function(t, k)
	local m = methods[k]
	if m then return m end
	local v = rawget(t, "_p")[k]
	if v ~= nil then return v end
	for _, c in ipairs(rawget(t, "_children")) do
		if c._p.Name == k then return c end
	end
	if EVENTS[k] then
		local s = rawget(t, "_signals")
		s[k] = s[k] or Signal.new()
		return s[k]
	end
	return nil
end

Inst.__newindex = function(t, k, v)
	local p = rawget(t, "_p")
	if k == "Parent" then
		local old = p.Parent
		if old then
			for i, c in ipairs(old._children) do
				if c == t then table.remove(old._children, i) break end
			end
		end
		p.Parent = v
		if v then table.insert(v._children, t) end
		return
	end
	p[k] = v
	if k == "CFrame" then p.Position = v.Position
	elseif k == "Position" then p.CFrame = cf(v, p.CFrame and p.CFrame.Rot)
	elseif k == "Value" then
		local s = rawget(t, "_signals")
		if s.Changed then s.Changed:Fire(v) end
	end
end

local function descendants(inst, out)
	for _, c in ipairs(inst._children) do
		out[#out + 1] = c
		descendants(c, out)
	end
	return out
end

function methods.GetChildren(self) return { table.unpack(self._children) } end
function methods.GetDescendants(self) return descendants(self, {}) end
function methods.FindFirstChild(self, name)
	for _, c in ipairs(self._children) do if c._p.Name == name then return c end end
end
function methods.FindFirstChildOfClass(self, cls)
	for _, c in ipairs(self._children) do if c._p.ClassName == cls then return c end end
end
function methods.WaitForChild(self, name)
	local c = methods.FindFirstChild(self, name)
	if not c then error("WaitForChild: no existe " .. name .. " en " .. self._p.Name, 2) end
	return c
end
function methods.IsA(self, cls)
	local c = self._p.ClassName
	if c == cls then return true end
	if cls == "BasePart" and CLASS_PARTS[c] then return true end
	return false
end
function methods.Destroy(self)
	local s = rawget(self, "_signals")
	if s.Destroying then s.Destroying:Fire() end
	for _, d in ipairs(descendants(self, {})) do
		local ds = rawget(d, "_signals")
		if ds.Destroying then ds.Destroying:Fire() end
	end
	self.Parent = nil
end
function methods.GetPivot(self)
	local pp = self._p.PrimaryPart
	return pp and pp._p.CFrame or cf(v3(0, 0, 0))
end
function methods.PivotTo(self, target)
	local cur = methods.GetPivot(self)
	local delta = target.Position - cur.Position
	for _, d in ipairs(descendants(self, {})) do
		if CLASS_PARTS[d._p.ClassName] then
			d.Position = d._p.Position + delta
		end
	end
end
function methods.GetServerTimeNow(self) return os.clock() end
function methods.FireAllClients(self, ...) self.OnClientEvent:Fire(...) end
function methods.FireClient(self, _, ...) self.OnClientEvent:Fire(...) end
function methods.FireServer(self, ...) self.OnServerEvent:Fire(...) end

Instance = { new = function(class) return newInstance(class) end }

-- task
task = {
	wait = function() return 0 end,
	spawn = function(f, ...)
		local co = coroutine.create(f)
		local ok, err = coroutine.resume(co, ...)
		if not ok then error(err, 0) end
		return co
	end,
	delay = function(_, f) f() end,
}
task.defer = task.spawn
warn = print
typeof = function(x)
	if type(x) == "table" and getmetatable(x) == Inst then return "Instance" end
	return type(x)
end
table.clone = function(t)
	local c = {}
	for k, v in pairs(t) do c[k] = v end
	return c
end
table.unpack = table.unpack or unpack

-- Servicios
local services = {}
workspace = newInstance("Workspace")
workspace._p.Name = "Workspace"
workspace.Gravity = 196.2
FAKE_PLAYERS = {}
services.Players = {
	GetPlayers = function() return FAKE_PLAYERS end,
	PlayerRemoving = Signal.new(),
	PlayerAdded = Signal.new(),
}
services.Lighting = { ClockTime = 12, Brightness = 1, Ambient = "a", OutdoorAmbient = "oa", FogColor = "fc", FogStart = 0, FogEnd = 100000 }
services.ServerStorage = newInstance("ServerStorage")
services.ReplicatedStorage = newInstance("ReplicatedStorage")
services.RunService = { Heartbeat = Signal.new() }
services.TweenService = {
	Create = function(_, inst, _, goal)
		return {
			Play = function() for k, v in pairs(goal) do inst[k] = v end end,
			Completed = Signal.new(),
		}
	end,
}
game = { GetService = function(_, name) return services[name] or error("servicio no simulado: " .. name) end }

-- require y arbol de scripts a partir de FILES
local loaded = {}
function require(node)
	if loaded[node] ~= nil then return loaded[node] end
	local env = setmetatable({ script = node }, { __index = _G })
	local chunk, err = load(node._p.Source, "=" .. node._p.Name, "t", env)
	if not chunk then error(err) end
	local result = chunk()
	loaded[node] = result == nil and true or result
	return loaded[node]
end

function BuildTree()
	local roots = {
		["src/shared"] = { services.ReplicatedStorage, "IslasShared" },
		["src/maps"] = { services.ServerStorage, "IslasMapas" },
	}
	local function ensureFolder(parent, name)
		local f = methods.FindFirstChild(parent, name)
		if not f then
			f = newInstance("Folder")
			f.Name = name
			f.Parent = parent
		end
		return f
	end
	for path, source in pairs(FILES) do
		for prefix, target in pairs(roots) do
			if path:sub(1, #prefix + 1) == prefix .. "/" then
				local rel = path:sub(#prefix + 2)
				local parent = ensureFolder(target[1], target[2])
				local parts = {}
				for seg in rel:gmatch("[^/]+") do parts[#parts + 1] = seg end
				for i = 1, #parts - 1 do parent = ensureFolder(parent, parts[i]) end
				local file = parts[#parts]:gsub("%.lua$", "")
				local node = newInstance("ModuleScript")
				node.Name = file
				node.Source = source
				node.Parent = parent
			end
		end
	end
	-- fuente de los scripts del servidor (se prueban aparte)
	local serverFolder = newInstance("Folder")
	serverFolder.Name = "IslasServer"
	for path, source in pairs(FILES) do
		if path:sub(1, 11) == "src/server/" then
			local node = newInstance("ModuleScript")
			node.Name = path:sub(12):gsub("%.server%.lua$", ""):gsub("%.lua$", "")
			node.Source = source
			node.Parent = serverFolder
		end
	end
	return serverFolder
end

NewInstance = newInstance
InstMethods = methods
