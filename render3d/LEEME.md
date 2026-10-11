# Render 3D de la villa

La animación del inicio de la web es una secuencia de 288 imágenes Full HD renderizadas con Blender (Cycles).
Estos scripts regeneran la escena y los fotogramas. Todo se ejecuta desde esta carpeta (`render3d/`).

## Preparar el entorno

`bpy 4.2.0` solo existe para Python 3.11: si `python3` es otra versión, usa `python3.11` en todos los comandos.

1. `python3.11 -m pip install bpy==4.2.0 pillow numpy`
2. `python3.11 textures.py` — genera las texturas propias en `tex/` (no hace falta si ya están en el repositorio)
3. `python3 polyhaven.py` — descarga el cielo HDRI y las texturas PBR de Poly Haven (CC0) en `ph/`
   (no se suben al repositorio). Necesita que la red del entorno permita `api.polyhaven.com` y `dl.polyhaven.org`.
   Sin `ph/` la escena funciona igual, con los materiales procedurales anteriores.

## Construir y probar

- `python3 build.py /ruta/villa.blend` — construye la escena (unos 40 s; ~16.000 objetos, casi 7.000 árboles instanciados).
- `UNIKAL_QUICK=1 python3 build.py ...` — escena sin vegetación ni césped, para pruebas rápidas.
- Fotograma de prueba: `python3 render.py /ruta/villa.blend /ruta/salida 288 1920 1080 20 0,129,230`
  - `CAM="x,y,z:tx,ty,tz:focal"` cambia la cámara; `BORDER="xmin,xmax,ymin,ymax"` renderiza solo un recorte.
  - Fotogramas útiles para revisar: 0 (inicio, piscina y fachada), 129 (vista aérea con la casa abierta),
    201 (carretera), 230 (jacuzzi y tarima), 258 (fachada de frente con los interiores).

## Render final

- `ANCHORS_ALL=1 SKIP_DONE=1 python3 render.py /ruta/villa.blend /ruta/final 288 1920 1080 20 0-287 3`
  y después lo mismo con `1-287 3` y `2-287 3` — un fotograma de cada tres en cada pasada, para tener pronto
  una versión completa a menos fotogramas. Con `SKIP_DONE=1` se reanuda si se interrumpe.
- Unos 5,5 minutos por fotograma con 4 núcleos: **~26–28 horas** los 288.
- `python3 build_seq.py /ruta/final` — empaqueta los fotogramas en `assets/seq/` (bloques 1080p, móvil y vista previa).

## Archivos

- `scene.py` — casa, materiales, piscina, jacuzzi, carretera, cubierta, interiores, luces, cámara y render.
- `detalles.py` — cocina exterior (barbacoa, fregadero, puertas y cajones), toallas, mesita con libro y vaso,
  bandeja con jarra y vasos, frutero, macetas con plantas y la estancia de la ventana vertical del volumen blanco.
- `vegetacion.py` — olivos, encinas, pinos piñoneros, cipreses (generados rama a rama), setos, lavanda,
  bosque alrededor (disco de Poisson) y sombrilla de brezo.
- `olas.py` — oleaje de la piscina y del jacuzzi; `render.py` lo aplica en cada fotograma (el agua se mueve al hacer scroll).
- `render.py` — recorrido de la cámara, despiece de la casa, agua, burbujas y anclas de las fichas.

## Estado (pendiente de aprobar antes del render final)

Hecho: agua con cáusticas reales, vegetación mediterránea y bosque frondoso, cielo HDRI, carretera realista,
tarima de tablas reales, fachada con revoco, ventanal con estudio, dormitorio y salón amueblados e iluminados,
cubierta con placas solares, jacuzzi revestido y sombrilla de brezo con mástil de tronco.
Además: cristales con capa reflectante (reflejan cielo y árboles), ventana vertical real en el volumen blanco
con estancia detrás, lajas de piedra natural (Poly Haven), cocina exterior completa y objetos de uso
(toallas, libro, vasos, jarra, limones, macetas).

Ideas pendientes para más realismo (por orden de impacto):
1. Correderas con tiradores, carriles y hojas que se solapan.
2. Algo de desgaste y suciedad: terraza y albardilla de la piscina demasiado limpias, marcas de agua.
3. Seto menos uniforme (huecos y zonas más o menos densas).
4. Remate del césped contra la terraza (bordillo o pletina).
5. Luz algo más soleada y cálida, con más contraste.
6. Bosque con más variedad (claros, caminos), coches y señales en la carretera, más detalle en los montes,
   sumideros y bajantes en la cubierta.
