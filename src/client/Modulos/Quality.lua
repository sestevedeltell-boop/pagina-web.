-- Quality: calidad de efectos automatica segun los FPS del jugador (1 = baja, 2 = media, 3 = alta).
-- Si el juego va lento se reducen fragmentos, particulas y efectos; si va sobrado se suben.
-- El jugador puede fijarla a mano desde Ajustes.
local RunService = game:GetService("RunService")

local Quality = {}

Quality.Level = 3
Quality.Auto = true
Quality.FPS = 60

local listeners = {}
function Quality.OnChanged(fn)
	listeners[#listeners + 1] = fn
end

local function set(level)
	level = math.clamp(level, 1, 3)
	if level ~= Quality.Level then
		Quality.Level = level
		for _, fn in ipairs(listeners) do
			task.spawn(fn, level)
		end
	end
end

function Quality.Set(level, auto)
	Quality.Auto = auto
	if level then
		set(level)
	end
end

local PRESETS = {
	{ MaxFragments = 70, PerBreak = 2, Life = 2.2, Particles = false, Distance = 220 },
	{ MaxFragments = 200, PerBreak = 4, Life = 3.2, Particles = true, Distance = 320 },
	{ MaxFragments = 420, PerBreak = 7, Life = 4.5, Particles = true, Distance = 450 },
}
function Quality.Settings()
	return PRESETS[Quality.Level]
end

function Quality.Init()
	local frames, acc, lowFor, highFor = 0, 0, 0, 0
	RunService.RenderStepped:Connect(function(dt)
		frames = frames + 1
		acc = acc + dt
		if acc >= 2 then
			local fps = frames / acc
			Quality.FPS = fps
			frames, acc = 0, 0
			if not Quality.Auto then
				return
			end
			if fps < 38 then
				lowFor = lowFor + 2
				highFor = 0
				if lowFor >= 4 then
					set(Quality.Level - 1)
					lowFor = 0
				end
			elseif fps > 56 then
				highFor = highFor + 2
				lowFor = 0
				if highFor >= 20 then
					set(Quality.Level + 1)
					highFor = 0
				end
			else
				lowFor, highFor = 0, 0
			end
		end
	end)
end

return Quality
