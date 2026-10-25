-- INSTALADOR de Islas de Desastres.
-- Crea (o reemplaza) estas carpetas: ReplicatedStorage.IslasShared, ServerStorage.IslasMapas,
-- ServerScriptService.IslasServer y StarterPlayer.StarterPlayerScripts.IslasClient.
-- No toca nada mas de tu juego.
-- PLUGIN: pega este texto en un Script nuevo (por ejemplo en ServerStorage), clic derecho sobre el Script >
-- "Save as Local Plugin...". Despues borra ese Script y usa el boton "Instalar Islas" de la pestana Plugins.

local function install()
	local services = {
		ReplicatedStorage = game:GetService("ReplicatedStorage"),
		ServerStorage = game:GetService("ServerStorage"),
		ServerScriptService = game:GetService("ServerScriptService"),
		StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"),
	}

	local function folderAt(service, path)
		local parent = services[service]
		for _, name in ipairs(path) do
			local f = parent:FindFirstChild(name)
			if not f then
				f = Instance.new("Folder")
				f.Name = name
				f.Parent = parent
			end
			parent = f
		end
		return parent
	end

	local function add(service, path, name, className, source)
		local parent = folderAt(service, path)
		local old = parent:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local inst = Instance.new(className)
		inst.Name = name
		inst.Source = source
		inst.Parent = parent
	end

	-- borra las carpetas antiguas para reinstalar limpio
	for _, pair in ipairs({
		{ "ReplicatedStorage", "IslasShared" },
		{ "ServerStorage", "IslasMapas" },
		{ "ServerScriptService", "IslasServer" },
		{ "StarterPlayerScripts", "IslasClient" },
	}) do
		local old = services[pair[1]]:FindFirstChild(pair[2])
		if old then
			old:Destroy()
		end
	end

	add("ReplicatedStorage", { "IslasShared" }, "Achievements", "ModuleScript", [[
-- Achievements: logros. Stat = estadistica del jugador que se compara con Goal.
-- Las estadisticas viven en PlayerData (Stats) y se actualizan en Rewards.
return {
	{ Id = "Primera", Name = "Primera vez", Desc = "Sobrevive a tu primera ronda", Stat = "Wins", Goal = 1, Reward = 25 },
	{ Id = "Diez", Name = "Duro de pelar", Desc = "Sobrevive 10 rondas", Stat = "Wins", Goal = 10, Reward = 100 },
	{ Id = "Cincuenta", Name = "Superviviente nato", Desc = "Sobrevive 50 rondas", Stat = "Wins", Goal = 50, Reward = 400 },
	{ Id = "Doscientas", Name = "Leyenda viva", Desc = "Sobrevive 200 rondas", Stat = "Wins", Goal = 200, Reward = 1500 },
	{ Id = "Racha5", Name = "En racha", Desc = "Consigue una racha de 5 rondas", Stat = "BestStreak", Goal = 5, Reward = 150 },
	{ Id = "Racha10", Name = "Imparable", Desc = "Consigue una racha de 10 rondas", Stat = "BestStreak", Goal = 10, Reward = 500 },
	{ Id = "Racha25", Name = "Inmortal", Desc = "Consigue una racha de 25 rondas", Stat = "BestStreak", Goal = 25, Reward = 2000 },
	{ Id = "Jugadas25", Name = "Habitual", Desc = "Juega 25 rondas", Stat = "Rounds", Goal = 25, Reward = 100 },
	{ Id = "Jugadas100", Name = "Adicto a los desastres", Desc = "Juega 100 rondas", Stat = "Rounds", Goal = 100, Reward = 500 },
	{ Id = "Rico", Name = "Hucha llena", Desc = "Gana 1.000 monedas en total", Stat = "CoinsEarned", Goal = 1000, Reward = 100 },
	{ Id = "Millonario", Name = "Magnate", Desc = "Gana 20.000 monedas en total", Stat = "CoinsEarned", Goal = 20000, Reward = 1000 },
	{ Id = "Nivel10", Name = "Nivel 10", Desc = "Llega al nivel 10", Stat = "Level", Goal = 10, Reward = 200 },
	{ Id = "Nivel25", Name = "Nivel 25", Desc = "Llega al nivel 25", Stat = "Level", Goal = 25, Reward = 750 },
	{ Id = "Turista", Name = "Turista", Desc = "Sobrevive en 5 mapas distintos", Stat = "MapsSurvived", Goal = 5, Reward = 200 },
	{ Id = "Trotamundos", Name = "Trotamundos", Desc = "Sobrevive en 10 mapas distintos", Stat = "MapsSurvived", Goal = 10, Reward = 600 },
	{ Id = "Cazador", Name = "Cazador de desastres", Desc = "Sobrevive a 8 desastres distintos", Stat = "DisastersSurvived", Goal = 8, Reward = 300 },
	{ Id = "Coleccionista", Name = "Coleccionista", Desc = "Sobrevive a 15 desastres distintos", Stat = "DisastersSurvived", Goal = 15, Reward = 1200 },
	{ Id = "Solitario", Name = "El ultimo en pie", Desc = "Se el unico superviviente de una ronda con 3+ jugadores", Stat = "SoleSurvivor", Goal = 1, Reward = 300 },
	{ Id = "Doble", Name = "Doble o nada", Desc = "Sobrevive a una ronda con dos desastres", Stat = "DoubleSurvived", Goal = 1, Reward = 200 },
	{ Id = "Recolector", Name = "Recolector", Desc = "Recoge 200 monedas del mapa", Stat = "CoinsPicked", Goal = 200, Reward = 250 },
	{ Id = "Comprador", Name = "De compras", Desc = "Compra 5 cosas en la tienda", Stat = "Purchases", Goal = 5, Reward = 150 },
	{ Id = "Parkour", Name = "Parkour", Desc = "Completa el obby del lobby", Stat = "ObbyCompleted", Goal = 1, Reward = 100 },
	{ Id = "Fiel", Name = "Fiel", Desc = "Reclama la recompensa diaria 7 dias seguidos", Stat = "DailyStreak", Goal = 7, Reward = 500 },
}
]])

	add("ReplicatedStorage", { "IslasShared" }, "Catalog", "ModuleScript", [[
-- Catalog: todo lo que se puede comprar con monedas.
-- Kind: "Gear" (herramienta que llevas en la ronda), "Trail" (estela cosmetica), "Upgrade" (mejora permanente)

local C = Color3.fromRGB

local Catalog = {}

Catalog.Items = {
	-- ===== Gears =====
	{ Id = "Linterna", Kind = "Gear", Name = "Linterna", Price = 100, Icon = "🔦", Color = C(255, 240, 160),
		Desc = "Ilumina a tu alrededor en tormentas, niebla y rondas nocturnas." },
	{ Id = "Botiquin", Kind = "Gear", Name = "Botiquin", Price = 150, Icon = "🩹", Color = C(255, 90, 90),
		Desc = "Clic: te cura 40 de vida. Recarga 12 s." },
	{ Id = "GloboVerde", Kind = "Gear", Name = "Globo verde", Price = 250, Icon = "🎈", Color = C(90, 220, 90),
		Desc = "Mientras lo llevas caes despacio y saltas mas alto. El clasico." },
	{ Id = "Paraguas", Kind = "Gear", Name = "Paraguas", Price = 300, Icon = "☂️", Color = C(120, 160, 255),
		Desc = "Te protege de la lluvia acida, la ventisca y la tormenta de arena." },
	{ Id = "BobinaVelocidad", Kind = "Gear", Name = "Bobina de velocidad", Price = 400, Icon = "⚡", Color = C(80, 200, 255),
		Desc = "Corres un 60% mas rapido mientras la llevas." },
	{ Id = "BobinaGravedad", Kind = "Gear", Name = "Bobina de gravedad", Price = 450, Icon = "🌀", Color = C(190, 120, 255),
		Desc = "Saltos enormes y caidas suaves." },
	{ Id = "Jetpack", Kind = "Gear", Name = "Mochila cohete", Price = 1500, Icon = "🚀", Color = C(255, 150, 60),
		Desc = "Clic: impulso hacia arriba. Recarga 4 s." },
	{ Id = "Garfio", Kind = "Gear", Name = "Garfio", Price = 1800, Icon = "🪝", Color = C(200, 200, 210),
		Desc = "Clic: te lanza hacia donde apuntes. Recarga 3 s." },
	{ Id = "Escudo", Kind = "Gear", Name = "Escudo de energia", Price = 2500, Icon = "🛡️", Color = C(90, 255, 230),
		Desc = "Clic: eres invulnerable durante 4 s. Recarga 45 s." },

	-- ===== Estelas =====
	{ Id = "EstelaAzul", Kind = "Trail", Name = "Estela azul", Price = 200, Icon = "💙",
		Colors = { C(80, 160, 255), C(30, 60, 200) } },
	{ Id = "EstelaNeon", Kind = "Trail", Name = "Estela neon", Price = 350, Icon = "💚",
		Colors = { C(80, 255, 120), C(20, 200, 255) } },
	{ Id = "EstelaFuego", Kind = "Trail", Name = "Estela de fuego", Price = 600, Icon = "🔥",
		Colors = { C(255, 230, 80), C(255, 60, 20) } },
	{ Id = "EstelaArcoiris", Kind = "Trail", Name = "Estela arcoiris", Price = 1200, Icon = "🌈",
		Colors = { C(255, 60, 60), C(255, 220, 60), C(60, 255, 120), C(60, 140, 255), C(200, 80, 255) } },
	{ Id = "EstelaDorada", Kind = "Trail", Name = "Estela dorada", Price = 3500, Icon = "👑",
		Colors = { C(255, 240, 150), C(255, 170, 30) } },

	-- ===== Mejoras permanentes =====
	{ Id = "RanuraExtra", Kind = "Upgrade", Name = "Ranura de gear extra", Price = 2000, Icon = "🎒",
		Desc = "Puedes llevar 2 gears a la vez en las rondas." },
	{ Id = "Iman", Kind = "Upgrade", Name = "Iman de monedas", Price = 800, Icon = "🧲",
		Desc = "Recoges las monedas del mapa desde mucho mas lejos." },
	{ Id = "VidaExtra", Kind = "Upgrade", Name = "Corazon reforzado", Price = 1600, Icon = "❤️",
		Desc = "Empiezas cada ronda con 125 de vida." },
	{ Id = "Suerte", Kind = "Upgrade", Name = "Trebol de la suerte", Price = 1200, Icon = "🍀",
		Desc = "+25% de monedas por sobrevivir." },
}

Catalog.ById = {}
for i, item in ipairs(Catalog.Items) do
	item.Order = i
	Catalog.ById[item.Id] = item
end

Catalog.BaseGearSlots = 1

function Catalog.GearSlots(owned)
	return Catalog.BaseGearSlots + ((owned and owned.RanuraExtra) and 1 or 0)
end

return Catalog
]])

	add("ReplicatedStorage", { "IslasShared" }, "Config", "ModuleScript", [[
-- Config: todos los ajustes del juego en un sitio. Cambia lo que quieras aqui.
return {
	-- ===== Mundo =====
	-- Donde se construye el mapa elegido: lejos del lobby y alto (lejos de FallenPartsDestroyHeight)
	MapOrigin = Vector3.new(8000, 1000, 0),
	-- Lobby propio: "auto" = solo si en workspace no hay ya una carpeta/modelo llamado "Lobby"
	BuildLobby = "auto",
	LobbyOrigin = Vector3.new(-6000, 400, 0),
	-- Nombre del lobby en el workspace (si tu juego ya tiene uno con otro nombre, ponlo aqui)
	LobbyName = "Lobby",

	-- ===== Mapas propios (los de tu otro juego) =====
	-- Carpetas de ServerStorage cuyos Model/Folder son mapas votables. Solo se clonan al workspace cuando ganan
	-- la votacion y se borran al terminar la ronda.
	CustomMapFolders = { "IslasMapasPropios" },
	-- Mapas que no quieres que salgan (por nombre), por ejemplo uno generado que este repetido con uno tuyo
	DisabledMaps = {},
	-- true = desactiva los scripts que traigan dentro tus mapas (por si llevan logica vieja de rondas/desastres)
	DisableMapScripts = false,

	-- ===== Rondas =====
	RunDefaultLoop = true, -- false si quieres llevar tu propio bucle (ver README)
	MinPlayers = 1,
	IntermissionTime = 20,
	VoteTime = 12,
	OptionsPerVote = 3,
	RoundTime = 150,
	ResultsTime = 7,

	-- ===== Desastres =====
	EnableDisasters = true,
	DisasterDelay = 8, -- aviso tras llegar a la isla antes de que empiece el desastre
	SecondDisasterChance = 0.25, -- probabilidad de que a mitad de ronda llegue otro desastre
	ModifierChance = 0.45, -- probabilidad de que la ronda tenga un modificador
	MysteryChance = 0.12, -- probabilidad de "desastre sorpresa" (no se sabe cual hasta que empieza)

	-- ===== Recompensas =====
	SurviveCoins = 40,
	StreakBonusCoins = 8, -- por cada ronda de racha (hasta MaxStreakBonus rondas)
	MaxStreakBonus = 15,
	ParticipationCoins = 8,
	AliveTickInterval = 15, -- cada tantos segundos vivo en la ronda...
	AliveTickCoins = 2, -- ...ganas esto
	SurviveXP = 35,
	ParticipationXP = 10,
	CoinPickups = 22, -- monedas que aparecen por el mapa en cada ronda
	CoinValue = 5,
	BigCoinValue = 25,
	BigCoinChance = 0.08,
	DailyRewardBase = 50,
	DailyRewardMaxDays = 7,

	-- ===== Rendimiento / destruccion =====
	ChunkSize = 12, -- tamano maximo de cada trozo de pared/suelo (mas pequeno = destruccion mas fina, mas piezas)
	MaxPhysicsBodies = 45, -- cuerpos fisicos sueltos a la vez (el resto se convierte en escombro visual en el cliente)
	MaxRubbleParts = 900, -- escombros quietos que se mantienen en el mapa
	DebrisSettleTime = 1.2, -- segundos casi quieto antes de congelar un escombro
	DebrisMaxLife = 12, -- segundos maximos de fisica para un escombro
	MaxShatterPerFlush = 70, -- roturas que se envian a los clientes por frame
	HidePerFrame = 60, -- piezas destruidas que se procesan por frame (evita tirones)
	CollapseInterval = 0.3, -- cada cuanto se comprueba si algo se ha quedado sin apoyo
	BuildBudgetMs = 6, -- milisegundos por frame dedicados a construir el mapa
	GraphBudgetMs = 4, -- milisegundos por frame para calcular apoyos tras construir

	-- ===== Administracion =====
	-- UserIds que pueden usar los comandos de prueba (!mapa, !desastre, !saltar...). En Studio y el dueno siempre pueden.
	Admins = {},

	-- ===== Datos =====
	DataStoreName = "IslasDatos_v2",
	LeaderboardStoreName = "IslasVictorias_v2",
	AutosaveInterval = 120,
}
]])

	add("ReplicatedStorage", { "IslasShared" }, "DisasterInfo", "ModuleScript", [[
-- DisasterInfo: nombre, descripcion, icono y color de cada desastre (lo usan servidor y cliente).
-- La logica de cada desastre esta en IslasServer/Disasters/<Id>.
local C = Color3.fromRGB

return {
	Earthquake = { Title = "Terremoto", Icon = "🌍", Color = C(190, 140, 90),
		Desc = "El suelo tiembla y los edificios se derrumban. Alejate de lo que pueda caerte encima." },
	Fire = { Title = "Incendio", Icon = "🔥", Color = C(255, 110, 30),
		Desc = "Focos de fuego que se extienden y queman la madera. Huye de las llamas." },
	Meteors = { Title = "Lluvia de meteoritos", Icon = "☄️", Color = C(255, 120, 40),
		Desc = "Un circulo rojo avisa donde va a caer cada meteorito. Sal de el." },
	Flood = { Title = "Inundacion", Icon = "💧", Color = C(60, 140, 230),
		Desc = "El agua sube sin parar. Busca un sitio alto." },
	Lava = { Title = "Lava", Icon = "🟧", Color = C(255, 90, 20),
		Desc = "El suelo es lava, sube y derrite lo que toca. Tocarla es morir." },
	Lightning = { Title = "Tormenta electrica", Icon = "⚡", Color = C(255, 235, 90),
		Desc = "Caen rayos donde marca el anillo amarillo." },
	AcidRain = { Title = "Lluvia acida", Icon = "🧪", Color = C(120, 230, 60),
		Desc = "Quema a quien este a cielo abierto y corroe los tejados. Ponte a cubierto." },
	Tornado = { Title = "Tornado", Icon = "🌪️", Color = C(160, 160, 170),
		Desc = "Arrastra jugadores y arranca trozos de los edificios." },
	Radiation = { Title = "Fuga de radiacion", Icon = "☢️", Color = C(110, 255, 80),
		Desc = "Nubes radiactivas recorren el mapa. No te quedes dentro." },
	Blizzard = { Title = "Ventisca", Icon = "❄️", Color = C(200, 230, 255),
		Desc = "Frio extremo: a la intemperie te congelas. Refugiate o acercate al fuego." },
	Sandstorm = { Title = "Tormenta de arena", Icon = "🏜️", Color = C(230, 190, 120),
		Desc = "Viento que empuja y arena que dana fuera de los edificios." },
	Volcano = { Title = "Volcan", Icon = "🌋", Color = C(255, 70, 20),
		Desc = "Un volcan surge del suelo y lanza bombas de lava." },
	Tsunami = { Title = "Tsunami", Icon = "🌊", Color = C(40, 120, 220),
		Desc = "Una ola gigante arrasa el mapa. Sube a lo mas alto." },
	Virus = { Title = "Virus mortal", Icon = "🦠", Color = C(150, 255, 120),
		Desc = "Algunos jugadores se infectan y contagian a los cercanos. Mantente lejos." },
	BlackHole = { Title = "Agujero negro", Icon = "🕳️", Color = C(140, 80, 255),
		Desc = "Absorbe todo lo que esta cerca, edificios incluidos. Corre en direccion contraria." },
	UFO = { Title = "Invasion alienigena", Icon = "🛸", Color = C(120, 255, 200),
		Desc = "Ovnis con rayos abductores y laseres. No te quedes bajo su luz." },
	Mystery = { Title = "???", Icon = "❓", Color = C(200, 200, 200),
		Desc = "Desastre sorpresa: nadie sabe lo que viene." },
}
]])

	add("ReplicatedStorage", { "IslasShared" }, "Format", "ModuleScript", [[
-- Format: formatos de numeros y tiempos para la interfaz.
local Format = {}

function Format.Number(n)
	n = math.floor(n or 0)
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	-- separador de miles
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if out:sub(1, 1) == "." then
		out = out:sub(2)
	end
	return out
end

function Format.Time(seconds)
	seconds = math.max(0, math.ceil(seconds or 0))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

return Format
]])

	add("ReplicatedStorage", { "IslasShared" }, "Levels", "ModuleScript", [[
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
]])

	add("ReplicatedStorage", { "IslasShared" }, "Modifiers", "ModuleScript", [[
-- Modifiers: modificadores de ronda que la hacen distinta (la logica esta en GameLoop).
local C = Color3.fromRGB

return {
	{ Id = "Doble", Title = "DOBLE DESASTRE", Desc = "Dos desastres a la vez desde el principio.", Color = C(255, 80, 80), Weight = 3 },
	{ Id = "Monedas2", Title = "MONEDAS x2", Desc = "Todas las monedas valen el doble.", Color = C(255, 210, 60), Weight = 3 },
	{ Id = "Noche", Title = "RONDA NOCTURNA", Desc = "Oscuridad total. Todos reciben una linterna.", Color = C(110, 120, 255), Weight = 2 },
	{ Id = "GravedadBaja", Title = "GRAVEDAD BAJA", Desc = "Saltas como en la luna.", Color = C(160, 220, 255), Weight = 2 },
	{ Id = "Velocidad", Title = "PIES RAPIDOS", Desc = "Todos corren mas rapido.", Color = C(80, 255, 160), Weight = 2 },
	{ Id = "Hiper", Title = "MODO HIPER", Desc = "Desastres un 60% mas intensos. Recompensa x1.5.", Color = C(255, 60, 200), Weight = 2 },
	{ Id = "Niebla", Title = "NIEBLA ESPESA", Desc = "Casi no se ve nada.", Color = C(190, 190, 200), Weight = 1 },
	{ Id = "Fragil", Title = "EDIFICIOS DE PAPEL", Desc = "Todo se rompe con muchisima facilidad.", Color = C(255, 150, 60), Weight = 2 },
}
]])

	add("ReplicatedStorage", { "IslasShared" }, "Net", "ModuleScript", [[
-- Net: todos los RemoteEvent/RemoteFunction del juego en un sitio.
-- En el servidor se crean al primer require; en el cliente se esperan.
--   local Net = require(ReplicatedStorage.IslasShared.Net)
--   Net.Event("Popup"):FireClient(player, ...)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"VoteOptions", "VoteUpdate", "VoteEnd", "CastVote", -- votacion
	"RoundState", "RoundStatus", "RoundResults", -- estado de la ronda
	"DisasterFX", "Shatter", "PlaySound", -- efectos
	"DataUpdate", "Popup", "Toast", "KillFeed", -- jugador / HUD
	"ElevatorMenu", "ElevatorRequest", -- ascensores
	"GearAction", "OpenUI", "DailyClaim", "SettingsChanged",
}
local FUNCTIONS = { "ShopRequest", "GetData" }

local Net = {}
local folder

if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("IslasRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "IslasRemotes"
		for _, name in ipairs(EVENTS) do
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
		for _, name in ipairs(FUNCTIONS) do
			local r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("IslasRemotes")
end

function Net.Event(name)
	return folder:WaitForChild(name)
end

function Net.Function(name)
	return folder:WaitForChild(name)
end

Net.Folder = folder
return Net
]])

	add("ReplicatedStorage", { "IslasShared" }, "Paths", "ModuleScript", [[
-- Paths: movimiento determinista a partir del reloj del servidor (workspace:GetServerTimeNow()).
-- El servidor y los clientes calculan la misma posicion sin enviar nada por la red: el servidor solo
-- manda los puntos de paso una vez, y cada cliente anima su copia visual de forma suave.
local Paths = {}

-- points: { Vector3 o {x, z} }, speed en studs/s, t0 = hora de inicio, loop = volver al principio
function Paths.Make(points, speed, t0, loop)
	local pts = {}
	for i, p in ipairs(points) do
		if typeof(p) == "Vector3" then
			pts[i] = { p.X, p.Z }
		else
			pts[i] = { p[1], p[2] }
		end
	end
	if loop then
		pts[#pts + 1] = { pts[1][1], pts[1][2] }
	end
	local lengths, total = {}, 0
	for i = 1, #pts - 1 do
		local dx, dz = pts[i + 1][1] - pts[i][1], pts[i + 1][2] - pts[i][2]
		local l = math.sqrt(dx * dx + dz * dz)
		lengths[i] = l
		total = total + l
	end
	return { points = pts, lengths = lengths, total = total, speed = speed, t0 = t0, loop = loop }
end

-- Posicion (x, z) en el instante t
function Paths.At(path, t)
	local pts = path.points
	if #pts == 1 or path.total <= 0 then
		return pts[1][1], pts[1][2]
	end
	local d = math.max(0, t - path.t0) * path.speed
	if path.loop then
		d = d % path.total
	else
		d = math.min(d, path.total)
	end
	for i, l in ipairs(path.lengths) do
		if d <= l or i == #path.lengths then
			local k = l > 0 and math.clamp(d / l, 0, 1) or 0
			local a, b = pts[i], pts[i + 1]
			return a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k
		end
		d = d - l
	end
	local last = pts[#pts]
	return last[1], last[2]
end

-- Nivel de un liquido que sube linealmente
function Paths.Level(y0, y1, t0, rise, t)
	local k = rise > 0 and math.clamp((t - t0) / rise, 0, 1) or 1
	return y0 + (y1 - y0) * k
end

return Paths
]])

	add("ReplicatedStorage", { "IslasShared" }, "Sounds", "ModuleScript", [[
-- Sounds: ids de sonido. Los "rbxasset://" vienen con Roblox; puedes cambiarlos por "rbxassetid://NUMERO"
-- de la biblioteca (Toolbox > Audio). Si un id no existe, simplemente no suena.
return {
	Coin = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/button.wav",
	Whoosh = "rbxasset://sounds/swoosh.wav",
	Hit = "rbxasset://sounds/hit.wav",
	Break = "rbxasset://sounds/snap.wav",
	Glass = "rbxasset://sounds/snap.wav",
	Crumble = "rbxasset://sounds/collide.wav",
	Explosion = "rbxasset://sounds/collide.wav",
	Death = "rbxasset://sounds/uuhhh.mp3",
	Splash = "rbxasset://sounds/impact_water.mp3",
	Warning = "rbxasset://sounds/electronicpingshort.wav",
	LevelUp = "rbxasset://sounds/electronicpingshort.wav",
	Win = "rbxasset://sounds/electronicpingshort.wav",
	Thunder = "rbxasset://sounds/collide.wav",
	-- musica (vacio = sin musica). Pon ids de la biblioteca si quieres.
	LobbyMusic = "",
	RoundMusic = "",
}
]])

	add("ServerStorage", { "IslasMapas", "Builders" }, "Airport", "ModuleScript", [[
-- Aeropuerto: terminal de 3 plantas con ascensores y escaleras, torre de control (ascensor + 3 paradas),
-- dos aviones con interior, hangar, camiones de combustible y pista.

local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local Airport = {
	Title = "Aeropuerto",
	Description = "Terminal de 3 plantas con ascensores, torre de control, aviones, hangar y pista.",
	Lighting = { ClockTime = 15, Brightness = 2 },
	Bounds = { x1 = -200, x2 = 200, z1 = -170, z2 = 100, top = 130, floor = 0 },
	Disasters = { "Earthquake", "Fire", "Meteors", "Flood", "Lightning", "Tornado", "Tsunami", "UFO", "BlackHole", "Sandstorm" },
	DisasterConfig = { Flood = { maxHeight = 30 } }, -- el agua llega a la planta 1; la 2 y la torre quedan a salvo
}

local WHITE = C(235, 238, 242)
local TILE = C(205, 208, 214)

local windows = Util.Windows

local function buildPlane(g)
	-- Avion de pasajeros mirando a +X, con puerta en el lado +Z. Origen = centro del avion en el suelo.
	local L = 56
	g:Box("Suelo", V(L, 0.6, 7), V(0, 3.2, 0), TILE, M.SmoothPlastic)
	g:Box("Techo", V(L, 0.6, 8), V(0, 9.8, 0), WHITE, M.SmoothPlastic)
	local door = { from = -20, to = -15, bottom = 0, top = 6.2 }
	g:Wall("ParedFrente", "x", 3.75, -L / 2, L / 2, 3.5, 9.5, 0.5, WHITE, M.SmoothPlastic, (function()
		local o = windows(-L / 2 + 6, L / 2 - 6, 4.5, 2, 2, 4.5, -22, -13)
		o[#o + 1] = door
		return o
	end)())
	g:Wall("ParedFondo", "x", -3.75, -L / 2, L / 2, 3.5, 9.5, 0.5, WHITE, M.SmoothPlastic, windows(-L / 2 + 6, L / 2 - 6, 4.5, 2, 2, 4.5))
	g:Wall("MamparaTrasera", "z", -L / 2, -3.5, 3.5, 3.5, 9.5, 0.5, WHITE, M.SmoothPlastic)
	-- morro y cabina
	g:Ball("Morro", 9.5, V(L / 2 + 1.5, 6.5, 0), WHITE, M.SmoothPlastic)
	g:Box("Cabina", V(3, 2, 7), V(L / 2 - 1.5, 8.6, 0), Colors.Glass, M.Glass, { transparency = 0.4 })
	-- cola
	g:Box("Deriva", V(6, 13, 0.8), V(-L / 2 + 1, 15, 0), Colors.Blue, M.SmoothPlastic, { rot = V(0, 0, -12) })
	g:Box("AlaCola", V(5, 0.6, 18), V(-L / 2 + 1, 10.5, 0), WHITE, M.SmoothPlastic)
	-- alas y motores
	g:Box("Ala", V(14, 0.8, 46), V(3, 3, 0), C(200, 204, 210), M.Metal)
	for _, side in ipairs({ -1, 1 }) do
		g:Box("Motor", V(8, 3.6, 3.6), V(6, 1.5, side * 13), Colors.DarkMetal, M.Metal, { shape = Enum.PartType.Cylinder })
		g:Box("PuntaAla", V(4, 1.5, 0.8), V(-1, 4, side * 23), Colors.Blue, M.SmoothPlastic)
	end
	-- tren de aterrizaje
	g:Box("Rueda", V(1, 3.4, 3.4), V(L / 2 - 6, 1.7, 0), Colors.DarkMetal, M.Rubber, { shape = Enum.PartType.Cylinder, rot = V(0, 90, 0) })
	-- asientos
	for row = 0, 9 do
		local x = -12 + row * 3.2
		for _, z in ipairs({ -2.6, -1.0, 1.0, 2.6 }) do
			g:Box("Asiento", V(1.6, 1.4, 1.4), V(x, 4.2, z), Colors.Blue, M.Fabric)
			g:Box("Respaldo", V(0.4, 2, 1.4), V(x - 0.7, 5.2, z), Colors.Blue, M.Fabric)
		end
	end
	-- escalerilla en la puerta (dirige hacia -Z)
	g:Stairs("Escalerilla", -17.5, 3.75 + 5.6, 0, 3.5, 4, 5.6, "-z", Colors.Metal, M.Metal)
end

local function buildTruck(g, x, z)
	local t = g:At(V(x, 0, z), "CamionCombustible")
	t:Box("Chasis", V(14, 1.4, 5.6), V(0, 1.9, 0), Colors.DarkMetal, M.Metal)
	t:Box("Cabina", V(4, 4, 5.6), V(6, 4.6, 0), Colors.Red, M.SmoothPlastic)
	t:Box("Parabrisas", V(0.3, 2, 4.8), V(8.1, 5.2, 0), Colors.Glass, M.Glass, { transparency = 0.4 })
	t:Box("Tanque", V(10, 4.4, 4.4), V(-2, 5, 0), Colors.White, M.Metal, { shape = Enum.PartType.Cylinder })
	for _, wx in ipairs({ -5, 0, 6 }) do
		for _, side in ipairs({ -1, 1 }) do
			t:Box("Rueda", V(1.2, 2.8, 2.8), V(wx, 1.4, side * 2.9), C(25, 25, 25), M.Rubber, { shape = Enum.PartType.Cylinder, rot = V(0, 90, 0) })
		end
	end
end

function Airport.Build(b)
	-- ===== Isla y mar =====
	b:Box("Isla", V(560, 10, 400), V(0, -5.5, 0), Colors.Grass, M.Grass)
	b:Sea(-6)

	-- ===== Pavimentos =====
	local ground = b:Group("Pavimentos")
	ground:Box("Plataforma", V(240, 0.5, 70), V(0, -0.25, -55), Colors.DarkConcrete, M.Concrete)
	ground:Box("Calle", V(18, 0.5, 70), V(0, -0.25, 15), Colors.Asphalt, M.Asphalt)
	ground:Box("Pista", V(540, 0.5, 40), V(0, -0.25, 70), Colors.Asphalt, M.Asphalt)
	for x = -250, 250, 30 do
		ground:Box("MarcaPista", V(14, 0.1, 1.2), V(x, 0.02, 70), WHITE, M.SmoothPlastic, { canCollide = false })
	end
	for _, z in ipairs({ 52.5, 87.5 }) do
		ground:Box("LineaPista", V(540, 0.1, 0.6), V(0, 0.02, z), WHITE, M.SmoothPlastic, { canCollide = false })
	end

	-- ===== Terminal =====
	local term = b:Group("Terminal")
	local x1, x2, z1, z2 = -80, 80, -170, -90
	local levels = { 0, 18, 36 }
	local roofY = 54
	local elevA = { name = "AscensorA", x = -8, z = -163.5, floors = levels, labels = { "PB", "1", "2" } }
	local elevB = { name = "AscensorB", x = 8, z = -163.5, floors = levels, labels = { "PB", "1", "2" } }
	local hA, hB = Elevator.hole(elevA), Elevator.hole(elevB)
	local stairHole1 = { 30, 59, -129, -121 } -- sube de PB a la 1
	local stairHole2 = { 43, 72, -144, -136 } -- sube de la 1 a la 2

	term:Slab("SueloPB", x1, x2, z1, z2, 0, 0.5, TILE, M.Marble, { hA, hB })
	term:Slab("Suelo1", x1, x2, z1, z2, 18, 1.5, TILE, M.Marble, { hA, hB, stairHole1 })
	term:Slab("Suelo2", x1, x2, z1, z2, 36, 1.5, TILE, M.Marble, { hA, hB, stairHole2 })
	term:Slab("Cubierta", x1 - 10, x2 + 10, z1 - 10, z2 + 10, roofY + 2, 2, Colors.DarkMetal, M.Metal)

	for i, y in ipairs(levels) do
		local top = y + 18
		-- fachada frontal (+Z)
		local front
		if i == 1 then
			front = windows(x1 + 2, x2 - 2, 14, 10, 3, 15, -14, 14)
			front[#front + 1] = { from = -10, to = 10, bottom = 0, top = 12 }
		else
			front = windows(x1 + 2, x2 - 2, 14, 11, 2, 16)
		end
		term:Wall("Fachada" .. i, "x", z2, x1, x2, y, top, 1, WHITE, M.Concrete, front)
		term:Wall("Trasera" .. i, "x", z1, x1, x2, y, top, 1, WHITE, M.Concrete)
		term:Wall("LateralIzq" .. i, "z", x1, z1, z2, y, top, 1, WHITE, M.Concrete, windows(z1 + 2, z2 - 2, 14, 10, 3, 15))
		term:Wall("LateralDer" .. i, "z", x2, z1, z2, y, top, 1, WHITE, M.Concrete, windows(z1 + 2, z2 - 2, 14, 10, 3, 15))
	end
	term:Board("Letrero", "AEROPUERTO INTERNACIONAL", V(90, 8, 1), V(0, roofY + 7, z2 + 3), Colors.Blue, WHITE)
	for x = -60, 60, 30 do
		term:Pillar("Columna", x, -118, 0, roofY, 2.4, WHITE, M.Concrete)
	end

	Elevator.build(term, elevA)
	Elevator.build(term, elevB)
	term:Stairs("EscaleraPB", 30, -125, 0, 18, 8, 29, "+x", WHITE, M.Concrete)
	term:Stairs("Escalera1", 72, -140, 18, 36, 8, 29, "-x", WHITE, M.Concrete)

	-- --- Planta baja ---
	local pb = term:Group("PlantaBaja")
	for i, x in ipairs({ -66, -52, -38, -24, 24, 38, 52, 66 }) do
		pb:Board("Mostrador", "CHECK-IN " .. i, V(10, 3.6, 3), V(x, 1.8, -105), Colors.Blue, WHITE)
		pb:Box("Cinta", V(8, 0.6, 1.4), V(x, 3.9, -105), Colors.DarkMetal, M.Metal)
	end
	for _, x in ipairs({ -48, -36, -24 }) do
		pb:Box("PorticoSeguridadIzq", V(0.6, 9, 1.5), V(x - 2.5, 4.5, -135), Colors.DarkMetal, M.Metal)
		pb:Box("PorticoSeguridadDer", V(0.6, 9, 1.5), V(x + 2.5, 4.5, -135), Colors.DarkMetal, M.Metal)
		pb:Box("PortcoSeguridadTop", V(5.6, 0.8, 1.5), V(x, 9.4, -135), Colors.DarkMetal, M.Metal)
		pb:Box("LuzSeguridad", V(4, 0.3, 0.3), V(x, 8.6, -135), C(90, 255, 120), M.Neon, { canCollide = false })
	end
	pb:Board("CartelSeguridad", "CONTROL DE SEGURIDAD", V(24, 3, 0.4), V(-36, 11.5, -135), Colors.Yellow, C(20, 20, 20))
	for r = 0, 1 do
		for x = -60, -30, 10 do
			pb:Box("Banco", V(8, 1.2, 2.2), V(x, 0.6 + 0.6, -150 + r * 6), Colors.Wood, M.Wood)
		end
	end
	pb:Box("TiendaMostrador", V(10, 4, 10), V(-70, 2, -150), Colors.Orange, M.SmoothPlastic)
	pb:Board("CartelTienda", "TIENDA", V(10, 3, 0.4), V(-70, 6.5, -144.7), Colors.Orange, WHITE)
	-- cinta de equipajes: empuja a los jugadores
	pb:Box("CintaEquipaje", V(36, 1.2, 6), V(45, 0.6, -160), Colors.DarkMetal, M.Metal, { velocity = V(7, 0, 0) })
	pb:Board("CartelEquipaje", "RECOGIDA DE EQUIPAJE", V(26, 3, 0.4), V(45, 8, -169.3), Colors.DarkMetal, WHITE)
	for i = 0, 5 do
		pb:Box("Maleta", V(2.4, 1.8, 1.4), V(32 + i * 5, 2.1, -160), C(60 + i * 25, 70, 140 - i * 15), M.Fabric, { canCollide = false })
	end
	for _, p in ipairs({ { -75, -95 }, { 75, -95 }, { -75, -165 }, { 75, -165 } }) do
		pb:Pillar("Maceta", p[1], p[2], 0, 2, 3, Colors.Wood, M.Wood)
		pb:Ball("Planta", 5, V(p[1], 4.5, p[2]), Colors.Green, M.Grass)
	end

	-- --- Planta 1: restaurantes y sala de embarque ---
	local p1 = term:Group("Planta1")
	for ix = 0, 3 do
		for iz = 0, 2 do
			local x, z = -66 + ix * 11, -155 + iz * 14
			p1:Pillar("PataMesa", x, z, 18, 21, 0.8, Colors.DarkMetal, M.Metal)
			p1:Pillar("MesaComedor", x, z, 21, 21.5, 5, WHITE, M.Marble)
			for _, o in ipairs({ { 3.4, 0 }, { -3.4, 0 }, { 0, 3.4 }, { 0, -3.4 } }) do
				p1:Box("Silla", V(1.6, 1.6, 1.6), V(x + o[1], 18.8, z + o[2]), Colors.Red, M.Fabric)
			end
		end
	end
	p1:Board("CartelComida", "ZONA DE RESTAURANTES", V(30, 3, 0.4), V(-45, 29, -169.3), Colors.Red, WHITE)
	for x = -66, 66, 16 do
		p1:Box("AsientoEmbarque", V(8, 1.4, 2), V(x, 18.7, -98), Colors.Blue, M.Fabric)
		p1:Box("RespaldoEmbarque", V(8, 2, 0.5), V(x, 20, -99.2), Colors.Blue, M.Fabric)
	end
	p1:Box("DutyFree", V(12, 4, 6), V(50, 20, -108), Colors.Yellow, M.SmoothPlastic)
	p1:Board("CartelDutyFree", "DUTY FREE", V(12, 3, 0.4), V(50, 24.5, -104.9), Colors.Yellow, C(20, 20, 20))
	p1:Board("PanelSalidas", "SALIDAS\nMAD   10:45   PUERTA 4\nJFK   11:20   PUERTA 7\nTYO   12:05   PUERTA 2\nLON   12:40   PUERTA 5", V(30, 11, 0.6), V(40, 29, -169.2), Colors.DarkMetal, C(255, 190, 60))

	-- --- Planta 2: mirador ---
	local p2 = term:Group("Planta2")
	p2:Board("CartelMirador", "MIRADOR · LOUNGE VIP", V(30, 3, 0.4), V(-40, 47, -169.3), Colors.Blue, WHITE)
	for ix = 0, 2 do
		for iz = 0, 1 do
			local x, z = -66 + ix * 14, -112 + iz * -10
			p2:Box("Sofa", V(8, 1.6, 3), V(x, 36.8, z), Colors.Red, M.Fabric)
			p2:Box("RespaldoSofa", V(8, 2.4, 0.8), V(x, 38, z - 1.4), Colors.Red, M.Fabric)
			p2:Box("MesaBaja", V(3, 1, 3), V(x, 36.5, z + 3.5), Colors.Wood, M.Wood)
		end
	end
	p2:Box("Barra", V(24, 4, 3), V(50, 38, -112), Colors.Wood, M.Wood)
	p2:Board("CartelBar", "BAR", V(6, 2, 0.4), V(50, 41.5, -110.4), Colors.DarkMetal, WHITE)

	-- ===== Torre de control =====
	local tw = b:Group("TorreDeControl")
	local tcfg = { name = "AscensorTorre", x = 150, z = -20, floors = { 0, 30, 60, 90 }, labels = { "PB", "1", "2", "3" } }
	local tx, tz = tcfg.x, tcfg.z
	local tHole = Elevator.hole(tcfg)
	tw:Slab("BaseTorre", tx - 14, tx + 14, tz - 8, tz + 18, 0, 0.5, TILE, M.Concrete, { tHole })
	Elevator.build(tw, tcfg)
	for _, y in ipairs({ 30, 60 }) do
		tw:Slab("Balcon", tx - 9, tx + 9, tz + 6.1, tz + 15, y, 1.5, WHITE, M.Concrete)
		tw:Wall("BarandillaFrente", "x", tz + 15, tx - 9, tx + 9, y, y + 4, 0.3, Colors.Glass, M.Glass, {})
		tw:Wall("BarandillaIzq", "z", tx - 9, tz + 6.1, tz + 15, y, y + 4, 0.3, Colors.Glass, M.Glass, {})
		tw:Wall("BarandillaDer", "z", tx + 9, tz + 6.1, tz + 15, y, y + 4, 0.3, Colors.Glass, M.Glass, {})
	end
	tw:Slab("SalaControl", tx - 14, tx + 14, tz - 14, tz + 14, 90, 1.5, WHITE, M.Concrete, { tHole })
	local ring = { { from = tx - 13, to = tx + 13, bottom = 1, top = 14, glass = true } }
	tw:Wall("VentanalFrente", "x", tz + 14, tx - 14, tx + 14, 90, 106, 0.6, Colors.DarkMetal, M.Metal, ring)
	tw:Wall("VentanalFondo", "x", tz - 14, tx - 14, tx + 14, 90, 106, 0.6, Colors.DarkMetal, M.Metal, ring)
	local ringZ = { { from = tz - 13, to = tz + 13, bottom = 1, top = 14, glass = true } }
	tw:Wall("VentanalIzq", "z", tx - 14, tz - 14, tz + 14, 90, 106, 0.6, Colors.DarkMetal, M.Metal, ringZ)
	tw:Wall("VentanalDer", "z", tx + 14, tz - 14, tz + 14, 90, 106, 0.6, Colors.DarkMetal, M.Metal, ringZ)
	tw:Slab("TechoTorre", tx - 16, tx + 16, tz - 16, tz + 16, 108, 2, Colors.DarkMetal, M.Metal)
	tw:Pillar("Antena", tx + 8, tz - 8, 108, 124, 1, Colors.Red, M.Metal)
	tw:Ball("LuzAntena", 2, V(tx + 8, 124.5, tz - 8), Colors.Red, M.Neon)
	for i = 0, 3 do
		tw:Box("Consola", V(6, 3, 2.5), V(tx - 10.5 + i * 7, 91.5 + 1.5, tz + 9), Colors.DarkMetal, M.Metal)
		tw:Box("Pantalla", V(5, 2, 0.2), V(tx - 10.5 + i * 7, 96.5, tz + 8), C(40, 220, 140), M.Neon, { canCollide = false })
		tw:Box("SillaControl", V(2, 2, 2), V(tx - 10.5 + i * 7, 92.5, tz + 5.5), Colors.Red, M.Fabric)
	end

	-- ===== Aviones =====
	buildPlane(b:At(V(-60, 0, -55), "AvionA"))
	buildPlane(b:At(V(58, 0, -55), "AvionB"))
	buildTruck(b, 100, -40)
	buildTruck(b, 100, -70)

	-- ===== Hangar =====
	local hg = b:Group("Hangar")
	local hx1, hx2, hz1, hz2 = -200, -150, -20, 20
	hg:Wall("HangarFrente", "x", hz2, hx1, hx2, 0, 22, 1, Colors.Metal, M.CorrodedMetal, { { from = -188, to = -162, bottom = 0, top = 16 } })
	hg:Wall("HangarFondo", "x", hz1, hx1, hx2, 0, 22, 1, Colors.Metal, M.CorrodedMetal)
	hg:Wall("HangarIzq", "z", hx1, hz1, hz2, 0, 22, 1, Colors.Metal, M.CorrodedMetal, windows(hz1 + 2, hz2 - 2, 10, 6, 14, 20))
	hg:Wall("HangarDer", "z", hx2, hz1, hz2, 0, 22, 1, Colors.Metal, M.CorrodedMetal, windows(hz1 + 2, hz2 - 2, 10, 6, 14, 20))
	hg:Slab("HangarSuelo", hx1, hx2, hz1, hz2, 0, 0.5, Colors.DarkConcrete, M.Concrete)
	hg:Slab("HangarTecho", hx1 - 2, hx2 + 2, hz1 - 2, hz2 + 2, 23, 1, Colors.DarkMetal, M.Metal)
	hg:Ladder("EscalerillaHangar", hx2 + 1.2, 0, 0, 24.5)
	for i = 0, 5 do
		local cx, cz = -194 + (i % 3) * 5, -14 + math.floor(i / 3) * 5
		hg:Box("Caja", V(4, 4, 4), V(cx, 2, cz), Colors.Wood, M.Wood)
		if i % 2 == 0 then
			hg:Box("CajaAlta", V(4, 4, 4), V(cx, 6, cz), Colors.Orange, M.Wood)
		end
	end
	hg:Board("CartelHangar", "HANGAR 1", V(26, 4, 0.4), V(-175, 19, hz2 + 0.7), Colors.Yellow, C(20, 20, 20))

	-- ===== Puntos de aparicion (plataforma, entre los dos aviones) =====
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-15 + ix * 10, 1, -78 + iz * 14))
		end
	end
end

return Airport
]])

	add("ServerStorage", { "IslasMapas", "Builders" }, "AmusementPark", "ModuleScript", [[
-- Parque de atracciones: noria y tiovivo que giran (animados en el cliente), torre de caida con ascensor,
-- montana rusa, casa del terror, coches de choque, puestos de comida y arco de entrada.
local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local Buildings = require(Lib.Buildings)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local AmusementPark = {
	Title = "Parque de atracciones",
	Description = "Noria y tiovivo girando, torre de caida con ascensor, montana rusa y casa del terror.",
	Lighting = { ClockTime = 18.2, Brightness = 1.8 },
	Bounds = { x1 = -160, x2 = 160, z1 = -160, z2 = 170, top = 120, floor = 0 },
	Disasters = { "Earthquake", "Fire", "Meteors", "Tornado", "Lightning", "UFO", "BlackHole", "AcidRain", "Virus", "Tsunami", "Volcano" },
}

local BRIGHT = { C(255, 80, 80), C(255, 200, 60), C(80, 200, 255), C(120, 255, 120), C(220, 110, 255), C(255, 140, 60) }

function AmusementPark.Build(b)
	b:Box("Isla", V(380, 10, 400), V(0, -5.5, 10), Colors.Grass, M.Grass, { indestructible = true })
	b:Sea(-6)
	local paths = b:Group("Caminos")
	paths:Box("CaminoCentral", V(16, 0.4, 300), V(0, 0.2, 20), C(210, 190, 160), M.Pavement, { indestructible = true })
	paths:Box("CaminoCruz", V(280, 0.4, 16), V(0, 0.2, -20), C(210, 190, 160), M.Pavement, { indestructible = true })

	-- arco de entrada
	local gate = b:Group("Entrada")
	for _, x in ipairs({ -14, 14 }) do
		gate:Box("TorreArco", V(6, 22, 6), V(x, 11, 160), BRIGHT[1], M.SmoothPlastic)
		gate:Ball("BolaArco", 6, V(x, 25, 160), BRIGHT[2], M.Neon)
	end
	gate:Board("CartelArco", "PARQUE DISASTRO", V(34, 6, 2), V(0, 20, 160), BRIGHT[3], Colors.White)
	gate:Box("Taquilla", V(8, 8, 6), V(26, 4, 150), BRIGHT[2], M.SmoothPlastic)

	-- noria (gira alrededor del eje Z en el cliente)
	local wheel = b:Group("Noria", "Model")
	local cx, cy, cz = -80, 42, -70
	local R = 32
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local x, y = cx + math.cos(a) * R, cy + math.sin(a) * R
		wheel:Box("Aro", V(9, 1.2, 1.2), V(x, y, cz - 2), BRIGHT[(i % #BRIGHT) + 1], M.Neon, { rot = V(0, 0, math.deg(a) + 90) })
		wheel:Box("Aro", V(9, 1.2, 1.2), V(x, y, cz + 2), BRIGHT[(i % #BRIGHT) + 1], M.Neon, { rot = V(0, 0, math.deg(a) + 90) })
		if i % 3 == 0 then
			wheel:Box("Radio", V(R, 0.6, 0.6), V(cx + math.cos(a) * R / 2, cy + math.sin(a) * R / 2, cz), Colors.White, M.Metal, { rot = V(0, 0, math.deg(a)) })
			wheel:Box("Cabina", V(4, 4, 5), V(x, y - 3, cz), BRIGHT[(i / 3) % #BRIGHT + 1], M.SmoothPlastic)
		end
	end
	wheel:Pillar("Eje", cx, cz, cy - 1.5, cy + 1.5, 4, Colors.DarkMetal, M.Metal)
	b:Spin(wheel.parent, 2, "Z")
	-- soportes (no giran)
	for _, s in ipairs({ -1, 1 }) do
		b:Box("SoporteNoria", V(2, 46, 2), V(cx + s * 12, 21, cz - 5), Colors.White, M.Metal, { rot = V(0, 0, -s * 15) })
		b:Box("SoporteNoria", V(2, 46, 2), V(cx + s * 12, 21, cz + 5), Colors.White, M.Metal, { rot = V(0, 0, -s * 15) })
	end
	b:Box("BaseNoria", V(36, 1, 16), V(cx, 0.5, cz), C(80, 80, 90), M.Concrete)

	-- tiovivo (gira en el eje Y)
	local carousel = b:Group("Tiovivo", "Model")
	local tx, tz = 70, -70
	carousel:Pillar("Plataforma", tx, tz, 0, 1.4, 30, C(230, 200, 150), M.WoodPlanks)
	carousel:Pillar("Centro", tx, tz, 1.4, 14, 4, BRIGHT[5], M.SmoothPlastic)
	carousel:Pillar("Techo", tx, tz, 14, 16, 32, BRIGHT[1], M.Fabric)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local x, z = tx + math.cos(a) * 11, tz + math.sin(a) * 11
		carousel:Pillar("Barra", x, z, 1.4, 14, 0.4, C(255, 215, 80), M.Metal)
		carousel:Box("Caballo", V(1.4, 2.6, 4), V(x, 4.5 + (i % 2), z), Colors.White, M.SmoothPlastic, { rot = V(0, -math.deg(a), 0) })
	end
	b:Spin(carousel.parent, 6, "Y")

	-- torre de caida con ascensor
	local drop = b:Group("TorreCaida")
	local dz = -120
	local lift = { name = "AscensorCaida", x = 0, z = dz, floors = { 0, 40, 80 }, labels = { "PB", "40", "80" }, wallColor = BRIGHT[4], wallMaterial = M.Metal }
	Elevator.build(drop, lift)
	for _, y in ipairs({ 40, 80 }) do
		drop:Slab("Mirador", -10, 10, dz + 6.1, dz + 16, y, 1.2, Colors.DarkMetal, M.DiamondPlate)
		drop:Wall("Barandilla", "x", dz + 16, -10, 10, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
		drop:Wall("Barandilla", "z", -10, dz + 6.1, dz + 16, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
		drop:Wall("Barandilla", "z", 10, dz + 6.1, dz + 16, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
	end
	drop:Ball("Corona", 8, V(0, 98, dz), BRIGHT[2], M.Neon)
	drop:Board("CartelCaida", "CAIDA LIBRE", V(14, 3, 0.4), V(0, 12, dz + 6.4), C(30, 30, 40), BRIGHT[2])

	-- montana rusa: circuito con subidas y bajadas sobre pilares
	local coaster = b:Group("MontanaRusa")
	local N = 40
	local prev
	for i = 0, N do
		local a = i / N * math.pi * 2
		local x, z = 90 + math.cos(a) * 45, 70 + math.sin(a) * 30
		local y = 10 + 14 * math.max(0, math.sin(a * 2)) + 6 * math.sin(a * 3)
		local p = V(x, y, z)
		if prev then
			local mid = (prev + p) / 2
			local len = (p - prev).Magnitude
			local dirAngle = math.deg(math.atan2(-(p.Z - prev.Z), p.X - prev.X))
			local slope = math.deg(math.atan2(p.Y - prev.Y, math.sqrt((p.X - prev.X) ^ 2 + (p.Z - prev.Z) ^ 2)))
			coaster:Box("Via", V(len + 0.4, 0.6, 4), mid, C(220, 40, 40), M.Metal, { rot = V(0, dirAngle, slope) })
			if i % 3 == 0 then
				coaster:Pillar("PilarVia", x, z, 0, y - 0.3, 0.8, Colors.White, M.Metal)
			end
		end
		prev = p
	end
	for k = 0, 2 do
		coaster:Box("Vagon", V(4, 2.4, 3.4), V(135 - k * 0.5, 12 + k * 0.2, 70 + k * 4.5), BRIGHT[k + 1], M.SmoothPlastic)
	end

	-- casa del terror (2 plantas)
	Buildings.House(b, -90, 70, 30, 26, 2, { name = "CasaTerror", color = C(70, 60, 80), roofColor = C(40, 30, 50) })
	b:Board("CartelTerror", "CASA DEL TERROR", V(18, 3, 0.4), V(-90, 9, 83.6), C(20, 10, 20), C(255, 80, 80))

	-- coches de choque
	local bump = b:Group("CochesChoque")
	bump:Box("Pista", V(40, 0.6, 30), V(70, 0.3, 10), C(60, 60, 70), M.DiamondPlate)
	bump:Box("TechoPista", V(42, 1, 32), V(70, 12, 10), BRIGHT[6], M.Fabric)
	for _, p in ipairs({ { 50, -5 }, { 90, -5 }, { 50, 25 }, { 90, 25 } }) do
		bump:Pillar("PostePista", p[1], p[2], 0, 12, 0.8, Colors.White, M.Metal)
	end
	for k = 0, 5 do
		bump:Box("Choque", V(5, 2, 3.5), V(56 + k * 6, 1.6, 4 + (k % 2) * 10), BRIGHT[k % #BRIGHT + 1], M.SmoothPlastic)
	end

	-- puestos de comida
	for k, name in ipairs({ "PALOMITAS", "ALGODON", "HELADOS", "PERRITOS" }) do
		local x = -60 + k * 22
		b:Box("Puesto", V(10, 4, 6), V(x, 2, 110), Colors.Wood, M.Wood)
		b:Box("Toldo", V(12, 0.5, 8), V(x, 9, 111), BRIGHT[k], M.Fabric)
		b:Board("CartelPuesto", name, V(10, 2, 0.4), V(x, 10.6, 115), C(30, 30, 40), Colors.White)
		for _, sx in ipairs({ -5, 5 }) do
			b:Box("PostePuesto", V(0.5, 9, 0.5), V(x + sx, 4.5, 114.5), Colors.Wood, M.Wood)
		end
	end
	for i = -3, 3 do
		Buildings.Lamp(b, 12, i * 40 + 20, 0)
	end
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		b:Pine(math.cos(a) * 165, 10 + math.sin(a) * 170, 0, 1.3)
	end

	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-15 + ix * 10, 1, 125 + iz * 9))
		end
	end
end

return AmusementPark
]])

	add("ServerStorage", { "IslasMapas", "Builders" }, "Castle", "ModuleScript", [[
-- Castillo: murallas almenadas con cuatro torres, foso con puente levadizo, patio con pozo y mercado,
-- y la torre del homenaje de 3 plantas con montacargas (ascensor) hasta la azotea.
local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Buildings = require(Lib.Buildings)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local Castle = {
	Title = "Castillo",
	Description = "Murallas, torres, foso con puente levadizo, mercado y torre del homenaje con montacargas.",
	Lighting = { ClockTime = 16.5, Brightness = 1.8 },
	Bounds = { x1 = -110, x2 = 110, z1 = -110, z2 = 130, top = 110, floor = 0 },
	Disasters = { "Earthquake", "Fire", "Meteors", "Lightning", "Tornado", "Volcano", "Flood", "Virus", "Blizzard", "UFO" },
	DisasterConfig = { Flood = { maxHeight = 20 } },
}

local STONE = C(150, 145, 135)
local DARK_STONE = C(110, 105, 98)

local function crenellatedWall(b, axis, fixed, a1, a2, h, th)
	b:Wall("Muralla", axis, fixed, a1, a2, 0, h, th, STONE, M.Cobblestone)
	-- almenas
	local step = 4
	local a = a1 + 1
	while a + 2 <= a2 do
		local pos = axis == "x" and V(a + 1, h + 1.5, fixed) or V(fixed, h + 1.5, a + 1)
		local size = axis == "x" and V(2, 3, th) or V(th, 3, 2)
		b:Box("Almena", size, pos, STONE, M.Cobblestone)
		a = a + step
	end
	-- adarve (pasillo encima de la muralla)
	local mid = (a1 + a2) / 2
	local len = a2 - a1
	local walk = axis == "x" and V(len, 1, 5) or V(5, 1, len)
	local wpos = axis == "x" and V(mid, h - 0.5, fixed + (fixed < 0 and 3 or -3)) or V(fixed + (fixed < 0 and 3 or -3), h - 0.5, mid)
	b:Box("Adarve", walk, wpos, DARK_STONE, M.Slate)
end

function Castle.Build(b)
	b:Box("Isla", V(320, 10, 340), V(0, -5.5, 10), Colors.Grass, M.Grass, { indestructible = true })
	b:Sea(-6)
	-- foso
	b:Box("Foso", V(200, 0.6, 10), V(0, -0.2, 92), Colors.Water, M.SmoothPlastic, { transparency = 0.2, canCollide = false, indestructible = true })

	local castle = b:Group("Castillo")
	local half, H = 80, 18
	castle:Slab("Patio", -half, half, -half, half, 0.3, 0.3, C(170, 160, 140), M.Pebble)
	crenellatedWall(castle, "x", -half, -half, half, H, 3)
	crenellatedWall(castle, "z", -half, -half, half, H, 3)
	crenellatedWall(castle, "z", half, -half, half, H, 3)
	-- muralla frontal con puerta
	castle:Wall("Muralla", "x", half, -half, half, 0, H, 3, STONE, M.Cobblestone, { { from = -8, to = 8, bottom = 0, top = 12 } })
	castle:Box("Puente", V(16, 1, 14), V(0, 0.5, 92), C(120, 85, 55), M.WoodPlanks)
	castle:Box("Rastrillo", V(16, 0.6, 1), V(0, 15, half + 2), Colors.DarkMetal, M.Metal)
	-- escaleras para subir al adarve
	castle:Stairs("EscaleraMuralla", -half + 8, half - 8, 0, H - 0.5, 6, 22, "-z", DARK_STONE, M.Slate)
	castle:Stairs("EscaleraMuralla", half - 8, -half + 8, 0, H - 0.5, 6, 22, "+z", DARK_STONE, M.Slate)

	-- torres de esquina
	for _, p in ipairs({ { -half, -half }, { half, -half }, { -half, half }, { half, half } }) do
		castle:Pillar("TorreEsquina", p[1], p[2], 0, 30, 16, STONE, M.Cobblestone)
		castle:Pillar("CoronaTorre", p[1], p[2], 30, 33, 18, DARK_STONE, M.Cobblestone)
		castle:Box("Bandera", V(0.3, 6, 4), V(p[1], 38, p[2] + 2), Colors.Red, M.Fabric)
		castle:Pillar("Mastil", p[1], p[2], 33, 41, 0.4, Colors.Wood, M.Wood)
	end

	-- torre del homenaje (3 plantas) con montacargas
	local keep = b:Group("TorreHomenaje")
	local x1, x2, z1, z2 = -30, 30, -70, -20
	local levels = { 0, 16, 32, 48 }
	local lift = { name = "Montacargas", x = 0, z = z1 + 6.4, floors = levels, labels = { "PB", "1", "2", "A" }, wallColor = DARK_STONE, wallMaterial = M.Cobblestone }
	local hole = Elevator.hole(lift)
	local stairHoles = { { 12, 28, z2 - 9, z2 - 3 }, { 12, 28, z2 - 15, z2 - 9 }, { 12, 28, z2 - 9, z2 - 3 } }
	for i, y in ipairs(levels) do
		local holes = { hole }
		if i > 1 then
			holes[#holes + 1] = stairHoles[i - 1]
		end
		keep:Slab("Planta", x1, x2, z1, z2, y + (i == 1 and 0.4 or 0), 1.2, C(120, 90, 60), M.WoodPlanks, holes)
	end
	for i = 1, 3 do
		local y = levels[i]
		local front = Util.Windows(x1 + 1, x2 - 1, 10, 3, 6, 12)
		if i == 1 then
			front = Util.Windows(x1 + 1, x2 - 1, 10, 3, 6, 12, -6, 6)
			front[#front + 1] = { from = -5, to = 5, bottom = 0, top = 10 }
		end
		keep:Wall("Muro", "x", z2, x1, x2, y, y + 16, 2, STONE, M.Cobblestone, front)
		keep:Wall("Muro", "x", z1, x1, x2, y, y + 16, 2, STONE, M.Cobblestone)
		keep:Wall("Muro", "z", x1, z1, z2, y, y + 16, 2, STONE, M.Cobblestone, Util.Windows(z1 + 1, z2 - 1, 10, 3, 6, 12))
		keep:Wall("Muro", "z", x2, z1, z2, y, y + 16, 2, STONE, M.Cobblestone, Util.Windows(z1 + 1, z2 - 1, 10, 3, 6, 12))
		if i % 2 == 1 then
			keep:Stairs("Escalera", 12, z2 - 6, y, y + 16, 6, 16, "+x", DARK_STONE, M.Slate)
		else
			keep:Stairs("Escalera", 28, z2 - 12, y, y + 16, 6, 16, "-x", DARK_STONE, M.Slate)
		end
	end
	Elevator.build(keep, lift)
	-- salon del trono
	keep:Box("Alfombra", V(6, 0.2, 30), V(-14, 0.6, -45), C(160, 30, 40), M.Fabric)
	keep:Box("Trono", V(5, 7, 4), V(-14, 3.5, -62), C(200, 160, 40), M.Wood)
	keep:Box("Mesa", V(16, 3, 5), V(-14, 17.5, -45), Colors.Wood, M.Wood)
	for k = 0, 3 do
		keep:Box("Barril", V(3, 4, 3), V(-24 + k * 4, 34, -60), C(120, 80, 40), M.Wood)
	end
	-- almenas de la azotea
	for k = 0, 14 do
		keep:Box("AlmenaTorre", V(2, 3, 2), V(x1 + 2 + k * 4, 49.5, z2 - 1), STONE, M.Cobblestone)
		keep:Box("AlmenaTorre", V(2, 3, 2), V(x1 + 2 + k * 4, 49.5, z1 + 1), STONE, M.Cobblestone)
	end

	-- patio: pozo y mercado (madera: arde)
	local yard = b:Group("Patio")
	yard:Pillar("Pozo", 40, 30, 0.3, 3, 6, STONE, M.Cobblestone)
	yard:Pillar("AguaPozo", 40, 30, 2.6, 2.8, 4.6, Colors.Water, M.SmoothPlastic)
	yard:Box("TejadoPozo", V(8, 0.6, 8), V(40, 8, 30), Colors.Wood, M.WoodPlanks)
	for _, x in ipairs({ 36.5, 43.5 }) do
		yard:Box("PostePozo", V(0.6, 5, 0.6), V(x, 5.5, 30), Colors.Wood, M.Wood)
	end
	local stallColors = { Colors.Red, Colors.Blue, Colors.Yellow, Colors.Green }
	for k = 0, 3 do
		local x = -60 + k * 18
		yard:Box("Puesto", V(10, 3.5, 5), V(x, 2, 40), Colors.Wood, M.Wood)
		yard:Box("Toldo", V(12, 0.4, 8), V(x, 8, 41), stallColors[k + 1], M.Fabric)
		for _, sx in ipairs({ -5, 5 }) do
			yard:Box("PostePuesto", V(0.5, 8, 0.5), V(x + sx, 4, 44), Colors.Wood, M.Wood)
		end
		yard:Box("Mercancia", V(3, 1.5, 2), V(x, 4.5, 40), C(200, 120, 60), M.Fabric)
	end
	-- establos y heno
	yard:Box("Establo", V(26, 10, 14), V(55, 5, -40), C(140, 90, 55), M.WoodPlanks)
	for k = 0, 4 do
		yard:Box("Heno", V(3, 2.5, 3), V(48 + k * 3.5, 1.5, -28), C(220, 190, 90), M.Grass)
	end

	-- bosque alrededor
	local trees = b:Group("Bosque")
	for i = 0, 19 do
		local a = i / 20 * math.pi * 2
		trees:Pine(math.cos(a) * 125, 10 + math.sin(a) * 125, 0, 1.5)
	end

	-- aparicion: en el patio
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-30 + ix * 20, 1.3, -4 + iz * 12))
		end
	end
end

return Castle
]])

	add("ServerStorage", { "IslasMapas", "Builders" }, "City", "ModuleScript", [[
-- Ciudad: manzanas con casas de 1-3 plantas, tiendas, una torre de apartamentos con ascensor,
-- gasolinera, parque, deposito de agua, calles con coches y farolas.
local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Buildings = require(Lib.Buildings)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local City = {
	Title = "Ciudad",
	Description = "Calles con casas, tiendas, gasolinera, parque y una torre de apartamentos con ascensor.",
	Lighting = { ClockTime = 13, Brightness = 2 },
	Bounds = { x1 = -170, x2 = 170, z1 = -170, z2 = 170, top = 110, floor = 0 },
	Disasters = { "Earthquake", "Fire", "Tornado", "Meteors", "Flood", "AcidRain", "Lightning", "Tsunami", "Virus", "UFO", "Volcano", "BlackHole" },
	DisasterConfig = { Flood = { maxHeight = 26 }, Tsunami = { height = 30 } },
}

local HOUSE_COLORS = { C(235, 220, 190), C(200, 220, 235), C(240, 200, 190), C(210, 235, 200), C(240, 235, 210), C(220, 205, 235) }
local ROOF_COLORS = { C(170, 70, 50), C(90, 90, 100), C(120, 60, 40), C(60, 90, 140) }

function City.Build(b)
	b:Box("Isla", V(420, 10, 420), V(0, -5.5, 0), Colors.Grass, M.Grass, { indestructible = true })
	b:Sea(-6)

	-- calles: cruz principal y anillo
	local streets = b:Group("Calles")
	for _, s in ipairs({ { V(340, 0.5, 18), V(0, -0.25, 0) }, { V(18, 0.5, 340), V(0, -0.25, 0) }, { V(340, 0.5, 14), V(0, -0.25, -120) }, { V(340, 0.5, 14), V(0, -0.25, 120) }, { V(14, 0.5, 340), V(-120, -0.25, 0) }, { V(14, 0.5, 340), V(120, -0.25, 0) } }) do
		streets:Box("Calle", s[1], s[2], Colors.Asphalt, M.Asphalt, { indestructible = true })
	end
	for x = -160, 160, 16 do
		streets:Box("Linea", V(7, 0.1, 0.6), V(x, 0.02, 0), Colors.White, M.SmoothPlastic, { canCollide = false, indestructible = true })
		streets:Box("Linea", V(0.6, 0.1, 7), V(0, 0.02, x), Colors.White, M.SmoothPlastic, { canCollide = false, indestructible = true })
	end

	-- casas en las cuatro manzanas (cuadrantes)
	local houses = b:Group("Casas")
	local n = 0
	for _, qx in ipairs({ -1, 1 }) do
		for _, qz in ipairs({ -1, 1 }) do
			for row = 0, 1 do
				for col = 0, 1 do
					n = n + 1
					local cx = qx * (35 + col * 45)
					local cz = qz * (35 + row * 45)
					-- la manzana noreste es la de la torre y el parque
					if not (qx == 1 and qz == -1) then
						local floors = (n % 3 == 0) and 3 or ((n % 2 == 0) and 2 or 1)
						Buildings.House(houses, cx, cz, 24, 22, floors, {
							name = "Casa" .. n,
							color = HOUSE_COLORS[n % #HOUSE_COLORS + 1],
							roofColor = ROOF_COLORS[n % #ROOF_COLORS + 1],
							roof = floors == 3 and "flat" or "pitched",
						})
						-- valla del jardin
						houses:Box("Seto", V(26, 2.5, 1.2), V(cx, 1.25, cz + qz * -14), C(50, 120, 50), M.Grass)
					end
				end
			end
		end
	end

	-- torre de apartamentos con ascensor (manzana noreste)
	Buildings.Tower(b, 58, -58, 34, 34, 6, { name = "Apartamentos", story = 12, color = C(190, 195, 210) })
	b:Board("CartelTorre", "APARTAMENTOS SOL", V(20, 3, 0.4), V(58, 10, -40.6), C(40, 50, 80), C(255, 220, 120))

	-- parque con fuente y arboles (al lado de la torre)
	local park = b:Group("Parque")
	park:Box("Cesped", V(40, 0.3, 40), V(100, 0.15, -100), C(80, 160, 70), M.Grass, { indestructible = true })
	park:Pillar("Fuente", 100, -100, 0.3, 1.6, 10, Colors.Concrete, M.Marble)
	park:Pillar("Agua", 100, -100, 1.6, 1.9, 8, Colors.Water, M.SmoothPlastic)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		park:Pine(100 + math.cos(a) * 15, -100 + math.sin(a) * 15, 0.3, 1.1)
	end

	-- gasolinera (sur-este): explota con el fuego
	local gas = b:Group("Gasolinera")
	gas:Box("Marquesina", V(30, 1, 18), V(140, 10, 140), C(230, 50, 50), M.Metal)
	for _, p in ipairs({ { 128, 133 }, { 152, 133 }, { 128, 147 }, { 152, 147 } }) do
		gas:Pillar("Columna", p[1], p[2], 0, 10, 1, Colors.White, M.Metal)
	end
	for _, x in ipairs({ 134, 146 }) do
		gas:Box("Surtidor", V(2, 4, 1.4), V(x, 2, 140), Colors.Red, M.Plastic)
	end
	gas:Box("Tienda24h", V(16, 9, 12), V(140, 4.5, 157), C(240, 240, 240), M.SmoothPlastic)
	gas:Board("CartelGas", "GASOLINERA 24H", V(16, 2.4, 0.4), V(140, 7, 150.8), C(230, 50, 50), Colors.White)

	-- tiendas (fila al oeste de la calle principal)
	local shops = b:Group("Tiendas")
	for i, name in ipairs({ "PANADERIA", "FARMACIA", "CAFE" }) do
		local cz = -50 + i * 30
		Buildings.House(shops, -150, cz, 20, 22, 1, { name = "Tienda" .. i, color = HOUSE_COLORS[i], roof = "flat", roofColor = Colors.DarkMetal, furnish = false })
		shops:Board("Rotulo" .. i, name, V(14, 2.4, 0.4), V(-150, 10, cz + 11.4), C(40, 40, 50), C(255, 220, 120))
	end

	-- deposito de agua
	local tank = b:Group("Deposito")
	for _, p in ipairs({ { -100, -150 }, { -88, -150 }, { -100, -138 }, { -88, -138 } }) do
		tank:Pillar("Pata", p[1], p[2], 0, 30, 1.2, Colors.DarkMetal, M.Metal)
	end
	tank:Pillar("Tanque", -94, -144, 30, 42, 16, C(150, 180, 210), M.Metal)
	tank:Board("Nombre", "CIUDAD", V(10, 3, 0.4), V(-94, 36, -135.8), C(150, 180, 210), C(40, 50, 80))

	-- coches y farolas
	local cols = { Colors.Red, Colors.Blue, Colors.Yellow, Colors.Green, C(240, 240, 240) }
	for i = 0, 7 do
		Buildings.Car(b, -140 + i * 40, 4, 0, cols[i % #cols + 1], 90)
	end
	for i = -3, 3 do
		if i ~= 0 then
			Buildings.Lamp(b, i * 45, 12, 0)
		end
		Buildings.Lamp(b, 12, i * 45 + 20, 0)
	end
	-- semaforos en el cruce
	for _, p in ipairs({ { 11, 11 }, { -11, -11 } }) do
		b:Pillar("Semaforo", p[1], p[2], 0, 8, 0.5, Colors.DarkMetal, M.Metal)
		b:Box("Luces", V(1.2, 3, 1.2), V(p[1], 9, p[2]), C(30, 30, 30), M.Metal)
		b:Ball("Verde", 0.9, V(p[1], 8.2, p[2] + 0.6), C(60, 255, 90), M.Neon)
	end

	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-18 + ix * 12, 1, -18 + iz * 18))
		end
	end
end

return City
]])

	add("ServerStorage", { "IslasMapas", "Builders" }, "CruiseShip", "ModuleScript", [[
-- Crucero: barco enorme en alta mar con 4 cubiertas, 2 ascensores, escaleras, piscina en la cubierta
-- de sol, chimenea, puente de mando y botes salvavidas. Caer al mar es morir.
local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local Buildings = require(Lib.Buildings)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors
local windows = Util.Windows

local CruiseShip = {
	Title = "Crucero",
	Description = "Un crucero gigante en alta mar: 4 cubiertas, ascensores, piscina y botes salvavidas.",
	Lighting = { ClockTime = 17, Brightness = 2, FogEnd = 3000 },
	Bounds = { x1 = -120, x2 = 140, z1 = -40, z2 = 40, top = 90, floor = 0 },
	Disasters = { "Tsunami", "Flood", "Lightning", "Tornado", "Meteors", "Fire", "Virus", "UFO", "BlackHole", "AcidRain" },
	DisasterConfig = { Flood = { maxHeight = 40 }, Tsunami = { height = 30, maxHeight = 14 } },
}

local WHITE = C(240, 242, 245)
local HULL = C(30, 50, 90)

function CruiseShip.Build(b)
	b:Sea(0, 2048, C(30, 90, 150), 0.1)

	local ship = b:Group("Barco")
	local X1, X2, Z = -110, 110, 25
	local decks = { 10, 22, 34, 46 }

	-- casco
	ship:Wall("Casco", "x", Z, X1, X2, -10, 10, 1.5, HULL, M.Metal)
	ship:Wall("Casco", "x", -Z, X1, X2, -10, 10, 1.5, HULL, M.Metal)
	ship:Wall("Popa", "z", X1, -Z, Z, -10, 10, 1.5, HULL, M.Metal)
	ship:Box("Fondo", V(X2 - X1, 1.5, Z * 2), V(0, -10, 0), HULL, M.Metal)
	ship:Box("FranjaRoja", V(X2 - X1, 2, Z * 2 + 0.4), V(0, -1, 0), C(180, 40, 40), M.Metal, { transparency = 0 })
	-- proa en punta
	ship:Wedge("Proa", V(Z * 2, 20, 30), V(X2 + 15, 0, 0), HULL, M.Metal, -90)

	-- elevadores y escaleras
	local elevA = { name = "AscensorProa", x = 30, z = -13.6, floors = decks, labels = { "1", "2", "3", "Sol" }, wallColor = C(200, 200, 205) }
	local elevB = { name = "AscensorPopa", x = -30, z = -13.6, floors = decks, labels = { "1", "2", "3", "Sol" }, wallColor = C(200, 200, 205) }
	local hA, hB = Elevator.hole(elevA), Elevator.hole(elevB)
	local SX1, SX2 = -78, -62
	local function stairHole(i)
		if i % 2 == 1 then
			return { SX1, SX2, 10, 16 }
		end
		return { SX1, SX2, 4, 10 }
	end

	-- cubiertas
	for i, y in ipairs(decks) do
		local holes = { hA, hB }
		if i > 1 then
			holes[#holes + 1] = stairHole(i - 1)
		end
		local x1, x2, z = X1, X2, Z
		ship:Slab("Cubierta" .. i, x1, x2, -z, z, y, 1.2, i == 4 and C(170, 130, 90) or C(200, 190, 175), i == 4 and M.WoodPlanks or M.SmoothPlastic, holes)
	end
	-- superestructura (camarotes) entre cubiertas
	local SX, EX, SZ = -82, 72, 20
	for i = 1, 3 do
		local y = decks[i]
		local top = decks[i + 1]
		local win = windows(SX + 1, EX - 1, 7, 4, 4, 9)
		ship:Wall("Camarotes", "x", SZ, SX, EX, y, top, 0.8, WHITE, M.SmoothPlastic, win)
		local back = windows(SX + 1, EX - 1, 7, 4, 4, 9, -38, 38)
		ship:Wall("Camarotes", "x", -SZ, SX, EX, y, top, 0.8, WHITE, M.SmoothPlastic, back)
		local door = { { from = -4, to = 4, bottom = 0, top = 9 } }
		ship:Wall("Camarotes", "z", SX, -SZ, SZ, y, top, 0.8, WHITE, M.SmoothPlastic, door)
		ship:Wall("Camarotes", "z", EX, -SZ, SZ, y, top, 0.8, WHITE, M.SmoothPlastic, { { from = -4, to = 4, bottom = 0, top = 9 } })
		if i % 2 == 1 then
			ship:Stairs("Escalera", SX1, 13, y, top, 6, SX2 - SX1, "+x", C(180, 180, 185), M.Metal)
		else
			ship:Stairs("Escalera", SX2, 7, y, top, 6, SX2 - SX1, "-x", C(180, 180, 185), M.Metal)
		end
		Buildings.Furnish(ship, -50, 10, 0, 18, y, i * 11)
		Buildings.Furnish(ship, 40, 70, 0, 18, y, i * 17)
	end
	Elevator.build(ship, elevA)
	Elevator.build(ship, elevB)

	-- barandillas de la cubierta principal y de la de sol
	for _, y in ipairs({ decks[1], decks[4] }) do
		ship:Wall("Barandilla", "x", Z, X1, X2, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
		ship:Wall("Barandilla", "x", -Z, X1, X2, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
		ship:Wall("Barandilla", "z", X1, -Z, Z, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
		ship:Wall("Barandilla", "z", X2, -Z, Z, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
	end

	-- cubierta de sol: piscina, tumbonas, chimenea y puente de mando
	local sun = b:Group("CubiertaSol")
	local ys = decks[4]
	sun:Box("BordePiscina", V(30, 1.6, 16), V(5, ys + 0.8, 4), C(230, 230, 235), M.Marble)
	sun:Box("Agua", V(28, 0.2, 14), V(5, ys + 1.7, 4), Colors.Water, M.SmoothPlastic, { transparency = 0.3, canCollide = false })
	for k = 0, 5 do
		sun:Box("Tumbona", V(2.4, 1, 6), V(-20 + k * 4, ys + 0.5, 16), C(240, 240, 240), M.Fabric)
	end
	sun:Box("Chimenea", V(14, 22, 10), V(-55, ys + 11, 0), C(200, 40, 40), M.Metal)
	sun:Box("ChimeneaTop", V(14.4, 4, 10.4), V(-55, ys + 20, 0), C(20, 20, 25), M.Metal)
	sun:Box("PuenteMando", V(20, 10, 36), V(80, ys + 5, 0), WHITE, M.SmoothPlastic)
	sun:Box("Ventanal", V(0.4, 4, 34), V(90.2, ys + 6, 0), Colors.Glass, M.Glass, { transparency = 0.4 })
	sun:Board("Nombre", "ISLA DORADA", V(30, 5, 0.4), V(0, 4, Z + 1), HULL, C(255, 220, 120))
	sun:Pillar("Mastil", 95, 0, ys, ys + 24, 0.8, WHITE, M.Metal)
	sun:Box("Radar", V(8, 0.6, 1.4), V(95, ys + 25, 0), Colors.DarkMetal, M.Metal)

	-- botes salvavidas
	for k = 0, 5 do
		local x = -90 + k * 32
		for _, side in ipairs({ -1, 1 }) do
			b:Box("BoteSalvavidas", V(12, 3, 4), V(x, 27, side * (Z + 3)), C(255, 130, 30), M.SmoothPlastic)
			b:Box("Pescante", V(1, 6, 1), V(x, 30, side * (Z + 1)), Colors.DarkMetal, M.Metal)
		end
	end

	-- aparicion: cubierta de proa
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(76 + ix * 8, decks[1] + 1, -16 + iz * 16))
		end
	end
end

return CruiseShip
]])

	add("ServerStorage", { "IslasMapas", "Builders" }, "Mall", "ModuleScript", [[
-- Centro comercial: 4 plantas alrededor de un gran atrio con claraboya, ascensores panoramicos de cristal,
-- escaleras, tiendas, fuente central, cine en la ultima planta y aparcamiento.

local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local Mall = {
	Title = "Centro Comercial",
	Description = "4 plantas con atrio, ascensores de cristal, escaleras, tiendas, fuente y cine.",
	Lighting = { ClockTime = 12, Brightness = 2 },
	Bounds = { x1 = -110, x2 = 110, z1 = -90, z2 = 150, top = 80, floor = 0 },
	Disasters = { "Earthquake", "Fire", "Meteors", "AcidRain", "Lava", "Virus", "BlackHole", "Volcano" },
	DisasterConfig = { Lava = { maxHeight = 40 } }, -- hay que llegar a la ultima planta
}

local FLOOR_H = 16
local SHOP_COLORS = { Colors.Red, Colors.Blue, Colors.Orange, Colors.Green, Colors.Yellow, C(170, 90, 200), C(60, 180, 190) }
local SHOP_NAMES = { "MODA", "TECH", "JUGUETES", "LIBROS", "DEPORTES", "ZAPATOS", "MUSICA", "CAFE" }

function Mall.Build(b)
	b:Box("Isla", V(420, 10, 360), V(0, -5.5, 0), Colors.Grass, M.Grass)
	b:Sea(-6)
	b:Box("Aparcamiento", V(300, 0.5, 70), V(0, -0.25, 110), Colors.Asphalt, M.Asphalt)
	for x = -135, 135, 15 do
		b:Box("PlazaAparcamiento", V(0.4, 0.1, 12), V(x, 0.02, 112), Colors.White, M.SmoothPlastic, { canCollide = false })
	end

	local mall = b:Group("Edificio")
	-- planta rectangular: x[-100,100], z[-80,80]. Atrio central x[-30,30], z[-30,30]
	local x1, x2, z1, z2 = -100, 100, -80, 80
	local floors = { 0, FLOOR_H, FLOOR_H * 2, FLOOR_H * 3 }
	local roofY = FLOOR_H * 4
	local atrium = { -30, 30, -30, 30 }

	-- ascensores de cristal en el lado norte del atrio, mirando a +Z hacia el atrio
	local elevL = { name = "AscensorCristalA", x = -14, z = -50, floors = floors, labels = { "PB", "1", "2", "3" }, glass = true }
	local elevR = { name = "AscensorCristalB", x = 14, z = -50, floors = floors, labels = { "PB", "1", "2", "3" }, glass = true }
	local hL, hR = Elevator.hole(elevL), Elevator.hole(elevR)
	-- escalera de la PB a la 1 y de la 1 a la 2 y de la 2 a la 3 en el lado sur
	local stairHoles = {
		{ -30, -2, 40, 48 },
		{ 2, 30, 56, 64 },
		{ -30, -2, 40, 48 },
	}

	mall:Slab("SueloPB", x1, x2, z1, z2, 0, 0.5, C(225, 225, 230), M.Marble, { hL, hR })
	for i = 2, 4 do
		local holes = { hL, hR, atrium }
		if i - 1 <= #stairHoles then
			holes[#holes + 1] = stairHoles[i - 1]
		end
		mall:Slab("Suelo" .. (i - 1), x1, x2, z1, z2, floors[i], 1.5, C(225, 225, 230), M.Marble, holes)
	end
	-- claraboya del atrio
	mall:Slab("Techo", x1 - 4, x2 + 4, z1 - 4, z2 + 4, roofY + 2, 2, Colors.DarkMetal, M.Metal, { { -28, 28, -28, 28 } })
	mall:Box("Claraboya", V(56, 0.6, 56), V(0, roofY + 1.5, 0), Colors.Glass, M.Glass, { transparency = 0.6 })

	-- muros exteriores con grandes cristaleras
	for i, y in ipairs(floors) do
		local top = y + FLOOR_H
		local function glassBand(a1, a2, skipFrom, skipTo)
			local list = {}
			local c = a1 + 7
			while c + 5 <= a2 do
				if not (skipFrom and c + 5 > skipFrom and c - 5 < skipTo) then
					list[#list + 1] = { from = c - 5, to = c + 5, bottom = 2, top = 13, glass = true }
				end
				c = c + 14
			end
			return list
		end
		local entrance = (i == 1) and { { from = -8, to = 8, bottom = 0, top = 11 } } or {}
		local frontList = glassBand(x1 + 2, x2 - 2, -8, 8)
		for _, e in ipairs(entrance) do
			frontList[#frontList + 1] = e
		end
		mall:Wall("FachadaSur" .. i, "x", z2, x1, x2, y, top, 1, C(235, 235, 240), M.Concrete, frontList)
		mall:Wall("FachadaNorte" .. i, "x", z1, x1, x2, y, top, 1, C(235, 235, 240), M.Concrete)
		mall:Wall("FachadaOeste" .. i, "z", x1, z1, z2, y, top, 1, C(235, 235, 240), M.Concrete, glassBand(z1 + 2, z2 - 2))
		mall:Wall("FachadaEste" .. i, "z", x2, z1, z2, y, top, 1, C(235, 235, 240), M.Concrete, glassBand(z1 + 2, z2 - 2))
	end
	mall:Board("Letrero", "GRAN CENTRO COMERCIAL", V(80, 7, 1), V(0, roofY + 8, z2 + 3), Colors.Red, C(255, 255, 255))

	-- barandillas de cristal alrededor del atrio en plantas 1-3
	for i = 2, 4 do
		local y = floors[i]
		mall:Wall("BarandillaN", "x", atrium[3], atrium[1], atrium[2], y, y + 4, 0.3, Colors.Glass, M.Glass, {})
		mall:Wall("BarandillaS", "x", atrium[4], atrium[1], atrium[2], y, y + 4, 0.3, Colors.Glass, M.Glass, {})
		mall:Wall("BarandillaO", "z", atrium[1], atrium[3], atrium[4], y, y + 4, 0.3, Colors.Glass, M.Glass, {})
		mall:Wall("BarandillaE", "z", atrium[2], atrium[3], atrium[4], y, y + 4, 0.3, Colors.Glass, M.Glass, {})
	end

	Elevator.build(mall, elevL)
	Elevator.build(mall, elevR)

	-- escaleras (cada tramo en su hueco)
	mall:Stairs("EscaleraPB", -30, 44, 0, FLOOR_H, 8, 28, "+x", C(210, 210, 215), M.Concrete)
	mall:Stairs("Escalera1", 30, 60, FLOOR_H, FLOOR_H * 2, 8, 28, "-x", C(210, 210, 215), M.Concrete)
	mall:Stairs("Escalera2", -30, 44, FLOOR_H * 2, FLOOR_H * 3, 8, 28, "+x", C(210, 210, 215), M.Concrete)

	-- fuente central en planta baja
	local fountain = mall:Group("Fuente")
	fountain:Pillar("Base", 0, 0, 0, 1.5, 22, Colors.Concrete, M.Marble)
	fountain:Pillar("Agua", 0, 0, 1.5, 1.8, 19, Colors.Water, M.SmoothPlastic)
	fountain:Pillar("Columna", 0, 0, 1.8, 8, 3, Colors.Concrete, M.Marble)
	fountain:Pillar("Cuenco", 0, 0, 8, 9, 10, Colors.Concrete, M.Marble)
	fountain:Ball("Esfera", 5, V(0, 11.5, 0), Colors.Glass, M.Glass)

	-- tiendas: bloques pegados a las paredes en cada planta (dejando libres ascensores y atrio)
	local shops = mall:Group("Tiendas")
	local n = 0
	for i, y in ipairs(floors) do
		local base = y
		local function shop(x, z, w, d, faceBack)
			n = n + 1
			local col = SHOP_COLORS[(n - 1) % #SHOP_COLORS + 1]
			local name = SHOP_NAMES[(n - 1) % #SHOP_NAMES + 1]
			shops:Box("Tienda", V(w, 3.5, d), V(x, base + 1.75, z), C(250, 250, 250), M.SmoothPlastic)
			shops:Box("Vitrina", V(w - 2, 5, 0.5), V(x, base + 6, z + (faceBack and -d / 2 or d / 2)), Colors.Glass, M.Glass, { transparency = 0.5 })
			shops:Board("Cartel", name, V(w - 1, 3, 0.5), V(x, base + 11, z + d / 2 + 0.3), col, C(255, 255, 255))
		end
		for k = 0, 3 do
			shop(-80 + k * 16, 70, 12, 8)
			shop(80 - k * 16, 70, 12, 8)
		end
		-- tiendas laterales (este y oeste)
		for k = 0, 2 do
			shop(-92, -10 + k * 22, 8, 14)
			shop(92, -10 + k * 22, 8, 14)
		end
	end

	-- bancos y plantas en cada planta
	local decor = mall:Group("Decoracion")
	for i, y in ipairs(floors) do
		local base = y
		for _, p in ipairs({ { -45, -20 }, { 45, -20 }, { -45, 20 }, { 45, 20 } }) do
			decor:Box("Banco", V(7, 1.2, 2), V(p[1], base + 0.6, p[2]), Colors.Wood, M.Wood)
			decor:Pillar("Maceta", p[1] + 6, p[2], base, base + 2, 2.6, Colors.Wood, M.Wood)
			decor:Ball("Planta", 4, V(p[1] + 6, base + 4, p[2]), Colors.Green, M.Grass)
		end
	end

	-- cine en la ultima planta (zona sur-oeste): sala con butacas y pantalla
	local cine = mall:Group("Cine")
	local cy = floors[4]
	cine:Box("Pantalla", V(26, 11, 0.6), V(-65, cy + 7.5, 47), C(240, 240, 255), M.SmoothPlastic)
	cine:Board("CartelCine", "CINE", V(8, 3, 0.4), V(-65, cy + 14, 20.7), Colors.DarkMetal, C(255, 220, 90))
	for row = 0, 4 do
		for col = 0, 5 do
			cine:Box("Butaca", V(3, 2, 2.4), V(-76 + col * 4.4, cy + 1 + row * 0.7, 20 + row * 4), Colors.Red, M.Fabric)
		end
	end

	-- aparcamiento: coches decorativos
	local cars = b:Group("Coches")
	for i = 0, 9 do
		local x = -135 + i * 30
		if i % 3 ~= 1 then
			cars:Box("Coche", V(5, 1.6, 10), V(x + 7.5, 1.4, 112), SHOP_COLORS[i % #SHOP_COLORS + 1], M.Metal)
			cars:Box("Cabina", V(4.2, 1.4, 5), V(x + 7.5, 2.9, 111), Colors.Glass, M.Glass, { transparency = 0.4 })
		end
	end

	-- arboles en la isla
	local trees = b:Group("Arboles")
	for i = 0, 11 do
		trees:Pine(-170 + i * 31, 160, 0, 1.2)
		trees:Pine(-170 + i * 31, -150, 0, 1.2)
	end

	-- puntos de aparicion: a la entrada, planta baja
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-50 + ix * 33, 1, 88 + iz * 14))
		end
	end
end

return Mall
]])

	add("ServerStorage", { "IslasMapas", "Builders" }, "OilRig", "ModuleScript", [[
-- Plataforma petrolifera en mitad del mar: cubierta principal sobre 4 patas, torre de perforacion,
-- modulo de alojamiento, helipuerto y muelle. Un ascensor une muelle, cubierta, modulo y helipuerto.
-- Si caes al mar, mueres.

local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local OilRig = {
	Title = "Plataforma Petrolifera",
	Description = "Plataforma en alta mar con torre de perforacion, helipuerto y ascensor desde el muelle.",
	Lighting = { ClockTime = 19.5, Brightness = 2, FogEnd = 2500, FogColor = C(120, 130, 150) },
	Bounds = { x1 = -50, x2 = 50, z1 = -50, z2 = 50, top = 110, floor = 0 },
	Disasters = { "Tornado", "Lightning", "Meteors", "Flood", "Fire", "AcidRain", "Tsunami", "Virus" },
	DisasterConfig = { Flood = { maxHeight = 46 } }, -- tsunami: inunda la cubierta, el modulo y el helipuerto quedan a salvo
}

local DECK = 30
local STEEL = C(110, 115, 125)
local RUST = C(150, 90, 60)

function OilRig.Build(b)
	b:Sea(0, 2048, C(25, 70, 120), 0.1)
	-- pequeno islote de roca bajo la plataforma, solo decorativo
	b:Box("Roca", V(18, 14, 18), V(-52, -3, 52), C(90, 90, 95), M.Slate)

	local rig = b:Group("Plataforma")
	local half = 45

	-- patas y cruces
	local legs = rig:Group("Patas")
	for _, p in ipairs({ { -36, -36 }, { 36, -36 }, { -36, 36 }, { 36, 36 } }) do
		legs:Pillar("Pata", p[1], p[2], -30, DECK, 8, STEEL, M.Metal)
		legs:Pillar("Anillo", p[1], p[2], 2, 6, 9, Colors.Yellow, M.Metal)
	end
	for _, y in ipairs({ 8, 18 }) do
		legs:Box("CruceX1", V(72, 1.6, 1.6), V(0, y, -36), STEEL, M.Metal)
		legs:Box("CruceX2", V(72, 1.6, 1.6), V(0, y, 36), STEEL, M.Metal)
		legs:Box("CruceZ1", V(1.6, 1.6, 72), V(-36, y, 0), STEEL, M.Metal)
		legs:Box("CruceZ2", V(1.6, 1.6, 72), V(36, y, 0), STEEL, M.Metal)
	end

	-- cubierta principal
	local elev = { name = "AscensorPlataforma", x = 0, z = -34, floors = { 3, DECK, 44, 58 }, labels = { "M", "1", "2", "H" }, wallColor = RUST }
	local hole = Elevator.hole(elev)
	rig:Slab("Cubierta", -half, half, -half, half, DECK, 2, STEEL, M.DiamondPlate, { hole })
	for _, w in ipairs({ { "x", half, -half, half }, { "x", -half, -half, half }, { "z", half, -half, half }, { "z", -half, -half, half } }) do
		rig:Wall("Barandilla", w[1], w[2], w[3], w[4], DECK, DECK + 3.5, 0.3, Colors.Yellow, M.Metal, {
			{ from = w[3] + 1, to = w[4] - 1, bottom = 1.2, top = 3.5, glass = true },
		})
	end

	Elevator.build(rig, elev)

	-- muelle flotante a nivel del mar, delante del ascensor
	local pier = rig:Group("Muelle")
	pier:Slab("Embarcadero", -15, 15, -28, 5, 3, 2.5, Colors.Wood, M.Wood)
	for _, p in ipairs({ { -13, -26 }, { 13, -26 }, { -13, 3 }, { 13, 3 } }) do
		pier:Pillar("Poste", p[1], p[2], -12, 3.5, 1.4, Colors.Wood, M.Wood)
	end
	pier:Wall("BarandillaMuelle", "x", 5, -15, 15, 3, 6, 0.3, Colors.Yellow, M.Metal, { { from = -14, to = 14, bottom = 1.2, top = 3, glass = true } })
	pier:Pillar("PataAscensor1", -9, -34, -12, 2, 1.6, STEEL, M.Metal)
	pier:Pillar("PataAscensor2", 9, -34, -12, 2, 1.6, STEEL, M.Metal)
	-- bote amarrado
	pier:Box("Bote", V(8, 2.4, 18), V(24, 1.2, -10), Colors.Red, M.SmoothPlastic)
	pier:Box("CabinaBote", V(5, 3, 6), V(24, 3.9, -12), Colors.White, M.SmoothPlastic)
	pier:Slab("PasarelaBote", 15, 20, -12, -8, 3, 1, Colors.Wood, M.Wood)

	-- plataformas del ascensor: nivel 44 (modulo) y 58 (helipuerto)
	local up = rig:Group("NivelesSuperiores")
	up:Slab("Rellano44", -9, 9, -28, -12, 44, 1.5, STEEL, M.DiamondPlate)
	for _, p in ipairs({ { -8, -13 }, { 8, -13 } }) do
		up:Pillar("Soporte", p[1], p[2], DECK, 44, 1.6, STEEL, M.Metal)
	end
	up:Wall("BarandillaRellano", "x", -12, -9, 9, 44, 47.5, 0.3, Colors.Yellow, M.Metal, { { from = -8, to = 8, bottom = 1.2, top = 3.5, glass = true } })
	up:Slab("Helipuerto", -26, 26, -28, 18, 58, 1.5, C(70, 72, 78), M.Concrete)
	for _, p in ipairs({ { -24, 16 }, { 24, 16 }, { -24, -20 }, { 24, -20 } }) do
		up:Pillar("SoporteHeli", p[1], p[2], DECK, 58, 2, STEEL, M.Metal)
	end
	up:Pillar("CirculoHeli", 0, -5, 58, 58.2, 30, Colors.Yellow, M.SmoothPlastic)
	up:Pillar("CirculoHeli2", 0, -5, 58.2, 58.4, 26, C(70, 72, 78), M.Concrete)
	up:Board("H", "H", V(14, 0.2, 14), V(0, 58.6, -5), C(70, 72, 78), C(255, 255, 255), Enum.NormalId.Top)
	for _, p in ipairs({ { -25, -27 }, { 25, -27 }, { -25, 17 }, { 25, 17 } }) do
		up:Ball("LuzHeli", 1.6, V(p[1], 59.6, p[2]), Colors.Green, M.Neon)
	end
	-- helicoptero decorativo
	local heli = up:At(V(0, 59, -5), "Helicoptero")
	heli:Box("Fuselaje", V(4, 3.4, 9), V(0, 2.2, 0), Colors.Red, M.SmoothPlastic)
	heli:Box("Cristal", V(3.4, 2, 3), V(0, 2.6, 4.2), Colors.Glass, M.Glass, { transparency = 0.4 })
	heli:Box("Cola", V(1, 1, 7), V(0, 2.6, -7.5), Colors.Red, M.SmoothPlastic)
	heli:Box("Rotor", V(18, 0.2, 1), V(0, 4.3, 0), Colors.DarkMetal, M.Metal, { canCollide = false })
	heli:Box("PatinIzq", V(0.4, 0.4, 8), V(-1.8, 0.4, 0), Colors.DarkMetal, M.Metal)
	heli:Box("PatinDer", V(0.4, 0.4, 8), V(1.8, 0.4, 0), Colors.DarkMetal, M.Metal)

	-- torre de perforacion (se sube por una escalera de mano hasta una plataforma a 70)
	local derrick = rig:Group("TorrePerforacion")
	local dx, dz = 22, 22
	for _, p in ipairs({ { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } }) do
		derrick:Box("Montante", V(1.4, 56, 1.4), V(dx + p[1] * 0.5, DECK + 28, dz + p[2] * 0.5), Colors.Yellow, M.Metal, { rot = V(-p[2] * 0.4, 0, p[1] * 0.4) })
	end
	for y = DECK + 8, DECK + 48, 10 do
		local s = 12 - (y - DECK) * 0.17
		derrick:Box("TravesanoX", V(s, 0.8, 0.8), V(dx, y, dz - s / 2), Colors.Yellow, M.Metal)
		derrick:Box("TravesanoX", V(s, 0.8, 0.8), V(dx, y, dz + s / 2), Colors.Yellow, M.Metal)
		derrick:Box("TravesanoZ", V(0.8, 0.8, s), V(dx - s / 2, y, dz), Colors.Yellow, M.Metal)
		derrick:Box("TravesanoZ", V(0.8, 0.8, s), V(dx + s / 2, y, dz), Colors.Yellow, M.Metal)
	end
	derrick:Slab("PlataformaTorre", dx - 6, dx + 6, dz - 6, dz + 6, DECK + 40, 1, STEEL, M.DiamondPlate)
	derrick:Wall("BarandillaTorreN", "x", dz - 6, dx - 6, dx + 6, DECK + 40, DECK + 43.5, 0.3, Colors.Yellow, M.Metal, { { from = dx - 5.5, to = dx + 5.5, bottom = 1.2, top = 3.5, glass = true } })
	derrick:Ladder("EscalerillaTorre", dx, dz - 6.4, DECK, DECK + 41.5)
	derrick:Pillar("Tuberia", dx, dz, DECK, DECK + 40, 2, Colors.DarkMetal, M.Metal)
	derrick:Ball("LuzTorre", 2, V(dx, DECK + 58, dz), Colors.Red, M.Neon)

	-- modulo de alojamiento (planta baja de cubierta)
	local hab = rig:Group("Alojamiento")
	local mx1, mx2, mz1, mz2 = -42, -14, 8, 40
	hab:Wall("ModuloN", "x", mz1, mx1, mx2, DECK, DECK + 12, 0.8, C(230, 230, 235), M.Metal)
	hab:Wall("ModuloS", "x", mz2, mx1, mx2, DECK, DECK + 12, 0.8, C(230, 230, 235), M.Metal, Util.Windows(mx1 + 1, mx2 - 1, 7, 4, 4, 9))
	hab:Wall("ModuloO", "z", mx1, mz1, mz2, DECK, DECK + 12, 0.8, C(230, 230, 235), M.Metal, Util.Windows(mz1 + 1, mz2 - 1, 8, 4, 4, 9))
	hab:Wall("ModuloE", "z", mx2, mz1, mz2, DECK, DECK + 12, 0.8, C(230, 230, 235), M.Metal, { { from = 18, to = 24, bottom = 0, top = 8 } })
	hab:Slab("TechoModulo", mx1 - 1, mx2 + 1, mz1 - 1, mz2 + 1, DECK + 13, 1, STEEL, M.Metal)
	hab:Board("CartelModulo", "ALOJAMIENTO", V(16, 2.6, 0.4), V(-28, DECK + 10.5, mz2 + 0.6), Colors.Red, C(255, 255, 255))
	for i = 0, 2 do
		hab:Box("Litera", V(3, 1.4, 7), V(mx1 + 3 + i * 7, DECK + 2.7, mz1 + 5), Colors.Blue, M.Fabric)
		hab:Box("Litera", V(3, 1.4, 7), V(mx1 + 3 + i * 7, DECK + 2.7, mz2 - 5), Colors.Blue, M.Fabric)
	end

	-- depositos, contenedores, grua, antorcha
	local deco = rig:Group("Equipamiento")
	for i, p in ipairs({ { 30, -30 }, { 30, -8 } }) do
		deco:Pillar("Deposito", p[1], p[2], DECK, DECK + 14, 14, C(210, 210, 215), M.Metal)
		deco:Pillar("TapaDeposito", p[1], p[2], DECK + 14, DECK + 15, 15, Colors.Red, M.Metal)
	end
	local cols = { Colors.Red, Colors.Blue, Colors.Orange, Colors.Green, Colors.Yellow }
	for i = 0, 7 do
		local x = -34 + (i % 4) * 7.5
		local z = -6 + math.floor(i / 4) * 14
		deco:Box("Contenedor", V(7, 6, 12), V(x, DECK + 3, z), cols[i % #cols + 1], M.CorrodedMetal)
		if i % 3 == 0 then
			deco:Box("ContenedorApilado", V(7, 6, 12), V(x, DECK + 9, z), cols[(i + 2) % #cols + 1], M.CorrodedMetal)
		end
	end
	-- grua
	deco:Pillar("MastilGrua", 38, 2, DECK, DECK + 22, 3, Colors.Yellow, M.Metal)
	deco:Box("Pluma", V(36, 2, 2), V(24, DECK + 22.5, 2), Colors.Yellow, M.Metal)
	deco:Box("CableGrua", V(0.2, 12, 0.2), V(8, DECK + 16, 2), Colors.DarkMetal, M.Metal, { canCollide = false })
	-- antorcha
	deco:Pillar("TorreAntorcha", -40, -40, DECK, DECK + 46, 2, STEEL, M.Metal)
	deco:Ball("Llama", 5, V(-40, DECK + 49, -40), Colors.Orange, M.Neon)
	-- botes salvavidas
	for _, x in ipairs({ -20, 20 }) do
		deco:Box("Salvavidas", V(6, 3, 12), V(x, DECK + 2.5, 41), Colors.Orange, M.SmoothPlastic)
	end
	-- luces
	for _, p in ipairs({ { -44, -44 }, { 44, -44 }, { -44, 44 }, { 44, 44 } }) do
		deco:Pillar("PosteLuz", p[1], p[2], DECK, DECK + 9, 0.8, STEEL, M.Metal)
		local lamp = deco:Box("Foco", V(2, 1, 2), V(p[1], DECK + 9.5, p[2]), C(255, 245, 200), M.Neon, { canCollide = false })
		Util.AddLight(lamp, 40, 1.4)
	end

	-- puntos de aparicion en cubierta
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-4 + ix * 6, DECK + 1, -24 + iz * 8))
		end
	end
end

return OilRig
]])

	add("ServerStorage", { "IslasMapas", "Builders" }, "SkiResort", "ModuleScript", [[
-- Estacion de esqui: montana nevada por terrazas, pistas, refugio de madera de 2 plantas en la base,
-- torre del funicular con ascensor hasta la cima, cabanas, telesilla decorativo y muchos abetos.
local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Buildings = require(Lib.Buildings)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local SkiResort = {
	Title = "Estacion de esqui",
	Description = "Montana nevada con refugio, cabanas y una torre-ascensor que sube hasta la cima.",
	Lighting = { ClockTime = 11, Brightness = 2.4, OutdoorAmbient = C(170, 180, 200) },
	Bounds = { x1 = -150, x2 = 150, z1 = -150, z2 = 150, top = 120, floor = 0 },
	Disasters = { "Blizzard", "Earthquake", "Lightning", "Meteors", "Tornado", "Fire", "Volcano", "UFO", "AcidRain", "Virus" },
}

local SNOW = C(245, 248, 255)
local ICE = C(190, 220, 245)

function SkiResort.Build(b)
	b:Box("Isla", V(330, 10, 330), V(0, -5.5, 0), SNOW, M.Snow, { indestructible = true })
	b:Sea(-6, 2048, C(40, 80, 120))

	-- montana por terrazas (lado norte)
	local mountain = b:Group("Montana")
	local terraces = { { 200, 16, -60 }, { 160, 14, -75 }, { 120, 14, -88 }, { 80, 14, -100 }, { 46, 12, -110 } }
	local y = 0
	for i, t in ipairs(terraces) do
		local w, h, cz = t[1], t[2], t[3]
		mountain:Box("Terraza", V(w, h, w * 0.6), V(0, y + h / 2, cz), SNOW, M.Snow, { indestructible = true })
		-- rampa de pista para subir andando
		mountain:Wedge("Pista", V(14, h, 24), V(-w / 2 + 14 + i * 4, y + h / 2, cz + w * 0.3 + 12), ICE, M.Ice, 180, { indestructible = true })
		y = y + h
	end
	local summit = y
	mountain:Box("Cima", V(30, 1, 20), V(0, summit + 0.5, -110), C(120, 110, 100), M.Rock, { indestructible = true })
	mountain:Board("CartelCima", "CIMA · 3.000 m", V(14, 3, 0.4), V(0, summit + 5, -100.4), C(40, 60, 100), Colors.White)

	-- torre del funicular: ascensor desde la base hasta la cima
	local liftTower = b:Group("Funicular")
	local lift = { name = "AscensorCima", x = 110, z = -40, floors = { 0, 30, summit }, labels = { "Base", "Medio", "Cima" }, wallColor = C(200, 60, 50), wallMaterial = M.Metal }
	Elevator.build(liftTower, lift)
	liftTower:Slab("PlataformaMedio", 103, 117, -33.9, -26, 30, 1.2, Colors.DarkMetal, M.DiamondPlate)
	liftTower:Wall("Barandilla", "x", -26, 103, 117, 30, 33.5, 0.3, Colors.Glass, M.Glass, {})
	-- pasarela desde lo alto de la torre hasta la cima
	liftTower:Slab("Pasarela", 103, 117, -33.9, -22, summit, 1.2, Colors.DarkMetal, M.DiamondPlate)
	liftTower:Box("PuenteCima", V(100, 1.2, 6), V(60, summit - 0.6, -25), Colors.DarkMetal, M.DiamondPlate)
	liftTower:Box("PuenteCima2", V(6, 1.2, 72), V(10, summit - 0.6, -61), Colors.DarkMetal, M.DiamondPlate)
	liftTower:Board("CartelFunicular", "FUNICULAR", V(12, 3, 0.4), V(110, 12, -33.6), C(200, 60, 50), Colors.White)

	-- refugio de madera (2 plantas) en la base
	Buildings.House(b, -40, 40, 34, 26, 2, { name = "Refugio", color = C(150, 100, 60), material = M.WoodPlanks, roofColor = SNOW })
	b:Board("CartelRefugio", "REFUGIO", V(14, 3, 0.4), V(-40, 9, 53.6), C(80, 50, 30), C(255, 230, 180))
	local fire = b:Box("Hoguera", V(4, 1, 4), V(-40, 1, 65), C(90, 60, 40), M.Wood)
	local f = Instance.new("Fire")
	f.Size = 6
	f.Parent = fire
	Util.AddLight(fire, 20, 2, C(255, 170, 80))

	-- cabanas
	for i, p in ipairs({ { 30, 60 }, { 60, 70 }, { 100, 40 }, { -100, 60 } }) do
		Buildings.House(b, p[1], p[2], 16, 14, 1, { name = "Cabana" .. i, color = C(130, 85, 50), material = M.WoodPlanks, roofColor = SNOW })
	end

	-- telesilla decorativo con postes
	for i = 0, 4 do
		local z = 30 - i * 30
		local py = math.max(0, -z * 0.6)
		b:Pillar("PosteTelesilla", -90, z, 0, 25 + py, 1.2, Colors.DarkMetal, M.Metal)
		b:Box("Silla", V(4, 0.6, 2), V(-90, 20 + py, z), Colors.Red, M.Metal)
	end
	b:Box("Cable", V(0.3, 0.3, 130), V(-90, 26 + 30, -35), Colors.DarkMetal, M.Metal, { rot = V(-15, 0, 0), canCollide = false })

	-- bosque de abetos
	local forest = b:Group("Bosque")
	for i = 0, 34 do
		local a = i * 2.39996
		local r = 70 + (i % 7) * 10
		local x, z = math.cos(a) * r, math.sin(a) * r * 0.9 + 30
		if z > -20 then
			forest:Pine(x, z, 0, 1.3 + (i % 3) * 0.3)
		end
	end
	-- muneco de nieve
	b:Ball("MunecoBase", 5, V(10, 2.5, 30), SNOW, M.Snow)
	b:Ball("MunecoCuerpo", 3.6, V(10, 6.3, 30), SNOW, M.Snow)
	b:Ball("MunecoCabeza", 2.6, V(10, 9, 30), SNOW, M.Snow)

	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-10 + ix * 12, 1, 70 + iz * 12))
		end
	end
end

return SkiResort
]])

	add("ServerStorage", { "IslasMapas", "Builders" }, "Skyscraper", "ModuleScript", [[
-- Rascacielos "Torre Cumbre": 12 plantas + azotea con helipuerto y piscina.
-- 3 ascensores en el nucleo central (13 paradas), escalera de emergencia en zigzag y vestibulo.

local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors
local windows = Util.Windows

local Skyscraper = {
	Title = "Rascacielos",
	Description = "Torre de 12 plantas con 3 ascensores, escalera de emergencia, helipuerto y piscina en la azotea.",
	Lighting = { ClockTime = 17.5, Brightness = 2, OutdoorAmbient = C(120, 110, 130) },
	Bounds = { x1 = -60, x2 = 60, z1 = -60, z2 = 100, top = 190, floor = 0 },
	Disasters = { "Earthquake", "Fire", "Lightning", "AcidRain", "Tornado", "Lava", "UFO", "Meteors", "Blizzard" },
	DisasterConfig = { Lava = { maxHeight = 112 } },
}

local STORY = 14
local LEVELS = 13 -- 12 plantas + azotea

function Skyscraper.Build(b)
	b:Box("Isla", V(300, 10, 300), V(0, -5.5, 0), Colors.Grass, M.Grass)
	b:Sea(-6)

	local tower = b:Group("Torre")
	local x1, x2, z1, z2 = -30, 30, -30, 30
	local lvl, labels = {}, {}
	for i = 1, LEVELS do
		lvl[i] = (i - 1) * STORY
		labels[i] = (i == 1 and "PB") or (i == LEVELS and "R") or tostring(i - 1)
	end

	local elevs = {}
	for _, x in ipairs({ -15, 0, 15 }) do
		elevs[#elevs + 1] = { name = "Ascensor" .. (#elevs + 1), x = x, z = -24, floors = lvl, labels = labels, wallColor = C(70, 74, 88) }
	end
	local elevHoles = {}
	for _, e in ipairs(elevs) do
		elevHoles[#elevHoles + 1] = Elevator.hole(e)
	end

	-- Escalera de emergencia en zigzag (vuelo i sube del nivel i al i+1)
	local function stairHole(i)
		if i % 2 == 1 then
			return { 8, 26, 12, 20 }
		end
		return { 8, 26, 20, 28 }
	end

	-- Forjados
	for i = 1, LEVELS do
		local holes = {}
		for _, h in ipairs(elevHoles) do
			holes[#holes + 1] = h
		end
		if i > 1 then
			holes[#holes + 1] = stairHole(i - 1)
		end
		local th = (i == 1) and 0.5 or 1.5
		tower:Slab("Planta" .. (i - 1), x1, x2, z1, z2, lvl[i], th, i == 1 and C(235, 230, 220) or C(225, 222, 215), M.Marble, holes)
	end

	-- Muros con cristaleras por planta
	for i = 1, LEVELS - 1 do
		local y, top = lvl[i], lvl[i] + STORY
		local front = windows(x1 + 2, x2 - 2, 12, 10, 2, 12)
		if i == 1 then
			front = windows(x1 + 2, x2 - 2, 12, 10, 3, 12, -8, 8)
			front[#front + 1] = { from = -8, to = 8, bottom = 0, top = 11 }
		end
		tower:Wall("FachadaSur" .. i, "x", z2, x1, x2, y, top, 1, C(60, 64, 78), M.Concrete, front)
		tower:Wall("FachadaNorte" .. i, "x", z1, x1, x2, y, top, 1, C(60, 64, 78), M.Concrete)
		tower:Wall("FachadaOeste" .. i, "z", x1, z1, z2, y, top, 1, C(60, 64, 78), M.Concrete, windows(z1 + 2, z2 - 2, 12, 10, 2, 12))
		tower:Wall("FachadaEste" .. i, "z", x2, z1, z2, y, top, 1, C(60, 64, 78), M.Concrete, windows(z1 + 2, z2 - 2, 12, 10, 2, 12))
	end
	-- pilares de esquina
	for _, p in ipairs({ { x1, z1 }, { x1, z2 }, { x2, z1 }, { x2, z2 } }) do
		tower:Chunked("PilarEsquina", V(2.4, STORY * (LEVELS - 1), 2.4), V(p[1], STORY * (LEVELS - 1) / 2, p[2]), Colors.DarkMetal, M.Metal)
	end

	for _, e in ipairs(elevs) do
		Elevator.build(tower, e)
	end

	-- Escaleras de emergencia
	for i = 1, LEVELS - 1 do
		if i % 2 == 1 then
			tower:Stairs("Escalera" .. i, 8, 16, lvl[i], lvl[i + 1], 8, 18, "+x", C(190, 190, 195), M.Concrete)
		else
			tower:Stairs("Escalera" .. i, 26, 24, lvl[i], lvl[i + 1], 8, 18, "-x", C(190, 190, 195), M.Concrete)
		end
	end

	-- Mobiliario por planta
	local rooms = tower:Group("Plantas")
	for i = 2, LEVELS - 1 do
		local y = lvl[i]
		local g = rooms:Group("Planta" .. (i - 1))
		-- dos "habitaciones": cama + mesita + sofa
		for k, x in ipairs({ -22, -6 }) do
			g:Box("Cama", V(6, 1.6, 8), V(x, y + 0.8, 8 + (k - 1) * 4), C(240, 240, 250), M.Fabric)
			g:Box("Almohada", V(4.5, 0.6, 1.6), V(x, y + 1.9, 8 + (k - 1) * 4 - 3), C(250, 250, 255), M.Fabric)
			g:Box("Mesita", V(2, 2, 2), V(x + 5, y + 1, 4 + (k - 1) * 4), Colors.Wood, M.Wood)
		end
		g:Box("Sofa", V(8, 1.6, 3), V(-14, y + 0.8, 24), Colors.Red, M.Fabric)
		g:Box("RespaldoSofa", V(8, 2.4, 0.8), V(-14, y + 1.8, 25.4), Colors.Red, M.Fabric)
		g:Pillar("Maceta", -26, 26, y, y + 2, 2.8, Colors.Wood, M.Wood)
		g:Ball("Planta", 4, V(-26, y + 4.4, 26), Colors.Green, M.Grass)
		g:Board("Numero", "PLANTA " .. (i - 1), V(14, 3, 0.4), V(0, y + 9, 29.3), Colors.DarkMetal, C(255, 220, 90), Enum.NormalId.Front)
	end
	-- la planta 12 es el Sky Lounge
	local lounge = rooms:Group("SkyLounge")
	local ly = lvl[LEVELS - 1]
	lounge:Box("Barra", V(24, 4, 3), V(-12, ly + 2, 10), Colors.Wood, M.Wood)
	lounge:Board("CartelBar", "SKY BAR", V(10, 2.4, 0.4), V(-12, ly + 6.5, 11.7), Colors.DarkMetal, C(255, 190, 60))
	for k = 0, 3 do
		lounge:Pillar("Mesa", -20 + k * 8, 22, ly, ly + 3.5, 0.8, Colors.DarkMetal, M.Metal)
		lounge:Pillar("MesaTop", -20 + k * 8, 22, ly + 3.5, ly + 4, 5, C(250, 250, 250), M.Marble)
	end

	-- Vestibulo (planta baja)
	local lobby = tower:Group("Vestibulo")
	lobby:Box("Recepcion", V(16, 4, 3), V(18, 2, 4), Colors.Wood, M.Wood)
	lobby:Board("CartelRecepcion", "RECEPCION", V(14, 2.4, 0.4), V(18, 6.3, 5.8), Colors.DarkMetal, C(255, 255, 255))
	lobby:Board("CartelTorre", "TORRE CUMBRE", V(40, 5, 0.6), V(0, 20, z2 + 0.8), Colors.DarkMetal, C(255, 220, 90))
	for _, p in ipairs({ { -26, 20 }, { 26, -6 } }) do
		lobby:Pillar("Maceta", p[1], p[2], 0, 2, 3, Colors.Wood, M.Wood)
		lobby:Ball("Planta", 5, V(p[1], 4.6, p[2]), Colors.Green, M.Grass)
	end

	-- Azotea
	local roof = b:Group("Azotea")
	local ry = lvl[LEVELS]
	for _, w in ipairs({
		{ "x", z2, x1, x2 }, { "x", z1, x1, x2 }, { "z", x1, z1, z2 }, { "z", x2, z1, z2 },
	}) do
		roof:Wall("Barandilla", w[1], w[2], w[3], w[4], ry, ry + 4, 0.4, Colors.Glass, M.Glass, {})
	end
	-- helipuerto
	roof:Pillar("Helipuerto", -14, 12, ry, ry + 0.8, 22, C(70, 70, 75), M.Concrete)
	roof:Pillar("AroHelipuerto", -14, 12, ry + 0.8, ry + 0.9, 18, Colors.Yellow, M.SmoothPlastic)
	roof:Pillar("CentroHelipuerto", -14, 12, ry + 0.9, ry + 1.0, 15, C(70, 70, 75), M.Concrete)
	roof:Board("H", "H", V(8, 0.2, 8), V(-14, ry + 1.1, 12), C(70, 70, 75), C(255, 255, 255), Enum.NormalId.Top)
	-- piscina
	roof:Box("BordePiscina", V(22, 1.6, 14), V(14, ry + 0.8, -6), Colors.Concrete, M.Concrete)
	roof:Box("Agua", V(20, 0.2, 12), V(14, ry + 1.7, -6), Colors.Water, M.SmoothPlastic, { transparency = 0.35, canCollide = false })
	for k = 0, 2 do
		roof:Box("Tumbona", V(2.4, 1, 6), V(-24 + k * 5, ry + 0.5, -2), Colors.White, M.Fabric)
	end
	-- antena y luz
	roof:Pillar("Antena", 24, -24, ry, ry + 26, 1.2, Colors.Red, M.Metal)
	roof:Ball("LuzAntena", 2.4, V(24, ry + 27, -24), Colors.Red, M.Neon)

	-- Plaza y entorno
	local plaza = b:Group("Plaza")
	plaza:Box("Plaza", V(120, 0.5, 70), V(0, -0.25, 62), C(200, 198, 192), M.Concrete)
	plaza:Pillar("Fuente", 0, 55, 0, 1.2, 14, Colors.Concrete, M.Marble)
	plaza:Pillar("AguaFuente", 0, 55, 1.2, 1.5, 11, Colors.Water, M.SmoothPlastic)
	for i = 0, 6 do
		plaza:Pine(-100 + i * 33, 120, 0, 1.3)
		plaza:Pine(-100 + i * 33, -120, 0, 1.3)
	end
	for _, x in ipairs({ -60, -40, 40, 60 }) do
		plaza:Box("Banco", V(7, 1.2, 2), V(x, 0.6, 70), Colors.Wood, M.Wood)
	end

	-- aparicion en la plaza
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-40 + ix * 26, 1, 40 + iz * 16))
		end
	end
end

return Skyscraper
]])

	add("ServerStorage", { "IslasMapas", "Builders" }, "SpaceStation", "ModuleScript", [[
-- Estacion espacial: nucleo de 4 plantas con 2 ascensores, cuatro brazos con modulos (laboratorio, invernadero,
-- reactor, hangar con lanzadera), paneles solares y planeta al fondo. Gravedad reducida.
-- Si te sales de la estacion, caes al vacio y mueres.

local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors
local windows = Util.Windows

local SpaceStation = {
	Title = "Estacion Espacial",
	Description = "Nucleo de 4 plantas con ascensores, brazos con laboratorio, invernadero y hangar. Gravedad baja.",
	Lighting = { ClockTime = 0, Brightness = 1, Ambient = C(60, 65, 90), OutdoorAmbient = C(40, 45, 70) },
	Bounds = { x1 = -130, x2 = 130, z1 = -130, z2 = 130, top = 110, floor = 0 },
	Disasters = { "Meteors", "Fire", "Earthquake", "Radiation", "BlackHole", "UFO", "Virus" },
	Gravity = 70,
}

local HULL = C(215, 220, 228)
local DARK = C(55, 58, 70)
local STORY = 20

-- pasillo (brazo) a lo largo de un eje, a nivel de la planta 1
local function corridor(g, axis, sign, from, to)
	-- axis "x": sale hacia +-X. from/to son distancias (>0) desde el centro
	local len = to - from
	local mid = sign * (from + to) / 2
	local w = 12
	local function pos(a, b, y) -- a = coordenada a lo largo del brazo, b = lateral
		if axis == "x" then return V(a, y, b) end
		return V(b, y, a)
	end
	local function size(along, lateral, h)
		if axis == "x" then return V(along, h, lateral) end
		return V(lateral, h, along)
	end
	g:Box("SueloBrazo", size(len, w, 1), pos(mid, 0, -0.5), DARK, M.DiamondPlate)
	g:Box("TechoBrazo", size(len, w + 2, 1), pos(mid, 0, 12.5), HULL, M.Metal)
	for _, side in ipairs({ -1, 1 }) do
		-- paredes laterales con ventanas
		local a1, a2 = sign * from, sign * to
		if a1 > a2 then a1, a2 = a2, a1 end
		g:Wall("ParedBrazo", axis, side * (w / 2), a1, a2, 0, 12, 0.8, HULL, M.Metal, windows(a1 + 1, a2 - 1, 9, 5, 3, 9))
	end
	for k = 1, math.floor(len / 14) do
		local a = sign * (from + k * 14 - 7)
		g:Box("Luz", size(2, 8, 0.2), pos(a, 0, 11.8), C(255, 250, 230), M.Neon, { canCollide = false })
	end
end

function SpaceStation.Build(b)
	b:KillPlane(-250)

	-- planeta y estrellas decorativas
	local sky = b:Group("Cielo")
	sky:Ball("Planeta", 900, V(900, -450, 700), C(40, 110, 190), M.SmoothPlastic).CanCollide = false
	sky:Ball("Atmosfera", 940, V(900, -450, 700), C(120, 180, 255), M.Neon).CanCollide = false
	sky:Ball("Luna", 120, V(-700, 260, -900), C(200, 200, 205), M.Slate).CanCollide = false

	local hub = b:Group("Nucleo")
	local x1, x2, z1, z2 = -30, 30, -30, 30
	local lvl = { 0, STORY, STORY * 2, STORY * 3 }

	local elevs = {}
	for _, x in ipairs({ -18, 18 }) do
		elevs[#elevs + 1] = { name = "Ascensor" .. (#elevs + 1), x = x, z = -22, floors = lvl, labels = { "1", "2", "3", "4" }, wallColor = DARK }
	end
	local holes = {}
	for _, e in ipairs(elevs) do
		holes[#holes + 1] = Elevator.hole(e)
	end
	-- escalera de la planta 1 a la 2 (y de la 2 a la 3, de la 3 a la 4) en la esquina este
	local stairHoles = { { 8, 26, 8, 16 }, { 8, 26, 16, 24 }, { 8, 26, 8, 16 } }

	hub:Slab("Planta1", x1, x2, z1, z2, 0, 1, DARK, M.DiamondPlate, holes)
	for i = 2, 4 do
		local hs = { holes[1], holes[2], stairHoles[i - 1] }
		hub:Slab("Planta" .. i, x1, x2, z1, z2, lvl[i], 1.5, i == 4 and C(40, 44, 60) or DARK, M.DiamondPlate, hs)
	end
	hub:Slab("Techo", x1 - 2, x2 + 2, z1 - 2, z2 + 2, STORY * 4 + 2, 2, HULL, M.Metal)

	-- muros del nucleo: ventanas grandes (vista al espacio); abiertos en los 4 brazos de la planta 1
	for i = 1, 4 do
		local y, top = lvl[i], lvl[i] + STORY
		local gap = (i == 1) and { { from = -6, to = 6, bottom = 0, top = 12 } } or {}
		local function band(a1, a2)
			local list = windows(a1 + 2, a2 - 2, 14, 11, 3, 16)
			for _, g in ipairs(gap) do
				-- quitar ventanas que choquen con el hueco del brazo
				for k = #list, 1, -1 do
					if list[k].to > g.from and list[k].from < g.to then
						table.remove(list, k)
					end
				end
				list[#list + 1] = g
			end
			return list
		end
		hub:Wall("MuroSur" .. i, "x", z2, x1, x2, y, top, 1, HULL, M.Metal, band(x1, x2))
		hub:Wall("MuroNorte" .. i, "x", z1, x1, x2, y, top, 1, HULL, M.Metal, i == 1 and { { from = -6, to = 6, bottom = 0, top = 12 } } or {})
		hub:Wall("MuroOeste" .. i, "z", x1, z1, z2, y, top, 1, HULL, M.Metal, band(z1, z2))
		hub:Wall("MuroEste" .. i, "z", x2, z1, z2, y, top, 1, HULL, M.Metal, band(z1, z2))
	end

	for _, e in ipairs(elevs) do
		Elevator.build(hub, e)
	end
	for i = 1, 3 do
		if i % 2 == 1 then
			hub:Stairs("Escalera" .. i, 8, 12, lvl[i], lvl[i + 1], 8, 18, "+x", C(190, 195, 205), M.Metal)
		else
			hub:Stairs("Escalera" .. i, 26, 20, lvl[i], lvl[i + 1], 8, 18, "-x", C(190, 195, 205), M.Metal)
		end
	end

	-- decoracion de cada planta del nucleo
	local decks = hub:Group("Plantas")
	-- 2: dormitorios
	for k = 0, 3 do
		decks:Box("Litera", V(4, 2, 9), V(-24 + k * 8, lvl[2] + 1.5, 22), C(70, 110, 190), M.Fabric)
		decks:Box("Taquilla", V(3, 8, 3), V(-24 + k * 8, lvl[2] + 4, 28), Colors.Metal, M.Metal)
	end
	decks:Board("Cartel2", "DORMITORIOS", V(16, 3, 0.4), V(-12, lvl[2] + 14, 29.3), DARK, C(120, 200, 255), Enum.NormalId.Front)
	-- 3: laboratorio
	for k = 0, 3 do
		decks:Box("Consola", V(6, 3, 2.5), V(-24 + k * 8, lvl[3] + 1.5, 26), DARK, M.Metal)
		decks:Box("Pantalla", V(5, 2.4, 0.2), V(-24 + k * 8, lvl[3] + 4.4, 24.9), C(70, 230, 160), M.Neon, { canCollide = false })
	end
	decks:Board("Cartel3", "LABORATORIO", V(16, 3, 0.4), V(-12, lvl[3] + 14, 29.3), DARK, C(120, 200, 255), Enum.NormalId.Front)
	-- 4: observatorio con telescopio
	decks:Pillar("PedestalTelescopio", -14, 14, lvl[4], lvl[4] + 4, 5, DARK, M.Metal)
	decks:Box("Telescopio", V(14, 3, 3), V(-14, lvl[4] + 6, 14), Colors.White, M.Metal, { shape = Enum.PartType.Cylinder, rot = V(0, 35, 28) })
	decks:Board("Cartel4", "OBSERVATORIO", V(16, 3, 0.4), V(-12, lvl[4] + 14, 29.3), DARK, C(120, 200, 255), Enum.NormalId.Front)

	-- brazos con modulos
	local arms = b:Group("Brazos")
	corridor(arms:Group("BrazoEste"), "x", 1, 30, 80)
	corridor(arms:Group("BrazoOeste"), "x", -1, 30, 80)
	corridor(arms:Group("BrazoSur"), "z", 1, 30, 80)
	corridor(arms:Group("BrazoNorte"), "z", -1, 30, 80)

	-- Modulo cuadrado de 40x40; `facing` es el lado que mira al nucleo (ahi se abre la puerta del pasillo).
	local function moduleOpen(name, cx, cz, color, facing)
		local g = arms:Group(name)
		local s = 40
		g:Slab("Suelo", cx - s / 2, cx + s / 2, cz - s / 2, cz + s / 2, 0, 1, DARK, M.DiamondPlate)
		g:Slab("Techo", cx - s / 2 - 1, cx + s / 2 + 1, cz - s / 2 - 1, cz + s / 2 + 1, 18, 1, HULL, M.Metal)
		local door = { from = -6, to = 6, bottom = 0, top = 12 }
		local function openings(a1, a2, center, isDoor)
			local list = windows(a1 + 1, a2 - 1, 10, 6, 4, 14, center - 7, center + 7)
			if isDoor then
				list[#list + 1] = { from = center - 6, to = center + 6, bottom = 0, top = 12 }
			end
			return list
		end
		g:Wall("MuroN", "x", cz - s / 2, cx - s / 2, cx + s / 2, 0, 18, 0.8, color, M.Metal, openings(cx - s / 2, cx + s / 2, cx, facing == "S"))
		g:Wall("MuroS", "x", cz + s / 2, cx - s / 2, cx + s / 2, 0, 18, 0.8, color, M.Metal, openings(cx - s / 2, cx + s / 2, cx, facing == "N"))
		g:Wall("MuroO", "z", cx - s / 2, cz - s / 2, cz + s / 2, 0, 18, 0.8, color, M.Metal, openings(cz - s / 2, cz + s / 2, cz, facing == "E"))
		g:Wall("MuroE", "z", cx + s / 2, cz - s / 2, cz + s / 2, 0, 18, 0.8, color, M.Metal, openings(cz - s / 2, cz + s / 2, cz, facing == "W"))
		return g
	end

	-- facing = lado del modulo que mira al nucleo
	local lab = moduleOpen("Laboratorio", 100, 0, C(205, 225, 240), "W")
	for k = 0, 3 do
		lab:Box("MesaLab", V(14, 3, 3), V(92 + (k % 2) * 16, 1.5, -10 + math.floor(k / 2) * 18), Colors.White, M.Metal)
		lab:Box("Matraz", V(1.4, 2, 1.4), V(92 + (k % 2) * 16, 4, -10 + math.floor(k / 2) * 18), C(120, 255, 170), M.Neon, { canCollide = false })
	end
	lab:Board("CartelLab", "LABORATORIO", V(16, 3, 0.4), V(100, 14, 19.3), DARK, C(120, 200, 255), Enum.NormalId.Front)

	local gh = moduleOpen("Invernadero", -100, 0, C(190, 235, 200), "E")
	for k = 0, 5 do
		local x, z = -112 + (k % 3) * 12, -10 + math.floor(k / 3) * 18
		gh:Box("Bancal", V(8, 1.4, 8), V(x, 0.7, z), C(90, 60, 40), M.Ground)
		gh:Ball("Arbusto", 6, V(x, 4.6, z), Colors.Green, M.Grass)
	end
	gh:Board("CartelInv", "INVERNADERO", V(16, 3, 0.4), V(-100, 14, 19.3), DARK, C(140, 255, 160), Enum.NormalId.Front)

	local rx = moduleOpen("Reactor", 0, 100, C(235, 200, 190), "N")
	rx:Pillar("Nucleo", 0, 100, 0, 15, 8, C(40, 40, 50), M.Metal)
	rx:Pillar("NucleoLuz", 0, 100, 1, 14, 5, C(255, 140, 60), M.Neon)
	for k = 0, 3 do
		local a = k * math.pi / 2
		rx:Pillar("Soporte", math.cos(a) * 12, 100 + math.sin(a) * 12, 0, 15, 2, DARK, M.Metal)
	end
	rx:Board("CartelReactor", "REACTOR", V(16, 3, 0.4), V(0, 14, 119.3), DARK, C(255, 150, 80), Enum.NormalId.Front)

	local hangar = moduleOpen("Hangar", 0, -100, C(200, 205, 215), "S")
	-- lanzadera
	local sh = hangar:At(V(0, 0, -102), "Lanzadera")
	sh:Box("Fuselaje", V(8, 6, 22), V(0, 5, 0), Colors.White, M.Metal)
	sh:Box("Morro", V(7, 5, 6), V(0, 5, 13), Colors.White, M.Metal, { rot = V(18, 0, 0) })
	sh:Box("Cristal", V(5, 2, 3), V(0, 7, 12), Colors.Glass, M.Glass, { transparency = 0.4 })
	sh:Box("AlaIzq", V(10, 0.6, 10), V(-9, 3.5, -2), Colors.Blue, M.Metal)
	sh:Box("AlaDer", V(10, 0.6, 10), V(9, 3.5, -2), Colors.Blue, M.Metal)
	sh:Box("Motor", V(5, 4, 4), V(0, 5, -12), DARK, M.Metal, { shape = Enum.PartType.Cylinder, rot = V(0, 90, 0) })
	sh:Box("Pata1", V(1, 3, 1), V(-3, 1.5, 6), DARK, M.Metal)
	sh:Box("Pata2", V(1, 3, 1), V(3, 1.5, 6), DARK, M.Metal)
	sh:Box("Pata3", V(1, 3, 1), V(0, 1.5, -8), DARK, M.Metal)
	hangar:Board("CartelHangar", "HANGAR", V(16, 3, 0.4), V(0, 14, -80.7), DARK, C(255, 220, 90), Enum.NormalId.Back)

	-- paneles solares sobre los brazos de este y oeste
	local solar = b:Group("PanelesSolares")
	for _, sx in ipairs({ -1, 1 }) do
		solar:Box("MastilSolar", V(2, 2, 80), V(sx * 55, 20, 0), DARK, M.Metal)
		for k = 0, 2 do
			solar:Box("PanelSolar", V(18, 0.6, 30), V(sx * (40 + k * 20), 20, 36), C(35, 70, 150), M.Glass, { reflectance = 0.2 })
			solar:Box("PanelSolar", V(18, 0.6, 30), V(sx * (40 + k * 20), 20, -36), C(35, 70, 150), M.Glass, { reflectance = 0.2 })
		end
		solar:Box("PuntalSolar", V(2, 7, 2), V(sx * 55, 16.5, 0), DARK, M.Metal)
	end
	-- antena parabolica sobre el nucleo
	local dish = b:Group("Antena")
	dish:Pillar("Soporte", 20, 20, STORY * 4 + 2, STORY * 4 + 14, 2, DARK, M.Metal)
	dish:Box("Plato", V(2, 14, 14), V(20, STORY * 4 + 17, 20), Colors.White, M.Metal, { shape = Enum.PartType.Cylinder, rot = V(0, 0, 40) })
	dish:Ball("LuzAntena", 2, V(20, STORY * 4 + 24, 20), Colors.Red, M.Neon)

	-- puntos de aparicion: planta 1 del nucleo
	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(-12 + ix * 8, 1, -2 + iz * 8))
		end
	end
end

return SpaceStation
]])

	add("ServerStorage", { "IslasMapas", "Builders" }, "TropicalIsland", "ModuleScript", [[
-- Isla tropical: playa con palmeras, cabanas de madera, chiringuito, muelle con barca, barco pirata
-- encallado, montana con cascada y un faro con ascensor y luz giratoria.
local Lib = script.Parent.Parent.Lib
local Util = require(Lib.Util)
local Elevator = require(Lib.Elevator)
local Buildings = require(Lib.Buildings)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors

local TropicalIsland = {
	Title = "Isla tropical",
	Description = "Playa con cabanas, barco pirata encallado, montana con cascada y un faro con ascensor.",
	Lighting = { ClockTime = 14.5, Brightness = 2.5, OutdoorAmbient = C(160, 150, 130) },
	Bounds = { x1 = -150, x2 = 150, z1 = -150, z2 = 150, top = 110, floor = 0 },
	Disasters = { "Tsunami", "Volcano", "Flood", "Lightning", "Tornado", "Meteors", "Fire", "Sandstorm", "AcidRain", "UFO" },
	DisasterConfig = { Flood = { maxHeight = 22 } },
}

local SAND = C(235, 215, 160)
local STRAW = C(200, 170, 90)

function TropicalIsland.Build(b)
	b:Pillar("Isla", 0, 0, -10, 0, 320, SAND, M.Sand)
	b:Pillar("Hierba", 0, 0, -9.6, 0.3, 230, C(100, 170, 70), M.Grass)
	b:Sea(-4, 2048, C(30, 170, 190), 0.25)
	-- no se rompen
	for _, d in ipairs(b.parent:GetChildren()) do
		if d.Name == "Isla" or d.Name == "Hierba" then
			d:SetAttribute("Indestructible", true)
		end
	end

	-- montana central con cascada
	local mountain = b:Group("Montana")
	for i, d in ipairs({ 90, 70, 52, 36 }) do
		local y1 = (i - 1) * 10
		mountain:Pillar("Roca", -30, -20, y1, y1 + 10.3, d, i == 4 and C(90, 140, 70) or C(120, 110, 95), i == 4 and M.Grass or M.Rock)
	end
	mountain:Box("Cascada", V(6, 30, 1), V(-30, 15, 5.5), C(120, 200, 255), M.Neon, { transparency = 0.35, canCollide = false })
	mountain:Pillar("Laguna", -30, 18, 0.3, 0.6, 20, C(60, 160, 220), M.SmoothPlastic)
	-- escalera tallada para subir
	mountain:Stairs("Sendero", -2, -20, 0, 40, 6, 46, "-x", C(140, 120, 95), M.Rock)

	-- faro con ascensor y luz giratoria
	local light = b:Group("Faro")
	local fx, fz = 100, -90
	local lift = { name = "AscensorFaro", x = fx, z = fz, floors = { 0, 30, 60 }, labels = { "PB", "30", "Luz" }, wallColor = C(240, 240, 240), wallMaterial = M.SmoothPlastic }
	Elevator.build(light, lift)
	light:Box("FranjaRoja", V(13.4, 6, 12.4), V(fx, 24, fz), C(210, 50, 50), M.SmoothPlastic)
	light:Box("FranjaRoja", V(13.4, 6, 12.4), V(fx, 48, fz), C(210, 50, 50), M.SmoothPlastic)
	for _, y in ipairs({ 30, 60 }) do
		light:Slab("Balcon", fx - 10, fx + 10, fz + 6.1, fz + 15, y, 1.2, Colors.DarkMetal, M.DiamondPlate)
		light:Wall("Barandilla", "x", fz + 15, fx - 10, fx + 10, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
		light:Wall("Barandilla", "z", fx - 10, fz + 6.1, fz + 15, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
		light:Wall("Barandilla", "z", fx + 10, fz + 6.1, fz + 15, y, y + 3.5, 0.3, Colors.Glass, M.Glass, {})
	end
	local beam = b:Group("LuzFaro", "Model")
	beam:Ball("Lampara", 5, V(fx, 78, fz), C(255, 245, 180), M.Neon)
	beam:Box("Haz", V(40, 2, 2), V(fx + 20, 78, fz), C(255, 245, 180), M.Neon, { transparency = 0.6, canCollide = false })
	beam:Box("Haz", V(40, 2, 2), V(fx - 20, 78, fz), C(255, 245, 180), M.Neon, { transparency = 0.6, canCollide = false })
	b:Spin(beam.parent, 8, "Y")
	light:Pillar("Linterna", fx, fz, 75, 81, 10, Colors.Glass, M.Glass)

	-- cabanas de playa (madera con tejado de paja: arden)
	for i, p in ipairs({ { 60, 70 }, { 85, 40 }, { 30, 95 }, { -10, 100 }, { -60, 80 } }) do
		Buildings.House(b, p[1], p[2], 14, 12, 1, { name = "Cabana" .. i, color = C(160, 110, 70), material = M.WoodPlanks, roofColor = STRAW })
	end
	-- chiringuito
	local bar = b:Group("Chiringuito")
	bar:Box("Barra", V(14, 4, 4), V(-90, 2, 20), C(140, 95, 60), M.Wood)
	bar:Box("TejadoPaja", V(18, 1, 12), V(-90, 10, 22), STRAW, M.Grass)
	for _, s in ipairs({ { -98, 16 }, { -82, 16 }, { -98, 28 }, { -82, 28 } }) do
		bar:Pillar("Poste", s[1], s[2], 0, 10, 0.8, C(140, 95, 60), M.Wood)
	end
	bar:Board("CartelBar", "TIKI BAR", V(10, 2.4, 0.4), V(-90, 8, 16), C(255, 140, 60), Colors.White)
	-- hoguera
	local fire = b:Box("Hoguera", V(4, 1, 4), V(-70, 0.8, 45), C(90, 60, 40), M.Wood)
	local f = Instance.new("Fire")
	f.Size = 6
	f.Parent = fire

	-- muelle y barca
	local pier = b:Group("Muelle")
	pier:Box("Pasarela", V(8, 1, 60), V(-20, 1, 175), C(150, 110, 70), M.WoodPlanks)
	for k = 0, 5 do
		pier:Pillar("Pilote", -24, 150 + k * 10, -8, 1, 1, C(120, 85, 55), M.Wood)
		pier:Pillar("Pilote", -16, 150 + k * 10, -8, 1, 1, C(120, 85, 55), M.Wood)
	end
	pier:Box("Barca", V(6, 2.4, 14), V(-8, 0.6, 190), C(220, 80, 60), M.Wood)

	-- barco pirata encallado (inclinado)
	local wreck = b:At(V(110, 0, 90), "BarcoPirata")
	wreck:Box("Casco", V(40, 10, 14), V(0, 3, 0), C(110, 75, 45), M.WoodPlanks, { rot = V(8, 25, 0) })
	wreck:Box("Cubierta", V(38, 1, 12), V(0, 8.5, 0), C(140, 100, 60), M.WoodPlanks, { rot = V(8, 25, 0) })
	wreck:Box("Mastil", V(1.4, 30, 1.4), V(0, 23, 0), C(100, 70, 40), M.Wood, { rot = V(8, 25, 0) })
	wreck:Box("Vela", V(14, 12, 0.4), V(0, 24, 1), C(235, 230, 215), M.Fabric, { rot = V(8, 25, 0) })
	wreck:Box("Cofre", V(4, 3, 3), V(-6, 10.5, 0), C(200, 160, 40), M.Wood)

	-- palmeras
	local palms = b:Group("Palmeras")
	for i = 0, 27 do
		local a = i * 2.39996
		local r = 60 + (i % 5) * 18
		local x, z = math.cos(a) * r, math.sin(a) * r
		if math.abs(x - fx) > 20 or math.abs(z - fz) > 20 then
			Buildings.Palm(palms, x, z, 0, 0.9 + (i % 3) * 0.2)
		end
	end
	-- hamacas
	for k = 0, 2 do
		b:Box("Hamaca", V(2, 0.4, 7), V(40 + k * 8, 2, 120), C(255, 100 + k * 50, 80), M.Fabric)
	end

	for ix = 0, 3 do
		for iz = 0, 2 do
			b:Spawn(V(20 + ix * 12, 1, 30 + iz * 12))
		end
	end
end

return TropicalIsland
]])

	add("ServerStorage", { "IslasMapas", "Lib" }, "Buildings", "ModuleScript", [[
-- Buildings: piezas grandes reutilizables para los mapas (casas, torres con ascensor, arboles, coches...).
-- Todas las medidas son relativas al origen del builder; el suelo del mapa esta en y = 0.
local Util = require(script.Parent.Util)
local Elevator = require(script.Parent.Elevator)
local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors
local windows = Util.Windows

local Buildings = {}

local FURNITURE_COLORS = { C(200, 70, 70), C(70, 110, 200), C(90, 160, 90), C(200, 170, 80), C(150, 90, 170) }

-- Muebles sencillos en una planta (madera y tela: arden)
function Buildings.Furnish(b, x1, x2, z1, z2, y, seed)
	local r = Random.new(seed or 1)
	local w, d = x2 - x1, z2 - z1
	if w < 10 or d < 10 then
		return
	end
	local col = FURNITURE_COLORS[r:NextInteger(1, #FURNITURE_COLORS)]
	local tx, tz = x1 + w * 0.35, z1 + d * 0.55
	b:Box("Mesa", V(4, 0.4, 3), V(tx, y + 3, tz), Colors.Wood, M.Wood)
	b:Box("PataMesa", V(0.5, 3, 0.5), V(tx, y + 1.5, tz), Colors.Wood, M.Wood)
	for _, o in ipairs({ -2.6, 2.6 }) do
		b:Box("Silla", V(1.5, 1.6, 1.5), V(tx + o, y + 0.8, tz), col, M.Fabric)
	end
	if r:NextNumber() < 0.6 then
		b:Box("Sofa", V(6, 1.6, 2.6), V(x1 + w * 0.7, y + 0.8, z1 + 2.5), col, M.Fabric)
		b:Box("RespaldoSofa", V(6, 2.2, 0.8), V(x1 + w * 0.7, y + 1.9, z1 + 1.6), col, M.Fabric)
	else
		b:Box("Cama", V(5, 1.4, 7), V(x1 + w * 0.72, y + 0.7, z1 + 4.5), C(240, 240, 245), M.Fabric)
	end
	b:Box("Estanteria", V(4, 6, 1.2), V(x2 - 3, y + 3, z2 - 1.6), Colors.Wood, M.Wood)
end

-- Casa de 1-3 plantas con puerta delante (+Z), ventanas, escalera interior y tejado.
-- opts: color, roofColor, story (12), roof ("pitched"/"flat"), furnish (true), material
function Buildings.House(b, cx, cz, w, d, floors, opts)
	opts = opts or {}
	local story = opts.story or 12
	local color = opts.color or C(230, 220, 200)
	local mat = opts.material or M.SmoothPlastic
	local x1, x2, z1, z2 = cx - w / 2, cx + w / 2, cz - d / 2, cz + d / 2
	local g = b:Group(opts.name or "Casa")
	local stairLen = story * 1.3
	local stairHole = { x1 + 1.5, x1 + 1.5 + stairLen, z1 + 1, z1 + 5 }
	for i = 0, floors - 1 do
		local y = i * story
		local holes = (i > 0) and { stairHole } or nil
		g:Slab("Suelo", x1, x2, z1, z2, y + (i == 0 and 0.4 or 0), i == 0 and 0.4 or 1, i == 0 and C(150, 110, 80) or C(170, 130, 95), M.WoodPlanks, holes)
		local front = windows(x1 + 1, x2 - 1, 8, 4, 4, 9, i == 0 and cx - 3 or nil, i == 0 and cx + 3 or nil)
		if i == 0 then
			front[#front + 1] = { from = cx - 2.5, to = cx + 2.5, bottom = 0, top = 8 }
		end
		g:Wall("Pared", "x", z2, x1, x2, y, y + story, 0.8, color, mat, front)
		g:Wall("Pared", "x", z1, x1, x2, y, y + story, 0.8, color, mat, windows(x1 + 1, x2 - 1, 8, 4, 4, 9))
		g:Wall("Pared", "z", x1, z1, z2, y, y + story, 0.8, color, mat, windows(z1 + 1, z2 - 1, 8, 4, 4, 9))
		g:Wall("Pared", "z", x2, z1, z2, y, y + story, 0.8, color, mat, windows(z1 + 1, z2 - 1, 8, 4, 4, 9))
		if i < floors - 1 then
			g:Stairs("Escalera", x1 + 1.5, z1 + 3, y, y + story, 4, stairLen, "+x", Colors.Wood, M.Wood)
		end
		if opts.furnish ~= false then
			Buildings.Furnish(g, x1 + 1, x2 - 1, z1 + 6, z2 - 1, y + (i == 0 and 0.4 or 0), math.floor(cx * 7 + cz * 13 + i))
		end
	end
	local top = floors * story
	local roofColor = opts.roofColor or C(170, 70, 50)
	if opts.roof == "flat" then
		g:Slab("Tejado", x1 - 0.5, x2 + 0.5, z1 - 0.5, z2 + 0.5, top + 1, 1, roofColor, M.Slate)
	else
		g:Slab("Techo", x1, x2, z1, z2, top + 0.6, 0.6, color, mat)
		local h = math.min(d, w) * 0.35
		-- dos aguas a lo largo de X
		g:Wedge("Tejado", V(w + 1, h, d / 2 + 0.5), V(cx, top + 0.6 + h / 2, z1 + d / 4 - 0.25), roofColor, M.Slate, 0)
		g:Wedge("Tejado", V(w + 1, h, d / 2 + 0.5), V(cx, top + 0.6 + h / 2, z2 - d / 4 + 0.25), roofColor, M.Slate, 180)
	end
	return g
end

-- Torre de varias plantas con ascensor (pared de atras) y escalera en zigzag (esquina delantera derecha).
-- Requiere w, d >= 30. Devuelve la lista de alturas de planta (incluida la azotea).
-- opts: color, glassColor, story (14), name, labels, furnish, wallColor (hueco del ascensor), roofRail (true)
function Buildings.Tower(b, cx, cz, w, d, floors, opts)
	opts = opts or {}
	local story = opts.story or 14
	local color = opts.color or C(200, 200, 205)
	local x1, x2, z1, z2 = cx - w / 2, cx + w / 2, cz - d / 2, cz + d / 2
	local g = b:Group(opts.name or "Torre")
	local levels, labels = {}, {}
	for i = 1, floors + 1 do
		levels[i] = (i - 1) * story
		labels[i] = (i == 1 and "PB") or (i == floors + 1 and "A") or tostring(i - 1)
	end
	local elev = { name = (opts.name or "Torre") .. "Ascensor", x = cx, z = z1 + 6.4, floors = levels, labels = opts.labels or labels, wallColor = opts.wallColor or C(90, 92, 100) }
	local hole = Elevator.hole(elev)
	local L = story * 1.25
	local sx2 = x2 - 3
	local sx1 = sx2 - L
	local function stairHole(i)
		if i % 2 == 1 then
			return { sx1, sx2, z2 - 10, z2 - 4 }
		end
		return { sx1, sx2, z2 - 16, z2 - 10 }
	end
	for i = 1, floors + 1 do
		local holes = { hole }
		if i > 1 then
			holes[#holes + 1] = stairHole(i - 1)
		end
		g:Slab("Planta", x1, x2, z1, z2, levels[i], i == 1 and 0.5 or 1.2, i == 1 and C(215, 210, 200) or C(205, 200, 195), M.Marble, holes)
	end
	for i = 1, floors do
		local y = levels[i]
		local front = windows(x1 + 1, x2 - 1, 10, 8, 2, story - 2)
		if i == 1 then
			front = windows(x1 + 1, x2 - 1, 10, 8, 2, story - 2, cx - 6, cx + 6)
			front[#front + 1] = { from = cx - 5, to = cx + 5, bottom = 0, top = 9 }
		end
		g:Wall("Fachada", "x", z2, x1, x2, y, y + story, 1, color, M.Concrete, front)
		g:Wall("Fachada", "x", z1, x1, x2, y, y + story, 1, color, M.Concrete)
		g:Wall("Fachada", "z", x1, z1, z2, y, y + story, 1, color, M.Concrete, windows(z1 + 1, z2 - 1, 10, 8, 2, story - 2))
		g:Wall("Fachada", "z", x2, z1, z2, y, y + story, 1, color, M.Concrete, windows(z1 + 1, z2 - 1, 10, 8, 2, story - 2))
		if i % 2 == 1 then
			g:Stairs("Escalera", sx1, z2 - 7, y, y + story, 6, L, "+x", C(180, 180, 185), M.Concrete)
		else
			g:Stairs("Escalera", sx2, z2 - 13, y, y + story, 6, L, "-x", C(180, 180, 185), M.Concrete)
		end
		if opts.furnish ~= false and i > 1 then
			Buildings.Furnish(g, x1 + 2, sx1 - 2, z1 + 14, z2 - 2, y, i * 31 + math.floor(cx))
		end
	end
	Elevator.build(g, elev)
	local roofY = levels[#levels]
	if opts.roofRail ~= false then
		for _, wdef in ipairs({ { "x", z2, x1, x2 }, { "x", z1, x1, x2 }, { "z", x1, z1, z2 }, { "z", x2, z1, z2 } }) do
			g:Wall("Barandilla", wdef[1], wdef[2], wdef[3], wdef[4], roofY, roofY + 3.5, 0.4, Colors.Glass, M.Glass, {})
		end
	end
	return levels, g
end

function Buildings.Palm(b, x, z, y, scale)
	scale = scale or 1
	local h = 14 * scale
	b:Pillar("TroncoPalmera", x, z, y, y + h, 1.4 * scale, C(140, 105, 70), M.Wood)
	for i = 0, 5 do
		local a = i / 6 * 360
		local rad = math.rad(a)
		b:Box("Hoja", V(9 * scale, 0.4, 2.4 * scale), V(x + math.cos(rad) * 4 * scale, y + h - 0.6, z + math.sin(rad) * 4 * scale), C(60, 150, 60), M.Grass, { rot = V(0, -a, -18) })
	end
end

function Buildings.Car(b, x, z, y, color, rotY)
	local g = b:At(V(x, y, z), "Coche")
	local along = (rotY or 0) % 180 == 0
	local size = along and V(5, 1.6, 10) or V(10, 1.6, 5)
	local cab = along and V(4.4, 1.5, 5) or V(5, 1.5, 4.4)
	g:Box("Carroceria", size, V(0, 1.4, 0), color, M.Metal)
	g:Box("Cabina", cab, V(0, 2.9, 0), Colors.Glass, M.Glass, { transparency = 0.35 })
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local px = along and sx * 2.4 or sz * 3.4
			local pz = along and sz * 3.4 or sx * 2.4
			g:Box("Rueda", V(1, 1.8, 1.8), V(px, 0.9, pz), C(25, 25, 25), M.Rubber, { shape = Enum.PartType.Cylinder, rot = along and V(0, 0, 0) or V(0, 90, 0) })
		end
	end
	return g
end

function Buildings.Lamp(b, x, z, y, h)
	h = h or 10
	b:Pillar("Farola", x, z, y, y + h, 0.6, Colors.DarkMetal, M.Metal)
	local lamp = b:Ball("Bombilla", 1.6, V(x, y + h + 0.6, z), C(255, 240, 200), M.Neon)
	Util.AddLight(lamp, 22, 1.1)
	return lamp
end

return Buildings
]])

	add("ServerStorage", { "IslasMapas", "Lib" }, "Elevator", "ModuleScript", [[
-- Elevator: ascensor funcional por codigo.
--
-- Mira hacia +Z (la puerta esta en la cara +Z del hueco). Se llama desde un mapa asi:
--   Elevator.build(b, { name = "AscensorA", x = 0, z = -40, floors = { 0, 20, 40 } })
-- floors = alturas (Y) del suelo de cada planta, de menor a mayor.
--
-- Hueco interior: 12 (X) x 11 (Z). Los agujeros de los forjados de cada planta deben coincidir
-- con Elevator.hole(cfg), que devuelve {x1, x2, z1, z2}.
--
-- Rendimiento: la cabina tiene pocas piezas (se mueve entera cada frame). Dentro hay un unico boton
-- (ProximityPrompt) que abre un menu de plantas en la pantalla del jugador.
-- Los ascensores no se rompen (Destruction ignora las carpetas *_Hueco y *_Cabina).

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(script.Parent.Util)
local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))
local V, C, M = Util.V, Util.C, Util.M

local Elevator = {}

local SHAFT_W, SHAFT_D = 12, 11 -- hueco interior
local CAB = 9 -- lado de la cabina
local DOOR_W, DOOR_H = 6, 8 -- hueco de la puerta
local WALL = 0.6
local SPEED = 16 -- studs por segundo

local registry = {} -- [id] = { request, labels, cabin, state }
Elevator._registry = registry -- para pruebas
local nextId = 0

local MenuEvent = Net.Event("ElevatorMenu")
local RequestEvent = Net.Event("ElevatorRequest")

RequestEvent.OnServerEvent:Connect(function(player, id, floor)
	local e = registry[id]
	if not e or typeof(floor) ~= "number" or floor ~= math.floor(floor) or floor < 1 or floor > #e.labels then
		return
	end
	-- solo si el jugador esta dentro o cerca de la cabina
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or not e.cabin.Parent or (hrp.Position - e.cabin:GetPivot().Position).Magnitude > 20 then
		return
	end
	e.request(floor)
end)

-- Rectangulo (x1, x2, z1, z2) que hay que dejar vacio en cada forjado
function Elevator.hole(cfg)
	return { cfg.x - SHAFT_W / 2, cfg.x + SHAFT_W / 2, cfg.z - SHAFT_D / 2, cfg.z + SHAFT_D / 2 }
end

function Elevator.build(b, cfg)
	local floors = cfg.floors
	local count = #floors
	local cx, cz = cfg.x, cfg.z
	local y0, yTop = floors[1], floors[count]
	local wallColor = cfg.wallColor or Util.Colors.Concrete
	local wallMat = cfg.wallMaterial or M.Concrete
	local metal = Util.Colors.Metal
	local labels = {}
	for i = 1, count do
		labels[i] = (cfg.labels and cfg.labels[i]) or tostring(i)
	end

	local shaft = b:Group(cfg.name .. "_Hueco")

	-- ===== Hueco (estatico) =====
	local sTop = yTop + CAB + 3
	local sBottom = y0 - 1
	local sH = sTop - sBottom
	local sMid = (sTop + sBottom) / 2
	local sm, shaftT = wallMat, nil
	if cfg.glass then
		sm, shaftT = M.Glass, 0.5
	end
	local frontZ = cz + SHAFT_D / 2 + WALL / 2

	shaft:Box("Fondo", V(SHAFT_W + WALL * 2, sH, WALL), V(cx, sMid, cz - SHAFT_D / 2 - WALL / 2), wallColor, sm, { transparency = shaftT })
	shaft:Box("LateralIzq", V(WALL, sH, SHAFT_D), V(cx - SHAFT_W / 2 - WALL / 2, sMid, cz), wallColor, sm, { transparency = shaftT })
	shaft:Box("LateralDer", V(WALL, sH, SHAFT_D), V(cx + SHAFT_W / 2 + WALL / 2, sMid, cz), wallColor, sm, { transparency = shaftT })
	shaft:Box("Techo", V(SHAFT_W + WALL * 2, 1, SHAFT_D + WALL * 2), V(cx, sTop + 0.5, cz), wallColor, M.Concrete)
	shaft:Box("Foso", V(SHAFT_W, 1, SHAFT_D), V(cx, sBottom - 0.5, cz), Util.Colors.DarkConcrete, M.Concrete)

	-- Frente: pilares a los lados de la puerta, y paneles entre plantas
	local pillarW = (SHAFT_W + WALL * 2 - DOOR_W) / 2
	for _, side in ipairs({ -1, 1 }) do
		shaft:Box("PilarPuerta", V(pillarW, sH, WALL), V(cx + side * (DOOR_W / 2 + pillarW / 2), sMid, frontZ), wallColor, wallMat)
	end
	for i = 1, count do
		local from = floors[i] + DOOR_H
		local to = floors[i + 1] or sTop
		if to > from then
			shaft:Box("PanelPuerta", V(DOOR_W, to - from, WALL), V(cx, (from + to) / 2, frontZ), wallColor, wallMat)
		end
		if floors[i + 1] == nil or floors[i + 1] - from > 1.4 then
			shaft:Board("Indicador", labels[i], V(2.2, 0.9, 0.2), V(cx, from + 0.7, frontZ + WALL / 2 + 0.1), Util.Colors.DarkMetal, C(120, 255, 140))
		end
	end

	-- ===== Cabina (se mueve como modelo: pocas piezas) =====
	local cabin = b:Group(cfg.name .. "_Cabina", "Model")
	local cabZ = cz + 0.9 -- su frente queda casi a ras del borde del hueco
	local cabFront = cabZ + CAB / 2
	local cabSide = cfg.glass and M.Glass or M.Metal
	local cabSideT = cfg.glass and 0.5 or nil

	local floorPart = cabin:Box("SueloCabina", V(CAB, 1, CAB), V(cx, y0 - 0.5, cabZ), Util.Colors.DarkMetal, M.DiamondPlate)
	cabin:Box("TechoCabina", V(CAB + 0.8, 0.6, CAB + 0.8), V(cx, y0 + CAB + 0.3, cabZ), metal, M.Metal)
	local lamp = cabin:Box("Luz", V(5, 0.2, 5), V(cx, y0 + CAB - 0.1, cabZ), C(255, 250, 220), M.Neon, { canCollide = false })
	Util.AddLight(lamp, 16, 1.2)
	cabin:Box("FondoCabina", V(CAB + 0.8, CAB, 0.4), V(cx, y0 + CAB / 2, cabZ - CAB / 2 - 0.2), metal, M.Metal)
	for _, side in ipairs({ -1, 1 }) do
		cabin:Box("LateralCabina", V(0.4, CAB, CAB), V(cx + side * (CAB / 2 + 0.2), y0 + CAB / 2, cabZ), metal, cabSide, { transparency = cabSideT })
	end
	local cabPillar = (CAB + 0.8 - DOOR_W) / 2
	for _, side in ipairs({ -1, 1 }) do
		cabin:Box("PilarCabina", V(cabPillar, DOOR_H, 0.4), V(cx + side * (DOOR_W / 2 + cabPillar / 2), y0 + DOOR_H / 2, cabFront - 0.2), metal, M.Metal)
	end
	cabin:Box("DintelCabina", V(CAB + 0.8, CAB - DOOR_H, 0.4), V(cx, y0 + DOOR_H + (CAB - DOOR_H) / 2, cabFront - 0.2), metal, M.Metal)

	local doorW = DOOR_W / 2
	local cabDoors = {}
	for k, side in ipairs({ -1, 1 }) do
		cabDoors[k] = cabin:Box("PuertaCabina", V(doorW, DOOR_H, 0.3), V(cx + side * doorW / 2, y0 + DOOR_H / 2, cabFront + 0.15), C(200, 205, 210), M.Metal)
	end

	-- botonera: un solo boton que abre el menu de plantas
	local panel = cabin:Board("Botonera", "▲▼", V(0.3, 2.2, 1.6), V(cx - CAB / 2 + 0.15, y0 + 4.4, cabZ + 2.3), Util.Colors.DarkMetal, C(120, 255, 140), Enum.NormalId.Right)
	local panelPrompt = Instance.new("ProximityPrompt")
	panelPrompt.ActionText = count == 2 and "Ir a la otra planta" or "Elegir planta"
	panelPrompt.ObjectText = "Ascensor"
	panelPrompt.HoldDuration = 0
	panelPrompt.MaxActivationDistance = 9
	panelPrompt.RequiresLineOfSight = false
	panelPrompt.Parent = panel

	cabin.parent.PrimaryPart = floorPart

	-- ===== Puertas de cada planta =====
	local floorDoors = {}
	for i = 1, count do
		local y = floors[i]
		local pair = {}
		for k, side in ipairs({ -1, 1 }) do
			pair[k] = shaft:Box("PuertaPlanta" .. i, V(doorW, DOOR_H, 0.3), V(cx + side * doorW / 2, y + DOOR_H / 2, frontZ + WALL / 2 + 0.15), C(200, 205, 210), M.Metal)
		end
		floorDoors[i] = pair
	end

	-- ===== Logica =====
	local originX = b.origin.X
	local st = { floor = 1, busy = false, queue = {}, alive = true, open = false }

	local function slide(door, absX)
		local goal = Vector3.new(absX, door.Position.Y, door.Position.Z)
		TweenService:Create(door, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Position = goal }):Play()
	end

	local function setDoors(open)
		if st.open == open then
			return
		end
		st.open = open
		local pairFloor = floorDoors[st.floor]
		for k, side in ipairs({ -1, 1 }) do
			local closedX = originX + cx + side * doorW / 2
			local openX = originX + cx + side * (doorW / 2 + doorW - 0.2)
			local target = open and openX or closedX
			slide(cabDoors[k], target)
			slide(pairFloor[k], target)
		end
		task.wait(0.9)
	end

	local function travel(idx)
		local fromY, toY = floors[st.floor], floors[idx]
		local model = cabin.parent
		local pivot = model:GetPivot()
		local cfv = Instance.new("CFrameValue")
		cfv.Value = pivot
		local conn = cfv.Changed:Connect(function(v)
			if st.alive then
				model:PivotTo(v)
			end
		end)
		local t = math.max(1.5, math.abs(toY - fromY) / SPEED)
		local tw = TweenService:Create(cfv, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Value = pivot + Vector3.new(0, toY - fromY, 0),
		})
		tw:Play()
		tw.Completed:Wait()
		conn:Disconnect()
		cfv:Destroy()
		if st.alive then
			model:PivotTo(pivot + Vector3.new(0, toY - fromY, 0))
		end
		st.floor = idx
	end

	local function process()
		while st.alive and #st.queue > 0 do
			local idx = table.remove(st.queue, 1)
			if idx ~= st.floor then
				setDoors(false)
				if not st.alive then
					return
				end
				travel(idx)
			end
			setDoors(true)
			task.wait(4)
			-- sin mas peticiones: cerrar puertas. Si mientras se cerraban llega otra peticion, se sigue.
			while st.alive and #st.queue == 0 and st.open do
				setDoors(false)
			end
		end
		st.busy = false
	end

	local function request(idx)
		if not st.alive then
			return
		end
		for _, q in ipairs(st.queue) do
			if q == idx then
				return
			end
		end
		-- ya esta aqui con las puertas abiertas: nada que hacer
		if idx == st.floor and st.busy and st.open then
			return
		end
		st.queue[#st.queue + 1] = idx
		if not st.busy then
			st.busy = true
			task.spawn(process)
		end
	end

	nextId = nextId + 1
	local id = nextId
	registry[id] = { request = request, labels = labels, cabin = cabin.parent, state = st }

	-- botones de llamada en cada planta
	for i = 1, count do
		local call = shaft:Box("BotonLlamada", V(0.7, 1, 0.3), V(cx + DOOR_W / 2 + 1, floors[i] + 3.5, frontZ + WALL / 2 + 0.15), C(255, 190, 60), M.Neon)
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = "Llamar ascensor"
		pp.ObjectText = "Planta " .. labels[i]
		pp.HoldDuration = 0
		pp.MaxActivationDistance = 8
		pp.RequiresLineOfSight = false
		pp.Parent = call
		pp.Triggered:Connect(function()
			request(i)
		end)
	end

	panelPrompt.Triggered:Connect(function(player)
		if count == 2 then
			request(st.floor == 1 and 2 or 1)
		else
			MenuEvent:FireClient(player, id, labels, st.floor)
		end
	end)

	cabin.parent.Destroying:Connect(function()
		st.alive = false
		registry[id] = nil
	end)

	task.defer(function()
		request(1)
	end)

	return { Cabin = cabin.parent, Request = request, Id = id }
end

return Elevator
]])

	add("ServerStorage", { "IslasMapas", "Lib" }, "Util", "ModuleScript", [[
-- Util: herramientas para construir mapas por codigo.
-- Todo es relativo al "origin" del builder, asi un mapa se puede construir en cualquier sitio.

local Util = {}

local V = Vector3.new
local C = Color3.fromRGB
local M = Enum.Material

Util.V = V
Util.C = C
Util.M = M

Util.Colors = {
	White = C(240, 240, 240),
	Concrete = C(160, 160, 165),
	DarkConcrete = C(95, 95, 100),
	Asphalt = C(45, 45, 50),
	Glass = C(170, 215, 235),
	Metal = C(180, 185, 190),
	DarkMetal = C(70, 72, 78),
	Red = C(200, 50, 50),
	Blue = C(50, 100, 200),
	Yellow = C(240, 200, 50),
	Orange = C(235, 130, 40),
	Green = C(70, 150, 70),
	Grass = C(90, 140, 70),
	Sand = C(220, 200, 150),
	Wood = C(140, 100, 60),
	Snow = C(245, 250, 255),
	Water = C(40, 110, 175),
}

-- Tiempo maximo seguido construyendo antes de ceder el hilo (para no congelar el servidor)
Util.BuildBudget = 0.006
-- Tamano maximo de cada trozo de pared/suelo: las paredes grandes se trocean para que se rompan por partes
Util.ChunkSize = 12

local Builder = {}
Builder.__index = Builder

-- parent: donde van las piezas, origin: Vector3 donde esta el (0,0,0) del mapa
function Util.newBuilder(parent, origin)
	return setmetatable({
		parent = parent,
		origin = origin,
		state = { count = 0, spawns = {} }, -- compartido con todos los builders hijos
	}, Builder)
end

function Builder:Count()
	return self.state.count
end

function Builder:Spawns()
	return self.state.spawns
end

-- Carpeta (o modelo) nueva dentro de este builder
function Builder:Group(name, className)
	local inst = Instance.new(className or "Folder")
	inst.Name = name
	inst.Parent = self.parent
	return setmetatable({ parent = inst, origin = self.origin, state = self.state }, Builder)
end

-- Igual que Group pero ademas desplaza el origen (para construir algo reutilizable en otro sitio)
function Builder:At(offset, name, className)
	local g = self:Group(name, className)
	g.origin = self.origin + offset
	return g
end

-- Pieza basica. size/pos son Vector3 (pos = centro, relativo al origen)
-- opts: shape, transparency, canCollide, rot (grados, Vector3), velocity, reflectance,
--       touch (true = puede disparar Touched), indestructible (no se rompe con los desastres)
function Builder:Box(name, size, pos, color, material, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Color = color or Util.Colors.Concrete
	p.Material = material or M.SmoothPlastic
	if opts.shape then
		p.Shape = opts.shape
	end
	if opts.transparency then
		p.Transparency = opts.transparency
	end
	if opts.canCollide == false then
		p.CanCollide = false
	end
	if opts.reflectance then
		p.Reflectance = opts.reflectance
	end
	-- rendimiento: las piezas del mapa no necesitan eventos Touched, y las pequenas no necesitan sombra
	if not opts.touch then
		p.CanTouch = false
	end
	if math.max(size.X, size.Y, size.Z) < 3 then
		p.CastShadow = false
	end
	if opts.indestructible then
		p:SetAttribute("Indestructible", true)
	end
	local cf = CFrame.new(self.origin + pos)
	if opts.rot then
		cf = cf * CFrame.Angles(math.rad(opts.rot.X), math.rad(opts.rot.Y), math.rad(opts.rot.Z))
	end
	p.CFrame = cf
	if opts.velocity then
		p.AssemblyLinearVelocity = opts.velocity
	end
	p.Parent = self.parent

	local s = self.state
	s.count = s.count + 1
	if os.clock() - (s.lastYield or 0) > Util.BuildBudget then
		task.wait()
		s.lastYield = os.clock()
	end
	return p
end

-- Como Box pero troceando en bloques de como mucho Util.ChunkSize (solo piezas sin rotar).
-- Asi una pared de 80 studs no se rompe entera de golpe sino por trozos.
function Builder:Chunked(name, size, pos, color, material, opts)
	local c = Util.ChunkSize
	local function count(v)
		return v > c * 1.25 and math.ceil(v / c) or 1
	end
	local nx, ny, nz = count(size.X), count(size.Y), count(size.Z)
	if nx * ny * nz == 1 then
		return self:Box(name, size, pos, color, material, opts)
	end
	local sx, sy, sz = size.X / nx, size.Y / ny, size.Z / nz
	local x0 = pos.X - size.X / 2 + sx / 2
	local y0 = pos.Y - size.Y / 2 + sy / 2
	local z0 = pos.Z - size.Z / 2 + sz / 2
	local first
	for i = 0, nx - 1 do
		for j = 0, ny - 1 do
			for k = 0, nz - 1 do
				local part = self:Box(name, V(sx, sy, sz), V(x0 + i * sx, y0 + j * sy, z0 + k * sz), color, material, opts)
				first = first or part
			end
		end
	end
	return first
end

-- Columna vertical redonda (las altas se trocean para que puedan romperse por tramos)
function Builder:Pillar(name, x, z, y1, y2, diameter, color, material)
	local h = y2 - y1
	local n = h > Util.ChunkSize * 1.5 and math.ceil(h / (Util.ChunkSize * 1.5)) or 1
	local seg = h / n
	local first
	for i = 0, n - 1 do
		local a = y1 + i * seg
		local part = self:Box(name, V(seg, diameter, diameter), V(x, a + seg / 2, z), color, material, {
			shape = Enum.PartType.Cylinder,
			rot = V(0, 0, 90),
		})
		first = first or part
	end
	return first
end

function Builder:Ball(name, diameter, pos, color, material)
	return self:Box(name, V(diameter, diameter, diameter), pos, color, material, { shape = Enum.PartType.Ball })
end

-- Pared recta con huecos.
-- axis "x": la pared corre a lo largo de X, situada en z = fixed (a1..a2 son coordenadas X)
-- axis "z": la pared corre a lo largo de Z, situada en x = fixed (a1..a2 son coordenadas Z)
-- openings: lista de { from, to, bottom, top, glass } (bottom/top relativos a y1)
function Builder:Wall(name, axis, fixed, a1, a2, y1, y2, th, color, material, openings)
	openings = openings or {}
	table.sort(openings, function(p, q)
		return p.from < q.from
	end)
	local h = y2 - y1

	local function seg(from, to, bottom, top, segColor, segMat, transp, segName)
		if to - from < 0.05 or top - bottom < 0.05 then
			return
		end
		local len = to - from
		local cy = y1 + (bottom + top) / 2
		local mid = (from + to) / 2
		local size, pos
		if axis == "x" then
			size = V(len, top - bottom, th)
			pos = V(mid, cy, fixed)
		else
			size = V(th, top - bottom, len)
			pos = V(fixed, cy, mid)
		end
		local useMat = segMat or material
		if useMat == M.Glass and transp == nil then
			transp = 0.55 -- el cristal siempre es translucido
		end
		self:Chunked(segName or name, size, pos, segColor or color, useMat, { transparency = transp })
	end

	local cursor = a1
	for _, o in ipairs(openings) do
		seg(cursor, o.from, 0, h)
		local bottom = o.bottom or 0
		local top = o.top or h
		seg(o.from, o.to, 0, bottom)
		seg(o.from, o.to, top, h)
		if o.glass then
			seg(o.from, o.to, bottom, top, Util.Colors.Glass, M.Glass, 0.55, name .. "Glass")
		end
		cursor = o.to
	end
	seg(cursor, a2, 0, h)
end

-- Lista de huecos de ventana para Builder:Wall: centros cada `step`, ancho `w`.
-- skipFrom/skipTo (opcional) dejan sin ventanas un tramo de la pared.
function Util.Windows(a1, a2, step, w, bottom, top, skipFrom, skipTo)
	local list = {}
	local c = a1 + step / 2
	while c + w / 2 <= a2 do
		local from, to = c - w / 2, c + w / 2
		if not (skipFrom and to > skipFrom and from < skipTo) then
			list[#list + 1] = { from = from, to = to, bottom = bottom, top = top, glass = true }
		end
		c = c + step
	end
	return list
end

-- Suelo/techo rectangular con agujeros. holes = { {x1, x2, z1, z2}, ... }
function Builder:Slab(name, x1, x2, z1, z2, ytop, th, color, material, holes)
	local rects = { { x1, x2, z1, z2 } }
	for _, h in ipairs(holes or {}) do
		local out = {}
		for _, r in ipairs(rects) do
			if h[2] <= r[1] or h[1] >= r[2] or h[4] <= r[3] or h[3] >= r[4] then
				out[#out + 1] = r
			else
				local hx1, hx2 = math.max(h[1], r[1]), math.min(h[2], r[2])
				local hz1, hz2 = math.max(h[3], r[3]), math.min(h[4], r[4])
				if hx1 > r[1] then
					out[#out + 1] = { r[1], hx1, r[3], r[4] }
				end
				if hx2 < r[2] then
					out[#out + 1] = { hx2, r[2], r[3], r[4] }
				end
				if hz1 > r[3] then
					out[#out + 1] = { hx1, hx2, r[3], hz1 }
				end
				if hz2 < r[4] then
					out[#out + 1] = { hx1, hx2, hz2, r[4] }
				end
			end
		end
		rects = out
	end
	for _, r in ipairs(rects) do
		self:Chunked(
			name,
			V(r[2] - r[1], th, r[4] - r[3]),
			V((r[1] + r[2]) / 2, ytop - th / 2, (r[3] + r[4]) / 2),
			color,
			material
		)
	end
end

-- Escalera de escalones macizos. (x, z) = pie de la escalera (centro del ancho).
-- dir = hacia donde se sube: "+x", "-x", "+z", "-z"
function Builder:Stairs(name, x, z, y1, y2, width, length, dir, color, material)
	local n = math.max(2, math.ceil(y2 - y1))
	local rise, run = (y2 - y1) / n, length / n
	for i = 1, n do
		local hgt = rise * i
		local off = run * (i - 0.5)
		local size, pos
		if dir == "+x" then
			size, pos = V(run, hgt, width), V(x + off, y1 + hgt / 2, z)
		elseif dir == "-x" then
			size, pos = V(run, hgt, width), V(x - off, y1 + hgt / 2, z)
		elseif dir == "+z" then
			size, pos = V(width, hgt, run), V(x, y1 + hgt / 2, z + off)
		else
			size, pos = V(width, hgt, run), V(x, y1 + hgt / 2, z - off)
		end
		self:Box(name, size, pos, color, material)
	end
end

-- Cuna (rampa/tejado). La parte alta queda hacia +Z; rotY gira alrededor del eje vertical (grados).
function Builder:Wedge(name, size, pos, color, material, rotY, opts)
	opts = opts or {}
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.Size = size
	w.Color = color or Util.Colors.Concrete
	w.Material = material or M.SmoothPlastic
	w.CanTouch = false
	if opts.indestructible then
		w:SetAttribute("Indestructible", true)
	end
	w.CFrame = CFrame.new(self.origin + pos) * CFrame.Angles(0, math.rad(rotY or 0), 0)
	w.Parent = self.parent
	local s = self.state
	s.count = s.count + 1
	if os.clock() - (s.lastYield or 0) > Util.BuildBudget then
		task.wait()
		s.lastYield = os.clock()
	end
	return w
end

-- Escalera de mano (se trepa)
function Builder:Ladder(name, x, z, y1, y2)
	local t = Instance.new("TrussPart")
	t.Name = name
	t.Anchored = true
	t.Size = V(2, y2 - y1, 2)
	t.CFrame = CFrame.new(self.origin + V(x, (y1 + y2) / 2, z))
	t.CanTouch = false
	t.Parent = self.parent
	self.state.count = self.state.count + 1
	return t
end

-- Texto en una cara de una pieza
function Builder:Sign(part, text, face, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Back -- Back = cara +Z: el cartel se lee mirando hacia -Z
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.Parent = gui
	return label
end

-- Cartel: caja con texto en la cara +Z por defecto
function Builder:Board(name, text, size, pos, bg, fg, face)
	local p = self:Box(name, size, pos, bg or Util.Colors.DarkMetal, M.SmoothPlastic)
	self:Sign(p, text, face, fg)
	return p
end

function Util.AddLight(part, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Range = range or 20
	l.Brightness = brightness or 1
	if color then
		l.Color = color
	end
	l.Parent = part
	return l
end

-- Punto de aparicion de jugadores (invisible)
function Builder:Spawn(pos)
	local p = self:Box("SpawnPoint", V(4, 1, 4), pos, Util.Colors.White, M.SmoothPlastic, {
		transparency = 1,
		canCollide = false,
		indestructible = true,
	})
	local list = self.state.spawns
	list[#list + 1] = p
	return p
end

-- Mar con plano de muerte: tocar el agua mata al jugador
function Builder:Sea(y, extent, color, transparency)
	extent = math.min(extent or 2048, 2048) -- una pieza mide como mucho 2048 studs
	local p = self:Box("Mar", V(extent, 2, extent), V(0, y - 1, 0), color or Util.Colors.Water, M.SmoothPlastic, {
		transparency = transparency or 0.15,
		canCollide = false,
		touch = true,
		indestructible = true,
	})
	p.CastShadow = false
	p.Touched:Connect(function(hit)
		local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.Health = 0
		end
	end)
	return p
end

-- Plano de muerte invisible (vacio): tocarlo mata al jugador
function Builder:KillPlane(y, extent)
	return self:Sea(y, extent, Util.Colors.DarkMetal, 1)
end

-- Marca un modelo para que los clientes lo hagan girar (sin coste para el servidor).
-- axis = "X", "Y" o "Z"; rpm = vueltas por minuto. El giro es alrededor del centro del modelo.
function Builder:Spin(model, rpm, axis)
	-- lo que gira no se rompe (el giro es solo visual en cada cliente)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d:SetAttribute("Indestructible", true)
		end
	end
	model:SetAttribute("GiroRPM", rpm)
	model:SetAttribute("GiroEje", axis or "Y")
	game:GetService("CollectionService"):AddTag(model, "IslasGira")
end

-- Abeto simple (tronco + 3 pisos)
function Builder:Pine(x, z, y, scale)
	scale = scale or 1
	self:Pillar("Tronco", x, z, y, y + 5 * scale, 1.2 * scale, Util.Colors.Wood, M.Wood)
	for i = 0, 2 do
		local d = (8 - i * 2.2) * scale
		self:Pillar("Copa", x, z, y + (3 + i * 2.2) * scale, y + (5.4 + i * 2.2) * scale, d, C(35, 95, 50), M.Grass)
	end
end

return Util
]])

	add("ServerScriptService", { "IslasServer" }, "AdminCommands", "ModuleScript", [[
-- AdminCommands: comandos de chat para probar el juego (solo en Studio, para el dueno del juego
-- o para los UserId de Config.Admins si existe).
--   !mapa castillo     la proxima ronda sera en ese mapa (sin votacion); vale el nombre en espanol o el interno
--   !desastre tornado  el proximo desastre sera ese
--   !saltar            salta el descanso o termina la ronda actual
--   !monedas 1000      te da monedas
--   !nivel 500         te da XP
--   !lista             muestra mapas y desastres disponibles
--   !stats             estado de la destruccion
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local S = script.Parent
local PlayerData = require(S.PlayerData)
local MapService = require(S.MapService)
local DisasterService = require(S.DisasterService)
local Destruction = require(S.Destruction)
local GameLoop = require(S.GameLoop)

local Toast = Net.Event("Toast")

local AdminCommands = {}

local function isAdmin(player)
	if RunService:IsStudio() or player.UserId == game.CreatorId then
		return true
	end
	for _, id in ipairs(Config.Admins or {}) do
		if id == player.UserId then
			return true
		end
	end
	return false
end

local function reply(player, text)
	Toast:FireClient(player, { Title = "Admin", Text = text })
end

-- Busca por nombre interno (City) o por titulo en espanol (Ciudad), completo o en parte
local function findName(list, query, titleOf)
	query = string.lower(query or "")
	if query == "" then
		return nil
	end
	local function keys(n)
		local k = { string.lower(n) }
		if titleOf then
			local ok, t = pcall(titleOf, n)
			if ok and t then
				k[2] = string.lower(t)
			end
		end
		return k
	end
	for _, n in ipairs(list) do
		for _, k in ipairs(keys(n)) do
			if k == query then
				return n
			end
		end
	end
	for _, n in ipairs(list) do
		for _, k in ipairs(keys(n)) do
			if string.find(k, query, 1, true) then
				return n
			end
		end
	end
	return nil
end

local commands = {}

commands.mapa = function(player, arg)
	local name = findName(MapService.GetMapNames(), arg, function(n)
		return MapService.GetInfo(n).Title
	end)
	if not name then
		return reply(player, "No existe ese mapa. Usa !lista")
	end
	GameLoop.ForceMap(name)
	reply(player, "Proxima ronda: " .. name)
end

commands.desastre = function(player, arg)
	local name = findName(DisasterService.GetNames(), arg, DisasterService.TitleOf)
	if not name then
		return reply(player, "No existe ese desastre. Usa !lista")
	end
	GameLoop.ForceDisaster(name)
	reply(player, "Proximo desastre: " .. name)
end

commands.saltar = function(player)
	GameLoop.Skip()
	reply(player, "Saltando fase...")
end

commands.monedas = function(player, arg)
	local n = tonumber(arg) or 1000
	PlayerData.AddCoins(player, n)
	reply(player, "+" .. n .. " monedas")
end

commands.nivel = function(player, arg)
	local n = tonumber(arg) or 500
	PlayerData.AddXP(player, n)
	reply(player, "+" .. n .. " XP")
end

commands.lista = function(player)
	reply(player, "Mapas: " .. table.concat(MapService.GetMapNames(), ", "))
	reply(player, "Desastres: " .. table.concat(DisasterService.GetNames(), ", "))
end

commands.stats = function(player)
	local st = Destruction.Stats()
	reply(player, string.format("Piezas %d · rotas %d · derrumbadas %d · fisicas %d · escombros %d",
		st.parts or 0, st.broken or 0, st.collapsed or 0, st.physics or 0, st.rubble or 0))
end

function AdminCommands.Handle(player, message)
	if typeof(message) ~= "string" or message:sub(1, 1) ~= "!" or not isAdmin(player) then
		return false
	end
	local cmd, arg = message:match("^!(%S+)%s*(.*)$")
	local fn = cmd and commands[string.lower(cmd)]
	if fn then
		local ok, err = pcall(fn, player, arg)
		if not ok then
			reply(player, "Error: " .. tostring(err))
		end
		return true
	end
	return false
end

function AdminCommands.Init()
	local function onPlayer(player)
		player.Chatted:Connect(function(message)
			AdminCommands.Handle(player, message)
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return AdminCommands
]])

	add("ServerScriptService", { "IslasServer" }, "CoinDrops", "ModuleScript", [[
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
]])

	add("ServerScriptService", { "IslasServer" }, "CollisionGroups", "ModuleScript", [[
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
]])

	add("ServerScriptService", { "IslasServer" }, "Destruction", "ModuleScript", [=[
-- Destruction: destruccion estructural de los mapas.
--
-- Como funciona:
--  1. Al cargar un mapa se registran sus piezas (salvo isla, mar, spawns y ascensores).
--  2. En segundo plano (repartido entre frames) se calcula quien toca a quien: un grafo de apoyos.
--     Las piezas que tocan el suelo del mapa son "raices".
--  3. Cada pieza tiene vida segun su material y tamano. Los desastres hacen dano con DamageSphere, Damage,
--     Shake, DamageBox, Ignite...
--  4. Al romperse una pieza: si es pequena o de cristal se hace anicos (desaparece y los clientes generan
--     fragmentos locales, sin coste para el servidor); si es grande y hay presupuesto, se suelta con fisica.
--  5. Cada poco se comprueba que todo siga unido a una raiz. Lo que se queda colgando se DERRUMBA:
--     se agrupa en bloques soldados (pocos cuerpos fisicos, aunque tengan muchas piezas) que caen juntos
--     y al pararse se quedan como escombro anclado.
--  6. Las piezas se borran poco a poco (Config.HidePerFrame por frame) para evitar tirones.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Config"))
local Net = require(ReplicatedStorage.IslasShared:WaitForChild("Net"))
local PhysicsBudget = require(script.Parent.PhysicsBudget)

local ShatterEvent = Net.Event("Shatter")

local Destruction = {}

local MATERIAL_HP = {
	Glass = 8, ForceField = 8, Neon = 25, Fabric = 20, Foil = 30, Ice = 30, Snow = 35, Wood = 45, WoodPlanks = 45,
	Plastic = 60, SmoothPlastic = 60, Sand = 60, Ground = 110, Grass = 110, LeafyGrass = 110, Mud = 80,
	Brick = 130, Marble = 130, Concrete = 140, Pavement = 140, Slate = 150, Cobblestone = 150, Asphalt = 160,
	Rock = 170, Basalt = 180, Granite = 180, CorrodedMetal = 170, Metal = 200, DiamondPlate = 220,
}
local FLAMMABLE = { Wood = true, WoodPlanks = true, Fabric = true, Grass = true, LeafyGrass = true, Plastic = true }
local NOT_FRAGILE = { Isla = true, Mar = true, SpawnPoint = true, Roca = true, Orilla = true, HumanoidRootPart = true }
local DARK = Color3.new(0.12, 0.11, 0.1)
local BURNT = Color3.fromRGB(35, 30, 28)

local S = nil -- estado del mapa actual

local function clock()
	return workspace:GetServerTimeNow()
end

local function matName(part)
	local m = part.Material
	return typeof(m) == "EnumItem" and m.Name or tostring(m)
end

-- "cabin" si la pieza es de una cabina de ascensor (se mueve: se ignora), "shaft" si es del hueco
local function elevatorPart(part, root)
	local p = part.Parent
	while p and p ~= root do
		local n = p.Name
		if n:match("_Cabina$") then
			return "cabin"
		elseif n:match("_Hueco$") then
			return "shaft"
		end
		p = p.Parent
	end
	return nil
end

-- Media altura real de la pieza en el mundo (tiene en cuenta la rotacion: columnas cilindricas, etc.)
local function halfHeight(part)
	local s = part.Size
	local _, _, _, r00, r01, r02, r10, r11, r12 = part.CFrame:GetComponents()
	local _ = r00 + r01 + r02
	return 0.5 * (math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z)
end

local function maxHp(part)
	local s = part.Size
	local vol = s.X * s.Y * s.Z
	local base = MATERIAL_HP[matName(part)] or 100
	return base * math.clamp((vol / 24) ^ 0.33, 0.5, 2.2) * (S and S.toughness or 1)
end

-- ======================================================================
-- Registro y grafo
-- ======================================================================

function Destruction.IsActive()
	return S ~= nil
end

function Destruction.Begin(folder, floorY)
	Destruction.Reset()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }

	S = {
		folder = folder,
		floorY = floorY,
		params = params,
		ids = {}, -- [part] = id
		parts = {}, -- [id] = part
		alive = {}, -- [id] = bool
		root = {}, -- [id] = bool
		neigh = {}, -- [id] = { ids }
		hp = {}, -- [id] = vida actual (se calcula al primer golpe)
		fixed = {}, -- [id] = true si no se rompe nunca (huecos de ascensor, piezas indestructibles): apoyo fijo
		stage = {}, -- [id] = 0/1/2 (oscurecimiento por dano)
		graphReady = false,
		dirty = false,
		removeQueue = {},
		removeHead = 1,
		shatterQueue = {},
		burning = {}, -- [id] = { t = inicio, fire = Fire }
		burningCount = 0,
		toughness = 1,
		broken = 0,
		collapsed = 0,
		token = {},
	}
	PhysicsBudget.Reset()
	PhysicsBudget.SetKillY(floorY - 60)

	local n = 0
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			local elev = elevatorPart(d, folder)
			local indestructible = NOT_FRAGILE[d.Name] or d:GetAttribute("Indestructible") or elev == "shaft"
			local invisibleHelper = d.Transparency >= 0.95 and not d.CanCollide
			-- las cabinas se mueven y las piezas sin colision indestructibles (mar, spawns) no sujetan nada
			if elev ~= "cabin" and not invisibleHelper and not (indestructible and not d.CanCollide) then
				n = n + 1
				S.ids[d] = n
				S.parts[n] = d
				S.alive[n] = true
				local bottom = d.Position.Y - halfHeight(d)
				local s = d.Size
				if indestructible then
					-- apoyo fijo: lo que se apoya en un hueco de ascensor o en una pieza indestructible no se cae
					S.fixed[n] = true
					S.root[n] = true
				else
					S.root[n] = bottom <= floorY + 0.75 or math.max(s.X, s.Z) > 160
				end
				-- piezas que estaban sueltas en el mapa original (muebles): se anclan hasta que algo las golpee
				if not d.Anchored then
					d.Anchored = true
				end
			end
		end
	end
	S.count = n

	local token = S.token
	task.spawn(function()
		local budget = Config.GraphBudgetMs / 1000
		local start = os.clock()
		local pad = Vector3.new(0.8, 0.8, 0.8) -- tolerancia de contacto (carteles pegados a paredes, etc.)
		for i = 1, n do
			if S == nil or S.token ~= token then
				return
			end
			local part = S.parts[i]
			local list = S.neigh[i] or {}
			S.neigh[i] = list
			if part.Parent then
				for _, other in ipairs(workspace:GetPartBoundsInBox(part.CFrame, part.Size + pad, params)) do
					local j = S.ids[other]
					if j and j ~= i and j > i then
						list[#list + 1] = j
						local lj = S.neigh[j]
						if not lj then
							lj = {}
							S.neigh[j] = lj
						end
						lj[#lj + 1] = i
					end
				end
			end
			if os.clock() - start > budget then
				task.wait()
				start = os.clock()
			end
		end
		if S and S.token == token then
			S.graphReady = true
			-- lo que nace sin apoyo (carteles colgados, luces...) se considera sujeto: no se cae de golpe
			local loose = Destruction.FindUnsupported()
			for _, p in ipairs(loose) do
				S.root[S.ids[p]] = true
			end
			S.initialLoose = #loose
			S.initialLooseNames = {}
			for i = 1, math.min(12, #loose) do
				S.initialLooseNames[i] = loose[i]
			end
		end
	end)
	return n
end

function Destruction.SetToughness(mult)
	if S then
		S.toughness = mult
	end
end

function Destruction.Reset()
	if S then
		for _, b in pairs(S.burning) do
			if b.fire and b.fire.Parent then
				b.fire:Destroy()
			end
		end
	end
	S = nil
	PhysicsBudget.Reset()
end

function Destruction.Stats()
	if not S then
		return { parts = 0 }
	end
	return { parts = S.count, broken = S.broken, collapsed = S.collapsed, graphReady = S.graphReady, physics = PhysicsBudget.Count(), rubble = PhysicsBudget.RubbleCount(), loose = S.initialLoose or 0, looseParts = S.initialLooseNames or {} }
end

-- ======================================================================
-- Romper piezas
-- ======================================================================

-- Borrado diferido (las piezas en cola ya no se ven: se ocultan al momento)
local function queueRemove(part)
	if not S then
		if part.Parent then
			part:Destroy()
		end
		return
	end
	S.removeQueue[#S.removeQueue + 1] = part
end
Destruction.Remove = queueRemove
PhysicsBudget.SetRemover(queueRemove)

local function shatter(part, burnt)
	if not S then
		return
	end
	local q = S.shatterQueue
	q[#q + 1] = { p = part.Position, s = part.Size, c = burnt and BURNT or part.Color, m = matName(part) }
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	queueRemove(part)
end

local function detach(part, impulse)
	local s = part.Size
	part.Anchored = false
	PhysicsBudget.Add({ part })
	part.AssemblyLinearVelocity = impulse or Vector3.new(math.random(-6, 6), 4, math.random(-6, 6))
	part.AssemblyAngularVelocity = Vector3.new(math.random(-3, 3), math.random(-3, 3), math.random(-3, 3))
	-- piezas muy grandes caen mas lentas en el giro
	if math.max(s.X, s.Y, s.Z) > 10 then
		part.AssemblyAngularVelocity = part.AssemblyAngularVelocity * 0.4
	end
end

local function breakId(id, impulse, opts)
	if not S or not S.alive[id] or S.fixed[id] then
		return
	end
	S.alive[id] = false
	S.broken = S.broken + 1
	S.dirty = true
	local part = S.parts[id]
	local burn = S.burning[id]
	if burn then
		if burn.fire and burn.fire.Parent then
			burn.fire:Destroy()
		end
		S.burning[id] = nil
		S.burningCount = S.burningCount - 1
	end
	if not part.Parent then
		return
	end
	local s = part.Size
	local vol = s.X * s.Y * s.Z
	local mat = matName(part)
	local forceShatter = opts and opts.shatter
	if forceShatter or mat == "Glass" or vol < 5 or not PhysicsBudget.CanAdd(1) or (opts and opts.burnt) then
		shatter(part, opts and opts.burnt)
	else
		detach(part, impulse)
	end
end

function Destruction.Break(part, impulse, opts)
	if not S then
		return
	end
	local id = S.ids[part]
	if id then
		breakId(id, impulse, opts)
	end
end

local function damageId(id, amount, impulse, opts)
	if not S or not S.alive[id] or S.fixed[id] then
		return false
	end
	local part = S.parts[id]
	local hp = S.hp[id]
	if not hp then
		hp = maxHp(part)
		S.hp[id] = hp
		S.max = S.max or {}
		S.max[id] = hp
	end
	hp = hp - amount
	S.hp[id] = hp
	if hp <= 0 then
		breakId(id, impulse, opts)
		return true
	end
	-- se oscurece al recibir dano (solo 2 cambios para no saturar la red)
	local ratio = hp / S.max[id]
	local stage = S.stage[id] or 0
	if ratio < 0.66 and stage < 1 then
		S.stage[id] = 1
		part.Color = part.Color:Lerp(DARK, 0.22)
	elseif ratio < 0.33 and stage < 2 then
		S.stage[id] = 2
		part.Color = part.Color:Lerp(DARK, 0.3)
	end
	return false
end

function Destruction.Damage(part, amount, impulse, opts)
	if not S then
		return false
	end
	local id = S.ids[part]
	if id then
		return damageId(id, amount, impulse, opts)
	end
	return false
end

-- Dano en esfera con caida por distancia. opts.fling = fuerza con la que salen despedidas las piezas.
function Destruction.DamageSphere(center, radius, damage, opts)
	if not S then
		return 0
	end
	opts = opts or {}
	local fling = opts.fling or 40
	local broken = 0
	local hits = workspace:GetPartBoundsInRadius(center, radius, S.params)
	local limit = opts.maxParts or 90
	for i, part in ipairs(hits) do
		if i > limit then
			break
		end
		local id = S.ids[part]
		if id and S.alive[id] then
			local off = part.Position - center
			local d = off.Magnitude
			local k = 1 - math.clamp(d / radius, 0, 1) * 0.7
			local dir = d > 0.1 and off.Unit or Vector3.yAxis
			local impulse = dir * fling * k + Vector3.new(0, fling * 0.5 * k, 0)
			if damageId(id, damage * k, impulse, opts) then
				broken = broken + 1
			end
		end
	end
	return broken
end

-- Dano a todo lo que haya dentro de una caja (lava, ola del tsunami...)
function Destruction.DamageBox(cframe, size, damage, opts)
	if not S then
		return 0
	end
	opts = opts or {}
	local broken = 0
	local hits = workspace:GetPartBoundsInBox(cframe, size, S.params)
	local limit = opts.maxParts or 80
	local impulse = opts.impulse
	local count = 0
	for _, part in ipairs(hits) do
		local id = S.ids[part]
		if id and S.alive[id] then
			count = count + 1
			if count > limit then
				break
			end
			if damageId(id, damage, impulse, opts) then
				broken = broken + 1
			end
		end
	end
	return broken
end

-- Terremoto: golpes aleatorios repartidos por el mapa, mas fuertes cuanto mas alto esta la pieza
function Destruction.Shake(intensity)
	if not S or S.count == 0 then
		return
	end
	local hits = math.floor(14 * intensity)
	for _ = 1, hits do
		local id = math.random(S.count)
		if S.alive[id] and not S.fixed[id] then
			local part = S.parts[id]
			local height = math.max(0, part.Position.Y - S.floorY)
			local dmg = (18 + height * 0.6) * intensity
			damageId(id, dmg, Vector3.new(math.random(-12, 12), 6, math.random(-12, 12)))
		end
	end
end

-- Pieza al azar que este a la vista desde el cielo (para lluvia acida, granizo...)
function Destruction.RandomTopPart(x, z, topY)
	if not S then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { S.folder }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(Vector3.new(x, topY, z), Vector3.new(0, -(topY - S.floorY + 50), 0), params)
	return hit and hit.Instance or nil
end

-- ======================================================================
-- Fuego que se propaga por la madera
-- ======================================================================
local MAX_BURNING = 45

function Destruction.Ignite(part)
	if not S then
		return false
	end
	local id = S.ids[part]
	if not id or not S.alive[id] or S.fixed[id] or S.burning[id] or S.burningCount >= MAX_BURNING then
		return false
	end
	if not FLAMMABLE[matName(part)] then
		return false
	end
	local fire = Instance.new("Fire")
	fire.Size = math.clamp(math.max(part.Size.X, part.Size.Z), 4, 14)
	fire.Heat = 9
	fire.Parent = part
	S.burning[id] = { t = clock(), fire = fire }
	S.burningCount = S.burningCount + 1
	return true
end

function Destruction.IgniteSphere(center, radius, chance)
	if not S then
		return 0
	end
	local n = 0
	for _, part in ipairs(workspace:GetPartBoundsInRadius(center, radius, S.params)) do
		if math.random() < (chance or 0.5) and Destruction.Ignite(part) then
			n = n + 1
		end
	end
	return n
end

function Destruction.BurningCount()
	return S and S.burningCount or 0
end

local function updateFires(dt)
	if not S then
		return
	end
	local now = clock()
	-- copia de las claves: el fuego se propaga (anade entradas) mientras se recorre
	local ids = {}
	for id in pairs(S.burning) do
		ids[#ids + 1] = id
	end
	for _, id in ipairs(ids) do
		local b = S and S.burning[id]
		local part = b and S.parts[id]
		if not b then
			-- ya se apago o se rompio en esta misma vuelta
		elseif not S.alive[id] or not part.Parent then
			if b.fire and b.fire.Parent then
				b.fire:Destroy()
			end
			S.burning[id] = nil
			S.burningCount = S.burningCount - 1
		else
			-- quema poco a poco y se propaga a los vecinos inflamables
			damageId(id, 10 * dt, nil, { burnt = true })
			if now - b.t > 3 and math.random() < 0.25 * dt * 4 then
				local list = S.neigh[id]
				if list and #list > 0 then
					local j = list[math.random(#list)]
					if S.alive[j] then
						Destruction.Ignite(S.parts[j])
					end
				end
			end
		end
	end
end

-- ======================================================================
-- Derrumbes
-- ======================================================================

local CLUSTER = 16

local function collapseComponent(component)
	-- agrupar por celdas para soldar bloques que caen juntos
	local cells = {}
	local order = {}
	for _, id in ipairs(component) do
		local p = S.parts[id]
		if p.Parent then
			local pos = p.Position
			local key = math.floor(pos.X / CLUSTER) .. ":" .. math.floor(pos.Y / CLUSTER) .. ":" .. math.floor(pos.Z / CLUSTER)
			local cell = cells[key]
			if not cell then
				cell = {}
				cells[key] = cell
				order[#order + 1] = cell
			end
			cell[#cell + 1] = id
		end
	end
	for _, cell in ipairs(order) do
		for _, id in ipairs(cell) do
			S.alive[id] = false
		end
		S.collapsed = S.collapsed + #cell
		if #cell <= 40 and PhysicsBudget.CanAdd(1) then
			local parts = {}
			local welds = {}
			local root = S.parts[cell[1]]
			for _, id in ipairs(cell) do
				local p = S.parts[id]
				parts[#parts + 1] = p
				if p ~= root then
					local w = Instance.new("WeldConstraint")
					w.Part0 = root
					w.Part1 = p
					w.Parent = root
					welds[#welds + 1] = w
				end
			end
			PhysicsBudget.Add(parts, welds)
			root.AssemblyLinearVelocity = Vector3.new(math.random(-4, 4), -6, math.random(-4, 4))
			root.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
		else
			for _, id in ipairs(cell) do
				local p = S.parts[id]
				if p.Parent then
					shatter(p)
				end
			end
		end
	end
end

-- Piezas que ahora mismo no estan unidas a ninguna raiz (para depurar mapas: deberia ser 0 al cargar)
function Destruction.FindUnsupported()
	if not S or not S.graphReady then
		return {}
	end
	local reached, queue, head = {}, {}, 1
	for id = 1, S.count do
		if S.alive[id] and S.root[id] then
			reached[id] = true
			queue[#queue + 1] = id
		end
	end
	while head <= #queue do
		local id = queue[head]
		head = head + 1
		for _, j in ipairs(S.neigh[id] or {}) do
			if S.alive[j] and not reached[j] then
				reached[j] = true
				queue[#queue + 1] = j
			end
		end
	end
	local out = {}
	for id = 1, S.count do
		if S.alive[id] and not reached[id] then
			out[#out + 1] = S.parts[id]
		end
	end
	return out
end

-- BFS desde las raices: todo lo vivo que no se alcance esta colgando y se derrumba
function Destruction.CheckSupport()
	if not S or not S.graphReady or not S.dirty then
		return 0
	end
	S.dirty = false
	local alive, neigh, root = S.alive, S.neigh, S.root
	local reached = {}
	local queue = {}
	local head = 1
	for id = 1, S.count do
		if alive[id] and root[id] then
			reached[id] = true
			queue[#queue + 1] = id
		end
	end
	while head <= #queue do
		local id = queue[head]
		head = head + 1
		local list = neigh[id]
		if list then
			for _, j in ipairs(list) do
				if alive[j] and not reached[j] then
					reached[j] = true
					queue[#queue + 1] = j
				end
			end
		end
	end
	-- componentes sin apoyo
	local fallen = 0
	local visited = {}
	for id = 1, S.count do
		if alive[id] and not reached[id] and not visited[id] then
			local comp = { id }
			visited[id] = true
			local h = 1
			while h <= #comp do
				local cur = comp[h]
				h = h + 1
				local list = neigh[cur]
				if list then
					for _, j in ipairs(list) do
						if alive[j] and not reached[j] and not visited[j] then
							visited[j] = true
							comp[#comp + 1] = j
						end
					end
				end
			end
			fallen = fallen + #comp
			collapseComponent(comp)
		end
	end
	return fallen
end

-- ======================================================================
-- Bucle: borrado diferido, envio de anicos a los clientes, fuego y derrumbes
-- ======================================================================
local collapseAcc, fireAcc = 0, 0

RunService.Heartbeat:Connect(function(dt)
	if not S then
		return
	end
	-- anicos -> clientes (en lote)
	local q = S.shatterQueue
	if #q > 0 then
		local batch = {}
		local n = math.min(#q, Config.MaxShatterPerFlush)
		for i = 1, n do
			batch[i] = q[i]
		end
		S.shatterQueue = {}
		ShatterEvent:FireAllClients(batch)
	end
	-- borrado repartido
	local rq = S.removeQueue
	local limit = Config.HidePerFrame
	local removed = 0
	while S.removeHead <= #rq and removed < limit do
		local p = rq[S.removeHead]
		rq[S.removeHead] = nil
		S.removeHead = S.removeHead + 1
		if p and p.Parent then
			p:Destroy()
		end
		removed = removed + 1
	end
	if S.removeHead > #rq then
		S.removeQueue = {}
		S.removeHead = 1
	end
	-- fuego
	fireAcc = fireAcc + dt
	if fireAcc >= 0.5 then
		updateFires(fireAcc)
		fireAcc = 0
	end
	-- derrumbes
	collapseAcc = collapseAcc + dt
	if collapseAcc >= Config.CollapseInterval then
		collapseAcc = 0
		Destruction.CheckSupport()
	end
end)

return Destruction
]=])

	add("ServerScriptService", { "IslasServer", "Disasters" }, "AcidRain", "ModuleScript", [[
-- Lluvia acida: quema a quien este a cielo abierto (el paraguas protege) y corroe los tejados poco a poco,
-- abriendo agujeros: los refugios dejan de ser seguros con el tiempo.
return {
	Run = function(ctx)
		ctx.setLighting({ FogColor = Color3.fromRGB(90, 140, 60), FogEnd = 450, Brightness = 1 })
		ctx.fx("tint", Color3.fromRGB(80, 200, 60), 0.86)
		ctx.fx("weather", "acid")
		local dt = 0.5
		local corrodeAcc = 0
		while ctx.active() do
			for _, entry in ipairs(ctx.players()) do
				if not ctx.holding(entry, "Paraguas") and not ctx.covered(entry) then
					ctx.damage(entry, (ctx.config.dps or 7) * dt * ctx.intensity)
				end
			end
			corrodeAcc = corrodeAcc + dt
			if corrodeAcc >= 0.6 then
				corrodeAcc = 0
				for _ = 1, math.ceil(4 * ctx.intensity) do
					local x, z = ctx.randomPoint()
					local part = ctx.D.RandomTopPart(x, z, ctx.bounds.top + 40)
					if part then
						ctx.D.Damage(part, 45, nil, { shatter = true })
					end
				end
			end
			task.wait(dt)
		end
	end,
}
]])

	add("ServerScriptService", { "IslasServer", "Disasters" }, "BlackHole", "ModuleScript", [[
-- Agujero negro: se mueve despacio por el mapa, atrae jugadores y piezas, arranca trozos de los edificios
-- y se traga todo lo que llega a su centro. Crece con el tiempo.
return {
	Run = function(ctx)
		local bb = ctx.bounds
		local points = {}
		for i = 1, 5 do
			local x, z = ctx.randomPoint()
			points[i] = { x, z }
		end
		local speed = 5 * math.min(ctx.intensity, 1.5)
		local path = ctx.Paths.Make(points, speed, ctx.time(), true)
		local height = ctx.config.height or 25
		ctx.fx("path", "BlackHole", { points = points, speed = speed, t0 = path.t0, loop = true, height = height })
		ctx.setLighting({ Brightness = 0.7, Ambient = Color3.fromRGB(60, 40, 90) })
		local dt = 0.1
		local tick = 0
		local baseY = bb.floor
		while ctx.active() do
			tick = tick + 1
			local x, z = ctx.Paths.At(path, ctx.time())
			if tick % 10 == 1 then
				baseY = ctx.groundY(x, z) or baseY
			end
			local center = Vector3.new(x, baseY + height, z)
			local grow = 1 + ctx.progress() * 0.8
			local pull = 80 * grow
			local horizon = 7 * grow
			for _, entry in ipairs(ctx.players()) do
				local off = center - entry.root.Position
				local d = off.Magnitude
				if d < horizon then
					ctx.kill(entry)
				elseif d < pull then
					local k = 1 - d / pull
					entry.root.AssemblyLinearVelocity = entry.root.AssemblyLinearVelocity * 0.6 + off.Unit * (25 + 60 * k) * ctx.intensity
				end
			end
			if tick % 3 == 0 then
				-- arranca piezas cerca y las atrae
				ctx.D.DamageSphere(center, 26 * grow, 90 * ctx.intensity, { fling = -60, maxParts = 30 })
				ctx.PB.ForEachBody(function(root)
					local off = center - root.Position
					local d = off.Magnitude
					if d < 8 then
						ctx.D.Remove(root)
					elseif d < pull * 1.3 then
						root.AssemblyLinearVelocity = off.Unit * (50 + 40 * (1 - d / (pull * 1.3)))
					end
				end)
			end
			task.wait(dt)
		end
	end,
}
]])

	add("ServerScriptService", { "IslasServer", "Disasters" }, "Blizzard", "ModuleScript", [[
-- Ventisca: frio extremo. A la intemperie pierdes vida (el paraguas ayuda); bajo techo o cerca de una
-- hoguera estas a salvo (las hogueras ademas curan). La nieve tapa la vista.
return {
	Run = function(ctx)
		ctx.setLighting({ FogColor = Color3.fromRGB(225, 235, 245), FogEnd = 180, FogStart = 10, Brightness = 1.4, ClockTime = 15 })
		ctx.fx("weather", "snow")
		ctx.fx("tint", Color3.fromRGB(200, 225, 255), 0.88)

		-- hogueras repartidas por el mapa
		local fires = {}
		for i = 1, 4 do
			local x, z = ctx.randomPoint()
			local y = ctx.groundY(x, z)
			if y then
				local base = ctx.build:Box("Hoguera", Vector3.new(4, 1, 4), Vector3.new(x, y + 0.5, z), Color3.fromRGB(90, 60, 40), Enum.Material.Wood, { indestructible = true })
				local f = Instance.new("Fire")
				f.Size = 8
				f.Heat = 12
				f.Parent = base
				ctx.Util.AddLight(base, 26, 3, Color3.fromRGB(255, 170, 80))
				fires[#fires + 1] = base.Position
			end
		end
		ctx.fx("markers", fires, Color3.fromRGB(255, 170, 80))

		local dt = 0.5
		while ctx.active() do
			local cold = (3 + ctx.progress() * 4) * ctx.intensity
			for _, entry in ipairs(ctx.players()) do
				local pos = entry.root.Position
				local warm = false
				for _, f in ipairs(fires) do
					if (pos - f).Magnitude < 13 then
						warm = true
						break
					end
				end
				if warm then
					entry.humanoid.Health = math.min(entry.humanoid.MaxHealth, entry.humanoid.Health + 4 * dt)
				elseif not ctx.covered(entry) then
					local k = ctx.holding(entry, "Paraguas") and 0.35 or 1
					ctx.damage(entry, cold * k * dt)
				end
			end
			-- el hielo rompe cristales y piezas finas
			if math.random() < 0.5 then
				local x, z = ctx.randomPoint()
				local part = ctx.D.RandomTopPart(x, z, ctx.bounds.top + 40)
				if part and part.Material == Enum.Material.Glass then
					ctx.D.Break(part, nil, { shatter = true })
				end
			end
			task.wait(dt)
		end
	end,
}
]])

	add("ServerScriptService", { "IslasServer", "Disasters" }, "Earthquake", "ModuleScript", [[
-- Terremoto: oleadas de temblores cada vez mas fuertes. Rompe piezas por todo el mapa (mas arriba = mas dano),
-- lo que provoca derrumbes reales. Tira a los jugadores al suelo de vez en cuando.
return {
	Run = function(ctx)
		while ctx.active() do
			local wave = 0.55 + 0.85 * math.abs(math.sin(ctx.elapsed() * 0.33))
			local k = (0.45 + ctx.progress() * 1.25) * wave * ctx.intensity
			ctx.fx("shake", 0.3 + k * 0.9, 1.1)
			ctx.D.Shake(k)
			if math.random() < 0.07 * k then
				for _, entry in ipairs(ctx.players()) do
					if math.random() < 0.5 then
						entry.humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
					end
				end
			end
			task.wait(0.5)
		end
	end,
}
]])

	add("ServerScriptService", { "IslasServer", "Disasters" }, "Fire", "ModuleScript", [[
-- Incendio: focos que crecen y prenden fuego a la madera, la tela y la hierba. El fuego se propaga por los
-- edificios (Destruction) y lo que se quema acaba cayendo.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		task.spawn(function()
			while ctx.active() do
				-- chispas que prenden cerca de los jugadores
				local x, z = ctx.targetPoint(0.6, 25)
				local y = ctx.groundY(x, z) or ctx.bounds.floor
				ctx.D.IgniteSphere(Vector3.new(x, y, z), 12, 0.6)
				task.wait(ctx.rate(3))
			end
		end)
		Hazards.Zones(ctx, {
			color = Color3.fromRGB(255, 110, 30),
			fire = true,
			dps = 14,
			startRadius = 5,
			maxRadius = 22,
			growth = 0.8,
			interval = 6,
			maxZones = 8,
			ignite = true,
			partDamage = 15,
		})
	end,
}
]])

	add("ServerScriptService", { "IslasServer", "Disasters" }, "Flood", "ModuleScript", [[
-- Inundacion: el agua sube hasta la altura que diga el mapa. Abajo te ahogas poco a poco.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		Hazards.Liquid(ctx, {
			color = Color3.fromRGB(40, 120, 200),
			material = "SmoothPlastic",
			transparency = 0.35,
			maxHeight = 40,
			lethal = false,
			dps = 15,
		})
	end,
}
]])

	add("ServerScriptService", { "IslasServer", "Disasters" }, "Lava", "ModuleScript", [[
-- Lava: sube, derrite lo que toca (los edificios se hunden desde abajo) y mata al instante.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		ctx.setLighting({ OutdoorAmbient = Color3.fromRGB(150, 90, 60) })
		Hazards.Liquid(ctx, {
			color = Color3.fromRGB(255, 90, 20),
			material = "Neon",
			transparency = 0.05,
			maxHeight = 40,
			lethal = true,
			melt = 90,
		})
	end,
}
]])

	add("ServerScriptService", { "IslasServer", "Disasters" }, "Lightning", "ModuleScript", [[
-- Tormenta electrica: rayos avisados con un anillo. Rompen lo que tocan y pueden prender fuego.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		ctx.setLighting({ Brightness = 0.5, FogEnd = 500, FogColor = Color3.fromRGB(55, 60, 75), Ambient = Color3.fromRGB(40, 40, 55), ClockTime = 19 })
		ctx.fx("weather", "rain")
		local cfg = ctx.config
		while ctx.active() do
			local x, z = ctx.targetPoint(0.7, 8)
			Hazards.Strike(ctx, x, z, {
				kind = "bolt",
				radius = cfg.radius or 9,
				damage = cfg.damage or 70,
				warn = 1.1,
				partDamage = 140,
				fling = 35,
				ignite = 0.5,
				color = Color3.fromRGB(255, 235, 90),
				knockback = 30,
			})
			task.wait(ctx.rate(math.max(0.45, 1.3 - ctx.progress() * 0.7)))
		end
	end,
}
]])

	add("ServerScriptService", { "IslasServer", "Disasters" }, "Meteors", "ModuleScript", [[
-- Lluvia de meteoritos: cada vez mas frecuentes. Revientan tejados y paredes y a veces prenden fuego.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		local cfg = ctx.config
		while ctx.active() do
			local volley = 1 + math.floor(ctx.progress() * 2.5 * ctx.intensity)
			for _ = 1, volley do
				local x, z = ctx.targetPoint(0.6, 18)
				Hazards.Strike(ctx, x, z, {
					kind = "meteor",
					radius = cfg.radius or 14,
					damage = cfg.damage or 70,
					warn = 1.7,
					partDamage = 320,
					fling = 65,
					ignite = 0.25,
					size = 6 + math.random() * 4,
				})
			end
			task.wait(ctx.rate(math.max(0.6, 1.8 - ctx.progress() * 1.0)))
		end
	end,
}
]])

	add("ServerScriptService", { "IslasServer", "Disasters" }, "Radiation", "ModuleScript", [[
-- Fuga de radiacion: nubes verdes que aparecen y crecen. No rompen nada pero hacen dano dentro.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		ctx.setLighting({ Ambient = Color3.fromRGB(70, 110, 60) })
		Hazards.Zones(ctx, {
			color = Color3.fromRGB(110, 255, 80),
			fire = false,
			dps = 11,
			startRadius = 6,
			maxRadius = 28,
			growth = 1.1,
			interval = 6,
			maxZones = 8,
		})
	end,
}
]])

	add("ServerScriptService", { "IslasServer", "Disasters" }, "Sandstorm", "ModuleScript", [[
-- Tormenta de arena: viento que cambia de direccion y empuja a quien este fuera; la arena hace dano a la
-- intemperie (el paraguas reduce el dano) y arranca piezas ligeras de los tejados.
return {
	Run = function(ctx)
		ctx.setLighting({ FogColor = Color3.fromRGB(215, 175, 110), FogEnd = 160, FogStart = 5, Brightness = 1.6 })
		ctx.fx("weather", "sand")
		ctx.fx("tint", Color3.fromRGB(230, 180, 110), 0.85)
		local angle = math.random() * math.pi * 2
		local dt = 0.25
		local acc = 0
		while ctx.active() do
			angle = angle + (math.random() - 0.5) * 0.15
			local wind = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local strength = (18 + 22 * math.abs(math.sin(ctx.elapsed() * 0.4))) * ctx.intensity
			for _, entry in ipairs(ctx.players()) do
				if not ctx.covered(entry) then
					local v = entry.root.AssemblyLinearVelocity
					entry.root.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, v.Z) + wind * strength * dt * 2.2
					local k = ctx.holding(entry, "Paraguas") and 0.4 or 1
					ctx.damage(entry, 5 * k * dt * ctx.intensity)
				end
			end
			acc = acc + dt
			if acc >= 1 then
				acc = 0
				for _ = 1, 3 do
					local x, z = ctx.randomPoint()
					local part = ctx.D.RandomTopPart(x, z, ctx.bounds.top + 40)
					if part then
						ctx.D.Damage(part, 25 * ctx.intensity, wind * 60 + Vector3.new(0, 20, 0))
					end
				end
			end
			task.wait(dt)
		end
	end,
}
]])

	add("ServerScriptService", { "IslasServer", "Disasters" }, "Tornado", "ModuleScript", [[
-- Tornado: recorre el mapa siguiendo puntos de paso (los clientes lo dibujan con el mismo recorrido),
-- arrastra jugadores, arranca piezas y lanza por los aires los escombros sueltos.
return {
	Run = function(ctx)
		local cfg = ctx.config
		local radius = cfg.radius or 42
		local speed = (cfg.speed or 11) * math.min(ctx.intensity, 1.5)
		local points = {}
		for i = 1, 7 do
			local x, z = ctx.randomPoint()
			points[i] = { x, z }
		end
		local path = ctx.Paths.Make(points, speed, ctx.time(), true)
		ctx.fx("path", "Tornado", { points = points, speed = speed, t0 = path.t0, loop = true, radius = radius })
		ctx.setLighting({ Brightness = 0.9, FogEnd = 700, FogColor = Color3.fromRGB(110, 110, 115) })

		local baseY = ctx.bounds.floor
		local tick = 0
		local dt = 0.1
		while ctx.active() do
			tick = tick + 1
			local px, pz = ctx.Paths.At(path, ctx.time())
			if tick % 5 == 1 then
				baseY = ctx.groundY(px, pz) or baseY
			end
			local core = Vector3.new(px, baseY, pz)

			for _, entry in ipairs(ctx.players()) do
				local pos = entry.root.Position
				local off = Vector3.new(pos.X - px, 0, pos.Z - pz)
				local d = off.Magnitude
				if d < radius and pos.Y - baseY < 140 then
					local k = 1 - d / radius
					local inward = d > 0.1 and -off.Unit or Vector3.zero
					local tangent = d > 0.1 and Vector3.new(-off.Z, 0, off.X).Unit or Vector3.zero
					entry.root.AssemblyLinearVelocity = tangent * (32 * k + 8) + inward * (15 * k) + Vector3.new(0, 30 * k + 8, 0)
					ctx.damage(entry, 6 * dt * k)
				end
			end

			if tick % 3 == 0 then
				ctx.D.DamageSphere(core + Vector3.new(0, 10, 0), 22, 70 * ctx.intensity, { fling = 80, maxParts = 30 })
				ctx.PB.ForEachBody(function(root)
					local p = root.Position
					local ox, oz = p.X - px, p.Z - pz
					local dd = math.sqrt(ox * ox + oz * oz)
					if dd > 0.5 and dd < radius * 1.2 then
						root.AssemblyLinearVelocity = Vector3.new(-oz, 0, ox).Unit * 45 + Vector3.new(-ox, 0, -oz).Unit * 12 + Vector3.new(0, 35, 0)
					end
				end)
			end
			task.wait(dt)
		end
	end,
}
]])

	add("ServerScriptService", { "IslasServer", "Disasters" }, "Tsunami", "ModuleScript", [[
-- Tsunami: olas gigantes que cruzan el mapa de un lado a otro. Arrastran a los jugadores y destrozan los
-- edificios a su paso. Despues de cada ola el nivel del agua sube un poco.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		local bb = ctx.bounds
		local H = ctx.config.height or 34
		local thick = 30
		local speed = (ctx.config.speed or 32) * math.min(ctx.intensity, 1.4)
		local cx, cz = (bb.x1 + bb.x2) / 2, (bb.z1 + bb.z2) / 2
		local spanX, spanZ = bb.x2 - bb.x1, bb.z2 - bb.z1

		-- agua de fondo que va subiendo con cada ola
		task.spawn(function()
			Hazards.Liquid(ctx, {
				color = Color3.fromRGB(35, 110, 190),
				material = "SmoothPlastic",
				transparency = 0.35,
				maxHeight = ctx.config.maxHeight or (H * 0.45),
				lethal = false,
				dps = 12,
			})
		end)

		while ctx.active() do
			local dirs = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
			local dir = dirs[math.random(#dirs)]
			local along = dir.X ~= 0 and spanX or spanZ
			local width = (dir.X ~= 0 and spanZ or spanX) + 120
			local start = Vector3.new(cx, bb.floor, cz) - dir * (along / 2 + 60)
			local t0 = ctx.time() + 3
			local travel = (along + 140) / speed
			ctx.fx("wave", { start = start, dir = dir, speed = speed, t0 = t0, width = width, height = H, thick = thick, duration = travel })
			ctx.fx("shake", 0.6, 3)
			task.wait(3)
			local acc = 0
			while ctx.active() and ctx.time() < t0 + travel do
				local front = start + dir * speed * (ctx.time() - t0)
				-- jugadores dentro de la ola
				for _, entry in ipairs(ctx.players()) do
					local rel = entry.root.Position - front
					local behind = -(rel.X * dir.X + rel.Z * dir.Z)
					if behind > -2 and behind < thick and entry.root.Position.Y < bb.floor + H then
						Hazards.Push(entry, dir * 55 + Vector3.new(0, 18, 0))
						ctx.damage(entry, 40 * 0.2)
					end
				end
				acc = acc + 0.2
				if acc >= 0.4 then
					acc = 0
					local center = front - dir * 6 + Vector3.new(0, H / 2, 0)
					local size = dir.X ~= 0 and Vector3.new(12, H, width) or Vector3.new(width, H, 12)
					ctx.D.DamageBox(CFrame.new(center), size, 140 * ctx.intensity, { impulse = dir * 70 + Vector3.new(0, 15, 0), maxParts = 50 })
				end
				task.wait(0.2)
			end
			task.wait(ctx.rate(6))
		end
	end,
}
]])

	add("ServerScriptService", { "IslasServer", "Disasters" }, "UFO", "ModuleScript", [[
-- Invasion alienigena: ovnis que patrullan el mapa. Disparan laseres avisados y encienden rayos abductores:
-- quien se queda debajo sube hacia la nave y, si llega arriba, desaparece.
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		local bb = ctx.bounds
		local count = math.clamp(math.floor(2 * ctx.intensity + 0.5), 1, 4)
		local height = ctx.config.height or 70
		local ufos = {}
		for u = 1, count do
			local points = {}
			for i = 1, 5 do
				local x, z = ctx.randomPoint()
				points[i] = { x, z }
			end
			local speed = 14 + math.random() * 6
			local path = ctx.Paths.Make(points, speed, ctx.time(), true)
			ufos[u] = { path = path, beamUntil = 0 }
			ctx.fx("path", "UFO", { points = points, speed = speed, t0 = path.t0, loop = true, height = height, index = u })
		end
		ctx.setLighting({ Ambient = Color3.fromRGB(70, 100, 90), Brightness = 1 })
		local dt = 0.2
		local nextLaser, nextBeam = 0, 4
		while ctx.active() do
			local now = ctx.time()
			for u, ufo in ipairs(ufos) do
				local x, z = ctx.Paths.At(ufo.path, now)
				local top = bb.floor + height
				-- rayo abductor
				if now < ufo.beamUntil then
					for _, entry in ipairs(ctx.players()) do
						local p = entry.root.Position
						local dx, dz = p.X - x, p.Z - z
						if dx * dx + dz * dz < 10 * 10 then
							entry.root.AssemblyLinearVelocity = Vector3.new(-dx * 0.5, 28, -dz * 0.5)
							ctx.damage(entry, 10 * dt)
							if p.Y > top - 8 then
								ctx.kill(entry)
							end
						end
					end
				end
				ufo.x, ufo.z = x, z
			end
			if now >= nextBeam then
				local ufo = ufos[math.random(#ufos)]
				ufo.beamUntil = now + 4.5
				ctx.fx("beam", table.find(ufos, ufo), 4.5)
				nextBeam = now + ctx.rate(math.max(3, 7 - ctx.progress() * 3))
			end
			if now >= nextLaser then
				local ufo = ufos[math.random(#ufos)]
				if ufo.x then
					local tx, tz = ctx.targetPoint(0.7, 12)
					Hazards.Strike(ctx, tx, tz, {
						kind = "laser",
						from = Vector3.new(ufo.x, bb.floor + height - 4, ufo.z),
						radius = 7,
						damage = 35,
						warn = 1,
						partDamage = 110,
						fling = 30,
						color = Color3.fromRGB(80, 255, 140),
						knockback = 25,
					})
				end
				nextLaser = now + ctx.rate(math.max(0.5, 1.4 - ctx.progress() * 0.8))
			end
			task.wait(dt)
		end
	end,
}
]])

	add("ServerScriptService", { "IslasServer", "Disasters" }, "Virus", "ModuleScript", [[
-- Virus mortal: algunos jugadores se infectan y pierden vida poco a poco. Contagian a quien este cerca.
-- Las estaciones de cura (cruz verde) curan y quitan el virus. Con un solo jugador, el virus va mas lento.
local Players = game:GetService("Players")

return {
	Run = function(ctx)
		local infected = {} -- [player] = true
		local exposure = {} -- [player] = segundos cerca de un infectado
		local highlights = {}

		local function setInfected(player, on)
			if on == (infected[player] == true) then
				return
			end
			infected[player] = on or nil
			local char = player.Character
			if highlights[player] then
				highlights[player]:Destroy()
				highlights[player] = nil
			end
			if on and char then
				local h = Instance.new("Highlight")
				h.Name = "Virus"
				h.FillColor = Color3.fromRGB(110, 255, 90)
				h.OutlineColor = Color3.fromRGB(30, 120, 20)
				h.FillTransparency = 0.55
				h.Parent = char
				highlights[player] = h
			end
			ctx.fx("infected", player.UserId, on == true)
		end
		ctx.onStop(function()
			for p in pairs(infected) do
				setInfected(p, false)
			end
		end)

		-- estaciones de cura
		local stations = {}
		for i = 1, 3 do
			local x, z = ctx.randomPoint()
			local y = ctx.groundY(x, z)
			if y then
				local pad = ctx.build:Box("EstacionCura", Vector3.new(6, 0.6, 6), Vector3.new(x, y + 0.3, z), Color3.fromRGB(80, 255, 120), Enum.Material.Neon, { indestructible = true })
				ctx.build:Board("Cruz", "✚", Vector3.new(3, 3, 0.4), Vector3.new(x, y + 4, z), Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 200, 80))
				stations[#stations + 1] = pad.Position
			end
		end
		ctx.fx("markers", stations, Color3.fromRGB(80, 255, 120))

		-- paciente cero
		local list = ctx.players()
		local n = math.max(1, math.ceil(#list / 4))
		for i = 1, math.min(n, #list) do
			local j = math.random(#list)
			setInfected(list[j].player, true)
			table.remove(list, j)
		end

		local dt = 0.5
		local solo = #Players:GetPlayers() <= 1
		while ctx.active() do
			local entries = ctx.players()
			local sick = {}
			for _, e in ipairs(entries) do
				if infected[e.player] then
					sick[#sick + 1] = e
					ctx.damage(e, (solo and 0.9 or 1.6) * dt * ctx.intensity)
				end
			end
			for _, e in ipairs(entries) do
				local pos = e.root.Position
				-- curarse
				for _, s in ipairs(stations) do
					if (pos - s).Magnitude < 7 then
						if infected[e.player] then
							setInfected(e.player, false)
						end
						e.humanoid.Health = math.min(e.humanoid.MaxHealth, e.humanoid.Health + 6 * dt)
					end
				end
				-- contagio
				if not infected[e.player] then
					local near = false
					for _, s in ipairs(sick) do
						if (s.root.Position - pos).Magnitude < 9 then
							near = true
							break
						end
					end
					exposure[e.player] = near and (exposure[e.player] or 0) + dt or 0
					if exposure[e.player] >= 1.5 then
						setInfected(e.player, true)
						exposure[e.player] = 0
					end
				end
			end
			-- si se cura todo el mundo, vuelve a aparecer
			if #sick == 0 and #entries > 0 and math.random() < 0.08 then
				setInfected(entries[math.random(#entries)].player, true)
			end
			task.wait(dt)
		end
	end,
}
]])

	add("ServerScriptService", { "IslasServer", "Disasters" }, "Volcano", "ModuleScript", [[
-- Volcan: surge del suelo en un lado del mapa, tiembla y lanza bombas de lava cada vez mas a menudo.
-- Alrededor del crater se forman rios de lava (zonas mortales que crecen).
local Hazards = require(script.Parent.Parent.Hazards)

return {
	Run = function(ctx)
		local bb = ctx.bounds
		-- en un borde del mapa
		local side = math.random(4)
		local x, z
		if side == 1 then
			x, z = bb.x1 + 15, bb.z1 + math.random() * (bb.z2 - bb.z1)
		elseif side == 2 then
			x, z = bb.x2 - 15, bb.z1 + math.random() * (bb.z2 - bb.z1)
		elseif side == 3 then
			x, z = bb.x1 + math.random() * (bb.x2 - bb.x1), bb.z1 + 15
		else
			x, z = bb.x1 + math.random() * (bb.x2 - bb.x1), bb.z2 - 15
		end
		local y = ctx.groundY(x, z) or bb.floor
		local height = ctx.config.height or 55
		local layers = 6
		local rock = Color3.fromRGB(70, 55, 50)
		local parts = {}
		for i = 1, layers do
			local d = 80 - (i - 1) * 12
			local h = height / layers
			-- sale de debajo del suelo
			local p = ctx.build:Box("Volcan", Vector3.new(h, d, d), Vector3.new(x, y - height + (i - 0.5) * h, z), rock, Enum.Material.Basalt, {
				shape = Enum.PartType.Cylinder,
				rot = Vector3.new(0, 0, 90),
				indestructible = true,
			})
			parts[i] = p
		end
		local crater = ctx.build:Box("Crater", Vector3.new(1, 18, 18), Vector3.new(x, y - 0.5, z), Color3.fromRGB(255, 90, 20), Enum.Material.Neon, {
			shape = Enum.PartType.Cylinder,
			rot = Vector3.new(0, 0, 90),
			canCollide = false,
		})
		for _, p in ipairs(parts) do
			ctx.tween(p, 6, { Position = p.Position + Vector3.new(0, height, 0) })
		end
		ctx.tween(crater, 6, { Position = crater.Position + Vector3.new(0, height + 0.6, 0) })
		ctx.fx("shake", 1.6, 6)
		-- lo que hubiera donde sale el volcan se rompe
		ctx.D.DamageSphere(Vector3.new(x, y + 10, z), 40, 1000, { fling = 80 })
		task.wait(6)
		ctx.setLighting({ OutdoorAmbient = Color3.fromRGB(150, 80, 60), FogColor = Color3.fromRGB(90, 50, 40), FogEnd = 900 })
		local top = Vector3.new(x, y + height + 2, z)

		-- rios de lava alrededor
		task.spawn(function()
			Hazards.Zones(ctx, {
				center = Vector3.new(x, y, z),
				spread = 45,
				color = Color3.fromRGB(255, 80, 20),
				fire = true,
				dps = 45,
				startRadius = 6,
				maxRadius = 18,
				growth = 0.5,
				interval = 9,
				maxZones = 6,
				ignite = true,
				partDamage = 40,
			})
		end)

		while ctx.active() do
			local n = 1 + math.floor(ctx.progress() * 3 * ctx.intensity)
			for _ = 1, n do
				local tx, tz = ctx.targetPoint(0.55, 25)
				Hazards.Strike(ctx, tx, tz, {
					kind = "bomb",
					from = top,
					radius = 11,
					damage = 60,
					warn = 2.2,
					partDamage = 220,
					fling = 50,
					ignite = 0.6,
					color = Color3.fromRGB(255, 80, 20),
					size = 5,
				})
			end
			if math.random() < 0.3 then
				ctx.fx("shake", 0.8, 1.5)
			end
			task.wait(ctx.rate(math.max(0.9, 2.4 - ctx.progress() * 1.4)))
		end
	end,
}
]])

	add("ServerScriptService", { "IslasServer" }, "DisasterService", "ModuleScript", [=[
-- DisasterService: lanza desastres en la isla actual (uno o varios a la vez).
--   DisasterService.Start(MapService.GetCurrent(), duracion [, "Earthquake" [, opts]])
--       opts: intensity (1 = normal), delay (segundos de aviso), mystery (oculta el nombre hasta que empieza)
--       -> { Id, Name, Title, Icon, Description }
--   DisasterService.StopAll()   -- limpia efectos y restaura la luz (llamalo antes de MapService.Unload)
--   DisasterService.Pick(current, exclude) -> nombre al azar de los que admite el mapa
--
-- Cada desastre es un ModuleScript en IslasServer/Disasters con Run(ctx). Run se ejecuta en su propio hilo
-- y hace un bucle `while ctx.active() do ... end`. Los efectos visuales se dibujan en los clientes con ctx.fx
-- (sin piezas replicadas) y el dano/destruccion se calcula en el servidor.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local DisasterInfo = require(Shared:WaitForChild("DisasterInfo"))
local Paths = require(Shared:WaitForChild("Paths"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(ServerStorage:WaitForChild("IslasMapas"):WaitForChild("Lib"):WaitForChild("Util"))
local Destruction = require(script.Parent.Destruction)
local PhysicsBudget = require(script.Parent.PhysicsBudget)
local Disasters = script.Parent:WaitForChild("Disasters")

local DisasterFX = Net.Event("DisasterFX")

local DisasterService = {}

local active = {} -- contextos en curso
local nextId = 0

function DisasterService.GetNames()
	local names = {}
	for _, child in ipairs(Disasters:GetChildren()) do
		if child:IsA("ModuleScript") then
			names[#names + 1] = child.Name
		end
	end
	table.sort(names)
	return names
end

function DisasterService.Info(name)
	local info = DisasterInfo[name]
	if info then
		return info
	end
	return { Title = name, Icon = "⚠️", Desc = "", Color = Color3.new(1, 1, 1) }
end

function DisasterService.TitleOf(name)
	return DisasterService.Info(name).Title
end

function DisasterService.Pick(current, exclude)
	local options = {}
	for _, n in ipairs(current.Def.Disasters or {}) do
		if n ~= exclude and Disasters:FindFirstChild(n) then
			options[#options + 1] = n
		end
	end
	if #options == 0 then
		return nil
	end
	return options[math.random(#options)]
end

function DisasterService.Active()
	return active
end

-- Lleva este jugador el gear `name` equipado (en la mano)?
local function holding(char, name)
	local tool = char and char:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool.Name == name
end
DisasterService.Holding = holding

local function buildContext(current, duration, name, opts)
	nextId = nextId + 1
	local info = DisasterService.Info(name)
	local ctx = {
		id = nextId,
		name = name,
		info = info,
		Util = Util,
		D = Destruction,
		PB = PhysicsBudget,
		Paths = Paths,
		map = current,
		duration = duration,
		intensity = opts.intensity or 1,
		config = (current.Def.DisasterConfig and current.Def.DisasterConfig[name]) or {},
		stopped = false,
		bounds = current.Bounds,
	}
	ctx.startTime = workspace:GetServerTimeNow()
	ctx.endTime = ctx.startTime + duration

	local folder = Instance.new("Folder")
	folder.Name = "EfectosDesastre"
	folder.Parent = workspace
	ctx.folder = folder
	ctx.build = Util.newBuilder(folder, Vector3.new(0, 0, 0))

	local stopCallbacks = {}
	function ctx.onStop(fn)
		stopCallbacks[#stopCallbacks + 1] = fn
	end
	ctx.stopCallbacks = stopCallbacks

	function ctx.time()
		return workspace:GetServerTimeNow()
	end
	function ctx.elapsed()
		return workspace:GetServerTimeNow() - ctx.startTime
	end
	function ctx.progress()
		return math.clamp(ctx.elapsed() / ctx.duration, 0, 1)
	end
	function ctx.active()
		return not ctx.stopped and workspace:GetServerTimeNow() < ctx.endTime
	end
	-- intervalo ajustado por intensidad (mas intensidad = mas a menudo)
	function ctx.rate(seconds)
		return seconds / ctx.intensity
	end

	function ctx.players()
		local list = {}
		local bb = ctx.bounds
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				local pos = root.Position
				if pos.X > bb.x1 - 60 and pos.X < bb.x2 + 60 and pos.Z > bb.z1 - 60 and pos.Z < bb.z2 + 60
					and pos.Y > bb.floor - 80 and pos.Y < bb.top + 150 then
					list[#list + 1] = { player = p, humanoid = hum, root = root, char = char }
				end
			end
		end
		return list
	end

	function ctx.damage(entry, amount)
		if entry.humanoid.Health > 0 and amount > 0 then
			entry.humanoid:SetAttribute("Causa", info.Title)
			entry.humanoid:TakeDamage(amount)
		end
	end
	function ctx.kill(entry)
		if entry.humanoid.Health > 0 and not entry.char:FindFirstChildOfClass("ForceField") then
			entry.humanoid:SetAttribute("Causa", info.Title)
			entry.humanoid.Health = 0
		end
	end
	function ctx.holding(entry, gear)
		return holding(entry.char, gear)
	end

	function ctx.randomPoint()
		local bb = ctx.bounds
		return bb.x1 + math.random() * (bb.x2 - bb.x1), bb.z1 + math.random() * (bb.z2 - bb.z1)
	end
	-- punto cerca de un jugador al azar (con probabilidad prob) o al azar en el mapa
	function ctx.targetPoint(prob, spread)
		local list = ctx.players()
		if #list > 0 and math.random() < (prob or 0.5) then
			local p = list[math.random(#list)].root.Position
			local bb = ctx.bounds
			local s = spread or 20
			return math.clamp(p.X + (math.random() - 0.5) * 2 * s, bb.x1, bb.x2), math.clamp(p.Z + (math.random() - 0.5) * 2 * s, bb.z1, bb.z2)
		end
		return ctx.randomPoint()
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { current.Folder }
	rayParams.RespectCanCollide = true
	ctx.rayParams = rayParams

	function ctx.groundY(x, z)
		local bb = ctx.bounds
		local hit = workspace:Raycast(Vector3.new(x, bb.top + 30, z), Vector3.new(0, -(bb.top - bb.floor + 200), 0), rayParams)
		return hit and hit.Position.Y or nil
	end
	-- hay techo encima de este jugador?
	function ctx.covered(entry, height)
		local origin = entry.root.Position + Vector3.new(0, 2.5, 0)
		return workspace:Raycast(origin, Vector3.new(0, height or 300, 0), rayParams) ~= nil
	end

	function ctx.fx(kind, ...)
		DisasterFX:FireAllClients(kind, ctx.id, ...)
	end

	function ctx.tween(inst, seconds, goal)
		TweenService:Create(inst, TweenInfo.new(seconds, Enum.EasingStyle.Linear), goal):Play()
	end

	local savedLight = {}
	function ctx.setLighting(props)
		for prop, value in pairs(props) do
			if savedLight[prop] == nil then
				savedLight[prop] = Lighting[prop]
			end
			Lighting[prop] = value
		end
	end
	ctx.onStop(function()
		for prop, value in pairs(savedLight) do
			Lighting[prop] = value
		end
	end)

	return ctx
end

local function stopContext(ctx)
	if ctx.stopped then
		return
	end
	ctx.stopped = true
	for i = #ctx.stopCallbacks, 1, -1 do
		pcall(ctx.stopCallbacks[i])
	end
	ctx.folder:Destroy()
	DisasterFX:FireAllClients("end", ctx.id)
	for i, c in ipairs(active) do
		if c == ctx then
			table.remove(active, i)
			break
		end
	end
end

function DisasterService.StopAll()
	for i = #active, 1, -1 do
		stopContext(active[i])
	end
	DisasterFX:FireAllClients("clear")
end
DisasterService.Stop = DisasterService.StopAll

function DisasterService.Start(current, duration, name, opts)
	opts = opts or {}
	if not current or not current.Def then
		return nil
	end
	name = name or DisasterService.Pick(current)
	if not name then
		return nil
	end
	local module = Disasters:FindFirstChild(name)
	if not module then
		warn("DisasterService: no existe el desastre '" .. tostring(name) .. "'")
		return nil
	end
	local disaster = require(module)
	local delay = opts.delay or Config.DisasterDelay
	local ctx = buildContext(current, duration + delay, name, opts)
	active[#active + 1] = ctx
	local info = ctx.info

	local shown = opts.mystery and DisasterInfo.Mystery or info
	DisasterFX:FireAllClients("banner", ctx.id, {
		Title = shown.Title,
		Desc = shown.Desc,
		Icon = shown.Icon,
		Color = shown.Color,
	}, delay)

	task.spawn(function()
		task.wait(delay)
		if ctx.stopped then
			return
		end
		ctx.startTime = workspace:GetServerTimeNow()
		ctx.duration = math.max(1, ctx.endTime - ctx.startTime)
		if opts.mystery then
			DisasterFX:FireAllClients("banner", ctx.id, { Title = info.Title, Desc = info.Desc, Icon = info.Icon, Color = info.Color }, 0)
		end
		DisasterFX:FireAllClients("start", ctx.id, name)
		local ok, err = pcall(disaster.Run, ctx)
		if not ok then
			warn("DisasterService: error en el desastre " .. name .. ": " .. tostring(err))
		end
	end)

	return { Id = ctx.id, Name = name, Title = info.Title, Icon = info.Icon, Description = info.Desc, Color = info.Color }
end

return DisasterService
]=])

	add("ServerScriptService", { "IslasServer" }, "GameLoop", "ModuleScript", [[
-- GameLoop: el ciclo de partida.
--   Descanso en el lobby -> votacion -> se construye la isla -> aviso -> ronda con desastre(s) -> resultados
-- Cada ronda puede traer un modificador (doble desastre, monedas x2, noche, gravedad baja...), un desastre
-- sorpresa o un segundo desastre a mitad de ronda. Sobrevivir da monedas, XP y racha.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Modifiers = require(Shared:WaitForChild("Modifiers"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))

local S = script.Parent
local MapService = require(S.MapService)
local VoteService = require(S.VoteService)
local DisasterService = require(S.DisasterService)
local Destruction = require(S.Destruction)
local PlayerData = require(S.PlayerData)
local Rewards = require(S.Rewards)
local Gear = require(S.Gear)
local CoinDrops = require(S.CoinDrops)
local Lobby = require(S.Lobby)

local RoundState = Net.Event("RoundState")
local RoundStatus = Net.Event("RoundStatus")
local RoundResults = Net.Event("RoundResults")
local KillFeed = Net.Event("KillFeed")
local PlaySound = Net.Event("PlaySound")

local GameLoop = {}

local state = {
	Phase = "Intermission",
	Status = "",
	EndsAt = 0,
	Map = nil,
	Disasters = {},
	Modifier = nil,
	Alive = 0,
	Total = 0,
	AliveIds = {},
}
GameLoop.State = state

local participants = {} -- [player] = { alive = bool, conn }

-- Para pruebas (comandos de administrador)
local forced = { map = nil, disaster = nil, skip = false }
function GameLoop.ForceMap(name)
	forced.map = name
end
function GameLoop.ForceDisaster(name)
	forced.disaster = name
end
function GameLoop.Skip()
	forced.skip = true
end

local function now()
	return workspace:GetServerTimeNow()
end

local function broadcast()
	RoundState:FireAllClients(state)
end

local function setPhase(phase, seconds, status)
	state.Phase = phase
	state.Status = status or ""
	state.EndsAt = seconds and (now() + seconds) or 0
	broadcast()
	RoundStatus:FireAllClients(status, seconds and state.EndsAt or nil)
	Lobby.SetStatus(status, seconds and Format.Time(seconds) or "")
end

-- espera actualizando el temporizador del lobby
local function countdown(seconds, status)
	local endAt = now() + seconds
	forced.skip = false
	while now() < endAt and not forced.skip do
		Lobby.SetStatus(status, Format.Time(endAt - now()))
		task.wait(math.min(1, math.max(0.05, endAt - now())))
	end
end

local function refreshAlive()
	local alive, ids, total = 0, {}, 0
	for player, p in pairs(participants) do
		total = total + 1
		if p.alive then
			alive = alive + 1
			ids[#ids + 1] = player.UserId
		end
	end
	if alive ~= state.Alive or total ~= state.Total then
		state.Alive, state.Total, state.AliveIds = alive, total, ids
		broadcast()
	end
	return alive
end

local function pickModifier()
	if math.random() > Config.ModifierChance then
		return nil
	end
	local total = 0
	for _, m in ipairs(Modifiers) do
		total = total + (m.Weight or 1)
	end
	local r = math.random() * total
	for _, m in ipairs(Modifiers) do
		r = r - (m.Weight or 1)
		if r <= 0 then
			return m
		end
	end
	return Modifiers[1]
end

-- ======================================================================
-- Modificadores
-- ======================================================================
local revert = {}

local function applyModifier(mod, list)
	table.clear(revert)
	Rewards.Multiplier = 1
	if not mod then
		return 1
	end
	local intensity = 1
	if mod.Id == "Monedas2" then
		Rewards.Multiplier = 2
	elseif mod.Id == "Hiper" then
		intensity = 1.6
		Rewards.Multiplier = 1.5
	elseif mod.Id == "Noche" then
		local old = { ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, OutdoorAmbient = Lighting.OutdoorAmbient }
		Lighting.ClockTime = 0
		Lighting.Brightness = 0.2
		Lighting.OutdoorAmbient = Color3.fromRGB(25, 25, 40)
		revert[#revert + 1] = function()
			for k, v in pairs(old) do
				Lighting[k] = v
			end
		end
	elseif mod.Id == "GravedadBaja" then
		local old = workspace.Gravity
		workspace.Gravity = 75
		revert[#revert + 1] = function()
			workspace.Gravity = old
		end
	elseif mod.Id == "Velocidad" then
		for _, player in ipairs(list) do
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:SetAttribute("VelocidadBase", 26)
				hum.WalkSpeed = 26
			end
		end
		revert[#revert + 1] = function()
			for _, player in ipairs(list) do
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum:SetAttribute("VelocidadBase", nil)
					hum.WalkSpeed = 16
				end
			end
		end
	elseif mod.Id == "Niebla" then
		local old = { FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor }
		Lighting.FogStart = 0
		Lighting.FogEnd = 90
		Lighting.FogColor = Color3.fromRGB(190, 190, 200)
		revert[#revert + 1] = function()
			for k, v in pairs(old) do
				Lighting[k] = v
			end
		end
	elseif mod.Id == "Fragil" then
		Destruction.SetToughness(0.35)
	end
	return intensity
end

local function revertModifier()
	for i = #revert, 1, -1 do
		pcall(revert[i])
	end
	table.clear(revert)
	Rewards.Multiplier = 1
end

-- ======================================================================
-- Ronda
-- ======================================================================
local function onDeath(player)
	local p = participants[player]
	if not p or not p.alive then
		return
	end
	p.alive = false
	player:SetAttribute("EnRonda", nil)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local cause = hum and hum:GetAttribute("Causa") or "Caida"
	KillFeed:FireAllClients({ Name = player.DisplayName, Cause = cause, UserId = player.UserId })
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		PlaySound:FireAllClients("Death", hrp.Position, 0.8)
	end
	refreshAlive()
end

local function prepareParticipant(player, mod)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false
	end
	local data = PlayerData.Get(player)
	hum.MaxHealth = (data and data.Owned.VidaExtra) and 125 or 100
	hum.Health = hum.MaxHealth
	hum:SetAttribute("Causa", nil)
	player:SetAttribute("EnRonda", true)
	Gear.Give(player, (mod and mod.Id == "Noche") and { "Linterna" } or nil)
	local conn = hum.Died:Connect(function()
		onDeath(player)
	end)
	participants[player] = { alive = true, conn = conn }
	return true
end

local function playRound(winner)
	local info = MapService.GetInfo(winner)
	setPhase("Loading", nil, "Construyendo " .. info.Title .. "...")
	local ok, err = pcall(MapService.Load, winner)
	if not ok then
		warn("GameLoop: error construyendo " .. winner .. ": " .. tostring(err))
		MapService.Unload()
		task.wait(2)
		return
	end
	local current = MapService.GetCurrent()

	local mod = pickModifier()
	state.Map = info.Title
	state.Modifier = mod and { Id = mod.Id, Title = mod.Title, Desc = mod.Desc, Color = mod.Color } or nil
	state.Disasters = {}

	-- participantes: todos los que estan vivos en el lobby
	table.clear(participants)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if prepareParticipant(player, mod) then
			list[#list + 1] = player
		end
	end
	local intensity = applyModifier(mod, list)
	MapService.TeleportToMap(list)
	refreshAlive()

	-- desastres
	local disasters = {}
	if Config.EnableDisasters then
		local mystery = math.random() < Config.MysteryChance
		local first = DisasterService.Start(current, Config.RoundTime, forced.disaster, { intensity = intensity, mystery = mystery })
		forced.disaster = nil
		if first then
			disasters[#disasters + 1] = first
			state.Disasters[#state.Disasters + 1] = mystery and { Title = "???", Icon = "❓" } or { Title = first.Title, Icon = first.Icon }
		end
		if mod and mod.Id == "Doble" and first then
			local second = DisasterService.Start(current, Config.RoundTime, DisasterService.Pick(current, first.Name), { intensity = intensity, delay = Config.DisasterDelay + 4 })
			if second then
				disasters[#disasters + 1] = second
				state.Disasters[#state.Disasters + 1] = { Title = second.Title, Icon = second.Icon }
			end
		end
	end
	CoinDrops.SpawnRound(current, Config.CoinPickups)

	local total = Config.DisasterDelay + Config.RoundTime
	setPhase("Round", total, mod and (mod.Title .. " · " .. info.Title) or ("Sobrevive en " .. info.Title))

	local startT = now()
	local endT = startT + total
	local secondTried = false
	local nextTick = startT + Config.DisasterDelay + Config.AliveTickInterval
	forced.skip = false
	while now() < endT and not forced.skip do
		task.wait(0.5)
		-- revisar vivos (por si alguien salio del mapa o del juego)
		for player, p in pairs(participants) do
			if not player.Parent then
				if p.conn then
					p.conn:Disconnect()
				end
				participants[player] = nil
			elseif p.alive then
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if not hum or hum.Health <= 0 then
					onDeath(player)
				elseif now() > startT + 6 and not MapService.IsOnMap(player) then
					-- fuera del mapa (por ejemplo, cayo al vacio y reaparecio en el lobby)
					p.alive = false
					refreshAlive()
				end
			end
		end
		if refreshAlive() == 0 then
			break
		end
		-- monedas por seguir vivo
		if now() >= nextTick then
			nextTick = nextTick + Config.AliveTickInterval
			for player, p in pairs(participants) do
				if p.alive then
					Rewards.Give(player, Config.AliveTickCoins, 2, { text = "Sigues vivo" })
				end
			end
		end
		-- segundo desastre a mitad de ronda
		if not secondTried and Config.EnableDisasters and now() > startT + Config.DisasterDelay + Config.RoundTime * 0.45 then
			secondTried = true
			if #disasters == 1 and math.random() < Config.SecondDisasterChance then
				local remaining = endT - now()
				local extra = DisasterService.Start(current, remaining - 5, DisasterService.Pick(current, disasters[1].Name), { intensity = intensity, delay = 5 })
				if extra then
					disasters[#disasters + 1] = extra
					state.Disasters[#state.Disasters + 1] = { Title = extra.Title, Icon = extra.Icon }
					broadcast()
				end
			end
		end
	end

	DisasterService.StopAll()
	CoinDrops.Clear()

	-- ===== Resultados =====
	local survivors, names = {}, {}
	for player, p in pairs(participants) do
		if p.alive and player.Parent then
			survivors[#survivors + 1] = player
			names[#names + 1] = player.DisplayName
		end
	end
	local titles = {}
	for _, d in ipairs(disasters) do
		titles[#titles + 1] = d.Title
	end
	setPhase("Results", Config.ResultsTime, #survivors > 0 and ("Sobrevivieron " .. #survivors .. " de " .. state.Total) or "No sobrevivio nadie")

	local count = state.Total
	for player, p in pairs(participants) do
		if p.conn then
			p.conn:Disconnect()
		end
		local data = PlayerData.Get(player)
		if data and player.Parent then
			local result = { Map = info.Title, Disasters = titles, Survivors = names, Total = count, Modifier = mod and mod.Title or nil }
			Rewards.Stat(player, "Rounds", 1)
			if p.alive then
				local streak = data.Stats.Streak + 1
				data.Stats.Streak = streak
				data.Stats.BestStreak = math.max(data.Stats.BestStreak, streak)
				local coins = Config.SurviveCoins + math.min(streak - 1, Config.MaxStreakBonus) * Config.StreakBonusCoins
				local c, x = Rewards.Give(player, coins, Config.SurviveXP, { text = "¡Sobreviviste!", lucky = true })
				Rewards.Stat(player, "Wins", 1)
				Rewards.Collect(player, "MapsDone", winner, "MapsSurvived")
				for _, d in ipairs(disasters) do
					Rewards.Collect(player, "DisastersDone", d.Name, "DisastersSurvived")
				end
				if #survivors == 1 and count >= 3 then
					Rewards.Stat(player, "SoleSurvivor", 1)
				end
				if #disasters >= 2 then
					Rewards.Stat(player, "DoubleSurvived", 1)
				end
				result.Survived, result.Coins, result.XP, result.Streak = true, c, x, streak
			else
				data.Stats.Streak = 0
				Rewards.Stat(player, "Deaths", 1)
				local c, x = Rewards.Give(player, Config.ParticipationCoins, Config.ParticipationXP, { text = "Participacion" })
				result.Survived, result.Coins, result.XP, result.Streak = false, c, x, 0
			end
			RoundResults:FireClient(player, result)
		end
	end
	task.wait(Config.ResultsTime)

	-- vuelta al lobby
	local back = {}
	for player in pairs(participants) do
		if player.Parent then
			back[#back + 1] = player
			player:SetAttribute("EnRonda", nil)
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.MaxHealth = 100
				hum.Health = 100
			end
		end
	end
	revertModifier()
	MapService.ReturnToLobby(back)
	for _, player in ipairs(back) do
		task.spawn(Gear.Refresh, player)
	end
	table.clear(participants)
	state.Map, state.Modifier, state.Disasters = nil, nil, {}
	state.Alive, state.Total, state.AliveIds = 0, 0, {}
	task.wait(1)
	MapService.Unload()
end

function GameLoop.Run()
	while true do
		while #Players:GetPlayers() < Config.MinPlayers do
			setPhase("Waiting", nil, "Esperando jugadores...")
			task.wait(2)
		end
		setPhase("Intermission", Config.IntermissionTime, "Descanso: compra en la tienda o haz el obby")
		countdown(Config.IntermissionTime, "Siguiente ronda en")

		setPhase("Vote", Config.VoteTime, "¡Vota el siguiente mapa!")
		local winner
		if forced.map then
			winner, forced.map = forced.map, nil
		else
			winner = VoteService.Run(VoteService.PickOptions(Config.OptionsPerVote), Config.VoteTime)
		end

		local ok, err = pcall(playRound, winner)
		if not ok then
			warn("GameLoop: error en la ronda: " .. tostring(err))
			pcall(DisasterService.StopAll)
			pcall(revertModifier)
			pcall(MapService.ReturnToLobby)
			pcall(MapService.Unload)
			table.clear(participants)
			task.wait(3)
		end
	end
end

return GameLoop
]])

	add("ServerScriptService", { "IslasServer" }, "Gear", "ModuleScript", [[
-- Gear: crea las herramientas (gears) y estelas, y aplica sus efectos en el servidor.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)

local PlaySound = Net.Event("PlaySound")

local Gear = {}

local C = Color3.fromRGB
local V = Vector3.new

local function characterMass(char)
	local m = 0
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and not d.Massless then
			m = m + d:GetMass()
		end
	end
	return m
end

local function cooldown(tool, seconds)
	tool.Enabled = false
	tool:SetAttribute("RecargaHasta", workspace:GetServerTimeNow() + seconds)
	task.delay(seconds, function()
		if tool.Parent then
			tool.Enabled = true
		end
	end)
end

local function addForce(char, name, fraction)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local att = hrp:FindFirstChild("IslasFuerzaAtt") or Instance.new("Attachment")
	att.Name = "IslasFuerzaAtt"
	att.Parent = hrp
	local f = Instance.new("VectorForce")
	f.Name = name
	f.Attachment0 = att
	f.RelativeTo = Enum.ActuatorRelativeTo.World
	f.ApplyAtCenterOfMass = true
	f.Force = V(0, characterMass(char) * workspace.Gravity * fraction, 0)
	f.Parent = hrp
end

local function removeForce(char, name)
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local f = hrp and hrp:FindFirstChild(name)
	if f then
		f:Destroy()
	end
end

-- Velocidad base del jugador (la cambian los modificadores de ronda)
local function baseSpeed(hum)
	return hum:GetAttribute("VelocidadBase") or 16
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

-- ======================================================================
-- Fabricas de cada gear
-- ======================================================================
local builders = {}

local function baseTool(id)
	local item = Catalog.ById[id]
	local tool = Instance.new("Tool")
	tool.Name = id
	tool.ToolTip = item.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("IslasGear", true)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = V(0.6, 1.4, 0.6)
	handle.Color = item.Color or C(200, 200, 200)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	return tool, handle
end

builders.GloboVerde = function()
	local tool, handle = baseTool("GloboVerde")
	handle.Size = V(0.2, 2, 0.2)
	handle.Color = C(240, 240, 240)
	local balloon = Instance.new("Part")
	balloon.Name = "Globo"
	balloon.Shape = Enum.PartType.Ball
	balloon.Size = V(2.6, 2.6, 2.6)
	balloon.Color = C(80, 220, 80)
	balloon.Material = Enum.Material.SmoothPlastic
	balloon.CanCollide = false
	balloon.Massless = true
	balloon.CFrame = handle.CFrame + V(0, 2.2, 0)
	balloon.Parent = tool
	weld(handle, balloon)
	local char
	tool.Equipped:Connect(function()
		char = tool.Parent
		addForce(char, "IslasGlobo", 0.62)
	end)
	tool.Unequipped:Connect(function()
		removeForce(char, "IslasGlobo")
	end)
	return tool
end

builders.BobinaVelocidad = function()
	local tool = baseTool("BobinaVelocidad")
	local hum
	tool.Equipped:Connect(function()
		hum = tool.Parent:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = baseSpeed(hum) * 1.6
		end
	end)
	tool.Unequipped:Connect(function()
		if hum then
			hum.WalkSpeed = baseSpeed(hum)
		end
	end)
	return tool
end

builders.BobinaGravedad = function()
	local tool = baseTool("BobinaGravedad")
	local hum, char
	tool.Equipped:Connect(function()
		char = tool.Parent
		hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.UseJumpPower = false
			hum.JumpHeight = 16
		end
		addForce(char, "IslasGravedad", 0.45)
	end)
	tool.Unequipped:Connect(function()
		if hum then
			hum.JumpHeight = 7.2
		end
		removeForce(char, "IslasGravedad")
	end)
	return tool
end

builders.Linterna = function()
	local tool, handle = baseTool("Linterna")
	handle.Size = V(0.5, 0.5, 1.6)
	handle.Color = C(40, 40, 45)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = 60
	spot.Angle = 50
	spot.Brightness = 4
	spot.Parent = handle
	local glow = Instance.new("PointLight")
	glow.Range = 14
	glow.Brightness = 1
	glow.Parent = handle
	return tool
end

builders.Paraguas = function()
	local tool, handle = baseTool("Paraguas")
	handle.Size = V(0.2, 3, 0.2)
	handle.Color = C(40, 40, 50)
	local canopy = Instance.new("Part")
	canopy.Name = "Tela"
	canopy.Shape = Enum.PartType.Cylinder
	canopy.Size = V(0.4, 6, 6)
	canopy.Color = C(120, 160, 255)
	canopy.CanCollide = false
	canopy.Massless = true
	canopy.CFrame = (handle.CFrame + V(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	canopy.Parent = tool
	weld(handle, canopy)
	return tool
end

builders.Botiquin = function()
	local tool, handle = baseTool("Botiquin")
	handle.Size = V(1, 0.8, 1.2)
	handle.Color = C(240, 240, 240)
	tool.Activated:Connect(function()
		local hum = tool.Parent and tool.Parent:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and tool.Enabled then
			hum.Health = math.min(hum.MaxHealth, hum.Health + 40)
			cooldown(tool, 12)
			local player = Players:GetPlayerFromCharacter(tool.Parent)
			if player then
				PlaySound:FireClient(player, "Coin", nil, 0.6)
			end
		end
	end)
	return tool
end

builders.Jetpack = function()
	local tool, handle = baseTool("Jetpack")
	handle.Size = V(1, 1.4, 0.8)
	tool.Activated:Connect(function()
		local char = tool.Parent
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and tool.Enabled then
			local v = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = V(v.X, 80, v.Z)
			local fire = Instance.new("Fire")
			fire.Size = 4
			fire.Heat = 15
			fire.Parent = handle
			Debris:AddItem(fire, 1)
			cooldown(tool, 4)
		end
	end)
	return tool
end

builders.Escudo = function()
	local tool, handle = baseTool("Escudo")
	handle.Shape = Enum.PartType.Ball
	handle.Size = V(1, 1, 1)
	handle.Material = Enum.Material.Neon
	tool.Activated:Connect(function()
		local char = tool.Parent
		if char and tool.Enabled and not char:FindFirstChildOfClass("ForceField") then
			local ff = Instance.new("ForceField")
			ff.Visible = true
			ff.Parent = char
			Debris:AddItem(ff, 4)
			cooldown(tool, 45)
		end
	end)
	return tool
end

builders.Garfio = function()
	local tool, handle = baseTool("Garfio")
	handle.Size = V(0.4, 0.4, 1.8)
	return tool -- el disparo llega por GearAction (necesita el punto al que apunta el jugador)
end

local function onGearAction(player, id, target)
	if id ~= "Garfio" or typeof(target) ~= "Vector3" then
		return
	end
	local char = player.Character
	local tool = char and char:FindFirstChild("Garfio")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not tool or not hrp or not tool.Enabled then
		return
	end
	local off = target - hrp.Position
	if off.Magnitude > 140 or off.Magnitude < 3 then
		return
	end
	hrp.AssemblyLinearVelocity = off.Unit * 115 + V(0, 25, 0)
	cooldown(tool, 3)
	PlaySound:FireAllClients("Whoosh", hrp.Position, 0.7)
end

function Gear.Make(id)
	local b = builders[id]
	return b and b() or nil
end

-- ======================================================================
-- Repartir gears y estelas
-- ======================================================================
local function removeGears(player)
	for _, container in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		if container then
			for _, t in ipairs(container:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("IslasGear") then
					t:Destroy()
				end
			end
		end
	end
	if player.Character then
		removeForce(player.Character, "IslasGlobo")
		removeForce(player.Character, "IslasGravedad")
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = baseSpeed(hum)
			hum.JumpHeight = 7.2
		end
	end
end

-- Da al jugador sus gears equipados (y extras temporales, p. ej. la linterna de la ronda nocturna)
function Gear.Give(player, extras)
	local data = PlayerData.Get(player)
	local backpack = player:FindFirstChild("Backpack")
	if not data or not backpack then
		return
	end
	removeGears(player)
	local given = {}
	local slots = Catalog.GearSlots(data.Owned)
	for i, id in ipairs(data.Equipped.Gears or {}) do
		if i <= slots and data.Owned[id] and not given[id] then
			local tool = Gear.Make(id)
			if tool then
				tool.Parent = backpack
				given[id] = true
			end
		end
	end
	for _, id in ipairs(extras or {}) do
		if not given[id] then
			local tool = Gear.Make(id)
			if tool then
				tool:SetAttribute("Temporal", true)
				tool.Parent = backpack
				given[id] = true
			end
		end
	end
end

function Gear.ApplyTrail(player)
	local data = PlayerData.Get(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not data or not hrp then
		return
	end
	local old = hrp:FindFirstChild("IslasEstela")
	if old then
		old:Destroy()
	end
	for _, n in ipairs({ "IslasEstelaA", "IslasEstelaB" }) do
		local a = hrp:FindFirstChild(n)
		if a then
			a:Destroy()
		end
	end
	local id = data.Equipped.Trail
	local item = id and Catalog.ById[id]
	if not item or not data.Owned[id] then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "IslasEstelaA"
	a0.Position = V(0, 0.9, 0)
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Name = "IslasEstelaB"
	a1.Position = V(0, -0.9, 0)
	a1.Parent = hrp
	local keypoints = {}
	local n = #item.Colors
	for i, c in ipairs(item.Colors) do
		keypoints[i] = ColorSequenceKeypoint.new(n == 1 and 0 or (i - 1) / (n - 1), c)
	end
	if n == 1 then
		keypoints[2] = ColorSequenceKeypoint.new(1, item.Colors[1])
	end
	local trail = Instance.new("Trail")
	trail.Name = "IslasEstela"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(keypoints)
	trail.Lifetime = 0.6
	trail.LightEmission = 0.5
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = hrp
end

function Gear.Refresh(player)
	Gear.Give(player)
	Gear.ApplyTrail(player)
end

function Gear.Init()
	Net.Event("GearAction").OnServerEvent:Connect(onGearAction)
	local function onPlayer(player)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("HumanoidRootPart", 10)
			PlayerData.WaitFor(player, 15)
			task.wait(0.2)
			if player.Character == char then
				Gear.Refresh(player)
			end
		end)
		if player.Character then
			task.spawn(function()
				PlayerData.WaitFor(player, 15)
				Gear.Refresh(player)
			end)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return Gear
]])

	add("ServerScriptService", { "IslasServer" }, "Hazards", "ModuleScript", [[
-- Hazards: piezas comunes de los desastres.
--   Hazards.Strike(ctx, x, z, opts)   impacto avisado (meteorito, rayo, bomba de lava, laser)
--   Hazards.Zones(ctx, opts)          zonas que aparecen y crecen (fuego, radiacion, lava)
--   Hazards.Liquid(ctx, opts)         liquido que sube (inundacion, lava)
-- Todo lo visual se dibuja en los clientes (ctx.fx); aqui solo se calcula el dano.
local Hazards = {}

local function push(entry, velocity)
	entry.root.AssemblyLinearVelocity = velocity
end
Hazards.Push = push

-- opts: kind ("meteor", "bolt", "bomb", "laser"), radius, damage, warn (s), fall (s), from (Vector3 opcional),
--       partDamage, fling, ignite (prob), color, size
function Hazards.Strike(ctx, x, z, opts)
	opts = opts or {}
	local radius = opts.radius or 12
	local y = ctx.groundY(x, z) or ctx.bounds.floor
	local target = Vector3.new(x, y, z)
	local warn = opts.warn or 1.5
	local kind = opts.kind or "meteor"
	local color = opts.color or Color3.fromRGB(255, 70, 40)
	ctx.fx("marker", target, radius, color, warn)
	if kind == "meteor" or kind == "bomb" then
		local from = opts.from or (target + Vector3.new(math.random(-70, 70), ctx.bounds.top - y + 140, math.random(-70, 70)))
		ctx.fx("meteor", from, target, warn, opts.color or Color3.fromRGB(255, 120, 30), opts.size or 7)
	end
	task.delay(warn, function()
		if ctx.stopped then
			return
		end
		if kind == "bolt" or kind == "laser" then
			local from = opts.from or (target + Vector3.new(0, ctx.bounds.top - y + 160, 0))
			ctx.fx("bolt", from, target, kind == "laser" and Color3.fromRGB(80, 255, 140) or Color3.fromRGB(230, 240, 255))
		end
		ctx.fx("explosion", target, radius, color)
		for _, entry in ipairs(ctx.players()) do
			local off = entry.root.Position - target
			local d = off.Magnitude
			if d <= radius then
				ctx.damage(entry, (opts.damage or 60) * (1 - 0.6 * d / radius))
				if d > 0.5 and (opts.knockback or 50) > 0 then
					push(entry, off.Unit * (opts.knockback or 50) + Vector3.new(0, 35, 0))
				end
			end
		end
		if opts.partDamage ~= 0 then
			ctx.D.DamageSphere(target + Vector3.new(0, 2, 0), radius * 1.1, opts.partDamage or 200, { fling = opts.fling or 55 })
		end
		if opts.ignite and math.random() < opts.ignite then
			ctx.D.IgniteSphere(target, radius, 0.5)
		end
	end)
end

-- opts: color, fire, dps, startRadius, maxRadius, growth, interval, maxZones, ignite (bool), partDamage (por s)
function Hazards.Zones(ctx, opts)
	local zones = {}
	local lastSpawn = -math.huge
	local lastSync = 0
	local dt = 0.25
	local cfg = ctx.config
	local maxZones = math.floor((cfg.maxZones or opts.maxZones) * math.min(ctx.intensity, 1.6))
	local interval = ctx.rate(cfg.interval or opts.interval)
	local key = 0

	local function addZone()
		local x, z
		if opts.center then
			local a = math.random() * math.pi * 2
			local r = math.random() * (opts.spread or 30)
			x, z = opts.center.X + math.cos(a) * r, opts.center.Z + math.sin(a) * r
		else
			x, z = ctx.targetPoint(0.5, 30)
		end
		local y = ctx.groundY(x, z) or ctx.bounds.floor
		key = key + 1
		local zone = { key = key, pos = Vector3.new(x, y, z), radius = opts.startRadius }
		zones[#zones + 1] = zone
		ctx.fx("zone", key, zone.pos, zone.radius, opts.color, opts.fire == true)
	end

	while ctx.active() do
		local now = ctx.time()
		if #zones < maxZones and now - lastSpawn >= interval then
			lastSpawn = now
			addZone()
		end
		for _, z in ipairs(zones) do
			z.radius = math.min(opts.maxRadius, z.radius + opts.growth * ctx.intensity * dt)
		end
		if now - lastSync >= 1 then
			lastSync = now
			for _, z in ipairs(zones) do
				ctx.fx("zone", z.key, z.pos, z.radius, opts.color, opts.fire == true)
				if opts.ignite then
					ctx.D.IgniteSphere(z.pos, z.radius * 0.7, 0.35)
				end
				if opts.partDamage then
					ctx.D.DamageSphere(z.pos, z.radius * 0.8, opts.partDamage, { fling = 10, maxParts = 25 })
				end
			end
		end
		for _, entry in ipairs(ctx.players()) do
			local pos = entry.root.Position
			for _, z in ipairs(zones) do
				if (pos - z.pos).Magnitude <= z.radius then
					ctx.damage(entry, opts.dps * dt)
					break
				end
			end
		end
		task.wait(dt)
	end
end

-- opts: color, material (nombre), transparency, maxHeight, lethal, dps, melt (dano a piezas por s), rise (s)
function Hazards.Liquid(ctx, opts)
	local b = ctx.bounds
	local pad = 160
	local cx, cz = (b.x1 + b.x2) / 2, (b.z1 + b.z2) / 2
	local sx = math.min(2048, (b.x2 - b.x1) + pad * 2)
	local sz = math.min(2048, (b.z2 - b.z1) + pad * 2)
	local maxHeight = (ctx.config.maxHeight or opts.maxHeight)
	local y0 = b.floor - 2
	local y1 = b.floor + maxHeight
	local t0 = ctx.time()
	local rise = (opts.rise or ctx.duration * 0.85) / math.min(ctx.intensity, 1.5)
	ctx.fx("liquid", {
		cx = cx, cz = cz, sx = sx, sz = sz, y0 = y0, y1 = y1, t0 = t0, rise = rise,
		color = opts.color, material = opts.material or "SmoothPlastic", transparency = opts.transparency or 0.3,
	})
	local dt = 0.2
	local meltAcc = 0
	while ctx.active() do
		local level = ctx.Paths.Level(y0, y1, t0, rise, ctx.time())
		for _, entry in ipairs(ctx.players()) do
			if entry.root.Position.Y - 2.5 < level then
				if opts.lethal then
					ctx.kill(entry)
				else
					ctx.damage(entry, opts.dps * dt)
				end
			end
		end
		meltAcc = meltAcc + dt
		if opts.melt and meltAcc >= 1 then
			meltAcc = 0
			ctx.D.DamageBox(CFrame.new(cx, level - 1, cz), Vector3.new(sx, 3, sz), opts.melt, { maxParts = 60, shatter = true })
		end
		task.wait(dt)
	end
end

return Hazards
]])

	add("ServerScriptService", { "IslasServer" }, "Leaderboards", "ModuleScript", [[
-- Leaderboards: rellena las pantallas de clasificacion del lobby (servidor y mundial).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Levels = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Levels"))
local PlayerData = require(script.Parent.PlayerData)
local Lobby = require(script.Parent.Lobby)

local Leaderboards = {}

local function lines(list, fmt)
	local out = {}
	for i, e in ipairs(list) do
		if i > 10 then
			break
		end
		local medal = (i == 1 and "🥇") or (i == 2 and "🥈") or (i == 3 and "🥉") or (i .. ".")
		out[#out + 1] = medal .. " " .. e.name .. "  " .. fmt(e)
	end
	if #out == 0 then
		return "Todavia nadie..."
	end
	return table.concat(out, "\n")
end

function Leaderboards.UpdateServer()
	local wins, levels = {}, {}
	for _, p in ipairs(Players:GetPlayers()) do
		local data = PlayerData.Get(p)
		if data then
			local level = Levels.FromTotal(data.XP)
			wins[#wins + 1] = { name = p.DisplayName, value = data.Stats.Wins }
			levels[#levels + 1] = { name = p.DisplayName, value = level }
		end
	end
	table.sort(wins, function(a, b)
		return a.value > b.value
	end)
	table.sort(levels, function(a, b)
		return a.value > b.value
	end)
	local boards = Lobby.Boards
	if boards[1] then
		boards[1].Lines.Text = lines(wins, function(e)
			return e.value .. " 🏆"
		end)
	end
	if boards[2] then
		boards[2].Lines.Text = lines(levels, function(e)
			return "Nv " .. e.value
		end)
	end
end

local nameCache = {}
local function nameOf(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or ("Jugador " .. userId)
	return nameCache[userId]
end

function Leaderboards.UpdateGlobal()
	local store = PlayerData.GetOrderedStore()
	local board = Lobby.Boards[3]
	if not store or not board then
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, 10):GetCurrentPage()
	end)
	if not ok then
		board.Lines.Text = "No disponible"
		return
	end
	local list = {}
	for _, entry in ipairs(page) do
		local id = tonumber(tostring(entry.key):match("%d+"))
		list[#list + 1] = { name = id and nameOf(id) or tostring(entry.key), value = entry.value }
	end
	board.Lines.Text = lines(list, function(e)
		return e.value .. " 🏆"
	end)
end

function Leaderboards.Init()
	task.spawn(function()
		local tick = 0
		while true do
			Leaderboards.UpdateServer()
			if tick % 4 == 0 then
				task.spawn(Leaderboards.UpdateGlobal)
			end
			tick = tick + 1
			task.wait(30)
		end
	end)
end

return Leaderboards
]])

	add("ServerScriptService", { "IslasServer" }, "Lobby", "ModuleScript", [[
-- Lobby: construye el lobby (si tu juego no tiene ya uno llamado "Lobby" en el workspace).
-- Tiene: puntos de aparicion alrededor de una fuente, pantalla de estado, tienda, cofre diario,
-- clasificaciones, camas elasticas y un obby con recompensa al final.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(ServerStorage:WaitForChild("IslasMapas"):WaitForChild("Lib"):WaitForChild("Util"))
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)

local V, C, M, Colors = Util.V, Util.C, Util.M, Util.Colors
local OpenUI = Net.Event("OpenUI")

local Lobby = {}

Lobby.Folder = nil
Lobby.Boards = {} -- { Title = TextLabel, Lines = TextLabel }
Lobby.StatusLabel = nil
Lobby.TimerLabel = nil

local function prompt(part, action, object, fn)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.Parent = part
	pp.Triggered:Connect(fn)
	return pp
end

local function screen(b, name, size, pos, face)
	local p = b:Box(name, size, pos, C(20, 22, 32), M.SmoothPlastic, { indestructible = true })
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = p
	return p, gui
end

local function boardGui(gui, title, accent)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0.16, 0)
	t.BackgroundColor3 = accent
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = C(30, 25, 10)
	t.Text = title
	t.Parent = gui
	local lines = Instance.new("TextLabel")
	lines.Size = UDim2.new(0.92, 0, 0.8, 0)
	lines.Position = UDim2.new(0.04, 0, 0.18, 0)
	lines.BackgroundTransparency = 1
	lines.Font = Enum.Font.GothamBold
	lines.TextScaled = true
	lines.TextXAlignment = Enum.TextXAlignment.Left
	lines.TextYAlignment = Enum.TextYAlignment.Top
	lines.TextColor3 = C(255, 255, 255)
	lines.Text = "Cargando..."
	lines.Parent = gui
	return { Title = t, Lines = lines }
end

local obbyCheckpoint = {} -- [player] = Vector3

function Lobby.ShouldBuild()
	if Config.BuildLobby == true then
		return true
	end
	if Config.BuildLobby == "auto" then
		return workspace:FindFirstChild(Config.LobbyName or "Lobby") == nil
	end
	return false
end

function Lobby.Build()
	local folder = Instance.new("Folder")
	folder.Name = Config.LobbyName or "Lobby"
	local O = Config.LobbyOrigin
	local b = Util.newBuilder(folder, O)

	-- isla
	b:Box("Isla", V(280, 10, 280), V(0, -5, 0), Colors.Grass, M.Grass, { indestructible = true })
	b:Box("Orilla", V(300, 6, 300), V(0, -8, 0), Colors.Sand, M.Sand, { indestructible = true })
	b:Box("Agua", V(1400, 1, 1400), V(0, -9, 0), Colors.Water, M.SmoothPlastic, { transparency = 0.2, canCollide = false, indestructible = true })
	b:KillPlane(-40, 2048)
	b:Pillar("Plaza", 0, 0, -0.4, 0.1, 90, C(205, 200, 190), M.Slate)

	-- fuente central y spawns alrededor
	b:Pillar("FuenteBase", 0, 0, 0, 1.6, 16, Colors.Concrete, M.Marble)
	b:Pillar("FuenteAgua", 0, 0, 1.6, 1.9, 13, Colors.Water, M.SmoothPlastic)
	b:Pillar("FuenteColumna", 0, 0, 1.9, 7, 2.4, Colors.Concrete, M.Marble)
	b:Ball("FuenteBola", 4, V(0, 8.5, 0), C(255, 200, 60), M.Neon)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local s = Instance.new("SpawnLocation")
		s.Name = "SpawnLobby"
		s.Anchored = true
		s.Neutral = true
		s.Duration = 0
		s.Size = V(6, 1, 6)
		s.Color = C(255, 196, 50)
		s.Material = M.Neon
		s.Transparency = 0.3
		s.TopSurface = Enum.SurfaceType.Smooth
		s.CFrame = CFrame.new(O + V(math.cos(a) * 20, 0.5, math.sin(a) * 20))
		s:SetAttribute("Indestructible", true)
		s.Parent = folder
	end

	-- titulo y pantalla de estado
	local title = b:Board("Titulo", "ISLAS DE DESASTRES", V(90, 14, 2), V(0, 34, -92), C(255, 196, 50), C(30, 25, 10))
	title:SetAttribute("Indestructible", true)
	b:Box("PosteTitulo", V(3, 27, 3), V(-40, 13.5, -92), Colors.DarkMetal, M.Metal, { indestructible = true })
	b:Box("PosteTitulo", V(3, 27, 3), V(40, 13.5, -92), Colors.DarkMetal, M.Metal, { indestructible = true })
	local _, statusGui = screen(b, "PantallaEstado", V(56, 16, 1), V(0, 17, -92))
	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, 0, 0.6, 0)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBlack
	status.TextScaled = true
	status.TextColor3 = C(255, 255, 255)
	status.Text = "Bienvenido"
	status.Parent = statusGui
	local timer = Instance.new("TextLabel")
	timer.Size = UDim2.new(1, 0, 0.4, 0)
	timer.Position = UDim2.new(0, 0, 0.6, 0)
	timer.BackgroundTransparency = 1
	timer.Font = Enum.Font.GothamBlack
	timer.TextScaled = true
	timer.TextColor3 = C(255, 196, 50)
	timer.Text = ""
	timer.Parent = statusGui
	Lobby.StatusLabel, Lobby.TimerLabel = status, timer

	-- clasificaciones
	local boardDefs = {
		{ "TOP VICTORIAS", C(255, 196, 50), -62 },
		{ "TOP NIVEL", C(120, 200, 255), 62 },
		{ "TOP MUNDIAL", C(255, 120, 200), 0 },
	}
	for i, def in ipairs(boardDefs) do
		local x, z, face = def[3], -70, Enum.NormalId.Back
		if i == 3 then
			-- la mundial, al otro lado de la plaza mirando hacia la fuente
			z, face = 85, Enum.NormalId.Front
		end
		local _, gui = screen(b, "Clasificacion", V(30, 34, 1), V(x, 19, z), face)
		b:Box("PieClasificacion", V(32, 2, 3), V(x, 1, z), Colors.DarkMetal, M.Metal, { indestructible = true })
		Lobby.Boards[i] = boardGui(gui, def[1], def[2])
	end

	-- tienda
	local shop = b:Group("Tienda")
	shop:Box("Mostrador", V(18, 4, 4), V(52, 2, -18), Colors.Wood, M.Wood, { indestructible = true })
	shop:Box("TechoTienda", V(22, 1, 12), V(52, 11, -22), Colors.Red, M.Fabric, { indestructible = true })
	for _, x in ipairs({ 42, 62 }) do
		shop:Box("PosteTienda", V(1, 11, 1), V(x, 5.5, -17), Colors.Wood, M.Wood, { indestructible = true })
	end
	local shopSign = shop:Board("CartelTienda", "🛒 TIENDA", V(18, 4, 0.6), V(52, 14, -16.8), C(255, 196, 50), C(30, 25, 10))
	shopSign:SetAttribute("Indestructible", true)
	local counter = shop:Box("ZonaTienda", V(18, 6, 2), V(52, 3, -15.5), C(0, 0, 0), M.SmoothPlastic, { transparency = 1, canCollide = false, indestructible = true })
	prompt(counter, "Abrir tienda", "Tienda", function(player)
		OpenUI:FireClient(player, "Shop")
	end)

	-- cofre diario
	local chest = b:Box("CofreDiario", V(6, 4, 4), V(-52, 2, -18), C(255, 196, 50), M.Neon, { indestructible = true })
	b:Box("TapaCofre", V(6.4, 1.2, 4.4), V(-52, 4.6, -18), C(160, 100, 40), M.Wood, { indestructible = true })
	b:Board("CartelCofre", "🎁 RECOMPENSA DIARIA", V(20, 3, 0.6), V(-52, 9, -16), C(120, 255, 160), C(20, 40, 20))
	Util.AddLight(chest, 18, 2, C(255, 220, 120))
	prompt(chest, "Reclamar", "Recompensa diaria", function(player)
		OpenUI:FireClient(player, "Daily")
	end)

	-- camas elasticas
	for i, p in ipairs({ { -30, 40 }, { 0, 50 }, { 30, 40 } }) do
		local pad = b:Box("CamaElastica", V(10, 1, 10), V(p[1], 0.6, p[2]), C(80 + i * 40, 120, 255), M.Neon, { touch = true, indestructible = true })
		local cooldown = {}
		pad.Touched:Connect(function(hit)
			local char = hit.Parent
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and (not cooldown[char] or os.clock() - cooldown[char] > 0.8) then
				cooldown[char] = os.clock()
				hrp.AssemblyLinearVelocity = V(hrp.AssemblyLinearVelocity.X, 120, hrp.AssemblyLinearVelocity.Z)
			end
		end)
	end

	-- obby: plataformas que suben hasta un trofeo
	local obby = b:Group("Obby")
	local start = V(95, 0, 60)
	obby:Board("CartelObby", "OBBY → premio al final", V(16, 3, 0.6), V(start.X, 6, start.Z - 8), C(255, 120, 60), C(255, 255, 255))
	local positions = {}
	local pos = start
	for i = 1, 18 do
		local dir = (math.floor((i - 1) / 6) % 2 == 0) and V(0, 0, 9) or V(0, 0, -9)
		if i % 6 == 0 then
			dir = V(-10, 0, 0)
		end
		pos = pos + dir + V(0, 2.2, 0)
		positions[i] = pos
		local size = (i % 4 == 0) and V(3, 1, 3) or V(5, 1, 5)
		local color = Color3.fromHSV((i / 18) % 1, 0.7, 1)
		local plat = obby:Box("Plataforma" .. i, size, pos, color, M.SmoothPlastic, { indestructible = true, touch = i % 6 == 0 })
		if i % 6 == 0 then
			-- punto de control
			plat.Material = M.Neon
			plat.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player then
					obbyCheckpoint[player] = plat.Position + V(0, 3, 0)
				end
			end)
		end
	end
	local finalPos = positions[#positions] + V(-10, 2, 0)
	local finish = obby:Box("Meta", V(10, 1, 10), finalPos, C(255, 196, 50), M.Neon, { indestructible = true, touch = true })
	obby:Ball("Trofeo", 4, finalPos + V(0, 4, 0), C(255, 210, 60), M.Neon)
	finish.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local data = player and PlayerData.Get(player)
		if data and os.time() - (data.LastObby or 0) >= 600 then
			data.LastObby = os.time()
			Rewards.Give(player, 30, 15, { noMultiplier = true, text = "¡Obby completado!" })
			Rewards.Stat(player, "ObbyCompleted", 1)
		end
	end)
	-- suelo bajo el obby: si caes vuelves al ultimo punto de control
	local fall = obby:Box("CaidaObby", V(40, 1, 80), V(start.X - 5, 0.6, start.Z + 20), C(255, 80, 80), M.Neon, { transparency = 0.7, canCollide = false, touch = true, indestructible = true })
	fall.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local cp = player and obbyCheckpoint[player]
		if cp and player.Character then
			player.Character:PivotTo(CFrame.new(cp))
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		obbyCheckpoint[p] = nil
	end)

	-- decoracion
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local r = 115
		b:Pine(math.cos(a) * r, math.sin(a) * r, 0, 1.4)
	end
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.3
		local x, z = math.cos(a) * 36, math.sin(a) * 36
		b:Pillar("Farola", x, z, 0, 9, 0.6, Colors.DarkMetal, M.Metal)
		local lamp = b:Ball("LuzFarola", 1.6, V(x, 9.6, z), C(255, 240, 200), M.Neon)
		Util.AddLight(lamp, 24, 1.2)
		b:Box("Banco", V(5, 1, 1.6), V(x * 0.85, 0.8, z * 0.85), Colors.Wood, M.Wood)
	end

	folder.Parent = workspace
	Lobby.Folder = folder
	return folder
end

function Lobby.SetStatus(text, timerText)
	if Lobby.StatusLabel then
		Lobby.StatusLabel.Text = text or ""
	end
	if Lobby.TimerLabel then
		Lobby.TimerLabel.Text = timerText or ""
	end
end

return Lobby
]])

	add("ServerScriptService", { "IslasServer" }, "Main", "Script", [[
-- Main: punto de entrada del servidor. Arranca todos los sistemas en orden.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
require(Shared:WaitForChild("Net")) -- crea los RemoteEvents

local S = script.Parent
require(S.CollisionGroups).Setup()
require(S.PlayerData).Init()
require(S.Rewards).Init()
require(S.Gear).Init()
require(S.ShopService).Init()
require(S.CoinDrops).Init()

local Lobby = require(S.Lobby)
local MapService = require(S.MapService)
if Lobby.ShouldBuild() then
	-- mientras se construye el lobby no aparecen personajes (si no, caerian al vacio)
	local autoLoads = Players.CharacterAutoLoads
	Players.CharacterAutoLoads = false
	Lobby.Build()
	Players.CharacterAutoLoads = autoLoads
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			MapService.ReturnToLobby({ player })
		elseif autoLoads then
			task.spawn(function()
				player:LoadCharacter()
			end)
		end
	end
end
require(S.Leaderboards).Init()
require(S.AdminCommands).Init()

if Config.RunDefaultLoop then
	task.spawn(require(S.GameLoop).Run)
end
]])

	add("ServerScriptService", { "IslasServer" }, "MapService", "ModuleScript", [[
-- MapService: construye un mapa SOLO cuando se necesita, teletransporta jugadores y lo borra despues.
-- Mientras un mapa no se ha votado no existe en el workspace, asi que no consume nada.
--
-- Mapas disponibles:
--   * Los generados por codigo en ServerStorage.IslasMapas.Builders
--   * Tus propios modelos: mete un Model en ServerStorage.IslasMapasPropios y aparece en la votacion.
--     Atributos opcionales del modelo: Title (texto), Description (texto), Disasters ("Earthquake,Fire,...").
--     Las piezas llamadas "Spawn"/"SpawnPoint" (o SpawnLocation) son los puntos de aparicion.
--
-- API:
--   MapService.GetMapNames()            -> lista de nombres de mapas disponibles
--   MapService.GetInfo(name)            -> { Name, Title, Description, Disasters }
--   MapService.Load(name)               -> construye el mapa (bloquea hasta terminar)
--   MapService.GetCurrent()             -> { Name, Folder, Spawns, Def, Bounds } o nil
--   MapService.TeleportToMap(players)   -> manda jugadores a los spawns del mapa cargado
--   MapService.ReturnToLobby(players)   -> los devuelve al lobby
--   MapService.Unload()                 -> borra el mapa (poco a poco, sin tirones) y restaura la luz

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Config"))
local MapsRoot = ServerStorage:WaitForChild("IslasMapas")
local Util = require(MapsRoot:WaitForChild("Lib"):WaitForChild("Util"))
local Builders = MapsRoot:WaitForChild("Builders")
local Destruction = require(script.Parent.Destruction)

Util.ChunkSize = Config.ChunkSize
Util.BuildBudget = Config.BuildBudgetMs / 1000

local MapService = {}

local current = nil
local savedLighting = nil
local savedGravity = nil
local lobbySpawns = nil

local LIGHT_PROPS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "FogColor", "FogStart", "FogEnd" }
local ALL_DISASTERS = { "Earthquake", "Fire", "Meteors", "Flood", "Lightning", "Tornado", "AcidRain", "Tsunami", "Volcano", "BlackHole", "UFO", "Virus" }

-- Carpetas de ServerStorage con mapas propios (Model o Folder). Ver Config.CustomMapFolders.
local function customFolders()
	local list = {}
	for _, name in ipairs(Config.CustomMapFolders or { "IslasMapasPropios" }) do
		local f = ServerStorage:FindFirstChild(name)
		if f then
			list[#list + 1] = f
		end
	end
	return list
end

local function findCustom(name)
	for _, f in ipairs(customFolders()) do
		local m = f:FindFirstChild(name)
		if m and (m:IsA("Model") or m:IsA("Folder")) then
			return m
		end
	end
	return nil
end

-- Caja que envuelve un Model o una Folder (las Folder no tienen GetBoundingBox)
local function boundsOf(inst)
	if inst:IsA("Model") then
		return inst:GetBoundingBox()
	end
	local minV, maxV
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			local p, h = d.Position, d.Size / 2
			local lo, hi = p - h, p + h
			minV = minV and minV:Min(lo) or lo
			maxV = maxV and maxV:Max(hi) or hi
		end
	end
	if not minV then
		return CFrame.new(), Vector3.zero
	end
	return CFrame.new((minV + maxV) / 2), maxV - minV
end

local customCache = {} -- [instancia] = def (calcular la caja de un mapa grande cuesta)

local function customDef(model)
	if customCache[model] then
		return customCache[model]
	end
	local disasters = ALL_DISASTERS
	local attr = model:GetAttribute("Disasters")
	if typeof(attr) == "string" and #attr > 0 then
		disasters = {}
		for _, d in ipairs(string.split(attr, ",")) do
			d = d:gsub("^%s+", ""):gsub("%s+$", "")
			if #d > 0 then
				disasters[#disasters + 1] = d
			end
		end
	end
	local _, size = boundsOf(model)
	local hx, hz = size.X / 2 + 10, size.Z / 2 + 10
	local lighting
	if typeof(model:GetAttribute("ClockTime")) == "number" then
		lighting = { ClockTime = model:GetAttribute("ClockTime") }
	end
	local def = {
		Title = model:GetAttribute("Title") or model.Name,
		Description = model:GetAttribute("Description") or "Mapa personalizado.",
		Disasters = disasters,
		Bounds = { x1 = -hx, x2 = hx, z1 = -hz, z2 = hz, top = size.Y + 40, floor = 0 },
		Lighting = lighting,
		Custom = model,
	}
	customCache[model] = def
	return def
end

local function getDef(name)
	local module = Builders:FindFirstChild(name)
	if module then
		return require(module)
	end
	local model = findCustom(name)
	if model then
		return customDef(model)
	end
	error("MapService: no existe el mapa '" .. tostring(name) .. "'")
end
MapService.GetDef = getDef

function MapService.GetMapNames()
	local names = {}
	local disabled = {}
	for _, n in ipairs(Config.DisabledMaps or {}) do
		disabled[n] = true
	end
	for _, child in ipairs(Builders:GetChildren()) do
		if child:IsA("ModuleScript") and not disabled[child.Name] then
			names[#names + 1] = child.Name
		end
	end
	for _, f in ipairs(customFolders()) do
		for _, child in ipairs(f:GetChildren()) do
			if (child:IsA("Model") or child:IsA("Folder")) and not table.find(names, child.Name) and not disabled[child.Name] then
				names[#names + 1] = child.Name
			end
		end
	end
	table.sort(names)
	return names
end

function MapService.GetInfo(name)
	local def = getDef(name)
	return {
		Name = name,
		Title = def.Title or name,
		Description = def.Description or "",
		Disasters = def.Disasters or {},
	}
end

local function applyLighting(settings)
	if not settings then
		return
	end
	if not savedLighting then
		savedLighting = {}
		for _, prop in ipairs(LIGHT_PROPS) do
			savedLighting[prop] = Lighting[prop]
		end
	end
	for prop, value in pairs(settings) do
		Lighting[prop] = value
	end
end

local function restoreLighting()
	if savedLighting then
		for prop, value in pairs(savedLighting) do
			Lighting[prop] = value
		end
		savedLighting = nil
	end
end

-- Borra un arbol de instancias poco a poco para no dar tirones
local function destroyGradually(folder)
	folder.Name = "MapaBorrandose"
	task.spawn(function()
		local budget = 0.004
		local start = os.clock()
		local function clear(inst)
			for _, child in ipairs(inst:GetChildren()) do
				if #child:GetChildren() > 40 then
					clear(child)
				end
				child:Destroy()
				if os.clock() - start > budget then
					task.wait()
					start = os.clock()
				end
			end
		end
		clear(folder)
		folder:Destroy()
	end)
end

function MapService.Unload()
	Destruction.Reset()
	if current then
		destroyGradually(current.Folder)
		current = nil
	end
	restoreLighting()
	if savedGravity then
		workspace.Gravity = savedGravity
		savedGravity = nil
	end
end

-- Coloca un modelo propio en el origen del mapa y saca sus puntos de aparicion
local SPAWN_FOLDERS = { spawns = true, spawnpoints = true, spawnlocations = true, puntosaparicion = true }

local function placeCustom(def, folder, origin)
	-- Se clona desde ServerStorage: el original nunca entra en el workspace
	local source = def.Custom
	local clone
	if source:IsA("Model") then
		clone = source:Clone()
	else
		clone = Instance.new("Model")
		clone.Name = source.Name
		for _, child in ipairs(source:GetChildren()) do
			local c = child:Clone()
			if c then
				c.Parent = clone
			end
		end
	end
	local cf, size = clone:GetBoundingBox()
	local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
	-- PivotTo mueve todo junto (tambien piezas soldadas)
	clone:PivotTo(clone:GetPivot() + (origin - bottom))
	if Config.DisableMapScripts then
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") then
				d.Disabled = true
			end
		end
	end
	clone.Parent = folder
	local spawns = {}
	for _, d in ipairs(clone:GetDescendants()) do
		local inSpawnFolder = d.Parent and SPAWN_FOLDERS[string.lower(d.Parent.Name)]
		if d:IsA("SpawnLocation") then
			d.Enabled = false
			spawns[#spawns + 1] = d
		elseif d:IsA("BasePart") and (inSpawnFolder or string.lower(d.Name):match("^spawn")) then
			d.Transparency = 1
			d.CanCollide = false
			spawns[#spawns + 1] = d
		end
	end
	for _, s in ipairs(spawns) do
		s:SetAttribute("Indestructible", true)
	end
	if #spawns == 0 then
		-- sin spawns: buscar suelo en una rejilla sobre el modelo
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { clone }
		for ix = -1, 1 do
			for iz = -1, 1 do
				local p = origin + Vector3.new(ix * size.X * 0.3, size.Y + 20, iz * size.Z * 0.3)
				local hit = workspace:Raycast(p, Vector3.new(0, -(size.Y + 60), 0), params)
				if hit then
					local marker = Instance.new("Part")
					marker.Name = "SpawnPoint"
					marker.Anchored = true
					marker.CanCollide = false
					marker.Transparency = 1
					marker.Size = Vector3.new(4, 1, 4)
					marker.Position = hit.Position + Vector3.new(0, 0.5, 0)
					marker:SetAttribute("Indestructible", true)
					marker.Parent = folder
					spawns[#spawns + 1] = marker
				end
			end
		end
	end
	return spawns
end

function MapService.Load(name)
	MapService.Unload()
	local def = getDef(name)
	local origin = Config.MapOrigin

	-- Se construye directamente en el workspace pero repartido entre frames (Util.BuildBudget):
	-- los clientes reciben la isla poco a poco en lugar de un unico golpe enorme.
	local folder = Instance.new("Folder")
	folder.Name = "MapaActual_" .. name
	folder.Parent = workspace

	local spawns
	local ok, err = pcall(function()
		if def.Custom then
			spawns = placeCustom(def, folder, origin)
		else
			local b = Util.newBuilder(folder, origin)
			def.Build(b)
			spawns = b:Spawns()
		end
	end)
	if not ok then
		folder:Destroy()
		error("MapService: fallo construyendo '" .. name .. "': " .. tostring(err), 0)
	end
	applyLighting(def.Lighting)
	if def.Gravity then
		savedGravity = workspace.Gravity
		workspace.Gravity = def.Gravity
	end

	local b = def.Bounds or { x1 = -100, x2 = 100, z1 = -100, z2 = 100, top = 100, floor = 0 }
	local bounds = {
		x1 = origin.X + b.x1,
		x2 = origin.X + b.x2,
		z1 = origin.Z + b.z1,
		z2 = origin.Z + b.z2,
		top = origin.Y + (b.top or 100),
		floor = origin.Y + (b.floor or 0),
	}
	Destruction.Begin(folder, bounds.floor)

	current = { Name = name, Folder = folder, Spawns = spawns, Def = def, Bounds = bounds }
	return folder
end

function MapService.GetCurrent()
	return current
end

-- ===== Lobby =====

local function findLobbySpawns()
	if lobbySpawns then
		local valid = true
		for _, s in ipairs(lobbySpawns) do
			if not s.Parent then
				valid = false
			end
		end
		if valid then
			return lobbySpawns
		end
	end
	local found = {}
	local lobby = workspace:FindFirstChild(Config.LobbyName or "Lobby")
	local scope = lobby or workspace
	for _, inst in ipairs(scope:GetDescendants()) do
		if inst:IsA("SpawnLocation") and not (current and inst:IsDescendantOf(current.Folder)) then
			found[#found + 1] = inst
		end
	end
	if #found == 0 then
		local p = Instance.new("SpawnLocation")
		p.Name = "SpawnLobbyPorDefecto"
		p.Anchored = true
		p.Size = Vector3.new(30, 1, 30)
		p.Position = Vector3.new(0, 0, 0)
		p.Parent = workspace
		found = { p }
	end
	lobbySpawns = found
	return found
end
MapService.GetLobbySpawns = findLobbySpawns

-- ===== Teletransporte =====

local function shuffled(list)
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.random(i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function moveTo(player, position)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	-- Con StreamingEnabled hay que pedir que se cargue la zona antes de llegar
	pcall(function()
		player:RequestStreamAroundAsync(position, 3)
	end)
	char:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
	root.AssemblyLinearVelocity = Vector3.zero
	return true
end

local function teleport(list, spawns)
	if #spawns == 0 then
		warn("MapService: no hay puntos de aparicion")
		return
	end
	local order = shuffled(spawns)
	for i, player in ipairs(list) do
		local sp = order[(i - 1) % #order + 1]
		local s = sp.Size
		local jitter = Vector3.new((math.random() - 0.5) * math.min(s.X, 10), 0, (math.random() - 0.5) * math.min(s.Z, 10))
		task.spawn(moveTo, player, sp.Position + jitter)
	end
end

function MapService.TeleportToMap(list)
	if not current then
		warn("MapService: no hay ningun mapa cargado")
		return
	end
	teleport(list or Players:GetPlayers(), current.Spawns)
end

function MapService.ReturnToLobby(list)
	teleport(list or Players:GetPlayers(), findLobbySpawns())
end

-- Esta este jugador dentro del mapa actual?
function MapService.IsOnMap(player)
	if not current then
		return false
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	local b = current.Bounds
	local p = hrp.Position
	return p.X > b.x1 - 80 and p.X < b.x2 + 80 and p.Z > b.z1 - 80 and p.Z < b.z2 + 80 and p.Y > b.floor - 100 and p.Y < b.top + 200
end

return MapService
]])

	add("ServerScriptService", { "IslasServer" }, "PhysicsBudget", "ModuleScript", [[
-- PhysicsBudget: controla cuantos cuerpos fisicos sueltos hay a la vez para que no caiga el rendimiento.
--  * Como mucho Config.MaxPhysicsBodies cuerpos simulandose (un "cuerpo" puede ser un bloque soldado de muchas piezas).
--  * Cuando un escombro se para (o lleva demasiado tiempo cayendo) se ANCLA: sigue viendose como escombro pero
--    ya no cuesta nada de fisica.
--  * Se guardan como mucho Config.MaxRubbleParts escombros; los mas viejos se borran.
--  * Los escombros rapidos hacen dano a los jugadores que golpean.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Config"))
local CollisionGroups = require(script.Parent.CollisionGroups)

local PhysicsBudget = {}

local bodies = {} -- { parts = {...}, root = part, welds = {...}, born = t, still = 0 }
local rubble = {} -- cola FIFO de piezas ancladas
local rubbleHead = 1
local killY = -math.huge
local hitCooldown = {} -- [humanoid] = t
local onRemove -- callback para borrar piezas (Destruction.Remove), evita tirones

local CHECK_EVERY = 0.15

local function clock()
	return workspace:GetServerTimeNow()
end

function PhysicsBudget.SetKillY(y)
	killY = y
end

function PhysicsBudget.SetRemover(fn)
	onRemove = fn
end

function PhysicsBudget.Count()
	return #bodies
end

function PhysicsBudget.RubbleCount()
	return #rubble - rubbleHead + 1
end

function PhysicsBudget.CanAdd(n)
	return #bodies + (n or 1) <= Config.MaxPhysicsBodies
end

local function removePart(part)
	if onRemove then
		onRemove(part)
	elseif part.Parent then
		part:Destroy()
	end
end

-- parts: lista de piezas (ya desancladas o no); la primera es la raiz del cuerpo
function PhysicsBudget.Add(parts, welds)
	local root = parts[1]
	if not root then
		return
	end
	for _, p in ipairs(parts) do
		p.CollisionGroup = CollisionGroups.Debris
		p.CanTouch = false
		p.CanQuery = false
		p.Anchored = false
	end
	bodies[#bodies + 1] = { parts = parts, root = root, welds = welds or {}, born = clock(), still = 0 }
end

local function settle(body)
	for _, w in ipairs(body.welds) do
		if w.Parent then
			w:Destroy()
		end
	end
	for _, p in ipairs(body.parts) do
		if p.Parent then
			p.Anchored = true
			p.AssemblyLinearVelocity = Vector3.zero
			rubble[#rubble + 1] = p
		end
	end
	-- limite de escombros: se quitan los mas viejos
	while #rubble - rubbleHead + 1 > Config.MaxRubbleParts do
		local old = rubble[rubbleHead]
		rubble[rubbleHead] = nil
		rubbleHead = rubbleHead + 1
		if old and old.Parent then
			removePart(old)
		end
	end
end

local function harmPlayers(body, speed)
	local root = body.root
	local s = root.Size
	local reach = math.max(s.X, s.Y, s.Z) / 2 + 3
	local pos = root.Position
	local now = clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 and (hrp.Position - pos).Magnitude < reach then
			if not hitCooldown[hum] or now - hitCooldown[hum] > 0.7 then
				hitCooldown[hum] = now
				hum:SetAttribute("Causa", "Escombros")
				hum:TakeDamage(math.clamp(speed * 0.6, 10, 45))
			end
		end
	end
end

function PhysicsBudget.Step(dt)
	local now = clock()
	for i = #bodies, 1, -1 do
		local b = bodies[i]
		local root = b.root
		if not root.Parent or root.Anchored then
			table.remove(bodies, i)
		elseif root.Position.Y < killY then
			for _, p in ipairs(b.parts) do
				removePart(p)
			end
			table.remove(bodies, i)
		else
			local speed = root.AssemblyLinearVelocity.Magnitude
			if speed > 28 then
				harmPlayers(b, speed)
			end
			if speed < 3 then
				b.still = b.still + dt
			else
				b.still = 0
			end
			if b.still >= Config.DebrisSettleTime or now - b.born > Config.DebrisMaxLife then
				settle(b)
				table.remove(bodies, i)
			end
		end
	end
end

-- Mueve los cuerpos activos hacia un punto (agujero negro, tornado)
function PhysicsBudget.ForEachBody(fn)
	for _, b in ipairs(bodies) do
		if b.root.Parent and not b.root.Anchored then
			fn(b.root, b)
		end
	end
end

function PhysicsBudget.Reset()
	table.clear(bodies)
	table.clear(rubble)
	rubbleHead = 1
	table.clear(hitCooldown)
	killY = -math.huge
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc = acc + dt
	if acc >= CHECK_EVERY then
		PhysicsBudget.Step(acc)
		acc = 0
	end
end)

return PhysicsBudget
]])

	add("ServerScriptService", { "IslasServer" }, "PlayerData", "ModuleScript", [[
-- PlayerData: datos persistentes de cada jugador (DataStore) con guardado automatico.
-- Si el DataStore no esta disponible (por ejemplo en Studio sin "Enable Studio Access to API Services"),
-- se juega con datos temporales y NO se sobrescribe nada.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Levels = require(Shared:WaitForChild("Levels"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Net = require(Shared:WaitForChild("Net"))

local DataUpdate = Net.Event("DataUpdate")

local PlayerData = {}

local profiles = {} -- [player] = { data = {...}, noSave = bool, dirty = bool }
local changedHandlers = {}
local store
local orderedStore

local function defaultData()
	return {
		Version = 2,
		Coins = 0,
		XP = 0,
		Owned = {},
		Equipped = { Gears = {}, Trail = nil },
		Stats = {
			Wins = 0, Rounds = 0, Deaths = 0, BestStreak = 0, Streak = 0, CoinsEarned = 0, CoinsPicked = 0,
			Purchases = 0, ObbyCompleted = 0, SoleSurvivor = 0, DoubleSurvived = 0, MapsSurvived = 0,
			DisastersSurvived = 0, DailyStreak = 0, Level = 1,
		},
		MapsDone = {},
		DisastersDone = {},
		Achievements = {},
		LastDaily = 0,
		LastObby = 0,
		Settings = { Quality = 0, Shake = 1, Music = true, Sounds = true },
	}
end

-- rellena campos nuevos en datos antiguos
local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			if type(v) == "table" then
				data[k] = {}
				reconcile(data[k], v)
			else
				data[k] = v
			end
		elseif type(v) == "table" and type(data[k]) == "table" and k ~= "Owned" and k ~= "Achievements" and k ~= "MapsDone" and k ~= "DisastersDone" then
			reconcile(data[k], v)
		end
	end
	return data
end

local function keyFor(player)
	return "u_" .. player.UserId
end

function PlayerData.OnChanged(fn)
	changedHandlers[#changedHandlers + 1] = fn
end

local function fireChanged(player, key)
	for _, fn in ipairs(changedHandlers) do
		task.spawn(fn, player, key)
	end
end

function PlayerData.Get(player)
	local p = profiles[player]
	return p and p.data or nil
end

function PlayerData.WaitFor(player, timeout)
	local limit = os.clock() + (timeout or 15)
	while not profiles[player] and player.Parent and os.clock() < limit do
		task.wait(0.1)
	end
	return PlayerData.Get(player)
end

function PlayerData.LevelInfo(data)
	local level, into, need = Levels.FromTotal(data.XP)
	return level, into, need
end

function PlayerData.Snapshot(player)
	local data = PlayerData.Get(player)
	if not data then
		return nil
	end
	local level, into, need = PlayerData.LevelInfo(data)
	local title, color = Levels.Title(level)
	local now = os.time()
	return {
		Coins = data.Coins,
		XP = data.XP,
		Level = level,
		LevelXP = into,
		LevelNeed = need,
		Title = title,
		TitleColor = color,
		Owned = data.Owned,
		Equipped = data.Equipped,
		Stats = data.Stats,
		Achievements = data.Achievements,
		Settings = data.Settings,
		GearSlots = Catalog.GearSlots(data.Owned),
		DailyAvailable = now - (data.LastDaily or 0) >= 20 * 3600,
		DailyStreak = data.Stats.DailyStreak,
		Temporary = profiles[player].noSave,
	}
end

local function updateLeaderstats(player)
	local data = PlayerData.Get(player)
	local ls = player:FindFirstChild("leaderstats")
	if not data or not ls then
		return
	end
	ls.Monedas.Value = data.Coins
	ls.Victorias.Value = data.Stats.Wins
	ls.Nivel.Value = (PlayerData.LevelInfo(data))
end

-- Envia los datos al cliente (agrupado: como mucho una vez por frame)
local pushPending = {}
function PlayerData.Push(player)
	if pushPending[player] then
		return
	end
	pushPending[player] = true
	task.defer(function()
		pushPending[player] = nil
		if player.Parent and profiles[player] then
			DataUpdate:FireClient(player, PlayerData.Snapshot(player))
			updateLeaderstats(player)
		end
	end)
end

function PlayerData.MarkDirty(player, key)
	local p = profiles[player]
	if p then
		p.dirty = true
		PlayerData.Push(player)
		fireChanged(player, key)
	end
end

function PlayerData.AddCoins(player, amount)
	local data = PlayerData.Get(player)
	if not data then
		return 0
	end
	amount = math.floor(amount + 0.5)
	data.Coins = math.max(0, data.Coins + amount)
	if amount > 0 then
		data.Stats.CoinsEarned = data.Stats.CoinsEarned + amount
	end
	PlayerData.MarkDirty(player, "Coins")
	return amount
end

function PlayerData.Spend(player, amount)
	local data = PlayerData.Get(player)
	if not data or data.Coins < amount then
		return false
	end
	data.Coins = data.Coins - amount
	PlayerData.MarkDirty(player, "Coins")
	return true
end

-- Devuelve nivelAntes, nivelDespues
function PlayerData.AddXP(player, amount)
	local data = PlayerData.Get(player)
	if not data then
		return 1, 1
	end
	local before = PlayerData.LevelInfo(data)
	data.XP = data.XP + math.floor(amount + 0.5)
	local after = PlayerData.LevelInfo(data)
	data.Stats.Level = after
	PlayerData.MarkDirty(player, "XP")
	return before, after
end

-- ======================================================================
-- Carga / guardado
-- ======================================================================
local function load(player)
	local data, ok
	if store then
		for attempt = 1, 3 do
			ok, data = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				break
			end
			task.wait(attempt)
		end
	end
	local noSave = not store or not ok
	if noSave and store then
		warn("PlayerData: no se pudieron cargar los datos de " .. player.Name .. "; se usan datos temporales")
	end
	data = reconcile(type(data) == "table" and data or defaultData(), defaultData())
	if not player.Parent then
		return
	end
	profiles[player] = { data = data, noSave = noSave, dirty = false }

	-- si tu otro juego ya crea leaderstats, se reutiliza y se anaden los valores que falten
	local ls = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, n in ipairs({ "Victorias", "Nivel", "Monedas" }) do
		if not ls:FindFirstChild(n) then
			local v = Instance.new("IntValue")
			v.Name = n
			v.Parent = ls
		end
	end
	ls.Parent = player
	updateLeaderstats(player)
	PlayerData.Push(player)
	fireChanged(player, "Loaded")
end

local function save(player, final)
	local p = profiles[player]
	if not p or p.noSave or not store then
		return true
	end
	if not p.dirty and not final then
		return true
	end
	local data = p.data
	local ok, err
	for attempt = 1, 3 do
		ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function()
				return data
			end)
		end)
		if ok then
			break
		end
		task.wait(attempt)
	end
	if ok then
		p.dirty = false
		if orderedStore then
			pcall(function()
				orderedStore:SetAsync(keyFor(player), data.Stats.Wins)
			end)
		end
	else
		warn("PlayerData: error guardando a " .. player.Name .. ": " .. tostring(err))
	end
	return ok
end
PlayerData.Save = save

function PlayerData.GetOrderedStore()
	return orderedStore
end

local started = false
function PlayerData.Init()
	if started then
		return
	end
	started = true
	local ok = pcall(function()
		store = DataStoreService:GetDataStore(Config.DataStoreName)
		orderedStore = DataStoreService:GetOrderedDataStore(Config.LeaderboardStoreName)
	end)
	if not ok then
		store, orderedStore = nil, nil
		warn("PlayerData: DataStore no disponible, los datos no se guardaran")
	end

	Players.PlayerAdded:Connect(function(player)
		load(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player, true)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		for player in pairs(profiles) do
			task.spawn(save, player, true)
		end
		task.wait(3)
	end)
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in pairs(profiles) do
				task.spawn(save, player, false)
			end
		end
	end)

	Net.Function("GetData").OnServerInvoke = function(player)
		PlayerData.WaitFor(player, 10)
		return PlayerData.Snapshot(player)
	end

	Net.Event("SettingsChanged").OnServerEvent:Connect(function(player, settings)
		local data = PlayerData.Get(player)
		if not data or typeof(settings) ~= "table" then
			return
		end
		local s = data.Settings
		if typeof(settings.Quality) == "number" then
			s.Quality = math.clamp(math.floor(settings.Quality), 0, 3)
		end
		if typeof(settings.Shake) == "number" then
			s.Shake = math.clamp(settings.Shake, 0, 1)
		end
		if typeof(settings.Music) == "boolean" then
			s.Music = settings.Music
		end
		if typeof(settings.Sounds) == "boolean" then
			s.Sounds = settings.Sounds
		end
		profiles[player].dirty = true
	end)
end

return PlayerData
]])

	add("ServerScriptService", { "IslasServer" }, "Rewards", "ModuleScript", [[
-- Rewards: monedas, experiencia, estadisticas, logros y recompensa diaria, con avisos al cliente
-- (numeros que saltan, subida de nivel, logro desbloqueado...).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Achievements = require(Shared:WaitForChild("Achievements"))
local Levels = require(Shared:WaitForChild("Levels"))
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)

local Popup = Net.Event("Popup")
local Toast = Net.Event("Toast")
local PlaySound = Net.Event("PlaySound")

local Rewards = {}

Rewards.Multiplier = 1 -- lo cambia GameLoop (monedas x2, modo hiper...)

local function checkAchievements(player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	for _, a in ipairs(Achievements) do
		if not data.Achievements[a.Id] then
			local value = data.Stats[a.Stat] or 0
			if value >= a.Goal then
				data.Achievements[a.Id] = os.time()
				PlayerData.AddCoins(player, a.Reward)
				Toast:FireClient(player, {
					Kind = "Achievement",
					Title = "🏆 Logro: " .. a.Name,
					Text = a.Desc .. "  (+" .. a.Reward .. " monedas)",
				})
				PlaySound:FireClient(player, "Win", nil, 0.8)
			end
		end
	end
end
Rewards.CheckAchievements = checkAchievements

-- coins/xp: cantidades base. opts.noMultiplier, opts.text (motivo), opts.position (Vector3: popup en el mundo)
function Rewards.Give(player, coins, xp, opts)
	opts = opts or {}
	local data = PlayerData.Get(player)
	if not data then
		return 0, 0
	end
	local mult = opts.noMultiplier and 1 or Rewards.Multiplier
	if opts.lucky and data.Owned.Suerte then
		mult = mult * 1.25
	end
	local c = math.floor((coins or 0) * mult + 0.5)
	local x = math.floor((xp or 0) * (opts.noMultiplier and 1 or math.max(1, Rewards.Multiplier * 0.75)) + 0.5)
	if c ~= 0 then
		PlayerData.AddCoins(player, c)
	end
	local before, after = 1, 1
	if x > 0 then
		before, after = PlayerData.AddXP(player, x)
	end
	if c > 0 or x > 0 then
		Popup:FireClient(player, { Coins = c, XP = x, Text = opts.text, Position = opts.position })
	end
	if after > before then
		local title = Levels.Title(after)
		Toast:FireClient(player, { Kind = "LevelUp", Title = "¡NIVEL " .. after .. "!", Text = "Rango: " .. title, Level = after })
		PlaySound:FireClient(player, "LevelUp", nil, 1)
		-- recompensa por subir de nivel
		PlayerData.AddCoins(player, 25 + after * 5)
	end
	checkAchievements(player)
	return c, x
end

-- Suma (o fija con set=true) una estadistica y revisa logros
function Rewards.Stat(player, stat, delta, set)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	if set then
		data.Stats[stat] = delta
	else
		data.Stats[stat] = (data.Stats[stat] or 0) + delta
	end
	PlayerData.MarkDirty(player, stat)
	checkAchievements(player)
end

-- Apunta algo en una coleccion (mapas/desastres sobrevividos) y actualiza el contador
function Rewards.Collect(player, setName, key, statName)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local set = data[setName]
	if not set[key] then
		set[key] = true
		local n = 0
		for _ in pairs(set) do
			n = n + 1
		end
		data.Stats[statName] = n
		PlayerData.MarkDirty(player, statName)
		checkAchievements(player)
	end
end

function Rewards.DailyInfo(player)
	local data = PlayerData.Get(player)
	if not data then
		return false, 0, 0
	end
	local now = os.time()
	local available = now - (data.LastDaily or 0) >= 20 * 3600
	local streak = data.Stats.DailyStreak or 0
	if now - (data.LastDaily or 0) > 48 * 3600 then
		streak = 0
	end
	local nextDay = math.min(streak + 1, Config.DailyRewardMaxDays)
	return available, nextDay, Config.DailyRewardBase * nextDay
end

function Rewards.ClaimDaily(player)
	local data = PlayerData.Get(player)
	if not data then
		return false
	end
	local available, day, amount = Rewards.DailyInfo(player)
	if not available then
		return false
	end
	data.LastDaily = os.time()
	data.Stats.DailyStreak = day
	Rewards.Give(player, amount, 20, { noMultiplier = true, text = "Recompensa diaria (dia " .. day .. ")" })
	Rewards.Stat(player, "DailyStreak", day, true)
	return true, amount, day
end

function Rewards.Init()
	Net.Event("DailyClaim").OnServerEvent:Connect(function(player)
		Rewards.ClaimDaily(player)
	end)
end

return Rewards
]])

	add("ServerScriptService", { "IslasServer" }, "ShopService", "ModuleScript", [[
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
]])

	add("ServerScriptService", { "IslasServer" }, "VoteService", "ModuleScript", [[
-- VoteService: votacion de mapa entre rondas.
--   local winner = VoteService.Run(VoteService.PickOptions(3), segundos)
-- Bloquea hasta que acaba el tiempo (o hasta que han votado todos) y devuelve el nombre del mapa ganador.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))
local MapService = require(script.Parent.MapService)
local DisasterService = require(script.Parent.DisasterService)

local VoteOptions = Net.Event("VoteOptions")
local VoteUpdate = Net.Event("VoteUpdate")
local VoteEnd = Net.Event("VoteEnd")
local CastVote = Net.Event("CastVote")

local VoteService = {}

local active = nil -- { set, list, votes = { [userId] = nombre } }
local lastWinner = nil

local function tally(options)
	local counts = {}
	for _, name in ipairs(options) do
		counts[name] = 0
	end
	for _, name in pairs(active.votes) do
		if counts[name] then
			counts[name] = counts[name] + 1
		end
	end
	return counts
end

CastVote.OnServerEvent:Connect(function(player, name)
	if not active or typeof(name) ~= "string" or not active.set[name] then
		return
	end
	active.votes[player.UserId] = name
	VoteUpdate:FireAllClients(tally(active.list))
end)

Players.PlayerRemoving:Connect(function(player)
	if active then
		active.votes[player.UserId] = nil
		VoteUpdate:FireAllClients(tally(active.list))
	end
end)

-- Elige `n` mapas distintos al azar (sin repetir el ultimo jugado si hay suficientes)
function VoteService.PickOptions(n)
	local names = MapService.GetMapNames()
	if #names > n and lastWinner then
		local i = table.find(names, lastWinner)
		if i then
			table.remove(names, i)
		end
	end
	for i = #names, 2, -1 do
		local j = math.random(i)
		names[i], names[j] = names[j], names[i]
	end
	local picked = {}
	for i = 1, math.min(n, #names) do
		picked[i] = names[i]
	end
	return picked
end

function VoteService.Run(options, seconds)
	local set = {}
	local infos = {}
	for _, name in ipairs(options) do
		set[name] = true
		local info = MapService.GetInfo(name)
		info.DisasterTitles = {}
		info.DisasterIcons = {}
		for _, d in ipairs(info.Disasters) do
			local di = DisasterService.Info(d)
			info.DisasterTitles[#info.DisasterTitles + 1] = di.Title
			info.DisasterIcons[#info.DisasterIcons + 1] = di.Icon
		end
		infos[#infos + 1] = info
	end
	active = { set = set, list = options, votes = {} }

	local endTime = workspace:GetServerTimeNow() + seconds
	VoteOptions:FireAllClients(infos, endTime)
	VoteUpdate:FireAllClients(tally(options))

	-- termina antes si ya han votado todos (y hay mas de uno)
	while workspace:GetServerTimeNow() < endTime do
		task.wait(0.25)
		local n, voted = #Players:GetPlayers(), 0
		for _ in pairs(active.votes) do
			voted = voted + 1
		end
		if n > 1 and voted >= n and endTime - workspace:GetServerTimeNow() > 2 then
			endTime = workspace:GetServerTimeNow() + 2
		end
	end

	local counts = tally(options)
	local best, bestCount = {}, -1
	for _, name in ipairs(options) do
		if counts[name] > bestCount then
			best, bestCount = { name }, counts[name]
		elseif counts[name] == bestCount then
			best[#best + 1] = name
		end
	end
	local winner = best[math.random(#best)]

	active = nil
	lastWinner = winner
	VoteEnd:FireAllClients(winner, MapService.GetInfo(winner).Title)
	return winner
end

return VoteService
]])

	add("StarterPlayerScripts", { "IslasClient" }, "Cliente", "LocalScript", [[
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
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "AchievementsUI", "ModuleScript", [[
-- AchievementsUI: lista de logros con progreso y estadisticas.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Achievements = require(Shared:WaitForChild("Achievements"))
local Format = require(Shared:WaitForChild("Format"))

local AchievementsUI = {}
local C = Color3.fromRGB

function AchievementsUI.Init(modules)
	local UI, State = modules.UI, modules.State
	local T = UI.Theme
	local gui = UI.Gui("LogrosGui", 10)
	local win = UI.Window(gui, "🏆 LOGROS", UDim2.new(0.6, 0, 0.75, 0), C(200, 150, 40))
	local stats = UI.Label(win.Content, { Font = T.Body, TextSize = 14, TextColor3 = T.Muted, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Left })
	local list = UI.New("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -46),
		Position = UDim2.new(0, 0, 0, 44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = win.Content,
	})
	UI.New("UIListLayout", { Padding = UDim.new(0, 6), Parent = list })

	local function render()
		local data = State.Data
		if not data then
			return
		end
		local s = data.Stats or {}
		stats.Text = string.format("Victorias: %d  ·  Rondas: %d  ·  Mejor racha: %d  ·  Monedas ganadas: %s  ·  Mapas: %d  ·  Desastres: %d",
			s.Wins or 0, s.Rounds or 0, s.BestStreak or 0, Format.Number(s.CoinsEarned or 0), s.MapsSurvived or 0, s.DisastersSurvived or 0)
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local done = 0
		for _, a in ipairs(Achievements) do
			local got = data.Achievements and data.Achievements[a.Id]
			if got then
				done = done + 1
			end
			local value = math.min(s[a.Stat] or 0, a.Goal)
			local row = UI.Panel(list, { Size = UDim2.new(1, -10, 0, 58), BackgroundColor3 = got and C(60, 55, 25) or T.Panel })
			UI.Stroke(row, got and T.Accent or T.Panel3, got and 2 or 1)
			UI.Label(row, { Text = got and "🏆" or "🔒", TextSize = 28, Size = UDim2.new(0, 50, 1, 0) })
			UI.Label(row, { Text = a.Name, Font = T.Black, TextSize = 17, Size = UDim2.new(1, -200, 0, 22), Position = UDim2.new(0, 52, 0, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = got and T.Accent or T.Text })
			UI.Label(row, { Text = a.Desc, Font = T.Body, TextSize = 13, TextColor3 = T.Muted, Size = UDim2.new(1, -200, 0, 20), Position = UDim2.new(0, 52, 0, 30), TextXAlignment = Enum.TextXAlignment.Left })
			UI.Label(row, { Text = got and "¡Hecho!" or (value .. " / " .. a.Goal), Font = T.Black, TextSize = 15, Size = UDim2.new(0, 140, 0, 22), Position = UDim2.new(1, -146, 0, 6), TextXAlignment = Enum.TextXAlignment.Right })
			UI.Label(row, { Text = "+" .. a.Reward .. " 🪙", Font = T.Black, TextSize = 14, TextColor3 = T.Accent, Size = UDim2.new(0, 140, 0, 20), Position = UDim2.new(1, -146, 0, 30), TextXAlignment = Enum.TextXAlignment.Right })
		end
		win.Title.Text = "🏆 LOGROS  " .. done .. "/" .. #Achievements
	end
	win.OnOpen = render
	State.OnData(function()
		if win.IsOpen() then
			render()
		end
	end)
	AchievementsUI.Toggle = win.Toggle
end

return AchievementsUI
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "DailyUI", "ModuleScript", [[
-- DailyUI: recompensa diaria con racha de 7 dias.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local DailyUI = {}
local C = Color3.fromRGB

function DailyUI.Init(modules)
	local UI, State = modules.UI, modules.State
	local T = UI.Theme
	local gui = UI.Gui("DiarioGui", 10)
	local win = UI.Window(gui, "🎁 RECOMPENSA DIARIA", UDim2.new(0, 620, 0, 300), C(80, 200, 120))
	local content = win.Content
	local days = UI.New("Frame", { Size = UDim2.new(1, 0, 0, 130), BackgroundTransparency = 1, Parent = content })
	UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), Parent = days })
	local info = UI.Label(content, { Font = T.Body, TextSize = 15, TextColor3 = T.Muted, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 136) })
	local claim = UI.Button(content, "RECLAMAR", { Size = UDim2.new(0, 220, 0, 46), Position = UDim2.new(0.5, -110, 1, -50), BackgroundColor3 = T.Good, TextSize = 20 }, function()
		Net.Event("DailyClaim"):FireServer()
		task.delay(0.5, function()
			win.Close()
		end)
	end)

	local function render()
		local data = State.Data
		if not data then
			return
		end
		for _, c in ipairs(days:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local streak = data.DailyStreak or 0
		local nextDay = data.DailyAvailable and math.min(streak + 1, Config.DailyRewardMaxDays) or streak
		for d = 1, Config.DailyRewardMaxDays do
			local got = d < nextDay or (not data.DailyAvailable and d <= streak)
			local today = data.DailyAvailable and d == nextDay
			local box = UI.Panel(days, { Size = UDim2.new(0, 76, 1, 0), BackgroundColor3 = today and C(60, 120, 80) or (got and T.Panel3 or T.Panel) })
			UI.Stroke(box, today and T.Good or T.Panel3, today and 3 or 1)
			UI.Label(box, { Text = "Dia " .. d, Font = T.Black, TextSize = 15, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 6) })
			UI.Label(box, { Text = got and "✔" or "🪙", TextSize = 32, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 0, 32) })
			UI.Label(box, { Text = tostring(Config.DailyRewardBase * d), Font = T.Black, TextSize = 16, TextColor3 = T.Accent, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -30) })
		end
		claim.Visible = data.DailyAvailable == true
		info.Text = data.DailyAvailable and "¡Tu recompensa de hoy esta lista! Vuelve cada dia para que suba (si pasan mas de 48 h, la racha vuelve al dia 1)."
			or "Ya la has reclamado hoy. Vuelve manana para seguir la racha."
	end

	win.OnOpen = render
	State.OnData(function(data, old)
		if win.IsOpen() then
			render()
		end
		-- se abre sola la primera vez que entras si hay recompensa
		if not old and data.DailyAvailable then
			task.delay(4, win.Open)
		end
	end)
	Net.Event("OpenUI").OnClientEvent:Connect(function(what)
		if what == "Daily" then
			win.Open()
		end
	end)
	DailyUI.Toggle = win.Toggle
end

return DailyUI
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "DebrisFX", "ModuleScript", [[
-- DebrisFX: fragmentos visuales cuando algo se rompe. Solo existen en este cliente:
--   * el servidor no simula ni replica nada (cero coste de red y de fisica en el servidor),
--   * se reutilizan piezas de un pool (no se crean/destruyen sin parar),
--   * el numero de fragmentos depende de la calidad (Quality) y la distancia,
--   * no chocan entre si ni con los jugadores (grupo de colision IslasFx).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local DebrisFX = {}

local Quality, SoundFX
local folder
local pool = {} -- piezas libres
local active = {} -- { part, born, life, fading }
local total = 0

local function getPart()
	local p = table.remove(pool)
	if p then
		return p
	end
	local settings = Quality.Settings()
	if total >= settings.MaxFragments then
		-- reciclar el fragmento mas viejo
		local oldest = table.remove(active, 1)
		if oldest then
			return oldest.part
		end
		return nil
	end
	total = total + 1
	p = Instance.new("Part")
	p.Name = "Fragmento"
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	pcall(function()
		p.CollisionGroup = "IslasFx"
	end)
	return p
end

local function release(entry)
	local p = entry.part
	p.Anchored = true
	p.Parent = nil
	pool[#pool + 1] = p
end

local function spawnFragments(rec, camPos, settings)
	local center, size = rec.p, rec.s
	if typeof(center) ~= "Vector3" or typeof(size) ~= "Vector3" then
		return
	end
	local dist = (center - camPos).Magnitude
	if dist > settings.Distance then
		return
	end
	local vol = size.X * size.Y * size.Z
	local n = math.clamp(math.floor(math.sqrt(vol) / 2) + 1, 1, settings.PerBreak)
	if dist > settings.Distance * 0.6 then
		n = math.max(1, math.floor(n / 2))
	end
	local scale = 1 / (n ^ (1 / 3))
	local mat = Enum.Material.SmoothPlastic
	pcall(function()
		mat = Enum.Material[rec.m]
	end)
	local glass = rec.m == "Glass"
	for _ = 1, n do
		local p = getPart()
		if not p then
			return
		end
		local r = 0.6 + math.random() * 0.5
		p.Size = Vector3.new(
			math.clamp(size.X * scale * r, 0.3, 6),
			math.clamp(size.Y * scale * r, 0.3, 6),
			math.clamp(size.Z * scale * r, 0.3, 6)
		)
		local off = Vector3.new((math.random() - 0.5) * size.X, (math.random() - 0.5) * size.Y, (math.random() - 0.5) * size.Z) * 0.8
		p.CFrame = CFrame.new(center + off) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		p.Color = rec.c or Color3.new(0.6, 0.6, 0.6)
		p.Material = mat
		p.Transparency = glass and 0.45 or 0
		p.CanCollide = true
		p.Anchored = false
		p.Parent = folder
		local dir = off.Magnitude > 0.1 and off.Unit or Vector3.yAxis
		p.AssemblyLinearVelocity = dir * (8 + math.random() * 14) + Vector3.new(0, 10 + math.random() * 12, 0)
		p.AssemblyAngularVelocity = Vector3.new(math.random() * 10 - 5, math.random() * 10 - 5, math.random() * 10 - 5)
		active[#active + 1] = { part = p, born = os.clock(), life = settings.Life * (0.7 + math.random() * 0.6) }
	end
end

function DebrisFX.Burst(batch)
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local settings = Quality.Settings()
	local sumPos, count, glassCount = Vector3.zero, 0, 0
	for _, rec in ipairs(batch) do
		spawnFragments(rec, camPos, settings)
		if typeof(rec.p) == "Vector3" then
			sumPos = sumPos + rec.p
			count = count + 1
			if rec.m == "Glass" then
				glassCount = glassCount + 1
			end
		end
	end
	if count > 0 and SoundFX then
		local center = sumPos / count
		if (center - camPos).Magnitude < 250 then
			SoundFX.PlayAt(glassCount > count / 2 and "Glass" or "Crumble", center, math.clamp(0.3 + count * 0.05, 0.3, 1))
		end
	end
end

function DebrisFX.Init(modules)
	Quality = modules.Quality
	SoundFX = modules.SoundFX
	folder = Instance.new("Folder")
	folder.Name = "FragmentosLocales"
	folder.Parent = workspace

	Net.Event("Shatter").OnClientEvent:Connect(function(batch)
		if typeof(batch) == "table" then
			DebrisFX.Burst(batch)
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local now = os.clock()
		for i = #active, 1, -1 do
			local e = active[i]
			local age = now - e.born
			if age > e.life then
				local t = math.clamp((age - e.life) / 0.6, 0, 1)
				e.part.Transparency = math.max(e.part.Transparency, t)
				if t >= 1 or e.part.Position.Y < -400 then
					table.remove(active, i)
					release(e)
				end
			end
		end
	end)

	-- si baja la calidad, se sueltan fragmentos sobrantes
	Quality.OnChanged(function()
		local max = Quality.Settings().MaxFragments
		while #active > max do
			release(table.remove(active, 1))
		end
	end)
end

return DebrisFX
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "DisasterFX", "ModuleScript", [[
-- DisasterFX: dibuja en el cliente todos los efectos de los desastres (no se replican piezas desde el servidor).
-- Mensajes del servidor: (tipo, idDesastre, ...). Ver Hazards.lua y Disasters/*.lua en el servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Net = require(Shared:WaitForChild("Net"))
local Paths = require(Shared:WaitForChild("Paths"))

local player = Players.LocalPlayer
local C = Color3.fromRGB
local V = Vector3.new

local DisasterFX = {}

local UI, Quality, SoundFX, Popups
local folder
local buckets = {} -- [id] = { inst = {}, update = {}, zones = {}, ufos = {} }
local overlay, banner
local shakeIntensity, shakeEnd = 0, 0
DisasterFX.ShakeScale = 1

local function now()
	return workspace:GetServerTimeNow()
end

local function bucket(id)
	local b = buckets[id]
	if not b then
		b = { inst = {}, update = {}, zones = {}, ufos = {} }
		buckets[id] = b
	end
	return b
end

local function track(id, inst)
	table.insert(bucket(id).inst, inst)
	return inst
end

local function onUpdate(id, fn)
	table.insert(bucket(id).update, fn)
end

local function clearId(id)
	local b = buckets[id]
	if not b then
		return
	end
	for _, inst in ipairs(b.inst) do
		if inst.Parent then
			inst:Destroy()
		end
	end
	buckets[id] = nil
	if b.tinted then
		overlay.BackgroundTransparency = 1
	end
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = folder
	return p
end

local function currentMap()
	for _, c in ipairs(workspace:GetChildren()) do
		if c.Name:sub(1, 11) == "MapaActual_" then
			return c
		end
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local function groundAt(x, z, fallback)
	local map = currentMap()
	if not map then
		return fallback
	end
	rayParams.FilterDescendantsInstances = { map }
	local hit = workspace:Raycast(V(x, fallback + 600, z), V(0, -1400, 0), rayParams)
	return hit and hit.Position.Y or fallback
end

local function camPos()
	local cam = workspace.CurrentCamera
	return cam and cam.CFrame.Position or Vector3.zero
end

local function shake(intensity, seconds)
	if intensity * DisasterFX.ShakeScale >= shakeIntensity or os.clock() >= shakeEnd then
		shakeIntensity = intensity * DisasterFX.ShakeScale
	end
	shakeEnd = math.max(shakeEnd, os.clock() + seconds)
end
DisasterFX.Shake = shake

-- ======================================================================
-- Cartel de aviso
-- ======================================================================
local bannerToken = 0
local function showBanner(info, delay)
	bannerToken = bannerToken + 1
	local token = bannerToken
	banner.Icon.Text = info.Icon or "⚠️"
	banner.Title.Text = string.upper(info.Title or "")
	banner.Title.TextColor3 = info.Color or C(255, 230, 120)
	banner.Desc.Text = info.Desc or ""
	banner.Frame.Visible = true
	UI.Pop(banner.Frame, 0.2)
	SoundFX.Play("Warning", 0.7)
	local endAt = os.clock() + (delay or 0)
	task.spawn(function()
		while token == bannerToken and os.clock() < endAt do
			banner.Count.Text = "Empieza en " .. math.ceil(endAt - os.clock())
			task.wait(0.2)
		end
		if token == bannerToken then
			banner.Count.Text = "¡YA!"
			task.wait(3)
			if token == bannerToken then
				banner.Frame.Visible = false
			end
		end
	end)
end

-- ======================================================================
-- Clima (particulas alrededor de la camara)
-- ======================================================================
local WEATHER = {
	rain = { color = C(170, 190, 230), rate = 400, speed = 90, size = 0.25, length = 3, transparency = 0.4 },
	acid = { color = C(140, 255, 90), rate = 400, speed = 80, size = 0.25, length = 3, transparency = 0.3 },
	snow = { color = C(255, 255, 255), rate = 300, speed = 12, size = 0.5, length = 0.5, transparency = 0.1, spread = 30 },
	sand = { color = C(220, 180, 110), rate = 500, speed = 40, size = 0.6, length = 1, transparency = 0.35, sideways = true },
}

local function weather(id, kind)
	local w = WEATHER[kind]
	if not w then
		return
	end
	local emitterPart = track(id, part({ Name = "Clima", Size = V(120, 1, 120), Transparency = 1 }))
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(w.color)
	e.LightEmission = 0.2
	e.Size = NumberSequence.new(w.size)
	e.Transparency = NumberSequence.new(w.transparency)
	e.Lifetime = NumberRange.new(1.5, 2.2)
	e.Speed = NumberRange.new(w.speed * 0.8, w.speed)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(w.spread or 5, w.spread or 5)
	if w.length > 1 then
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new(w.length)
	end
	e.Parent = emitterPart
	local function applyRate()
		e.Rate = w.rate * ({ 0.25, 0.6, 1 })[Quality.Level]
	end
	applyRate()
	Quality.OnChanged(applyRate)
	local t = 0
	onUpdate(id, function()
		local p = camPos()
		t = t + 1
		local off = w.sideways and V(math.sin(t * 0.01) * 30, 0, 0) or Vector3.zero
		emitterPart.CFrame = CFrame.new(p + V(0, 40, 0) + off)
		return true
	end)
end

-- ======================================================================
-- Visuales con recorrido (tornado, agujero negro, ovni)
-- ======================================================================
local function tornadoVisual(id, data)
	local path = Paths.Make(data.points, data.speed, data.t0, data.loop)
	local layers = {}
	for i = 1, 9 do
		local d = 8 + i * 5.5
		layers[i] = track(id, part({
			Name = "Embudo",
			Shape = Enum.PartType.Cylinder,
			Size = V(15, d, d),
			Color = C(120 + i * 3, 120 + i * 3, 125 + i * 3),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.45 + i * 0.03,
		}))
	end
	local bits = {}
	local nBits = ({ 8, 18, 30 })[Quality.Level]
	for i = 1, nBits do
		bits[i] = {
			p = track(id, part({ Name = "Escombro", Size = V(1.5, 1.5, 1.5), Color = i % 2 == 0 and C(130, 95, 60) or C(140, 140, 145), Material = Enum.Material.Wood })),
			a = math.random() * math.pi * 2,
			h = math.random(),
		}
	end
	local base = groundAt(path.points[1][1], path.points[1][2], 0)
	local lastRay = 0
	local smoothBase = base
	onUpdate(id, function(t)
		local x, z = Paths.At(path, t)
		if os.clock() - lastRay > 0.25 then
			lastRay = os.clock()
			base = groundAt(x, z, smoothBase)
		end
		smoothBase = smoothBase + (base - smoothBase) * 0.1
		for i, l in ipairs(layers) do
			local wob = math.sin(t * 2 + i * 0.6) * i * 0.4
			l.CFrame = CFrame.new(x + wob, smoothBase + (i - 0.5) * 15, z) * CFrame.Angles(0, t * 3 + i, math.rad(90))
		end
		for _, b in ipairs(bits) do
			local ang = b.a + t * (3.4 - b.h * 1.8)
			local r = 6 + b.h * 32
			b.p.CFrame = CFrame.new(x + math.cos(ang) * r, smoothBase + b.h * 130, z + math.sin(ang) * r) * CFrame.Angles(t * 3, t * 2, 0)
		end
		local d = (camPos() - V(x, smoothBase, z)).Magnitude
		if d < 120 then
			shake(0.6 * (1 - d / 120), 0.3)
		end
		return true
	end)
end

local function blackHoleVisual(id, data)
	local path = Paths.Make(data.points, data.speed, data.t0, data.loop)
	local core = track(id, part({ Name = "AgujeroNegro", Shape = Enum.PartType.Ball, Size = V(12, 12, 12), Color = C(0, 0, 0), Material = Enum.Material.SmoothPlastic }))
	local glow = track(id, part({ Name = "Halo", Shape = Enum.PartType.Ball, Size = V(18, 18, 18), Color = C(140, 80, 255), Transparency = 0.7 }))
	local rings = {}
	for i = 1, 3 do
		rings[i] = track(id, part({ Name = "Anillo", Shape = Enum.PartType.Cylinder, Size = V(0.4, 26 + i * 10, 26 + i * 10), Color = C(160 + i * 20, 90, 255), Transparency = 0.5 + i * 0.1 }))
	end
	local light = Instance.new("PointLight")
	light.Color = C(160, 90, 255)
	light.Range = 60
	light.Brightness = 3
	light.Parent = glow
	local base = groundAt(path.points[1][1], path.points[1][2], 0)
	local lastRay = 0
	local t0 = now()
	onUpdate(id, function(t)
		local x, z = Paths.At(path, t)
		if os.clock() - lastRay > 0.5 then
			lastRay = os.clock()
			base = groundAt(x, z, base)
		end
		local grow = 1 + math.clamp((t - t0) / 150, 0, 1) * 0.8
		local center = V(x, base + (data.height or 25), z)
		core.Size = V(12, 12, 12) * grow
		core.CFrame = CFrame.new(center)
		glow.Size = V(18, 18, 18) * grow * (1 + math.sin(t * 4) * 0.05)
		glow.CFrame = CFrame.new(center)
		for i, r in ipairs(rings) do
			r.CFrame = CFrame.new(center) * CFrame.Angles(math.sin(t * 0.7 + i) * 0.4, t * (1.5 + i * 0.4), math.rad(90))
		end
		return true
	end)
end

local function ufoVisual(id, data)
	local path = Paths.Make(data.points, data.speed, data.t0, data.loop)
	local disc = track(id, part({ Name = "Ovni", Shape = Enum.PartType.Cylinder, Size = V(3, 26, 26), Color = C(160, 165, 175), Material = Enum.Material.Metal }))
	local dome = track(id, part({ Name = "Cupula", Shape = Enum.PartType.Ball, Size = V(11, 11, 11), Color = C(120, 255, 200), Material = Enum.Material.Glass, Transparency = 0.3 }))
	local ring = track(id, part({ Name = "Luces", Shape = Enum.PartType.Cylinder, Size = V(1, 28, 28), Color = C(120, 255, 200), Transparency = 0.2 }))
	local beam = track(id, part({ Name = "Rayo", Shape = Enum.PartType.Cylinder, Size = V(1, 20, 20), Color = C(120, 255, 170), Transparency = 1 }))
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 80
	light.Angle = 40
	light.Color = C(120, 255, 200)
	light.Brightness = 4
	light.Parent = disc
	local entry = { beamUntil = 0 }
	bucket(id).ufos[data.index or 1] = entry
	local base = groundAt(path.points[1][1], path.points[1][2], 0)
	onUpdate(id, function(t)
		local x, z = Paths.At(path, t)
		local y = base + (data.height or 70) + math.sin(t * 1.5 + (data.index or 1)) * 2
		local cf = CFrame.new(x, y, z)
		disc.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
		dome.CFrame = cf + V(0, 2.5, 0)
		ring.CFrame = cf * CFrame.Angles(0, t * 2, math.rad(90)) - V(0, 1, 0)
		if os.clock() < entry.beamUntil then
			local h = y - base
			beam.Size = V(h, 20, 20)
			beam.CFrame = CFrame.new(x, base + h / 2, z) * CFrame.Angles(0, 0, math.rad(90))
			beam.Transparency = 0.55 + math.sin(t * 10) * 0.1
		else
			beam.Transparency = 1
		end
		return true
	end)
end

-- ======================================================================
-- Mensajes
-- ======================================================================
local handlers = {}

handlers.banner = function(id, info, delay)
	showBanner(info, delay)
end

handlers["end"] = function(id)
	clearId(id)
end

handlers.clear = function()
	for id in pairs(buckets) do
		clearId(id)
	end
	overlay.BackgroundTransparency = 1
	shakeIntensity = 0
	banner.Frame.Visible = false
end

handlers.shake = function(id, intensity, seconds)
	shake(intensity, seconds)
end

handlers.flash = function()
	overlay.BackgroundColor3 = Color3.new(1, 1, 1)
	overlay.BackgroundTransparency = 0.3
	UI.Tween(overlay, 0.35, { BackgroundTransparency = 1 })
end

handlers.tint = function(id, color, transparency)
	overlay.BackgroundColor3 = color
	overlay.BackgroundTransparency = transparency
	bucket(id).tinted = true
end

handlers.weather = weather

handlers.marker = function(id, pos, radius, color, seconds)
	local p = track(id, part({
		Name = "Aviso",
		Shape = Enum.PartType.Cylinder,
		Size = V(0.3, radius * 2, radius * 2),
		CFrame = CFrame.new(pos + V(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.6,
	}))
	local born = os.clock()
	onUpdate(id, function()
		local age = os.clock() - born
		if age >= seconds or not p.Parent then
			p:Destroy()
			return false
		end
		p.Transparency = 0.35 + 0.3 * math.abs(math.sin(age * (4 + age * 4)))
		return true
	end)
end

handlers.markers = function(id, list, color)
	for _, pos in ipairs(list or {}) do
		track(id, part({
			Name = "Baliza",
			Size = V(1, 60, 1),
			CFrame = CFrame.new(pos + V(0, 30, 0)),
			Color = color,
			Transparency = 0.4,
		}))
	end
end

handlers.meteor = function(id, from, to, seconds, color, size)
	local m = track(id, part({ Name = "Meteoro", Shape = Enum.PartType.Ball, Size = V(size, size, size), Color = color, CFrame = CFrame.new(from) }))
	if Quality.Level >= 2 then
		local a0 = Instance.new("Attachment")
		a0.Position = V(0, size * 0.4, 0)
		a0.Parent = m
		local a1 = Instance.new("Attachment")
		a1.Position = V(0, -size * 0.4, 0)
		a1.Parent = m
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.5
		trail.Color = ColorSequence.new(color, C(80, 60, 50))
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.LightEmission = 1
		trail.Parent = m
		local fire = Instance.new("Fire")
		fire.Size = size * 1.5
		fire.Heat = 0
		fire.Parent = m
	end
	local born = os.clock()
	onUpdate(id, function()
		local k = (os.clock() - born) / seconds
		if k >= 1 or not m.Parent then
			m:Destroy()
			return false
		end
		local pos = from:Lerp(to, k * k)
		m.CFrame = CFrame.new(pos)
		return true
	end)
end

handlers.explosion = function(id, pos, radius, color)
	local e = track(id, part({ Name = "Explosion", Shape = Enum.PartType.Ball, Size = V(3, 3, 3), Color = color, CFrame = CFrame.new(pos + V(0, 2, 0)), Transparency = 0.15 }))
	local big = radius * 2.3
	UI.Tween(e, 0.45, { Size = V(big, big, big), Transparency = 1 })
	task.delay(0.5, function()
		e:Destroy()
	end)
	local d = (camPos() - pos).Magnitude
	if d < radius * 5 then
		shake(math.clamp(1.4 * (1 - d / (radius * 5)), 0.1, 1.4), 0.45)
	end
	if d < 300 then
		SoundFX.PlayAt("Explosion", pos, 0.8)
	end
end

handlers.bolt = function(id, from, to, color)
	local segments = 6
	local prev = from
	for i = 1, segments do
		local k = i / segments
		local target = from:Lerp(to, k)
		if i < segments then
			target = target + V((math.random() - 0.5) * 10, 0, (math.random() - 0.5) * 10)
		end
		local mid = (prev + target) / 2
		local len = (target - prev).Magnitude
		local seg = track(id, part({ Name = "Rayo", Size = V(0.8, 0.8, len), Color = color, CFrame = CFrame.lookAt(mid, target) }))
		task.delay(0.18, function()
			seg:Destroy()
		end)
		prev = target
	end
	local d = (camPos() - to).Magnitude
	if d < 200 then
		handlers.flash()
	end
	if d < 400 then
		SoundFX.PlayAt("Thunder", to, 1)
	end
end

handlers.zone = function(id, key, pos, radius, color, fire)
	local b = bucket(id)
	local z = b.zones[key]
	if not z then
		local p = track(id, part({
			Name = "Zona",
			Shape = Enum.PartType.Ball,
			Size = V(1, 1, 1),
			CFrame = CFrame.new(pos + V(0, 1, 0)),
			Color = color,
			Transparency = 0.55,
		}))
		if fire and Quality.Level >= 2 then
			local f = Instance.new("Fire")
			f.Size = 20
			f.Heat = 12
			f.Parent = p
		end
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 30
		light.Brightness = 2
		light.Parent = p
		z = { part = p }
		b.zones[key] = z
	end
	local d = radius * 2
	UI.Tween(z.part, 1, { Size = V(d, d, d) }, Enum.EasingStyle.Linear)
end

handlers.liquid = function(id, data)
	local mat = Enum.Material.SmoothPlastic
	pcall(function()
		mat = Enum.Material[data.material]
	end)
	local p = track(id, part({
		Name = "Liquido",
		Size = V(data.sx, 4, data.sz),
		CFrame = CFrame.new(data.cx, data.y0 - 2, data.cz),
		Color = data.color,
		Material = mat,
		Transparency = data.transparency,
	}))
	onUpdate(id, function(t)
		local level = Paths.Level(data.y0, data.y1, data.t0, data.rise, t)
		p.CFrame = CFrame.new(data.cx, level - 2, data.cz)
		return true
	end)
end

handlers.path = function(id, kind, data)
	if kind == "Tornado" then
		tornadoVisual(id, data)
	elseif kind == "BlackHole" then
		blackHoleVisual(id, data)
	elseif kind == "UFO" then
		ufoVisual(id, data)
	end
end

handlers.beam = function(id, index, seconds)
	local entry = bucket(id).ufos[index]
	if entry then
		entry.beamUntil = os.clock() + seconds
	end
end

handlers.wave = function(id, data)
	local dir = data.dir
	local horizontal = dir.X ~= 0
	local size = horizontal and V(data.thick, data.height, data.width) or V(data.width, data.height, data.thick)
	local w = track(id, part({ Name = "Ola", Size = size, Color = C(40, 120, 210), Material = Enum.Material.SmoothPlastic, Transparency = 0.25 }))
	local foamSize = horizontal and V(data.thick * 0.6, 2, data.width) or V(data.width, 2, data.thick * 0.6)
	local foam = track(id, part({ Name = "Espuma", Size = foamSize, Color = C(235, 245, 255), Transparency = 0.2, Material = Enum.Material.SmoothPlastic }))
	onUpdate(id, function(t)
		local k = t - data.t0
		if k > data.duration + 2 then
			w:Destroy()
			foam:Destroy()
			return false
		end
		local front = data.start + dir * data.speed * math.max(0, k)
		local center = front - dir * data.thick / 2 + V(0, data.height / 2, 0)
		w.CFrame = CFrame.new(center)
		foam.CFrame = CFrame.new(center + V(0, data.height / 2, 0) + dir * data.thick * 0.2)
		local d = (camPos() - center).Magnitude
		if d < 150 then
			shake(0.7 * (1 - d / 150), 0.3)
		end
		return true
	end)
end

handlers.infected = function(id, userId, on)
	if userId == player.UserId and Popups then
		if on then
			Popups.Toast("🦠 ¡Estas infectado! Busca una estacion de cura (cruz verde)", C(110, 255, 90))
		else
			Popups.Toast("✚ Te has curado", C(80, 255, 140))
		end
	end
end

function DisasterFX.Init(modules)
	UI, Quality, SoundFX, Popups = modules.UI, modules.Quality, modules.SoundFX, modules.Popups
	folder = Instance.new("Folder")
	folder.Name = "EfectosLocales"
	folder.Parent = workspace

	local gui = UI.Gui("DesastresGui", 4, true)
	overlay = UI.New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		Parent = gui,
	})

	local frame = UI.Panel(gui, {
		Name = "Aviso",
		Size = UDim2.new(0, 560, 0, 120),
		Position = UDim2.new(0.5, 0, 0, 96),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C(70, 12, 12),
		BackgroundTransparency = 0.1,
		Visible = false,
	})
	UI.Stroke(frame, C(255, 90, 60), 3)
	UI.New("UISizeConstraint", { MaxSize = Vector2.new(560, 120), Parent = frame })
	local icon = UI.Label(frame, { Text = "⚠️", TextSize = 56, Size = UDim2.new(0, 90, 1, 0), Position = UDim2.new(0, 6, 0, 0) })
	local title = UI.Label(frame, { Font = UI.Theme.Black, TextSize = 32, Size = UDim2.new(1, -110, 0, 40), Position = UDim2.new(0, 96, 0, 8), TextXAlignment = Enum.TextXAlignment.Left })
	UI.TextStroke(title, 2)
	local desc = UI.Label(frame, { Font = UI.Theme.Body, TextSize = 16, TextWrapped = true, Size = UDim2.new(1, -110, 0, 44), Position = UDim2.new(0, 96, 0, 46), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	local count = UI.Label(frame, { Font = UI.Theme.Black, TextSize = 16, TextColor3 = C(255, 220, 120), Size = UDim2.new(1, -110, 0, 20), Position = UDim2.new(0, 96, 1, -26), TextXAlignment = Enum.TextXAlignment.Left })
	banner = { Frame = frame, Icon = icon, Title = title, Desc = desc, Count = count }

	Net.Event("DisasterFX").OnClientEvent:Connect(function(kind, id, ...)
		local h = handlers[kind]
		if h then
			local ok, err = pcall(h, id, ...)
			if not ok then
				warn("DisasterFX " .. tostring(kind) .. ": " .. tostring(err))
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		local t = now()
		for id, b in pairs(buckets) do
			local list = b.update
			for i = #list, 1, -1 do
				local ok, keep = pcall(list[i], t)
				if not ok or keep == false then
					table.remove(list, i)
				end
			end
		end
		-- temblor de camara
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			if shakeIntensity > 0 and os.clock() < shakeEnd then
				hum.CameraOffset = V((math.random() - 0.5) * shakeIntensity, (math.random() - 0.5) * shakeIntensity, 0)
			elseif hum.CameraOffset ~= Vector3.zero then
				hum.CameraOffset = Vector3.zero
				shakeIntensity = 0
			end
		end
	end)
end

return DisasterFX
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "ElevatorUI", "ModuleScript", [[
-- ElevatorUI: menu de plantas al pulsar el boton dentro de un ascensor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local ElevatorUI = {}
local C = Color3.fromRGB

function ElevatorUI.Init(modules)
	local UI = modules.UI
	local T = UI.Theme
	local gui = UI.Gui("AscensorGui", 9)
	local panel = UI.Panel(gui, {
		Size = UDim2.new(0, 260, 0, 100),
		Position = UDim2.new(1, -280, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = C(30, 32, 40),
		Visible = false,
	})
	UI.Stroke(panel, C(120, 255, 140), 2)
	UI.Label(panel, { Text = "▲▼ ELIGE PLANTA", Font = T.Black, TextSize = 16, TextColor3 = C(120, 255, 140), Size = UDim2.new(1, 0, 0, 30) })
	local grid = UI.New("Frame", { Size = UDim2.new(1, -16, 1, -70), Position = UDim2.new(0, 8, 0, 32), BackgroundTransparency = 1, Parent = panel })
	UI.New("UIGridLayout", { CellSize = UDim2.new(0, 54, 0, 44), CellPadding = UDim2.new(0, 6, 0, 6), Parent = grid })
	UI.Button(panel, "CERRAR", { Size = UDim2.new(1, -16, 0, 28), Position = UDim2.new(0, 8, 1, -34), BackgroundColor3 = T.Panel3, TextColor3 = T.Text, TextSize = 13 }, function()
		panel.Visible = false
	end)

	Net.Event("ElevatorMenu").OnClientEvent:Connect(function(id, labels, current)
		for _, c in ipairs(grid:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, label in ipairs(labels) do
			UI.Button(grid, tostring(label), {
				BackgroundColor3 = i == current and C(120, 255, 140) or C(60, 64, 80),
				TextColor3 = i == current and C(20, 40, 20) or C(255, 255, 255),
				TextSize = 18,
			}, function()
				Net.Event("ElevatorRequest"):FireServer(id, i)
				panel.Visible = false
			end)
		end
		local rows = math.ceil(#labels / 4)
		panel.Size = UDim2.new(0, 260, 0, 70 + rows * 50)
		panel.Visible = true
		UI.Pop(panel, 0.1)
	end)
end

return ElevatorUI
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "GearClient", "ModuleScript", [[
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
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "Hud", "ModuleScript", [[
-- Hud: barra superior (fase, tiempo, vivos, desastres, modificador), monedas, nivel con barra de XP
-- y botones del menu.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Format"))

local Hud = {}
local C = Color3.fromRGB

local PHASE_TEXT = {
	Waiting = "ESPERANDO JUGADORES",
	Intermission = "DESCANSO",
	Vote = "VOTACION",
	Loading = "CARGANDO MAPA",
	Round = "¡SOBREVIVE!",
	Results = "RESULTADOS",
}

function Hud.Init(modules)
	local UI, State, SoundFX = modules.UI, modules.State, modules.SoundFX
	local T = UI.Theme
	local gui = UI.Gui("HudGui", 2)

	-- ===== Barra superior =====
	local top = UI.Panel(gui, {
		Size = UDim2.new(0, 420, 0, 62),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.15,
	})
	UI.Stroke(top, T.Accent, 2, 0.3)
	local phase = UI.Label(top, { Font = T.Black, TextSize = 20, Size = UDim2.new(1, -110, 0, 26), Position = UDim2.new(0, 14, 0, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Accent })
	local status = UI.Label(top, { Font = T.Body, TextSize = 14, Size = UDim2.new(1, -110, 0, 22), Position = UDim2.new(0, 14, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Muted, TextTruncate = Enum.TextTruncate.AtEnd })
	local timer = UI.Label(top, { Font = T.Black, TextSize = 32, Size = UDim2.new(0, 100, 1, 0), Position = UDim2.new(1, -108, 0, 0), TextXAlignment = Enum.TextXAlignment.Right })
	UI.TextStroke(timer, 2)

	local chips = UI.New("Frame", {
		Size = UDim2.new(0, 600, 0, 30),
		Position = UDim2.new(0.5, 0, 0, 76),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), Parent = chips })

	local function chip(text, color)
		local f = UI.Panel(chips, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = color or T.Panel2, BackgroundTransparency = 0.1 })
		UI.Padding(f, 4)
		UI.Label(f, { Text = "  " .. text .. "  ", Font = T.Black, TextSize = 14, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = C(255, 255, 255) })
		return f
	end

	-- ===== Monedas y nivel (izquierda arriba) =====
	local left = UI.New("Frame", { Size = UDim2.new(0, 200, 0, 110), Position = UDim2.new(0, 10, 0, 8), BackgroundTransparency = 1, Parent = gui })
	local coinBox = UI.Panel(left, { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.15 })
	UI.Stroke(coinBox, T.Accent, 2, 0.3)
	UI.Label(coinBox, { Text = "🪙", TextSize = 26, Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(0, 4, 0, 0) })
	local coins = UI.Label(coinBox, { Text = "0", Font = T.Black, TextSize = 26, TextColor3 = T.Accent, Size = UDim2.new(1, -52, 1, 0), Position = UDim2.new(0, 44, 0, 0), TextXAlignment = Enum.TextXAlignment.Left })
	local streak = UI.Label(coinBox, { Text = "", Font = T.Black, TextSize = 18, TextColor3 = C(255, 140, 60), Size = UDim2.new(0, 70, 1, 0), Position = UDim2.new(1, 6, 0, 0), TextXAlignment = Enum.TextXAlignment.Left })
	UI.TextStroke(streak, 2)
	local levelBox = UI.Panel(left, { Size = UDim2.new(1, 0, 0, 56), Position = UDim2.new(0, 0, 0, 50), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.15 })
	local levelBadge = UI.Panel(levelBox, { Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0, 6, 0, 6), BackgroundColor3 = T.Info })
	local levelText = UI.Label(levelBadge, { Text = "1", Font = T.Black, TextSize = 22, Size = UDim2.fromScale(1, 1) })
	local titleText = UI.Label(levelBox, { Text = "Novato", Font = T.Font, TextSize = 15, Size = UDim2.new(1, -60, 0, 20), Position = UDim2.new(0, 56, 0, 6), TextXAlignment = Enum.TextXAlignment.Left })
	local barBg = UI.Panel(levelBox, { Size = UDim2.new(1, -62, 0, 12), Position = UDim2.new(0, 56, 0, 30), BackgroundColor3 = T.Panel3 })
	local bar = UI.Panel(barBg, { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.Info })
	local xpText = UI.Label(levelBox, { Text = "", Font = T.Body, TextSize = 11, TextColor3 = T.Muted, Size = UDim2.new(1, -62, 0, 12), Position = UDim2.new(0, 56, 0, 42), TextXAlignment = Enum.TextXAlignment.Left })

	-- contador de monedas que sube poco a poco (mas satisfactorio)
	local shownCoins, targetCoins = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		if shownCoins ~= targetCoins then
			local diff = targetCoins - shownCoins
			local step = math.max(1, math.abs(diff) * math.min(1, dt * 6))
			if math.abs(diff) <= step then
				shownCoins = targetCoins
			else
				shownCoins = shownCoins + (diff > 0 and step or -step)
			end
			coins.Text = Format.Number(shownCoins)
		end
	end)

	State.OnData(function(data, old)
		targetCoins = data.Coins or 0
		if old and data.Coins > old.Coins then
			UI.Pop(coinBox, 0.12)
		end
		local st = data.Stats and data.Stats.Streak or 0
		streak.Text = st >= 2 and ("🔥x" .. st) or ""
		if old and old.Stats and st > (old.Stats.Streak or 0) and st >= 2 then
			UI.Pop(streak, 0.4)
		end
		levelText.Text = tostring(data.Level)
		titleText.Text = data.Title or ""
		titleText.TextColor3 = data.TitleColor or T.Text
		levelBadge.BackgroundColor3 = data.TitleColor or T.Info
		bar.BackgroundColor3 = data.TitleColor or T.Info
		local k = data.LevelNeed and data.LevelNeed > 0 and (data.LevelXP / data.LevelNeed) or 0
		UI.Tween(bar, 0.4, { Size = UDim2.new(math.clamp(k, 0, 1), 0, 1, 0) })
		xpText.Text = (data.LevelXP or 0) .. " / " .. (data.LevelNeed or 0) .. " XP"
	end)

	-- ===== Menu (izquierda, centro) =====
	local menu = UI.New("Frame", { Size = UDim2.new(0, 64, 0, 330), Position = UDim2.new(0, 10, 0.5, -150), BackgroundTransparency = 1, Parent = gui })
	UI.New("UIListLayout", { Padding = UDim.new(0, 8), Parent = menu })
	local function menuButton(icon, label, color, onClick)
		local b = UI.Button(menu, icon, { Size = UDim2.new(0, 60, 0, 60), BackgroundColor3 = color, TextSize = 28, TextColor3 = C(255, 255, 255) }, onClick)
		UI.Stroke(b, C(0, 0, 0), 2, 0.4)
		local l = UI.Label(b, { Text = label, Font = T.Black, TextSize = 11, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -16) })
		UI.TextStroke(l, 1.5)
		return b
	end
	menuButton("🛒", "TIENDA", C(255, 160, 40), function()
		if modules.ShopUI then
			modules.ShopUI.Toggle()
		end
	end)
	local dailyBtn = menuButton("🎁", "DIARIO", C(80, 200, 120), function()
		if modules.DailyUI then
			modules.DailyUI.Toggle()
		end
	end)
	local dailyDot = UI.Panel(dailyBtn, { Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(1, -12, 0, -4), BackgroundColor3 = T.Bad, Visible = false })
	UI.Corner(dailyDot, 8)
	menuButton("🏆", "LOGROS", C(200, 150, 40), function()
		if modules.AchievementsUI then
			modules.AchievementsUI.Toggle()
		end
	end)
	menuButton("⚙️", "AJUSTES", C(110, 120, 150), function()
		if modules.SettingsUI then
			modules.SettingsUI.Toggle()
		end
	end)
	State.OnData(function(data)
		dailyDot.Visible = data.DailyAvailable == true
	end)

	-- ===== Estado de ronda =====
	local lastPhase = nil
	local function refreshRound(st)
		-- fundido al ir a la isla y al volver al lobby
		if lastPhase and st.Phase ~= lastPhase and modules.Popups and (st.Phase == "Round" or (lastPhase == "Results" and st.Phase ~= "Results")) then
			modules.Popups.Fade()
		end
		lastPhase = st.Phase
		phase.Text = PHASE_TEXT[st.Phase] or st.Phase or ""
		status.Text = st.Status or ""
		for _, c in ipairs(chips:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		if st.Phase == "Round" or st.Phase == "Results" then
			if st.Total and st.Total > 0 then
				chip("👥 " .. (st.Alive or 0) .. "/" .. st.Total, T.Panel2)
			end
			for _, d in ipairs(st.Disasters or {}) do
				chip((d.Icon or "⚠️") .. " " .. (d.Title or ""), C(150, 40, 40))
			end
		end
		if st.Modifier then
			chip("✨ " .. st.Modifier.Title, st.Modifier.Color)
		end
	end
	State.OnRound(refreshRound)

	local lastSecond = -1
	RunService.Heartbeat:Connect(function()
		local st = State.Round
		if st and st.EndsAt and st.EndsAt > 0 then
			local left = st.EndsAt - workspace:GetServerTimeNow()
			timer.Text = Format.Time(left)
			local s = math.ceil(left)
			if st.Phase == "Round" and s <= 10 and s > 0 and s ~= lastSecond then
				lastSecond = s
				timer.TextColor3 = C(255, 90, 90)
				UI.Pop(timer, 0.25)
				SoundFX.Play("Click", 0.4, 1.4)
			elseif s > 10 then
				timer.TextColor3 = T.Text
			end
		else
			timer.Text = ""
		end
	end)

	Hud.Gui = gui
end

return Hud
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "MapAnimator", "ModuleScript", [[
-- MapAnimator: hace girar en el cliente lo que el servidor marca con la etiqueta "IslasGira"
-- (norias, molinos, carruseles, monedas...). Coste cero para el servidor y movimiento suave.
-- Atributos: GiroRPM (vueltas por minuto) y GiroEje ("X", "Y" o "Z").
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local MapAnimator = {}

local spinning = {} -- [inst] = { pivot, rpm, axis }

local function add(inst)
	if spinning[inst] then
		return
	end
	local pivot = inst:GetPivot()
	spinning[inst] = { pivot = pivot, rpm = inst:GetAttribute("GiroRPM") or 10, axis = inst:GetAttribute("GiroEje") or "Y", angle = 0 }
end

local function remove(inst)
	spinning[inst] = nil
end

function MapAnimator.Init(modules)
	local Quality = modules.Quality
	for _, inst in ipairs(CollectionService:GetTagged("IslasGira")) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal("IslasGira"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("IslasGira"):Connect(remove)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		-- en calidad baja se actualiza a 20 fps para ahorrar
		acc = acc + dt
		if Quality.Level == 1 and acc < 0.05 then
			return
		end
		local step = acc
		acc = 0
		for inst, s in pairs(spinning) do
			if not inst.Parent then
				spinning[inst] = nil
			else
				s.angle = s.angle + step * s.rpm / 60 * math.pi * 2
				local rot
				if s.axis == "X" then
					rot = CFrame.Angles(s.angle, 0, 0)
				elseif s.axis == "Z" then
					rot = CFrame.Angles(0, 0, s.angle)
				else
					rot = CFrame.Angles(0, s.angle, 0)
				end
				inst:PivotTo(s.pivot * rot)
			end
		end
	end)
end

return MapAnimator
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "Music", "ModuleScript", [[
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
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "Popups", "ModuleScript", [[
-- Popups: numeros de monedas/XP que saltan, avisos (logros, subida de nivel) y lista de muertes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local Popups = {}
local UI, SoundFX
local gui, toastList, feed, bigText
local C = Color3.fromRGB

-- "+5" flotando en el mundo donde se recogio la moneda
local function worldPopup(amount, position)
	local att = Instance.new("Attachment")
	att.WorldPosition = position
	att.Parent = workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 120, 0, 40)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Adornee = att
	bb.Parent = att
	local label = UI.Label(bb, {
		Text = "+" .. amount,
		Font = UI.Theme.Black,
		TextSize = 30,
		TextColor3 = amount >= 25 and C(255, 120, 220) or UI.Theme.Accent,
		Size = UDim2.fromScale(1, 1),
	})
	UI.TextStroke(label, 2)
	UI.Tween(bb, 1, { StudsOffset = Vector3.new(0, 5, 0) })
	UI.Tween(label, 1, { TextTransparency = 1 })
	task.delay(1.1, function()
		att:Destroy()
	end)
end

-- Fundido a blanco (al teletransportar)
local fadeFrame
function Popups.Fade()
	if not fadeFrame then
		return
	end
	fadeFrame.BackgroundTransparency = 0
	UI.Tween(fadeFrame, 0.7, { BackgroundTransparency = 1 })
end

-- "+5 🪙" que sale cerca del contador de monedas y sube
function Popups.Coin(amount, xp, text, position)
	if typeof(position) == "Vector3" and amount > 0 then
		worldPopup(amount, position)
	end
	local T = UI.Theme
	local label = UI.Label(gui, {
		Text = (amount > 0 and ("+" .. amount .. " 🪙") or "") .. (xp and xp > 0 and ("  +" .. xp .. " XP") or ""),
		Font = T.Black,
		TextSize = amount >= 25 and 34 or 26,
		TextColor3 = amount >= 25 and C(255, 120, 220) or T.Accent,
		Size = UDim2.new(0, 320, 0, 40),
		Position = UDim2.new(0, 210 + math.random(-20, 20), 0, 70),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	UI.TextStroke(label, 2.5)
	if text then
		local sub = UI.Label(label, {
			Text = text,
			Font = T.Font,
			TextSize = 16,
			TextColor3 = T.Text,
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.new(0, 0, 1, -4),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		UI.TextStroke(sub, 1.5)
	end
	UI.Pop(label, 0.4)
	UI.Tween(label, 1.6, { Position = label.Position - UDim2.new(0, 0, 0, 50), TextTransparency = 1 })
	task.delay(1.7, function()
		label:Destroy()
	end)
end

-- Aviso en el lateral (logros, compras, informacion)
function Popups.Toast(text, color, title)
	local T = UI.Theme
	local frame = UI.Panel(toastList, {
		Size = UDim2.new(1, 0, 0, title and 64 or 44),
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.05,
	})
	UI.Stroke(frame, color or T.Accent, 2)
	if title then
		UI.Label(frame, { Text = title, Font = T.Black, TextSize = 18, TextColor3 = color or T.Accent, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0, 8, 0, 4), TextXAlignment = Enum.TextXAlignment.Left })
	end
	UI.Label(frame, {
		Text = text,
		Font = T.Body,
		TextSize = 15,
		TextWrapped = true,
		Size = UDim2.new(1, -16, 0, title and 30 or 40),
		Position = UDim2.new(0, 8, 0, title and 30 or 2),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	UI.Pop(frame, 0.1)
	task.delay(5, function()
		UI.Tween(frame, 0.4, { BackgroundTransparency = 1 })
		task.wait(0.4)
		frame:Destroy()
	end)
end

-- Texto enorme en el centro (subida de nivel, sobreviviste...)
function Popups.Big(text, color, seconds)
	bigText.Text = text
	bigText.TextColor3 = color or UI.Theme.Accent
	bigText.Visible = true
	bigText.TextTransparency = 0
	UI.Pop(bigText, 0.5)
	task.delay(seconds or 2, function()
		if bigText.Text == text then
			UI.Tween(bigText, 0.5, { TextTransparency = 1 })
		end
	end)
end

function Popups.Kill(name, cause)
	local T = UI.Theme
	local row = UI.Panel(feed, { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C(40, 10, 10), BackgroundTransparency = 0.3 })
	UI.Label(row, {
		Text = "💀 " .. name .. "  ·  " .. cause,
		Font = T.Font,
		TextSize = 15,
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	task.delay(7, function()
		row:Destroy()
	end)
end

function Popups.Init(modules)
	UI, SoundFX = modules.UI, modules.SoundFX
	gui = UI.Gui("AvisosGui", 8)
	toastList = UI.New("Frame", {
		Size = UDim2.new(0, 300, 0.6, 0),
		Position = UDim2.new(1, -310, 0.25, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.New("UIListLayout", { Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = toastList })
	feed = UI.New("Frame", {
		Size = UDim2.new(0, 280, 0, 200),
		Position = UDim2.new(1, -290, 0, 60),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.New("UIListLayout", { Padding = UDim.new(0, 4), Parent = feed })
	bigText = UI.Label(gui, {
		Font = UI.Theme.Black,
		TextSize = 64,
		Size = UDim2.new(1, 0, 0, 90),
		Position = UDim2.new(0, 0, 0.32, 0),
		Visible = false,
	})
	UI.TextStroke(bigText, 4)
	local fadeGui = UI.Gui("FundidoGui", 20, true)
	fadeFrame = UI.New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, Parent = fadeGui })

	Net.Event("Popup").OnClientEvent:Connect(function(p)
		if typeof(p) == "table" then
			Popups.Coin(p.Coins or 0, p.XP, p.Text, p.Position)
		end
	end)
	Net.Event("Toast").OnClientEvent:Connect(function(t)
		if typeof(t) ~= "table" then
			return
		end
		if t.Kind == "LevelUp" then
			Popups.Big(t.Title, C(120, 220, 255), 2.5)
			Popups.Toast(t.Text, C(120, 220, 255), t.Title)
		elseif t.Kind == "Achievement" then
			Popups.Toast(t.Text, C(255, 196, 50), t.Title)
		else
			Popups.Toast(t.Text or "", t.Color, t.Title)
		end
	end)
	Net.Event("KillFeed").OnClientEvent:Connect(function(k)
		if typeof(k) == "table" then
			Popups.Kill(k.Name or "?", k.Cause or "?")
			if k.UserId == Players.LocalPlayer.UserId then
				Popups.Big("HAS MUERTO", C(255, 80, 80), 2)
			end
		end
	end)
end

return Popups
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "Quality", "ModuleScript", [[
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
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "ResultsUI", "ModuleScript", [[
-- ResultsUI: pantalla de final de ronda (sobreviviste o no, monedas que cuentan hacia arriba, racha)
-- con confeti cuando sobrevives.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local ResultsUI = {}
local C = Color3.fromRGB

function ResultsUI.Init(modules)
	local UI, SoundFX, Quality = modules.UI, modules.SoundFX, modules.Quality
	local T = UI.Theme
	local gui = UI.Gui("ResultadosGui", 7, true)

	local panel = UI.Panel(gui, {
		Size = UDim2.new(0, 460, 0, 300),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.05,
		Visible = false,
	})
	local stroke = UI.Stroke(panel, T.Good, 4)
	local headline = UI.Label(panel, { Font = T.Black, TextSize = 40, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0, 10) })
	UI.TextStroke(headline, 3)
	local sub = UI.Label(panel, { Font = T.Body, TextSize = 16, TextColor3 = T.Muted, TextWrapped = true, Size = UDim2.new(1, -30, 0, 40), Position = UDim2.new(0, 15, 0, 68) })
	local coinsLabel = UI.Label(panel, { Font = T.Black, TextSize = 46, TextColor3 = T.Accent, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0, 112) })
	UI.TextStroke(coinsLabel, 3)
	local xpLabel = UI.Label(panel, { Font = T.Black, TextSize = 22, TextColor3 = T.Info, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 172) })
	local streakLabel = UI.Label(panel, { Font = T.Black, TextSize = 22, TextColor3 = C(255, 140, 60), Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 204) })
	local survivorsLabel = UI.Label(panel, { Font = T.Body, TextSize = 14, TextColor3 = T.Muted, TextWrapped = true, Size = UDim2.new(1, -30, 0, 50), Position = UDim2.new(0, 15, 0, 238) })

	local confettiLayer = UI.New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local confetti = {}
	local function burstConfetti()
		local n = ({ 30, 70, 120 })[Quality.Level]
		for _ = 1, n do
			local f = UI.New("Frame", {
				Size = UDim2.new(0, math.random(6, 12), 0, math.random(10, 18)),
				Position = UDim2.new(math.random(), 0, -0.05 - math.random() * 0.3, 0),
				BackgroundColor3 = Color3.fromHSV(math.random(), 0.8, 1),
				BorderSizePixel = 0,
				Rotation = math.random(0, 360),
				Parent = confettiLayer,
			})
			confetti[#confetti + 1] = { f = f, vy = 0.25 + math.random() * 0.35, vx = (math.random() - 0.5) * 0.1, spin = math.random(-300, 300), born = os.clock() }
		end
	end
	RunService.RenderStepped:Connect(function(dt)
		for i = #confetti, 1, -1 do
			local c = confetti[i]
			local p = c.f.Position
			c.f.Position = UDim2.new(p.X.Scale + c.vx * dt, 0, p.Y.Scale + c.vy * dt, 0)
			c.f.Rotation = c.f.Rotation + c.spin * dt
			if p.Y.Scale > 1.1 or os.clock() - c.born > 6 then
				c.f:Destroy()
				table.remove(confetti, i)
			end
		end
	end)

	Net.Event("RoundResults").OnClientEvent:Connect(function(r)
		if typeof(r) ~= "table" then
			return
		end
		if r.Survived then
			headline.Text = "¡SOBREVIVISTE!"
			headline.TextColor3 = T.Good
			stroke.Color = T.Good
			burstConfetti()
			SoundFX.Play("Win", 0.9)
		else
			headline.Text = "NO SOBREVIVISTE"
			headline.TextColor3 = T.Bad
			stroke.Color = T.Bad
		end
		sub.Text = (r.Map or "") .. "  ·  " .. table.concat(r.Disasters or {}, " + ") .. (r.Modifier and ("  ·  " .. r.Modifier) or "")
		xpLabel.Text = "+" .. (r.XP or 0) .. " XP"
		streakLabel.Text = (r.Streak and r.Streak > 1) and ("🔥 RACHA x" .. r.Streak) or ""
		local names = r.Survivors or {}
		survivorsLabel.Text = #names > 0 and ("Supervivientes: " .. table.concat(names, ", ")) or "Nadie sobrevivio"
		panel.Visible = true
		UI.Pop(panel, 0.15)
		-- las monedas cuentan hacia arriba
		local target = r.Coins or 0
		task.spawn(function()
			local steps = 20
			for i = 1, steps do
				coinsLabel.Text = "+" .. math.floor(target * i / steps) .. " 🪙"
				if i % 4 == 0 then
					SoundFX.Play("Coin", 0.25, 1 + i / steps)
				end
				task.wait(0.04)
			end
			UI.Pop(coinsLabel, 0.3)
		end)
		task.delay(6, function()
			panel.Visible = false
		end)
	end)
end

return ResultsUI
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "SettingsUI", "ModuleScript", [[
-- SettingsUI: calidad de efectos (auto/baja/media/alta), temblor de camara, musica y sonidos.
-- Se guarda en tus datos (SettingsChanged).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local SettingsUI = {}
local C = Color3.fromRGB

function SettingsUI.Init(modules)
	local UI, State, Quality, SoundFX, DisasterFX = modules.UI, modules.State, modules.Quality, modules.SoundFX, modules.DisasterFX
	local T = UI.Theme
	local gui = UI.Gui("AjustesGui", 10)
	local win = UI.Window(gui, "⚙️ AJUSTES", UDim2.new(0, 480, 0, 360), C(110, 120, 150))
	local layout = UI.New("UIListLayout", { Padding = UDim.new(0, 10), Parent = win.Content })

	local settings = { Quality = 0, Shake = 1, Music = true, Sounds = true }

	local function apply()
		if settings.Quality == 0 then
			Quality.Set(nil, true)
		else
			Quality.Set(settings.Quality, false)
		end
		if DisasterFX then
			DisasterFX.ShakeScale = settings.Shake
		end
		SoundFX.Muted = not settings.Sounds
		if modules.Music then
			modules.Music.SetEnabled(settings.Music)
		end
	end

	local function save()
		apply()
		Net.Event("SettingsChanged"):FireServer(settings)
	end

	local function row(title)
		local r = UI.New("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, Parent = win.Content })
		UI.Label(r, { Text = title, Font = T.Black, TextSize = 17, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left })
		local buttons = UI.New("Frame", { Size = UDim2.new(1, 0, 0, 32), Position = UDim2.new(0, 0, 0, 24), BackgroundTransparency = 1, Parent = r })
		UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = buttons })
		return buttons
	end

	local groups = {}
	local function choice(title, key, options)
		local holder = row(title)
		local btns = {}
		for _, opt in ipairs(options) do
			btns[#btns + 1] = { value = opt[2], button = UI.Button(holder, opt[1], { Size = UDim2.new(0, 100, 1, 0), TextSize = 14 }, function()
				settings[key] = opt[2]
				save()
				for _, g in ipairs(groups) do
					g()
				end
			end) }
		end
		groups[#groups + 1] = function()
			for _, b in ipairs(btns) do
				local on = settings[key] == b.value
				b.button.BackgroundColor3 = on and T.Accent or T.Panel2
				b.button.TextColor3 = on and C(30, 25, 10) or T.Text
			end
		end
	end

	choice("Calidad de efectos", "Quality", { { "AUTO", 0 }, { "BAJA", 1 }, { "MEDIA", 2 }, { "ALTA", 3 } })
	choice("Temblor de camara", "Shake", { { "NO", 0 }, { "SUAVE", 0.5 }, { "NORMAL", 1 } })
	choice("Musica", "Music", { { "SI", true }, { "NO", false } })
	choice("Sonidos", "Sounds", { { "SI", true }, { "NO", false } })
	local fps = UI.Label(win.Content, { Font = T.Body, TextSize = 13, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left })

	win.OnOpen = function()
		for _, g in ipairs(groups) do
			g()
		end
		fps.Text = string.format("FPS: %d  ·  calidad actual: %d", math.floor(Quality.FPS), Quality.Level)
	end

	local loaded = false
	State.OnData(function(data)
		if loaded or not data.Settings then
			return
		end
		loaded = true
		for k, v in pairs(data.Settings) do
			settings[k] = v
		end
		apply()
	end)
	SettingsUI.Toggle = win.Toggle
	local _ = layout
end

return SettingsUI
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "ShopUI", "ModuleScript", [[
-- ShopUI: tienda con pestanas (Gears, Estelas, Mejoras). Comprar y equipar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("IslasShared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))

local ShopUI = {}
local C = Color3.fromRGB

local TABS = {
	{ Kind = "Gear", Title = "GEARS" },
	{ Kind = "Trail", Title = "ESTELAS" },
	{ Kind = "Upgrade", Title = "MEJORAS" },
}

function ShopUI.Init(modules)
	local UI, State, Popups, SoundFX = modules.UI, modules.State, modules.Popups, modules.SoundFX
	local T = UI.Theme
	local gui = UI.Gui("TiendaGui", 10)
	local win = UI.Window(gui, "🛒 TIENDA", UDim2.new(0.7, 0, 0.75, 0), C(255, 160, 40))
	local content = win.Content

	local header = UI.New("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = content })
	UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = header })
	local coinsLabel = UI.Label(content, { Text = "", Font = T.Black, TextSize = 22, TextColor3 = T.Accent, Size = UDim2.new(0, 200, 0, 40), Position = UDim2.new(1, -200, 0, 0), TextXAlignment = Enum.TextXAlignment.Right })
	local slotsLabel = UI.Label(content, { Text = "", Font = T.Body, TextSize = 14, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 42), TextXAlignment = Enum.TextXAlignment.Left })

	local list = UI.New("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -70),
		Position = UDim2.new(0, 0, 0, 66),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = content,
	})
	UI.New("UIGridLayout", { CellSize = UDim2.new(0, 190, 0, 210), CellPadding = UDim2.new(0, 10, 0, 10), Parent = list })

	local currentKind = "Gear"
	local tabButtons = {}

	local function request(action, id)
		local ok, a, b = pcall(function()
			return Net.Function("ShopRequest"):InvokeServer(action, id)
		end)
		local success, msg = ok and a, ok and b or "Error de conexion"
		Popups.Toast(msg or "", success and T.Good or T.Bad)
		if not success then
			SoundFX.Play("Hit", 0.5)
		end
	end

	local function render()
		local data = State.Data
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if not data then
			return
		end
		coinsLabel.Text = "🪙 " .. Format.Number(data.Coins)
		slotsLabel.Text = currentKind == "Gear" and ("Puedes llevar " .. (data.GearSlots or 1) .. " gear(s) a la vez en las rondas. Pulsa EQUIPAR para elegir.") or ""
		for k, b in pairs(tabButtons) do
			b.BackgroundColor3 = k == currentKind and T.Accent or T.Panel2
			b.TextColor3 = k == currentKind and C(30, 25, 10) or T.Text
		end
		for _, item in ipairs(Catalog.Items) do
			if item.Kind == currentKind then
				local owned = data.Owned and data.Owned[item.Id]
				local equipped = false
				if item.Kind == "Gear" then
					equipped = table.find(data.Equipped.Gears or {}, item.Id) ~= nil
				elseif item.Kind == "Trail" then
					equipped = data.Equipped.Trail == item.Id
				end
				local card = UI.Panel(list, { BackgroundColor3 = equipped and C(40, 80, 55) or T.Panel })
				UI.Stroke(card, equipped and T.Good or (owned and T.Info or T.Panel3), 2)
				UI.Label(card, { Text = item.Icon or "?", TextSize = 46, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0, 6) })
				UI.Label(card, { Text = item.Name, Font = T.Black, TextSize = 17, TextWrapped = true, Size = UDim2.new(1, -10, 0, 22), Position = UDim2.new(0, 5, 0, 66) })
				UI.Label(card, { Text = item.Desc or "Estela cosmetica que te sigue al correr.", Font = T.Body, TextSize = 12, TextWrapped = true, TextColor3 = T.Muted, Size = UDim2.new(1, -14, 0, 64), Position = UDim2.new(0, 7, 0, 90), TextYAlignment = Enum.TextYAlignment.Top })
				local text, color, action
				if not owned then
					local affordable = data.Coins >= item.Price
					text = "🪙 " .. Format.Number(item.Price)
					color = affordable and T.Accent or C(90, 90, 100)
					action = "buy"
				elseif item.Kind == "Upgrade" then
					text, color = "✔ COMPRADO", T.Good
				else
					text = equipped and "QUITAR" or "EQUIPAR"
					color = equipped and T.Bad or T.Info
					action = "equip"
				end
				local btn = UI.Button(card, text, { Size = UDim2.new(1, -20, 0, 36), Position = UDim2.new(0, 10, 1, -44), BackgroundColor3 = color, TextSize = 16 }, function()
					if action then
						request(action, item.Id)
					end
				end)
				if not action then
					btn.Active = false
				end
			end
		end
	end

	for _, tab in ipairs(TABS) do
		tabButtons[tab.Kind] = UI.Button(header, tab.Title, { Size = UDim2.new(0, 120, 1, 0), BackgroundColor3 = T.Panel2, TextColor3 = T.Text, TextSize = 16 }, function()
			currentKind = tab.Kind
			render()
		end)
	end

	State.OnData(function()
		if win.IsOpen() then
			render()
		end
	end)
	win.OnOpen = render

	Net.Event("OpenUI").OnClientEvent:Connect(function(what)
		if what == "Shop" then
			win.Open()
		end
	end)

	ShopUI.Toggle = win.Toggle
	ShopUI.Open = win.Open
end

return ShopUI
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "SoundFX", "ModuleScript", [[
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
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "SpectateUI", "ModuleScript", [[
-- SpectateUI: mirar a los supervivientes cuando estas muerto o esperando en el lobby durante una ronda.
local Players = game:GetService("Players")

local SpectateUI = {}
local C = Color3.fromRGB

function SpectateUI.Init(modules)
	local UI, State = modules.UI, modules.State
	local T = UI.Theme
	local player = Players.LocalPlayer
	local gui = UI.Gui("EspectarGui", 3)

	local openBtn = UI.Button(gui, "👁 ESPECTAR", { Size = UDim2.new(0, 150, 0, 40), Position = UDim2.new(0.5, -75, 1, -110), BackgroundColor3 = C(90, 110, 200), TextColor3 = C(255, 255, 255), Visible = false })
	local bar = UI.Panel(gui, { Size = UDim2.new(0, 420, 0, 54), Position = UDim2.new(0.5, -210, 1, -120), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.1, Visible = false })
	UI.Stroke(bar, C(90, 110, 200), 2)
	local name = UI.Label(bar, { Font = T.Black, TextSize = 18, Size = UDim2.new(1, -200, 1, 0), Position = UDim2.new(0, 100, 0, 0) })

	local targets, index, spectating = {}, 1, false

	local function camera()
		return workspace.CurrentCamera
	end

	local function stop()
		spectating = false
		bar.Visible = false
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and camera() then
			camera().CameraSubject = hum
		end
	end

	local function refreshTargets()
		targets = {}
		for _, id in ipairs(State.Round.AliveIds or {}) do
			local p = Players:GetPlayerByUserId(id)
			if p and p ~= player and p.Character then
				targets[#targets + 1] = p
			end
		end
	end

	local function show()
		refreshTargets()
		if #targets == 0 then
			stop()
			return
		end
		index = ((index - 1) % #targets) + 1
		local target = targets[index]
		local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if hum and camera() then
			camera().CameraSubject = hum
			name.Text = target.DisplayName .. "  (" .. index .. "/" .. #targets .. ")"
		end
	end

	UI.Button(bar, "◀", { Size = UDim2.new(0, 44, 0, 40), Position = UDim2.new(0, 8, 0, 7), BackgroundColor3 = T.Panel2, TextColor3 = T.Text }, function()
		index = index - 1
		show()
	end)
	UI.Button(bar, "▶", { Size = UDim2.new(0, 44, 0, 40), Position = UDim2.new(0, 54, 0, 7), BackgroundColor3 = T.Panel2, TextColor3 = T.Text }, function()
		index = index + 1
		show()
	end)
	UI.Button(bar, "SALIR", { Size = UDim2.new(0, 90, 0, 40), Position = UDim2.new(1, -98, 0, 7), BackgroundColor3 = T.Bad, TextColor3 = T.Text }, stop)

	openBtn.Activated:Connect(function()
		spectating = true
		bar.Visible = true
		openBtn.Visible = false
		show()
	end)

	State.OnRound(function(st)
		local inRound = st.Phase == "Round"
		local alive = table.find(st.AliveIds or {}, player.UserId) ~= nil
		openBtn.Visible = inRound and not alive and not spectating and #(st.AliveIds or {}) > 0
		if spectating then
			if not inRound then
				stop()
			else
				show()
			end
		end
	end)
end

return SpectateUI
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "State", "ModuleScript", [[
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
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "UI", "ModuleScript", [[
-- UI: utilidades para construir la interfaz por codigo con un estilo comun.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local C = Color3.fromRGB

local UI = {}

UI.Theme = {
	Bg = C(14, 16, 26),
	Panel = C(26, 29, 44),
	Panel2 = C(38, 42, 62),
	Panel3 = C(52, 57, 82),
	Accent = C(255, 196, 50),
	Accent2 = C(255, 120, 40),
	Good = C(80, 220, 120),
	Bad = C(255, 80, 80),
	Info = C(80, 170, 255),
	Text = C(255, 255, 255),
	Muted = C(170, 178, 200),
	Font = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
	Black = Enum.Font.GothamBlack,
}
local T = UI.Theme

local clickSound

function UI.New(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.Corner(inst, radius)
	return UI.New("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = inst })
end

function UI.Stroke(inst, color, thickness, transparency)
	return UI.New("UIStroke", {
		Color = color or C(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

function UI.TextStroke(inst, thickness)
	return UI.New("UIStroke", { Color = C(0, 0, 0), Thickness = thickness or 2, Transparency = 0.3, Parent = inst })
end

function UI.Padding(inst, px)
	return UI.New("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = inst,
	})
end

function UI.Gradient(inst, c1, c2, rotation)
	return UI.New("UIGradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(1, c2) }),
		Rotation = rotation or 90,
		Parent = inst,
	})
end

function UI.Tween(inst, seconds, goal, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

-- ScreenGui en PlayerGui
function UI.Gui(name, order, ignoreInset)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = order or 1
	gui.IgnoreGuiInset = ignoreInset == true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function UI.Label(parent, props)
	local p = {
		BackgroundTransparency = 1,
		Font = T.Font,
		TextColor3 = T.Text,
		TextSize = 18,
		Text = "",
		Size = UDim2.new(1, 0, 0, 24),
		Parent = parent,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return UI.New("TextLabel", p)
end

function UI.Panel(parent, props)
	local p = { BackgroundColor3 = T.Panel, BorderSizePixel = 0, Parent = parent }
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	local f = UI.New("Frame", p)
	UI.Corner(f, 12)
	return f
end

-- Rebote rapido (se usa al ganar monedas, abrir ventanas...)
function UI.Pop(inst, amount)
	local scale = inst:FindFirstChildOfClass("UIScale") or UI.New("UIScale", { Parent = inst })
	scale.Scale = 1 + (amount or 0.15)
	UI.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

function UI.PlayClick()
	if not clickSound then
		local ok, Sounds = pcall(function()
			return require(game:GetService("ReplicatedStorage"):WaitForChild("IslasShared"):WaitForChild("Sounds"))
		end)
		clickSound = Instance.new("Sound")
		clickSound.Volume = 0.35
		clickSound.SoundId = ok and Sounds.Click or ""
		clickSound.Parent = game:GetService("SoundService")
	end
	clickSound:Play()
end

-- Boton con animacion al pasar el raton y al pulsar
function UI.Button(parent, text, props, onClick)
	local p = {
		BackgroundColor3 = T.Accent,
		AutoButtonColor = false,
		Font = T.Black,
		TextColor3 = C(30, 25, 10),
		TextSize = 18,
		Text = text,
		Size = UDim2.new(0, 140, 0, 40),
		Parent = parent,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	local b = UI.New("TextButton", p)
	UI.Corner(b, 10)
	local scale = UI.New("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		UI.Tween(scale, 0.12, { Scale = 1.05 })
	end)
	b.MouseLeave:Connect(function()
		UI.Tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		UI.Tween(scale, 0.08, { Scale = 0.95 })
	end)
	b.Activated:Connect(function()
		UI.Tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
		UI.PlayClick()
		if onClick then
			onClick()
		end
	end)
	return b
end

-- Ventana modal con titulo y boton de cerrar. Devuelve window, content
local openWindows = {}
function UI.Window(gui, title, size, accent)
	local win = UI.Panel(gui, {
		Name = "Ventana_" .. title,
		Size = size or UDim2.new(0, 560, 0, 420),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.05,
		Visible = false,
	})
	UI.Stroke(win, accent or T.Accent, 3)
	UI.New("UISizeConstraint", { MaxSize = Vector2.new(900, 700), Parent = win })
	local bar = UI.New("Frame", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = accent or T.Accent,
		BorderSizePixel = 0,
		Parent = win,
	})
	UI.Corner(bar, 12)
	local titleLabel = UI.Label(bar, {
		Text = title,
		Font = T.Black,
		TextSize = 24,
		TextColor3 = C(30, 25, 10),
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = UI.Button(bar, "X", {
		Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(1, -42, 0, 6),
		BackgroundColor3 = T.Bad,
		TextColor3 = T.Text,
	})
	local content = UI.New("Frame", {
		Name = "Contenido",
		Size = UDim2.new(1, -24, 1, -64),
		Position = UDim2.new(0, 12, 0, 56),
		BackgroundTransparency = 1,
		Parent = win,
	})
	local api = {}
	function api.Open()
		for _, w in ipairs(openWindows) do
			if w ~= api then
				w.Close()
			end
		end
		win.Visible = true
		UI.Pop(win, 0.08)
		if api.OnOpen then
			api.OnOpen()
		end
	end
	function api.Close()
		win.Visible = false
	end
	function api.Toggle()
		if win.Visible then
			api.Close()
		else
			api.Open()
		end
	end
	function api.IsOpen()
		return win.Visible
	end
	close.Activated:Connect(api.Close)
	api.Frame, api.Content, api.Title = win, content, titleLabel
	openWindows[#openWindows + 1] = api
	return api
end

function UI.IsMobile()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

return UI
]])

	add("StarterPlayerScripts", { "IslasClient", "Modulos" }, "VoteUI", "ModuleScript", [[
-- VoteUI: tarjetas de votacion de mapa con votos en directo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage:WaitForChild("IslasShared"):WaitForChild("Net"))

local VoteUI = {}
local C = Color3.fromRGB

function VoteUI.Init(modules)
	local UI, SoundFX = modules.UI, modules.SoundFX
	local T = UI.Theme
	local gui = UI.Gui("VotacionGui", 6)
	local panel = UI.Panel(gui, {
		Size = UDim2.new(0, 720, 0, 330),
		Position = UDim2.new(0.5, 0, 0.55, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.08,
		Visible = false,
	})
	UI.Stroke(panel, T.Accent, 3)
	UI.New("UISizeConstraint", { MaxSize = Vector2.new(720, 330), Parent = panel })
	local title = UI.Label(panel, { Text = "VOTA EL SIGUIENTE MAPA", Font = T.Black, TextSize = 26, Size = UDim2.new(1, 0, 0, 44), TextColor3 = T.Accent })
	local cards = UI.New("Frame", { Size = UDim2.new(1, -24, 1, -60), Position = UDim2.new(0, 12, 0, 50), BackgroundTransparency = 1, Parent = panel })
	UI.New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), Parent = cards })

	local voteEnd = nil
	local buttons, counts, titles = {}, {}, {}
	local myVote = nil

	local function highlight()
		for name, b in pairs(buttons) do
			local mine = name == myVote
			b.BackgroundColor3 = mine and C(50, 120, 70) or T.Panel2
			local stroke = b:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = mine and T.Good or T.Panel3
			end
		end
	end

	Net.Event("VoteOptions").OnClientEvent:Connect(function(infos, endTime)
		for _, c in ipairs(cards:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		buttons, counts, titles, myVote = {}, {}, {}, nil
		voteEnd = endTime
		local width = math.floor((696 - 10 * (#infos - 1)) / math.max(1, #infos))
		for _, info in ipairs(infos) do
			local b = UI.Button(cards, "", { Size = UDim2.new(0, width, 1, 0), BackgroundColor3 = T.Panel2, TextColor3 = T.Text }, function()
				myVote = info.Name
				highlight()
				Net.Event("CastVote"):FireServer(info.Name)
			end)
			UI.Stroke(b, T.Panel3, 2)
			UI.Label(b, { Text = info.Title, Font = T.Black, TextSize = 22, TextWrapped = true, Size = UDim2.new(1, -12, 0, 50), Position = UDim2.new(0, 6, 0, 8) })
			UI.Label(b, { Text = info.Description, Font = T.Body, TextSize = 13, TextWrapped = true, TextColor3 = T.Muted, Size = UDim2.new(1, -16, 0, 70), Position = UDim2.new(0, 8, 0, 58), TextYAlignment = Enum.TextYAlignment.Top })
			local icons = table.concat(info.DisasterIcons or {}, " ")
			UI.Label(b, { Text = icons, TextSize = 20, TextWrapped = true, Size = UDim2.new(1, -16, 0, 56), Position = UDim2.new(0, 8, 0, 132), TextYAlignment = Enum.TextYAlignment.Top })
			local count = UI.Label(b, { Text = "0 votos", Font = T.Black, TextSize = 20, TextColor3 = T.Accent, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -36) })
			buttons[info.Name], counts[info.Name], titles[info.Name] = b, count, info.Title
		end
		highlight()
		panel.Visible = true
		UI.Pop(panel, 0.08)
		SoundFX.Play("Whoosh", 0.5)
	end)

	Net.Event("VoteUpdate").OnClientEvent:Connect(function(c)
		for name, label in pairs(counts) do
			local n = c[name] or 0
			local before = label.Text
			label.Text = n .. (n == 1 and " voto" or " votos")
			if before ~= label.Text then
				UI.Pop(label, 0.3)
			end
		end
	end)

	Net.Event("VoteEnd").OnClientEvent:Connect(function(winner, winnerTitle)
		voteEnd = nil
		title.Text = "GANADOR: " .. string.upper(winnerTitle or titles[winner] or tostring(winner))
		local b = buttons[winner]
		if b then
			UI.Pop(b, 0.15)
			b.BackgroundColor3 = C(200, 150, 40)
		end
		SoundFX.Play("Win", 0.6)
		task.delay(2.5, function()
			panel.Visible = false
			title.Text = "VOTA EL SIGUIENTE MAPA"
		end)
	end)

	RunService.Heartbeat:Connect(function()
		if voteEnd and panel.Visible then
			title.Text = "VOTA EL SIGUIENTE MAPA  (" .. math.max(0, math.ceil(voteEnd - workspace:GetServerTimeNow())) .. ")"
		end
	end)
end

return VoteUI
]])

	print("Islas de Desastres instalado: 77 scripts. Dale a Play para probar.")
end

local toolbar = plugin:CreateToolbar("Islas de Desastres")
local button = toolbar:CreateButton("Instalar Islas", "Instala o actualiza los scripts de Islas de Desastres", "rbxassetid://0")
button.Click:Connect(function()
	local ok, err = pcall(install)
	if not ok then
		warn("Error instalando: " .. tostring(err))
	end
	game:GetService("ChangeHistoryService"):SetWaypoint("Instalar Islas de Desastres")
end)
