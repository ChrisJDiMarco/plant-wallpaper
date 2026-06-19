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
  if ('outputEncoding' in renderer && THREE.sRGBEncoding) {
    renderer.outputEncoding = THREE.sRGBEncoding;
  }
  renderer.sortObjects = true;
  document.body.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const camera = new THREE.OrthographicCamera(0, 1, 1, 0, -1000, 1000);
  camera.position.z = 500;

  const ambientLight = new THREE.AmbientLight(0xffffff, 0.74);
  const skyLight = new THREE.HemisphereLight(0xeaf8ff, 0x7b5a3c, 0.72);
  const sunLight = new THREE.DirectionalLight(0xfff2d2, 0.88);
  sunLight.position.set(180, -260, 420);
  const cameraFillLight = new THREE.DirectionalLight(0xf8fbff, 0.42);
  cameraFillLight.position.set(0, 0, 520);
  const rimLight = new THREE.DirectionalLight(0xcfeaff, 0.52);
  rimLight.position.set(-260, 170, 260);
  scene.add(ambientLight, skyLight, sunLight, cameraFillLight, rimLight);

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
    pixelStatsRequestId: 0,
    pixelStatsCompletedId: 0,
    lastPixelStats: null,
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

  const warmFillColor = new THREE.Color(0xfff1d8);
  const coolFillColor = new THREE.Color(0xdff4ff);

  function liftedColor(color, amount, fill = warmFillColor) {
    return new THREE.Color(color).lerp(fill, math.clamp(amount, 0, 1));
  }

  function luminance(color) {
    return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722;
  }

  function makeMaterial(color, options = {}) {
    const baseColor = liftedColor(color, options.colorLift ?? 0);
    const material = new THREE.MeshStandardMaterial({
      color: baseColor,
      roughness: options.roughness ?? 0.82,
      metalness: options.metalness ?? 0.02,
      transparent: options.transparent ?? false,
      opacity: options.opacity ?? 1,
      side: options.side ?? THREE.DoubleSide,
      emissive: liftedColor(color, options.emissiveLift ?? 0.14, coolFillColor),
      emissiveIntensity: options.emissiveIntensity ?? 0.045,
      depthWrite: options.depthWrite ?? !(options.transparent ?? false)
    });
    material.userData.baseColor = baseColor.clone();
    material.userData.minimumLift = options.minimumLift ?? (luminance(baseColor) < 0.09 ? 0.18 : 0.055);
    material.userData.baseOpacity = options.opacity ?? 1;
    material.userData.baseEmissiveIntensity = material.emissiveIntensity;
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

  function addBoneBetween(parent, start, end, radius, material, name) {
    const from = new THREE.Vector3(start.x, start.y, start.z);
    const to = new THREE.Vector3(end.x, end.y, end.z);
    const direction = new THREE.Vector3().subVectors(to, from);
    const length = Math.max(0.001, direction.length());
    const mesh = new THREE.Mesh(
      new THREE.CylinderGeometry(radius * 0.72, radius, length, 12),
      material
    );
    mesh.name = name || 'wingBone';
    mesh.position.copy(from).addScaledVector(direction, 0.5);
    mesh.quaternion.setFromUnitVectors(
      new THREE.Vector3(0, 1, 0),
      direction.clone().normalize()
    );
    parent.add(mesh);
    return mesh;
  }

  function makeEllipsoid(parent, material, name, transform = {}) {
    return addMesh(parent, new THREE.SphereGeometry(1, 32, 18), material, {
      name,
      ...transform
    });
  }

  function makeWingPanelGeometry(points, camber = 0.22, thickness = 0.09) {
    const top = points.map((point, index) => [
      point[0],
      point[1],
      (point[2] || 0) + camber * Math.sin((index / Math.max(1, points.length - 1)) * Math.PI)
    ]);
    const bottom = top.map(([x, y, z]) => [x, y, z - thickness]);
    const vertices = new Float32Array([...top.flat(), ...bottom.flat()]);
    const indices = [];
    for (let index = 1; index < points.length - 1; index += 1) {
      indices.push(0, index, index + 1);
      indices.push(points.length, points.length + index + 1, points.length + index);
    }
    for (let index = 0; index < points.length; index += 1) {
      const next = (index + 1) % points.length;
      indices.push(index, next, points.length + index);
      indices.push(next, points.length + next, points.length + index);
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(vertices, 3));
    geometry.setIndex(indices);
    geometry.computeVertexNormals();
    return geometry;
  }

  function makeFeatherGeometry(length, rootWidth, tipWidth, camber = 0.22, thickness = 0.16) {
    const root = rootWidth * 0.5;
    const mid = rootWidth * 0.34;
    const tip = tipWidth * 0.5;
    const x = -Math.abs(length);
    const geometry = new THREE.BufferGeometry();
    const top = [
      [0, -root, thickness * 0.20],
      [0, root, thickness * 0.20],
      [x * 0.46, -mid, camber + thickness * 0.52],
      [x * 0.46, mid, camber + thickness * 0.52],
      [x * 0.83, -tip * 1.15, camber * 0.42 + thickness * 0.20],
      [x * 0.83, tip * 1.15, camber * 0.42 + thickness * 0.20],
      [x, 0, thickness * 0.06]
    ];
    const bottom = top.map(([px, py, pz]) => [px, py, pz - thickness]);
    const vertices = new Float32Array([...top.flat(), ...bottom.flat()]);
    geometry.setAttribute('position', new THREE.BufferAttribute(vertices, 3));
    geometry.setIndex([
      0, 1, 2,
      1, 3, 2,
      2, 3, 4,
      3, 5, 4,
      4, 5, 6,
      7, 9, 8,
      8, 9, 10,
      9, 11, 10,
      10, 11, 13,
      10, 13, 12,
      0, 2, 7,
      2, 9, 7,
      1, 8, 3,
      3, 8, 10,
      4, 6, 11,
      6, 13, 11,
      0, 7, 1,
      1, 7, 8
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
    wing.position.set(5.1, side * 3.65, 1.18);
    wing.userData.parts = {};

    const darkSpeciesLift = species.body === '#16191d' || species.wing === '#0f1115' ? 0.16 : 0.045;
    const wingMaterial = makeMaterial(species.wing, { roughness: 0.66, colorLift: darkSpeciesLift, minimumLift: 0.10 });
    const covertColor = species.id === 'american-robin' ? '#50473c' : species.accent;
    const covertMaterial = makeMaterial(covertColor, {
      transparent: true,
      opacity: 0.84,
      roughness: 0.58,
      colorLift: species.id === 'american-robin' ? 0.025 : 0.08,
      minimumLift: species.id === 'american-robin' ? 0.08 : 0.12
    });
    const rimMaterial = makeMaterial('#f4fbff', {
      transparent: true,
      opacity: species.id === 'american-robin' ? 0.055 : 0.12,
      roughness: 0.36,
      colorLift: 0.08,
      emissiveIntensity: 0.10,
      depthWrite: false
    });
    const blurMaterial = makeMaterial('#d8f4ff', {
      transparent: true,
      opacity: 0.0,
      roughness: 0.32,
      colorLift: 0.12,
      emissiveIntensity: 0.18,
      depthWrite: false
    });
    const shaftMaterial = makeMaterial('#f1d7a8', {
      transparent: true,
      opacity: species.id === 'american-robin' ? 0.22 : species.body === '#16191d' ? 0.30 : 0.42,
      roughness: 0.52,
      colorLift: 0.08
    });
    const boneMaterial = makeMaterial(species.body, { roughness: 0.70, colorLift: darkSpeciesLift, minimumLift: 0.14 });
    const jointMaterial = makeMaterial(species.accent, {
      transparent: true,
      opacity: 0.72,
      roughness: 0.58,
      colorLift: darkSpeciesLift + 0.04,
      minimumLift: 0.14
    });

    const blur = addMesh(
      wing,
      makeWingBlurGeometry(species, side),
      blurMaterial,
      { name: 'wingBlur', z: 0.08 }
    );
    wing.userData.parts.blur = blur;

    const shoulderSocket = makeEllipsoid(wing, jointMaterial, 'shoulderSocket', {
      x: 0.12,
      y: side * 0.05,
      z: 0.54,
      sx: 2.35,
      sy: 1.05,
      sz: 0.82
    });
    wing.userData.parts.shoulderSocket = shoulderSocket;

    const humerus = new THREE.Group();
    humerus.name = 'humerusJoint';
    humerus.position.set(0.1, 0, 0.42);
    humerus.rotation.z = side * 0.11;
    humerus.rotation.x = side * -0.04;
    wing.add(humerus);
    wing.userData.parts.humerus = humerus;

    const elbowPoint = { x: -5.8, y: side * 2.45, z: 0.22 };
    addBoneBetween(humerus, { x: 0, y: 0, z: 0 }, elbowPoint, 0.32, boneMaterial, 'humerusBone');
    addMesh(humerus, makeWingPanelGeometry([
      [0.2, side * -0.15, 0.16],
      [-2.2, side * 1.65, 0.34],
      [-5.5, side * 3.0, 0.20],
      [-6.4, side * 1.3, -0.16],
      [-2.8, side * 0.20, -0.22]
    ], 0.28, 0.10), covertMaterial, {
      name: 'scapularCoverts',
      z: 0.04
    });
    const dorsalSheen = addMesh(humerus, makeWingPanelGeometry([
      [0.7, side * -0.2, 0.36],
      [-2.2, side * 1.5, 0.62],
      [-5.2, side * 2.5, 0.42],
      [-2.5, side * 0.55, 0.20]
    ], 0.18, 0.04), rimMaterial, {
      name: 'dorsalWingSheen',
      z: 0.28
    });
    wing.userData.parts.dorsalSheen = dorsalSheen;

    const elbow = new THREE.Group();
    elbow.name = 'elbowJoint';
    elbow.position.set(elbowPoint.x, elbowPoint.y, elbowPoint.z);
    elbow.rotation.z = side * 0.06;
    humerus.add(elbow);
    wing.userData.parts.elbow = elbow;
    makeEllipsoid(humerus, jointMaterial, 'elbowKnuckle', {
      x: elbowPoint.x,
      y: elbowPoint.y,
      z: elbowPoint.z,
      sx: 0.86,
      sy: 0.56,
      sz: 0.58
    });

    const wristPoint = { x: -7.1, y: side * 4.15, z: -0.04 };
    addBoneBetween(elbow, { x: 0, y: 0, z: 0 }, wristPoint, 0.25, boneMaterial, 'radiusUlna');
    addMesh(elbow, makeWingPanelGeometry([
      [-0.3, side * 0.0, 0.14],
      [-2.8, side * 2.1, 0.30],
      [-6.6, side * 4.4, 0.05],
      [-7.6, side * 2.3, -0.25],
      [-3.0, side * 0.55, -0.22]
    ], 0.24, 0.08), wingMaterial, {
      name: 'secondaryWingMembrane',
      z: 0.04
    });

    const primaries = new THREE.Group();
    primaries.name = 'primaryFeatherFan';
    const secondaries = new THREE.Group();
    secondaries.name = 'secondaryFeatherFan';
    elbow.add(secondaries);
    wing.userData.parts.primaries = primaries;
    wing.userData.parts.secondaries = secondaries;

    const wrist = new THREE.Group();
    wrist.name = 'wristJoint';
    wrist.position.set(wristPoint.x, wristPoint.y, wristPoint.z);
    wrist.rotation.z = side * 0.08;
    elbow.add(wrist);
    wrist.add(primaries);
    wing.userData.parts.wrist = wrist;
    makeEllipsoid(elbow, jointMaterial, 'wristKnuckle', {
      x: wristPoint.x,
      y: wristPoint.y,
      z: wristPoint.z,
      sx: 0.66,
      sy: 0.44,
      sz: 0.46
    });
    addBoneBetween(wrist, { x: 0, y: 0, z: 0 }, { x: -5.2, y: side * 2.5, z: -0.16 }, 0.18, boneMaterial, 'metacarpalHand');

    const primaryCount = species.behavior === 'soar' ? 9 : 7;
    const longWing = species.id === 'red-tailed-hawk' ? 1.28 : species.id === 'barn-swallow' ? 1.18 : 1;
    for (let index = 0; index < primaryCount; index += 1) {
      const length = (12.8 - index * 0.52) * longWing;
      const featherRz = side * (0.10 + index * 0.070);
      const feather = addMesh(
        primaries,
        makeFeatherGeometry(length, 2.45, 0.40, 0.34, 0.24),
        index % 2 === 0 ? wingMaterial : covertMaterial,
        {
          name: 'primaryFeather',
          x: -0.9 - index * 1.35,
          y: side * (1.15 + index * 1.36),
          z: 0.02 - index * 0.018,
          rz: featherRz,
          ry: side * 0.035
        }
      );
      feather.userData.baseRz = feather.rotation.z;
      addMesh(
        primaries,
        new THREE.CylinderGeometry(0.075, 0.045, length * 0.76, 6),
        shaftMaterial,
        {
          name: 'primaryFeatherShaft',
          x: -0.9 - index * 1.35 - length * 0.38,
          y: side * (1.15 + index * 1.36),
          z: 0.22 - index * 0.012,
          rz: Math.PI / 2 + featherRz
        }
      );
    }

    for (let index = 0; index < 7; index += 1) {
      const featherRz = side * (0.04 + index * 0.036);
      const length = 8.7 - index * 0.36;
      const feather = addMesh(
        secondaries,
        makeFeatherGeometry(length, 2.30, 0.52, 0.28, 0.20),
        index % 2 === 0 ? covertMaterial : wingMaterial,
        {
          name: 'secondaryFeather',
          x: -1.0 - index * 0.90,
          y: side * (0.55 + index * 0.58),
          z: 0.38 - index * 0.012,
          rz: featherRz
        }
      );
      feather.userData.baseRz = feather.rotation.z;
      addMesh(
        secondaries,
        new THREE.CylinderGeometry(0.065, 0.04, length * 0.70, 6),
        shaftMaterial,
        {
          name: 'secondaryFeatherShaft',
          x: -1.0 - index * 0.90 - length * 0.34,
          y: side * (0.55 + index * 0.58),
          z: 0.66,
          rz: Math.PI / 2 + featherRz
        }
      );
    }

    const alula = new THREE.Group();
    alula.name = 'alulaFeathers';
    alula.position.set(-0.7, side * 0.15, 0.34);
    wrist.add(alula);
    wing.userData.parts.alula = alula;
    for (let index = 0; index < 3; index += 1) {
      addMesh(alula, makeFeatherGeometry(5.0 - index * 0.34, 1.35, 0.36, 0.20, 0.16), covertMaterial, {
        name: 'alulaFeather',
        x: -0.3 - index * 0.45,
        y: side * (0.15 + index * 0.28),
        z: 0.18 + index * 0.03,
        rz: side * (0.42 + index * 0.05)
      });
    }

    return wing;
  }

  function makeHeroProfileWing(species) {
    const wing = new THREE.Group();
    wing.name = 'heroProfileNearWing';
    wing.position.set(3.8, -2.7, 3.7);
    wing.rotation.z = -0.58;
    wing.rotation.x = -0.18;
    wing.userData.parts = {};

    const wingMaterial = makeMaterial(species.wing, { roughness: 0.62, colorLift: 0.02, minimumLift: 0.08 });
    const covertMaterial = makeMaterial(species.id === 'american-robin' ? '#51483d' : species.accent, {
      transparent: true,
      opacity: 0.88,
      roughness: 0.56,
      colorLift: species.id === 'american-robin' ? 0.02 : 0.08,
      minimumLift: 0.08
    });
    const shaftMaterial = makeMaterial('#ecd4a7', {
      transparent: true,
      opacity: 0.24,
      roughness: 0.50,
      colorLift: 0.04
    });
    const jointMaterial = makeMaterial(species.body, { roughness: 0.68, colorLift: 0.04, minimumLift: 0.09 });

    makeEllipsoid(wing, jointMaterial, 'profileShoulderSocket', {
      x: 0,
      y: 0,
      z: 0,
      sx: 1.28,
      sy: 0.78,
      sz: 0.58
    });

    const humerus = new THREE.Group();
    humerus.name = 'profileHumerusJoint';
    wing.add(humerus);
    wing.userData.parts.humerus = humerus;
    addBoneBetween(humerus, { x: 0, y: 0, z: 0 }, { x: -3.8, y: -4.2, z: 0.18 }, 0.24, jointMaterial, 'profileHumerusBone');
    addMesh(humerus, makeWingPanelGeometry([
      [0.0, 0.0, 0.16],
      [-2.0, -3.5, 0.34],
      [-4.4, -6.0, 0.10],
      [-4.8, -2.8, -0.18],
      [-1.4, -0.8, -0.16]
    ], 0.24, 0.08), covertMaterial, {
      name: 'profileScapularCoverts',
      z: 0.08
    });

    const elbow = new THREE.Group();
    elbow.name = 'profileElbowJoint';
    elbow.position.set(-3.8, -4.2, 0.18);
    humerus.add(elbow);
    wing.userData.parts.elbow = elbow;
    addBoneBetween(elbow, { x: 0, y: 0, z: 0 }, { x: -5.9, y: -5.7, z: -0.05 }, 0.18, jointMaterial, 'profileRadiusUlna');

    const wrist = new THREE.Group();
    wrist.name = 'profileWristJoint';
    wrist.position.set(-5.9, -5.7, -0.05);
    elbow.add(wrist);
    wing.userData.parts.wrist = wrist;

    const secondaries = new THREE.Group();
    secondaries.name = 'profileSecondaryFeatherFan';
    elbow.add(secondaries);
    wing.userData.parts.secondaries = secondaries;
    for (let index = 0; index < 6; index += 1) {
      const length = 8.4 - index * 0.28;
      const feather = addMesh(secondaries, makeFeatherGeometry(length, 2.1, 0.44, 0.28, 0.20), index % 2 ? covertMaterial : wingMaterial, {
        name: 'profileSecondaryFeather',
        x: -0.5 - index * 0.95,
        y: -0.7 - index * 1.05,
        z: 0.16 - index * 0.018,
        rz: -0.58 - index * 0.025
      });
      feather.userData.baseRz = feather.rotation.z;
    }

    const primaries = new THREE.Group();
    primaries.name = 'profilePrimaryFeatherFan';
    wrist.add(primaries);
    wing.userData.parts.primaries = primaries;
    for (let index = 0; index < 8; index += 1) {
      const length = 10.8 - index * 0.38;
      const rz = -0.84 - index * 0.035;
      const feather = addMesh(primaries, makeFeatherGeometry(length, 2.2, 0.34, 0.34, 0.22), index % 2 ? covertMaterial : wingMaterial, {
        name: 'profilePrimaryFeather',
        x: -0.2 - index * 1.0,
        y: -0.5 - index * 1.26,
        z: -0.03 - index * 0.02,
        rz
      });
      feather.userData.baseRz = feather.rotation.z;
      addMesh(primaries, new THREE.CylinderGeometry(0.055, 0.035, length * 0.70, 6), shaftMaterial, {
        name: 'profilePrimaryFeatherShaft',
        x: -0.2 - index * 1.0 - length * 0.34,
        y: -0.5 - index * 1.26,
        z: 0.16 - index * 0.018,
        rz: Math.PI / 2 + rz
      });
    }

    return wing;
  }

  function makeTail(species) {
    const tail = new THREE.Group();
    tail.name = 'tailFan';
    tail.position.set(-13.2, 0, -0.18);
    tail.userData.parts = [];
    const material = makeMaterial(species.wing, { roughness: 0.68, colorLift: 0.06, minimumLift: 0.13 });
    const accent = makeMaterial(species.accent, { transparent: true, opacity: 0.80, colorLift: 0.08, minimumLift: 0.12 });
    const shaft = makeMaterial('#f0d2a0', { transparent: true, opacity: 0.34, roughness: 0.52 });
    const featherCount = species.id === 'barn-swallow' ? 4 : 4;
    for (let index = 0; index < featherCount; index += 1) {
      const centered = index - (featherCount - 1) / 2;
      const swallowFork = species.id === 'barn-swallow' && Math.abs(centered) > 1 ? 1.7 : 1;
      const length = (6.4 + Math.abs(centered) * 0.42) * swallowFork;
      const feather = addMesh(
        tail,
        makeFeatherGeometry(length, 1.68, 0.38, 0.18, 0.18),
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
      addMesh(tail, new THREE.CylinderGeometry(0.065, 0.04, length * 0.72, 6), shaft, {
        name: 'tailFeatherShaft',
        x: -length * 0.34,
        y: centered * 1.35,
        z: 0.18 - Math.abs(centered) * 0.04,
        rz: Math.PI / 2 + centered * 0.12
      });
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

  function addContourFeatherRows(root, species, materials) {
    const darkBird = species.body === '#16191d';
    const rows = [
      { name: 'backContourFeather', z: 2.55, y: -1.35, material: materials.highlight, count: 7, width: 1.55, height: 0.34 },
      { name: 'flankContourFeather', z: 0.92, y: 3.32, material: materials.shadow, count: 6, width: 1.36, height: 0.30 },
      { name: 'breastContourFeather', z: -0.95, y: 0.0, material: materials.breast, count: 6, width: 1.44, height: 0.36 }
    ];
    for (const row of rows) {
      for (let index = 0; index < row.count; index += 1) {
        const t = row.count === 1 ? 0 : index / (row.count - 1);
        const x = 7.2 - t * 14.0;
        const yWave = Math.sin(t * Math.PI) * (row.name === 'breastContourFeather' ? 0.24 : 0.52);
        makeEllipsoid(root, row.material, row.name, {
          x,
          y: row.y + (row.y < 0 ? -yWave : yWave),
          z: row.z - Math.abs(t - 0.5) * 0.32,
          sx: row.width * (0.78 + Math.sin(t * Math.PI) * 0.36),
          sy: 0.30 + row.height,
          sz: darkBird ? 0.18 : 0.22,
          rz: (t - 0.5) * -0.22
        });
      }
    }
  }

  function makeBird(species) {
    const root = new THREE.Group();
    root.userData.species = species;
    root.userData.parts = {};

    const darkBird = species.body === '#16191d' || species.body === '#263f6e' || species.body === '#3f3026';
    const bodyLift = darkBird ? 0.14 : 0.035;
    const bodyMaterial = makeMaterial(species.body, {
      roughness: 0.60,
      colorLift: bodyLift,
      minimumLift: darkBird ? 0.17 : 0.07,
      emissiveIntensity: darkBird ? 0.055 : 0.035
    });
    const breastMaterial = makeMaterial(species.breast, {
      transparent: true,
      opacity: 0.98,
      roughness: 0.58,
      colorLift: 0.045,
      minimumLift: 0.10
    });
    const throatMaterial = makeMaterial(species.accent, {
      transparent: true,
      opacity: species.id === 'ruby-throated-hummingbird' ? 0.98 : 0.80,
      colorLift: darkBird ? 0.12 : 0.04,
      minimumLift: 0.11
    });
    const contourMaterial = makeMaterial('#fff6dc', {
      transparent: true,
      opacity: darkBird ? 0.18 : 0.11,
      roughness: 0.40,
      colorLift: 0.04,
      emissiveIntensity: 0.12,
      depthWrite: false
    });
    const shadowContourMaterial = makeMaterial('#2b2118', {
      transparent: true,
      opacity: 0.20,
      roughness: 0.74,
      minimumLift: 0.12,
      depthWrite: false
    });
    const beakMaterial = makeMaterial(species.beak, { roughness: 0.42, colorLift: 0.08, minimumLift: 0.16 });
    const eyeMaterial = makeMaterial('#101014', { roughness: 0.22 });
    const catchlightMaterial = makeMaterial('#ffffff', { roughness: 0.08, emissiveIntensity: 0.20 });
    const legMaterial = makeMaterial(species.beak === '#151515' ? '#393436' : '#806746', {
      roughness: 0.54,
      colorLift: 0.08,
      minimumLift: 0.14
    });

    const body = addMesh(root, new THREE.SphereGeometry(1, 32, 18), bodyMaterial, {
      name: 'streamlinedBody',
      x: -1.8,
      z: 0.02,
      sx: 14.8,
      sy: 5.8,
      sz: 4.6
    });
    root.userData.parts.body = body;
    addMesh(root, new THREE.SphereGeometry(1, 24, 14), contourMaterial, {
      name: 'volumetricBackHighlight',
      x: -2.7,
      y: -1.4,
      z: 2.35,
      sx: 10.8,
      sy: 1.65,
      sz: 0.72,
      rz: -0.08
    });
    addMesh(root, new THREE.SphereGeometry(1, 20, 12), shadowContourMaterial, {
      name: 'roundedBellyShadow',
      x: -1.3,
      y: 1.65,
      z: -2.0,
      sx: 10.4,
      sy: 1.55,
      sz: 0.64,
      rz: 0.06
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
    addMesh(root, new THREE.CylinderGeometry(0.20, 0.34, 8.4, 12), shadowContourMaterial, {
      name: 'keelRidge',
      x: 1.6,
      y: 0,
      z: -3.05,
      rz: Math.PI / 2,
      sx: 1,
      sy: 1,
      sz: 1
    });
    for (const side of [-1, 1]) {
      makeEllipsoid(root, breastMaterial, 'pectoralFlightMuscle', {
        x: 2.6,
        y: side * 1.88,
        z: -1.78,
        sx: 5.3,
        sy: 1.35,
        sz: 1.25,
        rz: side * 0.10
      });
      makeEllipsoid(root, breastMaterial, 'sideBreastPatch', {
        x: 4.2,
        y: side * 2.82,
        z: 0.88,
        sx: 5.4,
        sy: 1.05,
        sz: 1.35,
        rz: side * -0.06
      });
    }
    addMesh(root, new THREE.SphereGeometry(1, 18, 10), contourMaterial, {
      name: 'breastFeatherSheen',
      x: 4.0,
      y: -0.9,
      z: -0.45,
      sx: 4.8,
      sy: 1.1,
      sz: 0.38,
      rz: -0.10
    });
    makeEllipsoid(root, bodyMaterial, 'rump', {
      x: -11.4,
      y: 0,
      z: -0.05,
      sx: 4.0,
      sy: 4.2,
      sz: 2.8
    });
    addMesh(root, new THREE.SphereGeometry(1, 16, 10), contourMaterial, {
      name: 'undertailCoverts',
      x: -12.9,
      y: 0,
      z: -1.75,
      sx: 2.4,
      sy: 2.8,
      sz: 0.75
    });
    const neck = addMesh(root, new THREE.SphereGeometry(1, 18, 12), bodyMaterial, {
      name: 'neck',
      x: 8.8,
      z: 0.65,
      sx: 3.8,
      sy: 3.2,
      sz: 2.8
    });
    root.userData.parts.neck = neck;
    const head = addMesh(root, new THREE.SphereGeometry(1, 28, 16), bodyMaterial, {
      name: 'head',
      x: 13.2,
      z: 0.85,
      sx: 5.4,
      sy: 4.2,
      sz: 3.9
    });
    root.userData.parts.head = head;
    addMesh(root, new THREE.SphereGeometry(1, 16, 10), contourMaterial, {
      name: 'headCrownHighlight',
      x: 13.4,
      y: -0.82,
      z: 3.0,
      sx: 2.9,
      sy: 0.82,
      sz: 0.50,
      rz: -0.18
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
    addMesh(root, new THREE.SphereGeometry(1, 20, 10), contourMaterial, {
      name: 'tailCovertsHighlight',
      x: -10.8,
      y: -0.75,
      z: 1.15,
      sx: 3.6,
      sy: 1.0,
      sz: 0.42,
      rz: -0.08
    });
    addContourFeatherRows(root, species, {
      highlight: contourMaterial,
      shadow: shadowContourMaterial,
      breast: breastMaterial
    });
    makeEllipsoid(root, breastMaterial, 'profileBreastBadge', {
      x: 4.8,
      y: -2.55,
      z: 3.05,
      sx: 4.6,
      sy: 0.92,
      sz: 0.46,
      rz: -0.08
    });

    const leftWing = makeWing(species, -1);
    const rightWing = makeWing(species, 1);
    const heroProfileWing = makeHeroProfileWing(species);
    const tail = makeTail(species);
    root.add(leftWing, rightWing, heroProfileWing, tail);
    root.userData.parts.leftWing = leftWing;
    root.userData.parts.rightWing = rightWing;
    root.userData.parts.heroProfileWing = heroProfileWing;
    root.userData.parts.heroProfileHumerus = heroProfileWing.userData.parts.humerus;
    root.userData.parts.heroProfileElbow = heroProfileWing.userData.parts.elbow;
    root.userData.parts.heroProfileWrist = heroProfileWing.userData.parts.wrist;
    root.userData.parts.heroProfilePrimaries = heroProfileWing.userData.parts.primaries;
    root.userData.parts.heroProfileSecondaries = heroProfileWing.userData.parts.secondaries;
    root.userData.parts.leftHumerus = leftWing.userData.parts.humerus;
    root.userData.parts.rightHumerus = rightWing.userData.parts.humerus;
    root.userData.parts.leftElbow = leftWing.userData.parts.elbow;
    root.userData.parts.rightElbow = rightWing.userData.parts.elbow;
    root.userData.parts.leftWrist = leftWing.userData.parts.wrist;
    root.userData.parts.rightWrist = rightWing.userData.parts.wrist;
    root.userData.parts.leftPrimaries = leftWing.userData.parts.primaries;
    root.userData.parts.rightPrimaries = rightWing.userData.parts.primaries;
    root.userData.parts.leftSecondaries = leftWing.userData.parts.secondaries;
    root.userData.parts.rightSecondaries = rightWing.userData.parts.secondaries;
    root.userData.parts.leftAlula = leftWing.userData.parts.alula;
    root.userData.parts.rightAlula = rightWing.userData.parts.alula;
    root.userData.parts.leftWingBlur = leftWing.userData.parts.blur;
    root.userData.parts.rightWingBlur = rightWing.userData.parts.blur;
    root.userData.parts.leftWingSheen = leftWing.userData.parts.dorsalSheen;
    root.userData.parts.rightWingSheen = rightWing.userData.parts.dorsalSheen;
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
    const brightness = 0.38 + state.lightLevel * 0.62;
    const warmth = state.lightMood === 'golden-hour' ? 1.08 : 1.0;
    for (const group of state.groups) {
      group.traverse((child) => {
        if (!child.material || !child.material.userData.baseColor) {
          return;
        }
        const base = child.material.userData.baseColor;
        const minimumLift = child.material.userData.minimumLift ?? 0.10;
        const fillAmount = minimumLift * 0.62 + (1 - state.lightLevel) * 0.10;
        child.material.color.copy(base)
          .multiplyScalar(brightness * warmth)
          .lerp(state.lightMood === 'golden-hour' ? warmFillColor : coolFillColor, fillAmount);
        child.material.opacity = Math.min(
          child.material.userData.baseOpacity ?? 1,
          0.70 + state.lightLevel * 0.30
        );
        child.material.emissiveIntensity = (child.material.userData.baseEmissiveIntensity ?? 0.04)
          * (0.85 + (1 - state.lightLevel) * 1.8);
        child.material.needsUpdate = true;
      });
    }
    const hasSoaringBird = state.birds.some((bird) => {
      const species = speciesCatalog[bird.speciesIndex % speciesCatalog.length];
      return species.behavior === 'soar';
    });
    ambientLight.intensity = 0.44 + state.lightLevel * 0.42;
    skyLight.intensity = 0.38 + state.lightLevel * 0.40;
    cameraFillLight.intensity = 0.30 + (1 - state.lightLevel) * 0.28;
    rimLight.intensity = 0.26 + state.lightLevel * 0.30 + (hasSoaringBird ? 0.06 : 0);
    sunLight.intensity = 0.30 + state.lightLevel * 0.70 + (hasSoaringBird ? 0.07 : 0);
  }

  function applyArticulatedWingPose(parts, species, flap, bank, speed, planFocus, liftPose) {
    const glideFold = species.behavior === 'soar' || species.behavior === 'glide'
      ? 0.36
      : 1.0;
    const downstroke = Math.max(0, -flap);
    const upstroke = Math.max(0, flap);
    const wingTravel = species.behavior === 'soar'
      ? 0.12 + (liftPose < -0.18 ? 0.08 : 0)
      : species.behavior === 'hover'
        ? 0.98
        : 0.36 + Math.min(0.32, speed / 210) + planFocus * 0.05;
    const shoulderBeat = flap * wingTravel * glideFold;
    const elbowFold = upstroke * 0.62 - downstroke * 0.18;
    const wristPronation = downstroke * 0.30 - upstroke * 0.22;
    const primaryLag = -flap * 0.14 + downstroke * 0.16 - upstroke * 0.08;
    const secondaryLift = -downstroke * 0.08 + upstroke * 0.06;

    parts.leftWing.rotation.z = -0.24 - bank * 0.09;
    parts.rightWing.rotation.z = 0.24 - bank * 0.09;
    parts.leftWing.rotation.x = shoulderBeat * 0.28 - bank * 0.12;
    parts.rightWing.rotation.x = -shoulderBeat * 0.28 - bank * 0.12;
    parts.leftWing.rotation.y = -0.06 + downstroke * 0.07;
    parts.rightWing.rotation.y = 0.06 - downstroke * 0.07;

    parts.leftHumerus.rotation.z = -0.28 - shoulderBeat * 0.34 - bank * 0.035;
    parts.rightHumerus.rotation.z = 0.28 + shoulderBeat * 0.34 - bank * 0.035;
    parts.leftHumerus.rotation.x = -0.12 - shoulderBeat * 0.62;
    parts.rightHumerus.rotation.x = 0.12 + shoulderBeat * 0.62;

    parts.leftElbow.rotation.z = -0.16 - elbowFold * 0.52 - bank * 0.025;
    parts.rightElbow.rotation.z = 0.16 + elbowFold * 0.52 - bank * 0.025;
    parts.leftElbow.rotation.x = -0.04 - downstroke * 0.18 + upstroke * 0.12;
    parts.rightElbow.rotation.x = 0.04 + downstroke * 0.18 - upstroke * 0.12;

    parts.leftWrist.rotation.z = -0.10 - wristPronation * 0.62 - bank * 0.035;
    parts.rightWrist.rotation.z = 0.10 + wristPronation * 0.62 - bank * 0.035;
    parts.leftWrist.rotation.y = -0.04 + downstroke * 0.18 - upstroke * 0.10;
    parts.rightWrist.rotation.y = 0.04 - downstroke * 0.18 + upstroke * 0.10;

    parts.leftPrimaries.rotation.z = -primaryLag - bank * 0.05;
    parts.rightPrimaries.rotation.z = primaryLag - bank * 0.05;
    parts.leftPrimaries.rotation.y = -0.04 + downstroke * 0.08;
    parts.rightPrimaries.rotation.y = 0.04 - downstroke * 0.08;
    parts.leftSecondaries.rotation.z = secondaryLift - bank * 0.03;
    parts.rightSecondaries.rotation.z = -secondaryLift - bank * 0.03;
    parts.leftAlula.rotation.z = -0.10 - upstroke * 0.22 + planFocus * 0.10;
    parts.rightAlula.rotation.z = 0.10 + upstroke * 0.22 - planFocus * 0.10;

    const blurOpacity = species.flapHz > 10
      ? 0.16 + Math.min(0.28, species.flapHz / 180)
      : Math.max(0, (Math.abs(flap) - 0.52) * 0.18);
    parts.leftWingBlur.material.opacity = blurOpacity;
    parts.rightWingBlur.material.opacity = blurOpacity;
    parts.leftWingBlur.material.needsUpdate = true;
    parts.rightWingBlur.material.needsUpdate = true;
    parts.leftWingBlur.scale.setScalar(1 + downstroke * 0.10);
    parts.rightWingBlur.scale.setScalar(1 + downstroke * 0.10);
    if (parts.leftWingSheen?.material && parts.rightWingSheen?.material) {
      const sheenOpacity = 0.10 + downstroke * 0.12 + Math.abs(bank) * 0.08;
      parts.leftWingSheen.material.opacity = sheenOpacity;
      parts.rightWingSheen.material.opacity = sheenOpacity;
      parts.leftWingSheen.material.needsUpdate = true;
      parts.rightWingSheen.material.needsUpdate = true;
    }
  }

  function updateBirdVisual(bird, group, dt) {
    const species = speciesCatalog[bird.speciesIndex % speciesCatalog.length];
    const velocityAngle = Math.atan2(bird.vy, bird.vx);
    const speed = bird.airspeed || Math.hypot(bird.vx, bird.vy);
    const flap = Math.sin(bird.wingPhase);
    const turnPose = math.clamp((bird.pathCurvature || 0) / Math.max(0.1, species.turnRate), -1, 1);
    const bank = (bird.bank || 0) * 0.76 + turnPose * species.maxBank * 0.18;
    const heroScale = bird.isHeroBird ? 3.1 : 1.0;
    const depthScale = species.size * heroScale * (0.42 + bird.depth * 0.52);
    const hoverWobble = species.behavior === 'hover'
      ? Math.sin(bird.age * 15 + bird.behaviorPhase) * 2.4
      : 0;
    const liftPose = math.clamp((bird.sinkRate || 0) / 28, -1, 1);
    const planFocus = bird.intent === 'edge-avoidance' || bird.intent === 'containment' ? 1 : 0;

    group.position.set(bird.x, bird.y + hoverWobble, bird.depth * 40);
    group.rotation.z = velocityAngle;
    group.rotation.x = (bird.isHeroBird ? -0.62 : -0.20) - bank * 0.20 + liftPose * 0.10;
    group.rotation.y = (bird.isHeroBird ? -0.24 : 0) + bank * 0.34 + Math.sin(bird.age * 0.9 + bird.behaviorPhase) * 0.04;
    group.scale.setScalar(depthScale);

    const parts = group.userData.parts;
    applyArticulatedWingPose(parts, species, flap, bank, speed, planFocus, liftPose);
    if (parts.heroProfileWing) {
      parts.heroProfileWing.visible = Boolean(bird.isHeroBird);
      if (bird.isHeroBird) {
        const downstroke = Math.max(0, -flap);
        const upstroke = Math.max(0, flap);
        parts.heroProfileWing.rotation.z = -0.62 - flap * 0.22 - bank * 0.08;
        parts.heroProfileHumerus.rotation.z = -0.06 - flap * 0.20;
        parts.heroProfileElbow.rotation.z = -0.04 - upstroke * 0.20 + downstroke * 0.08;
        parts.heroProfileWrist.rotation.z = -0.08 - downstroke * 0.22 + upstroke * 0.12;
        parts.heroProfilePrimaries.rotation.z = downstroke * 0.16 - upstroke * 0.08;
        parts.heroProfileSecondaries.rotation.z = -downstroke * 0.08 + upstroke * 0.05;
      }
    }
    if (parts.head && parts.neck) {
      const headTurn = math.clamp(
        math.signedAngleDelta(velocityAngle, bird.targetHeading || velocityAngle),
        -0.45,
        0.45
      );
      parts.neck.rotation.z = headTurn * 0.10;
      parts.head.rotation.z = headTurn * 0.18;
      parts.head.rotation.y = -bank * 0.12;
    }
    parts.tail.rotation.z = Math.sin(bird.age * 1.4 + bird.behaviorPhase) * 0.08 + bank * 0.22;
    parts.tail.rotation.y = -Math.sin(velocityAngle) * 0.10 + turnPose * 0.08;
    parts.tail.rotation.x = math.clamp((bird.sinkRate || 0) * -0.014, -0.15, 0.16);
  }

  function captureCanvasPixelStats() {
    const gl = renderer.getContext();
    const width = gl.drawingBufferWidth;
    const height = gl.drawingBufferHeight;
    const pixels = new Uint8Array(width * height * 4);
    gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
    let alphaPixels = 0;
    let lumaTotal = 0;
    let darkPixels = 0;
    const buckets = new Set();
    for (let index = 0; index < pixels.length; index += 4) {
      const alpha = pixels[index + 3];
      if (alpha <= 8) {
        continue;
      }
      const red = pixels[index];
      const green = pixels[index + 1];
      const blue = pixels[index + 2];
      const luma = red * 0.2126 + green * 0.7152 + blue * 0.0722;
      alphaPixels += 1;
      lumaTotal += luma;
      if (luma < 28) {
        darkPixels += 1;
      }
      buckets.add(`${Math.floor(red / 18)}:${Math.floor(green / 18)}:${Math.floor(blue / 18)}:${Math.floor(alpha / 32)}`);
    }
    return {
      width,
      height,
      alphaPixels,
      averageLuma: alphaPixels ? lumaTotal / alphaPixels : 0,
      darkRatio: alphaPixels ? darkPixels / alphaPixels : 1,
      bucketCount: buckets.size
    };
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
    if (state.pixelStatsRequestId !== state.pixelStatsCompletedId) {
      state.lastPixelStats = captureCanvasPixelStats();
      state.pixelStatsCompletedId = state.pixelStatsRequestId;
    }
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
        renderer: 'three-js-volumetric-intelligent-bird-flock',
        speciesCount: speciesCatalog.length,
        birdCount: state.birds.length,
        birdCountMultiplier: state.birdCountMultiplier,
        zoneCount: state.zones.length,
        lightLevel: state.lightLevel,
        windStrength: state.windStrength,
        lightingSignature: state.lightingSignature,
        pixelStats: state.lastPixelStats,
        pixelStatsCompletedId: state.pixelStatsCompletedId
      };
    },
    requestPixelStats() {
      state.pixelStatsRequestId += 1;
      return state.pixelStatsRequestId;
    }
  };

  window.requestAnimationFrame(animate);
}());
