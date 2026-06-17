#!/usr/bin/env node

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const catDir = path.join(
  __dirname,
  '..',
  'Sources',
  'PlantWallpaper',
  'WebAssets',
  'cat'
);

const main = fs.readFileSync(path.join(catDir, 'main.js'), 'utf8');
const anim = fs.readFileSync(path.join(catDir, 'cat-anim.js'), 'utf8');

assert.ok(
  main.includes('SURFACE_FOLLOW_RATE'),
  'main.js should damp the cropped canvas follow position instead of snapping every frame'
);
assert.ok(
  main.includes('surfaceDisplayX = damp(surfaceDisplayX, targetX, SURFACE_FOLLOW_RATE, dt)'),
  'cat canvas x-offset should use damped follow motion'
);
assert.ok(
  main.includes('surfaceDisplayY = damp(surfaceDisplayY, targetY, SURFACE_FOLLOW_RATE, dt)'),
  'cat canvas y-offset should use damped follow motion'
);
assert.ok(
  main.includes('MAX_ACTIVE_DT') && main.includes('Math.min(accumulator, maxFrameDt)'),
  'active cat simulation should clamp large frame deltas'
);

assert.ok(
  anim.includes('rawVelocity: new THREE.Vector3()'),
  'cat animator should keep raw velocity separate from smoothed velocity'
);
assert.ok(
  anim.includes('state.velocity.lerp(state.rawVelocity, Math.min(1, dt * 10))'),
  'cat animator should smooth velocity before it drives fur, whiskers, and neck lag'
);
assert.ok(
  anim.includes('state.hasPrevRootPos'),
  'cat animator should suppress first-frame derivative spikes'
);

console.log('cat motion smoothing guards ok');
