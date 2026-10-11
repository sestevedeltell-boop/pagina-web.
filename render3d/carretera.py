"""Detalles de la carretera (se ejecuta dentro de scene.py, justo después de crear la carretera, y comparte sus funciones).

Señales de velocidad, placa con el nombre de la calle, imbornales junto al bordillo y tapas de alcantarilla. Las farolas de scene.py
se rehacen aquí una a una, con algo de inclinación, altura y desgaste distintos."""

CR = random.Random(909)

def cylY(mb, x, y0, y1, z, r, n=32):
    """Cilindro con el eje en Y (ruedas)."""
    a_ = [k / n * 2 * math.pi for k in range(n)]
    A = [mb.bm.verts.new((x + r * math.cos(t), y0, z + r * math.sin(t))) for t in a_]
    B = [mb.bm.verts.new((x + r * math.cos(t), y1, z + r * math.sin(t))) for t in a_]
    for k in range(n): mb.bm.faces.new((A[k], A[(k + 1) % n], B[(k + 1) % n], B[k]))
    mb.bm.faces.new(list(reversed(A))); mb.bm.faces.new(B)

def loft(name, mat, xs, section, par=None, subsurf=2):
    """Malla a partir de secciones transversales: section(x) -> lista de (y, z) en orden alrededor (cerrada)."""
    V, F = [], []
    S = [section(x) for x in xs]; ns = len(S[0])
    for i, x in enumerate(xs):
        V += [(x, y, z) for (y, z) in S[i]]
    for i in range(len(xs) - 1):
        for k in range(ns):
            a = i * ns + k; b = i * ns + (k + 1) % ns; F.append((a, b, b + ns, a + ns))
    c0 = len(V); V.append((xs[0], 0, sum(z for _, z in S[0]) / ns)); c1 = len(V); V.append((xs[-1], 0, sum(z for _, z in S[-1]) / ns))
    for k in range(ns):
        F.append((c0, (k + 1) % ns, k)); F.append((c1, (len(xs) - 1) * ns + k, (len(xs) - 1) * ns + (k + 1) % ns))
    me = bpy.data.meshes.new(name); me.from_pydata(V, [], F); me.update(); me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
    o = bpy.data.objects.new(name, me); COL.objects.link(o); me.materials.append(M[mat])
    if par: o.parent = par
    if subsurf:
        sd = o.modifiers.new('suave', 'SUBSURF'); sd.levels = 1; sd.render_levels = subsurf
    return o

def lerp_tab(tab, x):
    """Interpolación lineal en una tabla [(x, valor), ...] ordenada por x."""
    if x <= tab[0][0]: return tab[0][1]
    for (x0, v0), (x1, v1) in zip(tab[:-1], tab[1:]):
        if x <= x1: t = (x - x0) / (x1 - x0); t = t * t * (3 - 2 * t); return v0 + (v1 - v0) * t
    return tab[-1][1]



# ------------------------------------------------------------------ señales y mobiliario
def disc_sign(name, x, y, rot, num='40'):
    root = empty(name); root.location = (x, y, 0); root.rotation_euler.z = rot
    simple('signred', 0xb3121a, .4, coat=.3); simple('signwhite', 0xf2f2ef, .35, coat=.3); simple('galv', 0x9a9d9f, .45, .9); simple('signback', 0x8c8f91, .5, .6)
    mb = MB(); mb.cyl(0, 0, 0, 2.55, .03, 16); mb.obj(name + '_pole', 'galv', 0, root, smooth=True)
    mb = MB(); cylY(mb, 0, -.045, -.035, 2.15, .3, 48); o_ = mb.obj(name + '_ring', 'signred', 0, root)
    mb = MB(); cylY(mb, 0, -.047, -.044, 2.15, .235, 48); mb.obj(name + '_face', 'signwhite', 0, root)
    mb = MB(); cylY(mb, 0, -.035, -.03, 2.15, .3, 48); mb.obj(name + '_back', 'signback', 0, root)
    cu = bpy.data.curves.new(name + '_txt', 'FONT'); cu.body = num; cu.size = .27; cu.align_x = 'CENTER'; cu.align_y = 'CENTER'; cu.extrude = .001
    try: cu.font = bpy.data.fonts.load('<builtin>')
    except Exception: pass
    t_ = bpy.data.objects.new(name + '_num', cu); COL.objects.link(t_); t_.parent = root; t_.location = (0, -.049, 2.14); t_.rotation_euler = (math.pi / 2, 0, 0)
    cu.materials.append(M['black'])
    return root
