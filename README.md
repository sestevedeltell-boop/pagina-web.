# Islas de Desastres

Sistema de **mundos/islas** para un juego de Roblox de desastres naturales. Las islas **no existen** hasta que
se votan: al terminar la ronda los jugadores votan, **solo entonces se construye** la isla ganadora (por
código, sin lag para el resto), se teletransporta a todos y, al acabar, se **borra**.

## Mundos incluidos

| Mapa | Qué tiene | Ascensores |
|---|---|---|
| **Aeropuerto** | Terminal de 3 plantas (check-in, seguridad, restaurantes, bar VIP), cinta de equipajes que mueve a los jugadores, 2 aviones con interior y escalerilla, hangar, camiones, torre de control, pista | 2 en la terminal (3 plantas) + 1 en la torre (4 paradas, hasta 90 studs) |
| **Centro Comercial** | 4 plantas alrededor de un atrio con claraboya y fuente, tiendas, cine en la última planta, aparcamiento | 2 ascensores panorámicos de cristal |
| **Rascacielos** | Torre de 12 plantas + azotea (helipuerto, piscina), sky bar, escalera de emergencia en zigzag | 3 ascensores, 13 paradas |
| **Plataforma Petrolífera** | Cubierta sobre 4 patas en alta mar, torre de perforación (se sube por escalera), alojamiento, grúa, helipuerto, muelle con bote | 1 ascensor muelle → cubierta → módulo → helipuerto |
| **Estación Espacial** | Núcleo de 4 plantas, 4 brazos con laboratorio, invernadero, reactor y hangar con lanzadera, paneles solares. **Gravedad baja** | 2 ascensores |

Los ascensores son reales: botón de llamada en cada planta (tecla **E**), botonera dentro de la cabina
(clic en el número), puertas que se abren y cierran, y cola de peticiones.

## Desastres

Al llegar a la isla los jugadores ven un aviso (`Config.DisasterDelay` = 10 s) y después empieza **un desastre al azar**
de los que admite ese mapa. Dura lo que la ronda y se limpia solo al terminar (también restaura la iluminación).
En la votación cada mapa muestra qué desastres puede tener.

| Desastre | Qué hace |
|---|---|
| **Terremoto** | La cámara tiembla, tira a jugadores al suelo y rompe hasta la mitad de las piezas pequeñas (paredes, muebles, cristales); los ascensores no se rompen |
| **Incendio** | Focos de fuego que crecen y queman; algunos aparecen cerca de los jugadores |
| **Lluvia de meteoritos** | Un círculo rojo avisa 1,8 s antes del impacto; explosión con daño y empujón. Cada vez más rápido |
| **Inundación** | El agua sube hasta una altura que depende del mapa; abajo te ahogas |
| **Lava** | El suelo es lava: sube y mata al instante |
| **Tormenta eléctrica** | Rayos con anillo de aviso, destellos y cielo oscuro |
| **Lluvia ácida** | Quema a quien esté a cielo abierto; bajo techo estás a salvo |
| **Tornado** | Recorre la isla, arrastra y lanza por los aires jugadores y piezas sueltas |
| **Fuga de radiación** | Nubes verdes que dañan (estación espacial) |

| Mapa | Desastres posibles |
|---|---|
| Aeropuerto | Terremoto, Incendio, Meteoritos, Inundación (hasta la planta 1), Tormenta eléctrica, Tornado |
| Centro Comercial | Terremoto, Incendio, Meteoritos, Lluvia ácida, Lava (hay que llegar a la última planta) |
| Rascacielos | Terremoto, Incendio, Tormenta eléctrica, Lluvia ácida, Tornado, Lava |
| Plataforma Petrolífera | Tornado, Tormenta eléctrica, Meteoritos, Inundación (tsunami), Incendio, Lluvia ácida |
| Estación Espacial | Meteoritos, Incendio, Terremoto, Fuga de radiación |

Ajustes por mapa en su `DisasterConfig` (por ejemplo `Flood = { maxHeight = 30 }`, `Meteors = { damage = 60, radius = 14 }`).
Para desactivarlos todos: `EnableDisasters = false` en `Config`.

**Añadir un desastre:** crea un ModuleScript en `src/server/Disasters/` con `Title`, `Description` y
`Run(ctx)`; añade su nombre al `Disasters = {...}` de los mapas donde quieras que salga. `Run` es un bucle
`while ctx.active() do ... end`. El `ctx` ofrece `players()`, `damage()`, `randomPoint()`, `groundY(x, z)`,
`build:Box(...)` (efectos que se borran solos), `fx(...)` (efectos de pantalla), `setLighting(...)`,
`tween(...)`, `fragileParts()` y `progress()`.

## Instalación

