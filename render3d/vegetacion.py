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
foliage_mat('oak_leaf', [(0, 0x26401b), (.45, 0x305022), (.8, 0x3a5c28), (1, 0x476830)],
            [(0, 0x4a5e36), (.5, 0x56693f), (1, 0x627448)], transl=.25, rough=.45, spec=.45, hue_var=.05, val_var=.18)
foliage_mat('pine_needle', [(0, 0x334a24), (.4, 0x3f5a2b), (.75, 0x4b6631), (1, 0x5d7038)], transl=.3, rough=.55, spec=.35, hue_var=.06, val_var=.2)
foliage_mat('cypress_leaf', [(0, 0x1f3319), (.45, 0x29401f), (.8, 0x324a24), (1, 0x3f5529)], transl=.15, rough=.6, spec=.3, hue_var=.025)
foliage_mat('hedge_leaf', [(0, 0x2f4d1f), (.4, 0x3b5d26), (.75, 0x4a6c2e), (1, 0x5a7a36)], transl=.25, rough=.45, spec=.45)
foliage_mat('box_leaf', [(0, 0x35541f), (.5, 0x456a28), (1, 0x587a31)], transl=.25, rough=.4, spec=.5)
foliage_mat('lav_leaf', [(0, 0x6f7d66), (.5, 0x83907a), (1, 0x97a18c)], transl=.2, rough=.6, spec=.3)
foliage_mat('lav_flower', [(0, 0x5d4a8c), (.5, 0x7a62a8), (1, 0x8e78b8)], transl=.35, rough=.6, spec=.25, hue_var=.02)
bark_mat('olive_bark', [(0, 0x57514a), (.5, 0x746d61), (1, 0x8d8576)], 18, 3.0, .8, 1.0)
bark_mat('pine_bark', [(0, 0x382a22), (.45, 0x4c392d), (.8, 0x5c4534), (1, 0x67503f)], 8, 2.5, 1.0, 1.0)
bark_mat('cypress_bark', [(0, 0x3e3328), (1, 0x5e4d3c)], 14, 5.0, .5, .6)
if HAVE_PH:   # cortezas fotografiadas (Poly Haven)
    for nm_, tex_, size_, tint_ in (('olive_bark', 'tree_bark_03', .8, 0x9a958a), ('pine_bark', 'pine_bark', 1.2, None), ('cypress_bark', 'chinese_cedar_bark', 1.0, None)):
        m, nt, b = newmat(nm_); M[nm_] = m
        pbr(nt, b, tex_, size_, tint=tint_, tint_fac=.5, nstr=1.2, rough=(.8, 1.))
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

# --- encina: tronco corto, copa redonda, muy densa y oscura (el árbol del bosque mediterráneo)
OAK = dict(seg=[.15, .16, .12, .08, .05], wob=[.08, .14, .2, .25, .3], trop=[.08, .08, .04, 0., -.04], taper=[.35, .5, .6, .65, .6],
           sides=[12, 9, 6, 5, 4], bumps=[.12, .08, .03, 0, 0], kids=[4, 7, 7, 6], kstart=[.75, .25, .2, .15],
           angle=[(30, 50), (35, 70), (30, 65), (30, 65)], kup=[.08, .1, .05, 0.], klen=[1.25, .7, .6, .55], krad=[.6, .5, .5, .55],
           skip_bark=5, shape=True)