disc_sign('sign40', 15.5, RY1 + .45, math.pi / 2)      # en la acera, para quien viene del este (circula por este lado)
disc_sign('sign40b', -31.0, RY0 - 1.0, -math.pi / 2)   # en el arcén de enfrente, para quien viene del oeste
# placa con el nombre de la calle en el muro de la parcela, junto a la puerta
simple('platewhite', 0xf3f1ea, .4, coat=.2); simple('plateframe', 0x1d3a6b, .4, coat=.2)
mb = MB(); mb.box(-3.0, -2.0, -13.69, -13.67, .32, .64); mb.obj('streetplate_f', 'plateframe', .002)
mb = MB(); mb.box(-2.97, -2.03, -13.7, -13.69, .345, .615); mb.obj('streetplate', 'platewhite', 0)
for (txt, sz_, zz_) in (('Calle de los Pinos', .07, .5), ('Nº 14', .055, .41)):
    cu = bpy.data.curves.new('stxt', 'FONT'); cu.body = txt; cu.size = sz_; cu.align_x = 'CENTER'; cu.align_y = 'CENTER'; cu.extrude = .0005
    t_ = bpy.data.objects.new('streetplate_txt', cu); COL.objects.link(t_); t_.location = (-2.5, -13.701, zz_); t_.rotation_euler = (math.pi / 2, 0, 0)
    cu.materials.append(M['plateframe'])
# imbornales junto al bordillo y tapas de alcantarilla en los carriles
simple('castiron', 0x2a2a29, .6, .7)
ib = MB(); tp = MB()
for xi in range(-44, 60, 26):
    ib.box(xi - .25, xi + .25, RY1 - .38, RY1 - .02, -.008, .002)
for (xm, ym) in ((-9.0, RYC + 1.4), (21.0, RYC - 1.5), (48.0, RYC + 1.3)):
    tp.cyl(xm, ym, -.006, .003, .33, 40)
ib.obj('gullies', 'castiron', 0); tp.obj('manholes', 'castiron', .002, smooth=False)
# rejilla de los imbornales y relieve de las tapas: con un material de barras
m, nt, b = newmat('gratebars'); M['gratebars'] = m
tcg = node(nt, 'ShaderNodeTexCoord'); wvb = node(nt, 'ShaderNodeTexWave'); wvb.wave_type = 'BANDS'; wvb.bands_direction = 'X'; wvb.wave_profile = 'SAW'
wvb.inputs['Scale'].default_value = 60; L(nt, tcg.outputs['Object'], wvb.inputs['Vector'])
gtb = node(nt, 'ShaderNodeMath'); gtb.operation = 'GREATER_THAN'; gtb.inputs[1].default_value = .55; L(nt, wvb.outputs['Fac'], gtb.inputs[0])
L(nt, mix(nt, gtb.outputs[0], lin(0x2c2b29), lin(0x060606)), b.inputs['Base Color']); b.inputs['Metallic'].default_value = .6; b.inputs['Roughness'].default_value = .55
bpy.data.objects['gullies'].data.materials[0] = M['gratebars']

# ------------------------------------------------------------------ farolas una a una: algo de inclinación, altura y desgaste distintos
for nm_ in ('lampposts', 'lampheads', 'lampglass'):
    o_ = bpy.data.objects.get(nm_)
    if o_: bpy.data.objects.remove(o_, do_unlink=True)
simple('lampmetal2', 0x44474a, .55, .7); simple('lampmetal3', 0x34373a, .4, .85)
for k, xl in enumerate([14 + 34 * k for k in range(-6, 6)]):
    root = empty('lamp%d' % k); root.location = (xl, RY1 + .45, .13)
    root.rotation_euler = (CR.uniform(-.018, .018), CR.uniform(-.018, .018), CR.uniform(-.03, .03))
    hgt = 6.07 + CR.uniform(-.12, .1); mat_ = CR.choice(['lampmetal', 'lampmetal2', 'lampmetal3'])
    pole_, head_, gl_ = MB(), MB(), MB()
    pole_.cyl(0, 0, 0, hgt, .075, 12, r2=.05); pole_.box(-.03, .03, -1.15, 0, hgt - .07, hgt - .01)
    pole_.cyl(0, 0, 0, .55, .1, 12); pole_.box(-.06, .06, .07, .1, .9, 1.15)   # base más ancha y registro
    head_.box(-.2, .2, -1.6, -1.0, hgt - .13, hgt - .03); gl_.box(-.17, .17, -1.57, -1.03, hgt - .14, hgt - .13)
    pole_.obj('lamppole%d' % k, mat_, .006, root, smooth=True); head_.obj('lamphead%d' % k, mat_, .01, root); gl_.obj('lampglass%d' % k, 'lampglass', 0, root)
