"""Villa UNIKAL en Blender/Cycles (pip install bpy==4.2.0). Ejecutar desde render3d/: python3 build.py
 Coordenadas: X derecha, Y hacia el fondo, Z arriba. Fachada principal mira a -Y."""
import bpy, bmesh, math, random, os
from mathutils import Vector, Matrix, Euler

TEX = os.environ.get('UNIKAL_TEX', os.path.join(os.getcwd(), 'tex')) + '/'
HERE = os.path.dirname(os.path.abspath(__file__))
QUICK = bool(os.environ.get('UNIKAL_QUICK'))   # sin vegetación ni césped: pruebas rápidas
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
v = objcoord(nt, 1.12); v.node.inputs['Scale'].default_value = (1 / 3.6, 1 / .9, 1 / .9)  # tablas largas en X, de unos 11 cm
t = img(nt, v, 'wood.jpg'); r = img(nt, v, 'wood_r.jpg', True)
wc0 = mix(nt, .5, t.outputs[0], lin(0x7a5638), 'MULTIPLY'); hs = node(nt, 'ShaderNodeHueSaturation'); hs.inputs['Saturation'].default_value = .72; hs.inputs['Hue'].default_value = .51; L(nt, wc0, hs.inputs['Color']); wc = hs.outputs[0]; bc = node(nt, 'ShaderNodeBrightContrast'); bc.inputs['Contrast'].default_value = .35; L(nt, wc, bc.inputs['Color']); L(nt, bc.outputs[0], b.inputs['Base Color'])
L(nt, r.outputs[0], b.inputs['Roughness']); L(nt, bump(nt, img(nt, v, 'wood.jpg', True).outputs[0], .35, .01), b.inputs['Normal'])
b.inputs['Coat Weight'].default_value = .15; b.inputs['Coat Roughness'].default_value = .2
# Gresite de piscina: teselas de vidrio de 2,5 cm (UV en metros), color por tesela, junta y cenefa en la línea de agua
def mosaic(name, palette, band_palette, band_z, water_z, sigma=(.42, .075, .05)):
    m, nt, b = newmat(name); M[name] = m
    uv = node(nt, 'ShaderNodeUVMap'); uv.uv_map = 'UVMap'
    sv = node(nt, 'ShaderNodeVectorMath'); sv.operation = 'SCALE'; sv.inputs['Scale'].default_value = 1 / .025; L(nt, uv.outputs['UV'], sv.inputs[0])
    fl = node(nt, 'ShaderNodeVectorMath'); fl.operation = 'FLOOR'; L(nt, sv.outputs[0], fl.inputs[0])
    fr = node(nt, 'ShaderNodeVectorMath'); fr.operation = 'FRACTION'; L(nt, sv.outputs[0], fr.inputs[0])
    wn = node(nt, 'ShaderNodeTexWhiteNoise'); wn.noise_dimensions = '3D'; L(nt, fl.outputs[0], wn.inputs['Vector'])
    def pal(stops):
        o = ramp(nt, wn.outputs['Value'], [(p, lin(c)) for p, c in stops]); o.node.color_ramp.interpolation = 'CONSTANT'; return o
    main, band = pal(palette), pal(band_palette)
    # cenefa: paredes (normal horizontal) por encima de band_z
    geo = node(nt, 'ShaderNodeNewGeometry'); sn = node(nt, 'ShaderNodeSeparateXYZ'); L(nt, geo.outputs['Normal'], sn.inputs[0])
    nz = node(nt, 'ShaderNodeMath'); nz.operation = 'ABSOLUTE'; L(nt, sn.outputs['Z'], nz.inputs[0])
    wall = node(nt, 'ShaderNodeMath'); wall.operation = 'LESS_THAN'; wall.inputs[1].default_value = .5; L(nt, nz.outputs[0], wall.inputs[0])
    sp = node(nt, 'ShaderNodeSeparateXYZ'); L(nt, geo.outputs['Position'], sp.inputs[0])
    hi = node(nt, 'ShaderNodeMath'); hi.operation = 'GREATER_THAN'; hi.inputs[1].default_value = band_z; L(nt, sp.outputs['Z'], hi.inputs[0])
    bm_ = node(nt, 'ShaderNodeMath'); bm_.operation = 'MULTIPLY'; L(nt, wall.outputs[0], bm_.inputs[0]); L(nt, hi.outputs[0], bm_.inputs[1])
    tile = mix(nt, bm_.outputs[0], main, band)
    # leve variación de brillo por tesela y a gran escala
    wn2 = node(nt, 'ShaderNodeTexWhiteNoise'); wn2.noise_dimensions = '4D'; wn2.inputs['W'].default_value = 3.3; L(nt, fl.outputs[0], wn2.inputs['Vector'])
    bri = node(nt, 'ShaderNodeMapRange'); bri.inputs['To Min'].default_value = .86; bri.inputs['To Max'].default_value = 1.08; L(nt, wn2.outputs['Value'], bri.inputs['Value'])
    tile = mix(nt, 1.0, tile, bri.outputs[0], 'MULTIPLY')
    big = noise(nt, uv.outputs['UV'], 1.3, 3)
    tile = mix(nt, .25, tile, big.outputs['Color'], 'OVERLAY')
    # junta
    sf = node(nt, 'ShaderNodeSeparateXYZ'); L(nt, fr.outputs[0], sf.inputs[0])
    def edge(sock):
        a = node(nt, 'ShaderNodeMath'); a.operation = 'SUBTRACT'; a.inputs[0].default_value = 1; L(nt, sock, a.inputs[1])
        mn = node(nt, 'ShaderNodeMath'); mn.operation = 'MINIMUM'; L(nt, sock, mn.inputs[0]); L(nt, a.outputs[0], mn.inputs[1]); return mn.outputs[0]
    e = node(nt, 'ShaderNodeMath'); e.operation = 'MINIMUM'; L(nt, edge(sf.outputs['X']), e.inputs[0]); L(nt, edge(sf.outputs['Y']), e.inputs[1])
    gr = node(nt, 'ShaderNodeMapRange'); gr.inputs['From Min'].default_value = .035; gr.inputs['From Max'].default_value = .075
    gr.inputs['To Min'].default_value = 1; gr.inputs['To Max'].default_value = 0; L(nt, e.outputs[0], gr.inputs['Value'])
    col = mix(nt, gr.outputs[0], tile, lin(0xd9dcd8))
    # absorción del agua: el rojo se pierde con la profundidad (ida y vuelta de la luz)
    dz = node(nt, 'ShaderNodeMath'); dz.operation = 'SUBTRACT'; dz.inputs[0].default_value = water_z; L(nt, sp.outputs['Z'], dz.inputs[1])
    dz2 = node(nt, 'ShaderNodeMath'); dz2.operation = 'MAXIMUM'; dz2.inputs[1].default_value = 0; L(nt, dz.outputs[0], dz2.inputs[0])
    cmb = node(nt, 'ShaderNodeCombineXYZ')
    for k, s_ in enumerate(sigma):
        mu = node(nt, 'ShaderNodeMath'); mu.operation = 'MULTIPLY'; mu.inputs[1].default_value = -2.4 * s_; L(nt, dz2.outputs[0], mu.inputs[0])
        ex = node(nt, 'ShaderNodeMath'); ex.operation = 'EXPONENT'; L(nt, mu.outputs[0], ex.inputs[0]); L(nt, ex.outputs[0], cmb.inputs[k])
    col = mix(nt, 1.0, col, cmb.outputs[0], 'MULTIPLY')
    L(nt, col, b.inputs['Base Color'])
    rgh = node(nt, 'ShaderNodeMapRange'); rgh.inputs['To Min'].default_value = .06; rgh.inputs['To Max'].default_value = .7; L(nt, gr.outputs[0], rgh.inputs['Value'])
    L(nt, rgh.outputs[0], b.inputs['Roughness'])
    inv = node(nt, 'ShaderNodeMath'); inv.operation = 'SUBTRACT'; inv.inputs[0].default_value = 1; L(nt, gr.outputs[0], inv.inputs[1])
    L(nt, bump(nt, inv.outputs[0], .35, .0015), b.inputs['Normal'])
    return m
