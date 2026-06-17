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
  'Sources/PlantWallpaper/WebAssets/gnomes/projection.js',
  'Sources/PlantWallpaper/WebAssets/gnomes/zone.js',
  'Sources/PlantWallpaper/WebAssets/gnomes/emergence.js'
]) {
  vm.runInContext(fs.readFileSync(path.join(root, file), 'utf8'), context, { filename: file });
}

const { THREE, GnomeProjection } = context;
assert.ok(GnomeProjection, 'gnome projection helpers should be available to main.js');

const width = 1600;
const height = 900;
const HZ = 300;
const FOV = 46;
const CAM_FIT = 1.16;
const HX = HZ * (width / height);

function makeCamera({ elevationDegrees, yawDegrees }) {
  const camera = new THREE.PerspectiveCamera(FOV, width / height, 1, 6000);
  const radius = Math.max(HX, HZ * 1.3);
  const dist = (radius / Math.tan((FOV * Math.PI / 180) / 2)) * CAM_FIT;
  const elev = elevationDegrees * Math.PI / 180;
  const yaw = yawDegrees * Math.PI / 180;
  const horizontalDist = Math.cos(elev) * dist;
  camera.position.set(
    Math.sin(yaw) * horizontalDist,
    Math.sin(elev) * dist,
    Math.cos(yaw) * horizontalDist + HZ * 0.2
  );
  camera.lookAt(0, 6, 0);
  camera.updateProjectionMatrix();
  camera.updateMatrixWorld(true);
  return camera;
}

for (const perspective of [
  { elevationDegrees: 42, yawDegrees: 0 },
  { elevationDegrees: 35, yawDegrees: 28 },
  { elevationDegrees: 58, yawDegrees: -32 }
]) {
  const camera = makeCamera(perspective);
  for (const screenPoint of [
    { x: 0.18, y: 0.78 },
    { x: 0.82, y: 0.68 },
    { x: 0.50, y: 0.42 }
  ]) {
    const ground = GnomeProjection.groundPointFromNormalized(screenPoint, camera, HX, HZ);
    const projected = new THREE.Vector3(ground.x, 0, ground.z).project(camera);
    const roundTrip = {
      x: (projected.x + 1) / 2,
      y: (1 - projected.y) / 2
    };

    assert.ok(
      Math.abs(roundTrip.x - screenPoint.x) < 0.00001,
      `projected x ${roundTrip.x} should match drawn x ${screenPoint.x} at ${JSON.stringify(perspective)}`
    );
    assert.ok(
      Math.abs(roundTrip.y - screenPoint.y) < 0.00001,
      `projected y ${roundTrip.y} should match drawn y ${screenPoint.y} at ${JSON.stringify(perspective)}`
    );
  }
}

const lShape = [
  { x: -80, z: -80 },
  { x: 80, z: -80 },
  { x: 80, z: -20 },
  { x: -20, z: -20 },
  { x: -20, z: 80 },
  { x: -80, z: 80 }
];
const bounds = context.polygonBounds(lShape);
const routing = context.createTownRouting({
  bounds,
  polygon: lShape,
  plaza: { x: -55, z: 55 },
  homes: [{ x: -55, z: 55 }],
  works: [{ x: 55, z: -55 }],
  wells: [],
  rng: (() => {
    const values = [0.0, 0.2, 0.4, 0.6, 0.8];
    let index = 0;
    return () => values[index++ % values.length];
  })()
});
const gnome = { role: 'build', x: -55, z: 55, work: { x: 55, z: -55 } };
routing.assign(gnome);
for (let i = 0; i < 180; i += 1) {
  routing.stepGnome(gnome, 1 / 30, () => {});
  assert.ok(
    context.pointInPolygon(gnome.x, gnome.z, lShape),
    `gnome should remain inside drawn polygon, got ${gnome.x}, ${gnome.z}`
  );
}

console.log('gnome zone projection and containment ok');
