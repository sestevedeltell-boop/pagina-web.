"""Villa UNIKAL en Blender/Cycles (pip install bpy==4.2.0). Ejecutar desde render3d/: python3 build.py
 Coordenadas: X derecha, Y hacia el fondo, Z arriba. Fachada principal mira a -Y."""
import bpy, bmesh, math, random, os
from mathutils import Vector, Matrix, Euler

TEX = os.environ.get('UNIKAL_TEX', os.path.join(os.getcwd(), 'tex')) + '/'
HERE = os.path.dirname(os.path.abspath(__file__))
QUICK = bool(os.environ.get('UNIKAL_QUICK'))   # sin vegetación ni césped: pruebas rápidas
PH = os.path.join(HERE, 'ph') + '/'            # recursos de Poly Haven (python3 polyhaven.py)
HAVE_PH = os.path.exists(PH + 'sky.hdr') and not os.environ.get('UNIKAL_NO_PH')
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

def pbr(nt, b, name, size, tint=None, tint_fac=1., nstr=1., rough=None, scale=None, sat=None, val=None, ao=0., disp=0., gain=None):
    """Textura PBR de Poly Haven (color, normal, rugosidad) en coordenadas de objeto, proyección en caja.
    sat/val: saturación y brillo del color; gain: multiplica el color (aclara texturas oscuras);
    ao: peso de la oclusión (mapa _ao); disp: relieve del mapa _disp en metros."""
    tc = node(nt, 'ShaderNodeTexCoord'); mp = node(nt, 'ShaderNodeMapping')
    mp.inputs['Scale'].default_value = scale or (1 / size,) * 3; L(nt, tc.outputs['Object'], mp.inputs['Vector'])
    def tex(suffix, noncolor):
        n = node(nt, 'ShaderNodeTexImage'); n.image = bpy.data.images.load(PH + '%s_%s.jpg' % (name, suffix), check_existing=True)
        n.projection = 'BOX'; n.projection_blend = .25
        if noncolor: n.image.colorspace_settings.name = 'Non-Color'
        L(nt, mp.outputs[0], n.inputs['Vector']); return n
    d = tex('diff', False).outputs[0]
    if sat is not None or val is not None:
        hs_ = node(nt, 'ShaderNodeHueSaturation'); hs_.inputs['Saturation'].default_value = 1. if sat is None else sat
        hs_.inputs['Value'].default_value = 1. if val is None else val; L(nt, d, hs_.inputs['Color']); d = hs_.outputs[0]
    if gain: d = mix(nt, 1.0, d, (gain, gain, gain, 1.), 'MULTIPLY')
    col = mix(nt, tint_fac, d, lin(tint), 'MULTIPLY') if tint is not None else d
    if ao: col = mix(nt, ao, col, tex('ao', True).outputs[0], 'MULTIPLY')
    L(nt, col, b.inputs['Base Color'])
    rg = tex('rough', True).outputs[0]
    if rough:
        mr = node(nt, 'ShaderNodeMapRange'); mr.inputs['To Min'].default_value, mr.inputs['To Max'].default_value = rough; L(nt, rg, mr.inputs['Value']); rg = mr.outputs[0]
    L(nt, rg, b.inputs['Roughness'])
    nm = node(nt, 'ShaderNodeNormalMap'); nm.inputs['Strength'].default_value = nstr; L(nt, tex('nor', True).outputs[0], nm.inputs['Color'])
    nrm = nm.outputs[0]
    if disp: nrm = bump(nt, tex('disp', True).outputs[0], 1., disp, nrm)
    L(nt, nrm, b.inputs['Normal'])
    return d

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
if HAVE_PH:   # revoco: relieve y rugosidad reales, color blanco con un leve matiz de la textura
    d = pbr(nt, b, 'rough_plaster_03', 1.1, nstr=1.3, rough=(.8, .97))   # revoco fratasado: relieve que se ve con el sol rasante
    bw = node(nt, 'ShaderNodeRGBToBW'); L(nt, d, bw.inputs[0])
    vr_ = node(nt, 'ShaderNodeMapRange'); vr_.inputs['From Min'].default_value = .45; vr_.inputs['From Max'].default_value = .75
    vr_.inputs['To Min'].default_value = .9; vr_.inputs['To Max'].default_value = 1.03; L(nt, bw.outputs[0], vr_.inputs['Value'])
    col = mix(nt, 1.0, col, vr_.outputs[0], 'MULTIPLY')
    geo_ = node(nt, 'ShaderNodeNewGeometry'); spz = node(nt, 'ShaderNodeSeparateXYZ'); L(nt, geo_.outputs['Position'], spz.inputs[0])
    dz = node(nt, 'ShaderNodeMapRange'); dz.inputs['From Min'].default_value = .05; dz.inputs['From Max'].default_value = .75
    dz.inputs['To Min'].default_value = 1; dz.inputs['To Max'].default_value = 0; L(nt, spz.outputs['Z'], dz.inputs['Value'])
    dn = noise(nt, geo_.outputs['Position'], 6, 5, .6); dd = node(nt, 'ShaderNodeMath'); dd.operation = 'MULTIPLY'; L(nt, dz.outputs[0], dd.inputs[0]); L(nt, dn.outputs['Fac'], dd.inputs[1])
    dd2 = node(nt, 'ShaderNodeMath'); dd2.operation = 'MULTIPLY'; dd2.inputs[1].default_value = .22; L(nt, dd.outputs[0], dd2.inputs[0])
    col = mix(nt, dd2.outputs[0], col, lin(0x8a7f6c))
    L(nt, col, b.inputs['Base Color'])
else:
    L(nt, col, b.inputs['Base Color']); b.inputs['Roughness'].default_value = .88
    L(nt, bump(nt, n2.outputs['Fac'], .06, .01), b.inputs['Normal'])
# Piedra en lajas
m, nt, b = newmat('stone'); M['stone'] = m
v = objcoord(nt, 3.0); t = img(nt, v, 'stone.jpg'); tn = img(nt, v, 'stone.jpg', True)
L(nt, mix(nt, .15, t.outputs[0], lin(0xb8ab94), 'MULTIPLY'), b.inputs['Base Color'])
b.inputs['Roughness'].default_value = .92; L(nt, bump(nt, tn.outputs[0], .5, .02), b.inputs['Normal'])
if HAVE_PH and os.path.exists(PH + 'stacked_stone_wall_diff.jpg'):
    # lajas de piedra natural apiladas: foto real con su oclusión entre piedras y relieve
    m, nt, b = newmat('stone'); M['stone'] = m
    # (la foto es oscura y rojiza: se desatura y se aclara hasta una caliza clara, gris cálido)
    pbr(nt, b, 'stacked_stone_wall', 1.6, tint=0xf7efe2, nstr=1.3, rough=(.78, .97), sat=.28, gain=3.3, ao=.6, disp=.03)
# Porcelánico exterior
m, nt, b = newmat('tile'); M['tile'] = m
v = objcoord(nt, 2.4); t = img(nt, v, 'tile.jpg'); L(nt, t.outputs[0], b.inputs['Base Color'])
b.inputs['Roughness'].default_value = .38; L(nt, bump(nt, img(nt, v, 'tile.jpg', True).outputs[0], .15, .005), b.inputs['Normal'])
def tile_joints(nt, b, tw, th, gap, tone=(.95, 1.04)):
    """Juntas de piezas rectangulares (coordenadas de objeto X/Y) y tono distinto por pieza."""
    tcj = node(nt, 'ShaderNodeTexCoord'); spj = node(nt, 'ShaderNodeSeparateXYZ'); L(nt, tcj.outputs['Object'], spj.inputs[0])
    def m_(op, a, b_=None):
        n_ = node(nt, 'ShaderNodeMath'); n_.operation = op
        for k_, x_ in enumerate((a, b_)):
            if x_ is None: continue
            if isinstance(x_, (int, float)): n_.inputs[k_].default_value = x_
            else: L(nt, x_, n_.inputs[k_])
        return n_.outputs[0]
    xr = m_('DIVIDE', spj.outputs['X'], tw); yr = m_('DIVIDE', spj.outputs['Y'], th)
    fx, fy = m_('FRACT', xr), m_('FRACT', yr)
    ex = m_('MULTIPLY', m_('MINIMUM', fx, m_('SUBTRACT', 1., fx)), tw); ey = m_('MULTIPLY', m_('MINIMUM', fy, m_('SUBTRACT', 1., fy)), th)
    e = m_('MINIMUM', ex, ey)
    jm = node(nt, 'ShaderNodeMapRange'); jm.inputs['From Min'].default_value = gap * .5; jm.inputs['From Max'].default_value = gap * .5 + .002; L(nt, e, jm.inputs['Value'])
    cmbj = node(nt, 'ShaderNodeCombineXYZ'); L(nt, m_('FLOOR', xr), cmbj.inputs[0]); L(nt, m_('FLOOR', yr), cmbj.inputs[1])
    wnj = node(nt, 'ShaderNodeTexWhiteNoise'); wnj.noise_dimensions = '3D'; L(nt, cmbj.outputs[0], wnj.inputs['Vector'])
    tn = node(nt, 'ShaderNodeMapRange'); tn.inputs['To Min'].default_value, tn.inputs['To Max'].default_value = tone; L(nt, wnj.outputs['Value'], tn.inputs['Value'])
    sh = node(nt, 'ShaderNodeMapRange'); sh.inputs['To Min'].default_value = .55; L(nt, jm.outputs[0], sh.inputs['Value'])
    src = b.inputs['Base Color'].links[0].from_socket
    c_ = mix(nt, 1.0, src, tn.outputs[0], 'MULTIPLY'); c_ = mix(nt, 1.0, c_, sh.outputs[0], 'MULTIPLY'); L(nt, c_, b.inputs['Base Color'])
    nsrc = b.inputs['Normal'].links[0].from_socket if b.inputs['Normal'].links else None
    bp = node(nt, 'ShaderNodeBump'); bp.inputs['Strength'].default_value = .5; bp.inputs['Distance'].default_value = .002; L(nt, jm.outputs[0], bp.inputs['Height'])
    if nsrc is not None: L(nt, nsrc, bp.inputs['Normal'])
    L(nt, bp.outputs[0], b.inputs['Normal'])