mosaic('pooltile', [(0, 0x8fd0de), (.34, 0x66c0d3), (.58, 0xb7e3eb), (.78, 0x45a6c4), (.9, 0xe3f3f5)],
       [(0, 0x1f6d8a), (.45, 0x2b84a3), (.8, 0x195a74)], -.27, -.07)
mosaic('spatile', [(0, 0x9ad5e1), (.4, 0x74c6d6), (.7, 0xc4e8ee), (.88, 0x4fadc8)], [(0, 0x9ad5e1), (1, 0x9ad5e1)], 9., .6)
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
# campo mediterráneo: parcelas (Voronoi) de hierba seca, matorral y tierra, con variación interior
tc = node(nt, 'ShaderNodeTexCoord'); v = tc.outputs['Object']
wv = noise(nt, v, .004, 2); dv = node(nt, 'ShaderNodeVectorMath'); dv.operation = 'MULTIPLY_ADD'; dv.inputs[1].default_value = (35, 35, 0)
L(nt, wv.outputs['Color'], dv.inputs[0]); L(nt, v, dv.inputs[2])
vo = node(nt, 'ShaderNodeTexVoronoi'); vo.inputs['Scale'].default_value = .018; vo.inputs['Randomness'].default_value = 1; L(nt, dv.outputs[0], vo.inputs['Vector'])
parc = ramp(nt, vo.outputs['Color'], [(0, lin(0x6b6440)), (.22, lin(0x7a7047)), (.4, lin(0x55603a)), (.58, lin(0x4a5532)), (.75, lin(0x6e573d)), (.9, lin(0x80754d))])
parc.node.color_ramp.interpolation = 'CONSTANT'
n1 = noise(nt, v, .06, 6); n2 = noise(nt, v, .9, 4); n3 = noise(nt, v, 30, 2)
nf = node(nt, 'ShaderNodeMath'); nf.operation = 'MULTIPLY'; nf.inputs[1].default_value = .45; L(nt, n1.outputs['Fac'], nf.inputs[0])
c = mix(nt, nf.outputs[0], parc, lin(0x4b5134))
c = mix(nt, .3, c, ramp(nt, n2.outputs['Fac'], [(0.35, lin(0x56553a)), (0.65, lin(0x76704c))]), 'MIX')
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
# Agua: superficie refractiva de verdad (las olas son geometría) y volumen que absorbe el rojo.
# Sin trucos de sombra: la luz del sol atraviesa la superficie con "shadow caustics" (MNEE) y dibuja las cáusticas.
# (Cycles no calcula estas cáusticas del sol si hay un volumen en el camino: la absorción del agua va en el gresite, según la profundidad.)
def watermat(name, tint):
    m, nt, b = newmat(name); M[name] = m
    b.inputs['Base Color'].default_value = tint; b.inputs['Transmission Weight'].default_value = 1
    b.inputs['Roughness'].default_value = .0; b.inputs['IOR'].default_value = 1.333
