"""Vegetación mediterránea de la villa (se ejecuta dentro de scene.py y comparte sus funciones).

Olivos, pinos piñoneros y cipreses con ramas de verdad (crecimiento recursivo) y hojas o acículas
en geometría, setos recortados, bolas de pitosporo, lavanda y los árboles del entorno instanciados.
Cada árbol es distinto: forma, tamaño y color por hoja (atributo 'leafvar') y por ejemplar (Object Info)."""

VR = random.Random(2024)
def vr(a, b): return VR.uniform(a, b)
def vdir():
    while True:
        v = Vector((VR.uniform(-1, 1), VR.uniform(-1, 1), VR.uniform(-1, 1)))
        if .05 < v.length <= 1: return v.normalized()

# ------------------------------------------------------------------ materiales
def foliage_mat(name, top, bottom=None, transl=.3, rough=.5, spec=.4, hue_var=.04, val_var=.12):
    """Hoja con color por hoja y por ejemplar, envés distinto (olivo plateado) y luz que la atraviesa."""
    m, nt, b = newmat(name); M[name] = m
    at = node(nt, 'ShaderNodeAttribute'); at.attribute_name = 'leafvar'; at.attribute_type = 'GEOMETRY'
    oi = node(nt, 'ShaderNodeObjectInfo')
    v = node(nt, 'ShaderNodeMath'); v.operation = 'MULTIPLY_ADD'; v.inputs[1].default_value = .8
    r_ = node(nt, 'ShaderNodeMath'); r_.operation = 'MULTIPLY'; r_.inputs[1].default_value = .2; L(nt, oi.outputs['Random'], r_.inputs[0])
    L(nt, at.outputs['Fac'], v.inputs[0]); L(nt, r_.outputs[0], v.inputs[2])
    col = ramp(nt, v.outputs[0], [(p, lin(c)) for p, c in top])
    if bottom:
        geo = node(nt, 'ShaderNodeNewGeometry')
        col = mix(nt, geo.outputs['Backfacing'], col, ramp(nt, v.outputs[0], [(p, lin(c)) for p, c in bottom]))
    hs = node(nt, 'ShaderNodeHueSaturation'); L(nt, col, hs.inputs['Color'])
    hh = node(nt, 'ShaderNodeMapRange'); hh.inputs['To Min'].default_value = .5 - hue_var; hh.inputs['To Max'].default_value = .5 + hue_var
    L(nt, oi.outputs['Random'], hh.inputs['Value']); L(nt, hh.outputs[0], hs.inputs['Hue'])
    wr = node(nt, 'ShaderNodeTexWhiteNoise'); wr.noise_dimensions = '1D'; L(nt, oi.outputs['Random'], wr.inputs['W'])
    vv = node(nt, 'ShaderNodeMapRange'); vv.inputs['To Min'].default_value = 1 - val_var; vv.inputs['To Max'].default_value = 1 + val_var
    L(nt, wr.outputs['Value'], vv.inputs['Value']); L(nt, vv.outputs[0], hs.inputs['Value'])
    col = hs.outputs[0]
    L(nt, col, b.inputs['Base Color']); b.inputs['Roughness'].default_value = rough; b.inputs['Specular IOR Level'].default_value = spec
    tl = node(nt, 'ShaderNodeBsdfTranslucent'); L(nt, col, tl.inputs['Color'])
    mx = node(nt, 'ShaderNodeMixShader'); mx.inputs[0].default_value = transl
    L(nt, b.outputs[0], mx.inputs[1]); L(nt, tl.outputs[0], mx.inputs[2]); L(nt, mx.outputs[0], nt.nodes['Material Output'].inputs['Surface'])
    return m