def oak_tree(bark, lv, hgt):
    def sink(pts, rads):
        n = len(pts)
        for i in range(1, n):
            p = pts[i]; d = (pts[i] - pts[i - 1]).normalized()
            for k in range(3):
                q = pts[i - 1].lerp(p, (k + 1) / 3)
                side = Matrix.Rotation(vr(0, 6.28), 3, d) @ d.orthogonal().normalized()
                for s in (-1, 1):
                    ld = (d * .5 + side * s * .8 + Vector((0, 0, .2))).normalized()
                    leaf6(lv, q, ld, (Vector((0, 0, 1)) + vdir() * .5).normalized(), vr(.045, .065), vr(.024, .032), VR.random(), vr(.05, .2))
        tipd = (pts[-1] - pts[-2]).normalized()
        for s in range(14):
            leaf6(lv, pts[-1] + vdir() * .06, (tipd + vdir() * .8).normalized(), (Vector((0, 0, 1)) + vdir() * .5).normalized(), vr(.045, .065), .028, VR.random(), .15)
    grow(bark, sink, Vector((0, 0, -.05)), Vector((vr(-.08, .08), vr(-.08, .08), 1)).normalized(), hgt * .2, vr(.25, .34), 0, OAK)

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
def hedge_segment(lv, inner, length, h, d, rough=0., holes=0, dens=1.):
    """Tramo de seto. rough: abombamientos y borde superior irregular (m); holes: huecos donde se ve el interior;
    dens: densidad de hojas. Con rough=0 es el seto recortado perfecto de antes."""
    tube(inner, [Vector((0, 0, .05)), Vector((0, 0, h - .1))], [d * .32, d * .32], 4)
    for _ in range(int(rough * 40)):   # ramitas sueltas por dentro (se ven en los huecos)
        p0 = Vector((vr(-length / 2, length / 2), vr(-d * .2, d * .2), vr(.2, h - .2)))
        tube(inner, [p0, p0 + Vector((0, VR.choice((-1, 1)) * d * vr(.3, .45), vr(-.1, .15)))], [.012, .006], 4)
    ph = [vr(0, 6.28) for _ in range(6)]
    def bulge(x, z):   # abombamiento suave de la cara (no es un plano recortado a cuchilla)
        return rough * (math.sin(x * 3.1 + ph[0]) * math.sin(z * 2.3 + ph[1]) * .6 + math.sin(x * 7.7 + z * 5.1 + ph[2]) * .4)
    def top(x):
        return h + rough * (.6 * math.sin(x * 2.7 + ph[3]) + .4 * math.sin(x * 6.9 + ph[4]))
    hl = [(vr(-length / 2, length / 2), vr(.25, h - .2), vr(.12, .3), VR.choice((-1, 1))) for _ in range(holes)]
    def in_hole(x, z, sgn):
        return any(sg == sgn and (x - hx) ** 2 + ((z - hz) * .8) ** 2 < hr * hr for hx, hz, hr, sg in hl)
    area = 2 * length * h + length * d
    n = int(area * 2600 * dens)
    for _ in range(n):
        side = VR.random() * area
        if side < length * h * 2:
            sgn = 1 if side < length * h else -1
            x = vr(-length / 2, length / 2); z = vr(.04, h - .02) ** 1.0
            if z > top(x) - .02: continue
            y = sgn * ((d / 2) * vr(.86, 1.04) * (1 - .1 * (1 - z / h)) + bulge(x, z))
            if in_hole(x, z, sgn): y *= vr(.35, .6)   # hueco: hojas más adentro y más claras de cantidad
            out = Vector((0, sgn, 0))
        else:
            x = vr(-length / 2, length / 2); y = vr(-d / 2, d / 2) * .95; z = top(x) * vr(.96, 1.02); out = Vector((0, 0, 1))
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
def oak_parts(h):
    bark, lv = Geo(), Geo(); oak_tree(bark, lv, h); return [(bark, 'olive_bark', True), (lv, 'oak_leaf', False)]
def pine_parts(h):
    bark, lv, inner = Geo(), Geo(), Geo(); pine_tree(bark, lv, h, inner)
    return [(bark, 'pine_bark', True), (lv, 'pine_needle', False), (inner, 'pine_inner', True)]
def cypress_parts(h):
    bark, lv, inner = Geo(), Geo(), Geo(); cypress_tree(bark, lv, inner, h)
    return [(bark, 'cypress_bark', True), (lv, 'cypress_leaf', False), (inner, 'innerdark', True)]
def hedge_parts(h, d, rough=0., holes=0, dens=1.):
    lv, inner = Geo(), Geo(); hedge_segment(lv, inner, 1.02, h, d, rough, holes, dens); return [(lv, 'hedge_leaf', False), (inner, 'innerdark', False)]
def ball_parts(r):
    lv, inner = Geo(), Geo(); ball_shrub(lv, inner, r); return [(lv, 'box_leaf', False), (inner, 'innerdark', True)]
def lav_parts(r):
    lv, fl = Geo(), Geo(); lavender(lv, fl, r); return [(lv, 'lav_leaf', False), (fl, 'lav_flower', False)]

