-- INSTALADOR de Islas de Desastres.
-- Crea (o reemplaza) estas carpetas: ReplicatedStorage.IslasShared, ServerStorage.IslasMapas,
-- ServerScriptService.IslasServer y StarterPlayer.StarterPlayerScripts.IslasClient.
-- No toca nada mas de tu juego.
-- PARTE 3 DE 5. Pega las partes en la Barra de comandos EN ORDEN (1, 2, 3...).

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

add("ServerScriptService", { "IslasServer" }, "Destruction", "ModuleScript", [=[
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
]=])

add("ServerScriptService", { "IslasServer", "Disasters" }, "AcidRain", "ModuleScript", [[
-- Lluvia acida: quema a quien este a cielo abierto (el paraguas protege) y corroe los tejados poco a poco,
-- abriendo agujeros: los refugios dejan de ser seguros con el tiempo.
return {
	Run = function(ctx)
		ctx.setLighting({ FogColor = Color3.fromRGB(90, 140, 60), FogEnd = 450, Brightness = 1 })
		ctx.fx("tint", Color3.fromRGB(80, 200, 60), 0.86)
		ctx.fx("weather", "acid")
		local dt = 0.5
		local corrodeAcc = 0
		while ctx.active() do
			for _, entry in ipairs(ctx.players()) do
				if not ctx.holding(entry, "Paraguas") and not ctx.covered(entry) then
					ctx.damage(entry, (ctx.config.dps or 7) * dt * ctx.intensity)
				end
			end
			corrodeAcc = corrodeAcc + dt
			if corrodeAcc >= 0.6 then
				corrodeAcc = 0
				for _ = 1, math.ceil(4 * ctx.intensity) do
					local x, z = ctx.randomPoint()
					local part = ctx.D.RandomTopPart(x, z, ctx.bounds.top + 40)
					if part then
						ctx.D.Damage(part, 45, nil, { shatter = true })
					end
				end
			end
			task.wait(dt)
		end
	end,
}
]])

add("ServerScriptService", { "IslasServer", "Disasters" }, "BlackHole", "ModuleScript", [[
-- Agujero negro: se mueve despacio por el mapa, atrae jugadores y piezas, arranca trozos de los edificios
-- y se traga todo lo que llega a su centro. Crece con el tiempo.
return {
	Run = function(ctx)
		local bb = ctx.bounds
		local points = {}
		for i = 1, 5 do
			local x, z = ctx.randomPoint()
			points[i] = { x, z }
		end
		local speed = 5 * math.min(ctx.intensity, 1.5)
		local path = ctx.Paths.Make(points, speed, ctx.time(), true)
		local height = ctx.config.height or 25
		ctx.fx("path", "BlackHole", { points = points, speed = speed, t0 = path.t0, loop = true, height = height })
		ctx.setLighting({ Brightness = 0.7, Ambient = Color3.fromRGB(60, 40, 90) })
		local dt = 0.1
		local tick = 0
		local baseY = bb.floor
		while ctx.active() do
			tick = tick + 1
			local x, z = ctx.Paths.At(path, ctx.time())
			if tick % 10 == 1 then
				baseY = ctx.groundY(x, z) or baseY
			end
			local center = Vector3.new(x, baseY + height, z)
			local grow = 1 + ctx.progress() * 0.8
			local pull = 80 * grow
			local horizon = 7 * grow
			for _, entry in ipairs(ctx.players()) do
				local off = center - entry.root.Position
				local d = off.Magnitude
				if d < horizon then
					ctx.kill(entry)
				elseif d < pull then
					local k = 1 - d / pull
					entry.root.AssemblyLinearVelocity = entry.root.AssemblyLinearVelocity * 0.6 + off.Unit * (25 + 60 * k) * ctx.intensity
				end
			end
			if tick % 3 == 0 then
				-- arranca piezas cerca y las atrae
				ctx.D.DamageSphere(center, 26 * grow, 90 * ctx.intensity, { fling = -60, maxParts = 30 })
				ctx.PB.ForEachBody(function(root)
					local off = center - root.Position
					local d = off.Magnitude
					if d < 8 then
						ctx.D.Remove(root)
					elseif d < pull * 1.3 then
						root.AssemblyLinearVelocity = off.Unit * (50 + 40 * (1 - d / (pull * 1.3)))
					end
				end)
			end
			task.wait(dt)
		end
	end,
}
]])

add("ServerScriptService", { "IslasServer", "Disasters" }, "Blizzard", "ModuleScript", [[
-- Ventisca: frio extremo. A la intemperie pierdes vida (el paraguas ayuda); bajo techo o cerca de una
-- hoguera estas a salvo (las hogueras ademas curan). La nieve tapa la vista.
return {
	Run = function(ctx)
		ctx.setLighting({ FogColor = Color3.fromRGB(225, 235, 245), FogEnd = 180, FogStart = 10, Brightness = 1.4, ClockTime = 15 })
		ctx.fx("weather", "snow")
		ctx.fx("tint", Color3.fromRGB(200, 225, 255), 0.88)

		-- hogueras repartidas por el mapa
		local fires = {}
		for i = 1, 4 do
			local x, z = ctx.randomPoint()
			local y = ctx.groundY(x, z)
			if y then
				local base = ctx.build:Box("Hoguera", Vector3.new(4, 1, 4), Vector3.new(x, y + 0.5, z), Color3.fromRGB(90, 60, 40), Enum.Material.Wood, { indestructible = true })
				local f = Instance.new("Fire")
				f.Size = 8
				f.Heat = 12
				f.Parent = base
				ctx.Util.AddLight(base, 26, 3, Color3.fromRGB(255, 170, 80))
				fires[#fires + 1] = base.Position
			end
		end
		ctx.fx("markers", fires, Color3.fromRGB(255, 170, 80))

		local dt = 0.5
		while ctx.active() do
			local cold = (3 + ctx.progress() * 4) * ctx.intensity
			for _, entry in ipairs(ctx.players()) do
				local pos = entry.root.Position
				local warm = false
				for _, f in ipairs(fires) do
					if (pos - f).Magnitude < 13 then
						warm = true
						break
					end
				end
				if warm then
					entry.humanoid.Health = math.min(entry.humanoid.MaxHealth, entry.humanoid.Health + 4 * dt)
				elseif not ctx.covered(entry) then
					local k = ctx.holding(entry, "Paraguas") and 0.35 or 1
					ctx.damage(entry, cold * k * dt)
				end
			end
			-- el hielo rompe cristales y piezas finas
			if math.random() < 0.5 then
				local x, z = ctx.randomPoint()
				local part = ctx.D.RandomTopPart(x, z, ctx.bounds.top + 40)
				if part and part.Material == Enum.Material.Glass then
					ctx.D.Break(part, nil, { shatter = true })
				end
			end
			task.wait(dt)
		end
	end,
}
]])

add("ServerScriptService", { "IslasServer", "Disasters" }, "Earthquake", "ModuleScript", [[
-- Terremoto: oleadas de temblores cada vez mas fuertes. Rompe piezas por todo el mapa (mas arriba = mas dano),
-- lo que provoca derrumbes reales. Tira a los jugadores al suelo de vez en cuando.
return {
	Run = function(ctx)
		while ctx.active() do
			local wave = 0.55 + 0.85 * math.abs(math.sin(ctx.elapsed() * 0.33))
			local k = (0.45 + ctx.progress() * 1.25) * wave * ctx.intensity
			ctx.fx("shake", 0.3 + k * 0.9, 1.1)
			ctx.D.Shake(k)
			if math.random() < 0.07 * k then
				for _, entry in ipairs(ctx.players()) do
					if math.random() < 0.5 then
						entry.humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
					end
				end
			end
			task.wait(0.5)
		end
	end,
}
]])

add("ServerScriptService", { "IslasServer", "Disasters" }, "Fire", "ModuleScript", [[
-- Incendio: focos que crecen y prenden fuego a la madera, la tela y la hierba. El fuego se propaga por los
-- edificios (Destruction) y lo que se quema acaba cayendo.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		task.spawn(function()
			while ctx.active() do
				-- chispas que prenden cerca de los jugadores
				local x, z = ctx.targetPoint(0.6, 25)
				local y = ctx.groundY(x, z) or ctx.bounds.floor
				ctx.D.IgniteSphere(Vector3.new(x, y, z), 12, 0.6)
				task.wait(ctx.rate(3))
			end
		end)
		Hazards.Zones(ctx, {
			color = Color3.fromRGB(255, 110, 30),
			fire = true,
			dps = 14,
			startRadius = 5,
			maxRadius = 22,
			growth = 0.8,
			interval = 6,
			maxZones = 8,
			ignite = true,
			partDamage = 15,
		})
	end,
}
]])