def bark_mat(name, cols, scale, stretch, fiss=.6, bump_s=.9):
    """Corteza procedural: grietas (Voronoi estirado) + ruido, con relieve."""
    m, nt, b = newmat(name); M[name] = m
    tc = node(nt, 'ShaderNodeTexCoord'); mp = node(nt, 'ShaderNodeMapping')
    mp.inputs['Scale'].default_value = (scale, scale, scale / stretch); L(nt, tc.outputs['Object'], mp.inputs['Vector'])
    vo = node(nt, 'ShaderNodeTexVoronoi'); vo.feature = 'DISTANCE_TO_EDGE'; vo.inputs['Randomness'].default_value = .9
    L(nt, mp.outputs[0], vo.inputs['Vector'])
    n1 = noise(nt, mp.outputs[0], 3.0, 6, .6); n2 = noise(nt, tc.outputs['Object'], .7, 3)
    fis = node(nt, 'ShaderNodeMapRange'); fis.inputs['From Min'].default_value = 0; fis.inputs['From Max'].default_value = .12 * fiss
    L(nt, vo.outputs['Distance'], fis.inputs['Value'])
    h = node(nt, 'ShaderNodeMath'); h.operation = 'MULTIPLY_ADD'; L(nt, fis.outputs[0], h.inputs[0]); h.inputs[1].default_value = .75; L(nt, n1.outputs['Fac'], h.inputs[2])
    c = ramp(nt, n1.outputs['Fac'], [(p, lin(cc)) for p, cc in cols])
    c = mix(nt, n2.outputs['Fac'], c, lin(cols[-1][1]), 'OVERLAY')
    c = mix(nt, fis.outputs[0], lin(0x221c16), c)
    L(nt, c, b.inputs['Base Color']); b.inputs['Roughness'].default_value = .95; b.inputs['Specular IOR Level'].default_value = .2
    L(nt, bump(nt, h.outputs[0], bump_s, .03), b.inputs['Normal'])
    return m

foliage_mat('olive_leaf', [(0, 0x3c4a31), (.45, 0x48563a), (.8, 0x546043), (1, 0x5f694a)],
            [(0, 0x727d66), (.5, 0x808a72), (1, 0x8e977f)], transl=.22, rough=.42, spec=.5)
foliage_mat('pine_needle', [(0, 0x334a24), (.4, 0x3f5a2b), (.75, 0x4b6631), (1, 0x5d7038)], transl=.3, rough=.55, spec=.35, hue_var=.06, val_var=.2)
foliage_mat('cypress_leaf', [(0, 0x1f3319), (.45, 0x29401f), (.8, 0x324a24), (1, 0x3f5529)], transl=.15, rough=.6, spec=.3, hue_var=.025)
foliage_mat('hedge_leaf', [(0, 0x2f4d1f), (.4, 0x3b5d26), (.75, 0x4a6c2e), (1, 0x5a7a36)], transl=.25, rough=.45, spec=.45)
foliage_mat('box_leaf', [(0, 0x35541f), (.5, 0x456a28), (1, 0x587a31)], transl=.25, rough=.4, spec=.5)
foliage_mat('lav_leaf', [(0, 0x6f7d66), (.5, 0x83907a), (1, 0x97a18c)], transl=.2, rough=.6, spec=.3)
foliage_mat('lav_flower', [(0, 0x5d4a8c), (.5, 0x7a62a8), (1, 0x8e78b8)], transl=.35, rough=.6, spec=.25, hue_var=.02)
bark_mat('olive_bark', [(0, 0x57514a), (.5, 0x746d61), (1, 0x8d8576)], 18, 3.0, .8, 1.0)
bark_mat('pine_bark', [(0, 0x382a22), (.45, 0x4c392d), (.8, 0x5c4534), (1, 0x67503f)], 8, 2.5, 1.0, 1.0)
bark_mat('cypress_bark', [(0, 0x3e3328), (1, 0x5e4d3c)], 14, 5.0, .5, .6)
simple('innerdark', 0x17240f, 1., spec=.2)
simple('pine_inner', 0x1f3015, 1., spec=.2)

