/* ============================================================================
 * detail.js — ADDITIVE DETAIL GEOMETRY for the gnome village
 * ----------------------------------------------------------------------------
 * Two helpers that BOLT extra refinement onto the existing builders WITHOUT
 * touching their rigs:
 *
 *   addGnomeDetail(parts, opts)      // parts = the object returned by makeGnome
 *   addHouseDetail(group, type, opts)// group = a finished build-site / house grp
 *
 * Design rules honored:
 *   - three.js r128, global THREE. ONLY Box/Cylinder/Sphere/Cone/Torus/Plane.
 *     No CapsuleGeometry, no loaders, no modules.
 *   - Everything solid sets castShadow = true.
 *   - Each new mesh is parented to the CORRECT existing bone/group, so it
 *     inherits that bone's animation for free (a brooch on the chest rides the
 *     torso; boot laces ride the foot; the cap tip rides hatSeg5).
 *   - Material kit is resolved gracefully: texturedMat(color, kind) if the host
 *     defines it, else mat(color, opts), else an inline MeshStandardMaterial.
 *   - Idempotent: a `__detailed` flag stops a double-call from duplicating meshes.
 *
 * MESH BUDGET (gnome): ~19 extra meshes idle, ~21 with the optional belt pouch
 *   + brooch toggles. Comfortably inside the requested 15-25 range and the
 *   prototype's ~70 cap (gnome base is ~66).
 * ==========================================================================*/

/* ----------------------------------------------------------------------------
 * Shared, resilient material resolver.
 *   kind is a semantic hint for a future texturedMat() (e.g. 'leather','wood',
 *   'metal','cloth','hair') — harmless to the mat()/inline fallbacks.
 * --------------------------------------------------------------------------*/
function _detailMat(color, kind, o) {
  o = o || {};
  if (typeof texturedMat === 'function') {
    try { return texturedMat(color, kind, o); } catch (e) { /* fall through */ }
  }
  if (typeof mat === 'function') return mat(color, o);
  return new THREE.MeshStandardMaterial({
    color: color,
    roughness: o.roughness !== undefined ? o.roughness : 0.85,
    metalness: o.metalness !== undefined ? o.metalness : 0.0,
    emissive: o.emissive !== undefined ? o.emissive : 0x000000,
    emissiveIntensity: o.emissiveIntensity !== undefined ? o.emissiveIntensity : 0.0
  });
}

/* small add-helper local to detail.js (mirrors the builders' own `add`) */
function _dAdd(parent, geo, material, x, y, z, rx, ry, rz) {
  var m = new THREE.Mesh(geo, material);
  m.position.set(x || 0, y || 0, z || 0);
  if (rx || ry || rz) m.rotation.set(rx || 0, ry || 0, rz || 0);
  m.castShadow = true;
  m.receiveShadow = false;
  parent.add(m);
  return m;
}

/* ============================================================================
 * 1) addGnomeDetail(parts, opts)
 * ----------------------------------------------------------------------------
 * parts: the `parts` object from makeGnome (root, torso/chest, head, hat{...},
 *        leftHand, rightHand, leftFoot, rightFoot, leftForeArm, etc.)
 * opts:
 *   tunicColor / hatColor / beardColor — to tint detail in with the body
 *   brooch  (default true)  — a brass disc clasp on the tunic
 *   buttons (default true)  — two horn buttons down the placket
 *   pouch   (default false) — a leather belt pouch on the right hip
 *   beardColor — overrides beard tint for the extra strands
 *
 * Adds (parented to the right bone so it all animates):
 *   chest:  3 hand-stitched seam lines, 1 brooch OR 2 buttons
 *   head:   4 layered tapered beard strands (volume), 2 bushier brow tufts,
 *           an asymmetric mustache flick
 *   hat.seg5: a floppier, slightly off-axis tip nub (rides the cap chain)
 *   leftFoot/rightFoot: 2 crossed laces + a sole welt each
 *   pelvis: optional belt pouch
 * --------------------------------------------------------------------------*/
