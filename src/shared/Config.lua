-- Config: ajustes del sistema de islas. Cambia lo que quieras aqui.
return {
	-- Donde se construye el mapa elegido: lejos del lobby, y alto para no acercarse a FallenPartsDestroyHeight
	MapOrigin = Vector3.new(8000, 1000, 0),

	-- Tiempos (segundos)
	IntermissionTime = 15,
	VoteTime = 15,
	RoundTime = 180,

	-- Cuantos mapas salen en la votacion
	OptionsPerVote = 3,

	-- Minimo de jugadores para empezar una ronda
	MinPlayers = 1,

	-- true = el script RoundLoop de este proyecto lleva las rondas.
	-- Pon false si ya tienes tu propio bucle de rondas y quieres llamar tu a MapService / VoteService.
	RunDefaultLoop = true,
}
