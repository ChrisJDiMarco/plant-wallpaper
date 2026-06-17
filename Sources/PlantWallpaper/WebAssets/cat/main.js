/* Scene bootstrap and the Swift bridge. The renderer is transparent — the
   desktop (and the painted garden) shows through everywhere the cat isn't.
   Camera is positioned so world y=0 lands at a configurable fraction from
   the bottom of the screen, usually the Dock top or the screen bottom. */

(() => {
  const config = {
    groundFraction: 0,
    catSizePx: 175,       // shoulder height in screen pixels
    variant: '',          // empty = seeded random pick
    seed: Math.floor(Math.random() * 1e9),
    screenIndex: 0,
    timeScale: 1,
    // Build-time appearance (require a reload to change):
    chubbiness: 1.0,
    stripeAmount: 1.0,
    // Runtime-adjustable:
    furLength: 1.5,
    activity: 0.5,
    curiosity: 0.5,
    playfulness: 0.6,
    mouseReactions: true,
    respectGnomeTerritories: false,
    purringEnabled: true,
    desktopEnvironment: {
      dockVisible: false,
      dockSide: 'none',
      dockThicknessPx: 0,
      wallInsetsPx: { left: 0, right: 0, bottom: 0 },
      effectiveGroundFraction: 0
    },
    gnomeTerritories: [],
    plantMissionTargets: [],
    // Real screen dimensions in CSS px. The Swift host window is only the
    // bottom band of the screen, so window.inner* can't be used for the
    // camera frustum or mouse mapping. 0 = fall back to window dims
    // (standalone/preview, where the window is the whole "screen").
    screenWidthPx: 0,
    screenHeightPx: 0
  };

  const SHOULDER_WORLD = 0.62;
  const FOV_DEGREES = 22;
  const MOTION_FPS = 60;   // locomotion, swats, pounces — translation judder is what the eye catches
  const IDLE_FPS = 30;     // sitting, grooming, looking around
  const SLEEP_FPS = 12;
  const MAX_ACTIVE_DT = 1 / 30;
  const MAX_SLEEP_DT = 0.1;
  const SURFACE_FOLLOW_RATE = 18;
  const SURFACE_SNAP_DISTANCE_PX = 120;

  let renderer = null;
  let scene = null;
  let camera = null;
  let behavior = null;
  let animator = null;
  let rig = null;
  let purr = null;
  let riderKit = null;
  let paused = false;
  let rafPending = false;
  let accumulator = 0;
  let clockTime = performance.now();
  let tickSeconds = 1 / 60;   // smoothed rAF tick estimate (display refresh)
  let ticksSinceRender = 0;
  let canvasWidth = 0;
  let canvasHeight = 0;
  let viewOffsetX = -1;       // -1 = needs repositioning
  let viewOffsetY = -1;
  let surfaceDisplayX = null;
  let surfaceDisplayY = null;
  let missionProjectionScale = 1;
  let missionProjectionLiftY = 0;

  function damp(current, target, rate, dt) {
    return current + (target - current) * Math.min(1, rate * dt);
  }

  function screenWidth() {
    return config.screenWidthPx || window.innerWidth;
  }

  function screenHeight() {
    return config.screenHeightPx || window.innerHeight;
  }

  function mulberry32(seed) {
    let a = seed >>> 0;
    return function () {
      a |= 0; a = (a + 0x6D2B79F5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  // The camera frustum always spans the full screen, regardless of how
  // small the window and canvas are — setViewOffset rasterizes just the
  // piece we need, pixel-identical to rendering the whole screen.
  function viewMetrics() {
    const worldPerPx = SHOULDER_WORLD / config.catSizePx;
    const visibleH = screenHeight() * worldPerPx;
    const visibleW = visibleH * (screenWidth() / screenHeight());
    return { visibleH, visibleW, worldPerPx };
  }

  function normalizedEnvironment() {
    const env = config.desktopEnvironment || {};
    const insets = env.wallInsetsPx || {};
    const effectiveGroundFraction = Number(env.effectiveGroundFraction);
    return {
      dockVisible: !!env.dockVisible,
      dockSide: env.dockSide || 'none',
      dockThicknessPx: Number(env.dockThicknessPx) || 0,
      wallInsetsPx: {
        left: Number(insets.left) || 0,
        right: Number(insets.right) || 0,
        bottom: Number(insets.bottom) || 0
      },
      effectiveGroundFraction: Number.isFinite(effectiveGroundFraction)
        ? effectiveGroundFraction
        : config.groundFraction
    };
  }

  function worldPointFromWindowPx(px, py) {
    const worldPerPx = SHOULDER_WORLD / config.catSizePx;
    return {
      x: (px - screenWidth() / 2) * worldPerPx,
      y: ((window.innerHeight - py) - config.groundFraction * screenHeight()) * worldPerPx
    };
  }

  function normalizedPointToWorld(point) {
    return worldPointFromWindowPx(
      (Number(point.x) || 0) * screenWidth(),
      (Number(point.y) || 0) * screenHeight()
    );
  }

  function normalizedGnomeTerritories(items) {
    return (Array.isArray(items) ? items : []).map((item) => {
      const points = (Array.isArray(item.points) ? item.points : [])
        .map(normalizedPointToWorld)
        .filter((point) => Number.isFinite(point.x) && Number.isFinite(point.y));
      if (points.length < 3) return null;
      const bounds = points.reduce((acc, point) => ({
        minX: Math.min(acc.minX, point.x),
        maxX: Math.max(acc.maxX, point.x),
        minY: Math.min(acc.minY, point.y),
        maxY: Math.max(acc.maxY, point.y)
      }), {
        minX: points[0].x,
        maxX: points[0].x,
        minY: points[0].y,
        maxY: points[0].y
      });
      const centroid = points.reduce((acc, point) => ({
        x: acc.x + point.x,
        y: acc.y + point.y
      }), { x: 0, y: 0 });
      return {
        id: String(item.id || ''),
        points,
        ...bounds,
        centerX: centroid.x / points.length,
        centerY: centroid.y / points.length
      };
    }).filter(Boolean);
  }

  function normalizedPlantMissionTargets(items) {
    return (Array.isArray(items) ? items : []).map((item) => {
      const screenX = Number(item.x);
      const screenY = Number(item.y);
      const point = normalizedPointToWorld({ x: screenX, y: screenY });
      if (!Number.isFinite(point.x) || !Number.isFinite(point.y)) return null;
      return {
        id: String(item.id || item.species || ''),
        species: String(item.species || ''),
        kind: String(item.kind || ''),
        x: point.x,
        y: point.y,
        screenX: Number.isFinite(screenX) ? screenX : 0.5,
        screenY: Number.isFinite(screenY) ? screenY : 0.5,
        scale: Number(item.scale) || 1,
        resourceValue: Math.max(0, Math.min(1, Number(item.resourceValue) || 0)),
        canopyHeight: Math.max(0, Math.min(0.5, Number(item.canopyHeight) || 0)),
        canClimb: !!item.canClimb
      };
    }).filter((item) => item && item.id);
  }

  function postCatEvent(payload) {
    try {
      const handler = window.webkit
        && window.webkit.messageHandlers
        && window.webkit.messageHandlers.catEvent;
      if (handler) handler.postMessage(payload);
    } catch (_) {
      // Standalone previews do not have a native bridge.
    }
  }

  // Checkpoint the cat's inner state to the Swift host so it persists across
  // launches (the host saves it and replays it via catBridge.restoreCatMemory).
  function postCatMemory() {
    if (!behavior || !behavior.snapshotMemory) return;
    postCatEvent({ type: 'catMemory', memory: behavior.snapshotMemory(), screenIndex: config.screenIndex });
  }

  function layoutCamera() {
    const { visibleH, visibleW, worldPerPx } = viewMetrics();
    const distance = (visibleH / 2) / Math.tan(THREE.MathUtils.degToRad(FOV_DEGREES / 2));
    const eyeY = visibleH * (0.5 - config.groundFraction);
    camera.fov = FOV_DEGREES;
    camera.aspect = screenWidth() / screenHeight();
    camera.position.set(0, eyeY, distance);
    camera.lookAt(0, eyeY, 0);
    camera.updateProjectionMatrix();
    if (behavior) {
      const env = normalizedEnvironment();
      const leftInsetWorld = env.wallInsetsPx.left * worldPerPx;
      const rightInsetWorld = env.wallInsetsPx.right * worldPerPx;
      const minX = -visibleW / 2 + 0.75 + leftInsetWorld;
      const maxX = visibleW / 2 - 0.75 - rightInsetWorld;
      behavior.setBounds(minX < maxX ? minX : -visibleW / 2 + 0.75, minX < maxX ? maxX : visibleW / 2 - 0.75);
      behavior.setEnvironment({
        ...env,
        worldPerPx,
        screenWidthWorld: visibleW,
        screenHeightWorld: visibleH
      });
    }
  }

  // The render surface is a cat-sized box, not the screen. Rasterizing and
  // compositing a full-screen Retina canvas every frame is what caused
  // dropped frames on the desktop: ~20x the pixels of what the cat needs,
  // pushed through the compositor 30-60 times a second. The canvas follows
  // the cat in both axes via a compositor-cheap transform — horizontally as
  // it roams, vertically when the cursor carries it up the screen.
  function layoutSurface() {
    canvasWidth = Math.min(Math.round(config.catSizePx * 4), window.innerWidth);
    canvasHeight = Math.min(Math.round(config.catSizePx * 3), window.innerHeight);
    renderer.setSize(canvasWidth, canvasHeight);
    viewOffsetX = -1;
    viewOffsetY = -1;
    surfaceDisplayX = null;
    surfaceDisplayY = null;
    layoutCamera();
  }

  function updateViewOffset(dt) {
    const pxPerWorld = config.catSizePx / SHOULDER_WORLD;
    const groundPx = config.groundFraction * screenHeight();
    const catScreenX = screenWidth() / 2 + behavior.state.worldX * pxPerWorld;
    const maxOffsetX = Math.max(0, screenWidth() - canvasWidth);
    const targetX = Math.min(maxOffsetX, Math.max(0, catScreenX - canvasWidth / 2));
    // Center the box on the body; clamping bottom-anchors it on the ground.
    const catCenterFromBottom = groundPx + (behavior.state.worldY + missionProjectionLiftY + 0.5) * pxPerWorld;
    const maxOffsetY = Math.max(0, screenHeight() - canvasHeight);
    const targetY = Math.min(maxOffsetY, Math.max(0,
      screenHeight() - catCenterFromBottom - canvasHeight / 2));

    if (surfaceDisplayX === null || surfaceDisplayY === null) {
      surfaceDisplayX = targetX;
      surfaceDisplayY = targetY;
    } else {
      const dx = Math.abs(targetX - surfaceDisplayX);
      const dy = Math.abs(targetY - surfaceDisplayY);
      if (dx > SURFACE_SNAP_DISTANCE_PX || dy > SURFACE_SNAP_DISTANCE_PX) {
        surfaceDisplayX = targetX;
        surfaceDisplayY = targetY;
      } else {
        surfaceDisplayX = damp(surfaceDisplayX, targetX, SURFACE_FOLLOW_RATE, dt);
        surfaceDisplayY = damp(surfaceDisplayY, targetY, SURFACE_FOLLOW_RATE, dt);
      }
    }

    const x = Math.round(surfaceDisplayX);
    const y = Math.round(surfaceDisplayY);
    if (x === viewOffsetX && y === viewOffsetY) return;
    viewOffsetX = x;
    viewOffsetY = y;
    camera.setViewOffset(
      screenWidth(), screenHeight(),
      x, y,
      canvasWidth, canvasHeight
    );
    renderer.domElement.style.transform = 'translate3d(' + x + 'px, ' + y + 'px, 0)';
  }

  function onResize() {
    layoutSurface();
  }

  function pickVariant(random) {
    if (CatModel.PALETTES[config.variant]) return config.variant;
    const names = Object.keys(CatModel.PALETTES);
    return names[Math.floor(random() * names.length)];
  }

  function createGnomeRiderKit() {
    const group = new THREE.Group();
    group.name = 'gnomeRiderKit';
    group.visible = false;
    group.position.set(-0.05, 0.34, 0);

    const leather = new THREE.MeshBasicMaterial({ color: 0x3c2115 });
    const darkLeather = new THREE.MeshBasicMaterial({ color: 0x22130c });
    const brass = new THREE.MeshBasicMaterial({ color: 0xcaa45a });
    const cloth = new THREE.MeshBasicMaterial({ color: 0x315c45 });
    const clothTrim = new THREE.MeshBasicMaterial({ color: 0xd9b35f });
    const linen = new THREE.MeshBasicMaterial({ color: 0xd5c5a4 });
    const rope = new THREE.LineBasicMaterial({ color: 0x5b3b22, transparent: true, opacity: 0.88 });

    function box(width, height, depth, material, x, y, z) {
      const mesh = new THREE.Mesh(new THREE.BoxGeometry(width, height, depth), material);
      mesh.position.set(x || 0, y || 0, z || 0);
      return mesh;
    }

    const saddlePad = box(0.52, 0.036, 0.36, cloth, -0.025, 0.010, 0);
    const padFrontTrim = box(0.030, 0.041, 0.37, clothTrim, 0.230, 0.013, 0);
    const padRearTrim = box(0.030, 0.041, 0.37, clothTrim, -0.280, 0.013, 0);
    const padLeftTrim = box(0.50, 0.043, 0.018, clothTrim, -0.025, 0.016, -0.182);
    const padRightTrim = box(0.50, 0.043, 0.018, clothTrim, -0.025, 0.016, 0.182);
    group.add(saddlePad, padFrontTrim, padRearTrim, padLeftTrim, padRightTrim);

    for (let i = 0; i < 7; i += 1) {
      const x = -0.245 + i * 0.075;
      const leftFringe = box(0.010, 0.050, 0.006, linen, x, -0.020, -0.202);
      const rightFringe = box(0.010, 0.050, 0.006, linen, x, -0.020, 0.202);
      group.add(leftFringe, rightFringe);
    }

    const seat = box(0.34, 0.060, 0.22, leather, -0.035, 0.070, 0);
    const frontPommel = new THREE.Mesh(new THREE.SphereGeometry(0.038, 14, 10), brass);
    frontPommel.position.set(0.160, 0.112, 0);
    const cantle = new THREE.Mesh(new THREE.CylinderGeometry(0.020, 0.024, 0.27, 12), darkLeather);
    cantle.rotation.x = Math.PI / 2;
    cantle.position.set(-0.225, 0.105, 0);
    const leftFlap = box(0.135, 0.105, 0.018, darkLeather, -0.045, 0.025, -0.145);
    const rightFlap = box(0.135, 0.105, 0.018, darkLeather, -0.045, 0.025, 0.145);
    group.add(seat, frontPommel, cantle, leftFlap, rightFlap);

    const bellyStrap = new THREE.Mesh(new THREE.TorusGeometry(0.255, 0.008, 8, 36, Math.PI * 1.62), leather);
    bellyStrap.rotation.z = Math.PI / 2;
    bellyStrap.rotation.y = Math.PI / 2;
    bellyStrap.position.set(-0.040, -0.050, 0);
    const chestHarness = new THREE.Mesh(new THREE.TorusGeometry(0.175, 0.007, 8, 30, Math.PI * 1.22), leather);
    chestHarness.rotation.y = Math.PI / 2;
    chestHarness.position.set(0.260, 0.020, 0);
    const harnessBadge = new THREE.Mesh(new THREE.SphereGeometry(0.018, 10, 8), brass);
    harnessBadge.position.set(0.265, 0.035, 0);
    group.add(bellyStrap, chestHarness, harnessBadge);

    function makeStirrup(zOffset) {
      const stirrup = new THREE.Group();
      const strap = box(0.010, 0.160, 0.006, darkLeather, 0, -0.020, zOffset);
      const ring = new THREE.Mesh(new THREE.TorusGeometry(0.032, 0.0045, 8, 18), brass);
      ring.rotation.x = Math.PI / 2;
      ring.position.set(0, -0.105, zOffset);
      stirrup.add(strap, ring);
      stirrup.position.x = 0.010;
      return stirrup;
    }
    group.add(makeStirrup(-0.175), makeStirrup(0.175));

    function makeLimb(length, radius, material, position, rotation) {
      const limb = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, length, 8), material);
      limb.position.set(position.x, position.y, position.z);
      limb.rotation.set(rotation.x || 0, rotation.y || 0, rotation.z || 0);
      return limb;
    }

    function makeTinyGnome(zOffset, hatColor, tunicColor) {
      const rider = new THREE.Group();
      const bootMat = new THREE.MeshBasicMaterial({ color: 0x17120f });
      const tunicMat = new THREE.MeshBasicMaterial({ color: tunicColor });
      const skinMat = new THREE.MeshBasicMaterial({ color: 0xd6a77e });
      const beardMat = new THREE.MeshBasicMaterial({ color: 0xeee5d2 });
      const hatMat = new THREE.MeshBasicMaterial({ color: hatColor });

      const body = new THREE.Mesh(new THREE.CylinderGeometry(0.036, 0.044, 0.090, 14), tunicMat);
      body.scale.y = 1.18;
      body.position.y = 0.08;
      rider.add(body);

      const belt = new THREE.Mesh(new THREE.TorusGeometry(0.039, 0.004, 6, 18), darkLeather);
      belt.rotation.x = Math.PI / 2;
      belt.position.y = 0.055;
      rider.add(belt);

      const buckle = new THREE.Mesh(new THREE.BoxGeometry(0.014, 0.010, 0.005), brass);
      buckle.position.set(0.036, 0.055, 0.006);
      rider.add(buckle);

      const head = new THREE.Mesh(new THREE.SphereGeometry(0.036, 16, 12), skinMat);
      head.position.y = 0.155;
      rider.add(head);

      const nose = new THREE.Mesh(new THREE.SphereGeometry(0.008, 8, 6), skinMat);
      nose.position.set(0.033, 0.158, 0.004);
      rider.add(nose);

      const beard = new THREE.Mesh(new THREE.ConeGeometry(0.034, 0.062, 14), beardMat);
      beard.rotation.x = Math.PI;
      beard.position.set(0.010, 0.125, 0.026);
      rider.add(beard);

      const hatBrim = new THREE.Mesh(new THREE.CylinderGeometry(0.043, 0.045, 0.012, 16), hatMat);
      hatBrim.position.y = 0.194;
      rider.add(hatBrim);

      const hat = new THREE.Mesh(new THREE.ConeGeometry(0.042, 0.112, 16), hatMat);
      hat.position.y = 0.230;
      rider.add(hat);

      const leftArm = makeLimb(0.075, 0.007, tunicMat, { x: 0.040, y: 0.103, z: -0.026 }, { z: -0.85, x: 0.12 });
      const rightArm = makeLimb(0.075, 0.007, tunicMat, { x: 0.040, y: 0.103, z: 0.026 }, { z: -0.85, x: -0.12 });
      const leftHand = new THREE.Mesh(new THREE.SphereGeometry(0.009, 8, 6), skinMat);
      const rightHand = leftHand.clone();
      leftHand.position.set(0.075, 0.081, -0.038);
      rightHand.position.set(0.075, 0.081, 0.038);
      rider.add(leftArm, rightArm, leftHand, rightHand);

      const leftLeg = makeLimb(0.075, 0.008, tunicMat, { x: -0.014, y: 0.025, z: -0.036 }, { x: 0.58, z: 0.10 });
      const rightLeg = makeLimb(0.075, 0.008, tunicMat, { x: -0.014, y: 0.025, z: 0.036 }, { x: -0.58, z: 0.10 });
      const bootL = new THREE.Mesh(new THREE.SphereGeometry(0.016, 8, 6), bootMat);
      const bootR = bootL.clone();
      bootL.position.set(-0.020, -0.012, -0.070);
      bootR.position.set(-0.020, -0.012, 0.070);
      rider.add(leftLeg, rightLeg, bootL, bootR);

      const pack = box(0.020, 0.045, 0.045, leather, -0.038, 0.083, 0);
      rider.add(pack);

      rider.position.set(-0.03, 0.095, zOffset);
      rider.rotation.y = -0.14;
      rider.scale.setScalar(0.82);
      rider.userData = { leftArm, rightArm, leftLeg, rightLeg, hat, beard };
      return rider;
    }

    const riderA = makeTinyGnome(-0.060, 0x8d2f24, 0x496a43);
    const riderB = makeTinyGnome(0.065, 0x315c92, 0x6d552b);
    group.add(riderA, riderB);

    const reinsGeometry = new THREE.BufferGeometry();
    const reinPositions = new Float32Array([
      0.13, 0.125, -0.050,  0.48, -0.030, -0.030,
      0.13, 0.125,  0.050,  0.48, -0.030,  0.030
    ]);
    reinsGeometry.setAttribute('position', new THREE.BufferAttribute(reinPositions, 3));
    const reins = new THREE.LineSegments(reinsGeometry, rope);
    reins.name = 'tinyGnomeReins';
    group.add(reins);

    const sampleBundle = new THREE.Group();
    sampleBundle.name = 'gnomeMissionSampleBundle';
    sampleBundle.visible = false;
    const bundleMat = new THREE.MeshBasicMaterial({ color: 0x6a4a2b });
    const leafMat = new THREE.MeshBasicMaterial({ color: 0x5f8f4f });
    const sampleGlowMat = new THREE.MeshBasicMaterial({
      color: 0xf0d27c,
      transparent: true,
      opacity: 0.68
    });
    const pouch = new THREE.Mesh(new THREE.SphereGeometry(0.036, 12, 8), bundleMat);
    pouch.scale.set(1.0, 0.78, 0.86);
    pouch.position.set(-0.205, 0.125, 0.105);
    const sampleLeafA = box(0.052, 0.011, 0.021, leafMat, -0.182, 0.158, 0.108);
    sampleLeafA.rotation.z = 0.55;
    const sampleLeafB = box(0.044, 0.010, 0.020, leafMat, -0.228, 0.156, 0.102);
    sampleLeafB.rotation.z = -0.45;
    const sampleGlow = new THREE.Mesh(new THREE.SphereGeometry(0.030, 12, 8), sampleGlowMat);
    sampleGlow.position.set(-0.205, 0.130, 0.108);
    sampleBundle.add(pouch, sampleLeafA, sampleLeafB, sampleGlow);
    group.add(sampleBundle);

    const physics = {
      bounce: 0,
      roll: 0,
      pitch: 0,
      reinsSag: 0
    };

    const setVisible = (value) => {
      group.visible = value;
      group.traverse((child) => {
        if (child.material && child.material.transparent) child.material.opacity = value ? 0.85 : 0;
      });
    };

    return {
      group,
      update(dt, riding) {
        setVisible(!!riding.active);
        if (!riding.active) return;
        const t = performance.now() * 0.001;
        const riderCount = Math.max(1, Math.min(2, Number(riding.riderCount) || 1));
        const heading = Number(riding.heading) || 1;
        const speed = Math.min(1.2, Math.abs(Number(riding.velocityX) || 0));
        const stride = Number(riding.stride) || t * 0.3;
        const missionPhase = String(riding.missionPhase || 'none');
        const depthTrend = String(riding.depthTrend || 'lateral');
        const gaitBounce = Math.sin(stride * 18) * (0.006 + speed * 0.006)
          + Math.sin(t * 4.2) * 0.003;
        const targetRoll = (riding.turning ? -heading * 0.070 : 0)
          + Math.sin(stride * 9) * (0.018 + speed * 0.012);
        const perspectivePitch = depthTrend === 'away'
          ? -0.034
          : depthTrend === 'toward'
            ? 0.026
            : 0;
        const targetPitch = -Math.min(0.065, speed * 0.035)
          + perspectivePitch
          + Math.sin(stride * 12 + 0.7) * 0.010;
        physics.bounce = damp(physics.bounce, gaitBounce, 14, dt);
        physics.roll = damp(physics.roll, targetRoll, 9, dt);
        physics.pitch = damp(physics.pitch, targetPitch, 8, dt);
        physics.reinsSag = damp(physics.reinsSag, 0.020 + speed * 0.010, 10, dt);

        riderB.visible = riderCount > 1;
        group.position.y = 0.34 + physics.bounce;
        group.rotation.z = physics.roll;
        group.rotation.x = physics.pitch;

        const riderLean = -physics.roll * 1.8 + Math.sin(stride * 10) * 0.030;
        riderA.rotation.z = riderLean + Math.sin(t * 5.2) * 0.018;
        riderB.rotation.z = riderLean * 0.8 + Math.sin(t * 4.7 + 0.8) * 0.018;
        riderA.userData.hat.rotation.z = -riderA.rotation.z * 0.25;
        riderB.userData.hat.rotation.z = -riderB.rotation.z * 0.25;
        const collectingWave = missionPhase === 'collecting' ? Math.sin(t * 13) * 0.24 : 0;
        riderA.userData.leftArm.rotation.z = -0.78 + Math.sin(stride * 16) * 0.045 + collectingWave;
        riderA.userData.rightArm.rotation.z = -0.84 - Math.sin(stride * 16) * 0.045 - collectingWave * 0.55;
        riderB.userData.leftArm.rotation.z = -0.78 + Math.sin(stride * 15 + 0.6) * 0.040 + collectingWave * 0.72;
        riderB.userData.rightArm.rotation.z = -0.84 - Math.sin(stride * 15 + 0.6) * 0.040 - collectingWave * 0.44;

        const collectProgress = Math.max(0, Math.min(1, Number(riding.collectProgress) || 0));
        const carryingSample = (missionPhase === 'collecting'
          || missionPhase === 'rideHome'
          || missionPhase === 'dismounting') && collectProgress > 0.03;
        sampleBundle.visible = carryingSample;
        if (carryingSample) {
          sampleBundle.scale.setScalar(0.72 + collectProgress * 0.48 + Math.sin(t * 6.4) * 0.018);
          sampleBundle.rotation.z = Math.sin(t * 4.6) * 0.055;
          sampleGlow.material.opacity = 0.38 + collectProgress * 0.30 + Math.sin(t * 7.0) * 0.05;
        }

        const reinPositions = reins.geometry.attributes.position.array;
        reinPositions[0] = 0.085; reinPositions[1] = 0.180; reinPositions[2] = -0.050;
        reinPositions[3] = 0.485; reinPositions[4] = -0.034 - physics.reinsSag; reinPositions[5] = -0.032;
        reinPositions[6] = 0.085; reinPositions[7] = 0.180; reinPositions[8] = 0.050;
        reinPositions[9] = 0.485; reinPositions[10] = -0.034 - physics.reinsSag; reinPositions[11] = 0.032;
        reins.geometry.attributes.position.needsUpdate = true;

        if (riding.phase === 'mounting') {
          group.position.y += (1 - riding.progress) * 0.18;
          group.scale.setScalar(0.92 + riding.progress * 0.08);
        } else if (riding.phase === 'dismounting') {
          group.position.y += riding.progress * 0.15;
          group.scale.setScalar(1 - riding.progress * 0.08);
        } else {
          group.scale.setScalar(1);
        }
      }
    };
  }

  function buildScene() {
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(FOV_DEGREES, 1, 0.1, 60);
    layoutCamera();

    const random = mulberry32(config.seed);
    const lighting = {
      direction: new THREE.Vector3(-0.35, 0.8, 0.55).normalize(),
      color: new THREE.Vector3(1.04, 0.99, 0.90),
      ambient: new THREE.Vector3(0.40, 0.43, 0.38)
    };
    rig = CatModel.buildCat(pickVariant(random), lighting, random, {
      chubbiness: config.chubbiness,
      stripeAmount: config.stripeAmount
    });
    rig.setFurLength(config.furLength);
    scene.add(rig.group);
    scene.add(rig.shadow);
    riderKit = createGnomeRiderKit();
    rig.bones.root.add(riderKit.group);

    animator = CatAnim.create(rig);
    behavior = CatBehavior.create(animator, random, {
      activity: config.activity,
      curiosity: config.curiosity,
      playfulness: config.playfulness,
      mouseReactions: config.mouseReactions,
      respectGnomeTerritories: config.respectGnomeTerritories,
      onBugCaught(bugID, details) {
        postCatEvent({
          type: 'bugCaught',
          bugID,
          screenIndex: config.screenIndex,
          species: details && details.species ? details.species : ''
        });
      }
    });
    purr = window.CatPurr ? CatPurr.create() : null;
    if (purr) purr.setEnabled(config.purringEnabled);
    layoutCamera();
    if (behavior) behavior.setGnomeTerritories(normalizedGnomeTerritories(config.gnomeTerritories));
    if (behavior) behavior.setGnomePlantTargets(normalizedPlantMissionTargets(config.plantMissionTargets));
    // Inspection handle for tests and debugging; not used by the app itself.
    window.catDebug = { rig, animator, behavior, scene, camera, config, riderKit };
  }

  function scheduleFrame() {
    if (rafPending) return;
    rafPending = true;
    requestAnimationFrame(frame);
  }

  function targetFps() {
    if (behavior.isSleeping()) return SLEEP_FPS;
    const moving = animator.state.speed > 0.03
      || animator.state.poseName === 'wallClimb'
      || animator.isSwiping()
      || animator.isClinging()
      || animator.isLunging()
      || animator.isBugEating()
      || animator.isDockPawing()
      || (behavior.gnomeRiding && behavior.gnomeRiding().active)
      || animator.state.pounce < 1
      || animator.state.land < 1
      || animator.state.petPulse > 0.05
      || animator.isTurning();
    return moving ? MOTION_FPS : IDLE_FPS;
  }

  function frame(now) {
    rafPending = false;
    // While paused the loop stops entirely (no idle wakeups);
    // setPaused(false) restarts it.
    if (paused) return;
    scheduleFrame();
    const elapsed = (now - clockTime) / 1000;
    clockTime = now;
    if (!behavior) return;

    // Lock the fps cap to whole vsync ticks (every 2nd tick = 30fps at
    // 60Hz, every 4th at 120Hz). Thresholding accumulated wall time
    // instead alternates between 2- and 3-tick frames from float jitter,
    // which presents as visible judder.
    if (elapsed > 0.001 && elapsed < 0.05) {
      tickSeconds += (elapsed - tickSeconds) * 0.1;
    }
    accumulator += elapsed;
    ticksSinceRender += 1;
    const ticksPerRender = Math.max(1, Math.round(1 / (targetFps() * tickSeconds)));
    if (ticksSinceRender < ticksPerRender) return;

    // Clamp so a stalled timeline doesn't fast-forward the simulation.
    const maxFrameDt = behavior.isSleeping() && !behavior.state.mouse ? MAX_SLEEP_DT : MAX_ACTIVE_DT;
    const dt = Math.min(accumulator, maxFrameDt) * config.timeScale;
    accumulator = 0;
    ticksSinceRender = 0;

    behavior.update(dt);
    const riding = behavior.gnomeRiding ? behavior.gnomeRiding() : null;
    applyGnomeMissionProjection(dt, riding);
    if (riderKit && riding) {
      riderKit.update(dt, riding);
    }
    if (purr) {
      const petPulse = animator && animator.state ? animator.state.petPulse || 0 : 0;
      const isPurring = behavior.isPurring ? behavior.isPurring() : behavior.state.name === 'petted';
      purr.setPurring(config.purringEnabled && isPurring, 0.78 + petPulse * 0.55);
      purr.update(dt);
    }
    updateViewOffset(dt);
    renderer.render(scene, camera);
  }

  function setPaused(value) {
    const next = !!value;
    if (next === paused) return paused;
    paused = next;
    if (!paused) {
      // Restart cleanly: a pause can last hours, so drop the stale clock.
      clockTime = performance.now();
      accumulator = 0;
      ticksSinceRender = 0;
      scheduleFrame();
    }
    return paused;
  }

  function applyGnomeMissionProjection(dt, riding) {
    const active = riding && riding.active;
    const targetScale = active ? Number(riding.depthScale) || 1 : 1;
    const targetLift = active ? Number(riding.depthLiftY) || 0 : 0;
    missionProjectionScale = damp(missionProjectionScale, targetScale, 8, dt);
    missionProjectionLiftY = damp(missionProjectionLiftY, targetLift, 8, dt);
    if (rig && rig.group) {
      rig.group.scale.setScalar(missionProjectionScale);
      rig.group.position.y = missionProjectionLiftY;
    }
  }

  function start() {
    const params = new URLSearchParams(location.search);
    if (params.get('variant')) config.variant = params.get('variant');
    if (params.get('seed')) config.seed = Number(params.get('seed'));
    for (const key of ['chubbiness', 'stripeAmount', 'furLength', 'catSizePx',
                       'activity', 'curiosity', 'playfulness',
                       'groundFraction', 'screenWidthPx', 'screenHeightPx']) {
      const value = params.get(key);
      if (value !== null && !Number.isNaN(Number(value))) config[key] = Number(value);
    }
    if (params.get('screenIndex') !== null) {
      const value = Number(params.get('screenIndex'));
      if (!Number.isNaN(value)) config.screenIndex = value;
    }
    if (params.get('mouseReactions') !== null) {
      config.mouseReactions = params.get('mouseReactions') !== 'false';
    }
    if (params.get('purringEnabled') !== null) {
      config.purringEnabled = params.get('purringEnabled') !== 'false';
    }
    // No MSAA: at 2x pixel ratio a full-screen multisampled framebuffer
    // costs hundreds of MB of GPU memory per display, and the fur's
    // alpha-blended edges don't benefit from it anyway.
    renderer = new THREE.WebGLRenderer({
      alpha: true,
      antialias: false,
      powerPreference: 'low-power'
    });
    renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
    renderer.setClearColor(0x000000, 0);
    renderer.outputEncoding = THREE.sRGBEncoding;
    document.body.appendChild(renderer.domElement);
    buildScene();
    layoutSurface();
    window.addEventListener('resize', onResize);
    document.addEventListener('visibilitychange', () => {
      setPaused(document.hidden);
      if (document.hidden) postCatMemory();   // save the moment the cat sleeps/hides
    });
    // Persist the cat's drives/mood periodically so it resumes its life across launches.
    setInterval(postCatMemory, 25000);
    window.addEventListener('pagehide', postCatMemory);
    scheduleFrame();
  }

  // Bridge for the Swift host. Variant/seed only apply at build time —
  // set them via configure before first paint or via ?variant= URL param.
  // (A hot scene-rebuild path existed and corrupted skinning; removed.)
  window.catBridge = {
    restoreCatMemory(mem) {
      if (behavior && behavior.restoreMemory) behavior.restoreMemory(mem);
    },
    configure(options) {
      Object.assign(config, options || {});
      if (options && options.desktopEnvironment) {
        config.desktopEnvironment = options.desktopEnvironment;
        const effectiveGroundFraction = Number(options.desktopEnvironment.effectiveGroundFraction);
        config.groundFraction = Number.isFinite(effectiveGroundFraction)
          ? effectiveGroundFraction
          : config.groundFraction;
      }
      if (renderer) layoutSurface();
      if (rig) rig.setFurLength(config.furLength);
      if (purr) purr.setEnabled(config.purringEnabled);
      if (behavior) {
        behavior.setPersonality({
          activity: config.activity,
          curiosity: config.curiosity,
          playfulness: config.playfulness,
          mouseReactions: config.mouseReactions,
          respectGnomeTerritories: config.respectGnomeTerritories
        });
        const { visibleH, visibleW, worldPerPx } = viewMetrics();
        behavior.setEnvironment({
          ...normalizedEnvironment(),
          worldPerPx,
          screenWidthWorld: visibleW,
          screenHeightWorld: visibleH
        });
        behavior.setGnomeTerritories(normalizedGnomeTerritories(config.gnomeTerritories));
        behavior.setGnomePlantTargets(normalizedPlantMissionTargets(config.plantMissionTargets));
      }
      return 'ok';
    },
    // Mouse position in CSS pixels relative to this window (x from the
    // left edge, y from the top edge). The window is a bottom-of-screen
    // band, so py can be negative when the cursor is above the band —
    // the math stays continuous and the cat just looks up at it.
    mouse(px, py) {
      if (!behavior) return;
      const point = worldPointFromWindowPx(px, py);
      behavior.setMouse(point.x, point.y);
    },
    mouseGone() {
      if (behavior) behavior.clearMouse();
    },
    // Moving bug targets from Swift, in window-local CSS px. They are
    // converted to the same world space as the cursor so the cat can stalk,
    // lunge, and catch actual live bug layers.
    bugs(items) {
      if (!behavior) return;
      const bugs = Array.isArray(items)
        ? items.map((item) => {
            const point = worldPointFromWindowPx(Number(item.x) || 0, Number(item.y) || 0);
            return {
              id: String(item.id || ''),
              species: String(item.species || ''),
              x: point.x,
              y: point.y,
              plantFocused: !!item.plantFocused
            };
          }).filter((item) => item.id)
        : [];
      behavior.setBugs(bugs);
    },
    gnomeTerritories(items) {
      config.gnomeTerritories = Array.isArray(items) ? items : [];
      if (behavior) behavior.setGnomeTerritories(normalizedGnomeTerritories(config.gnomeTerritories));
    },
    plantMissionTargets(items) {
      config.plantMissionTargets = Array.isArray(items) ? items : [];
      if (behavior) behavior.setGnomePlantTargets(normalizedPlantMissionTargets(config.plantMissionTargets));
    },
    // A real mouse click at window-local CSS px. Used to tap a climbing
    // cat down off the wall.
    click(px, py) {
      if (!behavior) return { hit: false, opensChat: false, action: 'none' };
      const point = worldPointFromWindowPx(px, py);
      return behavior.pokeAt(point.x, point.y);
    },
    setPaused(value) {
      return setPaused(value);
    },
    status() {
      return JSON.stringify({
        ready: !!behavior,
        state: behavior ? behavior.state.name : 'booting',
        mood: behavior ? behavior.state.mood : 'unknown',
        worldX: behavior ? Number(behavior.state.worldX.toFixed(3)) : 0,
        worldY: behavior ? Number(behavior.state.worldY.toFixed(3)) : 0,
        bugsVisible: behavior ? behavior.state.bugs.length : 0,
        bugTarget: behavior ? behavior.state.targetBugID : null,
        gnomeTerritories: behavior ? behavior.state.gnomeTerritories.length : 0,
        plantMissionTargets: behavior ? behavior.state.gnomePlantTargets.length : 0,
        gnomeRide: behavior && behavior.gnomeRiding ? behavior.gnomeRiding() : null,
        purr: purr ? purr.status() : null,
        environment: normalizedEnvironment(),
        paused
      });
    }
  };

  start();
})();
