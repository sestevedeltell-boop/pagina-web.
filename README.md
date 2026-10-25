# Islas de Desastres

Juego completo de supervivencia a desastres para Roblox, todo por código: lobby, votación de mapas,
11 islas que solo existen mientras se juegan, 16 desastres con destrucción real de edificios, economía con
monedas, niveles, logros, tienda de gears y estelas, recompensa diaria y modo espectador.

Inspirado en el género de *Natural Disaster Survival* y *Survive the Disasters*: rondas cortas, sorpresa,
rachas, recompensas constantes y edificios que se caen a pedazos.

## Instalación

**Opción A: plugin instalador (la más cómoda, sin Rojo).** Abre `dist/plugin_instalador.lua`, copia todo y
pégalo en un Script nuevo de Studio (por ejemplo en ServerStorage). Clic derecho sobre el Script →
*Save as Local Plugin...* y después borra ese Script. En la pestaña *Plugins* aparece el botón
**Instalar Islas**: púlsalo cada vez que quieras instalar o actualizar.

**Opción B: Barra de comandos.** Pega en la *Barra de comandos* (*Ver* → *Barra de comandos*) los archivos de
`dist/partes/` en orden (`instalar_parte_1.lua`, `_2`, `_3`...) pulsando Enter tras cada uno. También está
`dist/instalar_en_studio.lua` con todo junto, pero puede ser demasiado largo para la Barra de comandos.

Cualquiera de los dos crea (o reemplaza) solo estas 4 carpetas: `ReplicatedStorage.IslasShared`,
`ServerStorage.IslasMapas`, `ServerScriptService.IslasServer` y `StarterPlayer.StarterPlayerScripts.IslasClient`.

**Opción C: Rojo.** `rojo serve` con `default.project.json` y conecta Studio.

**Opción D: a mano.** Crea cada archivo de `src/` en la ruta que indica `default.project.json`
(`.lua` = ModuleScript, `.server.lua` = Script, `.client.lua` = LocalScript).

Para guardar datos de verdad en Studio activa *Game Settings → Security → Enable Studio Access to API Services*.
Sin eso se juega con datos temporales (no se pierde ni se sobrescribe nada).

**Recomendado para rendimiento:** activa `Workspace.StreamingEnabled`. Las islas se construyen lejos del
lobby y los jugadores solo cargan lo que tienen cerca (el teletransporte ya pide la zona antes de llegar).

Si cambias algo en `src/`, regenera el instalador con `npm run installer`.

## Cómo es una partida

1. **Descanso** en el lobby (tienda, cofre diario, obby con premio, camas elásticas, clasificaciones).
2. **Votación** entre 3 mapas (no repite el último). Cada tarjeta muestra los desastres posibles.
3. Se **construye la isla** ganadora (repartido entre frames para no dar tirones) y se teletransporta a todos.
4. **Aviso** de unos segundos y empieza el desastre. Puede haber:
   - un **modificador de ronda** (doble desastre, monedas x2, noche, gravedad baja, pies rápidos, modo hiper, niebla, edificios de papel),
   - un **desastre sorpresa** (no se sabe cuál es hasta que empieza),
   - un **segundo desastre** a mitad de ronda.
5. Durante la ronda: monedas repartidas por el mapa, +monedas cada 15 s vivo, lista de muertes con la causa,
   contador de vivos, espectador para los muertos.
6. **Resultados**: monedas que cuentan hacia arriba, XP, racha y confeti si sobrevives. La isla se borra.

## Mapas (11)

| Mapa | Lo más destacado | Ascensores |
|---|---|---|
| Aeropuerto | terminal de 3 plantas, aviones, hangar, torre de control | 3 |
| Centro comercial | atrio de 4 plantas, cine, aparcamiento | 2 de cristal |
| Rascacielos | 12 plantas, helipuerto y piscina en la azotea | 3 (13 paradas) |
| Plataforma petrolífera | alta mar, torre de perforación, helipuerto | 1 (muelle → helipuerto) |
| Estación espacial | núcleo + 4 módulos, gravedad baja | 2 |
| Ciudad | casas de 1-3 plantas, tiendas, gasolinera, parque, depósito de agua | torre de apartamentos |
| Castillo | murallas con adarve, torres, foso, mercado, torre del homenaje | montacargas |
| Estación de esquí | montaña por terrazas, refugio, cabañas, telesilla | funicular a la cima |
| Crucero | 4 cubiertas en alta mar, piscina, botes salvavidas | 2 |
| Parque de atracciones | noria y tiovivo que giran, montaña rusa, casa del terror | torre de caída |
| Isla tropical | palmeras, cabañas, barco pirata, montaña con cascada | faro con luz giratoria |

**Tus propios mapas:** mete un `Model` en `ServerStorage.IslasMapasPropios` y aparece en la votación.
Atributos opcionales: `Title`, `Description`, `Disasters` (por ejemplo `"Earthquake,Fire,Tornado"`).
Las piezas llamadas `Spawn`/`SpawnPoint` (o `SpawnLocation`) son los puntos de aparición; si no hay, se buscan solos.
Las piezas sueltas (muebles) se anclan al cargar y solo se sueltan cuando un desastre las golpea.

## Desastres (16)

Terremoto · Incendio (se propaga por la madera) · Lluvia de meteoritos · Inundación · Lava (derrite los edificios) ·
Tormenta eléctrica · Lluvia ácida (corroe los tejados) · Tornado · Fuga de radiación · Ventisca (hogueras para calentarse) ·
Tormenta de arena · Volcán (surge del suelo y lanza bombas) · Tsunami (olas que arrasan) · Virus mortal (contagio y estaciones de cura) ·
Agujero negro (absorbe piezas) · Invasión alienígena (ovnis con rayo abductor y láseres).

