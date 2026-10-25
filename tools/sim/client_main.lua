-- Prueba del cliente: arranca la interfaz y le envia todos los mensajes del servidor.
local server = BuildTree()
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local failures = 0
local function check(c, msg) if not c then failures = failures + 1 print("FALLO: " .. msg) end end

local Net = require(RS.IslasShared.Net) -- crea los remotos (modo servidor)
local C = Color3.fromRGB
local snapshot = {
	Coins = 1234, XP = 300, Level = 3, LevelXP = 40, LevelNeed = 190, Title = "Novato", TitleColor = C(200, 200, 200),
	Owned = { GloboVerde = true, EstelaAzul = true }, Equipped = { Gears = { "GloboVerde" }, Trail = "EstelaAzul" },
	Stats = { Wins = 3, Rounds = 5, BestStreak = 2, CoinsEarned = 900, MapsSurvived = 2, DisastersSurvived = 3, DailyStreak = 1 },
	Achievements = { Primera = 1 }, Settings = { Quality = 0, Shake = 1, Music = true, Sounds = true },
	GearSlots = 1, DailyAvailable = true, DailyStreak = 1,
}
Net.Function("GetData").OnServerInvoke = function() return snapshot end
Net.Function("ShopRequest").OnServerInvoke = function(p, a, id) return true, "ok " .. tostring(id) end

LOCAL_PLAYER = MakePlayer("Yo")
Players.LocalPlayer = LOCAL_PLAYER
local cam = NewInstance("Camera")
cam.Parent = workspace
workspace.CurrentCamera = cam
local mapa = NewInstance("Folder")
mapa.Name = "MapaActual_Prueba"
mapa.Parent = workspace
local suelo = NewInstance("Part")
suelo.Size = Vector3.new(400, 2, 400)
suelo.Position = Vector3.new(0, -1, 0)
suelo.Anchored = true
suelo.Parent = mapa

RunScript(game:GetService("StarterPlayer").StarterPlayerScripts.IslasClient.Cliente)
SimAdvance(2)

local function ev(name) return RS.IslasRemotes[name] end
ev("DataUpdate"):FireClient(LOCAL_PLAYER, snapshot)
ev("RoundState"):FireClient(LOCAL_PLAYER, { Phase = "Intermission", Status = "Descanso", EndsAt = VCLOCK + 20, Disasters = {}, Alive = 0, Total = 0, AliveIds = {} })
SimAdvance(1)
ev("VoteOptions"):FireClient(LOCAL_PLAYER, {
	{ Name = "Airport", Title = "Aeropuerto", Description = "x", Disasters = { "Fire" }, DisasterTitles = { "Incendio" }, DisasterIcons = { "🔥" } },
	{ Name = "Mall", Title = "Centro", Description = "y", Disasters = {}, DisasterTitles = {}, DisasterIcons = {} },
}, VCLOCK + 10)
SimAdvance(1)
ev("VoteUpdate"):FireClient(LOCAL_PLAYER, { Airport = 2, Mall = 1 })
ev("VoteEnd"):FireClient(LOCAL_PLAYER, "Airport", "Aeropuerto")
SimAdvance(3)
ev("RoundState"):FireClient(LOCAL_PLAYER, { Phase = "Round", Status = "Sobrevive", EndsAt = VCLOCK + 60, Map = "Aeropuerto",
	Disasters = { { Title = "Tornado", Icon = "🌪️" } }, Modifier = { Id = "Monedas2", Title = "MONEDAS x2", Desc = "", Color = C(255, 200, 60) },
	Alive = 2, Total = 3, AliveIds = { 999999 } })
