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

const lShape = [
  { x: -90, z: -90 },
  { x: 90, z: -90 },
  { x: 90, z: -30 },
  { x: -30, z: -30 },
  { x: -30, z: 90 },
  { x: -90, z: 90 }
];
const bounds = context.polygonBounds(lShape);
const routing = context.createTownRouting({
  bounds,
  polygon: lShape,
  plaza: { x: -62, z: 52 },
  homes: [{ x: -62, z: 52 }],
  works: [{ x: 62, z: -62 }],
  wells: [{ x: -62, z: -62 }],
  plantPOIs: [{ id: 'lavender', x: -52, z: -42, resourceValue: 0.8, canClimb: false }],
  simulation: {
    behaviorLiveliness: 1.1,
    cooperationMultiplier: 1.2,
    plantInteractionMultiplier: 1.0
  },
  dailyRoutine: {
    sleepBias: 0,
    buildBias: 1,
    socialBias: 0.2,
    forageBias: 0.4
  },
  rng: (() => {
    const values = [0.42, 0.18, 0.72, 0.31, 0.56, 0.08, 0.64, 0.27, 0.91];
    let index = 0;
    return () => values[index++ % values.length];
  })()
});

const gnome = { role: 'build', x: -62, z: 52, work: { x: 62, z: -62 } };
routing.assign(gnome);

const destination = { x: 62, z: -62, kind: 'work' };
const route = routing.planRouteForTesting(gnome, destination);
assert.ok(route.length >= 2, 'concave habitat should route through at least one interior waypoint');

let from = { x: gnome.x, z: gnome.z };
for (const waypoint of route) {
  assert.ok(
    routing.segmentInsideForTesting(from, waypoint),
    `route segment ${JSON.stringify(from)} -> ${JSON.stringify(waypoint)} should stay inside the drawn zone`
  );
  from = waypoint;
}

gnome.goal = destination;
gnome.route = route;
gnome.routeIndex = 0;
gnome.dwell = 0;
gnome.mind = null;

let maxStuck = 0;
let arrivedAtWork = false;
for (let i = 0; i < 620; i += 1) {
  routing.stepGnome(gnome, 1 / 30, () => {});
  maxStuck = Math.max(maxStuck, gnome.stuckScore || 0);
  assert.ok(
    context.pointInPolygon(gnome.x, gnome.z, lShape),
    `gnome should remain inside its drawn living area, got ${gnome.x.toFixed(2)}, ${gnome.z.toFixed(2)}`
  );
  if (gnome.dwell > 0 && gnome.action === 'build') arrivedAtWork = true;
  if (arrivedAtWork) break;
}

assert.ok(arrivedAtWork, 'gnome should reach the work site and start purposeful build behavior');
assert.ok(maxStuck < 1.2, `gnome should not look stuck against a boundary, saw stuckScore ${maxStuck}`);
assert.ok(gnome.mind && gnome.mind.intent, 'gnome should maintain a lightweight intent/mind state');

console.log('gnome intelligent routing ok');