tile_joints(nt, b, 1.2, .6, .004)
# Tarima de ipe
m, nt, b = newmat('wood'); M['wood'] = m
v = objcoord(nt, 1.12); v.node.inputs['Scale'].default_value = (1 / 3.6, 1 / .9, 1 / .9)  # tablas largas en X, de unos 11 cm
t = img(nt, v, 'wood.jpg'); r = img(nt, v, 'wood_r.jpg', True)
wc0 = mix(nt, .5, t.outputs[0], lin(0x7a5638), 'MULTIPLY'); hs = node(nt, 'ShaderNodeHueSaturation'); hs.inputs['Saturation'].default_value = .72; hs.inputs['Hue'].default_value = .51; L(nt, wc0, hs.inputs['Color']); wc = hs.outputs[0]; bc = node(nt, 'ShaderNodeBrightContrast'); bc.inputs['Contrast'].default_value = .35; L(nt, wc, bc.inputs['Color']); L(nt, bc.outputs[0], b.inputs['Base Color'])
L(nt, r.outputs[0], b.inputs['Roughness']); L(nt, bump(nt, img(nt, v, 'wood.jpg', True).outputs[0], .35, .01), b.inputs['Normal'])
b.inputs['Coat Weight'].default_value = .15; b.inputs['Coat Roughness'].default_value = .2
if HAVE_PH:
    # tarima: veta real de roble teñida a teca, con tablas de 14 cm, juntas, testas y tono distinto por tabla
    m, nt, b = newmat('wood'); M['wood'] = m
    pbr(nt, b, 'oak_wood_planks', 1.2, tint=0xb8977a, tint_fac=1., nstr=.6, rough=(.35, .75), scale=(1 / 2.2, 1 / .62, 1 / .62))
    b.inputs['Coat Weight'].default_value = .1; b.inputs['Coat Roughness'].default_value = .25
    PW, PL = .14, 2.4
    tcw = node(nt, 'ShaderNodeTexCoord'); sw = node(nt, 'ShaderNodeSeparateXYZ'); L(nt, tcw.outputs['Object'], sw.inputs[0])
    def mth(op, a, b_=None, v=None):
        n_ = node(nt, 'ShaderNodeMath'); n_.operation = op
        for k_, x_ in enumerate((a, b_)):
            if x_ is None: continue
            if isinstance(x_, (int, float)): n_.inputs[k_].default_value = x_
            else: L(nt, x_, n_.inputs[k_])
        return n_.outputs[0]
    yr = mth('DIVIDE', sw.outputs['Y'], PW); row = mth('FLOOR', yr); fy = mth('FRACT', yr)
    ey = mth('MINIMUM', fy, mth('SUBTRACT', 1., fy))
    wn = node(nt, 'ShaderNodeTexWhiteNoise'); wn.noise_dimensions = '1D'; L(nt, row, wn.inputs['W'])
    xr = mth('DIVIDE', mth('ADD', sw.outputs['X'], mth('MULTIPLY', wn.outputs['Value'], PL)), PL); seg = mth('FLOOR', xr); fx = mth('FRACT', xr)
    ex = mth('MINIMUM', fx, mth('SUBTRACT', 1., fx))
    gy = node(nt, 'ShaderNodeMapRange'); gy.inputs['From Min'].default_value = .025; gy.inputs['From Max'].default_value = .06; L(nt, ey, gy.inputs['Value'])
    gx = node(nt, 'ShaderNodeMapRange'); gx.inputs['From Min'].default_value = .0012; gx.inputs['From Max'].default_value = .003; L(nt, ex, gx.inputs['Value'])
    seam = mth('MINIMUM', gy.outputs[0], gx.outputs[0])
    wn2 = node(nt, 'ShaderNodeTexWhiteNoise'); wn2.noise_dimensions = '2D'; cmb_ = node(nt, 'ShaderNodeCombineXYZ'); L(nt, row, cmb_.inputs[0]); L(nt, seg, cmb_.inputs[1]); L(nt, cmb_.outputs[0], wn2.inputs['Vector'])
    tone = node(nt, 'ShaderNodeMapRange'); tone.inputs['To Min'].default_value = .82; tone.inputs['To Max'].default_value = 1.12; L(nt, wn2.outputs['Value'], tone.inputs['Value'])
    shade = node(nt, 'ShaderNodeMapRange'); shade.inputs['To Min'].default_value = .25; L(nt, seam, shade.inputs['Value'])
    base_link = b.inputs['Base Color'].links[0].from_socket
    col = mix(nt, 1.0, base_link, tone.outputs[0], 'MULTIPLY'); col = mix(nt, 1.0, col, shade.outputs[0], 'MULTIPLY'); L(nt, col, b.inputs['Base Color'])
    nmn = b.inputs['Normal'].links[0].from_socket
    bp = node(nt, 'ShaderNodeBump'); bp.inputs['Strength'].default_value = .6; bp.inputs['Distance'].default_value = .004
    L(nt, seam, bp.inputs['Height']); L(nt, nmn, bp.inputs['Normal']); L(nt, bp.outputs[0], b.inputs['Normal'])
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
# Base del césped (lo que asoma entre las briznas): verde oscuro con mantillo y tierra
m, nt, b = newmat('lawn'); M['lawn'] = m
tc = node(nt, 'ShaderNodeTexCoord'); v = tc.outputs['Object']
n1 = noise(nt, v, .25, 5); n3 = noise(nt, v, 180, 2)
base = ramp(nt, n1.outputs['Fac'], [(0.3, lin(0x2a3b19)), (0.6, lin(0x384c21)), (0.8, lin(0x48552a))])
c3 = mix(nt, n3.outputs['Fac'], base, lin(0x3a3223), 'MIX'); fin = mix(nt, .35, base, c3, 'MIX'); L(nt, fin, b.inputs['Base Color'])
if HAVE_PH:
    d = pbr(nt, b, 'grass_ground', 2.5, nstr=.8)
    L(nt, mix(nt, .55, fin, d, 'MULTIPLY'), b.inputs['Base Color'])
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
parc = ramp(nt, vo.outputs['Color'], [(0, lin(0x2f3a1d)), (.22, lin(0x3a4722)), (.4, lin(0x2a3419)), (.58, lin(0x434d2c)), (.75, lin(0x3b3224)), (.9, lin(0x48502e))])
parc.node.color_ramp.interpolation = 'CONSTANT'
n1 = noise(nt, v, .06, 6); n2 = noise(nt, v, .9, 4); n3 = noise(nt, v, 30, 2)
nf = node(nt, 'ShaderNodeMath'); nf.operation = 'MULTIPLY'; nf.inputs[1].default_value = .45; L(nt, n1.outputs['Fac'], nf.inputs[0])
c = mix(nt, nf.outputs[0], parc, lin(0x45522a))
c = mix(nt, .25, c, ramp(nt, n2.outputs['Fac'], [(0.35, lin(0x55552f)), (0.65, lin(0x7a7040))]), 'MIX')
if HAVE_PH:
    d = pbr(nt, b, 'aerial_grass_rock', 15.0, nstr=.7)
    c = mix(nt, .55, c, d, 'OVERLAY')
haze(nt, c, b, 2600.); b.inputs['Roughness'].default_value = 1
L(nt, bump(nt, n3.outputs['Fac'], .5, .05), b.inputs['Normal'])
m, nt, b = newmat('hills'); M['hills'] = m
tc = node(nt, 'ShaderNodeTexCoord'); n1 = noise(nt, tc.outputs['Object'], .01, 5); n2 = noise(nt, tc.outputs['Object'], .12, 6, .7)
c = ramp(nt, n1.outputs['Fac'], [(0.4, lin(0x2c3b1e)), (0.6, lin(0x3a4a26))]); c = mix(nt, n2.outputs['Fac'], lin(0x1c2814), c); haze(nt, c, b, 2200.)   # montes con bosque, algo azulados por la distancia
L(nt, bump(nt, n2.outputs['Fac'], 1.0, 2.0), b.inputs['Normal'])
b.inputs['Roughness'].default_value = 1
# Vidrio (deja pasar la luz para sombras: interiores iluminados)
def glassmat(name, tint=0xf2f6f5, rough=0., coat=0.):
    """Vidrio. coat: IOR de la capa reflectante (control solar / bajo emisivo) en la cara exterior; 0 = vidrio simple."""
    m, nt, b = newmat(name); M[name] = m
    b.inputs['Base Color'].default_value = lin(tint); b.inputs['Transmission Weight'].default_value = 1
    b.inputs['Roughness'].default_value = rough; b.inputs['IOR'].default_value = 1.52 if coat else 1.45
    surf = b.outputs[0]
    if coat:
        # reflejo extra según Fresnel solo al entrar (por la cara de atrás sería reflexión total y oscurecería)
        fr = node(nt, 'ShaderNodeFresnel'); fr.inputs['IOR'].default_value = coat
        geo = node(nt, 'ShaderNodeNewGeometry'); fm = node(nt, 'ShaderNodeMath'); fm.operation = 'MULTIPLY'
        inv = node(nt, 'ShaderNodeMath'); inv.operation = 'SUBTRACT'; inv.inputs[0].default_value = 1; L(nt, geo.outputs['Backfacing'], inv.inputs[1])
        L(nt, fr.outputs[0], fm.inputs[0]); L(nt, inv.outputs[0], fm.inputs[1])
        gl = node(nt, 'ShaderNodeBsdfGlossy'); gl.distribution = 'GGX'; gl.inputs['Roughness'].default_value = .015
        gl.inputs['Color'].default_value = lin(0xe9eef0)
        mc = node(nt, 'ShaderNodeMixShader'); L(nt, fm.outputs[0], mc.inputs[0]); L(nt, b.outputs[0], mc.inputs[1]); L(nt, gl.outputs[0], mc.inputs[2])
        surf = mc.outputs[0]
    lp = node(nt, 'ShaderNodeLightPath'); tr = node(nt, 'ShaderNodeBsdfTransparent'); tr.inputs[0].default_value = lin(0xe8efed)
    mx = node(nt, 'ShaderNodeMixShader'); out = nt.nodes['Material Output']
    L(nt, lp.outputs['Is Shadow Ray'], mx.inputs[0]); L(nt, surf, mx.inputs[1]); L(nt, tr.outputs[0], mx.inputs[2]); L(nt, mx.outputs[0], out.inputs['Surface'])
glassmat('glass', 0xdbe5e2, coat=2.3)
glassmat('tglass')   # vasos y jarra
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
def linen(name, tint):
    m, nt, b = newmat(name); M[name] = m
    if HAVE_PH:
        pbr(nt, b, 'rough_linen', .27, nstr=.6, rough=(.8, 1.))
        bw = node(nt, 'ShaderNodeRGBToBW'); L(nt, b.inputs['Base Color'].links[0].from_socket, bw.inputs[0])
        mr = node(nt, 'ShaderNodeMapRange'); mr.inputs['From Min'].default_value = .3; mr.inputs['From Max'].default_value = .7
        mr.inputs['To Min'].default_value = .88; mr.inputs['To Max'].default_value = 1.06; L(nt, bw.outputs[0], mr.inputs['Value'])
        L(nt, mix(nt, 1.0, lin(tint), mr.outputs[0], 'MULTIPLY'), b.inputs['Base Color'])
    else:
        b.inputs['Base Color'].default_value = lin(tint); b.inputs['Roughness'].default_value = .95
    b.inputs['Sheen Weight'].default_value = .4; b.inputs['Specular IOR Level'].default_value = .2
linen('fabric', 0x8e8a84); linen('fabriclight', 0xe9e3d7); linen('blue', 0x7d92a8); linen('canvas', 0xe6decf)
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

def soft(ob, w=.03, segs=3):
    """Bordes redondeados de verdad (cojines, colchonetas): bisel con normales endurecidas y sombreado suave."""
    for md in list(ob.modifiers):
        if md.type == 'BEVEL': ob.modifiers.remove(md)
    md = ob.modifiers.new('bev', 'BEVEL'); md.width = w; md.segments = segs; md.limit_method = 'ANGLE'; md.use_clamp_overlap = True; md.harden_normals = True
    for p in ob.data.polygons: p.use_smooth = True
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
# Salón: sofá modular en L con cojines, alfombra de lana, mesas de centro de piedra, mueble de TV volado con luz
FZB = .31
def _bx(name, mat, bx, bev=0., softw=0., segs=3, par=None):
    m_ = MB()
    for q in bx: m_.box(*q)
    o_ = m_.obj(name, mat, bev, par or G_BASE)
    return soft(o_, softw, segs) if softw else o_
linen('rug', 0xc8bfae); linen('pillowgreen', 0x8a9178); linen('throwtan', 0xb59a7a)
_bx('sofabase', 'darkwood', [(-4.1, .9, 5.82, 6.75, FZB, FZB + .1), (-5.1, -4.1, 4.05, 6.75, FZB, FZB + .1)], .008)
_bx('sofa', 'fabric', [(-4.1 + k * 1.25 + .01, -4.1 + (k + 1) * 1.25 - .01, 5.8, 6.5, FZB + .1, FZB + .29) for k in range(4)] +
    [(-5.08, -4.12, 4.05, 5.76, FZB + .1, FZB + .29), (-5.08, -4.12, 5.78, 6.5, FZB + .1, FZB + .29)], softw=.06, segs=4)
_bx('sofaback', 'fabric', [(-4.1 + k * 1.25 + .01, -4.1 + (k + 1) * 1.25 - .01, 6.5, 6.75, FZB + .29, FZB + .78) for k in range(4)] + [(-5.08, -4.12, 6.5, 6.75, FZB + .29, FZB + .78)], softw=.07, segs=4)
_bx('sofaarm', 'fabric', [(.72, .92, 5.8, 6.75, FZB + .1, FZB + .55)], softw=.05, segs=4)
for i_, (x_, y_, mat_, rz) in enumerate(((-3.3, 6.32, 'fabriclight', .15), (-2.85, 6.3, 'pillowgreen', -.1), (-.2, 6.32, 'fabriclight', -.2), (-4.65, 6.3, 'blue', .3), (.3, 6.3, 'throwtan', .1))):
    m_ = MB(); m_.cbox(0, 0, 0, .5, .14, .48); o_ = soft(m_.obj('cushion%d' % i_, mat_, 0, G_BASE), .07, 4)
    o_.location = (x_, y_, FZB + .53); o_.rotation_euler = (math.radians(-14), 0, rz)