watermat('water', (.9, .985, 1, 1))
watermat('spawater', (.92, .99, 1, 1))
# Espuma y burbujas del jacuzzi
m, nt, b = newmat('foam'); M['foam'] = m
b.inputs['Base Color'].default_value = lin(0xf4f8f8); b.inputs['Roughness'].default_value = .25
b.inputs['Subsurface Weight'].default_value = .4; b.inputs['Subsurface Radius'].default_value = (.02, .02, .02); b.inputs['Coat Weight'].default_value = .6
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
def planar_uv(ob, cyl=None):
    """UV en metros según la orientación de cada cara (cilíndricas en las paredes del jacuzzi)."""
    me = ob.data; uvl = me.uv_layers.new(name='UVMap')
    for p in me.polygons:
        n = p.normal; lis = list(p.loop_indices); cos = [me.vertices[me.loops[li].vertex_index].co for li in lis]
        if abs(n.z) > .5: uvs = [(c.x, c.y) for c in cos]
        elif cyl:
            ang = [math.atan2(c.y - cyl[1], c.x - cyl[0]) for c in cos]
            if max(ang) - min(ang) > math.pi: ang = [a + 2 * math.pi if a < 0 else a for a in ang]
            uvs = [(a * cyl[2], c.z) for a, c in zip(ang, cos)]
        elif abs(n.x) > .5: uvs = [(c.y, c.z) for c in cos]
        else: uvs = [(c.x, c.z) for c in cos]
        for li, uv in zip(lis, uvs): uvl.data[li].uv = uv
