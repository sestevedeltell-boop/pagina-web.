-- Simulador de la API de Roblox para probar los scripts fuera de Studio.
-- Incluye: planificador de hilos con reloj virtual (task.wait/spawn/delay/defer, Heartbeat),
-- instancias con atributos/etiquetas/clonado, consultas espaciales aproximadas (AABB),
-- raycast, DataStore en memoria, PhysicsService, CollectionService, tweens y remotos.
-- No simula fisica real: las piezas sueltas no caen.

-- =====================================================================
-- Planificador
-- =====================================================================
VCLOCK = 0
local FRAME = 1 / 30
local lastFrame = 0
local sleeping = {}
local managed = setmetatable({}, { __mode = "k" })
THREAD_ERRORS = {}

local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		local msg = debug.traceback(co, tostring(err))
		THREAD_ERRORS[#THREAD_ERRORS + 1] = msg
		print("ERROR EN HILO: " .. msg)
	end
end

local function newThread(f)
	if type(f) == "thread" then
		managed[f] = true
		return f
	end
	local co = coroutine.create(f)
	managed[co] = true
	return co
end

local function schedule(co, t, args)
	sleeping[#sleeping + 1] = { co = co, t = t, args = args or {}, n = args and args.n or 0 }
end

local heartbeatHandlers -- se rellena mas abajo

local function step(target)
	while true do
		local earliest, et = nil, math.huge
		for i, s in ipairs(sleeping) do
			if s.t < et then
				earliest, et = i, s.t
			end
		end
		local nextFrame = lastFrame + FRAME
		local tNext = math.min(nextFrame, et)
		if tNext > target then
			break
		end
		VCLOCK = math.max(VCLOCK, tNext)
		if earliest and et <= nextFrame then
			local s = table.remove(sleeping, earliest)
			resume(s.co, table.unpack(s.args, 1, s.n))
		else
			lastFrame = nextFrame
			heartbeatHandlers(FRAME)
		end
	end
	VCLOCK = math.max(VCLOCK, target)
end

local function inManagedThread()
	local co, isMain = coroutine.running()
	return (not isMain) and managed[co] and co or nil
end

task = {}
function task.wait(t)
	t = math.max(t or 0, FRAME)
	local co = inManagedThread()
	if co then
		schedule(co, VCLOCK + t)
		coroutine.yield()
	else
		step(VCLOCK + t)
	end
	return t
end
function task.spawn(f, ...)
	local co = newThread(f)
	resume(co, ...)
	return co
end
function task.defer(f, ...)
	local co = newThread(f)
	schedule(co, VCLOCK, table.pack(...))
	return co
end
function task.delay(t, f, ...)
	local co = newThread(f)
	schedule(co, VCLOCK + (t or 0), table.pack(...))
	return co
end
function task.cancel(co)
	for i = #sleeping, 1, -1 do
		if sleeping[i].co == co then
			table.remove(sleeping, i)
		end
	end
end
function SimAdvance(seconds)
	step(VCLOCK + seconds)
end
function SimPending()
	return #sleeping
end
wait = task.wait
spawn = task.spawn
delay = task.delay
tick = function() return VCLOCK end
time = function() return VCLOCK end
warn = function(...) print("WARN:", ...) end

-- =====================================================================
-- Senales
-- =====================================================================
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ handlers = {}, waiters = {} }, Signal) end
function Signal:Connect(fn)
	local h = { fn = fn, connected = true }
	table.insert(self.handlers, h)
	local sig = self
	return {
		Connected = true,
		Disconnect = function(c)
			h.connected = false
			c.Connected = false
			for i, x in ipairs(sig.handlers) do
				if x == h then table.remove(sig.handlers, i) break end
			end
		end,
	}
end
function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		fn(...)
	end)
	return c
end
function Signal:Fire(...)
	local list = { table.unpack(self.handlers) }
	for _, h in ipairs(list) do
		if h.connected then task.spawn(h.fn, ...) end
	end
	local waiters = self.waiters
	self.waiters = {}
	for _, co in ipairs(waiters) do resume(co, ...) end
end
function Signal:Wait()
	local co = inManagedThread()
	if co then
		table.insert(self.waiters, co)
		return coroutine.yield()
	end
end
NewSignal = Signal.new

-- =====================================================================
-- Tipos de datos
-- =====================================================================
local V3 = {}
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
V3.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		if m == 0 then return v3(0 / 0, 0 / 0, 0 / 0) end
		return v3(t.X / m, t.Y / m, t.Z / m)
	end
	return V3[k]
end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return string.format("%.2f, %.2f, %.2f", a.X, a.Y, a.Z) end
function V3.Lerp(a, b, t) return a + (b - a) * t end
function V3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V3.Cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V3.Abs(a) return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z)) end
function V3.Max(a, b) return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
function V3.Min(a, b) return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
function V3.FuzzyEq(a, b, e) return (a - b).Magnitude <= (e or 1e-5) end
Vector3 = {
	new = v3,
	zero = v3(0, 0, 0),
	one = v3(1, 1, 1),
	xAxis = v3(1, 0, 0),
	yAxis = v3(0, 1, 0),
	zAxis = v3(0, 0, 1),
}
IsVector3 = function(x) return getmetatable(x) == V3 end

local V2 = {}
V2.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y) end
	return V2[k]
end
local function v2(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end
V2.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b)
	if type(b) == "number" then return v2(a.X * b, a.Y * b) end
	return v2(a.X * b.X, a.Y * b.Y)
end
Vector2 = { new = v2, zero = v2(0, 0), one = v2(1, 1) }

-- CFrame: posicion + angulos (aproximado, sin matrices)
local CF = {}
local function cf(pos, rot) return setmetatable({ Position = pos, Rot = rot or v3(0, 0, 0) }, CF) end
CF.__index = function(t, k)
	if k == "LookVector" then
		local ry = t.Rot.Y
		return v3(-math.sin(ry), 0, -math.cos(ry))
	elseif k == "RightVector" then
		local ry = t.Rot.Y
		return v3(math.cos(ry), 0, -math.sin(ry))
	elseif k == "UpVector" then
		return v3(0, 1, 0)
	elseif k == "X" then return t.Position.X
	elseif k == "Y" then return t.Position.Y
	elseif k == "Z" then return t.Position.Z
	end
	return CF[k]
end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then return a.Position + b end
	return cf(a.Position + b.Position, v3(a.Rot.X + b.Rot.X, a.Rot.Y + b.Rot.Y, a.Rot.Z + b.Rot.Z))
end
CF.__add = function(a, b) return cf(a.Position + b, a.Rot) end
CF.__sub = function(a, b) return cf(a.Position - b, a.Rot) end
function CF.Inverse(a) return cf(-a.Position, -a.Rot) end
function CF.PointToWorldSpace(a, p) return a.Position + p end
function CF.PointToObjectSpace(a, p) return p - a.Position end
function CF.VectorToWorldSpace(a, p) return p end
function CF.ToWorldSpace(a, b) return a * b end
function CF.ToObjectSpace(a, b) return cf(b.Position - a.Position, b.Rot - a.Rot) end
function CF.Lerp(a, b, t) return cf(a.Position:Lerp(b.Position, t), a.Rot:Lerp(b.Rot, t)) end
function CF.GetComponents(a) return a.Position.X, a.Position.Y, a.Position.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1 end
function CF.ToEulerAnglesXYZ(a) return a.Rot.X, a.Rot.Y, a.Rot.Z end
CFrame = {
	new = function(a, b, c)
		if getmetatable(a) == V3 then
			return cf(a)
		end
		return cf(v3(a or 0, b or 0, c or 0))
	end,
	Angles = function(x, y, z) return cf(v3(0, 0, 0), v3(x or 0, y or 0, z or 0)) end,
	lookAt = function(p, target)
		local d = target - p
		return cf(p, v3(0, math.atan(-d.X, -d.Z), 0))
	end,
	identity = nil,
}
CFrame.fromEulerAnglesXYZ = CFrame.Angles
CFrame.fromOrientation = CFrame.Angles
CFrame.fromAxisAngle = function() return cf(v3(0, 0, 0)) end
CFrame.identity = cf(v3(0, 0, 0))