add("ServerScriptService", { "IslasServer", "Disasters" }, "Flood", "ModuleScript", [[
-- Inundacion: el agua sube hasta la altura que diga el mapa. Abajo te ahogas poco a poco.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		Hazards.Liquid(ctx, {
			color = Color3.fromRGB(40, 120, 200),
			material = "SmoothPlastic",
			transparency = 0.35,
			maxHeight = 40,
			lethal = false,
			dps = 15,
		})
	end,
}
]])

add("ServerScriptService", { "IslasServer", "Disasters" }, "Lava", "ModuleScript", [[
-- Lava: sube, derrite lo que toca (los edificios se hunden desde abajo) y mata al instante.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		ctx.setLighting({ OutdoorAmbient = Color3.fromRGB(150, 90, 60) })
		Hazards.Liquid(ctx, {
			color = Color3.fromRGB(255, 90, 20),
			material = "Neon",
			transparency = 0.05,
			maxHeight = 40,
			lethal = true,
			melt = 90,
		})
	end,
}
]])

add("ServerScriptService", { "IslasServer", "Disasters" }, "Lightning", "ModuleScript", [[
-- Tormenta electrica: rayos avisados con un anillo. Rompen lo que tocan y pueden prender fuego.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		ctx.setLighting({ Brightness = 0.5, FogEnd = 500, FogColor = Color3.fromRGB(55, 60, 75), Ambient = Color3.fromRGB(40, 40, 55), ClockTime = 19 })
		ctx.fx("weather", "rain")
		local cfg = ctx.config
		while ctx.active() do
			local x, z = ctx.targetPoint(0.7, 8)
			Hazards.Strike(ctx, x, z, {
				kind = "bolt",
				radius = cfg.radius or 9,
				damage = cfg.damage or 70,
				warn = 1.1,
				partDamage = 140,
				fling = 35,
				ignite = 0.5,
				color = Color3.fromRGB(255, 235, 90),
				knockback = 30,
			})
			task.wait(ctx.rate(math.max(0.45, 1.3 - ctx.progress() * 0.7)))
		end
	end,
}
]])

add("ServerScriptService", { "IslasServer", "Disasters" }, "Meteors", "ModuleScript", [[
-- Lluvia de meteoritos: cada vez mas frecuentes. Revientan tejados y paredes y a veces prenden fuego.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		local cfg = ctx.config
		while ctx.active() do
			local volley = 1 + math.floor(ctx.progress() * 2.5 * ctx.intensity)
			for _ = 1, volley do
				local x, z = ctx.targetPoint(0.6, 18)
				Hazards.Strike(ctx, x, z, {
					kind = "meteor",
					radius = cfg.radius or 14,
					damage = cfg.damage or 70,
					warn = 1.7,
					partDamage = 320,
					fling = 65,
					ignite = 0.25,
					size = 6 + math.random() * 4,
				})
			end
			task.wait(ctx.rate(math.max(0.6, 1.8 - ctx.progress() * 1.0)))
		end
	end,
}
]])

add("ServerScriptService", { "IslasServer", "Disasters" }, "Radiation", "ModuleScript", [[
-- Fuga de radiacion: nubes verdes que aparecen y crecen. No rompen nada pero hacen dano dentro.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		ctx.setLighting({ Ambient = Color3.fromRGB(70, 110, 60) })
		Hazards.Zones(ctx, {
			color = Color3.fromRGB(110, 255, 80),
			fire = false,
			dps = 11,
			startRadius = 6,
			maxRadius = 28,
			growth = 1.1,
			interval = 6,
			maxZones = 8,
		})
	end,
}
]])

add("ServerScriptService", { "IslasServer", "Disasters" }, "Sandstorm", "ModuleScript", [[
-- Tormenta de arena: viento que cambia de direccion y empuja a quien este fuera; la arena hace dano a la
-- intemperie (el paraguas reduce el dano) y arranca piezas ligeras de los tejados.
return {
	Run = function(ctx)
		ctx.setLighting({ FogColor = Color3.fromRGB(215, 175, 110), FogEnd = 160, FogStart = 5, Brightness = 1.6 })
		ctx.fx("weather", "sand")
		ctx.fx("tint", Color3.fromRGB(230, 180, 110), 0.85)
		local angle = math.random() * math.pi * 2
		local dt = 0.25
		local acc = 0
		while ctx.active() do
			angle = angle + (math.random() - 0.5) * 0.15
			local wind = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local strength = (18 + 22 * math.abs(math.sin(ctx.elapsed() * 0.4))) * ctx.intensity
			for _, entry in ipairs(ctx.players()) do
				if not ctx.covered(entry) then
					local v = entry.root.AssemblyLinearVelocity
					entry.root.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, v.Z) + wind * strength * dt * 2.2
					local k = ctx.holding(entry, "Paraguas") and 0.4 or 1
					ctx.damage(entry, 5 * k * dt * ctx.intensity)
				end
			end
			acc = acc + dt
			if acc >= 1 then
				acc = 0
				for _ = 1, 3 do
					local x, z = ctx.randomPoint()
					local part = ctx.D.RandomTopPart(x, z, ctx.bounds.top + 40)
					if part then
						ctx.D.Damage(part, 25 * ctx.intensity, wind * 60 + Vector3.new(0, 20, 0))
					end
				end
			end
			task.wait(dt)
		end
	end,
}
]])

