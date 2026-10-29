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
		Desc = "Te protege de la lluvia acida, el granizo, la ventisca y la tormenta de arena." },
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
