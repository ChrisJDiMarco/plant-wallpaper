/* ============================================================================
 * poseGnome(parts, t, action, opts)
 *   parts  : named bone hierarchy from makeGnome().parts
 *   t      : time in SECONDS (e.g. clock.getElapsedTime())
 *   action : 'idle' | 'walk' | 'carry' | 'build' | 'lift' | 'cheer'
 *   opts   : { speed } cycle-rate multiplier (default 1.0)
 *
 * Sets ABSOLUTE joint rotations every frame (never accumulates), so switching
 * action mid-animation is instant and bleed-free. Touches only rotations plus
 * root.position.y for bob/hop — never sub-joint positions — so it composes
 * cleanly with whatever world translate/scale/facing the caller applies to the
 * group. Convention: limbs swing forward/back about X, splay about Z; the
 * gnome faces +Z so a walk swings legs/arms about X and counter-rotates the
 * torso about Y. Unknown action strings fall through to 'idle'.
 * ==========================================================================*/
function poseGnome(parts, t, action, opts) {
  opts = opts || {};
  var p = parts;
  if (!p || !p.root) return;
  var speed = opts.speed !== undefined ? opts.speed : 1.0;
  var rest = p._rest || { leftUpperArmZ: 0.18, rightUpperArmZ: -0.18, upperArmX: 0.05 };

  function rot(j, x, y, z) { if (j) j.rotation.set(x || 0, y || 0, z || 0); }

  /* ---- clean neutral base every frame (prevents pose bleed-through) ---- */
  if (p.root) p.root.position.y = 0;
  rot(p.torso, 0, 0, 0);
  rot(p.pelvis, 0, 0, 0);
  rot(p.neck, 0, 0, 0);
  rot(p.head, 0, 0, 0);
  rot(p.leftUpperArm, rest.upperArmX, 0, rest.leftUpperArmZ);
  rot(p.rightUpperArm, rest.upperArmX, 0, rest.rightUpperArmZ);
  rot(p.leftForeArm, 0.15, 0, 0);
  rot(p.rightForeArm, 0.15, 0, 0);
  rot(p.leftHand, 0, 0, 0); rot(p.rightHand, 0, 0, 0);
  rot(p.leftThigh, 0, 0, 0); rot(p.rightThigh, 0, 0, 0);
  rot(p.leftShin, 0, 0, 0); rot(p.rightShin, 0, 0, 0);
  rot(p.leftFoot, 0, 0, 0); rot(p.rightFoot, 0, 0, 0);

  /* gentle ambient breathing on every action */
  var breathe = Math.sin(t * 1.6) * 0.025;
  if (p.chest) { /* chest is a mesh, not a joint — skip; breathe via torso */ }
  p.torso.rotation.x += breathe;

  if (action === 'walk') {
    var w = t * 6.0 * speed;
    var swing  = Math.sin(w) * 0.7;   // leg amplitude
    var aSwing = Math.sin(w) * 0.5;   // arm amplitude
    var bob = Math.abs(Math.sin(w)) * 0.5;
    if (p.root) p.root.position.y = bob;                          // vertical bob
    rot(p.torso, 0.04 + breathe, Math.sin(w) * 0.10, 0);          // counter-twist
    rot(p.pelvis, 0, Math.sin(w) * 0.08, 0);
    rot(p.head, -0.02 + Math.abs(Math.sin(w)) * 0.04, -Math.sin(w) * 0.06, 0);
    // legs swing opposite each other
    rot(p.leftThigh, swing, 0, 0);
    rot(p.rightThigh, -swing, 0, 0);
    // knees bend only on the back-swing (forward bend, clamped >= 0)
    rot(p.leftShin, Math.max(0, -swing) * 1.1, 0, 0);
    rot(p.rightShin, Math.max(0, swing) * 1.1, 0, 0);
    rot(p.leftFoot, -Math.max(0, -swing) * 0.5, 0, 0);
    rot(p.rightFoot, -Math.max(0, swing) * 0.5, 0, 0);
    // arms swing OPPOSITE the same-side leg
    rot(p.leftUpperArm, -aSwing, 0, rest.leftUpperArmZ);
    rot(p.rightUpperArm, aSwing, 0, rest.rightUpperArmZ);
    rot(p.leftForeArm, 0.4 + Math.max(0, aSwing) * 0.5, 0, 0);
    rot(p.rightForeArm, 0.4 + Math.max(0, -aSwing) * 0.5, 0, 0);

  } else if (action === 'carry') {
    var br = Math.sin(t * 2.0) * 0.03;
    rot(p.torso, -0.06 + breathe, 0, 0);                          // lean back under load
    rot(p.head, 0.05, 0, 0);
    rot(p.leftUpperArm,  -0.9, 0, rest.leftUpperArmZ + 0.15);     // elbows tucked in
    rot(p.rightUpperArm, -0.9, 0, rest.rightUpperArmZ - 0.15);
    rot(p.leftForeArm,  1.5 + br, 0.2, 0);                        // forearms forward ~90deg
    rot(p.rightForeArm, 1.5 + br, -0.2, 0);
    rot(p.leftHand, -0.3, 0, 0); rot(p.rightHand, -0.3, 0, 0);

  } else if (action === 'build') {
    var h = t * 5.0 * speed;
    var up = (Math.sin(h) * 0.5 + 0.5);                           // 0..1
    rot(p.torso, 0.10 + breathe, -0.08, 0);                       // lean into the work
    rot(p.head, 0.18, -0.05, 0);                                  // look down at workpiece
    // right (hammer) arm raises then strikes down
    rot(p.rightUpperArm, -0.2 - up * 1.3, 0, rest.rightUpperArmZ - 0.2);
    rot(p.rightForeArm, 0.5 + up * 1.1, 0, 0);
    // left arm steadies the piece, low & forward
    rot(p.leftUpperArm, -0.7, 0, rest.leftUpperArmZ + 0.3);
    rot(p.leftForeArm, 1.2, 0.3, 0);
    rot(p.leftHand, -0.2, 0, 0);
    // braced stance
    rot(p.leftThigh, 0.15, 0, 0.05); rot(p.rightThigh, -0.1, 0, -0.05);
    rot(p.leftShin, 0.25, 0, 0); rot(p.rightShin, 0.15, 0, 0);
    rot(p.leftFoot, -0.2, 0, 0); rot(p.rightFoot, -0.1, 0, 0);

  } else if (action === 'lift') {
    var l = (Math.sin(t * 1.6 * speed) * 0.5 + 0.5);              // 0 down .. 1 up
    var bend = (1 - l) * 1.0;                                     // hip bend up to ~1 rad
    if (p.root) p.root.position.y = -bend * 1.4;                  // whole body lowers
    rot(p.torso, bend + breathe, 0, 0);                           // hinge at the waist
    rot(p.head, -bend * 0.6 + 0.2, 0, 0);                         // eyes toward the load
    rot(p.leftUpperArm,  -0.2 - bend * 0.3, 0, rest.leftUpperArmZ + 0.1);
    rot(p.rightUpperArm, -0.2 - bend * 0.3, 0, rest.rightUpperArmZ - 0.1);
    rot(p.leftForeArm,  0.4 + l * 0.9, 0.1, 0);
    rot(p.rightForeArm, 0.4 + l * 0.9, -0.1, 0);
    rot(p.leftHand, -0.2, 0, 0); rot(p.rightHand, -0.2, 0, 0);
    // lift with the legs — deep knee bend when down
    rot(p.leftThigh, bend * 0.5, 0, 0); rot(p.rightThigh, bend * 0.5, 0, 0);
    rot(p.leftShin, bend * 1.1, 0, 0); rot(p.rightShin, bend * 1.1, 0, 0);
    rot(p.leftFoot, -bend * 0.5, 0, 0); rot(p.rightFoot, -bend * 0.5, 0, 0);

  } else if (action === 'cheer') {
    var c = t * 8.0;
    var hop = Math.max(0, Math.sin(c)) * 1.2;
    if (p.root) p.root.position.y = hop;
    rot(p.torso, -0.08 + breathe, 0, 0);
    rot(p.head, -0.15, Math.sin(c * 0.5) * 0.1, 0);
    // arms thrown up (swing about X to raise overhead; small Z spread)
    rot(p.leftUpperArm,  -2.6, 0, rest.leftUpperArmZ - 0.5 + Math.sin(c) * 0.1);
    rot(p.rightUpperArm, -2.6, 0, rest.rightUpperArmZ + 0.5 - Math.sin(c) * 0.1);
    rot(p.leftForeArm, -0.3, 0, 0); rot(p.rightForeArm, -0.3, 0, 0);
    rot(p.leftThigh, -0.1, 0, 0.1); rot(p.rightThigh, -0.1, 0, -0.1);
    rot(p.leftShin, hop > 0.1 ? 0.4 : 0.0, 0, 0);
    rot(p.rightShin, hop > 0.1 ? 0.4 : 0.0, 0, 0);

  } else {
    /* ---- IDLE: breathing sway + subtle weight shift + slow look-around ---- */
    var sway = Math.sin(t * 0.7) * 0.03;
    rot(p.torso, breathe * 0.5, sway, 0);
    rot(p.pelvis, 0, 0, -sway * 0.5);
    rot(p.head, Math.sin(t * 1.1) * 0.05, Math.sin(t * 0.5) * 0.18, 0);
    rot(p.leftUpperArm, 0.02 + breathe * 0.6, 0, rest.leftUpperArmZ + breathe);
    rot(p.rightUpperArm, 0.02 + breathe * 0.6, 0, rest.rightUpperArmZ - breathe);
    rot(p.leftForeArm, 0.18 + breathe, 0, 0);
    rot(p.rightForeArm, 0.18 - breathe, 0, 0);
  }

  /* ---- soft felt-cap secondary motion: the flopped tip lags the body ---- */
  if (p.hat && p.hat.seg4 && p.hat.seg5) {
    var lag = Math.sin(t * 3.0) * 0.06;
    p.hat.seg4.rotation.set(0.85, 0, 0.35 + lag);
    p.hat.seg5.rotation.set(1.0 + Math.cos(t * 3.0) * 0.04, 0, 0.45 + lag * 1.4);
  }
}