**Opción A: instalador (sin Rojo).** Abre `dist/instalar_en_studio.lua`, copia todo, pégalo en la
*Barra de comandos* de Studio (pestaña *Ver* → *Barra de comandos*) y pulsa Enter. Crea 4 carpetas
(`ReplicatedStorage.IslasShared`, `ServerStorage.IslasMapas`, `ServerScriptService.IslasServer`,
`StarterPlayerScripts.IslasClient`) y no toca nada más de tu juego. Puedes volver a ejecutarlo para actualizar.

**Opción B: Rojo.** `rojo serve` con `default.project.json` y conecta Studio.

**Opción C: a mano.** Crea cada archivo de `src/` como script en la misma ruta que indica
`default.project.json` (`.lua` = ModuleScript, `.server.lua` = Script, `.client.lua` = LocalScript).

Si cambias algo en `src/`, regenera el instalador con `npm run installer`.

## Cómo encaja con tu juego

Por defecto `RoundLoop` lleva el ciclo: espera → votación → construye isla → teletransporta → ronda → vuelta al lobby.
Si **ya tienes tu propio bucle de rondas**, pon `RunDefaultLoop = false` en `IslasShared/Config` y llama tú:

```lua
local MapService  = require(game.ServerScriptService.IslasServer.MapService)
local VoteService = require(game.ServerScriptService.IslasServer.VoteService)

-- al terminar tu ronda:
local winner = VoteService.Run(VoteService.PickOptions(3), 15) -- bloquea hasta acabar la votación
MapService.Load(winner)                                         -- construye la isla (aquí aparece por primera vez)
MapService.TeleportToMap(game.Players:GetPlayers())
local DisasterService = require(game.ServerScriptService.IslasServer.DisasterService)
DisasterService.Start(MapService.GetCurrent(), 180)             -- desastre al azar del mapa (opcional)
-- ... tu ronda ...
DisasterService.Stop()                                          -- antes de Unload, para restaurar la luz
MapService.ReturnToLobby(game.Players:GetPlayers())
MapService.Unload()                                             -- la isla desaparece
```

- Los puntos de aparición de cada isla están en `MapService.GetCurrent().Spawns`.
- El lobby: si existe `workspace.Lobby` se usan sus `SpawnLocation`; si no, cualquier `SpawnLocation` del workspace;
  y si no hay ninguno se crea un lobby simple.
- Los jugadores que mueren durante la ronda reaparecen en el lobby (comportamiento normal de Roblox).
- Las islas se construyen en `Config.MapOrigin` (por defecto `8000, 1000, 0`), lejos del lobby.

## Añadir un mundo nuevo

Crea un ModuleScript en `src/maps/Builders/` (cualquier nombre; aparece solo en la votación):

```lua
local Util = require(script.Parent.Parent.Lib.Util)
local Elevator = require(script.Parent.Parent.Lib.Elevator)
local V, C, M = Util.V, Util.C, Util.M

return {
  Title = "Mi Mundo", Description = "Texto de la votación",
  Lighting = { ClockTime = 14 },   -- opcional
  Gravity = 120,                    -- opcional
  Bounds = { x1 = -100, x2 = 100, z1 = -100, z2 = 100, top = 80, floor = 0 }, -- zona jugable (para los desastres)
  Disasters = { "Earthquake", "Fire", "Meteors" },                             -- los que pueden salir aqui
  Build = function(b)
    b:Box("Suelo", V(200, 2, 200), V(0, -1, 0), C(90, 140, 70), M.Grass)
    b:Wall("Pared", "x", 0, -20, 20, 0, 12, 1, C(200, 200, 200), M.Concrete, { {from=-4, to=4, bottom=0, top=9} })
    Elevator.build(b, { name = "Asc", x = 0, z = -30, floors = { 0, 20, 40 } })
    b:Spawn(V(0, 1, 40))
  end,
}
```

`Util` ofrece: `Box`, `Pillar`, `Ball`, `Wall` (con huecos y ventanas), `Slab` (suelo con agujeros),
`Stairs`, `Ladder`, `Board` (cartel con texto), `Sea` / `KillPlane`, `Pine`, `Spawn`, `Group` y `At`
(subgrupo con origen desplazado). Los ascensores miran a +Z; los agujeros de los forjados salen de `Elevator.hole(cfg)`.

## Pruebas

`npm install && npm test` construye cada mapa en un simulador de la API de Roblox (`tools/sim/`), llama a todos los
ascensores, comprueba spawns, teletransporte, votación, todos los desastres de cada mapa y una vuelta completa de `RoundLoop`.
**No sustituye a probar en Studio**: no simula la física (por ejemplo, cómo se agarran los jugadores a la cabina al moverse).
