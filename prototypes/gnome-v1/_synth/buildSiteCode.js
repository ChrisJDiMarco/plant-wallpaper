/* =====================================================================
 * CONSTRUCTION LIFECYCLE — makeBuildSite(opts)
 * ---------------------------------------------------------------------
 * Gnomes build structures over time. A site starts as a raw material
 * pile and visibly assembles into a finished cottage as progress (p)
 * climbs 0 -> 1, driven entirely by setProgress(p).
 *
 *   const site = makeBuildSite({ type:'cabin', seed:7, scale:1 });
 *   scene.add(site.group);
 *   site.setProgress(0.45);          // any state in [0,1]
 *   site.stageName(0.45);            // -> "Frame & Scaffold"
 *   site.smokeAnchor;                // Object3D at chimney top (finished)
 *
 * Scale note: footprint ~22x18, ~24 tall — sized to stand alongside the
 * ~26u gnomes. three.js r128, global THREE. No CapsuleGeometry (logs are
 * tapered CylinderGeometry + Sphere caps), no modules, no loaders.
 * Uses host scene's mat(hex,opts) if present, else an inline fallback.
 * =================================================================== */
function makeBuildSite(opts) {
  opts = opts || {};
  var type  = opts.type  || 'cabin';     // 'cabin' (timber) | 'roundhouse' (stone)
  var scale = opts.scale || 1;
  var seed  = (opts.seed == null) ? 1 : opts.seed;

  /* ---- seeded RNG (mulberry32) ---- */
  var _s = (seed * 1973 + 9277) >>> 0;
  function rng() {
    _s |= 0; _s = (_s + 0x6D2B79F5) | 0;
    var t = Math.imul(_s ^ (_s >>> 15), 1 | _s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  var rand  = function (a, b) { return a + (b - a) * rng(); };
  var randi = function (a, b) { return Math.floor(rand(a, b + 1)); };
  var pick  = function (arr) { return arr[Math.floor(rng() * arr.length)]; };

  /* ---- material helper (self-contained fallback) ---- */
  function M(colorHex, o) {
    o = o || {};
    if (typeof mat === 'function') return mat(colorHex, o);
    return new THREE.MeshStandardMaterial({
      color: colorHex,
      roughness: (o.roughness == null) ? 0.85 : o.roughness,
      metalness: (o.metalness == null) ? 0.0  : o.metalness,
      emissive: o.emissive || 0x000000,
      emissiveIntensity: (o.emissiveIntensity == null) ? 0 : o.emissiveIntensity
    });
  }

  /* ---- palette (jittered per-site) ---- */
  var woodHue   = pick([0x6f4a2c, 0x7a5230, 0x8a5a34, 0x6b4326]);
  var woodLight = pick([0xb6915f, 0xc09a63, 0xa9854f]);
  var stoneHue  = pick([0x8d8a82, 0x97928a, 0x837f78, 0x9a958c]);
  var thatchHue = pick([0xb79256, 0xc59f5e, 0xa9863f]);

  var matWoodDark  = M(woodHue,   { roughness: 0.9 });
  var matWoodLight = M(woodLight, { roughness: 0.86 });
  var matWoodRaw   = M(0x9a6d3e,  { roughness: 0.95 });
  var matStone     = M(stoneHue,  { roughness: 0.95 });
  var matStoneDark = M(0x6c6960,  { roughness: 0.97 });
  var matThatch    = M(thatchHue, { roughness: 1.0 });
  var matRope      = M(0xb9a36f,  { roughness: 1.0 });
  var matMetal     = M(0x5a5650,  { roughness: 0.55, metalness: 0.6 });
  var matDoor      = M(0x4f3320,  { roughness: 0.8 });
  var matShingle   = M(0x55402b,  { roughness: 0.9 });
  var matGlass     = M(0x2a2620,  { roughness: 0.3, metalness: 0.1,
                                    emissive: 0xffce6b, emissiveIntensity: 0 });

  /* ---- root group ---- */
  var group = new THREE.Group();
  group.scale.setScalar(scale);
  group.name = 'buildSite';

  /* ===== PART REGISTRY (appear/remove windows + grow/glow) ===== */
  var parts = [];
  function reg(obj3d, cfg) {
    cfg = cfg || {};
    group.add(obj3d);
    parts.push({
      obj: obj3d,
      appear: cfg.appear || [0, 0.0001],
      remove: cfg.remove || null,
      grow:   cfg.grow   || null,
      glow:   cfg.glow   || false,
      baseScale: obj3d.scale.clone(),
      baseY: obj3d.position.y,
      isPile: cfg.isPile || false
    });
    return obj3d;
  }
  function ramp(x, a, b) {
    if (b <= a) return x >= b ? 1 : 0;
    var t = (x - a) / (b - a);
    t = Math.max(0, Math.min(1, t));
    return t * t * (3 - 2 * t); // smoothstep
  }
  function tagMaterials(obj) {
    obj.traverse(function (n) {
      if (!n.isMesh) return;
      n.castShadow = true;
      if (n.geometry && n.geometry.type !== 'CircleGeometry') n.receiveShadow = false;
      // clone so opacity on one part never bleeds to another
      if (Array.isArray(n.material)) n.material = n.material.map(function (m) { return m.clone(); });
      else if (n.material) n.material = n.material.clone();
      var apply = function (m) { m.transparent = true; m.opacity = 1; };
      if (Array.isArray(n.material)) n.material.forEach(apply); else if (n.material) apply(n.material);
    });
    return obj;
  }
  function setObjOpacity(obj, o, glow) {
    obj.traverse(function (n) {
      if (!n.isMesh) return;
      var set = function (m) {
        m.opacity = o; m.visible = o > 0.02;
        if (glow) m.emissiveIntensity = o;
      };
      if (Array.isArray(n.material)) n.material.forEach(set); else if (n.material) set(n.material);
    });
    obj.visible = o > 0.02;
  }

  /* ---- small builders ---- */
  function box(w, h, d, m, pos, rot) {
    var mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m);
    if (pos) mesh.position.set(pos[0], pos[1], pos[2]);
    if (rot) mesh.rotation.set(rot[0], rot[1], rot[2]);
    mesh.castShadow = true; mesh.receiveShadow = true; return mesh;
  }
  function cyl(rt, rb, h, m, pos, rot, seg) {
    var mesh = new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, h, seg || 10), m);
    if (pos) mesh.position.set(pos[0], pos[1], pos[2]);
    if (rot) mesh.rotation.set(rot[0], rot[1], rot[2]);
    mesh.castShadow = true; mesh.receiveShadow = true; return mesh;
  }
  function sph(r, m, pos) {
    var mesh = new THREE.Mesh(new THREE.SphereGeometry(r, 12, 9), m);
    if (pos) mesh.position.set(pos[0], pos[1], pos[2]);
    mesh.castShadow = true; mesh.receiveShadow = true; return mesh;
  }
  // faux-capsule log = tapered cylinder + sphere caps (r128-safe)
  function log(len, rad, m, pos, rot) {
    var g = new THREE.Group();
    g.add(cyl(rad * 0.92, rad, len, m, [0, 0, 0], [0, 0, Math.PI / 2], 9));
    g.add(sph(rad, m, [len / 2, 0, 0]));
    g.add(sph(rad, m, [-len / 2, 0, 0]));
    if (pos) g.position.set(pos[0], pos[1], pos[2]);
    if (rot) g.rotation.set(rot[0], rot[1], rot[2]);
    return g;
  }

  /* ===== STAGE 0 — RAW MATERIAL PILE (consumed as we build) ===== */
  var pile = new THREE.Group();
  pile.position.set(-15, 0, 8);
  (function buildLogStack() {
    var rad = 1.5, len = 13, rows = randi(2, 3);
    for (var r = 0; r < rows; r++) {
      var count = (rows - r) + randi(1, 2);
      var y = rad + r * (rad * 1.85);
      for (var i = 0; i < count; i++) {
        var x = (i - (count - 1) / 2) * (rad * 2.05) + rand(-0.2, 0.2);
        pile.add(log(len + rand(-1.5, 1.5), rad * rand(0.9, 1.05), matWoodRaw,
          [x, y, rand(-0.4, 0.4)], [0, rand(-0.05, 0.05), 0]));
      }
    }
  })();
  (function buildPlankStack() {
    var px = rand(8, 10);
    for (var i = 0; i < randi(4, 6); i++) {
      pile.add(box(11, 0.7, 3.2, i % 2 ? matWoodLight : matWoodDark,
        [px, 0.5 + i * 0.78, -4 + rand(-0.3, 0.3)],
        [0, rand(-0.06, 0.06), rand(-0.02, 0.02)]));
    }
  })();
  (function buildStoneBlocks() {
    for (var i = 0; i < randi(3, 5); i++) {
      var s = rand(2.2, 3.2);
      pile.add(box(s, s * 0.8, s * 0.9, i % 2 ? matStone : matStoneDark,
        [rand(-3, 5), s * 0.4, rand(5, 9)], [0, rand(0, 1), 0]));
    }
  })();
  var rope = new THREE.Mesh(new THREE.TorusGeometry(1.7, 0.42, 8, 20), matRope);
  rope.rotation.x = Math.PI / 2; rope.position.set(-6, 0.5, 4); rope.castShadow = true; pile.add(rope);
  (function buildSawhorse() {
    var h = new THREE.Group();
    h.add(box(7, 0.7, 1.0, matWoodDark, [0, 4.0, 0]));
    [[-2.8, 1], [2.8, -1]].forEach(function (c) {
      h.add(cyl(0.3, 0.4, 4.4, matWoodDark, [c[0], 2.1, 1.2], [0.35 * c[1], 0, 0.18]));
      h.add(cyl(0.3, 0.4, 4.4, matWoodDark, [c[0], 2.1, -1.2], [-0.35 * c[1], 0, 0.18]));
    });
    h.position.set(2, 0, -8); pile.add(h);
  })();
  (function buildToolbox() {
    var t = new THREE.Group();
    t.add(box(4.5, 2.2, 2.6, matMetal, [0, 1.1, 0]));
    t.add(cyl(0.18, 0.18, 4.4, matWoodDark, [0, 3.0, 0], [Math.PI / 2, 0, 0], 8));
    t.position.set(-9, 0, -7); pile.add(t);
  })();
  tagMaterials(pile);
  reg(pile, { appear: [0, 0.02], remove: [0.12, 0.92], isPile: true });

  /* ===== shared geometry plan ===== */
  var isRound = (type === 'roundhouse');
  var W = 22, D = 18, RAD = 11, WALL_H = 12;
  var cornersRect = [
    [-W / 2, -D / 2], [W / 2, -D / 2], [W / 2, D / 2], [-W / 2, D / 2]
  ];

  /* ===== STAGE 1 — FOUNDATION (plinth + rising corner posts) ===== */
  var plinth = new THREE.Group();
  if (isRound) {
    plinth.add(cyl(RAD + 1.5, RAD + 2.2, 2.4, matStoneDark, [0, 1.2, 0], null, 32));
    var n0 = 18;
    for (var i0 = 0; i0 < n0; i0++) {
      var a0 = (i0 / n0) * Math.PI * 2;
      plinth.add(box(rand(2.6, 3.4), 1.8, 2.2, i0 % 2 ? matStone : matStoneDark,
        [Math.cos(a0) * RAD, 2.6, Math.sin(a0) * RAD], [0, -a0, 0]));
    }
  } else {
    plinth.add(box(W + 3, 2.4, D + 3, matStoneDark, [0, 1.2, 0]));
    for (var i1 = 0; i1 < 6; i1++) {
      plinth.add(box(rand(3, 4), 1.6, 2.0, i1 % 2 ? matStone : matStoneDark,
        [-W / 2 + (i1 + 0.5) * (W / 6), 2.5, -D / 2 - 0.4]));
    }
  }
  tagMaterials(plinth);
  reg(plinth, { appear: [0.12, 0.2] });

  var cornerPosts = new THREE.Group();
  var postPositions = isRound
    ? (function () { var o = []; for (var i = 0; i < 6; i++) { var a = (i / 6) * Math.PI * 2; o.push([Math.cos(a) * RAD, Math.sin(a) * RAD]); } return o; })()
    : cornersRect;
  postPositions.forEach(function (c) {
    cornerPosts.add(cyl(0.8, 1.0, WALL_H, matWoodDark, [c[0], WALL_H / 2 + 2.2, c[1]], [0, rand(-0.04, 0.04), 0], 9));
    cornerPosts.add(box(2.4, 0.6, 2.4, matWoodLight, [c[0], WALL_H + 2.2, c[1]]));
  });
  tagMaterials(cornerPosts);
  reg(cornerPosts, { appear: [0.18, 0.33], grow: 'y' });

  /* ===== STAGE 2 — FRAME + SCAFFOLD ===== */
  var frame = new THREE.Group();
  if (isRound) {
    var nf = 12;
    for (var fi = 0; fi < nf; fi++) {
      var af = (fi / nf) * Math.PI * 2;
      frame.add(cyl(0.4, 0.5, WALL_H * 0.96, matWoodDark,
        [Math.cos(af) * RAD, WALL_H / 2 + 2.4, Math.sin(af) * RAD], [0, -af, 0], 7));
    }
    var ring = new THREE.Mesh(new THREE.TorusGeometry(RAD, 0.5, 8, 32), matWoodLight);
    ring.rotation.x = Math.PI / 2; ring.position.y = WALL_H + 2.4; ring.castShadow = true;
    frame.add(ring);
  } else {
    cornersRect.forEach(function (c, i) {
      var nc = cornersRect[(i + 1) % 4];
      var studs = 4;
      for (var s = 1; s < studs; s++) {
        var x = c[0] + (nc[0] - c[0]) * (s / studs);
        var z = c[1] + (nc[1] - c[1]) * (s / studs);
        frame.add(cyl(0.45, 0.5, WALL_H, matWoodDark, [x, WALL_H / 2 + 2.4, z], null, 7));
      }
      var mx = (c[0] + nc[0]) / 2, mz = (c[1] + nc[1]) / 2;
      var len = Math.hypot(nc[0] - c[0], nc[1] - c[1]);
      var ang = Math.atan2(nc[1] - c[1], nc[0] - c[0]);
      var beam = cyl(0.5, 0.5, len, matWoodLight, [mx, WALL_H + 2.4, mz], null, 7);
      beam.rotation.set(0, -ang, Math.PI / 2);
      frame.add(beam);
    });
  }
  tagMaterials(frame);
  reg(frame, { appear: [0.33, 0.46], grow: 'y' });

  var trusses = new THREE.Group();
  var ridgeY = WALL_H + 2.4 + (isRound ? 8 : 7);
  if (isRound) {
    var nt = 8;
    for (var ti = 0; ti < nt; ti++) {
      var at = (ti / nt) * Math.PI * 2;
      var bx = Math.cos(at) * RAD, bz = Math.sin(at) * RAD;
      var top = WALL_H + 2.4;
      var lenR = Math.hypot(RAD, ridgeY - top);
      var r = cyl(0.3, 0.4, lenR, matWoodDark, [bx / 2, (top + ridgeY) / 2, bz / 2], null, 6);
      r.lookAt(new THREE.Vector3(0, ridgeY, 0)); r.rotateX(Math.PI / 2);
      r.position.set(bx / 2, (top + ridgeY) / 2, bz / 2);
      trusses.add(r);
    }
  } else {
    var spans = 3;
    for (var sp = 0; sp <= spans; sp++) {
      var z2 = -D / 2 + D * (sp / spans);
      var top2 = WALL_H + 2.4;
      [-1, 1].forEach(function (sgn) {
        var lenT = Math.hypot(W / 2, ridgeY - top2);
        var rr = cyl(0.32, 0.4, lenT, matWoodDark, [sgn * W / 4, (top2 + ridgeY) / 2, z2], null, 6);
        var angT = Math.atan2(ridgeY - top2, -sgn * W / 2);
        rr.rotation.set(0, 0, angT - Math.PI / 2);
        trusses.add(rr);
      });
      trusses.add(cyl(0.3, 0.3, W, matWoodLight, [0, top2, z2], [0, 0, Math.PI / 2], 6));
      trusses.add(cyl(0.28, 0.28, ridgeY - top2, matWoodDark, [0, (top2 + ridgeY) / 2, z2], null, 6));
    }
    trusses.add(cyl(0.4, 0.4, D, matWoodLight, [0, ridgeY, 0], [Math.PI / 2, 0, 0], 7));
  }
  tagMaterials(trusses);
  reg(trusses, { appear: [0.42, 0.58], grow: 'y' });

  var scaffold = new THREE.Group();
  (function buildScaffold() {
    function sampleEdge(a, b, n) {
      var out = [];
      for (var i = 0; i < n; i++) { var t = i / n; out.push([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]); }
      return out;
    }
    var offs = 3.5;
    var ringPts = isRound
      ? (function () { var o = []; for (var i = 0; i < 10; i++) { var a = (i / 10) * Math.PI * 2; o.push([Math.cos(a) * (RAD + offs), Math.sin(a) * (RAD + offs)]); } return o; })()
      : sampleEdge([-W / 2 - offs, -D / 2 - offs], [W / 2 + offs, -D / 2 - offs], 3)
          .concat(sampleEdge([W / 2 + offs, -D / 2 - offs], [W / 2 + offs, D / 2 + offs], 3))
          .concat(sampleEdge([W / 2 + offs, D / 2 + offs], [-W / 2 - offs, D / 2 + offs], 3))
          .concat(sampleEdge([-W / 2 - offs, D / 2 + offs], [-W / 2 - offs, -D / 2 - offs], 3));
    var scaffH = WALL_H + 5;
    ringPts.forEach(function (p) {
      scaffold.add(cyl(0.22, 0.3, scaffH, matWoodRaw, [p[0], scaffH / 2 + 1.5, p[1]],
        [rand(-0.04, 0.04), 0, rand(-0.04, 0.04)], 6));
    });
    [scaffH * 0.45, scaffH * 0.85].forEach(function (hy) {
      for (var i = 0; i < ringPts.length; i++) {
        var a = ringPts[i], b = ringPts[(i + 1) % ringPts.length];
        var mx = (a[0] + b[0]) / 2, mz = (a[1] + b[1]) / 2;
        var len = Math.hypot(b[0] - a[0], b[1] - a[1]);
        var ang = Math.atan2(b[1] - a[1], b[0] - a[0]);
        var rail = cyl(0.16, 0.16, len, matWoodRaw, [mx, hy, mz], null, 5);
        rail.rotation.set(0, -ang, Math.PI / 2);
        scaffold.add(rail);
      }
    });
    for (var i = 0; i < 3; i++) {
      var a = ringPts[i], b = ringPts[(i + 1) % ringPts.length];
      var mx = (a[0] + b[0]) / 2, mz = (a[1] + b[1]) / 2;
      scaffold.add(box(Math.hypot(b[0] - a[0], b[1] - a[1]) + 1, 0.4, 2.4, matWoodLight,
        [mx, scaffH * 0.85 + 0.4, mz], [0, -Math.atan2(b[1] - a[1], b[0] - a[0]), 0]));
    }
  })();
  tagMaterials(scaffold);
  reg(scaffold, { appear: [0.33, 0.42], remove: [0.78, 0.9] });

  var ladder = new THREE.Group();
  (function buildLadder() {
    var lh = WALL_H + 3, lw = 3;
    ladder.add(cyl(0.22, 0.26, lh, matWoodDark, [-lw / 2, lh / 2, 0], null, 6));
    ladder.add(cyl(0.22, 0.26, lh, matWoodDark, [lw / 2, lh / 2, 0], null, 6));
    for (var i = 1; i < 6; i++) {
      ladder.add(cyl(0.16, 0.16, lw, matWoodLight, [0, lh * (i / 6), 0], [0, 0, Math.PI / 2], 5));
    }
    ladder.rotation.x = -0.32;
    ladder.position.set(isRound ? RAD - 1 : W / 2 - 2, 1.5, isRound ? RAD + 2 : D / 2 + 3);
    ladder.rotation.y = rand(-0.3, 0.3);
  })();
  tagMaterials(ladder);
  reg(ladder, { appear: [0.36, 0.44], remove: [0.82, 0.9] });

  /* ===== STAGE 3 — CLADDING (walls rise band-by-band, roof rows) ===== */
  var WALL_BANDS = 5;
  for (var b = 0; b < WALL_BANDS; b++) {
    var band = new THREE.Group();
    var y0 = 2.4 + b * (WALL_H / WALL_BANDS);
    var bh = WALL_H / WALL_BANDS;
    if (isRound) {
      var nb = 16;
      for (var bi = 0; bi < nb; bi++) {
        var ab = (bi / nb) * Math.PI * 2 + (b % 2 ? Math.PI / nb : 0);
        band.add(box(rand(3.4, 4.2), bh * 0.92, 2.6, (bi + b) % 2 ? matStone : matStoneDark,
          [Math.cos(ab) * RAD, y0 + bh / 2, Math.sin(ab) * RAD], [0, -ab, 0]));
      }
    } else {
      cornersRect.forEach(function (c, i) {
        var nc = cornersRect[(i + 1) % 4];
        var mx = (c[0] + nc[0]) / 2, mz = (c[1] + nc[1]) / 2;
        var len = Math.hypot(nc[0] - c[0], nc[1] - c[1]);
        var ang = Math.atan2(nc[1] - c[1], nc[0] - c[0]);
        var plank = box(len, bh * 0.95, 1.2, (b % 2) ? matWoodLight : matWoodDark, [mx, y0 + bh / 2, mz]);
        plank.rotation.y = -ang;
        band.add(plank);
      });
    }
    tagMaterials(band);
    var ab2 = 0.6 + (b / WALL_BANDS) * 0.18;
    reg(band, { appear: [ab2, ab2 + 0.05], grow: 'y' });
  }

  var SHINGLE_ROWS = 4;
  for (var sr = 0; sr < SHINGLE_ROWS; sr++) {
    var rowG = new THREE.Group();
    var topR = WALL_H + 2.4;
    if (isRound) {
      var t0 = sr / SHINGLE_ROWS, t1 = (sr + 1) / SHINGLE_ROWS;
      var rr0 = RAD * (1 - t0), rr1 = RAD * (1 - t1);
      var yy0 = topR + (ridgeY - topR) * t0, yy1 = topR + (ridgeY - topR) * t1;
      var ringMesh = new THREE.Mesh(
        new THREE.CylinderGeometry(rr1, rr0 + 0.6, Math.hypot(rr0 - rr1, yy1 - yy0) + 1.2, 24, 1, true),
        matThatch);
      ringMesh.position.y = (yy0 + yy1) / 2; ringMesh.castShadow = true; ringMesh.material.side = THREE.DoubleSide;
      rowG.add(ringMesh);
    } else {
      var t0c = sr / SHINGLE_ROWS, t1c = (sr + 1) / SHINGLE_ROWS;
      [-1, 1].forEach(function (sgn) {
        var x0 = sgn * (W / 2) * (1 - t0c), yA = topR + (ridgeY - topR) * t0c;
        var x1 = sgn * (W / 2) * (1 - t1c), yB = topR + (ridgeY - topR) * t1c;
        var mx = (x0 + x1) / 2, my = (yA + yB) / 2;
        var strip = box(D + 1.5, 0.6, Math.hypot(x1 - x0, yB - yA) + 0.8, (sr % 2) ? matShingle : matWoodDark, [0, my, 0]);
        strip.position.set(mx, my, 0);
        strip.rotation.set(0, Math.PI / 2, Math.atan2(yB - yA, x1 - x0));
        rowG.add(strip);
      });
    }
    tagMaterials(rowG);
    var aSh = 0.68 + (sr / SHINGLE_ROWS) * 0.16;
    reg(rowG, { appear: [aSh, aSh + 0.05] });
  }

  /* ===== STAGE 4 — FINISHED (door, glowing windows, chimney) ===== */
  var door = new THREE.Group();
  (function buildDoor() {
    var dz = isRound ? RAD + 0.2 : D / 2 + 0.2;
    door.add(box(5, 8, 0.8, matDoor, [0, 6.4, dz]));
    door.add(box(5.8, 9, 0.5, matWoodLight, [0, 6.6, dz - 0.3]));
    door.add(sph(0.45, matMetal, [1.6, 6.4, dz + 0.5]));
    door.add(box(6, 1.2, 3, matStone, [0, 0.6, dz + 1.4]));
  })();
  tagMaterials(door);
  reg(door, { appear: [0.85, 0.92] });

  var windows = new THREE.Group();
  (function buildWindows() {
    var specs = isRound
      ? [Math.PI * 0.35, Math.PI * 1.0, Math.PI * 1.65].map(function (ang) {
          return [Math.cos(ang) * (RAD + 0.2), 7.5, Math.sin(ang) * (RAD + 0.2), -ang];
        })
      : [[-W / 4, 7.5, D / 2 + 0.2, 0], [W / 4, 7.5, D / 2 + 0.2, 0],
         [W / 2 + 0.2, 7.5, 0, Math.PI / 2], [-W / 2 - 0.2, 7.5, 0, Math.PI / 2]];
    specs.forEach(function (s) {
      var win = new THREE.Group();
      win.add(box(4.2, 4.2, 0.5, matWoodDark, [0, 0, 0]));
      win.add(box(3.4, 3.4, 0.3, matGlass, [0, 0, 0.18]));
      win.add(box(3.6, 0.4, 0.5, matWoodDark, [0, 0, 0.2]));
      win.add(box(0.4, 3.6, 0.5, matWoodDark, [0, 0, 0.2]));
      win.position.set(s[0], s[1], s[2]); win.rotation.y = s[3];
      windows.add(win);
    });
  })();
  tagMaterials(windows);
  reg(windows, { appear: [0.9, 1.0], glow: true });

  var chimney = new THREE.Group();
  var smokeAnchor = new THREE.Object3D();
  (function buildChimney() {
    var cx = isRound ? RAD * 0.45 : W / 2 - 4;
    var cz = isRound ? -RAD * 0.4 : -D / 4;
    var chTop = ridgeY + 4;
    chimney.add(box(3.4, chTop, 3.4, isRound ? matStone : matStoneDark, [cx, chTop / 2, cz]));
    chimney.add(box(4.2, 1.2, 4.2, matStone, [cx, chTop, cz]));
    smokeAnchor.position.set(cx, chTop + 1.2, cz);
    chimney.add(smokeAnchor);
  })();
  tagMaterials(chimney);
  reg(chimney, { appear: [0.86, 0.95], grow: 'y' });

  /* ===== setProgress(p): single source of truth for the whole site ===== */
  function setProgress(p) {
    p = Math.max(0, Math.min(1, p));
    for (var i = 0; i < parts.length; i++) {
      var part = parts[i];
      var a = ramp(p, part.appear[0], part.appear[1]);
      var vis = a;
      if (part.remove) vis = a * (1 - ramp(p, part.remove[0], part.remove[1]));
      setObjOpacity(part.obj, vis, part.glow);
      if (part.grow === 'y') {
        part.obj.scale.set(part.baseScale.x, (part.baseScale.y * a) || 0.0001, part.baseScale.z);
      } else if (part.grow === 'xz') {
        part.obj.scale.set((part.baseScale.x * a) || 0.0001, part.baseScale.y, (part.baseScale.z * a) || 0.0001);
      }
      if (part.isPile && part.remove) {
        var rm = ramp(p, part.remove[0], part.remove[1]);
        part.obj.scale.setScalar(1 - rm * 0.55);
        part.obj.position.y = part.baseY - rm * 1.5;  // settle into the ground as consumed
      }
    }
  }
  function stageName(p) {
    p = Math.max(0, Math.min(1, p));
    if (p < 0.12) return 'Raw Materials';
    if (p < 0.33) return 'Foundation';
    if (p < 0.6)  return 'Frame & Scaffold';
    if (p < 0.85) return 'Cladding';
    return 'Finished';
  }

  setProgress(0);
  return { group: group, setProgress: setProgress, stageName: stageName, smokeAnchor: smokeAnchor, type: type };
}