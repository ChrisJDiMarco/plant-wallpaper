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

const behavior = fs.readFileSync(path.join(catDir, 'cat-behavior.js'), 'utf8');
const anim = fs.readFileSync(path.join(catDir, 'cat-anim.js'), 'utf8');

assert.ok(
  behavior.includes("const MOUSE_STRIKE_STATES"),
  'mouse hunting should have an explicit strike-state set'
);
assert.ok(
  behavior.includes("case 'mouseProbe'") && behavior.includes("case 'mouseFeint'"),
  'cat behavior should include tentative paw probes and fake-out feints'
);
assert.ok(
  behavior.includes('function chooseMouseStrike(dist)'),
  'cat behavior should choose among varied cursor hunting actions'
);
assert.ok(
  behavior.includes('function mouseLungeStyle(dist)'),
  'cat behavior should style cursor lunges by cursor height and motion'
);
assert.ok(
  behavior.includes('lastMouseStrike') && behavior.includes('mouseStrikeStreak'),
  'cat behavior should downweight repeated mouse strikes for natural variation'
);
for (const style of ['highGrab', 'sideSwipe', 'lowPounce', 'hookGrab']) {
  assert.ok(behavior.includes(style), `behavior should be able to request ${style} lunges`);
  assert.ok(anim.includes(style), `animator should render ${style} lunges`);
}
for (const style of ['probe', 'hook', 'crossBat', 'sidePounce']) {
  assert.ok(anim.includes(style), `animator should render ${style} cursor-play style`);
}
assert.ok(
  anim.includes('triggerSwipe(alternatePaw, style)'),
  'swipe trigger should accept a visual style'
);
assert.ok(
  anim.includes('triggerLunge(duration, style)'),
  'lunge trigger should accept a visual style'
);
assert.ok(
  anim.includes('triggerPounce(style)'),
  'pounce trigger should accept a visual style'
);
assert.ok(
  behavior.includes("state.name !== 'mouseProbe'"),
  'clean-catch window should stay armed during mouseProbe swats'
);

console.log('cat mouse hunt variation guards ok');
