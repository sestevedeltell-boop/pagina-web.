-- CollisionGroups: grupos de colision para que los escombros no choquen entre si (lo mas caro de la fisica)
-- y los fragmentos visuales del cliente no empujen a los jugadores.
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local CollisionGroups = {
	Debris = "IslasDebris", -- escombros fisicos del servidor
	Fx = "IslasFx", -- fragmentos visuales del cliente
	Players = "IslasPlayers",
}

local done = false

function CollisionGroups.Setup()
	if done then
		return
	end
	done = true
	local ok, err = pcall(function()
		for _, g in ipairs({ CollisionGroups.Debris, CollisionGroups.Fx, CollisionGroups.Players }) do
			if not PhysicsService:IsCollisionGroupRegistered(g) then
				PhysicsService:RegisterCollisionGroup(g)
			end
		end
		PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Debris, CollisionGroups.Debris, false)
		PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Fx, CollisionGroups.Fx, false)
		PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Fx, CollisionGroups.Players, false)
		PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Fx, CollisionGroups.Debris, false)
		PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Players, CollisionGroups.Players, false)
	end)
	if not ok then
		warn("CollisionGroups: no se pudieron crear los grupos: " .. tostring(err))
	end

	local function setGroup(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = CollisionGroups.Players
		end
	end
	local function onCharacter(char)
		for _, d in ipairs(char:GetDescendants()) do
			setGroup(d)
		end
		char.DescendantAdded:Connect(setGroup)
	end
	local function onPlayer(player)
		if player.Character then
			onCharacter(player.Character)
		end
		player.CharacterAdded:Connect(onCharacter)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return CollisionGroups
