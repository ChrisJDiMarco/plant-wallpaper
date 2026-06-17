#!/usr/bin/env node

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const main = fs.readFileSync(
  path.join(root, 'Sources/PlantWallpaper/WebAssets/gnomes/main.js'),
  'utf8'
);
const buildsite = fs.readFileSync(
  path.join(root, 'Sources/PlantWallpaper/WebAssets/gnomes/buildsite.js'),
  'utf8'
);

for (const required of [
  'gnome-village-v4-resource-city-growth',
  'function settlementLifecycle',
  'function applySettlementLifecycle',
  'finishedFraction',
  'resourceMaturity',
  'borrowBoost',
  'resourceGate',
  'campOnly',
  'function makeResourceYard',
  'gnomeResourceYard',
  'rawResourcePile',
  'woodPile',
  'plantSampleCrates',
  'tunnelBorrowDepot',
  'interColonySupplyCart',
  'function makeCityUpgradeLayer',
  'gnomeCityUpgradeLayer',
  'verticalUpgradeTier',
  'gnomeAerialWalkway',
  'lifecycle.initialBuildProgress',
  'lifecycle.initialBuildCap'
]) {
  assert.ok(main.includes(required), `main gnome renderer should include ${required}`);
}

assert.ok(
  main.includes('if (lifecycle.campOnly) finishedTarget = 0'),
  'new colonies should force all sites into resource-pile/build-site mode'
);
assert.ok(
  main.includes('description.props = description.props.slice(0, propLimit)'),
  'new colonies should not spawn finished village props before the camp matures'
);
assert.ok(
  main.includes('site.settlementStage = lifecycle.campOnly ?'),
  'build sites should be tagged as primitive resource piles during the camp phase'
);
assert.ok(
  main.includes('village.collectionDepot.group.visible = lifecycle.depotOpen'),
  'the finished sample depot should stay hidden until the colony matures'
);
assert.ok(
  main.includes('const resourceGate = clamp((bs.resourceGate || 0.2)'),
  'construction speed should be gated by resources and borrowed supplies'
);

for (const buildStage of [
  'Survey & Supplies',
  'Excavation & Footings',
  'Frame & Scaffold',
  'Move-In Details'
]) {
  assert.ok(buildsite.includes(buildStage), `buildsite lifecycle should keep ${buildStage}`);
}

console.log('gnome colony lifecycle ok');
