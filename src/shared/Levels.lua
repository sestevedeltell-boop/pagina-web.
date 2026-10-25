-- Levels: curva de experiencia y titulos por nivel.
local Levels = {}

-- XP necesaria para pasar del nivel `level` al siguiente
function Levels.XPForLevel(level)
	return 100 + (level - 1) * 45 + math.floor((level - 1) ^ 1.5) * 10
end

-- Dada la XP total acumulada, devuelve nivel, XP dentro del nivel y XP necesaria
function Levels.FromTotal(total)
	local level = 1
	local need = Levels.XPForLevel(level)
	while total >= need do
		total = total - need
		level = level + 1
		need = Levels.XPForLevel(level)
		if level >= 999 then
			break
		end
	end
	return level, total, need
end

local TITLES = {
	{ 1, "Novato", Color3.fromRGB(200, 200, 200) },
	{ 5, "Superviviente", Color3.fromRGB(120, 220, 120) },
	{ 10, "Explorador", Color3.fromRGB(90, 180, 255) },
	{ 15, "Cazatormentas", Color3.fromRGB(160, 120, 255) },
	{ 20, "Veterano", Color3.fromRGB(255, 200, 80) },
	{ 30, "Indestructible", Color3.fromRGB(255, 120, 60) },
	{ 40, "Leyenda", Color3.fromRGB(255, 80, 120) },
	{ 60, "Inmortal", Color3.fromRGB(80, 255, 230) },
}

function Levels.Title(level)
	local best = TITLES[1]
	for _, t in ipairs(TITLES) do
		if level >= t[1] then
			best = t
		end
	end
	return best[2], best[3]
end

return Levels
