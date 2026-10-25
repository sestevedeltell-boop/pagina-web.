-- Pruebas del servidor en el simulador.
--   node tools/sim/run.js            (todas)
--   node tools/sim/run.js --solo Mall
local server = BuildTree()
local RS = game:GetService("ReplicatedStorage")

local failures = 0
function check(cond, msg)
	if not cond then
		failures = failures + 1
		print("FALLO: " .. msg)
	end
	return cond
end

-- Ejecuta fn en un hilo gestionado y avanza el reloj hasta que termine
function runAsync(fn, maxSeconds)
	local done, result, err = false, nil, nil
	task.spawn(function()
		local ok, r = pcall(fn)
		if ok then result = r else err = r end
		done = true
	end)
	local limit = VCLOCK + (maxSeconds or 120)
	while not done and VCLOCK < limit do
		SimAdvance(0.1)
	end
	if err then error(err, 0) end
	check(done, "runAsync no termino a tiempo")
	return result
end

local Shared = RS.IslasShared
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local tests = {}
local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end

TEST = { test = test, server = server, Config = Config, Net = Net }
local extra = load(TEST_EXTRA or "", "=tests_extra", "t", setmetatable({ test = test }, { __index = _G }))

-- ======================================================================
-- Carga de modulos y mapas
-- ======================================================================
local MapService = require(server.MapService)
local Destruction = require(server.Destruction)
local PhysicsBudget = require(server.PhysicsBudget)
require(server.CollisionGroups).Setup()

