/* ============================================================================
 * materials.js — PROCEDURAL MATERIAL KIT for the dusk gnome-village scene
 * ----------------------------------------------------------------------------
 * three.js r128, GLOBAL THREE, classic build. NO modules / loaders / image files.
 * Every texture is generated with the Canvas 2D API and wrapped in
 * THREE.CanvasTexture. Each material gets a procedural COLOR map + grayscale
 * bumpMap. Textures + materials are CACHED so repeated calls SHARE GPU resources.
 *
 * LOADS AS A PLAIN <script> BEFORE gnome.js / buildsite.js / zone.js.
 * It publishes two globals the other modules consume:
 *
 *   window.GnomeMat                       // the kit instance (built once)
 *   window.texturedMat(colorHex, kind, opts) -> THREE.MeshStandardMaterial
 *
 * Because gnome.js / buildsite.js / zone.js are separate <script> tags (separate
 * scopes), their local mat()/M()/ZONE_mat helpers can't see the host's inline
 * mat() closure. The fix: those helpers are re-pointed at the GLOBAL texturedMat
 * (see *-edits in the integration map). texturedMat is defined here so it exists
 * before any of them run.
 *
 * KINDS: skin beard felt fabric linen wool leather metal wood plank stone
 *        cobble thatch plaster leaf petal soil moss
 *
 * COLOR CORRECTNESS (r128):
 *   - color maps  -> texture.encoding = THREE.sRGBEncoding   (gamma-correct albedo)
 *   - bump maps   -> stay LINEAR (NEVER sRGB; they're height data, not color)
 *   - all maps    -> wrapS = wrapT = RepeatWrapping, sensible per-kind .repeat
 * ==========================================================================*/