_bx('rug', 'rug', [(-4.6, .6, 3.4, 6.1, FZB, FZB + .012)])
simple('stoneblanco', 0xe2dbce, .35, coat=.25)
m_ = MB(); m_.cyl(-2.15, 4.55, FZB, FZB + .36, .58, 48); m_.cyl(-1.25, 4.05, FZB, FZB + .28, .4, 40); soft(m_.obj('coffee', 'stoneblanco', 0, G_BASE), .015, 2)
_bx('coffeebooks', 'darkwood', [(-2.45, -2.05, 4.45, 4.75, FZB + .36, FZB + .4)], .004); _bx('coffeebooks2', 'fabriclight', [(-2.42, -2.08, 4.47, 4.73, FZB + .4, FZB + .43)], .004)
m_ = MB(); m_.cyl(-1.85, 4.62, FZB + .36, FZB + .62, .07, 20, r2=.04); soft(m_.obj('vase', 'black', 0, G_BASE), .01, 2)
_bx('tvunit', 'darkwood', [(-3.6, .4, 2.12, 2.58, FZB + .25, FZB + .62)], .008)
m, nt, b = newmat('ledwarm'); M['ledwarm'] = m; b.inputs['Base Color'].default_value = lin(0xffd2a0); b.inputs['Emission Color'].default_value = lin(0xffc58a); b.inputs['Emission Strength'].default_value = 7.
_bx('tvled', 'ledwarm', [(-3.5, .3, 2.2, 2.5, FZB + .245, FZB + .25)])
simple('tvback', 0x121212, .55)
_bx('tv', 'tv', [(-2.45, -.75, 2.385, 2.41, FZB + 1.0, FZB + 1.96)], .004); _bx('tvbackp', 'tvback', [(-2.42, -.78, 2.36, 2.386, FZB + 1.03, FZB + 1.93)], .004)
_bx('tvstand', 'black', [(-1.65, -1.55, 2.4, 2.46, FZB + .62, FZB + 1.0)])
_bx('tvdecor', 'stoneblanco', [(-.2, .05, 2.25, 2.45, FZB + .62, FZB + .9)], softw=.02)
m_ = MB(); m_.cyl(-5.2, 1.85, FZB, .63, .26, 28, r2=.3); m_.cyl(3.6, 1.65, FZB, .63, .26, 28, r2=.3); soft(m_.obj('salonpots', 'concrete', 0, G_BASE), .01, 2)
mb = MB(); mb.cbox(2.6, 5.2, 1.07, 2.6, 1.1, .06); mb.obj('table', 'oak', .01, G_BASE)
fr_, cu_, bk_ = MB(), MB(), MB()
for i in range(3):
    for s in (-1, 1):
        cx, cy = 1.7 + i * .9, 5.2 - s * .85
        for dx in (-.2, .2):
            for dy in (-.2, .2): fr_.box(cx + dx - .012, cx + dx + .012, cy + dy - .012, cy + dy + .012, .31, .74)
        fr_.box(cx - .23, cx + .23, cy - .23, cy + .23, .72, .74)
        cu_.box(cx - .225, cx + .225, cy - .225, cy + .225, .74, .8); bk_.box(cx - .22, cx + .22, cy - s * .23 - .03, cy - s * .23 + .03, .78, 1.2)
fr_.obj('chairframes', 'black', .004, G_BASE); soft(cu_.obj('chairs', 'fabriclight', 0, G_BASE), .025, 3); soft(bk_.obj('chairbacks', 'fabric', 0, G_BASE), .025, 3)
mb = MB(); mb.cbox(1.5, 5.2, .68, .1, .9, .72); mb.cbox(3.7, 5.2, .68, .1, .9, .72)
for i in range(3): mb.cyl(1.8 + i * .8, 5.2, 2.12, 3.6, .004, 6)
mb.obj('legs', 'black', 0, G_BASE)
simple('pendmetal', 0x1c1c1c, .35, .8)
mb = MB(); ml_ = MB()
for i in range(3):
    px_ = 1.8 + i * .8; n_ = 32; rings_ = []
    for k in range(9):
        a_ = k / 8 * math.pi / 2; rr2 = .2 * math.sin(a_) + .012; zz = 2.12 - .2 * (1 - math.cos(a_))
        rings_.append([mb.bm.verts.new((px_ + rr2 * math.cos(t_), 5.2 + rr2 * math.sin(t_), zz)) for t_ in [j / n_ * 2 * math.pi for j in range(n_)]])
    for k in range(8):
        for j in range(n_): mb.bm.faces.new((rings_[k][j], rings_[k][(j + 1) % n_], rings_[k + 1][(j + 1) % n_], rings_[k + 1][j]))
    ml_.cyl(px_, 5.2, 1.935, 1.94, .19, 32)
soft(mb.obj('pendants', 'pendmetal', 0, G_BASE, recalc=False), .0, 1); ml_.obj('pendlight', 'lamp', 0, G_BASE)
for i in range(3):
    pl_ = bpy.data.lights.new('pend%d' % i, 'POINT'); pl_.energy = 22; pl_.shadow_soft_size = .06; pl_.color = (1, .78, .55)
    po_ = bpy.data.objects.new('pend%d' % i, pl_); po_.location = (1.8 + i * .8, 5.2, 1.98); po_.parent = G_BASE; COL.objects.link(po_)
mb = MB(); mb.cbox(2.4, 2.9, .76, 3.2, 1.0, .92); mb.cbox(2.85, 6.75, 1.6, 2.3, .6, 2.6); mb.obj('kitchen', 'lacquer', .015, G_BASE)
mb = MB()
for k in range(1, 4): mb.box(.8 + k * .8 - .003, .8 + k * .8 + .003, 2.395, 2.4, .32, 1.2)
for k in range(1, 3): mb.box(1.7 + k * .77 - .003, 1.7 + k * .77 + .003, 6.445, 6.45, .32, 2.88)
mb.obj('kitchenseams', 'darkwood', 0, G_BASE)
m, nt, b = newmat('quartz'); M['quartz'] = m
tcq = node(nt, 'ShaderNodeTexCoord'); nq = noise(nt, tcq.outputs['Object'], 1.8, 8, .62); nq.inputs['Distortion'].default_value = 2.5
vq = ramp(nt, nq.outputs['Fac'], [(0.0, lin(0xf2f0ec)), (.47, lin(0xf2f0ec)), (.5, lin(0xa8a6a2)), (.53, lin(0xf2f0ec)), (1.0, lin(0xebe8e3))])
L(nt, vq, b.inputs['Base Color']); b.inputs['Roughness'].default_value = .12; b.inputs['Coat Weight'].default_value = .4
mb = MB(); mb.cbox(2.4, 2.9, 1.24, 3.4, 1.1, .04); mb.obj('counter', 'quartz', .005, G_BASE)
mb = MB(); mb.cyl(2.4, 3.25, 1.26, 1.6, .016, 12); mb.box(2.385, 2.415, 2.98, 3.26, 1.57, 1.6); mb.obj('faucet', 'black', 0, G_BASE, smooth=True)
st_, ss_ = MB(), MB()
for x_ in (1.3, 2.4, 3.5):
    for (dx, dy) in ((-.14, -.14), (.14, -.14), (-.14, .14), (.14, .14)): st_.box(x_ + dx - .01, x_ + dx + .01, 1.95 + dy - .01, 1.95 + dy + .01, FZB, .95)
    st_.box(x_ - .15, x_ + .15, 1.94 - .15, 1.96 - .15, .58, .6); ss_.cyl(x_, 1.95, .95, 1.02, .19, 28)
st_.obj('stoolframes', 'black', 0, G_BASE); soft(ss_.obj('stoolseats', 'fabric', 0, G_BASE), .02, 3)
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
# (la cocina exterior con barbacoa, fregadero y puertas se crea en detalles.py)
mb = MB(); mb.cbox(0, -1.2, 1.06, 2.2, 1.0, .05); mb.obj('otable', 'lacquer', .01, G_BASE)
mb = MB()
for x in (-1, 1):
    for y in (-.8, -1.6): mb.cbox(x, y, .67, .05, .05, .74)
mb.obj('olegs', 'alu', 0, G_BASE)
def soft(ob, w=.03, segs=3):
    """Bordes redondeados de verdad (cojines, colchonetas): bisel con normales endurecidas y sombreado suave."""
    for md in list(ob.modifiers):
        if md.type == 'BEVEL': ob.modifiers.remove(md)
    md = ob.modifiers.new('bev', 'BEVEL'); md.width = w; md.segments = segs; md.limit_method = 'ANGLE'; md.use_clamp_overlap = True; md.harden_normals = True
    for p in ob.data.polygons: p.use_smooth = True
    return ob
fr_, cu_, bk_ = MB(), MB(), MB()
for i in range(3):
    for s in (-1, 1):
        cx, cy = -.7 + i * .7, -1.2 - s * .75; ob_ = -s   # el respaldo queda al lado contrario de la mesa
        for dx in (-.2, .2):
            for dy in (-.2, .2): fr_.box(cx + dx - .011, cx + dx + .011, cy + dy - .011, cy + dy + .011, .30, .70)
        fr_.box(cx - .23, cx + .23, cy - .23, cy + .23, .68, .70)
        for dx in (-.21, .21): fr_.box(cx + dx - .011, cx + dx + .011, cy + ob_ * .22 - .011, cy + ob_ * .22 + .011, .70, 1.1)
        cu_.box(cx - .22, cx + .22, cy - .22, cy + .22, .70, .765)
        bk_.box(cx - .205, cx + .205, cy + ob_ * .235 - .028, cy + ob_ * .235 + .028, .80, 1.08)
fr_.obj('ochairframe', 'black', .004, G_BASE); soft(cu_.obj('ochaircush', 'fabriclight', 0, G_BASE), .025, 3); soft(bk_.obj('ochairback', 'fabriclight', 0, G_BASE), .02, 3)
mb = MB(); mb.box(1.5, 4.5, -1.08, -.08, .30, .42); mb.obj('osofabase', 'darkwood', .01, G_BASE)
se_, ba_, ar_ = MB(), MB(), MB()
for k in range(3):
    x0 = 1.6 + k * .935
    se_.box(x0 + .01, x0 + .925, -1.06, -.3, .42, .6); ba_.box(x0 + .01, x0 + .925, -.32, -.1, .58, 1.02)
ar_.box(1.45, 1.62, -1.08, -.08, .42, .78); ar_.box(4.38, 4.55, -1.08, -.08, .42, .78)
soft(se_.obj('osofaseat', 'fabriclight', 0, G_BASE), .05, 4); soft(ba_.obj('osofaback', 'fabriclight', 0, G_BASE), .05, 4); soft(ar_.obj('osofaarm', 'fabriclight', 0, G_BASE), .04, 3)
for (x, rz) in ((2.0, .12), (4.0, -.18)):
    mb = MB(); mb.cbox(0, 0, 0, .46, .13, .44); o_ = soft(mb.obj('ocush', 'blue', 0, G_BASE), .06, 4)
    o_.location = (x, -.38, .82); o_.rotation_euler = (math.radians(-12), 0, rz)

# Planta baja: muros, piedra, vidrio (WALLS)
mb = MB(); mb.box(-9.6, -6.4, 1.0, 7.2, .3, 3.6); mb.obj('stonevol', 'stone', .01, G_WALLS)
mb = MB(); mb.box(-6.4, 6.0, 6.9, 7.2, .3, 3.6); mb.obj('gwalls', 'render', .012, G_WALLS)
# Volumen blanco de la derecha: ventana vertical de verdad (hueco en el muro de 24 cm, marco, vidrio y vierteaguas)
# con una pequeña estancia detrás (se amuebla en detalles.py). Hueco y estancia se vacían con booleanos.
SX0, SX1, SZ0, SZ1, SGY = 4.9, 5.5, .62, 3.05, 1.09
mb = MB(); mb.box(4.0, 6.4, 1.0, 7.2, .3, 3.6); gw2 = mb.obj('gwalls2', 'render', 0, G_WALLS)
for cn_, bx_ in (('cut_slot', (SX0, SX1, .9, 1.3, SZ0, SZ1)), ('cut_room', (4.24, 6.16, 1.24, 3.6, .2, 3.36))):
    mb = MB(); mb.box(*bx_); c_ = mb.obj(cn_, 'render', 0, G_WALLS); c_.hide_render = True; c_.display_type = 'WIRE'
    md = gw2.modifiers.new(cn_, 'BOOLEAN'); md.operation = 'DIFFERENCE'; md.solver = 'EXACT'; md.object = c_
md = gw2.modifiers.new('bev', 'BEVEL'); md.width = .012; md.segments = 2; md.limit_method = 'ANGLE'; md.use_clamp_overlap = True
def glazing(name, x0, x1, y, z0, z1, panes, parent):
    mb = MB(); mb.box(x0, x1, y - .015, y + .015, z0 + .06, z1 - .06); mb.obj(name + '_g', 'glass', 0, parent)
    mb = MB(); mb.box(x0, x1, y - .07, y + .07, z0, z0 + .07); mb.box(x0, x1, y - .07, y + .07, z1 - .07, z1)
    for i in range(panes + 1):
        xx = x0 + (x1 - x0) * i / panes; mb.box(xx - .035, xx + .035, y - .07, y + .07, z0, z1)
    mb.obj(name + '_f', 'alu', .004, parent)
