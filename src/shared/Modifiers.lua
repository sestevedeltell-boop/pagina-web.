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
