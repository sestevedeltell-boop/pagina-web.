"""Uso: python3 render.py <blend> <outdir> <N> <W> <H> <samples> <frames: 'all' | '0,10,20' | 'a-b'> [step]"""
import bpy, sys, math, json, os, time
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
    bpy.data.materials['pipe'].node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value = 6 * s['pipe']
    bpy.data.materials['led'].node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value = 12 * s['pool']
    # hierba: menos briznas hijas cuando la cámara está alta (a distancia no se nota)
    sc.render.use_simplify = True
    sc.render.simplify_child_particles_render = 1.0 if s['cam'].z < 9 else .25
    bpy.data.lights['poollight'].energy = 450 * s['pool']
    w = i * .035
    for mname, nname in (('water', 'WAVE'), ('water', 'WAVE2'), ('spawater', 'WAVE'), ('spawater', 'WAVE2'), ('spawater', 'FOAM')):
        bpy.data.materials[mname].node_tree.nodes[nname].inputs['W'].default_value = w * (3 if mname == 'spawater' else 1)
    bpy.data.materials['spawater'].node_tree.nodes['FOAMAMT'].inputs[1].default_value = .35 + .5 * s['boil']
    bpy.data.materials['pooltile'].node_tree.nodes['CAUS'].inputs['W'].default_value = w * .6
    return s

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
