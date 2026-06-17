#!/usr/bin/env node

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.join(__dirname, '..');
const context = {
  console,
  window: null,
  self: null
};
context.window = context;
context.self = context;
context.globalThis = context;
vm.createContext(context);

vm.runInContext(
  fs.readFileSync(path.join(root, 'Sources/PlantWallpaper/WebAssets/cat/three.min.js'), 'utf8'),
  context,
  { filename: 'three.min.js' }
);

context.texturedMat = function texturedMat(colorHex, kind, options = {}) {
  const material = new context.THREE.MeshStandardMaterial({
    color: colorHex,
    roughness: options.roughness ?? 0.82,
    metalness: options.metalness ?? 0,
    emissive: options.emissive ?? 0x000000,
    emissiveIntensity: options.emissiveIntensity ?? 0,
    transparent: !!options.transparent,
    opacity: options.opacity ?? 1
  });
  material.userData.gnomeDisposableMaterial = true;
  material.userData.kind = kind;
  return material;
};

for (const file of [
  'Sources/PlantWallpaper/WebAssets/gnomes/detail.js',
  'Sources/PlantWallpaper/WebAssets/gnomes/buildsite.js'
]) {
  vm.runInContext(fs.readFileSync(path.join(root, file), 'utf8'), context, { filename: file });
}

const site = context.makeBuildSite({ type: 'cabin', seed: 42, scale: 1 });
assert.ok(site, 'makeBuildSite should create a construction site');

const stages = [
  [0.02, 'Survey & Supplies'],
  [0.16, 'Excavation & Footings'],
  [0.26, 'Foundation'],
  [0.48, 'Frame & Scaffold'],
  [0.64, 'Wall Raising'],
  [0.78, 'Roofing'],
  [0.90, 'Finish Trim'],
  [0.99, 'Move-In Details']
];

for (const [progress, expected] of stages) {
  assert.equal(site.stageName(progress), expected, `stageName(${progress}) should be ${expected}`);
}

for (const name of [
  'surveyFlags',
  'excavationFootings',
  'joineryPins',
  'roofWeathering',
  'finishTrim',
  'moveInDetails'
]) {
  assert.ok(site.group.getObjectByName(name), `build site should include ${name}`);
}

site.setProgress(0.99, 12);
assert.equal(site.constructionStats(0.99).stageName, 'Move-In Details');
assert.equal(site.constructionStats(0.99).isHabitable, true);

const materials = fs.readFileSync(
  path.join(root, 'Sources/PlantWallpaper/WebAssets/gnomes/materials.js'),
  'utf8'
);
for (const materialKind of ['leaf:', 'petal:', 'soil:', 'moss:']) {
  assert.ok(materials.includes(materialKind), `materials kit should include ${materialKind}`);
}

const main = fs.readFileSync(
  path.join(root, 'Sources/PlantWallpaper/WebAssets/gnomes/main.js'),
  'utf8'
);
assert.ok(main.includes('function constructionActionForStage'), 'main renderer should map build stages to gnome actions');
assert.ok(main.includes('bs.site.constructionStats'), 'main renderer should read build-site construction stats');

console.log('gnome construction fidelity ok');
