/* ============================================================================
 * poseGnome(parts, t, action, opts)  — v2, empirically-corrected directions
 *   parts  : named bone hierarchy from makeGnome().parts
 *   t      : time in SECONDS
 *   action : 'idle' | 'walk' | 'carry' | 'build' | 'lift' | 'cheer'
 *            | 'chat' | 'forage' | 'inspect' | 'climb' | 'nap' | 'sample'
 *            | 'grappleAim' | 'grappleShoot' | 'zipline' | 'rappel'
 *            | 'canopyInspect' | 'extractTap' | 'sampleBundle' | 'catalogSample'
 *            | 'butterflyMount' | 'butterflyRide' | 'butterflyRelease'
 *            | 'tunnelDig' | 'tunnelEmerge'
 *   opts   : { speed, bank, depthCue, emergeT }
 *
 * DIRECTION CONVENTIONS (verified on screen — limbs hang down -Y, gnome faces +Z):
 *   upperArm.x  : NEGATIVE = raise/swing FORWARD (+Z),  positive = back
 *   foreArm.x   : NEGATIVE = elbow flex (hand comes FORWARD/up)   <-- was flipped in v1
 *   thigh.x     : NEGATIVE = swing leg FORWARD,  positive = back
 *   shin.x      : POSITIVE = knee flex (calf folds back)
 *   foot.x      : NEGATIVE = toe down (plantarflex), positive = toe up
 *   torso.x     : NEGATIVE = lean torso FORWARD (chest over toes)  <-- was flipped in v1
 * Absolute rotations set every frame (no accumulation); switching action is instant.
 * ==========================================================================*/