glazing('gglass', -6.4, 4.0, 1.2, .3, 3.6, 4, G_WALLS)
mb = MB()   # marco de aluminio negro de 5 cm con travesaño (fijo abajo, practicable arriba)
mb.box(SX0, SX1, SGY - .03, SGY + .03, SZ0, SZ0 + .05); mb.box(SX0, SX1, SGY - .03, SGY + .03, SZ1 - .05, SZ1)
mb.box(SX0, SX0 + .05, SGY - .03, SGY + .03, SZ0, SZ1); mb.box(SX1 - .05, SX1, SGY - .03, SGY + .03, SZ0, SZ1)
mb.box(SX0, SX1, SGY - .03, SGY + .03, 1.06, 1.11); mb.box(SX0 + .05, SX1 - .05, SGY - .04, SGY - .03, 1.11, 1.15)
mb.obj('slot_f', 'alu', .003, G_WALLS)
mb = MB(); mb.box(SX0 + .03, SX1 - .03, SGY - .012, SGY + .012, SZ0 + .03, SZ1 - .03); mb.obj('slot_g', 'glass', 0, G_WALLS)
mb = MB(); mb.box(SX0 - .03, SX1 + .03, .965, SGY - .03, SZ0 - .03, SZ0 + .002); mb.obj('slot_sill', 'alu', .003, G_WALLS)
mb = MB(); mb.box(-9.38, -9.22, -1.93, -1.77, .3, 3.6); mb.box(5.12, 5.28, -1.93, -1.77, .3, 3.6); mb.obj('columns', 'alu', .005, G_WALLS)
# Apliques exteriores
mb = MB(); mb.cbox(-6.0, .95, 2.2, .12, .1, .3); mb.cbox(3.6, .95, 2.2, .12, .1, .3); mb.obj('sconce', 'black', .005, G_WALLS)

# Planta alta (UPPER)
mb = MB(); mb.box(-10.0, 5.6, -2.1, 7.1, 3.6, 4.02); mb.obj('uslab', 'render', .015, G_UPPER)
mb = MB(); mb.box(-10.0, -9.68, -2.1, 7.1, 4.02, 7.0); mb.box(-9.7, -.1, 6.8, 7.1, 4.02, 7.0)
# Volumen derecho: estudio con ventanal de suelo a techo en la fachada (muros de 24 cm y vidrio retranqueado)
WX0, WX1, WZ0, WZ1, WT = .25, 5.05, 4.1, 6.78, .24
mb.box(-.6, -.36, -2.1, 7.1, 4.02, 7.0); mb.box(5.36, 5.6, -2.1, 7.1, 4.02, 7.0); mb.box(-.36, 5.36, 6.86, 7.1, 4.02, 7.0)
mb.box(-.36, WX0, -2.1, -2.1 + WT, 4.02, 7.0); mb.box(WX1, 5.36, -2.1, -2.1 + WT, 4.02, 7.0)
mb.box(WX0, WX1, -2.1, -2.1 + WT, 4.02, WZ0); mb.box(WX0, WX1, -2.1, -2.1 + WT, WZ1, 7.0)
mb.obj('uwalls', 'render', .015, G_UPPER)
glazing('uglass', -9.68, -.6, 1.6, 4.02, 7.0, 4, G_UPPER)
mb = MB(); mb.box(-9.68, -.6, -2.0, -1.97, 4.08, 5.05); mb.obj('rail_g', 'glass', 0, G_UPPER)
mb = MB(); mb.box(-9.68, -.6, -2.05, -1.92, 4.02, 4.1); mb.obj('rail_base', 'steel', .003, G_UPPER)
mb = MB(); mb.box(-9.68, -.6, -1.97, 1.6, 4.02, 4.05); mb.obj('uterrace', 'tile', 0, G_UPPER)
# ventanal: marco de aluminio negro de 6 cm con dos montantes, vidrio y vierteaguas
GY = -2.1 + WT * .42
mb = MB()
mb.box(WX0, WX1, GY - .045, GY + .045, WZ0, WZ0 + .06); mb.box(WX0, WX1, GY - .045, GY + .045, WZ1 - .06, WZ1)
mb.box(WX0, WX0 + .06, GY - .045, GY + .045, WZ0, WZ1); mb.box(WX1 - .06, WX1, GY - .045, GY + .045, WZ0, WZ1)
for xx in (WX0 + (WX1 - WX0) / 3, WX0 + 2 * (WX1 - WX0) / 3): mb.box(xx - .025, xx + .025, GY - .045, GY + .045, WZ0, WZ1)
mb.box(WX0 - .02, WX1 + .02, -2.13, -2.1 + .06, WZ0 - .025, WZ0)
mb.obj('vent_f', 'alu', .003, G_UPPER)
mb = MB(); mb.box(WX0 + .04, WX1 - .04, GY - .006, GY + .006, WZ0 + .04, WZ1 - .04); mb.obj('vent_g', 'glass', 0, G_UPPER)
# interior del estudio: suelo de roble, tabique con estantería y libros, escritorio, silla, butaca, lámpara y cortinas
if HAVE_PH:
    m, nt, b = newmat('floorwood'); M['floorwood'] = m; pbr(nt, b, 'oak_wood_planks', 1.2, nstr=.4, rough=(.3, .6))
else: simple('floorwood', 0xb8875a, .4, coat=.3)
simple('paint_in', 0xebe6dd, .9)
mb = MB(); mb.box(-.36, 5.36, -1.86, 6.86, 4.02, 4.035); mb.obj('studyfloor', 'floorwood', 0, G_UPPER)
mb = MB(); mb.box(-.36, 5.36, 3.3, 3.45, 4.035, 7.0); mb.obj('studywall', 'paint_in', .01, G_UPPER)
mb = MB()
for k in range(5): mb.box(.3, 4.7, 3.1, 3.3, 4.32 + k * .5, 4.35 + k * .5)
for x in (.3, 1.4, 2.5, 3.6, 4.67): mb.box(x, x + .03, 3.1, 3.3, 4.32, 6.35)
mb.obj('shelves', 'darkwood', .004, G_UPPER)
for nm_, col_ in (('book1', 0x6b4a3a), ('book2', 0x2f3e4f), ('book3', 0xd8d0c0), ('book4', 0x7a7462), ('book5', 0x4d5a3c)): simple(nm_, col_, .7, spec=.3)
bks = [MB() for _ in range(5)]; R2 = random.Random(5)
for k in range(4):
    x = .36
    while x < 4.62:
        if R2.random() < .12: x += R2.uniform(.15, .4); continue
        wb = R2.uniform(.025, .05); hb = R2.uniform(.19, .3); db = R2.uniform(.15, .19)
        R2.choice(bks).box(x, x + wb, 3.3 - db, 3.3, 4.35 + k * .5, 4.35 + k * .5 + hb); x += wb + .003
for i_, bk in enumerate(bks): bk.obj('books%d' % i_, 'book%d' % (i_ + 1), .002, G_UPPER)
mb = MB(); mb.cbox(2.65, -.75, 4.79, 1.9, .75, .04); mb.obj('desk', 'oak', .006, G_UPPER)
mb = MB(); [mb.cbox(x, y, 4.42, .04, .04, .74) for x in (1.75, 3.55) for y in (-1.07, -.43)]; mb.obj('desklegs', 'black', 0, G_UPPER)
mb = MB(); mb.cbox(2.65, -.1, 4.5, .52, .5, .08); mb.cbox(2.65, .14, 4.86, .5, .07, .64); mb.obj('dchair', 'fabric', .03, G_UPPER)
mb = MB(); mb.cyl(2.65, -.1, 4.04, 4.46, .025, 8); mb.cyl(2.65, -.1, 4.035, 4.06, .3, 5); mb.obj('dchairbase', 'black', 0, G_UPPER)
mb = MB(); mb.cbox(2.0, -.6, 4.86, .5, .3, .1); mb.obj('deskbook', 'book3', .004, G_UPPER)
mb = MB(); mb.cbox(4.25, 1.55, 4.27, .85, .85, .4); mb.cbox(4.25, 1.92, 4.65, .85, .14, .5); mb.cbox(3.87, 1.55, 4.47, .1, .85, .25); mb.cbox(4.63, 1.55, 4.47, .1, .85, .25)
mb.obj('armchair', 'fabriclight', .05, G_UPPER)
mb = MB(); mb.cbox(3.6, 1.2, 4.04, 2.6, 1.9, .01); mb.obj('studyrug', 'rug', 0, G_UPPER)
mb = MB(); mb.cyl(4.95, 2.35, 4.035, 5.55, .015, 8); mb.cyl(4.95, 2.35, 4.035, 4.06, .16, 16); mb.obj('flamp', 'black', 0, G_UPPER)
mb = MB(); mb.cyl(4.95, 2.35, 5.55, 5.85, .2, 24, r2=.15); mb.obj('flampshade', 'lamp', 0, G_UPPER, smooth=True)
mb = MB(); mb.cyl(.75, 2.5, 4.035, 4.45, .26, 24, r2=.3); mb.obj('studypot', 'concrete', .01, G_UPPER, smooth=True)
# cortinas finas recogidas a los lados
m, nt, b = newmat('sheer'); M['sheer'] = m; b.inputs['Base Color'].default_value = lin(0xf3f0ea); b.inputs['Roughness'].default_value = .85
tl = node(nt, 'ShaderNodeBsdfTranslucent'); tl.inputs['Color'].default_value = lin(0xf3f0ea); tp = node(nt, 'ShaderNodeBsdfTransparent')
mx1 = node(nt, 'ShaderNodeMixShader'); mx1.inputs[0].default_value = .45; L(nt, b.outputs[0], mx1.inputs[1]); L(nt, tl.outputs[0], mx1.inputs[2])
mx2 = node(nt, 'ShaderNodeMixShader'); mx2.inputs[0].default_value = .3; L(nt, mx1.outputs[0], mx2.inputs[1]); L(nt, tp.outputs[0], mx2.inputs[2])
L(nt, mx2.outputs[0], nt.nodes['Material Output'].inputs['Surface'])
for (cx0, cx1) in ((WX0 + .08, WX0 + .75), (WX1 - .75, WX1 - .08)):
    cm_ = MB(); n_ = 60
    lo_ = [cm_.bm.verts.new((cx0 + (cx1 - cx0) * i / n_, GY + .14 + .045 * math.sin(i / n_ * 7 * 2 * math.pi), WZ0 + .03)) for i in range(n_ + 1)]
    hi_ = [cm_.bm.verts.new((v.co.x, v.co.y, WZ1 - .04)) for v in lo_]
    for i in range(n_): cm_.bm.faces.new((lo_[i], lo_[i + 1], hi_[i + 1], hi_[i]))
    cm_.obj('curtain', 'sheer', 0, G_UPPER, smooth=True)
mb = MB()
for i in range(8): mb.cyl(-8.5 + i * 1.6, -1.2, 3.585, 3.6, .07, 16)
mb.obj('downlights', 'downlight', 0, G_UPPER)
# Dormitorio principal: suelo de roble, pared de lamas, cama tapizada con ropa de cama, mesillas, lámparas,
# alfombra, banqueta, armario empotrado, rincón de lectura y cortinas
FZ = 4.035
def _box(name, mat, bx, bev=0., softw=0., segs=3):
    m_ = MB()
    for q in bx: m_.box(*q)
    o_ = m_.obj(name, mat, bev, G_UPPER)
    return soft(o_, softw, segs) if softw else o_
