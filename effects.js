// Shared canvas & text effects — vanilla ports inspired by ReactBits (reactbits.dev)
export function decryptEl(el, opts = {}) {
  const chars = opts.chars || "!<>-_\\/[]{}=+*^?#ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
  const nodes = [];
  while (walker.nextNode()) { const n = walker.currentNode; if (n.nodeValue.trim()) nodes.push(n); }
  nodes.forEach((node, ni) => {
    const original = node.nodeValue, len = original.length;
    let frame = 0;
    const total = Math.max(14, Math.min(48, len * 2.2));
    const start = performance.now() + ni * 140;
    const step = (t) => {
      if (t < start) { requestAnimationFrame(step); return; }
      frame++;
      const revealed = Math.floor((frame / total) * len);
      let out = "";
      for (let i = 0; i < len; i++) {
        const c = original[i];
        out += (i < revealed || c === " ") ? c : chars[(Math.random() * chars.length) | 0];
      }
      node.nodeValue = out;
      if (revealed < len) requestAnimationFrame(step);
      else node.nodeValue = original;
    };
    requestAnimationFrame(step);
  });
}

export function pixelTrail(canvas, opts = {}) {
  const size = opts.size || 16, color = opts.color || "#e8551c";
  const ctx = canvas.getContext("2d");
  const parent = canvas.parentElement;
  let px = [], raf, W, H;
  const resize = () => { W = canvas.width = parent.offsetWidth; H = canvas.height = parent.offsetHeight; };
  resize();
  const onMove = (e) => {
    const r = canvas.getBoundingClientRect();
    px.push({ x: Math.floor((e.clientX - r.left) / size) * size, y: Math.floor((e.clientY - r.top) / size) * size, life: 1 });
    if (px.length > 200) px.shift();
  };
  const loop = () => {
    ctx.clearRect(0, 0, W, H);
    px.forEach(p => {
      p.life -= 0.028;
      if (p.life > 0) {
        ctx.globalAlpha = p.life * 0.45;
        ctx.fillStyle = color;
        const s = size * p.life;
        ctx.fillRect(p.x + (size - s) / 2, p.y + (size - s) / 2, s, s);
      }
    });
    px = px.filter(p => p.life > 0);
    ctx.globalAlpha = 1;
    raf = requestAnimationFrame(loop);
  };
  raf = requestAnimationFrame(loop);
  parent.addEventListener("mousemove", onMove);
  window.addEventListener("resize", resize);
  return () => { cancelAnimationFrame(raf); parent.removeEventListener("mousemove", onMove); window.removeEventListener("resize", resize); };
}

export function particles(canvas, opts = {}) {
  const count = opts.count || 55;
  const ctx = canvas.getContext("2d");
  const parent = canvas.parentElement;
  let raf, W, H, dots = [];
  const resize = () => { W = canvas.width = parent.offsetWidth; H = canvas.height = parent.offsetHeight; };
  resize();
  const mk = () => ({ x: Math.random() * W, y: Math.random() * H, r: Math.random() * 1.8 + .6, vy: -(Math.random() * .35 + .12), vx: (Math.random() - .5) * .18, o: Math.random() * .38 + .1, orange: Math.random() < .3 });
  dots = Array.from({ length: count }, mk);
  const loop = () => {
    ctx.clearRect(0, 0, W, H);
    dots.forEach(d => {
      d.x += d.vx; d.y += d.vy;
      if (d.y < -4) { d.y = H + 4; d.x = Math.random() * W; }
      if (d.x < -4) d.x = W + 4;
      if (d.x > W + 4) d.x = -4;
      ctx.globalAlpha = d.o;
      ctx.fillStyle = d.orange ? "#e8551c" : "#ece5d6";
      ctx.beginPath(); ctx.arc(d.x, d.y, d.r, 0, 6.283); ctx.fill();
    });
    ctx.globalAlpha = 1;
    raf = requestAnimationFrame(loop);
  };
  raf = requestAnimationFrame(loop);
  window.addEventListener("resize", resize);
  return () => { cancelAnimationFrame(raf); window.removeEventListener("resize", resize); };
}

export function letterGlitch(canvas, opts = {}) {
  const fs = opts.fontSize || 15;
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<>/{}[]$#&_+-=*";
  const ctx = canvas.getContext("2d");
  const parent = canvas.parentElement;
  let raf, W, H, cols, rows, grid = [], last = 0;
  const resize = () => {
    W = canvas.width = parent.offsetWidth; H = canvas.height = parent.offsetHeight;
    cols = Math.ceil(W / (fs * 0.72)); rows = Math.ceil(H / (fs * 1.25));
    grid = [];
    for (let i = 0; i < cols * rows; i++) grid.push({ c: chars[(Math.random() * chars.length) | 0], o: Math.random() * .12 + .03, orange: Math.random() < .06 });
  };
  resize();
  const draw = (t) => {
    if (t - last > 90) {
      last = t;
      for (let k = 0; k < grid.length * 0.04; k++) {
        const i = (Math.random() * grid.length) | 0;
        grid[i].c = chars[(Math.random() * chars.length) | 0];
        grid[i].o = Math.random() * .14 + .03;
        grid[i].orange = Math.random() < .06;
      }
      ctx.clearRect(0, 0, W, H);
      ctx.font = "500 " + fs + "px 'JetBrains Mono', monospace";
      for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
        const g = grid[r * cols + c];
        if (!g) continue;
        ctx.globalAlpha = g.o;
        ctx.fillStyle = g.orange ? "#e8551c" : "#ece5d6";
        ctx.fillText(g.c, c * fs * 0.72, r * fs * 1.25 + fs);
      }
      ctx.globalAlpha = 1;
    }
    raf = requestAnimationFrame(draw);
  };
  raf = requestAnimationFrame(draw);
  window.addEventListener("resize", resize);
  return () => { cancelAnimationFrame(raf); window.removeEventListener("resize", resize); };
}
