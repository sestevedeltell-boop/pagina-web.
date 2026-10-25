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