# ------------------------------------------------------------------ geometría
class Geo:
    """Acumula vértices y caras en listas y crea el objeto de una vez."""
    def __init__(s): s.V = []; s.F = []; s.var = []
    def face(s, pts, var=0.):
        n = len(s.V); s.V += [tuple(p) for p in pts]; s.F.append(tuple(range(n, n + len(pts)))); s.var.append(var)
    def obj(s, name, mat, smooth=False, coll=None):
        me = bpy.data.meshes.new(name); me.from_pydata(s.V, [], s.F); me.update()
        if smooth: me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
        at = me.attributes.new('leafvar', 'FLOAT', 'FACE'); at.data.foreach_set('value', s.var)
        ob = bpy.data.objects.new(name, me); (coll or COL).objects.link(ob); me.materials.append(M[mat])
        return ob

def tube(g, pts, rads, k=8, bumps=0.):
    """Rama: anillos a lo largo de la polilínea (marco transportado, sin giros bruscos)."""
    rings = []; u = None; n = len(pts)
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        u = t.orthogonal().normalized() if u is None else (u - t * u.dot(t)).normalized()
        v = t.cross(u); base = len(g.V)
        for j in range(k):
            a = 2 * math.pi * j / k
            rr_ = rads[i] * (1 + bumps * (math.sin(a * 2 + i * 1.7) * .5 + math.sin(a * 3 - i * .9) * .35))
            g.V.append(tuple(p + (u * math.cos(a) + v * math.sin(a)) * rr_))
        rings.append(base)
    for i in range(n - 1):
        a0, a1 = rings[i], rings[i + 1]
        for j in range(k):
            g.F.append((a0 + j, a0 + (j + 1) % k, a1 + (j + 1) % k, a1 + j)); g.var.append(0.)
    # tapa en la punta
    if rads[-1] > .004:
        tip = len(g.V); g.V.append(tuple(pts[-1] + (pts[-1] - pts[-2]).normalized() * rads[-1] * .6))
        a0 = rings[-1]
        for j in range(k): g.F.append((a0 + j, a0 + (j + 1) % k, tip)); g.var.append(0.)

def leaf6(g, p, d, nrm, Ln, W, var, curl=.15):
    """Hoja lanceolada (6 vértices) con la cara superior hacia nrm y la punta algo caída."""
    side = d.cross(nrm).normalized(); up = side.cross(d).normalized()
    a1 = p + d * (Ln * .28) + side * (W * .5); b1 = p + d * (Ln * .28) - side * (W * .5)
    a2 = p + d * (Ln * .7) + side * (W * .36) - up * (curl * Ln * .3); b2 = p + d * (Ln * .7) - side * (W * .36) - up * (curl * Ln * .3)
    tip = p + d * Ln - up * (curl * Ln)
    g.face((p, b1, a1), var); g.face((a1, b1, b2, a2), var); g.face((a2, b2, tip), var)

def needle_tuft(g, p, d, n, Ln, var):
    """Penacho de acículas de pino: abanico hacia delante y arriba desde la punta de la ramilla."""
    for _ in range(n):
        q = (d * 1.0 + vdir() * .75 + Vector((0, 0, .25))).normalized()
        L_ = Ln * vr(.75, 1.15); w = .003
        s = q.orthogonal().normalized() * w
        base = p + q * vr(0, .02)
        g.face((base - s, base + s, base + q * L_), var + vr(-.08, .08))

def spray(g, p, d, nrm, Ln, var):
    """Ramillete de escamas de ciprés (textura fina y densa)."""
    leaf6(g, p, d, nrm, Ln, Ln * .5, var, .05)