function poseGnome(parts, t, action, opts) {
  opts = opts || {};
  var p = parts;
  if (!p || !p.root) return;
  var speed = opts.speed !== undefined ? opts.speed : 1.0;
  var rest = p._rest || { leftUpperArmZ: 0.18, rightUpperArmZ: -0.18, upperArmX: 0.05 };

  function rot(j, x, y, z) { if (j) j.rotation.set(x || 0, y || 0, z || 0); }
  function lerp(a, b, k) { return a + (b - a) * k; }
  function clamp01(v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }
  function mix01(a, b, k) { return a + (b - a) * k; }
  function easeInOutLocal(u) { u = clamp01(u); return u * u * (3 - 2 * u); }

  /* ---- neutral base each frame (a relaxed, slightly-bent stance) ---- */
  if (p.root) p.root.position.y = 0;
  rot(p.torso, 0, 0, 0);
  rot(p.pelvis, 0, 0, 0);
  rot(p.neck, 0, 0, 0);
  rot(p.head, 0, 0, 0);
  rot(p.leftUpperArm, 0.04, 0, rest.leftUpperArmZ + 0.05);
  rot(p.rightUpperArm, 0.04, 0, rest.rightUpperArmZ - 0.05);
  rot(p.leftForeArm, -0.28, 0, -0.08);   // relaxed elbow, hands slightly inward/forward
  rot(p.rightForeArm, -0.28, 0, 0.08);
  rot(p.leftHand, 0, 0, 0); rot(p.rightHand, 0, 0, 0);
  rot(p.leftThigh, 0, 0, 0); rot(p.rightThigh, 0, 0, 0);
  rot(p.leftShin, 0, 0, 0); rot(p.rightShin, 0, 0, 0);
  rot(p.leftFoot, 0, 0, 0); rot(p.rightFoot, 0, 0, 0);

  var breathe = Math.sin(t * 1.7) * 0.02;
  p.torso.rotation.x += breathe;

  if (action === 'walk') {
    // Per-gnome gait individuality: a stable seed nudges cadence + stride so a
    // crowd doesn't march in lockstep.
    var gaitSeed = opts.gait || 0;
    var gv = Math.sin(gaitSeed * 12.9898 + 0.7);   // stable -1..1 per gnome
    var cadence = 5.0 * (1 + gv * 0.08);
    var w = t * cadence * speed;
    var s = Math.sin(w);
    var c = Math.cos(w);
    var legAmp = 0.62 * (1 + gv * 0.12);
    var armAmp = 0.5 * (1 + gv * 0.10);
    // double-frequency vertical bob, plus a crisp weighted dip at each
    // foot-plant so steps land with intent instead of floating.
    var plant = Math.max(0, -Math.cos(2 * w));
    var bob = (-Math.abs(c) * 0.7 + 0.7) - plant * 0.12;
    if (p.root) p.root.position.y = bob;
    // torso leans gently into the stride, counter-rotates about Y and rolls
    // about Z with the weight shift; the head counter-bobs to hold the gaze level.
    rot(p.torso, -0.08 + breathe, -s * 0.13, s * 0.06);
    rot(p.pelvis, s * 0.02, s * 0.11, -s * 0.07);   // hip hike + sway over the stance leg
    rot(p.neck, 0.05, s * 0.05, -s * 0.02);
    rot(p.head, -0.04 + Math.abs(c) * 0.045, -s * 0.06, 0);
    // LEGS (contralateral): left leg back when s>0, right leg forward
    rot(p.leftThigh, s * legAmp, 0, 0.03);
    rot(p.rightThigh, -s * legAmp, 0, -0.03);
    // knees flex deepest through the forward swing (ground clearance), with a
    // lighter bend at push-off
    rot(p.leftShin, Math.max(0, -s) * 0.86 + Math.max(0, s) * 0.5, 0, 0);
    rot(p.rightShin, Math.max(0, s) * 0.86 + Math.max(0, -s) * 0.5, 0, 0);
    // feet roll heel-to-toe: toe-up heel-strike in front, toe-down toe-off at back
    rot(p.leftFoot, -s * 0.4 - Math.max(0, s) * 0.16, 0, 0);
    rot(p.rightFoot, s * 0.4 - Math.max(0, -s) * 0.16, 0, 0);
    // ARMS swing opposite the same-side leg with a touch of cross-body motion;
    // forearm keeps a soft, relaxed forward bend
    rot(p.leftUpperArm, -s * armAmp, s * 0.05, rest.leftUpperArmZ + 0.03);
    rot(p.rightUpperArm, s * armAmp, -s * 0.05, rest.rightUpperArmZ - 0.03);
    rot(p.leftForeArm, -0.38 - Math.max(0, -s) * 0.38, 0, 0);
    rot(p.rightForeArm, -0.38 - Math.max(0, s) * 0.38, 0, 0);

  } else if (action === 'carry') {
    var br = Math.sin(t * 1.8) * 0.04;
    rot(p.torso, 0.10 + breathe, 0, 0);          // lean BACK to counter the load (+x = back)
    rot(p.head, -0.06, 0, 0);
    rot(p.leftUpperArm, -0.85, 0, rest.leftUpperArmZ + 0.12);   // elbows up & in front
    rot(p.rightUpperArm, -0.85, 0, rest.rightUpperArmZ - 0.12);
    rot(p.leftForeArm, -1.25 + br, 0, -0.12);    // forearms FORWARD (negative), cradling
    rot(p.rightForeArm, -1.25 + br, 0, 0.12);
    rot(p.leftHand, 0.25, 0, 0); rot(p.rightHand, 0.25, 0, 0);
    rot(p.leftThigh, 0, 0, 0.03); rot(p.rightThigh, 0, 0, -0.03);

  } else if (action === 'build') {
    var h = t * 5.0 * speed;
    var strike = Math.pow(Math.max(0, Math.sin(h)), 0.6);  // sharp down-strike, slow raise
    rot(p.torso, -0.16 + breathe, 0.10, 0);      // lean INTO the work (negative = forward)
    rot(p.head, 0.26, 0.04, 0);                   // look down at the workpiece
    rot(p.pelvis, 0.05, 0, 0);
    // RIGHT (hammer) arm: raises up/back, then drives the hammer down/forward
    rot(p.rightUpperArm, -0.5 - (1 - strike) * 0.6, 0, rest.rightUpperArmZ - 0.15);
    rot(p.rightForeArm, -0.35 - (1 - strike) * 0.95, 0, 0);
    // LEFT arm steadies the piece, reaching forward-down
    rot(p.leftUpperArm, -0.9, 0, rest.leftUpperArmZ + 0.2);
    rot(p.leftForeArm, -0.9, 0, -0.15);
    rot(p.leftHand, 0.2, 0, 0);
    // braced stance: feet apart, knees soft
    rot(p.leftThigh, -0.18, 0, 0.08); rot(p.rightThigh, 0.12, 0, -0.08);
    rot(p.leftShin, 0.22, 0, 0); rot(p.rightShin, 0.16, 0, 0);
    rot(p.leftFoot, -0.12, 0, 0); rot(p.rightFoot, -0.08, 0, 0);

  } else if (action === 'lift') {
    var l = (Math.sin(t * 1.5 * speed) * 0.5 + 0.5);   // 1 = standing, 0 = crouched
    var bend = (1 - l);                                 // 0..1 crouch amount
    if (p.root) p.root.position.y = -bend * 1.9;        // whole body lowers
    rot(p.torso, -bend * 0.5 + breathe, 0, 0);          // modest forward hinge at the waist
    rot(p.head, bend * 0.32 - 0.05, 0, 0);              // keep eyes up toward load
    rot(p.leftUpperArm, -0.35 - bend * 0.2, 0, rest.leftUpperArmZ + 0.08);
    rot(p.rightUpperArm, -0.35 - bend * 0.2, 0, rest.rightUpperArmZ - 0.08);
    rot(p.leftForeArm, -0.5 - l * 0.7, 0, 0);           // curl up as it stands
    rot(p.rightForeArm, -0.5 - l * 0.7, 0, 0);
    rot(p.leftHand, 0.2, 0, 0); rot(p.rightHand, 0.2, 0, 0);
    // deep knee bend when crouched (lift with the legs)
    rot(p.leftThigh, -bend * 1.0, 0, 0.06); rot(p.rightThigh, -bend * 1.0, 0, -0.06);
    rot(p.leftShin, bend * 1.7, 0, 0); rot(p.rightShin, bend * 1.7, 0, 0);
    rot(p.leftFoot, -bend * 0.7, 0, 0); rot(p.rightFoot, -bend * 0.7, 0, 0);

  } else if (action === 'chat') {
    var talk = Math.sin(t * 2.4 * speed);
    var nod = Math.sin(t * 3.1 * speed) * 0.08;
    rot(p.torso, -0.02 + breathe, talk * 0.05, talk * 0.02);
    rot(p.head, nod, talk * 0.22, 0);
    rot(p.leftUpperArm, -0.35 + talk * 0.18, 0, rest.leftUpperArmZ + 0.22);
    rot(p.rightUpperArm, -0.55 - talk * 0.20, 0, rest.rightUpperArmZ - 0.18);
    rot(p.leftForeArm, -0.65 + talk * 0.18, 0, -0.22);
    rot(p.rightForeArm, -0.75 - talk * 0.16, 0, 0.18);
    rot(p.leftHand, 0.12, 0, talk * 0.22);
    rot(p.rightHand, 0.18, 0, -talk * 0.24);

  } else if (action === 'nap') {
    var snooze = Math.sin(t * 1.35 * speed) * 0.05;
    if (p.root) p.root.position.y = -1.35 + snooze;
    rot(p.pelvis, -0.18, 0, -0.16);
    rot(p.torso, 0.82 + breathe * 0.5, 0.05, 0.28);
    rot(p.neck, -0.12, 0, -0.08);
    rot(p.head, -0.52 + snooze, 0.08, -0.28);
    rot(p.leftUpperArm, -0.35, 0, rest.leftUpperArmZ + 0.38);
    rot(p.rightUpperArm, -0.48, 0, rest.rightUpperArmZ - 0.34);
    rot(p.leftForeArm, -1.18, 0, -0.28);
    rot(p.rightForeArm, -1.05, 0, 0.24);
    rot(p.leftThigh, -0.82, 0, 0.16);
    rot(p.rightThigh, -0.62, 0, -0.18);
    rot(p.leftShin, 1.34, 0, 0);
    rot(p.rightShin, 1.10, 0, 0);
    rot(p.leftFoot, -0.24, 0, 0.08);
    rot(p.rightFoot, -0.18, 0, -0.08);

  } else if (action === 'forage') {
    var reach = Math.sin(t * 2.1 * speed) * 0.5 + 0.5;
    if (p.root) p.root.position.y = -0.6 - reach * 0.55;
    rot(p.torso, -0.48 + breathe, 0.05, Math.sin(t * 1.3) * 0.04);
    rot(p.head, 0.36, Math.sin(t * 0.9) * 0.12, 0);
    rot(p.leftUpperArm, -1.05 - reach * 0.25, 0, rest.leftUpperArmZ + 0.12);
    rot(p.rightUpperArm, -1.25 + reach * 0.20, 0, rest.rightUpperArmZ - 0.10);
    rot(p.leftForeArm, -1.0 - reach * 0.2, 0, -0.12);
    rot(p.rightForeArm, -0.9 - reach * 0.35, 0, 0.08);
    rot(p.leftThigh, -0.55, 0, 0.08); rot(p.rightThigh, -0.70, 0, -0.08);
    rot(p.leftShin, 1.05, 0, 0); rot(p.rightShin, 1.22, 0, 0);
    rot(p.leftFoot, -0.28, 0, 0); rot(p.rightFoot, -0.32, 0, 0);

  } else if (action === 'inspect') {
    var peer = Math.sin(t * 1.8 * speed);
    rot(p.torso, -0.20 + breathe, peer * 0.06, 0);
    rot(p.head, 0.22 + Math.sin(t * 2.4) * 0.04, peer * 0.28, 0);
    rot(p.leftUpperArm, -0.25, 0, rest.leftUpperArmZ + 0.12);
    rot(p.rightUpperArm, -0.35, 0, rest.rightUpperArmZ - 0.10);
    rot(p.leftForeArm, -0.42, 0, -0.08);
    rot(p.rightForeArm, -0.52, 0, 0.10);
    rot(p.leftThigh, -0.12, 0, 0.03); rot(p.rightThigh, 0.05, 0, -0.03);
    rot(p.leftShin, 0.18, 0, 0); rot(p.rightShin, 0.12, 0, 0);

  } else if (action === 'climb') {
    var climb = t * 4.4 * speed;
    var cs = Math.sin(climb);
    if (p.root) p.root.position.y = 0.35 + Math.max(0, Math.sin(climb * 0.5)) * 0.8;
    rot(p.torso, -0.34 + breathe, 0, cs * 0.04);
    rot(p.head, -0.16, cs * 0.12, 0);
    rot(p.leftUpperArm, -2.05 + cs * 0.24, 0, rest.leftUpperArmZ + 0.12);
    rot(p.rightUpperArm, -2.05 - cs * 0.24, 0, rest.rightUpperArmZ - 0.12);
    rot(p.leftForeArm, -0.72 - Math.max(0, cs) * 0.4, 0, -0.10);
    rot(p.rightForeArm, -0.72 - Math.max(0, -cs) * 0.4, 0, 0.10);
    rot(p.leftThigh, -0.68 - cs * 0.18, 0, 0.11);
    rot(p.rightThigh, -0.68 + cs * 0.18, 0, -0.11);
    rot(p.leftShin, 1.24 + Math.max(0, cs) * 0.25, 0, 0);
    rot(p.rightShin, 1.24 + Math.max(0, -cs) * 0.25, 0, 0);
    rot(p.leftFoot, -0.45, 0, 0); rot(p.rightFoot, -0.45, 0, 0);

  } else if (action === 'grappleAim') {
    var aim = Math.sin(t * 2.2 * speed) * 0.04;
    if (p.root) p.root.position.y = -0.18;
    rot(p.torso, -0.22 + breathe, -0.08 + aim, 0.08);
    rot(p.head, -0.18, -0.20 + aim * 1.4, 0);
    rot(p.leftUpperArm, -1.85, 0.08, rest.leftUpperArmZ + 0.30);
    rot(p.leftForeArm, -0.54, 0, -0.18);
    rot(p.rightUpperArm, -2.32, -0.06, rest.rightUpperArmZ - 0.26);
    rot(p.rightForeArm, -0.45 + aim, 0, 0.22);
    rot(p.leftThigh, -0.28, 0, 0.12); rot(p.rightThigh, 0.18, 0, -0.16);
    rot(p.leftShin, 0.48, 0, 0); rot(p.rightShin, 0.30, 0, 0);
    rot(p.leftFoot, -0.18, 0, 0.10); rot(p.rightFoot, -0.10, 0, -0.08);

  } else if (action === 'grappleShoot') {
    var recoil = Math.max(0, Math.sin(t * 10.0 * speed));
    if (p.root) p.root.position.y = -0.12 - recoil * 0.20;
    rot(p.torso, 0.08 + breathe + recoil * 0.16, -0.16, -0.06);
    rot(p.head, -0.10, -0.24, 0);
    rot(p.leftUpperArm, -1.22 + recoil * 0.18, 0, rest.leftUpperArmZ + 0.18);
    rot(p.leftForeArm, -0.96, 0, -0.18);
    rot(p.rightUpperArm, -2.60 + recoil * 0.25, 0, rest.rightUpperArmZ - 0.22);
    rot(p.rightForeArm, -0.18 - recoil * 0.18, 0, 0.16);
    rot(p.leftThigh, -0.12, 0, 0.14); rot(p.rightThigh, 0.28, 0, -0.16);
    rot(p.leftShin, 0.34, 0, 0); rot(p.rightShin, 0.24, 0, 0);
    rot(p.leftFoot, -0.12, 0, 0); rot(p.rightFoot, -0.08, 0, 0);

  } else if (action === 'zipline') {
    // hand-over-hand rope climb: arms alternate a high reach and a downward
    // pull, legs push off the trunk for purchase, body surges up on each pull.
    var climb = Math.sin(t * 6.2 * speed);
    var pull = Math.max(0, climb);     // left arm pulls
    var pullR = Math.max(0, -climb);   // right arm pulls
    if (p.root) p.root.position.y = 0.5 + Math.abs(climb) * 0.22;
    rot(p.torso, 0.18 + breathe, climb * 0.06, climb * 0.05);
    rot(p.head, -0.14, climb * 0.10, 0);
    // pulling arm comes down toward the chest, the other reaches high overhead
    rot(p.leftUpperArm, -2.45 + pull * 0.45 - pullR * 0.6, 0, rest.leftUpperArmZ - 0.05);
    rot(p.rightUpperArm, -2.45 + pullR * 0.45 - pull * 0.6, 0, rest.rightUpperArmZ + 0.05);
    rot(p.leftForeArm, -0.5 - pull * 0.6, 0, -0.05);
    rot(p.rightForeArm, -0.5 - pullR * 0.6, 0, 0.05);
    rot(p.leftHand, 0.22, 0, 0.10); rot(p.rightHand, 0.22, 0, -0.10);
    // legs alternately extend to push against the trunk, then tuck
    rot(p.leftThigh, -0.72 + pull * 0.4, 0, 0.18);
    rot(p.rightThigh, -0.72 + pullR * 0.4, 0, -0.18);
    rot(p.leftShin, 1.25 - pull * 0.55, 0, 0);
    rot(p.rightShin, 1.25 - pullR * 0.55, 0, 0);
    rot(p.leftFoot, -0.3, 0, 0.08); rot(p.rightFoot, -0.3, 0, -0.08);

  } else if (action === 'butterflyMount') {
    var mount = Math.sin(t * 3.2 * speed) * 0.5 + 0.5;
    if (p.root) p.root.position.y = -0.38 + mount * 0.18;
    rot(p.torso, -0.42 + breathe, Math.sin(t * 1.4) * 0.08, 0);
    rot(p.head, 0.20, Math.sin(t * 1.1) * 0.18, 0);
    rot(p.leftUpperArm, -1.26 - mount * 0.30, 0, rest.leftUpperArmZ + 0.18);
    rot(p.rightUpperArm, -1.30 - mount * 0.26, 0, rest.rightUpperArmZ - 0.18);
    rot(p.leftForeArm, -1.05 - mount * 0.22, 0, -0.22);
    rot(p.rightForeArm, -1.06 - mount * 0.22, 0, 0.22);
    rot(p.leftThigh, -0.72, 0, 0.22);
    rot(p.rightThigh, -0.72, 0, -0.22);
    rot(p.leftShin, 1.14, 0, 0);
    rot(p.rightShin, 1.14, 0, 0);
    rot(p.leftFoot, -0.30, 0, 0.10);
    rot(p.rightFoot, -0.30, 0, -0.10);

  } else if (action === 'butterflyRide') {
    var wingRide = Math.sin(t * 5.4 * speed);
    var bank = opts.bank || 0;
    var behindCue = opts.depthCue && opts.depthCue < 0 ? 0.12 : 0;
    if (p.root) p.root.position.y = 0.32 + Math.sin(t * 3.4) * 0.22;
    rot(p.torso, -0.12 + breathe, bank * 0.38, bank * 0.72);
    rot(p.head, -0.12 + behindCue, bank * 0.28 + Math.sin(t * 1.7) * 0.08, -bank * 0.22);
    rot(p.leftUpperArm, -1.82 + bank * 0.10, 0, rest.leftUpperArmZ + 0.36);
    rot(p.rightUpperArm, -1.82 - bank * 0.10, 0, rest.rightUpperArmZ - 0.36);
    rot(p.leftForeArm, -1.12 + wingRide * 0.08, 0, -0.30);
    rot(p.rightForeArm, -1.12 - wingRide * 0.08, 0, 0.30);
    rot(p.leftHand, 0.28, 0, -0.24);
    rot(p.rightHand, 0.28, 0, 0.24);
    rot(p.leftThigh, -0.92 + wingRide * 0.06, 0, 0.32);
    rot(p.rightThigh, -0.92 - wingRide * 0.06, 0, -0.32);
    rot(p.leftShin, 1.52 + Math.max(0, wingRide) * 0.10, 0, 0);
    rot(p.rightShin, 1.52 + Math.max(0, -wingRide) * 0.10, 0, 0);
    rot(p.leftFoot, -0.44, 0, 0.18);
    rot(p.rightFoot, -0.44, 0, -0.18);

  } else if (action === 'butterflyRelease') {
    var wave = Math.sin(t * 5.8 * speed);
    var hopDown = Math.max(0, Math.sin(t * 3.0)) * 0.35;
    if (p.root) p.root.position.y = -0.08 + hopDown;
    rot(p.torso, -0.04 + breathe, 0, wave * 0.04);
    rot(p.head, -0.12, Math.sin(t * 1.8) * 0.20, 0);
    rot(p.leftUpperArm, -0.55, 0, rest.leftUpperArmZ + 0.16);
    rot(p.leftForeArm, -0.56, 0, -0.14);
    rot(p.rightUpperArm, -2.25, 0, rest.rightUpperArmZ + 0.20 + wave * 0.18);
    rot(p.rightForeArm, -0.42, 0, 0.30 + wave * 0.16);
    rot(p.rightHand, 0.18, 0, wave * 0.45);
    rot(p.leftThigh, -0.10, 0, 0.08);
    rot(p.rightThigh, -0.14, 0, -0.08);
    rot(p.leftShin, 0.22, 0, 0);
    rot(p.rightShin, 0.24, 0, 0);

  } else if (action === 'rappel') {
    // braked rappel descent: the top hand feeds the rope while the legs kick
    // off the trunk in rhythmic bounces, the body dipping between kicks.
    var bounce = Math.sin(t * 4.6 * speed);
    var kick = Math.max(0, bounce);
    if (p.root) p.root.position.y = 0.22 - Math.max(0, -bounce) * 0.20;
    rot(p.torso, -0.06 + breathe, bounce * 0.05, -0.12 + kick * 0.05);
    rot(p.head, 0.06, bounce * 0.14, 0);
    // left hand high on the rope, right hand brakes below
    rot(p.leftUpperArm, -2.62, 0, rest.leftUpperArmZ + 0.02);
    rot(p.leftForeArm, -0.74, 0, -0.06);
    rot(p.rightUpperArm, -1.5 + bounce * 0.12, 0, rest.rightUpperArmZ - 0.38);
    rot(p.rightForeArm, -0.95 - kick * 0.24, 0, 0.22);
    rot(p.leftHand, 0.18, 0, 0.10); rot(p.rightHand, 0.16, 0, -0.12);
    // legs extend to kick off the trunk on each bounce, then tuck back in
    rot(p.leftThigh, -0.4 - kick * 0.34, 0, 0.16);
    rot(p.rightThigh, -0.26 - kick * 0.34, 0, -0.16);
    rot(p.leftShin, 0.7 - kick * 0.5, 0, 0); rot(p.rightShin, 0.56 - kick * 0.5, 0, 0);
    rot(p.leftFoot, -0.30, 0, 0.10); rot(p.rightFoot, -0.24, 0, -0.10);

  } else if (action === 'canopyInspect') {
    var scan = Math.sin(t * 1.8 * speed);
    if (p.root) p.root.position.y = 0.15 + Math.sin(t * 2.2) * 0.08;
    rot(p.torso, -0.22 + breathe, scan * 0.08, 0.05);
    rot(p.head, -0.20 + Math.sin(t * 2.8) * 0.04, scan * 0.32, 0);
    rot(p.leftUpperArm, -1.35, 0, rest.leftUpperArmZ + 0.28);
    rot(p.leftForeArm, -1.08, 0, -0.22);
    rot(p.leftHand, 0.18, 0, -0.16);
    rot(p.rightUpperArm, -0.58 + scan * 0.08, 0, rest.rightUpperArmZ - 0.16);
    rot(p.rightForeArm, -0.72, 0, 0.10);
    rot(p.leftThigh, -0.28, 0, 0.12); rot(p.rightThigh, -0.12, 0, -0.12);
    rot(p.leftShin, 0.56, 0, 0); rot(p.rightShin, 0.42, 0, 0);
    rot(p.leftFoot, -0.18, 0, 0.08); rot(p.rightFoot, -0.12, 0, -0.08);

  } else if (action === 'extractTap') {
    var tap = Math.pow(Math.max(0, Math.sin(t * 7.8 * speed)), 0.45);
    var brace = Math.sin(t * 1.4) * 0.05;
    if (p.root) p.root.position.y = -0.10 + tap * 0.16;
    rot(p.torso, -0.36 + breathe, 0.12 + brace, 0.06);
    rot(p.head, 0.10, 0.22 + brace, 0);
    rot(p.leftUpperArm, -1.72, 0, rest.leftUpperArmZ + 0.22);
    rot(p.leftForeArm, -1.18, 0, -0.18);
    rot(p.leftHand, 0.12, 0, -0.24);
    rot(p.rightUpperArm, -1.18 - tap * 0.55, 0, rest.rightUpperArmZ - 0.18);
    rot(p.rightForeArm, -1.32 + tap * 0.46, 0, 0.26);
    rot(p.rightHand, 0.30, 0, 0.35 - tap * 0.45);
    rot(p.leftThigh, -0.30, 0, 0.12); rot(p.rightThigh, -0.48, 0, -0.08);
    rot(p.leftShin, 0.54, 0, 0); rot(p.rightShin, 0.76, 0, 0);
    rot(p.leftFoot, -0.18, 0, 0); rot(p.rightFoot, -0.24, 0, 0);

  } else if (action === 'sampleBundle') {
    var tie = Math.sin(t * 4.6 * speed);
    if (p.root) p.root.position.y = -0.18 + Math.max(0, tie) * 0.10;
    rot(p.torso, -0.28 + breathe, tie * 0.04, 0);
    rot(p.head, 0.20, tie * 0.08, 0);
    rot(p.leftUpperArm, -1.02, 0, rest.leftUpperArmZ + 0.22);
    rot(p.rightUpperArm, -1.04, 0, rest.rightUpperArmZ - 0.22);
    rot(p.leftForeArm, -1.38 + tie * 0.22, 0, -0.26);
    rot(p.rightForeArm, -1.38 - tie * 0.22, 0, 0.26);
    rot(p.leftHand, 0.24, 0, -0.32); rot(p.rightHand, 0.24, 0, 0.32);
    rot(p.leftThigh, -0.24, 0, 0.10); rot(p.rightThigh, -0.24, 0, -0.10);
    rot(p.leftShin, 0.48, 0, 0); rot(p.rightShin, 0.48, 0, 0);
    rot(p.leftFoot, -0.16, 0, 0); rot(p.rightFoot, -0.16, 0, 0);

  } else if (action === 'catalogSample') {
    var sort = Math.sin(t * 3.8 * speed);
    var note = Math.max(0, Math.sin(t * 6.2 * speed));
    if (p.root) p.root.position.y = -0.10 + note * 0.05;
    rot(p.torso, -0.24 + breathe, sort * 0.05, 0.02);
    rot(p.head, 0.26, sort * 0.14, 0);
    rot(p.leftUpperArm, -0.92, 0, rest.leftUpperArmZ + 0.20);
    rot(p.leftForeArm, -1.28 + sort * 0.16, 0, -0.22);
    rot(p.leftHand, 0.22, 0, -0.28);
    rot(p.rightUpperArm, -0.82 - note * 0.16, 0, rest.rightUpperArmZ - 0.20);
    rot(p.rightForeArm, -1.20 - note * 0.30, 0, 0.24);
    rot(p.rightHand, 0.24, 0, 0.32);
    rot(p.leftThigh, -0.18, 0, 0.08); rot(p.rightThigh, -0.22, 0, -0.08);
    rot(p.leftShin, 0.36, 0, 0); rot(p.rightShin, 0.40, 0, 0);
    rot(p.leftFoot, -0.12, 0, 0); rot(p.rightFoot, -0.14, 0, 0);

  } else if (action === 'sample') {
    var snip = Math.sin(t * 3.6 * speed) * 0.5 + 0.5;
    var careful = Math.sin(t * 1.2) * 0.04;
    if (p.root) p.root.position.y = -0.25 + snip * 0.2;
    rot(p.torso, -0.38 + breathe, 0.08 + careful, 0.04);
    rot(p.head, 0.18, 0.20 + Math.sin(t * 1.6) * 0.10, 0);
    rot(p.leftUpperArm, -1.55, 0, rest.leftUpperArmZ + 0.22);
    rot(p.leftForeArm, -0.98 - snip * 0.22, 0, -0.18);
    rot(p.leftHand, 0.18, 0, -0.20);
    rot(p.rightUpperArm, -1.15 - snip * 0.46, 0, rest.rightUpperArmZ - 0.18);
    rot(p.rightForeArm, -1.25 + snip * 0.36, 0, 0.20);
    rot(p.rightHand, 0.28, 0, 0.28 - snip * 0.32);
    rot(p.leftThigh, -0.22, 0, 0.08); rot(p.rightThigh, -0.38, 0, -0.08);
    rot(p.leftShin, 0.42, 0, 0); rot(p.rightShin, 0.58, 0, 0);
    rot(p.leftFoot, -0.16, 0, 0); rot(p.rightFoot, -0.24, 0, 0);

  } else if (action === 'tunnelDig') {
    // Deep forward crouch driving a shovel down into the mound mouth; the right
    // arm does a rhythmic shovel strike, sharp on the down-stroke, slow recover.
    var dig = Math.pow(Math.max(0, Math.sin(t * 5.0 * speed)), 0.5);
    var heave = Math.sin(t * 1.6) * 0.04;
    if (p.root) p.root.position.y = -0.30 - dig * 0.22;
    rot(p.torso, -0.52 + breathe + heave, 0.10, 0.04);   // deep forward lean
    rot(p.head, 0.34, 0.08, 0);                            // looking down at the dig
    rot(p.pelvis, 0.08, 0, 0);
    // RIGHT (shovel) arm: swung forward-down, strikes on the down-beat
    rot(p.rightUpperArm, -1.60 - dig * 0.30, 0, rest.rightUpperArmZ - 0.14);
    rot(p.rightForeArm, -1.40 + dig * 0.30, 0, 0.10);
    rot(p.rightHand, 0.24, 0, 0.18);
    // LEFT arm grips the shaft lower, forward-down
    rot(p.leftUpperArm, -1.55, 0, rest.leftUpperArmZ + 0.16);
    rot(p.leftForeArm, -1.32, 0, -0.12);
    rot(p.leftHand, 0.22, 0, -0.14);
    // braced, knees deeply bent
    rot(p.leftThigh, -0.80, 0, 0.12); rot(p.rightThigh, -0.80, 0, -0.12);
    rot(p.leftShin, 1.50, 0, 0); rot(p.rightShin, 1.50, 0, 0);
    rot(p.leftFoot, -0.30, 0, 0.08); rot(p.rightFoot, -0.30, 0, -0.08);

  } else if (action === 'tunnelEmerge') {
    // Rising up out of the ground: the root climbs from -2 -> 0 over the emerge
    // dwell (opts.emergeT, 0..1), arms lift from overhead-down to relaxed, head
    // tilts up toward the sky as the gnome clears the soil.
    var emergeT = (opts.emergeT != null) ? clamp01(opts.emergeT) : 1;
    var se = easeInOutLocal(emergeT);
    var clamber = Math.sin(t * 5.6 * speed) * (1 - emergeT) * 0.12;
    if (p.root) p.root.position.y = mix01(-2.0, 0, se);
    rot(p.torso, -0.18 + breathe + (1 - se) * 0.20, clamber, 0);
    rot(p.head, mix01(0.30, -0.18, se), clamber * 0.5, 0);  // head tilts up as it rises
    var armX = mix01(-2.80, -0.60, se);                       // overhead-grab -> relaxed
    rot(p.leftUpperArm, armX + clamber, 0, rest.leftUpperArmZ + 0.10);
    rot(p.rightUpperArm, armX - clamber, 0, rest.rightUpperArmZ - 0.10);
    rot(p.leftForeArm, mix01(-0.70, -0.30, se), 0, -0.10);
    rot(p.rightForeArm, mix01(-0.70, -0.30, se), 0, 0.10);
    rot(p.leftThigh, mix01(-0.95, -0.05, se), 0, 0.10);
    rot(p.rightThigh, mix01(-0.95, -0.05, se), 0, -0.10);
    rot(p.leftShin, mix01(1.45, 0.10, se), 0, 0);
    rot(p.rightShin, mix01(1.45, 0.10, se), 0, 0);
    rot(p.leftFoot, -0.20 * (1 - se), 0, 0); rot(p.rightFoot, -0.20 * (1 - se), 0, 0);

  } else if (action === 'cheer') {
    var c = t * 7.0;
    var hop = Math.max(0, Math.sin(c)) * 1.6;
    if (p.root) p.root.position.y = hop;
    rot(p.torso, -0.06 + breathe, 0, 0);
    rot(p.head, -0.18, Math.sin(c * 0.5) * 0.1, 0);
    // arms thrown overhead: upperArm swings way forward/up (very negative), forearm extends up
    rot(p.leftUpperArm, -2.7, 0, rest.leftUpperArmZ - 0.45 + Math.sin(c) * 0.12);
    rot(p.rightUpperArm, -2.7, 0, rest.rightUpperArmZ + 0.45 - Math.sin(c) * 0.12);
    rot(p.leftForeArm, -0.15 - Math.max(0, Math.sin(c)) * 0.2, 0, 0);
    rot(p.rightForeArm, -0.15 - Math.max(0, Math.sin(c)) * 0.2, 0, 0);
    // little knee spring on each hop
    rot(p.leftThigh, -0.12, 0, 0.1); rot(p.rightThigh, -0.12, 0, -0.1);
    rot(p.leftShin, hop > 0.15 ? 0.5 : 0.1, 0, 0);
    rot(p.rightShin, hop > 0.15 ? 0.5 : 0.1, 0, 0);
    rot(p.leftFoot, hop > 0.15 ? -0.3 : 0, 0, 0); rot(p.rightFoot, hop > 0.15 ? -0.3 : 0, 0, 0);

  } else {
    /* ---- IDLE: breathing + slow weight-shift + occasional look-around ---- */
    var sway = Math.sin(t * 0.6) * 0.04;
    var shift = Math.sin(t * 0.45);
    rot(p.torso, breathe * 0.6, sway, shift * 0.03);
    rot(p.pelvis, 0, 0, -shift * 0.04);
    rot(p.neck, 0.02, sway * 0.5, 0);
    rot(p.head, Math.sin(t * 1.0) * 0.04, Math.sin(t * 0.45) * 0.16, 0);
    rot(p.leftUpperArm, 0.04 + breathe * 0.7, 0, rest.leftUpperArmZ + 0.05 + breathe);
    rot(p.rightUpperArm, 0.04 + breathe * 0.7, 0, rest.rightUpperArmZ - 0.05 - breathe);
    rot(p.leftForeArm, -0.28 + breathe, 0, -0.08);
    rot(p.rightForeArm, -0.28 - breathe, 0, 0.08);
    // subtle weight on one leg
    rot(p.leftThigh, 0, 0, 0.02 + Math.max(0, shift) * 0.03);
    rot(p.rightThigh, 0, 0, -0.02 - Math.max(0, -shift) * 0.03);
  }

  /* ---- soft felt-cap secondary motion: the flopped tip lags + sways ---- */
  if (p.hat && p.hat.seg4 && p.hat.seg5) {
    var lag = Math.sin(t * 2.6) * 0.07;
    var bobV = (p.root ? p.root.position.y : 0) * 0.04;
    p.hat.seg4.rotation.set(0.85 - bobV, 0, 0.35 + lag);
    p.hat.seg5.rotation.set(1.0 + Math.cos(t * 2.6) * 0.05 - bobV, 0, 0.45 + lag * 1.5);
  }
}
