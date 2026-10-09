# Render 3D de la villa

La animación del inicio de la web es una secuencia de 288 imágenes Full HD renderizadas con Blender (Cycles).
Estos scripts regeneran la escena y los fotogramas.

1. `pip install bpy==4.2.0 pillow numpy`
2. `python3 textures.py` — genera las texturas en `tex/`
3. `python3 build.py /ruta/villa.blend` — construye la escena (ejecutar desde esta carpeta)
4. `ANCHORS_ALL=1 SKIP_DONE=1 python3 render.py /ruta/villa.blend /ruta/final 288 1920 1080 14 0-287 3`
   y después lo mismo con `1-287 3` y `2-287 3` — renderiza un fotograma de cada tres en cada pasada
   (con `SKIP_DONE=1` se puede reanudar si se interrumpe). Unos 2 minutos por fotograma con 4 núcleos.
5. `python3 build_seq.py /ruta/final` — empaqueta los fotogramas en `assets/seq/` (bloques 1080p, móvil y vista previa)