def grow(bark, sink, p0, d0, length, r0, lvl, S):
    """Crecimiento recursivo de una rama y sus hijas; en el último nivel se llama a sink (hojas)."""
    nseg = max(3, int(length / S['seg'][lvl]))
    pts = [p0.copy()]; rads = [r0]; d = d0.copy(); p = p0.copy()
    for i in range(1, nseg + 1):
        t = i / nseg
        d = (d + vdir() * S['wob'][lvl] + Vector((0, 0, S['trop'][lvl]))).normalized()
        p = p + d * (length / nseg); pts.append(p.copy()); rads.append(max(.0025, r0 * (1 - t * S['taper'][lvl])))
    if lvl < S['skip_bark']: tube(bark, pts, rads, S['sides'][lvl], S['bumps'][lvl])
    if lvl == len(S['kids']):
        sink(pts, rads); return
    nk = S['kids'][lvl]; az0 = vr(0, 2 * math.pi)
    for c in range(nk):
        t = vr(S['kstart'][lvl], 1.0) if nk > 1 else 1.0
        idx = t * (len(pts) - 1); i0 = min(len(pts) - 2, int(idx)); f = idx - i0
        pc = pts[i0].lerp(pts[i0 + 1], f); rc = (rads[i0] * (1 - f) + rads[i0 + 1] * f)
        par = (pts[i0 + 1] - pts[i0]).normalized()
        az = az0 + c * 2.39996 + vr(-.35, .35); ang = math.radians(vr(*S['angle'][lvl]))   # ángulo áureo: hijas repartidas alrededor
        u = par.orthogonal().normalized(); u = Matrix.Rotation(az, 3, par) @ u
        dc = (par * math.cos(ang) + u * math.sin(ang)).normalized()
        dc = (dc + Vector((0, 0, S['kup'][lvl]))).normalized()
        grow(bark, sink, pc, dc, length * S['klen'][lvl] * vr(.7, 1.15) * (1.15 - .4 * t if S['shape'] else 1), rc * S['krad'][lvl], lvl + 1, S)

# --- olivo: tronco corto y retorcido que se abre en 2-3 brazos; copa redonda e irregular de hojas plateadas
OLIVE = dict(seg=[.1, .12, .12, .08, .05], wob=[.1, .16, .2, .25, .3], trop=[.12, .1, .05, 0., -.04], taper=[.3, .5, .6, .65, .6],
             sides=[14, 10, 7, 5, 4], bumps=[.28, .15, .05, 0, 0], kids=[3, 7, 7, 6], kstart=[.82, .3, .2, .15],
             angle=[(30, 45), (35, 65), (30, 60), (30, 60)], kup=[.05, .1, .05, 0.], klen=[1.35, .7, .6, .55], krad=[.68, .5, .5, .55],
             skip_bark=5, shape=True)
def olive_tree(bark, lv, hgt):
    def sink(pts, rads):
        if pts[-1].z < hgt * .3: return   # sin hojas en lo bajo: se ve el tronco
        # ramilla con hojas en pares opuestos
        n = len(pts)
        for i in range(1, n):
            p = pts[i]; d = (pts[i] - pts[i - 1]).normalized()
            for k in range(3):
                q = pts[i - 1].lerp(p, (k + 1) / 3)
                side = d.orthogonal().normalized(); side = Matrix.Rotation(vr(0, 6.28), 3, d) @ side
                for s in (-1, 1):
                    ld = (d * .65 + side * s * .75 + Vector((0, 0, .15))).normalized()
                    nrm = (Vector((0, 0, 1)) + vdir() * .6).normalized()
                    leaf6(lv, q, ld, nrm, vr(.05, .075), vr(.011, .015), VR.random(), vr(.1, .3))
        # ramillete en la punta
        tipd = (pts[-1] - pts[-2]).normalized()
        for s in range(12):
            ld = (tipd + vdir() * .7).normalized()
            leaf6(lv, pts[-1] + vdir() * .04, ld, (Vector((0, 0, 1)) + vdir() * .6).normalized(), vr(.05, .07), .012, VR.random(), .2)
    grow(bark, sink, Vector((0, 0, -.05)), Vector((vr(-.15, .15), vr(-.15, .15), 1)).normalized(), hgt * .27, vr(.22, .28), 0, OLIVE)