_box('bedfloor', 'floorwood', [(-9.68, -.6, 1.6, 6.8, 4.02, FZ)])
_box('slatwall', 'darkwood', [(x_, x_ + .045, 6.72, 6.78, FZ, 6.99) for x_ in [-8.0 + k * .06 for k in range(80)]], .003)
linen('headfab', 0x9d978d); linen('bedwhite', 0xf1eee8); linen('beddark', 0x6f6a63); linen('throwtan', 0xb59a7a)
_box('bedbase', 'headfab', [(-6.55, -4.65, 4.55, 6.68, FZ + .08, FZ + .36)], softw=.03)
_box('bedfeet', 'black', [(-6.45, -6.4, 4.65, 4.7, FZ, FZ + .08), (-4.9, -4.85, 4.65, 4.7, FZ, FZ + .08), (-6.45, -6.4, 6.5, 6.55, FZ, FZ + .08), (-4.9, -4.85, 6.5, 6.55, FZ, FZ + .08)])
_box('mattress', 'bedwhite', [(-6.48, -4.72, 4.6, 6.62, FZ + .36, FZ + .58)], softw=.05, segs=4)
_box('duvet', 'bedwhite', [(-6.56, -4.64, 4.5, 5.95, FZ + .5, FZ + .64)], softw=.06, segs=4)
_box('bedthrow', 'throwtan', [(-6.6, -4.6, 4.62, 5.15, FZ + .62, FZ + .67)], softw=.025, segs=3)
_box('headboard', 'headfab', [(-7.05, -4.15, 6.62, 6.72, FZ + .3, FZ + 1.35)], softw=.04, segs=4)
for i_, (x_, mat_) in enumerate(((-6.05, 'bedwhite'), (-5.15, 'bedwhite'), (-5.95, 'beddark'), (-5.25, 'beddark'))):
    m_ = MB(); m_.cbox(0, 0, 0, .62, .16, .42); o_ = soft(m_.obj('pillow%d' % i_, mat_, 0, G_UPPER), .07, 4)
    o_.location = (x_, 6.42 - (i_ // 2) * .14, FZ + .78 - (i_ // 2) * .02); o_.rotation_euler = (math.radians(-18 + (i_ // 2) * 8), 0, 0)
_box('nightstands', 'oak', [(-7.55, -7.05, 6.25, 6.68, FZ + .12, FZ + .55), (-4.15, -3.65, 6.25, 6.68, FZ + .12, FZ + .55)], .01)
_box('nsdrawer', 'darkwood', [(-7.53, -7.07, 6.245, 6.25, FZ + .32, FZ + .33), (-4.13, -3.67, 6.245, 6.25, FZ + .32, FZ + .33)])
_box('nslegs', 'black', [(x_, x_ + .02, y_, y_ + .02, FZ, FZ + .12) for x_ in (-7.52, -7.1, -4.12, -3.7) for y_ in (6.28, 6.63)])
m_ = MB(); [m_.cyl(x_, 6.46, FZ + .55, FZ + .85, .07, 20, r2=.05) for x_ in (-7.3, -3.9)]; soft(m_.obj('tlampbase', 'lacquer', 0, G_UPPER), .01, 2)
m_ = MB(); [m_.cyl(x_, 6.46, FZ + .85, FZ + 1.1, .18, 28, r2=.15) for x_ in (-7.3, -3.9)]; m_.obj('tlampshade', 'lamp', 0, G_UPPER, smooth=True)
_box('bedrug', 'rug', [(-7.6, -3.6, 3.3, 6.2, FZ, FZ + .012)])
_box('bench', 'headfab', [(-6.35, -4.85, 4.0, 4.42, FZ + .3, FZ + .46)], softw=.03)
_box('benchlegs', 'oak', [(x_, x_ + .04, y_, y_ + .04, FZ, FZ + .3) for x_ in (-6.3, -4.94) for y_ in (4.05, 4.33)])
# armario empotrado de suelo a techo con puertas de roble y tiradores
_box('wardrobe', 'oak', [(-3.0 + k * .59 + .005, -3.0 + (k + 1) * .59 - .005, 6.2, 6.8, FZ, 6.95) for k in range(4)], .004)
_box('wardhandles', 'black', [(-3.0 + k * .59 + (.52 if k % 2 == 0 else .05), -3.0 + k * .59 + (.54 if k % 2 == 0 else .07), 6.17, 6.2, 5.0, 5.9) for k in range(4)])
# rincón de lectura junto al ventanal
m_ = MB(); m_.cbox(0, 0, .22, .78, .8, .16); m_.cbox(0, .33, .55, .78, .14, .6); m_.cbox(-.36, 0, .4, .1, .8, .3); m_.cbox(.36, 0, .4, .1, .8, .3)
o_ = soft(m_.obj('bedarmchair', 'fabriclight', 0, G_UPPER), .035, 3); o_.location = (-8.85, 2.45, FZ + .14); o_.rotation_euler.z = math.radians(-145)
m_ = MB(); [m_.cbox(-8.85 + dx, 2.45 + dy, FZ + .07, .04, .04, .14) for dx in (-.3, .3) for dy in (-.3, .3)]; m_.obj('bedarmlegs', 'oak', 0, G_UPPER)
m_ = MB(); m_.cyl(-8.05, 2.1, FZ, FZ + .5, .2, 24); m_.obj('sidetable', 'marble', 0, G_UPPER, smooth=True)
m_ = MB(); m_.cyl(-9.4, 3.1, FZ, FZ + 1.55, .012, 8); m_.cyl(-9.4, 3.1, FZ, FZ + .02, .15, 16); m_.obj('bflamp', 'black', 0, G_UPPER)
m_ = MB(); m_.cyl(-9.4, 3.1, FZ + 1.45, FZ + 1.72, .2, 24, r2=.16); m_.obj('bflampshade', 'lamp', 0, G_UPPER, smooth=True)
m_ = MB(); m_.cyl(-1.2, 2.3, FZ, FZ + .45, .24, 24, r2=.28); m_.obj('bedpot', 'concrete', .01, G_UPPER, smooth=True)
# cuadro en la pared del fondo junto al armario
_box('artframe', 'black', [(-9.68, -9.64, 3.4, 4.8, 5.0, 6.1)])
m_ = MB(); m_.box(-9.64, -9.63, 3.46, 4.74, 5.06, 6.04); simple('artcanvas', 0xc9b79c, .9); m_.obj('artcanvas', 'artcanvas', 0, G_UPPER)
# cortinas finas recogidas a los lados del ventanal del dormitorio
for (cx0, cx1) in ((-9.6, -8.95), (-1.35, -.7)):
    cm_ = MB(); n_ = 60
    lo_ = [cm_.bm.verts.new((cx0 + (cx1 - cx0) * i / n_, 1.78 + .045 * math.sin(i / n_ * 7 * 2 * math.pi), FZ + .03)) for i in range(n_ + 1)]
    hi_ = [cm_.bm.verts.new((v.co.x, v.co.y, 6.96)) for v in lo_]
    for i in range(n_): cm_.bm.faces.new((lo_[i], lo_[i + 1], hi_[i + 1], hi_[i]))
    cm_.obj('bcurtain', 'sheer', 0, G_UPPER, smooth=True)
# Jardineras en terraza
mb = MB(); mb.box(-9.5, -8.5, -1.8, -1.2, 4.02, 4.5); mb.box(-2.0, -1.0, -1.8, -1.2, 4.02, 4.5); mb.obj('planters', 'concrete', .01, G_UPPER)

# Cubierta (ROOF): losa, petos con albardilla de aluminio, grava, pasillo de losas, castillete con puerta,
# máquinas de aire acondicionado y placas solares con células, marco y estructura apoyada en la cubierta
RZ = 7.4
mb = MB(); mb.box(-10.2, 5.8, -2.2, 7.2, 7.0, 7.36); mb.obj('rslab', 'render', .015, G_ROOF)
mb = MB(); mb.box(-10.2, 5.8, -2.2, -2.0, 7.36, 7.85); mb.box(-10.2, 5.8, 7.0, 7.2, 7.36, 7.85); mb.box(-10.2, -10.0, -2.0, 7.0, 7.36, 7.85); mb.box(5.6, 5.8, -2.0, 7.0, 7.36, 7.85)
mb.obj('parapet', 'render', .01, G_ROOF)
simple('copingmetal', 0xa7a9ab, .32, .85)
mb = MB(); mb.box(-10.23, 5.83, -2.23, -1.97, 7.85, 7.875); mb.box(-10.23, 5.83, 6.97, 7.23, 7.85, 7.875); mb.box(-10.23, -9.97, -1.97, 6.97, 7.85, 7.875); mb.box(5.57, 5.83, -1.97, 6.97, 7.85, 7.875)
mb.obj('copings', 'copingmetal', .003, G_ROOF)
m, nt, b = newmat('gravelroof'); M['gravelroof'] = m
if HAVE_PH: pbr(nt, b, 'gravel_floor_02', 2.0, tint=0xc8c4bc, tint_fac=.4, nstr=1.0, rough=(.85, 1.))
else: b.inputs['Base Color'].default_value = lin(0xb3ada3); b.inputs['Roughness'].default_value = 1
mb = MB(); mb.box(-10.0, 5.6, -2.0, 7.0, 7.36, RZ); mb.obj('rgravel', 'gravelroof', 0, G_ROOF)
mb = MB()
for k in range(22): mb.box(-9.7 + k * .51, -9.7 + k * .51 + .5, 6.2, 6.7, RZ, RZ + .04)
for k in range(9): mb.box(.95, 1.45, 6.2 - (k + 1) * .51, 6.2 - (k + 1) * .51 + .5, RZ, RZ + .04)
mb.obj('roofpavers', 'concrete', .006, G_ROOF)
# castillete de la escalera (2,4 m sobre la cubierta) con puerta y albardilla
mb = MB(); mb.box(1.7, 4.7, 3.6, 6.4, 7.36, 9.8); mb.obj('caseton', 'render', .015, G_ROOF)
mb = MB(); mb.box(1.67, 4.73, 3.57, 6.43, 9.8, 9.825); mb.obj('casetoncap', 'copingmetal', .003, G_ROOF)
mb = MB(); mb.box(1.675, 1.7, 4.45, 5.4, RZ + .02, RZ + 2.12); mb.obj('roofdoor', 'alu', .004, G_ROOF)
mb = MB(); mb.box(1.66, 1.675, 5.25, 5.3, RZ + 1.0, RZ + 1.12); mb.obj('roofhandle', 'steel', 0, G_ROOF)
# aire acondicionado: dos unidades exteriores con rejilla del ventilador, patas y tubos al castillete
simple('acbody', 0xdcdcd8, .38, .3); simple('acgrille', 0x2a2c2e, .5, .6)
acb, acg, acf = MB(), MB(), MB()
for xa in (2.15, 3.45):
    acb.box(xa, xa + 1.0, 2.25, 2.62, RZ + .1, RZ + .82)
    acg.cyl(xa + .38, 2.25, RZ + .2, RZ + .72, .0, 3)   # (no usado: marcador)
    for yy in (2.3, 2.57): acf.box(xa + .05, xa + .95, yy - .03, yy + .03, RZ, RZ + .1)
acb.obj('acunits', 'acbody', .012, G_ROOF); acf.obj('acfeet', 'black', 0, G_ROOF)
mb = MB()
for xa in (2.15, 3.45):
    n_ = 32; cxg, czg = xa + .4, RZ + .46
    ring = [mb.bm.verts.new((cxg + .27 * math.cos(a), 2.245, czg + .27 * math.sin(a))) for a in [i / n_ * 2 * math.pi for i in range(n_)]]
    ctr = mb.bm.verts.new((cxg, 2.24, czg))
    for i in range(n_): mb.bm.faces.new((ring[i], ring[(i + 1) % n_], ctr))
mb.obj('acfans', 'acgrille', 0, G_ROOF)
mb = MB()
for xa in (2.15, 3.45):
    for k in range(9): mb.box(xa + .4 - .27, xa + .4 + .27, 2.235, 2.24, RZ + .46 - .27 + k * .066, RZ + .46 - .27 + k * .066 + .008)
    mb.box(xa + .78, xa + .82, 2.6, 3.62, RZ + .3, RZ + .34); mb.box(xa + .86, xa + .9, 2.6, 3.62, RZ + .38, RZ + .42)
mb.obj('acbars', 'acgrille', 0, G_ROOF)
# placas solares: 2 filas de 6 módulos de 1,1 x 1,9 m inclinados 25° hacia el sur, con marco y estructura
m, nt, b = newmat('pv'); M['pv'] = m
uvn = node(nt, 'ShaderNodeUVMap'); uvn.uv_map = 'UVMap'; spv = node(nt, 'ShaderNodeSeparateXYZ'); L(nt, uvn.outputs['UV'], spv.inputs[0])
def pm(op, a, b_=None):
    n_ = node(nt, 'ShaderNodeMath'); n_.operation = op
    for k_, x_ in enumerate((a, b_)):
        if x_ is None: continue
        if isinstance(x_, (int, float)): n_.inputs[k_].default_value = x_
        else: L(nt, x_, n_.inputs[k_])
    return n_.outputs[0]
u6, v10 = pm('MULTIPLY', spv.outputs['X'], 6), pm('MULTIPLY', spv.outputs['Y'], 10)
fu, fv = pm('FRACT', u6), pm('FRACT', v10)
eu = pm('MINIMUM', fu, pm('SUBTRACT', 1., fu)); ev = pm('MINIMUM', fv, pm('SUBTRACT', 1., fv))
gapu = node(nt, 'ShaderNodeMapRange'); gapu.inputs['From Min'].default_value = .025; gapu.inputs['From Max'].default_value = .035; gapu.inputs['To Min'].default_value = 1; gapu.inputs['To Max'].default_value = 0; L(nt, eu, gapu.inputs['Value'])
gapv = node(nt, 'ShaderNodeMapRange'); gapv.inputs['From Min'].default_value = .02; gapv.inputs['From Max'].default_value = .03; gapv.inputs['To Min'].default_value = 1; gapv.inputs['To Max'].default_value = 0; L(nt, ev, gapv.inputs['Value'])
gap = pm('MAXIMUM', gapu.outputs[0], gapv.outputs[0])
f5 = pm('FRACT', pm('MULTIPLY', fu, 5)); bus = pm('LESS_THAN', pm('ABSOLUTE', pm('SUBTRACT', f5, .5)), .035)
fin = pm('LESS_THAN', pm('ABSOLUTE', pm('SUBTRACT', pm('FRACT', pm('MULTIPLY', fv, 22)), .5)), .04)
cmbp = node(nt, 'ShaderNodeCombineXYZ'); L(nt, pm('FLOOR', u6), cmbp.inputs[0]); L(nt, pm('FLOOR', v10), cmbp.inputs[1])
wnc = node(nt, 'ShaderNodeTexWhiteNoise'); wnc.noise_dimensions = '3D'; L(nt, cmbp.outputs[0], wnc.inputs['Vector'])
cell = mix(nt, wnc.outputs['Value'], lin(0x0b1322), lin(0x141f36))
cell = mix(nt, pm('MULTIPLY', fin, .25), cell, lin(0x3a4250))
cell = mix(nt, pm('MULTIPLY', bus, .8), cell, lin(0x9aa0a6))
cell = mix(nt, gap, cell, lin(0xd9dde0))
L(nt, cell, b.inputs['Base Color']); b.inputs['Roughness'].default_value = .25; b.inputs['Metallic'].default_value = .1
b.inputs['Coat Weight'].default_value = 1.; b.inputs['Coat Roughness'].default_value = .02; b.inputs['Coat IOR'].default_value = 1.52
simple('pvframe', 0xbfc2c5, .28, 1.)
bmp = bmesh.new(); uvp = bmp.loops.layers.uv.new('UVMap'); frm = MB(); mnt = MB()
TILT = math.radians(25); Rt = Matrix.Rotation(TILT, 3, 'X'); PW_, PH_ = 1.1, 1.9
def pv_place(v, cx, cy, cz): return Rt @ Vector(v) + Vector((cx, cy, cz))
def beam(mb_, p0, p1, w):
    d_ = (p1 - p0); ax = d_.normalized(); u_ = ax.orthogonal().normalized() * w / 2; v_ = ax.cross(u_).normalized() * w / 2
    c0 = [p0 + u_ + v_, p0 - u_ + v_, p0 - u_ - v_, p0 + u_ - v_]; c1 = [c + d_ for c in c0]
    vs = [mb_.bm.verts.new(c) for c in c0 + c1]
    for q in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)): mb_.bm.faces.new([vs[i] for i in q])
