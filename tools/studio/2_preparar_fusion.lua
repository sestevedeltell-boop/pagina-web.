-- 2) PREPARAR LA FUSION (con Islas de Desastres ya instalado en tu juego)
-- Pega esto en la Barra de comandos de Studio con tu juego abierto y pulsa Enter.
--
-- Que hace:
--   * Lleva TUS mapas a ServerStorage.IslasMapasPropios. Asi cada mapa es individual, sale en la votacion y
--     solo se construye en el mundo cuando gana (y se borra al acabar la ronda). Los mapas que tengas puestos
--     directamente en el Workspace dejan de estar cargados todo el rato.
--   * Busca los scripts de tu juego viejo que hacen lo mismo que Islas de Desastres (bucle de rondas,
--     desastres, votacion, guardado de datos...) y te los lista. Si APLICAR = true, los desactiva (no los borra).
--
-- PRIMERO dejalo con APLICAR = false para ver que haria. Guarda una copia del juego antes de aplicar
-- (Archivo > Guardar como...). Tambien puedes deshacer con Ctrl+Z.

local APLICAR = false

-- Donde estan tus mapas. Se busca una carpeta con estos nombres en ServerStorage, ReplicatedStorage,
-- Lighting y Workspace. Cada Model o Folder que haya dentro se convierte en un mapa.
local CARPETAS_DE_MAPAS = { "Maps", "Mapas", "MapStorage", "Islands", "Islas" }

-- Mapas sueltos (ruta completa) que quieras anadir aunque no esten en esas carpetas, por ejemplo:
-- "Workspace.Ciudad", "ServerStorage.Aeropuerto"
local MAPAS_SUELTOS = {}

-- Scripts a desactivar a mano (ruta completa), ademas de los que se detecten:
local DESACTIVAR = {}

-- Desactivar tambien los scripts detectados automaticamente (mira la lista primero con APLICAR = false)
local DESACTIVAR_DETECTADOS = true

-- =====================================================================
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local OURS = { IslasShared = true, IslasMapas = true, IslasServer = true, IslasClient = true, IslasExportacion = true, IslasMapasPropios = true }

local function ours(inst)
	local p = inst
	while p and p ~= game do
		if OURS[p.Name] then
			return true
		end
		p = p.Parent
	end
	return false
end

local function byPath(path)
	local inst = game
	for name in path:gmatch("[^%.]+") do
		if inst == game then
			local ok, svc = pcall(game.GetService, game, name)
			inst = ok and svc or game:FindFirstChild(name)
		else
			inst = inst and inst:FindFirstChild(name)
		end
		if not inst then
			return nil
		end
	end
	return inst
end

local log = {}
local function say(s)
	log[#log + 1] = s
	print(s)
end

say(APLICAR and "=== PREPARAR FUSION: APLICANDO CAMBIOS ===" or "=== PREPARAR FUSION: SOLO MIRANDO (APLICAR = false) ===")
local target = ServerStorage:FindFirstChild("IslasMapasPropios")
if not target and APLICAR then
	target = Instance.new("Folder")
	target.Name = "IslasMapasPropios"
	target.Parent = ServerStorage
end

-- ----- mapas -----
local maps = {}
for _, sname in ipairs({ "ServerStorage", "ReplicatedStorage", "Lighting", "Workspace" }) do
	local svc = game:GetService(sname)
	for _, fname in ipairs(CARPETAS_DE_MAPAS) do
		local f = svc:FindFirstChild(fname)
		if f and not ours(f) then
			for _, m in ipairs(f:GetChildren()) do
				if m:IsA("Model") or m:IsA("Folder") then
					maps[#maps + 1] = m
				end
			end
		end
	end
end
for _, path in ipairs(MAPAS_SUELTOS) do
	local m = byPath(path)
	if m then
		maps[#maps + 1] = m
	else
		say("No encuentro el mapa " .. path)
	end
end

local existing = {}
for _, b in ipairs(ServerStorage:FindFirstChild("IslasMapas") and ServerStorage.IslasMapas.Builders:GetChildren() or {}) do
	existing[b.Name:lower()] = true
end

say("")
say("MAPAS (" .. #maps .. "):")
for _, m in ipairs(maps) do
	local n = 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			n = n + 1
		end
	end
	local note = existing[m.Name:lower()] and "  (OJO: hay un mapa generado con el mismo nombre; el tuyo se llamara " .. m.Name .. "_Propio)" or ""
	say("  " .. m:GetFullName() .. "  [" .. n .. " piezas]" .. note)
	if APLICAR then
		if existing[m.Name:lower()] or (target:FindFirstChild(m.Name) and target:FindFirstChild(m.Name) ~= m) then
			m.Name = m.Name .. "_Propio"
		end
		if m:GetAttribute("Title") == nil then
			m:SetAttribute("Title", m.Name:gsub("_Propio$", ""))
		end
		m.Parent = target
	end
end

-- ----- scripts que chocan -----
local PATTERNS = {
	{ "bucle de rondas", { "intermission", "intermedio", "roundtime", "round_time", "startround", "endround", "while true do.-round" } },
	{ "desastres", { "disaster", "desastre", "meteor", "tornado", "tsunami", "earthquake" } },
	{ "votacion de mapas", { "vote", "votacion", "votar" } },
	{ "carga de mapas", { ":clone%(%).-map", "mapas?%.", "maps:getchildren", "currentmap" } },
	{ "datos/monedas", { "datastore", "leaderstats", "coins", "monedas" } },
	{ "tienda", { "shop", "tienda", "purchase" } },
}

say("")
say("SCRIPTS DE TU JUEGO QUE HACEN LO MISMO QUE ISLAS DE DESASTRES:")
local manual = {}
for _, p in ipairs(DESACTIVAR) do
	local s = byPath(p)
	if s then
		manual[s] = true
	else
		say("  No encuentro el script " .. p)
	end
end
local found = 0
for _, sname in ipairs({ "ServerScriptService", "Workspace", "ServerStorage", "ReplicatedStorage", "StarterPlayer", "StarterGui", "StarterPack" }) do
	for _, d in ipairs(game:GetService(sname):GetDescendants()) do
		if d:IsA("BaseScript") and not ours(d) and not d.Disabled then
			local src = d.Source:lower()
			local reasons = {}
			for _, pat in ipairs(PATTERNS) do
				for _, w in ipairs(pat[2]) do
					if src:find(w) then
						reasons[#reasons + 1] = pat[1]
						break
					end
				end
			end
			if manual[d] or #reasons >= 2 or (reasons[1] == "bucle de rondas") then
				found = found + 1
				say("  " .. d:GetFullName() .. "  -> " .. (manual[d] and "a mano" or table.concat(reasons, ", ")))
				if APLICAR and (manual[d] or DESACTIVAR_DETECTADOS) then
					d.Disabled = true
				end
			end
		end
	end
end
if found == 0 then
	say("  ninguno")
end

say("")
if APLICAR then
	ChangeHistoryService:SetWaypoint("Preparar fusion Islas de Desastres")
	say("Hecho. Tus mapas estan en ServerStorage.IslasMapasPropios y los scripts listados estan DESACTIVADOS.")
	say("Prueba con Play. Si algo falta, reactiva un script quitando 'Disabled' o deshaz con Ctrl+Z.")
else
	say("Nada cambiado. Si la lista te parece bien, pon APLICAR = true y vuelve a ejecutarlo.")
end
