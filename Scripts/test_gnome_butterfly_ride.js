#!/usr/bin/env node

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..');
const context = {
  console,
  window: null,
  self: null,
  document: {
    createElement() {
      return {
        width: 1,
        height: 1,
        getContext() {
          return {
            createImageData(width, height) {
              return { data: new Uint8ClampedArray(width * height * 4) };
            },
            putImageData() {}
          };
        }
      };
    }
  }
};
context.window = context;
context.self = context;
context.globalThis = context;
vm.createContext(context);

for (const file of [
  'Sources/PlantWallpaper/WebAssets/cat/three.min.js',
  'Sources/PlantWallpaper/WebAssets/gnomes/zone.js',
  'Sources/PlantWallpaper/WebAssets/gnomes/emergence.js'
]) {
  vm.runInContext(fs.readFileSync(path.join(root, file), 'utf8'), context, { filename: file });
}

const polygon = [
  { x: -70, z: -55 },
  { x: 70, z: -55 },
  { x: 72, z: 55 },
  { x: -70, z: 55 }
];
const plantTargets = [
  { id: 'foxglove', x: 105, z: -18, resourceValue: 0.74, canopyHeight: 0.22, sampleColor: 0xff82c0, species: 'Foxglove' },
  { id: 'maple', x: 126, z: 34, resourceValue: 0.92, canopyHeight: 0.38, sampleColor: 0xa66b32, species: 'Japanese Maple' }
];
const butterfly = {
  id: 'butterfly-maple-loop',
  x: 76,
  z: -4,
  kind: 'butterfly',
  allowOutside: true,
  resourceValue: 0.88,
  flightHeight: 58,
  wingColor: 0xffc35f,
  circuitRadius: 44,
  plantTargets
};

const routing = context.createTownRouting({
  bounds: context.polygonBounds(polygon),
  polygon,
  plaza: { x: 0, z: 0 },
  homes: [{ x: -24, z: 20 }],
  works: [{ x: 22, z: -20 }],
  wells: [{ x: -22, z: -18 }],
  plantPOIs: [],
  expeditionPlants: plantTargets.map(plant => ({ ...plant, kind: 'expeditionPlant', allowOutside: true, canClimb: true })),
  butterflyPOIs: [butterfly],
  explorationBounds: { minX: -180, maxX: 180, minZ: -130, maxZ: 130 },
  simulation: {
    behaviorLiveliness: 1.2,
    cooperationMultiplier: 1.0,
    plantInteractionMultiplier: 1.0
  },
  dailyRoutine: {
    sleepBias: 0,
    buildBias: 0.4,
    socialBias: 0.4,
    forageBias: 1
  },
  rng: (() => {
    const values = [0.21, 0.44, 0.11, 0.63, 0.29, 0.76, 0.18, 0.54, 0.33, 0.82];
    let index = 0;
    return () => values[index++ % values.length];
  })()
});

const gnome = {
  role: 'idle',
  x: butterfly.x - 2,
  z: butterfly.z - 1,
  heading: 0,
  butterflyRider: true
};
routing.assign(gnome);
gnome.x = butterfly.x - 2;
gnome.z = butterfly.z - 1;
gnome.goal = butterfly;
gnome.route = [butterfly];
gnome.routeIndex = 0;
gnome.dwell = 0;
gnome.missionPhase = 'butterflySeek';
gnome.missionTarget = butterfly;
gnome.action = 'walk';

routing.stepGnome(gnome, 1 / 30, () => {});
assert.equal(gnome.missionPhase, 'butterflyMount', 'arrival should begin the butterfly mounting phase');
assert.equal(gnome.action, 'butterflyMount', 'gnome should use a dedicated mounting pose');
assert.ok(gnome.butterflyFlightPlan && gnome.butterflyFlightPlan.points.length >= 5, 'ride should build a plant-aware flight plan');

const seen = new Set([gnome.missionPhase]);
let maxHeight = 0;
let farthestFromPlaza = 0;
let sawBehindCue = false;
let released = false;
let walkingDeposits = 0;

for (let i = 0; i < 2400; i += 1) {
  routing.stepGnome(gnome, 1 / 30, (x, z, amount) => {
    if (amount > 0) walkingDeposits += 1;
  });
  if (gnome.missionPhase) seen.add(gnome.missionPhase);
  maxHeight = Math.max(maxHeight, gnome.ziplineHeight || 0);
  farthestFromPlaza = Math.max(farthestFromPlaza, Math.hypot(gnome.x, gnome.z));
  sawBehindCue = sawBehindCue || (gnome.butterflyDepthCue || 0) < 0;
  if (!gnome.missionPhase && gnome.action !== 'butterflyRide') {
    released = true;
    break;
  }
}

for (const phase of ['butterflyMount', 'butterflyLaunch', 'butterflyRide', 'butterflyReturn', 'butterflyRelease']) {
  assert.ok(seen.has(phase), `butterfly mission should include ${phase}`);
}
assert.ok(maxHeight > 45, `butterfly should visibly carry the gnome into the air, maxHeight=${maxHeight}`);
assert.ok(farthestFromPlaza > 90, `ride should leave the colony and inspect surrounding plants, farthest=${farthestFromPlaza}`);
assert.ok(sawBehindCue, 'flight plan should include a behind-plant depth cue');
assert.ok(released, 'gnome should return to the colony and release the butterfly');
assert.ok(walkingDeposits < 30, 'airborne riding should not grind heavy ground paths while flying');

console.log('gnome butterfly ride ok');
