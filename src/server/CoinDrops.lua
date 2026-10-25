-- CoinDrops: monedas repartidas por el mapa durante la ronda (y en el lobby). Al tocarlas se cobran.
-- Con el "Iman de monedas" se recogen desde lejos. Los clientes las hacen girar (etiqueta IslasGira).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)

local PlaySound = Net.Event("PlaySound")

local CoinDrops = {}

local folder
local coins = {} -- [part] = value

local function ensureFolder()
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "MonedasRonda"
		folder.Parent = workspace
	end
	return folder
end

local function collect(coin, player)
	local value = coins[coin]
	if not value then
		return
	end
	coins[coin] = nil
	local pos = coin.Position
	coin:Destroy()
	Rewards.Give(player, value, 1, { text = value >= Config.BigCoinValue and "¡Moneda grande!" or nil, position = pos })
	Rewards.Stat(player, "CoinsPicked", value)
	PlaySound:FireClient(player, "Coin", pos, value >= Config.BigCoinValue and 1 or 0.6)
end

function CoinDrops.Spawn(position, value, parent)
	local big = value >= Config.BigCoinValue
	local coin = Instance.new("Part")
	coin.Name = big and "MonedaGrande" or "Moneda"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = big and Vector3.new(0.5, 4, 4) or Vector3.new(0.35, 2.4, 2.4)
	coin.Color = big and Color3.fromRGB(255, 120, 220) or Color3.fromRGB(255, 205, 50)
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CastShadow = false
	coin.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	coin:SetAttribute("GiroRPM", 40)
	coin:SetAttribute("GiroEje", "X")
	coin.Parent = parent or ensureFolder()
	CollectionService:AddTag(coin, "IslasGira")
	coins[coin] = value
	coin.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if player and hum and hum.Health > 0 then
			collect(coin, player)
		end
	end)
	return coin
end

-- Reparte monedas por la superficie del mapa
function CoinDrops.SpawnRound(current, count)
	CoinDrops.Clear()
	local b = current.Bounds
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { current.Folder }
	params.RespectCanCollide = true
	local placed = 0
	for _ = 1, count * 3 do
		if placed >= count then
			break
		end
		local x = b.x1 + math.random() * (b.x2 - b.x1)
		local z = b.z1 + math.random() * (b.z2 - b.z1)
		local hit = workspace:Raycast(Vector3.new(x, b.top + 30, z), Vector3.new(0, -(b.top - b.floor + 120), 0), params)
		if hit and hit.Position.Y > b.floor - 1 then
			local big = math.random() < Config.BigCoinChance
			CoinDrops.Spawn(hit.Position + Vector3.new(0, 2.5, 0), big and Config.BigCoinValue or Config.CoinValue)
			placed = placed + 1
		end
	end
	return placed
end

function CoinDrops.Clear()
	for coin in pairs(coins) do
		if coin.Parent and coin:IsDescendantOf(ensureFolder()) then
			coins[coin] = nil
			coin:Destroy()
		end
	end
end

function CoinDrops.Count()
	local n = 0
	for _ in pairs(coins) do
		n = n + 1
	end
	return n
end

function CoinDrops.Init()
	-- iman: recoge monedas cercanas
	task.spawn(function()
		while true do
			task.wait(0.3)
			if next(coins) then
				for _, player in ipairs(Players:GetPlayers()) do
					local data = PlayerData.Get(player)
					local char = player.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if data and data.Owned.Iman and hrp and hum and hum.Health > 0 then
						for coin in pairs(coins) do
							if coin.Parent and (coin.Position - hrp.Position).Magnitude < 16 then
								collect(coin, player)
							end
						end
					end
				end
			end
		end
	end)
end

return CoinDrops
