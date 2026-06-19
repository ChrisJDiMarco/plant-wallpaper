(function attachBirdFlockMath(global) {
  'use strict';

  const SPECIES = [
    {
      id: 'american-robin',
      name: 'American Robin',
      body: '#5b5147',
      breast: '#c76536',
      wing: '#3d3d3a',
      accent: '#f2d3a0',
      beak: '#d99a2b',
      size: 1.00,
      speed: 1.00,
      flap: 1.00,
      flapHz: 5.2,
      wingAspect: 5.8,
      wingSpan: 34,
      mass: 0.077,
      turnRate: 2.6,
      maxBank: 0.74,
      minSpeed: 24,
      maxSpeed: 116,
      lift: 0.78,
      behavior: 'swoop'
    },
    {
      id: 'northern-cardinal',
      name: 'Northern Cardinal',
      body: '#b81524',
      breast: '#dd2d35',
      wing: '#7b1019',
      accent: '#201718',
      beak: '#f07840',
      size: 0.92,
      speed: 0.96,
      flap: 1.10,
      flapHz: 6.1,
      wingAspect: 5.4,
      wingSpan: 30,
      mass: 0.045,
      turnRate: 2.9,
      maxBank: 0.82,
      minSpeed: 22,
      maxSpeed: 112,
      lift: 0.72,
      behavior: 'burst'
    },
    {
      id: 'blue-jay',
      name: 'Blue Jay',
      body: '#3b78bd',
      breast: '#d9e1e6',
      wing: '#25538e',
      accent: '#111923',
      beak: '#20242a',
      size: 1.05,
      speed: 1.02,
      flap: 0.94,
      flapHz: 4.4,
      wingAspect: 5.2,
      wingSpan: 40,
      mass: 0.090,
      turnRate: 2.35,
      maxBank: 0.70,
      minSpeed: 24,
      maxSpeed: 112,
      lift: 0.84,
      behavior: 'curious'
    },
    {
      id: 'american-goldfinch',
      name: 'American Goldfinch',
      body: '#e8cf24',
      breast: '#f4dd45',
      wing: '#1e211c',
      accent: '#fff5a6',
      beak: '#e0a766',
      size: 0.76,
      speed: 1.12,
      flap: 1.24,
      flapHz: 9.8,
      wingAspect: 5.7,
      wingSpan: 23,
      mass: 0.014,
      turnRate: 3.6,
      maxBank: 0.90,
      minSpeed: 20,
      maxSpeed: 118,
      lift: 0.68,
      behavior: 'bob'
    },
    {
      id: 'barn-swallow',
      name: 'Barn Swallow',
      body: '#263f6e',
      breast: '#d0a384',
      wing: '#1f2d4f',
      accent: '#a84b31',
      beak: '#1e1b17',
      size: 0.82,
      speed: 1.42,
      flap: 1.46,
      flapHz: 7.4,
      wingAspect: 8.8,
      wingSpan: 34,
      mass: 0.020,
      turnRate: 4.4,
      maxBank: 1.02,
      minSpeed: 34,
      maxSpeed: 176,
      lift: 0.92,
      behavior: 'weave'
    },
    {
      id: 'mourning-dove',
      name: 'Mourning Dove',
      body: '#bcae9d',
      breast: '#d6c1b2',
      wing: '#8f8175',
      accent: '#4f4a45',
      beak: '#34302a',
      size: 1.12,
      speed: 0.82,
      flap: 0.72,
      flapHz: 4.2,
      wingAspect: 5.0,
      wingSpan: 45,
      mass: 0.120,
      turnRate: 1.72,
      maxBank: 0.58,
      minSpeed: 22,
      maxSpeed: 92,
      lift: 0.88,
      behavior: 'glide'
    },
    {
      id: 'ruby-throated-hummingbird',
      name: 'Ruby-throated Hummingbird',
      body: '#2f8c5c',
      breast: '#d8e3d4',
      wing: '#2d544a',
      accent: '#b5162e',
      beak: '#181818',
      size: 0.48,
      speed: 1.54,
      flap: 3.40,
      flapHz: 42.0,
      wingAspect: 7.0,
      wingSpan: 10,
      mass: 0.003,
      turnRate: 7.4,
      maxBank: 1.15,
      minSpeed: 3,
      maxSpeed: 96,
      lift: 1.28,
      behavior: 'hover'
    },
    {
      id: 'red-tailed-hawk',
      name: 'Red-tailed Hawk',
      body: '#6f5138',
      breast: '#d3b58a',
      wing: '#3f3026',
      accent: '#9d5733',
      beak: '#d9b64a',
      size: 1.62,
      speed: 0.92,
      flap: 0.52,
      flapHz: 1.1,
      wingAspect: 6.4,
      wingSpan: 125,
      mass: 1.100,
      turnRate: 1.08,
      maxBank: 0.50,
      minSpeed: 28,
      maxSpeed: 106,
      lift: 1.34,
      behavior: 'soar'
    },
    {
      id: 'american-crow',
      name: 'American Crow',
      body: '#16191d',
      breast: '#25292d',
      wing: '#0f1115',
      accent: '#39424b',
      beak: '#151515',
      size: 1.26,
      speed: 0.98,
      flap: 0.82,
      flapHz: 3.3,
      wingAspect: 5.6,
      wingSpan: 95,
      mass: 0.450,
      turnRate: 1.42,
      maxBank: 0.62,
      minSpeed: 24,
      maxSpeed: 104,
      lift: 1.02,
      behavior: 'sentinel'
    },
    {
      id: 'house-sparrow',
      name: 'House Sparrow',
      body: '#8b6a44',
      breast: '#cbb99c',
      wing: '#5b452f',
      accent: '#24201b',
      beak: '#6f593b',
      size: 0.70,
      speed: 1.08,
      flap: 1.18,
      flapHz: 11.5,
      wingAspect: 5.4,
      wingSpan: 22,
      mass: 0.027,
      turnRate: 3.35,
      maxBank: 0.88,
      minSpeed: 18,
      maxSpeed: 112,
      lift: 0.64,
      behavior: 'flit'
    }
  ];

  function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
  }

  function mulberry32(seed) {
    let value = seed >>> 0;
    return function random() {
      value += 0x6D2B79F5;
      let t = value;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function hashString(value) {
    let hash = 2166136261;
    for (let index = 0; index < value.length; index += 1) {
      hash ^= value.charCodeAt(index);
      hash = Math.imul(hash, 16777619);
    }
    return hash >>> 0;
  }

  function normalizeAngle(angle) {
    let next = angle;
    while (next <= -Math.PI) {
      next += Math.PI * 2;
    }
    while (next > Math.PI) {
      next -= Math.PI * 2;
    }
    return next;
  }

  function signedAngleDelta(from, to) {
    return normalizeAngle(to - from);
  }

  function approach(current, target, maxDelta) {
    const delta = target - current;
    if (Math.abs(delta) <= maxDelta) {
      return target;
    }
    return current + Math.sign(delta) * maxDelta;
  }

  function length(x, y) {
    return Math.hypot(x, y);
  }

  function pointInPolygon(point, polygon) {
    let inside = false;
    for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i, i += 1) {
      const xi = polygon[i].x;
      const yi = polygon[i].y;
      const xj = polygon[j].x;
      const yj = polygon[j].y;
      const crosses = ((yi > point.y) !== (yj > point.y))
        && point.x < ((xj - xi) * (point.y - yi)) / Math.max(0.000001, yj - yi) + xi;
      if (crosses) {
        inside = !inside;
      }
    }
    return inside;
  }

  function polygonCentroid(points) {
    if (!points.length) {
      return { x: 0, y: 0 };
    }
    const sum = points.reduce((partial, point) => ({
      x: partial.x + point.x,
      y: partial.y + point.y
    }), { x: 0, y: 0 });
    return { x: sum.x / points.length, y: sum.y / points.length };
  }

  function zoneToPixels(zone, width, height) {
    const points = zone.points.map((point) => ({
      x: point.x * width,
      y: point.y * height
    }));
    const centroid = zone.centroid
      ? { x: zone.centroid.x * width, y: zone.centroid.y * height }
      : polygonCentroid(points);
    return {
      id: zone.id,
      skySeed: zone.skySeed || hashString(zone.id || 'sky'),
      points,
      centroid,
      bounds: {
        minX: (zone.bounds?.minX ?? 0) * width,
        minY: (zone.bounds?.minY ?? 0) * height,
        maxX: (zone.bounds?.maxX ?? 1) * width,
        maxY: (zone.bounds?.maxY ?? 1) * height
      }
    };
  }

  function randomPointInZone(zone, random) {
    const bounds = zone.bounds;
    for (let attempt = 0; attempt < 90; attempt += 1) {
      const point = {
        x: bounds.minX + random() * Math.max(1, bounds.maxX - bounds.minX),
        y: bounds.minY + random() * Math.max(1, bounds.maxY - bounds.minY)
      };
      if (pointInPolygon(point, zone.points)) {
        return point;
      }
    }
    return { ...zone.centroid };
  }

  function speciesCatalog() {
    return SPECIES.map((species) => ({ ...species }));
  }

  function birdCountForZone(zone, width, height, countMultiplier = 1) {
    const area = Math.max(0.001, (zone.bounds.maxX - zone.bounds.minX) * (zone.bounds.maxY - zone.bounds.minY));
    const screenArea = Math.max(1, width * height);
    const density = clamp(countMultiplier, 0.25, 2.0);
    return clamp(Math.round((1.8 + area / screenArea * 7.0) * density), 1, 10);
  }

  function createBirdState(zone, index, width, height) {
    const random = mulberry32((zone.skySeed || 1) + index * 8191 + hashString(zone.id || 'zone'));
    const point = randomPointInZone(zone, random);
    const speciesIndex = Math.floor(random() * SPECIES.length) % SPECIES.length;
    const species = SPECIES[speciesIndex];
    const angle = random() * Math.PI * 2;
    const speed = clamp(
      (35 + random() * 42) * species.speed,
      species.minSpeed,
      species.maxSpeed
    );
    return {
      id: `${zone.id}-${index}`,
      zoneId: zone.id,
      x: point.x,
      y: point.y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed * 0.45,
      heading: angle,
      targetHeading: angle,
      airspeed: speed,
      bank: 0,
      depth: 0.45 + random() * 0.55,
      speciesIndex,
      wingPhase: random() * Math.PI * 2,
      liftPhase: random() * Math.PI * 2,
      flapHz: species.flapHz,
      wingStroke: 0,
      sinkRate: 0,
      liftForce: 0,
      behaviorPhase: random() * Math.PI * 2,
      orbitBias: random() > 0.5 ? 1 : -1,
      leadership: random(),
      restlessness: random(),
      age: 0
    };
  }

  function rebuildBirdsForZones(zones, width, height, options = {}) {
    const birds = [];
    for (const zone of zones) {
      const count = birdCountForZone(zone, width, height, options.countMultiplier ?? 1);
      for (let index = 0; index < count; index += 1) {
        birds.push(createBirdState(zone, index, width, height));
      }
    }
    return birds;
  }

  function stepFlock(birds, zones, dt, options = {}) {
    const zoneMap = new Map(zones.map((zone) => [zone.id, zone]));
    const wind = (options.windStrength || 0) - 0.5;
    const time = options.time || 0;
    const safeDt = clamp(dt, 0.001, 0.05);
    const turnDt = clamp(dt, 0.001, 0.12);

    for (const bird of birds) {
      const zone = zoneMap.get(bird.zoneId) || zones[0];
      if (!zone) {
        continue;
      }
      const species = SPECIES[bird.speciesIndex % SPECIES.length];
      const point = { x: bird.x, y: bird.y };
      const futurePoint = {
        x: bird.x + bird.vx * 0.68,
        y: bird.y + bird.vy * 0.68
      };
      const inside = pointInPolygon(point, zone.points);
      const futureInside = pointInPolygon(futurePoint, zone.points);
      let desiredX = bird.vx + wind * 18;
      let desiredY = bird.vy;

      if (!inside || !futureInside) {
        const containmentUrgency = inside ? 1.85 : 5.2;
        desiredX += (zone.centroid.x - bird.x) * containmentUrgency;
        desiredY += (zone.centroid.y - bird.y) * containmentUrgency;
      } else {
        const dx = zone.centroid.x - bird.x;
        const dy = zone.centroid.y - bird.y;
        const orbit = Math.sin(time * 0.18 + bird.behaviorPhase) * 0.5 + bird.orbitBias;
        desiredX += dx * 0.42 + -dy * 0.22 * orbit;
        desiredY += dy * 0.34 + dx * 0.16 * orbit;
      }

      let neighbors = 0;
      let closeX = 0;
      let closeY = 0;
      let alignX = 0;
      let alignY = 0;
      let cohesionX = 0;
      let cohesionY = 0;
      for (const other of birds) {
        if (other === bird || other.zoneId !== bird.zoneId) {
          continue;
        }
        const dx = other.x - bird.x;
        const dy = other.y - bird.y;
        const distanceSq = dx * dx + dy * dy;
        if (distanceSq > 240 * 240) {
          continue;
        }
        neighbors += 1;
        alignX += other.vx;
        alignY += other.vy;
        cohesionX += other.x;
        cohesionY += other.y;
        if (distanceSq < 54 * 54) {
          closeX -= dx / Math.max(1, distanceSq);
          closeY -= dy / Math.max(1, distanceSq);
        }
      }
      if (neighbors > 0) {
        const inv = 1 / neighbors;
        desiredX += (alignX * inv - bird.vx) * 0.56;
        desiredY += (alignY * inv - bird.vy) * 0.42;
        desiredX += (cohesionX * inv - bird.x) * 0.26;
        desiredY += (cohesionY * inv - bird.y) * 0.22;
        desiredX += closeX * 11500;
        desiredY += closeY * 11500;
      }

      switch (species.behavior) {
      case 'hover':
        desiredX += Math.sin(time * 4.3 + bird.behaviorPhase) * 34;
        desiredY += Math.cos(time * 5.1 + bird.behaviorPhase) * 28;
        break;
      case 'soar':
        desiredX += Math.cos(time * 0.42 + bird.behaviorPhase) * 34;
        desiredY += Math.sin(time * 0.31 + bird.behaviorPhase) * 18;
        break;
      case 'weave':
        desiredX += Math.sin(time * 2.1 + bird.behaviorPhase) * 62;
        desiredY += Math.cos(time * 1.7 + bird.behaviorPhase) * 34;
        break;
      case 'bob':
        desiredY += Math.sin(time * 3.4 + bird.behaviorPhase) * 42;
        break;
      case 'burst':
        desiredX += Math.sin(time * 1.9 + bird.behaviorPhase) * 46;
        break;
      default:
        desiredX += Math.sin(time * 0.9 + bird.behaviorPhase) * 18;
        desiredY += Math.cos(time * 0.7 + bird.behaviorPhase) * 13;
      }

      const desiredHeading = Math.atan2(desiredY, desiredX);
      const turnDelta = signedAngleDelta(bird.heading ?? Math.atan2(bird.vy, bird.vx), desiredHeading);
      const urgencyMultiplier = !inside ? 7.0 : !futureInside ? 2.4 : 1.0;
      const maxTurn = species.turnRate * turnDt * (1 + bird.restlessness * 0.32) * urgencyMultiplier;
      const limitedTurn = clamp(turnDelta, -maxTurn, maxTurn);
      bird.heading = normalizeAngle((bird.heading ?? desiredHeading) + limitedTurn);
      bird.targetHeading = desiredHeading;

      const desiredSpeed = clamp(
        length(desiredX, desiredY),
        species.minSpeed,
        species.maxSpeed * (0.82 + bird.restlessness * 0.22)
      );
      const acceleration = species.behavior === 'burst'
        ? 118 / Math.sqrt(species.mass + 0.04)
        : 64 / Math.sqrt(species.mass + 0.06);
      bird.airspeed = approach(
        bird.airspeed ?? length(bird.vx, bird.vy),
        desiredSpeed,
        acceleration * safeDt
      );

      const bankTarget = clamp(
        maxTurn > 0 ? (limitedTurn / maxTurn) * species.maxBank : 0,
        -species.maxBank,
        species.maxBank
      );
      bird.bank += (bankTarget - (bird.bank || 0)) * clamp(safeDt * 5.2, 0, 1);

      const liftRatio = clamp((bird.airspeed - species.minSpeed) / Math.max(1, species.maxSpeed - species.minSpeed), 0, 1);
      const wingAreaProxy = Math.max(1, (species.wingSpan * species.wingSpan) / Math.max(1.2, species.wingAspect || 5.5));
      const wingLoading = species.mass / wingAreaProxy;
      const downstroke = Math.max(0, -Math.sin(bird.wingPhase));
      const upstroke = Math.max(0, Math.sin(bird.wingPhase));
      const gravity = species.behavior === 'hover' ? 4.5 : 15.5 + wingLoading * 12800;
      const glideEfficiency = species.behavior === 'soar'
        ? 1.55
        : species.behavior === 'glide'
          ? 1.22
          : 0.86;
      const dynamicLift = liftRatio * species.lift * glideEfficiency * 17;
      const strokeLift = Math.pow(downstroke, 1.55)
        * species.lift
        * (species.behavior === 'hover' ? 27 : 9.5)
        * (0.72 + liftRatio * 0.52);
      const liftPulse = (downstroke - upstroke * 0.34) * species.lift;
      const hoverHold = species.behavior === 'hover'
        ? Math.sin(time * 8.2 + bird.liftPhase) * 6.5
        : 0;
      const liftForce = dynamicLift + strokeLift;
      const liftOffset = gravity - liftForce + hoverHold;
      bird.sinkRate = liftOffset;
      bird.liftForce = liftForce;
      bird.vx = Math.cos(bird.heading) * bird.airspeed + wind * 7;
      bird.vy = Math.sin(bird.heading) * bird.airspeed + liftOffset;

      bird.x += bird.vx * safeDt;
      bird.y += bird.vy * safeDt;
      bird.age += safeDt;
      const baseFlapHz = species.flapHz || 5.0;
      const flapHz = species.behavior === 'soar'
        ? baseFlapHz * (liftRatio > 0.38 ? 0.28 : 0.64)
        : species.behavior === 'glide'
          ? baseFlapHz * 0.56
          : baseFlapHz * (0.72 + liftRatio * 0.42);
      bird.flapHz = flapHz;
      bird.wingStroke = liftPulse;
      bird.wingPhase += safeDt * flapHz * Math.PI * 2;
    }
    return birds;
  }

  const api = {
    clamp,
    mulberry32,
    hashString,
    normalizeAngle,
    signedAngleDelta,
    approach,
    pointInPolygon,
    polygonCentroid,
    zoneToPixels,
    randomPointInZone,
    speciesCatalog,
    birdCountForZone,
    createBirdState,
    rebuildBirdsForZones,
    stepFlock
  };

  global.BirdFlockMath = api;
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  }
}(typeof window !== 'undefined' ? window : globalThis));
