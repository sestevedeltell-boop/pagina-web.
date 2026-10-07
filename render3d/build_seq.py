"""Convierte los PNG renderizados en la secuencia web (WebP escritorio + móvil) y el manifiesto."""
import json, os, sys
from PIL import Image, ImageEnhance
SRC = sys.argv[1] if len(sys.argv) > 1 else 'final/'
DST = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'seq') + '/'
N = 96
os.makedirs(DST + 'd', exist_ok=True); os.makedirs(DST + 'm', exist_ok=True)
anchors = json.load(open(SRC + 'anchors.json'))
done = 0
for i in range(N):
    src = SRC + 'f%03d.png' % i
    if not os.path.exists(src): continue
    d, m = DST + 'd/f%03d.webp' % i, DST + 'm/f%03d.webp' % i
    if os.path.exists(d) and os.path.getmtime(d) > os.path.getmtime(src): done += 1; continue
    im = Image.open(src).convert('RGB')
    im = ImageEnhance.Sharpness(im).enhance(1.12)
    im.save(d, quality=76, method=5)
    im.resize((854, 480), Image.LANCZOS).save(m, quality=72, method=5)
    done += 1
json.dump({'n': N, 'anchors': {k: v for k, v in anchors.items()}}, open(DST + 'manifest.json', 'w'), separators=(',', ':'))
tot = sum(os.path.getsize(DST + 'd/' + f) for f in os.listdir(DST + 'd'))
totm = sum(os.path.getsize(DST + 'm/' + f) for f in os.listdir(DST + 'm'))
print('frames', done, 'desktop MB %.1f' % (tot / 1e6), 'mobile MB %.1f' % (totm / 1e6))
