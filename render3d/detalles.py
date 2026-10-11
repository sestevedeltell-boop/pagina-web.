"""Detalles de la villa (se ejecuta dentro de scene.py, después de vegetacion.py, y comparte sus funciones).

Cocina exterior con barbacoa de gas, fregadero, puertas y cajones; objetos de uso (toallas en las tumbonas,
mesita con libro y vaso, bandeja con jarra y vasos, frutero con limones, tabla de cortar, aceite) y macetas
con plantas en la terraza; y la pequeña estancia que se ve por la ventana vertical del volumen blanco."""

DR = random.Random(77)

# ------------------------------------------------------------------ geometría auxiliar
def lathe(mb, cx, cy, z0, prof, n=40):
    """Sólido de revolución: prof = [(radio, z), ...] de abajo arriba (radio 0 = punto del eje)."""
    rings = []
    for (r_, z_) in prof:
        if r_ < 1e-6: rings.append([mb.bm.verts.new((cx, cy, z0 + z_))])
        else: rings.append([mb.bm.verts.new((cx + r_ * math.cos(a), cy + r_ * math.sin(a), z0 + z_)) for a in [i / n * 2 * math.pi for i in range(n)]])
    for A, B in zip(rings[:-1], rings[1:]):
        if len(A) == 1 and len(B) == 1: continue
        if len(A) == 1:
            for i in range(n): mb.bm.faces.new((A[0], B[(i + 1) % n], B[i]))
        elif len(B) == 1:
            for i in range(n): mb.bm.faces.new((A[i], A[(i + 1) % n], B[0]))
        else:
            for i in range(n): mb.bm.faces.new((A[i], A[(i + 1) % n], B[(i + 1) % n], B[i]))

def sharpen(mb, deg=30):
    """Aristas vivas (labio del vaso, fondo, borde de la maceta) fuera del sombreado suave: si no, en un vidrio
    fino la normal suavizada se tuerce en toda la pared, la luz se refleja por dentro y el vaso sale negro."""
    bmesh.ops.recalc_face_normals(mb.bm, faces=mb.bm.faces)
    for e in mb.bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(deg): e.smooth = False
    return mb

def ptube(mb, pts, r, n=12, cap=True):
    """Tubo de radio r por una polilínea (transporte paralelo del marco: no se retuerce)."""
    pts = [Vector(p) for p in pts]; rings = []; pu = None
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        u = d.orthogonal().normalized() if pu is None else (pu - d * pu.dot(d)).normalized()
        v = d.cross(u); pu = u
        rings.append([mb.bm.verts.new(p + (u * math.cos(a) + v * math.sin(a)) * r) for a in [k / n * 2 * math.pi for k in range(n)]])
    for A, B in zip(rings[:-1], rings[1:]):
        for k in range(n): mb.bm.faces.new((A[k], A[(k + 1) % n], B[(k + 1) % n], B[k]))
    if cap: mb.bm.faces.new(rings[0]); mb.bm.faces.new(list(reversed(rings[-1])))

def chaikin(P, it=3):
    for _ in range(it):
        Q = [P[0]]
        for a, b in zip(P[:-1], P[1:]): Q += [a * .75 + b * .25, a * .25 + b * .75]
        P = Q + [P[-1]]
    return P

