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
  { x: -90, z: -90 },
  { x: 90, z: -90 },
  { x: 90, z: 90 },
  { x: -90, z: 90 }
];
const bounds = context.polygonBounds(polygon);
const routing = context.createTownRouting({
  bounds,
  polygon,
  plaza: { x: 0, z: 0 },
  homes: [{ x: -20, z: 0 }, { x: 20, z: 0 }],
  works: [{ x: 72, z: 0 }],
  wells: [{ x: 0, z: -50 }],
  simulation: { behaviorLiveliness: 1.0, cooperationMultiplier: 1.0, plantInteractionMultiplier: 0 },
  dailyRoutine: { sleepBias: 0, buildBias: 1, socialBias: 0.2, forageBias: 0 },
  rng: (() => {
    const values = [0.37, 0.63, 0.22, 0.81, 0.44, 0.12];
    let index = 0;
    return () => values[index++ % values.length];
  })()
});

const a = { role: 'build', x: -1.1, z: 0, work: { x: 72, z: 0 } };
const b = { role: 'build', x: 1.1, z: 0, work: { x: 72, z: 0 } };
routing.assign(a);
routing.assign(b);

const sharedGoal = { x: 72, z: 0, kind: 'work' };
for (const gnome of [a, b]) {
  gnome.goal = sharedGoal;
  gnome.route = routing.planRouteForTesting(gnome, sharedGoal);
  gnome.routeIndex = 0;
  gnome.dwell = 0;
}

const startDistance = Math.hypot(a.x - b.x, a.z - b.z);
for (let i = 0; i < 75; i += 1) {
  routing.stepGnome(a, 1 / 30, () => {});
  routing.stepGnome(b, 1 / 30, () => {});
}
const endDistance = Math.hypot(a.x - b.x, a.z - b.z);

assert.ok(endDistance > startDistance + 1.4, `gnomes should preserve personal space, ${startDistance.toFixed(2)} -> ${endDistance.toFixed(2)}`);
assert.ok(a.mind && b.mind, 'socially aware routing should maintain gnome minds');
assert.ok(context.pointInPolygon(a.x, a.z, polygon) && context.pointInPolygon(b.x, b.z, polygon), 'social steering should stay inside the zone');

console.log('gnome social awareness ok');
