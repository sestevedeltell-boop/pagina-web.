-- State: ultimo estado conocido del jugador (monedas, nivel, inventario...) y de la ronda.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local State = {
	Data = nil, -- snapshot de PlayerData
	Round = { Phase = "Intermission", EndsAt = 0, Disasters = {}, Alive = 0, Total = 0, AliveIds = {} },
}

local dataListeners, roundListeners = {}, {}

function State.OnData(fn)
	dataListeners[#dataListeners + 1] = fn
	if State.Data then
		task.spawn(fn, State.Data, nil)
	end
end

function State.OnRound(fn)
	roundListeners[#roundListeners + 1] = fn
	task.spawn(fn, State.Round)
end

local function setData(data)
	if typeof(data) ~= "table" then
		return
	end
	local old = State.Data
	State.Data = data
	for _, fn in ipairs(dataListeners) do
		task.spawn(fn, data, old)
	end
end

function State.Init()
	Net.Event("DataUpdate").OnClientEvent:Connect(setData)
	Net.Event("RoundState").OnClientEvent:Connect(function(st)
		if typeof(st) ~= "table" then
			return
		end
		State.Round = st
		for _, fn in ipairs(roundListeners) do
			task.spawn(fn, st)
		end
	end)
	task.spawn(function()
		local ok, data = pcall(function()
			return Net.Function("GetData"):InvokeServer()
		end)
		if ok and data and not State.Data then
			setData(data)
		end
	end)
end

return State
