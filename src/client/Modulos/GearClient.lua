-- GearClient: entrada del jugador para los gears que necesitan saber a donde apuntas (garfio)
-- y aviso visual de recarga.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local GearClient = {}

function GearClient.Init(modules)
	local player = Players.LocalPlayer
	local mouse = player:GetMouse()
	local Popups = modules.Popups

	local function hook(tool)
		if not tool:IsA("Tool") or not tool:GetAttribute("IslasGear") or tool:GetAttribute("HookCliente") then
			return
		end
		tool:SetAttribute("HookCliente", true)
		tool.Activated:Connect(function()
			if tool.Name == "Garfio" then
				local hit = mouse.Hit
				if hit then
					Net.Event("GearAction"):FireServer("Garfio", hit.Position)
				end
			end
			local untilT = tool:GetAttribute("RecargaHasta")
			if untilT and untilT > workspace:GetServerTimeNow() and Popups then
				Popups.Toast("Recargando: " .. math.ceil(untilT - workspace:GetServerTimeNow()) .. " s")
			end
		end)
	end

	local function watch(container)
		for _, c in ipairs(container:GetChildren()) do
			hook(c)
		end
		container.ChildAdded:Connect(hook)
	end

	local backpack = player:WaitForChild("Backpack")
	watch(backpack)
	player.CharacterAdded:Connect(function(char)
		watch(char)
		local bp = player:WaitForChild("Backpack")
		if bp ~= backpack then
			backpack = bp
			watch(bp)
		end
	end)
	if player.Character then
		watch(player.Character)
	end
end

return GearClient
