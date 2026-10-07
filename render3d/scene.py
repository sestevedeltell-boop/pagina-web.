"""Villa UNIKAL en Blender/Cycles (pip install bpy==4.2.0). Ejecutar desde render3d/: python3 build.py
 Coordenadas: X derecha, Y hacia el fondo, Z arriba. Fachada principal mira a -Y."""
import bpy, bmesh, math, random, os
from mathutils import Vector, Matrix, Euler

TEX = os.environ.get('UNIKAL_TEX', os.path.join(os.getcwd(), 'tex')) + '/'
R = random.Random(7)
def rr(a, b): return R.uniform(a, b)
def lin(h):
    c = [((h >> s) & 255) / 255 for s in (16, 8, 0)]
    return tuple((v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in c) + (1.0,)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
COL = sc.collection

# ------------------------------------------------------------------ materiales
def newmat(name):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    return m, nt, b
def node(nt, t, **kw):
    n = nt.nodes.new(t)
    for k, v in kw.items(): setattr(n, k, v)
    return n
def L(nt, a, b): nt.links.new(a, b)
def objcoord(nt, scale=1.0):
    tc = node(nt, 'ShaderNodeTexCoord'); mp = node(nt, 'ShaderNodeMapping')
    mp.inputs['Scale'].default_value = (1 / scale,) * 3
    L(nt, tc.outputs['Object'], mp.inputs['Vector']); return mp.outputs[0]
def img(nt, vec, name, noncolor=False):
    n = node(nt, 'ShaderNodeTexImage'); n.image = bpy.data.images.load(TEX + name, check_existing=True)
    n.projection = 'BOX'; n.projection_blend = .2
    if noncolor: n.image.colorspace_settings.name = 'Non-Color'
    L(nt, vec, n.inputs['Vector']); return n
def bump(nt, height, strength=.2, dist=.02, normal=None):
    b = node(nt, 'ShaderNodeBump'); b.inputs['Strength'].default_value = strength; b.inputs['Distance'].default_value = dist
    L(nt, height, b.inputs['Height'])
    if normal is not None: L(nt, normal, b.inputs['Normal'])
    return b.outputs[0]
def noise(nt, vec, scale, detail=4, rough=.55, w=None):
    n = node(nt, 'ShaderNodeTexNoise'); n.inputs['Scale'].default_value = scale; n.inputs['Detail'].default_value = detail
    n.inputs['Roughness'].default_value = rough
    if w is not None: n.noise_dimensions = '4D'; n.inputs['W'].default_value = w
    if vec is not None: L(nt, vec, n.inputs['Vector'])
    return n
def mix(nt, fac, a, b, blend='MIX'):
    m = node(nt, 'ShaderNodeMixRGB'); m.blend_type = blend
    for i, v in ((0, fac), (1, a), (2, b)):
        if isinstance(v, (float, int)): m.inputs[i].default_value = v
        elif isinstance(v, tuple): m.inputs[i].default_value = v
        else: L(nt, v, m.inputs[i])
    return m.outputs[0]
def ramp(nt, inp, stops):
    r = node(nt, 'ShaderNodeValToRGB'); el = r.color_ramp.elements
    el[0].position, el[0].color = stops[0]; el[1].position, el[1].color = stops[-1]
    for pos, c in stops[1:-1]:
        e = el.new(pos); e.color = c
    L(nt, inp, r.inputs[0]); return r.outputs[0]

M = {}
def simple(name, color, rough=.5, metal=0., spec=.5, coat=0.):
    m, nt, b = newmat(name)
    b.inputs['Base Color'].default_value = lin(color) if isinstance(color, int) else color
    b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    b.inputs['Specular IOR Level'].default_value = spec; b.inputs['Coat Weight'].default_value = coat
    M[name] = m; return m, nt, b

# Revoco blanco con leve variación y relieve
m, nt, b = newmat('render'); M['render'] = m
v = objcoord(nt); n1 = noise(nt, v, 1.2, 3); n2 = noise(nt, v, 60, 2)
col = mix(nt, n1.outputs['Fac'], lin(0xe4e2dc), lin(0xf2f1ec))
L(nt, col, b.inputs['Base Color']); b.inputs['Roughness'].default_value = .88
L(nt, bump(nt, n2.outputs['Fac'], .06, .01), b.inputs['Normal'])
# Piedra en lajas
m, nt, b = newmat('stone'); M['stone'] = m
v = objcoord(nt, 3.0); t = img(nt, v, 'stone.jpg'); tn = img(nt, v, 'stone.jpg', True)
L(nt, mix(nt, .15, t.outputs[0], lin(0xb8ab94), 'MULTIPLY'), b.inputs['Base Color'])
b.inputs['Roughness'].default_value = .92; L(nt, bump(nt, tn.outputs[0], .5, .02), b.inputs['Normal'])
# Porcelánico exterior
m, nt, b = newmat('tile'); M['tile'] = m
v = objcoord(nt, 2.4); t = img(nt, v, 'tile.jpg'); L(nt, t.outputs[0], b.inputs['Base Color'])
b.inputs['Roughness'].default_value = .38; L(nt, bump(nt, img(nt, v, 'tile.jpg', True).outputs[0], .15, .005), b.inputs['Normal'])
# Tarima de ipe
m, nt, b = newmat('wood'); M['wood'] = m
v = objcoord(nt, 1.12); t = img(nt, v, 'wood.jpg'); r = img(nt, v, 'wood_r.jpg', True)
wc0 = mix(nt, .5, t.outputs[0], lin(0x7a5638), 'MULTIPLY'); hs = node(nt, 'ShaderNodeHueSaturation'); hs.inputs['Saturation'].default_value = .72; hs.inputs['Hue'].default_value = .51; L(nt, wc0, hs.inputs['Color']); wc = hs.outputs[0]; bc = node(nt, 'ShaderNodeBrightContrast'); bc.inputs['Contrast'].default_value = .35; L(nt, wc, bc.inputs['Color']); L(nt, bc.outputs[0], b.inputs['Base Color'])
L(nt, r.outputs[0], b.inputs['Roughness']); L(nt, bump(nt, img(nt, v, 'wood.jpg', True).outputs[0], .35, .01), b.inputs['Normal'])
b.inputs['Coat Weight'].default_value = .15; b.inputs['Coat Roughness'].default_value = .2
# Gresite de piscina con cáusticas falsas (animadas por W)
m, nt, b = newmat('pooltile'); M['pooltile'] = m
v = objcoord(nt, 1.6); t = img(nt, v, 'pooltile.jpg'); L(nt, t.outputs[0], b.inputs['Base Color'])
b.inputs['Roughness'].default_value = .15
tc = node(nt, 'ShaderNodeTexCoord'); vor = node(nt, 'ShaderNodeTexVoronoi'); vor.voronoi_dimensions = '4D'; vor.feature = 'DISTANCE_TO_EDGE'
vor.inputs['Scale'].default_value = 2.2; L(nt, tc.outputs['Object'], vor.inputs['Vector']); vor.name = 'CAUS'
cr = ramp(nt, vor.outputs['Distance'], [(0.0, (1, 1, 1, 1)), (0.06, (0, 0, 0, 1))])
L(nt, cr, b.inputs['Emission Color']); b.inputs['Emission Strength'].default_value = .5
# Césped con franjas de corte
m, nt, b = newmat('lawn'); M['lawn'] = m
tc = node(nt, 'ShaderNodeTexCoord'); v = tc.outputs['Object']
n1 = noise(nt, v, .35, 5); n2 = noise(nt, v, 4, 3); n3 = noise(nt, v, 250, 2)
wv = node(nt, 'ShaderNodeTexWave'); wv.wave_type = 'BANDS'; wv.bands_direction = 'X'; wv.wave_profile = 'SAW'
wv.inputs['Scale'].default_value = .4; wv.inputs['Distortion'].default_value = 0; L(nt, v, wv.inputs['Vector'])
stripe = node(nt, 'ShaderNodeMath'); stripe.operation = 'GREATER_THAN'; stripe.inputs[1].default_value = .5; L(nt, wv.outputs['Fac'], stripe.inputs[0])
base = ramp(nt, n1.outputs['Fac'], [(0.3, lin(0x3d6b22)), (0.55, lin(0x4f8a2c)), (0.75, lin(0x6a9a3a))])
c = mix(nt, n2.outputs['Fac'], base, lin(0x5e8e30), 'MIX')
c = mix(nt, .5, c, lin(0x4a7d26), 'MIX')
c2 = mix(nt, stripe.outputs[0], c, (0.9, 0.95, 0.85, 1), 'MULTIPLY')
c3 = mix(nt, n3.outputs['Fac'], c2, lin(0x2c4a17), 'MIX')
fin = mix(nt, .3, c2, c3, 'MIX'); L(nt, fin, b.inputs['Base Color'])
b.inputs['Roughness'].default_value = .95; b.inputs['Specular IOR Level'].default_value = .3
L(nt, bump(nt, n3.outputs['Fac'], .9, .02), b.inputs['Normal'])
# Terreno seco exterior con perspectiva aérea
def haze(nt, colsock, b, k=900.):
    cam = node(nt, 'ShaderNodeCameraData'); mr = node(nt, 'ShaderNodeMath'); mr.operation = 'DIVIDE'; mr.inputs[1].default_value = k
    L(nt, cam.outputs['View Distance'], mr.inputs[0])
    ex = node(nt, 'ShaderNodeMath'); ex.operation = 'MULTIPLY'; ex.inputs[1].default_value = -1; L(nt, mr.outputs[0], ex.inputs[0])
    e2 = node(nt, 'ShaderNodeMath'); e2.operation = 'EXPONENT'; L(nt, ex.outputs[0], e2.inputs[0])
    inv = node(nt, 'ShaderNodeMath'); inv.operation = 'SUBTRACT'; inv.inputs[0].default_value = 1; L(nt, e2.outputs[0], inv.inputs[1])
    out = mix(nt, inv.outputs[0], colsock, lin(0xb9c7d2), 'MIX'); L(nt, out, b.inputs['Base Color'])
    em = node(nt, 'ShaderNodeMath'); em.operation = 'MULTIPLY'; em.inputs[1].default_value = .9; L(nt, inv.outputs[0], em.inputs[0])
    L(nt, out, b.inputs['Emission Color']); L(nt, em.outputs[0], b.inputs['Emission Strength'])
m, nt, b = newmat('land'); M['land'] = m
tc = node(nt, 'ShaderNodeTexCoord'); v = tc.outputs['Object']
n1 = noise(nt, v, .05, 6); n2 = noise(nt, v, .8, 4); n3 = noise(nt, v, 30, 2)
c = ramp(nt, n1.outputs['Fac'], [(0.35, lin(0x4f5230)), (0.48, lin(0x655c38)), (0.6, lin(0x46532a)), (0.72, lin(0x3a4a22))])
c = mix(nt, n2.outputs['Fac'], c, lin(0x585636), 'MIX')
haze(nt, c, b, 1400.); b.inputs['Roughness'].default_value = 1
L(nt, bump(nt, n3.outputs['Fac'], .5, .05), b.inputs['Normal'])
m, nt, b = newmat('hills'); M['hills'] = m
tc = node(nt, 'ShaderNodeTexCoord'); n1 = noise(nt, tc.outputs['Object'], .01, 5)
c = ramp(nt, n1.outputs['Fac'], [(0.4, lin(0x6f6a4a)), (0.6, lin(0x5d6440))]); haze(nt, c, b, 700.)
b.inputs['Roughness'].default_value = 1
# Vidrio (deja pasar la luz para sombras: interiores iluminados)
def glassmat(name, tint=0xf2f6f5, rough=0.):
    m, nt, b = newmat(name); M[name] = m
    b.inputs['Base Color'].default_value = lin(tint); b.inputs['Transmission Weight'].default_value = 1
    b.inputs['Roughness'].default_value = rough; b.inputs['IOR'].default_value = 1.45
    lp = node(nt, 'ShaderNodeLightPath'); tr = node(nt, 'ShaderNodeBsdfTransparent'); tr.inputs[0].default_value = lin(0xe8efed)
    mx = node(nt, 'ShaderNodeMixShader'); out = nt.nodes['Material Output']
    L(nt, lp.outputs['Is Shadow Ray'], mx.inputs[0]); L(nt, b.outputs[0], mx.inputs[1]); L(nt, tr.outputs[0], mx.inputs[2]); L(nt, mx.outputs[0], out.inputs['Surface'])
glassmat('glass')
# Agua de piscina (volumen con absorción, oleaje animado por W)
def watermat(name, absorb, dens, wave_scale, foam=False):
    m, nt, b = newmat(name); M[name] = m
    b.inputs['Base Color'].default_value = (1, 1, 1, 1); b.inputs['Transmission Weight'].default_value = 1
    b.inputs['Roughness'].default_value = .0; b.inputs['IOR'].default_value = 1.333
    tc = node(nt, 'ShaderNodeTexCoord'); n = noise(nt, tc.outputs['Object'], wave_scale, 3, .5, w=0.); n.name = 'WAVE'
    n2 = noise(nt, tc.outputs['Object'], wave_scale * 3.1, 2, .5, w=0.); n2.name = 'WAVE2'
    ad = node(nt, 'ShaderNodeMath'); ad.operation = 'ADD'; L(nt, n.outputs['Fac'], ad.inputs[0]); L(nt, n2.outputs['Fac'], ad.inputs[1])
    L(nt, bump(nt, ad.outputs[0], .25, .02), b.inputs['Normal'])
    out = nt.nodes['Material Output']
    lp = node(nt, 'ShaderNodeLightPath'); tr = node(nt, 'ShaderNodeBsdfTransparent')
    mx = node(nt, 'ShaderNodeMixShader'); L(nt, lp.outputs['Is Shadow Ray'], mx.inputs[0]); L(nt, b.outputs[0], mx.inputs[1]); L(nt, tr.outputs[0], mx.inputs[2])
    surf = mx.outputs[0]
    if foam:
        fn = noise(nt, tc.outputs['Object'], 9, 6, .7, w=0.); fn.name = 'FOAM'
        fm = ramp(nt, fn.outputs['Fac'], [(0.5, (0, 0, 0, 1)), (0.62, (1, 1, 1, 1))]); fm_n = node(nt, 'ShaderNodeMath'); fm_n.name = 'FOAMAMT'
        fm_n.operation = 'MULTIPLY'; fm_n.inputs[1].default_value = .6; L(nt, fm, fm_n.inputs[0])
        fb = node(nt, 'ShaderNodeBsdfPrincipled'); fb.inputs['Base Color'].default_value = (.95, .97, .97, 1); fb.inputs['Roughness'].default_value = .6
        mx2 = node(nt, 'ShaderNodeMixShader'); L(nt, fm_n.outputs[0], mx2.inputs[0]); L(nt, surf, mx2.inputs[1]); L(nt, fb.outputs[0], mx2.inputs[2]); surf = mx2.outputs[0]
    L(nt, surf, out.inputs['Surface'])
    va = node(nt, 'ShaderNodeVolumeAbsorption'); va.inputs['Color'].default_value = lin(absorb); va.inputs['Density'].default_value = dens
    L(nt, va.outputs[0], out.inputs['Volume'])
watermat('water', 0x4fd6e0, .55, 1.6)
watermat('spawater', 0x5ad9e3, .8, 3.0, foam=True)
# Metales, telas y maderas
simple('alu', 0x2a2b2d, .35, .9)
simple('steel', 0xc9ccd0, .18, 1.)
simple('black', 0x0e0e0f, .4)
simple('fabric', 0x8e8a84, .95, spec=.2)
simple('fabriclight', 0xe7e2d8, .95, spec=.2)
simple('blue', 0x6f8fbf, .95, spec=.2)
simple('rug', 0xc9bfae, 1., spec=.1)
simple('darkwood', 0x3e2b1f, .45, coat=.2)
simple('oak', 0xb8875a, .4, coat=.3)
simple('marble', 0x1b4436, .08, coat=.6)
simple('lacquer', 0xf1efe9, .25, coat=.4)
simple('pink', 0xc7a19d, .95, spec=.2)
simple('canvas', 0xe6ddcc, .9, spec=.2)
simple('panel', 0x10203e, .12, .3, coat=1.)
simple('gravelroof', 0xb3ada3, 1.)
simple('trunk', 0x8a7a64, .95)
simple('olivetrunk', 0x5e5446, .95)
simple('soil', 0x4a3a2a, 1.)
simple('concrete', 0xbdb6aa, .8)
simple('tv', 0x050505, .15, coat=1.)
def emis(name, color, strength):
    m, nt, b = simple(name, color, .5)
    b.inputs['Emission Color'].default_value = lin(color); b.inputs['Emission Strength'].default_value = strength; return m
emis('lamp', 0xffd8a6, 25.); emis('downlight', 0xfff0d8, 30.); emis('led', 0x9ff6ff, 0.); emis('pipe', 0xff5a1a, 0.)
# Hojas con color por hoja y translucidez
def leafmat(name, sheen=.2):
    m, nt, b = newmat(name); M[name] = m
    ca = node(nt, 'ShaderNodeVertexColor'); ca.layer_name = 'col'
    L(nt, ca.outputs['Color'], b.inputs['Base Color']); b.inputs['Roughness'].default_value = .55
    b.inputs['Specular IOR Level'].default_value = .45
    tl = node(nt, 'ShaderNodeBsdfTranslucent'); L(nt, ca.outputs['Color'], tl.inputs['Color'])
    mx = node(nt, 'ShaderNodeMixShader'); mx.inputs[0].default_value = .35
    L(nt, b.outputs[0], mx.inputs[1]); L(nt, tl.outputs[0], mx.inputs[2]); L(nt, mx.outputs[0], nt.nodes['Material Output'].inputs['Surface'])
    return m
leafmat('leaf')
for k in M.values(): k.blend_method = 'OPAQUE'

# ------------------------------------------------------------------ geometría
class MB:
    def __init__(s, colors=False):
        s.bm = bmesh.new(); s.col = s.bm.loops.layers.color.new('col') if colors else None
    def poly(s, pts, color=None):
        vs = [s.bm.verts.new(p) for p in pts]; f = s.bm.faces.new(vs)
        if s.col is not None and color is not None:
            for lo in f.loops: lo[s.col] = color
        return f
    def box(s, x0, x1, y0, y1, z0, z1):
        P = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        vs = [s.bm.verts.new(p) for p in P]
        for q in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)): s.bm.faces.new([vs[i] for i in q])
    def cbox(s, cx, cy, cz, w, d, h): s.box(cx - w / 2, cx + w / 2, cy - d / 2, cy + d / 2, cz - h / 2, cz + h / 2)
    def cyl(s, cx, cy, z0, z1, r, n=24, cap=True, r2=None):
        r2 = r if r2 is None else r2
        bot = [s.bm.verts.new((cx + r * math.cos(a), cy + r * math.sin(a), z0)) for a in [i / n * 2 * math.pi for i in range(n)]]
        top = [s.bm.verts.new((cx + r2 * math.cos(a), cy + r2 * math.sin(a), z1)) for a in [i / n * 2 * math.pi for i in range(n)]]
        for i in range(n): s.bm.faces.new((bot[i], bot[(i + 1) % n], top[(i + 1) % n], top[i]))
        if cap: s.bm.faces.new(top); s.bm.faces.new(list(reversed(bot)))
    def obj(s, name, mat, bevel=0., parent=None, smooth=False, recalc=True):
        if recalc: bmesh.ops.recalc_face_normals(s.bm, faces=s.bm.faces)
        me = bpy.data.meshes.new(name); s.bm.to_mesh(me); s.bm.free()
        if smooth:
            for p in me.polygons: p.use_smooth = True
        ob = bpy.data.objects.new(name, me); COL.objects.link(ob); me.materials.append(M[mat])
        if bevel:
            md = ob.modifiers.new('bev', 'BEVEL'); md.width = bevel; md.segments = 2; md.limit_method = 'ANGLE'; md.use_clamp_overlap = True
        if parent: ob.parent = parent
        return ob