for cy in (5.0, 2.45):
    cz = RZ + .32 + (PH_ / 2) * math.sin(TILT)
    for c in range(6):
        cx = -8.7 + c * 1.14
        P = [(-PW_ / 2 + .03, -PH_ / 2 + .03, .0), (PW_ / 2 - .03, -PH_ / 2 + .03, .0), (PW_ / 2 - .03, PH_ / 2 - .03, .0), (-PW_ / 2 + .03, PH_ / 2 - .03, .0)]
        vs = [bmp.verts.new(pv_place(p, cx, cy, cz)) for p in P]
        f = bmp.faces.new(vs)
        for lo, (uu, vv) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))): lo[uvp].uv = (uu, vv)
        # marco de aluminio (4 perfiles) y canto del módulo
        for (a_, b_) in (((-PW_ / 2, -PH_ / 2), (PW_ / 2, -PH_ / 2)), ((PW_ / 2, -PH_ / 2), (PW_ / 2, PH_ / 2)), ((PW_ / 2, PH_ / 2), (-PW_ / 2, PH_ / 2)), ((-PW_ / 2, PH_ / 2), (-PW_ / 2, -PH_ / 2))):
            beam(frm, pv_place((a_[0], a_[1], -.012), cx, cy, cz), pv_place((b_[0], b_[1], -.012), cx, cy, cz), .035)
        beam(frm, pv_place((-PW_ / 2 + .02, 0, -.03), cx, cy, cz), pv_place((PW_ / 2 - .02, 0, -.03), cx, cy, cz), .02)
    # estructura: largueros bajo los módulos y patas delanteras y traseras sobre zapatas
    for xs in [-9.2 + k * 1.14 for k in range(7)]:
        front = pv_place((0, -PH_ / 2 + .15, -.04), 0, cy, cz) + Vector((xs, 0, 0)); back = pv_place((0, PH_ / 2 - .15, -.04), 0, cy, cz) + Vector((xs, 0, 0))
        beam(mnt, front, back, .04)
        beam(mnt, Vector((front.x, front.y, RZ + .05)), front, .035); beam(mnt, Vector((back.x, back.y, RZ + .05)), back, .035)
        beam(mnt, Vector((front.x, front.y, RZ + .05)), back, .025)
        for p_ in (front, back): mnt.box(p_.x - .12, p_.x + .12, p_.y - .12, p_.y + .12, RZ, RZ + .06)
mep = bpy.data.meshes.new('panels'); bmp.to_mesh(mep); bmp.free()
op = bpy.data.objects.new('panels', mep); COL.objects.link(op); mep.materials.append(M['pv']); op.parent = G_ROOF
frm.obj('pvframes', 'pvframe', 0, G_ROOF); mnt.obj('pvmounts', 'pvframe', 0, G_ROOF)

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
# Tarima de tablas reales: 14 cm de ancho, juntas de 6 mm, testas escalonadas, cantos redondeados y veta distinta en cada tabla
simple('deckgap', 0x1b1612, .9)
mb = MB(); mb.box(-9.8, -3.4, -11.6, -4.0, 0, .05); mb.box(-3.4, 9.4, -11.6, -9.2, 0, .05); mb.obj('deckbase', 'deckgap', 0)
m, nt, b = newmat('deckboard'); M['deckboard'] = m
if HAVE_PH:
    atb = node(nt, 'ShaderNodeAttribute'); atb.attribute_name = 'boardvar'; atb.attribute_type = 'GEOMETRY'
    tcb = node(nt, 'ShaderNodeTexCoord'); ofs = node(nt, 'ShaderNodeVectorMath'); ofs.operation = 'MULTIPLY_ADD'; ofs.inputs[1].default_value = (7.3, 0, 0)
    L(nt, atb.outputs['Fac'], ofs.inputs[0]); L(nt, tcb.outputs['Object'], ofs.inputs[2])
    mpb = node(nt, 'ShaderNodeMapping'); mpb.inputs['Scale'].default_value = (1 / 2.4, 1 / .62, 1 / .62); L(nt, ofs.outputs[0], mpb.inputs['Vector'])
    def tb(suf, nc):
        n_ = node(nt, 'ShaderNodeTexImage'); n_.image = bpy.data.images.load(PH + 'oak_wood_planks_%s.jpg' % suf, check_existing=True); n_.projection = 'BOX'; n_.projection_blend = .2
        if nc: n_.image.colorspace_settings.name = 'Non-Color'
        L(nt, mpb.outputs[0], n_.inputs['Vector']); return n_.outputs[0]
    bc_ = node(nt, 'ShaderNodeBrightContrast'); bc_.inputs['Contrast'].default_value = .35; L(nt, tb('diff', False), bc_.inputs['Color'])
    tone = ramp(nt, atb.outputs['Fac'], [(0, lin(0xd2c4b4)), (.3, lin(0xe2d4c0)), (.55, lin(0xbfae9a)), (.8, lin(0xe8d8c2)), (1, lin(0xae9c86))])
    wc_ = mix(nt, 1.0, mix(nt, 1.0, bc_.outputs[0], lin(0xb8977a), 'MULTIPLY'), tone, 'MULTIPLY')
    hsd = node(nt, 'ShaderNodeHueSaturation'); hsd.inputs['Saturation'].default_value = .8; hsd.inputs['Hue'].default_value = .51; L(nt, wc_, hsd.inputs['Color'])
    L(nt, hsd.outputs[0], b.inputs['Base Color'])
    rr2 = node(nt, 'ShaderNodeMapRange'); rr2.inputs['To Min'].default_value = .38; rr2.inputs['To Max'].default_value = .8; L(nt, tb('rough', True), rr2.inputs['Value']); L(nt, rr2.outputs[0], b.inputs['Roughness'])
    nmb = node(nt, 'ShaderNodeNormalMap'); nmb.inputs['Strength'].default_value = 1.2; L(nt, tb('nor', True), nmb.inputs['Color']); L(nt, nmb.outputs[0], b.inputs['Normal'])
    b.inputs['Coat Weight'].default_value = .12; b.inputs['Coat Roughness'].default_value = .3
else:
    b.inputs['Base Color'].default_value = lin(0x9a6a48); b.inputs['Roughness'].default_value = .6
RB = random.Random(31); V_, F_, A_ = [], [], []
def board(x0, x1, y0, y1, z0, z1, a):
    n = len(V_); V_.extend([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)])
    for q in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)): F_.append(tuple(n + i for i in q)); A_.append(a)
y = -11.6 + .003
while y < -4.0:
    y1 = min(y + .14, -4.003)
    xa, xb = (-9.8, 9.4) if y1 <= -9.2 else (-9.8, -3.4)
    x = xa - RB.uniform(0, 2.4)
    while x < xb:
        L_ = RB.choice((2.4, 3.0, 3.6)); bx0, bx1 = max(xa, x) + .002, min(xb, x + L_) - .002
        if bx1 - bx0 > .05: board(bx0, bx1, y, y1, .05, .08, RB.random())
        x += L_
    y += .148
med = bpy.data.meshes.new('deck'); med.from_pydata(V_, [], F_); med.update()
at_ = med.attributes.new('boardvar', 'FLOAT', 'FACE'); at_.data.foreach_set('value', A_)
deck_ob = bpy.data.objects.new('deck', med); COL.objects.link(deck_ob); med.materials.append(M['deckboard'])
bv_ = deck_ob.modifiers.new('bev', 'BEVEL'); bv_.width = .0045; bv_.segments = 2; bv_.limit_method = 'ANGLE'; bv_.harden_normals = True
for p in med.polygons: p.use_smooth = True
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
simple('spashell', 0x231c16, .9); mb.obj('spa', 'spashell', .01, recalc=False)   # queda detrás de las lamas
spain = mi.obj('spain', 'spatile', 0, recalc=False); planar_uv(spain, (JX, JY, 1.2)); spain.cycles.is_caustics_receiver = True
water_sheet('spawater', 'spawater', JX - 1.26, JX + 1.26, JY - 1.26, JY + 1.26, .6, .012, keep=lambda x, y: (x - JX) ** 2 + (y - JY) ** 2 < 1.225 ** 2)
# burbujas y espuma: render.py las coloca en cada fotograma
fo = bpy.data.objects.new('spafoam', bpy.data.meshes.new('spafoam')); COL.objects.link(fo); fo.data.materials.append(M['foam'])
mb = MB(); mb.cbox(JX, JY - 1.85, .17, 1.0, .5, .18); mb.obj('spastep', 'wood', .005)
# revestimiento de lamas de madera alrededor del jacuzzi y borde de piedra redondeado
mb = MB(); nl_ = 110
for k in range(nl_):
    a0 = k / nl_ * 2 * math.pi; a1 = (k + .86) / nl_ * 2 * math.pi
    p_ = [(JX + r_ * math.cos(a), JY + r_ * math.sin(a)) for r_ in (1.505, 1.535) for a in (a0, a1)]
    vs_ = [mb.bm.verts.new((x_, y_, z_)) for z_ in (.09, .6) for (x_, y_) in p_]
    for q in ((0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5), (4, 5, 7, 6)): mb.bm.faces.new([vs_[i] for i in q])
mb.obj('spaslats', 'wood', 0)
mb = MB(); n_ = 160
ro = [mb.bm.verts.new((JX + 1.58 * math.cos(a), JY + 1.58 * math.sin(a), z_)) for z_ in (.615, .715) for a in [i / n_ * 2 * math.pi for i in range(n_)]]
ri = [mb.bm.verts.new((JX + 1.17 * math.cos(a), JY + 1.17 * math.sin(a), z_)) for z_ in (.615, .715) for a in [i / n_ * 2 * math.pi for i in range(n_)]]
for i in range(n_):
    j = (i + 1) % n_
    mb.bm.faces.new((ro[i], ro[j], ro[n_ + j], ro[n_ + i])); mb.bm.faces.new((ri[n_ + i], ri[n_ + j], ri[j], ri[i]))
    mb.bm.faces.new((ro[n_ + i], ro[n_ + j], ri[n_ + j], ri[n_ + i])); mb.bm.faces.new((ri[i], ri[j], ro[j], ro[i]))