# --- pino piñonero: fuste alto, se abre arriba en brazos que forman una copa plana en sombrilla
PINE = dict(seg=[.5, .35, .25, .15, .09], wob=[.03, .08, .12, .18, .2], trop=[.04, .09, .08, .1, .12], taper=[.45, .6, .65, .65, .6],
            sides=[14, 10, 7, 5, 4], bumps=[.06, .04, .02, 0, 0], kids=[8, 7, 6, 5], kstart=[.84, .3, .3, .3],
            angle=[(60, 80), (45, 80), (30, 60), (25, 50)], kup=[-.05, .15, .25, .3], klen=[.74, .52, .55, .5], krad=[.55, .5, .5, .5],
            skip_bark=5, shape=True)
def pine_tree(bark, lv, hgt, inner=None):
    def sink(pts, rads):
        if inner is not None:   # mata oscura dentro del penacho: copa densa vista desde arriba
            c = pts[-1] + Vector((0, 0, .05)); rad = vr(.1, .16)
            for k_ in range(3):
                q = c + vdir() * rad * .5
                tube(inner, [q - Vector((0, 0, rad * .5)), q, q + Vector((0, 0, rad * .4))], [rad * .5, rad, rad * .3], 5)
        n = len(pts)
        for i in range(1, n):
            d = (pts[i] - pts[i - 1]).normalized()
            needle_tuft(lv, pts[i], (d + Vector((0, 0, .4))).normalized(), 18, vr(.14, .2), VR.random())
        d = (pts[-1] - pts[-2]).normalized()
        for k in range(4):
            needle_tuft(lv, pts[-1] + vdir() * .1, (d + Vector((0, 0, .7)) + vdir() * .45).normalized(), 30, vr(.16, .23), VR.random())
    grow(bark, sink, Vector((0, 0, -.1)), Vector((vr(-.06, .06), vr(-.06, .06), 1)).normalized(), hgt * .5, vr(.34, .44), 0, PINE)

# --- ciprés: columna estrecha y densa de ramilletes, con lóbulos verticales y núcleo oscuro
def cypress_tree(bark, lv, inner, hgt):
    R0 = vr(.75, .95)
    tube(bark, [Vector((0, 0, -.1)), Vector((0, 0, .8)), Vector((0, 0, hgt * .9))], [.16, .13, .03], 9)
    def prof(t): return R0 * math.sin(min(1., (1 - t) * 1.25 + .06) * math.pi * .55) * (1 - .25 * t) * (.55 + .45 * min(1, t * 6))
    # núcleo oscuro para que no se transparente (queda bien dentro)
    zs = [.4 + (hgt - .3) * i / 16 for i in range(17)]
    tube(inner, [Vector((0, 0, z)) for z in zs], [max(.03, prof((z - .3) / hgt) * .62) for z in zs], 10)
    lobes = [(vr(0, 6.28), vr(.25, 1.0)) for _ in range(int(hgt * 5))]
    n = int(hgt * 3400)
    for _ in range(n):
        t = VR.random() ** .9; z = .35 + t * (hgt - .35)
        a = vr(0, 6.28); lob = min(lobes, key=lambda l: abs(((a - l[0] + 3.14) % 6.28) - 3.14) + abs(l[1] - t) * 2)
        bulge = .88 + .12 * math.cos((a - lob[0]) * 3)
        r = prof(t) * bulge * (VR.random() ** .35)
        p = Vector((math.cos(a) * r, math.sin(a) * r, z))
        out = Vector((math.cos(a), math.sin(a), 0))
        d = (Vector((0, 0, 1)) * 1.4 + out * .55 + vdir() * .35).normalized()
        spray(lv, p, d, (out + vdir() * .4).normalized(), vr(.04, .065), VR.random())

# --- seto recortado (tramo de 1 m) y bola de pitosporo
def hedge_segment(lv, inner, length, h, d):
    tube(inner, [Vector((0, 0, .05)), Vector((0, 0, h - .1))], [d * .32, d * .32], 4)
    area = 2 * length * h + length * d
    n = int(area * 2600)
    for _ in range(n):
        side = VR.random() * area
        if side < length * h * 2:
            sgn = 1 if side < length * h else -1
            x = vr(-length / 2, length / 2); z = vr(.04, h - .02) ** 1.0
            y = sgn * (d / 2) * vr(.86, 1.04) * (1 - .1 * (1 - z / h))
            out = Vector((0, sgn, 0))
        else:
            x = vr(-length / 2, length / 2); y = vr(-d / 2, d / 2) * .95; z = h * vr(.96, 1.02); out = Vector((0, 0, 1))
        p = Vector((x, y, z)); ld = (vdir() + out * .6).normalized()
        leaf6(lv, p, ld, (out + vdir() * .7).normalized(), vr(.03, .045), vr(.014, .02), VR.random(), .2)

