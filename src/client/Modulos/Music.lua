-- Music: musica de fondo del lobby y de las rondas (ids en Sounds.LobbyMusic / Sounds.RoundMusic).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Sounds"))

local Music = {}
local enabled = true
local sound

function Music.SetEnabled(on)
	enabled = on
	if sound then
		sound.Volume = on and 0.3 or 0
	end
end

function Music.Init(modules)
	if (Sounds.LobbyMusic or "") == "" and (Sounds.RoundMusic or "") == "" then
		return
	end
	sound = Instance.new("Sound")
	sound.Name = "MusicaIslas"
	sound.Looped = true
	sound.Volume = 0.3
	sound.Parent = SoundService
	local current
	modules.State.OnRound(function(st)
		local id = (st.Phase == "Round") and Sounds.RoundMusic or Sounds.LobbyMusic
		if id ~= "" and id ~= current then
			current = id
			sound.SoundId = id
			sound.Volume = enabled and 0.3 or 0
			sound:Play()
		end
	end)
end

return Music
