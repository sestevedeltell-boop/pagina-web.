-- Destruction: destruccion estructural de los mapas.
--
-- Como funciona:
--  1. Al cargar un mapa se registran sus piezas (salvo isla, mar, spawns y ascensores).
--  2. En segundo plano (repartido entre frames) se calcula quien toca a quien: un grafo de apoyos.
--     Las piezas que tocan el suelo del mapa son "raices".
--  3. Cada pieza tiene vida segun su material y tamano. Los desastres hacen dano con DamageSphere, Damage,
--     Shake, DamageBox, Ignite...
--  4. Al romperse una pieza: si es pequena o de cristal se hace anicos (desaparece y los clientes generan
--     fragmentos locales, sin coste para el servidor); si es grande y hay presupuesto, se suelta con fisica.
--  5. Cada poco se comprueba que todo siga unido a una raiz. Lo que se queda colgando se DERRUMBA:
--     se agrupa en bloques soldados (pocos cuerpos fisicos, aunque tengan muchas piezas) que caen juntos
--     y al pararse se quedan como escombro anclado.
--  6. Las piezas se borran poco a poco (Config.HidePerFrame por frame) para evitar tirones.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Config"))
local Net = require(ReplicatedStorage.IslasShared:WaitForChild("Net"))
local PhysicsBudget = require(script.Parent.PhysicsBudget)

local ShatterEvent = Net.Event("Shatter")

local Destruction = {}

local MATERIAL_HP = {
	Glass = 8, ForceField = 8, Neon = 25, Fabric = 20, Foil = 30, Ice = 30, Snow = 35, Wood = 45, WoodPlanks = 45,
	Plastic = 60, SmoothPlastic = 60, Sand = 60, Ground = 110, Grass = 110, LeafyGrass = 110, Mud = 80,
	Brick = 130, Marble = 130, Concrete = 140, Pavement = 140, Slate = 150, Cobblestone = 150, Asphalt = 160,
	Rock = 170, Basalt = 180, Granite = 180, CorrodedMetal = 170, Metal = 200, DiamondPlate = 220,
}
local FLAMMABLE = { Wood = true, WoodPlanks = true, Fabric = true, Grass = true, LeafyGrass = true, Plastic = true }
local NOT_FRAGILE = { Isla = true, Mar = true, SpawnPoint = true, Roca = true, Orilla = true, HumanoidRootPart = true }
local DARK = Color3.new(0.12, 0.11, 0.1)
local BURNT = Color3.fromRGB(35, 30, 28)

local S = nil -- estado del mapa actual

local function clock()
	return workspace:GetServerTimeNow()
end

local function matName(part)
	local m = part.Material
	return typeof(m) == "EnumItem" and m.Name or tostring(m)
end

-- "cabin" si la pieza es de una cabina de ascensor (se mueve: se ignora), "shaft" si es del hueco
local function elevatorPart(part, root)
	local p = part.Parent
	while p and p ~= root do
		local n = p.Name
		if n:match("_Cabina$") then
			return "cabin"
		elseif n:match("_Hueco$") then
			return "shaft"
		end
		p = p.Parent
	end
	return nil
end

-- Media altura real de la pieza en el mundo (tiene en cuenta la rotacion: columnas cilindricas, etc.)
local function halfHeight(part)
	local s = part.Size
	local _, _, _, r00, r01, r02, r10, r11, r12 = part.CFrame:GetComponents()
	local _ = r00 + r01 + r02
	return 0.5 * (math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z)
end

local function maxHp(part)
	local s = part.Size
	local vol = s.X * s.Y * s.Z
	local base = MATERIAL_HP[matName(part)] or 100
	return base * math.clamp((vol / 24) ^ 0.33, 0.5, 2.2) * (S and S.toughness or 1)
end

-- ======================================================================
-- Registro y grafo
-- ======================================================================

function Destruction.IsActive()
	return S ~= nil
end