soft(mb.obj('spacoping', 'tile', 0), .02, 3)
# Tumbonas, sombrilla
simple('whitemetal', 0xe6e6e2, .3, .7)
for i, x in enumerate((1.0, 2.3, 3.6)):
    mb = MB()
    for sx in (-1, 1):
        mb.box(x + sx * .34 - .02, x + sx * .34 + .02, -11.35, -9.4, .22, .26)
        for yy in (-11.3, -9.45): mb.box(x + sx * .34 - .02, x + sx * .34 + .02, yy - .02, yy + .02, .08, .24)
    for yy in (-11.35, -9.4): mb.box(x - .36, x + .36, yy - .02, yy + .02, .22, .26)
    mb.obj('lounger%d' % i, 'whitemetal', .006)
    mb = MB(); mb.box(x - .33, x + .33, -10.85, -9.42, .26, .34); soft(mb.obj('lcush%d' % i, 'fabriclight', 0), .035, 4)
    mb = MB(); mb.box(-.33, .33, -.36, .36, 0, .08)
    me_o = soft(mb.obj('lback%d' % i, 'fabriclight', 0), .035, 4); me_o.location = (x, -11.12, .5); me_o.rotation_euler = (math.radians(-40), 0, 0)
# (la sombrilla de brezo con mástil de madera se crea en vegetacion.py)

# ------------------------------------------------------------------ vegetación
NEIGH = []   # sin casas vecinas: la villa está rodeada de bosque
if not QUICK: exec(open(os.path.join(HERE, 'vegetacion.py')).read())
exec(open(os.path.join(HERE, 'detalles.py')).read())   # cocina exterior, objetos de uso y estancia de la ventana vertical
# Carretera: asfalto envejecido de dos carriles (6,2 m), líneas pintadas algo gastadas, rodadas, parches y manchas;
# bordillo y acera de adoquín junto a la parcela, arcén de tierra y grava al otro lado, y farolas
RY0, RY1 = -21.6, -15.4; RYC = (RY0 + RY1) / 2
def mth_(nt, op, a, b_=None):
    n_ = node(nt, 'ShaderNodeMath'); n_.operation = op
    for k_, x_ in enumerate((a, b_)):
        if x_ is None: continue
        if isinstance(x_, (int, float)): n_.inputs[k_].default_value = x_
        else: L(nt, x_, n_.inputs[k_])
    return n_.outputs[0]
def band(nt, y, center, half, soft):
    """1 dentro de la franja |y-center|<half, con borde suave."""
    d = mth_(nt, 'ABSOLUTE', mth_(nt, 'SUBTRACT', y, center))
    mr = node(nt, 'ShaderNodeMapRange'); mr.inputs['From Min'].default_value = half; mr.inputs['From Max'].default_value = half + soft
    mr.inputs['To Min'].default_value = 1; mr.inputs['To Max'].default_value = 0; L(nt, d, mr.inputs['Value']); return mr.outputs[0]
m, nt, b = newmat('asphalt'); M['asphalt'] = m
if HAVE_PH:
    d = pbr(nt, b, 'asphalt_02', 3.0, nstr=.9, rough=(.72, .95))
    base = mix(nt, 1.0, d, lin(0xb4b4b0), 'MULTIPLY')
else:
    base = lin(0x3a3b3c); b.inputs['Roughness'].default_value = .85
tc = node(nt, 'ShaderNodeTexCoord'); sp = node(nt, 'ShaderNodeSeparateXYZ'); L(nt, tc.outputs['Object'], sp.inputs[0]); X_, Y_ = sp.outputs['X'], sp.outputs['Y']
big = noise(nt, tc.outputs['Object'], .06, 4); col = mix(nt, .35, base, mix(nt, big.outputs['Fac'], lin(0x7a7a76), lin(0xc8c8c2)), 'MULTIPLY')
# parches de reparación (rectángulos más oscuros y lisos)
cx = mth_(nt, 'FLOOR', mth_(nt, 'DIVIDE', X_, 7.0)); cy = mth_(nt, 'FLOOR', mth_(nt, 'DIVIDE', Y_, 3.1))
cmb = node(nt, 'ShaderNodeCombineXYZ'); L(nt, cx, cmb.inputs[0]); L(nt, cy, cmb.inputs[1])
wnp = node(nt, 'ShaderNodeTexWhiteNoise'); wnp.noise_dimensions = '3D'; L(nt, cmb.outputs[0], wnp.inputs['Vector'])
fxp = mth_(nt, 'FRACT', mth_(nt, 'DIVIDE', X_, 7.0)); fyp = mth_(nt, 'FRACT', mth_(nt, 'DIVIDE', Y_, 3.1))
inside = mth_(nt, 'MULTIPLY', mth_(nt, 'MULTIPLY', mth_(nt, 'GREATER_THAN', fxp, .15), mth_(nt, 'LESS_THAN', fxp, .7)),
              mth_(nt, 'MULTIPLY', mth_(nt, 'GREATER_THAN', fyp, .1), mth_(nt, 'LESS_THAN', fyp, .85)))
patch = mth_(nt, 'MULTIPLY', inside, mth_(nt, 'GREATER_THAN', wnp.outputs['Value'], .88))
col = mix(nt, patch, col, mix(nt, .5, col, lin(0x3a3a3a), 'MULTIPLY'))
# rodadas: franjas algo más oscuras y pulidas; manchas de aceite en el centro de cada carril
tracks = mth_(nt, 'MAXIMUM', mth_(nt, 'MAXIMUM', band(nt, Y_, RYC + 1.55 + .85, .28, .25), band(nt, Y_, RYC + 1.55 - .85, .28, .25)),
              mth_(nt, 'MAXIMUM', band(nt, Y_, RYC - 1.55 + .85, .28, .25), band(nt, Y_, RYC - 1.55 - .85, .28, .25)))
col = mix(nt, mth_(nt, 'MULTIPLY', tracks, .35), col, mix(nt, 1.0, col, lin(0xb0b0b0), 'MULTIPLY'))
oil = noise(nt, tc.outputs['Object'], 1.6, 3)
oilm = node(nt, 'ShaderNodeMapRange'); oilm.inputs['From Min'].default_value = .6; oilm.inputs['From Max'].default_value = .72; L(nt, oil.outputs['Fac'], oilm.inputs['Value'])
lanec = mth_(nt, 'MAXIMUM', band(nt, Y_, RYC + 1.55, .35, .3), band(nt, Y_, RYC - 1.55, .35, .3))
col = mix(nt, mth_(nt, 'MULTIPLY', mth_(nt, 'MULTIPLY', oilm.outputs[0], lanec), .45), col, lin(0x1a1a1a))
# tierra y polvo hacia los bordes
edge = mth_(nt, 'MAXIMUM', band(nt, Y_, RY0, .05, .6), band(nt, Y_, RY1, .05, .45))
col = mix(nt, mth_(nt, 'MULTIPLY', edge, .45), col, lin(0x6e6250))
# marcas viales: eje discontinuo (4,5 m de línea cada 12 m) y líneas de borde continuas, con desgaste
dash = mth_(nt, 'LESS_THAN', mth_(nt, 'FRACT', mth_(nt, 'DIVIDE', X_, 12.0)), .375)
paint = mth_(nt, 'MAXIMUM', mth_(nt, 'MULTIPLY', band(nt, Y_, RYC, .05, .012), dash),
             mth_(nt, 'MAXIMUM', band(nt, Y_, RY1 - .3, .05, .012), band(nt, Y_, RY0 + .3, .05, .012)))
wear = noise(nt, tc.outputs['Object'], 7.0, 5, .65)
wm = node(nt, 'ShaderNodeMapRange'); wm.inputs['From Min'].default_value = .38; wm.inputs['From Max'].default_value = .55; L(nt, wear.outputs['Fac'], wm.inputs['Value'])
paint = mth_(nt, 'MULTIPLY', paint, wm.outputs[0])
col = mix(nt, mth_(nt, 'MULTIPLY', paint, .9), col, lin(0xdedcd3))
L(nt, col, b.inputs['Base Color'])
rr_ = b.inputs['Roughness'].links[0].from_socket if b.inputs['Roughness'].links else None
if rr_ is not None:
    r2 = mth_(nt, 'SUBTRACT', rr_, mth_(nt, 'ADD', mth_(nt, 'MULTIPLY', tracks, .12), mth_(nt, 'MULTIPLY', paint, .25)))
    L(nt, r2, b.inputs['Roughness'])
mb = MB(); mb.box(-1500, 1500, RY0, RY1, -.02, .0); mb.obj('road', 'asphalt')
# bordillo de hormigón y acera de adoquín junto a la parcela
m, nt, b = newmat('curb'); M['curb'] = m
if HAVE_PH: pbr(nt, b, 'asphalt_04', 1.5, tint=0xd8d6d0, tint_fac=.5, nstr=.8, rough=(.7, .9))
else: b.inputs['Base Color'].default_value = lin(0xc9c4ba)
mb = MB(); mb.box(-1500, 1500, RY1, RY1 + .16, -.02, .15); mb.obj('curbs', 'curb', .012)
m, nt, b = newmat('pavers'); M['pavers'] = m
if HAVE_PH: pbr(nt, b, 'concrete_pavers', 1.6, tint=0xd2cfc8, tint_fac=.35, nstr=1.0, rough=(.75, .95))
else: b.inputs['Base Color'].default_value = lin(0xb8b2a6)
mb = MB(); mb.box(-1500, 1500, RY1 + .16, -13.66, -.02, .13); mb.obj('sidewalk', 'pavers', .004)
# arcén de tierra y grava al otro lado
m, nt, b = newmat('shoulder'); M['shoulder'] = m
if HAVE_PH: pbr(nt, b, 'gravel_road', 2.0, nstr=1.0, rough=(.85, 1.))
else: b.inputs['Base Color'].default_value = lin(0x7a6a52)
mb = MB(); mb.box(-1500, 1500, RY0 - 1.3, RY0, -.025, -.004); mb.obj('roadshoulder', 'shoulder')
# farolas en la acera (fuste gris oscuro de 6 m, brazo y luminaria plana)
simple('lampmetal', 0x3a3c3e, .45, .8); simple('lampglass', 0xe8ecef, .15)
pole, head, glass_ = MB(), MB(), MB()
for xl in [14 + 34 * k for k in range(-6, 6)]:
    pole.cyl(xl, RY1 + .45, .13, 6.2, .075, 12, r2=.05); pole.box(xl - .03, xl + .03, RY1 - .7, RY1 + .45, 6.12, 6.18)
    head.box(xl - .2, xl + .2, RY1 - 1.15, RY1 - .55, 6.06, 6.16); glass_.box(xl - .17, xl + .17, RY1 - 1.12, RY1 - .58, 6.05, 6.06)
pole.obj('lampposts', 'lampmetal', .006, smooth=True); head.obj('lampheads', 'lampmetal', .01); glass_.obj('lampglass', 'lampglass', 0)
# ------------------------------------------------------------------ luces, cielo, cámara
SUN_EL, SUN_AZ = 33, 145   # sun_rotation: 0=+Y, 90=+X -> sol delante-derecha
if HAVE_PH:
    # kloofendal_38d_partly_cloudy_puresky: sol a 37,9° de altura y azimut -35,9° (atan2) en la imagen;
    # se gira el cielo para dejarlo donde estaba el sol de la escena (azimut 145°, delante a la derecha)
    SUN_EL = 37.9; K_SKY = 1.75
    w = bpy.data.worlds.new('sky'); sc.world = w; w.use_nodes = True; nt = w.node_tree
    tcw = nt.nodes.new('ShaderNodeTexCoord'); mpw = nt.nodes.new('ShaderNodeMapping'); mpw.inputs['Rotation'].default_value = (0, 0, math.radians(19.1))
    env = nt.nodes.new('ShaderNodeTexEnvironment'); env.image = bpy.data.images.load(PH + 'sky.hdr')
    nt.links.new(tcw.outputs['Generated'], mpw.inputs['Vector']); nt.links.new(mpw.outputs[0], env.inputs['Vector'])
    dk = nt.nodes.new('ShaderNodeMixRGB'); dk.blend_type = 'DARKEN'; dk.inputs['Fac'].default_value = 1; dk.inputs['Color2'].default_value = (50, 50, 50, 1)
    nt.links.new(env.outputs[0], dk.inputs['Color1'])
    bg = nt.nodes['Background']; bg.inputs['Strength'].default_value = K_SKY; nt.links.new(dk.outputs[0], bg.inputs[0])