def empty(name):
    e = bpy.data.objects.new(name, None); COL.objects.link(e); return e
G_ROOF, G_UPPER, G_WALLS, G_BASE = empty('ROOF'), empty('UPPER'), empty('WALLS'), empty('BASE')

# --- terreno y parcela
def rect_hole(mb, outer, hole, z):
    x0, x1, y0, y1 = outer; hx0, hx1, hy0, hy1 = hole
    for a in ((x0, x1, y0, hy0), (x0, x1, hy1, y1), (x0, hx0, hy0, hy1), (hx1, x1, hy0, hy1)):
        mb.poly([(a[0], a[2], z), (a[1], a[2], z), (a[1], a[3], z), (a[0], a[3], z)])
mb = MB(); rect_hole(mb, (-1500, 1500, -1500, 1500), (-16, 18, -13.5, 13.5), -0.02); mb.obj('land', 'land')
mb = MB()
for (x0, x1, y0, y1) in ((-16, 18, 7.2, 13.5), (-16, -9.8, -13.5, 7.2), (9.4, 18, -13.5, 7.2), (-9.8, 9.4, -13.5, -11.6), (6.5, 9.4, 1.0, 7.2), (9.0, 9.4, -4.0, 1.0)):
    mb.poly([(x0, y0, 0), (x1, y0, 0), (x1, y1, 0), (x0, y1, 0)])