add("ServerScriptService", { "IslasServer", "Disasters" }, "Tornado", "ModuleScript", [[
-- Tornado: recorre el mapa siguiendo puntos de paso (los clientes lo dibujan con el mismo recorrido),
-- arrastra jugadores, arranca piezas y lanza por los aires los escombros sueltos.
return {
	Run = function(ctx)
		local cfg = ctx.config
		local radius = cfg.radius or 42
		local speed = (cfg.speed or 11) * math.min(ctx.intensity, 1.5)
		local points = {}
		for i = 1, 7 do
			local x, z = ctx.randomPoint()
			points[i] = { x, z }
		end
		local path = ctx.Paths.Make(points, speed, ctx.time(), true)
		ctx.fx("path", "Tornado", { points = points, speed = speed, t0 = path.t0, loop = true, radius = radius })
		ctx.setLighting({ Brightness = 0.9, FogEnd = 700, FogColor = Color3.fromRGB(110, 110, 115) })

		local baseY = ctx.bounds.floor
		local tick = 0
		local dt = 0.1
		while ctx.active() do
			tick = tick + 1
			local px, pz = ctx.Paths.At(path, ctx.time())
			if tick % 5 == 1 then
				baseY = ctx.groundY(px, pz) or baseY
			end
			local core = Vector3.new(px, baseY, pz)

			for _, entry in ipairs(ctx.players()) do
				local pos = entry.root.Position
				local off = Vector3.new(pos.X - px, 0, pos.Z - pz)
				local d = off.Magnitude
				if d < radius and pos.Y - baseY < 140 then
					local k = 1 - d / radius
					local inward = d > 0.1 and -off.Unit or Vector3.zero
					local tangent = d > 0.1 and Vector3.new(-off.Z, 0, off.X).Unit or Vector3.zero
					entry.root.AssemblyLinearVelocity = tangent * (32 * k + 8) + inward * (15 * k) + Vector3.new(0, 30 * k + 8, 0)
					ctx.damage(entry, 6 * dt * k)
				end
			end

			if tick % 3 == 0 then
				ctx.D.DamageSphere(core + Vector3.new(0, 10, 0), 22, 70 * ctx.intensity, { fling = 80, maxParts = 30 })
				ctx.PB.ForEachBody(function(root)
					local p = root.Position
					local ox, oz = p.X - px, p.Z - pz
					local dd = math.sqrt(ox * ox + oz * oz)
					if dd > 0.5 and dd < radius * 1.2 then
						root.AssemblyLinearVelocity = Vector3.new(-oz, 0, ox).Unit * 45 + Vector3.new(-ox, 0, -oz).Unit * 12 + Vector3.new(0, 35, 0)
					end
				end)
			end
			task.wait(dt)
		end
	end,
}
]])