local C3 = {}
C3.__index = C3
local function c3(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end
function C3.Lerp(a, b, t) return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
function C3.ToHSV(a) return 0, 0, math.max(a.R, a.G, a.B) end
C3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
Color3 = {
	new = c3,
	fromRGB = function(r, g, b) return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end,
	fromHSV = function(h, s, v) return c3(v, v * (1 - s), v * (1 - s * h)) end,
	fromHex = function() return c3(1, 1, 1) end,
}

local UD2 = {}
UD2.__index = UD2
local function ud2(a, b, c, d) return setmetatable({ X = { Scale = a or 0, Offset = b or 0 }, Y = { Scale = c or 0, Offset = d or 0 } }, UD2) end
UD2.__add = function(p, q) return ud2(p.X.Scale + q.X.Scale, p.X.Offset + q.X.Offset, p.Y.Scale + q.Y.Scale, p.Y.Offset + q.Y.Offset) end
UD2.__sub = function(p, q) return ud2(p.X.Scale - q.X.Scale, p.X.Offset - q.X.Offset, p.Y.Scale - q.Y.Scale, p.Y.Offset - q.Y.Offset) end
function UD2.Lerp(p, q, t) return q end
UDim = { new = function(a, b) return { Scale = a or 0, Offset = b or 0 } end }
UDim2 = {
	new = ud2,
	fromScale = function(a, b) return ud2(a, 0, b, 0) end,
	fromOffset = function(a, b) return ud2(0, a, 0, b) end,
}
Rect = { new = function(...) return { ... } end }
NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end }
NumberSequence = { new = function(a) return { Keypoints = a } end }
NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
ColorSequence = { new = function(a) return { Keypoints = a } end }
ColorSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
PhysicalProperties = { new = function(...) return { ... } end }
BrickColor = { new = function(n) return { Name = n, Color = c3(1, 1, 1) } end, random = function() return { Color = c3(1, 1, 1) } end }
TweenInfo = { new = function(t, style, dir, reps, rev, dly) return { Time = t or 1, RepeatCount = reps or 0, Reverses = rev } end }
DateTime = { now = function() return { UnixTimestamp = os.time() + math.floor(VCLOCK), UnixTimestampMillis = (os.time() + VCLOCK) * 1000 } end }
local function newParams() return { FilterType = "Exclude", FilterDescendantsInstances = {}, RespectCanCollide = false, CollisionGroup = "Default", MaxParts = 0 } end
RaycastParams = { new = newParams }
OverlapParams = { new = newParams }
Random = {
	new = function(seed)
		local r = {}
		function r.NextNumber(_, a, b)
			a, b = a or 0, b or 1
			return a + math.random() * (b - a)
		end
		function r.NextInteger(_, a, b) return math.random(a, b) end
		function r.NextUnitVector() return v3(1, 0, 0) end
		return r
	end,
}

Enum = setmetatable({}, { __index = function(t, k)
	local e = setmetatable({}, { __index = function(et, n)
		local item = setmetatable({ Name = n, EnumType = k, Value = 0 }, { __tostring = function() return "Enum." .. k .. "." .. n end })
		rawset(et, n, item)
		return item
	end })
	e.GetEnumItems = function() return {} end
	rawset(t, k, e)
	return e
end })

-- funciones de Luau que no existen en Lua 5.3
math.clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end
math.round = function(v) return math.floor(v + 0.5) end
math.sign = function(v) return v > 0 and 1 or (v < 0 and -1 or 0) end
math.noise = function(x, y, z) return (math.sin((x or 0) * 12.9898 + (y or 0) * 78.233 + (z or 0) * 37.719) * 0.5) end
math.log10 = math.log10 or function(x) return math.log(x, 10) end
math.pow = math.pow or function(a, b) return a ^ b end
table.clone = function(t)
	local c = {}
	for k, v in pairs(t) do c[k] = v end
	return c
end
table.find = function(t, v, init)
	for i = init or 1, #t do
		if t[i] == v then return i end
	end
	return nil
end
table.create = function(n, v)
	local t = {}
	for i = 1, n do t[i] = v end
	return t
end
table.freeze = function(t) return t end
table.isfrozen = function() return false end
table.clear = function(t)
	for k in pairs(t) do t[k] = nil end
