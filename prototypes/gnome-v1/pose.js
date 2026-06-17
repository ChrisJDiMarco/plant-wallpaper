/* ============================================================================
 * poseGnome(parts, t, action, opts)  — v2, empirically-corrected directions
 *   parts  : named bone hierarchy from makeGnome().parts
 *   t      : time in SECONDS
 *   action : 'idle' | 'walk' | 'carry' | 'build' | 'lift' | 'cheer'
 *   opts   : { speed }
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
    var w = t * 5.0 * speed;
    var s = Math.sin(w);
    var legAmp = 0.62, armAmp = 0.5;
    // double-frequency vertical bob: body dips on each foot-plant
    var bob = -Math.abs(Math.cos(w)) * 0.7 + 0.7;
    if (p.root) p.root.position.y = bob;
    // torso & hips: counter-rotate about Y, slight roll about Z (weight shift)
    rot(p.torso, -0.06 + breathe, -s * 0.12, s * 0.05);
    rot(p.pelvis, 0, s * 0.10, -s * 0.06);
    rot(p.neck, 0.04, s * 0.05, 0);
    rot(p.head, -0.03, -s * 0.05, 0);
    // LEGS (contralateral): left leg back when s>0, right leg forward
    rot(p.leftThigh, s * legAmp, 0, 0.03);
    rot(p.rightThigh, -s * legAmp, 0, -0.03);
    // knees flex on the rear/push-off leg and during forward swing to clear ground
    rot(p.leftShin, Math.max(0, -s) * 0.5 + Math.max(0, s) * 0.9, 0, 0);
    rot(p.rightShin, Math.max(0, s) * 0.5 + Math.max(0, -s) * 0.9, 0, 0);
    // feet: heel-strike (toe up) in front, toe-off (toe down) at back
    rot(p.leftFoot, -s * 0.35, 0, 0);
    rot(p.rightFoot, s * 0.35, 0, 0);
    // ARMS swing opposite same-side leg; forearm keeps a soft forward bend
    rot(p.leftUpperArm, -s * armAmp, 0, rest.leftUpperArmZ);
    rot(p.rightUpperArm, s * armAmp, 0, rest.rightUpperArmZ);
    rot(p.leftForeArm, -0.35 - Math.max(0, -s) * 0.35, 0, 0);
    rot(p.rightForeArm, -0.35 - Math.max(0, s) * 0.35, 0, 0);

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