add("ServerScriptService", { "IslasServer", "Disasters" }, "Tsunami", "ModuleScript", [[
-- Tsunami: olas gigantes que cruzan el mapa de un lado a otro. Arrastran a los jugadores y destrozan los
-- edificios a su paso. Despues de cada ola el nivel del agua sube un poco.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		local bb = ctx.bounds
		local H = ctx.config.height or 34
		local thick = 30
		local speed = (ctx.config.speed or 32) * math.min(ctx.intensity, 1.4)
		local cx, cz = (bb.x1 + bb.x2) / 2, (bb.z1 + bb.z2) / 2
		local spanX, spanZ = bb.x2 - bb.x1, bb.z2 - bb.z1

		-- agua de fondo que va subiendo con cada ola
		task.spawn(function()
			Hazards.Liquid(ctx, {
				color = Color3.fromRGB(35, 110, 190),
				material = "SmoothPlastic",
				transparency = 0.35,
				maxHeight = ctx.config.maxHeight or (H * 0.45),
				lethal = false,
				dps = 12,
			})
		end)

		while ctx.active() do
			local dirs = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
			local dir = dirs[math.random(#dirs)]
			local along = dir.X ~= 0 and spanX or spanZ
			local width = (dir.X ~= 0 and spanZ or spanX) + 120
			local start = Vector3.new(cx, bb.floor, cz) - dir * (along / 2 + 60)
			local t0 = ctx.time() + 3
			local travel = (along + 140) / speed
			ctx.fx("wave", { start = start, dir = dir, speed = speed, t0 = t0, width = width, height = H, thick = thick, duration = travel })
			ctx.fx("shake", 0.6, 3)
			task.wait(3)
			local acc = 0
			while ctx.active() and ctx.time() < t0 + travel do
				local front = start + dir * speed * (ctx.time() - t0)
				-- jugadores dentro de la ola
				for _, entry in ipairs(ctx.players()) do
					local rel = entry.root.Position - front
					local behind = -(rel.X * dir.X + rel.Z * dir.Z)
					if behind > -2 and behind < thick and entry.root.Position.Y < bb.floor + H then
						Hazards.Push(entry, dir * 55 + Vector3.new(0, 18, 0))
						ctx.damage(entry, 40 * 0.2)
					end
				end
				acc = acc + 0.2
				if acc >= 0.4 then
					acc = 0
					local center = front - dir * 6 + Vector3.new(0, H / 2, 0)
					local size = dir.X ~= 0 and Vector3.new(12, H, width) or Vector3.new(width, H, 12)
					ctx.D.DamageBox(CFrame.new(center), size, 140 * ctx.intensity, { impulse = dir * 70 + Vector3.new(0, 15, 0), maxParts = 50 })
				end
				task.wait(0.2)
			end
			task.wait(ctx.rate(6))
		end
	end,
}
]])

add("ServerScriptService", { "IslasServer", "Disasters" }, "UFO", "ModuleScript", [[
-- Invasion alienigena: ovnis que patrullan el mapa. Disparan laseres avisados y encienden rayos abductores:
-- quien se queda debajo sube hacia la nave y, si llega arriba, desaparece.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		local bb = ctx.bounds
		local count = math.clamp(math.floor(2 * ctx.intensity + 0.5), 1, 4)
		local height = ctx.config.height or 70
		local ufos = {}
		for u = 1, count do
			local points = {}
			for i = 1, 5 do
				local x, z = ctx.randomPoint()
				points[i] = { x, z }
			end
			local speed = 14 + math.random() * 6
			local path = ctx.Paths.Make(points, speed, ctx.time(), true)
			ufos[u] = { path = path, beamUntil = 0 }
			ctx.fx("path", "UFO", { points = points, speed = speed, t0 = path.t0, loop = true, height = height, index = u })
		end
		ctx.setLighting({ Ambient = Color3.fromRGB(70, 100, 90), Brightness = 1 })
		local dt = 0.2
		local nextLaser, nextBeam = 0, 4
		while ctx.active() do
			local now = ctx.time()
			for u, ufo in ipairs(ufos) do
				local x, z = ctx.Paths.At(ufo.path, now)
				local top = bb.floor + height
				-- rayo abductor
				if now < ufo.beamUntil then
					for _, entry in ipairs(ctx.players()) do
						local p = entry.root.Position
						local dx, dz = p.X - x, p.Z - z
						if dx * dx + dz * dz < 10 * 10 then
							entry.root.AssemblyLinearVelocity = Vector3.new(-dx * 0.5, 28, -dz * 0.5)
							ctx.damage(entry, 10 * dt)
							if p.Y > top - 8 then
								ctx.kill(entry)
							end
						end
					end
				end
				ufo.x, ufo.z = x, z
			end
			if now >= nextBeam then
				local ufo = ufos[math.random(#ufos)]
				ufo.beamUntil = now + 4.5
				ctx.fx("beam", table.find(ufos, ufo), 4.5)
				nextBeam = now + ctx.rate(math.max(3, 7 - ctx.progress() * 3))
			end
			if now >= nextLaser then
				local ufo = ufos[math.random(#ufos)]
				if ufo.x then
					local tx, tz = ctx.targetPoint(0.7, 12)
					Hazards.Strike(ctx, tx, tz, {
						kind = "laser",
						from = Vector3.new(ufo.x, bb.floor + height - 4, ufo.z),
						radius = 7,
						damage = 35,
						warn = 1,
						partDamage = 110,
						fling = 30,
						color = Color3.fromRGB(80, 255, 140),
						knockback = 25,
					})
				end
				nextLaser = now + ctx.rate(math.max(0.5, 1.4 - ctx.progress() * 0.8))
			end
			task.wait(dt)
		end
	end,
}
]])

add("ServerScriptService", { "IslasServer", "Disasters" }, "Virus", "ModuleScript", [[
-- Virus mortal: algunos jugadores se infectan y pierden vida poco a poco. Contagian a quien este cerca.
-- Las estaciones de cura (cruz verde) curan y quitan el virus. Con un solo jugador, el virus va mas lento.
local Players = game:GetService("Players")

return {
	Run = function(ctx)
		local infected = {} -- [player] = true
		local exposure = {} -- [player] = segundos cerca de un infectado
		local highlights = {}

		local function setInfected(player, on)
			if on == (infected[player] == true) then
				return
			end
			infected[player] = on or nil
			local char = player.Character
			if highlights[player] then
				highlights[player]:Destroy()
				highlights[player] = nil
			end
			if on and char then
				local h = Instance.new("Highlight")
				h.Name = "Virus"
				h.FillColor = Color3.fromRGB(110, 255, 90)
				h.OutlineColor = Color3.fromRGB(30, 120, 20)
				h.FillTransparency = 0.55
				h.Parent = char
				highlights[player] = h
			end
			ctx.fx("infected", player.UserId, on == true)
		end
		ctx.onStop(function()
			for p in pairs(infected) do
				setInfected(p, false)
			end
		end)

		-- estaciones de cura
		local stations = {}
		for i = 1, 3 do
			local x, z = ctx.randomPoint()
			local y = ctx.groundY(x, z)
			if y then
				local pad = ctx.build:Box("EstacionCura", Vector3.new(6, 0.6, 6), Vector3.new(x, y + 0.3, z), Color3.fromRGB(80, 255, 120), Enum.Material.Neon, { indestructible = true })
				ctx.build:Board("Cruz", "✚", Vector3.new(3, 3, 0.4), Vector3.new(x, y + 4, z), Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 200, 80))
				stations[#stations + 1] = pad.Position
			end
		end
		ctx.fx("markers", stations, Color3.fromRGB(80, 255, 120))

		-- paciente cero
		local list = ctx.players()
		local n = math.max(1, math.ceil(#list / 4))
		for i = 1, math.min(n, #list) do
			local j = math.random(#list)
			setInfected(list[j].player, true)
			table.remove(list, j)
		end

		local dt = 0.5
		local solo = #Players:GetPlayers() <= 1
		while ctx.active() do
			local entries = ctx.players()
			local sick = {}
			for _, e in ipairs(entries) do
				if infected[e.player] then
					sick[#sick + 1] = e
					ctx.damage(e, (solo and 0.9 or 1.6) * dt * ctx.intensity)
				end
			end
			for _, e in ipairs(entries) do
				local pos = e.root.Position
				-- curarse
				for _, s in ipairs(stations) do
					if (pos - s).Magnitude < 7 then
						if infected[e.player] then
							setInfected(e.player, false)
						end
						e.humanoid.Health = math.min(e.humanoid.MaxHealth, e.humanoid.Health + 6 * dt)
					end
				end
				-- contagio
				if not infected[e.player] then
					local near = false
					for _, s in ipairs(sick) do
						if (s.root.Position - pos).Magnitude < 9 then
							near = true
							break
						end
					end
					exposure[e.player] = near and (exposure[e.player] or 0) + dt or 0
					if exposure[e.player] >= 1.5 then
						setInfected(e.player, true)
						exposure[e.player] = 0
					end
				end
			end
			-- si se cura todo el mundo, vuelve a aparecer
			if #sick == 0 and #entries > 0 and math.random() < 0.08 then
				setInfected(entries[math.random(#entries)].player, true)
			end
			task.wait(dt)
		end
	end,
}
]])

add("ServerScriptService", { "IslasServer", "Disasters" }, "Volcano", "ModuleScript", [[
-- Volcan: surge del suelo en un lado del mapa, tiembla y lanza bombas de lava cada vez mas a menudo.
-- Alrededor del crater se forman rios de lava (zonas mortales que crecen).
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		local bb = ctx.bounds
		-- en un borde del mapa
		local side = math.random(4)
		local x, z
		if side == 1 then
			x, z = bb.x1 + 15, bb.z1 + math.random() * (bb.z2 - bb.z1)
		elseif side == 2 then
			x, z = bb.x2 - 15, bb.z1 + math.random() * (bb.z2 - bb.z1)
		elseif side == 3 then
			x, z = bb.x1 + math.random() * (bb.x2 - bb.x1), bb.z1 + 15
		else
			x, z = bb.x1 + math.random() * (bb.x2 - bb.x1), bb.z2 - 15
		end
		local y = ctx.groundY(x, z) or bb.floor
		local height = ctx.config.height or 55
		local layers = 6
		local rock = Color3.fromRGB(70, 55, 50)
		local parts = {}
		for i = 1, layers do
			local d = 80 - (i - 1) * 12
			local h = height / layers
			-- sale de debajo del suelo
			local p = ctx.build:Box("Volcan", Vector3.new(h, d, d), Vector3.new(x, y - height + (i - 0.5) * h, z), rock, Enum.Material.Basalt, {
				shape = Enum.PartType.Cylinder,
				rot = Vector3.new(0, 0, 90),
				indestructible = true,
			})
			parts[i] = p
		end
		local crater = ctx.build:Box("Crater", Vector3.new(1, 18, 18), Vector3.new(x, y - 0.5, z), Color3.fromRGB(255, 90, 20), Enum.Material.Neon, {
			shape = Enum.PartType.Cylinder,
			rot = Vector3.new(0, 0, 90),
			canCollide = false,
		})
		for _, p in ipairs(parts) do
			ctx.tween(p, 6, { Position = p.Position + Vector3.new(0, height, 0) })
		end
		ctx.tween(crater, 6, { Position = crater.Position + Vector3.new(0, height + 0.6, 0) })
		ctx.fx("shake", 1.6, 6)
		-- lo que hubiera donde sale el volcan se rompe
		ctx.D.DamageSphere(Vector3.new(x, y + 10, z), 40, 1000, { fling = 80 })
		task.wait(6)
		ctx.setLighting({ OutdoorAmbient = Color3.fromRGB(150, 80, 60), FogColor = Color3.fromRGB(90, 50, 40), FogEnd = 900 })
		local top = Vector3.new(x, y + height + 2, z)

		-- rios de lava alrededor
		task.spawn(function()
			Hazards.Zones(ctx, {
				center = Vector3.new(x, y, z),
				spread = 45,
				color = Color3.fromRGB(255, 80, 20),
				fire = true,
				dps = 45,
				startRadius = 6,
				maxRadius = 18,
				growth = 0.5,
				interval = 9,
				maxZones = 6,
				ignite = true,
				partDamage = 40,
			})
		end)

		while ctx.active() do
			local n = 1 + math.floor(ctx.progress() * 3 * ctx.intensity)
			for _ = 1, n do
				local tx, tz = ctx.targetPoint(0.55, 25)
				Hazards.Strike(ctx, tx, tz, {
					kind = "bomb",
					from = top,
					radius = 11,
					damage = 60,
					warn = 2.2,
					partDamage = 220,
					fling = 50,
					ignite = 0.6,
					color = Color3.fromRGB(255, 80, 20),
					size = 5,
				})
			end
			if math.random() < 0.3 then
				ctx.fx("shake", 0.8, 1.5)
			end
			task.wait(ctx.rate(math.max(0.9, 2.4 - ctx.progress() * 1.4)))
		end
	end,
}
]])

add("ServerScriptService", { "IslasServer" }, "DisasterService", "ModuleScript", [=[
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
]=])

add("ServerScriptService", { "IslasServer" }, "GameLoop", "ModuleScript", [[
-- GameLoop: el ciclo de partida.
--   Descanso en el lobby -> votacion -> se construye la isla -> aviso -> ronda con desastre(s) -> resultados
-- Cada ronda puede traer un modificador (doble desastre, monedas x2, noche, gravedad baja...), un desastre
-- sorpresa o un segundo desastre a mitad de ronda. Sobrevivir da monedas, XP y racha.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Modifiers = require(Shared:WaitForChild("Modifiers"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))

local S = script.Parent
local MapService = require(S.MapService)
local VoteService = require(S.VoteService)
local DisasterService = require(S.DisasterService)
local Destruction = require(S.Destruction)
local PlayerData = require(S.PlayerData)
local Rewards = require(S.Rewards)
local Gear = require(S.Gear)
local CoinDrops = require(S.CoinDrops)
local Lobby = require(S.Lobby)

local RoundState = Net.Event("RoundState")
local RoundStatus = Net.Event("RoundStatus")
local RoundResults = Net.Event("RoundResults")
local KillFeed = Net.Event("KillFeed")
local PlaySound = Net.Event("PlaySound")

local GameLoop = {}

local state = {
	Phase = "Intermission",
	Status = "",
	EndsAt = 0,
	Map = nil,
	Disasters = {},
	Modifier = nil,
	Alive = 0,
	Total = 0,
	AliveIds = {},
}
GameLoop.State = state

local participants = {} -- [player] = { alive = bool, conn }

-- Para pruebas (comandos de administrador)
local forced = { map = nil, disaster = nil, skip = false }
function GameLoop.ForceMap(name)
	forced.map = name
end
function GameLoop.ForceDisaster(name)
	forced.disaster = name
end
function GameLoop.Skip()
	forced.skip = true
end

local function now()
	return workspace:GetServerTimeNow()
end

local function broadcast()
	RoundState:FireAllClients(state)
end

local function setPhase(phase, seconds, status)
	state.Phase = phase
	state.Status = status or ""
	state.EndsAt = seconds and (now() + seconds) or 0
	broadcast()
	RoundStatus:FireAllClients(status, seconds and state.EndsAt or nil)
	Lobby.SetStatus(status, seconds and Format.Time(seconds) or "")
end

-- espera actualizando el temporizador del lobby
local function countdown(seconds, status)
	local endAt = now() + seconds
	forced.skip = false
	while now() < endAt and not forced.skip do
		Lobby.SetStatus(status, Format.Time(endAt - now()))
		task.wait(math.min(1, math.max(0.05, endAt - now())))
	end
end

local function refreshAlive()
	local alive, ids, total = 0, {}, 0
	for player, p in pairs(participants) do
		total = total + 1
		if p.alive then
			alive = alive + 1
			ids[#ids + 1] = player.UserId
		end
	end
	if alive ~= state.Alive or total ~= state.Total then
		state.Alive, state.Total, state.AliveIds = alive, total, ids
		broadcast()
	end
	return alive
end

local function pickModifier()
	if math.random() > Config.ModifierChance then
		return nil
	end
	local total = 0
	for _, m in ipairs(Modifiers) do
		total = total + (m.Weight or 1)
	end
	local r = math.random() * total
	for _, m in ipairs(Modifiers) do
		r = r - (m.Weight or 1)
		if r <= 0 then
			return m
		end
	end
	return Modifiers[1]
end

-- ======================================================================
-- Modificadores
-- ======================================================================
local revert = {}

local function applyModifier(mod, list)
	table.clear(revert)
	Rewards.Multiplier = 1
	if not mod then
		return 1
	end
	local intensity = 1
	if mod.Id == "Monedas2" then
		Rewards.Multiplier = 2
	elseif mod.Id == "Hiper" then
		intensity = 1.6
		Rewards.Multiplier = 1.5
	elseif mod.Id == "Noche" then
		local old = { ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, OutdoorAmbient = Lighting.OutdoorAmbient }
		Lighting.ClockTime = 0
		Lighting.Brightness = 0.2
		Lighting.OutdoorAmbient = Color3.fromRGB(25, 25, 40)
		revert[#revert + 1] = function()
			for k, v in pairs(old) do
				Lighting[k] = v
			end
		end
	elseif mod.Id == "GravedadBaja" then
		local old = workspace.Gravity
		workspace.Gravity = 75
		revert[#revert + 1] = function()
			workspace.Gravity = old
		end
	elseif mod.Id == "Velocidad" then
		for _, player in ipairs(list) do
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:SetAttribute("VelocidadBase", 26)
				hum.WalkSpeed = 26
			end
		end
		revert[#revert + 1] = function()
			for _, player in ipairs(list) do
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum:SetAttribute("VelocidadBase", nil)
					hum.WalkSpeed = 16
				end
			end
		end
	elseif mod.Id == "Niebla" then
		local old = { FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor }
		Lighting.FogStart = 0
		Lighting.FogEnd = 90
		Lighting.FogColor = Color3.fromRGB(190, 190, 200)
		revert[#revert + 1] = function()
			for k, v in pairs(old) do
				Lighting[k] = v
			end
		end
	elseif mod.Id == "Fragil" then
		Destruction.SetToughness(0.35)
	end
	return intensity
end

local function revertModifier()
	for i = #revert, 1, -1 do
		pcall(revert[i])
	end
	table.clear(revert)
	Rewards.Multiplier = 1
end

-- ======================================================================
-- Ronda
-- ======================================================================
local function onDeath(player)
	local p = participants[player]
	if not p or not p.alive then
		return
	end
	p.alive = false
	player:SetAttribute("EnRonda", nil)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local cause = hum and hum:GetAttribute("Causa") or "Caida"
	KillFeed:FireAllClients({ Name = player.DisplayName, Cause = cause, UserId = player.UserId })
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		PlaySound:FireAllClients("Death", hrp.Position, 0.8)
	end
	refreshAlive()
end

local function prepareParticipant(player, mod)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false
	end
	local data = PlayerData.Get(player)
	hum.MaxHealth = (data and data.Owned.VidaExtra) and 125 or 100
	hum.Health = hum.MaxHealth
	hum:SetAttribute("Causa", nil)
	player:SetAttribute("EnRonda", true)
	Gear.Give(player, (mod and mod.Id == "Noche") and { "Linterna" } or nil)
	local conn = hum.Died:Connect(function()
		onDeath(player)
	end)
	participants[player] = { alive = true, conn = conn }
	return true
end

local function playRound(winner)
	local info = MapService.GetInfo(winner)
	setPhase("Loading", nil, "Construyendo " .. info.Title .. "...")
	local ok, err = pcall(MapService.Load, winner)
	if not ok then
		warn("GameLoop: error construyendo " .. winner .. ": " .. tostring(err))
		MapService.Unload()
		task.wait(2)
		return
	end
	local current = MapService.GetCurrent()

	local mod = pickModifier()
	state.Map = info.Title
	state.Modifier = mod and { Id = mod.Id, Title = mod.Title, Desc = mod.Desc, Color = mod.Color } or nil
	state.Disasters = {}

	-- participantes: todos los que estan vivos en el lobby
	table.clear(participants)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if prepareParticipant(player, mod) then
			list[#list + 1] = player
		end
	end
	local intensity = applyModifier(mod, list)
	MapService.TeleportToMap(list)
	refreshAlive()

	-- desastres
	local disasters = {}
	if Config.EnableDisasters then
		local mystery = math.random() < Config.MysteryChance
		local first = DisasterService.Start(current, Config.RoundTime, forced.disaster, { intensity = intensity, mystery = mystery })
		forced.disaster = nil
		if first then
			disasters[#disasters + 1] = first
			state.Disasters[#state.Disasters + 1] = mystery and { Title = "???", Icon = "❓" } or { Title = first.Title, Icon = first.Icon }
		end
		if mod and mod.Id == "Doble" and first then
			local second = DisasterService.Start(current, Config.RoundTime, DisasterService.Pick(current, first.Name), { intensity = intensity, delay = Config.DisasterDelay + 4 })
			if second then
				disasters[#disasters + 1] = second
				state.Disasters[#state.Disasters + 1] = { Title = second.Title, Icon = second.Icon }
			end
		end
	end
	CoinDrops.SpawnRound(current, Config.CoinPickups)

	local total = Config.DisasterDelay + Config.RoundTime
	setPhase("Round", total, mod and (mod.Title .. " · " .. info.Title) or ("Sobrevive en " .. info.Title))

	local startT = now()
	local endT = startT + total
	local secondTried = false
	local nextTick = startT + Config.DisasterDelay + Config.AliveTickInterval
	forced.skip = false
	while now() < endT and not forced.skip do
		task.wait(0.5)
		-- revisar vivos (por si alguien salio del mapa o del juego)
		for player, p in pairs(participants) do
			if not player.Parent then
				if p.conn then
					p.conn:Disconnect()
				end
				participants[player] = nil
			elseif p.alive then
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if not hum or hum.Health <= 0 then
					onDeath(player)
				elseif now() > startT + 6 and not MapService.IsOnMap(player) then
					-- fuera del mapa (por ejemplo, cayo al vacio y reaparecio en el lobby)
					p.alive = false
					refreshAlive()
				end
			end
		end
		if refreshAlive() == 0 then
			break
		end
		-- monedas por seguir vivo
		if now() >= nextTick then
			nextTick = nextTick + Config.AliveTickInterval
			for player, p in pairs(participants) do
				if p.alive then
					Rewards.Give(player, Config.AliveTickCoins, 2, { text = "Sigues vivo" })
				end
			end
		end
		-- segundo desastre a mitad de ronda
		if not secondTried and Config.EnableDisasters and now() > startT + Config.DisasterDelay + Config.RoundTime * 0.45 then
			secondTried = true
			if #disasters == 1 and math.random() < Config.SecondDisasterChance then
				local remaining = endT - now()
				local extra = DisasterService.Start(current, remaining - 5, DisasterService.Pick(current, disasters[1].Name), { intensity = intensity, delay = 5 })
				if extra then
					disasters[#disasters + 1] = extra
					state.Disasters[#state.Disasters + 1] = { Title = extra.Title, Icon = extra.Icon }
					broadcast()
				end
			end
		end
	end

	DisasterService.StopAll()
	CoinDrops.Clear()

	-- ===== Resultados =====
	local survivors, names = {}, {}
	for player, p in pairs(participants) do
		if p.alive and player.Parent then
			survivors[#survivors + 1] = player
			names[#names + 1] = player.DisplayName
		end
	end
	local titles = {}
	for _, d in ipairs(disasters) do
		titles[#titles + 1] = d.Title
	end
	setPhase("Results", Config.ResultsTime, #survivors > 0 and ("Sobrevivieron " .. #survivors .. " de " .. state.Total) or "No sobrevivio nadie")

	local count = state.Total
	for player, p in pairs(participants) do
		if p.conn then
			p.conn:Disconnect()
		end
		local data = PlayerData.Get(player)
		if data and player.Parent then
			local result = { Map = info.Title, Disasters = titles, Survivors = names, Total = count, Modifier = mod and mod.Title or nil }
			Rewards.Stat(player, "Rounds", 1)
			if p.alive then
				local streak = data.Stats.Streak + 1
				data.Stats.Streak = streak
				data.Stats.BestStreak = math.max(data.Stats.BestStreak, streak)
				local coins = Config.SurviveCoins + math.min(streak - 1, Config.MaxStreakBonus) * Config.StreakBonusCoins
				local c, x = Rewards.Give(player, coins, Config.SurviveXP, { text = "¡Sobreviviste!", lucky = true })
				Rewards.Stat(player, "Wins", 1)
				Rewards.Collect(player, "MapsDone", winner, "MapsSurvived")
				for _, d in ipairs(disasters) do
					Rewards.Collect(player, "DisastersDone", d.Name, "DisastersSurvived")
				end
				if #survivors == 1 and count >= 3 then
					Rewards.Stat(player, "SoleSurvivor", 1)
				end
				if #disasters >= 2 then
					Rewards.Stat(player, "DoubleSurvived", 1)
				end
				result.Survived, result.Coins, result.XP, result.Streak = true, c, x, streak
			else
				data.Stats.Streak = 0
				Rewards.Stat(player, "Deaths", 1)
				local c, x = Rewards.Give(player, Config.ParticipationCoins, Config.ParticipationXP, { text = "Participacion" })
				result.Survived, result.Coins, result.XP, result.Streak = false, c, x, 0
			end
			RoundResults:FireClient(player, result)
		end
	end
	task.wait(Config.ResultsTime)

	-- vuelta al lobby
	local back = {}
	for player in pairs(participants) do
		if player.Parent then
			back[#back + 1] = player
			player:SetAttribute("EnRonda", nil)
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.MaxHealth = 100
				hum.Health = 100
			end
		end
	end
	revertModifier()
	MapService.ReturnToLobby(back)
	for _, player in ipairs(back) do
		task.spawn(Gear.Refresh, player)
	end
	table.clear(participants)
	state.Map, state.Modifier, state.Disasters = nil, nil, {}
	state.Alive, state.Total, state.AliveIds = 0, 0, {}
	task.wait(1)
	MapService.Unload()
end

function GameLoop.Run()
	while true do
		while #Players:GetPlayers() < Config.MinPlayers do
			setPhase("Waiting", nil, "Esperando jugadores...")
			task.wait(2)
		end
		setPhase("Intermission", Config.IntermissionTime, "Descanso: compra en la tienda o haz el obby")
		countdown(Config.IntermissionTime, "Siguiente ronda en")

		setPhase("Vote", Config.VoteTime, "¡Vota el siguiente mapa!")
		local winner
		if forced.map then
			winner, forced.map = forced.map, nil
		else
			winner = VoteService.Run(VoteService.PickOptions(Config.OptionsPerVote), Config.VoteTime)
		end

		local ok, err = pcall(playRound, winner)
		if not ok then
			warn("GameLoop: error en la ronda: " .. tostring(err))
			pcall(DisasterService.StopAll)
			pcall(revertModifier)
			pcall(MapService.ReturnToLobby)
			pcall(MapService.Unload)
			table.clear(participants)
			task.wait(3)
		end
	end
end

return GameLoop
]])

add("ServerScriptService", { "IslasServer" }, "Gear", "ModuleScript", [[
-- Gear: crea las herramientas (gears) y estelas, y aplica sus efectos en el servidor.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)

local PlaySound = Net.Event("PlaySound")

local Gear = {}

local C = Color3.fromRGB
local V = Vector3.new

local function characterMass(char)
	local m = 0
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and not d.Massless then
			m = m + d:GetMass()
		end
	end
	return m
end

local function cooldown(tool, seconds)
	tool.Enabled = false
	tool:SetAttribute("RecargaHasta", workspace:GetServerTimeNow() + seconds)
	task.delay(seconds, function()
		if tool.Parent then
			tool.Enabled = true
		end
	end)
end

local function addForce(char, name, fraction)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local att = hrp:FindFirstChild("IslasFuerzaAtt") or Instance.new("Attachment")
	att.Name = "IslasFuerzaAtt"
	att.Parent = hrp
	local f = Instance.new("VectorForce")
	f.Name = name
	f.Attachment0 = att
	f.RelativeTo = Enum.ActuatorRelativeTo.World
	f.ApplyAtCenterOfMass = true
	f.Force = V(0, characterMass(char) * workspace.Gravity * fraction, 0)
	f.Parent = hrp
end

local function removeForce(char, name)
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local f = hrp and hrp:FindFirstChild(name)
	if f then
		f:Destroy()
	end
end

-- Velocidad base del jugador (la cambian los modificadores de ronda)
local function baseSpeed(hum)
	return hum:GetAttribute("VelocidadBase") or 16
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

-- ======================================================================
-- Fabricas de cada gear
-- ======================================================================
local builders = {}

local function baseTool(id)
	local item = Catalog.ById[id]
	local tool = Instance.new("Tool")
	tool.Name = id
	tool.ToolTip = item.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("IslasGear", true)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = V(0.6, 1.4, 0.6)
	handle.Color = item.Color or C(200, 200, 200)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	return tool, handle
end

builders.GloboVerde = function()
	local tool, handle = baseTool("GloboVerde")
	handle.Size = V(0.2, 2, 0.2)
	handle.Color = C(240, 240, 240)
	local balloon = Instance.new("Part")
	balloon.Name = "Globo"
	balloon.Shape = Enum.PartType.Ball
	balloon.Size = V(2.6, 2.6, 2.6)
	balloon.Color = C(80, 220, 80)
	balloon.Material = Enum.Material.SmoothPlastic
	balloon.CanCollide = false
	balloon.Massless = true
	balloon.CFrame = handle.CFrame + V(0, 2.2, 0)
	balloon.Parent = tool
	weld(handle, balloon)
	local char
	tool.Equipped:Connect(function()
		char = tool.Parent
		addForce(char, "IslasGlobo", 0.62)
	end)
	tool.Unequipped:Connect(function()
		removeForce(char, "IslasGlobo")
	end)
	return tool
end

builders.BobinaVelocidad = function()
	local tool = baseTool("BobinaVelocidad")
	local hum
	tool.Equipped:Connect(function()
		hum = tool.Parent:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = baseSpeed(hum) * 1.6
		end
	end)
	tool.Unequipped:Connect(function()
		if hum then
			hum.WalkSpeed = baseSpeed(hum)
		end
	end)
	return tool
end

builders.BobinaGravedad = function()
	local tool = baseTool("BobinaGravedad")
	local hum, char
	tool.Equipped:Connect(function()
		char = tool.Parent
		hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.UseJumpPower = false
			hum.JumpHeight = 16
		end
		addForce(char, "IslasGravedad", 0.45)
	end)
	tool.Unequipped:Connect(function()
		if hum then
			hum.JumpHeight = 7.2
		end
		removeForce(char, "IslasGravedad")
	end)
	return tool
end

builders.Linterna = function()
	local tool, handle = baseTool("Linterna")
	handle.Size = V(0.5, 0.5, 1.6)
	handle.Color = C(40, 40, 45)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = 60
	spot.Angle = 50
	spot.Brightness = 4
	spot.Parent = handle
	local glow = Instance.new("PointLight")
	glow.Range = 14
	glow.Brightness = 1
	glow.Parent = handle
	return tool
end

builders.Paraguas = function()
	local tool, handle = baseTool("Paraguas")
	handle.Size = V(0.2, 3, 0.2)
	handle.Color = C(40, 40, 50)
	local canopy = Instance.new("Part")
	canopy.Name = "Tela"
	canopy.Shape = Enum.PartType.Cylinder
	canopy.Size = V(0.4, 6, 6)
	canopy.Color = C(120, 160, 255)
	canopy.CanCollide = false
	canopy.Massless = true
	canopy.CFrame = (handle.CFrame + V(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	canopy.Parent = tool
	weld(handle, canopy)
	return tool
end

builders.Botiquin = function()
	local tool, handle = baseTool("Botiquin")
	handle.Size = V(1, 0.8, 1.2)
	handle.Color = C(240, 240, 240)
	tool.Activated:Connect(function()
		local hum = tool.Parent and tool.Parent:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and tool.Enabled then
			hum.Health = math.min(hum.MaxHealth, hum.Health + 40)
			cooldown(tool, 12)
			local player = Players:GetPlayerFromCharacter(tool.Parent)
			if player then
				PlaySound:FireClient(player, "Coin", nil, 0.6)
			end
		end
	end)
	return tool
end

builders.Jetpack = function()
	local tool, handle = baseTool("Jetpack")
	handle.Size = V(1, 1.4, 0.8)
	tool.Activated:Connect(function()
		local char = tool.Parent
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and tool.Enabled then
			local v = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = V(v.X, 80, v.Z)
			local fire = Instance.new("Fire")
			fire.Size = 4
			fire.Heat = 15
			fire.Parent = handle
			Debris:AddItem(fire, 1)
			cooldown(tool, 4)
		end
	end)
	return tool
end

builders.Escudo = function()
	local tool, handle = baseTool("Escudo")
	handle.Shape = Enum.PartType.Ball
	handle.Size = V(1, 1, 1)
	handle.Material = Enum.Material.Neon
	tool.Activated:Connect(function()
		local char = tool.Parent
		if char and tool.Enabled and not char:FindFirstChildOfClass("ForceField") then
			local ff = Instance.new("ForceField")
			ff.Visible = true
			ff.Parent = char
			Debris:AddItem(ff, 4)
			cooldown(tool, 45)
		end
	end)
	return tool
end

builders.Garfio = function()
	local tool, handle = baseTool("Garfio")
	handle.Size = V(0.4, 0.4, 1.8)
	return tool -- el disparo llega por GearAction (necesita el punto al que apunta el jugador)
end

local function onGearAction(player, id, target)
	if id ~= "Garfio" or typeof(target) ~= "Vector3" then
		return
	end
	local char = player.Character
	local tool = char and char:FindFirstChild("Garfio")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not tool or not hrp or not tool.Enabled then
		return
	end
	local off = target - hrp.Position
	if off.Magnitude > 140 or off.Magnitude < 3 then
		return
	end
	hrp.AssemblyLinearVelocity = off.Unit * 115 + V(0, 25, 0)
	cooldown(tool, 3)
	PlaySound:FireAllClients("Whoosh", hrp.Position, 0.7)
end

function Gear.Make(id)
	local b = builders[id]
	return b and b() or nil
end

-- ======================================================================
-- Repartir gears y estelas
-- ======================================================================
local function removeGears(player)
	for _, container in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		if container then
			for _, t in ipairs(container:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("IslasGear") then
					t:Destroy()
				end
			end
		end
	end
	if player.Character then
		removeForce(player.Character, "IslasGlobo")
		removeForce(player.Character, "IslasGravedad")
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = baseSpeed(hum)
			hum.JumpHeight = 7.2
		end
	end
end

-- Da al jugador sus gears equipados (y extras temporales, p. ej. la linterna de la ronda nocturna)
function Gear.Give(player, extras)
	local data = PlayerData.Get(player)
	local backpack = player:FindFirstChild("Backpack")
	if not data or not backpack then
		return
	end
	removeGears(player)
	local given = {}
	local slots = Catalog.GearSlots(data.Owned)
	for i, id in ipairs(data.Equipped.Gears or {}) do
		if i <= slots and data.Owned[id] and not given[id] then
			local tool = Gear.Make(id)
			if tool then
				tool.Parent = backpack
				given[id] = true
			end
		end
	end
	for _, id in ipairs(extras or {}) do
		if not given[id] then
			local tool = Gear.Make(id)
			if tool then
				tool:SetAttribute("Temporal", true)
				tool.Parent = backpack
				given[id] = true
			end
		end
	end
end

function Gear.ApplyTrail(player)
	local data = PlayerData.Get(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not data or not hrp then
		return
	end
	local old = hrp:FindFirstChild("IslasEstela")
	if old then
		old:Destroy()
	end
	for _, n in ipairs({ "IslasEstelaA", "IslasEstelaB" }) do
		local a = hrp:FindFirstChild(n)
		if a then
			a:Destroy()
		end
	end
	local id = data.Equipped.Trail
	local item = id and Catalog.ById[id]
	if not item or not data.Owned[id] then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "IslasEstelaA"
	a0.Position = V(0, 0.9, 0)
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Name = "IslasEstelaB"
	a1.Position = V(0, -0.9, 0)
	a1.Parent = hrp
	local keypoints = {}
	local n = #item.Colors
	for i, c in ipairs(item.Colors) do
		keypoints[i] = ColorSequenceKeypoint.new(n == 1 and 0 or (i - 1) / (n - 1), c)
	end
	if n == 1 then
		keypoints[2] = ColorSequenceKeypoint.new(1, item.Colors[1])
	end
	local trail = Instance.new("Trail")
	trail.Name = "IslasEstela"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(keypoints)
	trail.Lifetime = 0.6
	trail.LightEmission = 0.5
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = hrp
end

function Gear.Refresh(player)
	Gear.Give(player)
	Gear.ApplyTrail(player)
end

function Gear.Init()
	Net.Event("GearAction").OnServerEvent:Connect(onGearAction)
	local function onPlayer(player)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("HumanoidRootPart", 10)
			PlayerData.WaitFor(player, 15)
			task.wait(0.2)
			if player.Character == char then
				Gear.Refresh(player)
			end
		end)
		if player.Character then
			task.spawn(function()
				PlayerData.WaitFor(player, 15)
				Gear.Refresh(player)
			end)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return Gear
]])

print("Islas de Desastres: parte 3 de 5 instalada")
