(function bootBirdFlockRenderer() {
  'use strict';

  const math = window.BirdFlockMath;
  const speciesCatalog = math.speciesCatalog();
  const renderer = new THREE.WebGLRenderer({
    alpha: true,
    antialias: true,
    powerPreference: 'low-power'
  });
  renderer.setClearColor(0x000000, 0);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  document.body.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const camera = new THREE.OrthographicCamera(0, 1, 1, 0, -1000, 1000);
  camera.position.z = 500;

  const ambientLight = new THREE.AmbientLight(0xffffff, 0.72);
  const sunLight = new THREE.DirectionalLight(0xfff2d2, 0.76);
  sunLight.position.set(160, -220, 380);
  scene.add(ambientLight, sunLight);

  const state = {
    width: 1,
    height: 1,
    zones: [],
    zoneSignature: '',
    birds: [],
    groups: [],
    plants: [],
    lightLevel: 1,
    lightMood: 'bright',
    windStrength: 0.5,
    birdCountMultiplier: 1,
    lightingSignature: '',
    lastTime: performance.now()
  };

  function resize(width, height) {
    const nextWidth = Math.max(1, Math.round(width || window.innerWidth || 1));
    const nextHeight = Math.max(1, Math.round(height || window.innerHeight || 1));
    if (state.width === nextWidth && state.height === nextHeight) {
      return;
    }

    state.width = nextWidth;
    state.height = nextHeight;
    renderer.setSize(nextWidth, nextHeight, false);
    camera.left = 0;
    camera.right = nextWidth;
    camera.top = 0;
    camera.bottom = nextHeight;
    camera.updateProjectionMatrix();
  }

  function makeMaterial(color, options = {}) {
    const material = new THREE.MeshStandardMaterial({
      color,
      roughness: options.roughness ?? 0.82,
      metalness: options.metalness ?? 0.02,
      transparent: options.transparent ?? false,
      opacity: options.opacity ?? 1,
      side: THREE.DoubleSide
    });
    material.userData.baseColor = new THREE.Color(color);
    material.userData.baseOpacity = options.opacity ?? 1;
    return material;
  }

  function addMesh(parent, geometry, material, transform = {}) {
    const mesh = new THREE.Mesh(geometry, material);
    mesh.name = transform.name || '';
    mesh.position.set(transform.x || 0, transform.y || 0, transform.z || 0);
    mesh.rotation.set(transform.rx || 0, transform.ry || 0, transform.rz || 0);
    mesh.scale.set(transform.sx || 1, transform.sy || 1, transform.sz || 1);
    parent.add(mesh);
    return mesh;
  }

  function makeFeatherGeometry(length, rootWidth, tipWidth, camber = 0.22) {
    const root = rootWidth * 0.5;
    const mid = rootWidth * 0.34;
    const tip = tipWidth * 0.5;
    const x = -Math.abs(length);
    const geometry = new THREE.BufferGeometry();
    const vertices = new Float32Array([
      0, -root, 0,
      0, root, 0,
      x * 0.52, -mid, camber,
      x * 0.52, mid, camber,
      x, -tip, 0,
      x, tip, 0
    ]);
    geometry.setAttribute('position', new THREE.BufferAttribute(vertices, 3));
    geometry.setIndex([
      0, 1, 2,
      1, 3, 2,
      2, 3, 4,
      3, 5, 4
    ]);
    geometry.computeVertexNormals();
    return geometry;
  }

  function makeWingSurfaceGeometry(species, side) {
    const spanScale = species.id === 'red-tailed-hawk' ? 1.26 : species.id === 'ruby-throated-hummingbird' ? 0.72 : 1;
    const geometry = new THREE.BufferGeometry();
    const vertices = new Float32Array([
      0, 0, 0.18,
      -5.0 * spanScale, side * 3.2, 0.55,
      -12.0 * spanScale, side * 7.4, 0.34,
      -22.0 * spanScale, side * 11.8, -0.10,
      -13.5 * spanScale, side * 5.6, -0.42,
      -4.2 * spanScale, side * 1.4, -0.24
    ]);
    geometry.setAttribute('position', new THREE.BufferAttribute(vertices, 3));
    geometry.setIndex([
      0, 1, 5,
      1, 2, 5,
      2, 4, 5,
      2, 3, 4
    ]);
    geometry.computeVertexNormals();
    return geometry;
  }

  function makeWingBlurGeometry(species, side) {
    const spanScale = species.id === 'red-tailed-hawk' ? 1.34 : species.id === 'ruby-throated-hummingbird' ? 0.82 : 1.08;
    const geometry = new THREE.BufferGeometry();
    const vertices = new Float32Array([
      0, 0, 0,
      -6.0 * spanScale, side * 5.0, 0.22,
      -18.0 * spanScale, side * 14.0, 0.06,
      -26.0 * spanScale, side * 19.0, -0.08,
      -15.0 * spanScale, side * 4.0, -0.10,
      -4.0 * spanScale, side * -1.5, -0.04
    ]);
    geometry.setAttribute('position', new THREE.BufferAttribute(vertices, 3));
    geometry.setIndex([
      0, 1, 5,
      1, 2, 5,
      2, 4, 5,
      2, 3, 4
    ]);
    geometry.computeVertexNormals();
    return geometry;
  }

  function makeWing(species, side) {
    const wing = new THREE.Group();
    wing.name = side < 0 ? 'leftWing' : 'rightWing';
    wing.position.set(2.0, side * 4.0, 0.8);
    wing.userData.parts = {};

    const wingMaterial = makeMaterial(species.wing, { roughness: 0.72 });
    const covertMaterial = makeMaterial(species.accent, { transparent: true, opacity: 0.76, roughness: 0.64 });
    const blurMaterial = makeMaterial('#d8f4ff', { transparent: true, opacity: 0.0, roughness: 0.38 });
    const boneMaterial = makeMaterial(species.body, { roughness: 0.76 });

    const blur = addMesh(
      wing,
      makeWingBlurGeometry(species, side),
      blurMaterial,
      { name: 'wingBlur', z: 0.08 }
    );
    wing.userData.parts.blur = blur;

    const surface = addMesh(
      wing,
      makeWingSurfaceGeometry(species, side),
      wingMaterial,
      { name: 'wingSurface', z: 0.16 }
    );
    wing.userData.parts.surface = surface;

    addMesh(
      wing,
      new THREE.SphereGeometry(1, 14, 10),
      boneMaterial,
      { name: 'shoulder', x: 0.2, y: side * 0.2, z: 0.62, sx: 2.5, sy: 1.15, sz: 0.70 }
    );

    const primaries = new THREE.Group();
    primaries.name = 'primaryFeathers';
    const secondaries = new THREE.Group();
    secondaries.name = 'secondaryFeathers';
    wing.add(secondaries, primaries);
    wing.userData.parts.primaries = primaries;
    wing.userData.parts.secondaries = secondaries;

    const primaryCount = species.behavior === 'soar' ? 9 : 7;
    const longWing = species.id === 'red-tailed-hawk' ? 1.28 : species.id === 'barn-swallow' ? 1.18 : 1;
    for (let index = 0; index < primaryCount; index += 1) {
      const length = (13.8 - index * 0.58) * longWing;
      const feather = addMesh(
        primaries,
        makeFeatherGeometry(length, 2.55, 0.38, 0.22),
        index % 2 === 0 ? wingMaterial : covertMaterial,
        {
          name: 'primaryFeather',
          x: -10.8 - index * 1.9,
          y: side * (7.2 + index * 1.78),
          z: 0.02 - index * 0.018,
          rz: side * (0.16 + index * 0.055),
          ry: side * 0.035
        }
      );
      feather.userData.baseRz = feather.rotation.z;
    }

    for (let index = 0; index < 5; index += 1) {
      const feather = addMesh(
        secondaries,
        makeFeatherGeometry(9.4 - index * 0.45, 2.25, 0.48, 0.24),
        index % 2 === 0 ? covertMaterial : wingMaterial,
        {
          name: 'secondaryFeather',
          x: -4.6 - index * 2.0,
          y: side * (3.5 + index * 0.92),
          z: 0.45,
          rz: side * (0.04 + index * 0.036)
        }
      );
      feather.userData.baseRz = feather.rotation.z;
    }

    return wing;
  }

  function makeTail(species) {
    const tail = new THREE.Group();
    tail.name = 'tailFan';
    tail.position.set(-14.6, 0, -0.12);
    tail.userData.parts = [];
    const material = makeMaterial(species.wing, { roughness: 0.74 });
    const accent = makeMaterial(species.accent, { transparent: true, opacity: 0.72 });
    const featherCount = species.id === 'barn-swallow' ? 4 : 5;
    for (let index = 0; index < featherCount; index += 1) {
      const centered = index - (featherCount - 1) / 2;
      const swallowFork = species.id === 'barn-swallow' && Math.abs(centered) > 1 ? 1.7 : 1;
      const feather = addMesh(
        tail,
        makeFeatherGeometry((9.8 + Math.abs(centered) * 0.8) * swallowFork, 2.0, 0.44, 0.16),
        Math.abs(centered) < 0.5 ? material : accent,
        {
          name: 'tailFeather',
          y: centered * 1.35,
          z: -Math.abs(centered) * 0.05,
          rz: centered * 0.12
        }
      );
      feather.userData.baseRz = feather.rotation.z;
      tail.userData.parts.push(feather);
    }
    return tail;
  }

  function makeLegPair(root, species, legMaterial) {
    for (const side of [-1, 1]) {
      addMesh(root, new THREE.CylinderGeometry(0.18, 0.14, 4.6, 8), legMaterial, {
        name: 'leg',
        x: -1.8,
        y: side * 2.4,
        z: -3.7,
        rx: Math.PI / 2,
        rz: side * 0.12
      });
      addMesh(root, new THREE.ConeGeometry(0.34, 2.1, 8), legMaterial, {
        name: 'talon',
        x: -2.9,
        y: side * 3.1,
        z: -4.2,
        rz: -Math.PI / 2 + side * 0.16,
        sx: species.id === 'red-tailed-hawk' ? 1.35 : 0.85
      });
    }
  }

  function makeBird(species) {
    const root = new THREE.Group();
    root.userData.species = species;
    root.userData.parts = {};

    const bodyMaterial = makeMaterial(species.body, { roughness: 0.68 });
    const breastMaterial = makeMaterial(species.breast, { transparent: true, opacity: 0.96, roughness: 0.66 });
    const throatMaterial = makeMaterial(species.accent, { transparent: true, opacity: species.id === 'ruby-throated-hummingbird' ? 0.96 : 0.72 });
    const beakMaterial = makeMaterial(species.beak, { roughness: 0.46 });
    const eyeMaterial = makeMaterial('#101014', { roughness: 0.22 });
    const catchlightMaterial = makeMaterial('#ffffff', { roughness: 0.10 });
    const legMaterial = makeMaterial(species.beak === '#151515' ? '#181a1c' : '#6d573c', { roughness: 0.58 });

    addMesh(root, new THREE.SphereGeometry(1, 32, 18), bodyMaterial, {
      name: 'streamlinedBody',
      x: -1.8,
      z: 0.02,
      sx: 14.8,
      sy: 5.8,
      sz: 4.6
    });
    addMesh(root, new THREE.SphereGeometry(1, 24, 14), breastMaterial, {
      name: 'keelBreast',
      x: 2.4,
      y: 0,
      z: -1.6,
      sx: 8.0,
      sy: 4.2,
      sz: 2.4
    });
    addMesh(root, new THREE.SphereGeometry(1, 18, 12), bodyMaterial, {
      name: 'neck',
      x: 8.8,
      z: 0.65,
      sx: 3.8,
      sy: 3.2,
      sz: 2.8
    });
    addMesh(root, new THREE.SphereGeometry(1, 28, 16), bodyMaterial, {
      name: 'head',
      x: 13.2,
      z: 0.85,
      sx: 5.4,
      sy: 4.2,
      sz: 3.9
    });
    addMesh(root, new THREE.SphereGeometry(1, 18, 10), throatMaterial, {
      name: 'throatPatch',
      x: 12.9,
      y: 0,
      z: -1.45,
      sx: 3.1,
      sy: 2.6,
      sz: 0.92
    });
    if (species.id === 'northern-cardinal') {
      addMesh(root, new THREE.ConeGeometry(2.8, 6.6, 18), bodyMaterial, {
        name: 'crest',
        x: 11.0,
        z: 5.4,
        rx: Math.PI * 0.08,
        rz: Math.PI
      });
    }
    addMesh(root, new THREE.ConeGeometry(1.25, species.id === 'ruby-throated-hummingbird' ? 16 : 6.8, 22), beakMaterial, {
      name: 'beak',
      x: 18.1,
      z: 0.65,
      rz: -Math.PI / 2
    });
    for (const side of [-1, 1]) {
      addMesh(root, new THREE.SphereGeometry(1, 12, 8), eyeMaterial, {
        name: 'eye',
        x: 14.7,
        y: side * 2.95,
        z: 2.35,
        sx: 0.72,
        sy: 0.42,
        sz: 0.72
      });
      addMesh(root, new THREE.SphereGeometry(1, 8, 6), catchlightMaterial, {
        name: 'catchlight',
        x: 15.08,
        y: side * 3.18,
        z: 2.66,
        sx: 0.17,
        sy: 0.10,
        sz: 0.17
      });
    }

    if (species.id === 'blue-jay') {
      addMesh(root, new THREE.ConeGeometry(2.2, 5.4, 16), bodyMaterial, {
        name: 'crest',
        x: 11.8,
        z: 5.15,
        rz: Math.PI
      });
    }

    addMesh(root, new THREE.SphereGeometry(1, 16, 10), throatMaterial, {
      name: 'speciesMarking',
      x: species.id === 'ruby-throated-hummingbird' ? 13.6 : -2.4,
      z: species.id === 'ruby-throated-hummingbird' ? -0.85 : 2.9,
      sx: species.id === 'ruby-throated-hummingbird' ? 2.5 : 5.6,
      sy: species.id === 'ruby-throated-hummingbird' ? 2.0 : 1.4,
      sz: 0.45
    });

    const leftWing = makeWing(species, -1);
    const rightWing = makeWing(species, 1);
    const tail = makeTail(species);
    root.add(leftWing, rightWing, tail);
    root.userData.parts.leftWing = leftWing;
    root.userData.parts.rightWing = rightWing;
    root.userData.parts.leftPrimaries = leftWing.userData.parts.primaries;
    root.userData.parts.rightPrimaries = rightWing.userData.parts.primaries;
    root.userData.parts.leftSecondaries = leftWing.userData.parts.secondaries;
    root.userData.parts.rightSecondaries = rightWing.userData.parts.secondaries;
    root.userData.parts.leftWingBlur = leftWing.userData.parts.blur;
    root.userData.parts.rightWingBlur = rightWing.userData.parts.blur;
    root.userData.parts.tail = tail;

    makeLegPair(root, species, legMaterial);

    return root;
  }

  function disposeObjectTree(object) {
    object.traverse((child) => {
      if (child.geometry) {
        child.geometry.dispose();
      }
      if (child.material) {
        if (Array.isArray(child.material)) {
          child.material.forEach((material) => material.dispose());
        } else {
          child.material.dispose();
        }
      }
    });
  }

  function clearBirds() {
    for (const group of state.groups) {
      scene.remove(group);
      disposeObjectTree(group);
    }
    state.groups = [];
    state.birds = [];
  }

  function rebuildFlock() {
    clearBirds();
    if (!state.zones.length) {
      return;
    }

    state.birds = math.rebuildBirdsForZones(state.zones, state.width, state.height, {
      countMultiplier: state.birdCountMultiplier
    });
    state.groups = state.birds.map((bird) => {
      const species = speciesCatalog[bird.speciesIndex % speciesCatalog.length];
      const group = makeBird(species);
      scene.add(group);
      return group;
    });
    state.lightingSignature = '';
    applyLightingToFlock();
  }

  function zoneSignature(zones) {
    return JSON.stringify({
      count: Math.round(state.birdCountMultiplier * 100),
      zones: zones.map((zone) => ({
        id: zone.id,
        seed: zone.skySeed,
        points: zone.points.map((point) => [
          Math.round(point.x),
          Math.round(point.y)
        ])
      }))
    });
  }

  function configure(payload) {
    const nextWidth = payload?.screenWidthPx || window.innerWidth || 1;
    const nextHeight = payload?.screenHeightPx || window.innerHeight || 1;
    resize(nextWidth, nextHeight);
    state.lightLevel = math.clamp(payload?.lightLevel ?? 1, 0.15, 1);
    state.lightMood = payload?.lightMood || 'bright';
    state.windStrength = math.clamp(payload?.windStrength ?? 0.5, 0, 1);
    state.birdCountMultiplier = math.clamp(payload?.birdCountMultiplier ?? 1, 0.25, 2.0);
    state.plants = payload?.plants || [];
    const nextZones = (payload?.zones || []).map((zone) => math.zoneToPixels(zone, state.width, state.height));
    const nextSignature = zoneSignature(nextZones);
    if (nextSignature !== state.zoneSignature) {
      state.zones = nextZones;
      state.zoneSignature = nextSignature;
      rebuildFlock();
    }
    applyLightingToFlock();
  }

  function lightingSignatureForState() {
    return [
      Math.round(state.lightLevel * 100),
      state.lightMood,
      state.groups.length
    ].join(':');
  }

  function applyLightingToFlock() {
    const signature = lightingSignatureForState();
    if (signature === state.lightingSignature) {
      return;
    }
    state.lightingSignature = signature;
    const brightness = 0.34 + state.lightLevel * 0.76;
    const warmth = state.lightMood === 'golden-hour' ? 1.08 : 1.0;
    for (const group of state.groups) {
      group.traverse((child) => {
        if (!child.material || !child.material.userData.baseColor) {
          return;
        }
        child.material.color.copy(child.material.userData.baseColor)
          .multiplyScalar(brightness * warmth);
        child.material.opacity = Math.min(
          child.material.userData.baseOpacity ?? 1,
          0.70 + state.lightLevel * 0.30
        );
        child.material.needsUpdate = true;
      });
    }
    const hasSoaringBird = state.birds.some((bird) => {
      const species = speciesCatalog[bird.speciesIndex % speciesCatalog.length];
      return species.behavior === 'soar';
    });
    ambientLight.intensity = 0.36 + state.lightLevel * 0.50;
    sunLight.intensity = 0.22 + state.lightLevel * 0.72 + (hasSoaringBird ? 0.08 : 0);
  }

  function updateBirdVisual(bird, group, dt) {
    const species = speciesCatalog[bird.speciesIndex % speciesCatalog.length];
    const velocityAngle = Math.atan2(bird.vy, bird.vx);
    const speed = bird.airspeed || Math.hypot(bird.vx, bird.vy);
    const flap = Math.sin(bird.wingPhase);
    const bank = bird.bank || 0;
    const depthScale = species.size * (0.42 + bird.depth * 0.52);
    const hoverWobble = species.behavior === 'hover'
      ? Math.sin(bird.age * 15 + bird.behaviorPhase) * 2.4
      : 0;

    group.position.set(bird.x, bird.y + hoverWobble, bird.depth * 40);
    group.rotation.z = velocityAngle;
    group.rotation.x = -bank * 0.34;
    group.rotation.y = bank * 0.52 + Math.sin(bird.age * 0.9 + bird.behaviorPhase) * 0.06;
    group.scale.setScalar(depthScale);

    const parts = group.userData.parts;
    const glideFold = species.behavior === 'soar' || species.behavior === 'glide'
      ? 0.36
      : 1.0;
    const downstroke = Math.max(0, -flap);
    const upstroke = Math.max(0, flap);
    const wingTravel = species.behavior === 'soar'
      ? 0.12 + (bird.sinkRate > 3 ? 0.10 : 0)
      : species.behavior === 'hover'
        ? 0.94
        : 0.42 + Math.min(0.34, speed / 180);
    parts.leftWing.rotation.z = -0.18 - flap * wingTravel;
    parts.rightWing.rotation.z = 0.18 + flap * wingTravel;
    parts.leftWing.rotation.x = flap * 0.42 * glideFold - bank * 0.22;
    parts.rightWing.rotation.x = -flap * 0.42 * glideFold - bank * 0.22;
    parts.leftPrimaries.rotation.z = -downstroke * 0.12 - upstroke * 0.06;
    parts.rightPrimaries.rotation.z = downstroke * 0.12 + upstroke * 0.06;
    parts.leftSecondaries.rotation.z = -downstroke * 0.07;
    parts.rightSecondaries.rotation.z = downstroke * 0.07;
    const blurOpacity = species.flapHz > 10
      ? 0.18 + Math.min(0.24, species.flapHz / 180)
      : Math.max(0, (Math.abs(flap) - 0.58) * 0.18);
    parts.leftWingBlur.material.opacity = blurOpacity;
    parts.rightWingBlur.material.opacity = blurOpacity;
    parts.leftWingBlur.material.needsUpdate = true;
    parts.rightWingBlur.material.needsUpdate = true;
    parts.tail.rotation.z = Math.sin(bird.age * 1.6 + bird.behaviorPhase) * 0.11 + bank * 0.16;
    parts.tail.rotation.y = -Math.sin(velocityAngle) * 0.14;
    parts.tail.rotation.x = math.clamp((bird.sinkRate || 0) * -0.018, -0.18, 0.18);
  }

  function animate(now) {
    const dt = Math.min(0.045, Math.max(0.001, (now - state.lastTime) / 1000));
    state.lastTime = now;
    math.stepFlock(state.birds, state.zones, dt, {
      windStrength: state.windStrength,
      time: now / 1000
    });
    for (let index = 0; index < state.birds.length; index += 1) {
      updateBirdVisual(state.birds[index], state.groups[index], dt);
    }
    renderer.render(scene, camera);
    window.requestAnimationFrame(animate);
  }

  resize(window.innerWidth, window.innerHeight);
  window.addEventListener('resize', () => {
    resize(window.innerWidth, window.innerHeight);
    state.zoneSignature = '';
  });

  window.birdBridge = {
    configure,
    status() {
      return {
        renderer: 'three-js-anatomical-bird-flock',
        speciesCount: speciesCatalog.length,
        birdCount: state.birds.length,
        birdCountMultiplier: state.birdCountMultiplier,
        zoneCount: state.zones.length,
        lightLevel: state.lightLevel,
        windStrength: state.windStrength,
        lightingSignature: state.lightingSignature
      };
    }
  };

  window.requestAnimationFrame(animate);
}());