def drape(name, mat, xc, path_yz, width, seed, nx=24):
    """Toalla echada sobre una tumbona: tira de tela que sigue el perfil (y, z), con arrugas suaves y grosor."""
    rg = random.Random(seed)
    P = chaikin([Vector((0, y, z)) for y, z in path_yz], 4)
    me = bpy.data.meshes.new(name); V, F = [], []
    ph = [rg.uniform(0, 6.28) for _ in range(4)]
    s_ = 0.
    for i, p in enumerate(P):
        if i: s_ += (p - P[i - 1]).length
        t = (P[min(i + 1, len(P) - 1)] - P[max(i - 1, 0)]).normalized(); nrm = Vector((0, -t.z, t.y))
        if nrm.z < 0: nrm = -nrm
        for j in range(nx + 1):
            u = j / nx - .5
            # pliegues suaves a lo largo de la toalla (no en rombos) y ondas en los bordes
            w = (.0028 * math.sin(u * 13 + ph[0] + .6 * math.sin(s_ * 2.3 + ph[1])) * (.6 + .4 * math.sin(s_ * 3.1 + ph[2]))
                 + .0012 * math.sin(u * 29 + ph[1]) + .006 * max(0, abs(u) - .38) / .12 * math.sin(s_ * 9 + ph[2]))
            sag = .004 * (abs(u) * 2) ** 3   # los bordes caen un poco
            V.append((xc + u * width + .003 * math.sin(s_ * 7 + ph[3]), p.y + nrm.y * (w - sag), p.z + nrm.z * (w - sag) + .003))
    for i in range(len(P) - 1):
        for j in range(nx):
            a = i * (nx + 1) + j; F.append((a, a + 1, a + nx + 2, a + nx + 1))
    me.from_pydata(V, [], F); me.update(); me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
    ob_ = bpy.data.objects.new(name, me); COL.objects.link(ob_); me.materials.append(M[mat])
    so = ob_.modifiers.new('grosor', 'SOLIDIFY'); so.thickness = .007; so.offset = 0
    return ob_

