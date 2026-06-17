/* Animation engine: procedural quadruped gait with planted feet (2-bone IK
   per leg, solved in the cat's sagittal plane), a pose library for sit /
   groom / lie / sleep / stretch, damped blending between everything, and
   secondary motion — tail chain, breathing, blinking, head wander.

   All gait math runs in body-local space (cat always walks toward local +x);
   the root bone's yaw + world x position handle heading and travel. */

const CatAnim = (() => {
  const ROOT_REST_Y = 0.46;

  const LEGS = {
    backL:  { thigh: 'thighBL', shin: 'shinBL', foot: 'footBL', hip: [-0.28, -0.04], l1: 0.19, l2: 0.175, homeX: -0.29, plantY: 0.055, bend: 1,  phase: 0.0, lift: 0.10, parents: ['hips'] },
    backR:  { thigh: 'thighBR', shin: 'shinBR', foot: 'footBR', hip: [-0.28, -0.04], l1: 0.19, l2: 0.175, homeX: -0.29, plantY: 0.055, bend: 1,  phase: 0.5, lift: 0.10, parents: ['hips'] },
    frontL: { thigh: 'shoulderFL', shin: 'elbowFL', foot: 'footFL', hip: [0.30, -0.02], l1: 0.205, l2: 0.185, homeX: 0.31, plantY: 0.05, bend: -1, phase: 0.3, lift: 0.085, parents: ['spine', 'chest'] },
    frontR: { thigh: 'shoulderFR', shin: 'elbowFR', foot: 'footFR', hip: [0.30, -0.02], l1: 0.205, l2: 0.185, homeX: 0.31, plantY: 0.05, bend: -1, phase: 0.8, lift: 0.085, parents: ['spine', 'chest'] }
  };

  const TROT_PHASES = { backL: 0.0, frontR: 0.05, backR: 0.5, frontL: 0.55 };

  // Gait tuning per movement style. Stalk is the low slinky hunting creep.
  const GAITS = {
    walk: { stanceFrac: 0.62, stride: 0.34, liftMult: 1.0, bobAmp: 0.013 },
    trot: { stanceFrac: 0.50, stride: 0.46, liftMult: 1.3, bobAmp: 0.028 },
    stalk: { stanceFrac: 0.72, stride: 0.22, liftMult: 0.45, bobAmp: 0.005 }
  };

  // Pose channels not covered here default to 0 (stand). Legs: ik weight 1
  // means gait/IK drives the leg; 0 means the authored fold rotations do.
  const POSES = {
    stand:   { breath: 1, eyes: 1 },
    walk:    { breath: 1, eyes: 1 },
    trot:    { breath: 1.4, eyes: 1 },
    sit: {
      // Pelvis on the ground, hind legs folded flat, all the height in the
      // spine/chest bend — the classic upright-sit S-curve.
      rootHeight: -0.246, rootPitch: 0.35,
      spineRz: 0.22, chestRz: 0.16, neckRz: -0.42, headRz: -0.22,
      backIk: 0, backFold: [1.48, -3.05, 1.44],
      frontTargetX: 0.27, frontTargetY: 0.05,
      tailCurl: 0.90, tailSide: 0.90,
      breath: 1, eyes: 1
    },
    groom: {
      rootHeight: -0.246, rootPitch: 0.35,
      spineRz: 0.22, chestRz: 0.16, neckRz: -1.05, headRz: -0.32, headRy: 0.45,
      backIk: 0, backFold: [1.48, -3.05, 1.44],
      frontIkL: 0, frontFoldL: [0.90, -2.40, 0.30],
      frontTargetX: 0.25, frontTargetY: 0.05,
      tailCurl: 0.85, tailSide: 0.85,
      breath: 1.1, eyes: 0.55
    },
    groomPaw: {
      rootHeight: -0.246, rootPitch: 0.35,
      spineRz: 0.22, chestRz: 0.16, neckRz: -1.02, headRz: -0.34, headRy: 0.46,
      backIk: 0, backFold: [1.48, -3.05, 1.44],
      frontIkL: 0, frontFoldL: [0.90, -2.40, 0.30],
      frontTargetX: 0.25, frontTargetY: 0.05,
      tailCurl: 0.85, tailSide: 0.85,
      breath: 1.1, eyes: 0.55
    },
    groomFace: {
      rootHeight: -0.246, rootPitch: 0.34,
      spineRz: 0.20, chestRz: 0.14, neckRz: -0.78, headRz: -0.26, headRy: 0.22,
      backIk: 0, backFold: [1.48, -3.05, 1.44],
      frontIkL: 0, frontFoldL: [0.72, -2.12, 0.18],
      frontTargetX: 0.26, frontTargetY: 0.05,
      tailCurl: 0.78, tailSide: 0.82,
      breath: 1.08, eyes: 0.50
    },
    groomFlank: {
      rootHeight: -0.255, rootPitch: 0.28,
      spineRz: 0.31, chestRz: 0.22, neckRz: -1.18, headRz: -0.44, headRy: -0.86,
      backIk: 0, backFold: [1.50, -2.86, 0.32],
      frontIk: 0, frontFold: [1.05, -2.40, 0.14],
      tailCurl: 0.54, tailSide: 1.06,
      breath: 1.24, eyes: 0.48
    },
    groomBelly: {
      rootHeight: -0.285, rootPitch: 0.05, rootRoll: 2.20,
      spineRz: 0.06, chestRz: -0.02, neckRz: -0.72, headRz: -0.38, headRy: -0.40,
      backIk: 0, backFold: [1.02, -1.80, 0.24],
      frontIk: 0, frontFold: [0.98, -1.60, 0.12],
      tailCurl: 0.16, tailSide: 0.72,
      breath: 1.52, eyes: 0.50
    },
    groomTail: {
      rootHeight: -0.252, rootPitch: 0.29,
      spineRz: 0.26, chestRz: 0.17, neckRz: -1.08, headRz: -0.38, headRy: -1.05,
      backIk: 0, backFold: [1.46, -2.84, 0.32],
      frontIk: 0, frontFold: [1.02, -2.26, 0.10],
      tailCurl: 1.18, tailSide: 1.34,
      breath: 1.2, eyes: 0.48
    },
    groomHaunch: {
      rootHeight: -0.258, rootPitch: 0.27,
      spineRz: 0.30, chestRz: 0.19, neckRz: -1.04, headRz: -0.42, headRy: -0.74,
      backIk: 0, backFold: [1.34, -2.58, 0.24],
      backFoldL: [1.88, -2.14, 0.04],
      frontIk: 0, frontFold: [1.10, -2.36, 0.12],
      tailCurl: 0.44, tailSide: 1.08,
      breath: 1.18, eyes: 0.50
    },
    bugEat: {
      // Caught-a-bug crouch: shoulders low, one paw cups the catch, head
      // dips and chews with tiny possessive adjustments.
      rootHeight: -0.205, rootPitch: 0.18,
      spineRz: 0.14, chestRz: 0.10, neckRz: -0.72, headRz: -0.34,
      frontIkL: 0, frontFoldL: [1.18, -2.34, 0.18],
      frontIkR: 0, frontFoldR: [0.82, -2.08, 0.10],
      backIk: 0, backFold: [1.18, -2.65, 0.30],
      tailCurl: 0.32, tailSide: 0.62,
      breath: 1.25, eyes: 0.92
    },
    loaf: {
      // Compact "all paws tucked" rest: close to lie, but with the head
      // carried higher and the body gathered into a neat warm oval.
      rootHeight: -0.265, rootPitch: 0.03,
      spineRz: 0.05, chestRz: -0.03, neckRz: -0.14, headRz: -0.02,
      backIk: 0, backFold: [1.42, -2.95, 0.18],
      frontIk: 0, frontFold: [1.22, -2.72, 0.16],
      tailCurl: 0.46, tailSide: 1.05,
      breath: 1.45, eyes: 0.82
    },
    lie: {
      // Belly settles into the ground (the fur spread sells the loaf) and
      // the folded legs tuck up inside the body silhouette.
      rootHeight: -0.265, rootPitch: 0.05,
      neckRz: -0.18, headRz: -0.08,
      backIk: 0, backFold: [1.40, -2.90, 0.15],
      frontIk: 0, frontFold: [1.30, -2.70, 0.10],
      tailCurl: 0.25, tailSide: 0.95,
      breath: 1.4, eyes: 0.85
    },
    sleep: {
      rootHeight: -0.275, rootPitch: 0.05,
      neckRz: -0.62, headRz: -0.42, headRy: 0.25,
      backIk: 0, backFold: [1.40, -2.90, 0.15],
      frontIk: 0, frontFold: [1.30, -2.70, 0.10],
      tailCurl: 0.30, tailSide: 1.25,
      breath: 2.3, eyes: 0
    },
    stretch: {
      rootHeight: -0.07, rootPitch: -0.48,
      neckRz: 0.55, headRz: 0.40,
      frontTargetX: 0.62, frontTargetY: 0.05,
      tailCurl: -0.55, tailSide: 0,
      breath: 1.2, eyes: 0.7
    },
    stalk: {
      // Hunting creep: body dropped, head low and thrust forward, tail
      // streaming flat behind.
      rootHeight: -0.13, rootPitch: 0.0,
      spineRz: -0.02, neckRz: 0.30, headRz: 0.20,
      tailCurl: -0.28, tailSide: 0,
      breath: 1.3, eyes: 1
    },
    scratchEar: {
      // Sit base with the head dipped toward the raised hind paw; the
      // fast scratching oscillation is layered on in update.
      rootHeight: -0.246, rootPitch: 0.35,
      spineRz: 0.22, chestRz: 0.16, neckRz: -0.78, headRz: -0.42,
      headRx: 0.42,
      backIk: 0, backFold: [1.48, -3.05, 1.44],
      backFoldL: [2.60, -1.10, 0.20],
      frontTargetX: 0.27, frontTargetY: 0.05,
      tailCurl: 0.70, tailSide: 0.80,
      breath: 1.2, eyes: 0.4
    },
    wallInspect: {
      rootHeight: -0.015, rootPitch: -0.03,
      spineRz: 0.03, chestRz: 0.04, neckRz: 0.20, headRz: 0.09, headRy: -0.12,
      frontTargetX: 0.38, frontTargetY: 0.05,
      tailCurl: -0.34, tailSide: 0.26,
      breath: 1.05, eyes: 1
    },
    wallRub: {
      rootHeight: -0.035, rootPitch: -0.08,
      spineRz: 0.09, chestRz: 0.08, neckRz: 0.16, headRz: 0.10, headRy: -0.18,
      frontTargetX: 0.38, frontTargetY: 0.05,
      tailCurl: -0.58, tailSide: 0.76,
      breath: 1.05, eyes: 0.9
    },
    wallScratch: {
      // Rearing up against the screen edge like a scratching post: hind
      // feet planted, body pitched up tall, back arched, both front paws
      // reaching high overhead. Alternating drag strokes layer in after IK.
      rootHeight: 0.04, rootPitch: 0.82,
      spineRz: 0.12, chestRz: 0.14, neckRz: 0.26, headRz: 0.14,
      frontIk: 0, frontFold: [1.55, -0.30, -0.42],
      tailCurl: -0.50, tailSide: 0.15,
      breath: 1.25, eyes: 0.95
    },
    dockInspect: {
      rootHeight: -0.115, rootPitch: -0.08,
      spineRz: -0.03, chestRz: 0.02, neckRz: 0.42, headRz: 0.28,
      frontTargetX: 0.43, frontTargetY: 0.05,
      tailCurl: -0.16, tailSide: 0.18,
      breath: 1.2, eyes: 1
    },
    dockPaw: {
      rootHeight: -0.095, rootPitch: -0.03,
      spineRz: -0.02, chestRz: 0.02, neckRz: 0.36, headRz: 0.24,
      frontTargetX: 0.40, frontTargetY: 0.05,
      tailCurl: -0.20, tailSide: 0.12,
      breath: 1.1, eyes: 1
    },
    mouseCling: {
      // Hanging from the cursor: body pitched nearly vertical (nose up),
      // both forelegs extended overhead with paws hooked on the grip point,
      // everything below the shoulders limp — hind legs dangling long, tail
      // hanging. The exact paw-to-cursor anchor is measured at runtime.
      rootHeight: 0, rootPitch: 1.24,
      spineRz: 0.08, chestRz: 0.12, neckRz: 0.30, headRz: 0.16,
      frontIk: 0, frontFold: [1.95, -0.28, -0.42],
      backIk: 0, backFold: [-0.92, -0.18, 0.06],
      tailCurl: -0.34, tailSide: 0.04,
      breath: 1.5, eyes: 1
    },
    lungeAir: {
      // Mid-leap: body stretched along the flight arc, forelegs shot out
      // ahead with paws spread to trap, hind legs trailing fully extended.
      rootHeight: 0, rootPitch: 0.30,
      spineRz: -0.06, chestRz: -0.04, neckRz: 0.30, headRz: 0.18,
      frontIk: 0, frontFold: [-0.55, -0.18, -0.30],
      backIk: 0, backFold: [-0.62, 0.30, 0.18],
      tailCurl: -0.42, tailSide: 0,
      breath: 1.3, eyes: 1
    },
    bellyUp: {
      // Sprawled on its back, belly to the sky, paws curled loosely over
      // the chest, head lolled toward the viewer. Pure trust.
      rootHeight: -0.265, rootPitch: 0.06, rootRoll: 2.45,
      neckRz: -0.26, headRz: -0.12, headRy: -0.30,
      backIk: 0, backFold: [1.05, -1.95, 0.30],
      frontIk: 0, frontFold: [0.85, -1.75, 0.22],
      tailCurl: 0.18, tailSide: 0.80,
      breath: 1.55, eyes: 0.72
    },
    playOnBack: {
      // Same sprawl but switched on: paws up boxing the air, eyes wide,
      // tail whipping. The batting strokes layer in after IK.
      rootHeight: -0.29, rootPitch: 0.06, rootRoll: 2.35,
      neckRz: -0.32, headRz: -0.16, headRy: -0.34,
      backIk: 0, backFold: [1.30, -2.05, 0.22],
      frontIk: 0, frontFold: [1.15, -1.60, 0.05],
      tailCurl: 0.12, tailSide: 0.55,
      breath: 1.2, eyes: 1
    },
    bellyPet: {
      // Belly-rub trust pose: still on the back, but softer and more liquid
      // than playOnBack. Paws knead, hips roll, and the head nudges the hand.
      rootHeight: -0.285, rootPitch: 0.04, rootRoll: 2.55,
      neckRz: -0.34, headRz: -0.18, headRy: -0.22,
      backIk: 0, backFold: [1.18, -1.88, 0.18],
      frontIk: 0, frontFold: [1.05, -1.58, 0.12],
      tailCurl: 0.10, tailSide: 0.70,
      breath: 1.75, eyes: 0.42
    },
    wallClimb: {
      // Vertical against the screen edge, hugging it: forelegs hooked high,
      // hind legs braced under the body. The paw-over-paw cycle layers in
      // per-frame, driven by climb height so the feet match the ascent.
      rootHeight: 0, rootPitch: 1.36,
      spineRz: 0.07, chestRz: 0.09, neckRz: 0.32, headRz: 0.18,
      frontIk: 0, frontFold: [1.70, -0.42, -0.46],
      backIk: 0, backFold: [-0.42, -0.55, 0.16],
      tailCurl: -0.48, tailSide: 0.10,
      breath: 1.4, eyes: 1
    },
    wallHang: {
      // Holding position on the wall: same hug, settled and breathing,
      // claws doing the work. Waits to be tapped down.
      rootHeight: 0, rootPitch: 1.36,
      spineRz: 0.05, chestRz: 0.07, neckRz: 0.26, headRz: 0.12,
      frontIk: 0, frontFold: [1.78, -0.36, -0.52],
      backIk: 0, backFold: [-0.36, -0.50, 0.14],
      tailCurl: -0.36, tailSide: 0.14,
      breath: 1.5, eyes: 0.95
    },
    petted: {
      // Standing into the stroke: mid-back arched up toward the hand, head
      // tipped, tail raised. Purr vibration and lean layer in per-frame.
      rootHeight: 0.015, rootPitch: 0.05,
      spineRz: -0.10, chestRz: -0.06, neckRz: -0.16, headRz: -0.10,
      tailCurl: -0.85, tailSide: 0.20,
      breath: 1.35, eyes: 0.5
    }
  };

  const GROOM_POSE_TARGETS = {
    groom: 'paw',
    groomPaw: 'paw',
    groomFace: 'face',
    groomFlank: 'flank',
    groomBelly: 'belly',
    groomTail: 'tail',
    groomHaunch: 'haunch'
  };

  function isGroomingPoseName(name) {
    return Object.prototype.hasOwnProperty.call(GROOM_POSE_TARGETS, name);
  }

  function damp(current, target, rate, dt) {
    return current + (target - current) * Math.min(1, rate * dt);
  }

  const ZERO_FOLD = [0, 0, 0];

  // 2-bone IK in the x/y plane. Returns absolute world angles (rotation
  // from straight-down) for thigh and the relative knee/ankle bends.
  // Writes into a shared scratch object — consume before the next call.
  const ikScratch = { thighAbs: 0, shinRel: 0 };
  function solveLeg(leg, hipX, hipY, targetX, targetY) {
    let dx = targetX - hipX;
    let dy = targetY - hipY;
    let dist = Math.sqrt(dx * dx + dy * dy);
    const maxReach = leg.l1 + leg.l2 - 0.005;
    const minReach = Math.abs(leg.l1 - leg.l2) + 0.02;
    dist = THREE.MathUtils.clamp(dist, minReach, maxReach);
    const phi = Math.atan2(dx, -dy);
    const cosBeta = (leg.l1 * leg.l1 + dist * dist - leg.l2 * leg.l2) / (2 * leg.l1 * dist);
    const beta = Math.acos(THREE.MathUtils.clamp(cosBeta, -1, 1));
    const cosKnee = (leg.l1 * leg.l1 + leg.l2 * leg.l2 - dist * dist) / (2 * leg.l1 * leg.l2);
    const knee = Math.acos(THREE.MathUtils.clamp(cosKnee, -1, 1));
    ikScratch.thighAbs = phi + leg.bend * beta;
    ikScratch.shinRel = -leg.bend * (Math.PI - knee);
    return ikScratch;
  }

  function create(rig) {
    const bones = rig.bones;
    // Rest heights of the front-leg roots, for the scapula slide: a cat's
    // shoulder blade glides with the stride, so the whole front-leg
    // attachment translates vertically — the signature shoulder roll.
    const shoulderBaseY = {
      frontL: bones.shoulderFL.position.y,
      frontR: bones.shoulderFR.position.y
    };
    const state = {
      poseName: 'stand',
      // Damped channel values; targets come from the active pose.
      ch: {
        rootHeight: 0, rootPitch: 0, rootRoll: 0, spineRz: 0, chestRz: 0,
        neckRz: 0, neckRy: 0, headRx: 0, headRy: 0, headRz: 0,
        tailCurl: 0, tailSide: 0, breath: 1, eyes: 1,
        backIkL: 1, backIkR: 1, frontIkL: 1, frontIkR: 1,
        frontTargetX: 0.31, frontTargetY: 0.05
      },
      foldCh: {
        backL: [0, 0, 0], backR: [0, 0, 0], frontL: [0, 0, 0], frontR: [0, 0, 0]
      },
      speed: 0,
      targetSpeed: 0,
      gait: 'walk',
      heading: 1,
      yaw: -0.18,
      worldX: 0,
      worldY: 0,
      gaitPhase: Math.random(),
      groomCycle: 0,
      blinkTimer: 2 + Math.random() * 3,
      blinkPhase: 1,
      isSlowBlink: false,    // slow affectionate "cat kiss" vs the reflex blink
      lookTimer: 1,
      lookTarget: { ry: 0, rx: 0 },
      lookOverride: null,
      lookPitch: 0,
      swipe: { t: 1, leg: 'frontL', style: 'bat' },
      dockPaw: { t: 1, leg: 'frontL' },
      bugEat: { t: 1 },
      // Pendulum state while clinging to the cursor: carry velocity feeds a
      // spring-damped swing angle so the body trails the grip point.
      clingVelX: 0,
      clingVelY: 0,
      clingSwing: 0,
      clingSwingVel: 0,
      clingStress: 0,
      clingLegLag: 0,
      // Front paw tip anchor, measured each cling/lunge frame so behavior
      // can pin the paws exactly on the cursor.
      pawAnchorX: 0.16,
      pawAnchorYAbs: 1.0,
      headOffsetX: 0.55,
      lunge: { t: 1, duration: 0.45, pitch: 0, style: 'flyingGrab' },
      land: 1,
      agility: 1,
      petPulse: 0,
      // Pre-pounce butt-wiggle / hindquarter coil, and the agitated tail
      // lash (overstimulation, thwarted hunt). Both idle at t>=1.
      wiggle: { t: 1, duration: 0.5 },
      tailLash: { t: 1, duration: 0.7, intensity: 1 },
      // Anatomy/physiology layer.
      arousal: 0,          // pupil dilation + alertness, set by behavior
      arousalSmooth: 0,
      effort: 0,           // muscle load → haunch bulge
      gaitNoise: 0,        // per-stride tempo wobble so steps aren't metronomic
      gaitNoiseTarget: 0,
      gaitNoiseTimer: 0,
      neckLag: 0,          // follow-through on vertical accelerations
      clawOut: 0,          // retractable claws: extended while climbing/raking
      // Where the stroking hand is (world units), which way it's moving,
      // and how firmly. Refreshed by behavior; fades if not renewed.
      petContact: { x: 0, y: -10, dir: 0, amp: 0, timer: 0 },
      pounce: 1,
      pounceStyle: 'groundPounce',
      earFlickTimer: 1.5 + Math.random() * 4,
      earFlickPhase: 1,
      time: 0,
      prevRootPos: new THREE.Vector3(0, ROOT_REST_Y, 0),
      hasPrevRootPos: false,
      rawVelocity: new THREE.Vector3(),
      velocity: new THREE.Vector3()
    };

    function setPose(name) {
      state.poseName = POSES[name] ? name : 'stand';
    }

    function poseTarget(key, fallback) {
      const pose = POSES[state.poseName];
      return pose[key] !== undefined ? pose[key] : fallback;
    }

    function groomingTarget() {
      return GROOM_POSE_TARGETS[state.poseName] || null;
    }

    function updateChannels(dt) {
      const ch = state.ch;
      const rate = 5.5;
      ch.rootHeight = damp(ch.rootHeight, poseTarget('rootHeight', 0), rate, dt);
      ch.rootPitch = damp(ch.rootPitch, poseTarget('rootPitch', 0), rate, dt);
      // Rolling over is a slower, whole-body motion than a pose blend.
      ch.rootRoll = damp(ch.rootRoll, poseTarget('rootRoll', 0), 3.6, dt);
      ch.spineRz = damp(ch.spineRz, poseTarget('spineRz', 0), rate, dt);
      ch.chestRz = damp(ch.chestRz, poseTarget('chestRz', 0), rate, dt);
      // The head and neck are lighter than the torso: they settle into a
      // new pose noticeably faster, which is most of what reads as feline
      // quickness in pose changes.
      ch.neckRz = damp(ch.neckRz, poseTarget('neckRz', 0), 7.5, dt);
      ch.headRz = damp(ch.headRz, poseTarget('headRz', 0), 7.5, dt);
      ch.headRy = damp(ch.headRy, poseTarget('headRy', 0), 7.5, dt);
      ch.tailCurl = damp(ch.tailCurl, poseTarget('tailCurl', 0), rate, dt);
      ch.tailSide = damp(ch.tailSide, poseTarget('tailSide', 0), rate, dt);
      ch.breath = damp(ch.breath, poseTarget('breath', 1), rate, dt);
      ch.eyes = damp(ch.eyes, poseTarget('eyes', 1), 7, dt);
      ch.frontTargetX = damp(ch.frontTargetX, poseTarget('frontTargetX', 0.31), rate, dt);
      ch.frontTargetY = damp(ch.frontTargetY, poseTarget('frontTargetY', 0.05), rate, dt);

      const backIk = poseTarget('backIk', 1);
      const frontIk = poseTarget('frontIk', 1);
      ch.backIkL = damp(ch.backIkL, backIk, rate, dt);
      ch.backIkR = damp(ch.backIkR, backIk, rate, dt);
      ch.frontIkL = damp(ch.frontIkL, poseTarget('frontIkL', frontIk), rate, dt);
      ch.frontIkR = damp(ch.frontIkR, poseTarget('frontIkR', frontIk), rate, dt);

      const backFold = poseTarget('backFold', ZERO_FOLD);
      const frontFold = poseTarget('frontFold', ZERO_FOLD);
      dampFold('backL', poseTarget('backFoldL', backFold), rate, dt);
      dampFold('backR', poseTarget('backFoldR', backFold), rate, dt);
      dampFold('frontL', poseTarget('frontFoldL', frontFold), rate, dt);
      dampFold('frontR', poseTarget('frontFoldR', frontFold), rate, dt);
    }

    function dampFold(key, target, rate, dt) {
      const fold = state.foldCh[key];
      for (let i = 0; i < 3; i++) {
        fold[i] = damp(fold[i], target[i], rate, dt);
      }
    }

    // Reused across the four applyLeg calls each frame — no per-frame garbage.
    const footTarget = { x: 0, y: 0 };

    function gaitFootTarget(leg, legKey, walkAmp) {
      const gait = GAITS[state.gait] || GAITS.walk;
      const phaseOffset = state.gait === 'trot' ? TROT_PHASES[legKey] : leg.phase;
      const p = (state.gaitPhase + phaseOffset) % 1;
      const stride = gait.stride * walkAmp;
      let xRel;
      let lift = 0;
      if (p < gait.stanceFrac) {
        xRel = stride * (0.5 - p / gait.stanceFrac);
      } else {
        const q = (p - gait.stanceFrac) / (1 - gait.stanceFrac);
        xRel = stride * (q - 0.5);
        lift = leg.lift * Math.sin(q * Math.PI) * walkAmp * gait.liftMult;
      }
      footTarget.x = leg.homeX + xRel;
      footTarget.y = leg.plantY + lift;
    }

    function applyLeg(legKey, ikWeight, dt) {
      const leg = LEGS[legKey];
      const ch = state.ch;
      const walkAmp = THREE.MathUtils.clamp(state.speed / 0.5, 0, 1.6);
      const isFront = legKey.startsWith('front');

      // Leg-root joint position in body-local space. Hind hips hang off the
      // root directly; front shoulders ride the root->spine->chest chain, so
      // spine/chest pitch must displace them or bent poses detach the legs.
      const pivotY = ROOT_REST_Y + ch.rootHeight;
      let hipX;
      let hipY;
      if (isFront) {
        const a0 = ch.rootPitch;
        const a1 = a0 + ch.spineRz;
        const a2 = a1 + ch.chestRz;
        // Rest offsets along the chain, each rotated by its segment angle:
        // pivot->spine (-0.02, 0.03), spine->chest (0.28, -0.01),
        // chest->shoulder joint (0.04, -0.04) — from the bone definitions.
        hipX = 0;
        hipY = pivotY;
        let c = Math.cos(a0);
        let s = Math.sin(a0);
        hipX += -0.02 * c - 0.03 * s;
        hipY += -0.02 * s + 0.03 * c;
        c = Math.cos(a1);
        s = Math.sin(a1);
        hipX += 0.28 * c + 0.01 * s;
        hipY += 0.28 * s - 0.01 * c;
        c = Math.cos(a2);
        s = Math.sin(a2);
        hipX += 0.04 * c + 0.04 * s;
        hipY += 0.04 * s - 0.04 * c;
      } else {
        const cosP = Math.cos(ch.rootPitch);
        const sinP = Math.sin(ch.rootPitch);
        hipX = leg.hip[0] * cosP - leg.hip[1] * sinP;
        hipY = pivotY + leg.hip[0] * sinP + leg.hip[1] * cosP;
      }

      if (walkAmp > 0.02) {
        gaitFootTarget(leg, legKey, Math.min(walkAmp, 1));
      } else if (isFront) {
        footTarget.x = ch.frontTargetX;
        footTarget.y = ch.frontTargetY;
      } else {
        footTarget.x = leg.homeX;
        footTarget.y = leg.plantY;
      }
      // Scapula slide: the shoulder drops as that leg loads (stance) and
      // rides up in swing. Translating the leg root sells the rolling
      // shoulder-blade silhouette of a walking cat.
      if (isFront) {
        const phaseOffset = state.gait === 'trot' ? TROT_PHASES[legKey] : leg.phase;
        const legPhase = (state.gaitPhase + phaseOffset) % 1;
        const bone = bones[leg.thigh];
        bone.position.y = shoulderBaseY[legKey]
          - Math.cos(legPhase * Math.PI * 2) * 0.022 * walkAmp;
      }
      // Groom: the raised paw bobs as the cat licks it.
      if ((state.poseName === 'groom' || state.poseName === 'groomPaw')
          && legKey === 'frontL' && ikWeight < 0.5) {
        state.foldCh.frontL[1] = POSES.groomPaw.frontFoldL[1] + Math.sin(state.time * 7.5) * 0.18;
      }

      const ik = solveLeg(leg, hipX, hipY, footTarget.x, footTarget.y);
      let parentAngle = ch.rootPitch;
      for (const parent of leg.parents) {
        parentAngle += parent === 'hips' ? 0 : (parent === 'spine' ? ch.spineRz : ch.chestRz);
      }
      const ikThigh = ik.thighAbs - parentAngle;
      const ikShin = ik.shinRel;
      const ikFoot = -(ik.thighAbs + ik.shinRel);

      const fold = state.foldCh[legKey];
      // Overlays (cling paw-pinch) set thigh x-rotation; reset it here so
      // it never leaks into other states.
      bones[leg.thigh].rotation.x = 0;
      bones[leg.thigh].rotation.z = ikThigh * ikWeight + fold[0] * (1 - ikWeight);
      bones[leg.shin].rotation.z = ikShin * ikWeight + fold[1] * (1 - ikWeight);
      bones[leg.foot].rotation.z = ikFoot * ikWeight + fold[2] * (1 - ikWeight);
    }

    function applyTail(dt) {
      const ch = state.ch;
      const walkAmp = THREE.MathUtils.clamp(state.speed / 0.5, 0, 1);
      const idleFlick = Math.sin(state.time * 1.3) * 0.5 + Math.sin(state.time * 0.37) * 0.5;
      for (let i = 1; i <= 6; i++) {
        const bone = bones['tail' + i];
        const along = i / 6;
        // Base curl + side wrap (poses) + travelling sway wave (alive).
        bone.rotation.z = ch.tailCurl * 0.38 * (i === 1 ? 1.6 : 1) - along * ch.tailCurl * 0.10;
        const sway = Math.sin(state.time * (1.6 + walkAmp * 2.2) - i * 0.85);
        bone.rotation.y = ch.tailSide * 0.34
          + sway * (0.05 + walkAmp * 0.10) * along
          + idleFlick * 0.05 * along * (1 - walkAmp);
      }
      // Tail-tip flick while idle: cats telegraph mood with the last joint.
      bones.tail6.rotation.y += Math.sin(state.time * 2.1 + 1.7) * 0.22 * (1 - walkAmp);
    }

    function applyBlink(dt) {
      // Only start a new blink once the previous one has fully opened, so a
      // slow blink is never cut short by the reflex timer.
      if (state.blinkTimer > 0) state.blinkTimer -= dt;
      if (state.blinkTimer <= 0 && state.blinkPhase >= 1) {
        // When calm and content the cat offers a slow blink — the feline
        // "I trust you." Otherwise it's an ordinary fast reflex blink.
        const calm = (state.poseName === 'sit' || state.poseName === 'lie'
            || state.poseName === 'loaf' || state.poseName === 'petted'
            || state.poseName === 'bellyUp' || state.poseName === 'bellyPet'
            || isGroomingPoseName(state.poseName))
          && state.arousalSmooth < 0.28;
        if (calm && Math.random() < 0.4) {
          state.isSlowBlink = true;
          state.blinkTimer = 4 + Math.random() * 7;
        } else {
          state.isSlowBlink = false;
          state.blinkTimer = 1.8 + Math.random() * 4.5;
        }
        state.blinkPhase = 0;
      }

      let blink;
      if (state.isSlowBlink) {
        // ~1.5s: ease the lids down, hold them nearly shut, ease back open.
        state.blinkPhase = Math.min(1, state.blinkPhase + dt / 1.5);
        const t = state.blinkPhase;
        const peak = 0.88;
        if (t < 0.30) blink = THREE.MathUtils.smoothstep(t / 0.30, 0, 1) * peak;
        else if (t < 0.60) blink = peak;
        else blink = (1 - THREE.MathUtils.smoothstep((t - 0.60) / 0.40, 0, 1)) * peak;
      } else {
        state.blinkPhase = Math.min(1, state.blinkPhase + dt / 0.13);
        blink = Math.sin(state.blinkPhase * Math.PI);
      }

      // Arousal opens the eyes a touch wider (alert); a calm cat's eyes
      // settle softer. Subtle so it reads as mood, not a cartoon.
      const widen = 1 + state.arousalSmooth * 0.13;
      const open = THREE.MathUtils.clamp(state.ch.eyes * widen * (1 - blink), 0.04, 1.12);
      const closed = THREE.MathUtils.clamp(1 - open, 0, 1);
      for (const { eye, upperLid, lowerLid, upperBaseY, lowerBaseY } of rig.eyes) {
        eye.scale.y = open;
        if (upperLid && lowerLid) {
          upperLid.position.y = upperBaseY - closed * 0.026;
          lowerLid.position.y = lowerBaseY + closed * 0.012;
          upperLid.scale.y = 0.18 + closed * 0.34;
          lowerLid.scale.y = 0.115 + closed * 0.18;
        }
      }
    }

    function applyHeadLook(dt) {
      // Explicit gaze target (the mouse) wins over idle wandering.
      if (state.lookOverride) {
        const look = state.lookOverride;
        const headY = ROOT_REST_Y + state.ch.rootHeight + 0.20;
        const dx = look.x - state.worldX;
        const inFront = dx * state.heading >= -0.05;
        const pitch = THREE.MathUtils.clamp(
          Math.atan2(look.y - headY, Math.max(0.18, Math.abs(dx))), -0.65, 0.55
        );
        // The mouse lives on the screen plane, slightly viewer-side; behind
        // the cat it looks over its shoulder the viewer-facing way.
        const ry = inFront ? -0.40 : -1.05;
        state.ch.headRy = damp(state.ch.headRy, poseTarget('headRy', 0) + ry, 6.5, dt);
        state.ch.headRx = damp(state.ch.headRx, poseTarget('headRx', 0), 6.5, dt);
        state.lookPitch = damp(state.lookPitch, pitch * 0.8, 6.5, dt);
        return;
      }
      state.lookPitch = damp(state.lookPitch, 0, 3.2, dt);
      state.lookTimer -= dt;
      if (state.lookTimer <= 0) {
        state.lookTimer = 1.5 + Math.random() * 4;
        if (state.speed > 0.05) {
          state.lookTarget = { ry: (Math.random() - 0.5) * 0.3, rx: 0 };
        } else if (Math.random() < 0.22) {
          // Look toward the viewer.
          state.lookTarget = { ry: -0.85, rx: (Math.random() - 0.5) * 0.15 };
        } else {
          state.lookTarget = { ry: (Math.random() - 0.5) * 1.0, rx: (Math.random() - 0.5) * 0.3 };
        }
      }
      state.ch.headRy = damp(state.ch.headRy, poseTarget('headRy', 0) + state.lookTarget.ry, 3.2, dt);
      state.ch.headRx = damp(state.ch.headRx, poseTarget('headRx', 0) + state.lookTarget.rx, 3.2, dt);
    }

    // Quick instinctive swat: raise, strike forward-down, recover. Runs as
    // an overlay on top of whatever the leg was doing.
    function applySwipe(dt) {
      if (state.swipe.t >= 1) return;
      const style = state.swipe.style || 'bat';
      const duration = style === 'probe' ? 0.30 : style === 'hook' ? 0.50 : 0.42;
      state.swipe.t = Math.min(1, state.swipe.t + dt / duration);
      const t = state.swipe.t;
      const leg = LEGS[state.swipe.leg];
      // Raise 0-0.25, strike 0.25-0.6, recover 0.6-1.
      let fold;
      const raiseEnd = style === 'probe' ? 0.18 : 0.25;
      const strikeEnd = style === 'probe' ? 0.52 : style === 'hook' ? 0.66 : 0.60;
      const reachScale = style === 'probe' ? 0.62 : style === 'hook' ? 1.12 : 1;
      if (t < raiseEnd) {
        const q = t / raiseEnd;
        fold = [1.05 * reachScale * q, -1.9 * reachScale * q, 0.2 * q];
      } else if (t < strikeEnd) {
        const q = (t - raiseEnd) / (strikeEnd - raiseEnd);
        const strike = Math.sin(q * Math.PI);
        const hook = style === 'hook' ? Math.sin(q * Math.PI * 0.5) : 0;
        fold = [
          1.05 * reachScale + strike * (style === 'probe' ? 0.42 : 0.85),
          -1.9 * reachScale + strike * (style === 'hook' ? 1.72 : 1.45) + hook * 0.32,
          0.2 - strike * (style === 'probe' ? 0.32 : 0.6) - hook * 0.36
        ];
      } else {
        const q = (t - strikeEnd) / (1 - strikeEnd);
        fold = [
          1.05 * reachScale * (1 - q),
          -1.9 * reachScale * (1 - q),
          0.2 * (1 - q)
        ];
      }
      // Bell-shaped blend: ramps in during the raise, fades out through the
      // recover so the leg eases back into IK without snapping.
      const blend = Math.pow(Math.sin(Math.min(t, 1) * Math.PI), 0.75);
      bones[leg.thigh].rotation.z = bones[leg.thigh].rotation.z * (1 - blend) + fold[0] * blend;
      bones[leg.shin].rotation.z = bones[leg.shin].rotation.z * (1 - blend) + fold[1] * blend;
      bones[leg.foot].rotation.z = bones[leg.foot].rotation.z * (1 - blend) + fold[2] * blend;
      if (style === 'crossBat') {
        bones[leg.thigh].rotation.x += (state.swipe.leg === 'frontL' ? -0.18 : 0.18) * blend;
      } else if (style === 'hook') {
        bones[leg.thigh].rotation.x += (state.swipe.leg === 'frontL' ? 0.08 : -0.08) * blend;
      }
      // Crouch into the swat.
      const crouch = Math.sin(t * Math.PI) * (style === 'probe' ? 0.028 : style === 'hook' ? 0.065 : 0.05);
      bones.root.position.y -= crouch;
      bones.root.rotation.z += crouch * 0.8;
    }

    // Hop-pounce: a short forward leap arc; behavior drives the ground
    // speed while this shapes the body.
    function applyPounce(dt) {
      if (state.pounce >= 1) return;
      const style = state.pounceStyle || 'groundPounce';
      const duration = style === 'sidePounce' ? 0.42 : 0.5;
      state.pounce = Math.min(1, state.pounce + dt / duration);
      const t = state.pounce;
      const lift = style === 'sidePounce' ? 0.12 : 0.15;
      bones.root.position.y += Math.sin(t * Math.PI) * lift;
      bones.root.rotation.z += Math.sin(t * Math.PI * 2) * (style === 'sidePounce' ? -0.06 : -0.10);
      if (style === 'sidePounce') {
        bones.root.rotation.y += Math.sin(t * Math.PI) * (state.heading > 0 ? -0.22 : 0.22);
        bones.chest.rotation.y += Math.sin(t * Math.PI) * (state.heading > 0 ? -0.12 : 0.12);
      }
    }

    // The pre-pounce butt-wiggle: hindquarters drop and load, the rear
    // waggles side to side as it ranges the target, weight rocks back, the
    // tail-tip twitches — the universally recognized "about to pounce" tell.
    // An envelope ramps the waggle in and lets it settle before the launch.
    function applyWiggle(dt) {
      if (state.wiggle.t >= 1) return;
      state.wiggle.t = Math.min(1, state.wiggle.t + dt / state.wiggle.duration);
      const t = state.wiggle.t;
      const env = Math.sin(Math.min(1, t) * Math.PI);   // 0→1→0 over the beat
      // Fast lateral hip waggle; the rear leads, the shoulders barely move.
      const waggle = Math.sin(state.time * 38) * 0.06 * env;
      bones.hips.rotation.y += waggle;
      bones.hips.rotation.x += Math.abs(Math.sin(state.time * 38)) * 0.03 * env;
      bones.spine.rotation.y += waggle * 0.4;
      // Load the haunches: rear settles down and back before the spring.
      bones.root.position.y -= 0.05 * env;
      bones.root.rotation.z -= 0.05 * env;        // nose dips, rump up
      // Tail tip flicks with the excitement.
      bones.tail6.rotation.y += Math.sin(state.time * 22) * 0.28 * env;
      bones.tail5.rotation.y += Math.sin(state.time * 22) * 0.16 * env;
      state.effort = Math.max(state.effort, 0.6 * env);
    }

    // Agitated tail lash: big, slow side-to-side whips of the whole tail —
    // overstimulation while petted, or a thwarted hunt. Layered after the
    // normal tail so it dominates while active.
    function applyTailLash(dt) {
      if (state.tailLash.t >= 1) return;
      state.tailLash.t = Math.min(1, state.tailLash.t + dt / state.tailLash.duration);
      const t = state.tailLash.t;
      const env = Math.sin(Math.min(1, t) * Math.PI);
      const amp = (0.5 + state.tailLash.intensity * 0.5) * env;
      const lash = Math.sin(state.time * 9.5);
      for (let i = 1; i <= 6; i++) {
        const along = i / 6;
        bones['tail' + i].rotation.y += lash * amp * (0.20 + along * 0.55);
      }
      // A flick of irritation runs up into the hips.
      bones.hips.rotation.y += lash * amp * 0.06;
    }

    // Hind-leg ear scratch: fast oscillation layered over the scratchEar
    // pose, head tilted into it.
    function applyScratch() {
      if (state.poseName !== 'scratchEar') return;
      const wobble = Math.sin(state.time * 13);
      const leg = LEGS.backL;
      bones[leg.thigh].rotation.z += wobble * 0.06;
      bones[leg.shin].rotation.z += wobble * 0.30;
      bones.head.rotation.x += wobble * 0.05;
    }

    function blendLegFold(legKey, fold, blend) {
      const leg = LEGS[legKey];
      bones[leg.thigh].rotation.z = bones[leg.thigh].rotation.z * (1 - blend) + fold[0] * blend;
      bones[leg.shin].rotation.z = bones[leg.shin].rotation.z * (1 - blend) + fold[1] * blend;
      bones[leg.foot].rotation.z = bones[leg.foot].rotation.z * (1 - blend) + fold[2] * blend;
    }

    function setTongue(visible, extension, sideBias, curl) {
      const tongue = rig.tongue && (rig.tongue.group || rig.tongue);
      if (!tongue) return;
      tongue.visible = visible;
      if (!visible) return;
      const base = rig.tongue.basePosition || { x: 0, y: 0, z: 0 };
      const rot = rig.tongue.baseRotation || { x: 0, y: 0, z: 0 };
      tongue.position.set(
        base.x + extension * 0.034,
        base.y - extension * 0.006,
        base.z + sideBias
      );
      tongue.rotation.set(
        rot.x + curl * 0.10,
        rot.y + sideBias * 4.0,
        rot.z - 0.18 - curl * 0.28
      );
      tongue.scale.set(
        0.74 + extension * 1.02,
        0.62 + extension * 0.24,
        0.70 + extension * 0.08
      );
      if (rig.tongue.tip) {
        rig.tongue.tip.position.x = 0.022 + extension * 0.012;
        rig.tongue.tip.position.y = -0.001 - extension * 0.003;
      }
    }

    function applyGrooming(dt) {
      const target = groomingTarget();
      if (!target) {
        state.groomCycle = (state.groomCycle + dt * 0.35) % 1;
        setTongue(false, 0, 0, 0);
        return;
      }

      const cycleRate = target === 'face' ? 1.55 : target === 'tail' ? 1.85 : 2.15;
      state.groomCycle = (state.groomCycle + dt * cycleRate) % 1;
      const phase = state.groomCycle;
      const lickWindow = target === 'face' && phase > 0.54 ? 0 : 1;
      const lick = lickWindow * Math.max(0, Math.sin(Math.min(1, phase / 0.66) * Math.PI));
      const tiny = Math.sin(state.time * 19.0) * 0.010;
      const side = target === 'tail' || target === 'flank' || target === 'haunch' || target === 'belly'
        ? -0.012
        : (target === 'face' ? 0.008 : 0);
      setTongue(lick > 0.08, lick, side, Math.sin(phase * Math.PI * 2));

      // A grooming cat closes in around the target, then releases: tiny
      // head bobs, paw wipes, tail guarding, and body curls sell intent.
      const bob = Math.sin(phase * Math.PI * 2);
      bones.neck.rotation.z -= lick * 0.035 + tiny;
      bones.head.rotation.z -= lick * 0.032;
      bones.head.rotation.x += bob * 0.018;
      bones.chest.rotation.z += Math.max(0, lick) * 0.012;

      if (target === 'paw') {
        blendLegFold('frontL', [0.90 + lick * 0.22, -2.40 - lick * 0.30, 0.30 - lick * 0.10], 0.86);
        blendLegFold('frontR', [0.42, -1.22, 0.10], 0.30);
        bones.head.rotation.y += 0.16 + lick * 0.08;
      } else if (target === 'face') {
        const wipe = THREE.MathUtils.smoothstep(phase, 0.48, 1.0);
        const pawSweep = Math.sin(wipe * Math.PI);
        blendLegFold('frontL', [
          0.70 + pawSweep * 0.45,
          -2.12 - pawSweep * 0.18,
          0.18 - pawSweep * 0.38
        ], 0.88);
        bones[LEGS.frontL.thigh].rotation.x += 0.12 + pawSweep * 0.16;
        bones.head.rotation.y += 0.12 - pawSweep * 0.20;
        bones.head.rotation.z -= pawSweep * 0.05;
      } else if (target === 'flank') {
        bones.root.rotation.x += Math.sin(state.time * 1.1) * 0.035;
        bones.spine.rotation.z += 0.08 + lick * 0.05;
        bones.chest.rotation.y -= 0.10 + lick * 0.06;
        bones.head.rotation.y -= 0.26 + lick * 0.12;
        blendLegFold('frontL', [1.00, -2.26, 0.10], 0.55);
        bones.tail6.rotation.y += Math.sin(state.time * 4.2) * 0.10;
      } else if (target === 'belly') {
        bones.root.rotation.x += Math.sin(state.time * 1.4) * 0.055;
        bones.root.rotation.y += Math.sin(state.time * 0.9) * 0.045;
        bones.neck.rotation.z -= 0.05 + lick * 0.08;
        bones.head.rotation.y -= 0.18 + lick * 0.10;
        blendLegFold('backL', [1.02 + lick * 0.18, -1.80 + lick * 0.18, 0.24 - lick * 0.10], 0.60);
        blendLegFold('frontR', [0.90, -1.44, 0.05], 0.46);
      } else if (target === 'tail') {
        for (let i = 1; i <= 6; i++) {
          const along = i / 6;
          bones['tail' + i].rotation.y += 0.20 * along + Math.sin(state.time * 2.8 + i) * 0.05;
          bones['tail' + i].rotation.z += 0.10 * along;
        }
        bones.head.rotation.y -= 0.38 + lick * 0.16;
        blendLegFold('frontL', [0.94, -2.10, 0.08], 0.58);
        blendLegFold('frontR', [0.84, -1.98, 0.08], 0.46);
      } else if (target === 'haunch') {
        bones.hips.rotation.y -= 0.10 + Math.sin(state.time * 1.3) * 0.05;
        bones.spine.rotation.z += 0.05 + lick * 0.05;
        bones.head.rotation.y -= 0.24 + lick * 0.10;
        blendLegFold('backL', [1.88 + lick * 0.12, -2.14 + lick * 0.16, 0.04], 0.70);
        blendLegFold('frontL', [1.05, -2.28, 0.08], 0.52);
      }

      if (rig.whiskers) {
        for (const whisker of rig.whiskers) {
          whisker.mesh.rotation.y += whisker.side * (0.018 + lick * 0.020) * (whisker.sensitivity || 1);
        }
      }
    }

    function applyWallScratch() {
      if (state.poseName !== 'wallScratch') return;
      // Deliberate alternating strokes: each paw reaches a little higher,
      // hooks in, and drags down the "post" — slower than a swat, with the
      // whole body rising into each pull and the shoulders working.
      const cycle = state.time * 4.6;
      for (const [legKey, phase] of [['frontL', 0], ['frontR', Math.PI]]) {
        const leg = LEGS[legKey];
        const wave = Math.sin(cycle + phase);
        const reachUp = Math.max(0, wave);             // lifting to re-hook
        const dragDown = Math.max(0, -wave);           // claws raking down
        const fold = [
          1.55 + reachUp * 0.55 - dragDown * 0.45,
          -0.30 - dragDown * 0.55 + reachUp * 0.10,
          -0.42 - dragDown * 0.30
        ];
        const blend = 0.8;
        bones[leg.thigh].rotation.z = bones[leg.thigh].rotation.z * (1 - blend) + fold[0] * blend;
        bones[leg.shin].rotation.z = bones[leg.shin].rotation.z * (1 - blend) + fold[1] * blend;
        bones[leg.foot].rotation.z = bones[leg.foot].rotation.z * (1 - blend) + fold[2] * blend;
      }
      // Effort travels through the body: rise into the pull, the arch
      // deepens, hips counterbalance, head tracks the working paw.
      const effort = Math.sin(cycle * 2) * 0.5 + 0.5;
      bones.root.position.y += 0.02 + effort * 0.022;
      bones.spine.rotation.z += effort * 0.03;
      bones.chest.rotation.z += effort * 0.035;
      bones.hips.rotation.y += Math.sin(cycle) * 0.030;
      bones.head.rotation.z += Math.sin(cycle) * 0.045;
      bones.neck.rotation.z += 0.05 + effort * 0.02;
      measurePawAnchor();
    }

    // Head world offset for nose-to-wall contact during rubs/inspects.
    function measureHeadOffset() {
      bones.head.getWorldPosition(pawScratchA);
      state.headOffsetX = pawScratchA.x - state.worldX;
    }

    function applyWallRub() {
      if (state.poseName === 'wallRub' || state.poseName === 'wallInspect') {
        measureHeadOffset();
      }
      if (state.poseName !== 'wallRub') return;
      const rub = Math.sin(state.time * 2.8);
      bones.root.position.x += rub * 0.028 * state.heading;
      bones.root.rotation.z += rub * 0.035;
      bones.chest.rotation.z += rub * 0.060;
      bones.neck.rotation.y += -0.18 + rub * 0.10;
      bones.head.rotation.y += -0.28 + rub * 0.18;
      bones.head.rotation.z += rub * 0.08;
      bones.tail1.rotation.z -= 0.14;
      bones.tail2.rotation.z -= 0.10;
    }

    function applyDockPaw(dt) {
      if (state.dockPaw.t >= 1) return;
      state.dockPaw.t = Math.min(1, state.dockPaw.t + dt / 0.72);
      const t = state.dockPaw.t;
      const leg = LEGS[state.dockPaw.leg];
      let fold;
      if (t < 0.28) {
        const q = t / 0.28;
        fold = [0.95 * q, -1.75 * q, 0.14 * q];
      } else if (t < 0.62) {
        const q = (t - 0.28) / 0.34;
        const tap = Math.sin(q * Math.PI);
        fold = [0.95 + tap * 0.36, -1.75 + tap * 0.50, 0.14 - tap * 0.46];
      } else {
        const q = (t - 0.62) / 0.38;
        fold = [0.95 * (1 - q), -1.75 * (1 - q), 0.14 * (1 - q)];
      }
      const blend = Math.pow(Math.sin(t * Math.PI), 0.8);
      bones[leg.thigh].rotation.z = bones[leg.thigh].rotation.z * (1 - blend) + fold[0] * blend;
      bones[leg.shin].rotation.z = bones[leg.shin].rotation.z * (1 - blend) + fold[1] * blend;
      bones[leg.foot].rotation.z = bones[leg.foot].rotation.z * (1 - blend) + fold[2] * blend;
      bones.head.rotation.z += Math.sin(t * Math.PI) * 0.035;
      bones.neck.rotation.z += Math.sin(t * Math.PI) * 0.040;
    }

    function applyDockInspect() {
      if (state.poseName !== 'dockInspect') return;
      const sniff = Math.sin(state.time * 4.2);
      bones.head.rotation.x += sniff * 0.025;
      bones.head.rotation.z += Math.max(0, sniff) * 0.035;
      bones.neck.rotation.z += Math.max(0, -sniff) * 0.025;
    }

    function applyBugEat(dt) {
      if (state.poseName !== 'bugEat') {
        state.bugEat.t = Math.min(1, state.bugEat.t + dt * 2.5);
        return;
      }
      state.bugEat.t = Math.min(1, state.bugEat.t + dt / 2.3);
      const chew = Math.max(0, Math.sin(state.time * 13.5));
      const noseDip = Math.sin(state.time * 5.4) * 0.018;
      bones.neck.rotation.z -= 0.04 + chew * 0.035;
      bones.head.rotation.z -= 0.05 + chew * 0.030 + noseDip;
      bones.head.rotation.x += Math.sin(state.time * 8.2) * 0.018;
      bones.chest.rotation.z += chew * 0.018;

      for (const [legKey, phase] of [['frontL', 0], ['frontR', Math.PI * 0.8]]) {
        const leg = LEGS[legKey];
        const knead = Math.max(0, Math.sin(state.time * 4.8 + phase));
        const fold = legKey === 'frontL'
          ? [1.18 + knead * 0.18, -2.34 - knead * 0.18, 0.18 - knead * 0.08]
          : [0.82 + knead * 0.12, -2.08 - knead * 0.12, 0.10 - knead * 0.06];
        const blend = 0.78;
        bones[leg.thigh].rotation.z = bones[leg.thigh].rotation.z * (1 - blend) + fold[0] * blend;
        bones[leg.shin].rotation.z = bones[leg.shin].rotation.z * (1 - blend) + fold[1] * blend;
        bones[leg.foot].rotation.z = bones[leg.foot].rotation.z * (1 - blend) + fold[2] * blend;
      }
      bones.tail5.rotation.y += Math.sin(state.time * 6.0) * 0.08;
      bones.tail6.rotation.y += Math.sin(state.time * 8.8) * 0.14;
    }

    // Measured world position of the front paw tips, expressed so behavior
    // can place them exactly on the cursor regardless of how the pose
    // settles: anchorX is the paw offset from worldX, anchorYAbs is the paw
    // height with worldY factored out.
    const pawScratchA = new THREE.Vector3();
    const pawScratchB = new THREE.Vector3();
    function measurePawAnchor() {
      bones.footFL.getWorldPosition(pawScratchA);
      bones.footFR.getWorldPosition(pawScratchB);
      pawScratchA.add(pawScratchB).multiplyScalar(0.5);
      state.pawAnchorX = pawScratchA.x - state.worldX;
      state.pawAnchorYAbs = pawScratchA.y - state.worldY;
    }

    function applyMouseCling(dt) {
      if (state.poseName !== 'mouseCling') {
        state.clingSwing = damp(state.clingSwing, 0, 6, dt);
        state.clingStress = 0;
        return;
      }

      // Pendulum: the carry velocity pushes the swing angle, a spring pulls
      // it back to plumb. Fast drags make the body trail visibly; stopping
      // lets it oscillate once or twice and settle — like a real dangle.
      const swingTarget = THREE.MathUtils.clamp(-state.clingVelX * 0.20, -0.5, 0.5);
      const springK = 24;
      const springDamp = 5.5;
      state.clingSwingVel += (
        (swingTarget - state.clingSwing) * springK - state.clingSwingVel * springDamp
      ) * dt;
      state.clingSwingVel = THREE.MathUtils.clamp(state.clingSwingVel, -6, 6);
      state.clingSwing = THREE.MathUtils.clamp(
        state.clingSwing + state.clingSwingVel * dt, -0.6, 0.6
      );

      // Stress rises with how hard it's being flung: grip tightens, body
      // stays LIMP — a held cat goes slack, it doesn't scramble.
      const flung = Math.min(1, Math.hypot(state.clingVelX, state.clingVelY) * 0.4);
      state.clingStress = damp(state.clingStress, flung, 4, dt);
      const stress = state.clingStress;
      const swing = state.clingSwing * state.heading;
      const breathe = Math.sin(state.time * 2.1) * 0.012;
      const grip = Math.max(0, Math.sin(state.time * 2.6));

      // The body pendulums under the grip point (rotation.z is the sagittal
      // swing axis once the body hangs vertical).
      bones.root.rotation.z += swing * 0.9;
      bones.root.rotation.x += state.clingSwing * 0.10;

      // Forelegs: locked overhead. Slow desperate kneading, deepening with
      // stress; thigh x-rotation pinches both paws together onto the cursor.
      for (const [legKey, side, phase] of [['frontL', 1, 0], ['frontR', -1, Math.PI]]) {
        const leg = LEGS[legKey];
        const knead = Math.max(0, Math.sin(state.time * 2.6 + phase)) * (0.10 + stress * 0.12);
        // Forelegs overhead: thigh rotation cancels the body pitch so the
        // paws sit almost directly above the shoulders, hooked over.
        const fold = [
          1.95 + knead * 0.30,
          -0.28 - knead * 0.6,
          -0.42 - knead * 0.5 - stress * 0.12
        ];
        const blend = 0.92;
        bones[leg.thigh].rotation.z = bones[leg.thigh].rotation.z * (1 - blend) + fold[0] * blend;
        bones[leg.shin].rotation.z = bones[leg.shin].rotation.z * (1 - blend) + fold[1] * blend;
        bones[leg.foot].rotation.z = bones[leg.foot].rotation.z * (1 - blend) + fold[2] * blend;
        bones[leg.thigh].rotation.x = -side * (0.30 + grip * 0.06 + stress * 0.08);
      }

      // Hind legs: pure ragdoll. They trail the swing with a softer lag —
      // no kicking, no cycling, just mass on the end of a rope.
      state.clingLegLag = damp(state.clingLegLag || 0, state.clingSwing, 3.2, dt);
      const legTrail = (state.clingSwing - state.clingLegLag) * 2.2;
      for (const [legKey, splay] of [['backL', 0.07], ['backR', -0.05]]) {
        const leg = LEGS[legKey];
        // Counter-rotated against the body pitch so they dangle plumb,
        // trailing the pendulum with soft lag.
        const fold = [
          -0.92 + legTrail * 0.55 + splay + breathe * 0.4,
          -0.18 + legTrail * 0.30 - splay * 0.5,
          0.06 + legTrail * 0.15
        ];
        const blend = 0.85;
        bones[leg.thigh].rotation.z = bones[leg.thigh].rotation.z * (1 - blend) + fold[0] * blend;
        bones[leg.shin].rotation.z = bones[leg.shin].rotation.z * (1 - blend) + fold[1] * blend;
        bones[leg.foot].rotation.z = bones[leg.foot].rotation.z * (1 - blend) + fold[2] * blend;
      }

      // Tail hangs and trails the swing; the tip telegraphs the nerves.
      const tailTrail = (state.clingSwing - state.clingLegLag);
      for (let i = 1; i <= 6; i++) {
        bones['tail' + i].rotation.z += tailTrail * 0.22 * (i / 6);
      }
      bones.tail6.rotation.y += Math.sin(state.time * 5.2) * (0.10 + stress * 0.18);

      measurePawAnchor();

      // Velocity decays between behavior updates so a released drag
      // doesn't leave a phantom push.
      state.clingVelX = damp(state.clingVelX, 0, 4, dt);
      state.clingVelY = damp(state.clingVelY, 0, 4, dt);
    }

    // Paw-over-paw climb cycle, keyed to height so the feet track the
    // ascent: each foreleg alternately releases, reaches higher, hooks in,
    // and pulls, while the hind legs push in counter-phase and the body
    // bobs with each pull — the way a cat actually goes up a post.
    function applyWallClimb(dt) {
      if (state.poseName !== 'wallClimb') return;
      const cyc = state.worldY * 11 + state.time * 0.6;
      for (const [legKey, phase] of [['frontL', 0], ['frontR', Math.PI]]) {
        const leg = LEGS[legKey];
        const wave = Math.sin(cyc + phase);
        const reach = Math.max(0, wave);     // releasing + reaching higher
        const pull = Math.max(0, -wave);     // hooked in, pulling down
        const fold = [
          1.70 + reach * 0.42 - pull * 0.18,
          -0.42 - reach * 0.30 - pull * 0.10,
          -0.46 - pull * 0.26
        ];
        const blend = 0.82;
        bones[leg.thigh].rotation.z = bones[leg.thigh].rotation.z * (1 - blend) + fold[0] * blend;
        bones[leg.shin].rotation.z = bones[leg.shin].rotation.z * (1 - blend) + fold[1] * blend;
        bones[leg.foot].rotation.z = bones[leg.foot].rotation.z * (1 - blend) + fold[2] * blend;
      }
      for (const [legKey, phase] of [['backL', Math.PI], ['backR', 0]]) {
        const leg = LEGS[legKey];
        const push = Math.max(0, Math.sin(cyc + phase));
        const fold = [
          -0.42 + push * 0.34,
          -0.55 - push * 0.28,
          0.16 + push * 0.18
        ];
        const blend = 0.78;
        bones[leg.thigh].rotation.z = bones[leg.thigh].rotation.z * (1 - blend) + fold[0] * blend;
        bones[leg.shin].rotation.z = bones[leg.shin].rotation.z * (1 - blend) + fold[1] * blend;
        bones[leg.foot].rotation.z = bones[leg.foot].rotation.z * (1 - blend) + fold[2] * blend;
      }
      // The body surges with each pull; the head checks upward.
      bones.root.position.y += Math.sin(cyc * 2) * 0.014;
      bones.root.rotation.z += Math.sin(cyc) * 0.02;
      bones.head.rotation.z += Math.max(0, Math.sin(cyc * 0.5)) * 0.06;
      measurePawAnchor();
    }

    function applyWallHang() {
      if (state.poseName !== 'wallHang') return;
      // Small grip adjustments and an over-the-shoulder check toward the
      // room — it knows you're going to tap it.
      const settle = Math.sin(state.time * 1.4);
      bones.root.position.y += settle * 0.004;
      bones.head.rotation.y += Math.sin(state.time * 0.5) * 0.30 - 0.25;
      bones.tail4.rotation.y += Math.sin(state.time * 1.9) * 0.08;
      bones.tail6.rotation.y += Math.sin(state.time * 2.7) * 0.14;
      measurePawAnchor();
    }

    // Mid-air lunge shaping over the behavior-driven flight arc: a coiled
    // launch, full extension with paws reaching, then the paws sweep
    // together for the grab in the last fifth of the flight.
    function applyLunge(dt) {
      if (state.lunge.t >= 1) return;
      state.lunge.t = Math.min(1, state.lunge.t + dt / state.lunge.duration);
      const t = state.lunge.t;
      const style = state.lunge.style || 'flyingGrab';

      // Align the spine with the flight direction.
      const vy = state.velocity.y;
      const vx = Math.abs(state.velocity.x);
      const pitchBias = style === 'highGrab' ? 0.22 : style === 'lowPounce' ? -0.12 : 0;
      const flightPitch = THREE.MathUtils.clamp(
        Math.atan2(vy, Math.max(0.3, vx)) * 0.7 + pitchBias,
        -0.55,
        1.05
      );
      state.lunge.pitch = damp(state.lunge.pitch, flightPitch, 10, dt);
      bones.root.rotation.z += state.lunge.pitch;

      // Reach: paws spread during flight, snap together at the end.
      const grabStart = style === 'highGrab' ? 0.68 : style === 'sideSwipe' ? 0.82 : 0.78;
      const grabPhase = THREE.MathUtils.smoothstep(t, grabStart, 1.0);
      const reach = Math.sin(Math.min(1, t / (style === 'highGrab' ? 0.72 : 0.85)) * Math.PI * 0.5);
      const reachMult = style === 'highGrab' ? 1.20 : style === 'lowPounce' ? 0.82 : 1;
      for (const [legKey, side] of [['frontL', 1], ['frontR', -1]]) {
        const leg = LEGS[legKey];
        const leadLeg = state.heading > 0 ? 'frontL' : 'frontR';
        const leadBias = style === 'sideSwipe'
          ? (legKey === leadLeg ? 0.24 : -0.08)
          : 0;
        const hookCurl = style === 'hookGrab' ? Math.sin(grabPhase * Math.PI * 0.5) * 0.20 : 0;
        const fold = [
          (-0.55 * reach * reachMult) + grabPhase * (1.35 + leadBias),
          -0.18 - grabPhase * (0.30 + hookCurl),
          -0.30 - grabPhase * (0.10 + hookCurl)
        ];
        const blend = 0.9;
        bones[leg.thigh].rotation.z = bones[leg.thigh].rotation.z * (1 - blend) + fold[0] * blend;
        bones[leg.shin].rotation.z = bones[leg.shin].rotation.z * (1 - blend) + fold[1] * blend;
        bones[leg.foot].rotation.z = bones[leg.foot].rotation.z * (1 - blend) + fold[2] * blend;
        // Paws spread apart in flight, then converge on the prey.
        bones[leg.thigh].rotation.x = side * (0.14 * reach * (1 - grabPhase)) - side * grabPhase * 0.30;
        if (style === 'sideSwipe') {
          bones[leg.thigh].rotation.x += (legKey === leadLeg ? -side * 0.20 : side * 0.06) * reach;
        }
      }
      if (style === 'sideSwipe') {
        bones.root.rotation.y += Math.sin(t * Math.PI) * (state.heading > 0 ? -0.18 : 0.18);
        bones.chest.rotation.y += Math.sin(t * Math.PI) * (state.heading > 0 ? -0.10 : 0.10);
      } else if (style === 'highGrab') {
        bones.chest.rotation.z += reach * 0.10;
        bones.neck.rotation.z += reach * 0.08;
      }
      // Hind legs trail out behind, toes pointed.
      const trail = reach * (1 - grabPhase * (style === 'lowPounce' ? 0.25 : 0.4));
      for (const legKey of ['backL', 'backR']) {
        const leg = LEGS[legKey];
        const fold = [
          -0.62 * trail * (style === 'lowPounce' ? 0.75 : 1),
          0.30 * trail,
          0.18 * trail
        ];
        const blend = 0.85;
        bones[leg.thigh].rotation.z = bones[leg.thigh].rotation.z * (1 - blend) + fold[0] * blend;
        bones[leg.shin].rotation.z = bones[leg.shin].rotation.z * (1 - blend) + fold[1] * blend;
        bones[leg.foot].rotation.z = bones[leg.foot].rotation.z * (1 - blend) + fold[2] * blend;
      }
      // Tail streams as a rudder.
      for (let i = 1; i <= 6; i++) {
        bones['tail' + i].rotation.z += -state.lunge.pitch * 0.18 * (i / 6);
      }
      measurePawAnchor();
    }

    // Landing absorb: a fast squash through the forelegs that releases into
    // a recover. Triggered by behavior when a lunge misses.
    function applyLand(dt) {
      if (state.land >= 1) return;
      state.land = Math.min(1, state.land + dt / 0.38);
      const squash = Math.sin(state.land * Math.PI);
      bones.root.position.y -= squash * 0.085;
      bones.root.rotation.z -= squash * 0.16;
      bones.chest.rotation.z += squash * 0.10;
    }

    // On its back, boxing the air: quick alternating jabs with shoulder
    // english and a whipping tail — kitten energy.
    function applyPlayOnBack(dt) {
      if (state.poseName !== 'playOnBack') return;
      const cycle = state.time * 7.5;
      for (const [legKey, phase] of [['frontL', 0], ['frontR', Math.PI * 0.9]]) {
        const leg = LEGS[legKey];
        const jab = Math.max(0, Math.sin(cycle + phase));
        const fold = [
          1.15 + jab * 0.55,
          -1.60 + jab * 0.95,
          0.05 - jab * 0.45
        ];
        const blend = 0.8;
        bones[leg.thigh].rotation.z = bones[leg.thigh].rotation.z * (1 - blend) + fold[0] * blend;
        bones[leg.shin].rotation.z = bones[leg.shin].rotation.z * (1 - blend) + fold[1] * blend;
        bones[leg.foot].rotation.z = bones[leg.foot].rotation.z * (1 - blend) + fold[2] * blend;
      }
      // Hips wriggle, the body rocks on the spine ridge.
      bones.root.rotation.x += Math.sin(cycle * 0.5) * 0.07;
      bones.root.rotation.y += Math.sin(cycle * 0.33) * 0.05;
      const kick = Math.max(0, Math.sin(cycle * 0.5 + 2.1));
      bones.thighBL.rotation.z += kick * 0.22;
      bones.shinBL.rotation.z -= kick * 0.30;
      bones.tail4.rotation.y += Math.sin(cycle * 0.8) * 0.16;
      bones.tail6.rotation.y += Math.sin(cycle * 1.1 + 1) * 0.30;
    }

    // Being petted: purr vibration and an active rub against the hand —
    // the section of back under the cursor rises into it, the head pushes
    // up and cheek-rubs when the hand is near the face, the raised
    // tail-tip quivers.
    function applyPetting(dt) {
      const contact = state.petContact;
      contact.timer = Math.max(0, contact.timer - dt);
      if (contact.timer <= 0) {
        contact.amp = damp(contact.amp, 0, 8, dt);
      }
      const active = state.poseName === 'petted' || state.poseName === 'bellyPet';
      state.petPulse = damp(state.petPulse, active ? 1 : 0, 4, dt);
      if (state.petPulse < 0.02) return;
      const p = state.petPulse;

      // Purr: a fine 24Hz tremor through the chest, inaudible but visible.
      const purr = Math.sin(state.time * 24) * 0.0035 * p;
      bones.chest.scale.x += purr;
      bones.chest.scale.y += purr;

      // Where along the body is the hand? +1 head end, -1 tail end.
      const along = THREE.MathUtils.clamp(
        (contact.x - state.worldX) * state.heading / 0.45, -1, 1
      );
      const handOn = contact.amp * p;

      if (state.poseName === 'bellyPet') {
        const roll = Math.sin(state.time * 1.25) * 0.10 * p + contact.dir * 0.055 * handOn;
        const breathingRoll = Math.sin(state.time * 0.78) * 0.045 * p;
        bones.root.rotation.x += roll;
        bones.root.rotation.y += breathingRoll;
        bones.spine.rotation.z += Math.sin(state.time * 1.6) * 0.035 * p;
        bones.chest.rotation.z -= (0.025 + handOn * 0.030) * p;
        bones.neck.rotation.z -= (0.06 + handOn * 0.05) * p;
        bones.head.rotation.z -= 0.04 * p;
        bones.head.rotation.y += Math.sin(state.time * 1.1) * 0.12 * p
          + contact.dir * 0.10 * handOn;
        bones.head.rotation.x += Math.sin(state.time * 0.9) * 0.055 * p;

        for (const [legKey, phase] of [['frontL', 0], ['frontR', Math.PI]]) {
          const leg = LEGS[legKey];
          const knead = Math.max(0, Math.sin(state.time * 5.6 + phase)) * (0.35 + handOn * 0.65);
          const fold = [1.05 + knead * 0.32, -1.58 - knead * 0.45, 0.12 - knead * 0.18];
          const blend = 0.72;
          bones[leg.thigh].rotation.z = bones[leg.thigh].rotation.z * (1 - blend) + fold[0] * blend;
          bones[leg.shin].rotation.z = bones[leg.shin].rotation.z * (1 - blend) + fold[1] * blend;
          bones[leg.foot].rotation.z = bones[leg.foot].rotation.z * (1 - blend) + fold[2] * blend;
        }

        for (const [legKey, phase] of [['backL', Math.PI * 0.35], ['backR', Math.PI * 1.15]]) {
          const leg = LEGS[legKey];
          const stretch = Math.max(0, Math.sin(state.time * 2.2 + phase)) * (0.28 + handOn * 0.38);
          const fold = [1.18 + stretch * 0.25, -1.88 + stretch * 0.38, 0.18 - stretch * 0.20];
          const blend = 0.64;
          bones[leg.thigh].rotation.z = bones[leg.thigh].rotation.z * (1 - blend) + fold[0] * blend;
          bones[leg.shin].rotation.z = bones[leg.shin].rotation.z * (1 - blend) + fold[1] * blend;
          bones[leg.foot].rotation.z = bones[leg.foot].rotation.z * (1 - blend) + fold[2] * blend;
        }

        bones.tail4.rotation.y += Math.sin(state.time * 3.0) * 0.075 * p;
        bones.tail6.rotation.y += Math.sin(state.time * 8.5) * 0.12 * p;
        return;
      }

      // The stretch of spine under the hand lifts into it: hand toward the
      // rear arches the spine, toward the shoulders arches the chest.
      const arch = (0.030 + Math.sin(state.time * 1.4) * 0.010) * handOn + 0.012 * p;
      const rearWeight = THREE.MathUtils.clamp(0.5 - along * 0.5, 0, 1);
      bones.spine.rotation.z -= arch * (0.5 + rearWeight);
      bones.chest.rotation.z -= arch * (1.3 - rearWeight);
      bones.root.position.y += arch * 0.9;
      // Body sidles subtly toward the hand — rubbing, not just receiving.
      bones.root.position.x += THREE.MathUtils.clamp(
        contact.x - state.worldX, -0.06, 0.06
      ) * handOn * 0.5;

      // Hand near the face: head tips up under it and cheek-rubs in slow
      // figure strokes. Hand along the back: slow contented head bobs.
      const headWeight = THREE.MathUtils.smoothstep(along, 0.25, 0.9);
      const cheekRub = Math.sin(state.time * 1.7) * headWeight * handOn;
      bones.neck.rotation.z -= (0.06 + headWeight * 0.10) * handOn;
      bones.head.rotation.z -= 0.05 * handOn + cheekRub * 0.10;
      bones.head.rotation.x += cheekRub * 0.16;
      bones.head.rotation.y += contact.dir * 0.14 * handOn
        + Math.sin(state.time * 0.9) * 0.05 * p;
      const nudge = Math.max(0, Math.sin(state.time * 1.1)) * p;
      bones.neck.rotation.z -= nudge * 0.06;

      // Tail up with a happy tip-quiver.
      bones.tail6.rotation.y += Math.sin(state.time * 9) * 0.14 * p;
    }

    function applyFaceMicroMotion(dt) {
      state.earFlickTimer -= dt;
      if (state.earFlickTimer <= 0) {
        state.earFlickTimer = 2.5 + Math.random() * 6.5;
        state.earFlickPhase = 0;
      }
      if (state.earFlickPhase < 1) {
        state.earFlickPhase = Math.min(1, state.earFlickPhase + dt / 0.18);
      }
      const flick = state.earFlickPhase < 1
        ? Math.sin(state.earFlickPhase * Math.PI) * 0.26
        : 0;
      if (rig.innerEars) {
        for (const ear of rig.innerEars) {
          ear.mesh.rotation.x = ear.baseRotationX + flick * ear.side;
        }
      }
      if (rig.whiskers) {
        const twitch = Math.sin(state.time * 3.1) * 0.020 + flick * 0.08;
        // Whiskers fan forward and spread with arousal — an interested cat
        // pushes them toward what it's watching. A couple of close-inspection
        // poses keep a forward bias even when arousal is low.
        const poseAlert = state.poseName === 'dockInspect' || state.poseName === 'dockPaw'
          || state.poseName === 'wallInspect' || state.poseName === 'mouseCling' ? 0.045 : 0;
        const alert = Math.max(poseAlert, state.arousalSmooth * 0.07);
        // Hair physics: each whisker is a tiny damped spring driven by the
        // body's velocity. Walking makes them trail and bounce with the
        // gait; a direction change whips them around and they settle with
        // a wobble. Sensitivity falls off down the rows so the coat of
        // whiskers moves as individual hairs, not a fused fan.
        const vx = state.velocity.x;
        const vy = state.velocity.y;
        const dragY = THREE.MathUtils.clamp(-vx * state.heading * 0.085, -0.16, 0.16);
        const dragZ = THREE.MathUtils.clamp(-vy * 0.10, -0.14, 0.14);
        for (const whisker of rig.whiskers) {
          const sensitivity = whisker.sensitivity || 1;
          const springRate = 9 - whisker.index * 0.9;
          whisker.bendY = damp(
            whisker.bendY || 0,
            dragY * whisker.side * sensitivity,
            springRate, dt
          );
          whisker.bendZ = damp(
            whisker.bendZ || 0,
            (dragZ - Math.abs(vx) * 0.012) * sensitivity,
            springRate, dt
          );
          // Per-hair breeze shimmer, decorrelated by index so neighboring
          // whiskers never move in lockstep.
          const breezeY = Math.sin(state.time * (1.9 + whisker.index * 0.23) + whisker.index * 2.1)
            * 0.008 * sensitivity;
          const breezeZ = Math.sin(state.time * (2.3 + whisker.index * 0.31) + whisker.index * 1.3)
            * 0.011 * sensitivity;
          whisker.mesh.rotation.y = whisker.baseRotationY
            + whisker.side * (twitch + alert) * sensitivity
            + whisker.bendY + breezeY * whisker.side;
          whisker.mesh.rotation.z = whisker.baseRotationZ
            + whisker.bendZ + breezeZ;
        }
      }
    }

    function update(dt, externalWorldX, externalWorldY = 0) {
      state.time += dt;
      state.worldX = externalWorldX;
      state.worldY = externalWorldY;
      // Agility > 1 during play/attack: a hunting cat accelerates and
      // turns visibly quicker than an ambling one.
      state.speed = damp(state.speed, state.targetSpeed, 3.0 * state.agility, dt);

      updateChannels(dt);
      applyHeadLook(dt);

      const ch = state.ch;
      const walkAmp = THREE.MathUtils.clamp(state.speed / 0.5, 0, 1);

      // Advance gait phase so stride matches ground speed (no foot sliding).
      // A few percent of slow wander on the tempo keeps strides organic —
      // real gaits are never metronomic.
      state.gaitNoiseTimer -= dt;
      if (state.gaitNoiseTimer <= 0) {
        state.gaitNoiseTimer = 1.2 + Math.random() * 2.2;
        state.gaitNoiseTarget = (Math.random() - 0.5) * 0.08;
      }
      state.gaitNoise = damp(state.gaitNoise, state.gaitNoiseTarget, 1.5, dt);
      const gait = GAITS[state.gait] || GAITS.walk;
      if (state.speed > 0.02) {
        const cycleTime = THREE.MathUtils.clamp(
          gait.stride / (state.speed * gait.stanceFrac), 0.4, 1.8
        );
        state.gaitPhase = (state.gaitPhase + (dt / cycleTime) * (1 + state.gaitNoise)) % 1;
      }

      // Locomotion body dynamics.
      const bobAmp = gait.bobAmp;
      const bobY = -Math.cos(state.gaitPhase * Math.PI * 4) * bobAmp * walkAmp;
      const pitchWobble = Math.sin(state.gaitPhase * Math.PI * 4 + 0.6) * 0.018 * walkAmp;
      const roll = Math.sin(state.gaitPhase * Math.PI * 2) * 0.030 * walkAmp;
      const spineSway = Math.sin(state.gaitPhase * Math.PI * 2) * 0.05 * walkAmp;

      const root = bones.root;
      const yawTarget = state.heading > 0 ? -0.18 : -(Math.PI - 0.18);
      state.yaw = damp(state.yaw, yawTarget, 3.4 * state.agility, dt);
      root.rotation.order = 'YZX';
      root.rotation.y = state.yaw;
      root.rotation.z = ch.rootPitch + pitchWobble;
      root.rotation.x = roll + ch.rootRoll;
      root.position.set(state.worldX, ROOT_REST_Y + ch.rootHeight + bobY + state.worldY, 0);

      // Spine flexion-extension with the stride (the back visibly works in
      // a moving cat) and pelvic roll as each hind leg loads. Standing
      // still, slow weight-shifts keep the body from ever freezing solid.
      const spineFlex = Math.sin(state.gaitPhase * Math.PI * 2 + 1.1) * 0.030 * walkAmp;
      const pelvicRoll = Math.sin(state.gaitPhase * Math.PI * 2) * 0.045 * walkAmp;
      const idleAmp = 1 - walkAmp;
      // A resting cat is never truly still — two slow decorrelated sways plus
      // a gentle fore/aft weight rock keep it breathing-alive, not frozen.
      const idleShift = (Math.sin(state.time * 0.31) * 0.016
        + Math.sin(state.time * 0.17 + 1.3) * 0.008) * idleAmp;
      root.position.y += Math.sin(state.time * 0.41) * 0.010 * idleAmp;
      root.rotation.x += idleShift;
      root.rotation.z += Math.sin(state.time * 0.23 + 0.6) * 0.010 * idleAmp;

      // Follow-through: the neck lags vertical accelerations of the body,
      // then settles — heads bob because they're mass on a spring.
      state.neckLag = damp(
        state.neckLag,
        THREE.MathUtils.clamp(-state.velocity.y * 0.045, -0.12, 0.12),
        8, dt
      );

      // The head leads turns: eyes and ears commit to the new heading a
      // beat before the body comes around.
      const turnLead = THREE.MathUtils.clamp((yawTarget - state.yaw) * 0.5, -0.45, 0.45);

      bones.hips.rotation.y = -spineSway;
      bones.hips.rotation.x = pelvicRoll;
      bones.spine.rotation.z = ch.spineRz + spineFlex;
      bones.chest.rotation.z = ch.chestRz - spineFlex * 0.7;
      bones.chest.rotation.y = spineSway;
      bones.neck.rotation.z = ch.neckRz - pitchWobble - bobY * 1.6 + state.neckLag;
      bones.neck.rotation.y = ch.neckRy + turnLead * 0.4;
      bones.head.rotation.set(
        ch.headRx,
        ch.headRy + turnLead,
        ch.headRz + state.lookPitch + state.neckLag * 0.5
      );

      // Breathing: chest swells, belly follows softly. Kept subtle — at
      // wallpaper scale a visible heave reads as panting.
      const breath = 1 + Math.sin(state.time * (ch.breath > 1.8 ? 1.1 : 1.9)) * 0.010 * ch.breath;
      bones.chest.scale.set(breath, breath, breath);
      bones.spine.scale.set(1 + (breath - 1) * 0.5, 1 + (breath - 1) * 0.5, 1);

      applyLeg('backL', ch.backIkL, dt);
      applyLeg('backR', ch.backIkR, dt);
      applyLeg('frontL', ch.frontIkL, dt);
      applyLeg('frontR', ch.frontIkR, dt);
      applyGrooming(dt);
      applyScratch();
      applyWallScratch();
      applyWallRub();
      applyDockInspect();
      applyBugEat(dt);
      applyWallClimb(dt);
      applyWallHang();
      applyMouseCling(dt);
      applyLunge(dt);
      applyLand(dt);
      applyPlayOnBack(dt);
      applyPetting(dt);
      applySwipe(dt);
      applyDockPaw(dt);
      applyWiggle(dt);
      applyPounce(dt);
      applyTail(dt);
      applyTailLash(dt);
      applyFaceMicroMotion(dt);
      applyBlink(dt);

      // Body velocity feeds fur inertia (bounce). Includes bob and turning.
      const rootPos = root.position;
      if (dt > 0 && state.hasPrevRootPos) {
        state.rawVelocity.set(
          (rootPos.x - state.prevRootPos.x) / dt,
          (rootPos.y - state.prevRootPos.y) / dt,
          (rootPos.z - state.prevRootPos.z) / dt
        );
        state.rawVelocity.x = THREE.MathUtils.clamp(state.rawVelocity.x, -5, 5);
        state.rawVelocity.y = THREE.MathUtils.clamp(state.rawVelocity.y, -5, 5);
        state.rawVelocity.z = THREE.MathUtils.clamp(state.rawVelocity.z, -5, 5);
        state.velocity.lerp(state.rawVelocity, Math.min(1, dt * 10));
      } else {
        state.velocity.set(0, 0, 0);
        state.hasPrevRootPos = true;
      }
      state.prevRootPos.copy(rootPos);
      rig.furDriver.update(dt, state.time, state.velocity, state.petContact);

      // Muscle load: the haunches visibly bulge when the hindquarters are
      // working — coiled in a stalk, driving a pounce or lunge, raking a
      // wall, or powering a fast trot. Thickness only (x/z), so legs never
      // change length.
      let effortTarget = 0;
      if (state.poseName === 'stalk') effortTarget = 0.7;
      if (state.poseName === 'bugEat') effortTarget = 0.25;
      if (state.poseName === 'wallScratch') effortTarget = 0.55;
      if (state.pounce < 1) effortTarget = Math.max(effortTarget, Math.sin(state.pounce * Math.PI));
      if (state.lunge.t < 1) effortTarget = Math.max(effortTarget, 1 - state.lunge.t * 0.6);
      effortTarget = Math.max(effortTarget, THREE.MathUtils.clamp(state.speed / 1.6, 0, 1) * 0.5);
      state.effort = damp(state.effort, effortTarget, 6, dt);
      const bulge = 1 + state.effort * 0.09;
      bones.thighBL.scale.set(bulge, 1, bulge);
      bones.thighBR.scale.set(bulge, 1, bulge);

      // Arousal drives the pupils: slits when calm, pools when hunting or
      // playing. The texture only redraws when dilation meaningfully moves.
      state.arousalSmooth = damp(state.arousalSmooth, state.arousal, 2.5, dt);
      if (rig.setPupilDilation) {
        rig.setPupilDilation(state.arousalSmooth);
      }

      // Claws unsheathe for work that needs them: climbing, hanging on,
      // raking the wall, gripping the cursor, and mid-lunge.
      const clawsWanted = state.poseName === 'wallClimb'
        || state.poseName === 'wallHang'
        || state.poseName === 'wallScratch'
        || state.poseName === 'bugEat'
        || state.poseName === 'mouseCling'
        || state.swipe.t < 1
        || state.lunge.t < 1 ? 1 : 0;
      state.clawOut = damp(state.clawOut, clawsWanted, 6, dt);
      if (rig.setClawsOut) {
        rig.setClawsOut(state.clawOut);
      }

      // Contact shadow follows, widening and fading as the body rises.
      const bodyDrop = -ch.rootHeight;
      const air = Math.max(0, state.worldY);
      rig.shadow.position.x = state.worldX;
      const spread = 1 + bodyDrop * 0.9 + air * 0.55;
      rig.shadow.scale.set(spread, 1 + bodyDrop * 0.4 + air * 0.24, 1);
      // Fade fully by ~0.7 world units of air: the shadow stays at ground
      // level, so once the render box follows the cat up the screen the
      // shadow must already be invisible.
      rig.shadow.material.opacity = THREE.MathUtils.clamp(0.85 + bodyDrop * 0.5 - air * 1.3, 0, 0.95);
      rig.shadow.visible = rig.shadow.material.opacity > 0.01;
    }

    return {
      state,
      setPose,
      update,
      setHeading(h) { state.heading = h; },
      setLocomotion(speed, gait) {
        state.targetSpeed = speed;
        if (gait) state.gait = gait;
      },
      isTurning() {
        const yawTarget = state.heading > 0 ? -0.18 : -(Math.PI - 0.18);
        return Math.abs(state.yaw - yawTarget) > 0.3;
      },
      setLookOverride(target) { state.lookOverride = target; },
      triggerSwipe(alternatePaw, style) {
        const lead = state.heading > 0 ? 'frontL' : 'frontR';
        const other = lead === 'frontL' ? 'frontR' : 'frontL';
        state.swipe = {
          t: 0,
          leg: alternatePaw ? other : lead,
          style: style || (alternatePaw ? 'crossBat' : 'bat')
        };
      },
      isSwiping() { return state.swipe.t < 1; },
      startMouseCling() {
        state.swipe.t = 1;
        state.pounce = 1;
        state.clingSwing = 0;
        state.clingSwingVel = 0;
        state.clingStress = 0;
        state.clingVelX = 0;
        state.clingVelY = 0;
      },
      setClingMotion(vx, vy) {
        state.clingVelX = vx;
        state.clingVelY = vy;
      },
      // Where the front paw tips actually are, so behavior can pin them on
      // the cursor: x relative to worldX, y with worldY factored out.
      getPawAnchor() {
        return { x: state.pawAnchorX, yAbs: state.pawAnchorYAbs };
      },
      getHeadOffsetX() { return state.headOffsetX; },
      triggerLunge(duration, style) {
        state.lunge = {
          t: 0,
          duration: Math.max(0.25, duration || 0.45),
          pitch: 0,
          style: style || 'flyingGrab'
        };
        state.swipe.t = 1;
        state.pounce = 1;
      },
      isLunging() { return state.lunge.t < 1; },
      cancelLunge() { state.lunge.t = 1; },
      triggerLand() { state.land = 0; },
      setAgility(value) {
        state.agility = THREE.MathUtils.clamp(value || 1, 0.6, 2.2);
      },
      // 0 = calm slits, 1 = full hunting pools. Behavior owns the signal.
      setArousal(value) {
        state.arousal = THREE.MathUtils.clamp(value || 0, 0, 1);
      },
      // A stroking hand at (x, y) world units moving in direction dir
      // [-1, 1] with firmness amp [0, 1]. Drives the localized fur rustle
      // immediately — recognition (the petted pose) is behavior's call.
      setPetContact(x, y, dir, amp) {
        const contact = state.petContact;
        contact.x = x;
        contact.y = y;
        contact.dir = THREE.MathUtils.clamp(dir, -1, 1);
        contact.amp = THREE.MathUtils.clamp(amp, 0, 1);
        contact.timer = 0.25;
      },
      isClinging() { return state.poseName === 'mouseCling'; },
      triggerDockPaw() {
        state.dockPaw = { t: 0, leg: state.heading > 0 ? 'frontL' : 'frontR' };
      },
      isDockPawing() { return state.dockPaw.t < 1; },
      triggerBugEat() { state.bugEat = { t: 0 }; },
      isBugEating() { return state.poseName === 'bugEat' && state.bugEat.t < 1; },
      triggerPounce(style) {
        state.pounceStyle = style || 'groundPounce';
        state.pounce = 0;
      },
      // Pre-pounce butt-wiggle. Behavior fires it during the coil beat.
      triggerWiggle(duration) {
        state.wiggle = { t: 0, duration: Math.max(0.25, duration || 0.5) };
      },
      isWiggling() { return state.wiggle.t < 1; },
      // Agitated tail lash. intensity 0..1 scales the whip amplitude.
      triggerTailLash(duration, intensity) {
        state.tailLash = {
          t: 0,
          duration: Math.max(0.4, duration || 0.7),
          intensity: THREE.MathUtils.clamp(intensity === undefined ? 1 : intensity, 0, 1)
        };
      },
      isTailLashing() { return state.tailLash.t < 1; }
    };
  }

  return { create, POSES };
})();