mb.obj('lawn', 'lawn')
# Montañas
mb = MB(); segA, rings = 220, 9
grid = []
for ri in range(rings):
    rad = 520 + ri * 75; row = []
    for a in range(segA):
        ang = a / segA * 2 * math.pi
        n = math.sin(ang * 3 + 1.3) * .5 + math.sin(ang * 7 + .4) * .28 + math.sin(ang * 17 + 2) * .12 + math.sin(ang * 41) * .05 + math.sin(ang * 83 + 1) * .03
        back = .45 + .55 * (0.5 + 0.5 * math.sin(ang))
        h = 0 if ri in (0, rings - 1) else max(0, (75 + n * 70) * math.sin(ri / (rings - 1) * math.pi) * back + rr(-4, 4))
        row.append(mb.bm.verts.new((math.cos(ang) * rad, math.sin(ang) * rad, h - 2)))
    grid.append(row)
for ri in range(rings - 1):
    for a in range(segA): mb.bm.faces.new((grid[ri][a], grid[ri][(a + 1) % segA], grid[ri + 1][(a + 1) % segA], grid[ri + 1][a]))
mb.obj('hills', 'hills', smooth=True)

# Muros perimetrales con lamas
mb = MB()
mb.box(-16.15, 18.15, 13.25, 13.55, 0, 1.1); mb.box(-16.15, -15.85, -13.5, 13.55, 0, 1.1); mb.box(17.85, 18.15, -13.5, 13.55, 0, 1.1)
mb.box(-16.15, -1.6, -13.65, -13.35, 0, .7); mb.box(3.6, 18.15, -13.65, -13.35, 0, .7)
mb.obj('walls_perim', 'render', .01)
mb = MB()
x = -16
while x < 18: mb.box(x, x + .07, 13.33, 13.47, 1.1, 2.0, ); x += .14
y = -13.5
while y < 13.4:
    mb.box(-16.07, -15.93, y, y + .07, 1.1, 2.0); mb.box(17.93, 18.07, y, y + .07, 1.1, 2.0); y += .14
x = -1.6
while x < 3.6: mb.box(x, x + .07, -13.57, -13.43, 0, 1.6); x += .14
simple('slat', 0x3b3a38, .5, .3); mb.obj('slats', 'slat')
# Camino de losas desde la puerta
mb = MB()
for i in range(5): mb.box(.2 + (i % 2) * .15, 1.8 + (i % 2) * .15, -13.0 + i * .9, -12.4 + i * .9, 0, .03)
mb.obj('stepstones', 'concrete', .01)

# ------------------------------------------------------------------ vivienda
# Plataforma, terraza y escalón (BASE)
mb = MB(); mb.box(-9.6, 6.5, 1.0, 7.2, 0, .3); mb.box(-9.6, 8.9, -3.5, 1.0, 0, .3); mb.box(-9.6, 9.0, -4.0, -3.5, 0, .15)
mb.obj('terrace', 'tile', .01, G_BASE)
# Interior planta baja
mb = MB(); mb.box(-6.4, 4.0, 1.2, 6.9, .3, .31); mb.obj('floor_in', 'tile', 0, G_BASE)
mb = MB(); mb.cbox(-1.6, 6.2, .52, 5.2, 1.0, .45); mb.cbox(-1.6, 6.62, .9, 5.2, .25, .45); mb.cbox(-4.6, 5.2, .52, 1.0, 2.6, .45)
mb.obj('sofa', 'fabric', .06, G_BASE)
mb = MB(); [mb.cbox(x, 6.42, .85, .7, .18, .4) for x in (-2.8, -1.6, -.4)]; mb.obj('cushions', 'fabriclight', .06, G_BASE)
mb = MB(); mb.cbox(-2.0, 4.8, .315, 4.2, 3.0, .01); mb.obj('rug', 'rug', 0, G_BASE)
mb = MB(); mb.cbox(-2.0, 4.7, .5, 1.4, .9, .38); mb.obj('coffee', 'marble', .02, G_BASE)
mb = MB(); mb.cbox(-1.6, 2.4, .58, 4.2, .5, .55); mb.obj('tvunit', 'darkwood', .01, G_BASE)
mb = MB(); mb.cbox(-1.6, 2.4, 1.95, 2.6, .06, 1.5); mb.obj('tv', 'tv', .005, G_BASE)
mb = MB(); mb.cbox(2.6, 5.2, 1.07, 2.6, 1.1, .06); mb.obj('table', 'oak', .01, G_BASE)
mb = MB()
for i in range(3):
    for s in (-1, 1): mb.cbox(1.7 + i * .9, 5.2 - s * .85, .55, .48, .48, .45); mb.cbox(1.7 + i * .9, 5.2 - s * 1.07, .98, .48, .08, .5)
