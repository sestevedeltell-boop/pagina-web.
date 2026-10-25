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
