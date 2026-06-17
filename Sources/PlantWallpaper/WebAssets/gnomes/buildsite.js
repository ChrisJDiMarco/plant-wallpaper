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
    if (typeof texturedMat === 'function') return texturedMat(colorHex, o.kind || 'wood', o);
    if (typeof mat === 'function') return mat(colorHex, o);
    var material = new THREE.MeshStandardMaterial({
      color: colorHex,
      roughness: (o.roughness == null) ? 0.85 : o.roughness,
      metalness: (o.metalness == null) ? 0.0  : o.metalness,
      emissive: o.emissive || 0x000000,
      emissiveIntensity: (o.emissiveIntensity == null) ? 0 : o.emissiveIntensity
    });
    if (o.transparent) { material.transparent = true; material.opacity = o.opacity == null ? 1 : o.opacity; }
    material.userData.gnomeDisposableMaterial = true;
    return material;
  }

  /* ---- palette (jittered per-site) ---- */
  var woodHue   = pick([0x6f4a2c, 0x7a5230, 0x8a5a34, 0x6b4326]);
  var woodLight = pick([0xb6915f, 0xc09a63, 0xa9854f]);
  var stoneHue  = pick([0x8d8a82, 0x97928a, 0x837f78, 0x9a958c]);
  var thatchHue = pick([0xb79256, 0xc59f5e, 0xa9863f]);

  var matWoodDark  = M(woodHue,   { kind: 'wood',  roughness: 0.9 });
  var matWoodLight = M(woodLight, { kind: 'plank', roughness: 0.86 });
  var matWoodRaw   = M(0x9a6d3e,  { kind: 'wood',  roughness: 0.95 });
  var matStone     = M(stoneHue,  { kind: 'stone' });
  var matStoneDark = M(0x6c6960,  { kind: 'stone' });
  var matThatch    = M(thatchHue, { kind: 'thatch' });
  var matRope      = M(0xb9a36f,  { kind: 'wool',  roughness: 1.0 });
  var matMetal     = M(0x5a5650,  { kind: 'metal', roughness: 0.55, metalness: 0.6 });
  var matDoor      = M(0x4f3320,  { kind: 'plank', roughness: 0.8 });
  var matShingle   = M(0x55402b,  { kind: 'plank', roughness: 0.9 });
  var matGlass     = M(0x2a2620,  { kind: 'glass', roughness: 0.3, metalness: 0.1,
                                    emissive: 0xffce6b, emissiveIntensity: 0 });
  var matSoil      = M(0x5b3b25,  { kind: 'soil', roughness: 1.0 });
  var matMoss      = M(0x526f36,  { kind: 'moss', roughness: 1.0 });
  var matLeaf      = M(0x557f3b,  { kind: 'leaf', roughness: 0.82 });
  var matPetal     = M(0xd67a86,  { kind: 'petal', roughness: 0.72 });

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
      motion: cfg.motion || null,
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
      function cloneDisposableMaterial(m) {
        var clone = m.clone();
        clone.userData.gnomeDisposableMaterial = true;
        return clone;
      }
      if (Array.isArray(n.material)) n.material = n.material.map(cloneDisposableMaterial);
      else if (n.material) n.material = cloneDisposableMaterial(n.material);
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

  /* ===== STAGE 0 — RAW MATERIAL PILE (varies by structure; consumed as we build) =====
   * Timber structures stockpile wood (log stacks, plank bundles, a straw roof bundle,
   * a saw); stone structures stockpile a quarried stone heap with a mortar/sand mound,
   * scaffold poles and a mason's mallet. Per-site jitter keeps two of a kind distinct. */
  var timberHeavy = (type !== 'roundhouse');
  var pile = new THREE.Group();
  pile.position.set(-15, 0, 8);

  (function buildLogStack() {
    var rad = timberHeavy ? 1.6 : 1.15;
    var len = timberHeavy ? 14 : 9;
    var rows = timberHeavy ? randi(3, 4) : randi(1, 2);
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
    var stacks = timberHeavy ? 2 : 1;
    for (var s = 0; s < stacks; s++) {
      var px = rand(8, 10) + s * 3.6;
      var rows = timberHeavy ? randi(4, 6) : randi(2, 3);
      for (var i = 0; i < rows; i++) {
        pile.add(box(timberHeavy ? 11 : 8, 0.7, 3.2, i % 2 ? matWoodLight : matWoodDark,
          [px, 0.5 + i * 0.78, -4 + rand(-0.3, 0.3)],
          [0, rand(-0.06, 0.06), rand(-0.02, 0.02)]));
      }
    }
  })();

  (function buildStoneHeap() {
    if (timberHeavy) {
      // just a few footing stones for a timber build
      for (var i = 0; i < randi(2, 3); i++) {
        var fs = rand(2.2, 3.0);
        pile.add(box(fs, fs * 0.8, fs * 0.9, i % 2 ? matStone : matStoneDark,
          [rand(-3, 5), fs * 0.4, rand(5, 9)], [0, rand(0, 1), 0]));
      }
      return;
    }
    // stone build: a stacked, pyramid-ish heap of dressed blocks
    var layers = randi(3, 4);
    for (var L = 0; L < layers; L++) {
      var n = (layers - L) + randi(1, 2);
      var bs = rand(2.6, 3.4);
      var rowY = L * (bs * 0.8) + bs * 0.4;
      for (var b = 0; b < n; b++) {
        var bx = (b - (n - 1) / 2) * (bs * 1.08) + rand(-0.2, 0.2);
        pile.add(box(bs, bs * 0.78, bs * 0.92, (b + L) % 2 ? matStone : matStoneDark,
          [bx + 1, rowY, rand(4, 8)], [0, rand(-0.2, 0.2), 0]));
      }
    }
    // scaffold poles leaning by the stone
    for (var p = 0; p < 3; p++) {
      pile.add(log(11 + rand(-1, 1), 0.7, matWoodRaw,
        [rand(-10, -6), 3.0 + p * 0.5, rand(-2, 2)], [0, rand(-0.4, 0.4), Math.PI / 2.2 + rand(-0.12, 0.12)]));
    }
  })();

  (function buildBinder() {
    if (timberHeavy) {
      // a roped bundle of straw/thatch for the roof
      var bundle = new THREE.Group();
      for (var i = 0; i < 9; i++) {
        bundle.add(cyl(0.18, 0.22, 6.5, matThatch,
          [rand(-0.9, 0.9), 3.2, rand(-0.6, 0.6)], [rand(-0.06, 0.06), rand(0, 1), rand(-0.06, 0.06)], 6));
      }
      var tie = new THREE.Mesh(new THREE.TorusGeometry(1.3, 0.16, 6, 16), matRope);
      tie.rotation.x = Math.PI / 2; tie.position.y = 3.4; bundle.add(tie);
      bundle.position.set(-6, 0, -3); pile.add(bundle);
    } else {
      // a mound of sand/mortar with a trowel resting in it
      var mound = sph(rand(3.0, 3.8), matSoil, [-7, 1.2, -3]);
      mound.scale.set(1.2, 0.5, 1.0); pile.add(mound);
      pile.add(box(0.5, 0.18, 2.6, matMetal, [-7, 2.6, -3], [0.1, 0.5, 0.4]));            // trowel blade
      pile.add(cyl(0.16, 0.18, 2.2, matWoodDark, [-8.4, 3.0, -3.6], [0.3, 0.5, 0.5], 6)); // trowel handle
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
    if (timberHeavy) {
      t.add(box(0.18, 3.4, 1.4, matMetal, [2.6, 2.0, 0], [0, 0, 0.5]));                  // saw blade
      t.add(cyl(0.18, 0.18, 4.4, matWoodDark, [0, 3.0, 0], [Math.PI / 2, 0, 0], 8));
    } else {
      t.add(cyl(0.9, 0.9, 1.7, matWoodDark, [2.8, 1.6, 0], [0, 0, Math.PI / 2], 10));    // mallet head
      t.add(cyl(0.2, 0.22, 2.8, matWoodDark, [4.4, 1.6, 0], [0, 0, Math.PI / 2], 6));    // mallet handle
      t.add(cyl(0.12, 0.16, 1.6, matMetal, [0, 2.5, 0.8], [0.2, 0, 0], 6));              // chisel
    }
    t.position.set(-9, 0, -7); pile.add(t);
  })();

  tagMaterials(pile);
  reg(pile, { appear: [0, 0.02], remove: [0.12, 0.92], isPile: true });

  var surveyFlags = new THREE.Group();
  surveyFlags.name = 'surveyFlags';
  (function buildSurveyFlags() {
    var markerMat = M(0xf1d58a, { kind: 'linen', roughness: 0.96 });
    var chalkMat = M(0xe9dec8, { kind: 'linen', roughness: 1.0, transparent: true, opacity: 0.72 });
    [[-13, -10], [13, -10], [13, 10], [-13, 10]].forEach(function (p, i) {
      surveyFlags.add(cyl(0.12, 0.18, 5.2, matWoodRaw, [p[0], 2.6, p[1]], [0.02, 0, -0.04], 5));
      var flag = box(2.3, 1.0, 0.08, markerMat, [p[0] + (i % 2 ? -1.1 : 1.1), 4.7, p[1]], [0, 0.08 * (i - 1), 0.04]);
      surveyFlags.add(flag);
    });
    surveyFlags.add(box(27.5, 0.08, 0.08, chalkMat, [0, 0.38, -10], [0, 0, 0]));
    surveyFlags.add(box(27.5, 0.08, 0.08, chalkMat, [0, 0.38, 10], [0, 0, 0]));
    surveyFlags.add(box(0.08, 0.08, 21.5, chalkMat, [-13, 0.38, 0], [0, 0, 0]));
    surveyFlags.add(box(0.08, 0.08, 21.5, chalkMat, [13, 0.38, 0], [0, 0, 0]));
    for (var i = 0; i < 8; i++) {
      var pebble = sph(rand(0.22, 0.42), matStone, [rand(-12, 12), 0.28, rand(-9, 9)]);
      pebble.scale.y = 0.45;
      surveyFlags.add(pebble);
    }
  })();
  tagMaterials(surveyFlags);
  reg(surveyFlags, {
    appear: [0.01, 0.06],
    remove: [0.26, 0.42],
    motion: function (obj, p, a, vis, time) {
      var clock = time != null ? time : p * 10;
      obj.rotation.y = Math.sin(clock * 0.8 + seed) * 0.01 * vis;
    }
  });

  /* ===== shared geometry plan ===== */
  var isRound = (type === 'roundhouse');
  var W = 22, D = 18, RAD = 11, WALL_H = 12;
  var cornersRect = [
    [-W / 2, -D / 2], [W / 2, -D / 2], [W / 2, D / 2], [-W / 2, D / 2]
  ];

  var excavationFootings = new THREE.Group();
  excavationFootings.name = 'excavationFootings';
  (function buildExcavationFootings() {
    var trenchY = 0.16;
    if (isRound) {
      var trench = new THREE.Mesh(new THREE.TorusGeometry(RAD + 1.5, 1.25, 10, 36), matSoil);
      trench.name = 'soilTrench';
      trench.rotation.x = Math.PI / 2;
      trench.position.y = trenchY;
      trench.castShadow = true; trench.receiveShadow = true;
      excavationFootings.add(trench);
      for (var r = 0; r < 16; r++) {
        var ar = (r / 16) * Math.PI * 2;
        excavationFootings.add(box(rand(2.1, 3.4), 0.55, rand(1.1, 1.8), r % 2 ? matStone : matStoneDark,
          [Math.cos(ar) * (RAD + 1.5), 0.52, Math.sin(ar) * (RAD + 1.5)], [0, -ar + rand(-0.08, 0.08), 0]));
      }
    } else {
      var segments = [
        [0, -D / 2 - 1.1, W + 3.6, 1.65, 0],
        [0, D / 2 + 1.1, W + 3.6, 1.65, 0],
        [-W / 2 - 1.1, 0, 1.65, D + 3.6, 0],
        [W / 2 + 1.1, 0, 1.65, D + 3.6, 0]
      ];
      segments.forEach(function (s) {
        excavationFootings.add(box(s[2], 0.32, s[3], matSoil, [s[0], trenchY, s[1]]));
      });
      for (var st = 0; st < 18; st++) {
        var edge = st % 4;
        var px = edge < 2 ? rand(-W / 2, W / 2) : (edge === 2 ? -W / 2 - 1.0 : W / 2 + 1.0);
        var pz = edge < 2 ? (edge === 0 ? -D / 2 - 1.0 : D / 2 + 1.0) : rand(-D / 2, D / 2);
        excavationFootings.add(box(rand(1.1, 2.0), 0.52, rand(0.8, 1.5), st % 2 ? matStone : matStoneDark,
          [px, 0.52, pz], [0, rand(-0.28, 0.28), 0]));
      }
    }
  })();
  tagMaterials(excavationFootings);
  reg(excavationFootings, { appear: [0.06, 0.17], remove: [0.48, 0.74] });

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

  var joineryPins = new THREE.Group();
  joineryPins.name = 'joineryPins';
  (function buildJoineryPins() {
    var pegMat = M(0x2d1d12, { kind: 'wood', roughness: 0.92 });
    var braceMat = M(0x9b7044, { kind: 'plank', roughness: 0.88 });
    if (isRound) {
      for (var ji = 0; ji < 12; ji++) {
        var a = (ji / 12) * Math.PI * 2;
        var x = Math.cos(a) * RAD, z = Math.sin(a) * RAD;
        var peg = cyl(0.18, 0.22, 1.6, pegMat, [x, WALL_H + 2.6 + (ji % 2) * 1.4, z], [Math.PI / 2, 0, -a], 7);
        joineryPins.add(peg);
        var brace = cyl(0.16, 0.2, 5.5, braceMat, [x * 0.88, WALL_H * 0.78, z * 0.88], [0.34, -a, 0.58], 6);
        joineryPins.add(brace);
      }
    } else {
      cornersRect.forEach(function (c, ci) {
        var next = cornersRect[(ci + 1) % 4];
        var ang = Math.atan2(next[1] - c[1], next[0] - c[0]);
        for (var pi = 0; pi < 3; pi++) {
          var t = (pi + 1) / 4;
          var x = c[0] + (next[0] - c[0]) * t;
          var z = c[1] + (next[1] - c[1]) * t;
          var peg = cyl(0.16, 0.2, 1.5, pegMat, [x, WALL_H + 2.5, z], [Math.PI / 2, 0, -ang], 7);
          joineryPins.add(peg);
        }
      });
      [[-1, -1], [1, -1], [-1, 1], [1, 1]].forEach(function (corner) {
        var brace = cyl(0.18, 0.22, 7.0, braceMat,
          [corner[0] * (W / 2 - 2.2), WALL_H * 0.7, corner[1] * (D / 2 - 2.0)],
          [0.42 * corner[1], 0, 0.5 * corner[0]], 6);
        joineryPins.add(brace);
      });
    }
  })();
  tagMaterials(joineryPins);
  reg(joineryPins, { appear: [0.46, 0.61], remove: [0.82, 0.94] });

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

  function makeConstructionHoist() {
    var hoist = new THREE.Group();
    var mastH = WALL_H + 12;
    var mast = cyl(0.34, 0.45, mastH, matWoodDark, [-W * 0.62, mastH / 2 + 1, D * 0.5], [0.03, 0, -0.04], 7);
    var boom = cyl(0.28, 0.32, W * 0.78, matWoodLight, [-W * 0.25, mastH - 1, D * 0.5], null, 7);
    boom.rotation.set(0, -0.12, Math.PI / 2);
    var brace = cyl(0.18, 0.22, W * 0.68, matWoodRaw, [-W * 0.4, mastH * 0.73, D * 0.5], null, 6);
    brace.rotation.set(0.3, -0.04, Math.PI / 2);
    var pulley = new THREE.Mesh(new THREE.TorusGeometry(1.0, 0.18, 8, 18), matMetal);
    pulley.position.set(W * 0.06, mastH - 1.0, D * 0.5); pulley.rotation.y = Math.PI / 2; pulley.castShadow = true;
    var ropeLine = cyl(0.08, 0.08, mastH * 0.55, matRope, [W * 0.06, mastH * 0.64, D * 0.5], null, 5);
    var hook = new THREE.Group();
    hook.position.set(W * 0.06, mastH * 0.38, D * 0.5);
    hook.add(cyl(0.08, 0.08, 3.0, matMetal, [0, 0.8, 0], null, 5));
    var hookLoop = new THREE.Mesh(new THREE.TorusGeometry(0.55, 0.12, 8, 16), matMetal);
    hookLoop.position.y = -0.9; hookLoop.rotation.x = Math.PI / 2; hookLoop.castShadow = true; hook.add(hookLoop);
    var bundle = new THREE.Group();
    bundle.position.set(W * 0.06, mastH * 0.28, D * 0.5);
    for (var hb = 0; hb < 3; hb++) {
      bundle.add(box(7.0, 0.55, 1.4, hb % 2 ? matWoodLight : matWoodRaw, [0, hb * 0.62, (hb - 1) * 1.0], [0, rand(-0.08, 0.08), 0]));
    }
    bundle.add(cyl(0.10, 0.10, 6.8, matRope, [0, 1.1, 0], [Math.PI / 2, 0, Math.PI / 2], 5));
    hoist.add(mast); hoist.add(boom); hoist.add(brace); hoist.add(pulley); hoist.add(ropeLine); hoist.add(hook); hoist.add(bundle);
    hoist.userData.hook = hook;
    hoist.userData.bundle = bundle;
    hoist.userData.ropeLine = ropeLine;
    hoist.userData.baseHookY = hook.position.y;
    hoist.userData.baseBundleY = bundle.position.y;
    return hoist;
  }
  var hoist = makeConstructionHoist();
  tagMaterials(hoist);
  reg(hoist, {
    appear: [0.28, 0.38],
    remove: [0.76, 0.9],
    motion: function (obj, p, a, vis, time) {
      var lift = ramp(p, 0.38, 0.78);
      var clock = time != null ? time : p * 12;
      var wobble = Math.sin(clock * 2.1 + seed) * 0.45 * (1 - lift * 0.55);
      if (obj.userData.hook) {
        obj.userData.hook.position.y = obj.userData.baseHookY + lift * 8.0 + wobble;
        obj.userData.hook.rotation.z = Math.sin(clock * 1.6 + seed) * 0.08;
      }
      if (obj.userData.bundle) {
        obj.userData.bundle.position.y = obj.userData.baseBundleY + lift * 8.0 + wobble;
        obj.userData.bundle.rotation.y = Math.sin(clock * 1.25 + seed) * 0.12;
      }
      if (obj.userData.ropeLine) obj.userData.ropeLine.scale.y = Math.max(0.18, 1 - lift * 0.34);
    }
  });

  function makeConstructionMotes() {
    var motes = new THREE.Group();
    var dustMat = M(0xd8c9ab, { kind: 'linen', roughness: 1.0, transparent: true, opacity: 0.5 });
    for (var mi = 0; mi < 18; mi++) {
      var mote = new THREE.Mesh(new THREE.SphereGeometry(rand(0.12, 0.32), 8, 6), dustMat);
      mote.position.set(rand(-W * 0.55, W * 0.55), rand(1.0, WALL_H + 3.0), rand(-D * 0.5, D * 0.55));
      mote.userData.home = mote.position.clone();
      mote.userData.phase = rand(0, Math.PI * 2);
      motes.add(mote);
    }
    var chalkLine = box(W * 0.9, 0.12, 0.12, matRope, [0, 0.45, D / 2 + 2.8], [0, 0.04, 0]);
    motes.add(chalkLine);
    return motes;
  }
  var constructionMotes = makeConstructionMotes();
  tagMaterials(constructionMotes);
  reg(constructionMotes, {
    appear: [0.22, 0.28],
    remove: [0.72, 0.9],
    motion: function (obj, p, a, vis, time) {
      var clock = time != null ? time : p * 10;
      var intensity = Math.sin(ramp(p, 0.2, 0.7) * Math.PI);
      obj.children.forEach(function (child, idx) {
        if (!child.userData || !child.userData.home) return;
        child.position.x = child.userData.home.x + Math.sin(clock * 2.8 + child.userData.phase) * 0.75 * intensity;
        child.position.y = child.userData.home.y + Math.sin(clock * 3.4 + child.userData.phase) * 1.3 * intensity;
        child.position.z = child.userData.home.z + Math.cos(clock * 2.2 + child.userData.phase) * 0.75 * intensity;
        child.scale.setScalar(0.55 + intensity * (0.45 + (idx % 3) * 0.12));
      });
    }
  });

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

  var roofWeathering = new THREE.Group();
  roofWeathering.name = 'roofWeathering';
  (function buildRoofWeathering() {
    var strawCord = M(0xd2b16e, { kind: 'thatch', roughness: 1.0 });
    if (isRound) {
      for (var rw = 0; rw < 18; rw++) {
        var a = (rw / 18) * Math.PI * 2;
        var rr = RAD * rand(0.42, 0.94);
        var y = WALL_H + 4.0 + (ridgeY - WALL_H - 4.0) * rand(0.05, 0.7);
        var patch = box(rand(2.2, 4.2), 0.26, rand(0.9, 1.8), rw % 3 === 0 ? matMoss : strawCord,
          [Math.cos(a) * rr, y, Math.sin(a) * rr], [rand(-0.18, 0.18), -a, rand(-0.14, 0.14)]);
        roofWeathering.add(patch);
      }
    } else {
      for (var side = -1; side <= 1; side += 2) {
        for (var i = 0; i < 10; i++) {
          var t = i / 9;
          var x = side * (W / 2) * (1 - t * 0.72) + rand(-0.4, 0.4);
          var y = WALL_H + 2.8 + (ridgeY - WALL_H - 2.8) * t;
          var z = rand(-D / 2 + 1.4, D / 2 - 1.4);
          var strip = box(rand(2.5, 5.0), 0.3, rand(0.9, 1.6), i % 4 === 0 ? matMoss : strawCord,
            [x, y, z], [0, Math.PI / 2, side * 0.55]);
          roofWeathering.add(strip);
        }
      }
    }
    for (var tuft = 0; tuft < 9; tuft++) {
      var tx = rand(-W * 0.42, W * 0.42);
      var tz = rand(-D * 0.45, D * 0.45);
      var ty = WALL_H + 2.6 + rand(0.4, ridgeY - WALL_H - 1.8);
      var grass = new THREE.Group();
      grass.position.set(tx, ty, tz);
      for (var blade = 0; blade < 4; blade++) {
        var b = cyl(0.045, 0.07, rand(1.3, 2.4), matLeaf, [rand(-0.35, 0.35), rand(0.6, 1.1), rand(-0.25, 0.25)],
          [rand(-0.35, 0.35), 0, rand(-0.28, 0.28)], 5);
        grass.add(b);
      }
      roofWeathering.add(grass);
    }
  })();
  tagMaterials(roofWeathering);
  reg(roofWeathering, { appear: [0.77, 0.9] });

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

  var finishTrim = new THREE.Group();
  finishTrim.name = 'finishTrim';
  (function buildFinishTrim() {
    var frontZ = isRound ? RAD + 0.58 : D / 2 + 0.58;
    var trimMat = M(0xb38b58, { kind: 'plank', roughness: 0.86 });
    var ironMat = M(0x2f2d29, { kind: 'metal', roughness: 0.48, metalness: 0.52 });
    finishTrim.add(box(6.2, 0.42, 0.42, trimMat, [0, 10.9, frontZ + 0.25]));
    finishTrim.add(box(0.42, 8.8, 0.42, trimMat, [-3.05, 6.5, frontZ + 0.25]));
    finishTrim.add(box(0.42, 8.8, 0.42, trimMat, [3.05, 6.5, frontZ + 0.25]));
    finishTrim.add(box(5.4, 0.32, 0.26, ironMat, [-0.05, 8.8, frontZ + 0.72], [0, 0, 0.12]));
    finishTrim.add(box(5.4, 0.32, 0.26, ironMat, [0.05, 4.2, frontZ + 0.72], [0, 0, -0.12]));
    var handle = new THREE.Mesh(new THREE.TorusGeometry(0.52, 0.12, 8, 18), ironMat);
    handle.name = 'doorRingHandle';
    handle.position.set(1.65, 6.4, frontZ + 0.88);
    handle.rotation.x = Math.PI / 2;
    handle.castShadow = true;
    finishTrim.add(handle);
    for (var wi = 0; wi < 2; wi++) {
      var wx = wi ? W / 4 : -W / 4;
      finishTrim.add(box(4.8, 0.35, 0.35, trimMat, [wx, 9.85, frontZ + 0.18]));
      finishTrim.add(box(4.8, 0.35, 0.35, trimMat, [wx, 5.1, frontZ + 0.18]));
      finishTrim.add(box(0.35, 4.6, 0.35, trimMat, [wx - 2.2, 7.45, frontZ + 0.18]));
      finishTrim.add(box(0.35, 4.6, 0.35, trimMat, [wx + 2.2, 7.45, frontZ + 0.18]));
    }
  })();
  tagMaterials(finishTrim);
  reg(finishTrim, { appear: [0.88, 0.96] });

  var moveInDetails = new THREE.Group();
  moveInDetails.name = 'moveInDetails';
  (function buildMoveInDetails() {
    var frontZ = isRound ? RAD + 1.8 : D / 2 + 1.8;
    var crateMat = M(0x7b5635, { kind: 'plank', roughness: 0.9 });
    var clothMat = M(0xe0c786, { kind: 'linen', roughness: 0.96 });
    var warmMat = M(0xffd07a, { kind: 'glass', emissive: 0xffbd55, emissiveIntensity: 0.42, transparent: true, opacity: 0.72 });
    var bench = new THREE.Group();
    bench.position.set(-7.5, 0, frontZ + 1.1);
    bench.add(box(5.8, 0.5, 1.4, crateMat, [0, 2.6, 0]));
    [-2.2, 2.2].forEach(function (x) {
      bench.add(cyl(0.18, 0.25, 2.7, matWoodDark, [x, 1.25, -0.45], [0.12, 0, 0.05], 6));
      bench.add(cyl(0.18, 0.25, 2.7, matWoodDark, [x, 1.25, 0.45], [-0.12, 0, 0.05], 6));
    });
    moveInDetails.add(bench);

    for (var c = 0; c < 3; c++) {
      var crate = box(2.3, 1.6, 2.0, crateMat, [6.2 + c * 1.8, 0.8 + c * 0.16, frontZ + 0.8 + (c % 2) * 1.2], [0, c * 0.16, 0]);
      moveInDetails.add(crate);
    }
    var basket = new THREE.Mesh(new THREE.TorusGeometry(1.15, 0.25, 8, 22), M(0xb88d55, { kind: 'wool', roughness: 0.98 }));
    basket.name = 'welcomeBasket';
    basket.rotation.x = Math.PI / 2;
    basket.position.set(4.4, 1.2, frontZ + 3.3);
    basket.castShadow = true;
    moveInDetails.add(basket);
    for (var f = 0; f < 7; f++) {
      var stem = cyl(0.04, 0.05, 1.5, matLeaf, [4.4 + rand(-0.8, 0.8), 1.9, frontZ + 3.3 + rand(-0.55, 0.55)], [rand(-0.3, 0.3), 0, rand(-0.35, 0.35)], 5);
      moveInDetails.add(stem);
      moveInDetails.add(sph(0.18, f % 2 ? matPetal : matLeaf, [stem.position.x, 2.75 + rand(-0.12, 0.12), stem.position.z]));
    }
    var curtainL = box(1.0, 3.4, 0.08, clothMat, [-W / 4 - 1.2, 7.4, frontZ + 0.72], [0, 0.03, 0.05]);
    var curtainR = box(1.0, 3.4, 0.08, clothMat, [W / 4 + 1.2, 7.4, frontZ + 0.72], [0, -0.03, -0.05]);
    moveInDetails.add(curtainL);
    moveInDetails.add(curtainR);
    var porchLantern = new THREE.Mesh(new THREE.SphereGeometry(0.95, 14, 10), warmMat);
    porchLantern.name = 'moveInPorchGlow';
    porchLantern.position.set(-3.8, 9.8, frontZ + 0.9);
    porchLantern.scale.set(1.3, 1.3, 0.7);
    porchLantern.castShadow = false;
    moveInDetails.add(porchLantern);
    var littleSign = box(3.2, 1.0, 0.18, crateMat, [0, 3.0, frontZ + 3.6], [0, 0.06, 0]);
    littleSign.name = 'freshlyBuiltSign';
    moveInDetails.add(littleSign);
  })();
  tagMaterials(moveInDetails);
  reg(moveInDetails, {
    appear: [0.94, 1.0],
    motion: function (obj, p, a, vis, time) {
      var clock = time != null ? time : p * 12;
      var glowObj = obj.getObjectByName && obj.getObjectByName('moveInPorchGlow');
      if (glowObj && glowObj.material) glowObj.material.opacity = (0.12 + a * 0.28) * (0.9 + Math.sin(clock * 4.1) * 0.08);
    }
  });

  /* ===== setProgress(p): single source of truth for the whole site ===== */
  function setProgress(p, time) {
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
      if (part.motion) part.motion(part.obj, p, a, vis, time);
    }
  }
  function stageName(p) {
    p = Math.max(0, Math.min(1, p));
    if (p < 0.08) return 'Survey & Supplies';
    if (p < 0.20) return 'Excavation & Footings';
    if (p < 0.34) return 'Foundation';
    if (p < 0.58) return 'Frame & Scaffold';
    if (p < 0.72) return 'Wall Raising';
    if (p < 0.86) return 'Roofing';
    if (p < 0.96) return 'Finish Trim';
    return 'Move-In Details';
  }
  function constructionStats(p) {
    p = Math.max(0, Math.min(1, p));
    var thresholds = [0.08, 0.20, 0.34, 0.58, 0.72, 0.86, 0.96, 1.01];
    var idx = thresholds.findIndex(function (limit) { return p < limit; });
    if (idx < 0) idx = thresholds.length - 1;
    return {
      stageIndex: idx,
      stageName: stageName(p),
      isHabitable: p >= 0.96,
      materialsRemaining: Math.max(0, 1 - ramp(p, 0.12, 0.92)),
      visibleCraftDetail: ramp(p, 0.46, 1.0)
    };
  }

  setProgress(0);
  return {
    group: group,
    setProgress: setProgress,
    stageName: stageName,
    constructionStats: constructionStats,
    smokeAnchor: smokeAnchor,
    type: type
  };
}