def ball_shrub(lv, inner, rad, mat_leaf=None):
    ret_c = Vector((0, 0, rad * .92))
    zs = [ret_c.z - rad * .8 + rad * 1.6 * i / 6 for i in range(7)]
    tube(inner, [Vector((0, 0, z)) for z in zs], [max(.02, rad * .7 * math.sqrt(max(0, 1 - ((z - ret_c.z) / rad) ** 2))) for z in zs], 8)
    n = int(4 * math.pi * rad * rad * 3200)
    for _ in range(n):
        u = vdir(); r = rad * vr(.9, 1.03)
        p = ret_c + Vector((u.x * r, u.y * r, u.z * r * .92))
        if p.z < .03: continue
        leaf6(lv, p, (vdir() + u * .5).normalized(), (u + vdir() * .7).normalized(), vr(.022, .032), vr(.011, .015), VR.random(), .15)

# --- lavanda: mata de hojas grises con espigas moradas
def lavender(lv, fl, rad):
    for _ in range(int(rad * rad * 2600)):
        a = vr(0, 6.28); r = rad * math.sqrt(VR.random()) * .85
        p = Vector((math.cos(a) * r, math.sin(a) * r, vr(.02, rad * .5)))
        d = (Vector((math.cos(a), math.sin(a), 1.3)) + vdir() * .5).normalized()
        leaf6(lv, p, d, (Vector((0, 0, 1)) + vdir()).normalized(), vr(.03, .05), .005, VR.random(), .1)
    for _ in range(int(rad * rad * 420)):
        a = vr(0, 6.28); r = rad * math.sqrt(VR.random()) * .7
        p = Vector((math.cos(a) * r, math.sin(a) * r, rad * .35))
        d = (Vector((math.cos(a) * r * 1.2, math.sin(a) * r * 1.2, 1)) + vdir() * .12).normalized()
        top = p + d * vr(.25, .4)
        tube(lv, [p, top], [.0018, .0012], 3)
        lv.var[-1] = .5
        for k in range(7):
            q = top + d * (k * .012)
            leaf6(fl, q, (d + vdir() * .4).normalized(), (vdir()).normalized(), .016, .009, VR.random(), 0)

# ------------------------------------------------------------------ prototipos (colecciones instanciables)
proto = {}
def make_proto(name, build):
    col = bpy.data.collections.new(name); parts = build()
    for (g, mat, smooth) in parts:
        if g.F: g.obj(name + '_' + mat, mat, smooth, col)
    proto[name] = col
    return col

def olive_parts(h):
    bark, lv = Geo(), Geo(); olive_tree(bark, lv, h); return [(bark, 'olive_bark', True), (lv, 'olive_leaf', False)]
def pine_parts(h):
    bark, lv, inner = Geo(), Geo(), Geo(); pine_tree(bark, lv, h, inner)
    return [(bark, 'pine_bark', True), (lv, 'pine_needle', False), (inner, 'pine_inner', True)]
def cypress_parts(h):
    bark, lv, inner = Geo(), Geo(), Geo(); cypress_tree(bark, lv, inner, h)
    return [(bark, 'cypress_bark', True), (lv, 'cypress_leaf', False), (inner, 'innerdark', True)]
def hedge_parts(h, d):
    lv, inner = Geo(), Geo(); hedge_segment(lv, inner, 1.02, h, d); return [(lv, 'hedge_leaf', False), (inner, 'innerdark', False)]
