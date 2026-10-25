-- Cliente: punto de entrada del jugador. Carga todos los modulos de la carpeta Modulos en orden.
local modulesFolder = script.Parent:WaitForChild("Modulos")

local ORDER = {
	"UI", "Quality", "SoundFX", "State", "Popups", "DebrisFX", "DisasterFX", "MapAnimator", "Hud",
	"VoteUI", "ResultsUI", "ShopUI", "DailyUI", "AchievementsUI", "SettingsUI", "SpectateUI",
	"ElevatorUI", "GearClient", "Music",
}

local modules = {}
for _, name in ipairs(ORDER) do
	local m = modulesFolder:FindFirstChild(name)
	if m then
		local ok, result = pcall(require, m)
		if ok then
			modules[name] = result
		else
			warn("Cliente: no se pudo cargar " .. name .. ": " .. tostring(result))
		end
	end
end
for _, name in ipairs(ORDER) do
	local m = modules[name]
	if type(m) == "table" and m.Init then
		local ok, err = pcall(m.Init, modules)
		if not ok then
			warn("Cliente: error iniciando " .. name .. ": " .. tostring(err))
		end
	end
end
