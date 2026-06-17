#!/usr/bin/env node

const assert = require('assert');
const flock = require('../Sources/PlantWallpaper/WebAssets/birds/flock.js');

const species = flock.speciesCatalog();
assert.strictEqual(species.length, 10, 'bird catalog should expose ten species');
assert(species.some((entry) => entry.name === 'Ruby-throated Hummingbird'), 'hummingbird species missing');
assert(species.some((entry) => entry.name === 'Red-tailed Hawk'), 'hawk species missing');
for (const entry of species) {
  assert(entry.wingSpan > 0, `${entry.name} should expose a wingspan for flight physics`);
  assert(entry.mass > 0, `${entry.name} should expose a mass for flight physics`);
  assert(entry.turnRate > 0, `${entry.name} should expose a turn-rate limit`);
  assert(entry.maxBank > 0, `${entry.name} should expose a bank limit`);
}

const zone = {
  id: 'sky-test',
  skySeed: 123,
  points: [
    { x: 50, y: 50 },
    { x: 250, y: 50 },
    { x: 250, y: 160 },
    { x: 50, y: 160 }
  ],
  centroid: { x: 150, y: 105 },
  bounds: { minX: 50, minY: 50, maxX: 250, maxY: 160 }
};

assert(flock.pointInPolygon({ x: 120, y: 90 }, zone.points), 'inside point should be inside polygon');
assert(!flock.pointInPolygon({ x: 20, y: 90 }, zone.points), 'outside point should be outside polygon');

const rebuilt = flock.rebuildBirdsForZones([zone], 500, 300);
assert(rebuilt.length >= 4, 'zone should create a small flock');
assert(rebuilt.length <= 18, 'zone should cap flock size');

const outsideBird = {
  ...flock.createBirdState(zone, 0, 500, 300),
  x: 330,
  y: 260,
  vx: 0,
  vy: 0
};
const beforeDistance = Math.hypot(outsideBird.x - zone.centroid.x, outsideBird.y - zone.centroid.y);
flock.stepFlock([outsideBird], [zone], 0.5, { windStrength: 0.5, time: 10 });
const afterDistance = Math.hypot(outsideBird.x - zone.centroid.x, outsideBird.y - zone.centroid.y);
assert(afterDistance < beforeDistance, 'outside bird should steer back toward its sky zone');

const leftBird = {
  ...flock.createBirdState(zone, 1, 500, 300),
  x: 120,
  y: 90,
  vx: 0,
  vy: 0
};
const rightBird = {
  ...flock.createBirdState(zone, 2, 500, 300),
  x: 124,
  y: 90,
  vx: 0,
  vy: 0
};
const beforeSeparation = Math.hypot(leftBird.x - rightBird.x, leftBird.y - rightBird.y);
for (let tick = 0; tick < 8; tick += 1) {
  flock.stepFlock([leftBird, rightBird], [zone], 0.06, { windStrength: 0.5, time: 12 + tick * 0.06 });
}
const afterSeparation = Math.hypot(leftBird.x - rightBird.x, leftBird.y - rightBird.y);
assert(afterSeparation > beforeSeparation, 'close birds should separate instead of stacking');

const swallow = species.findIndex((entry) => entry.name === 'Barn Swallow');
const turningBird = {
  ...flock.createBirdState(zone, 3, 500, 300),
  speciesIndex: swallow,
  x: 245,
  y: 150,
  vx: 90,
  vy: 0,
  heading: 0,
  airspeed: 90,
  bank: 0
};
flock.stepFlock([turningBird], [zone], 0.25, { windStrength: 0.5, time: 18 });
assert(Number.isFinite(turningBird.bank), 'bank should stay finite');
assert(Math.abs(turningBird.bank) <= species[swallow].maxBank + 0.001, 'bank should obey species bank limit');
assert(Math.abs(turningBird.heading) < Math.PI * 0.8, 'turn-rate limiter should prevent instant heading flips');

const hawk = species.findIndex((entry) => entry.name === 'Red-tailed Hawk');
const glider = {
  ...flock.createBirdState(zone, 4, 500, 300),
  speciesIndex: hawk,
  x: 150,
  y: 105,
  vx: 40,
  vy: 0,
  heading: 0,
  airspeed: 40,
  bank: 0,
  wingPhase: 0
};
flock.stepFlock([glider], [zone], 0.4, { windStrength: 0.5, time: 24 });
assert(glider.wingPhase < 4.0, 'soaring birds should flap slowly instead of jittering');

const escapee = {
  ...flock.createBirdState(zone, 5, 500, 300),
  x: 460,
  y: 260,
  vx: 180,
  vy: 90,
  heading: 0.4,
  airspeed: 201,
  bank: 0
};
const beforeX = escapee.x;
const beforeY = escapee.y;
flock.stepFlock([escapee], [zone], 0.25, { windStrength: 0.5, time: 30 });
const travel = Math.hypot(escapee.x - beforeX, escapee.y - beforeY);
assert(travel < 80, 'containment should steer strongly without teleporting birds across the desktop');
assert(Math.hypot(escapee.x - zone.centroid.x, escapee.y - zone.centroid.y) < Math.hypot(beforeX - zone.centroid.x, beforeY - zone.centroid.y), 'escapee should move back toward the sky zone');

console.log('bird flock logic ok');
