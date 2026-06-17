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
    headingHistory: [],
    bugEatCount: 0,
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
      this.headingHistory.push(heading);
    },
    isTurning() { return false; },
    setLookOverride(target) { this.lookOverride = target; },
    setArousal(value) { this.arousal = value; },
    setPetContact() {},
    getPawAnchor() { return { x: 0.16, yAbs: 0.72 }; },
    getHeadOffsetX() { return 0.24; },
    triggerSwipe() { this.swiped = true; },
    triggerPounce() {},
    triggerDockPaw() {},
    triggerLunge() { this.lunged = true; },
    cancelLunge() { this.lunged = false; },
    triggerLand() {},
    triggerBugEat() { this.bugEatCount += 1; },
    startMouseCling() {},
    setClingMotion() {},
    isSwiping() { return false; },
    isClinging() { return this.poseName === 'mouseCling'; },
    isLunging() { return false; },
    isDockPawing() { return false; },
    isBugEating() { return this.poseName === 'bugEat'; },
    update(dt, worldX, worldY) {
      this.updateCalls.push({ dt, worldX, worldY, pose: this.poseName });
    }
  };
}

function fixedRandom(value) {
  return () => value;
}

const caught = [];
const animator = makeAnimator();
const behavior = context.CatBehavior.create(animator, fixedRandom(0.01), {
  activity: 0.6,
  curiosity: 1,
  playfulness: 1,
  mouseReactions: true,
  onBugCaught(id, details) {
    caught.push({ id, details });
  }
});
behavior.setBounds(-3, 3);
behavior.state.bugCooldown = 0;

const bee = { id: 'bee-1', species: 'bee', x: 0.18, y: 0.50, plantFocused: true };
behavior.setBugs([bee]);
behavior.update(0.1);
assert.equal(behavior.state.name, 'bugWatch', 'nearby moving bug should make the cat lock on and watch');
assert.equal(animator.lookOverride.x, bee.x, 'cat should look directly at the bug horizontally');
assert.equal(animator.lookOverride.y, bee.y, 'cat should look directly at the bug vertically');

for (let i = 0; i < 12 && behavior.state.name !== 'bugEat'; i += 1) {
  behavior.setBugs([bee]);
  behavior.update(0.1);
}

assert.equal(behavior.state.name, 'bugEat', 'well-timed close bug hunt should enter the eating animation');
assert.equal(animator.poseName, 'bugEat', 'behavior should request the caught-bug eating pose');
assert.equal(animator.bugEatCount, 1, 'eating animation trigger should fire once');
assert.equal(caught.length, 1, 'native bridge should be told exactly one bug was caught');
assert.equal(caught[0].id, 'bee-1', 'native bridge should receive the caught bug id');
assert.equal(caught[0].details.species, 'bee', 'native bridge should receive the caught bug species');
assert.equal(behavior.state.bugs.length, 0, 'caught bug should be removed from the cat prey list');

const trackingAnimator = makeAnimator();
const trackingBehavior = context.CatBehavior.create(trackingAnimator, fixedRandom(0.99), {
  activity: 0.6,
  curiosity: 1,
  playfulness: 1,
  mouseReactions: true
});
trackingBehavior.setBounds(-3, 3);
trackingBehavior.state.bugCooldown = 0;

trackingBehavior.setBugs([{ id: 'moth-1', species: 'moth', x: -0.40, y: 0.72, plantFocused: true }]);
trackingBehavior.update(0.1);
trackingBehavior.setBugs([{ id: 'moth-1', species: 'moth', x: -0.10, y: 0.74, plantFocused: true }]);
trackingBehavior.update(0.1);

assert.equal(
  trackingBehavior.state.name,
  'bugWatch',
  'cat should begin with a locked watch before committing to a bug strike'
);
assert.equal(
  trackingBehavior.state.bugFocus.id,
  'moth-1',
  'cat should keep prey focus memory for the selected bug'
);
assert.ok(
  trackingBehavior.state.bugFocus.lock > 0.1,
  'prey focus should build smoothly across consecutive bug snapshots'
);
assert.ok(
  trackingAnimator.lookOverride.x > -0.10,
  'cat gaze should lead a moving bug instead of staring at the stale position'
);
assert.ok(
  trackingBehavior.state.bugs[0].vx > 0,
  'bug snapshots should infer horizontal velocity for predictive stalking'
);

const overheadAnimator = makeAnimator();
const overheadBehavior = context.CatBehavior.create(overheadAnimator, fixedRandom(0.01), {
  activity: 0.6,
  curiosity: 1,
  playfulness: 1,
  mouseReactions: true
});
overheadBehavior.setBounds(-3, 3);
overheadBehavior.state.bugCooldown = 0;
overheadBehavior.state.worldX = 0;

for (const x of [0.012, -0.011, 0.010, -0.014, 0.009, -0.010, 0.013, -0.012]) {
  overheadBehavior.setBugs([{ id: 'gnat-1', species: 'gnat', x, y: 1.34, plantFocused: false }]);
  overheadBehavior.update(0.08);
  overheadBehavior.state.timer = Math.max(overheadBehavior.state.timer, 1.0);
}

const overheadHeadingFlips = overheadAnimator.headingHistory
  .slice(1)
  .reduce((count, heading, index) => (
    heading !== overheadAnimator.headingHistory[index] ? count + 1 : count
  ), 0);

assert.ok(
  overheadHeadingFlips <= 1,
  `overhead bug jitter should not make the cat flip left/right every frame; saw ${overheadHeadingFlips} flips`
);
assert.ok(
  overheadAnimator.lookOverride.y > 1.2,
  'cat should keep looking upward at an overhead bug while holding body direction steady'
);

console.log('cat bug hunting behavior ok');