VEG_ONLY = os.environ.get('UNIKAL_VEG_ONLY')   # pruebas: generar solo algunos prototipos
for nm, fn in (('oliveA', lambda: olive_parts(5.2)), ('oliveB', lambda: olive_parts(4.4)), ('oliveC', lambda: olive_parts(5.8)),
               ('oakA', lambda: oak_parts(9.5)), ('oakB', lambda: oak_parts(8.0)), ('oakC', lambda: oak_parts(10.5)),
               ('pineA', lambda: pine_parts(13.5)), ('pineB', lambda: pine_parts(11.5)), ('pineC', lambda: pine_parts(15.0)),
               ('cypressA', lambda: cypress_parts(10.5)), ('cypressB', lambda: cypress_parts(8.5)),
               ('hedgeT', lambda: hedge_parts(1.95, .75, .035, 0)), ('hedgeT2', lambda: hedge_parts(1.95, .75, .05, 2, .85)),
               ('hedgeT3', lambda: hedge_parts(1.95, .75, .045, 1, 1.1)), ('hedgeT4', lambda: hedge_parts(1.95, .75, .06, 3, .7)),
               ('hedgeL', lambda: hedge_parts(1.0, .6, .03, 0)), ('hedgeL2', lambda: hedge_parts(1.0, .6, .045, 1, .8)),
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
    # setos irregulares: cada tramo de 1 m es una de varias variantes (abombamientos, huecos, más o menos tupido),
    # con altura, grosor, giro y posición algo distintos; el giro de 180° alterna la cara que se ve
    def hedge(kinds, wts, x, y, rot):
        k = VR.choices(kinds, wts)[0]; e = place(k, x + vr(-.03, .03), y + vr(-.04, .04), 1, rot=rot + VR.choice((0, math.pi)) + vr(-.03, .03))
        if e: e.scale = (1, vr(.94, 1.07), vr(.95, 1.05))
    HT, HW = ['hedgeT', 'hedgeT2', 'hedgeT3', 'hedgeT4'], [4, 2, 3, 1]
    x = -15.0
    while x <= 17.0:
        hedge(HT, HW, x, 12.75, 0); x += 1.0
    y = -12.4
    while y <= 12.2:
        hedge(HT, HW, -15.3, y, math.pi / 2); hedge(HT, HW, 17.3, y, math.pi / 2); y += 1.0
    x = -15.0
    while x <= 17.0:
        if not (-2.3 < x < 4.3): hedge(['hedgeL', 'hedgeL2'], [3, 2], x, -12.95, 0)
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
    for (kind, x, y, s) in (('ballA', 9.9, .6, 1.0), ('ballB', 8.1, 1.7, 1.0), ('ballA', -11.2, -4.4, 1.1), ('ballB', -10.4, -5.6, 1.0),
                            ('ballA', 12.0, -10.6, 1.0), ('ballB', 12.9, -11.3, .9), ('ballA', -12.6, -9.6, 1.0), ('ballB', -11.8, -10.4, .9),
                            ('ballA', -10.2, 1.8, .9), ('ballA', 11.4, 6.0, 1.0), ('ballB', -12.2, 5.0, 1.0)):
        place(kind, x, y, s)
    for (bx, by, w, d) in ((10.9, .5, 1.0, .9), (-11.4, -5, 1.2, 2), (12.6, -6.8, 1.4, 2.4), (-11.1, 2.8, 1.0, 1.4)):   # siempre sobre césped
        for i in range(int(w * d * 2.2)):
            place('lavA', bx + vr(-w, w) * .9, by + vr(-d, d) * .9, vr(.8, 1.2))
    for i in range(14):
        place('lavA', -9.4 + i * .45, -11.95 + vr(-.05, .05), vr(.85, 1.1))
    # sombrilla de brezo (paja) con mástil de madera, la típica de piscinas y hoteles: varias capas de briznas,
    # fleco irregular en el borde, varillas de madera debajo y remate en la punta
    foliage_mat('straw', [(0, 0x6a5537), (.3, 0x8a7149), (.6, 0xa58b5e), (.85, 0xbca174), (1, 0x8f7b5c)], transl=.2, rough=.75, spec=.3, hue_var=.02, val_var=.08)
    m, nt, b = newmat('polewood'); M['polewood'] = m
    if HAVE_PH: pbr(nt, b, 'rough_wood', .5, tint=0xd8b080, tint_fac=.55, nstr=1.6, rough=(.6, .9), scale=(1 / .45, 1 / .45, 1 / .9))   # tronco de pino pelado, con grietas a lo largo
    else:
        tcp = node(nt, 'ShaderNodeTexCoord'); npw = noise(nt, tcp.outputs['Object'], 30, 6, .6)
        L(nt, ramp(nt, npw.outputs['Fac'], [(.3, lin(0x6b4a2e)), (.8, lin(0x9f7a50))]), b.inputs['Base Color'])
    UX, UY, R_, ZA, ZE = 6.3, -11.0, 1.6, 2.98, 2.42
    st, wd, mat_, rope = Geo(), Geo(), Geo(), Geo()
    def cz(r): return ZA - (ZA - ZE) * r / R_
    # mástil de tronco con ligera conicidad, cubo bajo la copa y 12 varillas
    tube(wd, [Vector((UX, UY, .08)), Vector((UX + .006, UY, .9)), Vector((UX + .004, UY + .004, 1.8)), Vector((UX, UY + .003, ZA - .02))], [.105, .1, .095, .088], 28, .035)
    tube(wd, [Vector((UX, UY, ZA - .44)), Vector((UX, UY, ZA - .3))], [.15, .15], 24)
    plate = Geo()   # placa de anclaje de acero con tornillos
    for (x0, x1, y0, y1, z0, z1) in ((UX - .2, UX + .2, UY - .2, UY + .2, .08, .095),) + tuple((UX + dx - .015, UX + dx + .015, UY + dy - .015, UY + dy + .015, .095, .11) for dx in (-.15, .15) for dy in (-.15, .15)):
        P8 = [Vector(c) for c in ((x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
        for q in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)): plate.face([P8[i] for i in q])
    plate.obj('umbrella_plate', 'black')
    for k in range(12):
        a = k / 12 * 2 * math.pi + .13
        tube(wd, [Vector((UX + math.cos(a) * .08, UY + math.sin(a) * .08, ZA - .36)), Vector((UX + math.cos(a) * R_ * .96, UY + math.sin(a) * R_ * .96, cz(R_ * .96) - .03))], [.02, .014], 6)
    n_c = 48
    for j in range(n_c):   # estera de caña bajo la paja
        a0, a1 = j / n_c * 2 * math.pi, (j + 1) / n_c * 2 * math.pi
        for (r0, r1) in ((.06, .6), (.6, 1.15), (1.15, R_ * .99)):
            mat_.face([Vector((UX + math.cos(a0) * r0, UY + math.sin(a0) * r0, cz(r0) - .012)), Vector((UX + math.cos(a1) * r0, UY + math.sin(a1) * r0, cz(r0) - .012)),
                       Vector((UX + math.cos(a1) * r1, UY + math.sin(a1) * r1, cz(r1) - .012)), Vector((UX + math.cos(a0) * r1, UY + math.sin(a0) * r1, cz(r1) - .012))], .1 + .05 * (j % 2))
    # paja en tres capas: cada capa tapa el arranque de la siguiente y termina en un borde recortado
    TIERS = [(.03, .62, .74, .085), (.52, 1.1, 1.22, .055), (1.0, 1.5, R_ + .04, .025)]   # raíz desde, raíz hasta, borde, altura sobre la estera
    for ti, (ra, rb, rt, h0) in enumerate(TIERS):
        n_s = int(16000 * (rt * rt - ra * ra) / (R_ * R_) + 6000)
        for _ in range(n_s):
            r0 = math.sqrt(vr(ra * ra, rb * rb)); a = vr(0, 2 * math.pi)
            out = Vector((math.cos(a), math.sin(a), 0)); tang = Vector((-out.y, out.x, 0))
            rtip = rt + vr(-.025, .02) + .012 * math.sin(a * 23 + ti)
            if rtip <= r0 + .08: continue
            def P(r, lift): return Vector((UX + out.x * r, UY + out.y * r, cz(r) + lift))
            lift = h0 * vr(.3, 1.0)
            p0 = P(r0, lift); p1 = P(rtip, lift * .4)
            if ti == 2:   # el borde exterior cae un poco al final
                pm_ = P(rtip - .12, lift * .5); p1 = pm_ + (out * .1 + Vector((0, 0, -.11))) * vr(.9, 1.2)
            else: pm_ = p0.lerp(p1, .7)
            jit = tang * vr(-.012, .012); w = vr(.0022, .0042)
            side = tang * w
            st.face([p0 - side + jit, p0 + side + jit, pm_ + side * .9 + jit, pm_ - side * .9 + jit], VR.random())
            st.face([pm_ - side * .9 + jit, pm_ + side * .9 + jit, p1 + side * .5 + jit, p1 - side * .5 + jit], VR.random())
    # remate: haz de paja atado con cuerda en la punta
    for _ in range(1600):
        a = vr(0, 2 * math.pi); out = Vector((math.cos(a), math.sin(a), 0)); rb_ = vr(.02, .13)
        p0 = Vector((UX + out.x * rb_, UY + out.y * rb_, cz(rb_) + .09)); p1 = Vector((UX + out.x * .015, UY + out.y * .015, ZA + .3 + vr(-.02, .02)))
        side = Vector((-out.y, out.x, 0)) * vr(.002, .0035)
        st.face([p0 - side, p0 + side, p1 + side * .5, p1 - side * .5], VR.random())
    ring_ = [Vector((UX + .055 * math.cos(t), UY + .055 * math.sin(t), ZA + .2)) for t in [k / 24 * 2 * math.pi for k in range(25)]]
    tube(rope, ring_, [.012] * 25, 6)
    ring_ = [Vector((UX + .035 * math.cos(t), UY + .035 * math.sin(t), ZA + .27)) for t in [k / 24 * 2 * math.pi for k in range(25)]]
    tube(rope, ring_, [.01] * 25, 6)
    linen('rope', 0x7a6650)
    st.obj('umbrella_straw', 'straw'); mat_.obj('umbrella_mat', 'straw'); wd.obj('umbrella_wood', 'polewood', smooth=True); rope.obj('umbrella_rope', 'rope', smooth=True)

    # olivos en maceta en el salón, junto al ventanal
    for (x_, y_, s_) in ((-5.2, 1.85, .34), (3.6, 1.65, .28)):
        e = place('oliveB', x_, y_, s_, rot=x_)
        if e: e.location.z = .62; e.parent = G_BASE
    # olivo en maceta dentro del estudio de la planta alta
    e = place('oliveB', .75, 2.5, .3, rot=1.2)
    if e: e.location.z = 4.3; e.parent = G_UPPER

    # ---------------- bosque frondoso alrededor de la parcela (encinas, pinos piñoneros, cipreses y matorral)
    # Densidad irregular (bosquetes cerrados y zonas más abiertas), claros de pradera seca, caminos de tierra
    # y árboles de tamaños e inclinaciones distintos. El suelo se pinta en el mapa 'groundmap' del material 'land'.
    import numpy as np
    def zone(x, y):
        if -18.5 < x < 20.5 and -13.8 < y < 16.5: return None        # parcela
        if -22.6 < y < -13.3: return None                             # carretera y aceras
        if -62 < x < 46 and -85 < y < -22.6: return 'claro'           # delante de la carretera: solo matorral (la cámara pasa por aquí)
        return 'bosque'
    _vn = {}
    def vnoise(x, y, sc, seed):
        """Ruido de valor suave (0-1)."""
        x, y = x / sc, y / sc; ix, iy = math.floor(x), math.floor(y); fx, fy = x - ix, y - iy
        def h(i, j):
            k = (i, j, seed)
            if k not in _vn: _vn[k] = random.Random(hash(k) & 0xffffffff).random()
            return _vn[k]
        sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a = h(ix, iy) + (h(ix + 1, iy) - h(ix, iy)) * sx; b = h(ix, iy + 1) + (h(ix + 1, iy + 1) - h(ix, iy + 1)) * sx
        return a + (b - a) * sy
    def openness(x, y):   # 0 = bosque cerrado, 1 = muy abierto
        return .65 * vnoise(x, y, 42, 1) + .35 * vnoise(x, y, 15, 2)
    MEADOWS = [(-52, 38, 15), (44, 74, 19), (-22, 98, 13), (74, 14, 16), (-88, 82, 21), (16, 140, 18), (-120, 20, 17)]
    def meadow(x, y):
        best = 0.
        for cx, cy, r in MEADOWS:
            rr_ = r * (1 + .3 * (vnoise(x, y, 9, 3) - .5)); d = math.hypot(x - cx, y - cy)
            best = max(best, min(1., max(0., (rr_ - d) / 4.)))
        return best
    PATHS = [[(-35, -13.3), (-34, -2), (-30, 14), (-27, 26), (-30, 42), (-37, 58), (-35, 80), (-26, 104), (-21, 138), (-24, 180)],
             [(-27, 26), (-12, 31), (6, 29), (24, 33), (40, 44), (56, 51), (74, 50), (98, 58), (130, 60)],
             [(44, 74), (52, 96), (48, 122), (58, 150)]]
    def densify(pl, step=1.5):
        P = [Vector((x, y, 0)) for x, y in pl]
        for _ in range(3):   # Chaikin: curvas suaves
            Q = [P[0]]
            for a, b in zip(P[:-1], P[1:]): Q += [a * .75 + b * .25, a * .25 + b * .75]
            P = Q + [P[-1]]
        out = [P[0]]
        for a, b in zip(P[:-1], P[1:]):
            n = max(1, int((b - a).length / step))
            out += [a.lerp(b, k / n) for k in range(1, n + 1)]
        return [(p.x, p.y) for p in out]
    PATHPTS = [densify(p) for p in PATHS]
    PSEG = np.array([(a[0], a[1], b[0], b[1]) for pl in PATHPTS for a, b in zip(pl[:-1], pl[1:])])
    def path_dist(x, y):
        ax, ay, bx, by = PSEG.T; dx, dy = bx - ax, by - ay
        t = np.clip(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy + 1e-9), 0, 1)
        return float(np.min(np.hypot(ax + t * dx - x, ay + t * dy - y)))
    # muestreo de disco de Poisson con radio variable: copas que se tocan en los bosquetes, más separadas en lo abierto
    cell = 4.0; grid = {}; pts = []
    def free(x, y, r):
        gx, gy = int(x // cell), int(y // cell)
        for i in range(gx - 4, gx + 5):
            for j in range(gy - 4, gy + 5):
                for (px, py, pr) in grid.get((i, j), ()):
                    if (px - x) ** 2 + (py - y) ** 2 < (r + pr) ** 2 * .25: return False
        return True
    tries = 0
    while tries < 300000 and len(pts) < 11000:
        tries += 1
        d = math.sqrt(VR.random()) * 300; a = vr(0, 2 * math.pi); x, y = math.cos(a) * d * 1.1, math.sin(a) * d
        z_ = zone(x, y)
        if z_ != 'bosque': continue
        mw = meadow(x, y)
        if mw > .05 and VR.random() < mw * .97: continue                # claros (algún árbol suelto)
        if path_dist(x, y) < 3.2: continue                              # caminos
        op = openness(x, y)
        r = vr(3.4, 4.6) * (.8 + 1.1 * op * op) * (1 + max(0, d - 140) / 220)
        if not free(x, y, r): continue
        grid.setdefault((int(x // cell), int(y // cell)), []).append((x, y, r)); pts.append((x, y))
        u = VR.random(); pd = vnoise(x, y, 60, 4)
        if u < .06 + .32 * pd * pd: kind = VR.choice(['pineA', 'pineB', 'pineC']); s = vr(.7, 1.25)
        elif u < .94: kind = VR.choice(['oakA', 'oakB', 'oakC']); s = vr(.62, 1.32)
        elif u < .97: kind = VR.choice(['cypressA', 'cypressB']); s = vr(.8, 1.2)
        else: kind = VR.choice(['oliveA', 'oliveC']); s = vr(.8, 1.15)
        e = place(kind, x, y, s, sz=vr(.85, 1.15))
        if e: e.rotation_euler.x = vr(-.06, .06); e.rotation_euler.y = vr(-.06, .06)
    print('bosque:', len(pts), 'árboles', flush=True)
    # sotobosque y matorral (más denso en el claro delante de la carretera; poco en las praderas; nada en los caminos)
    cnt = 0; tries = 0
    while cnt < 9000 and tries < 140000:
        tries += 1
        d = 21 + math.sqrt(VR.random()) * 240; a = vr(0, 2 * math.pi); x, y = math.cos(a) * d * 1.1, math.sin(a) * d
        z_ = zone(x, y)
        if z_ is None or (z_ == 'claro' and VR.random() > .8): continue
        mw = meadow(x, y)
        if mw > .5 and VR.random() < .85: continue
        if path_dist(x, y) < 1.8: continue
        e = place('ballA' if VR.random() < .5 else 'ballB', x, y, 1)
        if e:
            s_ = (vr(1.8, 3.6) if z_ == 'bosque' else vr(.9, 1.8)) * (1 - .55 * mw)
            e.scale = (s_ * vr(.8, 1.4), s_ * vr(.8, 1.4), s_ * vr(.6, 1.1))
        cnt += 1
    # algunos olivos y encinas jóvenes sueltos en el claro y en las praderas
    for _ in range(40):
        x, y = vr(-60, 44), vr(-84, -60)
        if zone(x, y) == 'claro': place(VR.choice(['oliveA', 'oliveB', 'oakB']), x, y, vr(.5, .8))
    for cx, cy, r in MEADOWS:
        for _ in range(3):
            a = vr(0, 6.28); dd = r * vr(.2, .7); place(VR.choice(['oliveA', 'oakB', 'oliveC']), cx + math.cos(a) * dd, cy + math.sin(a) * dd, vr(.6, 1.0))
    # mapa del suelo: caminos (R), praderas (G) y sombra de copas / hojarasca (B)
    if 'groundmap' in bpy.data.images:
        N_ = 1024; gm_ = 640.; px_ = (np.arange(N_) + .5) / N_ * gm_ - gm_ / 2
        X_, Y_ = np.meshgrid(px_, px_)
        Rc = np.zeros((N_, N_)); Gc = np.zeros((N_, N_)); Bc = np.zeros((N_, N_))
        for ax, ay, bx, by in PSEG:
            x0, x1, y0, y1 = min(ax, bx) - 4, max(ax, bx) + 4, min(ay, by) - 4, max(ay, by) + 4
            i0, i1 = np.searchsorted(px_, [y0, y1]); j0, j1 = np.searchsorted(px_, [x0, x1])
            if i1 <= i0 or j1 <= j0: continue
            xs, ys = X_[i0:i1, j0:j1], Y_[i0:i1, j0:j1]; dx, dy = bx - ax, by - ay
            t = np.clip(((xs - ax) * dx + (ys - ay) * dy) / (dx * dx + dy * dy + 1e-9), 0, 1)
            dd = np.hypot(ax + t * dx - xs, ay + t * dy - ys)
            Rc[i0:i1, j0:j1] = np.maximum(Rc[i0:i1, j0:j1], np.clip((1.25 - dd) / .5, 0, 1))
        for cx, cy, r in MEADOWS:
            dd = np.hypot(X_ - cx, Y_ - cy); Gc = np.maximum(Gc, np.clip((r * 1.1 - dd) / 6, 0, 1))
        P_ = np.array(pts); H_, _, _ = np.histogram2d(P_[:, 1], P_[:, 0], bins=N_, range=[[-gm_ / 2, gm_ / 2]] * 2)
        k = 7; ker = np.exp(-np.linspace(-2.5, 2.5, 2 * k + 1) ** 2); ker /= ker.sum()
        Bc = np.apply_along_axis(lambda v_: np.convolve(v_, ker, 'same'), 0, H_); Bc = np.apply_along_axis(lambda v_: np.convolve(v_, ker, 'same'), 1, Bc)
        Bc = np.clip(Bc / (np.percentile(Bc[Bc > 0], 90) + 1e-6), 0, 1)
        Gc *= 1 - Rc; Bc *= (1 - Rc) * (1 - Gc)
        img_ = np.stack([Rc, Gc, Bc, np.ones_like(Rc)], -1).astype(np.float32)
        gi = bpy.data.images['groundmap']; gi.pixels.foreach_set(img_.ravel()); gi.pack()
