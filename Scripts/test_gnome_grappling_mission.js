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

const villagePolygon = [
  { x: -60, z: -60 },
  { x: 60, z: -60 },
  { x: 60, z: 60 },
  { x: -60, z: 60 }
];
const target = {
  id: 'tall-maple',
  x: 128,
  z: 12,
  kind: 'expeditionPlant',
  resourceValue: 0.96,
  canClimb: true,
  canopyHeight: 0.42,
  sampleColor: 0xa66b32,
  allowOutside: true
};

const routing = context.createTownRouting({
  bounds: context.polygonBounds(villagePolygon),
  polygon: villagePolygon,
  plaza: { x: 0, z: 0 },
  homes: [{ x: -18, z: 18 }],
  works: [{ x: 24, z: -16 }],
  wells: [{ x: -24, z: -18 }],
  plantPOIs: [],
  expeditionPlants: [target],
  explorationBounds: { minX: -180, maxX: 180, minZ: -130, maxZ: 130 },
  simulation: {
    behaviorLiveliness: 1.2,
    cooperationMultiplier: 1.0,
    plantInteractionMultiplier: 1.0
  },
  dailyRoutine: {
    sleepBias: 0,
    buildBias: 0.5,
    socialBias: 0.2,
    forageBias: 1
  },
  rng: (() => {
    const values = [0.31, 0.57, 0.12, 0.84, 0.26, 0.68, 0.41, 0.09, 0.74];
    let index = 0;
    return () => values[index++ % values.length];
  })()
});

const gnome = { role: 'carry', x: target.x - 2, z: target.z - 1, heading: 0 };
routing.assign(gnome);
gnome.x = target.x - 2;
gnome.z = target.z - 1;
gnome.goal = target;
gnome.route = [target];
gnome.routeIndex = 0;
gnome.dwell = 0;
gnome.missionPhase = 'depart';
gnome.missionTarget = target;
gnome.action = 'walk';

routing.stepGnome(gnome, 1 / 30, () => {});
assert.equal(gnome.missionPhase, 'grappleAim', 'arrival should start a visible aiming phase');
assert.equal(gnome.action, 'grappleAim', 'arrival should pose the gnome as aiming the hook');
assert.ok(gnome.grappleAnchor && gnome.grappleAnchor.y > 80, 'tall plant should create a high grapple anchor');

const seen = new Set([gnome.missionPhase]);
let maxHeight = 0;
let delivered = false;

for (let i = 0; i < 2400; i += 1) {
  routing.stepGnome(gnome, 1 / 30, () => {});
  if (gnome.missionPhase) seen.add(gnome.missionPhase);
  maxHeight = Math.max(maxHeight, gnome.ziplineHeight || 0);
  if ((gnome.deliveredSamples || 0) > 0) {
    delivered = true;
    break;
  }
}

for (const phase of ['grappleAim', 'grappleShoot', 'ziplineUp', 'canopyInspect', 'extractTap', 'sampleBundle', 'rappelDown', 'return']) {
  assert.ok(seen.has(phase), `mission should include ${phase}`);
}
assert.ok(maxHeight > 50, `zipline should visibly lift the gnome, maxHeight=${maxHeight}`);
assert.ok(gnome.resourceCollectionPlan, 'gnome should keep a fieldwork plan for the plant resource');
assert.equal(gnome.resourceCollectionProgress, 1, 'resource collection should finish before delivery');
assert.ok(delivered, 'gnome should bring the collected sample back to the village depot');
assert.equal(gnome.sampleCarried, false, 'sample should be unpacked at the depot after delivery');

console.log('gnome grappling mission ok');