function addGnomeDetail(parts, opts) {
  opts = opts || {};
  if (!parts || !parts.head || parts.__detailed) return parts;

  var TUNIC_D  = opts.tunicColor !== undefined ? _darkenHex(opts.tunicColor, 0.78) : 0x24573d;
  var BEARD    = opts.beardColor !== undefined ? opts.beardColor : 0xf2f2ee;
  var BEARD_D  = _darkenHex(BEARD, 0.9);
  var LEATHER  = 0x5a3a22, LEATHER_D = 0x432a18;
  var LACE     = 0x8a6a48;
  var BRASS    = 0xc9a227;

  var matSeam   = _detailMat(TUNIC_D,  'cloth',   { roughness: 0.9 });
  var matBeard  = _detailMat(BEARD,    'hair',    { roughness: 0.96 });
  var matBeardD = _detailMat(BEARD_D,  'hair',    { roughness: 0.97 });
  var matBrow   = _detailMat(0xe6e6e0, 'hair',    { roughness: 0.95 });
  var matBrass  = _detailMat(BRASS,    'metal',   { roughness: 0.34, metalness: 0.7 });
  var matHorn   = _detailMat(0x2b2018, 'metal',   { roughness: 0.5, metalness: 0.2 });
  var matLace   = _detailMat(LACE,     'leather', { roughness: 0.8 });
  var matLeather  = _detailMat(LEATHER,   'leather', { roughness: 0.7 });
  var matLeatherD = _detailMat(LEATHER_D, 'leather', { roughness: 0.72 });

  /* ---- CHEST: hand-stitched seams + clasp ---- */
  var chest = parts.chest || parts.torso;
  if (chest) {
    // 3 short angled seam stitches along the jerkin shoulder/placket
    var seamGeo = new THREE.BoxGeometry(0.18, 1.5, 0.16);
    _dAdd(chest, seamGeo, matSeam, -2.7, 1.0, 3.9, 0, 0, 0.22);
    _dAdd(chest, seamGeo, matSeam,  2.7, 1.0, 3.9, 0, 0, -0.22);
    _dAdd(chest, new THREE.BoxGeometry(0.18, 2.2, 0.16), matSeam, 0, 1.2, 4.25);

    var wantBrooch  = opts.brooch  !== false;
    var wantButtons = opts.buttons !== false && !wantBrooch;
    if (wantBrooch) {
      // brass brooch / clasp at the collar — torus + center stud
      var brooch = _dAdd(chest, new THREE.TorusGeometry(0.62, 0.22, 8, 16), matBrass, 0, 3.0, 4.05);
      brooch.rotation.x = Math.PI / 2;
      _dAdd(chest, new THREE.SphereGeometry(0.34, 10, 8), matBrass, 0, 3.0, 4.25);
    }
    if (wantButtons) {
      // two horn buttons down the placket
      _dAdd(chest, new THREE.CylinderGeometry(0.34, 0.34, 0.22, 12), matHorn, 0, 2.0, 4.2, Math.PI / 2, 0, 0);
      _dAdd(chest, new THREE.CylinderGeometry(0.34, 0.34, 0.22, 12), matHorn, 0, 0.4, 4.2, Math.PI / 2, 0, 0);
    }
  }

  /* ---- HEAD: richer multi-strand beard + bushier brows + mustache flick ---- */
  var head = parts.head;
  // 4 thin tapered cones layered over the existing beard mass for volume.
  // beard sits roughly head-local y -0.6..-5, z ~1.4-1.7, faces +Z.
  var strandSpec = [
    [-1.5, -3.6, 1.9, 0.55, 4.6,  0.10],
    [-0.5, -4.3, 2.0, 0.5,  5.2,  0.03],
    [ 0.7, -4.1, 2.0, 0.5,  5.0, -0.05],
    [ 1.6, -3.5, 1.9, 0.55, 4.4, -0.12]
  ];
  strandSpec.forEach(function (s, i) {
    var strand = _dAdd(head,
      new THREE.ConeGeometry(s[3], s[4], 9),
      (i % 2) ? matBeardD : matBeard,
      s[0], s[1], s[2]);
    strand.rotation.x = Math.PI;     // point downward like the host beard cone
    strand.rotation.z = s[5];        // slight individual sway
  });

  // bushier eyebrow tufts sitting just over the existing box brows
  // (host eyes: y2.6 z3.0, brows at y ~3.55 z3.2)
  var browTuftGeo = new THREE.SphereGeometry(0.55, 10, 8);
  var browTL = _dAdd(head, browTuftGeo, matBrow, -1.25, 3.6, 3.35);
  var browTR = _dAdd(head, browTuftGeo, matBrow,  1.25, 3.6, 3.35);
  browTL.scale.set(1.35, 0.6, 0.7); browTL.rotation.z = 0.16;
  browTR.scale.set(1.35, 0.6, 0.7); browTR.rotation.z = -0.16;

  // asymmetric mustache flick (one side curls up a touch more — character)
  var flick = _dAdd(head, new THREE.ConeGeometry(0.3, 1.4, 8), matBeard, -1.7, 0.7, 3.0);
  flick.rotation.set(0, 0, 1.15);

  /* ---- HAT: floppier, slightly asymmetric tip riding the cap chain ---- */
  if (parts.hat && parts.hat.seg5) {
    var tip = _dAdd(parts.hat.seg5, new THREE.ConeGeometry(0.34, 1.1, 10), matBeard, 0.18, 1.4, 0.1);
    tip.rotation.set(0.35, 0, 0.28);   // extra droop + sideways lean = asymmetry
  }

  /* ---- BOOTS: crossed laces + a defined sole welt (per foot) ---- */
  // host foot: boot top jointCap at y0, sole box at y-3.0 z1.4, toe at z3.4
  function dressBoot(foot) {
    if (!foot) return;
    // sole welt — a thin lighter rim running under the boot toe box
    _dAdd(foot, new THREE.BoxGeometry(2.4, 0.4, 4.6), matLeatherD, 0, -3.85, 1.5);
    // two crossed laces over the instep
    var laceGeo = new THREE.CylinderGeometry(0.1, 0.1, 2.4, 6);
    var laceA = _dAdd(foot, laceGeo, matLace, 0, -2.0, 2.4);
    laceA.rotation.set(0, 0, 0.7);
    var laceB = _dAdd(foot, laceGeo, matLace, 0, -2.0, 2.4);
    laceB.rotation.set(0, 0, -0.7);
  }
  dressBoot(parts.leftFoot);
  dressBoot(parts.rightFoot);

  /* ---- OPTIONAL belt pouch on the right hip (rides the pelvis) ---- */
  if (opts.pouch && parts.pelvis) {
    var pouch = new THREE.Group();
    pouch.position.set(2.9, -0.4, 2.2);
    pouch.rotation.z = -0.12;
    _dAdd(pouch, new THREE.SphereGeometry(1.3, 12, 10), matLeather, 0, 0, 0).scale.set(0.9, 1.0, 0.7);
    _dAdd(pouch, new THREE.BoxGeometry(1.8, 0.7, 0.4), matLeatherD, 0, 0.9, 0.6); // flap
    _dAdd(pouch, new THREE.SphereGeometry(0.22, 8, 6), matBrass, 0, 0.5, 0.85);   // stud
    pouch.traverse(function (n) { if (n.isMesh) n.castShadow = true; });
    parts.pelvis.add(pouch);
  }

  parts.__detailed = true;
  return parts;
}