def water_sheet(name, mat, x0, x1, y0, y1, z, step, keep=None):
    """Superficie del agua: rejilla fina que render.py ondula en cada fotograma (olas.py).
    Se mete unos centímetros dentro de las paredes: fondo y paredes quedan dentro del volumen del agua."""
    import numpy as np
    nx = int(round((x1 - x0) / step)); ny = int(round((y1 - y0) / step))
    X, Y = np.meshgrid(np.linspace(x0, x1, nx + 1), np.linspace(y0, y1, ny + 1))
    V = np.stack([X.ravel(), Y.ravel(), np.full(X.size, z)], 1)
    idx = np.arange(X.size).reshape(ny + 1, nx + 1)
    F = np.stack([idx[:-1, :-1], idx[:-1, 1:], idx[1:, 1:], idx[1:, :-1]], -1).reshape(-1, 4)
    if keep is not None:
        c = V[F].mean(1); F = F[keep(c[:, 0], c[:, 1])]
        used = np.unique(F); remap = np.full(len(V), -1); remap[used] = np.arange(len(used)); V = V[used]; F = remap[F]
    me = bpy.data.meshes.new(name); me.from_pydata(V.tolist(), [], F.tolist()); me.update()
    me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
    ob = bpy.data.objects.new(name, me); COL.objects.link(ob); me.materials.append(M[mat])
    ob['wave_z'] = z; ob.cycles.is_caustics_caster = True
    return ob
pool_ob = mb.obj('pool', 'pooltile', 0, recalc=False); planar_uv(pool_ob); pool_ob.cycles.is_caustics_receiver = True
water_sheet('water', 'water', PX0 - .03, PX1 + .03, PY0 - .03, PY1 + .03, -.07, .015)
mb = MB(); mb.box(-3.4, 9.4, -9.2, -8.8, 0, .07); mb.box(-3.4, 9.4, -4.4, -4.0, 0, .07); mb.box(-3.4, -3.0, -8.8, -4.4, 0, .07); mb.box(9.0, 9.4, -8.8, -4.4, 0, .07)
mb.obj('coping', 'tile', .012)
mb = MB()
for i in range(6): mb.cbox(-2 + i * 2, -4.42, -.45, .13, .01, .13)
mb.obj('leds', 'led', 0)
mb = MB(); mb.box(-9.8, -3.4, -11.6, -4.0, 0, .08); mb.box(-3.4, 9.4, -11.6, -9.2, 0, .08); mb.obj('deck', 'wood', .004)
# Jacuzzi elevado
JX, JY = -6.4, -7.2
mb = MB(); n = 160
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
mb.obj('spa', 'render', .01, recalc=False)
spain = mi.obj('spain', 'spatile', 0, recalc=False); planar_uv(spain, (JX, JY, 1.2)); spain.cycles.is_caustics_receiver = True
water_sheet('spawater', 'spawater', JX - 1.26, JX + 1.26, JY - 1.26, JY + 1.26, .6, .012, keep=lambda x, y: (x - JX) ** 2 + (y - JY) ** 2 < 1.225 ** 2)
# burbujas y espuma: render.py las coloca en cada fotograma
fo = bpy.data.objects.new('spafoam', bpy.data.meshes.new('spafoam')); COL.objects.link(fo); fo.data.materials.append(M['foam'])
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
NEIGH = [(-48, 40, 12, 9), (40, 55, 14, 10), (-72, -8, 10, 8), (66, 8, 12, 9), (12, 78, 16, 10), (-30, 85, 12, 8), (90, 60, 12, 9), (-60, -60, 12, 9), (55, -55, 14, 9), (-95, 30, 12, 9)]
if not QUICK: exec(open(os.path.join(HERE, 'vegetacion.py')).read())
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
sun_d.cycles.is_caustics_light = True
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
pl = bpy.data.lights.new('poollight', 'POINT'); pl.energy = 0; pl.color = (.55, .95, 1); pl.shadow_soft_size = 2.5
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
cy.use_adaptive_sampling = True; cy.adaptive_threshold = .03; cy.samples = 160; cy.adaptive_min_samples = 8
cy.use_denoising = True; cy.denoiser = 'OPENIMAGEDENOISE'; cy.denoising_input_passes = 'RGB_ALBEDO_NORMAL'; cy.denoising_prefilter = 'ACCURATE'
cy.max_bounces = 8; cy.diffuse_bounces = 2; cy.glossy_bounces = 2; cy.transmission_bounces = 6; cy.volume_bounces = 1; cy.transparent_max_bounces = 8
cy.caustics_reflective = False; cy.caustics_refractive = True; cy.sample_clamp_indirect = 8; cy.blur_glossy = 1.0
cy.use_light_tree = True
r.use_persistent_data = True
sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Medium High Contrast'; sc.view_settings.exposure = 0.0
r.film_transparent = False
r.image_settings.file_format = 'PNG'; r.image_settings.color_depth = '8'
# ---------------- hierba con partículas de pelo
if not QUICK:
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
