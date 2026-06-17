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
    return material;
  }

  function addMesh(parent, geometry, material, transform = {}) {
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(transform.x || 0, transform.y || 0, transform.z || 0);
    mesh.rotation.set(transform.rx || 0, transform.ry || 0, transform.rz || 0);
    mesh.scale.set(transform.sx || 1, transform.sy || 1, transform.sz || 1);
    parent.add(mesh);
    return mesh;
  }

  function makeWing(species, side) {
    const wing = new THREE.Group();
    const wingMaterial = makeMaterial(species.wing);
    const accentMaterial = makeMaterial(species.accent, { transparent: true, opacity: 0.70 });
    const baseAngle = side * -0.28;

    addMesh(
      wing,
      new THREE.BoxGeometry(20, 3.0, 3.2),
      wingMaterial,
      { x: -4, y: side * 6.2, z: 0.4, rz: baseAngle, sx: 1.0, sy: 1, sz: 1 }
    );
    wing.add(makeFeatherLayer(species, side, wingMaterial, accentMaterial, baseAngle));
    return wing;
  }

  function makeFeatherLayer(species, side, wingMaterial, accentMaterial, baseAngle) {
    const layer = new THREE.Group();
    const primaryCount = species.behavior === 'soar' ? 7 : 5;
    for (let index = 0; index < primaryCount; index += 1) {
      const featherLength = (14.5 - index * 0.92) * (species.id === 'red-tailed-hawk' ? 1.32 : 1);
      addMesh(
        layer,
        new THREE.BoxGeometry(featherLength, 1.15, 1.45),
        index % 2 === 0 ? wingMaterial : accentMaterial,
        {
          x: -9.5 - index * 2.1,
          y: side * (8.0 + index * 2.0),
          z: 0.2 - index * 0.035,
          rz: baseAngle + side * (0.10 + index * 0.045),
          sx: 1,
          sy: 1,
          sz: 1
        }
      );
    }
    for (let index = 0; index < 3; index += 1) {
      addMesh(
        layer,
        new THREE.BoxGeometry(9.5 - index * 0.7, 0.72, 1.2),
        accentMaterial,
        {
          x: -5.5 - index * 2.3,
          y: side * (5.1 + index * 1.25),
          z: 1.05,
          rz: baseAngle + side * (0.02 + index * 0.025),
          sx: 1,
          sy: 1,
          sz: 1
        }
      );
    }
    return layer;
  }

  function makeTail(species) {
    const tail = new THREE.Group();
    const material = makeMaterial(species.wing);
    for (let index = 0; index < 3; index += 1) {
      addMesh(
        tail,
        new THREE.BoxGeometry(11, 1.8, 1.8),
        material,
        {
          x: -18,
          y: (index - 1) * 2.2,
          rz: (index - 1) * 0.18,
          sx: species.id === 'barn-swallow' ? 1.35 : 1
        }
      );
    }
    return tail;
  }

  function makeBird(species) {
    const root = new THREE.Group();
    root.userData.species = species;
    root.userData.parts = {};

    const bodyMaterial = makeMaterial(species.body);
    const breastMaterial = makeMaterial(species.breast, { transparent: true, opacity: 0.95 });
    const headMaterial = makeMaterial(species.body);
    const accentMaterial = makeMaterial(species.accent);
    const beakMaterial = makeMaterial(species.beak);
    const eyeMaterial = makeMaterial('#101014');
    const catchlightMaterial = makeMaterial('#ffffff', { roughness: 0.18 });

    addMesh(root, new THREE.SphereGeometry(1, 24, 16), bodyMaterial, {
      sx: 15.5,
      sy: 7.0,
      sz: 5.5
    });
    addMesh(root, new THREE.SphereGeometry(1, 18, 12), breastMaterial, {
      x: 3.2,
      y: 1.8,
      z: 0.4,
      sx: 8.6,
      sy: 4.0,
      sz: 2.0
    });
    addMesh(root, new THREE.SphereGeometry(1, 20, 14), headMaterial, {
      x: 12.5,
      y: -2.1,
      z: 0.4,
      sx: 6.0,
      sy: 5.1,
      sz: 4.4
    });
    if (species.id === 'northern-cardinal') {
      addMesh(root, new THREE.ConeGeometry(3.1, 7.0, 18), bodyMaterial, {
        x: 11.0,
        y: -7.0,
        rz: Math.PI
      });
    }
    addMesh(root, new THREE.ConeGeometry(1.8, species.id === 'ruby-throated-hummingbird' ? 15 : 7, 18), beakMaterial, {
      x: 18.4,
      y: -2.0,
      rz: -Math.PI / 2
    });
    addMesh(root, new THREE.SphereGeometry(1, 10, 8), eyeMaterial, {
      x: 14.7,
      y: -5.0,
      z: 2.2,
      sx: 1.0,
      sy: 1.0,
      sz: 0.55
    });
    addMesh(root, new THREE.SphereGeometry(1, 8, 6), catchlightMaterial, {
      x: 15.15,
      y: -5.42,
      z: 2.62,
      sx: 0.24,
      sy: 0.24,
      sz: 0.14
    });
    addMesh(root, new THREE.SphereGeometry(1, 10, 8), eyeMaterial, {
      x: 15.0,
      y: 0.2,
      z: 2.0,
      sx: 0.76,
      sy: 0.76,
      sz: 0.46
    });
    addMesh(root, new THREE.SphereGeometry(1, 8, 6), catchlightMaterial, {
      x: 15.35,
      y: -0.10,
      z: 2.36,
      sx: 0.18,
      sy: 0.18,
      sz: 0.11
    });

    const leftWing = makeWing(species, -1);
    const rightWing = makeWing(species, 1);
    const tail = makeTail(species);
    root.add(leftWing, rightWing, tail);
    root.userData.parts.leftWing = leftWing;
    root.userData.parts.rightWing = rightWing;
    root.userData.parts.tail = tail;

    addMesh(root, new THREE.BoxGeometry(1.0, 5.2, 1.0), accentMaterial, {
      x: -2.0,
      y: 6.0,
      z: -0.2,
      rz: 0.18
    });
    addMesh(root, new THREE.BoxGeometry(1.0, 5.0, 1.0), accentMaterial, {
      x: 0.8,
      y: 6.2,
      z: -0.2,
      rz: -0.10
    });

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

    state.birds = math.rebuildBirdsForZones(state.zones, state.width, state.height);
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
    return JSON.stringify(zones.map((zone) => ({
      id: zone.id,
      seed: zone.skySeed,
      points: zone.points.map((point) => [
        Math.round(point.x),
        Math.round(point.y)
      ])
    })));
  }

  function configure(payload) {
    const nextWidth = payload?.screenWidthPx || window.innerWidth || 1;
    const nextHeight = payload?.screenHeightPx || window.innerHeight || 1;
    resize(nextWidth, nextHeight);
    state.lightLevel = math.clamp(payload?.lightLevel ?? 1, 0.15, 1);
    state.lightMood = payload?.lightMood || 'bright';
    state.windStrength = math.clamp(payload?.windStrength ?? 0.5, 0, 1);
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
        child.material.opacity = Math.min(child.material.opacity || 1, 0.70 + state.lightLevel * 0.30);
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
    const secondaryFlap = Math.sin(bird.wingPhase + Math.PI * 0.42);
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
    const wingTravel = species.behavior === 'soar'
      ? 0.16
      : 0.46 + Math.min(0.34, speed / 180);
    parts.leftWing.rotation.z = -0.18 - flap * wingTravel;
    parts.rightWing.rotation.z = 0.18 + secondaryFlap * wingTravel;
    parts.leftWing.rotation.x = flap * 0.26 * glideFold - bank * 0.22;
    parts.rightWing.rotation.x = -secondaryFlap * 0.26 * glideFold - bank * 0.22;
    parts.tail.rotation.z = Math.sin(bird.age * 1.6 + bird.behaviorPhase) * 0.11 + bank * 0.16;
    parts.tail.rotation.y = -Math.sin(velocityAngle) * 0.14;
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
        renderer: 'three-js-bird-flock',
        speciesCount: speciesCatalog.length,
        birdCount: state.birds.length,
        zoneCount: state.zones.length,
        lightLevel: state.lightLevel,
        windStrength: state.windStrength,
        lightingSignature: state.lightingSignature
      };
    }
  };

  window.requestAnimationFrame(animate);
}());
