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
