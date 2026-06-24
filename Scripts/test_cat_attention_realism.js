#!/usr/bin/env node

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const catDir = path.join(
  __dirname,
  '..',
  'Sources',
  'PlantWallpaper',
  'WebAssets',
  'cat'
);

const behaviorSource = fs.readFileSync(path.join(catDir, 'cat-behavior.js'), 'utf8');
const animSource = fs.readFileSync(path.join(catDir, 'cat-anim.js'), 'utf8');
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
vm.runInContext(`${behaviorSource}\nglobalThis.CatBehavior = CatBehavior;`, context);

function makeAnimator() {
  return {
    state: { speed: 0, poseName: 'stand', heading: 1, ch: { rootHeight: 0 } },
    poseName: 'stand',
    lookOverride: null,
    emotionSignals: null,
    setAgility(value) { this.agility = value; },
    setPose(name) {
      this.poseName = name;
      this.state.poseName = name;
    },
    setLocomotion(speed, gait) {
      this.state.speed = speed;
      this.gait = gait;
    },
    setHeading(heading) { this.state.heading = heading; },
    isTurning() { return false; },
    setLookOverride(target) { this.lookOverride = target; },
    setArousal(value) { this.arousal = value; },
    setEmotionSignals(values) { this.emotionSignals = values; },
    setPetContact() {},
    getPawAnchor() { return { x: 0.16, yAbs: 0.72 }; },
    getHeadOffsetX() { return 0.24; },
    triggerSwipe() {},
    triggerPounce() {},
    triggerDockPaw() {},
    triggerLunge() {},
    cancelLunge() {},
    triggerLand() {},
    triggerBugEat() {},
    startMouseCling() {},
    setClingMotion() {},
    isSwiping() { return false; },
    isClinging() { return this.poseName === 'mouseCling'; },
    isLunging() { return false; },
    isDockPawing() { return false; },
    isBugEating() { return this.poseName === 'bugEat'; },
    update() {}
  };
}

function fixedRandom(value) {
  return () => value;
}

function makeBehavior(random = fixedRandom(0.01)) {
  const animator = makeAnimator();
  const behavior = context.CatBehavior.create(animator, random, {
    activity: 0.55,
    curiosity: 1,
    playfulness: 0.85,
    mouseReactions: true
  });
  behavior.setBounds(-3, 3);
  behavior.setClockHour(8);
  behavior.state.scratchCooldown = 999;
  behavior.state.wallCooldown = 999;
  behavior.state.gnomeCooldown = 999;
  return { animator, behavior };
}

{
  const { behavior } = makeBehavior();
  behavior.setGnomePlantTargets([
    { id: 'far-plant', x: 1.8, y: 0.48, resourceValue: 0.30, canopyHeight: 0.05 },
    { id: 'near-rich-plant', x: 0.55, y: 0.62, resourceValue: 0.92, canopyHeight: 0.24 }
  ]);

  behavior.update(0.16);

  assert.equal(behavior.state.attentionTarget.kind, 'plant', 'attention should choose the live plant/object stimulus');
  assert.equal(behavior.state.attentionTarget.key, 'plant:near-rich-plant', 'attention should prefer the nearest/highest-salience object');
}

{
  const { behavior } = makeBehavior();
  behavior.setMouse(0.62, 0.74);
  behavior.update(0.16);
  const firstScore = behavior.state.attentionTarget.score;
  for (let i = 0; i < 16; i += 1) {
    behavior.setMouse(0.62, 0.74);
    behavior.update(0.16);
  }

  assert.ok(behavior.state.attentionHabituation.cursor > 0.25, 'still cursor should build habituation');
  assert.ok(
    behavior.state.attentionTarget.score < firstScore,
    'habituation should reduce repeated cursor salience'
  );
}

{
  const { behavior } = makeBehavior();
  behavior.setGnomePlantTargets([
    { id: 'fern', x: 0.35, y: 0.62, resourceValue: 1, canopyHeight: 0.20 }
  ]);
  behavior.state.bugCooldown = 0;
  behavior.setBugs([{ id: 'moth', species: 'moth', x: 0.18, y: 0.58, plantFocused: true }]);
  behavior.update(0.10);

  assert.equal(behavior.state.name, 'bugWatch', 'live prey should override idle object curiosity');
  assert.equal(behavior.state.attentionTarget.kind, 'bug', 'attention should stay on prey during the hunt');
}

{
  const { animator, behavior } = makeBehavior();
  behavior.force('petted');
  behavior.setMouse(0.0, 0.64);
  behavior.update(0.16);

  assert.equal(behavior.state.attentionTarget, null, 'active petting should suppress prey/object attention');
  assert.equal(animator.lookOverride, null, 'petted cat should keep soft eyes instead of target tracking');
  assert.ok(animator.emotionSignals.confidence > 0, 'behavior should send emotion signals to the animator');
}

{
  const { animator, behavior } = makeBehavior();
  behavior.setGnomePlantTargets([
    { id: 'rubber-tree', x: -0.5, y: 0.58, resourceValue: 1, canopyHeight: 0.28, canClimb: true }
  ]);
  behavior.state.plantFocus = behavior.state.gnomePlantTargets[0];
  behavior.state.needs.energy = 0.90;
  behavior.force('plantInspect');
  assert.equal(animator.poseName, 'sniff', 'plant/object inspection should use the sniff pose first');
  behavior.state.timer = 0;
  behavior.update(0.16);
  assert.notEqual(behavior.state.name, 'plantRest', 'rest beside an object should require a tired cat');
}

{
  const { behavior } = makeBehavior();
  behavior.force('alert');
  behavior.state.lastMouse = { x: 1.1, y: 0.82 };
  behavior.state.mouseInterest = 1.3;
  behavior.clearMouse();
  behavior.update(0.16);

  assert.equal(behavior.state.name, 'lostMouse', 'lost cursor object permanence should still work');
  assert.equal(behavior.state.memory.poiKind, 'cursor', 'lost cursor should remain a remembered point of interest');
}

assert.ok(animSource.includes('sniff:'), 'animator should expose a sniff pose');
assert.ok(animSource.includes('rubObject:'), 'animator should expose a rubObject pose');
assert.ok(animSource.includes('setEmotionSignals(values)'), 'animator should expose internal emotion signals');
assert.ok(
  animSource.includes('0.0065 * breathDepth') && !animSource.includes('emotion.tension * 0.45'),
  'emotion should not drive fast, obvious chest puffing'
);
assert.ok(behaviorSource.includes('attentionTarget'), 'behavior should track a chosen attention target');
assert.ok(behaviorSource.includes('attentionHabituation'), 'behavior should track habituation');
assert.ok(behaviorSource.includes('animator.setEmotionSignals'), 'behavior should drive animation emotion signals');

console.log('cat attention realism behavior ok');
