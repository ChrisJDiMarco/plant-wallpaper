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
    petContacts: [],
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
    setPetContact(x, y, dir, amp) {
      this.petContacts.push({ x, y, dir, amp });
    },
    triggerSwipe() { this.swiped = true; },
    triggerPounce() { this.pounced = true; },
    triggerDockPaw() {},
    triggerLunge() { this.lunged = true; },
    cancelLunge() {},
    triggerLand() {},
    triggerTailLash() {},
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
  curiosity: 0.6,
  playfulness: 0.9,
  mouseReactions: true
});
behavior.setBounds(-3, 3);

behavior.force('bellyUp');
behavior.setMouse(0.02, 0.24);
behavior.update(0.16);
behavior.setMouse(0.32, 0.24);
behavior.update(0.16);

assert.equal(
  behavior.state.name,
  'bellyUp',
  'fast cursor motion near a belly-up cat should not trigger hunting or startle behavior'
);
assert.equal(animator.swiped, undefined, 'belly-up cursor motion should not swat');
assert.equal(animator.lunged, undefined, 'belly-up cursor motion should not lunge');

for (const x of [-0.18, -0.02, 0.16, -0.08, 0.12, -0.10, 0.08, -0.06]) {
  behavior.setMouse(x, 0.34);
  behavior.update(0.16);
}

assert.equal(
  behavior.state.name,
  'bellyPet',
  'gentle strokes on a belly-up cat should enter the dedicated belly-petting state'
);
assert.equal(animator.state.poseName, 'bellyPet', 'belly petting should use the rolling belly-pet pose');
assert.equal(behavior.isPurring(), true, 'belly petting should request audible purring');
assert.ok(animator.petContacts.length >= 3, 'belly strokes should keep sending fur contact to the animator');

console.log('cat belly petting behavior ok');
