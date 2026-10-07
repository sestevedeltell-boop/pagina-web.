/* UNIKAL · Casa 3D que se despieza con el scroll.
   Requiere THREE (r147) y THREE.RoundedBoxGeometry cargados antes. */
(function () {
  const canvas = document.getElementById('scene');
  if (!canvas || !window.THREE) return;
  const T = THREE;
  if (T.ColorManagement) T.ColorManagement.legacyMode = false; // colores hex en sRGB
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const lowPower = matchMedia('(max-width: 760px)').matches || /Android|iPhone|iPad|Mobi/i.test(navigator.userAgent);
  const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
  const lerp = (a, b, t) => a + (b - a) * t;
  const ss = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
  const rand = (a, b) => a + Math.random() * (b - a);
  let seed = 11; const srand = (a, b) => { seed = (seed * 16807) % 2147483647; return a + (seed / 2147483647) * (b - a); };

  /* ---------- Renderer, cielo y luz ---------- */
  const renderer = new T.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(devicePixelRatio, lowPower ? 1.5 : 2));
  renderer.outputEncoding = T.sRGBEncoding;
  renderer.toneMapping = T.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.0;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = T.PCFSoftShadowMap;

  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(28, 1, 0.5, 4000);

  const sunDir = new T.Vector3().setFromSphericalCoords(1, T.MathUtils.degToRad(90 - 36), T.MathUtils.degToRad(32));
  // Cielo degradado: fondo visible y luz ambiental (el sol lo aporta la luz direccional)
  function skyDome(withSun) {
    const g = new T.SphereGeometry(3000, 48, 24), pos = g.attributes.position, col = [], c = new T.Color();
    const top = new T.Color(0x2f6bb0), hor = new T.Color(0xc7d9e6), low = new T.Color(0x6b6a52);
    for (let i = 0; i < pos.count; i++) {
      const y = pos.getY(i) / 3000;
      if (y >= 0) c.copy(hor).lerp(top, Math.pow(y, .55)); else c.copy(hor).lerp(low, Math.min(1, -y * 5));
      col.push(c.r, c.g, c.b);
    }
    g.setAttribute('color', new T.Float32BufferAttribute(col, 3));
    const dome = new T.Mesh(g, new T.MeshBasicMaterial({ vertexColors: true, side: T.BackSide, fog: false, depthWrite: false }));
    if (withSun) {
      const s = new T.Mesh(new T.SphereGeometry(140, 16, 12), new T.MeshBasicMaterial({ color: new T.Color(14, 12, 10), fog: false }));
      s.position.copy(sunDir).multiplyScalar(2600); dome.add(s);
    }
    return dome;
  }
  const pmrem = new T.PMREMGenerator(renderer);
  const envScene = new T.Scene(); envScene.add(skyDome(true));
  scene.environment = pmrem.fromScene(envScene, .02, .1, 4000).texture;
  scene.add(skyDome(false));
  scene.fog = new T.Fog(0xcdd9e0, 260, 1500);

  const sun = new T.DirectionalLight(0xfff0d8, 2.6);
  sun.position.copy(sunDir).multiplyScalar(70);
  sun.castShadow = true;
  sun.shadow.mapSize.set(lowPower ? 2048 : 4096, lowPower ? 2048 : 4096);
  Object.assign(sun.shadow.camera, { left: -26, right: 26, top: 26, bottom: -26, near: 10, far: 160 });
  sun.shadow.bias = -0.00025; sun.shadow.normalBias = 0.025; sun.shadow.radius = 3;
  scene.add(sun);

  /* ---------- Texturas ---------- */
  const BASE = 'assets/tex/';
  const manager = new T.LoadingManager();
  manager.onLoad = () => canvas.classList.add('ready');
  setTimeout(() => canvas.classList.add('ready'), 5000);
  const TL = new T.TextureLoader(manager);
  const aniso = Math.min(8, renderer.capabilities.getMaxAnisotropy());
  function tex(name, srgb = true, rx = 1, ry = 1) {
    const t = TL.load(BASE + name);
    t.wrapS = t.wrapT = T.RepeatWrapping; t.repeat.set(rx, ry); t.anisotropy = aniso;
    if (srgb) t.encoding = T.sRGBEncoding;
    return t;
  }
  const tx = {
    grass: tex('grass.jpg'), grassN: tex('grass_n.jpg', false),
    wood: tex('wood.jpg'), woodN: tex('wood_n.jpg', false), woodR: tex('wood_r.jpg', false),
    stone: tex('stone.jpg'), stoneN: tex('stone_n.jpg', false),
    tile: tex('tile.jpg'), stucco: tex('stucco.jpg', true, 2, 2), stuccoN: tex('stucco_n.jpg', false, 2, 2),
    pool: tex('pooltile.jpg'), waterN: tex('water_n.jpg', false, 3, 3), caus: tex('caustics.jpg', false),
    gravel: tex('gravel.jpg'), frond: tex('frond.png'), leaves: tex('leaves.png'), bark: tex('bark.jpg', true, 3, 1),
    foam: tex('foam.png'), aoBlob: tex('ao_blob.png'), aoEdge: tex('ao_edge.png'),
  };
  tx.aoBlob.wrapS = tx.aoBlob.wrapT = tx.aoEdge.wrapS = tx.aoEdge.wrapT = T.ClampToEdgeWrapping;
  tx.frond.wrapS = tx.frond.wrapT = tx.leaves.wrapS = tx.leaves.wrapT = tx.foam.wrapS = tx.foam.wrapT = T.ClampToEdgeWrapping;

  // Panel solar con celdas (lienzo)
  const pc = document.createElement('canvas'); pc.width = 128; pc.height = 256;
  const g2 = pc.getContext('2d'); g2.fillStyle = '#0d1a33'; g2.fillRect(0, 0, 128, 256);
  g2.strokeStyle = '#3b5578'; g2.lineWidth = 2;
  for (let x = 0; x <= 128; x += 21.3) { g2.beginPath(); g2.moveTo(x, 0); g2.lineTo(x, 256); g2.stroke(); }
  for (let y = 0; y <= 256; y += 21.3) { g2.beginPath(); g2.moveTo(0, y); g2.lineTo(128, y); g2.stroke(); }
  g2.strokeStyle = '#c9ced6'; g2.lineWidth = 6; g2.strokeRect(0, 0, 128, 256);
  const panelTex = new T.CanvasTexture(pc); panelTex.encoding = T.sRGBEncoding; panelTex.anisotropy = aniso;

  /* ---------- Materiales ---------- */
  const S = (o) => new T.MeshStandardMaterial(o);
  const shimmer = { time: { value: 0 }, caus: { value: tx.caus }, k: { value: 0.55 } };
  const mat = {
    stucco: S({ color: 0xffffff, map: tx.stucco, normalMap: tx.stuccoN, normalScale: new T.Vector2(.25, .25), roughness: .92, envMapIntensity: .75 }),
    stone: S({ map: tx.stone, normalMap: tx.stoneN, normalScale: new T.Vector2(.9, .9), roughness: .95 }),
    tile: S({ map: tx.tile, roughness: .45, envMapIntensity: .8 }),
    wood: S({ map: tx.wood, normalMap: tx.woodN, roughnessMap: tx.woodR, roughness: 1, envMapIntensity: .7 }),
    grass: S({ map: tx.grass, normalMap: tx.grassN, normalScale: new T.Vector2(.7, .7), roughness: 1, envMapIntensity: .55 }),
    gravel: S({ map: tx.gravel, roughness: 1, envMapIntensity: .5 }),
    land: S({ map: tx.gravel, color: 0x9c9a7e, roughness: 1, envMapIntensity: .45 }),
    scrub: S({ color: 0x27331a, roughness: 1, envMapIntensity: .5 }),
    olive: S({ color: 0x3f4d2c, roughness: 1, envMapIntensity: .5 }),
    pool: S({ map: tx.pool, roughness: .2, envMapIntensity: .7 }),
    alu: S({ color: 0x2b2d30, metalness: .75, roughness: .35 }),
    steel: S({ color: 0xbfc3c7, metalness: 1, roughness: .25 }),
    black: S({ color: 0x141414, roughness: .4, metalness: .2 }),
    fabric: S({ color: 0x8b8884, roughness: 1 }),
    fabricLight: S({ color: 0xece8e0, roughness: 1 }),
    cushionBlue: S({ color: 0x7f9cc9, roughness: 1 }),
    rug: S({ color: 0xcfc6b8, roughness: 1 }),
    darkWood: S({ color: 0x4b3528, roughness: .55 }),
    oak: S({ color: 0xb98b5b, roughness: .5 }),
    marble: S({ color: 0x1d4a3b, roughness: .15, metalness: .05 }),
    lacquer: S({ color: 0xf3f1ec, roughness: .3 }),
    bedPink: S({ color: 0xc9a3a0, roughness: 1 }),
    lamp: S({ color: 0xfff6e6, emissive: 0xffd9a8, emissiveIntensity: 2.2 }),
    downlight: S({ color: 0xffffff, emissive: 0xfff1d6, emissiveIntensity: 1.6 }),
    panel: S({ map: panelTex, roughness: .18, metalness: .35, envMapIntensity: 1.4 }),
    canvas: S({ color: 0xe9e1d2, roughness: 1, side: T.DoubleSide }),
    trunk: S({ map: tx.bark, roughness: 1 }),
    leaf: S({ map: tx.frond, alphaTest: .45, side: T.DoubleSide, roughness: .75, color: 0xdcebc8 }),
    dry: S({ map: tx.frond, alphaTest: .45, side: T.DoubleSide, roughness: .9, color: 0xa88d62 }),
    bush: S({ map: tx.leaves, alphaTest: .45, side: T.DoubleSide, roughness: .85 }),
    bushCore: S({ color: 0x23391b, roughness: 1 }),
    hills: S({ vertexColors: true, roughness: 1, flatShading: false }),
    pipe: S({ color: 0xff6a2b, emissive: 0xff4a10, emissiveIntensity: 1.3, transparent: true, opacity: 0 }),
    led: S({ color: 0xffffff, emissive: 0x9ff6ff, emissiveIntensity: 0.5 }),
    bubble: S({ color: 0xffffff, transparent: true, opacity: .8, roughness: .1 }),
    foam: new T.MeshBasicMaterial({ map: tx.foam, transparent: true, depthWrite: false, opacity: .0 }),
    ao: new T.MeshBasicMaterial({ color: 0x000000, map: tx.aoBlob, transparent: true, depthWrite: false, opacity: .55, polygonOffset: true, polygonOffsetFactor: -2 }),
    aoEdge: new T.MeshBasicMaterial({ color: 0x000000, map: tx.aoEdge, transparent: true, depthWrite: false, opacity: .4, polygonOffset: true, polygonOffsetFactor: -2 }),
  };
  // Cáusticas animadas sobre el gresite (en coordenadas de mundo)
  mat.pool.onBeforeCompile = (sh) => {
    sh.uniforms.uTime = shimmer.time; sh.uniforms.uCaus = shimmer.caus; sh.uniforms.uK = shimmer.k;
    sh.vertexShader = sh.vertexShader.replace('#include <common>', '#include <common>\nvarying vec3 vWP;')
      .replace('#include <project_vertex>', '#include <project_vertex>\nvWP=(modelMatrix*vec4(transformed,1.0)).xyz;');
    sh.fragmentShader = sh.fragmentShader.replace('#include <common>', '#include <common>\nvarying vec3 vWP;uniform float uTime;uniform float uK;uniform sampler2D uCaus;')
      .replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>
        vec2 cp=vWP.xz+vec2(vWP.y*0.35);
        float c1=texture2D(uCaus,cp*0.32+vec2(uTime*0.021,uTime*0.013)).r;
        float c2=texture2D(uCaus,cp*0.27+vec2(-uTime*0.017,uTime*0.019)).r;
        totalEmissiveRadiance+=vec3(0.72,0.95,1.0)*pow(c1*c2,0.75)*uK;`);
  };
  // Vidrio y agua: refracción real en escritorio, transparencia simple en móvil
  const glass = lowPower
    ? S({ color: 0x9fb9c2, metalness: .3, roughness: .04, transparent: true, opacity: .32, envMapIntensity: 1.6 })
    : new T.MeshPhysicalMaterial({ color: 0xffffff, metalness: 0, roughness: .02, transmission: 1, thickness: .06, ior: 1.5, attenuationColor: new T.Color(0xcfe3df), attenuationDistance: 1.4, envMapIntensity: 1.5, specularIntensity: 1 });
  const water = lowPower
    ? S({ color: 0x2cc3d6, roughness: .03, metalness: .1, transparent: true, opacity: .55, normalMap: tx.waterN, normalScale: new T.Vector2(.4, .4), envMapIntensity: 1.3 })
    : new T.MeshPhysicalMaterial({ color: 0xffffff, roughness: .03, metalness: 0, transmission: 1, thickness: 1.4, ior: 1.33, attenuationColor: new T.Color(0x1fb3c4), attenuationDistance: 1.9, normalMap: tx.waterN, normalScale: new T.Vector2(.3, .3), clearcoat: 1, clearcoatRoughness: .02, envMapIntensity: 1.2 });
  mat.glass = glass; mat.water = water;

  // Sombras de hojas con recorte alfa
  const leafDepth = (m) => new T.MeshDepthMaterial({ depthPacking: T.RGBADepthPacking, map: m.map, alphaTest: .45 });
  const depthFrond = leafDepth(mat.leaf), depthBush = leafDepth(mat.bush);

  /* ---------- Utilidades de geometría ---------- */
  function uvBox(geo, w, h, d, size) {
    const uv = geo.attributes.uv; const dims = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]];
    for (let f = 0; f < 6; f++) for (let k = 0; k < 4; k++) { const i = f * 4 + k; uv.setXY(i, uv.getX(i) * dims[f][0] / size, uv.getY(i) * dims[f][1] / size); }
    return geo;
  }
  function mesh(geo, m, parent, x = 0, y = 0, z = 0, cast = true, recv = true) {
    const o = new T.Mesh(geo, m); o.position.set(x, y, z); o.castShadow = cast; o.receiveShadow = recv; parent.add(o); return o;
  }
  // Caja con textura a escala real (size = metros que ocupa la textura)
  const tbox = (w, h, d, m, x, y, z, parent, size = 2, cast = true) => mesh(uvBox(new T.BoxGeometry(w, h, d), w, h, d, size), m, parent, x, y, z, cast);
  // Volumen blanco con aristas suavizadas
  const rbox = (w, h, d, m, x, y, z, parent, r = .03, cast = true) => mesh(new T.RoundedBoxGeometry(w, h, d, 2, r), m, parent, x, y, z, cast);
  const box = (w, h, d, m, x, y, z, parent, cast = true) => mesh(new T.BoxGeometry(w, h, d), m, parent, x, y, z, cast);
  function plane(w, d, m, x, y, z, parent, size, recv = true) {
    const g = new T.PlaneGeometry(w, d); g.rotateX(-Math.PI / 2);
    if (size) { const uv = g.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * w / size, uv.getY(i) * d / size); }
    return mesh(g, m, parent, x, y, z, false, recv);
  }
  const blob = (w, d, x, y, z, parent, op = .5) => { const p = plane(w, d, mat.ao, x, y, z, parent); p.material = mat.ao.clone(); p.material.opacity = op; p.renderOrder = 1; return p; };
  function edgeAO(len, x, y, z, rotY, parent, width = 1.1, op = .38) {
    const g = new T.PlaneGeometry(len, width); g.rotateX(-Math.PI / 2); g.translate(0, 0, width / 2);
    const m = mat.aoEdge.clone(); m.opacity = op; const p = mesh(g, m, parent, x, y, z, false, false); p.rotation.y = rotY; p.renderOrder = 1; return p;
  }
  const anchor = (parent, x, y, z) => { const o = new T.Object3D(); o.position.set(x, y, z); parent.add(o); return o; };

  // Acristalamiento con perfilería de aluminio
  function glazing(parent, w, h, x, y, z, rotY = 0, panes = 4) {
    const g = new T.Group(); g.position.set(x, y, z); g.rotation.y = rotY; parent.add(g);
    mesh(new T.BoxGeometry(w, h, .03), glass, g, 0, h / 2, 0, false, false);
    box(w + .1, .07, .12, mat.alu, 0, .035, 0, g); box(w + .1, .07, .12, mat.alu, 0, h - .035, 0, g);
    for (let i = 0; i <= panes; i++) box(.06, h, .12, mat.alu, -w / 2 + i * w / panes, h / 2, 0, g);
    return g;
  }

  /* ---------- Mundo ---------- */
  const world = new T.Group(); scene.add(world);

  // Terreno exterior, montañas y vecinos
  function holedPlane(outer, hole, m, y, size) {
    const sh = new T.Shape(); sh.moveTo(outer[0], -outer[3]); sh.lineTo(outer[1], -outer[3]); sh.lineTo(outer[1], -outer[2]); sh.lineTo(outer[0], -outer[2]); sh.closePath();
    const h = new T.Path(); h.moveTo(hole[0], -hole[3]); h.lineTo(hole[0], -hole[2]); h.lineTo(hole[1], -hole[2]); h.lineTo(hole[1], -hole[3]); h.closePath(); sh.holes.push(h);
    const g = new T.ShapeGeometry(sh); g.rotateX(-Math.PI / 2);
    const uv = g.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) / size, uv.getY(i) / size);
    return mesh(g, m, world, 0, y, 0, false, true);
  }
  holedPlane([-1300, 1300, -1300, 1300], [-16, 18, -13.5, 13.5], mat.land, -0.02, 14);
  // Monte bajo y olivos alrededor de la parcela
  (function () {
    const n = 420, im = new T.InstancedMesh(new T.IcosahedronGeometry(1, 1), mat.scrub, n), d = new T.Object3D();
    const trees = 90, tm = new T.InstancedMesh(new T.IcosahedronGeometry(1, 2), mat.olive, trees), trunks = new T.InstancedMesh(new T.CylinderGeometry(.12, .2, 1, 6), mat.trunk, trees);
    let i = 0, guard = 0;
    while (i < n && guard++ < 5000) {
      const x = srand(-160, 160), z = srand(-160, 120);
      if (x > -19 && x < 21 && z > -16 && z < 16) continue;
      const sc = srand(.3, .9); d.position.set(x, sc * .35, z); d.scale.set(sc * srand(.8, 1.4), sc * .6, sc * srand(.8, 1.4)); d.rotation.set(0, srand(0, 6), 0); d.updateMatrix(); im.setMatrixAt(i++, d.matrix);
    }
    im.count = i; im.castShadow = true; im.receiveShadow = true; world.add(im);
    let j = 0; guard = 0;
    while (j < trees && guard++ < 5000) {
      const x = srand(-120, 120), z = srand(-130, 60);
      if (x > -20 && x < 22 && z > -17 && z < 17) continue;
      const h = srand(2.2, 3.6), r = srand(1.2, 2.0);
      d.position.set(x, h, z); d.scale.set(r, r * .75, r); d.rotation.set(0, srand(0, 6), 0); d.updateMatrix(); tm.setMatrixAt(j, d.matrix);
      d.position.set(x, h * .5, z); d.scale.set(1, h, 1); d.updateMatrix(); trunks.setMatrixAt(j, d.matrix); j++;
    }
    tm.count = trunks.count = j; tm.castShadow = trunks.castShadow = true; tm.receiveShadow = true; world.add(tm, trunks);
  })();
  (function hills() {
    const segA = 160, rings = 7, pos = [], col = [], idx = [];
    const c1 = new T.Color(0x8c9370), c2 = new T.Color(0x9fa8b3);
    for (let r = 0; r < rings; r++) {
      const rad = 420 + r * 70;
      for (let a = 0; a <= segA; a++) {
        const ang = a / segA * Math.PI * 2;
        const n = Math.sin(ang * 3 + 1.3) * .5 + Math.sin(ang * 7 + .4) * .3 + Math.sin(ang * 13 + 2) * .15 + Math.sin(ang * 29) * .05;
        const front = .35 + .65 * (0.5 - 0.5 * Math.cos(ang - Math.PI));
        const hgt = r === 0 || r === rings - 1 ? -2 : Math.max(0, (60 + n * 55) * Math.sin(r / (rings - 1) * Math.PI) * front);
        pos.push(Math.sin(ang) * rad, hgt, Math.cos(ang) * rad);
        const c = c1.clone().lerp(c2, r / rings); col.push(c.r, c.g, c.b);
      }
    }
    for (let r = 0; r < rings - 1; r++) for (let a = 0; a < segA; a++) {
      const i = r * (segA + 1) + a, j = i + segA + 1; idx.push(i, j, i + 1, i + 1, j, j + 1);
    }
    const g = new T.BufferGeometry(); g.setAttribute('position', new T.Float32BufferAttribute(pos, 3));
    g.setAttribute('color', new T.Float32BufferAttribute(col, 3)); g.setIndex(idx); g.computeVertexNormals();
    const m = new T.Mesh(g, mat.hills); m.material.side = T.DoubleSide; world.add(m);
  })();
  [[-48, -40, 10, 6, 9], [36, -52, 12, 7, 8], [-70, 10, 9, 6, 9], [62, -6, 10, 7, 8], [10, -72, 14, 6, 10]].forEach(([x, z, w, h, d]) => {
    rbox(w, h, d, mat.stucco, x, h / 2, z, world, .05);
    box(w * .6, h * .3, .1, mat.alu, x, h * .55, z + d / 2 + .02, world, false);
  });

  // Parcela: césped y muro perimetral con lamas
  holedPlane([-16, 18, -13.5, 13.5], [-3, 9, 4.4, 8.8], mat.grass, 0.01, 5);
  const wallM = mat.stucco;
  rbox(34, 1.1, .3, wallM, 1, .55, -13.4, world, .02);
  rbox(.3, 1.1, 27, wallM, -16, .55, 0, world, .02);
  rbox(.3, 1.1, 27, wallM, 18, .55, 0, world, .02);
  rbox(15.2, .7, .3, wallM, -8.4, .35, 13.5, world, .02); rbox(15.2, .7, .3, wallM, 10.4, .35, 13.5, world, .02);
  box(3.6, .05, .3, mat.alu, 1, .02, 13.5, world, false);
  (function slats() {
    const runs = [[-16, -13.4, 18, -13.4], [-16, -13.4, -16, 13.5], [18, -13.4, 18, 13.5]];
    let n = 0; const mats = [];
    runs.forEach(([x0, z0, x1, z1]) => {
      const L = Math.hypot(x1 - x0, z1 - z0), cnt = Math.floor(L / .13);
      for (let i = 0; i < cnt; i++) { const t = i / cnt; mats.push([lerp(x0, x1, t), lerp(z0, z1, t), x0 === x1]); n++; }
    });
    const im = new T.InstancedMesh(new T.BoxGeometry(.07, .95, .05), mat.alu, n); const d = new T.Object3D();
    mats.forEach(([x, z, side], i) => { d.position.set(x, 1.58, z); d.rotation.y = side ? Math.PI / 2 : 0; d.updateMatrix(); im.setMatrixAt(i, d.matrix); });
    im.castShadow = true; im.receiveShadow = true; world.add(im);
  })();
  edgeAO(34, 1, .02, -13.25, 0, world, .9, .35);

  /* ===== Base: plataforma, terraza, interiores y suelo radiante ===== */
  const base = new T.Group(); world.add(base);
  // Plataforma de la vivienda + terraza de porcelánico
  tbox(16, .3, 6.2, mat.tile, -1.5, .15, -4.1, base, 2.4);
  tbox(18.4, .3, 4.6, mat.tile, -0.3, .15, 1.2, base, 2.4);
  tbox(18.6, .15, .5, mat.tile, -0.3, .075, 3.75, base, 2.4); // escalón
  edgeAO(10.6, -9.5, .02, -2.0, -Math.PI / 2, world, 1.0, .3); edgeAO(10.6, 6.5, .02, -2.0, Math.PI / 2, world, 1.0, .3);
  // Interior planta baja
  const inside = new T.Group(); base.add(inside);
  box(5.2, .45, 1.0, mat.fabric, -1.6, .52, -6.2, inside); box(5.2, .45, .25, mat.fabric, -1.6, .9, -6.62, inside);
  box(1.0, .45, 2.6, mat.fabric, -4.6, .52, -5.2, inside);
  [-2.8, -1.6, -.4].forEach((x) => box(.7, .35, .2, mat.fabricLight, x, .85, -6.45, inside));
  box(4.2, .02, 3, mat.rug, -2.0, .31, -4.8, inside, false);
  box(1.4, .38, .9, mat.marble, -2.0, .5, -4.7, inside);
  box(4.2, .55, .5, mat.darkWood, -1.6, .58, -2.4, inside); box(2.6, 1.5, .06, mat.black, -1.6, 1.95, -2.4, inside);
  // Comedor y cocina
  box(2.6, .07, 1.1, mat.oak, 2.6, 1.07, -5.2, inside);
  box(.1, .72, .9, mat.black, 1.5, .68, -5.2, inside); box(.1, .72, .9, mat.black, 3.7, .68, -5.2, inside);
  for (let i = 0; i < 3; i++) for (const s of [-1, 1]) { box(.48, .45, .48, mat.fabricLight, 1.7 + i * .9, .55, -5.2 + s * .85, inside); box(.48, .5, .08, mat.fabricLight, 1.7 + i * .9, .98, -5.2 + s * 1.07, inside); }
  for (let i = 0; i < 3; i++) { box(.012, 1.4, .012, mat.black, 1.8 + i * .8, 2.7, -5.2, inside, false); mesh(new T.CylinderGeometry(.09, .14, .3, 16), mat.lamp, inside, 1.8 + i * .8, 1.95, -5.2, false); }
  rbox(3.2, .92, 1.0, mat.lacquer, 2.4, .76, -2.9, inside, .02);
  box(3.4, .04, 1.1, mat.tile, 2.4, 1.24, -2.9, inside);
  rbox(2.3, 2.6, .6, mat.lacquer, 2.85, 1.6, -6.75, inside, .02);
  // Escalera volada con barandilla de vidrio
  for (let i = 0; i < 12; i++) box(1.1, .07, .3, mat.darkWood, -5.75, .4 + i * .26, -6.6 + i * .3, inside);
  mesh(new T.BoxGeometry(.02, 1.0, 4.3), glass, inside, -5.17, 2.35, -4.95, false, false).rotation.x = -0.71;
  // Suelo radiante (aparece al despiezar)
  const radiant = new T.Group(); base.add(radiant);
  for (let i = 0; i < 11; i++) {
    box(10.2, .06, .16, mat.pipe, -1.2, .36, -6.7 + i * .5, radiant, false);
    if (i < 10) { const x = (i % 2 === 0) ? 3.9 : -6.3; box(.16, .06, .66, mat.pipe, x, .36, -6.7 + i * .5 + .25, radiant, false); }
  }
  const heat = plane(10.4, 5.8, new T.MeshBasicMaterial({ color: 0xff7a2a, transparent: true, opacity: 0, depthWrite: false, blending: T.AdditiveBlending }), -1.2, .45, -4.1, radiant);
  const lightIn = new T.PointLight(0xffd9a8, .55, 14, 2); lightIn.position.set(-1, 2.6, -4.5); base.add(lightIn);

  /* ===== Planta baja: muros, piedra y vidrio ===== */
  const gWalls = new T.Group(); world.add(gWalls);
  tbox(3.2, 3.3, 6.2, mat.stone, -8.0, 1.95, -4.1, gWalls, 3); // volumen de piedra
  rbox(12.4, 3.3, .3, mat.stucco, -.2, 1.95, -7.05, gWalls);   // muro trasero
  rbox(2.4, 3.3, 6.2, mat.stucco, 5.2, 1.95, -4.1, gWalls);    // volumen este
  box(.5, 2.4, .05, mat.alu, 5.2, 1.8, -.98, gWalls);           // ventana rasgada
  glazing(gWalls, 10.4, 3.2, -1.2, .3, -1.2, 0, 4);
  box(.16, 3.3, .16, mat.alu, -9.3, 1.95, 1.85, gWalls); box(.16, 3.3, .16, mat.alu, 5.2, 1.95, 1.85, gWalls);
  // Cocina exterior bajo el porche
  tbox(2.6, .9, .7, mat.stone, -5.2, .75, 2.4, base, 3); box(2.7, .05, .78, mat.black, -5.2, 1.22, 2.4, base);
  // Mesa exterior y sofá
  box(2.2, .05, 1.0, mat.lacquer, 0, 1.06, 1.2, base); [[-1, .8], [1, .8], [-1, 1.6], [1, 1.6]].forEach(([x, z]) => box(.05, .74, .05, mat.alu, x, .67, z, base));
  for (let i = 0; i < 3; i++) for (const s of [-1, 1]) box(.45, .42, .45, mat.fabricLight, -.7 + i * .7, .51, 1.2 + s * .75, base);
  rbox(3.2, .4, 1.0, mat.fabricLight, 3.0, .5, .6, base, .08); rbox(3.2, .45, .25, mat.fabricLight, 3.0, .85, .2, base, .08);
  [2.0, 3.0, 4.0].forEach((x, i) => { const c = rbox(.55, .5, .14, i === 1 ? mat.fabricLight : mat.cushionBlue, x, .95, .38, base, .06); c.rotation.x = -.25; });
  blob(4.2, 2.4, 3.0, .31, .5, base, .35); blob(3.6, 2.6, 0, .31, 1.2, base, .35);
  const aStone = anchor(gWalls, -7.2, 2.2, -.95);

  /* ===== Planta alta en voladizo ===== */
  const upper = new T.Group(); world.add(upper);
  rbox(15.6, .42, 9.2, mat.stucco, -2.2, 3.81, -2.5, upper, .03);      // forjado en voladizo
  for (let i = 0; i < 8; i++) mesh(new T.CylinderGeometry(.06, .06, .02, 14), mat.downlight, upper, -8.5 + i * 1.6, 3.59, 1.2, false);
  rbox(.32, 3.0, 9.2, mat.stucco, -9.84, 5.5, -2.5, upper);            // aleta oeste
  rbox(6.2, 3.0, 9.2, mat.stucco, 2.5, 5.5, -2.5, upper, .03);         // volumen dormitorio
  box(5.0, .9, .05, mat.alu, 2.5, 5.6, 2.12, upper);                   // ventana horizontal
  mesh(new T.BoxGeometry(4.9, .8, .03), glass, upper, 2.5, 5.6, 2.16, false, false);
  rbox(9.6, 3.0, .3, mat.stucco, -4.9, 5.5, -6.95, upper);             // muro trasero
  glazing(upper, 9.5, 2.95, -4.9, 4.02, -1.6, 0, 4);
  // Terraza con barandilla de vidrio
  mesh(new T.BoxGeometry(9.5, 1.0, .03), glass, upper, -4.9, 4.55, 2.0, false, false);
  for (let i = 0; i < 6; i++) box(.06, .1, .08, mat.steel, -9.2 + i * 1.75, 4.1, 2.0, upper);
  tbox(9.5, .04, 3.4, mat.tile, -4.9, 4.04, .25, upper, 2.4, false);
  // Interior: dormitorio
  rbox(2.0, .5, 2.2, mat.fabricLight, -4.8, 4.27, -4.6, upper, .08);
  rbox(2.0, .12, 1.4, mat.bedPink, -4.8, 4.56, -4.2, upper, .05);
  rbox(2.2, 1.1, .12, mat.darkWood, -4.8, 4.6, -5.8, upper);
  box(3.4, 2.6, .5, mat.oak, -1.6, 5.3, -6.5, upper);
  const pend = mesh(new T.SphereGeometry(.16, 16, 12), mat.lamp, upper, -6.3, 5.1, -5.3, false); pend.scale.y = 1.5;
  const aCanti = anchor(upper, -9.2, 4.4, 2.0);
  edgeAO(10.4, -1.2, .31, -1.15, 0, base, 1.6, .28);
  const aSmart = anchor(upper, 2.5, 5.6, 2.15);

  /* ===== Cubierta con placas solares ===== */
  const roof = new T.Group(); world.add(roof);
  rbox(16.0, .36, 9.4, mat.stucco, -2.2, 7.18, -2.5, roof, .03);
  rbox(16.0, .5, .2, mat.stucco, -2.2, 7.6, 2.15, roof, .02); rbox(16.0, .5, .2, mat.stucco, -2.2, 7.6, -7.15, roof, .02);
  rbox(.2, .5, 9.4, mat.stucco, -10.1, 7.6, -2.5, roof, .02); rbox(.2, .5, 9.4, mat.stucco, 5.7, 7.6, -2.5, roof, .02);
  plane(15.6, 9.0, mat.gravel, -2.2, 7.37, -2.5, roof, 4);
  for (let r = 0; r < 2; r++) for (let c = 0; c < 6; c++) {
    const p = box(1.1, .04, 1.9, mat.panel, -8.6 + c * 1.2, 7.75, -5.6 + r * 2.2, roof); p.rotation.x = -.42;
    box(.04, .35, .04, mat.alu, -8.6 + c * 1.2, 7.5, -4.9 + r * 2.2, roof);
  }
  rbox(3.0, 1.6, 2.8, mat.stucco, 3.2, 8.2, -5.0, roof);
  const aRoof = anchor(roof, -6.2, 7.9, -4.6);

  /* ===== Piscina, tarima y jacuzzi ===== */
  const outdoor = new T.Group(); world.add(outdoor);
  const PX = 3, PZ = 6.6, PW = 12, PD = 4.4, DEPTH = 1.5;
  // Vaso con gresite
  const basin = new T.Group(); basin.position.set(PX, 0, PZ); outdoor.add(basin);
  const poolFloor = new T.PlaneGeometry(PW, PD); poolFloor.rotateX(-Math.PI / 2);
  (function () { const uv = poolFloor.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * PW / 1.6, uv.getY(i) * PD / 1.6); })();
  mesh(poolFloor, mat.pool, basin, 0, -DEPTH, 0, false);
  [[PW, 0, -PD / 2, 0], [PW, 0, PD / 2, Math.PI], [PD, -PW / 2, 0, Math.PI / 2], [PD, PW / 2, 0, -Math.PI / 2]].forEach(([w, x, z, r]) => {
    const g = new T.PlaneGeometry(w, DEPTH + .1); const uv = g.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * w / 1.6, uv.getY(i) * (DEPTH + .1) / 1.6);
    const m = mesh(g, mat.pool, basin, x, -DEPTH / 2 + .05, z, false); m.rotation.y = r;
  });
  tbox(3.0, .45, 1.2, mat.pool, -PW / 2 + 1.5, -1.25, -PD / 2 + .6, basin, 1.6, false); // escalera romana
  tbox(3.0, .45, .6, mat.pool, -PW / 2 + 1.5, -.85, -PD / 2 + .3, basin, 1.6, false);
  const leds = [];
  for (let i = 0; i < 6; i++) { const l = mesh(new T.CircleGeometry(.1, 20), mat.led, basin, -PW / 2 + 1 + i * 2, -.45, -PD / 2 + .01, false, false); leds.push(l); }
  const waterTop = new T.PlaneGeometry(PW, PD); waterTop.rotateX(-Math.PI / 2);
  const waterMesh = mesh(waterTop, water, basin, 0, -.08, 0, false, false);
  const poolLight = new T.PointLight(0x84f2ff, 0, 10, 2); poolLight.position.set(0, -.3, 0); basin.add(poolLight);
  // Coronación de piedra
  tbox(PW + .8, .08, .4, mat.tile, PX, .04, PZ - PD / 2 - .2, outdoor, 2.4);
  tbox(PW + .8, .08, .4, mat.tile, PX, .04, PZ + PD / 2 + .2, outdoor, 2.4);
  tbox(.4, .08, PD, mat.tile, PX - PW / 2 - .2, .04, PZ, outdoor, 2.4);
  tbox(.4, .08, PD, mat.tile, PX + PW / 2 + .2, .04, PZ, outdoor, 2.4);
  // Tarima de ipe (oeste y sur)
  tbox(6.4, .08, 7.6, mat.wood, -6.6, .04, 7.8, outdoor, 1.12);
  tbox(PW + .8, .08, 2.4, mat.wood, PX, .04, PZ + PD / 2 + 1.6, outdoor, 1.12);
  // Jacuzzi elevado con burbujas
  const spa = new T.Group(); spa.position.set(-6.4, .08, 7.2); outdoor.add(spa);
  const ring = new T.Mesh(new T.CylinderGeometry(1.45, 1.5, .6, 64, 1, true), mat.stucco); ring.position.y = .3; ring.castShadow = ring.receiveShadow = true; spa.add(ring);
  const lip = new T.Mesh(new T.RingGeometry(1.18, 1.5, 64), mat.tile); lip.rotation.x = -Math.PI / 2; lip.position.y = .6; lip.receiveShadow = true; spa.add(lip);
  const poolBack = mat.pool.clone(); poolBack.side = T.BackSide; poolBack.onBeforeCompile = mat.pool.onBeforeCompile;
  const inner = new T.Mesh(new T.CylinderGeometry(1.18, 1.18, .57, 64, 1, true), poolBack); inner.position.y = .315; spa.add(inner);
  const spaFloor = new T.Mesh(new T.CircleGeometry(1.18, 64), mat.pool); spaFloor.rotation.x = -Math.PI / 2; spaFloor.position.y = .03; spa.add(spaFloor);
  const spaWater = new T.Mesh(new T.CircleGeometry(1.18, 64), water); spaWater.rotation.x = -Math.PI / 2; spaWater.position.y = .52; spa.add(spaWater);
  const foam = new T.Mesh(new T.CircleGeometry(1.15, 48), mat.foam); foam.rotation.x = -Math.PI / 2; foam.position.y = .535; foam.renderOrder = 2; spa.add(foam);
  const NB = 140, bubbles = new T.InstancedMesh(new T.SphereGeometry(.035, 8, 6), mat.bubble, NB); spa.add(bubbles);
  const bData = [...Array(NB)].map(() => ({ r: Math.sqrt(Math.random()) * 1.05, a: Math.random() * 6.28, t: Math.random(), s: .5 + Math.random() }));
  tbox(.9, .25, .5, mat.wood, -6.4, .2, 8.95, outdoor, 1.12);
  blob(4, 4, -6.4, .085, 7.2, outdoor, .45);
  const aSpa = anchor(spa, 0, .7, 0);
  const aPool = anchor(basin, 3.5, 0, .4);
  // Tumbonas, sombrilla
  function lounger(x, z, ry) {
    const g = new T.Group(); g.position.set(x, .08, z); g.rotation.y = ry; outdoor.add(g);
    rbox(.75, .22, 2.0, mat.lacquer, 0, .2, 0, g, .05);
    rbox(.68, .1, 1.35, mat.fabricLight, 0, .36, .3, g, .04);
    const back = rbox(.68, .1, .75, mat.fabricLight, 0, .55, -.62, g, .04); back.rotation.x = .75;
    blob(1.3, 2.6, x, .09, z, outdoor, .45);
  }
  lounger(1.0, 10.5, Math.PI); lounger(2.3, 10.5, Math.PI); lounger(3.6, 10.5, Math.PI);
  const pole = mesh(new T.CylinderGeometry(.035, .035, 2.6, 10), mat.alu, outdoor, 5.6, 1.38, 10.5);
  const canopy = mesh(new T.ConeGeometry(1.9, .45, 4, 1, true), mat.canvas, outdoor, 5.6, 2.55, 10.5); canopy.rotation.y = Math.PI / 4;
  blob(4, 4, 6.4, .09, 9.6, outdoor, .35);

  /* ===== Vegetación ===== */
  function palm(x, z, h, lean, yaw) {
    const g = new T.Group(); g.position.set(x, 0, z); world.add(g);
    const top = new T.Vector3(Math.sin(yaw) * lean * h, h, Math.cos(yaw) * lean * h);
    const curve = new T.CatmullRomCurve3([new T.Vector3(0, 0, 0), new T.Vector3(top.x * .15, h * .35, top.z * .15), new T.Vector3(top.x * .55, h * .72, top.z * .55), top]);
    const SEG = 28, RAD = 10, tg = new T.TubeGeometry(curve, SEG, .2, RAD, false);
    const pos = tg.attributes.position, c = new T.Vector3(), p = new T.Vector3();
    for (let i = 0; i <= SEG; i++) {
      curve.getPointAt(i / SEG, c); const s = (1 - .32 * (i / SEG)) * (i < 2 ? 1.35 - i * .15 : 1);
      for (let j = 0; j <= RAD; j++) { const k = i * (RAD + 1) + j; p.fromBufferAttribute(pos, k).sub(c).multiplyScalar(s).add(c); pos.setXYZ(k, p.x, p.y, p.z); }
    }
    tg.computeVertexNormals();
    mesh(tg, mat.trunk, g);
    const crown = new T.Group(); crown.position.copy(top); g.add(crown);
    mesh(new T.SphereGeometry(.32, 12, 10), mat.trunk, crown, 0, -.1, 0);
    const fronds = [];
    const n = 15;
    for (let i = 0; i < n; i++) {
      const dry = i >= n - 3;
      const len = dry ? srand(2.2, 2.8) : srand(3.0, 4.1), wid = len * .48;
      const fg = new T.PlaneGeometry(wid, len, 4, 12); fg.translate(0, len / 2, 0);
      const droop = dry ? .05 : srand(.35, .6);
      const fp = fg.attributes.position;
      for (let k = 0; k < fp.count; k++) { const y = fp.getY(k), x = fp.getX(k), s = y / len; fp.setZ(k, -Math.abs(x) * .45 + droop * s * s * len); }
      fg.computeVertexNormals();
      const fm = new T.Mesh(fg, dry ? mat.dry : mat.leaf);
      fm.customDepthMaterial = depthFrond; fm.castShadow = true; fm.receiveShadow = true;
      const pivot = new T.Group(); pivot.rotation.order = 'YXZ';
      const elev = dry ? srand(-1.3, -1.0) : (i < 5 ? srand(.6, 1.05) : srand(.05, .5));
      pivot.rotation.y = i / n * Math.PI * 2 * 2.618 + srand(-.2, .2);
      pivot.rotation.x = Math.PI / 2 - elev;
      pivot.add(fm); crown.add(pivot); fronds.push({ pivot, base: pivot.rotation.x, ph: srand(0, 6) });
    }
    blob(3.2, 3.2, x, .03, z, world, .3);
    return fronds;
  }
  const palms = [
    palm(10.6, .8, 8.6, .07, .6), palm(13.6, 3.2, 7.2, .1, 1.2), palm(-12.2, 2.4, 7.8, .08, -.7),
    palm(-13.4, -9.2, 9.2, .05, .3), palm(14.6, 11.2, 6.4, .12, 2.2), palm(-11.5, 10.5, 6.0, .1, -2.4),
  ];

  // Arbustos y setos con tarjetas de hojas instanciadas
  const cards = [], cores = [];
  function bush(x, y, z, sx, sy, sz, n) {
    cores.push([x, y, z, sx * .82, sy * .78, sz * .82]);
    for (let i = 0; i < n; i++) {
      const u = srand(0, Math.PI * 2), v = Math.acos(srand(-1, 1)), r = Math.cbrt(srand(.35, 1));
      cards.push([x + Math.sin(v) * Math.cos(u) * sx * r, y + Math.cos(v) * sy * r, z + Math.sin(v) * Math.sin(u) * sz * r, srand(.75, 1.15)]);
    }
  }
  for (let x = -15.2; x <= 17.2; x += .95) bush(x, 1.05, -12.6, .65, 1.05, .55, 22);
  for (let z = -11.6; z <= 12.4; z += 1.1) { bush(-15.3, .95, z, .6, .95, .55, 18); bush(17.3, .95, z, .6, .95, .55, 18); }
  for (let x = -15.4; x <= 17.4; x += 1.0) if (Math.abs(x - 1) > 2.4) bush(x, .55, 12.9, .55, .6, .45, 14);
  [[9.2, -.4, 1.0], [7.6, -.6, .8], [-11.2, 4.2, .9], [-10.5, 5.6, .7], [12.2, 5.0, .9], [13.2, 9.4, 1.0], [-12.8, 8.8, .8], [-10, -1.6, .75], [7.2, 1.5, .55], [11.6, -4, .9], [-12.6, -4.5, 1.0]]
    .forEach(([x, z, s]) => bush(x, s * .7, z, s, s * .8, s, Math.round(40 * s)));
  (function () {
    const im = new T.InstancedMesh(new T.PlaneGeometry(.75, .75), mat.bush, cards.length), d = new T.Object3D(), col = new T.Color();
    cards.forEach(([x, y, z, s], i) => {
      d.position.set(x, y, z); d.rotation.set(srand(0, 6.28), srand(0, 6.28), srand(0, 6.28)); d.scale.setScalar(s); d.updateMatrix(); im.setMatrixAt(i, d.matrix);
      col.setRGB(srand(.72, 1.05), srand(.82, 1.1), srand(.7, .95)); im.setColorAt(i, col);
    });
    im.castShadow = true; im.receiveShadow = true; im.customDepthMaterial = depthBush; world.add(im);
    const cm = new T.InstancedMesh(new T.SphereGeometry(1, 14, 10), mat.bushCore, cores.length);
    cores.forEach(([x, y, z, sx, sy, sz], i) => { d.position.set(x, y, z); d.rotation.set(0, 0, 0); d.scale.set(sx, sy, sz); d.updateMatrix(); cm.setMatrixAt(i, d.matrix); });
    cm.castShadow = true; cm.receiveShadow = true; world.add(cm);
  })();
  // Flores
  (function () {
    const beds = [[8.4, -.5, 2.2, .9], [-11.4, 5, 1.2, 2], [12.6, 6.8, 1.4, 2.4], [-10.6, -2.8, 1.2, 1.4]];
    const n = 320, im = new T.InstancedMesh(new T.SphereGeometry(.07, 8, 6), S({ roughness: .8 }), n), d = new T.Object3D(), col = new T.Color();
    const pal = [0xd2263b, 0xe0457b, 0xf2f2f2, 0xd9372a, 0xf0a3c0];
    for (let i = 0; i < n; i++) {
      const b = beds[i % beds.length];
      d.position.set(b[0] + srand(-b[2], b[2]), srand(.25, .6), b[1] + srand(-b[3], b[3])); d.scale.setScalar(srand(.7, 1.3)); d.updateMatrix(); im.setMatrixAt(i, d.matrix);
      col.setHex(pal[i % pal.length]); im.setColorAt(i, col);
    }
    im.castShadow = true; world.add(im);
  })();
  const aLawn = anchor(world, 12.2, .4, 8.4);
  edgeAO(16, -1.5, .02, -7.2, Math.PI, world, 1.2, .3);

  /* ---------- Fichas laterales ---------- */
  const features = [
    { a: aRoof, side: 'r', r: [.13, .30], k: 'Cubierta', t: 'Placas solares', d: 'Paneles fotovoltaicos integrados en la cubierta: energía limpia y menor factura.' },
    { a: aCanti, side: 'l', r: [.20, .37], k: 'Planta alta', t: 'Voladizo con terraza', d: 'Ventanales de suelo a techo y barandilla de vidrio para no perder las vistas.' },
    { a: aSmart, side: 'r', r: [.29, .45], k: 'Tecnología', t: 'Domótica integral', d: 'Clima, iluminación y persianas controlados desde el móvil, con eficiencia energética.' },
    { a: null, side: 'l', r: [.37, .55], k: 'Confort', t: 'Suelo radiante', d: 'Calor uniforme y silencioso bajo el pavimento. Sin radiadores a la vista.' },
    { a: aStone, side: 'r', r: [.45, .60], k: 'Sostenibilidad', t: 'Materiales nobles', d: 'Piedra natural, madera laminada CLT, hormigón reciclado y aislamiento de corcho.' },
    { a: aPool, side: 'l', r: [.60, .75], k: 'Exterior', t: 'Piscina con luz LED', d: 'Vaso de gresite con escalera romana, iluminación LED y tarima de madera tropical.' },
    { a: aSpa, side: 'r', r: [.68, .84], k: 'Bienestar', t: 'Jacuzzi con burbujas', d: 'Hidromasaje exterior climatizado para disfrutarlo todo el año.' },
    { a: aLawn, side: 'l', r: [.79, .92], k: 'Jardín', t: 'Césped y palmeras', d: 'Jardín de césped natural, flores, zona de tumbonas y sombra junto a la piscina.' },
  ];
  features[3].a = anchor(base, -4.8, .36, -3.0);
  const coWrap = document.getElementById('callouts'), svg = document.getElementById('lines'), NS = 'http://www.w3.org/2000/svg';
  features.forEach((f) => {
    f.el = document.createElement('div'); f.el.className = 'callout';
    f.el.innerHTML = `<small>${f.k}</small><h3>${f.t}</h3><p>${f.d}</p>`; coWrap.appendChild(f.el);
    f.line = document.createElementNS(NS, 'line'); f.halo = document.createElementNS(NS, 'circle'); f.dot = document.createElementNS(NS, 'circle');
    f.halo.setAttribute('class', 'halo'); f.dot.setAttribute('class', 'dot'); f.dot.setAttribute('r', 6);
    svg.append(f.line, f.halo, f.dot);
  });

  /* ---------- Scroll y bucle ---------- */
  const house = document.querySelector('.house');
  const heroCopy = document.getElementById('heroCopy'), outro = document.getElementById('outroCopy'), hint = document.getElementById('scrollHint'), veil = document.getElementById('veil');
  const progEl = document.getElementById('progress'), chN = document.getElementById('chapterN'), chT = document.getElementById('chapterT');
  let target = 0, p = 0, W = 1, H = 1, visible = true;
  function readScroll() {
    const r = house.getBoundingClientRect();
    target = clamp(-r.top / (house.offsetHeight - innerHeight), 0, 1);
    visible = r.bottom > 0;
  }
  addEventListener('scroll', readScroll, { passive: true });
  function resize() {
    W = canvas.clientWidth; H = canvas.clientHeight;
    renderer.setSize(W, H, false); camera.aspect = W / H; camera.updateProjectionMatrix();
    svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
  }
  addEventListener('resize', () => { resize(); readScroll(); });

  const v = new T.Vector3(), tgt = new T.Vector3(), home = new T.Vector3(-1.5, 2.4, -1.5), dummy = new T.Object3D(), clock = new T.Clock();
  function frame() {
    requestAnimationFrame(frame);
    const dt = Math.min(clock.getDelta(), .05), t = clock.elapsedTime;
    p += (target - p) * (reduce ? 1 : Math.min(1, dt * 5));
    if (!visible) return;
    const narrow = W / H < .9;

    // Despiece
    const e = ss(.12, .32, p) - ss(.58, .72, p);
    roof.position.y = 7 * e; roof.rotation.z = .03 * e;
    upper.position.y = 3.9 * e;
    gWalls.position.y = 3.6 * e;
    mat.pipe.opacity = ss(.30, .40, p) * (1 - ss(.56, .64, p));
    mat.pipe.emissiveIntensity = 1.1 + .5 * Math.sin(t * 3);
    heat.material.opacity = mat.pipe.opacity * (.18 + .08 * Math.sin(t * 2));
    inside.visible = true;

    // Agua, LED y burbujas
    shimmer.time.value = t;
    tx.waterN.offset.set(t * .012, t * .007);
    const pool = ss(.58, .70, p);
    mat.led.emissiveIntensity = .5 + pool * 3;
    poolLight.intensity = pool * 2.5;
    const boil = 1 + 3 * ss(.64, .72, p);
    bData.forEach((b, i) => {
      b.t += dt * .4 * b.s * boil; if (b.t > 1) { b.t = 0; b.a = Math.random() * 6.28; b.r = Math.sqrt(Math.random()) * 1.05; }
      dummy.position.set(Math.cos(b.a) * b.r + Math.sin(t * 4 + i) * .03, .3 + b.t * .25, Math.sin(b.a) * b.r);
      dummy.scale.setScalar((.4 + b.t) * (.7 + .5 * ss(.6, .7, p))); dummy.updateMatrix(); bubbles.setMatrixAt(i, dummy.matrix);
    });
    bubbles.instanceMatrix.needsUpdate = true;
    mat.foam.opacity = .25 + .55 * ss(.62, .72, p); foam.rotation.z = t * .15;
    palms.forEach((fr, j) => fr.forEach((f) => { f.pivot.rotation.x = f.base + Math.sin(t * 1.1 + f.ph + j) * .025; }));

    // Cámara
    const zoom = ss(.6, .78, p), back = ss(.86, 1, p);
    const ang = -.62 + p * 1.25 + (reduce ? 0 : Math.sin(t * .12) * .025);
    let R = lerp(lerp(56, 50, ss(0, .3, p)), 30, zoom); R = lerp(R, 60, back);
    let Hc = lerp(lerp(17, 15, p), 9.5, zoom); Hc = lerp(Hc, 20, back);
    if (narrow) { R *= 1.6; Hc *= 1.3; }
    const shift = narrow ? 0 : lerp(-9, 0, ss(.05, .2, p));
    tgt.set(lerp(-1.5 + shift, -1.2, zoom), lerp(2.4 + 4 * e, .6, zoom), lerp(-1.5, 6.8, zoom));
    if (narrow) tgt.y += 4.5 * (1 - ss(.05, .2, p));
    tgt.lerp(home, back);
    camera.position.set(tgt.x + Math.sin(ang) * R, Hc, tgt.z + Math.cos(ang) * R);
    camera.lookAt(tgt);
    renderer.render(scene, camera);

    // Textos
    const hk = ss(.03, .10, p);
    heroCopy.style.opacity = 1 - hk; heroCopy.style.transform = `translateY(${-60 * hk}px)`;
    if (veil) veil.style.opacity = 1 - hk;
    hint.style.opacity = 1 - ss(.01, .05, p);
    const ok = ss(.92, .98, p);
    outro.style.opacity = ok; outro.style.transform = `translateY(${30 * (1 - ok)}px)`;
    progEl.style.width = (p * 100) + '%';
    let ci = -1; features.forEach((f, i) => { if (p >= f.r[0] && p <= f.r[1]) ci = i; });
    chN.textContent = ci < 0 ? '00' : String(ci + 1).padStart(2, '0'); chT.textContent = ci < 0 ? 'La casa' : features[ci].k;

    // Fichas laterales con línea hasta el punto de la casa
    const mobile = W < 760, topSafe = 96;
    const ops = features.map((f) => ss(f.r[0], f.r[0] + .035, p) * (1 - ss(f.r[1] - .035, f.r[1], p)));
    const best = ops.indexOf(Math.max(...ops));
    features.forEach((f, i) => {
      const op = mobile && i !== best ? 0 : ops[i];
      if (op <= .001) { f.el.style.opacity = 0; f.line.style.opacity = 0; f.dot.style.opacity = 0; f.halo.style.opacity = 0; return; }
      f.a.getWorldPosition(v); v.project(camera);
      const ax = (v.x * .5 + .5) * W, ay = (-v.y * .5 + .5) * H;
      const cw = f.el.offsetWidth, chh = f.el.offsetHeight;
      let ex, ey;
      if (mobile) {
        f.el.style.left = ''; f.el.style.top = '';
        f.el.style.transform = `translateY(${(1 - op) * 24}px)`;
        const r = f.el.getBoundingClientRect(), sr = canvas.getBoundingClientRect();
        ex = clamp(ax, 24, W - 24); ey = r.top - sr.top;
      } else {
        const bottomSafe = f.side === 'r' ? 240 : 70;
        const ly = Math.max(topSafe, Math.min(ay - chh / 2, H - chh - bottomSafe));
        const lx = f.side === 'l' ? Math.max(24, W * .05) : W - Math.max(24, W * .05) - cw;
        f.el.style.left = lx + 'px'; f.el.style.top = ly + 'px';
        f.el.style.transform = `translateX(${(1 - op) * 40 * (f.side === 'l' ? -1 : 1)}px)`;
        ex = f.side === 'l' ? lx + cw : lx; ey = clamp(ay, ly + 24, ly + chh - 24);
      }
      f.el.style.opacity = op;
      const k = ss(0, 1, op);
      f.line.setAttribute('x1', ex); f.line.setAttribute('y1', ey);
      f.line.setAttribute('x2', lerp(ex, ax, k)); f.line.setAttribute('y2', lerp(ey, ay, k));
      f.line.style.opacity = mobile ? op * .7 : op;
      f.dot.setAttribute('cx', ax); f.dot.setAttribute('cy', ay); f.dot.style.opacity = op;
      const pulse = (t * .9 + i * .2) % 1;
      f.halo.setAttribute('cx', ax); f.halo.setAttribute('cy', ay); f.halo.setAttribute('r', 6 + pulse * 18); f.halo.style.opacity = op * (1 - pulse);
    });
  }
  resize(); readScroll(); frame();
})();
