/* ============================================================================
 * makeGnome — a rigged, human-bodied storybook gnome  (three.js r128, global THREE)
 * ----------------------------------------------------------------------------
 * BASE: Approach C's rig (joint Groups placed AT each pivot; limb geometry
 *       pre-translated so its TOP sits at the joint origin → clean fleshy bends,
 *       nested children follow a parent rotation for free; live mesh counter).
 * GRAFTED:
 *   - Approach B's richer clothing layering + 5-segment floppy felt cap chain
 *     (so the tip actually flops, not a rigid cone) + multi-lobe mustache.
 *   - Approach A's proportions (stocky ~3.75 heads) + _rest channel discipline.
 *
 * PROPORTIONS (stocky human, ~3.6-3.75 heads, ~26 world units sole→crown):
 *   hip pivot ...... y 10.6   legs short+sturdy (thigh 4.2 + shin 4.0 + boot)
 *   torso pivot .... y +1.6 above pelvis; shoulders broad (half-span 4.4)
 *   neck top ....... y 7.6 within torso; head sphere r3.5 (large, characterful)
 *   crown .......... ~26u; soft floppy cap towers above that.
 *   arms ........... upper 4.2 + fore 3.6 + hand ~1.8
 * RIG HIERARCHY (rotating a parent carries all its children):
 *   root → pelvis → torso(=spine) → neck → head(face+beard+hat)
 *                 → leftUpperArm  → leftForeArm  → leftHand
 *                 → rightUpperArm → rightForeArm → rightHand
 *          pelvis → leftThigh  → leftShin  → leftFoot
 *                 → rightThigh → rightShin → rightFoot
 * Coordinate system: Y up, ground = XZ at y=0, character faces +Z.
 * r128-safe: only Box/Cylinder/Sphere/Cone/Torus. No CapsuleGeometry, no loaders.
 * Mesh budget ~66 idle / ~68 with hammer — under the 70 cap.
 * Every solid mesh sets castShadow=true so it registers on the scene's
 * PCFSoft shadow map / ShadowMaterial contact plane.
 * ==========================================================================*/