test("mapas", function()
	local names = MapService.GetMapNames()
	print("Mapas: " .. table.concat(names, ", "))
	check(#names >= 5, "deberia haber al menos 5 mapas")
	local player = MakePlayer("Probador")
	for _, name in ipairs(names) do
		if not SOLO or SOLO == name then
			local t0 = os.clock()
			local folder = runAsync(function() return MapService.Load(name) end, 600)
			local cur = MapService.GetCurrent()
			local parts = 0
			for _, d in ipairs(folder:GetDescendants()) do
				if d:IsA("BasePart") then parts = parts + 1 end
			end
			if DUMP then
				for _, d in ipairs(folder:GetDescendants()) do
					if d:IsA("BasePart") then
						local r = d.CFrame.Rot
						print(string.format("PART\t%s\t%s\t%.2f,%.2f,%.2f\t%.2f,%.2f,%.2f\t%.3f,%.3f,%.3f\t%.2f,%.2f,%.2f\t%s\t%s\t%s",
							name, d.Name, d.Size.X, d.Size.Y, d.Size.Z, d.Position.X, d.Position.Y, d.Position.Z, r.X, r.Y, r.Z,
							d.Color.R, d.Color.G, d.Color.B, tostring(d.Transparency), tostring(d.CanCollide), tostring(d.Shape)))
					end
				end
			end
			print(string.format("%s: %d piezas, %d spawns, construido en %.1fs reales", name, parts, #cur.Spawns, os.clock() - t0))
			check(#cur.Spawns >= 8, name .. ": pocos spawns")
			for _, d in ipairs(folder:GetDescendants()) do
				if d:IsA("BasePart") then
					local s = d.Size
					if not (s.X > 0 and s.Y > 0 and s.Z > 0 and s.X <= 2048 and s.Y <= 2048 and s.Z <= 2048) then
						check(false, name .. ": tamano invalido en " .. d.Name)
					end
				end
			end

			-- grafo de apoyos
			for _ = 1, 120 do
				if Destruction.Stats().graphReady then break end
				SimAdvance(1)
			end
			local st = Destruction.Stats()
			check(st.graphReady, name .. ": el grafo de apoyos no termino")
			print(string.format("  destruccion: %d piezas registradas", st.parts))
			if st.loose > 0 then
				local names = {}
				for _, p in ipairs(st.looseParts) do
					names[#names + 1] = p.Name .. "@" .. string.format("%.0f,%.0f,%.0f", p.Position.X - Config.MapOrigin.X, p.Position.Y - Config.MapOrigin.Y, p.Position.Z - Config.MapOrigin.Z)
				end
				print("  nacen sin apoyo (" .. st.loose .. "): " .. table.concat(names, " "))
			end
			check(#Destruction.FindUnsupported() == 0, name .. ": quedan piezas sin apoyo tras cargar")

			-- ascensores: llamar a cada planta
			for _, d in ipairs(folder:GetDescendants()) do
				if d:IsA("Model") and d.Name:match("_Cabina$") then
					local prefix = d.Name:gsub("_Cabina$", "")
					local floorPart = d.PrimaryPart
					local base = floorPart.Position.Y
					local prompts = {}
					for _, pp in ipairs(folder:GetDescendants()) do
						if pp:IsA("ProximityPrompt") and pp.Parent.Parent and pp.Parent.Parent.Name == prefix .. "_Hueco" then
							prompts[#prompts + 1] = pp
						end
					end
					check(#prompts >= 2, name .. ": " .. prefix .. " con menos de 2 plantas")
					prompts[#prompts].Triggered:Fire(player)
					SimAdvance(40)
					local up = floorPart.Position.Y - base
					check(up > 5, name .. ": " .. prefix .. " no sube")
					prompts[1].Triggered:Fire(player)
					SimAdvance(40)
					check(math.abs(floorPart.Position.Y - base) < 0.05, name .. ": " .. prefix .. " no vuelve abajo")
					print(string.format("  %s: %d plantas, sube %.0f", prefix, #prompts, up))
				end
			end

			-- teletransporte
			MapService.TeleportToMap({ player })
			SimAdvance(0.5)
			check(MapService.IsOnMap(player), name .. ": jugador no llego al mapa")

			-- destruccion: romper la planta baja entera y comprobar que lo de encima se derrumba
			local b = cur.Bounds
			local center = Vector3.new((b.x1 + b.x2) / 2, b.floor + 6, (b.z1 + b.z2) / 2)
			local brokenNow = Destruction.DamageSphere(center, 25, 400, { fling = 30 })
			Destruction.DamageBox(CFrame.new(Vector3.new((b.x1 + b.x2) / 2, b.floor + 4, (b.z1 + b.z2) / 2)), Vector3.new(b.x2 - b.x1, 9, b.z2 - b.z1), 1e6, { maxParts = 100000 })
			SimAdvance(3)
			local st2 = Destruction.Stats()
			print(string.format("  rotas=%d derrumbadas=%d fisicas=%d escombros=%d", st2.broken, st2.collapsed, st2.physics, st2.rubble))
			check(st2.broken > 0, name .. ": no se rompio nada")
			check(st2.physics <= Config.MaxPhysicsBodies, name .. ": se paso el presupuesto de fisica")
			SimAdvance(15)
			check(PhysicsBudget.Count() == 0, name .. ": quedan cuerpos fisicos sin congelar (" .. PhysicsBudget.Count() .. ")")

			MapService.ReturnToLobby({ player })
			MapService.Unload()
			for _ = 1, 60 do
				if not workspace:FindFirstChild("MapaBorrandose") then break end
				SimAdvance(1)
			end
			check(workspace:FindFirstChild("MapaBorrandose") == nil, name .. ": el mapa viejo no se borro")
		end
	end
	RemovePlayer(player)
end)

if extra then extra() end

for _, t in ipairs(tests) do
	if not ONLY or ONLY == t.name then
		local ok, err = pcall(t.fn)
		if not ok then
			check(false, "prueba '" .. t.name .. "' fallo: " .. tostring(err))
		end
	end
end

check(#THREAD_ERRORS == 0, #THREAD_ERRORS .. " errores en hilos")
print(failures == 0 and "TODO OK" or ("FALLOS: " .. failures))