def ball_parts(r):
    lv, inner = Geo(), Geo(); ball_shrub(lv, inner, r); return [(lv, 'box_leaf', False), (inner, 'innerdark', True)]
def lav_parts(r):
    lv, fl = Geo(), Geo(); lavender(lv, fl, r); return [(lv, 'lav_leaf', False), (fl, 'lav_flower', False)]

VEG_ONLY = os.environ.get('UNIKAL_VEG_ONLY')   # pruebas: generar solo algunos prototipos
for nm, fn in (('oliveA', lambda: olive_parts(5.2)), ('oliveB', lambda: olive_parts(4.4)), ('oliveC', lambda: olive_parts(5.8)),
               ('pineA', lambda: pine_parts(13.5)), ('pineB', lambda: pine_parts(11.5)),
               ('cypressA', lambda: cypress_parts(10.5)), ('cypressB', lambda: cypress_parts(8.5)),
               ('hedgeT', lambda: hedge_parts(1.95, .75)), ('hedgeL', lambda: hedge_parts(1.0, .6)),
               ('ballA', lambda: ball_parts(.55)), ('ballB', lambda: ball_parts(.4)), ('lavA', lambda: lav_parts(.38))):
    if VEG_ONLY and nm not in VEG_ONLY.split(','): continue
    make_proto(nm, fn)
    print('vegetación:', nm, flush=True)

def place(kind, x, y, s=1.0, rot=None, sz=None, name=None):
    if kind not in proto: return None
    e = bpy.data.objects.new(name or ('veg_' + kind), None); e.instance_type = 'COLLECTION'; e.instance_collection = proto[kind]
    e.location = (x, y, 0); e.rotation_euler.z = vr(0, 6.28) if rot is None else rot
    e.scale = (s, s, s * (sz or vr(.94, 1.06))); COL.objects.link(e); return e