function makeGnome(opts) {
  opts = opts || {};
  var hatColor   = opts.hatColor   !== undefined ? opts.hatColor   : 0xc0392b; // classic red felt
  var tunicColor = opts.tunicColor !== undefined ? opts.tunicColor : 0x2e6f4e; // forest-green jerkin
  var shirtColor = opts.shirtColor !== undefined ? opts.shirtColor : 0xe8d9b5; // cream long-sleeve
  var role       = opts.role       || 'idle';

  /* ---- palette ---- */
  var SKIN      = 0xe0a884, SKIN_D = 0xc98d6a, NOSE = 0xd99277;
  var BEARD     = opts.beardColor !== undefined ? opts.beardColor : 0xf2f2ee;
  var BEARD_D   = 0xdcd6c9, BROW = 0xe6e6e0;
  var LEATHER   = 0x5a3a22, LEATHER_D = 0x432a18, BUCKLE = 0xc9a227;
  var TROUSER   = opts.trouserColor !== undefined ? opts.trouserColor : 0x3a4a63;
  var EYE       = 0x20140c, WHITE = 0xffffff;

  function _darken(hex, f) {
    var r = ((hex >> 16) & 255) * f, g = ((hex >> 8) & 255) * f, b = (hex & 255) * f;
    return (Math.round(r) << 16) | (Math.round(g) << 8) | Math.round(b);
  }

  /* ---- material helper: uses host scene's mat(hex,opts) if present, else inline.
   *      NOTE: the host prototype's mat() is a closure local; when makeGnome is
   *      defined in the same closure it resolves; otherwise the fallback runs. ---- */
  function _M(color, o) {
    o = o || {};
    if (typeof mat === 'function') return mat(color, o);
    return new THREE.MeshStandardMaterial({
      color: color,
      roughness: o.roughness !== undefined ? o.roughness : 0.85,
      metalness: o.metalness !== undefined ? o.metalness : 0.0,
      emissive: o.emissive !== undefined ? o.emissive : 0x000000,
      emissiveIntensity: o.emissiveIntensity !== undefined ? o.emissiveIntensity : 0.0
    });
  }

  /* shared materials (few, to limit GPU state churn) */
  var matSkin     = _M(SKIN,        { roughness: 0.6 });
  var matSkinD    = _M(SKIN_D,      { roughness: 0.6 });
  var matNose     = _M(NOSE,        { roughness: 0.55 });
  var matBeard    = _M(BEARD,       { roughness: 0.95 });
  var matBeardD   = _M(BEARD_D,     { roughness: 0.96 });
  var matBrow     = _M(BROW,        { roughness: 0.95 });
  var matShirt    = _M(shirtColor,  { roughness: 0.9 });
  var matTunic    = _M(tunicColor,  { roughness: 0.85 });
  var matTunicD   = _M(_darken(tunicColor, 0.8), { roughness: 0.86 });
  var matHat      = _M(hatColor,    { roughness: 0.9 });
  var matHatD     = _M(_darken(hatColor, 0.82), { roughness: 0.92 });
  var matLeather  = _M(LEATHER,     { roughness: 0.7 });
  var matLeatherD = _M(LEATHER_D,   { roughness: 0.7 });
  var matBuckle   = _M(BUCKLE,      { roughness: 0.35, metalness: 0.7 });
  var matTrouser  = _M(TROUSER,     { roughness: 0.9 });
  var matEye      = _M(EYE,         { roughness: 0.3 });
  var matWhite    = _M(WHITE,       { roughness: 0.25 });
  var matCatch    = _M(WHITE,       { emissive: 0xffffff, emissiveIntensity: 0.9, roughness: 0.2 });

  var meshCount = 0;
  function add(parent, geo, material, x, y, z) {
    var m = new THREE.Mesh(geo, material);
    m.position.set(x || 0, y || 0, z || 0);
    m.castShadow = true; m.receiveShadow = false;
    parent.add(m); meshCount++;
    return m;
  }
  function grp(x, y, z) {
    var g = new THREE.Group();
    g.position.set(x || 0, y || 0, z || 0);
    return g;
  }
  /* tapered limb: cylinder whose TOP is at local y=0, body hanging down -len,
     so it pivots at the joint origin. rTop = radius at joint, rBot = far end. */
  function limbSeg(parent, rTop, rBot, len, material) {
    var geo = new THREE.CylinderGeometry(rTop, rBot, len, 12, 1, false);
    geo.translate(0, -len / 2, 0);
    var m = new THREE.Mesh(geo, material);
    m.castShadow = true; meshCount++;
    parent.add(m);
    return m;
  }
  function jointCap(parent, r, material) {
    var m = new THREE.Mesh(new THREE.SphereGeometry(r, 12, 10), material);
    m.castShadow = true; meshCount++;
    parent.add(m);
    return m;
  }

  var parts = {};

  /* ================= ROOT / PELVIS ================= */
  var root = new THREE.Group(); root.name = 'gnomeRoot';
  parts.root = root;

  var HIP_Y = 10.6;
  var pelvis = grp(0, HIP_Y, 0); parts.pelvis = pelvis; root.add(pelvis);
  // hip block (trousers), slightly squashed (wider than deep)
  add(pelvis, new THREE.SphereGeometry(4.2, 14, 10), matTrouser, 0, 0.2, 0).scale.set(1.18, 0.78, 0.95);

  /* ================= TORSO (spine→chest), clothing-rich ================= */
  var torso = grp(0, 1.6, 0); parts.torso = torso; parts.spine = torso; pelvis.add(torso);

  // rounded belly (shirt), low+forward paunch
  add(torso, new THREE.SphereGeometry(4.4, 16, 12), matShirt, 0, 1.4, 0.6).scale.set(1.12, 0.95, 1.04);
  // chest (broader up top) — the jerkin barrel
  var chest = add(torso, new THREE.SphereGeometry(4.6, 16, 12), matTunic, 0, 5.0, 0);
  chest.scale.set(1.18, 0.95, 0.92); parts.chest = chest;
  // jerkin yoke / shoulder seam (slightly darker)
  add(torso, new THREE.CylinderGeometry(4.7, 4.2, 2.0, 22), matTunicD, 0, 6.4, 0).scale.set(1.0, 1.0, 0.9);
  // shirt collar peeking at the neckline
  add(torso, new THREE.CylinderGeometry(1.7, 2.1, 1.4, 12), matShirt, 0, 7.4, 0.2);
  // front placket (darker tunic seam down the chest)
  add(torso, new THREE.BoxGeometry(0.8, 4.2, 0.4), matTunicD, 0, 4.4, 4.1);

  // tunic skirt flaring below the belt over the hips (stacked fold rings)
  add(torso, new THREE.CylinderGeometry(4.3, 5.2, 2.0, 20), matTunic,  0, 0.6, 0);
  add(torso, new THREE.CylinderGeometry(5.0, 5.6, 1.7, 20), matTunicD, 0, -0.8, 0.1);

  // wide leather belt + brass buckle (at the waist)
  add(torso, new THREE.CylinderGeometry(4.55, 4.55, 1.5, 22), matLeather, 0, 2.6, 0.1).scale.set(1.02, 1.0, 0.92);
  add(torso, new THREE.BoxGeometry(1.9, 1.6, 0.6), matBuckle, 0, 2.6, 4.4);

  /* ================= NECK ================= */
  var neck = grp(0, 7.6, 0.1); parts.neck = neck; torso.add(neck);
  add(neck, new THREE.CylinderGeometry(1.5, 1.7, 1.6, 12), matSkin, 0, 0.6, 0);

  /* ================= HEAD ================= */
  var head = grp(0, 1.5, 0); parts.head = head; neck.add(head);

  // skull / face
  add(head, new THREE.SphereGeometry(3.5, 18, 16), matSkin, 0, 2.0, 0).scale.set(1.0, 1.05, 0.98);
  // rosy cheeks
  add(head, new THREE.SphereGeometry(1.0, 10, 8), matSkinD, -1.9, 1.2, 2.5).scale.set(1, 0.7, 0.6);
  add(head, new THREE.SphereGeometry(1.0, 10, 8), matSkinD,  1.9, 1.2, 2.5).scale.set(1, 0.7, 0.6);
  // ears
  add(head, new THREE.SphereGeometry(0.8, 8, 8), matSkin, -3.3, 2.0, 0).scale.set(0.6, 1.0, 0.8);
  add(head, new THREE.SphereGeometry(0.8, 8, 8), matSkin,  3.3, 2.0, 0).scale.set(0.6, 1.0, 0.8);

  // eyes — whites + dark iris + emissive catchlight
  var eyeY = 2.6, eyeZ = 3.0, eyeX = 1.25;
  add(head, new THREE.SphereGeometry(0.62, 10, 8), matWhite, -eyeX, eyeY, eyeZ).scale.set(1, 1.05, 0.6);
  add(head, new THREE.SphereGeometry(0.62, 10, 8), matWhite,  eyeX, eyeY, eyeZ).scale.set(1, 1.05, 0.6);
  add(head, new THREE.SphereGeometry(0.30, 8, 8), matEye, -eyeX, eyeY, eyeZ + 0.45);
  add(head, new THREE.SphereGeometry(0.30, 8, 8), matEye,  eyeX, eyeY, eyeZ + 0.45);
  add(head, new THREE.SphereGeometry(0.11, 6, 6), matCatch, -eyeX + 0.14, eyeY + 0.18, eyeZ + 0.7);
  add(head, new THREE.SphereGeometry(0.11, 6, 6), matCatch,  eyeX + 0.14, eyeY + 0.18, eyeZ + 0.7);

  // bushy eyebrows
  var browL = add(head, new THREE.BoxGeometry(1.3, 0.45, 0.5), matBrow, -eyeX, eyeY + 0.95, eyeZ + 0.2);
  var browR = add(head, new THREE.BoxGeometry(1.3, 0.45, 0.5), matBrow,  eyeX, eyeY + 0.95, eyeZ + 0.2);
  browL.rotation.z = 0.12; browR.rotation.z = -0.12;

  // BULBOUS NOSE — big rounded sphere out front
  var nose = add(head, new THREE.SphereGeometry(1.05, 12, 10), matNose, 0, 1.7, 3.4);
  nose.scale.set(0.95, 0.9, 1.15); parts.nose = nose;

  // MUSTACHE — two swept lobes under the nose
  var mustL = add(head, new THREE.SphereGeometry(1.0, 12, 9), matBeard, -1.0, 0.6, 3.0);
  var mustR = add(head, new THREE.SphereGeometry(1.0, 12, 9), matBeard,  1.0, 0.6, 3.0);
  mustL.scale.set(1.3, 0.55, 0.8); mustR.scale.set(1.3, 0.55, 0.8);
  mustL.rotation.z = 0.4; mustR.rotation.z = -0.4;

  // BIG LAYERED BEARD — stacked rounded masses tapering to a coned point
  add(head, new THREE.SphereGeometry(3.2, 16, 12), matBeard,  0, -0.6, 1.4).scale.set(1.15, 1.0, 0.95); // upper jaw mass
  add(head, new THREE.SphereGeometry(2.7, 14, 12), matBeardD, 0, -2.6, 1.7).scale.set(1.05, 1.1, 0.85); // mid (shadow tone)
  add(head, new THREE.ConeGeometry(2.2, 4.0, 14),  matBeard,  0, -5.0, 1.6);                            // flowing point
  add(head, new THREE.SphereGeometry(1.2, 10, 8),  matBeard, -2.9, -0.2, 1.0).scale.set(0.7, 1.2, 0.9); // cheek chops
  add(head, new THREE.SphereGeometry(1.2, 10, 8),  matBeard,  2.9, -0.2, 1.0).scale.set(0.7, 1.2, 0.9);

  // hair peeking under the hat (back/sides)
  add(head, new THREE.SphereGeometry(2.0, 12, 8), matBeard, -2.4, 3.4, -1.8).scale.set(0.8, 0.7, 0.9);
  add(head, new THREE.SphereGeometry(2.0, 12, 8), matBeard,  2.4, 3.4, -1.8).scale.set(0.8, 0.7, 0.9);

  /* ================= SOFT FLOPPY FELT CAP =================
   * Five stacked + progressively rotated cone segments in a nested chain,
   * so the tip curls/flops forward (NOT a rigid cone). The chain is exposed
   * on parts.hat so poseGnome can add secondary lag motion. */
  var hat = grp(0, 4.2, -0.2);
  parts.hatRoot = hat;
  head.add(hat);
  // brim band hugging the brow
  add(hat, new THREE.CylinderGeometry(3.7, 3.9, 1.1, 18), matHatD, 0, 0.2, 0.2);
  // base bell (wide, soft)
  add(hat, new THREE.ConeGeometry(3.6, 3.4, 18), matHat, 0, 2.0, 0.1);
  // segment 2 — starts to lean
  var hatSeg2 = grp(0, 2.9, 0.1); hatSeg2.rotation.set(0.18, 0, 0.06); hat.add(hatSeg2);
  add(hatSeg2, new THREE.ConeGeometry(2.6, 3.0, 16), matHat, 0, 1.2, 0);
  // segment 3 — leans more, curving forward/side
  var hatSeg3 = grp(0, 2.7, 0.25); hatSeg3.rotation.set(0.5, 0, 0.18); hatSeg2.add(hatSeg3);
  add(hatSeg3, new THREE.ConeGeometry(1.9, 2.8, 14), matHatD, 0, 1.1, 0);
  // segment 4 — the floppy bend
  var hatSeg4 = grp(0, 2.4, 0.2); hatSeg4.rotation.set(0.85, 0, 0.35); hatSeg3.add(hatSeg4);
  add(hatSeg4, new THREE.ConeGeometry(1.2, 2.4, 12), matHat, 0, 1.0, 0);
  // segment 5 — drooping tip + felt pom
  var hatSeg5 = grp(0, 2.1, 0.1); hatSeg5.rotation.set(1.0, 0, 0.45); hatSeg4.add(hatSeg5);
  add(hatSeg5, new THREE.ConeGeometry(0.6, 2.0, 12), matHatD, 0, 0.9, 0);
  add(hatSeg5, new THREE.SphereGeometry(0.65, 12, 9), matBeard, 0, 1.9, 0);
  parts.hat = { root: hat, seg2: hatSeg2, seg3: hatSeg3, seg4: hatSeg4, seg5: hatSeg5 };

  /* ================= ARMS (shoulder under torso → inherit torso motion) ================= */
  var SH_Y = 5.8, SH_X = 4.4;
  function buildArm(side) {
    var s = (side === 'left') ? 1 : -1;
    var upper = grp(SH_X * s, SH_Y, 0);
    upper.rotation.z = -0.18 * s; upper.rotation.x = 0.05;   // resting splay (not a T-pose)
    jointCap(upper, 1.7, matTunic);                           // shoulder cap
    limbSeg(upper, 1.5, 1.25, 4.2, matTunic);                 // upper sleeve (tunic)
    add(upper, new THREE.CylinderGeometry(1.4, 1.35, 0.7, 12), matShirt, 0, -3.6, 0); // shirt cuff peek

    var fore = grp(0, -4.2, 0);                               // elbow pivot
    jointCap(fore, 1.25, matShirt);
    limbSeg(fore, 1.2, 1.0, 3.6, matShirt);                   // forearm (shirt sleeve)
    add(fore, new THREE.CylinderGeometry(1.1, 1.15, 0.6, 12), matShirt, 0, -3.4, 0); // wrist cuff
    upper.add(fore);

    var hand = grp(0, -3.6, 0);                               // wrist pivot
    jointCap(hand, 1.0, matSkin);
    var palm = add(hand, new THREE.SphereGeometry(1.05, 12, 10), matSkin, 0, -0.9, 0.1);
    palm.scale.set(0.9, 1.1, 0.7);                            // mitten paddle
    add(hand, new THREE.SphereGeometry(0.78, 10, 8), matSkin, 0, -1.7, 0); // four-finger mitt tip
    var thumb = add(hand, new THREE.SphereGeometry(0.42, 10, 8), matSkin, 0.7 * s, -0.7, 0.35);
    thumb.scale.set(0.8, 1.2, 0.8);
    fore.add(hand);
    return { upper: upper, fore: fore, hand: hand };
  }
  var L = buildArm('left'), R = buildArm('right');
  torso.add(L.upper); torso.add(R.upper);
  parts.leftUpperArm = L.upper;  parts.leftForeArm = L.fore;  parts.leftHand = L.hand;
  parts.rightUpperArm = R.upper; parts.rightForeArm = R.fore; parts.rightHand = R.hand;

  /* ================= LEGS (anchored to pelvis; short, sturdy) ================= */
  var HIP_X = 2.2;
  function buildLeg(side) {
    var s = (side === 'left') ? 1 : -1;
    var thigh = grp(HIP_X * s, -1.2, 0);
    jointCap(thigh, 1.8, matTrouser);
    limbSeg(thigh, 1.7, 1.45, 4.2, matTrouser);

    var shin = grp(0, -4.2, 0);
    jointCap(shin, 1.45, matTrouser);
    limbSeg(shin, 1.4, 1.15, 4.0, matTrouser);
    thigh.add(shin);

    // turned-down leather boot (pivot at ankle)
    var foot = grp(0, -4.0, 0);
    jointCap(foot, 1.3, matLeather);                          // boot top / ankle
    var cuff = new THREE.Mesh(new THREE.CylinderGeometry(1.6, 1.4, 1.4, 12), matLeatherD);
    cuff.geometry.translate(0, -0.7, 0); cuff.castShadow = true; meshCount++; foot.add(cuff);
    var lower = new THREE.Mesh(new THREE.CylinderGeometry(1.4, 1.5, 1.6, 12), matLeather);
    lower.geometry.translate(0, -2.2, 0); lower.castShadow = true; meshCount++; foot.add(lower);
    add(foot, new THREE.BoxGeometry(2.2, 1.5, 4.2), matLeather, 0, -3.0, 1.4);     // sole/toe box forward (+Z)
    var toeCap = add(foot, new THREE.SphereGeometry(1.1, 10, 8), matLeather, 0, -3.0, 3.4);
    toeCap.scale.set(1.0, 0.7, 0.9);
    shin.add(foot);
    return { thigh: thigh, shin: shin, foot: foot };
  }
  var LL = buildLeg('left'), RL = buildLeg('right');
  pelvis.add(LL.thigh); pelvis.add(RL.thigh);
  parts.leftThigh = LL.thigh;  parts.leftShin = LL.shin;  parts.leftFoot = LL.foot;
  parts.rightThigh = RL.thigh; parts.rightShin = RL.shin; parts.rightFoot = RL.foot;

  /* ================= ROLE PROP — hammer parented to RIGHT HAND ================= */
  parts.hammer = null;
  if (role === 'build' || role === 'builder') {
    var handle = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.3, 4.5, 8), matLeatherD);
    handle.geometry.translate(0, -2.0, 0); handle.castShadow = true; meshCount++;
    var headM = new THREE.Mesh(new THREE.BoxGeometry(1.6, 1.2, 1.2), matBuckle);
    headM.position.set(0, -4.2, 0); headM.castShadow = true; meshCount++;
    var hammer = new THREE.Group();
    hammer.add(handle); hammer.add(headM);
    hammer.position.set(0, -1.2, 0.4); hammer.rotation.x = -0.4;
    parts.rightHand.add(hammer);
    parts.hammer = hammer;
  }

  /* rest values for poseGnome to return to a believable neutral */
  parts._rest = { leftUpperArmZ: 0.18, rightUpperArmZ: -0.18, upperArmX: 0.05 };
  parts._meshCount = meshCount;
  root.userData.height = 26;

  return { group: root, parts: parts };
}