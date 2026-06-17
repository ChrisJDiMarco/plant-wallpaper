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
    setAgility(value) { this.agility = value; },
    setPose(name) { this.state.poseName = name; },
    setLocomotion(speed, gait) { this.state.speed = speed; this.gait = gait; },
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
  id: 'seed-village',
  points: [
    { x: -0.36, y: 0.20 },
    { x: 0.36, y: 0.20 },
    { x: 0.36, y: 0.84 },
    { x: -0.36, y: 0.84 }
  ],
  minX: -0.36,
  maxX: 0.36,
  minY: 0.20,
  maxY: 0.84,
  centerX: 0,
  centerY: 0.52
};

const behavior = context.CatBehavior.create(makeAnimator(), () => 0.22, {
  activity: 0.6,
  curiosity: 1,
  playfulness: 0.8,
  mouseReactions: true
});
behavior.setBounds(-2.2, 2.2);
behavior.setGnomeTerritories([territory]);
assert.equal(typeof behavior.setGnomePlantTargets, 'function', 'cat bridge should accept plant mission targets');

behavior.setGnomePlantTargets([
  {
    id: 'inside-herb',
    species: 'Mint',
    x: 0.08,
    y: 0.48,
    resourceValue: 0.88,
    canopyHeight: 0.12,
    canClimb: false
  },
  {
    id: 'upper-maple',
    species: 'Japanese Maple',
    x: 1.22,
    y: 1.34,
    screenY: 0.18,
    resourceValue: 0.96,
    canopyHeight: 0.38,
    canClimb: true
  },
  {
    id: 'lower-flower',
    species: 'Tulip',
    x: -1.30,
    y: 0.16,
    screenY: 0.83,
    resourceValue: 0.62,
    canopyHeight: 0.08,
    canClimb: false
  }
]);

behavior.state.worldX = 0;
behavior.state.targetX = 0;
behavior.state.gnomeFocus = territory;
behavior.force('gnomeRide');

let riding = behavior.gnomeRiding();
assert.equal(riding.mission.targetID, 'upper-maple', 'cat ride should choose the best outside plant mission');
assert.equal(riding.missionPhase, 'rideOut', 'mission should start by riding out toward the target plant');
assert.equal(riding.depthTrend, 'away', 'up-screen plant targets should read as walking away from the viewer');
assert.ok(riding.depthScaleTarget < 1, `away rides should shrink the cat, saw ${riding.depthScaleTarget}`);

const seenPhases = new Set([riding.missionPhase]);
let smallestScale = riding.depthScale;
let highestLift = riding.depthLiftY;
let largestX = behavior.state.worldX;

for (let i = 0; i < 480; i += 1) {
  behavior.update(1 / 60);
  riding = behavior.gnomeRiding();
  if (riding.missionPhase) seenPhases.add(riding.missionPhase);
  smallestScale = Math.min(smallestScale, riding.depthScale || 1);
  highestLift = Math.max(highestLift, riding.depthLiftY || 0);
  largestX = Math.max(largestX, behavior.state.worldX);
}

assert.ok(seenPhases.has('collecting'), 'gnomes should pause at the target plant to collect samples');
assert.ok(
  seenPhases.has('rideHome') || seenPhases.has('dismounting'),
  'gnomes should ride back toward the colony after collecting'
);
assert.ok(smallestScale < 0.94, `away mission should visibly reduce projected cat scale, saw ${smallestScale}`);
assert.ok(highestLift > 0.08, `away mission should project the cat upward in the scene, saw ${highestLift}`);
assert.ok(largestX > 0.75, `cat should travel horizontally toward the mission plant, max x=${largestX}`);

console.log('cat gnome collection mission ok');