function Destruction.Begin(folder, floorY)
	Destruction.Reset()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }

	S = {
		folder = folder,
		floorY = floorY,
		params = params,
		ids = {}, -- [part] = id
		parts = {}, -- [id] = part
		alive = {}, -- [id] = bool
		root = {}, -- [id] = bool
		neigh = {}, -- [id] = { ids }
		hp = {}, -- [id] = vida actual (se calcula al primer golpe)
		fixed = {}, -- [id] = true si no se rompe nunca (huecos de ascensor, piezas indestructibles): apoyo fijo
		stage = {}, -- [id] = 0/1/2 (oscurecimiento por dano)
		graphReady = false,
		dirty = false,
		removeQueue = {},
		removeHead = 1,
		shatterQueue = {},
		burning = {}, -- [id] = { t = inicio, fire = Fire }
		burningCount = 0,
		toughness = 1,
		broken = 0,
		collapsed = 0,
		token = {},
	}
	PhysicsBudget.Reset()
	PhysicsBudget.SetKillY(floorY - 60)

	local n = 0
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			local elev = elevatorPart(d, folder)
			local indestructible = NOT_FRAGILE[d.Name] or d:GetAttribute("Indestructible") or elev == "shaft"
			local invisibleHelper = d.Transparency >= 0.95 and not d.CanCollide
			-- las cabinas se mueven y las piezas sin colision indestructibles (mar, spawns) no sujetan nada
			if elev ~= "cabin" and not invisibleHelper and not (indestructible and not d.CanCollide) then
				n = n + 1
				S.ids[d] = n
				S.parts[n] = d
				S.alive[n] = true
				local bottom = d.Position.Y - halfHeight(d)
				local s = d.Size
				if indestructible then
					-- apoyo fijo: lo que se apoya en un hueco de ascensor o en una pieza indestructible no se cae
					S.fixed[n] = true
					S.root[n] = true
				else
					S.root[n] = bottom <= floorY + 0.75 or math.max(s.X, s.Z) > 160
				end
				-- piezas que estaban sueltas en el mapa original (muebles): se anclan hasta que algo las golpee
				if not d.Anchored then
					d.Anchored = true
				end
			end
		end
	end
	S.count = n

	local token = S.token
	task.spawn(function()
		local budget = Config.GraphBudgetMs / 1000
		local start = os.clock()
		local pad = Vector3.new(0.8, 0.8, 0.8) -- tolerancia de contacto (carteles pegados a paredes, etc.)
		for i = 1, n do
			if S == nil or S.token ~= token then
				return
			end
			local part = S.parts[i]
			local list = S.neigh[i] or {}
			S.neigh[i] = list
			if part.Parent then
				for _, other in ipairs(workspace:GetPartBoundsInBox(part.CFrame, part.Size + pad, params)) do
					local j = S.ids[other]
					if j and j ~= i and j > i then
						list[#list + 1] = j
						local lj = S.neigh[j]
						if not lj then
							lj = {}
							S.neigh[j] = lj
						end
						lj[#lj + 1] = i
					end
				end
			end
			if os.clock() - start > budget then
				task.wait()
				start = os.clock()
			end
		end
		if S and S.token == token then
			S.graphReady = true
			-- lo que nace sin apoyo (carteles colgados, luces...) se considera sujeto: no se cae de golpe
			local loose = Destruction.FindUnsupported()
			for _, p in ipairs(loose) do
				S.root[S.ids[p]] = true
			end
			S.initialLoose = #loose
			S.initialLooseNames = {}
			for i = 1, math.min(12, #loose) do
				S.initialLooseNames[i] = loose[i]
			end
		end
	end)
	return n
end

function Destruction.SetToughness(mult)
	if S then
		S.toughness = mult
	end
end

function Destruction.Reset()
	if S then
		for _, b in pairs(S.burning) do
			if b.fire and b.fire.Parent then
				b.fire:Destroy()
			end
		end
	end
	S = nil
	PhysicsBudget.Reset()
end

function Destruction.Stats()
	if not S then
		return { parts = 0 }
	end
	return { parts = S.count, broken = S.broken, collapsed = S.collapsed, graphReady = S.graphReady, physics = PhysicsBudget.Count(), rubble = PhysicsBudget.RubbleCount(), loose = S.initialLoose or 0, looseParts = S.initialLooseNames or {} }
end

-- ======================================================================
-- Romper piezas
-- ======================================================================

-- Borrado diferido (las piezas en cola ya no se ven: se ocultan al momento)
local function queueRemove(part)
	if not S then
		if part.Parent then
			part:Destroy()
		end
		return
	end
	S.removeQueue[#S.removeQueue + 1] = part
end
Destruction.Remove = queueRemove
PhysicsBudget.SetRemover(queueRemove)

local function shatter(part, burnt)
	if not S then
		return
	end
	local q = S.shatterQueue
	q[#q + 1] = { p = part.Position, s = part.Size, c = burnt and BURNT or part.Color, m = matName(part) }
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	queueRemove(part)
end

local function detach(part, impulse)
	local s = part.Size
	part.Anchored = false
	PhysicsBudget.Add({ part })
	part.AssemblyLinearVelocity = impulse or Vector3.new(math.random(-6, 6), 4, math.random(-6, 6))
	part.AssemblyAngularVelocity = Vector3.new(math.random(-3, 3), math.random(-3, 3), math.random(-3, 3))
	-- piezas muy grandes caen mas lentas en el giro
	if math.max(s.X, s.Y, s.Z) > 10 then
		part.AssemblyAngularVelocity = part.AssemblyAngularVelocity * 0.4
	end
end

local function breakId(id, impulse, opts)
	if not S or not S.alive[id] or S.fixed[id] then
		return
	end
	S.alive[id] = false
	S.broken = S.broken + 1
	S.dirty = true
	local part = S.parts[id]
	local burn = S.burning[id]
	if burn then
		if burn.fire and burn.fire.Parent then
			burn.fire:Destroy()
		end
		S.burning[id] = nil
		S.burningCount = S.burningCount - 1
	end
	if not part.Parent then
		return
	end
	local s = part.Size
	local vol = s.X * s.Y * s.Z
	local mat = matName(part)
	local forceShatter = opts and opts.shatter
	if forceShatter or mat == "Glass" or vol < 5 or not PhysicsBudget.CanAdd(1) or (opts and opts.burnt) then
		shatter(part, opts and opts.burnt)
	else
		detach(part, impulse)
	end
end

function Destruction.Break(part, impulse, opts)
	if not S then
		return
	end
	local id = S.ids[part]
	if id then
		breakId(id, impulse, opts)
	end
end

local function damageId(id, amount, impulse, opts)
	if not S or not S.alive[id] or S.fixed[id] then
		return false
	end
	local part = S.parts[id]
	local hp = S.hp[id]
	if not hp then
		hp = maxHp(part)
		S.hp[id] = hp
		S.max = S.max or {}
		S.max[id] = hp
	end
	hp = hp - amount
	S.hp[id] = hp
	if hp <= 0 then
		breakId(id, impulse, opts)
		return true
	end
	-- se oscurece al recibir dano (solo 2 cambios para no saturar la red)
	local ratio = hp / S.max[id]
	local stage = S.stage[id] or 0
	if ratio < 0.66 and stage < 1 then
		S.stage[id] = 1
		part.Color = part.Color:Lerp(DARK, 0.22)
	elseif ratio < 0.33 and stage < 2 then
		S.stage[id] = 2
		part.Color = part.Color:Lerp(DARK, 0.3)
	end
	return false
end

function Destruction.Damage(part, amount, impulse, opts)
	if not S then
		return false
	end
	local id = S.ids[part]
	if id then
		return damageId(id, amount, impulse, opts)
	end
	return false
end

-- Dano en esfera con caida por distancia. opts.fling = fuerza con la que salen despedidas las piezas.
function Destruction.DamageSphere(center, radius, damage, opts)
	if not S then
		return 0
	end
	opts = opts or {}
	local fling = opts.fling or 40
	local broken = 0
	local hits = workspace:GetPartBoundsInRadius(center, radius, S.params)
	local limit = opts.maxParts or 90
	for i, part in ipairs(hits) do
		if i > limit then
			break
		end
		local id = S.ids[part]
		if id and S.alive[id] then
			local off = part.Position - center
			local d = off.Magnitude
			local k = 1 - math.clamp(d / radius, 0, 1) * 0.7
			local dir = d > 0.1 and off.Unit or Vector3.yAxis
			local impulse = dir * fling * k + Vector3.new(0, fling * 0.5 * k, 0)
			if damageId(id, damage * k, impulse, opts) then
				broken = broken + 1
			end
		end
	end
	return broken
end

-- Dano a todo lo que haya dentro de una caja (lava, ola del tsunami...)
function Destruction.DamageBox(cframe, size, damage, opts)
	if not S then
		return 0
	end
	opts = opts or {}
	local broken = 0
	local hits = workspace:GetPartBoundsInBox(cframe, size, S.params)
	local limit = opts.maxParts or 80
	local impulse = opts.impulse
	local count = 0
	for _, part in ipairs(hits) do
		local id = S.ids[part]
		if id and S.alive[id] then
			count = count + 1
			if count > limit then
				break
			end
			if damageId(id, damage, impulse, opts) then
				broken = broken + 1
			end
		end
	end
	return broken
end

-- Terremoto: golpes aleatorios repartidos por el mapa, mas fuertes cuanto mas alto esta la pieza
function Destruction.Shake(intensity)
	if not S or S.count == 0 then
		return
	end
	local hits = math.floor(14 * intensity)
	for _ = 1, hits do
		local id = math.random(S.count)
		if S.alive[id] and not S.fixed[id] then
			local part = S.parts[id]
			local height = math.max(0, part.Position.Y - S.floorY)
			local dmg = (18 + height * 0.6) * intensity
			damageId(id, dmg, Vector3.new(math.random(-12, 12), 6, math.random(-12, 12)))
		end
	end
end

-- Pieza al azar que este a la vista desde el cielo (para lluvia acida, granizo...)
function Destruction.RandomTopPart(x, z, topY)
	if not S then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { S.folder }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(Vector3.new(x, topY, z), Vector3.new(0, -(topY - S.floorY + 50), 0), params)
	return hit and hit.Instance or nil
end

-- ======================================================================
-- Fuego que se propaga por la madera
-- ======================================================================
local MAX_BURNING = 45

function Destruction.Ignite(part)
	if not S then
		return false
	end
	local id = S.ids[part]
	if not id or not S.alive[id] or S.fixed[id] or S.burning[id] or S.burningCount >= MAX_BURNING then
		return false
	end
	if not FLAMMABLE[matName(part)] then
		return false
	end
	local fire = Instance.new("Fire")
	fire.Size = math.clamp(math.max(part.Size.X, part.Size.Z), 4, 14)
	fire.Heat = 9
	fire.Parent = part
	S.burning[id] = { t = clock(), fire = fire }
	S.burningCount = S.burningCount + 1
	return true
end

function Destruction.IgniteSphere(center, radius, chance)
	if not S then
		return 0
	end
	local n = 0
	for _, part in ipairs(workspace:GetPartBoundsInRadius(center, radius, S.params)) do
		if math.random() < (chance or 0.5) and Destruction.Ignite(part) then
			n = n + 1
		end
	end
	return n
end

function Destruction.BurningCount()
	return S and S.burningCount or 0
end

local function updateFires(dt)
	if not S then
		return
	end
	local now = clock()
	-- copia de las claves: el fuego se propaga (anade entradas) mientras se recorre
	local ids = {}
	for id in pairs(S.burning) do
		ids[#ids + 1] = id
	end
	for _, id in ipairs(ids) do
		local b = S and S.burning[id]
		local part = b and S.parts[id]
		if not b then
			-- ya se apago o se rompio en esta misma vuelta
		elseif not S.alive[id] or not part.Parent then
			if b.fire and b.fire.Parent then
				b.fire:Destroy()
			end
			S.burning[id] = nil
			S.burningCount = S.burningCount - 1
		else
			-- quema poco a poco y se propaga a los vecinos inflamables
			damageId(id, 10 * dt, nil, { burnt = true })
			if now - b.t > 3 and math.random() < 0.25 * dt * 4 then
				local list = S.neigh[id]
				if list and #list > 0 then
					local j = list[math.random(#list)]
					if S.alive[j] then
						Destruction.Ignite(S.parts[j])
					end
				end
			end
		end
	end
end

-- ======================================================================
-- Derrumbes
-- ======================================================================

local CLUSTER = 16

local function collapseComponent(component)
	-- agrupar por celdas para soldar bloques que caen juntos
	local cells = {}
	local order = {}
	for _, id in ipairs(component) do
		local p = S.parts[id]
		if p.Parent then
			local pos = p.Position
			local key = math.floor(pos.X / CLUSTER) .. ":" .. math.floor(pos.Y / CLUSTER) .. ":" .. math.floor(pos.Z / CLUSTER)
			local cell = cells[key]
			if not cell then
				cell = {}
				cells[key] = cell
				order[#order + 1] = cell
			end
			cell[#cell + 1] = id
		end
	end
	for _, cell in ipairs(order) do
		for _, id in ipairs(cell) do
			S.alive[id] = false
		end
		S.collapsed = S.collapsed + #cell
		if #cell <= 40 and PhysicsBudget.CanAdd(1) then
			local parts = {}
			local welds = {}
			local root = S.parts[cell[1]]
			for _, id in ipairs(cell) do
				local p = S.parts[id]
				parts[#parts + 1] = p
				if p ~= root then
					local w = Instance.new("WeldConstraint")
					w.Part0 = root
					w.Part1 = p
					w.Parent = root
					welds[#welds + 1] = w
				end
			end
			PhysicsBudget.Add(parts, welds)
			root.AssemblyLinearVelocity = Vector3.new(math.random(-4, 4), -6, math.random(-4, 4))
			root.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
		else
			for _, id in ipairs(cell) do
				local p = S.parts[id]
				if p.Parent then
					shatter(p)
				end
			end
		end
	end
end

-- Piezas que ahora mismo no estan unidas a ninguna raiz (para depurar mapas: deberia ser 0 al cargar)
function Destruction.FindUnsupported()
	if not S or not S.graphReady then
		return {}
	end
	local reached, queue, head = {}, {}, 1
	for id = 1, S.count do
		if S.alive[id] and S.root[id] then
			reached[id] = true
			queue[#queue + 1] = id
		end
	end
	while head <= #queue do
		local id = queue[head]
		head = head + 1
		for _, j in ipairs(S.neigh[id] or {}) do
			if S.alive[j] and not reached[j] then
				reached[j] = true
				queue[#queue + 1] = j
			end
		end
	end
	local out = {}
	for id = 1, S.count do
		if S.alive[id] and not reached[id] then
			out[#out + 1] = S.parts[id]
		end
	end
	return out
end

-- BFS desde las raices: todo lo vivo que no se alcance esta colgando y se derrumba
function Destruction.CheckSupport()
	if not S or not S.graphReady or not S.dirty then
		return 0
	end
	S.dirty = false
	local alive, neigh, root = S.alive, S.neigh, S.root
	local reached = {}
	local queue = {}
	local head = 1
	for id = 1, S.count do
		if alive[id] and root[id] then
			reached[id] = true
			queue[#queue + 1] = id
		end
	end
	while head <= #queue do
		local id = queue[head]
		head = head + 1
		local list = neigh[id]
		if list then
			for _, j in ipairs(list) do
				if alive[j] and not reached[j] then
					reached[j] = true
					queue[#queue + 1] = j
				end
			end
		end
	end
	-- componentes sin apoyo
	local fallen = 0
	local visited = {}
	for id = 1, S.count do
		if alive[id] and not reached[id] and not visited[id] then
			local comp = { id }
			visited[id] = true
			local h = 1
			while h <= #comp do
				local cur = comp[h]
				h = h + 1
				local list = neigh[cur]
				if list then
					for _, j in ipairs(list) do
						if alive[j] and not reached[j] and not visited[j] then
							visited[j] = true
							comp[#comp + 1] = j
						end
					end
				end
			end
			fallen = fallen + #comp
			collapseComponent(comp)
		end
	end
	return fallen
end

-- ======================================================================
-- Bucle: borrado diferido, envio de anicos a los clientes, fuego y derrumbes
-- ======================================================================
local collapseAcc, fireAcc = 0, 0

RunService.Heartbeat:Connect(function(dt)
	if not S then
		return
	end
	-- anicos -> clientes (en lote)
	local q = S.shatterQueue
	if #q > 0 then
		local batch = {}
		local n = math.min(#q, Config.MaxShatterPerFlush)
		for i = 1, n do
			batch[i] = q[i]
		end
		S.shatterQueue = {}
		ShatterEvent:FireAllClients(batch)
	end
	-- borrado repartido
	local rq = S.removeQueue
	local limit = Config.HidePerFrame
	local removed = 0
	while S.removeHead <= #rq and removed < limit do
		local p = rq[S.removeHead]
		rq[S.removeHead] = nil
		S.removeHead = S.removeHead + 1
		if p and p.Parent then
			p:Destroy()
		end
		removed = removed + 1
	end
	if S.removeHead > #rq then
		S.removeQueue = {}
		S.removeHead = 1
	end
	-- fuego
	fireAcc = fireAcc + dt
	if fireAcc >= 0.5 then
		updateFires(fireAcc)
		fireAcc = 0
	end
	-- derrumbes
	collapseAcc = collapseAcc + dt
	if collapseAcc >= Config.CollapseInterval then
		collapseAcc = 0
		Destruction.CheckSupport()
	end
end)

return Destruction