def ellipsoid(mb, c, r, rot, k=1.25, seg=20):
    bm2 = bmesh.new(); bmesh.ops.create_uvsphere(bm2, u_segments=seg, v_segments=seg // 2 + 2, radius=r); bm2.verts.index_update()
    R_ = Euler(rot).to_matrix()
    for v in bm2.verts:
        co = Vector((v.co.x, v.co.y, v.co.z * k))
        if abs(co.z) > r * k * .93: co.z *= 1.04   # puntitas del limón
        mb.bm.verts.new(R_ @ co + Vector(c))
    # (se copian las caras con los mismos índices)
    off = len(mb.bm.verts) - len(bm2.verts); mb.bm.verts.ensure_lookup_table()
    for f in bm2.faces: mb.bm.faces.new([mb.bm.verts[off + v.index] for v in f.verts])
    bm2.free()

# ------------------------------------------------------------------ materiales
def terry(name, tint, stripes=None):
    """Rizo de toalla: tela con relieve fino de bucles y brillo aterciopelado; stripes = (color, periodo, ancho)."""
    m, nt, b = newmat(name); M[name] = m
    tc = node(nt, 'ShaderNodeTexCoord'); v = tc.outputs['Object']
    col = lin(tint)
    if stripes:
        c2, per, wd = stripes
        sx = node(nt, 'ShaderNodeSeparateXYZ'); L(nt, v, sx.inputs[0])
        fr = node(nt, 'ShaderNodeMath'); fr.operation = 'PINGPONG'; fr.inputs[1].default_value = per / 2; L(nt, sx.outputs['X'], fr.inputs[0])
        st = node(nt, 'ShaderNodeMapRange'); st.inputs['From Min'].default_value = per / 2 - wd - .002; st.inputs['From Max'].default_value = per / 2 - wd
        L(nt, fr.outputs[0], st.inputs['Value'])
        col = mix(nt, st.outputs[0], lin(tint), lin(c2))
    n1 = noise(nt, v, 900, 2, .5); n2 = noise(nt, v, 9, 3)
    cv = mix(nt, .12, col, n2.outputs['Color'], 'OVERLAY')
    L(nt, cv, b.inputs['Base Color']); b.inputs['Roughness'].default_value = .97; b.inputs['Specular IOR Level'].default_value = .15
    b.inputs['Sheen Weight'].default_value = .8; b.inputs['Sheen Roughness'].default_value = .6
    L(nt, bump(nt, n1.outputs['Fac'], .55, .0025), b.inputs['Normal'])
terry('towelwhite', 0xeeeae2); terry('towelsand', 0xd8c4a2); terry('towelgrey', 0x9eaaad); terry('towelstripe', 0xf0ebe0, (0x2c4766, .11, .028))
simple('paper', 0xeee7d6, .92, spec=.2); simple('bookred', 0x7a2f2b, .55, spec=.35); simple('bookblue', 0x2e475a, .55, spec=.35)
simple('teak', 0x8a5b39, .5, coat=.15)
simple('hpl', 0x3a3b3d, .48, spec=.4)           # puertas de compacto antracita
simple('inox', 0xcfd2d4, .27, 1.)               # acero inoxidable cepillado
simple('kinner', 0x161718, .8)
simple('ceramic', 0xf2efe9, .1, coat=.5)
m, nt, b = newmat('drink'); M['drink'] = m
b.inputs['Base Color'].default_value = (.95, .99, 1, 1); b.inputs['Transmission Weight'].default_value = 1; b.inputs['Roughness'].default_value = 0; b.inputs['IOR'].default_value = 1.33
m, nt, b = newmat('oilglass'); M['oilglass'] = m
b.inputs['Base Color'].default_value = lin(0x6d8a3a); b.inputs['Transmission Weight'].default_value = 1; b.inputs['Roughness'].default_value = .02; b.inputs['IOR'].default_value = 1.5
m, nt, b = newmat('lemon'); M['lemon'] = m
tc = node(nt, 'ShaderNodeTexCoord'); pn = noise(nt, tc.outputs['Object'], 260, 2); vn = noise(nt, tc.outputs['Object'], 18, 3)
L(nt, mix(nt, vn.outputs['Fac'], lin(0xe2b81c), lin(0xf0cf3a)), b.inputs['Base Color']); b.inputs['Roughness'].default_value = .38
b.inputs['Subsurface Weight'].default_value = .2; b.inputs['Subsurface Radius'].default_value = (.01, .006, .002)
L(nt, bump(nt, pn.outputs['Fac'], .35, .0015), b.inputs['Normal'])
m, nt, b = newmat('terracotta'); M['terracotta'] = m
tc = node(nt, 'ShaderNodeTexCoord'); tn_ = noise(nt, tc.outputs['Object'], 6, 4); tf_ = noise(nt, tc.outputs['Object'], 140, 2)
c_ = mix(nt, tn_.outputs['Fac'], lin(0xa95b38), lin(0xc47a52))
geo_ = node(nt, 'ShaderNodeNewGeometry'); spz_ = node(nt, 'ShaderNodeSeparateXYZ'); L(nt, geo_.outputs['Position'], spz_.inputs[0])
c_ = mix(nt, .25, c_, lin(0xd8cbb5), 'MIX')   # algo de cal / salitre
L(nt, c_, b.inputs['Base Color']); b.inputs['Roughness'].default_value = .93; b.inputs['Specular IOR Level'].default_value = .25
L(nt, bump(nt, tf_.outputs['Fac'], .3, .002), b.inputs['Normal'])
simple('potglaze', 0x2e3735, .3, coat=.35)

# ------------------------------------------------------------------ cocina exterior (frente a -Y, hacia la piscina)
KX0, KX1, KY0, KY1, KZ0, KZT = -6.5, -3.9, -2.75, -2.05, .3, 1.17
mb = MB(); mb.box(KX0, KX0 + .08, KY0, KY1, KZ0, KZT); mb.box(KX1 - .08, KX1, KY0, KY1, KZ0, KZT); mb.box(KX0 + .08, KX1 - .08, KY1 - .08, KY1, KZ0, KZT)
mb.obj('k_stone', 'stone', .006, G_BASE)
mb = MB(); mb.box(KX0 + .08, KX1 - .08, KY0 + .06, KY1 - .08, KZ0, KZ0 + .1); mb.obj('k_plinth', 'black', 0, G_BASE)
mb = MB(); mb.box(KX0 + .08, KX1 - .08, KY0 + .022, KY1 - .08, KZ0 + .1, KZT); mb.obj('k_body', 'kinner', 0, G_BASE)
xa, xb, xc, xd, xe = -6.42, -5.84, -4.92, -4.46, -3.98   # módulos: puerta | puertas de la barbacoa | cajones | puerta del fregadero
zb, zt = KZ0 + .103, KZT - .004
dh, di, hd = MB(), MB(), MB()
dh.box(xa + .002, xb - .0015, KY0, KY0 + .022, zb, zt)
di.box(xb + .0015, (xb + xc) / 2 - .0015, KY0, KY0 + .022, zb, zt); di.box((xb + xc) / 2 + .0015, xc - .0015, KY0, KY0 + .022, zb, zt)
dz = [zb, zb + .25, zb + .5, zt]
for k in range(3): dh.box(xc + .0015, xd - .0015, KY0, KY0 + .022, dz[k] + .0015, dz[k + 1] - .0015)
dh.box(xd + .0015, xe - .002, KY0, KY0 + .022, zb, zt)
soft(dh.obj('k_doors', 'hpl', 0, G_BASE), .002, 1); soft(di.obj('k_doors_inox', 'inox', 0, G_BASE), .002, 1)
HY = KY0 - .032
def vbar(x, z0, z1):
    ptube(hd, [(x, HY, z0), (x, HY, z1)], .0065, 10)
    for z_ in (z0 + .03, z1 - .03): ptube(hd, [(x, KY0 + .001, z_), (x, HY, z_)], .005, 8)
def hbar(xm, z, Ln):
    ptube(hd, [(xm - Ln / 2, HY, z), (xm + Ln / 2, HY, z)], .0065, 10)
    for x_ in (xm - Ln / 2 + .03, xm + Ln / 2 - .03): ptube(hd, [(x_, KY0 + .001, z), (x_, HY, z)], .005, 8)
vbar(xb - .06, zt - .36, zt - .06); vbar((xb + xc) / 2 - .05, zt - .36, zt - .06); vbar((xb + xc) / 2 + .05, zt - .36, zt - .06); vbar(xd + .06, zt - .36, zt - .06)
for k in range(3): hbar((xc + xd) / 2, dz[k + 1] - .06, .26)
hd.obj('k_handles', 'steel', 0, G_BASE, smooth=True)
# encimera de piedra blanca (4 cm) con el hueco del fregadero bajo encimera
SKX0, SKX1, SKY0, SKY1 = -4.42, -4.02, -2.6, -2.2
mb = MB(); mb.box(KX0 - .03, KX1 + .03, KY0 - .03, KY1, KZT, KZT + .04); ctop = mb.obj('k_counter', 'quartz', 0, G_BASE)
mb = MB(); mb.box(SKX0, SKX1, SKY0, SKY1, KZT - .05, KZT + .1); cut_ = mb.obj('k_sinkcut', 'quartz', 0, G_BASE); cut_.hide_render = True; cut_.display_type = 'WIRE'
md = ctop.modifiers.new('cut', 'BOOLEAN'); md.operation = 'DIFFERENCE'; md.solver = 'EXACT'; md.object = cut_
md = ctop.modifiers.new('bev', 'BEVEL'); md.width = .004; md.segments = 2; md.limit_method = 'ANGLE'; md.use_clamp_overlap = True
# fregadero de acero (cubeta bajo encimera), desagüe y grifo de caño alto
mb = MB(); x0_, x1_, y0_, y1_, zb_ = SKX0 - .01, SKX1 + .01, SKY0 - .01, SKY1 + .01, KZT - .2
mb.poly([(x0_, y0_, zb_), (x1_, y0_, zb_), (x1_, y1_, zb_), (x0_, y1_, zb_)])
for (p_, q_) in (((x0_, y0_), (x1_, y0_)), ((x1_, y0_), (x1_, y1_)), ((x1_, y1_), (x0_, y1_)), ((x0_, y1_), (x0_, y0_))):
    mb.poly([(p_[0], p_[1], zb_), (q_[0], q_[1], zb_), (q_[0], q_[1], KZT), (p_[0], p_[1], KZT)])
sk_ = mb.obj('k_sink', 'inox', 0, G_BASE); so_ = sk_.modifiers.new('grosor', 'SOLIDIFY'); so_.thickness = .002
mb = MB(); mb.cyl((SKX0 + SKX1) / 2, (SKY0 + SKY1) / 2, zb_ + .001, zb_ + .004, .035, 24); mb.obj('k_drain', 'black', 0, G_BASE)
FX, FY = (SKX0 + SKX1) / 2, -2.11
mb = MB(); mb.cyl(FX, FY, KZT + .04, KZT + .08, .026, 24)
arc = [(FX, FY, KZT + .06), (FX, FY, KZT + .2)] + \
      [(FX, -2.215 + .105 * math.cos(a), KZT + .27 + .105 * math.sin(a)) for a in [k / 12 * math.pi for k in range(13)]] + [(FX, -2.32, KZT + .22)]
ptube(mb, arc, .011, 14)
ptube(mb, [(FX + .02, FY, KZT + .065), (FX + .1, FY + .01, KZT + .09)], .006, 8)
mb.obj('k_faucet', 'steel', 0, G_BASE, smooth=True)
# barbacoa de gas encastrada: cuerpo, mandos, tapa abovedada con asa y termómetro
GX0, GX1, GY0, GY1, GZ = -5.83, -4.93, -2.66, -2.14, KZT + .04
mb = MB(); mb.box(GX0, GX1, GY0, GY1, GZ, GZ + .13); mb.box(GX0 + .01, GX1 - .01, GY0 + .04, GY1 - .01, GZ + .13, GZ + .135)
mb.obj('g_body', 'inox', .004, G_BASE)
LCY, LR, LH, LZ = (GY0 + .04 + GY1) / 2, (GY1 - GY0 - .04) / 2, .18, GZ + .135
mb = MB(); nA = 28; ends = []
for x_ in (GX0 + .015, GX1 - .015):
    ends.append([mb.bm.verts.new((x_, LCY + LR * math.cos(a), LZ + LH * math.sin(a))) for a in [k / nA * math.pi for k in range(nA + 1)]])
for k in range(nA): mb.bm.faces.new((ends[0][k], ends[0][k + 1], ends[1][k + 1], ends[1][k])).smooth = True
mb.bm.faces.new(ends[0]); mb.bm.faces.new(list(reversed(ends[1]))); mb.bm.faces.new((ends[0][0], ends[1][0], ends[1][nA], ends[0][nA]))
mb.obj('g_lid', 'inox', .006, G_BASE)
hd2 = MB(); hz = LZ + .11; hy = LCY - LR * math.cos(math.asin(.11 / LH)) - .065
ptube(hd2, [(GX0 + .12, hy, hz), (GX1 - .12, hy, hz)], .011, 14)
for x_ in (GX0 + .15, GX1 - .15): ptube(hd2, [(x_, hy, hz), (x_, hy + .072, hz - .005)], .007, 10)
hd2.obj('g_handle', 'steel', 0, G_BASE, smooth=True)
kb = MB()
for k in range(4): ptube(kb, [(GX0 + .17 + k * .187, GY0 + .001, GZ + .065), (GX0 + .17 + k * .187, GY0 - .032, GZ + .065)], .021, 20)
a_ = math.pi - .95; tp = Vector((-5.38, LCY + LR * math.cos(a_), LZ + LH * math.sin(a_))); tn = Vector((0, LH * math.cos(a_), LR * math.sin(a_))).normalized()
ptube(kb, [tp - tn * .004, tp + tn * .01], .03, 24)
kb.obj('g_knobs', 'black', 0, G_BASE, smooth=True)
# encima: tabla de cortar con dos limones, aceite de oliva y una maceta de hierbas
mb = MB(); mb.cbox(0, 0, .011, .38, .25, .022); tb_ = soft(mb.obj('k_board', 'oak', 0, G_BASE), .008, 3)
tb_.location = (-4.68, -2.44, KZT + .04); tb_.rotation_euler.z = .12
lm = MB(); ellipsoid(lm, (-4.74, -2.47, KZT + .04 + .022 + .03), .03, (1.5, .3, .6)); ellipsoid(lm, (-4.63, -2.4, KZT + .04 + .022 + .03), .029, (1.6, 0, 2.1))
lm.obj('k_lemons', 'lemon', 0, G_BASE, smooth=True)
mb = MB(); lathe(mb, -6.32, -2.24, KZT + .04, [(0, 0), (.03, 0), (.033, .006), (.033, .19), (.028, .225), (.012, .25), (.012, .272), (0, .272)], 28)
sharpen(mb).obj('k_oil', 'oilglass', 0, G_BASE, smooth=True)
mb = MB(); mb.cyl(-6.32, -2.24, KZT + .04 + .27, KZT + .04 + .295, .014, 16); mb.obj('k_oilcap', 'black', 0, G_BASE, smooth=True)

# ------------------------------------------------------------------ macetas
def pot(name, x, y, z, r, h, mat='terracotta', plant=None, ps=1.0, par=None):
    mb = MB(); lathe(mb, x, y, z, [(0, 0), (r * .72, 0), (r * .74, .01), (r, h * .86), (r * 1.07, h * .88), (r * 1.07, h), (r * .99, h), (r * .95, h * .9), (0, h * .9)], 40)
    o_ = sharpen(mb).obj(name, mat, 0, par, smooth=True)
    mb = MB(); mb.cyl(x, y, z + h * .9, z + h * .93, r * .955, 40); mb.obj(name + '_soil', 'soil', 0, par)
    if plant and 'place' in globals():
        e = place(plant, x, y, ps)
        if e: e.location.z = z + h * .9
    return o_
pot('p_terr1', -9.12, -3.1, .3, .28, .55, 'terracotta', 'ballA', .48)
pot('p_terr2', -8.52, -3.26, .3, .19, .36, 'terracotta', 'lavA', .5)
pot('p_terr3', 8.42, -3.05, .3, .24, .62, 'potglaze', 'ballB', .5)
pot('p_terr4', 7.88, -3.24, .3, .16, .3, 'terracotta', 'lavA', .42)
pot('p_kherb', -6.06, -2.3, KZT + .04, .065, .12, 'terracotta', 'lavA', .2)

# ------------------------------------------------------------------ tumbonas: toallas
# perfil de la tumbona (y, z): respaldo inclinado, colchoneta y caída por los pies
LOUNGE = [(-11.258, .727), (-10.8, .352), (-10.7, .347), (-9.5, .346), (-9.432, .343), (-9.397, .33), (-9.367, .29), (-9.357, .23), (-9.353, .15)]
drape('towel0', 'towelsand', 1.0, LOUNGE, .58, 3)
drape('towel2', 'towelstripe', 3.6, [(y_, z_) for (y_, z_) in LOUNGE[2:]], .6, 9)
mb = MB(); mb.cbox(0, 0, .023, .44, .3, .046); t1 = soft(mb.obj('towelfold1', 'towelgrey', 0), .018, 3); t1.location = (2.3, -9.74, .343); t1.rotation_euler.z = .04
mb = MB(); mb.cbox(0, 0, .021, .42, .28, .042); t2 = soft(mb.obj('towelfold2', 'towelwhite', 0), .017, 3); t2.location = (2.31, -9.75, .389); t2.rotation_euler.z = -.09
mb = MB(); mb.cyl(0, 0, -.24, .24, .058, 28); t3 = soft(mb.obj('towelroll', 'towelwhite', 0), .02, 3)
t3.location = (2.3, -10.6, .343 + .057); t3.rotation_euler = (0, math.pi / 2, 0)
# mesita auxiliar de teca entre dos tumbonas, con un libro y un vaso de agua
mb = MB(); mb.cyl(1.65, -10.7, .4, .425, .21, 48); soft(mb.obj('loungetable', 'teak', 0), .006, 2)
mb = MB(); mb.cyl(1.65, -10.7, .08, .4, .022, 16); mb.cyl(1.65, -10.7, .08, .095, .15, 40); mb.obj('loungetablebase', 'black', 0, smooth=True)
def book(name, x, y, z, rz, w=.15, l=.22, t=.028, cover='bookred'):
    mb = MB(); mb.box(-w / 2 + .006, w / 2 - .003, -l / 2 + .003, l / 2 - .003, .0025, t - .0025); p_ = mb.obj(name + '_p', 'paper', 0)
    mb = MB(); mb.box(-w / 2, w / 2, -l / 2, l / 2, 0, .0025); mb.box(-w / 2, w / 2, -l / 2, l / 2, t - .0025, t); mb.box(-w / 2, -w / 2 + .006, -l / 2, l / 2, 0, t)
    c_ = soft(mb.obj(name + '_c', cover, 0), .0012, 1)
    for o_ in (p_, c_): o_.location = (x, y, z); o_.rotation_euler.z = rz
book('book1', 1.6, -10.77, .425, .45)
def tumbler(name, x, y, z, fill=.6):
    mb = MB(); lathe(mb, x, y, z, [(0, 0), (.031, 0), (.0335, .003), (.039, .1), (.037, .1), (.0325, .009), (0, .009)], 36)
    sharpen(mb).obj(name, 'tglass', 0, None, smooth=True)
    if fill:
        mb = MB(); lathe(mb, x, y, z, [(0, .0095), (.0318, .0095), (.0325 + .006 * fill, .009 + .09 * fill), (0, .009 + .09 * fill)], 36)
        sharpen(mb).obj(name + '_w', 'drink', 0, None, smooth=True)
tumbler('glass_side', 1.74, -10.6, .425, .55)
# bandeja con jarra de agua y vasos en la mesa del porche, y frutero con limones
TZ = 1.085
mb = MB(); mb.box(-.59, -.11, -1.36, -1.04, TZ, TZ + .012)
for bx_ in ((-.59, -.11, -1.36, -1.35), (-.59, -.11, -1.05, -1.04), (-.59, -.58, -1.36, -1.04), (-.12, -.11, -1.36, -1.04)): mb.box(bx_[0], bx_[1], bx_[2], bx_[3], TZ, TZ + .035)
soft(mb.obj('tray', 'oak', 0, G_BASE), .003, 2)
mb = MB(); lathe(mb, -.48, -1.2, TZ + .012, [(0, 0), (.055, 0), (.06, .008), (.062, .13), (.05, .17), (.033, .205), (.035, .24), (.033, .242), (.031, .207), (.047, .17), (.059, .13), (.057, .011), (0, .011)], 40)
sharpen(mb).obj('carafe', 'tglass', 0, G_BASE, smooth=True)
mb = MB(); lathe(mb, -.48, -1.2, TZ + .012, [(0, .0115), (.0565, .0115), (.0585, .13), (0, .13)], 40); sharpen(mb).obj('carafe_w', 'drink', 0, G_BASE, smooth=True)
for i_, (gx, gy) in enumerate(((-.33, -1.28), (-.22, -1.27), (-.33, -1.12), (-.21, -1.13))): tumbler('glass_t%d' % i_, gx, gy, TZ + .012, .45 if i_ % 2 else 0)
mb = MB(); lathe(mb, .45, -1.15, TZ, [(0, 0), (.07, 0), (.075, .004), (.14, .06), (.15, .075), (.145, .077), (.136, .066), (.073, .009), (0, .009)], 48)
sharpen(mb, 40).obj('fruitbowl', 'ceramic', 0, G_BASE, smooth=True)
lm = MB()
for k in range(5):
    a = k / 5 * 2 * math.pi + .3; ellipsoid(lm, (.45 + .06 * math.cos(a), -1.15 + .06 * math.sin(a), TZ + .045), .034, (DR.uniform(1.2, 1.9), DR.uniform(-.4, .4), a + 1.57))
ellipsoid(lm, (.45, -1.15, TZ + .09), .035, (1.5, .2, .7)); ellipsoid(lm, (.47, -1.11, TZ + .088), .033, (1.4, -.3, 2.5))
lm.obj('lemons', 'lemon', 0, G_BASE, smooth=True)

# ------------------------------------------------------------------ estancia de la ventana vertical (volumen blanco de la derecha)
mb = MB(); mb.box(4.24, 6.16, 1.24, 3.6, .3, .315); mb.obj('slotfloor', 'floorwood', 0, G_BASE)
pot('slotpot', 4.95, 2.75, .315, .3, .48, 'potglaze', 'oliveB', .3, G_BASE)
mb = MB(); mb.box(4.55, 5.75, 3.575, 3.6, 1.15, 2.35); mb.obj('slotart_f', 'black', 0, G_WALLS)
simple('slotcanvas', 0xb9a58a, .9); mb = MB(); mb.box(4.6, 5.7, 3.57, 3.575, 1.2, 2.3); mb.obj('slotart', 'slotcanvas', 0, G_WALLS)
ld_ = bpy.data.lights.new('in5', 'AREA'); ld_.energy = 35; ld_.size = .9; ld_.color = (1, .82, .6)
lo_ = bpy.data.objects.new('in5', ld_); lo_.location = (5.2, 2.5, 3.3); lo_.parent = G_BASE; COL.objects.link(lo_)
lo_.visible_camera = False; lo_.visible_transmission = False; lo_.visible_glossy = False
