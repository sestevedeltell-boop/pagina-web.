/* UNIKAL · Secuencia renderizada (Blender/Cycles) que avanza con el scroll.
   Lee assets/seq/manifest.json: { n, desktop:"d/", mobile:"m/", anchors:{ "i": { clave:[x,y,visible] } } } */
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

  let N = 1, anchors = {}, imgs = [], W = 1, H = 1, dpr = 1, target = 0, p = 0, drawnP = -1, visible = true, dirty = true, geo = null;
  const small = matchMedia('(max-width: 760px)').matches || (screen.width < 900 && devicePixelRatio <= 2);

  function resize() {
    W = canvas.clientWidth; H = canvas.clientHeight; dpr = Math.min(devicePixelRatio || 1, 2);
    canvas.width = Math.round(W * dpr); canvas.height = Math.round(H * dpr);
    svg.setAttribute('viewBox', `0 0 ${W} ${H}`); dirty = true;
  }
  // Encaje de la imagen: "cover" en pantallas apaisadas; en vertical, a lo ancho con fondo difuminado
  function fit(iw, ih) {
    const portrait = W / H < 1.05;
    const top = 76;
    if (!portrait) { const s = Math.max(W / iw, (H - top) / ih); const w = iw * s, h = ih * s; return { x: (W - w) / 2, y: top + (H - top - h) * .5, w, h, portrait }; }
    const s = Math.min(W * 1.5 / iw, H / ih); const w = iw * s, h = ih * s;
    return { x: (W - w) / 2, y: top + (H - top - h) * .32, w, h, portrait };
  }
  function readScroll() {
    const r = house.getBoundingClientRect();
    target = clamp(-r.top / (house.offsetHeight - innerHeight), 0, 1);
    visible = r.bottom > 0;
  }

  function draw() {
    const f = p * (N - 1);
    let a0 = -1, a1 = -1;
    for (let i = Math.floor(f); i >= 0; i--) if (imgs[i] && imgs[i].ok) { a0 = i; break; }
    for (let i = Math.ceil(f); i < N; i++) if (imgs[i] && imgs[i].ok) { a1 = i; break; }
    if (a0 < 0) a0 = a1; if (a1 < 0) a1 = a0; if (a0 < 0) return false;
    const k = a1 > a0 ? (f - a0) / (a1 - a0) : 0;
    const im0 = imgs[a0].img, g = fit(im0.naturalWidth, im0.naturalHeight);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    if (g.portrait) {
      ctx.fillStyle = '#dfe7ec'; ctx.fillRect(0, 0, W, H);
      ctx.save(); ctx.filter = 'blur(28px) saturate(1.1)'; const s = Math.max(W / im0.naturalWidth, H / im0.naturalHeight) * 1.1;
      ctx.drawImage(im0, (W - im0.naturalWidth * s) / 2, (H - im0.naturalHeight * s) / 2, im0.naturalWidth * s, im0.naturalHeight * s); ctx.restore();
    }
    ctx.globalAlpha = 1; ctx.drawImage(im0, g.x, g.y, g.w, g.h);
    if (a1 !== a0 && k > .01) { ctx.globalAlpha = k; ctx.drawImage(imgs[a1].img, g.x, g.y, g.w, g.h); ctx.globalAlpha = 1; }
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
    if (!visible) return;
    p += (target - p) * (reduce ? 1 : .14);
    if (Math.abs(target - p) < .0002) p = target;
    if (dirty || p !== drawnP) { const g = draw(); if (g) { geo = g; drawnP = p; dirty = false; } }
    if (geo) overlay(geo);
  }

  function load(order) {
    const dir = 'assets/seq/' + (small ? 'm/' : 'd/');
    let next = 0; const PAR = 6;
    const pump = () => {
      if (next >= order.length) return;
      const i = order[next++];
      if (imgs[i]) { pump(); return; }
      const im = new Image(); im.decoding = 'async'; imgs[i] = { img: im, ok: false };
      im.onload = () => { imgs[i].ok = true; dirty = true; if (i === 0) canvas.classList.add('ready'); pump(); };
      im.onerror = pump;
      im.src = dir + 'f' + String(i).padStart(3, '0') + '.webp';
    };
    for (let k = 0; k < PAR; k++) pump();
  }

  fetch('assets/seq/manifest.json').then((r) => r.json()).then((m) => {
    N = m.n; anchors = m.anchors; imgs = new Array(N);
    const order = [], seen = new Set();
    const have = new Set(m.have || [...Array(N).keys()]);
    [16, 8, 4, 2, 1].forEach((st) => { for (let i = 0; i < N; i += st) if (!seen.has(i) && have.has(i)) { seen.add(i); order.push(i); } });
    have.forEach((i) => { if (!seen.has(i)) { seen.add(i); order.push(i); } });
    load(order);
  });
  addEventListener('scroll', readScroll, { passive: true });
  addEventListener('resize', () => { resize(); readScroll(); });
  resize(); readScroll(); frame();
})();