end
table.unpack = table.unpack or unpack
table.pack = table.pack or function(...) return { n = select("#", ...), ... } end
string.split = function(s, sep)
	sep = sep or ","
	local out = {}
	local start = 1
	while true do
		local i, j = string.find(s, sep, start, true)
		if not i then
			out[#out + 1] = s:sub(start)
			break
		end
		out[#out + 1] = s:sub(start, i - 1)
		start = j + 1
	end
	return out
end

-- =====================================================================
-- Instancias
-- =====================================================================
local Inst = {}
local methods = {}
local EVENTS = {}
for _, n in ipairs({
	"Touched", "TouchEnded", "Changed", "Destroying", "MouseClick", "Triggered", "TriggerEnded", "Activated", "Deactivated",
	"Equipped", "Unequipped", "Completed", "OnServerEvent", "OnClientEvent", "PlayerRemoving", "PlayerAdded",
	"ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "Heartbeat", "RenderStepped", "Stepped",
	"PostSimulation", "PreSimulation", "Died", "HealthChanged", "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded",
	"AncestryChanged", "InputBegan", "InputEnded", "InputChanged", "MouseButton1Click", "MouseButton1Down", "MouseEnter",
	"MouseLeave", "FocusLost", "Event", "PromptTriggered", "PromptShown", "PromptHidden", "StateChanged", "Running",
	"Chatted", "Jumping", "FreeFalling", "Seated", "Idled", "MoveToFinished", "Button1Down", "Button1Up", "Move",
	"JumpRequest", "WindowFocused", "WindowFocusReleased", "Played", "Ended", "Stopped", "Loaded", "DidLoop",
}) do
	EVENTS[n] = true
end
local PART_CLASSES = { Part = true, TrussPart = true, SpawnLocation = true, WedgePart = true, MeshPart = true, UnionOperation = true, Seat = true, VehicleSeat = true, CornerWedgePart = true }
local SCRIPT_CLASSES = { Script = true, LocalScript = true, ModuleScript = true }
local GUI_CLASSES = {
	Frame = true, TextLabel = true, TextButton = true, ImageLabel = true, ImageButton = true, ScrollingFrame = true,
	TextBox = true, ViewportFrame = true, CanvasGroup = true,
}
local VALUE_CLASSES = { IntValue = 0, NumberValue = 0, StringValue = "", BoolValue = false, ObjectValue = false, CFrameValue = true, Vector3Value = true, Color3Value = true }

local nextUserId = 1000
local CLASS_DEFAULTS = {}
local function defaultsFor(class, p)
	if PART_CLASSES[class] then
		p.Anchored = false
		p.CanCollide = true
		p.CanTouch = true
		p.CanQuery = true
		p.Transparency = 0
		p.Reflectance = 0
		p.Size = v3(4, 1, 2)
		p.CFrame = cf(v3(0, 0, 0))
		p.Position = v3(0, 0, 0)
		p.Orientation = v3(0, 0, 0)
		p.Color = c3(0.64, 0.64, 0.64)
		p.Material = Enum.Material.Plastic
		p.CollisionGroup = "Default"
		p.AssemblyLinearVelocity = v3(0, 0, 0)
		p.AssemblyAngularVelocity = v3(0, 0, 0)
		p.Massless = false
		p.CastShadow = true
		p.Locked = false
		p.Shape = Enum.PartType.Block
	elseif class == "Humanoid" then
		p.Health = 100
		p.MaxHealth = 100
		p.WalkSpeed = 16
		p.JumpPower = 50
		p.JumpHeight = 7.2
		p.UseJumpPower = false
		p.HipHeight = 2
		p.CameraOffset = v3(0, 0, 0)
		p.DisplayName = ""
		p.FloorMaterial = Enum.Material.Air
		p.MoveDirection = v3(0, 0, 0)
	elseif class == "Player" then
		nextUserId = nextUserId + 1
		p.UserId = nextUserId
		p.DisplayName = "Jugador" .. nextUserId
		p.AccountAge = 30
	elseif class == "Camera" then
		p.CFrame = cf(v3(0, 10, 0))
		p.FieldOfView = 70
		p.ViewportSize = v2(1280, 720)
		p.CameraType = Enum.CameraType.Custom
	elseif GUI_CLASSES[class] then
		p.Visible = true
		p.Size = ud2(0, 100, 0, 100)
		p.Position = ud2(0, 0, 0, 0)
		p.AbsoluteSize = v2(100, 100)
		p.AbsolutePosition = v2(0, 0)
		p.BackgroundTransparency = 0
		p.Text = ""
		p.TextTransparency = 0
		p.ZIndex = 1
		p.Rotation = 0
		p.CanvasSize = ud2(0, 0, 0, 0)
	elseif class == "ScreenGui" then
		p.Enabled = true
		p.AbsoluteSize = v2(1280, 720)
	elseif class == "Sound" then
		p.Volume = 0.5
		p.Playing = false
		p.TimeLength = 1
		p.IsLoaded = true
	elseif class == "Tool" then
		p.Enabled = true
		p.RequiresHandle = true
		p.CanBeDropped = true
	elseif class == "ProximityPrompt" then
		p.Enabled = true
		p.MaxActivationDistance = 10
	elseif VALUE_CLASSES[class] ~= nil then
		local d = VALUE_CLASSES[class]
		if d ~= true and d ~= false then p.Value = d elseif d == false and class == "BoolValue" then p.Value = false end
	elseif class == "UIListLayout" or class == "UIGridLayout" then
		p.AbsoluteContentSize = v2(100, 100)
	elseif class == "Model" then
		p.WorldPivot = cf(v3(0, 0, 0))
	elseif class == "Animator" then
	end
end

-- cada cambio de una pieza invalida el indice espacial de su carpeta superior
local spatialVersion = setmetatable({}, { __mode = "k" })
local function touchSpatial(inst)
	local p = inst
	while p do
		spatialVersion[p] = (spatialVersion[p] or 0) + 1
		p = rawget(p, "_p").Parent
	end
end

local function newInstance(class)
	local o = setmetatable({
		_p = { ClassName = class, Name = class, Archivable = true },
		_children = {},
		_signals = {},
		_attrs = {},
		_tags = {},
		_propSignals = {},
		_attrSignals = {},
	}, Inst)
	defaultsFor(class, o._p)
	return o
end

local SPECIAL_GET = {}
function SPECIAL_GET.AssemblyMass(t)
	local s = t._p.Size
	return s and s.X * s.Y * s.Z * 0.7 or 0
end
SPECIAL_GET.Mass = SPECIAL_GET.AssemblyMass
function SPECIAL_GET.AssemblyRootPart(t) return t end
function SPECIAL_GET.Orientation(t)
	local r = t._p.CFrame and t._p.CFrame.Rot or v3(0, 0, 0)
	return v3(math.deg(r.X), math.deg(r.Y), math.deg(r.Z))
end

Inst.__index = function(t, k)
	local m = methods[k]
	if m then return m end
	local p = rawget(t, "_p")
	local v = p[k]
	if v ~= nil then return v end
	local sg = SPECIAL_GET[k]
	if sg then return sg(t) end
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

local function fireProp(t, k)
	local ps = rawget(t, "_propSignals")[k]
	if ps then ps:Fire() end
end

Inst.__newindex = function(t, k, v)
	local p = rawget(t, "_p")
	if p._destroyedLock and k == "Parent" then
		error("The Parent property of " .. tostring(p.Name) .. " is locked", 2)
	end
	if k == "Parent" then
		local old = p.Parent
		if old == v then return end
		if old then
			for i, c in ipairs(old._children) do
				if c == t then table.remove(old._children, i) break end
			end
			touchSpatial(old)
			local s = rawget(old, "_signals")
			if s.ChildRemoved then s.ChildRemoved:Fire(t) end
		end
		p.Parent = v
		if v then
			table.insert(v._children, t)
			touchSpatial(v)
			local s = rawget(v, "_signals")
			if s.ChildAdded then s.ChildAdded:Fire(t) end
			local anc = v
			while anc do
				local as = rawget(anc, "_signals")
				if as.DescendantAdded then as.DescendantAdded:Fire(t) end
				anc = anc._p.Parent
			end
		end
		local s = rawget(t, "_signals")
		if s.AncestryChanged then s.AncestryChanged:Fire(t, v) end
		fireProp(t, "Parent")
		return
	end
	local old = p[k]
	if k == "Health" and p.ClassName == "Humanoid" then
		v = math.max(0, math.min(v, p.MaxHealth or 100))
	end
	p[k] = v
	if k == "CFrame" then
		p.Position = v.Position
		touchSpatial(t)
	elseif k == "Position" and PART_CLASSES[p.ClassName] then
		p.CFrame = cf(v, p.CFrame and p.CFrame.Rot)
		touchSpatial(t)
	elseif k == "Size" or k == "CanCollide" or k == "CanQuery" then
		touchSpatial(t)
	elseif k == "Value" then
		local s = rawget(t, "_signals")
		if s.Changed then s.Changed:Fire(v) end
	elseif k == "Health" and p.ClassName == "Humanoid" then
		local s = rawget(t, "_signals")
		if s.HealthChanged then s.HealthChanged:Fire(v) end
		if v <= 0 and (old or 0) > 0 then
			if s.Died then s.Died:Fire() end
			if not s.Died then
				-- se crea para que los que conecten tarde no se pierdan nada
			end
		end
	elseif k == "Character" and p.ClassName == "Player" and v then
		local s = rawget(t, "_signals")
		if s.CharacterAdded then s.CharacterAdded:Fire(v) end
	end
	if old ~= v then
		fireProp(t, k)
		if k ~= "Value" then
			local s = rawget(t, "_signals")
			if s.Changed and k ~= "Position" and k ~= "CFrame" then s.Changed:Fire(k) end
		end
	end
end
Inst.__tostring = function(t) return t._p.Name end

local function descendants(inst, out)
	for _, c in ipairs(inst._children) do
		out[#out + 1] = c
		descendants(c, out)
	end
	return out
end

local function isA(self, cls)
	local c = self._p.ClassName
	if c == cls or cls == "Instance" then return true end
	if cls == "BasePart" and PART_CLASSES[c] then return true end
	if cls == "PVInstance" and (PART_CLASSES[c] or c == "Model") then return true end
	if cls == "LuaSourceContainer" and SCRIPT_CLASSES[c] then return true end
	if cls == "BaseScript" and (c == "Script" or c == "LocalScript") then return true end
	if cls == "GuiObject" and GUI_CLASSES[c] then return true end
	if cls == "GuiButton" and (c == "TextButton" or c == "ImageButton") then return true end
	if cls == "LayerCollector" and (c == "ScreenGui" or c == "SurfaceGui" or c == "BillboardGui") then return true end
	if cls == "ValueBase" and VALUE_CLASSES[c] ~= nil then return true end
	if cls == "Light" and (c == "PointLight" or c == "SpotLight" or c == "SurfaceLight") then return true end
	if cls == "Constraint" and (c == "WeldConstraint" or c == "AlignPosition" or c == "VectorForce" or c == "LinearVelocity") then return true end
	if cls == "JointInstance" and (c == "Weld" or c == "Motor6D") then return true end
	if cls == "FormFactorPart" and (c == "Part" or c == "WedgePart" or c == "TrussPart") then return true end
	return false
end
methods.IsA = isA
function methods.GetChildren(self) return { table.unpack(self._children) } end
function methods.GetDescendants(self) return descendants(self, {}) end
function methods.FindFirstChild(self, name, recursive)
	for _, c in ipairs(self._children) do if c._p.Name == name then return c end end
	if recursive then
		for _, d in ipairs(descendants(self, {})) do if d._p.Name == name then return d end end
	end
end
function methods.FindFirstChildOfClass(self, cls)
	for _, c in ipairs(self._children) do if c._p.ClassName == cls then return c end end
end
function methods.FindFirstChildWhichIsA(self, cls, recursive)
	local list = recursive and descendants(self, {}) or self._children
	for _, c in ipairs(list) do if isA(c, cls) then return c end end
end
function methods.FindFirstAncestor(self, name)
	local p = self._p.Parent
	while p do
		if p._p.Name == name then return p end
		p = p._p.Parent
	end
end
function methods.FindFirstAncestorOfClass(self, cls)
	local p = self._p.Parent
	while p do
		if p._p.ClassName == cls then return p end
		p = p._p.Parent
	end
end
function methods.FindFirstAncestorWhichIsA(self, cls)
	local p = self._p.Parent
	while p do
		if isA(p, cls) then return p end
		p = p._p.Parent
	end
end
function methods.IsDescendantOf(self, anc)
	local p = self._p.Parent
	while p do
		if p == anc then return true end
		p = p._p.Parent
	end
	return false
end
function methods.IsAncestorOf(self, d) return methods.IsDescendantOf(d, self) end
function methods.GetFullName(self)
	local names = {}
	local p = self
	while p do
		table.insert(names, 1, p._p.Name)
		p = p._p.Parent
	end
	return table.concat(names, ".")
end
function methods.WaitForChild(self, name, timeout)
	local c = methods.FindFirstChild(self, name)
	if c then return c end
	local co = inManagedThread()
	if co then
		local limit = VCLOCK + (timeout or 30)
		while VCLOCK < limit do
			task.wait(0.1)
			c = methods.FindFirstChild(self, name)
			if c then return c end
		end
		if timeout then return nil end
	end
	error("WaitForChild: no existe " .. name .. " en " .. methods.GetFullName(self), 2)
end
function methods.ClearAllChildren(self)
	for _, c in ipairs({ table.unpack(self._children) }) do methods.Destroy(c) end
end
function methods.Destroy(self)
	local p = rawget(self, "_p")
	if p._destroyed then return end
	for _, d in ipairs(descendants(self, {})) do
		local ds = rawget(d, "_signals")
		d._p._destroyed = true
		if ds.Destroying then ds.Destroying:Fire() end
	end
	local s = rawget(self, "_signals")
	if s.Destroying then s.Destroying:Fire() end
	self.Parent = nil
	p._destroyed = true
	p._destroyedLock = true
end
function methods.Remove(self) self.Parent = nil end
function methods.Clone(self)
	if self._p.Archivable == false then return nil end
	local c = newInstance(self._p.ClassName)
	for k, v in pairs(self._p) do
		if k ~= "Parent" and k ~= "_destroyed" and k ~= "_destroyedLock" then c._p[k] = v end
	end
	for k, v in pairs(self._attrs) do c._attrs[k] = v end
	for k, v in pairs(self._tags) do c._tags[k] = v end
	for _, ch in ipairs(self._children) do
		local cc = methods.Clone(ch)
		if cc then cc.Parent = c end
	end
	-- PrimaryPart apunta a la copia
	if self._p.PrimaryPart then
		local idx
		local src = descendants(self, {})
		for i, d in ipairs(src) do if d == self._p.PrimaryPart then idx = i end end
		c._p.PrimaryPart = idx and descendants(c, {})[idx] or nil
	end
	return c
end
function methods.SetAttribute(self, k, v)
	self._attrs[k] = v
	local s = self._attrSignals[k]
	if s then s:Fire() end
end
function methods.GetAttribute(self, k) return self._attrs[k] end
function methods.GetAttributes(self) return table.clone(self._attrs) end
function methods.GetAttributeChangedSignal(self, k)
	self._attrSignals[k] = self._attrSignals[k] or Signal.new()
	return self._attrSignals[k]
end
function methods.GetPropertyChangedSignal(self, k)
	self._propSignals[k] = self._propSignals[k] or Signal.new()
	return self._propSignals[k]
end
local tagged = {}
local tagAdded = {}
function methods.AddTag(self, tag)
	if self._tags[tag] then return end
	self._tags[tag] = true
	tagged[tag] = tagged[tag] or setmetatable({}, { __mode = "k" })
	tagged[tag][self] = true
	if tagAdded[tag] then tagAdded[tag]:Fire(self) end
end
function methods.RemoveTag(self, tag)
	self._tags[tag] = nil
	if tagged[tag] then tagged[tag][self] = nil end
end
function methods.HasTag(self, tag) return self._tags[tag] == true end
function methods.GetTags(self)
	local out = {}
	for k in pairs(self._tags) do out[#out + 1] = k end
	return out
end

-- Modelos y piezas
local function partAABB(part)
	local p = part._p
	local s, pos = p.Size, p.Position
	local rot = p.CFrame and p.CFrame.Rot or v3(0, 0, 0)
	local sx, sy, sz = s.X, s.Y, s.Z
	local function c(a) return math.abs(math.cos(a)) end
	local function sn(a) return math.abs(math.sin(a)) end
	local bx, by = sx * c(rot.Z) + sy * sn(rot.Z), sx * sn(rot.Z) + sy * c(rot.Z)
	sx, sy = bx, by
	local bx2, bz = sx * c(rot.Y) + sz * sn(rot.Y), sx * sn(rot.Y) + sz * c(rot.Y)
	sx, sz = bx2, bz
	local by2, bz2 = sy * c(rot.X) + sz * sn(rot.X), sy * sn(rot.X) + sz * c(rot.X)
	sy, sz = by2, bz2
	return pos.X - sx / 2, pos.X + sx / 2, pos.Y - sy / 2, pos.Y + sy / 2, pos.Z - sz / 2, pos.Z + sz / 2
end
PartAABB = partAABB

local function boundingBox(self)
	local x1, x2, y1, y2, z1, z2 = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
	local any = false
	for _, d in ipairs(descendants(self, {})) do
		if PART_CLASSES[d._p.ClassName] then
			any = true
			local a, b, c, e, f, g = partAABB(d)
			x1, x2, y1, y2, z1, z2 = math.min(x1, a), math.max(x2, b), math.min(y1, c), math.max(y2, e), math.min(z1, f), math.max(z2, g)
		end
	end
	if not any then return cf(v3(0, 0, 0)), v3(0, 0, 0) end
	return cf(v3((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2)), v3(x2 - x1, y2 - y1, z2 - z1)
end
methods.GetBoundingBox = boundingBox
function methods.GetExtentsSize(self)
	local _, s = boundingBox(self)
	return s
end
function methods.GetPivot(self)
	if PART_CLASSES[self._p.ClassName] then return self._p.CFrame end
	local pp = self._p.PrimaryPart
	if pp then return pp._p.CFrame end
	local c = boundingBox(self)
	return c
end
function methods.PivotTo(self, target)
	if PART_CLASSES[self._p.ClassName] then
		self.CFrame = target
		return
	end
	local cur = methods.GetPivot(self)
	local delta = target.Position - cur.Position
	for _, d in ipairs(descendants(self, {})) do
		if PART_CLASSES[d._p.ClassName] then
			d.Position = d._p.Position + delta
		end
	end
end
methods.SetPrimaryPartCFrame = methods.PivotTo
function methods.GetMass(self) return SPECIAL_GET.AssemblyMass(self) end
function methods.SetNetworkOwner() end
function methods.SetNetworkOwnershipAuto() end
function methods.CanSetNetworkOwnership() return true end
function methods.GetNetworkOwner() return nil end
function methods.ApplyImpulse(self, imp)
	local m = SPECIAL_GET.AssemblyMass(self)
	self.AssemblyLinearVelocity = self._p.AssemblyLinearVelocity + imp / math.max(m, 1)
end
function methods.ApplyAngularImpulse() end
function methods.GetConnectedParts() return {} end
function methods.GetJoints() return {} end
function methods.BreakJoints() end
function methods.MakeJoints() end
function methods.GetTouchingParts() return {} end
function methods.Resize() return true end
function methods.ScaleTo() end

-- Humanoid
function methods.TakeDamage(self, n)
	if self._p.Health and n > 0 then
		local ff = self._p.Parent and methods.FindFirstChildOfClass(self._p.Parent, "ForceField")
		if ff then return end
		self.Health = self._p.Health - n
	end
end
function methods.ChangeState(self, s) self._p._state = s end
function methods.GetState(self) return self._p._state or Enum.HumanoidStateType.Running end
function methods.SetStateEnabled() end
function methods.MoveTo() end
function methods.EquipTool(self, tool) tool.Parent = self._p.Parent end
function methods.UnequipTools(self)
	local char = self._p.Parent
	if not char then return end
	for _, c in ipairs({ table.unpack(char._children) }) do
		if c._p.ClassName == "Tool" then c.Parent = nil end
	end
end
function methods.GetPlayingAnimationTracks() return {} end
function methods.LoadAnimation()
	return { Play = function() end, Stop = function() end, AdjustSpeed = function() end, Length = 1 }
end
function methods.ApplyDescription() end
function methods.GetAppliedDescription() return newInstance("HumanoidDescription") end

-- Sonido / animaciones / tweens de GUI
function methods.Play(self) self._p.Playing = true end
function methods.Stop(self) self._p.Playing = false end
function methods.Pause(self) self._p.Playing = false end
function methods.Resume(self) self._p.Playing = true end
function methods.TweenPosition() return true end
function methods.TweenSize() return true end
function methods.TweenSizeAndPosition() return true end
function methods.CaptureFocus() end
function methods.ReleaseFocus() end
function methods.Emit() end
function methods.Clear() end

-- Workspace / Players
function methods.GetServerTimeNow() return VCLOCK end
function methods.GetRealPhysicsFPS() return 60 end
function methods.GetNumAwakeParts() return 0 end
function methods.GetPlayers(self)
	local out = {}
	for _, c in ipairs(self._children) do
		if c._p.ClassName == "Player" then out[#out + 1] = c end
	end
	return out
end
function methods.GetPlayerFromCharacter(self, char)
	for _, c in ipairs(methods.GetPlayers(self)) do
		if c._p.Character == char then return c end
	end
end
function methods.GetPlayerByUserId(self, id)
	for _, c in ipairs(methods.GetPlayers(self)) do
		if c._p.UserId == id then return c end
	end
end
function methods.GetUserIdFromNameAsync() return 1 end
function methods.GetNameFromUserIdAsync(_, id) return "Jugador" .. tostring(id) end
function methods.GetUserThumbnailAsync() return "rbxassetid://0", true end
function methods.RequestStreamAroundAsync() end
function methods.Kick(self) self.Parent = nil end
function methods.LoadCharacter(self)
	local char = MakeCharacter(self._p.Name)
	if self._p.Character then methods.Destroy(self._p.Character) end
	char.Parent = workspace
	self.Character = char
end
function methods.GetMouse(self)
	return { Hit = cf(v3(0, 0, -50)), Target = nil, X = 0, Y = 0, Button1Down = Signal.new(), Button1Up = Signal.new(), Move = Signal.new(), Icon = "" }
end
function methods.IsInGroup() return false end
function methods.GetRankInGroup() return 0 end
function methods.GetFriendsOnline() return {} end
function methods.IsFriendsWith() return false end

-- Remotos y bindables
CLIENT_SENT = {}
function methods.FireAllClients(self, ...) self.OnClientEvent:Fire(...) end
function methods.FireClient(self, player, ...)
	if not LOCAL_PLAYER or player == LOCAL_PLAYER then self.OnClientEvent:Fire(...) end
end
function methods.FireServer(self, ...)
	CLIENT_SENT[#CLIENT_SENT + 1] = { name = self._p.Name, args = table.pack(...) }
	if SERVER_LISTENS then self.OnServerEvent:Fire(LOCAL_PLAYER, ...) end
end
function methods.InvokeServer(self, ...)
	CLIENT_SENT[#CLIENT_SENT + 1] = { name = self._p.Name, args = table.pack(...) }
	local f = self._p.OnServerInvoke
	if f then return f(LOCAL_PLAYER, ...) end
	return nil
end
function methods.InvokeClient(self, player, ...)
	local f = self._p.OnClientInvoke
	if f then return f(...) end
end
function methods.Fire(self, ...) self.Event:Fire(...) end
function methods.Invoke(self, ...)
	local f = self._p.OnInvoke
	if f then return f(...) end
end

-- Consultas espaciales (rejilla XZ por carpeta raiz, invalidada al cambiar piezas)
local CELL = 32
local gridCache = setmetatable({}, { __mode = "k" })
local function gridFor(root)
	local ver = spatialVersion[root] or 0
	local g = gridCache[root]
	if g and g.ver == ver then return g end
	g = { ver = ver, cells = {}, all = {} }
	local list = PART_CLASSES[root._p.ClassName] and { root } or descendants(root, {})
	if PART_CLASSES[root._p.ClassName] then
		for _, d in ipairs(descendants(root, {})) do list[#list + 1] = d end
	end
	for _, d in ipairs(list) do
		if PART_CLASSES[d._p.ClassName] then
			local x1, x2, y1, y2, z1, z2 = partAABB(d)
			local e = { part = d, x1 = x1, x2 = x2, y1 = y1, y2 = y2, z1 = z1, z2 = z2 }
			g.all[#g.all + 1] = e
			for cx = math.floor(x1 / CELL), math.floor(x2 / CELL) do
				for cz = math.floor(z1 / CELL), math.floor(z2 / CELL) do
					local key = cx * 100003 + cz
					local cell = g.cells[key]
					if not cell then
						cell = {}
						g.cells[key] = cell
					end
					cell[#cell + 1] = e
				end
			end
		end
	end
	gridCache[root] = g
	return g
end

local function rootsFor(params)
	params = params or newParams()
	local list = params.FilterDescendantsInstances or {}
	if params.FilterType == Enum.RaycastFilterType.Include or params.FilterType == Enum.RaycastFilterType.Whitelist then
		return list, nil
	end
	local excl = {}
	for _, x in ipairs(list) do excl[x] = true end
	return { workspace }, excl
end

local function excludedBy(part, excl)
	if not excl then return false end
	local p = part
	while p do
		if excl[p] then return true end
		p = p._p.Parent
	end
	return false
end

local function query(params, x1, x2, y1, y2, z1, z2, filterFn)
	local roots, excl = rootsFor(params)
	local seen, out = {}, {}
	for _, root in ipairs(roots) do
		if root._p and not root._p._destroyed then
			local g = gridFor(root)
			for cx = math.floor(x1 / CELL), math.floor(x2 / CELL) do
				for cz = math.floor(z1 / CELL), math.floor(z2 / CELL) do
					local cell = g.cells[cx * 100003 + cz]
					if cell then
						for _, e in ipairs(cell) do
							if not seen[e] and e.x2 >= x1 and e.x1 <= x2 and e.y2 >= y1 and e.y1 <= y2 and e.z2 >= z1 and e.z1 <= z2 then
								seen[e] = true
								local part = e.part
								if part._p.Parent and part._p.CanQuery ~= false and not excludedBy(part, excl) and (not filterFn or filterFn(e)) then
									if not (params and params.RespectCanCollide and part._p.CanCollide == false) then
										out[#out + 1] = part
									end
								end
							end
						end
					end
				end
			end
		end
	end
	return out
end

function methods.GetPartBoundsInBox(self, cframe, size, params)
	local p = cframe.Position
	return query(params, p.X - size.X / 2, p.X + size.X / 2, p.Y - size.Y / 2, p.Y + size.Y / 2, p.Z - size.Z / 2, p.Z + size.Z / 2)
end
function methods.GetPartBoundsInRadius(self, pos, r, params)
	return query(params, pos.X - r, pos.X + r, pos.Y - r, pos.Y + r, pos.Z - r, pos.Z + r, function(e)
		local cx = math.max(e.x1, math.min(pos.X, e.x2))
		local cy = math.max(e.y1, math.min(pos.Y, e.y2))
		local cz = math.max(e.z1, math.min(pos.Z, e.z2))
		local dx, dy, dz = cx - pos.X, cy - pos.Y, cz - pos.Z
		return dx * dx + dy * dy + dz * dz <= r * r
	end)
end
function methods.GetPartsInPart(self, part, params)
	local x1, x2, y1, y2, z1, z2 = partAABB(part)
	local out = {}
	for _, p in ipairs(query(params, x1, x2, y1, y2, z1, z2)) do
		if p ~= part then out[#out + 1] = p end
	end
	return out
end

-- Raycast contra AABBs (suficiente para pruebas)
function methods.Raycast(self, origin, dir, params)
	local len = dir.Magnitude
	if len == 0 then return nil end
	local ex = origin + dir
	local x1, x2 = math.min(origin.X, ex.X), math.max(origin.X, ex.X)
	local y1, y2 = math.min(origin.Y, ex.Y), math.max(origin.Y, ex.Y)
	local z1, z2 = math.min(origin.Z, ex.Z), math.max(origin.Z, ex.Z)
	local candidates = query(params, x1, x2, y1, y2, z1, z2)
	local best, bestT, bestN = nil, math.huge, nil
	for _, part in ipairs(candidates) do
		local a1, a2, b1, b2, c1, c2 = partAABB(part)
		local tmin, tmax = 0, 1
		local normal
		local ok = true
		for _, ax in ipairs({ { origin.X, dir.X, a1, a2, v3(-1, 0, 0), v3(1, 0, 0) }, { origin.Y, dir.Y, b1, b2, v3(0, -1, 0), v3(0, 1, 0) }, { origin.Z, dir.Z, c1, c2, v3(0, 0, -1), v3(0, 0, 1) } }) do
			local o, d, lo, hi = ax[1], ax[2], ax[3], ax[4]
			if math.abs(d) < 1e-9 then
				if o < lo or o > hi then ok = false break end
			else
				local t1, t2 = (lo - o) / d, (hi - o) / d
				local n1, n2 = ax[5], ax[6]
				if t1 > t2 then t1, t2, n1, n2 = t2, t1, n2, n1 end
				if t1 > tmin then tmin, normal = t1, n1 end
				if t2 < tmax then tmax = t2 end
				if tmin > tmax then ok = false break end
			end
		end
		if ok and tmin < bestT then
			best, bestT, bestN = part, tmin, normal or v3(0, 1, 0)
		end
	end
	if not best then return nil end
	return {
		Instance = best,
		Position = origin + dir * bestT,
		Normal = bestN,
		Distance = len * bestT,
		Material = best._p.Material,
	}
end
function methods.Blockcast(self, cframe, size, dir, params) return methods.Raycast(self, cframe.Position, dir, params) end
function methods.Spherecast(self, pos, r, dir, params) return methods.Raycast(self, pos, dir, params) end
function methods.FindPartOnRay() return nil end
function methods.ArePartsTouchingOthers() return false end
function methods.BulkMoveTo(self, parts, cframes)
	for i, p in ipairs(parts) do p.CFrame = cframes[i] end
end
function methods.WorldToViewportPoint(self, p) return v3(640, 360, 10), true end
function methods.WorldToScreenPoint(self, p) return v3(640, 360, 10), true end
function methods.ViewportPointToRay() return { Origin = v3(0, 0, 0), Direction = v3(0, 0, -1) } end
function methods.ScreenPointToRay() return { Origin = v3(0, 0, 0), Direction = v3(0, 0, -1) } end

Instance = {
	new = function(class, parent)
		local o = newInstance(class)
		if parent then o.Parent = parent end
		return o
	end,
}
IsInstance = function(x) return type(x) == "table" and getmetatable(x) == Inst end

typeof = function(x)
	local mt = getmetatable(x)
	if mt == Inst then return "Instance" end
	if mt == V3 then return "Vector3" end
	if mt == V2 then return "Vector2" end
	if mt == CF then return "CFrame" end
	if mt == C3 then return "Color3" end
	if mt == UD2 then return "UDim2" end
	if type(x) == "table" and x.EnumType then return "EnumItem" end
	return type(x)
end

-- =====================================================================
-- Servicios
-- =====================================================================
local services = {}
local function service(name, class)
	local s = newInstance(class or name)
	s._p.Name = name
	services[name] = s
	return s
end

workspace = service("Workspace")
workspace.Gravity = 196.2
workspace.FallenPartsDestroyHeight = -500
workspace.StreamingEnabled = false
workspace.DistributedGameTime = 0
Workspace = workspace
local terrain = newInstance("Terrain")
terrain._p.Name = "Terrain"
terrain.Parent = workspace

local Players = service("Players")
Players.MaxPlayers = 20
local Lighting = service("Lighting")
Lighting.ClockTime = 14
Lighting.Brightness = 2
Lighting.Ambient = c3(0.5, 0.5, 0.5)
Lighting.OutdoorAmbient = c3(0.5, 0.5, 0.5)
Lighting.FogColor = c3(0.75, 0.75, 0.75)
Lighting.FogStart = 0
Lighting.FogEnd = 100000
Lighting.ExposureCompensation = 0
Lighting.GlobalShadows = true
Lighting.ColorShift_Top = c3(0, 0, 0)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
service("ServerStorage")
service("ReplicatedStorage")
service("ServerScriptService")
service("ReplicatedFirst")
service("StarterGui")
service("StarterPack")
service("SoundService")
service("Teams")
service("Chat")
service("TextChatService")
local starterPlayer = service("StarterPlayer")
local sps = newInstance("StarterPlayerScripts")
sps._p.Name = "StarterPlayerScripts"
sps.Parent = starterPlayer
local scs = newInstance("StarterCharacterScripts")
scs._p.Name = "StarterCharacterScripts"
scs.Parent = starterPlayer
starterPlayer.CharacterWalkSpeed = 16

local RunService = service("RunService")
function methods.IsServer() return not LOCAL_PLAYER end
function methods.IsClient() return LOCAL_PLAYER ~= nil end
function methods.IsStudio() return true end
function methods.IsRunning() return true end
function methods.BindToRenderStep() end
function methods.UnbindFromRenderStep() end

heartbeatHandlers = function(dt)
	workspace._p.DistributedGameTime = VCLOCK
	for _, name in ipairs({ "Stepped", "PreSimulation", "Heartbeat", "PostSimulation", "RenderStepped" }) do
		local s = rawget(RunService, "_signals")[name]
		if s and #s.handlers > 0 then
			if name == "Stepped" then s:Fire(VCLOCK, dt) else s:Fire(dt) end
		end
	end
end

local TweenService = service("TweenService")
function methods.Create(self, inst, info, goal)
	if self ~= TweenService then error("Create solo en TweenService") end
	local tw = { PlaybackState = Enum.PlaybackState.Begin, Completed = Signal.new(), Instance = inst }
	function tw.Play(t)
		for k, v in pairs(goal) do inst[k] = v end
		tw.PlaybackState = Enum.PlaybackState.Playing
		if (info.RepeatCount or 0) >= 0 then
			task.delay(info.Time or 1, function()
				if tw.PlaybackState == Enum.PlaybackState.Playing then
					tw.PlaybackState = Enum.PlaybackState.Completed
					tw.Completed:Fire(Enum.PlaybackState.Completed)
				end
			end)
		end
	end
	function tw.Cancel() tw.PlaybackState = Enum.PlaybackState.Cancelled end
	function tw.Pause() tw.PlaybackState = Enum.PlaybackState.Paused end
	function tw.Destroy() end
	return tw
end
function methods.GetValue(self, alpha) return alpha end

local Debris = service("Debris")
function methods.AddItem(self, inst, t)
	task.delay(t or 10, function()
		if inst and inst._p and not inst._p._destroyed then methods.Destroy(inst) end
	end)
end

local PhysicsService = service("PhysicsService")
local groups = { Default = true }
local collidable = {}
function methods.RegisterCollisionGroup(self, name) groups[name] = true end
function methods.IsCollisionGroupRegistered(self, name) return groups[name] == true end
function methods.CollisionGroupSetCollidable(self, a, b, v)
	if not groups[a] or not groups[b] then error("grupo de colision no registrado: " .. a .. "/" .. b) end
	collidable[a .. "|" .. b] = v
	collidable[b .. "|" .. a] = v
end
function methods.CollisionGroupsAreCollidable(self, a, b)
	local v = collidable[a .. "|" .. b]
	if v == nil then return true end
	return v
end
function methods.GetRegisteredCollisionGroups()
	local out = {}
	for k in pairs(groups) do out[#out + 1] = { name = k } end
	return out
end
function methods.GetMaxCollisionGroups() return 32 end

local CollectionService = service("CollectionService")
function methods.GetTagged(self, tag)
	local out = {}
	for inst in pairs(tagged[tag] or {}) do
		if not inst._p._destroyed then out[#out + 1] = inst end
	end
	return out
end
function methods.GetInstanceAddedSignal(self, tag)
	tagAdded[tag] = tagAdded[tag] or Signal.new()
	return tagAdded[tag]
end
function methods.GetInstanceRemovedSignal() return Signal.new() end

-- CollectionService:AddTag(inst, tag) vs inst:AddTag(tag)
local instAddTag, instRemoveTag, instHasTag = methods.AddTag, methods.RemoveTag, methods.HasTag
methods.AddTag = function(self, a, b)
	if self == CollectionService then return instAddTag(a, b) end
	return instAddTag(self, a)
end
methods.RemoveTag = function(self, a, b)
	if self == CollectionService then return instRemoveTag(a, b) end
	return instRemoveTag(self, a)
end
methods.HasTag = function(self, a, b)
	if self == CollectionService then return instHasTag(a, b) end
	return instHasTag(self, a)
end

-- DataStore en memoria
DATASTORE_FAIL = false
DATASTORE_DATA = {}
local DataStoreService = service("DataStoreService")
local function makeStore(name, ordered)
	DATASTORE_DATA[name] = DATASTORE_DATA[name] or {}
	local data = DATASTORE_DATA[name]
	local store = {}
	local function check()
		if DATASTORE_FAIL then error("DataStore no disponible (simulado)") end
	end
	local function copy(v)
		if type(v) ~= "table" then return v end
		local c = {}
		for k, x in pairs(v) do c[k] = copy(x) end
		return c
	end
	function store.GetAsync(_, key) check() return copy(data[key]) end
	function store.SetAsync(_, key, v) check() data[key] = copy(v) end
	function store.UpdateAsync(_, key, fn)
		check()
		local nv = fn(copy(data[key]))
		if nv ~= nil then data[key] = copy(nv) end
		return copy(nv)
	end
	function store.IncrementAsync(_, key, n)
		check()
		data[key] = (data[key] or 0) + (n or 1)
		return data[key]
	end
	function store.RemoveAsync(_, key) check() data[key] = nil end
	if ordered then
		function store.GetSortedAsync(_, asc, size)
			check()
			local list = {}
			for k, v in pairs(data) do list[#list + 1] = { key = k, value = v } end
			table.sort(list, function(a, b)
				if asc then return a.value < b.value end
				return a.value > b.value
			end)
			local page = {}
			for i = 1, math.min(size or 50, #list) do page[i] = list[i] end
			return { GetCurrentPage = function() return page end, IsFinished = true, AdvanceToNextPageAsync = function() end }
		end
	end
	return store
end
function methods.GetDataStore(self, name) return makeStore(name, false) end
function methods.GetOrderedDataStore(self, name) return makeStore("ord_" .. name, true) end
function methods.GetRequestBudgetForRequestType() return 100 end

local MarketplaceService = service("MarketplaceService")
function methods.UserOwnsGamePassAsync() return false end
function methods.PromptGamePassPurchase() end
function methods.PromptProductPurchase() end
function methods.GetProductInfo() return { Name = "x", PriceInRobux = 0 } end

local BadgeService = service("BadgeService")
function methods.AwardBadge() return true end
function methods.UserHasBadgeAsync() return false end

local HttpService = service("HttpService")
local guid = 0
function methods.GenerateGUID()
	guid = guid + 1
	return "guid-" .. guid
end
function methods.JSONEncode(self, v) return tostring(v) end
function methods.JSONDecode() return {} end

local UserInputService = service("UserInputService")
UserInputService.TouchEnabled = false
UserInputService.KeyboardEnabled = true
UserInputService.MouseEnabled = true
UserInputService.GamepadEnabled = false
UserInputService.MouseBehavior = Enum.MouseBehavior.Default
function methods.IsKeyDown() return false end
function methods.GetMouseLocation() return v2(0, 0) end
function methods.GetLastInputType() return Enum.UserInputType.MouseButton1 end
function methods.IsMouseButtonPressed() return false end

local ContextActionService = service("ContextActionService")
function methods.BindAction() end
function methods.UnbindAction() end
function methods.SetTitle() end
function methods.SetPosition() end
function methods.GetButton() return nil end

local StarterGui = services.StarterGui
function methods.SetCore() end
function methods.GetCore() return nil end
function methods.SetCoreGuiEnabled() end
function methods.GetCoreGuiEnabled() return true end

local GuiService = service("GuiService")
function methods.GetGuiInset() return v2(0, 36), v2(0, 0) end
GuiService.MenuIsOpen = false

local TextService = service("TextService")
function methods.GetTextSize(self, text) return v2(#text * 8, 16) end

local SocialService = service("SocialService")
local PolicyService = service("PolicyService")
local ContentProvider = service("ContentProvider")
function methods.PreloadAsync() end
local LocalizationService = service("LocalizationService")
local Stats = service("Stats")
function methods.GetTotalMemoryUsageMb() return 500 end
local ProximityPromptService = service("ProximityPromptService")
local VRService = service("VRService")
local HapticService = service("HapticService")
local Teams = services.Teams
local Chat = services.Chat
local TeleportService = service("TeleportService")
local MessagingService = service("MessagingService")
function methods.SubscribeAsync() return { Disconnect = function() end } end
function methods.PublishAsync() end
local AnalyticsService = service("AnalyticsService")
function methods.LogCustomEvent() end
function methods.LogEconomyEvent() end
function methods.LogProgressionEvent() end

game = newInstance("DataModel")
game._p.Name = "Juego"
game._p.PlaceId = 0
game._p.JobId = "sim"
game._p.CreatorId = 0
for _, s in pairs(services) do s.Parent = game end
function methods.GetService(self, name)
	return services[name] or error("servicio no simulado: " .. name)
end
methods.FindService = function(self, name) return services[name] end
function methods.BindToClose(self, fn) BIND_TO_CLOSE = BIND_TO_CLOSE or {} BIND_TO_CLOSE[#BIND_TO_CLOSE + 1] = fn end
function methods.IsLoaded() return true end
game.Loaded = Signal.new()

-- =====================================================================
-- Ayudas para las pruebas
-- =====================================================================
function MakeCharacter(name)
	local char = newInstance("Model")
	char._p.Name = name or "Personaje"
	local root = newInstance("Part")
	root._p.Name = "HumanoidRootPart"
	root.Size = v3(2, 2, 1)
	root.Position = v3(0, 5, 0)
	root.Parent = char
	local head = newInstance("Part")
	head._p.Name = "Head"
	head.Size = v3(2, 1, 1)
	head.Position = v3(0, 6.5, 0)
	head.Parent = char
	local torso = newInstance("Part")
	torso._p.Name = "UpperTorso"
	torso.Parent = char
	local hum = newInstance("Humanoid")
	hum.Parent = char
	local animator = newInstance("Animator")
	animator.Parent = hum
	char.PrimaryPart = root
	for _, n in ipairs({ "RightHand", "LeftHand" }) do
		local p = newInstance("Part")
		p._p.Name = n
		p.Parent = char
		local a = newInstance("Attachment")
		a._p.Name = n == "RightHand" and "RightGripAttachment" or "LeftGripAttachment"
		a.Parent = p
	end
	local ra = newInstance("Attachment")
	ra._p.Name = "RootRigAttachment"
	ra.Parent = root
	return char
end

function MakePlayer(name, noCharacter)
	local pl = newInstance("Player")
	pl._p.Name = name or ("Jugador" .. pl._p.UserId)
	pl._p.DisplayName = pl._p.Name
	local backpack = newInstance("Backpack")
	backpack._p.Name = "Backpack"
	backpack.Parent = pl
	local pg = newInstance("PlayerGui")
	pg._p.Name = "PlayerGui"
	pg.Parent = pl
	local ps = newInstance("PlayerScripts")
	ps._p.Name = "PlayerScripts"
	ps.Parent = pl
	pl.Parent = Players
	local ps2 = rawget(Players, "_signals").PlayerAdded
	if ps2 then ps2:Fire(pl) end
	if not noCharacter then
		local char = MakeCharacter(pl._p.Name)
		char.Parent = workspace
		pl.Character = char
	end
	return pl
end

function RemovePlayer(pl)
	local s = rawget(Players, "_signals").PlayerRemoving
	if s then s:Fire(pl) end
	SimAdvance(0.1)
	pl.Parent = nil
end

-- =====================================================================
-- require y arbol de scripts a partir de FILES
-- =====================================================================
local loaded = {}
local loading = {}
function require(node)
	if type(node) ~= "table" then error("require: se esperaba un ModuleScript, llego " .. tostring(node), 2) end
	if loaded[node] ~= nil then return loaded[node] end
	if loading[node] then error("require circular: " .. methods.GetFullName(node), 2) end
	loading[node] = true
	local env = setmetatable({ script = node }, { __index = _G })
	local chunk, err = load(node._p.Source, "=" .. node._p.Name, "t", env)
	if not chunk then error(err) end
	local result = chunk()
	loading[node] = nil
	loaded[node] = result == nil and true or result
	return loaded[node]
end

-- Ejecuta un Script/LocalScript en su propio hilo (como hace Roblox)
function RunScript(node)
	local env = setmetatable({ script = node }, { __index = _G })
	local chunk, err = load(node._p.Source, "=" .. node._p.Name, "t", env)
	if not chunk then error(err) end
	return task.spawn(chunk)
end

local function ensureFolder(parent, name)
	local f = methods.FindFirstChild(parent, name)
	if not f then
		f = newInstance("Folder")
		f._p.Name = name
		f.Parent = parent
	end
	return f
end

-- Monta el arbol igual que default.project.json
function BuildTree()
	local roots = {
		["src/shared"] = { services.ReplicatedStorage, "IslasShared" },
		["src/maps"] = { services.ServerStorage, "IslasMapas" },
		["src/server"] = { services.ServerScriptService, "IslasServer" },
		["src/client"] = { sps, "IslasClient" },
	}
	for path, source in pairs(FILES) do
		for prefix, target in pairs(roots) do
			if path:sub(1, #prefix + 1) == prefix .. "/" then
				local rel = path:sub(#prefix + 2)
				local parent = ensureFolder(target[1], target[2])
				local parts = {}
				for seg in rel:gmatch("[^/]+") do parts[#parts + 1] = seg end
				for i = 1, #parts - 1 do parent = ensureFolder(parent, parts[i]) end
				local file = parts[#parts]
				local class = "ModuleScript"
				if file:match("%.server%.lua$") then
					class = "Script"
				elseif file:match("%.client%.lua$") then
					class = "LocalScript"
				end
				local node = newInstance(class)
				node._p.Name = file:gsub("%.server%.lua$", ""):gsub("%.client%.lua$", ""):gsub("%.lua$", "")
				node._p.Source = source
				node.Parent = parent
			end
		end
	end
	return services.ServerScriptService.IslasServer
end

NewInstance = newInstance
InstMethods = methods
Services = services
