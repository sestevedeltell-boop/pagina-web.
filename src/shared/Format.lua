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
