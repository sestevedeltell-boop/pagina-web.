-- 1) EXPORTAR TU JUEGO (para fusionarlo con Islas de Desastres)
-- Pega esto en la Barra de comandos de Studio (Ver > Barra de comandos) con TU juego abierto y pulsa Enter.
-- No cambia nada de tu juego: solo crea en ServerStorage una carpeta "IslasExportacion" con uno o varios
-- Scripts de texto que contienen:
--   * el arbol de tu juego (carpetas, modelos y cuantas piezas tiene cada uno),
--   * los mapas que parece tener (modelos grandes) con su tamano,
--   * el codigo de TODOS tus scripts.
-- Despues abre cada Script de IslasExportacion, Ctrl+A, Ctrl+C y pegalo en un archivo .txt. Subelo al
-- repositorio (GitHub > Add file > Upload files, en una carpeta "otro_juego") o pegalo en el chat.

local MAX_CHARS = 180000 -- por Script (Studio va lento con textos enormes)
local IGNORE = { IslasShared = true, IslasMapas = true, IslasServer = true, IslasClient = true, IslasExportacion = true, IslasRemotes = true, MapaActual = true }

local out, parts = {}, {}
local size = 0
local function emit(line)
	out[#out + 1] = line
	size = size + #line + 1
	if size > MAX_CHARS then
		parts[#parts + 1] = table.concat(out, "\n")
		out, size = {}, 0
	end
end

local function ignored(inst)
	local p = inst
	while p and p ~= game do
		if IGNORE[p.Name] or p.Name:sub(1, 11) == "MapaActual_" then
			return true
		end
		p = p.Parent
	end
	return false
end

local function partCount(inst)
	local n = 0
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			n = n + 1
		end
	end
	return n
end

local SERVICES = { "Workspace", "ServerScriptService", "ServerStorage", "ReplicatedStorage", "ReplicatedFirst", "StarterPlayer", "StarterGui", "StarterPack", "Lighting", "Teams", "SoundService" }

emit("-- ===== EXPORTACION DEL JUEGO: " .. tostring(game.Name) .. " (PlaceId " .. tostring(game.PlaceId) .. ") =====")
emit("--[[")
emit("ARBOL (carpetas y modelos con numero de piezas; profundidad 3)")
local function tree(inst, depth, prefix)
	for _, c in ipairs(inst:GetChildren()) do
		if not ignored(c) and (c:IsA("Folder") or c:IsA("Model") or c:IsA("LuaSourceContainer") or c:IsA("ScreenGui") or c:IsA("Tool") or c:IsA("Configuration")) then
			local extra = ""
			if c:IsA("Folder") or c:IsA("Model") then
				extra = "  [" .. partCount(c) .. " piezas]"
			end
			emit(prefix .. c.Name .. " (" .. c.ClassName .. ")" .. extra)
			if depth < 3 then
				tree(c, depth + 1, prefix .. "    ")
			end
		end
	end
end
for _, sname in ipairs(SERVICES) do
	local ok, svc = pcall(game.GetService, game, sname)
	if ok and svc then
		emit(sname)
		tree(svc, 1, "    ")
	end
end

emit("")
emit("POSIBLES MAPAS (modelos/carpetas con 80+ piezas)")
for _, sname in ipairs({ "Workspace", "ServerStorage", "ReplicatedStorage", "Lighting" }) do
	local svc = game:GetService(sname)
	for _, d in ipairs(svc:GetDescendants()) do
		if (d:IsA("Model") or d:IsA("Folder")) and not ignored(d) and not d:FindFirstChildOfClass("Humanoid") then
			local n = partCount(d)
			local parentN = (d.Parent and d.Parent ~= svc and (d.Parent:IsA("Model") or d.Parent:IsA("Folder"))) and partCount(d.Parent) or 0
			-- solo el nivel que agrupa (no cada sub-modelo)
			if n >= 80 and (parentN == 0 or parentN > n * 3) then
				local s = ""
				if d:IsA("Model") then
					local _, sz = d:GetBoundingBox()
					s = string.format("  tamano %.0fx%.0fx%.0f", sz.X, sz.Y, sz.Z)
				end
				local spawns = 0
				for _, x in ipairs(d:GetDescendants()) do
					if x:IsA("SpawnLocation") or (x:IsA("BasePart") and x.Name:lower():match("spawn")) then
						spawns = spawns + 1
					end
				end
				emit("    " .. d:GetFullName() .. "  [" .. n .. " piezas, " .. spawns .. " spawns]" .. s)
			end
		end
	end
end
emit("]]")
emit("")

-- codigo de todos los scripts
local count = 0
for _, sname in ipairs(SERVICES) do
	local ok, svc = pcall(game.GetService, game, sname)
	if ok and svc then
		for _, d in ipairs(svc:GetDescendants()) do
			if d:IsA("LuaSourceContainer") and not ignored(d) then
				count = count + 1
				local src = d.Source
				local n = 0
				while src:find("]" .. string.rep("=", n) .. "]", 1, true) do
					n = n + 1
				end
				local eq = string.rep("=", n)
				emit("-- ===== " .. d.ClassName .. ": " .. d:GetFullName() .. (d:IsA("BaseScript") and d.Disabled and " (DESACTIVADO)" or "") .. " =====")
				emit("--[" .. eq .. "[")
				for line in (src .. "\n"):gmatch("(.-)\n") do
					emit(line)
				end
				emit("]" .. eq .. "]")
				emit("")
			end
		end
	end
end
emit("-- ===== FIN: " .. count .. " scripts =====")
parts[#parts + 1] = table.concat(out, "\n")

local folder = game:GetService("ServerStorage"):FindFirstChild("IslasExportacion")
if folder then
	folder:Destroy()
end
folder = Instance.new("Folder")
folder.Name = "IslasExportacion"
for i, text in ipairs(parts) do
	local s = Instance.new("Script")
	s.Name = "Exportacion_" .. i .. "_de_" .. #parts
	s.Disabled = true
	s.Source = text
	s.Parent = folder
end
folder.Parent = game:GetService("ServerStorage")
print("Exportacion lista: " .. count .. " scripts en " .. #parts .. " parte(s). Mira ServerStorage > IslasExportacion.")