mb.obj('chairs', 'fabriclight', .03, G_BASE)
mb = MB(); mb.cbox(1.5, 5.2, .68, .1, .9, .72); mb.cbox(3.7, 5.2, .68, .1, .9, .72)
for i in range(3): mb.cyl(1.8 + i * .8, 5.2, 2.05, 3.55, .006, 6)
mb.obj('legs', 'black', 0, G_BASE)
mb = MB()
for i in range(3): mb.cyl(1.8 + i * .8, 5.2, 1.8, 2.1, .14, 20, r2=.09)
mb.obj('pendants', 'lamp', 0, G_BASE, smooth=True)
mb = MB(); mb.cbox(2.4, 2.9, .76, 3.2, 1.0, .92); mb.cbox(2.85, 6.75, 1.6, 2.3, .6, 2.6); mb.obj('kitchen', 'lacquer', .015, G_BASE)
mb = MB(); mb.cbox(2.4, 2.9, 1.24, 3.4, 1.1, .04); mb.obj('counter', 'tile', .005, G_BASE)
mb = MB()
for i in range(12): mb.cbox(-5.75, 6.6 - i * .3, .4 + i * .26, 1.1, .3, .07)
mb.obj('stairs', 'darkwood', .008, G_BASE)
# Suelo radiante
mb = MB()
for i in range(11):
    mb.cbox(-1.2, 6.7 - i * .5, .33, 10.2, .14, .03)
    if i < 10:
        x = 3.9 if i % 2 == 0 else -6.3; mb.cbox(x, 6.7 - i * .5 - .25, .33, .14, .64, .03)
mb.obj('radiant', 'pipe', 0, G_BASE)
# Cocina exterior, mesa y sofá de porche
mb = MB(); mb.cbox(-5.2, -2.4, .75, 2.6, .7, .9); mb.obj('bbq', 'stone', .01, G_BASE)
mb = MB(); mb.cbox(-5.2, -2.4, 1.22, 2.7, .78, .05); mb.obj('bbqtop', 'black', .005, G_BASE)
mb = MB(); mb.cbox(0, -1.2, 1.06, 2.2, 1.0, .05); mb.obj('otable', 'lacquer', .01, G_BASE)
mb = MB()
for x in (-1, 1):
    for y in (-.8, -1.6): mb.cbox(x, y, .67, .05, .05, .74)
mb.obj('olegs', 'alu', 0, G_BASE)
mb = MB()
for i in range(3):
    for s in (-1, 1): mb.cbox(-.7 + i * .7, -1.2 - s * .75, .51, .45, .45, .42); mb.cbox(-.7 + i * .7, -1.2 - s * .95, .85, .45, .06, .5)
mb.obj('ochairs', 'fabriclight', .02, G_BASE)
mb = MB(); mb.cbox(3.0, -.6, .5, 3.2, 1.0, .4); mb.cbox(3.0, -.2, .85, 3.2, .25, .45); mb.obj('osofa', 'fabriclight', .07, G_BASE)
mb = MB(); [mb.cbox(x, -.4, .95, .55, .14, .5) for x in (2.0, 4.0)]; mb.obj('ocush', 'blue', .06, G_BASE)

# Planta baja: muros, piedra, vidrio (WALLS)
mb = MB(); mb.box(-9.6, -6.4, 1.0, 7.2, .3, 3.6); mb.obj('stonevol', 'stone', .01, G_WALLS)
mb = MB(); mb.box(-6.4, 6.0, 6.9, 7.2, .3, 3.6); mb.box(4.0, 6.4, 1.0, 7.2, .3, 3.6); mb.obj('gwalls', 'render', .012, G_WALLS)
def glazing(name, x0, x1, y, z0, z1, panes, parent):
    mb = MB(); mb.box(x0, x1, y - .015, y + .015, z0 + .06, z1 - .06); mb.obj(name + '_g', 'glass', 0, parent)
    mb = MB(); mb.box(x0, x1, y - .07, y + .07, z0, z0 + .07); mb.box(x0, x1, y - .07, y + .07, z1 - .07, z1)
    for i in range(panes + 1):
        xx = x0 + (x1 - x0) * i / panes; mb.box(xx - .035, xx + .035, y - .07, y + .07, z0, z1)
    mb.obj(name + '_f', 'alu', .004, parent)
glazing('gglass', -6.4, 4.0, 1.2, .3, 3.6, 4, G_WALLS)
mb = MB(); mb.box(4.95, 5.45, .95, 1.0, .6, 3.0); mb.obj('slotwin', 'alu', 0, G_WALLS)
mb = MB(); mb.box(-9.38, -9.22, -1.93, -1.77, .3, 3.6); mb.box(5.12, 5.28, -1.93, -1.77, .3, 3.6); mb.obj('columns', 'alu', .005, G_WALLS)
# Apliques exteriores
mb = MB(); mb.cbox(-6.0, .95, 2.2, .12, .1, .3); mb.cbox(3.6, .95, 2.2, .12, .1, .3); mb.obj('sconce', 'black', .005, G_WALLS)

# Planta alta (UPPER)
mb = MB(); mb.box(-10.0, 5.6, -2.1, 7.1, 3.6, 4.02); mb.obj('uslab', 'render', .015, G_UPPER)
mb = MB(); mb.box(-10.0, -9.68, -2.1, 7.1, 4.02, 7.0); mb.box(-.6, 5.6, -2.1, 7.1, 4.02, 7.0); mb.box(-9.7, -.1, 6.8, 7.1, 4.02, 7.0)
mb.obj('uwalls', 'render', .015, G_UPPER)
glazing('uglass', -9.68, -.6, 1.6, 4.02, 7.0, 4, G_UPPER)
mb = MB(); mb.box(-9.68, -.6, -2.0, -1.97, 4.08, 5.05); mb.obj('rail_g', 'glass', 0, G_UPPER)
mb = MB(); mb.box(-9.68, -.6, -2.05, -1.92, 4.02, 4.1); mb.obj('rail_base', 'steel', .003, G_UPPER)
mb = MB(); mb.box(-9.68, -.6, -1.97, 1.6, 4.02, 4.05); mb.obj('uterrace', 'tile', 0, G_UPPER)
mb = MB(); mb.box(0.0, 5.0, -2.16, -2.1, 5.15, 6.05); mb.obj('hwin_f', 'alu', 0, G_UPPER)
mb = MB(); mb.box(.08, 4.92, -2.19, -2.16, 5.22, 5.98); mb.obj('hwin_g', 'glass', 0, G_UPPER)
mb = MB()
for i in range(8): mb.cyl(-8.5 + i * 1.6, -1.2, 3.585, 3.6, .07, 16)
mb.obj('downlights', 'downlight', 0, G_UPPER)
mb = MB(); mb.cbox(-4.8, 4.6, 4.27, 2.0, 2.2, .5); mb.obj('bed', 'fabriclight', .06, G_UPPER)
mb = MB(); mb.cbox(-4.8, 4.2, 4.56, 2.0, 1.4, .12); mb.obj('throw', 'pink', .04, G_UPPER)
mb = MB(); mb.cbox(-4.8, 5.8, 4.6, 2.2, .12, 1.1); mb.cbox(-1.6, 6.5, 5.3, 3.4, .5, 2.6); mb.obj('uwood', 'darkwood', .01, G_UPPER)
mb = MB(); mb.cyl(-6.3, 5.3, 5.0, 5.35, .16, 20, r2=.1); mb.obj('ulamp', 'lamp', 0, G_UPPER, smooth=True)
# Jardineras en terraza
mb = MB(); mb.box(-9.5, -8.5, -1.8, -1.2, 4.02, 4.5); mb.box(-2.0, -1.0, -1.8, -1.2, 4.02, 4.5); mb.obj('planters', 'concrete', .01, G_UPPER)

# Cubierta (ROOF)
mb = MB(); mb.box(-10.2, 5.8, -2.2, 7.2, 7.0, 7.36); mb.obj('rslab', 'render', .015, G_ROOF)
mb = MB(); mb.box(-10.2, 5.8, -2.2, -2.0, 7.36, 7.85); mb.box(-10.2, 5.8, 7.0, 7.2, 7.36, 7.85); mb.box(-10.2, -10.0, -2.0, 7.0, 7.36, 7.85); mb.box(5.6, 5.8, -2.0, 7.0, 7.36, 7.85)
mb.obj('parapet', 'render', .01, G_ROOF)
mb = MB(); mb.box(-10.0, 5.6, -2.0, 7.0, 7.36, 7.4); mb.obj('rgravel', 'gravelroof', 0, G_ROOF)
mb = MB(); mb.box(1.7, 4.7, 3.6, 6.4, 7.36, 9.0); mb.obj('caseton', 'render', .015, G_ROOF)
panels = MB(); legs = MB()
for r in range(2):
    for c in range(6):
        cx, cy = -8.6 + c * 1.2, 4.6 - r * 2.2
        bm = panels.bm; before = set(bm.verts)
        panels.cbox(cx, cy, 0, 1.1, 1.9, .04)
        new = [v for v in bm.verts if v not in before]
        rot = Matrix.Rotation(math.radians(24), 4, 'X')
        for v in new: v.co = rot @ v.co + Vector((0, 0, 7.85))
        legs.cbox(cx, cy - .7, 7.55, .04, .04, .4)
panels.obj('panels', 'panel', .005, G_ROOF); legs.obj('plegs', 'alu', 0, G_ROOF)