if not VEG_ONLY:
    # ---------------- jardín
    # setos altos en los laterales y el fondo; seto bajo delante (deja libre la puerta)
    x = -15.0
    while x <= 17.0:
        place('hedgeT', x, 12.75, 1, rot=0, sz=1); x += 1.0
    y = -12.4
    while y <= 12.2:
        place('hedgeT', -15.3, y, 1, rot=math.pi / 2, sz=1); place('hedgeT', 17.3, y, 1, rot=math.pi / 2, sz=1); y += 1.0
    x = -15.0
    while x <= 17.0:
        if not (-2.3 < x < 4.3): place('hedgeL', x, -12.95, 1, rot=0, sz=1)
        x += 1.0
    # cipreses en hilera delante del seto del fondo y flanqueando la entrada
    x = -12.6
    while x <= 15.5:
        place('cypressA' if VR.random() < .6 else 'cypressB', x + vr(-.15, .15), 11.7 + vr(-.1, .1), vr(.9, 1.08)); x += 2.6
    # olivos en el césped
    for (kind, x, y, s) in (('oliveA', 13.2, -7.2, 1.0), ('oliveC', -13.0, -1.2, .95), ('oliveB', 13.6, 3.9, 1.05), ('oliveA', -12.6, 8.4, .9),
                            ('oliveB', 2.2, -12.0, .7)):
        place(kind, x, y, s)
    # pinos piñoneros grandes en las esquinas del fondo
    place('pineA', -13.4, 10.2, 1.0); place('pineB', 15.6, 9.8, 1.05)
    # bolas de pitosporo y lavanda
    for (kind, x, y, s) in (('ballA', 9.3, .6, 1.0), ('ballB', 8.2, .9, 1.0), ('ballA', 7.6, -1.6, .8), ('ballA', -11.2, -4.4, 1.1), ('ballB', -10.4, -5.6, 1.0),
                            ('ballA', 12.0, -10.6, 1.0), ('ballB', 12.9, -11.3, .9), ('ballA', -12.6, -9.6, 1.0), ('ballB', -11.8, -10.4, .9),
                            ('ballA', -10.2, 1.8, .9), ('ballA', 11.4, 6.0, 1.0), ('ballB', -12.2, 5.0, 1.0)):
        place(kind, x, y, s)
    for (bx, by, w, d) in ((8.4, .5, 2.2, .9), (-11.4, -5, 1.2, 2), (12.6, -6.8, 1.4, 2.4), (-10.6, 2.8, 1.2, 1.4)):
        for i in range(int(w * d * 2.2)):
            place('lavA', bx + vr(-w, w) * .9, by + vr(-d, d) * .9, vr(.8, 1.2))
    for i in range(14):
        place('lavA', -9.4 + i * .45, -11.95 + vr(-.05, .05), vr(.85, 1.1))

    # ---------------- entorno: pinares en manchas, olivares en hileras y cipreses junto a las casas
    def blocked(x, y):
        if -21 < x < 23 and -22 < y < 18: return True
        if -21.5 < y < -14: return True   # carretera
        if -75 < x < 75 and -110 < y < -21: return VR.random() > .1   # corredor de la cámara casi despejado
        for (hx, hy, w, d) in NEIGH:
            if abs(x - hx) < w / 2 + 5 and abs(y - hy) < d / 2 + 6: return True
        return False
    groves = [(vr(-420, 420), vr(-200, 420), vr(20, 55)) for _ in range(30)]
    def pine_density(x, y):
        return max(math.exp(-((x - gx) ** 2 + (y - gy) ** 2) / (2 * gr * gr)) for gx, gy, gr in groves)
    cnt = 0; tries = 0
    while cnt < 380 and tries < 60000:
        tries += 1
        d = 30 + (VR.random() ** .9) * 430; a = vr(0, 2 * math.pi); x, y = math.cos(a) * d * 1.1, math.sin(a) * d
        if blocked(x, y) or VR.random() > .02 + .98 * pine_density(x, y) ** 1.5: continue
        place('pineA' if VR.random() < .5 else 'pineB', x, y, vr(.7, 1.25)); cnt += 1
    # olivares (hileras de 7 m) en parcelas sueltas
    for _ in range(9):
        cx, cy = vr(-380, 380), vr(-150, 380); ang = vr(0, 3.14); nx_, ny_ = VR.randint(5, 11), VR.randint(4, 9)
        ca, sa = math.cos(ang), math.sin(ang)
        for i in range(nx_):
            for j in range(ny_):
                lx, ly = (i - nx_ / 2) * 7 + vr(-.5, .5), (j - ny_ / 2) * 7 + vr(-.5, .5)
                x, y = cx + lx * ca - ly * sa, cy + lx * sa + ly * ca
                if not blocked(x, y): place(VR.choice(['oliveA', 'oliveB', 'oliveC']), x, y, vr(.75, 1.0))
    # matorral (lentisco, coscoja) en manchas sobre el campo
    cnt = 0; tries = 0
    while cnt < 1400 and tries < 40000:
        tries += 1
        d = 26 + (VR.random() ** 1.2) * 300; a = vr(0, 2 * math.pi); x, y = math.cos(a) * d * 1.1, math.sin(a) * d
        if blocked(x, y) or VR.random() > .15 + .85 * pine_density(x * .8 + 40, y * .8 - 30): continue
        e = place('ballA' if VR.random() < .5 else 'ballB', x, y, 1)
        if e: s_ = vr(1.1, 2.6); e.scale = (s_ * vr(.8, 1.3), s_ * vr(.8, 1.3), s_ * vr(.55, .9))
        cnt += 1
    # cipreses y olivos en los jardines vecinos
    for (hx, hy, w, d) in NEIGH:
        for k in range(VR.randint(3, 6)):
            place('cypressA' if VR.random() < .5 else 'cypressB', hx + w / 2 + 3 + k * 2.4, hy + d / 2 + 4, vr(.85, 1.05))
        place(VR.choice(['oliveA', 'oliveB']), hx - w / 2 - 3, hy - d / 2 - 5, vr(.8, 1.0))
        place('pineA', hx + vr(-w, w), hy + d / 2 + 9, vr(.85, 1.1))
