-- SoundFX: sonidos en el cliente (en la posicion del mundo o en la interfaz), con limite por segundo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Sounds = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Sounds"))
local Net = require(ReplicatedStorage.IslasShared:WaitForChild("Net"))

local SoundFX = {}
SoundFX.Volume = 1
SoundFX.Muted = false

local budget, budgetReset = 0, 0
local MAX_PER_SECOND = 10

local function allowed()
	local now = os.clock()
	if now - budgetReset > 1 then
		budget, budgetReset = 0, now
	end
	if budget >= MAX_PER_SECOND then
		return false
	end
	budget = budget + 1
	return true
end

local function idFor(name)
	return Sounds[name] or name
end

-- Sonido de interfaz (no posicional)
function SoundFX.Play(name, volume, pitch)
	if SoundFX.Muted or not allowed() then
		return
	end
	local id = idFor(name)
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = (volume or 0.5) * SoundFX.Volume
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 4)
end

-- Sonido en un punto del mundo
function SoundFX.PlayAt(name, position, volume, pitch)
	if SoundFX.Muted or not allowed() then
		return
	end
	local id = idFor(name)
	if not id or id == "" then
		return
	end
	local att = Instance.new("Attachment")
	att.WorldPosition = position
	att.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = (volume or 0.6) * SoundFX.Volume
	s.PlaybackSpeed = pitch or (0.9 + math.random() * 0.2)
	s.RollOffMaxDistance = 400
	s.Parent = att
	s:Play()
	Debris:AddItem(att, 4)
end

function SoundFX.Init()
	Net.Event("PlaySound").OnClientEvent:Connect(function(name, position, volume)
		if typeof(position) == "Vector3" then
			SoundFX.PlayAt(name, position, volume)
		else
			SoundFX.Play(name, volume)
		end
	end)
end

return SoundFX
