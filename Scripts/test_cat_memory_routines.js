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
    updateCalls: [],
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
    update(dt, worldX, worldY) {
      this.updateCalls.push({ dt, worldX, worldY, pose: this.poseName });
    }
  };
}

function fixedRandom(value) {
  return () => value;
}

function makeBehavior(random = fixedRandom(0.01)) {
  const animator = makeAnimator();
  const behavior = context.CatBehavior.create(animator, random, {
    activity: 0.5,
    curiosity: 1,
    playfulness: 0.7,
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
  const { animator, behavior } = makeBehavior();
  behavior.state.memory.poiKind = 'cursor';
  behavior.state.memory.poiX = 1.35;
  behavior.state.memory.poiY = 0.82;
  behavior.state.memory.poiWeight = 1;
  behavior.state.mood = 'mellow';
  behavior.force('idle');
  behavior.state.timer = 0;

  behavior.update(0.16);

  assert.equal(behavior.state.name, 'investigateSpot', 'remembered prey should become a later investigation');
  assert.equal(behavior.state.investigation.kind, 'cursor', 'investigation should keep the remembered stimulus kind');
  assert.ok(Math.abs(behavior.state.targetX - 1.35) < 0.01, 'cat should walk toward the remembered cursor spot');

  behavior.update(0.16);
  assert.equal(animator.lookOverride.x, 1.35, 'cat should look at the remembered point while investigating');
  assert.equal(animator.lookOverride.y, 0.82, 'cat should preserve remembered point height');
}

{
  const { behavior } = makeBehavior();
  behavior.state.worldX = 1.4;
  behavior.state.memory.favoriteX = -1.25;
  behavior.state.memory.favoriteWeight = 1;
  behavior.state.needs.energy = 0.15;
  behavior.state.mood = 'mellow';
  behavior.force('idle');
  behavior.state.timer = 0;

  behavior.update(0.16);

  assert.equal(behavior.state.name, 'returnToFavorite', 'tired cat should sometimes return to a learned rest spot');
  assert.ok(Math.abs(behavior.state.targetX + 1.25) < 0.01, 'favorite spot target should be reused');
}

{
  const { behavior } = makeBehavior();
  behavior.force('alert');
  behavior.state.lastMouse = { x: 0.9, y: 0.74 };
  behavior.state.mouseInterest = 1.4;

  behavior.update(0.16);

  assert.equal(behavior.state.name, 'lostMouse', 'vanished cursor should still trigger object permanence');
  assert.equal(behavior.state.memory.poiKind, 'cursor', 'lost cursor should be stored as a point of interest');
  assert.ok(behavior.state.memory.poiWeight > 0.3, 'lost cursor memory should be strong enough to revisit');
}

{
  const { behavior } = makeBehavior();
  behavior.state.memory.trust = 0.83;
  behavior.state.memory.favoriteX = -0.7;
  behavior.state.memory.favoriteWeight = 0.66;
  behavior.state.memory.poiKind = 'missedMouse';
  behavior.state.memory.poiX = 1.1;
  behavior.state.memory.poiY = 0.9;
  behavior.state.memory.poiWeight = 0.58;
  behavior.state.memory.poiAge = 12;

  const snapshot = behavior.snapshotMemory();
  const restored = makeBehavior().behavior;
  assert.equal(restored.restoreMemory(snapshot), true, 'memory snapshot should restore');
  assert.equal(restored.state.memory.trust, 0.83, 'trust should persist');
  assert.equal(restored.state.memory.favoriteX, -0.7, 'favorite spot should persist');
  assert.equal(restored.state.memory.poiKind, 'missedMouse', 'POI kind should persist');
  assert.equal(restored.state.memory.poiWeight, 0.58, 'POI strength should persist');
}

{
  const { animator, behavior } = makeBehavior();
  behavior.setGnomePlantTargets([{
    id: 'fern-1',
    species: 'Fern',
    kind: 'foliage',
    x: 1.2,
    y: 0.58,
    resourceValue: 0.92,
    canopyHeight: 0.22,
    canClimb: true
  }]);
  behavior.state.plantCooldown = 0;
  behavior.force('idle');
  behavior.state.timer = 0;

  behavior.update(0.16);

  assert.equal(behavior.state.name, 'plantApproach', 'curious cat should notice plant/object targets');
  assert.equal(behavior.state.plantFocus.id, 'fern-1', 'plant/object visit should keep a concrete target');
  assert.ok(Math.abs(behavior.state.targetX - 0.86) < 0.01, 'cat should approach the side of the target, not stand inside it');

  behavior.state.worldX = behavior.state.targetX;
  behavior.update(0.16);

  assert.equal(behavior.state.name, 'plantInspect', 'arriving at the plant should become an inspection');
  assert.equal(animator.lookOverride.x, 1.2, 'inspection should look at the actual plant/object');
  assert.ok(animator.lookOverride.y > 0.58, 'inspection should look up into the plant/object body');
}

{
  const { behavior } = makeBehavior();
  behavior.setGnomePlantTargets([{
    id: 'tree-1',
    species: 'Tree',
    kind: 'tree',
    x: -0.4,
    y: 0.62,
    resourceValue: 1,
    canopyHeight: 0.4,
    canClimb: true
  }]);
  behavior.state.plantFocus = behavior.state.gnomePlantTargets[0];
  behavior.state.needs.energy = 0.32;
  behavior.force('plantInspect');
  behavior.state.timer = 0;

  behavior.update(0.16);

  assert.equal(behavior.state.name, 'plantRest', 'tired cat should sometimes settle beside an inviting plant/object');
}

console.log('cat memory routines ok');