# ------------------------------------------------------------------ piscina y jacuzzi
mb = MB()
PX0, PX1, PY0, PY1, D = -3, 9, -8.8, -4.4, 1.5
mb.poly([(PX0, PY0, -D), (PX1, PY0, -D), (PX1, PY1, -D), (PX0, PY1, -D)])
for (a, b2) in (((PX0, PY0), (PX1, PY0)), ((PX1, PY0), (PX1, PY1)), ((PX1, PY1), (PX0, PY1)), ((PX0, PY1), (PX0, PY0))):
    mb.poly([(a[0], a[1], 0), (b2[0], b2[1], 0), (b2[0], b2[1], -D), (a[0], a[1], -D)])
mb.box(-3, 0, -5.6, -4.4, -D, -1.05); mb.box(-3, 0, -5.0, -4.4, -D, -.6)
mb.obj('pool', 'pooltile', 0, recalc=False)
mb = MB(); mb.box(PX0 + .002, PX1 - .002, PY0 + .002, PY1 - .002, -D + .002, -.07); mb.obj('water', 'water', 0)
mb = MB(); mb.box(-3.4, 9.4, -9.2, -8.8, 0, .07); mb.box(-3.4, 9.4, -4.4, -4.0, 0, .07); mb.box(-3.4, -3.0, -8.8, -4.4, 0, .07); mb.box(9.0, 9.4, -8.8, -4.4, 0, .07)
mb.obj('coping', 'tile', .012)
mb = MB()
for i in range(6): mb.cbox(-2 + i * 2, -4.42, -.45, .2, .01, .2)
mb.obj('leds', 'led', 0)
mb = MB(); mb.box(-9.8, -3.4, -11.6, -4.0, 0, .08); mb.box(-3.4, 9.4, -11.6, -9.2, 0, .08); mb.obj('deck', 'wood', .004)
# Jacuzzi elevado
JX, JY = -6.4, -7.2
mb = MB(); n = 64
outer_b = [mb.bm.verts.new((JX + 1.5 * math.cos(a), JY + 1.5 * math.sin(a), .08)) for a in [i / n * 2 * math.pi for i in range(n)]]
outer_t = [mb.bm.verts.new((JX + 1.5 * math.cos(a), JY + 1.5 * math.sin(a), .68)) for a in [i / n * 2 * math.pi for i in range(n)]]
inner_t = [mb.bm.verts.new((JX + 1.2 * math.cos(a), JY + 1.2 * math.sin(a), .68)) for a in [i / n * 2 * math.pi for i in range(n)]]
inner_b = [mb.bm.verts.new((JX + 1.2 * math.cos(a), JY + 1.2 * math.sin(a), .12)) for a in [i / n * 2 * math.pi for i in range(n)]]
mi = MB(); inner_t2 = [mi.bm.verts.new(v.co) for v in inner_t]; inner_b2 = [mi.bm.verts.new(v.co) for v in inner_b]
for i in range(n):
    j = (i + 1) % n
    mb.bm.faces.new((outer_b[i], outer_b[j], outer_t[j], outer_t[i])); mb.bm.faces.new((outer_t[i], outer_t[j], inner_t[j], inner_t[i]))
    mi.bm.faces.new((inner_t2[i], inner_t2[j], inner_b2[j], inner_b2[i]))
mi.bm.faces.new(list(inner_b2))
mb.obj('spa', 'render', .01, recalc=False); mi.obj('spain', 'pooltile', 0, recalc=False)
mb = MB(); mb.cyl(JX, JY, .121, .6, 1.198, 64); mb.obj('spawater', 'spawater', 0, smooth=True)
mb = MB(); mb.cbox(JX, JY - 1.85, .17, 1.0, .5, .18); mb.obj('spastep', 'wood', .005)
# Tumbonas, sombrilla
for i, x in enumerate((1.0, 2.3, 3.6)):
    mb = MB(); mb.cbox(x, -10.4, .2, .75, 2.0, .2); mb.obj('lounger%d' % i, 'lacquer', .03)
    mb = MB(); mb.cbox(x, -10.15, .36, .68, 1.35, .1); mb.obj('lcush%d' % i, 'fabriclight', .04)
    mb = MB(); mb.cbox(0, 0, 0, .68, .75, .1)
    me_o = mb.obj('lback%d' % i, 'fabriclight', .04); me_o.location = (x, -11.05, .56); me_o.rotation_euler = (math.radians(-45), 0, 0)
mb = MB(); mb.cyl(6.3, -11.0, .08, 2.65, .035, 10); mb.obj('pole', 'alu', 0)
mb = MB()
apex = mb.bm.verts.new((6.3, -11.0, 2.85)); ring = [mb.bm.verts.new((6.3 + 1.7 * math.cos(a + math.pi / 4), -11.0 + 1.7 * math.sin(a + math.pi / 4), 2.42)) for a in [i / 4 * 2 * math.pi for i in range(4)]]
for i in range(4): mb.bm.faces.new((apex, ring[i], ring[(i + 1) % 4]))
o = mb.obj('canopy', 'canvas', 0); o.modifiers.new('sol', 'SOLIDIFY').thickness = .01

# ------------------------------------------------------------------ vegetación
def leaf(mb, p, d, up, L, W, color, fold=.25, curl=.0):
    """Hoja elíptica de 7 vértices. d: dirección, up: normal aproximada."""
    d = d.normalized(); side = d.cross(up).normalized(); nrm = side.cross(d).normalized()
    tip = p + d * L + nrm * (-curl * L)
    a1 = p + d * (L * .3) + side * (W * .5) + nrm * (fold * W * .5)
    a2 = p + d * (L * .68) + side * (W * .38) + nrm * (fold * W * .4 - curl * L * .4)
    b1 = p + d * (L * .3) - side * (W * .5) + nrm * (fold * W * .5)
    b2 = p + d * (L * .68) - side * (W * .38) + nrm * (fold * W * .4 - curl * L * .4)
    mid1 = p + d * (L * .3); mid2 = p + d * (L * .68) + nrm * (-curl * L * .4)
    mb.poly([p, a1, mid1], color); mb.poly([p, mid1, b1], color)
    mb.poly([mid1, a1, a2, mid2], color); mb.poly([mid1, mid2, b2, b1], color)
    mb.poly([mid2, a2, tip], color); mb.poly([mid2, tip, b2], color)

def srgb(h): return tuple(((h >> s_) & 255) / 255 for s_ in (16, 8, 0)) + (1.0,)
def rcol(base, var=.12):
    c = srgb(base); f = rr(1 - var, 1 + var); g = rr(-var, var) * .5
    return (max(0, c[0] * f * (1 - g)), max(0, c[1] * f), max(0, c[2] * f * (1 + g)), 1)

def randdir():
    while True:
        v = Vector((rr(-1, 1), rr(-1, 1), rr(-1, 1)))
        if .05 < v.length <= 1: return v.normalized()

def shrub(mb, core, c, sx, sy, sz, n, leafL=(.07, .12), palette=(0x3d6a26, 0x4f7d2e, 0x2f5420, 0x5b8a34), flowers=None, fmb=None):
    for i in range(n):
        u = randdir(); rad = rr(.75, 1.0)
        p = Vector((c[0] + u.x * sx * rad, c[1] + u.y * sy * rad, c[2] + u.z * sz * rad))
        if p.z < .02: continue
        d = (u + randdir() * .9).normalized()
        L = rr(*leafL); leaf(mb, p, d, u, L, L * .5, rcol(R.choice(palette)), .3, rr(-.1, .25))
        if flowers and fmb and R.random() < flowers:
            q = p + u * .02; s = rr(.025, .04); fc = rcol(R.choice((0xc2185b, 0xd81b60, 0xad1457, 0xe91e63)), .08)
            for k in range(3):
                dd = (randdir() + u).normalized(); leaf(fmb, q, dd, u, s * 1.4, s * 1.2, fc, .5, .2)
    # núcleo oscuro para tapar huecos
    ret = bmesh.ops.create_icosphere(core.bm, subdivisions=2, radius=1.0)
    for v in ret['verts']: v.co = Vector((c[0] + v.co.x * sx * .82, c[1] + v.co.y * sy * .82, c[2] + v.co.z * sz * .82))

leaves = MB(True); flowers = MB(True); cores = MB()
# setos perimetrales
x = -15.3
while x <= 17.3:
    shrub(leaves, cores, (x, 12.6, 1.05), .7, .6, 1.05, 520, (.1, .16)); x += 1.0
y = -12.5
while y <= 12.0:
    shrub(leaves, cores, (-15.2, y, .95), .6, .65, .95, 420, (.1, .16)); shrub(leaves, cores, (17.2, y, .95), .6, .65, .95, 420, (.1, .16)); y += 1.1
x = -15.3
while x <= 17.4:
    if not (-2.2 < x < 4.2): shrub(leaves, cores, (x, -12.9, .55), .55, .45, .6, 300, (.08, .13))
    x += 1.0
