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
