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