# arbustos sueltos y buganvillas
for (x, y, s, fl) in ((9.2, .4, 1.0, 0), (7.6, .6, .8, .0), (-11.2, -4.2, .9, .35), (-10.5, -5.6, .7, 0), (12.2, -5.0, .9, 0), (13.2, -9.4, 1.0, .3),
                      (-12.8, -8.8, .8, 0), (-10.0, 1.6, .75, 0), (7.2, -1.5, .55, 0), (11.6, 4.0, .9, 0), (-12.6, 4.5, 1.0, .3), (16.6, 12.4, 1.3, .45), (-15.0, 12.2, 1.3, .45)):
    shrub(leaves, cores, (x, y, s * .7), s, s, s * .8, int(1500 * s * s), (.08, .13), flowers=fl, fmb=flowers)
# flores bajas en parterres
for (bx, by, w, d) in ((8.4, .5, 2.2, .9), (-11.4, -5, 1.2, 2), (12.6, -6.8, 1.4, 2.4), (-10.6, 2.8, 1.2, 1.4)):
    for i in range(int(w * d * 60)):
        p = Vector((bx + rr(-w, w), by + rr(-d, d), rr(.05, .35)))
        c = rcol(R.choice((0xd2263b, 0xe0457b, 0xf4f4f4, 0xd9372a, 0xf0a3c0)), .05)
        for k in range(4): leaf(flowers, p, Vector((math.cos(k * 1.57 + .3), math.sin(k * 1.57 + .3), .4)), Vector((0, 0, 1)), .035, .03, c, .4)
        leaf(leaves, Vector((p.x, p.y, rr(.02, p.z))), Vector((rr(-1, 1), rr(-1, 1), .6)), Vector((0, 0, 1)), .08, .03, rcol(0x3f6b25), .3)
simple('core', 0x2c4a1e, 1.)
leaves.obj('leaves', 'leaf'); flowers.obj('flowers', 'leaf'); cores.obj('bushcores', 'core', smooth=True)

# Palmeras con folíolos en geometría
def palm(name, x, y, h, lean, yaw, seed):
    R.seed(seed)
    trunk = MB(); fr = MB(True)
    top = Vector((math.sin(yaw) * lean * h, math.cos(yaw) * lean * h, h))
    def curve(t):
        return Vector((top.x * (t ** 1.8), top.y * (t ** 1.8), h * t))
    seg, rad = 40, 14; rings = []
    for i in range(seg + 1):
        t = i / seg; c = curve(t) + Vector((x, y, 0))
        r0 = (.26 - .08 * t) * (1.35 if t < .04 else 1) * (1 + .05 * math.sin(i * 2.7))
        ring = [trunk.bm.verts.new(c + Vector((math.cos(a) * r0, math.sin(a) * r0, 0))) for a in [k / rad * 2 * math.pi for k in range(rad)]]
        rings.append(ring)
    for i in range(seg):
        for k in range(rad): trunk.bm.faces.new((rings[i][k], rings[i][(k + 1) % rad], rings[i + 1][(k + 1) % rad], rings[i + 1][k]))
    crown = curve(1) + Vector((x, y, 0))
    ret = bmesh.ops.create_uvsphere(trunk.bm, u_segments=12, v_segments=8, radius=.42)
    for v in ret['verts']: v.co = Vector((v.co.x, v.co.y, v.co.z * 1.4)) + crown - Vector((0, 0, .25))
    nf = 17
    for i in range(nf):
        dry = i >= nf - 3
        yawf = i * 2.39996 + rr(-.15, .15)
        elev = rr(-1.25, -.95) if dry else (rr(.55, 1.0) if i < 6 else rr(-.05, .45))
        Lf = rr(2.2, 2.8) if dry else rr(3.0, 4.2)
        droop = .05 if dry else rr(.45, .8)
        dirh = Vector((math.cos(yawf), math.sin(yawf), 0))
        base_col = 0x9c8455 if dry else R.choice((0x3a6e22, 0x467d28, 0x2f6320, 0x528a2c))
        pts = []
        for k in range(16):
            t = k / 15
            e = elev - droop * t * t * 1.6
            pts.append(crown + dirh * (math.cos(elev) * Lf * t) + Vector((0, 0, math.sin(elev) * Lf * t - droop * Lf * t * t * .8)))
        for k in range(15):  # raquis
            a, b2 = pts[k], pts[k + 1]; w = .025 * (1 - k / 15) + .006
            side = (b2 - a).cross(Vector((0, 0, 1))).normalized() * w
            fr.poly([a - side, a + side, b2 + side, b2 - side], rcol(0x8a8a50, .05))
        nl = 44
        for k in range(2, nl):
            t = k / nl; idx = t * 15; i0 = min(14, int(idx)); f = idx - i0
            p = pts[i0].lerp(pts[i0 + 1], f); tang = (pts[i0 + 1] - pts[i0]).normalized()
            sidev = tang.cross(Vector((0, 0, 1))).normalized()
            Ll = (.35 + .75 * math.sin(min(1, t * 1.15) * math.pi * .95)) * (Lf / 3.6) * (.7 if dry else 1)
            for s in (-1, 1):
                d = (tang * .55 + sidev * s * 1.0 + Vector((0, 0, .35 if not dry else -.4))).normalized()
                c = rcol(base_col, .1)
                leaf(fr, p, d, Vector((0, 0, 1)), Ll, .075, c, .15, rr(.15, .35) if not dry else .05)
    trunk.obj(name + '_trunk', 'trunk', 0, smooth=True)
    fr.obj(name + '_fronds', 'leaf')
palm('palm1', 10.6, -.8, 8.6, .07, .6, 1); palm('palm2', 13.6, -3.2, 7.2, .1, 1.2, 2); palm('palm3', -12.2, -2.4, 7.8, .08, -.7, 3)
palm('palm4', -13.4, 9.2, 9.2, .05, 2.8, 4); palm('palm5', 14.6, -11.2, 6.4, .12, 2.2, 5); palm('palm6', -13.8, -9.0, 6.0, .1, -2.4, 6)
palm('palm7', 6.8, 9.6, 8.0, .06, 3.6, 7)
R.seed(99)

# Árboles mediterráneos instanciados (pino piñonero, olivo, ciprés)
m, nt, b = newmat('canopy'); M['canopy'] = m
tc = node(nt, 'ShaderNodeTexCoord'); ob_i = node(nt, 'ShaderNodeObjectInfo')
n1 = noise(nt, tc.outputs['Object'], 9, 8, .7); n2 = noise(nt, tc.outputs['Object'], 2, 3)
ca = node(nt, 'ShaderNodeVertexColor'); ca.layer_name = 'col'
var = mix(nt, ob_i.outputs['Random'], ca.outputs['Color'], lin(0x6a7a40), 'MIX')
c = mix(nt, n1.outputs['Fac'], lin(0x1d2a12), var, 'MIX'); c = mix(nt, .6, c, var, 'MIX')

haze(nt, c, b, 900.)
b.inputs['Roughness'].default_value = .9; L(nt, bump(nt, n1.outputs['Fac'], 1.0, .3), b.inputs['Normal'])
proto = {}
def proto_tree(name, build):
    col = bpy.data.collections.new(name); mbt = MB(True); mtr = MB(); build(mbt, mtr)
    o1 = mbt.obj(name + '_c', 'leaf'); o2 = mtr.obj(name + '_t', 'olivetrunk', smooth=True)
    for o in (o1, o2):
        COL.objects.unlink(o); col.objects.link(o)
    proto[name] = col
def tube(mb, p0, p1, r0, r1, n=7):
    p0, p1 = Vector(p0), Vector(p1); ax = (p1 - p0).normalized()
    u = ax.orthogonal().normalized(); v = ax.cross(u)
    a = [mb.bm.verts.new(p0 + (u * math.cos(t) + v * math.sin(t)) * r0) for t in [k / n * 2 * math.pi for k in range(n)]]
    b_ = [mb.bm.verts.new(p1 + (u * math.cos(t) + v * math.sin(t)) * r1) for t in [k / n * 2 * math.pi for k in range(n)]]
    for k in range(n): mb.bm.faces.new((a[k], a[(k + 1) % n], b_[(k + 1) % n], b_[k]))
def tuft(mbt, c, n, Lr, Wr, palette, up_bias=.3):
    for _ in range(n):
        d = (randdir() + Vector((0, 0, up_bias))).normalized(); L_ = rr(*Lr)
        leaf(mbt, c + randdir() * L_ * .25, d, randdir(), L_, L_ * Wr, rcol(R.choice(palette), .12), .25, rr(0, .2))
def core(mbt, c, rad, color):
    ret = bmesh.ops.create_icosphere(mbt.bm, subdivisions=2, radius=1)
    for v in ret['verts']: v.co = Vector((c.x + v.co.x * rad[0], c.y + v.co.y * rad[1], c.z + v.co.z * rad[2]))
    for f in {f for v in ret['verts'] for f in v.link_faces}:
        for lo in f.loops: lo[mbt.col] = color
