#!/usr/bin/env node

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const catDir = path.join(__dirname, '..', 'Sources', 'PlantWallpaper', 'WebAssets', 'cat');
const animPath = path.join(catDir, 'cat-anim.js');
const behaviorPath = path.join(catDir, 'cat-behavior.js');
const modelPath = path.join(catDir, 'cat-model.js');

const animSource = fs.readFileSync(animPath, 'utf8');
const behaviorSource = fs.readFileSync(behaviorPath, 'utf8');
const modelSource = fs.readFileSync(modelPath, 'utf8');

const context = { console };
vm.createContext(context);
vm.runInContext(`${animSource}\nglobalThis.CatAnim = CatAnim;`, context);
vm.runInContext(`${modelSource}\nglobalThis.CatModel = CatModel;`, context);

const requiredPoses = [
  'groomPaw',
  'groomFace',
  'groomFlank',
  'groomBelly',
  'groomTail',
  'groomHaunch'
];
for (const pose of requiredPoses) {
  assert.ok(context.CatAnim.POSES[pose], `CatAnim should expose ${pose}`);
  assert.match(behaviorSource, new RegExp(`case '${pose}'`), `behavior should enter ${pose}`);
}

const spec = context.CatModel.FACE_DETAIL_SPEC;
assert.equal(spec.realisticTongue, true, 'cat model should declare the tongue fidelity detail');
assert.deepEqual(
  Array.from(spec.groomingTargets),
  ['paw', 'face', 'flank', 'belly', 'tail', 'haunch'],
  'grooming target list should cover the whole body'
);

assert.match(modelSource, /tongueGroup\.visible = false/, 'tongue should idle hidden until lick strokes');
assert.match(modelSource, /tongueTip/, 'tongue should include a rounded tip mesh');
assert.match(animSource, /function applyGrooming/, 'animator should have a grooming overlay');
assert.match(animSource, /setTongue\(lick > 0\.08/, 'lick cycle should reveal tongue only during strokes');
assert.match(animSource, /rig\.tongue/, 'animator should drive the model tongue rig');
assert.match(behaviorSource, /chooseGroomingState\('afterBug'\)/, 'bug eating should transition to cleanup');
assert.match(behaviorSource, /chooseGroomingState\('afterPet'\)/, 'petting should sometimes transition to grooming');
assert.match(behaviorSource, /chooseGroomingState\('afterBellyPet'\)/, 'belly petting should sometimes transition to belly grooming');

console.log('cat grooming behavior spec ok');
