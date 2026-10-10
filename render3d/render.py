"""Uso: python3 render.py <blend> <outdir> <N> <W> <H> <samples> <frames: 'all' | '0,10,20' | 'a-b'> [step]"""
import bpy, bmesh, sys, math, json, os, time
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import olas
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

blend, outdir, N, W, H, SAMP, which = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6]), sys.argv[7]
step = int(sys.argv[8]) if len(sys.argv) > 8 else 1
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene; ob = bpy.data.objects
os.makedirs(outdir, exist_ok=True)

def clamp(v, a, b): return min(b, max(a, v))
def lerp(a, b, t): return a + (b - a) * t
def ss(a, b, x):
    t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

# Fotogramas clave de cámara: (p, posición, objetivo, focal)
KEYS = [
    (0.00, (12.5, -12.6, 2.1), (-2.5, 1.0, 3.0), 22),
    (0.10, (17.0, -25.0, 7.5), (-2.0, 1.5, 3.4), 24),
    (0.30, (8.0, -47.0, 24.0), (-2.0, 2.0, 4.8), 28),
    (0.45, (-13.0, -47.0, 23.0), (-2.0, 2.0, 5.6), 28),
    (0.58, (-31.0, -34.0, 18.0), (-2.0, 2.0, 5.0), 28),
    (0.70, (-19.0, -21.0, 6.5), (0.0, -5.0, 1.2), 26),
    (0.80, (-11.0, -13.0, 1.8), (0.0, -4.5, 1.4), 24),
    (0.90, (-4.0, -26.0, 9.0), (-1.5, 1.5, 2.8), 26),
    (1.00, (-21.0, -37.0, 12.0), (-1.5, 1.5, 2.6), 26),
]
def catmull(p0, p1, p2, p3, t):
    t2, t3 = t * t, t * t * t
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
def path(p, idx):
    ks = KEYS; n = len(ks)
    for k in range(n - 1):
        if ks[k][0] <= p <= ks[k + 1][0]: break
    t = (p - ks[k][0]) / (ks[k + 1][0] - ks[k][0]); t = t * t * (3 - 2 * t) * .35 + t * .65
    get = lambda j: Vector(ks[max(0, min(n - 1, j))][idx]) if idx < 3 else ks[max(0, min(n - 1, j))][idx]
    if idx == 3: return lerp(get(k), get(k + 1), t)
    return catmull(get(k - 1), get(k), get(k + 1), get(k + 2), t)

def state(p):
    e = ss(.12, .32, p) - ss(.58, .72, p)
    return dict(e=e, cam=path(p, 1), tgt=path(p, 2), lens=path(p, 3),
                pipe=ss(.30, .40, p) * (1 - ss(.56, .64, p)), pool=ss(.60, .72, p), boil=ss(.64, .74, p))

def apply(p, i):
    s = state(p)
    ob['ROOF'].location.z = 7.0 * s['e']; ob['ROOF'].rotation_euler.y = .03 * s['e']
    ob['UPPER'].location.z = 3.9 * s['e']; ob['WALLS'].location.z = 3.6 * s['e']
    ob['cam'].location = s['cam']; ob['target'].location = s['tgt']; ob['cam'].data.lens = s['lens']
    if os.environ.get('CAM'):   # pruebas: CAM="x,y,z:tx,ty,tz:focal"
        c_, t_, f_ = os.environ['CAM'].split(':')
        ob['cam'].location = [float(v) for v in c_.split(',')]; ob['target'].location = [float(v) for v in t_.split(',')]; ob['cam'].data.lens = float(f_)
    bpy.data.materials['pipe'].node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value = 6 * s['pipe']
    bpy.data.materials['led'].node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value = 12 * s['pool']
    # hierba: menos briznas hijas cuando la cámara está alta (a distancia no se nota)
    # (solo si cambia: tocarlo en cada fotograma obliga a regenerar toda la hierba)
    ch = 1.0 if s['cam'].z < 9 else .25
    if not sc.render.use_simplify: sc.render.use_simplify = True
    if abs(sc.render.simplify_child_particles_render - ch) > 1e-6: sc.render.simplify_child_particles_render = ch
    bpy.data.lights['poollight'].energy = 450 * s['pool']
    t = i * .03   # segundos de "tiempo del agua" por fotograma
    update_water(t, s['boil'])
    return s

# ---------------- agua: olas reales en la rejilla de la superficie, burbujas y espuma del jacuzzi
JX, JY = -6.4, -7.2
JETS = [(JX + 1.0 * math.cos(math.radians(30 + 60 * k)), JY + 1.0 * math.sin(math.radians(30 + 60 * k))) for k in range(6)]
WATER = {}
for name in ('water', 'spawater'):
    if name in ob:
        me = ob[name].data; co = np.empty(len(me.vertices) * 3); me.vertices.foreach_get('co', co)
        WATER[name] = co.reshape(-1, 3)
