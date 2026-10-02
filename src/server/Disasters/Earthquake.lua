local Debris = game:GetService("Debris")

return {
	Title = "Terremoto",
	Description = "El suelo tiembla: se rompen paredes y objetos. Aleja de lo que pueda caerte encima.",
	Run = function(ctx)
		ctx.fx("shake", 1.4, ctx.duration)
		local parts = table.clone(ctx.fragileParts())
		local limit = math.floor(#parts * (ctx.config.maxBroken or 0.5))
		local broken = 0
		while ctx.active() do
			if broken < limit then
				local n = math.min(limit - broken, math.max(6, math.floor(#parts * 0.03)))
				for _ = 1, n do
					if #parts == 0 then
						break
					end
					local p = table.remove(parts, math.random(#parts))
					if p.Parent then
						p.Anchored = false
						p.AssemblyLinearVelocity = Vector3.new(math.random(-8, 8), math.random(0, 6), math.random(-8, 8))
						Debris:AddItem(p, 30)
						broken = broken + 1
					end
				end
			end
			-- el temblor tira al suelo a algunos jugadores
			for _, entry in ipairs(ctx.players()) do
				if math.random() < 0.15 then
					entry.humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
				end
			end
			task.wait(3)
		end
	end,
}