def pine(mbt, mtr):
    H = rr(9.5, 12.0); top = Vector((rr(-.4, .4), rr(-.4, .4), H * .7))
    tube(mtr, (0, 0, 0), top, .34, .22, 9)
    pal = (0x4f6f3a, 0x5b7c41, 0x456533, 0x66864a)
    for k in range(8):
        a = k / 8 * 2 * math.pi + rr(-.3, .3); r = rr(1.6, 3.4)
        end = Vector((math.cos(a) * r, math.sin(a) * r, H * rr(.86, .95)))
        tube(mtr, top, end, .13, .06, 6)
    core(mbt, Vector((0, 0, H * .97)), (4.0, 4.0, .75), srgb(0x2f4520))
    for _ in range(560):
        a = rr(0, 2 * math.pi); r = 4.7 * math.sqrt(rr(0, 1)); h = H * .97 + (1 - (r / 4.7) ** 2) * .9 * rr(.3, 1) - rr(0, .7)
        tuft(mbt, Vector((math.cos(a) * r, math.sin(a) * r, h)), 30, (.3, .5), .18, pal, .5)
def olivet(mbt, mtr):
    H = rr(3.6, 4.6); base = Vector((0, 0, 0)); fork = Vector((rr(-.3, .3), rr(-.3, .3), 1.3))
    tube(mtr, base, fork, .32, .24, 9)
    pal = (0x84946a, 0x738459, 0x9aa781, 0x6c7a52)
    for k in range(4):
        a = k * 1.6 + rr(-.3, .3); end = fork + Vector((math.cos(a) * 1.2, math.sin(a) * 1.2, rr(1.2, 1.8))); tube(mtr, fork, end, .14, .07, 6)
    core(mbt, Vector((0, 0, H * .72)), (1.9, 1.9, 1.0), srgb(0x56634a))
    for _ in range(300):
        u = randdir(); c = Vector((u.x * 2.3, u.y * 2.3, H * .72 + u.z * 1.25)) * rr(.7, 1.0)
        c.z = max(c.z, 1.8); tuft(mbt, c, 34, (.1, .17), .3, pal, .1)
def cypress(mbt, mtr):
    H = rr(9, 12); tube(mtr, (0, 0, 0), (0, 0, 1.2), .2, .16, 7)
    pal = (0x34502a, 0x3f5f30, 0x4a6a36)
    core(mbt, Vector((0, 0, H * .45)), (.85, .85, H * .45), srgb(0x23361c))
    for _ in range(600):
        t = rr(0, 1) ** .8; z = 1.0 + t * (H - 1.0); rad = 1.15 * math.sin(min(1, (1 - t) * 1.3 + .05) * math.pi * .55) * (1 - t * .3)
        a = rr(0, 2 * math.pi); r = rad * math.sqrt(rr(.3, 1))
        tuft(mbt, Vector((math.cos(a) * r, math.sin(a) * r, z)), 18, (.16, .26), .4, pal, .8)
def bigbush(mbt, mtr):
    pal = (0x5a7a3e, 0x688a46, 0x75894c, 0x858a55)
    core(mbt, Vector((0, 0, .5)), (.95, .95, .5), srgb(0x34492a))
    for _ in range(170):
        u = randdir(); c = Vector((u.x * 1.1, u.y * 1.1, .55 + u.z * .5)) * rr(.75, 1)
        c.z = max(c.z, .1); tuft(mbt, c, 28, (.1, .16), .5, pal, .2)
def palmproto(name):
    palm(name + '_src', 0, 0, rr(7, 10), rr(.03, .1), rr(0, 6), R.randint(10, 999))
    col = bpy.data.collections.new(name)
    for suf in ('_trunk', '_fronds'):
        o = bpy.data.objects[name + '_src' + suf]; COL.objects.unlink(o); col.objects.link(o)
    proto[name] = col
R.seed(21)
for nm, fn in (('pineA', pine), ('pineB', pine), ('oliveA', olivet), ('oliveB', olivet), ('cypress', cypress), ('bushA', bigbush), ('bushB', bigbush)): proto_tree(nm, fn)
palmproto('palmA'); palmproto('palmB')
NEIGH = [(-48, 40, 12, 9), (40, 55, 14, 10), (-72, -8, 10, 8), (66, 8, 12, 9), (12, 78, 16, 10), (-30, 85, 12, 8), (90, 60, 12, 9), (-60, -60, 12, 9), (55, -55, 14, 9), (-95, 30, 12, 9)]
def blocked(x, y, kind_big=True):
    if -21 < x < 23 and -22 < y < 18: return True
    if -21 < y < -14: return True   # carretera
    if -75 < x < 75 and -110 < y < -21: return R.random() > .12 or kind_big   # corredor de cámara casi despejado
    for (hx, hy, w, d) in NEIGH:
        if abs(x - hx) < w / 2 + 6 and abs(y - hy) < d / 2 + 8: return True
    return False
cnt = 0; tries = 0
while cnt < 1500 and tries < 60000:
    tries += 1
    d = 22 + (rr(0, 1) ** 1.6) * 330; a = rr(0, 2 * math.pi); x, y = math.cos(a) * d * 1.1, math.sin(a) * d
    kind = R.choices(['pineA', 'pineB', 'oliveA', 'oliveB', 'cypress', 'bushA', 'bushB', 'palmA', 'palmB'], [3, 3, 3.5, 3.5, 1.5, 3, 3, 1, 1])[0]
    if blocked(x, y, not kind.startswith('bush')): continue
    e = bpy.data.objects.new('tree%d' % cnt, None); e.instance_type = 'COLLECTION'; e.instance_collection = proto[kind]
    sc_ = rr(.75, 1.3); e.scale = (sc_, sc_, sc_ * rr(.9, 1.1)); e.rotation_euler.z = rr(0, 6.3); e.location = (x, y, -.02)
    COL.objects.link(e); cnt += 1
# Carretera con aceras
simple('asphalt', 0x3a3b3c, .85); simple('curb', 0xc9c4ba, .8)
mb = MB(); mb.box(-1500, 1500, -20.0, -15.6, -.02, .0); mb.obj('road', 'asphalt')
mb = MB(); mb.box(-1500, 1500, -15.6, -14.0, -.02, .12); mb.box(-1500, 1500, -21.6, -20.0, -.02, .12); mb.obj('sidewalk', 'curb', .01)
mb = MB()
x = -300
while x < 300: mb.box(x, x + 3, -17.85, -17.75, 0, .003); x += 6
simple('paint', 0xe8e6df, .6); mb.obj('roadline', 'paint')
# Casas vecinas con jardín y piscina
nb = MB(); nbw = MB(); nbl = MB(); nbp = MB(); nbwall = MB()
for (x, y, w, d) in NEIGH:
    h = rr(6.0, 7.0)
    nb.box(x - w / 2, x + w / 2, y - d / 2, y + d / 2, 0, h * .5); nb.box(x - w / 2 + 1, x + w / 2 - rr(1, 3), y - d / 2 + rr(0, 1), y + d / 2, h * .5, h)
    face = -1 if y > -14 else 1
    yf = y - d / 2 if face < 0 else y + d / 2
    nbw.box(x - w * .35, x + w * .3, yf - .06, yf + .06, .4, h * .45); nbw.box(x - w * .3, x + w * .2, yf - .06 + face * -.5, yf + .06 + face * -.5, h * .55, h * .92)
    gy0, gy1 = (y - d / 2 - 14, y - d / 2) if face < 0 else (y + d / 2, y + d / 2 + 14)
    nbl.poly([(x - w / 2 - 6, gy0, .01), (x + w / 2 + 6, gy0, .01), (x + w / 2 + 6, gy1, .01), (x - w / 2 - 6, gy1, .01)])
    py = (gy0 + gy1) / 2; nbp.box(x - 4, x + 4, py - 1.6, py + 1.6, .0, .03)
    for (a0, a1, b0, b1) in ((x - w / 2 - 6, x + w / 2 + 6, gy0 - .1, gy0 + .1) if face < 0 else (x - w / 2 - 6, x + w / 2 + 6, gy1 - .1, gy1 + .1),):
        nbwall.box(a0, a1, b0, b1, 0, 1.6)
nb.obj('neighbors', 'render', .02); nbw.obj('neighborwin', 'alu', 0); nbl.obj('neighborlawn', 'lawn'); nbwall.obj('neighborwalls', 'render', .01)
simple('npool', 0x2fb6c9, .05); nbp.obj('neighborpools', 'npool')