function makeGnomeMat() {

  /* ---------------- tiny deterministic PRNG (stable textures) ---------------- */
  function mulberry32(a) {
    return function () {
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      var t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  /* ---------------- color helpers ---------------- */
  function hexRGB(hex) { return { r: (hex >> 16) & 255, g: (hex >> 8) & 255, b: hex & 255 }; }
  function cssRGB(r, g, b) { return 'rgb(' + (r | 0) + ',' + (g | 0) + ',' + (b | 0) + ')'; }
  function clamp255(v) { return v < 0 ? 0 : v > 255 ? 255 : v; }
  function shade(rgb, f) { return { r: clamp255(rgb.r * f), g: clamp255(rgb.g * f), b: clamp255(rgb.b * f) }; }
  function mix(a, b, t) {
    return { r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t, b: a.b + (b.b - a.b) * t };
  }

  /* ---------------- canvas factory ---------------- */
  function makeCanvas(size) {
    var c = document.createElement('canvas');
    c.width = c.height = size;
    return c;
  }

  /* Wrap a canvas as a tiling color texture (sRGB). */
  function colorTex(canvas, repU, repV) {
    var t = new THREE.CanvasTexture(canvas);
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.repeat.set(repU, repV);
    if ('encoding' in t) t.encoding = THREE.sRGBEncoding;   // COLOR map -> sRGB
    t.anisotropy = 4;
    t.needsUpdate = true;
    return t;
  }
  /* Wrap a grayscale canvas as a tiling bump texture (LINEAR — never sRGB). */
  function bumpTex(canvas, repU, repV) {
    var t = new THREE.CanvasTexture(canvas);
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.repeat.set(repU, repV);
    // NOTE: deliberately leave encoding at default LinearEncoding for height data
    t.anisotropy = 2;
    t.needsUpdate = true;
    return t;
  }

  /* ============================================================================
   * TEXTURE GENERATORS — each returns { color:<canvas>, bump:<canvas> }
   * tinted toward `base` (an {r,g,b}). Fixed seed per kind for stable, seamless-ish
   * tiles. (Canvases left as-is when a generator paints to the edges; tiling
   * artifacts are masked by the modest per-kind repeat counts + bump-only relief.)
   * ==========================================================================*/
  function newPair(size) {
    var col = makeCanvas(size), bmp = makeCanvas(size);
    return { col: col, cx: col.getContext('2d'), bmp: bmp, bx: bmp.getContext('2d') };
  }
  function bumpFill(bx, size, v) { bx.fillStyle = cssRGB(v, v, v); bx.fillRect(0, 0, size, size); }

  /* --- SKIN: soft waxy tone, faint pores, gentle mottling --- */
  function genSkin(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(11);
    p.cx.fillStyle = cssRGB(base.r, base.g, base.b); p.cx.fillRect(0, 0, S, S);
    bumpFill(p.bx, S, 128);
    for (var i = 0; i < 70; i++) {
      var x = rnd() * S, y = rnd() * S, r = 6 + rnd() * 22;
      var c = rnd() > 0.5 ? shade(base, 1.06) : shade(base, 0.93);
      var g = p.cx.createRadialGradient(x, y, 0, x, y, r);
      g.addColorStop(0, 'rgba(' + (c.r | 0) + ',' + (c.g | 0) + ',' + (c.b | 0) + ',0.10)');
      g.addColorStop(1, 'rgba(0,0,0,0)');
      p.cx.fillStyle = g; p.cx.beginPath(); p.cx.arc(x, y, r, 0, 6.283); p.cx.fill();
    }
    for (var k = 0; k < 900; k++) {
      var px = rnd() * S, py = rnd() * S, pr = 0.4 + rnd() * 0.7;
      p.cx.fillStyle = 'rgba(60,40,30,0.05)';
      p.cx.beginPath(); p.cx.arc(px, py, pr, 0, 6.283); p.cx.fill();
      var bv = 120 + rnd() * 16;
      p.bx.fillStyle = cssRGB(bv, bv, bv);
      p.bx.beginPath(); p.bx.arc(px, py, pr, 0, 6.283); p.bx.fill();
    }
    return { color: p.col, bump: p.bmp };
  }

  /* --- BEARD: fine soft strand lines flowing downward --- */
  function genBeard(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(23);
    p.cx.fillStyle = cssRGB(base.r, base.g, base.b); p.cx.fillRect(0, 0, S, S);
    bumpFill(p.bx, S, 120);
    var light = shade(base, 1.12), dark = shade(base, 0.82);
    for (var i = 0; i < 240; i++) {
      var x = rnd() * S, len = 16 + rnd() * 46, sway = (rnd() - 0.5) * 10;
      var tone = mix(dark, light, rnd()), w = 0.5 + rnd() * 1.1;
      p.cx.strokeStyle = cssRGB(tone.r, tone.g, tone.b);
      p.cx.lineWidth = w; p.cx.lineCap = 'round';
      p.cx.beginPath(); p.cx.moveTo(x, 0);
      p.cx.quadraticCurveTo(x + sway * 0.5, len * 0.5, x + sway, len); p.cx.stroke();
      var bv = 120 + (rnd() * 60 - 10);
      p.bx.strokeStyle = cssRGB(bv, bv, bv);
      p.bx.lineWidth = w; p.bx.lineCap = 'round';
      p.bx.beginPath(); p.bx.moveTo(x, 0);
      p.bx.quadraticCurveTo(x + sway * 0.5, len * 0.5, x + sway, len); p.bx.stroke();
    }
    return { color: p.col, bump: p.bmp };
  }

  /* --- FELT: matte wool-felt fuzz, dense fiber speckle --- */
  function genFelt(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(37);
    p.cx.fillStyle = cssRGB(base.r, base.g, base.b); p.cx.fillRect(0, 0, S, S);
    bumpFill(p.bx, S, 128);
    for (var i = 0; i < 5200; i++) {
      var x = rnd() * S, y = rnd() * S, a = rnd() * 6.283, l = 1 + rnd() * 2.4;
      var c = shade(base, 0.88 + rnd() * 0.26);
      p.cx.strokeStyle = 'rgba(' + (c.r | 0) + ',' + (c.g | 0) + ',' + (c.b | 0) + ',0.5)';
      p.cx.lineWidth = 0.7;
      p.cx.beginPath(); p.cx.moveTo(x, y); p.cx.lineTo(x + Math.cos(a) * l, y + Math.sin(a) * l); p.cx.stroke();
      var bv = 118 + rnd() * 22;
      p.bx.strokeStyle = 'rgba(' + (bv | 0) + ',' + (bv | 0) + ',' + (bv | 0) + ',0.5)';
      p.bx.lineWidth = 0.7;
      p.bx.beginPath(); p.bx.moveTo(x, y); p.bx.lineTo(x + Math.cos(a) * l, y + Math.sin(a) * l); p.bx.stroke();
    }
    return { color: p.col, bump: p.bmp };
  }

  /* --- FABRIC: visible woven warp/weft (tunic/jerkin), warm matte --- */
  function genFabric(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(41);
    p.cx.fillStyle = cssRGB(base.r, base.g, base.b); p.cx.fillRect(0, 0, S, S);
    bumpFill(p.bx, S, 128);
    var step = 8, tw = 4;
    var light = shade(base, 1.12), dark = shade(base, 0.80);
    for (var x = 0; x < S; x += step) {
      var lc = mix(dark, light, 0.7);
      p.cx.fillStyle = cssRGB(lc.r, lc.g, lc.b); p.cx.fillRect(x, 0, tw, S);
      p.bx.fillStyle = cssRGB(180, 180, 180); p.bx.fillRect(x, 0, tw, S);
    }
    for (var y = 0; y < S; y += step) {
      for (var xx = 0; xx < S; xx += step) {
        var over = (((xx / step) + (y / step)) & 1) === 0;
        var c = over ? light : dark;
        p.cx.fillStyle = cssRGB(c.r, c.g, c.b);
        p.cx.fillRect(xx + (over ? tw : 0), y, tw, tw);
        var bv = over ? 195 : 110;
        p.bx.fillStyle = cssRGB(bv, bv, bv);
        p.bx.fillRect(xx + (over ? tw : 0), y, tw, tw);
      }
    }
    for (var i = 0; i < 500; i++) {
      var sx = rnd() * S, sy = rnd() * S;
      var s = shade(base, 0.85 + rnd() * 0.3);
      p.cx.fillStyle = 'rgba(' + (s.r | 0) + ',' + (s.g | 0) + ',' + (s.b | 0) + ',0.18)';
      p.cx.fillRect(sx, sy, 1.4, 1.4);
    }
    return { color: p.col, bump: p.bmp };
  }

  /* --- LINEN: fine plain-weave, lighter & airier than fabric --- */
  function genLinen(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(53);
    p.cx.fillStyle = cssRGB(base.r, base.g, base.b); p.cx.fillRect(0, 0, S, S);
    bumpFill(p.bx, S, 132);
    var step = 4, light = shade(base, 1.07), dark = shade(base, 0.90);
    for (var y = 0; y < S; y += step) {
      for (var x = 0; x < S; x += step) {
        var over = (((x / step) + (y / step)) & 1) === 0;
        var c = over ? light : dark;
        p.cx.fillStyle = 'rgba(' + (c.r | 0) + ',' + (c.g | 0) + ',' + (c.b | 0) + ',0.6)';
        p.cx.fillRect(x, y, step, step);
        var bv = over ? 150 : 118;
        p.bx.fillStyle = cssRGB(bv, bv, bv); p.bx.fillRect(x, y, step, step);
      }
    }
    for (var i = 0; i < 700; i++) {
      var fx = rnd() * S, fy = rnd() * S, fl = 1 + rnd() * 4;
      var s = shade(base, 0.86 + rnd() * 0.26);
      p.cx.strokeStyle = 'rgba(' + (s.r | 0) + ',' + (s.g | 0) + ',' + (s.b | 0) + ',0.22)';
      p.cx.lineWidth = 0.8;
      p.cx.beginPath(); p.cx.moveTo(fx, fy); p.cx.lineTo(fx + fl, fy + (rnd() - 0.5)); p.cx.stroke();
    }
    return { color: p.col, bump: p.bmp };
  }

  /* --- WOOL: soft knit V-stitches + heather flecks --- */
  function genWool(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(67);
    p.cx.fillStyle = cssRGB(base.r, base.g, base.b); p.cx.fillRect(0, 0, S, S);
    bumpFill(p.bx, S, 124);
    var light = shade(base, 1.1), dark = shade(base, 0.82), col = 10, rowH = 9;
    for (var ry = 0; ry < S + rowH; ry += rowH) {
      for (var cx2 = 0; cx2 < S + col; cx2 += col) {
        var off = ((ry / rowH) & 1) ? col * 0.5 : 0;
        var x0 = cx2 + off, tone = mix(dark, light, 0.4 + rnd() * 0.5);
        p.cx.strokeStyle = cssRGB(tone.r, tone.g, tone.b);
        p.cx.lineWidth = 2.4; p.cx.lineCap = 'round';
        p.cx.beginPath(); p.cx.moveTo(x0, ry);
        p.cx.lineTo(x0 + col * 0.5, ry + rowH * 0.7); p.cx.lineTo(x0 + col, ry); p.cx.stroke();
        p.bx.strokeStyle = cssRGB(170, 170, 170);
        p.bx.lineWidth = 2.4; p.bx.lineCap = 'round';
        p.bx.beginPath(); p.bx.moveTo(x0, ry);
        p.bx.lineTo(x0 + col * 0.5, ry + rowH * 0.7); p.bx.lineTo(x0 + col, ry); p.bx.stroke();
      }
    }
    for (var i = 0; i < 600; i++) {
      var fx = rnd() * S, fy = rnd() * S;
      var hue = rnd() > 0.5 ? shade(base, 1.3) : shade(base, 0.6);
      p.cx.fillStyle = 'rgba(' + (hue.r | 0) + ',' + (hue.g | 0) + ',' + (hue.b | 0) + ',0.25)';
      p.cx.beginPath(); p.cx.arc(fx, fy, 0.7, 0, 6.283); p.cx.fill();
    }
    return { color: p.col, bump: p.bmp };
  }

  /* --- LEATHER: grain pebbling + creases, low sheen --- */
  function genLeather(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(83);
    p.cx.fillStyle = cssRGB(base.r, base.g, base.b); p.cx.fillRect(0, 0, S, S);
    bumpFill(p.bx, S, 128);
    for (var i = 0; i < 1600; i++) {
      var x = rnd() * S, y = rnd() * S, r = 1 + rnd() * 2.6;
      var c = shade(base, 0.82 + rnd() * 0.34);
      p.cx.fillStyle = 'rgba(' + (c.r | 0) + ',' + (c.g | 0) + ',' + (c.b | 0) + ',0.30)';
      p.cx.beginPath(); p.cx.arc(x, y, r, 0, 6.283); p.cx.fill();
      var bv = 100 + rnd() * 56;
      p.bx.fillStyle = 'rgba(' + (bv | 0) + ',' + (bv | 0) + ',' + (bv | 0) + ',0.5)';
      p.bx.beginPath(); p.bx.arc(x, y, r, 0, 6.283); p.bx.fill();
    }
    for (var k = 0; k < 12; k++) {
      var sx = rnd() * S, sy = rnd() * S, ex = sx + (rnd() - 0.5) * 70, ey = sy + (rnd() - 0.5) * 70;
      var d = shade(base, 0.7);
      p.cx.strokeStyle = 'rgba(' + (d.r | 0) + ',' + (d.g | 0) + ',' + (d.b | 0) + ',0.4)';
      p.cx.lineWidth = 1 + rnd();
      p.cx.beginPath(); p.cx.moveTo(sx, sy);
      p.cx.quadraticCurveTo((sx + ex) / 2 + (rnd() - 0.5) * 20, (sy + ey) / 2, ex, ey); p.cx.stroke();
      p.bx.strokeStyle = 'rgba(70,70,70,0.6)';
      p.bx.lineWidth = 1 + rnd();
      p.bx.beginPath(); p.bx.moveTo(sx, sy);
      p.bx.quadraticCurveTo((sx + ex) / 2 + (rnd() - 0.5) * 20, (sy + ey) / 2, ex, ey); p.bx.stroke();
    }
    return { color: p.col, bump: p.bmp };
  }

  /* --- METAL: brushed brass with anisotropic horizontal streaks --- */
  function genMetal(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(97);
    p.cx.fillStyle = cssRGB(base.r, base.g, base.b); p.cx.fillRect(0, 0, S, S);
    bumpFill(p.bx, S, 130);
    for (var i = 0; i < 2600; i++) {
      var y = rnd() * S, x = rnd() * S, len = 8 + rnd() * 40;
      var c = shade(base, 0.7 + rnd() * 0.6);
      p.cx.strokeStyle = 'rgba(' + (c.r | 0) + ',' + (c.g | 0) + ',' + (c.b | 0) + ',0.22)';
      p.cx.lineWidth = 0.6;
      p.cx.beginPath(); p.cx.moveTo(x, y); p.cx.lineTo(x + len, y + (rnd() - 0.5) * 0.6); p.cx.stroke();
      var bv = 120 + (rnd() * 24 - 12);
      p.bx.strokeStyle = 'rgba(' + (bv | 0) + ',' + (bv | 0) + ',' + (bv | 0) + ',0.3)';
      p.bx.lineWidth = 0.6;
      p.bx.beginPath(); p.bx.moveTo(x, y); p.bx.lineTo(x + len, y); p.bx.stroke();
    }
    var g = p.cx.createLinearGradient(0, 0, 0, S);
    g.addColorStop(0, 'rgba(255,255,255,0.0)');
    g.addColorStop(0.45, 'rgba(255,255,255,0.16)');
    g.addColorStop(0.55, 'rgba(255,255,255,0.16)');
    g.addColorStop(1, 'rgba(255,255,255,0.0)');
    p.cx.fillStyle = g; p.cx.fillRect(0, 0, S, S);
    return { color: p.col, bump: p.bmp };
  }

  /* --- WOOD (logs / round walls): grain rings + streaks --- */
  function genWood(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(109);
    var light = shade(base, 1.12), dark = shade(base, 0.74);
    for (var x = 0; x < S; x++) {
      var n = 0.5 + 0.5 * Math.sin(x * 0.18 + Math.sin(x * 0.05) * 2);
      var c = mix(dark, light, n * 0.6 + 0.2);
      p.cx.fillStyle = cssRGB(c.r, c.g, c.b); p.cx.fillRect(x, 0, 1, S);
      var bv = 110 + n * 40;
      p.bx.fillStyle = cssRGB(bv, bv, bv); p.bx.fillRect(x, 0, 1, S);
    }
    for (var i = 0; i < 60; i++) {
      var gx = rnd() * S, w = 0.5 + rnd() * 1.6;
      var d = shade(base, 0.6 + rnd() * 0.2);
      p.cx.strokeStyle = 'rgba(' + (d.r | 0) + ',' + (d.g | 0) + ',' + (d.b | 0) + ',0.35)';
      p.cx.lineWidth = w;
      p.cx.beginPath(); p.cx.moveTo(gx, 0);
      p.cx.bezierCurveTo(gx + (rnd() - 0.5) * 8, S * 0.33, gx + (rnd() - 0.5) * 8, S * 0.66, gx + (rnd() - 0.5) * 6, S);
      p.cx.stroke();
      p.bx.strokeStyle = 'rgba(90,90,90,0.4)';
      p.bx.lineWidth = w;
      p.bx.beginPath(); p.bx.moveTo(gx, 0);
      p.bx.bezierCurveTo(gx + (rnd() - 0.5) * 8, S * 0.33, gx + (rnd() - 0.5) * 8, S * 0.66, gx + (rnd() - 0.5) * 6, S);
      p.bx.stroke();
    }
    for (var k = 0; k < 3; k++) {
      var kx = rnd() * S, ky = rnd() * S, kr = 3 + rnd() * 5;
      var d2 = shade(base, 0.5);
      var rg = p.cx.createRadialGradient(kx, ky, 0, kx, ky, kr);
      rg.addColorStop(0, 'rgba(' + (d2.r | 0) + ',' + (d2.g | 0) + ',' + (d2.b | 0) + ',0.6)');
      rg.addColorStop(1, 'rgba(0,0,0,0)');
      p.cx.fillStyle = rg; p.cx.beginPath(); p.cx.arc(kx, ky, kr, 0, 6.283); p.cx.fill();
    }
    return { color: p.col, bump: p.bmp };
  }

  /* --- PLANK: sawn boards — long grain + horizontal seams --- */
  function genPlank(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(127);
    var light = shade(base, 1.1), dark = shade(base, 0.78);
    var boards = 4, bw = S / boards;
    for (var b = 0; b < boards; b++) {
      var by = b * bw;
      var boardTone = mix(dark, light, 0.35 + rnd() * 0.4);
      p.cx.fillStyle = cssRGB(boardTone.r, boardTone.g, boardTone.b); p.cx.fillRect(0, by, S, bw);
      p.bx.fillStyle = cssRGB(150, 150, 150); p.bx.fillRect(0, by, S, bw);
      for (var i = 0; i < 26; i++) {
        var gy = by + rnd() * bw;
        var d = shade(base, 0.7 + rnd() * 0.25);
        p.cx.strokeStyle = 'rgba(' + (d.r | 0) + ',' + (d.g | 0) + ',' + (d.b | 0) + ',0.3)';
        p.cx.lineWidth = 0.5 + rnd();
        p.cx.beginPath(); p.cx.moveTo(0, gy);
        p.cx.bezierCurveTo(S * 0.33, gy + (rnd() - 0.5) * 3, S * 0.66, gy + (rnd() - 0.5) * 3, S, gy);
        p.cx.stroke();
      }
      p.cx.fillStyle = 'rgba(0,0,0,0.45)'; p.cx.fillRect(0, by, S, 1.6);
      p.bx.fillStyle = cssRGB(40, 40, 40); p.bx.fillRect(0, by, S, 2);
    }
    return { color: p.col, bump: p.bmp };
  }

  /* --- STONE: rough hewn granite speckle, mottled --- */
  function genStone(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(149);
    p.cx.fillStyle = cssRGB(base.r, base.g, base.b); p.cx.fillRect(0, 0, S, S);
    bumpFill(p.bx, S, 128);
    for (var i = 0; i < 220; i++) {
      var x = rnd() * S, y = rnd() * S, r = 3 + rnd() * 12;
      var c = shade(base, 0.8 + rnd() * 0.4);
      var g = p.cx.createRadialGradient(x, y, 0, x, y, r);
      g.addColorStop(0, 'rgba(' + (c.r | 0) + ',' + (c.g | 0) + ',' + (c.b | 0) + ',0.18)');
      g.addColorStop(1, 'rgba(0,0,0,0)');
      p.cx.fillStyle = g; p.cx.beginPath(); p.cx.arc(x, y, r, 0, 6.283); p.cx.fill();
    }
    for (var k = 0; k < 2600; k++) {
      var sx = rnd() * S, sy = rnd() * S, sr = 0.5 + rnd() * 1.3;
      var lite = rnd() > 0.5;
      var sc = lite ? shade(base, 1.4) : shade(base, 0.5);
      p.cx.fillStyle = 'rgba(' + (sc.r | 0) + ',' + (sc.g | 0) + ',' + (sc.b | 0) + ',0.4)';
      p.cx.beginPath(); p.cx.arc(sx, sy, sr, 0, 6.283); p.cx.fill();
      var bv = lite ? 165 : 95;
      p.bx.fillStyle = 'rgba(' + (bv | 0) + ',' + (bv | 0) + ',' + (bv | 0) + ',0.5)';
      p.bx.beginPath(); p.bx.arc(sx, sy, sr, 0, 6.283); p.bx.fill();
    }
    return { color: p.col, bump: p.bmp };
  }

  /* --- COBBLE: rounded stones with mortar lines (plaza/road) --- */
  function genCobble(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(163);
    var mortar = shade(base, 0.45);
    p.cx.fillStyle = cssRGB(mortar.r, mortar.g, mortar.b); p.cx.fillRect(0, 0, S, S);
    bumpFill(p.bx, S, 70);
    var cell = 26;
    for (var gy = -cell; gy < S + cell; gy += cell) {
      for (var gx = -cell; gx < S + cell; gx += cell) {
        var off = ((gy / cell) & 1) ? cell * 0.5 : 0;
        var cx0 = gx + off + (rnd() - 0.5) * 5, cy0 = gy + (rnd() - 0.5) * 5;
        var rad = cell * 0.42 + rnd() * 3, c = shade(base, 0.8 + rnd() * 0.45);
        var rg = p.cx.createRadialGradient(cx0 - rad * 0.3, cy0 - rad * 0.3, rad * 0.1, cx0, cy0, rad);
        rg.addColorStop(0, cssRGB(clamp255(c.r * 1.15), clamp255(c.g * 1.15), clamp255(c.b * 1.15)));
        rg.addColorStop(1, cssRGB(c.r * 0.8, c.g * 0.8, c.b * 0.8));
        p.cx.fillStyle = rg;
        p.cx.beginPath(); p.cx.ellipse(cx0, cy0, rad, rad * (0.82 + rnd() * 0.2), rnd() * 3.14, 0, 6.283); p.cx.fill();
        var bg = p.bx.createRadialGradient(cx0, cy0, rad * 0.1, cx0, cy0, rad);
        bg.addColorStop(0, cssRGB(210, 210, 210));
        bg.addColorStop(0.8, cssRGB(150, 150, 150));
        bg.addColorStop(1, cssRGB(80, 80, 80));
        p.bx.fillStyle = bg;
        p.bx.beginPath(); p.bx.ellipse(cx0, cy0, rad, rad * 0.9, 0, 0, 6.283); p.bx.fill();
      }
    }
    return { color: p.col, bump: p.bmp };
  }

  /* --- THATCH: bundled straw streaks (roof) --- */
  function genThatch(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(181);
    p.cx.fillStyle = cssRGB(base.r, base.g, base.b); p.cx.fillRect(0, 0, S, S);
    bumpFill(p.bx, S, 120);
    var light = shade(base, 1.16), dark = shade(base, 0.66);
    for (var i = 0; i < 1400; i++) {
      var y = rnd() * S, x = rnd() * S, len = 10 + rnd() * 26;
      var tone = mix(dark, light, rnd());
      p.cx.strokeStyle = cssRGB(tone.r, tone.g, tone.b);
      p.cx.lineWidth = 0.7 + rnd() * 1.1; p.cx.lineCap = 'round';
      p.cx.beginPath(); p.cx.moveTo(x, y); p.cx.lineTo(x + (rnd() - 0.5) * 3, y + len); p.cx.stroke();
      var bv = 100 + rnd() * 60;
      p.bx.strokeStyle = 'rgba(' + (bv | 0) + ',' + (bv | 0) + ',' + (bv | 0) + ',0.6)';
      p.bx.lineWidth = 0.7 + rnd();
      p.bx.beginPath(); p.bx.moveTo(x, y); p.bx.lineTo(x + (rnd() - 0.5) * 3, y + len); p.bx.stroke();
    }
    for (var c2 = 18; c2 < S; c2 += 24) {
      p.cx.fillStyle = 'rgba(0,0,0,0.12)'; p.cx.fillRect(0, c2, S, 3);
      p.bx.fillStyle = 'rgba(70,70,70,0.5)'; p.bx.fillRect(0, c2, S, 3);
    }
    return { color: p.col, bump: p.bmp };
  }

  /* --- PLASTER: troweled stucco, subtle waves & pits --- */
  function genPlaster(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(199);
    p.cx.fillStyle = cssRGB(base.r, base.g, base.b); p.cx.fillRect(0, 0, S, S);
    bumpFill(p.bx, S, 130);
    for (var i = 0; i < 90; i++) {
      var x = rnd() * S, y = rnd() * S, r = 10 + rnd() * 30;
      var lite = rnd() > 0.5;
      var c = lite ? shade(base, 1.05) : shade(base, 0.93);
      var g = p.cx.createRadialGradient(x, y, 0, x, y, r);
      g.addColorStop(0, 'rgba(' + (c.r | 0) + ',' + (c.g | 0) + ',' + (c.b | 0) + ',0.10)');
      g.addColorStop(1, 'rgba(0,0,0,0)');
      p.cx.fillStyle = g; p.cx.beginPath(); p.cx.arc(x, y, r, 0, 6.283); p.cx.fill();
      var bv = lite ? 150 : 112;
      var bg = p.bx.createRadialGradient(x, y, 0, x, y, r);
      bg.addColorStop(0, 'rgba(' + bv + ',' + bv + ',' + bv + ',0.4)');
      bg.addColorStop(1, 'rgba(130,130,130,0)');
      p.bx.fillStyle = bg; p.bx.beginPath(); p.bx.arc(x, y, r, 0, 6.283); p.bx.fill();
    }
    for (var k = 0; k < 1200; k++) {
      var px = rnd() * S, py = rnd() * S;
      p.cx.fillStyle = 'rgba(0,0,0,0.04)';
      p.cx.beginPath(); p.cx.arc(px, py, 0.5 + rnd() * 0.7, 0, 6.283); p.cx.fill();
      var bv2 = 100 + rnd() * 30;
      p.bx.fillStyle = 'rgba(' + (bv2 | 0) + ',' + (bv2 | 0) + ',' + (bv2 | 0) + ',0.4)';
      p.bx.beginPath(); p.bx.arc(px, py, 0.5 + rnd() * 0.7, 0, 6.283); p.bx.fill();
    }
    return { color: p.col, bump: p.bmp };
  }

  /* --- LEAF: veined waxy foliage with subtle midrib relief --- */
  function genLeaf(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(211);
    var light = shade(base, 1.16), dark = shade(base, 0.62);
    var grad = p.cx.createLinearGradient(0, 0, S, S);
    grad.addColorStop(0, cssRGB(light.r, light.g, light.b));
    grad.addColorStop(1, cssRGB(dark.r, dark.g, dark.b));
    p.cx.fillStyle = grad; p.cx.fillRect(0, 0, S, S);
    bumpFill(p.bx, S, 118);
    for (var y = -10; y < S + 10; y += 10) {
      var vein = shade(base, 0.48 + rnd() * 0.16);
      p.cx.strokeStyle = 'rgba(' + (vein.r | 0) + ',' + (vein.g | 0) + ',' + (vein.b | 0) + ',0.34)';
      p.cx.lineWidth = 1.0 + rnd() * 0.9;
      p.cx.beginPath(); p.cx.moveTo(0, y);
      p.cx.quadraticCurveTo(S * 0.45, y + 8 + rnd() * 8, S, y + 18 + rnd() * 8);
      p.cx.stroke();
      p.bx.strokeStyle = 'rgba(185,185,185,0.45)';
      p.bx.lineWidth = 1.2;
      p.bx.beginPath(); p.bx.moveTo(0, y);
      p.bx.quadraticCurveTo(S * 0.45, y + 8, S, y + 18);
      p.bx.stroke();
    }
    p.cx.strokeStyle = 'rgba(255,255,255,0.16)';
    p.cx.lineWidth = 3;
    p.cx.beginPath(); p.cx.moveTo(S * 0.5, 0); p.cx.lineTo(S * 0.5, S); p.cx.stroke();
    p.bx.strokeStyle = 'rgba(220,220,220,0.72)';
    p.bx.lineWidth = 4;
    p.bx.beginPath(); p.bx.moveTo(S * 0.5, 0); p.bx.lineTo(S * 0.5, S); p.bx.stroke();
    return { color: p.col, bump: p.bmp };
  }

  /* --- PETAL: satin petal with translucent-looking radial striations --- */
  function genPetal(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(227);
    var light = shade(base, 1.22), dark = shade(base, 0.72);
    var rg = p.cx.createRadialGradient(S * 0.45, S * 0.32, 4, S * 0.5, S * 0.55, S * 0.78);
    rg.addColorStop(0, cssRGB(light.r, light.g, light.b));
    rg.addColorStop(1, cssRGB(dark.r, dark.g, dark.b));
    p.cx.fillStyle = rg; p.cx.fillRect(0, 0, S, S);
    bumpFill(p.bx, S, 128);
    for (var i = 0; i < 70; i++) {
      var x = S * 0.5 + (rnd() - 0.5) * 18;
      var a = -0.65 + rnd() * 1.3;
      var tone = rnd() > 0.5 ? shade(base, 1.32) : shade(base, 0.65);
      p.cx.strokeStyle = 'rgba(' + (tone.r | 0) + ',' + (tone.g | 0) + ',' + (tone.b | 0) + ',0.22)';
      p.cx.lineWidth = 0.7 + rnd() * 0.9;
      p.cx.beginPath(); p.cx.moveTo(x, 0);
      p.cx.quadraticCurveTo(S * 0.5 + Math.sin(a) * 26, S * 0.55, S * 0.5 + Math.sin(a) * 48, S);
      p.cx.stroke();
      p.bx.strokeStyle = 'rgba(165,165,165,0.35)';
      p.bx.lineWidth = 0.8;
      p.bx.beginPath(); p.bx.moveTo(x, 0);
      p.bx.quadraticCurveTo(S * 0.5 + Math.sin(a) * 26, S * 0.55, S * 0.5 + Math.sin(a) * 48, S);
      p.bx.stroke();
    }
    return { color: p.col, bump: p.bmp };
  }

  /* --- SOIL: loose dark earth, grit, and small pebble bumps --- */
  function genSoil(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(241);
    p.cx.fillStyle = cssRGB(base.r, base.g, base.b); p.cx.fillRect(0, 0, S, S);
    bumpFill(p.bx, S, 102);
    for (var i = 0; i < 2200; i++) {
      var x = rnd() * S, y = rnd() * S, r = 0.5 + rnd() * 2.8;
      var c = shade(base, 0.52 + rnd() * 0.9);
      p.cx.fillStyle = 'rgba(' + (c.r | 0) + ',' + (c.g | 0) + ',' + (c.b | 0) + ',0.48)';
      p.cx.beginPath(); p.cx.arc(x, y, r, 0, 6.283); p.cx.fill();
      var bv = 74 + rnd() * 92;
      p.bx.fillStyle = 'rgba(' + (bv | 0) + ',' + (bv | 0) + ',' + (bv | 0) + ',0.68)';
      p.bx.beginPath(); p.bx.arc(x, y, r, 0, 6.283); p.bx.fill();
    }
    return { color: p.col, bump: p.bmp };
  }

  /* --- MOSS: clumped fuzzy velvet with raised cushions --- */
  function genMoss(base) {
    var S = 128, p = newPair(S), rnd = mulberry32(257);
    var dark = shade(base, 0.54), light = shade(base, 1.28);
    p.cx.fillStyle = cssRGB(dark.r, dark.g, dark.b); p.cx.fillRect(0, 0, S, S);
    bumpFill(p.bx, S, 108);
    for (var i = 0; i < 520; i++) {
      var x = rnd() * S, y = rnd() * S, r = 2 + rnd() * 7;
      var c = mix(dark, light, rnd());
      var g = p.cx.createRadialGradient(x - r * 0.2, y - r * 0.2, 0, x, y, r);
      g.addColorStop(0, 'rgba(' + (c.r | 0) + ',' + (c.g | 0) + ',' + (c.b | 0) + ',0.74)');
      g.addColorStop(1, 'rgba(0,0,0,0)');
      p.cx.fillStyle = g; p.cx.beginPath(); p.cx.arc(x, y, r, 0, 6.283); p.cx.fill();
      var bg = p.bx.createRadialGradient(x, y, 0, x, y, r);
      bg.addColorStop(0, 'rgba(220,220,220,0.72)');
      bg.addColorStop(1, 'rgba(90,90,90,0)');
      p.bx.fillStyle = bg; p.bx.beginPath(); p.bx.arc(x, y, r, 0, 6.283); p.bx.fill();
    }
    return { color: p.col, bump: p.bmp };
  }

  /* ============================================================================
   * KIND TABLE — generator + default material params + default repeat
   * ALIASES let callers use friendly names (cloth->fabric, hair->beard, etc).
   * ==========================================================================*/
  var KIND = {
    skin:    { gen: genSkin,    rough: 0.62, metal: 0.0,  bump: 0.04, rep: [2, 2] },
    beard:   { gen: genBeard,   rough: 0.95, metal: 0.0,  bump: 0.10, rep: [3, 3] },
    felt:    { gen: genFelt,    rough: 0.97, metal: 0.0,  bump: 0.06, rep: [3, 3] },
    fabric:  { gen: genFabric,  rough: 0.86, metal: 0.0,  bump: 0.10, rep: [4, 4] },
    linen:   { gen: genLinen,   rough: 0.90, metal: 0.0,  bump: 0.05, rep: [6, 6] },
    wool:    { gen: genWool,    rough: 0.92, metal: 0.0,  bump: 0.12, rep: [4, 4] },
    leather: { gen: genLeather, rough: 0.55, metal: 0.05, bump: 0.10, rep: [3, 3] },
    metal:   { gen: genMetal,   rough: 0.38, metal: 0.72, bump: 0.04, rep: [2, 2] },
    wood:    { gen: genWood,    rough: 0.88, metal: 0.0,  bump: 0.18, rep: [2, 3] },
    plank:   { gen: genPlank,   rough: 0.85, metal: 0.0,  bump: 0.16, rep: [2, 2] },
    stone:   { gen: genStone,   rough: 0.95, metal: 0.0,  bump: 0.22, rep: [2, 2] },
    cobble:  { gen: genCobble,  rough: 0.93, metal: 0.0,  bump: 0.35, rep: [4, 4] },
    thatch:  { gen: genThatch,  rough: 1.0,  metal: 0.0,  bump: 0.30, rep: [4, 3] },
    plaster: { gen: genPlaster, rough: 0.92, metal: 0.0,  bump: 0.08, rep: [3, 3] },
    leaf:    { gen: genLeaf,    rough: 0.74, metal: 0.0,  bump: 0.08, rep: [3, 3] },
    petal:   { gen: genPetal,   rough: 0.62, metal: 0.0,  bump: 0.035, rep: [2, 2] },
    soil:    { gen: genSoil,    rough: 0.98, metal: 0.0,  bump: 0.26, rep: [4, 4] },
    moss:    { gen: genMoss,    rough: 1.0,  metal: 0.0,  bump: 0.18, rep: [4, 4] }
  };
  /* friendly aliases so detail.js / callers can pass natural names */
  var ALIAS = {
    cloth: 'fabric', hair: 'beard', felted: 'felt', timber: 'wood',
    board: 'plank', rock: 'stone', straw: 'thatch', stucco: 'plaster',
    brass: 'metal', iron: 'metal', glass: 'plaster',
    foliage: 'leaf', flower: 'petal', bloom: 'petal', earth: 'soil', dirt: 'soil'
  };
  function resolveKind(kind) {
    if (!kind) return 'fabric';
    if (KIND[kind]) return kind;
    if (ALIAS[kind]) return ALIAS[kind];
    return 'fabric';   // safe default — never throw into the render loop
  }

  /* ---------------- texture cache (shared across calls) ---------------- */
  var texCache = {};
  function getTextures(kind, colorHex) {
    var key = kind + '|' + colorHex;
    if (texCache[key]) return texCache[key];
    var base = hexRGB(colorHex);
    var built = KIND[kind].gen(base);
    texCache[key] = built;
    return built;
  }

  /* ---------------- material cache (per kind|color|repeat|flags) ---------------- */
  var matCache = {};
  function repeatOf(spec, fallback) {
    if (spec == null) return fallback;
    if (Array.isArray(spec)) return spec;
    return [spec, spec];
  }

  function build(kind, colorHex, opts) {
    opts = opts || {};
    kind = resolveKind(kind);
    var def = KIND[kind];

    var rep = repeatOf(opts.repeat, def.rep);
    var rough = opts.roughness != null ? opts.roughness : def.rough;
    var metal = opts.metalness != null ? opts.metalness : def.metal;
    var bscale = opts.bumpScale != null ? opts.bumpScale : def.bump;
    var emissive = opts.emissive != null ? opts.emissive : 0x000000;
    var emInt = opts.emissiveIntensity != null ? opts.emissiveIntensity : 0.0;
    var transparent = !!opts.transparent;
    var opacity = opts.opacity != null ? opts.opacity : 1;
    var side = opts.side != null ? opts.side : null;

    var matKey = [kind, colorHex, rep[0], rep[1], rough, metal, bscale, emissive, emInt,
                  transparent ? 1 : 0, opacity, side == null ? 0 : side].join('|');
    if (matCache[matKey]) return matCache[matKey];

    var tex = getTextures(kind, colorHex);
    var map = colorTex(tex.color, rep[0], rep[1]);
    var bump = bumpTex(tex.bump, rep[0], rep[1]);

    var params = {
      map: map, bumpMap: bump, bumpScale: bscale,
      roughness: rough, metalness: metal,
      emissive: emissive, emissiveIntensity: emInt
    };
    if (transparent) { params.transparent = true; params.opacity = opacity; }
    if (side != null) params.side = side;

    var m = new THREE.MeshStandardMaterial(params);
    matCache[matKey] = m;
    return m;
  }

  /* ---------------- public API: one factory per kind ---------------- */
  var api = {};
  Object.keys(KIND).forEach(function (kind) {
    api[kind] = function (colorHex, opts) { return build(kind, colorHex, opts); };
  });
  api.texturedMat = function (colorHex, kind, opts) { return build(kind, colorHex, opts); };
  api.kinds = Object.keys(KIND);
  api.aliases = ALIAS;
  api.disposeAll = function () {
    Object.keys(matCache).forEach(function (k) {
      var m = matCache[k];
      if (m.map) m.map.dispose();
      if (m.bumpMap) m.bumpMap.dispose();
      m.dispose();
    });
    matCache = {}; texCache = {};
  };

  return api;
}

/* ============================================================================
 * GLOBAL SINGLETON + GLOBAL texturedMat
 * ----------------------------------------------------------------------------
 * Build the kit ONCE, lazily on first use (so THREE is guaranteed present), and
 * expose a flat texturedMat(colorHex, kind, opts) the other <script> modules call.
 *
 *   texturedMat(0xc0392b, 'felt')                  // red felt cap
 *   texturedMat(0x2e6f4e, 'fabric', { repeat: 3 }) // green woven tunic
 *   texturedMat(0xffd778, 'plaster', { emissive: 0xffbd55, emissiveIntensity: 0.9 })
 * ==========================================================================*/
(function () {
  var _kit = null;
  function kit() {
    if (!_kit) _kit = makeGnomeMat();
    return _kit;
  }
  // GnomeMat is a lazy proxy-getter so window.GnomeMat.felt(...) also works.
  if (typeof window !== 'undefined') {
    window.makeGnomeMat = makeGnomeMat;
    Object.defineProperty(window, 'GnomeMat', { get: kit, configurable: true });
    window.texturedMat = function (colorHex, kind, opts) {
      return kit().texturedMat(colorHex, kind, opts);
    };
  }
})();
