"""Descarga los recursos de Poly Haven (CC0) que usa la escena: cielo HDRI y texturas PBR.

Uso: python3 polyhaven.py   (deja los archivos en render3d/ph/, que no se sube al repositorio)
Requiere acceso a api.polyhaven.com y dl.polyhaven.org."""
import json, os, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'ph')
UA = {'User-Agent': 'unikal-villa-render/1.0'}

HDRI = ('kloofendal_48d_partly_cloudy_puresky', '8k')   # cielo azul con cúmulos de buen tiempo, sol a 48°
TEXTURES = {   # nombre -> resolución
    'oak_wood_planks': '2k',        # tarima
    'painted_plaster_wall': '2k',   # relieve del revoco blanco
    'tree_bark_03': '2k',           # olivo
    'pine_bark': '2k',              # pino piñonero
    'chinese_cedar_bark': '1k',     # ciprés
    'aerial_grass_rock': '2k',      # campo visto desde lejos
    'grass_ground': '2k',           # base del césped
    'asphalt_02': '2k',             # carretera
    'concrete_pavers': '2k',        # acera
    'asphalt_04': '2k',             # bordillos de hormigón
    'gravel_road': '2k',            # arcén de tierra y grava
    'rough_linen': '2k',            # tela de cojines y colchonetas
    'gravel_floor_02': '2k',        # grava de la cubierta
    'rough_plaster_03': '2k',       # relieve del revoco de la fachada
    'rough_wood': '2k',             # mástil de la sombrilla (madera agrietada)
    'stacked_stone_wall': '2k',     # lajas de piedra del volumen de piedra y de la cocina exterior
}
MAPS = {'Diffuse': 'diff', 'nor_gl': 'nor', 'Rough': 'rough'}
EXTRA = {'stacked_stone_wall': {'AO': 'ao', 'Displacement': 'disp'}}   # oclusión y relieve para la piedra


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r:
        return r.read()


def save(url, path, tries=6):
    """Descarga con reanudación (cabecera Range) si la conexión se corta a mitad."""
    if os.path.exists(path): return
    part = path + '.part'
    for k in range(tries):
        have = os.path.getsize(part) if os.path.exists(part) else 0
        hdr = dict(UA, Range='bytes=%d-' % have) if have else UA
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=hdr), timeout=120) as r:
                total = have + int(r.headers.get('Content-Length', 0))
                with open(part, 'ab' if have and r.status == 206 else 'wb') as fo:
                    while True:
                        b = r.read(1 << 20)
                        if not b: break
                        fo.write(b)
            if os.path.getsize(part) >= total: break
        except Exception as e:
            print('   reintento', k + 1, os.path.basename(path), type(e).__name__)
    os.replace(part, path)
    print('  ', os.path.basename(path), '%.1f MB' % (os.path.getsize(path) / 1e6))


def main():
    os.makedirs(OUT, exist_ok=True)
    name, res = HDRI
    f = json.loads(get('https://api.polyhaven.com/files/' + name))
    save(f['hdri'][res]['hdr']['url'], os.path.join(OUT, 'sky_%s.hdr' % name))
    for name, res in TEXTURES.items():
        f = json.loads(get('https://api.polyhaven.com/files/' + name))
        for key, short in dict(MAPS, **EXTRA.get(name, {})).items():
            if key in f:
                save(f[key][res]['jpg']['url'], os.path.join(OUT, '%s_%s.jpg' % (name, short)))
    print('Poly Haven: listo en', OUT)


if __name__ == '__main__':
    main()
