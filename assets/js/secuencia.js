/* UNIKAL · Secuencia renderizada (Blender/Cycles) que avanza con el scroll.
   assets/seq/manifest.json: { n, ch, have, d:[[off,len]|null…], m:[…], p:[…], anchors:{ "i": { clave:[x,y,visible] } } }
   Los fotogramas van empaquetados en bloques (d/cNN.webp a 1080p, m/cNN.webp para móvil) y en una vista previa
   ligera de toda la secuencia (p.webp). Los bloques se descargan por prioridad alrededor de la posición del scroll
   y solo se mantienen decodificados los fotogramas cercanos, para no agotar la memoria del móvil. */
(function () {
  const canvas = document.getElementById('scene');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
  const lerp = (a, b, t) => a + (b - a) * t;
  const ss = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };

  const house = document.querySelector('.house');
  const heroCopy = document.getElementById('heroCopy'), outro = document.getElementById('outroCopy'), hint = document.getElementById('scrollHint'), veil = document.getElementById('veil');
  const progEl = document.getElementById('progress'), chN = document.getElementById('chapterN'), chT = document.getElementById('chapterT');
  const coWrap = document.getElementById('callouts'), svg = document.getElementById('lines'), NS = 'http://www.w3.org/2000/svg';

  const features = [
    { a: 'roof', side: 'r', r: [.13, .30], k: 'Cubierta', t: 'Placas solares', d: 'Paneles fotovoltaicos integrados en la cubierta: energía limpia y menor factura.' },
    { a: 'canti', side: 'l', r: [.20, .37], k: 'Planta alta', t: 'Voladizo con terraza', d: 'Ventanales de suelo a techo y barandilla de vidrio para no perder las vistas.' },
    { a: 'smart', side: 'r', r: [.29, .45], k: 'Tecnología', t: 'Domótica integral', d: 'Clima, iluminación y persianas controlados desde el móvil, con eficiencia energética.' },
    { a: 'radiant', side: 'l', r: [.37, .55], k: 'Confort', t: 'Suelo radiante', d: 'Calor uniforme y silencioso bajo el pavimento. Sin radiadores a la vista.' },
    { a: 'stone', side: 'r', r: [.45, .60], k: 'Sostenibilidad', t: 'Materiales nobles', d: 'Piedra natural, madera laminada CLT, hormigón reciclado y aislamiento de corcho.' },
    { a: 'pool', side: 'r', r: [.61, .76], k: 'Exterior', t: 'Piscina con luz LED', d: 'Vaso de gresite con escalera romana, iluminación LED y tarima de madera tropical.' },
    { a: 'spa', side: 'l', r: [.70, .85], k: 'Bienestar', t: 'Jacuzzi con burbujas', d: 'Hidromasaje exterior climatizado para disfrutarlo todo el año.' },
    { a: 'lawn', side: 'r', r: [.83, .95], k: 'Jardín', t: 'Césped y palmeras', d: 'Césped natural, flores, zona de tumbonas y sombra junto a la piscina.' },
  ];
  features.forEach((f) => {
    f.el = document.createElement('div'); f.el.className = 'callout';
    f.el.innerHTML = `<small>${f.k}</small><h3>${f.t}</h3><p>${f.d}</p>`; coWrap.appendChild(f.el);
    f.line = document.createElementNS(NS, 'line'); f.halo = document.createElementNS(NS, 'circle'); f.dot = document.createElementNS(NS, 'circle');
    f.halo.setAttribute('class', 'halo'); f.dot.setAttribute('class', 'dot'); f.dot.setAttribute('r', 6);
    svg.append(f.line, f.halo, f.dot);
  });

  const small = matchMedia('(max-width: 760px)').matches || (screen.width < 900 && devicePixelRatio <= 2);
  // Full HD en todos los dispositivos; la versión ligera (960×540) solo en móviles con poca memoria o ahorro de datos.
  // Con #hd en la dirección se fuerza siempre la Full HD.
  const conn = navigator.connection || {};
  const lite = small && location.hash !== '#hd' && !!(conn.saveData || (navigator.deviceMemory || 8) < 4);
  const TIER = lite ? 'm' : 'd';
  const HI_MAX = lite ? 30 : small ? 12 : 18;   // fotogramas nítidos decodificados a la vez (cada Full HD ocupa ~8 MB)
  const LO_MAX = 60;                // fotogramas de vista previa decodificados a la vez
  const PAR_DECODE = 3, PAR_FETCH = 2;

  let man = null, N = 1, CH = 12, anchors = {};
  let W = 1, H = 1, dpr = 1, target = 0, p = 0, drawnP = -1, dirIdx = 1, visible = true, dirty = true, geo = null, shown = false;
  const hiBlob = [], loBlob = [], hiBmp = new Map(), loBmp = new Map(), pend = new Set(), chunkState = [];
  let decoding = 0, fetching = 0;

  const toBitmap = window.createImageBitmap
    ? (b) => createImageBitmap(b)
    : (b) => new Promise((res, rej) => { const im = new Image(); im.onload = () => res(im); im.onerror = rej; im.src = URL.createObjectURL(b); });

  function resize() {
    W = canvas.clientWidth; H = canvas.clientHeight; dpr = Math.min(devicePixelRatio || 1, lite ? 1.5 : small ? 3 : 2);
    canvas.width = Math.round(W * dpr); canvas.height = Math.round(H * dpr);
    svg.setAttribute('viewBox', `0 0 ${W} ${H}`); dirty = true;
  }
  // Encaje de la imagen 16:9: "cover" en pantallas apaisadas; en vertical, franja ancha con fondo difuminado (CSS)
  function fit() {
    const iw = 16, ih = 9, portrait = W / H < 1.05, top = 76;
    if (!portrait) { const s = Math.max(W / iw, (H - top) / ih); const w = iw * s, h = ih * s; return { x: (W - w) / 2, y: top + (H - top - h) * .5, w, h, portrait }; }
    const s = Math.min(W * 1.5 / iw, H / ih); const w = iw * s, h = ih * s;
    return { x: (W - w) / 2, y: top + (H - top - h) * .32, w, h, portrait };
  }
  function readScroll() {
    const r = house.getBoundingClientRect();
    target = clamp(-r.top / (house.offsetHeight - innerHeight), 0, 1);
    visible = r.bottom > 0;
  }

  /* ---------- Caché de fotogramas decodificados (LRU) ---------- */
  function touch(map, i) { const b = map.get(i); map.delete(i); map.set(i, b); return b; }
  function trim(map, max, keep) {
    for (const k of map.keys()) {
      if (map.size <= max) break;
      if (Math.abs(k - keep) <= 2) continue;
      const b = map.get(k); map.delete(k); if (b && b.close) b.close();
    }
  }
  function decode(kind, i) {
    const map = kind === 'h' ? hiBmp : loBmp, src = kind === 'h' ? hiBlob : loBlob, key = kind + i;
    if (i < 0 || i >= N || map.has(i) || pend.has(key) || !src[i] || decoding >= PAR_DECODE) return;
    pend.add(key); decoding++;
    toBitmap(src[i]).then((bm) => {
      map.set(i, bm); trim(map, kind === 'h' ? HI_MAX : LO_MAX, Math.round(p * (N - 1))); dirty = true;
    }).catch(() => {}).finally(() => { pend.delete(key); decoding--; });
  }
  function schedule() {
    const i = Math.round(p * (N - 1)), d = dirIdx;
    for (const o of [0, d, 2 * d, -d, 3 * d, 4 * d, -2 * d, 5 * d, 6 * d]) if (!hiBmp.has(i + o)) decode('h', i + o);
    for (const o of [0, d, -d, 2 * d, 3 * d]) if (!hiBmp.has(i + o) && !loBmp.has(i + o)) decode('l', i + o);
  }
  function nearest(map, i, maxd) {
    for (let k = 0; k <= maxd; k++) { if (map.has(i - k)) return i - k; if (map.has(i + k)) return i + k; }
    return -1;
  }

  /* ---------- Descarga por bloques, priorizando lo que viene por delante ---------- */
  function chunkHasFrames(c) {
    for (let i = c * CH; i < Math.min(N, (c + 1) * CH); i++) if (man[TIER][i]) return true;
    return false;
  }
  function fetchChunk(c) {
    chunkState[c] = 1; fetching++;
    fetch(`assets/seq/${TIER}/c${String(c).padStart(2, '0')}.webp`)
      .then((r) => { if (!r.ok) throw new Error(r.status); return r.arrayBuffer(); })
      .then((buf) => {
        for (let i = c * CH; i < Math.min(N, (c + 1) * CH); i++) {
          const e = man[TIER][i]; if (e) hiBlob[i] = new Blob([new Uint8Array(buf, e[0], e[1])], { type: 'image/webp' });
        }
        chunkState[c] = 2; dirty = true;
      })
      .catch(() => { chunkState[c] = 3; })
      .finally(() => { fetching--; pumpChunks(); });
  }
  function pumpChunks() {
    if (!man) return;
    const nc = Math.ceil(N / CH), c0 = Math.floor(Math.round(target * (N - 1)) / CH);
    while (fetching < PAR_FETCH) {
      let best = -1, bestScore = Infinity;
      for (let c = 0; c < nc; c++) {
        if (chunkState[c]) continue;
        if (!chunkHasFrames(c)) { chunkState[c] = 2; continue; }
        const k = c - c0, score = k >= 0 ? k : -k * 1.6;
        if (score < bestScore) { bestScore = score; best = c; }
      }
      if (best < 0) return;
      fetchChunk(best);
    }
  }
  function loadPreview() {
    fetch('assets/seq/p.webp').then((r) => r.arrayBuffer()).then((buf) => {
      for (let i = 0; i < N; i++) { const e = man.p[i]; if (e) loBlob[i] = new Blob([new Uint8Array(buf, e[0], e[1])], { type: 'image/webp' }); }
      dirty = true;
    }).catch(() => {});
  }

  /* ---------- Dibujo ---------- */
  function draw() {
    const i = Math.round(p * (N - 1));
    let bm = null, j;
    if (hiBmp.has(i)) bm = touch(hiBmp, i);
    else if ((j = nearest(hiBmp, i, 1)) >= 0) bm = touch(hiBmp, j);
    else if ((j = nearest(loBmp, i, 1)) >= 0) bm = touch(loBmp, j);
    else if ((j = nearest(hiBmp, i, N)) >= 0) bm = touch(hiBmp, j);
    else if ((j = nearest(loBmp, i, N)) >= 0) bm = touch(loBmp, j);
    if (!bm) return null;
    const g = fit();
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, W, H);
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(bm, g.x, g.y, g.w, g.h);
    if (!shown) { shown = true; canvas.classList.add('ready'); }
    return g;
  }
  function anchorAt(key, f) {
    const i0 = Math.floor(f), i1 = Math.min(N - 1, i0 + 1), k = f - i0;
    const A = anchors[i0] && anchors[i0][key], B = anchors[i1] && anchors[i1][key];
    if (!A) return null; if (!B) return A;
    return [lerp(A[0], B[0], k), lerp(A[1], B[1], k), A[2] && B[2]];
  }

  function overlay(g) {
    const hk = ss(.03, .10, p);
    heroCopy.style.opacity = 1 - hk; heroCopy.style.transform = `translateY(${-60 * hk}px)`;
    if (veil) veil.style.opacity = 1 - hk;
    hint.style.opacity = 1 - ss(.01, .05, p);
    const ok = ss(.93, .99, p); outro.style.opacity = ok; outro.style.transform = `translateY(${30 * (1 - ok)}px)`;
    progEl.style.width = (p * 100) + '%';
    let ci = -1; features.forEach((f, i) => { if (p >= f.r[0] && p <= f.r[1]) ci = i; });
    chN.textContent = ci < 0 ? '00' : String(ci + 1).padStart(2, '0'); chT.textContent = ci < 0 ? 'La casa' : features[ci].k;

    const mobile = W < 760, topSafe = 96, fr = p * (N - 1);
    const ops = features.map((f) => ss(f.r[0], f.r[0] + .035, p) * (1 - ss(f.r[1] - .035, f.r[1], p)));
    const best = ops.indexOf(Math.max(...ops));
    features.forEach((f, i) => {
      const an = anchorAt(f.a, fr);
      const inView = an && an[2] && an[0] > .02 && an[0] < .98 && an[1] > .04 && an[1] < .97;
      const op = (mobile && i !== best) || !inView ? 0 : ops[i];
      if (op <= .001) { f.el.style.opacity = 0; f.line.style.opacity = 0; f.dot.style.opacity = 0; f.halo.style.opacity = 0; return; }
      const ax = g.x + an[0] * g.w, ay = g.y + an[1] * g.h;
      const cw = f.el.offsetWidth, chh = f.el.offsetHeight;
      let ex, ey;
      if (mobile) {
        f.el.style.left = ''; f.el.style.top = ''; f.el.style.transform = `translateY(${(1 - op) * 24}px)`;
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
      const kk = ss(0, 1, op);
      f.line.setAttribute('x1', ex); f.line.setAttribute('y1', ey);
      f.line.setAttribute('x2', lerp(ex, ax, kk)); f.line.setAttribute('y2', lerp(ey, ay, kk));
      f.line.style.opacity = mobile ? op * .7 : op;
      f.dot.setAttribute('cx', ax); f.dot.setAttribute('cy', ay); f.dot.style.opacity = op;
      f.halo.setAttribute('cx', ax); f.halo.setAttribute('cy', ay);
      const pulse = (performance.now() / 1100 + i * .2) % 1;
      f.halo.setAttribute('r', 6 + pulse * 18); f.halo.style.opacity = op * (1 - pulse);
    });
  }

  function frame() {
    requestAnimationFrame(frame);
    if (!visible || !man) return;
    if (target > p + 1e-4) dirIdx = 1; else if (target < p - 1e-4) dirIdx = -1;
    p += (target - p) * (reduce ? 1 : .18);
    if (Math.abs(target - p) < .0002) p = target;
    schedule();
    if (dirty || p !== drawnP) { const g = draw(); if (g) { geo = g; drawnP = p; dirty = false; } }
    if (geo) overlay(geo);
  }

  // La secuencia se pide cuando la página ya ha terminado de cargar, para que abra al instante
  const pageLoaded = new Promise((res) => (document.readyState === 'complete' ? res() : addEventListener('load', res, { once: true })));
  Promise.all([fetch('assets/seq/manifest.json').then((r) => r.json()), pageLoaded]).then(([m]) => {
    man = m; N = m.n; CH = m.ch || 12; anchors = m.anchors; readScroll();
    loadPreview();
    pumpChunks();
  }).catch(() => {});
  addEventListener('scroll', () => { readScroll(); pumpChunks(); }, { passive: true });
  addEventListener('resize', () => { resize(); readScroll(); });
  resize(); readScroll(); frame();
})();
