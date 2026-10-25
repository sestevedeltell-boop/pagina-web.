-- ShopService: compras y equipamiento (RemoteFunction "ShopRequest").
--   ShopRequest:InvokeServer("buy", id)   -> ok, mensaje
--   ShopRequest:InvokeServer("equip", id) -> ok, mensaje   (gears: pone/quita; estela: cambia)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)
local Gear = require(script.Parent.Gear)

local PlaySound = Net.Event("PlaySound")

local ShopService = {}

local busy = {}

local function equip(player, data, item)
	if item.Kind == "Gear" then
		local list = data.Equipped.Gears
		local idx = table.find(list, item.Id)
		if idx then
			table.remove(list, idx)
			return true, item.Name .. " quitado"
		end
		local slots = Catalog.GearSlots(data.Owned)
		while #list >= slots do
			table.remove(list, 1)
		end
		list[#list + 1] = item.Id
		return true, item.Name .. " equipado"
	elseif item.Kind == "Trail" then
		if data.Equipped.Trail == item.Id then
			data.Equipped.Trail = nil
			return true, "Estela quitada"
		end
		data.Equipped.Trail = item.Id
		return true, item.Name .. " equipada"
	end
	return false, "No se puede equipar"
end

function ShopService.Handle(player, action, id)
	local data = PlayerData.Get(player)
	local item = typeof(id) == "string" and Catalog.ById[id]
	if not data or not item then
		return false, "Objeto no valido"
	end
	if busy[player] then
		return false, "Espera un momento"
	end
	busy[player] = true
	local ok, msg = false, "Accion no valida"
	if action == "buy" then
		if data.Owned[id] then
			ok, msg = false, "Ya lo tienes"
		elseif not PlayerData.Spend(player, item.Price) then
			ok, msg = false, "Te faltan " .. (item.Price - data.Coins) .. " monedas"
		else
			data.Owned[id] = true
			Rewards.Stat(player, "Purchases", 1)
			if item.Kind ~= "Upgrade" then
				equip(player, data, item)
			end
			ok, msg = true, "¡Comprado: " .. item.Name .. "!"
			PlaySound:FireClient(player, "Win", nil, 0.8)
		end
	elseif action == "equip" then
		if not data.Owned[id] then
			ok, msg = false, "Primero tienes que comprarlo"
		else
			ok, msg = equip(player, data, item)
		end
	end
	if ok then
		PlayerData.MarkDirty(player, "Shop")
		-- en el lobby se aplica al momento; en la ronda, los gears nuevos llegan en la siguiente
		if player:GetAttribute("EnRonda") ~= true then
			Gear.Refresh(player)
		else
			Gear.ApplyTrail(player)
		end
	end
	busy[player] = nil
	return ok, msg
end

function ShopService.Init()
	Net.Function("ShopRequest").OnServerInvoke = function(player, action, id)
		local ok, a, b = pcall(ShopService.Handle, player, action, id)
		if not ok then
			warn("ShopService: " .. tostring(a))
			busy[player] = nil
			return false, "Error"
		end
		return a, b
	end
end

return ShopService