else:
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
if HAVE_PH: sun_d.energy = 2.4 * K_SKY; sun_d.angle = math.radians(.6); sun_d.color = (1.0, .957, .873)   # irradiancia y color medidos del sol del HDRI
sun_d.cycles.is_caustics_light = True
sun = bpy.data.objects.new('sun', sun_d); COL.objects.link(sun)
# dirección de la luz coherente con el cielo: rotación Z = azimut, X = 90-elevación
sun.rotation_euler = Euler((math.radians(90 - SUN_EL), 0, math.radians(SUN_AZ - 180)), 'XYZ')
# Luces interiores cálidas
def area(name, loc, size, energy, color=(1, .82, .6), parent=None, rot=(0, 0, 0)):
    d = bpy.data.lights.new(name, 'AREA'); d.energy = energy; d.size = size; d.color = color
    o = bpy.data.objects.new(name, d); o.location = loc; o.rotation_euler = rot; COL.objects.link(o)
    o.visible_camera = False; o.visible_transmission = False; o.visible_glossy = False   # se ve la luz, no el panel
    if parent: o.parent = parent
    return o
area('in1', (-1.5, 4.5, 3.45), 4.0, 70, parent=G_BASE); area('in2', (2.5, 4.5, 3.45), 3.0, 50, parent=G_BASE)
# focos empotrados (luz cálida de 2.700 K) que dejan círculos de luz en suelo y paredes
dl_ = MB()
for (x_, y_) in ((-3.6, 3.3), (-1.6, 3.3), (.4, 3.3), (-3.6, 5.3), (-1.6, 5.3), (.4, 5.3), (1.5, 2.9), (3.3, 2.9), (2.85, 6.2), (-5.6, 2.6), (-5.6, 5.0), (3.5, 4.4)):
    sd_ = bpy.data.lights.new('spot', 'SPOT'); sd_.energy = 34; sd_.spot_size = math.radians(80); sd_.spot_blend = .55; sd_.shadow_soft_size = .03; sd_.color = (1, .79, .56)
    so_ = bpy.data.objects.new('spot', sd_); so_.location = (x_, y_, 3.56); so_.parent = G_UPPER; COL.objects.link(so_)
    dl_.cyl(x_, y_, 3.585, 3.6, .045, 20)
dl_.obj('ceilspots', 'downlight', 0, G_UPPER)
mb = MB(); mb.box(-6.3, 3.95, 6.6, 6.9, 3.42, 3.6); mb.obj('ledsoffit', 'render', .005, G_UPPER)
mb = MB(); mb.box(-6.25, 3.9, 6.84, 6.88, 3.39, 3.41); mb.obj('ledcove', 'ledwarm', 0, G_UPPER)
mb = MB(); mb.cyl(1.35, 6.35, FZB, FZB + .03, .2, 24); mb.obj('arcbase', 'stoneblanco', 0, G_BASE, smooth=True)
pts_ = [Vector((1.35 - .9 * math.sin(t * math.pi * .55) * 1.0, 6.35 - 1.2 * math.sin(t * math.pi * .55), FZB + 2.05 * math.sin(t * math.pi * .5 + .0))) for t in [k / 14 for k in range(15)]]
ap_ = MB()
for k in range(14):
    p0, p1 = pts_[k], pts_[k + 1]; n0_ = len(ap_.bm.verts); ap_.cyl(0, 0, 0, 1, .012, 6); ap_.bm.verts.ensure_lookup_table()
    ax = p1 - p0; rot = ax.to_track_quat('Z', 'Y').to_matrix()
    for kk in range(n0_, len(ap_.bm.verts)): v = ap_.bm.verts[kk]; v.co = rot @ Vector((v.co.x, v.co.y, v.co.z * ax.length)) + p0
ap_.obj('arcpole', 'black', 0, G_BASE, smooth=True)
pe_ = pts_[-1]; mb = MB(); mb.cyl(pe_.x, pe_.y, pe_.z - .22, pe_.z, .2, 32, r2=.06); mb.obj('arcshade', 'pendmetal', 0, G_BASE, smooth=True)
al_ = bpy.data.lights.new('arclamp', 'POINT'); al_.energy = 30; al_.shadow_soft_size = .06; al_.color = (1, .78, .55)
ao_ = bpy.data.objects.new('arclamp', al_); ao_.location = (pe_.x, pe_.y, pe_.z - .16); ao_.parent = G_BASE; COL.objects.link(ao_)
# cortinas finas a los lados del ventanal del salón y cuadro en la pared de la cocina
for (cx0, cx1) in ((-6.32, -5.65), (3.3, 3.96)):
    cm_ = MB(); n_ = 60
    lo_ = [cm_.bm.verts.new((cx0 + (cx1 - cx0) * i / n_, 1.4 + .045 * math.sin(i / n_ * 7 * 2 * math.pi), .33)) for i in range(n_ + 1)]
    hi_ = [cm_.bm.verts.new((v.co.x, v.co.y, 3.58)) for v in lo_]
    for i in range(n_): cm_.bm.faces.new((lo_[i], lo_[i + 1], hi_[i + 1], hi_[i]))
    cm_.obj('gcurtain', 'sheer', 0, G_BASE, smooth=True)
mb = MB(); mb.box(3.95, 3.99, 3.7, 5.3, 1.35, 2.55); mb.obj('artframe2', 'black', 0, G_BASE)
mb = MB(); mb.box(3.94, 3.95, 3.76, 5.24, 1.41, 2.49); simple('artcanvas2', 0x8d9a8a, .9); mb.obj('artcanvas2', 'artcanvas2', 0, G_BASE)
area('in3', (-4.5, 4.0, 6.85), 4.0, 200, parent=G_UPPER); area('in4', (2.5, .9, 6.85), 3.2, 240, parent=G_UPPER)
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
cy.max_bounces = 12; cy.diffuse_bounces = 2; cy.glossy_bounces = 2; cy.transmission_bounces = 12; cy.volume_bounces = 1; cy.transparent_max_bounces = 12   # vasos con agua: 6-8 superficies
cy.caustics_reflective = False; cy.caustics_refractive = True; cy.sample_clamp_indirect = 8; cy.blur_glossy = 1.0
cy.use_light_tree = True
r.use_persistent_data = True
sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Medium High Contrast'; sc.view_settings.exposure = 0.0
r.film_transparent = False
r.image_settings.file_format = 'PNG'; r.image_settings.color_depth = '8'
sc.use_nodes = True; r.use_compositing = True; ct = sc.node_tree
for n_ in list(ct.nodes): ct.nodes.remove(n_)
rl = ct.nodes.new('CompositorNodeRLayers'); gl = ct.nodes.new('CompositorNodeGlare'); gl.glare_type = 'FOG_GLOW'; gl.quality = 'HIGH'; gl.threshold = 1.2; gl.mix = -.9; gl.size = 7
ld = ct.nodes.new('CompositorNodeLensdist'); ld.use_fit = True; ld.inputs['Dispersion'].default_value = .005
em = ct.nodes.new('CompositorNodeEllipseMask'); em.width = 1.15; em.height = 1.05
bl = ct.nodes.new('CompositorNodeBlur'); bl.filter_type = 'FAST_GAUSS'; bl.use_relative = True; bl.factor_x = 30; bl.factor_y = 30
vm = ct.nodes.new('CompositorNodeMapRange'); vm.inputs['To Min'].default_value = .8; vm.inputs['To Max'].default_value = 1.0
mx_ = ct.nodes.new('CompositorNodeMixRGB'); mx_.blend_type = 'MULTIPLY'
co = ct.nodes.new('CompositorNodeComposite')
ct.links.new(rl.outputs['Image'], gl.inputs['Image']); ct.links.new(gl.outputs['Image'], ld.inputs['Image'])
ct.links.new(em.outputs['Mask'], bl.inputs['Image']); ct.links.new(bl.outputs['Image'], vm.inputs['Value'])
ct.links.new(ld.outputs['Image'], mx_.inputs[1]); ct.links.new(vm.outputs['Value'], mx_.inputs[2]); ct.links.new(mx_.outputs['Image'], co.inputs['Image'])
# ---------------- hierba con partículas de pelo
if not QUICK:
    # Briznas: verdes variados, manchas algo más secas, franjas de corte suaves y base oscura
    m, nt, b = newmat('grass'); M['grass'] = m
    hi = node(nt, 'ShaderNodeHairInfo'); tcg = node(nt, 'ShaderNodeTexCoord')
    green = ramp(nt, hi.outputs['Random'], [(0.0, lin(0x37591e)), (0.35, lin(0x466c27)), (0.7, lin(0x587e2f)), (0.9, lin(0x6a8a36)), (1.0, lin(0x869045))])
    dryc = ramp(nt, hi.outputs['Random'], [(0.0, lin(0x56602f)), (0.6, lin(0x77783c)), (1.0, lin(0x938c52))])
    patch = noise(nt, tcg.outputs['Object'], .22, 4)
    dry = node(nt, 'ShaderNodeMapRange'); dry.inputs['From Min'].default_value = .56; dry.inputs['From Max'].default_value = .78
    dry.inputs['To Max'].default_value = .55; L(nt, patch.outputs['Fac'], dry.inputs['Value'])
    col = mix(nt, dry.outputs[0], green, dryc)
    wv = node(nt, 'ShaderNodeTexWave'); wv.wave_type = 'BANDS'; wv.bands_direction = 'X'; wv.wave_profile = 'SAW'
    wv.inputs['Scale'].default_value = .4; wv.inputs['Distortion'].default_value = 0; L(nt, tcg.outputs['Object'], wv.inputs['Vector'])
    stp = node(nt, 'ShaderNodeMath'); stp.operation = 'GREATER_THAN'; stp.inputs[1].default_value = .5; L(nt, wv.outputs['Fac'], stp.inputs[0])
    stc = node(nt, 'ShaderNodeMapRange'); stc.inputs['To Min'].default_value = .93; stc.inputs['To Max'].default_value = 1.06; L(nt, stp.outputs[0], stc.inputs['Value'])
    col = mix(nt, 1.0, col, stc.outputs[0], 'MULTIPLY')
    ip = node(nt, 'ShaderNodeMath'); ip.operation = 'POWER'; ip.inputs[1].default_value = .55; L(nt, hi.outputs['Intercept'], ip.inputs[0])
    grad = mix(nt, ip.outputs[0], lin(0x17230d), col, 'MIX')
    L(nt, grad, b.inputs['Base Color']); b.inputs['Roughness'].default_value = .5; b.inputs['Specular IOR Level'].default_value = .45
    tl = node(nt, 'ShaderNodeBsdfTranslucent'); L(nt, col, tl.inputs['Color'])
    mxg = node(nt, 'ShaderNodeMixShader'); mxg.inputs[0].default_value = .3; L(nt, b.outputs[0], mxg.inputs[1]); L(nt, tl.outputs[0], mxg.inputs[2])
    L(nt, mxg.outputs[0], nt.nodes['Material Output'].inputs['Surface'])
    lawn = bpy.data.objects['lawn']; lawn.data.materials.append(M['grass'])
    # subdividir el césped para repartir mejor las partículas
    bm = bmesh.new(); bm.from_mesh(lawn.data); bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=10, use_grid_fill=True); bm.to_mesh(lawn.data); bm.free()
    md = lawn.modifiers.new('grass', 'PARTICLE_SYSTEM'); st = lawn.particle_systems[-1].settings
    st.type = 'HAIR'; st.count = 70000; st.hair_length = .06; st.emit_from = 'FACE'; st.distribution = 'RAND'; st.use_emit_random = True
    st.use_advanced_hair = True; st.normal_factor = .055; st.factor_random = .022; st.brownian_factor = 0
    st.child_type = 'INTERPOLATED'; st.child_percent = 1; st.rendered_child_count = 16; st.child_radius = .08; st.child_roundness = 1
    st.child_length = .95; st.child_length_threshold = .4; st.clump_factor = .1; st.roughness_1 = .012; st.roughness_1_size = 1; st.roughness_endpoint = .022
    st.render_step = 3; st.display_step = 2; st.material = 2
    st.root_radius = 1.0; st.tip_radius = 0.0; st.radius_scale = .004; st.use_close_tip = True
print('ESCENA OK', len(bpy.data.objects), 'objetos')
