# Render 3D de la villa

La animación del inicio de la web es una secuencia de imágenes renderizadas con Blender (Cycles).
Estos scripts regeneran la escena y los fotogramas.

1. `pip install bpy==4.2.0 pillow numpy`
2. `python3 textures.py` — genera las texturas en `tex/`
3. `python3 build.py` — construye la escena y guarda `villa.blend`
4. `ANCHORS_ALL=1 python3 render.py villa.blend final 96 1280 720 24 all` — renderiza los 96 fotogramas
5. `python3 build_seq.py final/` — convierte a WebP en `assets/seq/` y crea `manifest.json`