# ------------------------------------------------------------------ luces, cielo, cámara
SUN_EL, SUN_AZ = 33, 145   # sun_rotation: 0=+Y, 90=+X -> sol delante-derecha
w = bpy.data.worlds.new('sky'); sc.world = w; w.use_nodes = True; nt = w.node_tree
sky = nt.nodes.new('ShaderNodeTexSky'); sky.sky_type = 'NISHITA'; sky.sun_disc = False
sky.sun_elevation = math.radians(SUN_EL); sky.sun_rotation = math.radians(SUN_AZ); sky.air_density = 1.0; sky.dust_density = .45; sky.ozone_density = 1.2; sky.altitude = 150
bg = nt.nodes['Background']; bg.inputs['Strength'].default_value = .3
# nubes: ruido proyectado sobre un plano a gran altura
tcw = nt.nodes.new('ShaderNodeTexCoord'); sep = nt.nodes.new('ShaderNodeSeparateXYZ'); nt.links.new(tcw.outputs['Generated'], sep.inputs[0])
dv = nt.nodes.new('ShaderNodeVectorMath'); dv.operation = 'DIVIDE'; nt.links.new(tcw.outputs['Generated'], dv.inputs[0])
cz = nt.nodes.new('ShaderNodeMath'); cz.operation = 'MAXIMUM'; cz.inputs[1].default_value = .04; nt.links.new(sep.outputs['Z'], cz.inputs[0])
cmb = nt.nodes.new('ShaderNodeCombineXYZ'); [nt.links.new(cz.outputs[0], cmb.inputs[k]) for k in range(3)]; nt.links.new(cmb.outputs[0], dv.inputs[1])
cn = nt.nodes.new('ShaderNodeTexNoise'); cn.inputs['Scale'].default_value = 1.6; cn.inputs['Detail'].default_value = 8; cn.inputs['Roughness'].default_value = .62
nt.links.new(dv.outputs[0], cn.inputs['Vector'])
cr = nt.nodes.new('ShaderNodeValToRGB'); cr.color_ramp.elements[0].position = .56; cr.color_ramp.elements[1].position = .78; nt.links.new(cn.outputs['Fac'], cr.inputs[0])
hz = nt.nodes.new('ShaderNodeMapRange'); hz.inputs['From Min'].default_value = .02; hz.inputs['From Max'].default_value = .25; nt.links.new(sep.outputs['Z'], hz.inputs['Value'])
cm = nt.nodes.new('ShaderNodeMath'); cm.operation = 'MULTIPLY'; nt.links.new(cr.outputs[0], cm.inputs[0]); nt.links.new(hz.outputs[0], cm.inputs[1])
cm2 = nt.nodes.new('ShaderNodeMath'); cm2.operation = 'MULTIPLY'; cm2.inputs[1].default_value = .85; nt.links.new(cm.outputs[0], cm2.inputs[0])
ccol = nt.nodes.new('ShaderNodeMixRGB'); ccol.inputs['Color2'].default_value = (14., 14., 14.5, 1)
nt.links.new(cn.outputs['Fac'], ccol.inputs['Fac']); ccol.inputs['Color1'].default_value = (7., 7.4, 8.2, 1)
skymix = nt.nodes.new('ShaderNodeMixRGB'); nt.links.new(cm2.outputs[0], skymix.inputs['Fac']); nt.links.new(sky.outputs[0], skymix.inputs['Color1']); nt.links.new(ccol.outputs[0], skymix.inputs['Color2'])
nt.links.new(skymix.outputs[0], bg.inputs[0])
sun_d = bpy.data.lights.new('sun', 'SUN'); sun_d.energy = 4.2; sun_d.angle = math.radians(.8); sun_d.color = (1.0, .95, .88)
sun = bpy.data.objects.new('sun', sun_d); COL.objects.link(sun)
# dirección de la luz coherente con el cielo: rotación Z = azimut, X = 90-elevación
sun.rotation_euler = Euler((math.radians(90 - SUN_EL), 0, math.radians(SUN_AZ - 180)), 'XYZ')
# Luces interiores cálidas
def area(name, loc, size, energy, color=(1, .82, .6), parent=None, rot=(0, 0, 0)):
    d = bpy.data.lights.new(name, 'AREA'); d.energy = energy; d.size = size; d.color = color
    o = bpy.data.objects.new(name, d); o.location = loc; o.rotation_euler = rot; COL.objects.link(o)
    if parent: o.parent = parent
    return o
area('in1', (-1.5, 4.5, 3.45), 4.0, 260, parent=G_BASE); area('in2', (2.5, 4.5, 3.45), 3.0, 180, parent=G_BASE)
area('in3', (-4.5, 4.0, 6.85), 4.0, 200, parent=G_UPPER)
pl = bpy.data.lights.new('poollight', 'POINT'); pl.energy = 0; pl.color = (.55, .95, 1); pl.shadow_soft_size = .5
plo = bpy.data.objects.new('poollight', pl); plo.location = (3, -6.6, -.9); COL.objects.link(plo)

cam_d = bpy.data.cameras.new('cam'); cam_d.lens = 32; cam_d.sensor_width = 36; cam_d.clip_start = .3; cam_d.clip_end = 6000
cam = bpy.data.objects.new('cam', cam_d); COL.objects.link(cam); sc.camera = cam
tgt = empty('target'); tc = cam.constraints.new('TRACK_TO'); tc.target = tgt; tc.track_axis = 'TRACK_NEGATIVE_Z'; tc.up_axis = 'UP_Y'

# Anclas para las fichas
ANCH = {}
for k, loc, par in (('roof', (-6.2, 4.6, 7.95), G_ROOF), ('canti', (-9.2, -2.0, 4.6), G_UPPER), ('smart', (2.5, -2.2, 5.6), G_UPPER),
                    ('radiant', (-4.8, 3.0, .36), G_BASE), ('stone', (-7.2, .95, 2.2), G_WALLS), ('pool', (6.5, -6.2, 0.0), None),
                    ('spa', (JX, JY, .75), None), ('lawn', (9.8, -2.0, .1), None)):
    e = empty('A_' + k); e.location = loc
    if par: e.parent = par
    ANCH[k] = e

# ------------------------------------------------------------------ render
r = sc.render; cy = sc.cycles
r.engine = 'CYCLES'; cy.device = 'CPU'
cy.use_adaptive_sampling = True; cy.adaptive_threshold = .015; cy.samples = 160; cy.adaptive_min_samples = 24
cy.use_denoising = True; cy.denoiser = 'OPENIMAGEDENOISE'; cy.denoising_input_passes = 'RGB_ALBEDO_NORMAL'; cy.denoising_prefilter = 'ACCURATE'
cy.max_bounces = 8; cy.diffuse_bounces = 3; cy.glossy_bounces = 4; cy.transmission_bounces = 10; cy.volume_bounces = 1; cy.transparent_max_bounces = 12
cy.caustics_reflective = False; cy.caustics_refractive = False; cy.sample_clamp_indirect = 8; cy.blur_glossy = 1.0
cy.use_light_tree = True
r.use_persistent_data = True
sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Medium High Contrast'; sc.view_settings.exposure = 0.0
r.film_transparent = False
r.image_settings.file_format = 'PNG'; r.image_settings.color_depth = '8'
# ---------------- hierba con partículas de pelo
m, nt, b = newmat('grass'); M['grass'] = m
hi = node(nt, 'ShaderNodeHairInfo')
cr = ramp(nt, hi.outputs['Random'], [(0.0, lin(0x2f5a1b)), (0.45, lin(0x46802a)), (0.8, lin(0x5d9334)), (1.0, lin(0x8a9a45))])
grad = mix(nt, hi.outputs['Intercept'], lin(0x1d3510), cr, 'MIX')
L(nt, grad, b.inputs['Base Color']); b.inputs['Roughness'].default_value = .6; b.inputs['Specular IOR Level'].default_value = .4
tl = node(nt, 'ShaderNodeBsdfTranslucent'); L(nt, cr, tl.inputs['Color'])
mxg = node(nt, 'ShaderNodeMixShader'); mxg.inputs[0].default_value = .25; L(nt, b.outputs[0], mxg.inputs[1]); L(nt, tl.outputs[0], mxg.inputs[2])
L(nt, mxg.outputs[0], nt.nodes['Material Output'].inputs['Surface'])
lawn = bpy.data.objects['lawn']; lawn.data.materials.append(M['grass'])
# subdividir el césped para repartir mejor las partículas
bm = bmesh.new(); bm.from_mesh(lawn.data); bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=10, use_grid_fill=True); bm.to_mesh(lawn.data); bm.free()
md = lawn.modifiers.new('grass', 'PARTICLE_SYSTEM'); st = lawn.particle_systems[-1].settings
st.type = 'HAIR'; st.count = 70000; st.hair_length = .07; st.emit_from = 'FACE'; st.distribution = 'RAND'; st.use_emit_random = True
st.use_advanced_hair = True; st.normal_factor = .065; st.factor_random = .025; st.brownian_factor = 0
st.child_type = 'INTERPOLATED'; st.child_percent = 1; st.rendered_child_count = 14; st.child_radius = .08; st.child_roundness = 1
st.child_length = 1.0; st.child_length_threshold = .3; st.clump_factor = 0; st.roughness_1 = .012; st.roughness_1_size = 1; st.roughness_endpoint = .025
st.render_step = 3; st.display_step = 2; st.material = 2
st.root_radius = 1.0; st.tip_radius = 0.0; st.radius_scale = .0035; st.use_close_tip = True
print('ESCENA OK', len(bpy.data.objects), 'objetos')