local DF = ev("DisasterFX")
local id = 7
DF:FireClient(LOCAL_PLAYER, "banner", id, { Title = "Tornado", Desc = "algo", Icon = "🌪️", Color = C(200, 200, 200) }, 3)
DF:FireClient(LOCAL_PLAYER, "start", id, "Tornado")
DF:FireClient(LOCAL_PLAYER, "shake", id, 1, 2)
DF:FireClient(LOCAL_PLAYER, "flash", id)
DF:FireClient(LOCAL_PLAYER, "tint", id, C(100, 200, 100), 0.8)
for _, w in ipairs({ "rain", "acid", "snow", "sand" }) do DF:FireClient(LOCAL_PLAYER, "weather", id, w) end
DF:FireClient(LOCAL_PLAYER, "marker", id, Vector3.new(0, 0, 0), 10, C(255, 0, 0), 1.5)
DF:FireClient(LOCAL_PLAYER, "markers", id, { Vector3.new(1, 0, 1) }, C(0, 255, 0))
DF:FireClient(LOCAL_PLAYER, "meteor", id, Vector3.new(0, 200, 0), Vector3.new(0, 0, 0), 1.5, C(255, 100, 0), 7)
DF:FireClient(LOCAL_PLAYER, "explosion", id, Vector3.new(0, 0, 0), 12, C(255, 100, 0))
DF:FireClient(LOCAL_PLAYER, "bolt", id, Vector3.new(0, 200, 0), Vector3.new(0, 0, 0), C(255, 255, 255))
DF:FireClient(LOCAL_PLAYER, "zone", id, 1, Vector3.new(5, 0, 5), 6, C(255, 100, 0), true)
DF:FireClient(LOCAL_PLAYER, "zone", id, 1, Vector3.new(5, 0, 5), 9, C(255, 100, 0), true)
DF:FireClient(LOCAL_PLAYER, "liquid", id, { cx = 0, cz = 0, sx = 300, sz = 300, y0 = -2, y1 = 30, t0 = VCLOCK, rise = 20, color = C(0, 0, 255), material = "SmoothPlastic", transparency = 0.3 })
local pts = { { 0, 0 }, { 50, 0 }, { 50, 50 } }
DF:FireClient(LOCAL_PLAYER, "path", id, "Tornado", { points = pts, speed = 10, t0 = VCLOCK, loop = true, radius = 40 })
DF:FireClient(LOCAL_PLAYER, "path", id, "BlackHole", { points = pts, speed = 5, t0 = VCLOCK, loop = true, height = 25 })
DF:FireClient(LOCAL_PLAYER, "path", id, "UFO", { points = pts, speed = 14, t0 = VCLOCK, loop = true, height = 70, index = 1 })
DF:FireClient(LOCAL_PLAYER, "beam", id, 1, 3)
DF:FireClient(LOCAL_PLAYER, "wave", id, { start = Vector3.new(-100, 0, 0), dir = Vector3.new(1, 0, 0), speed = 30, t0 = VCLOCK + 1, width = 200, height = 30, thick = 30, duration = 8 })
DF:FireClient(LOCAL_PLAYER, "infected", id, LOCAL_PLAYER.UserId, true)
ev("Shatter"):FireClient(LOCAL_PLAYER, {
	{ p = Vector3.new(0, 5, 0), s = Vector3.new(12, 6, 1), c = C(200, 200, 200), m = "Concrete" },
	{ p = Vector3.new(3, 5, 0), s = Vector3.new(4, 4, 0.5), c = C(170, 215, 235), m = "Glass" },
})
local frag = workspace:FindFirstChild("FragmentosLocales")
check(frag and #frag:GetChildren() > 0, "no se crearon fragmentos")
SimAdvance(4)
ev("Popup"):FireClient(LOCAL_PLAYER, { Coins = 5, XP = 2, Text = "Sigues vivo" })
ev("Popup"):FireClient(LOCAL_PLAYER, { Coins = 25, XP = 1, Position = Vector3.new(1, 2, 3) })
ev("Toast"):FireClient(LOCAL_PLAYER, { Kind = "LevelUp", Title = "¡NIVEL 4!", Text = "Rango: Novato" })
ev("Toast"):FireClient(LOCAL_PLAYER, { Kind = "Achievement", Title = "Logro", Text = "x" })
ev("KillFeed"):FireClient(LOCAL_PLAYER, { Name = "Beto", Cause = "Tornado", UserId = 1 })
ev("ElevatorMenu"):FireClient(LOCAL_PLAYER, 1, { "PB", "1", "2", "3" }, 1)
ev("PlaySound"):FireClient(LOCAL_PLAYER, "Coin", Vector3.new(0, 0, 0), 1)
ev("OpenUI"):FireClient(LOCAL_PLAYER, "Shop")
SimAdvance(1)
ev("OpenUI"):FireClient(LOCAL_PLAYER, "Daily")
SimAdvance(10)
DF:FireClient(LOCAL_PLAYER, "end", id)
DF:FireClient(LOCAL_PLAYER, "clear", 0)
ev("RoundResults"):FireClient(LOCAL_PLAYER, { Survived = true, Coins = 120, XP = 40, Streak = 3, Map = "Aeropuerto", Disasters = { "Tornado" }, Survivors = { "Yo" }, Total = 3, Modifier = "MONEDAS x2" })
SimAdvance(8)
ev("RoundState"):FireClient(LOCAL_PLAYER, { Phase = "Results", Status = "x", EndsAt = VCLOCK + 5, Disasters = {}, Alive = 1, Total = 3, AliveIds = { LOCAL_PLAYER.UserId } })
SimAdvance(2)

-- botones de la interfaz: pulsar todos los TextButton visibles
local pg = LOCAL_PLAYER.PlayerGui
local pressed = 0
for _, d in ipairs(pg:GetDescendants()) do
	if d:IsA("TextButton") then
		d.Activated:Fire()
		d.MouseEnter:Fire()
		d.MouseButton1Down:Fire()
		pressed = pressed + 1
	end
end
SimAdvance(3)
print("Botones pulsados: " .. pressed .. ", guis: " .. #pg:GetChildren())
check(#pg:GetChildren() >= 10, "faltan interfaces")
check(#CLIENT_SENT > 0, "el cliente no envio nada al servidor")
local sent = {}
for _, s in ipairs(CLIENT_SENT) do sent[s.name] = (sent[s.name] or 0) + 1 end
local names = {}
for k, v in pairs(sent) do names[#names + 1] = k .. "=" .. v end
table.sort(names)
print("Enviado al servidor: " .. table.concat(names, " "))
check(#THREAD_ERRORS == 0, #THREAD_ERRORS .. " errores en hilos del cliente")
check(#WARNINGS == 0, #WARNINGS .. " avisos en el cliente")
print(failures == 0 and "CLIENTE OK" or ("FALLOS: " .. failures))
