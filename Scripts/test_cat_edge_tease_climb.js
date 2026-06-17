#!/usr/bin/env node

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const behaviorPath = path.join(
  __dirname,
  '..',
  'Sources',
  'PlantWallpaper',
  'WebAssets',
  'cat',
  'cat-behavior.js'
);

const source = fs.readFileSync(behaviorPath, 'utf8');
const context = {
  console,
  THREE: {
    MathUtils: {
      clamp(value, min, max) {
        return Math.min(max, Math.max(min, value));
      }
    }
  }
};
vm.createContext(context);
vm.runInContext(`${source}\nglobalThis.CatBehavior = CatBehavior;`, context);

function makeAnimator() {
  return {
    state: {
      speed: 0,
      poseName: 'stand',
      heading: 1,
      ch: { rootHeight: 0 }
    },
    lookOverride: null,
    setAgility(value) { this.agility = value; },
    setPose(name) {
      this.state.poseName = name;
      this.poseName = name;
    },
    setLocomotion(speed, gait) {
      this.state.speed = speed;
      this.gait = gait;
    },
    setHeading(heading) { this.state.heading = heading; },
    isTurning() { return false; },
    setLookOverride(target) { this.lookOverride = target; },
    setArousal(value) { this.arousal = value; },
    setPetContact() {},
    triggerSwipe() {},
    triggerPounce() {},
    triggerDockPaw() {},
    triggerLunge() {},
    cancelLunge() {},
    triggerLand() {},
    isSwiping() { return false; },
    isClinging() { return false; },
    isLunging() { return false; },
    isDockPawing() { return false; },
    getPawAnchor() { return { x: 0.18, yAbs: 0.75 }; },
    getHeadOffsetX() { return 0.24; },
    update() {}
  };
}

function fixedRandom(value) {
  return () => value;
}

const animator = makeAnimator();
const behavior = context.CatBehavior.create(animator, fixedRandom(0.5), {
  activity: 0.5,
  curiosity: 1,
  playfulness: 0.8,
  mouseReactions: true
});
behavior.setBounds(-2.25, 2.25);
behavior.setEnvironment({
  dockVisible: false,
  dockSide: 'none',
  dockThicknessPx: 0,
  wallInsetsPx: { left: 0, right: 0, bottom: 0 },
  worldPerPx: 0.0035,
  screenWidthWorld: 6,
  screenHeightWorld: 4,
  effectiveGroundFraction: 0
});

for (const y of [0.75, 1.08, 0.84, 1.22, 0.92, 1.52, 1.14, 1.70]) {
  behavior.setMouse(3, y);
  behavior.update(0.16);
}

assert.equal(
  behavior.state.name,
  'wallApproach',
  'rubbing the cursor along the screen edge should send the cat toward that wall'
);
assert.equal(behavior.state.contactSide, 'right', 'cat should choose the rubbed wall side');
assert.equal(behavior.state.pendingWallAction, 'wallClimb', 'edge tease should resolve into a climb');

for (let i = 0; i < 40 && behavior.state.name === 'wallApproach'; i += 1) {
  behavior.setMouse(3, 1.85);
  behavior.update(0.16);
}

assert.equal(behavior.state.name, 'wallClimb', 'cat should climb after reaching the teased edge');
assert.ok(
  Math.abs(behavior.state.climbTargetY - 1.85) < 0.08,
  'cat should climb toward the latest cursor height on the edge'
);
assert.equal(animator.state.poseName, 'wallClimb', 'climb should use the wall climbing pose');

const tapResult = behavior.pokeAt(behavior.state.worldX, behavior.state.worldY + 0.45);
assert.equal(tapResult.hit, true, 'clicking the climbing cat should hit the cat body');
assert.equal(tapResult.opensChat, false, 'clicking the climbing cat should not open chat');
assert.equal(tapResult.action, 'wallJumpDown', 'clicking the climbing cat should request a jump down');
assert.equal(behavior.state.name, 'wallJumpDown', 'cat should jump down after being tapped while climbing');

const insetAnimator = makeAnimator();
const insetBehavior = context.CatBehavior.create(insetAnimator, fixedRandom(0.5), {
  activity: 0.5,
  curiosity: 1,
  playfulness: 0.8,
  mouseReactions: true
});
insetBehavior.setBounds(-2.25, 2.25);
insetBehavior.setEnvironment({
  dockVisible: true,
  dockSide: 'right',
  dockThicknessPx: 120,
  wallInsetsPx: { left: 0, right: 120, bottom: 0 },
  worldPerPx: 0.0035,
  screenWidthWorld: 6,
  screenHeightWorld: 4,
  effectiveGroundFraction: 0
});

for (const y of [0.72, 1.10, 0.86, 1.24, 0.94, 1.58, 1.18, 1.72]) {
  insetBehavior.setMouse(3, y);
  insetBehavior.update(0.16);
}

assert.equal(
  insetBehavior.state.name,
  'wallApproach',
  'rubbing the cursor on the physical screen edge should still trigger a climb with a side dock inset'
);
assert.equal(insetBehavior.state.contactSide, 'right', 'cat should choose the physical right screen edge');

for (let i = 0; i < 40 && insetBehavior.state.name === 'wallApproach'; i += 1) {
  insetBehavior.setMouse(3, 1.85);
  insetBehavior.update(0.16);
}

assert.equal(insetBehavior.state.name, 'wallClimb', 'cat should climb after reaching the physical edge');
insetBehavior.update(0.16);
const rootGapPx = Math.abs(3 - insetBehavior.state.worldX) / 0.0035;
assert.ok(
  rootGapPx <= 18,
  `climbing cat body should hug the physical screen edge, saw ${rootGapPx.toFixed(1)}px inward gap`
);

console.log('cat edge tease climb behavior ok');
