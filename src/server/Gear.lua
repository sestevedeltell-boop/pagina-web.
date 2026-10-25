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