Cada mapa elige qué desastres admite (`Disasters`) y puede ajustarlos (`DisasterConfig`, por ejemplo la altura del agua).

## Destrucción y rendimiento

La destrucción está pensada para que se vea espectacular sin hundir los FPS:

- **Paredes y suelos troceados** (`Config.ChunkSize`): se rompen por partes, no enteros.
- **Vida por material y tamaño**: el cristal estalla enseguida, la madera arde, el hormigón y el metal aguantan.
  Las piezas se oscurecen al recibir daño.
- **Derrumbes reales**: al cargar el mapa se calcula (repartido entre frames) quién se apoya en quién.
  Si algo se queda sin conexión con el suelo, se cae. Lo hace en **bloques soldados**: muchas piezas forman un
  solo cuerpo físico, mucho más barato que piezas sueltas.
- **Presupuesto de física** (`MaxPhysicsBodies`): nunca hay más de N cuerpos simulándose. Lo que no cabe se
  convierte en **fragmentos visuales en el cliente**.
- **Los escombros se congelan**: cuando un trozo se para (o tras `DebrisMaxLife` s) se ancla. Sigue viéndose como
  escombro pero ya no cuesta física. Hay un máximo de escombros (`MaxRubbleParts`).
- **Los escombros no chocan entre sí** (grupo de colisión propio), que es lo más caro de la física.
- **Fragmentos solo en el cliente**: los añicos los crea cada jugador localmente, reutilizando piezas de un pool.
  El servidor no simula ni replica nada.
- **Calidad automática**: si un jugador va a menos de ~38 FPS se reducen fragmentos, partículas y efectos; si va
  sobrado, se suben. También se puede fijar en *Ajustes*.
- **Borrado repartido**: las piezas rotas y el mapa al terminar se borran poco a poco, sin tirones.
- **Efectos de desastre en el cliente**: meteoritos, rayos, olas, tornados, agujeros negros y ovnis se dibujan en
  cada cliente con movimiento determinista basado en el reloj del servidor. No se replican piezas en movimiento.
- Los muebles que estaban sueltos se anclan hasta que algo los golpea, así no consumen física mientras no pasa nada.
- Las piezas del mapa no generan eventos `Touched` y las pequeñas no proyectan sombra.

## Economía y progresión

- **Monedas**: sobrevivir (+bonus por racha), participar, cada 15 s vivo, monedas del mapa (las rosas valen más),
  logros, subidas de nivel, obby del lobby y recompensa diaria (racha de 7 días).
- **Niveles y rangos** (Novato → Inmortal) con barra de XP.
- **23 logros** con recompensa.
- **Tienda**: 9 gears (linterna, botiquín, globo, paraguas, bobinas de velocidad y gravedad, mochila cohete,
  garfio, escudo), 5 estelas y 4 mejoras permanentes (ranura de gear extra, imán de monedas, más vida, suerte).
- `leaderstats` (Victorias, Nivel, Monedas) y clasificaciones en el lobby (servidor y mundial).

## Integrar con tu propio juego

Todo se ajusta en `IslasShared/Config`. Para llevar tú las rondas pon `RunDefaultLoop = false` y usa:

```lua
local S = game.ServerScriptService.IslasServer
local MapService = require(S.MapService)
local VoteService = require(S.VoteService)
local DisasterService = require(S.DisasterService)

local winner = VoteService.Run(VoteService.PickOptions(3), 12)
MapService.Load(winner)
MapService.TeleportToMap(game.Players:GetPlayers())
DisasterService.Start(MapService.GetCurrent(), 150)        -- desastre al azar del mapa
-- ... tu ronda ...
DisasterService.StopAll()
MapService.ReturnToLobby(game.Players:GetPlayers())
MapService.Unload()
```

El lobby propio se construye solo si no existe ya `workspace.Lobby` (`Config.BuildLobby`).

## Añadir contenido

- **Mapa nuevo**: ModuleScript en `src/maps/Builders/` con `Title`, `Description`, `Bounds`, `Disasters` y
  `Build(b)`. `Util` (piezas, paredes con ventanas, suelos con agujeros, escaleras, carteles...),
  `Buildings` (casas, torres con ascensor y escaleras, palmeras, coches, farolas) y `Elevator` hacen casi todo.
  `b:Spin(modelo, rpm, eje)` hace girar algo en los clientes.
- **Desastre nuevo**: ModuleScript en `src/server/Disasters/` con `Run(ctx)` (bucle `while ctx.active()`),
  su ficha en `src/shared/DisasterInfo.lua` y su nombre en los `Disasters` de los mapas.
  `Hazards` tiene impactos avisados, zonas que crecen y líquidos que suben; `ctx.D` es la destrucción.
- **Objetos de la tienda**: `src/shared/Catalog.lua` y su efecto en `src/server/Gear.lua`.
- **Sonidos y música**: `src/shared/Sounds.lua` (pon ids de la biblioteca).

## Pruebas

`npm install && npm test` ejecuta un simulador de la API de Roblox (`tools/sim/`):

- construye los 11 mapas, prueba todos los ascensores, la destrucción y los derrumbes, y avisa de piezas sin apoyo;
- lanza cada desastre en cada mapa con jugadores;
- juega partidas completas (fases, votación, resultados, monedas, tienda, recompensa diaria, logros);
- arranca toda la interfaz del cliente y le envía todos los mensajes del servidor (`node tools/sim/run.js --client`).

El simulador no reproduce la física real ni el render: hay que probar en Studio la sensación de juego, los
tiempos y los valores de daño.
