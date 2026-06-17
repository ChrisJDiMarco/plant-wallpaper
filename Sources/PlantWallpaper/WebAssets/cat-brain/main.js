(() => {
  function showFallback(message) {
    document.documentElement.dataset.brainReady = 'fallback';
    const fallback = document.getElementById('brainFallback');
    if (fallback) {
      fallback.hidden = false;
      fallback.querySelector('[data-message]').textContent = message || 'Neural map unavailable';
    }
  }

  try {
  const canvas = document.getElementById('brainCanvas');
  const stage = document.getElementById('stage');
  const halo = document.getElementById('halo');

  if (!window.THREE) {
    showFallback('Neural renderer unavailable');
    return;
  }

  const settings = {
    activity: 0.5,
    curiosity: 0.5,
    playfulness: 0.6,
    mouseReactions: true,
    furLength: 1.0,
    chubbiness: 1.0,
    stripeAmount: 1.0
  };

  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const renderer = new THREE.WebGLRenderer({
    canvas,
    alpha: true,
    antialias: true,
    powerPreference: 'high-performance'
  });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.setClearColor(0x000000, 0);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(38, 1, 0.1, 100);
  camera.position.set(0, 0.02, 6.8);

  const key = new THREE.PointLight(0xffffff, 3.0, 9);
  key.position.set(2.6, 2.5, 4.2);
  scene.add(key);

  const rim = new THREE.PointLight(0x7a68ff, 3.5, 8);
  rim.position.set(-2.4, 1.3, 3.4);
  scene.add(rim);

  scene.add(new THREE.AmbientLight(0x93b4ff, 0.85));

  const brain = new THREE.Group();
  brain.position.set(0, 0.72, 0);
  brain.scale.set(0.66, 0.66, 0.66);
  scene.add(brain);

  const tissueMaterial = new THREE.MeshPhysicalMaterial({
    color: 0xf0b6c8,
    roughness: 0.42,
    metalness: 0.02,
    transmission: 0.18,
    transparent: true,
    opacity: 0.90,
    clearcoat: 0.2,
    emissive: 0x2b1024,
    emissiveIntensity: 0.16
  });

  const cortexMaterial = new THREE.MeshPhysicalMaterial({
    color: 0xffc1d1,
    roughness: 0.36,
    metalness: 0.0,
    transparent: true,
    opacity: 0.84,
    clearcoat: 0.35,
    emissive: 0x381932,
    emissiveIntensity: 0.20
  });

  const stemMaterial = new THREE.MeshStandardMaterial({
    color: 0xe2a0b2,
    roughness: 0.55,
    transparent: true,
    opacity: 0.78,
    emissive: 0x271322,
    emissiveIntensity: 0.13
  });

  function ellipsoid(width, height, depth, material, position, rotation = [0, 0, 0]) {
    const mesh = new THREE.Mesh(new THREE.SphereGeometry(1, 48, 32), material);
    mesh.scale.set(width, height, depth);
    mesh.position.set(...position);
    mesh.rotation.set(...rotation);
    brain.add(mesh);
    return mesh;
  }

  const lobes = [
    ellipsoid(1.10, 0.58, 0.78, tissueMaterial, [-0.54, 0.11, 0.03], [0.04, 0.10, -0.07]),
    ellipsoid(1.10, 0.58, 0.78, tissueMaterial, [0.54, 0.11, 0.03], [0.04, -0.10, 0.07]),
    ellipsoid(0.72, 0.45, 0.56, cortexMaterial, [-0.56, -0.23, -0.03], [-0.08, 0.10, -0.16]),
    ellipsoid(0.72, 0.45, 0.56, cortexMaterial, [0.56, -0.23, -0.03], [-0.08, -0.10, 0.16]),
    ellipsoid(0.46, 0.30, 0.34, tissueMaterial, [-0.26, -0.58, -0.18], [0.12, -0.18, 0.0]),
    ellipsoid(0.46, 0.30, 0.34, tissueMaterial, [0.26, -0.58, -0.18], [0.12, 0.18, 0.0])
  ];

  function makeBrainStem() {
    const group = new THREE.Group();
    const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.13, 0.18, 0.68, 28), stemMaterial);
    shaft.position.set(0, -0.02, 0);
    const top = new THREE.Mesh(new THREE.SphereGeometry(0.16, 28, 16), stemMaterial);
    top.position.set(0, 0.34, 0);
    top.scale.set(1.0, 0.72, 1.0);
    const base = new THREE.Mesh(new THREE.SphereGeometry(0.18, 28, 16), stemMaterial);
    base.position.set(0, -0.35, 0);
    base.scale.set(0.92, 0.72, 0.92);
    group.add(shaft, top, base);
    group.position.set(0, -0.92, -0.14);
    group.rotation.x = -0.06;
    brain.add(group);
    return group;
  }

  makeBrainStem();

  const gyri = [];
  const gyrusMaterial = new THREE.MeshStandardMaterial({
    color: 0xffd4de,
    roughness: 0.5,
    transparent: true,
    opacity: 0.55,
    emissive: 0x5a243d,
    emissiveIntensity: 0.18
  });

  for (let side of [-1, 1]) {
    for (let i = 0; i < 12; i += 1) {
      const angle = (i / 11) * Math.PI * 1.05 - Math.PI * 0.52;
      const curve = new THREE.CatmullRomCurve3([
        new THREE.Vector3(side * (0.20 + Math.cos(angle) * 0.20), 0.42 + Math.sin(angle) * 0.14, 0.62),
        new THREE.Vector3(side * (0.42 + Math.cos(angle + 0.4) * 0.35), 0.14 + Math.sin(angle + 0.25) * 0.28, 0.72),
        new THREE.Vector3(side * (0.58 + Math.cos(angle + 0.8) * 0.28), -0.18 + Math.sin(angle + 0.55) * 0.18, 0.54)
      ]);
      const tube = new THREE.Mesh(new THREE.TubeGeometry(curve, 24, 0.018, 8, false), gyrusMaterial);
      gyri.push(tube);
      brain.add(tube);
    }
  }

  const circuits = [];
  function makeCircuit(name, color, points, baseOpacity) {
    const curve = new THREE.CatmullRomCurve3(points.map((p) => new THREE.Vector3(...p)));
    const material = new THREE.MeshBasicMaterial({
      color,
      transparent: true,
      opacity: baseOpacity
    });
    const tube = new THREE.Mesh(new THREE.TubeGeometry(curve, 72, 0.025, 10, false), material);
    tube.userData = { name, baseOpacity, color };
    brain.add(tube);

    const pulseMaterial = new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.85 });
    const pulse = new THREE.Mesh(new THREE.SphereGeometry(0.055, 18, 12), pulseMaterial);
    pulse.userData = { curve, offset: Math.random() };
    brain.add(pulse);
    circuits.push({ name, tube, material, pulse, pulseMaterial, curve });
  }

  makeCircuit('activity', 0x49d88d, [
    [-0.82, 0.18, 0.82], [-0.20, 0.50, 0.92], [0.32, 0.35, 0.82], [0.80, 0.02, 0.56]
  ], 0.55);
  makeCircuit('curiosity', 0x51a8ff, [
    [-0.95, -0.15, 0.62], [-0.42, 0.12, 1.02], [0.0, 0.50, 1.10], [0.48, 0.12, 1.02], [0.95, -0.15, 0.62]
  ], 0.55);
  makeCircuit('playfulness', 0xffb34c, [
    [-0.52, -0.42, 0.72], [-0.05, -0.16, 1.12], [0.52, -0.42, 0.72], [0.24, -0.78, 0.42], [-0.24, -0.78, 0.42], [-0.52, -0.42, 0.72]
  ], 0.52);
  makeCircuit('mouse', 0xf067ff, [
    [-0.18, 0.66, 0.86], [0.0, 0.94, 0.96], [0.18, 0.66, 0.86], [0.0, 0.30, 1.14], [-0.18, 0.66, 0.86]
  ], 0.32);

  const synapses = [];
  const synapseMaterial = new THREE.MeshBasicMaterial({
    color: 0xffffff,
    transparent: true,
    opacity: 0.55
  });
  for (let i = 0; i < 36; i += 1) {
    const mesh = new THREE.Mesh(new THREE.SphereGeometry(0.018 + Math.random() * 0.018, 10, 8), synapseMaterial.clone());
    mesh.position.set(
      (Math.random() - 0.5) * 1.75,
      -0.42 + Math.random() * 1.1,
      0.58 + Math.random() * 0.42
    );
    mesh.userData = { speed: 0.4 + Math.random() * 0.9, phase: Math.random() * Math.PI * 2 };
    brain.add(mesh);
    synapses.push(mesh);
  }

  function resize() {
    const rect = stage.getBoundingClientRect();
    const width = Math.max(1, rect.width);
    const height = Math.max(1, rect.height);
    renderer.setSize(width, height, false);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
  }

  function configure(next) {
    Object.assign(settings, next || {});
    const activity = Number(settings.activity || 0);
    const curiosity = Number(settings.curiosity || 0);
    const playfulness = Number(settings.playfulness || 0);
    const mouse = settings.mouseReactions ? 1 : 0.12;
    const max = Math.max(activity, curiosity, playfulness, mouse * 0.45);
    halo.style.opacity = String(0.72 + max * 0.24);
    halo.style.transform = `translateY(${1 - curiosity * 2}%) scale(${0.98 + playfulness * 0.05})`;
    circuits.forEach((circuit) => {
      let level = 0.4;
      if (circuit.name === 'activity') level = activity;
      if (circuit.name === 'curiosity') level = curiosity;
      if (circuit.name === 'playfulness') level = playfulness;
      if (circuit.name === 'mouse') level = mouse;
      circuit.material.opacity = 0.18 + level * 0.76;
      circuit.pulseMaterial.opacity = 0.28 + level * 0.70;
      circuit.tube.scale.setScalar(0.96 + level * 0.12);
    });
    lobes.forEach((lobe) => {
      const chub = Number(settings.chubbiness || 1.0);
      lobe.scale.x *= 1;
      lobe.material.emissiveIntensity = 0.13 + curiosity * 0.11 + playfulness * 0.05;
      lobe.material.opacity = 0.78 + Math.min(0.16, (chub - 0.8) * 0.28);
    });
  }

  function animate(nowMs) {
    const t = nowMs * 0.001;
    const speed = prefersReducedMotion ? 0.03 : 0.13 + settings.activity * 0.06;
    brain.rotation.y = Math.sin(t * 0.25) * 0.12 + t * speed;
    brain.rotation.x = -0.06 + Math.sin(t * 0.37) * 0.035;
    brain.position.y = 0.70 + Math.sin(t * 0.8) * (prefersReducedMotion ? 0.004 : 0.025);

    circuits.forEach((circuit, index) => {
      const pulseSpeed = 0.10 + settings.playfulness * 0.24 + settings.activity * 0.18;
      const u = (t * pulseSpeed + circuit.pulse.userData.offset + index * 0.21) % 1;
      circuit.pulse.position.copy(circuit.curve.getPointAt(u));
      circuit.pulse.scale.setScalar(0.78 + Math.sin(t * 5.3 + index) * 0.16);
    });

    synapses.forEach((synapse, index) => {
      synapse.material.opacity = 0.24 + Math.max(settings.curiosity, settings.playfulness) * 0.42 + Math.sin(t * synapse.userData.speed * 3 + synapse.userData.phase) * 0.12;
      synapse.scale.setScalar(0.82 + Math.sin(t * 2.4 + index) * 0.20);
    });

    gyri.forEach((tube, index) => {
      tube.material.opacity = 0.40 + Math.sin(t * 1.7 + index * 0.45) * 0.08 + settings.curiosity * 0.08;
    });

    renderer.render(scene, camera);
    requestAnimationFrame(animate);
  }

  window.catBrainBridge = {
    configure,
    status() {
      return {
        ...settings,
        ready: document.documentElement.dataset.brainReady === 'true',
        circuits: circuits.map((c) => c.name)
      };
    }
  };

  resize();
  configure(settings);
  document.documentElement.dataset.brainReady = 'true';
  window.addEventListener('resize', resize);
  requestAnimationFrame(animate);
  } catch (error) {
    console.error('Cat brain visualizer failed', error);
    showFallback('Neural map restarted in compatibility mode');
  }
})();
