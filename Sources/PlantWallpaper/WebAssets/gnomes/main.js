/* ============================================================================
 * Gnome Village — v1 rigged/textured renderer (wallpaper overlay)
 * ----------------------------------------------------------------------------
 * Driven by the Swift bridge: window.gnomeBridge.configure({ zones, plants,
 * lightLevel, ... }). Each player-drawn zone (a normalized [0,1] polygon) is
 * mapped onto the XZ ground plane and grown into a procedural village —
 * cottages/roundhouses that build up from material piles, cobble plaza + roads,
 * and human-bodied gnomes (makeGnome/poseGnome) in textured gnome clothes
 * (materials.js) with extra detail (detail.js).
 *
 * Renders TRANSPARENT over the desktop: no sky, no opaque ground. A hidden
 * ShadowMaterial plane catches contact shadows so the village feels planted.
 * Modules loaded before this file: materials.js, gnome.js, pose.js,
 * buildsite.js, zone.js, detail.js (all global, r128-safe).
 * ==========================================================================*/
(() => {
  const canvas = document.getElementById('gnome-canvas');
  const visualVersion = 'gnome-village-v4-resource-city-growth';

  /* ---- tunables ---- */
  const HZ = 300;                 // ground half-depth (world units); HX scales with aspect
  const HOUSE_SCALE = 20;         // cottage size passed to buildZone
  const BUILD_SCALE = 1.7;        // makeBuildSite group scale
  const DEFAULT_CAM_ELEV = 42;    // gentler desktop-perspective view
  const DEFAULT_CAM_YAW = 0;
  const FOV = 46;
  const CAM_FIT = 1.16;           // distance fudge so the ground fits in frame
  const MAX_FIRE_LIGHTS = 4;      // cap real bonfire point-lights for perf
  const gnomeHatColors = [0xb8512f, 0x3f6b9c, 0x6a8f3a, 0xb08a2e, 0x824a8c, 0xb84a6a, 0x3f7d6b];
  const gnomeTunicColors = [0x2e6f4e, 0x6a4a86, 0x8a5a2a, 0x356b86, 0x7a3a3a, 0x4a5a86];

  const state = {
    width: window.innerWidth,
    height: window.innerHeight,
    lightLevel: 1,
    paused: false,
    lastTime: performance.now(),
    prevT: 0,
    perspective: { yawDegrees: DEFAULT_CAM_YAW, elevationDegrees: DEFAULT_CAM_ELEV },
    simulation: normalizedSimulation(null),
    dailyRoutine: normalizedDailyRoutine(null),
    zones: [],
    plants: [],
    villages: new Map(),
    tunnelLinks: new Map(),
    fireLightCount: 0
  };

  const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true, premultipliedAlpha: false });
  renderer.setClearColor(0x000000, 0);
  renderer.setPixelRatio(Math.min(1.75, window.devicePixelRatio || 1));
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.12;
  if ('outputEncoding' in renderer) renderer.outputEncoding = THREE.sRGBEncoding;

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(FOV, 1, 1, 6000);

  /* ---- lighting (dusk 3-point) — intensities scaled by circadian lightLevel ---- */
  const hemi = new THREE.HemisphereLight(0x9bb0ff, 0x241826, 0.32);
  scene.add(hemi);
  const moon = new THREE.DirectionalLight(0xffcaa0, 1.45);
  moon.castShadow = true;
  moon.shadow.mapSize.set(2048, 2048);
  moon.shadow.camera.near = 40;
  moon.shadow.bias = -0.0006;
  moon.shadow.radius = 4;
  scene.add(moon);
  const fill = new THREE.DirectionalLight(0x6f7dff, 0.5);
  scene.add(fill);
  const rim = new THREE.DirectionalLight(0xff9d57, 0.85);
  rim.position.set(120, 60, -260);
  scene.add(rim);
  const baseIntensity = { hemi: 0.32, moon: 1.45, fill: 0.5, rim: 0.85 };

  /* ---- invisible ground that only catches contact shadows ---- */
  const shadowCatcher = new THREE.Mesh(
    new THREE.PlaneGeometry(8000, 8000),
    new THREE.ShadowMaterial({ opacity: 0.3 })
  );
  shadowCatcher.rotation.x = -Math.PI / 2;
  shadowCatcher.receiveShadow = true;
  scene.add(shadowCatcher);

  /* ---- global fireflies ---- */
  const FF = 90;
  const ffGeo = new THREE.BufferGeometry();
  const ffPos = new Float32Array(FF * 3);
  const ffPhase = [];
  const ffTex = makeGlowTex();
  function seedFireflies() {
    const HX = HZ * (state.width / Math.max(1, state.height));
    for (let i = 0; i < FF; i++) {
      ffPos[i * 3] = (Math.random() - 0.5) * 2.2 * HX;
      ffPos[i * 3 + 1] = 8 + Math.random() * 90;
      ffPos[i * 3 + 2] = (Math.random() - 0.5) * 2.2 * HZ;
      ffPhase[i] = Math.random() * Math.PI * 2;
    }
    ffGeo.setAttribute('position', new THREE.BufferAttribute(ffPos, 3));
  }
  seedFireflies();
  const fireflies = new THREE.Points(ffGeo, new THREE.PointsMaterial({
    map: ffTex, color: 0xffe79a, size: 3.4, transparent: true,
    blending: THREE.AdditiveBlending, depthWrite: false, sizeAttenuation: true
  }));
  scene.add(fireflies);

  /* ---- helpers ---- */
  function clamp(value, min, max) { return Math.max(min, Math.min(max, value)); }
  function smoothstep(edge0, edge1, value) {
    if (edge1 <= edge0) return value >= edge1 ? 1 : 0;
    const t = clamp((value - edge0) / (edge1 - edge0), 0, 1);
    return t * t * (3 - 2 * t);
  }
  function finiteNumber(value, fallback) {
    const n = Number(value);
    return Number.isFinite(n) ? n : fallback;
  }
  function normalizedPerspective(input) {
    const source = input || {};
    return {
      yawDegrees: clamp(finiteNumber(source.yawDegrees, DEFAULT_CAM_YAW), -55, 55),
      elevationDegrees: clamp(finiteNumber(source.elevationDegrees, DEFAULT_CAM_ELEV), 24, 68)
    };
  }
  function normalizedSimulation(input) {
    const source = input || {};
    return {
      populationMultiplier: clamp(finiteNumber(source.populationMultiplier, 1), 0.25, 2.5),
      tribeScaleMultiplier: clamp(finiteNumber(source.tribeScaleMultiplier, 1), 0.45, 2.25),
      behaviorLiveliness: clamp(finiteNumber(source.behaviorLiveliness, 1), 0.25, 2.5),
      buildingSpeedMultiplier: clamp(finiteNumber(source.buildingSpeedMultiplier, 1), 0.10, 4.0),
      cooperationMultiplier: clamp(finiteNumber(source.cooperationMultiplier, 1), 0, 2.5),
      plantInteractionMultiplier: clamp(finiteNumber(source.plantInteractionMultiplier, 1), 0, 2.5),
      villageDetailMultiplier: clamp(finiteNumber(source.villageDetailMultiplier, 1), 0.50, 2.0),
      settlementExpansionDays: clamp(finiteNumber(source.settlementExpansionDays, 7), 0.25, 30)
    };
  }
  function normalizedDailyRoutine(input) {
    const source = input || {};
    return {
      phase: String(source.phase || 'midday'),
      localHour: clamp(finiteNumber(source.localHour, 12), 0, 23.99),
      homeLightIntensity: clamp(finiteNumber(source.homeLightIntensity, 0.08), 0, 1),
      lanternIntensity: clamp(finiteNumber(source.lanternIntensity, 0.04), 0, 1),
      bonfireIntensity: clamp(finiteNumber(source.bonfireIntensity, 0.12), 0, 1),
      fireflyIntensity: clamp(finiteNumber(source.fireflyIntensity, 0.04), 0, 1),
      smokeIntensity: clamp(finiteNumber(source.smokeIntensity, 0.28), 0, 1),
      sleepBias: clamp(finiteNumber(source.sleepBias, 0.12), 0, 1),
      buildBias: clamp(finiteNumber(source.buildBias, 0.55), 0, 1),
      socialBias: clamp(finiteNumber(source.socialBias, 0.42), 0, 1),
      forageBias: clamp(finiteNumber(source.forageBias, 0.42), 0, 1)
    };
  }
  function perspectiveSignature() {
    const p = normalizedPerspective(state.perspective);
    return [
      Number(p.yawDegrees || 0).toFixed(2),
      Number(p.elevationDegrees || DEFAULT_CAM_ELEV).toFixed(2)
    ];
  }
  function simulationGeometrySignature() {
    const s = normalizedSimulation(state.simulation);
    return [
      Number(s.populationMultiplier).toFixed(2),
      Number(s.tribeScaleMultiplier).toFixed(2),
      Number(s.plantInteractionMultiplier).toFixed(2),
      Number(s.villageDetailMultiplier).toFixed(2),
      Number(s.settlementExpansionDays).toFixed(2)
    ];
  }
  function halfX() { return HZ * (state.width / Math.max(1, state.height)); }
  function zonePolygon(zone) {
    const HX = halfX();
    const project = typeof GnomeProjection !== 'undefined' && GnomeProjection.groundPointFromNormalized
      ? (p) => GnomeProjection.groundPointFromNormalized(p, camera, HX, HZ)
      : (p) => ({ x: (p.x - 0.5) * 2 * HX, z: (p.y - 0.5) * 2 * HZ });
    const pts = (zone.points || []).map(project);
    return pts.length >= 3 ? pts : null;
  }

  function zoneSignature(zone) {
    const bounds = zone.bounds || {};
    const points = (zone.points || []).map(p => [
      Number(p.x || 0).toFixed(5),
      Number(p.y || 0).toFixed(5)
    ]);
    return JSON.stringify({
      id: zone.id,
      points,
      bounds: [
        Number(bounds.minX || 0).toFixed(5),
        Number(bounds.minY || 0).toFixed(5),
        Number(bounds.maxX || 0).toFixed(5),
        Number(bounds.maxY || 0).toFixed(5)
      ],
      width: state.width,
      height: state.height,
      perspective: perspectiveSignature(),
      simulation: simulationGeometrySignature(),
      settlementIndex: Math.max(0, Math.round(finiteNumber(zone.settlementIndex, 0))),
      settlementProgress: Number(clamp(finiteNumber(zone.settlementProgress, 1), 0, 1)).toFixed(2),
      isStartingZone: !!zone.isStartingZone,
      plants: plantInteractionSignature()
    });
  }

  function plantInteractionSignature() {
    if (!Array.isArray(state.plants) || state.simulation.plantInteractionMultiplier <= 0.001) return [];
    return state.plants
      .map(plant => [
        String(plant.id || plant.species || 'plant'),
        Number(finiteNumber(plant.x, 0.5)).toFixed(3),
        Number(finiteNumber(plant.y, 0.5)).toFixed(3),
        Number(finiteNumber(plant.resourceValue, 0.25)).toFixed(2),
        Number(finiteNumber(plant.canopyHeight, 0.1)).toFixed(2),
        !!plant.canClimb ? 1 : 0
      ])
      .sort((a, b) => String(a[0]).localeCompare(String(b[0])));
  }

  function plantPOIsForPolygon(poly) {
    if (!poly || !Array.isArray(state.plants) || state.simulation.plantInteractionMultiplier <= 0.001) return [];
    return state.plants
      .map(projectPlantPOI)
      .filter(plant => plant.resourceValue > 0.12 && pointInPolygon(plant.x, plant.z, poly))
      .sort((a, b) => b.resourceValue - a.resourceValue)
      .slice(0, Math.round(2 + state.simulation.plantInteractionMultiplier * 4));
  }

  function expeditionPOIsForPolygon(poly, zoneBounds) {
    if (!poly || !Array.isArray(state.plants) || state.simulation.plantInteractionMultiplier <= 0.001) return [];
    const center = typeof polygonCentroid === 'function' ? polygonCentroid(poly) : { x: 0, z: 0 };
    const bounds = zoneBounds || { w: 180, h: 180 };
    const maxDistance = Math.max(140, Math.min(halfX() * 1.65, HZ * 1.85, Math.max(bounds.w || 160, bounds.h || 160) * 3.2));
    return state.plants
      .map(projectPlantPOI)
      .map(plant => {
        const dx = plant.x - center.x;
        const dz = plant.z - center.z;
        const distance = Math.hypot(dx, dz);
        return {
          ...plant,
          kind: 'expeditionPlant',
          allowOutside: true,
          distance,
          sampleColor: sampleColorForPlant(plant),
          resourceValue: clamp(plant.resourceValue + (plant.canClimb ? 0.12 : 0) + plant.canopyHeight * 0.45, 0, 1)
        };
      })
      .filter(plant => !pointInPolygon(plant.x, plant.z, poly))
      .filter(plant => plant.distance <= maxDistance)
      .filter(plant => plant.resourceValue > 0.42 && (plant.canClimb || plant.canopyHeight > 0.15))
      .sort((a, b) => (b.resourceValue + b.canopyHeight) - (a.resourceValue + a.canopyHeight))
      .slice(0, Math.round(2 + state.simulation.plantInteractionMultiplier * 3));
  }

  function butterflyPOIsForPolygon(poly, zoneBounds, plantPOIs, expeditionPlants, seed) {
    if (!poly || state.simulation.plantInteractionMultiplier <= 0.001) return [];
    const nearPlants = (plantPOIs || []).concat(expeditionPlants || [])
      .filter(plant => plant && plant.resourceValue > 0.28)
      .sort((a, b) => (b.resourceValue + b.canopyHeight) - (a.resourceValue + a.canopyHeight));
    if (!nearPlants.length) return [];
    const center = typeof polygonCentroid === 'function' ? polygonCentroid(poly) : { x: 0, z: 0 };
    const bounds = zoneBounds || { w: 160, h: 160 };
    const count = Math.max(1, Math.min(4, Math.round(1 + state.simulation.plantInteractionMultiplier * 1.6)));
    const palette = [0xffc35f, 0xff92c6, 0x88d8ff, 0xe9c76f, 0x9ee58c, 0xcfa7ff];
    const targets = nearPlants.slice(0, 5).map(plant => ({
      id: plant.id,
      x: plant.x,
      z: plant.z,
      resourceValue: plant.resourceValue,
      canopyHeight: plant.canopyHeight,
      sampleColor: plant.sampleColor,
      species: plant.species
    }));
    return nearPlants.slice(0, count).map((plant, index) => {
      const phase = ((seed || 1) * 0.37 + index * 2.11) % (Math.PI * 2);
      const hoverRadius = Math.max(18, Math.min(72, Math.max(bounds.w || 160, bounds.h || 160) * (0.10 + index * 0.018)));
      const x = clamp(plant.x + Math.cos(phase) * hoverRadius, -halfX() + 20, halfX() - 20);
      const z = clamp(plant.z + Math.sin(phase) * hoverRadius * 0.58, -HZ + 20, HZ - 20);
      const height = 36 + clamp(finiteNumber(plant.canopyHeight, 0.14), 0.05, 0.5) * 150 + index * 7;
      return {
        id: `butterfly-${plant.id || index}`,
        x,
        z,
        kind: 'butterfly',
        allowOutside: true,
        resourceValue: clamp(0.45 + plant.resourceValue * 0.36, 0, 1),
        flightHeight: height,
        wingColor: palette[(Math.abs(seed || 1) + index) % palette.length],
        circuitRadius: 28 + plant.resourceValue * 38,
        plantTargets: targets
      };
    });
  }

  function projectPlantPOI(plant) {
    const HX = halfX();
    const project = typeof GnomeProjection !== 'undefined' && GnomeProjection.groundPointFromNormalized
      ? (p) => GnomeProjection.groundPointFromNormalized(p, camera, HX, HZ)
      : (p) => ({ x: (p.x - 0.5) * 2 * HX, z: (p.y - 0.5) * 2 * HZ });
    const p = project({ x: finiteNumber(plant.x, 0.5), y: finiteNumber(plant.y, 0.5) });
    return {
      id: String(plant.id || plant.species || 'plant'),
      x: p.x,
      z: p.z,
      kind: 'plant',
      resourceValue: clamp(finiteNumber(plant.resourceValue, 0.25), 0, 1),
      canClimb: !!plant.canClimb,
      canopyHeight: clamp(finiteNumber(plant.canopyHeight, 0.1), 0, 0.5),
      species: String(plant.species || ''),
      sampleColor: sampleColorForPlant(plant)
    };
  }

  function sampleColorForPlant(plant) {
    const kind = String(plant.kind || '').toLowerCase();
    const species = String(plant.species || '').toLowerCase();
    if (kind.includes('flower') || species.includes('orchid') || species.includes('cosmos')) return 0xff82c0;
    if (kind.includes('edible') || species.includes('tomato') || species.includes('pepper')) return 0xff9b42;
    if (kind.includes('tree') || species.includes('maple') || species.includes('blood')) return 0xa66b32;
    if (species.includes('fern') || species.includes('moss')) return 0x7bc45a;
    return 0x65b86f;
  }

  function makeGlowTexLocal() { return ffTex; }
  function glow(color, size, intensity) {
    const s = new THREE.Sprite(new THREE.SpriteMaterial({
      map: ffTex, color, transparent: true, blending: THREE.AdditiveBlending,
      depthWrite: false, opacity: intensity ?? 0.8
    }));
    s.material.userData.gnomeDisposableMaterial = true;
    s.scale.set(size, size, 1);
    return s;
  }
  function mat(c, o = {}) {
    const material = new THREE.MeshStandardMaterial({
      color: c, roughness: o.roughness ?? 0.85, metalness: o.metalness ?? 0,
      emissive: o.emissive ?? 0x000000, emissiveIntensity: o.emissiveIntensity ?? 0
    });
    if (o.transparent) {
      material.transparent = true;
      material.opacity = o.opacity ?? 1;
    }
    material.userData.gnomeDisposableMaterial = true;
    return material;
  }

  function makeBonfire(plaza) {
    const fire = new THREE.Group();
    for (let i = 0; i < 4; i++) {
      const log = new THREE.Mesh(new THREE.CylinderGeometry(1.4, 1.6, 14, 7),
        (typeof texturedMat === 'function') ? texturedMat(0x5a3f2d, 'wood') : mat(0x5a3f2d));
      log.position.y = 4; log.rotation.z = 0.5; log.rotation.y = i * 0.8; log.castShadow = true; fire.add(log);
    }
    const flame = new THREE.Mesh(new THREE.ConeGeometry(5, 16, 12), mat(0xff9a3c, { emissive: 0xff7a1e, emissiveIntensity: 1.1 }));
    flame.position.y = 12; fire.add(flame);
    const flameIn = new THREE.Mesh(new THREE.ConeGeometry(2.6, 10, 10), mat(0xffe06a, { emissive: 0xffd24d, emissiveIntensity: 1.2 }));
    flameIn.position.y = 11; fire.add(flameIn);
    const fireGlow = glow(0xff8a3c, 36, 0.5); fireGlow.position.y = 14; fire.add(fireGlow);
    fire.position.set(plaza.x, 0, plaza.z);
    let light = null;
    if (state.fireLightCount < MAX_FIRE_LIGHTS) {
      light = new THREE.PointLight(0xff7a30, 1.35, 300, 2.2);
      light.position.set(plaza.x, 20, plaza.z);
      scene.add(light);
      state.fireLightCount++;
    }
    return { group: fire, flame, fireGlow, light };
  }

  function createExpeditionKit() {
    const kit = new THREE.Group();
    kit.name = 'expeditionKit';
    const leather = mat(0x5a3823, { roughness: 0.72 });
    const rope = mat(0xc9b27a, { roughness: 0.86 });
    const metal = mat(0x8d9295, { roughness: 0.42, metalness: 0.55 });
    const sampleMat = mat(0x65b86f, { roughness: 0.58, emissive: 0x18340f, emissiveIntensity: 0.1 });
    const glassMat = mat(0xbdeaff, { roughness: 0.12, metalness: 0.02, transparent: true, opacity: 0.48, emissive: 0x315d61, emissiveIntensity: 0.08 });
    const moteMat = mat(0x95d97b, { roughness: 0.48, transparent: true, opacity: 0.74, emissive: 0x244d17, emissiveIntensity: 0.16 });

    const pack = new THREE.Mesh(new THREE.BoxGeometry(3.2, 4.4, 1.5), leather);
    pack.position.set(0, 13.8, -3.5);
    pack.castShadow = true;
    kit.add(pack);

    const coil = new THREE.Mesh(new THREE.TorusGeometry(1.65, 0.18, 8, 28), rope);
    coil.position.set(-2.4, 14.2, -3.2);
    coil.rotation.y = Math.PI / 2;
    coil.castShadow = true;
    coil.name = 'ropeCoil';
    kit.add(coil);

    const hookBar = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.12, 3.1, 8), metal);
    hookBar.position.set(2.3, 14.4, -3.2);
    hookBar.rotation.z = Math.PI / 2;
    hookBar.castShadow = true;
    kit.add(hookBar);
    const hookTipA = new THREE.Mesh(new THREE.ConeGeometry(0.32, 0.9, 8), metal);
    hookTipA.position.set(3.8, 14.4, -3.2);
    hookTipA.rotation.z = -Math.PI / 2.8;
    hookTipA.castShadow = true;
    kit.add(hookTipA);
    const hookTipB = hookTipA.clone();
    hookTipB.position.x = 0.8;
    hookTipB.rotation.z = Math.PI / 2.8;
    kit.add(hookTipB);

    const sample = new THREE.Mesh(new THREE.SphereGeometry(0.95, 10, 8), sampleMat);
    sample.name = 'carriedSample';
    sample.position.set(0, 11.4, 5.1);
    sample.castShadow = true;
    sample.visible = false;
    kit.add(sample);
    kit.userData.sample = sample;

    const toolBlade = new THREE.Group();
    toolBlade.name = 'toolBlade';
    const handle = new THREE.Mesh(new THREE.CylinderGeometry(0.13, 0.16, 2.4, 8), leather);
    handle.rotation.z = Math.PI / 2;
    handle.castShadow = true;
    toolBlade.add(handle);
    const blade = new THREE.Mesh(new THREE.ConeGeometry(0.32, 1.1, 8), metal);
    blade.position.x = 1.35;
    blade.rotation.z = -Math.PI / 2;
    blade.castShadow = true;
    toolBlade.add(blade);
    const brush = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.28, 0.9, 8), rope);
    brush.name = 'fieldBrushTip';
    brush.position.x = -1.25;
    brush.rotation.z = Math.PI / 2;
    brush.castShadow = true;
    toolBlade.add(brush);
    toolBlade.position.set(3.2, 12.5, 4.5);
    toolBlade.rotation.set(0.12, -0.3, -0.5);
    toolBlade.visible = false;
    kit.add(toolBlade);
    kit.userData.toolBlade = toolBlade;

    const vial = new THREE.Mesh(new THREE.CylinderGeometry(0.28, 0.34, 1.45, 12), glassMat);
    vial.name = 'sampleVial';
    vial.position.set(-1.25, 11.0, 5.0);
    vial.rotation.z = 0.25;
    vial.castShadow = true;
    vial.visible = false;
    kit.add(vial);
    kit.userData.vial = vial;

    const bundle = new THREE.Group();
    bundle.name = 'sampleBundle';
    for (let i = 0; i < 5; i += 1) {
      const leaf = new THREE.Mesh(new THREE.SphereGeometry(0.42, 8, 6), sampleMat);
      leaf.scale.set(1.0, 0.22, 0.58);
      leaf.position.set((i - 2) * 0.28, Math.sin(i) * 0.12, Math.cos(i) * 0.18);
      leaf.rotation.set(0.3 + i * 0.2, 0.1, i * 0.55);
      leaf.castShadow = true;
      bundle.add(leaf);
    }
    bundle.position.set(0.8, 11.2, 5.2);
    bundle.visible = false;
    kit.add(bundle);
    kit.userData.sampleBundle = bundle;

    const motes = new THREE.Group();
    motes.name = 'collectionMotes';
    for (let i = 0; i < 9; i += 1) {
      const mote = new THREE.Mesh(new THREE.SphereGeometry(0.16 + (i % 3) * 0.04, 7, 5), moteMat.clone());
      mote.material.userData.gnomeDisposableMaterial = true;
      mote.position.set(Math.sin(i * 1.7) * 2.0, 12.2 + (i % 4) * 0.75, 4.6 + Math.cos(i * 2.1) * 0.8);
      mote.userData.seed = i * 1.37;
      mote.castShadow = true;
      motes.add(mote);
    }
    motes.visible = false;
    kit.add(motes);
    kit.userData.collectionMotes = motes;
    kit.visible = false;
    return kit;
  }

  function makeCollectionDepot(plaza, scale) {
    const group = new THREE.Group();
    group.name = 'gnomeSampleDepot';
    group.position.set(plaza.x - scale * 17, 0.2, plaza.z + scale * 12);
    group.rotation.y = 0.35;
    group.scale.setScalar(scale);
    const wood = (typeof texturedMat === 'function') ? texturedMat(0x6f4c2c, 'wood') : mat(0x6f4c2c);
    const glass = mat(0xa9e2ff, { roughness: 0.18, metalness: 0.02, transparent: true, opacity: 0.44, emissive: 0x315d61, emissiveIntensity: 0.08 });
    const leaf = mat(0x69b65d, { roughness: 0.65 });
    const parchment = mat(0xd5bd86, { roughness: 0.78 });
    const slots = [];
    const resourceLedger = {};

    const table = new THREE.Mesh(new THREE.BoxGeometry(18, 2, 9), wood);
    table.position.y = 4;
    table.castShadow = true;
    group.add(table);
    const bench = new THREE.Group();
    bench.name = 'sampleProcessingBench';
    bench.position.set(0, 0, 0);
    group.add(bench);
    for (let i = 0; i < 4; i++) {
      const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.55, 0.7, 7, 7), wood);
      leg.position.set(i < 2 ? -7.2 : 7.2, 1.4, i % 2 === 0 ? -3.2 : 3.2);
      leg.castShadow = true;
      group.add(leg);
    }
    const rack = new THREE.Mesh(new THREE.BoxGeometry(16, 1.2, 1.2), wood);
    rack.position.set(0, 10.8, -3.9);
    rack.castShadow = true;
    group.add(rack);
    for (let i = 0; i < 9; i++) {
      const jarMat = glass.clone();
      jarMat.userData.gnomeDisposableMaterial = true;
      const jar = new THREE.Mesh(new THREE.CylinderGeometry(0.9, 1.0, 2.7, 12), jarMat);
      jar.position.set(-7 + i * 1.75, 7.2 + (i % 2) * 1.2, -3.7);
      jar.visible = false;
      jar.castShadow = true;
      group.add(jar);
      slots.push(jar);
    }
    for (let i = 0; i < 4; i++) {
      const tray = new THREE.Mesh(new THREE.BoxGeometry(3.2, 0.35, 2.2), parchment.clone());
      tray.material.userData.gnomeDisposableMaterial = true;
      tray.name = `sampleSortingTray-${i}`;
      tray.position.set(-5.8 + i * 3.8, 6.0, -0.4);
      tray.rotation.y = (i - 1.5) * 0.06;
      tray.castShadow = true;
      tray.visible = false;
      bench.add(tray);
      slots.push(tray);
    }
    for (let i = 0; i < 5; i++) {
      const bundleMat = leaf.clone();
      bundleMat.userData.gnomeDisposableMaterial = true;
      const bundle = new THREE.Mesh(new THREE.SphereGeometry(1.2, 10, 8), bundleMat);
      bundle.scale.set(1.4, 0.42, 0.7);
      bundle.position.set(-6 + i * 3, 5.5, 2.2);
      bundle.visible = false;
      bundle.castShadow = true;
      group.add(bundle);
      slots.push(bundle);
    }
    const depotGlow = glow(0xb6f2a1, 18, 0.0);
    depotGlow.name = 'sampleDepotPulse';
    depotGlow.position.set(0, 8.4, 0.2);
    depotGlow.visible = false;
    group.add(depotGlow);

    return {
      group,
      slots,
      resourceLedger,
      lastDeliveryPulse: 0,
      setStock(count, samplePlan) {
        if (samplePlan && samplePlan.method) {
          resourceLedger[samplePlan.method] = (resourceLedger[samplePlan.method] || 0) + 1;
          this.lastDeliveryPulse = performance.now ? performance.now() / 1000 : Date.now() / 1000;
        }
        const sampleColor = (samplePlan && samplePlan.color) || 0x69b65d;
        const visibleCount = Math.min(slots.length, Math.max(0, count | 0));
        slots.forEach((slot, index) => {
          slot.visible = index < visibleCount;
          if (slot.material && slot.material.color) {
            slot.material.color.setHex(index < 9 ? sampleColor : (index < 13 ? 0xd5bd86 : sampleColor));
            if (slot.material.emissive) {
              slot.material.emissive.setHex(index < 9 ? sampleColor : 0x000000);
              slot.material.emissiveIntensity = index < 9 && index < visibleCount ? 0.08 : 0;
            }
          }
        });
      },
      update(t) {
        const elapsed = t - (this.lastDeliveryPulse || -999);
        const pulse = elapsed >= 0 && elapsed < 2.4 ? 1 - elapsed / 2.4 : 0;
        depotGlow.visible = pulse > 0.02;
        depotGlow.material.opacity = pulse * 0.34;
        depotGlow.scale.setScalar(0.75 + pulse * 0.55 + Math.sin(t * 7) * pulse * 0.04);
        bench.children.forEach((tray, index) => {
          if (!tray.visible) return;
          tray.rotation.z = Math.sin(t * 1.6 + index) * 0.015;
        });
      }
    };
  }

  function settlementLifecycle(settlement) {
    const progress = clamp(finiteNumber(settlement && settlement.progress, 0), 0, 1);
    const settlementIndex = Math.max(0, Math.round(finiteNumber(settlement && settlement.settlementIndex, 0)));
    const isStartingZone = !!(settlement && settlement.isStartingZone);
    const resourceMaturity = smoothstep(0.06, 0.34, progress);
    const siteMaturity = smoothstep(0.16, 0.95, progress);
    const finishedFraction = smoothstep(0.34, 0.86, progress);
    const borrowBoost = !isStartingZone
      ? clamp(0.08 + progress * 0.20 + settlementIndex * 0.025, 0, 0.34)
      : clamp(progress > 0.86 ? 0.08 : 0, 0, 0.08);
    return {
      progress,
      settlementIndex,
      isStartingZone,
      resourceMaturity,
      siteMaturity,
      finishedFraction,
      borrowBoost,
      initialBuildProgress: clamp(0.014 + progress * 0.20 + borrowBoost * 0.16, 0.012, 0.42),
      initialBuildCap: clamp(0.07 + smoothstep(0.18, 0.94, progress) * 0.74 + borrowBoost * 0.18, 0.06, 0.92),
      resourceGate: clamp(0.18 + progress * 0.42 + borrowBoost * 0.54, 0.18, 1.08),
      cityTier: progress >= 0.93 ? 3 : (progress >= 0.78 ? 2 : (progress >= 0.58 ? 1 : 0)),
      tunnelOpen: settlementIndex > 0 || progress > 0.22,
      depotOpen: progress > 0.24,
      campOnly: progress < 0.34
    };
  }

  function deterministicRank(index, seed) {
    const raw = Math.sin((index + 1) * 12.9898 + (seed || 1) * 78.233) * 43758.5453;
    return raw - Math.floor(raw);
  }

  function inferredHouseType(index, seed) {
    const options = ['cottage', 'cottage', 'cottage', 'hall', 'tower'];
    return options[Math.abs(Math.floor((seed || 1) + index * 7)) % options.length];
  }

  function applySettlementLifecycle(description, lifecycle, seed) {
    if (!description || !Array.isArray(description.sites)) return description;
    const ordered = description.sites
      .map((site, index) => ({ index, rank: deterministicRank(index, seed) }))
      .sort((a, b) => a.rank - b.rank);
    let finishedTarget = Math.floor(description.sites.length * clamp(lifecycle.finishedFraction, 0, 1));
    if (lifecycle.campOnly) finishedTarget = 0;
    if (finishedTarget >= description.sites.length && description.sites.length && lifecycle.progress < 0.995) {
      finishedTarget = description.sites.length - 1;
    }

    const buildSites = [];
    ordered.forEach((entry, order) => {
      const site = description.sites[entry.index];
      if (!site.originalType) {
        site.originalType = site.type === 'build' ? inferredHouseType(entry.index, seed) : (site.type || inferredHouseType(entry.index, seed));
      }
      if (order < finishedTarget) {
        site.type = site.originalType;
        site.settlementStage = 'habitable';
      } else {
        site.type = 'build';
        site.settlementStage = lifecycle.campOnly ? 'resource-pile' : 'construction';
        buildSites.push(entry.index);
      }
    });

    description.buildSites = buildSites;
    if (Array.isArray(description.props)) {
      const propLimit = lifecycle.campOnly
        ? 0
        : Math.round(description.props.length * smoothstep(0.28, 0.82, lifecycle.progress));
      description.props = description.props.slice(0, propLimit);
    }
    description.settlementLifecycle = lifecycle;
    return description;
  }

  function makeResourceYard(plaza, scale, lifecycle, seed) {
    const group = new THREE.Group();
    group.name = 'gnomeResourceYard';
    group.position.set(plaza.x - scale * 26, 0.18, plaza.z - scale * 15);
    group.rotation.y = ((seed || 1) % 23) * 0.041 - 0.36;
    group.scale.setScalar(scale);

    const wood = (typeof texturedMat === 'function') ? texturedMat(0x8a5d34, 'wood') : mat(0x8a5d34);
    const rawWood = (typeof texturedMat === 'function') ? texturedMat(0xa77743, 'wood') : mat(0xa77743);
    const stone = (typeof texturedMat === 'function') ? texturedMat(0x847d70, 'stone') : mat(0x847d70);
    const leaf = (typeof texturedMat === 'function') ? texturedMat(0x5d8f4e, 'leaf') : mat(0x5d8f4e);
    const rope = mat(0xb8a16a, { roughness: 0.95 });
    const brass = mat(0xc59b55, { roughness: 0.42, metalness: 0.35, emissive: 0x2a1606, emissiveIntensity: 0.06 });

    const rawPiles = [];
    const refinedPiles = [];
    const samplePiles = [];
    const borrowedPiles = [];

    function addLog(parent, x, y, z, length, radius, material, rotY) {
      const log = new THREE.Mesh(new THREE.CylinderGeometry(radius * 0.88, radius, length, 9), material);
      log.position.set(x, y, z);
      log.rotation.set(Math.PI / 2, rotY || 0, Math.PI / 2 + (rotY || 0) * 0.08);
      log.castShadow = true;
      log.receiveShadow = true;
      parent.add(log);
      return log;
    }

    const raw = new THREE.Group();
    raw.name = 'rawResourcePile';
    for (let r = 0; r < 4; r += 1) {
      for (let i = 0; i < 3 + r; i += 1) {
        const log = addLog(raw, (i - 2) * 2.2, 1.0 + r * 1.25, r * 1.8, 8.5 - r * 0.4, 0.62, rawWood, (i - r) * 0.06);
        rawPiles.push(log);
      }
    }
    group.add(raw);

    const planks = new THREE.Group();
    planks.name = 'woodPile';
    planks.position.set(10, 0, 1);
    for (let i = 0; i < 10; i += 1) {
      const plank = new THREE.Mesh(new THREE.BoxGeometry(8.5, 0.38, 1.1), i % 2 ? wood : rawWood);
      plank.position.set(0.2 * (i % 2), 0.4 + i * 0.42, (i % 3) * 1.25);
      plank.rotation.y = (i % 2 ? 0.05 : -0.035);
      plank.castShadow = true;
      plank.receiveShadow = true;
      planks.add(plank);
      refinedPiles.push(plank);
    }
    group.add(planks);

    const stones = new THREE.Group();
    stones.name = 'stoneAndRootPile';
    stones.position.set(-9, 0, 7);
    for (let i = 0; i < 12; i += 1) {
      const pebble = new THREE.Mesh(new THREE.DodecahedronGeometry(0.8 + (i % 4) * 0.18, 0), stone);
      pebble.position.set(Math.sin(i * 1.7) * 3.2, 0.7 + (i % 3) * 0.48, Math.cos(i * 1.3) * 2.1);
      pebble.rotation.set(i * 0.2, i * 0.7, i * 0.17);
      pebble.castShadow = true;
      stones.add(pebble);
      rawPiles.push(pebble);
    }
    group.add(stones);

    const samples = new THREE.Group();
    samples.name = 'plantSampleCrates';
    samples.position.set(4, 0, -7);
    for (let i = 0; i < 9; i += 1) {
      const bundle = new THREE.Mesh(new THREE.SphereGeometry(0.82, 10, 8), leaf);
      bundle.scale.set(1.45, 0.34, 0.74);
      bundle.position.set((i % 3) * 2.0, 0.8 + Math.floor(i / 3) * 0.64, Math.floor(i / 3) * 1.1);
      bundle.rotation.set(0.08, i * 0.44, 0.02);
      bundle.castShadow = true;
      bundle.visible = false;
      samples.add(bundle);
      samplePiles.push(bundle);
    }
    group.add(samples);

    const borrowDepot = new THREE.Group();
    borrowDepot.name = 'tunnelBorrowDepot';
    borrowDepot.position.set(-1.5, 0, -10.5);
    const railA = new THREE.Mesh(new THREE.BoxGeometry(13, 0.18, 0.26), brass);
    railA.position.set(0, 0.28, -1.1);
    borrowDepot.add(railA);
    const railB = railA.clone();
    railB.position.z = 1.1;
    borrowDepot.add(railB);
    const cart = new THREE.Group();
    cart.name = 'interColonySupplyCart';
    const cartBox = new THREE.Mesh(new THREE.BoxGeometry(5.8, 2.2, 3.4), wood);
    cartBox.position.y = 1.55;
    cartBox.castShadow = true;
    cart.add(cartBox);
    [-2.1, 2.1].forEach(x => [-1.45, 1.45].forEach(z => {
      const wheel = new THREE.Mesh(new THREE.TorusGeometry(0.62, 0.12, 8, 18), brass);
      wheel.position.set(x, 0.48, z);
      wheel.rotation.y = Math.PI / 2;
      cart.add(wheel);
    }));
    cart.position.x = 1.2;
    borrowDepot.add(cart);
    for (let i = 0; i < 5; i += 1) {
      const crate = new THREE.Mesh(new THREE.BoxGeometry(1.45, 1.2, 1.25), i % 2 ? rawWood : wood);
      crate.position.set(-5.5 + i * 1.2, 1.1 + (i % 2) * 0.7, -2.7);
      crate.rotation.y = i * 0.12;
      crate.castShadow = true;
      borrowDepot.add(crate);
      borrowedPiles.push(crate);
    }
    const pulley = new THREE.Mesh(new THREE.TorusGeometry(1.05, 0.13, 8, 22), brass);
    pulley.name = 'borrowPulley';
    pulley.position.set(6.2, 5.1, 0);
    pulley.rotation.y = Math.PI / 2;
    borrowDepot.add(pulley);
    const ropeLine = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 8.4, 6), rope);
    ropeLine.position.set(6.2, 2.5, 0);
    borrowDepot.add(ropeLine);
    borrowDepot.visible = lifecycle.borrowBoost > 0.04;
    group.add(borrowDepot);

    const deliveryGlow = glow(0xc8ff9a, 20, 0);
    deliveryGlow.name = 'resourceYardDeliveryGlow';
    deliveryGlow.position.set(2.5, 6.8, -1.2);
    deliveryGlow.visible = false;
    group.add(deliveryGlow);

    function applyVisibility(items, visibleCount) {
      items.forEach((item, index) => { item.visible = index < visibleCount; });
    }

    return {
      group,
      borrowDepot,
      lastDeliveryPulse: 0,
      setStock(count, samplePlan) {
        const stock = Math.max(0, count | 0);
        const maturity = lifecycle.resourceMaturity || 0;
        const rawCount = Math.min(rawPiles.length, Math.max(3, Math.round(3 + maturity * rawPiles.length)));
        const refinedCount = Math.min(refinedPiles.length, Math.round(maturity * refinedPiles.length + stock * 0.45 + lifecycle.borrowBoost * 6));
        const sampleCount = Math.min(samplePiles.length, Math.round(stock + maturity * 2));
        const borrowCount = Math.min(borrowedPiles.length, Math.round(lifecycle.borrowBoost * 12));
        applyVisibility(rawPiles, rawCount);
        applyVisibility(refinedPiles, refinedCount);
        applyVisibility(samplePiles, sampleCount);
        applyVisibility(borrowedPiles, borrowCount);
        borrowDepot.visible = lifecycle.borrowBoost > 0.04 || borrowCount > 0;
        if (samplePlan && samplePlan.color) {
          samplePiles.forEach(item => {
            if (item.material && item.material.color) item.material.color.setHex(samplePlan.color);
          });
          this.lastDeliveryPulse = performance.now ? performance.now() / 1000 : Date.now() / 1000;
        }
      },
      update(t) {
        const elapsed = t - (this.lastDeliveryPulse || -999);
        const pulse = elapsed >= 0 && elapsed < 2.8 ? 1 - elapsed / 2.8 : 0;
        deliveryGlow.visible = pulse > 0.03;
        deliveryGlow.material.opacity = pulse * 0.38;
        deliveryGlow.scale.setScalar(0.8 + pulse * 0.65 + Math.sin(t * 8.0) * pulse * 0.04);
        if (borrowDepot.visible) {
          cart.position.x = 1.2 + Math.sin(t * 0.75 + seed) * 0.28;
          pulley.rotation.z = t * 0.9;
        }
      }
    };
  }

  function makeCityUpgradeLayer(description, lifecycle, houseScale, seed) {
    const group = new THREE.Group();
    group.name = 'gnomeCityUpgradeLayer';
    if (!description || !Array.isArray(description.sites) || lifecycle.cityTier <= 0) return group;

    const finished = description.sites
      .map((site, index) => ({ site, index, rank: deterministicRank(index + 97, seed) }))
      .filter(entry => entry.site.type !== 'build')
      .sort((a, b) => a.rank - b.rank);
    const upgradeCount = Math.min(finished.length, Math.ceil(finished.length * smoothstep(0.55, 0.98, lifecycle.progress)));
    const wood = (typeof texturedMat === 'function') ? texturedMat(0x6f4c2c, 'wood') : mat(0x6f4c2c);
    const roof = (typeof texturedMat === 'function') ? texturedMat(0x7a3828, 'thatch') : mat(0x7a3828);
    const linen = (typeof texturedMat === 'function') ? texturedMat(0xd6bf86, 'linen') : mat(0xd6bf86);
    const warmGlass = mat(0xffd88a, { roughness: 0.36, emissive: 0xffbd55, emissiveIntensity: 0.8, transparent: true, opacity: 0.62 });
    const scale = Math.max(1, houseScale);

    function addTier(entry, order) {
      const site = entry.site;
      const tier = Math.min(lifecycle.cityTier, 1 + Math.floor((lifecycle.progress - 0.58) * 7));
      const upgrade = new THREE.Group();
      upgrade.name = `verticalUpgradeTier-${tier}`;
      upgrade.position.set(site.x, 0.4, site.z);
      upgrade.rotation.y = site.rotation || 0;

      const deck = new THREE.Mesh(new THREE.BoxGeometry(scale * 0.86, scale * 0.08, scale * 0.62), wood);
      deck.name = 'upperDeck';
      deck.position.set(0, scale * 1.35, scale * 0.04);
      deck.castShadow = true;
      upgrade.add(deck);
      const dormer = new THREE.Mesh(new THREE.BoxGeometry(scale * 0.34, scale * 0.28, scale * 0.24), linen);
      dormer.name = 'storyDormer';
      dormer.position.set(scale * 0.18, scale * 1.52, scale * 0.36);
      dormer.castShadow = true;
      upgrade.add(dormer);
      const dormerWindow = new THREE.Mesh(new THREE.PlaneGeometry(scale * 0.16, scale * 0.16), warmGlass);
      dormerWindow.name = 'windowLights';
      dormerWindow.position.set(scale * 0.18, scale * 1.53, scale * 0.49);
      upgrade.add(dormerWindow);

      if (tier >= 2) {
        const lookout = new THREE.Mesh(new THREE.CylinderGeometry(scale * 0.18, scale * 0.22, scale * 0.78, 10), wood);
        lookout.name = 'lookoutStory';
        lookout.position.set(-scale * 0.26, scale * 1.86, -scale * 0.08);
        lookout.castShadow = true;
        upgrade.add(lookout);
        const lookoutRoof = new THREE.Mesh(new THREE.ConeGeometry(scale * 0.33, scale * 0.38, 12), roof);
        lookoutRoof.name = 'lookoutRoof';
        lookoutRoof.position.set(-scale * 0.26, scale * 2.45, -scale * 0.08);
        lookoutRoof.castShadow = true;
        upgrade.add(lookoutRoof);
      }
      if (tier >= 3) {
        const banner = new THREE.Mesh(new THREE.BoxGeometry(scale * 0.04, scale * 0.46, scale * 0.28), linen);
        banner.name = 'cultureBanner';
        banner.position.set(scale * 0.44, scale * 2.02, scale * 0.38);
        banner.rotation.z = Math.sin((seed + order) * 0.4) * 0.06;
        banner.castShadow = true;
        upgrade.add(banner);
      }
      group.add(upgrade);
    }

    finished.slice(0, upgradeCount).forEach(addTier);

    if (lifecycle.cityTier >= 3 && finished.length >= 2) {
      const first = finished[0].site;
      const second = finished[1].site;
      const dx = second.x - first.x;
      const dz = second.z - first.z;
      const length = Math.max(1, Math.hypot(dx, dz));
      const bridge = new THREE.Mesh(new THREE.BoxGeometry(scale * 0.16, scale * 0.08, length), wood);
      bridge.name = 'gnomeAerialWalkway';
      bridge.position.set((first.x + second.x) * 0.5, scale * 1.62, (first.z + second.z) * 0.5);
      bridge.rotation.y = Math.atan2(dx, dz);
      bridge.castShadow = true;
      group.add(bridge);
    }

    return group;
  }

  function normalizedZoneSettlement(zone) {
    return {
      progress: clamp(finiteNumber(zone && zone.settlementProgress, zone && zone.isStartingZone ? 0.12 : 0), 0, 1),
      settlementIndex: Math.max(0, Math.round(finiteNumber(zone && zone.settlementIndex, 0))),
      isStartingZone: !!(zone && zone.isStartingZone)
    };
  }

  function makeTunnelEntrance(plaza, scale, seed, opts) {
    opts = opts || {};
    const tunnelEntrances = new THREE.Group();
    tunnelEntrances.name = 'tunnelEntrances';
    tunnelEntrances.position.set(plaza.x, 0.22, plaza.z);
    // If a partner direction is known, orient the mound mouth toward it; else a
    // gentle seed-based rotation so isolated entrances aren't all axis-aligned.
    tunnelEntrances.rotation.y = (typeof opts.directionAngle === 'number' && isFinite(opts.directionAngle))
      ? opts.directionAngle
      : ((seed || 0) % 17) * 0.11;
    tunnelEntrances.scale.setScalar(scale);

    const moundMat = mat(0x7a5532, { roughness: 0.92 });
    const tunnelMound = new THREE.Mesh(new THREE.SphereGeometry(9, 24, 10), moundMat);
    tunnelMound.name = 'tunnelMound';
    tunnelMound.scale.set(1.25, 0.22, 0.76);
    tunnelMound.position.y = 1.0;
    tunnelMound.castShadow = true;
    tunnelMound.receiveShadow = true;
    tunnelEntrances.add(tunnelMound);

    const openingMat = mat(0x18100a, { roughness: 0.96, transparent: true, opacity: 0.86 });
    const opening = new THREE.Mesh(new THREE.CircleGeometry(4.1, 28), openingMat);
    opening.name = 'tunnelOpening';
    opening.rotation.x = -Math.PI / 2;
    opening.position.set(0, 1.26, 0.65);
    tunnelEntrances.add(opening);

    const rimMat = mat(0x3f2c1e, { roughness: 0.88 });
    const rim = new THREE.Mesh(new THREE.TorusGeometry(4.2, 0.32, 8, 28), rimMat);
    rim.name = 'tunnelRootRim';
    rim.rotation.x = Math.PI / 2;
    rim.position.copy(opening.position);
    rim.castShadow = true;
    tunnelEntrances.add(rim);

    for (let i = 0; i < 5; i++) {
      const pebble = new THREE.Mesh(new THREE.DodecahedronGeometry(0.55 + (i % 3) * 0.18, 0), mat(0x5c4434, { roughness: 0.94 }));
      const a = -1.2 + i * 0.62;
      pebble.position.set(Math.cos(a) * 5.8, 0.8, Math.sin(a) * 3.0 + 1.4);
      pebble.rotation.set(i * 0.4, a, i * 0.2);
      pebble.castShadow = true;
      tunnelEntrances.add(pebble);
    }

    const marker = glow(0xffd18a, 11, 0.18);
    marker.name = 'tunnelLanternGlow';
    marker.position.set(-4.7, 5.6, 2.2);
    tunnelEntrances.add(marker);
    tunnelEntrances.lanternGlow = marker;   // exposed for dig/emerge pulses

    return tunnelEntrances;
  }

  // Pre-allocated pool of reusable dirt-clump sprites for the tunnel dig/emerge
  // spray. Like the smoke pool, these are created once (visible=false) and just
  // repositioned/faded per frame — never allocated during the animation.
  function makeTunnelDirtPool(village, count) {
    for (let i = 0; i < count; i++) {
      const clump = glow(0x6b4a2c, 6, 0);
      clump.name = 'tunnelDirtClump';
      clump.visible = false;
      clump.position.set(9999, -50, 9999);
      clump.userData.seed = Math.random() * Math.PI * 2;
      village.group.add(clump);
      village.tunnelDirt.push(clump);
    }
  }

  function spawnGnome(village, action, role, x, z, faceX, faceZ) {
    const i = village.gnomes.length;
    const hat = gnomeHatColors[(village.colorBase + i) % gnomeHatColors.length];
    const tunic = gnomeTunicColors[(village.colorBase + i) % gnomeTunicColors.length];
    const g = makeGnome({ hatColor: hat, tunicColor: tunic, role });
    if (typeof addGnomeDetail === 'function') {
      addGnomeDetail(g.parts, { tunicColor: tunic, hatColor: hat, beardColor: 0xf2f2ee, pouch: role === 'carry' || role === 'build' });
    }
    g.group.position.set(x, 0, z);
    g.group.scale.setScalar(village.gnomeScale || 1);
    if (faceX !== undefined) g.group.rotation.y = Math.atan2(faceX - x, faceZ - z);
    village.group.add(g.group);
    const rec = { group: g.group, parts: g.parts, action, role, phase: i * 1.7 };
    rec.expeditionKit = createExpeditionKit();
    g.group.add(rec.expeditionKit);
    village.gnomes.push(rec);
    return rec;
  }

  function createGrapplingLine(village, rec) {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(9), 3));
    const material = new THREE.LineBasicMaterial({ color: 0xd7c28d, transparent: true, opacity: 0.72 });
    material.userData.gnomeDisposableMaterial = true;
    const line = new THREE.Line(geometry, material);
    line.name = 'grapplingLine';
    line.visible = false;
    village.group.add(line);
    rec.grapplingLine = line;
    return line;
  }

  function createGrapplingHook(village, rec) {
    const hook = new THREE.Group();
    hook.name = 'grapplingHook';
    const metal = mat(0x9ba1a4, { roughness: 0.34, metalness: 0.62 });
    const cord = mat(0xc9b27a, { roughness: 0.86 });
    const ring = new THREE.Mesh(new THREE.TorusGeometry(1.1, 0.09, 8, 20), metal);
    ring.rotation.x = Math.PI / 2;
    ring.castShadow = true;
    hook.add(ring);
    const spine = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.12, 3.6, 8), metal);
    spine.rotation.z = Math.PI / 2;
    spine.castShadow = true;
    hook.add(spine);
    for (let i = 0; i < 3; i += 1) {
      const tooth = new THREE.Mesh(new THREE.ConeGeometry(0.26, 1.15, 8), metal);
      tooth.position.x = 1.6;
      tooth.rotation.z = -Math.PI / 2.35;
      tooth.rotation.y = i * Math.PI * 2 / 3;
      tooth.castShadow = true;
      hook.add(tooth);
    }
    const knot = new THREE.Mesh(new THREE.SphereGeometry(0.28, 10, 8), cord);
    knot.position.x = -1.9;
    knot.castShadow = true;
    hook.add(knot);
    const glint = glow(0xcfe7ff, 4.4, 0.16);
    glint.name = 'grapplingHookGlint';
    glint.position.set(1.45, 0.25, 0);
    hook.add(glint);
    hook.visible = false;
    hook.scale.setScalar(0.86);
    village.group.add(hook);
    rec.grapplingHook = hook;
    return hook;
  }

  // --- Rider mount seating (shared by the butterfly + dragonfly mounts) ---
  // The mount body floats MOUNT_BODY_LIFT above the ride height and the saddle
  // pad sits MOUNT_SADDLE_LOCAL_Y above the body (mount-local units). The rider
  // must land ON that pad, so BOTH the mount placement and the gnome's lift are
  // derived from the same numbers — otherwise the gnome floats off the saddle
  // (the bug where the gnome rode high above / "below" the wings).
  const MOUNT_BODY_LIFT = 2.7;
  const MOUNT_SADDLE_LOCAL_Y = 2.4;
  function mountRideScale(village, phase) {
    return Math.max(0.25, (village.gnomeScale || 1) * (phase === 'butterflyRelease' ? 0.72 : 0.84));
  }
  function mountSeatLift(village, phase) {
    return mountRideScale(village, phase) * (MOUNT_BODY_LIFT + MOUNT_SADDLE_LOCAL_Y);
  }

  function makeButterflyWingGeometry() {
    const shape = new THREE.Shape();
    shape.moveTo(0, 0);
    shape.bezierCurveTo(5.8, 5.8, 14.2, 5.2, 16.5, 0.8);
    shape.bezierCurveTo(14.2, -3.2, 6.4, -5.3, 0, 0);
    return new THREE.ShapeGeometry(shape, 18);
  }

  function createButterflyMount(village, rec) {
    const mount = new THREE.Group();
    mount.name = 'gnomeButterflyMount';
    mount.userData.mountKind = 'butterfly';
    const wingColor = (rec.butterflyFlightPlan && rec.butterflyFlightPlan.wingColor) || (rec.missionTarget && rec.missionTarget.wingColor) || 0xffc66f;
    const wingMat = new THREE.MeshStandardMaterial({
      color: wingColor,
      roughness: 0.42,
      metalness: 0,
      transparent: true,
      opacity: 0.58,
      emissive: wingColor,
      emissiveIntensity: 0.10,
      side: THREE.DoubleSide,
      depthWrite: false
    });
    wingMat.userData.gnomeDisposableMaterial = true;
    const wingVeinMat = mat(0x4a3325, { roughness: 0.78, transparent: true, opacity: 0.32 });
    const bodyMat = mat(0x3a2a22, { roughness: 0.66, emissive: 0x120806, emissiveIntensity: 0.08 });
    const fuzzMat = mat(0x8d6a43, { roughness: 0.92 });
    const leather = mat(0x5b3927, { roughness: 0.76 });
    const brass = mat(0xc99f54, { roughness: 0.38, metalness: 0.42, emissive: 0x3d2508, emissiveIntensity: 0.08 });

    const body = new THREE.Group();
    body.name = 'butterflyBody';
    const thorax = new THREE.Mesh(new THREE.SphereGeometry(2.4, 18, 12), fuzzMat);
    thorax.scale.set(0.74, 0.92, 1.25);
    thorax.castShadow = true;
    body.add(thorax);
    const abdomen = new THREE.Mesh(new THREE.CylinderGeometry(0.92, 1.35, 8.5, 16), bodyMat);
    abdomen.rotation.x = Math.PI / 2;
    abdomen.position.z = -4.0;
    abdomen.castShadow = true;
    body.add(abdomen);
    const head = new THREE.Mesh(new THREE.SphereGeometry(1.25, 16, 10), bodyMat);
    head.position.z = 5.1;
    head.castShadow = true;
    body.add(head);
    for (let i = -1; i <= 1; i += 2) {
      const antenna = new THREE.Mesh(new THREE.CylinderGeometry(0.045, 0.07, 5.6, 7), wingVeinMat);
      antenna.position.set(i * 0.65, 1.0, 6.6);
      antenna.rotation.set(1.04, 0, i * 0.32);
      body.add(antenna);
      const tip = new THREE.Mesh(new THREE.SphereGeometry(0.18, 8, 6), brass);
      tip.position.set(i * 1.95, 3.7, 8.1);
      body.add(tip);
    }
    mount.add(body);

    const wingGeometry = makeButterflyWingGeometry();
    const wingPivotNames = ['leftForeWing', 'rightForeWing', 'leftHindWing', 'rightHindWing'];
    const wingPivots = {};
    wingPivotNames.forEach((name, index) => {
      const side = name.startsWith('left') ? -1 : 1;
      const hind = name.indexOf('Hind') >= 0;
      const pivot = new THREE.Group();
      pivot.name = name;
      pivot.position.set(side * 1.0, hind ? -0.1 : 0.24, hind ? -2.2 : 1.2);
      const wingMaterial = index === 0 ? wingMat : wingMat.clone();
      wingMaterial.userData.gnomeDisposableMaterial = true;
      const wing = new THREE.Mesh(wingGeometry, wingMaterial);
      wing.name = `${name}Mesh`;
      wing.material.userData.gnomeDisposableMaterial = true;
      wing.scale.set(side * (hind ? 0.62 : 0.82), hind ? 0.56 : 0.72, 1);
      wing.rotation.set(hind ? -0.24 : 0.08, 0, side * (hind ? 0.64 : 0.48));
      wing.castShadow = true;
      pivot.add(wing);
      for (let vein = 0; vein < 3; vein += 1) {
        const rib = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.045, hind ? 8.4 : 11.6, 5), wingVeinMat.clone());
        rib.material.userData.gnomeDisposableMaterial = true;
        rib.rotation.set(Math.PI / 2, 0, side * (0.72 + vein * 0.22));
        rib.position.set(side * (2.8 + vein * 2.7), 0.10, hind ? -1.0 - vein * 0.18 : 1.0 + vein * 0.12);
        pivot.add(rib);
      }
      mount.add(pivot);
      wingPivots[name] = pivot;
    });
    mount.userData.wingPivots = wingPivots;

    const saddle = new THREE.Group();
    saddle.name = 'butterflySaddle';
    const pad = new THREE.Mesh(new THREE.BoxGeometry(4.8, 0.7, 3.2), leather);
    pad.position.y = 2.4;
    pad.castShadow = true;
    saddle.add(pad);
    const strap = new THREE.Mesh(new THREE.TorusGeometry(2.6, 0.12, 8, 32), leather);
    strap.rotation.x = Math.PI / 2;
    strap.position.y = 1.4;
    saddle.add(strap);
    for (let i = -1; i <= 1; i += 2) {
      const ring = new THREE.Mesh(new THREE.TorusGeometry(0.36, 0.055, 6, 14), brass);
      ring.position.set(i * 2.1, 2.5, 1.4);
      ring.rotation.y = Math.PI / 2;
      saddle.add(ring);
    }
    mount.add(saddle);
    mount.userData.saddle = saddle;

    function makeRein(name, x) {
      const geometry = new THREE.BufferGeometry();
      geometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(9), 3));
      const material = new THREE.LineBasicMaterial({ color: 0xc9b27a, transparent: true, opacity: 0.58 });
      material.userData.gnomeDisposableMaterial = true;
      const line = new THREE.Line(geometry, material);
      line.name = name;
      line.userData.offsetX = x;
      mount.add(line);
      return line;
    }
    mount.userData.reinLeft = makeRein('butterflyReinLeft', -1.0);
    mount.userData.reinRight = makeRein('butterflyReinRight', 1.0);
    mount.userData.glow = glow(wingColor, 32, 0.16);
    mount.userData.glow.position.y = 1.0;
    mount.add(mount.userData.glow);

    mount.visible = false;
    mount.scale.setScalar(Math.max(0.25, (village.gnomeScale || 1) * 0.84));
    village.group.add(mount);
    rec.butterflyMountVisual = mount;
    return mount;
  }

  function makeDragonflyWingGeometry(hind) {
    // Long, narrow, membranous wing — the dragonfly silhouette, not the wide
    // butterfly paddle. Slight asymmetry between fore (longer) and hind (wider).
    const len = hind ? 19 : 22;
    const w = hind ? 3.0 : 2.5;
    const shape = new THREE.Shape();
    shape.moveTo(0, 0);
    shape.bezierCurveTo(len * 0.35, w, len * 0.85, w * 0.85, len, w * 0.30);
    shape.bezierCurveTo(len * 0.97, -w * 0.12, len * 0.6, -w * 0.65, len * 0.25, -w * 0.5);
    shape.bezierCurveTo(len * 0.1, -w * 0.36, 0, -w * 0.08, 0, 0);
    return new THREE.ShapeGeometry(shape, 22);
  }

  // A rideable dragonfly, built to read as a real darner: robust thorax, two
  // huge wrap-around compound eyes, a long segmented iridescent abdomen, and
  // four long outstretched gossamer wings. Reuses the same wing-pivot names and
  // saddle height as the butterfly so the shared seat + wingbeat code drives it.
  function createDragonflyMount(village, rec) {
    const mount = new THREE.Group();
    mount.name = 'gnomeDragonflyMount';
    mount.userData.mountKind = 'dragonfly';

    const palette = [
      { body: 0x1f7a8c, sheen: 0x6fe3ff, eye: 0x123b44 }, // electric teal darner
      { body: 0x2e8b57, sheen: 0x8effc0, eye: 0x10331f }, // emerald darner
      { body: 0xb5462a, sheen: 0xffb784, eye: 0x3a160c }, // ruby skimmer
      { body: 0x3a4cc0, sheen: 0x9fb3ff, eye: 0x15183f }  // blue dasher
    ];
    const pal = palette[Math.abs(Math.floor((rec.butterflyPhaseSeed || rec.phase || 1) * 97)) % palette.length];

    const bodyMat = mat(pal.body, { roughness: 0.34, metalness: 0.45, emissive: pal.body, emissiveIntensity: 0.14 });
    const sheenMat = mat(pal.sheen, { roughness: 0.22, metalness: 0.6, emissive: pal.sheen, emissiveIntensity: 0.18 });
    const eyeMat = mat(pal.eye, { roughness: 0.18, metalness: 0.3, emissive: pal.sheen, emissiveIntensity: 0.12 });
    const legMat = mat(0x1a1a1f, { roughness: 0.7 });
    const leather = mat(0x5b3927, { roughness: 0.76 });

    const body = new THREE.Group();
    body.name = 'dragonflyBody';

    const thorax = new THREE.Mesh(new THREE.SphereGeometry(2.6, 20, 14), bodyMat);
    thorax.scale.set(0.95, 1.05, 1.35);
    thorax.castShadow = true;
    body.add(thorax);
    const thoraxSheen = new THREE.Mesh(new THREE.SphereGeometry(2.63, 20, 14), sheenMat);
    thoraxSheen.scale.set(0.46, 1.08, 1.0);
    body.add(thoraxSheen);

    const segCount = 9;
    for (let i = 0; i < segCount; i += 1) {
      const f = i / (segCount - 1);
      const r = 0.95 - f * 0.62;
      const seg = new THREE.Mesh(new THREE.CylinderGeometry(r * 0.9, r, 1.95, 12), i % 2 ? sheenMat : bodyMat);
      seg.rotation.x = Math.PI / 2;
      seg.position.z = -3.0 - i * 1.85;
      seg.position.y = Math.sin(f * 1.1) * 0.5;
      seg.castShadow = true;
      body.add(seg);
    }
    const tail = new THREE.Mesh(new THREE.ConeGeometry(0.3, 1.2, 8), bodyMat);
    tail.rotation.x = -Math.PI / 2;
    tail.position.z = -3.0 - segCount * 1.85;
    body.add(tail);

    const head = new THREE.Group();
    head.position.z = 3.4;
    const face = new THREE.Mesh(new THREE.SphereGeometry(1.5, 14, 10), bodyMat);
    face.scale.set(1.2, 0.9, 0.8);
    head.add(face);
    for (let s = -1; s <= 1; s += 2) {
      const eye = new THREE.Mesh(new THREE.SphereGeometry(1.35, 16, 12), eyeMat);
      eye.position.set(s * 0.85, 0.35, 0.4);
      eye.scale.set(0.95, 1.05, 1.1);
      head.add(eye);
    }
    body.add(head);

    for (let i = 0; i < 6; i += 1) {
      const side = i % 2 ? 1 : -1;
      const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.05, 2.2, 5), legMat);
      leg.position.set(side * 1.1, -1.6, 1.6 - Math.floor(i / 2) * 1.1);
      leg.rotation.set(0.5, 0, side * 0.7);
      body.add(leg);
    }
    mount.add(body);

    const membraneMat = new THREE.MeshStandardMaterial({
      color: 0xeaffff, roughness: 0.2, metalness: 0.1,
      transparent: true, opacity: 0.26, emissive: pal.sheen, emissiveIntensity: 0.06,
      side: THREE.DoubleSide, depthWrite: false
    });
    membraneMat.userData.gnomeDisposableMaterial = true;
    const veinMat = mat(pal.body, { roughness: 0.6, transparent: true, opacity: 0.5 });

    const wingNames = ['leftForeWing', 'rightForeWing', 'leftHindWing', 'rightHindWing'];
    const wingPivots = {};
    wingNames.forEach((name) => {
      const side = name.startsWith('left') ? -1 : 1;
      const hind = name.indexOf('Hind') >= 0;
      const pivot = new THREE.Group();
      pivot.name = name;
      pivot.position.set(side * 0.9, 0.55, hind ? -1.4 : 0.9);
      const wing = new THREE.Mesh(makeDragonflyWingGeometry(hind), membraneMat.clone());
      wing.name = `${name}Mesh`;
      wing.material.userData.gnomeDisposableMaterial = true;
      wing.scale.set(side, 1, 1);
      wing.rotation.set(Math.PI / 2, hind ? -0.12 : 0.06, 0); // lay flat, outstretched
      pivot.add(wing);
      const stigma = new THREE.Mesh(new THREE.BoxGeometry(1.6, 0.05, 0.7), veinMat.clone());
      stigma.material.userData.gnomeDisposableMaterial = true;
      stigma.position.set(side * (hind ? 15.5 : 18.5), 0.06, hind ? 1.0 : 0.9);
      pivot.add(stigma);
      for (let v = 0; v < 2; v += 1) {
        const rib = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, hind ? 17 : 20, 4), veinMat.clone());
        rib.material.userData.gnomeDisposableMaterial = true;
        rib.rotation.set(0, 0, Math.PI / 2);
        rib.position.set(side * (hind ? 9 : 10.5), 0.05, (hind ? 1.0 : 0.9) + (v ? 0.85 : -0.55));
        pivot.add(rib);
      }
      mount.add(pivot);
      wingPivots[name] = pivot;
    });
    mount.userData.wingPivots = wingPivots;

    const saddle = new THREE.Group();
    saddle.name = 'dragonflySaddle';
    const pad = new THREE.Mesh(new THREE.BoxGeometry(3.6, 0.6, 3.0), leather);
    pad.position.set(0, MOUNT_SADDLE_LOCAL_Y, 0.4);
    pad.castShadow = true;
    saddle.add(pad);
    const strap = new THREE.Mesh(new THREE.TorusGeometry(2.4, 0.11, 8, 28), leather);
    strap.rotation.x = Math.PI / 2;
    strap.position.y = MOUNT_SADDLE_LOCAL_Y - 0.9;
    saddle.add(strap);
    mount.add(saddle);
    mount.userData.saddle = saddle;

    function makeRein(name, x) {
      const geometry = new THREE.BufferGeometry();
      geometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(9), 3));
      const material = new THREE.LineBasicMaterial({ color: 0xc9b27a, transparent: true, opacity: 0.55 });
      material.userData.gnomeDisposableMaterial = true;
      const line = new THREE.Line(geometry, material);
      line.name = name;
      line.userData.offsetX = x;
      mount.add(line);
      return line;
    }
    mount.userData.reinLeft = makeRein('butterflyReinLeft', -1.0);
    mount.userData.reinRight = makeRein('butterflyReinRight', 1.0);
    mount.userData.glow = glow(pal.sheen, 30, 0.14);
    mount.userData.glow.position.y = 1.0;
    mount.add(mount.userData.glow);

    mount.visible = false;
    mount.scale.setScalar(mountRideScale(village, rec.missionPhase || ''));
    village.group.add(mount);
    rec.butterflyMountVisual = mount;
    return mount;
  }

  function updateRein(line, side, t) {
    if (!line || !line.geometry || !line.geometry.attributes.position) return;
    const positions = line.geometry.attributes.position.array;
    const flutter = Math.sin(t * 6.4 + side) * 0.18;
    positions[0] = side * 0.8; positions[1] = 2.7; positions[2] = 1.0;
    positions[3] = side * (0.42 + flutter); positions[4] = 4.2; positions[5] = 3.6;
    positions[6] = side * 0.52; positions[7] = 1.0; positions[8] = 5.7;
    line.geometry.attributes.position.needsUpdate = true;
  }

  function updateButterflyRideVisuals(village, rec, t) {
    const phase = rec.missionPhase || '';
    const active = phase.indexOf('butterfly') === 0;
    // Default rides to the dragonfly; the mount kind is chosen when the ride
    // begins. Rebuild the cached visual only if the kind changed between rides.
    const kind = rec.mountType === 'butterfly' ? 'butterfly' : 'dragonfly';
    let mount = rec.butterflyMountVisual || null;
    if (active && (!mount || mount.userData.mountKind !== kind)) {
      if (mount && mount.parent) mount.parent.remove(mount);
      mount = kind === 'butterfly' ? createButterflyMount(village, rec) : createDragonflyMount(village, rec);
    }
    if (!mount) return;
    mount.visible = active;
    if (!active) return;
    const isDragon = kind === 'dragonfly';

    const scale = mountRideScale(village, phase);
    const lift = finiteNumber(rec.ziplineHeight, 0);
    const depthCue = finiteNumber(rec.butterflyDepthCue, 0);
    const bank = finiteNumber(rec.butterflyBank, 0);
    mount.scale.setScalar(scale * (depthCue < 0 ? 0.90 : 1.0));
    // Mount body sits MOUNT_BODY_LIFT above ride height; the gnome's seat in the
    // tick loop uses the matching mountSeatLift so the rider lands on the saddle.
    mount.position.set(rec.x, lift + scale * MOUNT_BODY_LIFT, rec.z);
    mount.rotation.set(Math.sin(t * 1.7 + rec.phase) * 0.04, finiteNumber(rec.heading, 0), bank);

    const pivots = mount.userData.wingPivots || {};
    if (isDragon) {
      // Dragonfly: wings stay outstretched and shimmer with a fast, low-amplitude
      // buzz; fore and hind beat slightly out of phase like the real insect.
      const buzz = Math.sin(t * 34 + rec.phase);
      const buzz2 = Math.sin(t * 34 + rec.phase + Math.PI * 0.55);
      const amp = 0.20;
      if (pivots.leftForeWing) pivots.leftForeWing.rotation.set(0, 0.05, -0.05 - buzz * amp);
      if (pivots.rightForeWing) pivots.rightForeWing.rotation.set(0, -0.05, 0.05 + buzz * amp);
      if (pivots.leftHindWing) pivots.leftHindWing.rotation.set(0, 0.05, -0.03 - buzz2 * amp);
      if (pivots.rightHindWing) pivots.rightHindWing.rotation.set(0, -0.05, 0.03 + buzz2 * amp);
      mount.traverse(child => {
        if (child.material && child.material.opacity != null && child.name && child.name.indexOf('Wing') >= 0) {
          // Faster buzz reads as more transparent (motion-blur cue).
          child.material.opacity = (depthCue < 0 ? 0.16 : 0.24) + Math.abs(buzz) * 0.06;
        }
      });
      if (mount.userData.glow) {
        mount.userData.glow.material.opacity = (depthCue < 0 ? 0.08 : 0.14) + Math.abs(buzz) * 0.05;
        mount.userData.glow.scale.setScalar(0.8 + Math.abs(buzz) * 0.22);
      }
    } else {
      const wingColor = (rec.butterflyFlightPlan && rec.butterflyFlightPlan.wingColor) || (rec.missionTarget && rec.missionTarget.wingColor) || 0xffc66f;
      const flap = Math.sin(t * 26 + rec.phase);
      const wobble = Math.sin(t * 5.2 + rec.phase) * 0.06;
      if (pivots.leftForeWing) pivots.leftForeWing.rotation.set(0.05 + wobble, 0.12, -0.58 - flap * 0.62);
      if (pivots.rightForeWing) pivots.rightForeWing.rotation.set(0.05 - wobble, -0.12, 0.58 + flap * 0.62);
      if (pivots.leftHindWing) pivots.leftHindWing.rotation.set(-0.18 + wobble, 0.08, -0.42 - flap * 0.44);
      if (pivots.rightHindWing) pivots.rightHindWing.rotation.set(-0.18 - wobble, -0.08, 0.42 + flap * 0.44);
      mount.traverse(child => {
        if (child.material && child.material.emissive && child.name !== 'butterflyBody') {
          child.material.emissive.setHex(wingColor);
          child.material.emissiveIntensity = 0.08 + Math.abs(flap) * 0.08;
        }
        if (child.material && child.material.opacity != null && child.name && child.name.indexOf('Wing') >= 0) {
          child.material.opacity = depthCue < 0 ? 0.38 : 0.58;
        }
      });
      if (mount.userData.glow) {
        mount.userData.glow.material.color.setHex(wingColor);
        mount.userData.glow.material.opacity = (depthCue < 0 ? 0.08 : 0.16) + Math.abs(flap) * 0.07;
        mount.userData.glow.scale.setScalar(0.8 + Math.abs(flap) * 0.28);
      }
    }
    updateRein(mount.userData.reinLeft, -1, t);
    updateRein(mount.userData.reinRight, 1, t);
  }

  function expeditionAnchorFor(rec, target) {
    const anchor = rec.grappleAnchor || {};
    return {
      x: finiteNumber(anchor.x, target ? finiteNumber(target.x, rec.x) : rec.x),
      y: finiteNumber(anchor.y, target ? 32 + clamp(finiteNumber(target.canopyHeight, 0.16), 0.05, 0.5) * 240 : 78),
      z: finiteNumber(anchor.z, target ? finiteNumber(target.z, rec.z) : rec.z)
    };
  }

  function expeditionOriginFor(rec) {
    const origin = rec.grappleOrigin || {};
    return {
      x: finiteNumber(origin.x, rec.x),
      y: finiteNumber(origin.y, 14),
      z: finiteNumber(origin.z, rec.z)
    };
  }

  function updateRopeGeometry(line, start, end, tension, jitter, t) {
    const positions = line.geometry.attributes.position.array;
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    const dz = end.z - start.z;
    const span = Math.max(1, Math.hypot(dx, dz));
    const ropeSag = clamp((1 - tension) * 12 + span * 0.025, 1.8, 16);
    const sway = Math.sin(t * 3.2 + jitter * 4.7) * (1 - tension) * 2.2;
    positions[0] = start.x; positions[1] = start.y; positions[2] = start.z;
    positions[3] = start.x + dx * 0.50 + sway; positions[4] = start.y + dy * 0.50 - ropeSag; positions[5] = start.z + dz * 0.50 - sway * 0.35;
    positions[6] = end.x; positions[7] = end.y; positions[8] = end.z;
    line.geometry.attributes.position.needsUpdate = true;
    if (line.material) line.material.opacity = clamp(0.46 + tension * 0.30, 0.42, 0.82);
  }

  function createCollectionContactMarker(village, rec) {
    const group = new THREE.Group();
    group.name = 'collectionContactMarker';
    const color = (rec.resourceCollectionPlan && rec.resourceCollectionPlan.color) || 0x65b86f;
    const glowSprite = glow(color, 10, 0.22);
    glowSprite.name = 'collectionContactGlow';
    group.add(glowSprite);
    const ring = new THREE.Mesh(
      new THREE.TorusGeometry(2.1, 0.06, 8, 36),
      mat(color, { roughness: 0.58, emissive: color, emissiveIntensity: 0.18, transparent: true, opacity: 0.72 })
    );
    ring.rotation.x = Math.PI / 2;
    group.add(ring);
    const flecks = new THREE.Group();
    flecks.name = 'collectionContactFlecks';
    for (let i = 0; i < 7; i += 1) {
      const fleck = new THREE.Mesh(
        new THREE.SphereGeometry(0.13 + (i % 2) * 0.05, 7, 5),
        mat(color, { roughness: 0.45, emissive: color, emissiveIntensity: 0.24, transparent: true, opacity: 0.78 })
      );
      fleck.userData.seed = i * 0.91;
      flecks.add(fleck);
    }
    group.add(flecks);
    group.visible = false;
    village.group.add(group);
    rec.collectionContactMarker = group;
    return group;
  }

  function updateCollectionContactMarker(village, rec, active, color, t) {
    const marker = rec.collectionContactMarker || (active ? createCollectionContactMarker(village, rec) : null);
    if (!marker) return;
    marker.visible = !!active;
    if (!active) return;
    const wp = rec.resourceCollectionWorkPoint || rec.grappleAnchor || rec.missionTarget;
    if (!wp) { marker.visible = false; return; }
    const stage = clamp(finiteNumber(rec.resourceCollectionStageProgress, 0), 0, 1);
    marker.position.set(finiteNumber(wp.x, rec.x), finiteNumber(wp.y, 16), finiteNumber(wp.z, rec.z));
    marker.rotation.y = t * 0.5 + rec.phase;
    marker.scale.setScalar(0.55 + stage * 0.45 + Math.sin(t * 4.1 + rec.phase) * 0.04);
    marker.traverse(child => {
      if (child.material && child.material.color) {
        child.material.color.setHex(color);
        if (child.material.emissive) child.material.emissive.setHex(color);
      }
    });
    const flecks = marker.getObjectByName('collectionContactFlecks');
    if (flecks) {
      flecks.children.forEach((fleck, i) => {
        const seed = finiteNumber(fleck.userData.seed, i);
        const r = 1.2 + stage * 2.4;
        fleck.position.set(
          Math.sin(t * 2.7 + seed) * r,
          Math.sin(t * 3.8 + seed) * 0.8 + stage * 1.3,
          Math.cos(t * 2.3 + seed) * r * 0.6
        );
        fleck.scale.setScalar(0.55 + Math.sin(t * 5.1 + seed) * 0.18 + stage * 0.28);
      });
    }
  }

  function updateExpeditionVisuals(village, rec, t) {
    const missionActive = !!rec.missionPhase;
    const phase = rec.missionPhase;
    const collectionPhase = phase === 'canopyInspect' || phase === 'fieldInspect' || phase === 'extractTap' || phase === 'sampleBundle';
    const sampleColor = (rec.resourceCollectionPlan && rec.resourceCollectionPlan.color) || (rec.missionTarget && rec.missionTarget.sampleColor) || 0x65b86f;
    if (rec.expeditionKit) {
      rec.expeditionKit.visible = missionActive || !!rec.sampleCarried;
      const sample = rec.expeditionKit.userData.sample;
      if (sample) {
        sample.visible = !!rec.sampleCarried || rec.action === 'sample' || rec.action === 'catalogSample' || phase === 'sampleBundle';
        if (sample.material) {
          sample.material.color.setHex(sampleColor);
        }
        const p = clamp(finiteNumber(rec.resourceCollectionProgress, sample.visible ? 1 : 0), 0, 1);
        sample.scale.setScalar((0.45 + p * 0.55) + Math.sin(t * 5.4 + rec.phase) * 0.04);
      }
      const tool = rec.expeditionKit.userData.toolBlade;
      if (tool) {
        tool.visible = collectionPhase && phase !== 'sampleBundle';
        const planTool = rec.resourceCollectionPlan ? rec.resourceCollectionPlan.tool : 'snips';
        const tap = Math.max(0, Math.sin(t * (planTool === 'brush' ? 9.0 : 12.0) + rec.phase));
        tool.rotation.set(0.12 + tap * 0.18, planTool === 'tap' ? -0.72 : -0.3, -0.5 - tap * (planTool === 'brush' ? 0.24 : 0.55));
        tool.position.set(3.0 + tap * 0.45, 12.1 + tap * 0.38, 4.5);
      }
      const vial = rec.expeditionKit.userData.vial;
      if (vial) {
        vial.visible = collectionPhase || !!rec.sampleCarried || rec.action === 'catalogSample';
        vial.scale.setScalar(0.72 + clamp(finiteNumber(rec.resourceCollectionProgress, 0), 0, 1) * 0.28);
        if (vial.material && rec.resourceCollectionPlan && rec.resourceCollectionPlan.method === 'seedPod') {
          vial.material.emissiveIntensity = 0.16;
        }
      }
      const bundle = rec.expeditionKit.userData.sampleBundle;
      if (bundle) {
        bundle.visible = phase === 'sampleBundle' || !!rec.sampleCarried || rec.action === 'catalogSample';
        bundle.scale.setScalar(0.45 + clamp(finiteNumber(rec.resourceCollectionProgress, 0), 0, 1) * 0.72);
        bundle.rotation.set(0.12, Math.sin(t * 1.6 + rec.phase) * 0.12, Math.sin(t * 4.4) * 0.04);
        bundle.traverse(child => {
          if (child.material && child.material.color) child.material.color.setHex(sampleColor);
        });
      }
      const motes = rec.expeditionKit.userData.collectionMotes;
      if (motes) {
        const motesActive = phase === 'extractTap' || phase === 'sampleBundle';
        motes.visible = motesActive;
        const progress = clamp(finiteNumber(rec.resourceCollectionStageProgress, 0), 0, 1);
        motes.children.forEach((mote, i) => {
          const seed = finiteNumber(mote.userData.seed, i);
          const drift = (t * 1.8 + seed) % 1;
          mote.position.x = Math.sin(seed + t * 2.4) * (1.1 + progress * 1.6);
          mote.position.y = 11.4 + drift * (3.4 + progress * 1.2);
          mote.position.z = 4.4 + Math.cos(seed + t * 2.1) * (0.5 + progress * 0.7);
          mote.scale.setScalar(0.55 + Math.sin(t * 5.2 + seed) * 0.12 + progress * 0.42);
          if (mote.material) {
            mote.material.color.setHex(sampleColor);
            mote.material.opacity = motesActive ? clamp(0.25 + (1 - drift) * 0.62, 0.18, 0.82) : 0;
          }
        });
      }
    }

    if ((rec.deliveredSamples || 0) !== (rec._visualDeliveredSamples || 0)) {
      const delta = Math.max(0, (rec.deliveredSamples || 0) - (rec._visualDeliveredSamples || 0));
      rec._visualDeliveredSamples = rec.deliveredSamples || 0;
      village.sampleStock = (village.sampleStock || 0) + delta;
      const borrowBoost = village.lifecycle ? village.lifecycle.borrowBoost || 0 : 0;
      village.resourceBoost = Math.min(0.65, borrowBoost + village.sampleStock * 0.018);
      if (village.collectionDepot) {
        village.collectionDepot.group.visible = true;
        village.collectionDepot.setStock(village.sampleStock, rec.resourceCollectionPlan);
      }
      if (village.resourceYard) village.resourceYard.setStock(village.sampleStock, rec.resourceCollectionPlan);
    }
    updateCollectionContactMarker(village, rec, collectionPhase, sampleColor, t);

    const target = rec.missionTarget;
    const linePhases = phase === 'grappleShoot' || phase === 'ziplineUp' || phase === 'sampling' || phase === 'canopyInspect' || phase === 'extractTap' || phase === 'sampleBundle' || phase === 'rappelDown';
    const needsLine = missionActive && target && (linePhases || rec.action === 'climb' || phase === 'climbing');
    const line = rec.grapplingLine || (needsLine ? createGrapplingLine(village, rec) : null);
    const hook = rec.grapplingHook || (missionActive && target ? createGrapplingHook(village, rec) : null);
    if (line) line.visible = !!needsLine;
    if (hook) hook.visible = !!(missionActive && target && (phase === 'grappleAim' || phase === 'grappleShoot' || linePhases));
    if (!target) return;

    const origin = expeditionOriginFor(rec);
    const anchor = expeditionAnchorFor(rec, target);
    const tension = clamp(finiteNumber(rec.grappleTension, phase === 'grappleShoot' ? 0.3 : 0.78), 0, 1);
    const jitter = finiteNumber(rec.grappleLineJitter, 0);
    let hookPoint = anchor;

    if (phase === 'grappleAim') {
      hookPoint = { x: rec.x + Math.sin(t * 1.7 + rec.phase) * 1.0, y: 18 + Math.sin(t * 3 + rec.phase) * 0.5, z: rec.z + 3.8 };
    } else if (phase === 'grappleShoot') {
      const p = clamp(finiteNumber(rec.grappleShootProgress, rec.grappleProgress || 0), 0, 1);
      const arc = Math.sin(p * Math.PI) * 18;
      hookPoint = {
        x: origin.x + (anchor.x - origin.x) * p,
        y: origin.y + (anchor.y - origin.y) * p + arc,
        z: origin.z + (anchor.z - origin.z) * p
      };
      if (line) updateRopeGeometry(line, origin, hookPoint, tension, jitter, t);
    } else if (needsLine && line) {
      const start = phase === 'rappelDown'
        ? { x: rec.x, y: Math.max(10, finiteNumber(rec.ziplineHeight, 0) + 16), z: rec.z }
        : origin;
      updateRopeGeometry(line, start, anchor, tension, jitter, t);
      hookPoint = anchor;
    }

    if (hook) {
      hook.position.set(hookPoint.x, hookPoint.y, hookPoint.z);
      const yaw = Math.atan2(anchor.x - origin.x, anchor.z - origin.z);
      hook.rotation.set(Math.sin(t * 7 + rec.phase) * 0.05, yaw, Math.cos(t * 5 + rec.phase) * 0.08);
      const hookScale = phase === 'grappleShoot' ? 0.88 + Math.sin(t * 18) * 0.04 : 0.86;
      hook.scale.setScalar(hookScale);
    }
  }

  // Pulse a village's tunnel-entrance lantern glow amber (helper shared by the
  // dig-in + emerge beats). intensity 0..1.
  function pulseTunnelLantern(village, intensity, t) {
    if (!village || !village.tunnelEntrances) return;
    village.tunnelEntrances.forEach(group => {
      const lamp = group.lanternGlow;
      if (!lamp || !lamp.material) return;
      const base = 0.18;
      lamp.material.opacity = clamp(base + intensity * 0.62 + Math.sin(t * 6) * intensity * 0.06, 0, 0.95);
      lamp.scale.setScalar(11 * (1 + intensity * 0.35));
    });
  }

  // Drive the dig/transit/emerge spray + lantern pulses. Modeled on
  // updateExpeditionVisuals: reuses the pre-allocated per-village dirt pool, no
  // per-frame allocation. The gnome is invisible during 'tunnelUnderground'.
  function updateTunnelVisuals(village, rec, t) {
    const phase = rec.tunnelPhase;
    const dirt = village.tunnelDirt || [];
    if (!phase) {
      // ensure no stray visible clumps when idle
      if (rec._tunnelDirtActive) {
        dirt.forEach(c => { c.visible = false; if (c.material) c.material.opacity = 0; });
        rec._tunnelDirtActive = false;
      }
      return;
    }

    if (phase === 'tunnelDigIn') {
      // dig progress 0..1 → scatter clumps outward from the gnome's feet & fade.
      const prog = clamp(finiteNumber(rec.tunnelProgress, 0), 0, 1);
      rec._tunnelDirtActive = true;
      dirt.forEach((clump, i) => {
        const seed = finiteNumber(clump.userData.seed, i);
        const angle = seed + i * 0.9;
        const burst = (Math.sin(t * 5 + seed) * 0.5 + 0.5);   // rhythmic with the shovel
        const reach = 4 + burst * 9 + prog * 4;
        clump.visible = true;
        clump.position.set(
          rec.x + Math.cos(angle) * reach,
          1.5 + burst * (6 + prog * 6),
          rec.z + Math.sin(angle) * reach * 0.7
        );
        clump.scale.setScalar(3 + burst * 4);
        if (clump.material) clump.material.opacity = clamp(burst * 0.5 * (1 - prog * 0.4), 0, 0.6);
      });
      pulseTunnelLantern(village, 0.35 + prog * 0.4, t);
      return;
    }

    if (phase === 'tunnelUnderground') {
      // nothing on the surface; hide any lingering clumps.
      if (rec._tunnelDirtActive) {
        dirt.forEach(c => { c.visible = false; if (c.material) c.material.opacity = 0; });
        rec._tunnelDirtActive = false;
      }
      return;
    }

    if (phase === 'tunnelEmerge') {
      // rising dust cone at the partner entrance + pulse the TARGET lantern.
      const prog = clamp(finiteNumber(rec.tunnelEmergeProgress, 0), 0, 1);
      rec._tunnelDirtActive = true;
      dirt.forEach((clump, i) => {
        const seed = finiteNumber(clump.userData.seed, i);
        const angle = seed + i * 1.3;
        const rise = ((t * 0.9 + seed) % 1);
        const radius = 2.4 + (1 - rise) * 5;
        clump.visible = true;
        clump.position.set(
          rec.x + Math.cos(angle) * radius * (0.4 + prog * 0.6),
          1.0 + rise * (8 + prog * 6),
          rec.z + Math.sin(angle) * radius * 0.6
        );
        clump.scale.setScalar(2.5 + (1 - rise) * 3);
        if (clump.material) clump.material.opacity = clamp((1 - rise) * 0.45 * (1 - prog * 0.5), 0, 0.5);
      });
      const targetVillage = rec.tunnelLink ? state.villages.get(rec.tunnelLink.targetVillageId) : null;
      pulseTunnelLantern(targetVillage || village, 0.4 + (1 - prog) * 0.4, t);
      return;
    }

    // tunnelArrived (or any other) — stop the spray.
    if (rec._tunnelDirtActive) {
      dirt.forEach(c => { c.visible = false; if (c.material) c.material.opacity = 0; });
      rec._tunnelDirtActive = false;
    }
  }

  // Move a surfaced courier from its source village into the partner village's
  // gnome list + scene group, then re-assign it a fresh local goal. Groups share
  // one world coordinate frame, so reparenting without changing position keeps
  // the gnome visually in place. Called AFTER the per-village step loop.
  function performVillageHandoff(sourceVillage, rec) {
    const targetVillage = rec.tunnelLink ? state.villages.get(rec.tunnelLink.targetVillageId) : null;
    if (!targetVillage) {
      // partner gone (zone deleted / rebuilt) — reset the gnome locally so it
      // never stays invisible or stuck in a tunnel phase.
      rec.tunnelPhase = null;
      rec.tunnelLink = null;
      rec.tunnelProgress = 0;
      rec.tunnelEmergeProgress = 0;
      rec.missionPhase = null;
      rec.group.visible = true;
      sourceVillage.routing.assign(rec);
      return;
    }
    // splice out of source, reparent the group, push into target
    const idx = sourceVillage.gnomes.indexOf(rec);
    if (idx >= 0) sourceVillage.gnomes.splice(idx, 1);
    if (sourceVillage.routing && typeof sourceVillage.routing.removeResident === 'function') {
      sourceVillage.routing.removeResident(rec);
    }
    sourceVillage.group.remove(rec.group);
    targetVillage.group.add(rec.group);
    targetVillage.gnomes.push(rec);
    // hide any source-village dirt clumps that were tracking this gnome
    if (rec._tunnelDirtActive && sourceVillage.tunnelDirt) {
      sourceVillage.tunnelDirt.forEach(c => { c.visible = false; if (c.material) c.material.opacity = 0; });
      rec._tunnelDirtActive = false;
    }
    rec.tunnelPhase = null;
    rec.tunnelLink = null;
    rec.tunnelProgress = 0;
    rec.tunnelEmergeProgress = 0;
    rec.missionPhase = null;
    rec.group.visible = true;
    // clear the stale source-village home/work so the courier adopts a home in
    // its new village; keep it a courier so it can tunnel onward later.
    rec.home = null;
    rec.work = null;
    rec.assignedSite = null;
    rec.tunnelCourier = true;
    // match the partner village's gnome scale so the courier isn't mis-sized
    if (rec.group && targetVillage.gnomeScale) rec.group.scale.setScalar(targetVillage.gnomeScale);
    targetVillage.routing.assign(rec);
  }

  function buildVillage(zone) {
    const poly = zonePolygon(zone);
    if (!poly) return null;
    const seed = zone.cultureSeed || 1;
    const sim = normalizedSimulation(state.simulation);
    const settlement = normalizedZoneSettlement(zone);
    const lifecycle = settlementLifecycle(settlement);
    const group = new THREE.Group();
    group.name = `village-${zone.id}`;
    scene.add(group);

    const village = {
      id: zone.id,
      zoneSignature: zoneSignature(zone),
      group,
      gnomes: [],
      buildSites: [],
      fires: [],
      windowLights: [],
      hearthGlows: [],
      lanternGlows: [],
      colorBase: Math.abs(seed) % gnomeHatColors.length,
      smoke: [],
      smokeSite: null,
      sampleStock: 0,
      resourceBoost: 0,
      collectionDepot: null,
      resourceYard: null,
      cityUpgradeLayer: null,
      tunnelTradeDepot: null,
      settlement,
      lifecycle,
      tunnelEntrances: [],
      tunnelLinks: [],
      tunnelExits: [],
      tunnelDirt: []
    };

    const siteCount = Math.max(
      1,
      Math.round((settlement.isStartingZone ? 2 : 1) + lifecycle.siteMaturity * (18 + sim.villageDetailMultiplier * 10))
    );
    const description = populateZone(poly, {
      seed,
      detailMultiplier: sim.villageDetailMultiplier,
      siteCount
    });
    applySettlementLifecycle(description, lifecycle, seed);
    village.description = description;

    // scale the whole village to the size of the drawn area so it FILLS the region
    const ms = description.minSpacing || 60;
    const gb = description.bounds || { minX: -100, maxX: 100, minZ: -100, maxZ: 100, w: 200, h: 200 };
    const zoneShortSide = Math.max(1, Math.min(gb.w || 1, gb.h || 1));
    const tribeScale = sim.tribeScaleMultiplier || 1;
    const houseScale = Math.max(4.5, Math.min(180, ms * 0.5, zoneShortSide * 0.18)) * tribeScale;
    village.houseScale = houseScale;
    village.gnomeScale = Math.max(0.22, Math.min(5.0, houseScale * 0.046));
    village.buildScale = Math.max(0.25, Math.min(9.0, houseScale / 12));

    // finished houses + props — roads + plaza are now EMERGENT, so suppress them
    const zoneGroup = buildZone(description, { houseScale, noRoads: true, noPlaza: true });
    collectRoutineLights(zoneGroup, village);
    group.add(zoneGroup);

    village.cityUpgradeLayer = makeCityUpgradeLayer(description, lifecycle, houseScale, seed);
    collectRoutineLights(village.cityUpgradeLayer, village);
    group.add(village.cityUpgradeLayer);

    // emergent desire-path ground: gnomes wear paths into this as they walk
    village.ground = createEmergentGround({
      bounds: { minX: gb.minX, maxX: gb.maxX, minZ: gb.minZ, maxZ: gb.maxZ },
      cellSize: Math.max(6, Math.min(14, ms * 0.16)),
      y: 0.18
    });
    group.add(village.ground.mesh);
    village.ground.seedPlaza(description.plaza.x, description.plaza.z, ms * 0.5, 0.7);

    // live build sites (grow pile -> finished), staggered so the village is mid-construction
    const bsIdx = description.buildSites || [];
    bsIdx.forEach((idx, k) => {
      const s = description.sites[idx];
      const site = makeBuildSite({ type: k % 2 === 0 ? 'cabin' : 'roundhouse', seed: seed + idx, scale: 1 });
      site.group.position.set(s.x, 0, s.z);
      site.group.rotation.y = s.rotation || 0;
      site.group.scale.setScalar(village.buildScale);
      group.add(site.group);
      const stagger = bsIdx.length > 1 ? (k / bsIdx.length) * 0.52 : 0.08;
      const init = clamp(
        lifecycle.initialBuildProgress + stagger * 0.18,
        0.012,
        lifecycle.initialBuildCap
      );
      site.setProgress(init, 0);
      village.buildSites.push({
        site,
        idx,
        progress: init,
        baseRate: 0.012 + (k % 3) * 0.005,
        resourceGate: lifecycle.resourceGate,
        detailed: false,
        smokeBound: false
      });
    });

    // bonfire at the plaza
    const bf = makeBonfire(description.plaza);
    group.add(bf.group);
    village.fires.push(bf);

    village.collectionDepot = makeCollectionDepot(description.plaza, Math.max(0.45, village.buildScale * 0.72));
    village.collectionDepot.group.visible = lifecycle.depotOpen;
    group.add(village.collectionDepot.group);

    village.resourceYard = makeResourceYard(
      description.plaza,
      Math.max(0.44, Math.min(2.9, village.buildScale * 0.74)),
      lifecycle,
      seed + 11
    );
    village.tunnelTradeDepot = village.resourceYard.borrowDepot;
    village.resourceYard.setStock(Math.round(lifecycle.resourceMaturity * 4 + lifecycle.borrowBoost * 5), null);
    group.add(village.resourceYard.group);

    const tunnelEntrance = makeTunnelEntrance(
      description.plaza,
      Math.max(0.45, Math.min(2.4, village.buildScale * (settlement.isStartingZone ? 0.68 : 0.92))),
      seed + settlement.settlementIndex * 31
    );
    tunnelEntrance.visible = lifecycle.tunnelOpen;
    group.add(tunnelEntrance);
    village.tunnelEntrances.push(tunnelEntrance);

    // smoke sprites (re-anchored to a chimney once a build finishes)
    for (let i = 0; i < 6; i++) {
      const s = glow(0xb9b3a8, 14, 0.16); s.visible = false; s.position.set(9999, 0, 9999);
      s.userData.off = Math.random() * 10; group.add(s); village.smoke.push(s);
    }

    // gnomes spread ACROSS the whole drawn area: a resident outside most houses,
    // a builder at each build site, a few gathered at the plaza, plus wanderers.
    const plaza = description.plaza;
    const populationScale = clamp(0.12 + lifecycle.resourceMaturity * 0.22 + settlement.progress * 0.66, 0.10, 1);
    const GNOME_CAP = Math.round(clamp(18 * sim.populationMultiplier * populationScale, settlement.isStartingZone ? 3 : 1, 36));
    // residents — stand just outside each cottage door (door faces the plaza)
    description.sites.forEach((s, k) => {
      if (s.type === 'build') return;
      if (village.gnomes.length >= Math.max(2, GNOME_CAP - 4)) return;
      if (k % 3 === 2) return;                       // not every single house, ~2/3
      const dx = plaza.x - s.x, dz = plaza.z - s.z;
      const d = Math.hypot(dx, dz) || 1;
      const off = houseScale * 0.8;
      const gx = s.x + (dx / d) * off, gz = s.z + (dz / d) * off;
      spawnGnome(village, (k % 4 === 0) ? 'carry' : 'idle', 'idle', gx, gz, plaza.x, plaza.z);
    });
    // builders hammering at each live build site
    village.buildSites.forEach(bs => {
      const p = bs.site.group.position;
      const off = houseScale * 0.7;
      const b = spawnGnome(village, 'build', 'build', p.x + off, p.z + off, p.x, p.z);
      b.assignedSite = bs;
    });
    // a small gathering at the plaza
    if (village.gnomes.length < GNOME_CAP) {
      spawnGnome(village, 'cheer', 'idle', plaza.x + houseScale * 0.2, plaza.z + houseScale * 0.9, plaza.x, plaza.z);
    }
    if (village.gnomes.length < GNOME_CAP) {
      spawnGnome(village, 'chat', 'idle', plaza.x - houseScale * 0.9, plaza.z + houseScale * 0.5, plaza.x, plaza.z);
    }

    // a couple more carriers shuttling goods through town
    if (village.gnomes.length < GNOME_CAP) {
      spawnGnome(village, 'carry', 'carry', plaza.x + houseScale * 1.2, plaza.z - houseScale * 0.6, plaza.x, plaza.z);
    }
    if (village.gnomes.length < GNOME_CAP) {
      spawnGnome(village, 'idle', 'idle', plaza.x - houseScale * 0.4, plaza.z - houseScale * 1.1, plaza.x, plaza.z);
    }

    // ---- routing: gnomes roam between POIs (home / work / well / plaza),
    //      wearing desire paths into the ground; the plaza emerges from traffic ----
    const finishedHomes = description.sites.filter(s => s.type !== 'build').map(s => ({ x: s.x, z: s.z }));
    const homes = finishedHomes.length
      ? finishedHomes
      : [
          { x: plaza.x + houseScale * 0.38, z: plaza.z + houseScale * 0.62 },
          { x: plaza.x - houseScale * 0.72, z: plaza.z + houseScale * 0.28 },
          { x: plaza.x + houseScale * 0.10, z: plaza.z - houseScale * 0.68 }
        ];
    const works = village.buildSites.map(bs => ({ x: bs.site.group.position.x, z: bs.site.group.position.z }));
    const wells = [{ x: plaza.x + ms * 0.8, z: plaza.z - ms * 0.5 }];
    const plantPOIs = plantPOIsForPolygon(poly);
    const expeditionPlants = expeditionPOIsForPolygon(poly, gb);
    const butterflyPOIs = butterflyPOIsForPolygon(poly, gb, plantPOIs, expeditionPlants, seed);
    if (expeditionPlants.length && village.gnomes.length < GNOME_CAP) {
      const scout = spawnGnome(village, 'inspect', 'carry', plaza.x + houseScale * 0.9, plaza.z - houseScale * 1.1, plaza.x, plaza.z);
      scout.expeditionSpecialist = true;
    }
    if (butterflyPOIs.length && village.gnomes.length < GNOME_CAP) {
      const rider = spawnGnome(village, 'cheer', 'idle', plaza.x - houseScale * 1.0, plaza.z - houseScale * 0.7, plaza.x, plaza.z);
      rider.butterflyRider = true;
      rider.nextButterflyRideAt = 5 + (seed % 19);
    }
    village.routing = createTownRouting({
      bounds: { minX: gb.minX, maxX: gb.maxX, minZ: gb.minZ, maxZ: gb.maxZ },
      explorationBounds: { minX: -halfX(), maxX: halfX(), minZ: -HZ, maxZ: HZ },
      polygon: poly,
      plaza: { x: plaza.x, z: plaza.z },
      homes, works, wells,
      plantPOIs,
      expeditionPlants,
      butterflyPOIs,
      simulation: sim,
      dailyRoutine: normalizedDailyRoutine(state.dailyRoutine),
      rng: mulberry32(seed)
    });
    village.gnomes.forEach(rec => {
      rec.x = rec.group.position.x; rec.z = rec.group.position.z;
      if (rec.assignedSite) {
        rec.role = 'build';
        rec.work = { x: rec.assignedSite.site.group.position.x, z: rec.assignedSite.site.group.position.z };
      }
      village.routing.assign(rec);
    });

    // ---- tunnel couriers: a small fraction of the colony specializes in
    //      cross-zone travel. They walk to the tunnel entrance, dig, travel
    //      underground, and emerge in a partner zone. Only spawn when this
    //      village's tunnel is open; cross-zone links are wired in buildTunnelLinks.
    if (lifecycle.tunnelOpen) {
      const courierCap = Math.max(1, Math.floor(village.gnomes.length * 0.1));
      const courierCount = Math.min(courierCap, 1 + (seed % 2)); // 1–2 couriers
      for (let c = 0; c < courierCount; c++) {
        const cx = plaza.x + houseScale * (0.6 + c * 0.3);
        const cz = plaza.z + houseScale * (0.4 - c * 0.5);
        const courier = spawnGnome(village, 'walk', 'carry', cx, cz, plaza.x, plaza.z);
        courier.tunnelCourier = true;
        courier.x = courier.group.position.x;
        courier.z = courier.group.position.z;
        village.routing.assign(courier);
      }
    }

    // reusable dig/emerge dirt-spray sprites (created once, never per frame)
    makeTunnelDirtPool(village, 7);

    return village;
  }

  function constructionActionForStage(stats, fallbackRole) {
    if (!stats) return fallbackRole === 'build' ? 'build' : 'idle';
    switch (stats.stageName) {
      case 'Survey & Supplies':
      case 'Excavation & Footings':
        return 'inspect';
      case 'Foundation':
      case 'Wall Raising':
        return 'carry';
      case 'Frame & Scaffold':
      case 'Roofing':
      case 'Finish Trim':
        return 'build';
      case 'Move-In Details':
        return 'cheer';
      default:
        return fallbackRole === 'build' ? 'build' : 'idle';
    }
  }

  function collectRoutineLights(root, village) {
    if (!root || !root.traverse) return;
    root.traverse(obj => {
      if (!obj || !obj.isMesh) return;
      if (obj.name === 'windowLights') village.windowLights.push(obj);
      if (obj.name === 'hearthGlow' || obj.userData.routineLight === 'home') village.hearthGlows.push(obj);
      if (obj.name === 'lanternGlow' || obj.userData.routineLight === 'lantern') village.lanternGlows.push(obj);
    });
  }

  function removeVillage(village) {
    // a gnome deleted mid-traversal must never be left invisible — clear any
    // in-flight tunnel state and re-show its body before the group is disposed.
    if (Array.isArray(village.gnomes)) {
      village.gnomes.forEach(rec => {
        if (rec && rec.tunnelPhase) {
          rec.tunnelPhase = null;
          rec.tunnelLink = null;
          if (rec.group) rec.group.visible = true;
        }
      });
    }
    village.fires.forEach(f => {
      if (f.light) {
        scene.remove(f.light);
        state.fireLightCount = Math.max(0, state.fireLightCount - 1);
      }
    });
    const excluded = new Set();
    if (village.ground && village.ground.mesh) excluded.add(village.ground.mesh);
    if (village.ground && village.ground.dispose) village.ground.dispose();
    disposeObjectTree(village.group, excluded);
    scene.remove(village.group);
  }

  function disposeObjectTree(root, excludedObjects) {
    if (!root || !root.traverse) return;
    const excluded = excludedObjects || new Set();
    root.traverse(obj => {
      if (excluded.has(obj)) return;
      if (obj.geometry && obj.geometry.dispose) obj.geometry.dispose();
      const materials = Array.isArray(obj.material) ? obj.material : (obj.material ? [obj.material] : []);
      materials.forEach(material => {
        if (material && material.userData && material.userData.gnomeDisposableMaterial && material.dispose) {
          material.dispose();
        }
      });
    });
  }

  function applyCircadian() {
    const lvl = Math.max(0.12, Math.min(1, state.lightLevel || 1));
    hemi.intensity = baseIntensity.hemi * (0.5 + lvl * 0.9);
    moon.intensity = baseIntensity.moon * (0.28 + lvl * 0.85);
    fill.intensity = baseIntensity.fill * (0.4 + lvl * 0.8);
    rim.intensity = baseIntensity.rim * (0.5 + (1 - lvl) * 0.7);   // rim warms up at dusk
    renderer.toneMappingExposure = 0.92 + lvl * 0.26;
  }

  function setRoutineMaterial(mesh, intensity, opacity) {
    if (!mesh || !mesh.material) return;
    const materials = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
    materials.forEach(material => {
      if (!material) return;
      material.transparent = true;
      material.opacity = clamp(opacity, 0, 1);
      material.emissiveIntensity = clamp(intensity, 0, 2.4);
      material.needsUpdate = true;
    });
    mesh.visible = opacity > 0.015 || intensity > 0.015;
  }

  function applyDailyRoutine(t) {
    const routine = normalizedDailyRoutine(state.dailyRoutine);
    const lightFactor = clamp(1.1 - state.lightLevel, 0, 1);
    const pulse = 0.92 + Math.sin((t || 0) * 4.7) * 0.05 + Math.sin((t || 0) * 11.3) * 0.025;
    const home = clamp((routine.homeLightIntensity + lightFactor * 0.28) * pulse, 0, 1.35);
    const lantern = clamp((routine.lanternIntensity + lightFactor * 0.18) * pulse, 0, 1.25);
    const firefly = clamp(routine.fireflyIntensity + lightFactor * 0.22, 0, 1);
    fireflies.visible = firefly > 0.01;
    fireflies.material.opacity = 0.08 + firefly * 0.86;
    fireflies.material.size = 1.2 + firefly * 3.2;

    for (const v of state.villages.values()) {
      v.windowLights.forEach(light => setRoutineMaterial(light, 0.18 + home * 1.6, 0.12 + home * 0.76));
      v.hearthGlows.forEach(light => setRoutineMaterial(light, 0.24 + home * 1.4, 0.10 + home * 0.72));
      v.lanternGlows.forEach(light => setRoutineMaterial(light, 0.16 + lantern * 1.65, 0.08 + lantern * 0.72));
      v.smoke.forEach(s => {
        if (s.userData.base == null) return;
        s.visible = routine.smokeIntensity > 0.03;
      });
    }
  }

  /* ---- camera framing ---- */
  function frameCamera() {
    const HX = halfX();
    const aspect = state.width / Math.max(1, state.height);
    camera.aspect = aspect;
    const radius = Math.max(HX, HZ * 1.3);
    const dist = (radius / Math.tan((FOV * Math.PI / 180) / 2)) * CAM_FIT;
    state.perspective = normalizedPerspective(state.perspective);
    const elev = state.perspective.elevationDegrees * Math.PI / 180;
    const yaw = state.perspective.yawDegrees * Math.PI / 180;
    const horizontalDist = Math.cos(elev) * dist;
    camera.position.set(
      Math.sin(yaw) * horizontalDist,
      Math.sin(elev) * dist,
      Math.cos(yaw) * horizontalDist + HZ * 0.2
    );
    camera.lookAt(0, 6, 0);
    camera.updateProjectionMatrix();
    camera.updateMatrixWorld(true);

    moon.position.set(-HX * 0.6, dist * 0.9, HZ * 0.7);
    const sc = moon.shadow.camera;
    const ext = Math.max(HX, HZ) * 1.3;
    sc.left = -ext; sc.right = ext; sc.top = ext; sc.bottom = -ext;
    sc.far = dist * 2.4; sc.updateProjectionMatrix();
    fill.position.set(HX * 0.5, dist * 0.4, -HZ);
  }

  function resize() {
    const previousWidth = state.width;
    const previousHeight = state.height;
    state.width = window.innerWidth;
    state.height = window.innerHeight;
    renderer.setSize(state.width, state.height, false);
    frameCamera();
    seedFireflies();
    if ((previousWidth !== state.width || previousHeight !== state.height) && state.villages.size > 0) {
      for (const v of state.villages.values()) removeVillage(v);
      state.villages.clear();
      syncVillages();
    }
  }

  /* ---- cross-zone tunnel links ----
   * For every pair of villages whose tunnel is open, link each village to its
   * 1–3 nearest neighbours (cheap O(n^2) over plaza centroids — runs only on a
   * syncVillages rebuild, not per frame). Each village's routing gets the links
   * out of it (so its couriers can pick a destination zone) and its tunnel
   * entrance is reoriented to face its single nearest partner.
   * TunnelLink = { sourceVillageId, targetVillageId, sourceEntrancePos{x,z},
   *                targetEntrancePos{x,z}, distanceWorldUnits }. */
  const MAX_TUNNEL_NEIGHBOURS = 3;
  function tunnelEntrancePosFor(village) {
    const plaza = village.description && village.description.plaza;
    return plaza ? { x: plaza.x, z: plaza.z } : { x: 0, z: 0 };
  }
  function buildTunnelLinks() {
    state.tunnelLinks.clear();
    const open = [];
    for (const v of state.villages.values()) {
      if (v.lifecycle && v.lifecycle.tunnelOpen) {
        open.push({ village: v, pos: tunnelEntrancePosFor(v) });
      }
      v.tunnelLinks = [];
      v.tunnelExits = [];
    }
    if (open.length >= 2) {
      for (let i = 0; i < open.length; i++) {
        const self = open[i];
        // distance to every other open village
        const others = [];
        for (let j = 0; j < open.length; j++) {
          if (j === i) continue;
          const other = open[j];
          const dx = other.pos.x - self.pos.x;
          const dz = other.pos.z - self.pos.z;
          others.push({ other, distance: Math.hypot(dx, dz) });
        }
        others.sort((a, b) => a.distance - b.distance);
        const links = [];
        const count = Math.min(MAX_TUNNEL_NEIGHBOURS, others.length);
        for (let k = 0; k < count; k++) {
          const entry = others[k];
          links.push({
            sourceVillageId: self.village.id,
            targetVillageId: entry.other.village.id,
            sourceEntrancePos: { x: self.pos.x, z: self.pos.z },
            targetEntrancePos: { x: entry.other.pos.x, z: entry.other.pos.z },
            distanceWorldUnits: entry.distance
          });
        }
        state.tunnelLinks.set(self.village.id, links);
        self.village.tunnelLinks = links;
        self.village.tunnelExits = links.slice();

        // reorient this village's tunnel entrance toward its NEAREST partner
        if (links.length && self.village.tunnelEntrances && self.village.tunnelEntrances.length) {
          const nearest = links[0];
          const dx = nearest.targetEntrancePos.x - self.pos.x;
          const dz = nearest.targetEntrancePos.z - self.pos.z;
          const angle = Math.atan2(dx, dz);
          self.village.tunnelEntrances.forEach(group => { group.rotation.y = angle; });
        }
      }
    }

    // push the per-village links into each routing instance
    for (const v of state.villages.values()) {
      if (v.routing && typeof v.routing.setTunnelLinks === 'function') {
        v.routing.setTunnelLinks(v.tunnelLinks || []);
      }
    }
  }

  /* ---- sync villages to the current zone set ---- */
  function syncVillages() {
    const active = new Set(state.zones.map(z => z.id));
    for (const [id, v] of state.villages.entries()) {
      if (!active.has(id)) { removeVillage(v); state.villages.delete(id); }
    }
    for (const zone of state.zones) {
      const existing = state.villages.get(zone.id);
      const signature = zoneSignature(zone);
      if (existing && existing.zoneSignature !== signature) {
        removeVillage(existing);
        state.villages.delete(zone.id);
      }
      if (!state.villages.has(zone.id)) {
        const v = buildVillage(zone);
        if (v) state.villages.set(zone.id, v);
      } else {
        const v = state.villages.get(zone.id);
        if (v && v.routing && v.routing.setSimulation) {
          v.routing.setSimulation(normalizedSimulation(state.simulation));
        }
        if (v && v.routing && v.routing.setDailyRoutine) {
          v.routing.setDailyRoutine(normalizedDailyRoutine(state.dailyRoutine));
        }
      }
    }
    // wire cross-zone tunnel links now that the full village set is current
    buildTunnelLinks();
  }

  /* ---- animation ---- */
  function tick(now) {
    requestAnimationFrame(tick);
    const t = now / 1000;
    const dt = Math.min(0.05, Math.max(0, t - state.prevT));
    state.prevT = t;
    if (state.paused) { renderer.render(scene, camera); return; }
    applyDailyRoutine(t);

    // fireflies drift
    const fp = ffGeo.attributes.position.array;
    for (let i = 0; i < FF; i++) {
      fp[i * 3 + 1] += Math.sin(t * 1.3 + ffPhase[i]) * 0.05;
      fp[i * 3] += Math.cos(t * 0.7 + ffPhase[i]) * 0.06;
    }
    ffGeo.attributes.position.needsUpdate = true;

    const sim = normalizedSimulation(state.simulation);
    const routine = normalizedDailyRoutine(state.dailyRoutine);
    const simDt = dt * clamp(0.65 + sim.behaviorLiveliness * 0.35, 0.35, 1.7);
    const poseOptions = { speed: sim.behaviorLiveliness };
    const tunnelHandoffs = [];   // (sourceVillage, rec) tuples to reparent AFTER stepping
    for (const v of state.villages.values()) {
      // gnomes roam between POIs, wearing desire paths into the ground
      for (const rec of v.gnomes) {
        v.routing.stepGnome(rec, simDt, v.ground.deposit);
        const ridingButterfly = String(rec.missionPhase || '').indexOf('butterfly') === 0
          && rec.missionPhase !== 'butterflyRelease';
        const liftedY = finiteNumber(rec.ziplineHeight, 0)
          + (ridingButterfly ? mountSeatLift(v, rec.missionPhase) : 0);
        rec.group.position.set(rec.x, liftedY, rec.z);
        if (rec.heading != null) rec.group.rotation.y = rec.heading;
        poseGnome(rec.parts, t + rec.phase, rec.action, {
          ...poseOptions,
          gait: finiteNumber(rec.phase, 0),
          bank: finiteNumber(rec.butterflyBank, 0),
          depthCue: finiteNumber(rec.butterflyDepthCue, 0),
          emergeT: finiteNumber(rec.tunnelEmergeProgress, 0)
        });
        // surfaced at a partner zone — queue for the cross-village hand-off
        // (don't reparent mid-loop while iterating v.gnomes).
        if (rec.tunnelPhase === 'tunnelArrived') tunnelHandoffs.push({ sourceVillage: v, rec });
      }
      v.ground.update(dt);   // decay + throttled texture repaint (paths pave/fade)

      // build sites advance
      for (const bs of v.buildSites) {
        if (bs.progress < 1) {
          const resourceGate = clamp((bs.resourceGate || 0.2) + (v.resourceBoost || 0) + (v.sampleStock || 0) * 0.012, 0.16, 1.85);
          bs.progress = Math.min(1, bs.progress + (bs.baseRate || 0.012) * sim.buildingSpeedMultiplier * simDt * (0.18 + routine.buildBias * 0.92) * resourceGate);
          bs.site.setProgress(bs.progress, t);
        }
        bs.stats = bs.site.constructionStats ? bs.site.constructionStats(bs.progress) : null;
        bs.stageName = bs.stats ? bs.stats.stageName : (bs.site.stageName ? bs.site.stageName(bs.progress) : 'Building');
        if (bs.progress >= 0.999 && !bs.detailed) {
          bs.detailed = true;
          if (typeof addHouseDetail === 'function') addHouseDetail(bs.site.group, bs.site.type, {});
        }
        if (bs.progress >= 1 && !bs.smokeBound && !v.smokeSite) {
          bs.smokeBound = true; v.smokeSite = bs.site;
          const wp = new THREE.Vector3(); bs.site.smokeAnchor.getWorldPosition(wp);
          v.group.worldToLocal(wp);
          v.smoke.forEach((s, k) => { s.visible = true; s.userData.base = wp.y + k * 7; s.position.x = wp.x; s.position.z = wp.z; });
        }
      }
      for (const rec of v.gnomes) {
        if (!rec.assignedSite || rec.missionPhase) continue;
        if (rec.dwell > 0 || rec.role === 'build') {
          rec.action = constructionActionForStage(rec.assignedSite.stats, rec.role);
        }
      }
      if (v.smokeSite) {
        v.smoke.forEach((s, k) => {
          const yy = ((t * 8 + s.userData.off + k * 7) % 56);
          s.position.y = s.userData.base + yy; s.material.opacity = 0.18 * routine.smokeIntensity * (1 - yy / 56); s.scale.setScalar(14 + yy * 0.5);
        });
      }
      if (v.collectionDepot && typeof v.collectionDepot.update === 'function') {
        v.collectionDepot.update(t);
      }
      if (v.resourceYard && typeof v.resourceYard.update === 'function') {
        v.resourceYard.update(t);
      }
      // fire flicker
      for (const f of v.fires) {
        const fireIntensity = clamp(routine.bonfireIntensity + (1 - state.lightLevel) * 0.25, 0, 1.1);
        if (f.light) f.light.intensity = fireIntensity * (0.85 + Math.sin(t * 9 + f.group.position.x) * 0.16 + Math.sin(t * 23) * 0.06);
        f.fireGlow.material.opacity = 0.12 + fireIntensity * 0.54;
        f.fireGlow.scale.setScalar((20 + fireIntensity * 24) + Math.sin(t * 7 + f.group.position.x) * 3);
        f.flame.visible = fireIntensity > 0.04;
        f.fireGlow.visible = fireIntensity > 0.04;
        f.flame.scale.y = 0.7 + fireIntensity * 0.35 + Math.sin(t * 11) * 0.12;
      }
      for (const rec of v.gnomes) {
        updateExpeditionVisuals(v, rec, t);
        updateButterflyRideVisuals(v, rec, t);
        updateTunnelVisuals(v, rec, t);
      }
    }

    // process deferred cross-village hand-offs now that every village's gnomes
    // have been stepped (reparenting mid-loop would corrupt the iteration).
    for (const h of tunnelHandoffs) performVillageHandoff(h.sourceVillage, h.rec);

    renderer.render(scene, camera);
  }

  function makeGlowTex() {
    const c = document.createElement('canvas'); c.width = c.height = 128; const ctx = c.getContext('2d');
    const g = ctx.createRadialGradient(64, 64, 0, 64, 64, 64);
    g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(0.28, 'rgba(255,255,255,0.55)'); g.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = g; ctx.fillRect(0, 0, 128, 128); return new THREE.CanvasTexture(c);
  }

  /* ---- bridge ---- */
  window.gnomeBridge = {
    configure(payload) {
      state.zones = Array.isArray(payload.zones) ? payload.zones : [];
      state.plants = Array.isArray(payload.plants) ? payload.plants : [];
      state.lightLevel = Number.isFinite(payload.lightLevel) ? payload.lightLevel : 1;
      state.perspective = normalizedPerspective(payload.perspective);
      state.simulation = normalizedSimulation(payload.simulation);
      state.dailyRoutine = normalizedDailyRoutine(payload.dailyRoutine);
      resize();
      syncVillages();
      applyCircadian();
      applyDailyRoutine(performance.now() / 1000);
    },
    setPaused(paused) { state.paused = !!paused; },
    status() {
      let gnomes = 0, sites = 0;
      for (const v of state.villages.values()) { gnomes += v.gnomes.length; sites += v.buildSites.length; }
      return {
        renderer: 'three-js',
        visualVersion,
        zoneCount: state.zones.length,
        villageCount: state.villages.size,
        gnomes,
        buildSites: sites,
        lightLevel: state.lightLevel,
        dailyRoutine: normalizedDailyRoutine(state.dailyRoutine),
        perspective: normalizedPerspective(state.perspective),
        simulation: normalizedSimulation(state.simulation),
        hasThree: typeof THREE !== 'undefined',
        hasModules: typeof makeGnome === 'function' && typeof spawnZone === 'function' && typeof texturedMat === 'function'
      };
    }
  };

  resize();
  applyCircadian();
  window.addEventListener('resize', resize);
  requestAnimationFrame(tick);
})();
