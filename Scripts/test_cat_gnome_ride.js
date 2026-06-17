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
  const headings = [];
  return {
    headings,
    state: { speed: 0, poseName: 'stand', heading: -1, ch: { rootHeight: 0 } },
    setAgility(value) { this.agility = value; },
    setPose(name) { this.state.poseName = name; },
    setLocomotion(speed, gait) { this.state.speed = speed; this.gait = gait; },
    setHeading(heading) {
      if (this.state.heading !== heading) headings.push(heading);
      this.state.heading = heading;
    },
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
    triggerWiggle() {},
    isSwiping() { return false; },
    isClinging() { return false; },
    isLunging() { return false; },
    isDockPawing() { return false; },
    getPawAnchor() { return { x: 0.18, yAbs: 0.75 }; },
    getHeadOffsetX() { return 0.24; },
    update() {}
  };
}

const territory = {
  id: 'left-planter-gnomes',
  points: [
    { x: -2.25, y: 0.05 },
    { x: -1.55, y: 0.05 },
    { x: -1.55, y: 0.95 },
    { x: -2.25, y: 0.95 }
  ],
  minX: -2.25,
  maxX: -1.55,
  minY: 0.05,
  maxY: 0.95,
  centerX: -1.90,
  centerY: 0.50
};

const animator = makeAnimator();
const behavior = context.CatBehavior.create(animator, () => 0.45, {
  activity: 0.5,
  curiosity: 1,
  playfulness: 0.8,
  mouseReactions: true
});

behavior.setBounds(-2, 2);
behavior.setGnomeTerritories([territory]);
behavior.state.gnomeFocus = territory;
behavior.state.worldX = -1.95;
behavior.state.targetX = -1.95;
behavior.force('gnomeRide');

assert.ok(
  behavior.state.targetX > behavior.state.worldX + 0.20,
  'gnome ride should steer inward when it begins beside the left screen edge'
);

for (let i = 0; i < 160; i += 1) behavior.update(1 / 60);
const riding = behavior.gnomeRiding();

assert.equal(typeof riding.heading, 'number', 'ride telemetry should expose stable heading');
assert.equal(typeof riding.velocityX, 'number', 'ride telemetry should expose lateral speed');
assert.equal(typeof riding.turning, 'boolean', 'ride telemetry should expose turn state for rider physics');
assert.ok(
  animator.headings.length <= 2,
  `gnome ride should not flicker left/right at the edge, saw ${animator.headings.length} heading changes`
);

console.log('cat gnome ride behavior ok');
