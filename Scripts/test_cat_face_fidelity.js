#!/usr/bin/env node

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const modelPath = path.join(
  __dirname,
  '..',
  'Sources',
  'PlantWallpaper',
  'WebAssets',
  'cat',
  'cat-model.js'
);
const source = fs.readFileSync(modelPath, 'utf8');
const context = { console };
vm.createContext(context);
vm.runInContext(`${source}\nglobalThis.CatModel = CatModel;`, context);

const spec = context.CatModel.FACE_DETAIL_SPEC;
assert.ok(spec, 'CatModel should expose a face detail fidelity spec');
assert.equal(spec.eyeTextureSize >= 192, true, 'eye texture should be higher resolution than the old 128px iris');
assert.equal(spec.whiskersPerSide >= 5, true, 'each cheek should have a fuller whisker fan');
assert.equal(spec.whiskerLengthVariance, true, 'whiskers should use varied lengths instead of identical rods');
assert.equal(spec.whiskerRoots, true, 'whiskers should have visible root dots in the muzzle pad');
assert.equal(spec.cheekPads, true, 'face should include cheek/muzzle pads');
assert.equal(spec.eyelidRims, true, 'eyes should include eyelid rims');
assert.equal(spec.noseBridge, true, 'nose should include a bridge plane or ridge');
assert.equal(spec.mouthLine, true, 'muzzle should include subtle mouth line detail');
assert.equal(spec.realisticTongue, true, 'model should include a hidden tongue rig for grooming lick strokes');
assert.deepEqual(
  Array.from(spec.groomingTargets),
  ['paw', 'face', 'flank', 'belly', 'tail', 'haunch'],
  'grooming targets should cover the whole body'
);

console.log('cat face fidelity spec ok');
