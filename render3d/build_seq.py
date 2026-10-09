"""Empaqueta los fotogramas renderizados (PNG 1920x1080) para la web.

Uso: python3 build_seq.py <carpeta_png> [carpeta_cache]

Genera en assets/seq/:
  d/cNN.webp   bloques de 12 fotogramas a 1920x1080 (escritorio)
  m/cNN.webp   bloques de 12 fotogramas a 960x540 (móvil)
  p.webp       vista previa ligera de todos los fotogramas (480x270)
  poster-d.webp, poster-m.webp   primer fotograma, visible mientras carga
  manifest.json  posición de cada fotograma dentro de su bloque y anclas de las fichas
Cada bloque es la concatenación de varios WebP; la web los separa con los desplazamientos del manifiesto.
"""
import json, os, sys, shutil
from PIL import Image, ImageEnhance

SRC = sys.argv[1] if len(sys.argv) > 1 else 'final'
CACHE = sys.argv[2] if len(sys.argv) > 2 else os.path.join(SRC, '_web')
DST = os.environ.get('UNIKAL_SEQ_DST') or os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'seq'))
CH = 12
TIERS = {'d': (1920, 1080, 72), 'm': (960, 540, 70), 'p': (480, 270, 50)}

anchors = json.load(open(os.path.join(SRC, 'anchors.json')))
N = len(anchors)
for t in TIERS: os.makedirs(os.path.join(CACHE, t), exist_ok=True)

have = []
for i in range(N):
    src = os.path.join(SRC, 'f%03d.png' % i)
    if not os.path.exists(src): continue
    have.append(i)
    outs = {t: os.path.join(CACHE, t, 'f%03d.webp' % i) for t in TIERS}
    if all(os.path.exists(o) and os.path.getmtime(o) >= os.path.getmtime(src) for o in outs.values()): continue
    im = Image.open(src).convert('RGB')
    for t, (w, h, q) in TIERS.items():
        x = im if im.size == (w, h) else im.resize((w, h), Image.LANCZOS)
        if t != 'p': x = ImageEnhance.Sharpness(x).enhance(1.08)
        x.save(outs[t], quality=q, method=5)

# Limpia la salida anterior (fotogramas sueltos o bloques viejos)
for t in ('d', 'm'):
    d = os.path.join(DST, t)
    if os.path.isdir(d): shutil.rmtree(d)
    os.makedirs(d)

man = {'n': N, 'ch': CH, 'have': have, 'd': [None] * N, 'm': [None] * N, 'p': [None] * N, 'anchors': anchors}
sizes = {}
for t in ('d', 'm'):
    tot = 0
    for c in range((N + CH - 1) // CH):
        data = bytearray()
        for i in range(c * CH, min(N, (c + 1) * CH)):
            f = os.path.join(CACHE, t, 'f%03d.webp' % i)
            if i in have and os.path.exists(f):
                b = open(f, 'rb').read(); man[t][i] = [len(data), len(b)]; data += b
        if data:
            open(os.path.join(DST, t, 'c%02d.webp' % c), 'wb').write(data); tot += len(data)
    sizes[t] = tot
data = bytearray()
for i in have:
    b = open(os.path.join(CACHE, 'p', 'f%03d.webp' % i), 'rb').read(); man['p'][i] = [len(data), len(b)]; data += b
open(os.path.join(DST, 'p.webp'), 'wb').write(data); sizes['p'] = len(data)
if 0 in have:
    shutil.copy(os.path.join(CACHE, 'd', 'f000.webp'), os.path.join(DST, 'poster-d.webp'))
    shutil.copy(os.path.join(CACHE, 'm', 'f000.webp'), os.path.join(DST, 'poster-m.webp'))
json.dump(man, open(os.path.join(DST, 'manifest.json'), 'w'), separators=(',', ':'))
print('fotogramas %d/%d' % (len(have), N), ' '.join('%s %.1f MB' % (k, v / 1e6) for k, v in sizes.items()))
