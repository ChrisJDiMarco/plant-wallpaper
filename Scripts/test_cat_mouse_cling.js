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
    state: { speed: 0, poseName: 'stand', heading: 1, ch: { rootHeight: 0 } },
    poseName: 'stand',
    heading: 1,
    turning: false,
    swipeCount: 0,
    updateCalls: [],
    setAgility(value) { this.agility = value; },
    setPose(name) {
      this.poseName = name;
      this.state.poseName = name;
    },
    setLocomotion(speed, gait) { this.state.speed = speed; this.gait = gait; },
    setHeading(heading) {
      this.heading = heading;
      this.state.heading = heading;
    },
    isTurning() { return this.turning; },
    setLookOverride(target) { this.lookOverride = target; },
    setArousal(value) { this.arousal = value; },
    setPetContact() {},
    getPawAnchor() { return { x: 0.18, yAbs: 0.75 }; },
    getHeadOffsetX() { return 0.24; },
    triggerSwipe() { this.swipeCount += 1; },
    triggerPounce() {},
    triggerDockPaw() {},
    triggerLunge() {},
    cancelLunge() {},
    triggerLand() {},
    startMouseCling() {},
    setClingMotion() {},
    isSwiping() { return false; },
    isClinging() { return this.poseName === 'mouseCling'; },
    isLunging() { return false; },
    isDockPawing() { return false; },
    update(dt, worldX, worldY) {
      this.updateCalls.push({ dt, worldX, worldY });
    }
  };
}

function fixedRandom(value) {
  return () => value;
}

const animator = makeAnimator();
const behavior = context.CatBehavior.create(animator, fixedRandom(0.5), {
  activity: 0.5,
  curiosity: 0.7,
  playfulness: 1,
  mouseReactions: true
});
behavior.setBounds(-3, 3);

behavior.setMouse(0.12, 0.36);
behavior.update(0.05);
assert.equal(behavior.state.name, 'swipe', 'first close cursor pass should start a swat');
assert.equal(animator.swipeCount, 1, 'swat animation should trigger before a catch');

behavior.setMouse(0.10, 0.38);
behavior.update(0.18);
assert.equal(behavior.state.name, 'mouseCling', 'a clean swat should latch onto the cursor');
assert.equal(animator.poseName, 'mouseCling', 'cling state should request the hanging animation pose');

behavior.setMouse(0.9, 1.6);
behavior.update(0.12);
assert.ok(behavior.state.worldX > 0.45, 'latched cat should follow the cursor horizontally');
assert.ok(behavior.state.worldY > 0.35, 'latched cat should hang above the ground');
assert.ok(
  animator.updateCalls.some((call) => call.worldY > 0.35),
  'animation update should receive the vertical hang offset'
);

behavior.setMouse(0.9, 0.08);
behavior.update(0.18);
assert.notEqual(behavior.state.name, 'mouseCling', 'cat should release once the cursor returns to ground level');
assert.ok(behavior.state.worldY < 0.18, 'release should leave the cat near the ground');

console.log('cat mouse cling behavior ok');
