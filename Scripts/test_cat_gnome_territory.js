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

const animator = makeAnimator();
const colony = {
  id: 'colony',
  points: [
    { x: -0.45, y: 0.05 },
    { x: 0.45, y: 0.05 },
    { x: 0.45, y: 1.15 },
    { x: -0.45, y: 1.15 }
  ],
  minX: -0.45,
  maxX: 0.45,
  minY: 0.05,
  maxY: 1.15,
  centerX: 0,
  centerY: 0.60
};

function makeBehavior(options = {}) {
  const instance = context.CatBehavior.create(makeAnimator(), () => 0.45, {
    activity: 0.5,
    curiosity: 1,
    playfulness: 0.8,
    mouseReactions: true,
    ...options
  });
  instance.setBounds(-3, 3);
  instance.setGnomeTerritories([colony]);
  return instance;
}

const behavior = makeBehavior();

behavior.state.worldX = 0;
behavior.state.targetX = 0;
behavior.update(0.016);
assert.ok(
  Math.abs(behavior.state.worldX) < 0.08,
  'cat should be allowed inside gnome territory by default while avoidance is disabled'
);

const respectfulBehavior = makeBehavior({ respectGnomeTerritories: true });
respectfulBehavior.state.worldX = 0;
respectfulBehavior.state.targetX = 0;
respectfulBehavior.update(0.016);
assert.ok(
  Math.abs(respectfulBehavior.state.worldX) > 0.6,
  'explicit territory respect should still push the cat outside the padded colony interval'
);

respectfulBehavior.state.worldX = -1.2;
respectfulBehavior.state.bugCooldown = 0;
respectfulBehavior.state.gnomeCooldown = 999;
respectfulBehavior.setBugs([{ id: 'bug-inside-colony', x: 0, y: 0.55, plantFocused: true }]);
respectfulBehavior.update(0.2);
assert.equal(
  respectfulBehavior.state.targetBugID,
  null,
  'explicit territory respect should keep the cat from targeting bugs inside colony space'
);

behavior.state.gnomeCooldown = 0;
behavior.state.gnomeRideCooldown = 0;
behavior.force('idle');
behavior.state.timer = 0;
behavior.update(0.05);
assert.ok(
  ['gnomeApproach', 'gnomeWatch'].includes(behavior.state.name),
  'idle cat near a colony should approach the border or settle into watching'
);

behavior.force('gnomeRide');
behavior.update(0.2);
const riding = behavior.gnomeRiding();
assert.equal(riding.active, true, 'gnome riding state should expose an active rider kit signal');
assert.ok(['mounting', 'mounted'].includes(riding.phase), 'ride should start in a mounting or mounted phase');

console.log('cat gnome territory behavior ok');