/* local hex darken (the gnome builder has its own private one) */
function _darkenHex(hex, f) {
  var r = ((hex >> 16) & 255) * f, g = ((hex >> 8) & 255) * f, b = (hex & 255) * f;
  return (Math.round(r) << 16) | (Math.round(g) << 8) | Math.round(b);
}

/* ============================================================================
 * 2) addHouseDetail(group, type, opts)
 * ----------------------------------------------------------------------------
 * group: a finished structure Object3D (the `.group` from makeBuildSite, or a
 *        makeHouse() group). type: 'cabin' | 'roundhouse' | 'tower' | 'cottage'
 *        | 'hall' (anything non-round is treated rectangular).
 * opts (all optional — defaults match makeBuildSite's plan so it works out of
 *       the box on finished build sites):
 *   W, D, RAD, WALL_H, ridgeY  — footprint/height used to place trim
 *   doorWidth, doorHeight
 *   accent (default true)      — roof-edge shingle/thatch tufts
 *
 * Adds: window frames + mullion cross over each face window, a plank door with
 *       two iron hinges + a ring handle, a doorstep stone, a run of roof-edge
 *       shingle tufts, and a chimney cap. All castShadow, all parented to group.
 *
 * NOTE: this is purely additive trim layered on TOP of the existing finished
 *       geometry — it does not move or rescale the host meshes.
 * --------------------------------------------------------------------------*/