def _ico():
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    V = np.array([v.co[:] for v in bm.verts]); F = np.array([[v.index for v in f.verts] for f in bm.faces]); bm.free(); return V, F
ICO_V, ICO_F = _ico()
BR = np.random.default_rng(17); NB = 1400
B_JET = BR.integers(0, 7, NB)                     # 6 boquillas + centro
B_DIR = BR.uniform(-.7, .7, NB); B_SPD = BR.uniform(.18, .42, NB); B_LIFE = BR.uniform(1.0, 2.6, NB)
B_OFF = BR.uniform(0, 3, NB); B_R = np.exp(BR.uniform(np.log(.0025), np.log(.011), NB)); B_FOAM = BR.random(NB) < .35
def update_water(t, boil):
    for name, co in WATER.items():
        x, y = co[:, 0], co[:, 1]
        h = olas.waves(x, y, t, olas.POOL) if name == 'water' else olas.spa_height(x, y, t, JX, JY, boil, JETS)
        new = co.copy(); new[:, 2] = ob[name]['wave_z'] + h
        ob[name].data.vertices.foreach_set('co', new.ravel()); ob[name].data.update()
    fo = ob.get('spafoam')
    if fo is None: return
    me = fo.data
    n = int(NB * boil)
    if n == 0:
        me.clear_geometry(); return
    age = (t + B_OFF[:n]) % B_LIFE[:n]
    jet = B_JET[:n]
    jx = np.array([p[0] for p in JETS] + [JX])[jet]; jy = np.array([p[1] for p in JETS] + [JY])[jet]
    base = np.arctan2(JY - jy, JX - jx)
    ang = np.where(jet == 6, B_DIR[:n] * 4.5, base + B_DIR[:n])
    d = B_SPD[:n] * age
    px, py = jx + np.cos(ang) * d, jy + np.sin(ang) * d
    ok = np.hypot(px - JX, py - JY) < 1.16
    life = 1 - age / B_LIFE[:n]
    r = B_R[:n] * np.where(B_FOAM[:n], 1.6, 1.0) * (.55 + .45 * life)
    px, py, r, foam = px[ok], py[ok], r[ok], B_FOAM[:n][ok]
    pz = ob['spawater']['wave_z'] + olas.spa_height(px, py, t, JX, JY, boil, JETS)
    sz = np.where(foam, .45, .8)
    V = (ICO_V[None] * np.stack([r, r, r * sz], 1)[:, None, :] + np.stack([px, py, pz + r * sz * .25], 1)[:, None, :]).reshape(-1, 3)
    F = (ICO_F[None] + (np.arange(len(px)) * len(ICO_V))[:, None, None]).reshape(-1, 3)
    me.clear_geometry(); me.from_pydata(V.tolist(), [], F.tolist()); me.update()
    me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))

r = sc.render; r.resolution_x, r.resolution_y, r.resolution_percentage = W, H, 100
sc.cycles.samples = SAMP
if which == 'all': frames = list(range(0, N, step))
elif '-' in which: a, b = which.split('-'); frames = list(range(int(a), int(b) + 1, step))
else: frames = [int(x) for x in which.split(',')]
anchors_path = os.path.join(outdir, 'anchors.json')
anchors = json.load(open(anchors_path)) if os.path.exists(anchors_path) else {}
def anchor_frame(i):
    apply(i / (N - 1), i); bpy.context.view_layer.update(); a = {}
    for o in ob:
        if o.name.startswith('A_'):
            v = world_to_camera_view(sc, ob['cam'], o.matrix_world.translation)
            a[o.name[2:]] = [round(v.x, 4), round(1 - v.y, 4), 1 if v.z > 0 else 0]
    return a
if os.environ.get('ANCHORS_ALL'):
    for k in range(N): anchors[str(k)] = anchor_frame(k)
    json.dump(anchors, open(anchors_path, 'w'))
for i in frames:
    out = os.path.join(outdir, 'f%03d.png' % i)
    if os.path.exists(out) and os.environ.get('SKIP_DONE'): continue
    p = i / (N - 1); apply(p, i)
    bpy.context.view_layer.update()
    a = {}
    for o in ob:
        if o.name.startswith('A_'):
            v = world_to_camera_view(sc, ob['cam'], o.matrix_world.translation)
            a[o.name[2:]] = [round(v.x, 4), round(1 - v.y, 4), 1 if v.z > 0 else 0]
    anchors[str(i)] = a
    t0 = time.time(); r.filepath = out; bpy.ops.render.render(write_still=True)
    print('FRAME', i, 'p=%.3f' % p, '%.1fs' % (time.time() - t0), flush=True)
    json.dump(anchors, open(anchors_path, 'w'))
