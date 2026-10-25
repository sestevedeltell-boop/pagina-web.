-- INSTALADOR de Islas de Desastres.
-- Crea (o reemplaza) estas carpetas: ReplicatedStorage.IslasShared, ServerStorage.IslasMapas,
-- ServerScriptService.IslasServer y StarterPlayer.StarterPlayerScripts.IslasClient.
-- No toca nada mas de tu juego.
-- PARTE 1 DE 5. Pega las partes en la Barra de comandos EN ORDEN (1, 2, 3...).

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

print("Islas de Desastres: parte 1 de 5 instalada")