function addHouseDetail(group, type, opts) {
  opts = opts || {};
  if (!group || group.__detailed) return group;
  type = type || 'cabin';
  var isRound = (type === 'roundhouse');
  var isTower = (type === 'tower');

  // default plan = makeBuildSite's plan; override via opts for makeHouse/tower
  var W      = opts.W      != null ? opts.W      : 22;
  var D      = opts.D      != null ? opts.D      : 18;
  var RAD    = opts.RAD    != null ? opts.RAD    : (isTower ? 6 : 11);
  var WALL_H = opts.WALL_H != null ? opts.WALL_H : 12;
  var ridgeY = opts.ridgeY != null ? opts.ridgeY : (WALL_H + 2.4 + (isRound ? 8 : 7));

  var matWoodDark  = _detailMat(0x47301d, 'wood',    { roughness: 0.9 });
  var matWoodLight = _detailMat(0xb6915f, 'wood',    { roughness: 0.86 });
  var matIron      = _detailMat(0x3b3833, 'metal',   { roughness: 0.5, metalness: 0.65 });
  var matThatch    = _detailMat(0xc59f5e, 'thatch',  { roughness: 1.0 });
  var matStone     = _detailMat(0x8d8a82, 'stone',   { roughness: 0.95 });

  /* radius/half-extent of the front face along +Z */
  var frontZ = isRound || isTower ? RAD + 0.2 : D / 2 + 0.2;

  /* ---- WINDOW frames + mullion cross over each window opening ----
     window centers mirror makeBuildSite (y 7.5) / can be overridden. */
  var winY = opts.winY != null ? opts.winY : 7.5;
  var winSpecs;
  if (isRound) {
    winSpecs = [Math.PI * 0.35, Math.PI * 1.0, Math.PI * 1.65].map(function (a) {
      return { x: Math.cos(a) * (RAD + 0.25), z: Math.sin(a) * (RAD + 0.25), ry: -a };
    });
  } else if (isTower) {
    winSpecs = [{ x: 0, z: RAD + 0.25, ry: 0 }];
  } else {
    winSpecs = [
      { x: -W / 4, z: D / 2 + 0.25, ry: 0 },
      { x:  W / 4, z: D / 2 + 0.25, ry: 0 },
      { x:  W / 2 + 0.25, z: 0, ry: Math.PI / 2 },
      { x: -W / 2 - 0.25, z: 0, ry: Math.PI / 2 }
    ];
  }
  winSpecs.forEach(function (s) {
    var win = new THREE.Group();
    win.position.set(s.x, winY, s.z);
    win.rotation.y = s.ry;
    // 4-side frame (top/bottom/left/right bars)
    _dAdd(win, new THREE.BoxGeometry(4.6, 0.5, 0.6), matWoodDark, 0,  2.1, 0);
    _dAdd(win, new THREE.BoxGeometry(4.6, 0.5, 0.6), matWoodDark, 0, -2.1, 0);
    _dAdd(win, new THREE.BoxGeometry(0.5, 4.6, 0.6), matWoodDark, -2.1, 0, 0);
    _dAdd(win, new THREE.BoxGeometry(0.5, 4.6, 0.6), matWoodDark,  2.1, 0, 0);
    // mullion cross
    _dAdd(win, new THREE.BoxGeometry(4.0, 0.32, 0.5), matWoodLight, 0, 0, 0.15);
    _dAdd(win, new THREE.BoxGeometry(0.32, 4.0, 0.5), matWoodLight, 0, 0, 0.15);
    // small sill
    _dAdd(win, new THREE.BoxGeometry(5.0, 0.5, 1.1), matWoodLight, 0, -2.4, 0.3);
    group.add(win);
  });

  /* ---- PLANK DOOR detail: vertical planks face, iron hinges + ring handle ---- */
  var door = new THREE.Group();
  door.position.set(0, 0, frontZ + 0.35);
  var dW = opts.doorWidth  != null ? opts.doorWidth  : 5;
  var dH = opts.doorHeight != null ? opts.doorHeight : 8;
  var dCY = dH / 2 + 2.0;
  // 3 vertical planks
  for (var p = -1; p <= 1; p++) {
    _dAdd(door, new THREE.BoxGeometry(dW / 3 - 0.15, dH, 0.3), matWoodDark, p * (dW / 3), dCY, 0);
  }
  // two iron Z-brace battens
  _dAdd(door, new THREE.BoxGeometry(dW + 0.4, 0.5, 0.2), matIron, 0, dCY + dH * 0.28, 0.2);
  _dAdd(door, new THREE.BoxGeometry(dW + 0.4, 0.5, 0.2), matIron, 0, dCY - dH * 0.28, 0.2);
  // two iron hinges on the hinge side
  _dAdd(door, new THREE.BoxGeometry(0.6, 1.4, 0.25), matIron, -dW / 2 - 0.1, dCY + dH * 0.28, 0.22);
  _dAdd(door, new THREE.BoxGeometry(0.6, 1.4, 0.25), matIron, -dW / 2 - 0.1, dCY - dH * 0.28, 0.22);
  // ring handle (torus) on the latch side
  var handle = _dAdd(door, new THREE.TorusGeometry(0.45, 0.14, 8, 16), matIron, dW / 2 - 0.6, dCY, 0.4);
  handle.rotation.x = Math.PI / 2;
  group.add(door);

  /* ---- DOORSTEP stone slab in front of the door ---- */
  _dAdd(group, new THREE.BoxGeometry(dW + 2.5, 1.0, 3.0), matStone, 0, 0.5, frontZ + 1.8);

  /* ---- ROOF-EDGE accent: shingle / thatch tufts along the eave ---- */
  if (opts.accent !== false) {
    var eaveY = WALL_H + 2.4;       // top of walls (matches makeBuildSite)
    var tuftGeo = new THREE.BoxGeometry(2.2, 0.5, 1.4);
    if (isRound || isTower) {
      var nE = isTower ? 10 : 16;
      for (var e = 0; e < nE; e++) {
        var ae = (e / nE) * Math.PI * 2;
        var tuft = _dAdd(group, tuftGeo, matThatch,
          Math.cos(ae) * (RAD + 0.6), eaveY + 0.3, Math.sin(ae) * (RAD + 0.6));
        tuft.rotation.y = -ae;
        tuft.rotation.x = -0.3;
      }
    } else {
      // run tufts along the two long eaves (front +Z, back -Z)
      var span = 7;
      for (var f = 0; f < span; f++) {
        var fx = -W / 2 + (f + 0.5) * (W / span);
        var tF = _dAdd(group, tuftGeo, matThatch, fx, eaveY + 0.3,  D / 2 + 0.4);
        tF.rotation.x = -0.32;
        var tB = _dAdd(group, tuftGeo, matThatch, fx, eaveY + 0.3, -D / 2 - 0.4);
        tB.rotation.x = 0.32;
      }
    }
  }

  /* ---- CHIMNEY CAP — a small stone slab + flue collar at the ridge ----
     placement mirrors makeBuildSite's chimney (cabin: W/2-4, -D/4 ; round: inset) */
  var cx = isRound || isTower ? RAD * 0.45 : W / 2 - 4;
  var cz = isRound || isTower ? -RAD * 0.4 : -D / 4;
  var chTop = ridgeY + 4;
  _dAdd(group, new THREE.BoxGeometry(4.6, 0.8, 4.6), matStone, cx, chTop + 0.6, cz);   // cap slab
  _dAdd(group, new THREE.CylinderGeometry(1.0, 1.2, 1.4, 10), matIron, cx, chTop + 1.5, cz); // flue collar

  group.__detailed = true;
  return group;
}

/* expose for non-closure script tags (matches gnome.js/buildsite.js global style) */
if (typeof window !== 'undefined') {
  window.addGnomeDetail = addGnomeDetail;
  window.addHouseDetail = addHouseDetail;
}
