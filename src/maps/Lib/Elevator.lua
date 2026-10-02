-- Elevator: ascensor funcional por codigo.
--
-- Mira hacia +Z (la puerta esta en la cara +Z del hueco). Se llama desde un mapa asi:
--   Elevator.build(b, { name = "AscensorA", x = 0, z = -40, floors = { 0, 20, 40 } })
-- floors = alturas (Y) del suelo de cada planta, de menor a mayor.
--
-- Hueco interior: 12 (X) x 11 (Z). Los agujeros de los forjados de cada planta deben coincidir
-- con Elevator.hole(cfg), que devuelve {x1, x2, z1, z2}.

local TweenService = game:GetService("TweenService")

local Util = require(script.Parent.Util)
local V, C, M = Util.V, Util.C, Util.M

local Elevator = {}

local SHAFT_W, SHAFT_D = 12, 11 -- hueco interior
local CAB = 9 -- lado de la cabina
local DOOR_W, DOOR_H = 6, 8 -- hueco de la puerta
local WALL = 0.6
local SPEED = 14 -- studs por segundo

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
	local labels = cfg.labels or {}

	local function label(i)
		return labels[i] or tostring(i)
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
	-- panel sobre la puerta de cada planta (hasta la planta siguiente o el techo)
	for i = 1, count do
		local from = floors[i] + DOOR_H
		local to = floors[i + 1] or sTop
		if to > from then
			shaft:Box("PanelPuerta", V(DOOR_W, to - from, WALL), V(cx, (from + to) / 2, frontZ), wallColor, wallMat)
		end
		-- indicador de planta sobre la puerta
		if floors[i + 1] == nil or floors[i + 1] - from > 1.4 then
			shaft:Board("Indicador", label(i), V(2.2, 0.9, 0.2), V(cx, from + 0.7, frontZ + WALL / 2 + 0.1), Util.Colors.DarkMetal, C(120, 255, 140))
		end
	end

	-- ===== Cabina (se mueve como modelo) =====
	local cabin = b:Group(cfg.name .. "_Cabina", "Model")
	local cabZ = cz + 0.9 -- centro de la cabina: su frente queda casi a ras del borde del hueco
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
	-- frente de la cabina: pilares + dintel
	local cabPillar = (CAB + 0.8 - DOOR_W) / 2
	for _, side in ipairs({ -1, 1 }) do
		cabin:Box("PilarCabina", V(cabPillar, DOOR_H, 0.4), V(cx + side * (DOOR_W / 2 + cabPillar / 2), y0 + DOOR_H / 2, cabFront - 0.2), metal, M.Metal)
	end
	cabin:Box("DintelCabina", V(CAB + 0.8, CAB - DOOR_H, 0.4), V(cx, y0 + DOOR_H + (CAB - DOOR_H) / 2, cabFront - 0.2), metal, M.Metal)

	-- puertas de la cabina
	local doorW = DOOR_W / 2
	local cabDoors = {}
	for k, side in ipairs({ -1, 1 }) do
		cabDoors[k] = cabin:Box("PuertaCabina", V(doorW, DOOR_H, 0.3), V(cx + side * doorW / 2, y0 + DOOR_H / 2, cabFront + 0.15), C(200, 205, 210), M.Metal)
	end

	-- botonera interior (clic en cada numero). Dos o tres columnas si hay muchas plantas.
	cabin:Box("Botonera", V(0.2, 6.2, 2.9), V(cx - CAB / 2 + 0.05, y0 + 4.2, cabZ + 1.4), Util.Colors.DarkMetal, M.Metal)
	local rowsPerCol = 6
	local buttons = {}
	for i = 1, count do
		local col = math.floor((i - 1) / rowsPerCol)
		local row = (i - 1) % rowsPerCol
		local btn = cabin:Box("Boton" .. i, V(0.2, 0.8, 0.8), V(cx - CAB / 2 + 0.2, y0 + 1.6 + row * 0.95, cabZ + 2.3 - col * 0.95), C(40, 40, 45), M.SmoothPlastic)
		cabin:Sign(btn, label(i), Enum.NormalId.Right, C(255, 255, 255))
		local cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 14
		cd.Parent = btn
		buttons[i] = { part = btn, click = cd }
	end
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
		local pivot = cabin.parent:GetPivot()
		local cfv = Instance.new("CFrameValue")
		cfv.Value = pivot
		local conn = cfv.Changed:Connect(function(v)
			if st.alive then
				cabin.parent:PivotTo(v)
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
			task.wait(5)
		end
		if st.alive then
			setDoors(false)
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
		if idx == st.floor and st.busy then
			return
		end
		st.queue[#st.queue + 1] = idx
		if not st.busy then
			st.busy = true
			task.spawn(process)
		end
	end

	-- botones de llamada en cada planta (ProximityPrompt) y de cabina (ClickDetector)
	for i = 1, count do
		local call = shaft:Box("BotonLlamada", V(0.7, 1, 0.3), V(cx + DOOR_W / 2 + 1, floors[i] + 3.5, frontZ + WALL / 2 + 0.15), C(255, 190, 60), M.Neon)
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = "Llamar ascensor"
		pp.ObjectText = "Planta " .. label(i)
		pp.HoldDuration = 0
		pp.MaxActivationDistance = 8
		pp.RequiresLineOfSight = false
		pp.Parent = call
		pp.Triggered:Connect(function()
			request(i)
		end)
		buttons[i].click.MouseClick:Connect(function()
			request(i)
		end)
	end

	cabin.parent.Destroying:Connect(function()
		st.alive = false
	end)

	-- la planta inferior arranca con las puertas abiertas
	task.defer(function()
		request(1)
	end)

	return { Cabin = cabin.parent, Request = request }
end

return Elevator
