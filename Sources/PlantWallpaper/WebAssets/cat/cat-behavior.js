/* The cat's brain: a weighted state machine shaped by a personality
   (activity / curiosity / playfulness, each 0..1) plus instinctive
   reactions to the user's mouse — watching it, stalking it when teased,
   and swatting when it gets within paw range. Durations are randomized
   so the cat never loops visibly. */

const CatBehavior = (() => {
  const WALK_SPEED = 0.55;
  const TROT_SPEED = 1.55;
  const STALK_SPEED = 0.28;
  const POUNCE_SPEED = 1.9;
  const TURN_CREEP = 0.10;

  const SWIPE_RANGE = 0.55;     // horizontal paw reach, world units
  const SWIPE_HEIGHT = 1.08;    // mouse must be below this to be swattable
  const PROBE_RANGE = 0.72;     // curious paw-test range, less committed than a swat
  const FEINT_RANGE = 1.05;     // close enough for fake-outs before the real launch
  const CATCH_RANGE = 0.28;     // clean catch: paws need to land almost on the cursor
  const CATCH_MIN_HEIGHT = 0.32;
  const CATCH_MAX_HEIGHT = 1.14;
  const CATCH_WINDOW_SECONDS = 0.28;
  const CLING_RELEASE_HEIGHT = 0.26;
  const CLING_TOP_MARGIN = 0.30;          // keep the ears on screen
  const LUNGE_MIN_RANGE = 0.50;
  const LUNGE_MAX_RANGE = 1.45;
  const LUNGE_MAX_HEIGHT = 1.55;
  const PET_SPEED_MIN = 0.10;             // slower than this is a parked cursor
  const PET_SPEED_MAX = 2.4;              // faster is roughhousing, not petting
  const CLIMB_SPEED = 0.32;               // world units/s up the screen edge
  const WATCH_RANGE = 1.8;
  const MOUSE_STALE_SECONDS = 0.6;
  const WALL_REACH = 0.32;
  const WALL_CLIMB_EDGE_INSET = 0.045;    // visually flush: ~13px at default cat size
  const WALL_CLIMB_PIN_RATE = 16;
  const EDGE_TEASE_RANGE = 0.24;
  const EDGE_TEASE_TRIGGER = 1.15;
  const EDGE_TEASE_MIN_VERTICAL_SPEED = 0.10;
  const EDGE_TEASE_DECAY = 0.65;
  const WALL_CLICK_HALF_WIDTH = 1.55;
  const WALL_CLICK_HALF_HEIGHT = 1.18;
  const BUG_STALE_SECONDS = 0.9;
  const BUG_WATCH_RANGE = 2.15;
  const BUG_STRIKE_RANGE = 0.74;
  const BUG_CATCH_RANGE = 0.34;
  const BUG_MIN_HEIGHT = 0.08;
  const BUG_MAX_HEIGHT = 1.75;
  const BUG_LEAD_SECONDS = 0.16;
  const BUG_LOCK_TRIGGER = 0.12;
  const BUG_HEADING_DEAD_ZONE = 0.16;
  const BUG_HEADING_REVERSE_SECONDS = 0.18;
  const GNOME_TERRITORY_PADDING = 0.34;
  const GNOME_WATCH_RANGE = 1.45;
  const GNOME_RIDE_MIN_COOLDOWN = 75;
  const GNOME_RIDE_MAX_COOLDOWN = 180;
  const GNOME_RIDE_EDGE_MARGIN = 0.45;
  const GNOME_RIDE_EDGE_PADDING = 0.20;
  const GNOME_MISSION_MIN_RESOURCE = 0.32;
  const GNOME_MISSION_COLLECT_SECONDS = 1.35;
  const PLANT_CURIOSITY_RANGE = 2.6;
  const PLANT_SNIFF_OFFSET = 0.34;
  const ATTENTION_SWITCH_MARGIN = 0.18;

  function pickWeighted(random, options) {
    let total = 0;
    for (const [, weight] of options) total += weight;
    let roll = random() * total;
    for (const [name, weight] of options) {
      roll -= weight;
      if (roll <= 0) return name;
    }
    return options[0][0];
  }

  function damp(current, target, rate, dt) {
    return current + (target - current) * Math.min(1, rate * dt);
  }

  function create(animator, random, personalityOpts) {
    const onBugCaught = typeof (personalityOpts && personalityOpts.onBugCaught) === 'function'
      ? personalityOpts.onBugCaught
      : () => {};
    const setAnimatorLookOverride = typeof animator.setLookOverride === 'function'
      ? animator.setLookOverride.bind(animator)
      : () => {};
    const personality = {
      activity: 0.5,
      curiosity: 0.5,
      playfulness: 0.6,
      mouseReactions: true,
      respectGnomeTerritories: false,
      ...(personalityOpts || {})
    };

    const state = {
      name: 'idle',
      timer: 2,
      worldX: 0,
      worldY: 0,
      targetX: 0,
      minX: -2,
      maxX: 2,
      zoomieLegs: 0,
      mouse: null,           // { x, y, speed, age }
      mouseInterest: 0,      // builds while the mouse teases nearby
      swipeCooldown: 0,
      swipeChained: false,
      lastMouseStrike: null,
      mouseStrikeStreak: 0,
      pendingPounceStyle: 'groundPounce',
      catchCooldown: 0,
      catchArmed: false,
      catchWindow: 0,
      catchDelay: 0,
      clingLostTimer: 0,
      lunge: null,
      lungeCooldown: 5,
      bugs: [],
      targetBugID: null,
      bugFocus: {
        id: null,
        lock: 0,
        smoothX: 0,
        smoothY: 0
      },
      bugFacing: {
        id: null,
        heading: 1,
        pendingHeading: 0,
        pendingTime: 0
      },
      bugStrike: null,
      bugCooldown: 4 + random() * 8,
      bugEatTimer: 0,
      gnomeTerritories: [],
      gnomePlantTargets: [],
      gnomeFocus: null,
      gnomeCooldown: 12 + random() * 32,
      gnomeRideCooldown: GNOME_RIDE_MIN_COOLDOWN + random() * (GNOME_RIDE_MAX_COOLDOWN - GNOME_RIDE_MIN_COOLDOWN),
      gnomeRiding: {
        active: false,
        phase: 'none',
        progress: 0,
        riderCount: 0,
        heading: 1,
        velocityX: 0,
        turning: false,
        stride: 0,
        mission: null,
        missionPhase: 'none',
        depthTrend: 'lateral',
        depthScale: 1,
        depthScaleTarget: 1,
        depthLiftY: 0,
        collectProgress: 0
      },
      gnomeRideDirection: 1,
      plantFocus: null,
      plantCooldown: 24 + random() * 48,
      attentionTarget: null,
      attentionSurprise: 0,
      attentionCommitment: 0,
      attentionHabituation: {},
      attentionLast: null,
      frameLookTarget: null,
      intent: {
        reason: 'idle',
        state: 'idle',
        since: 0,
        hesitation: 0,
        lookBack: null
      },
      petScore: 0,
      petDir: 0,
      petIdle: 0,
      petLastX: null,
      petOverstim: 0,        // rises while being petted; too much → tail-lash + walk off
      novelty: 1,            // 1 = the cursor is fresh/interesting; falls with repeated catches → boredom
      lastMouse: null,       // last-seen cursor spot, for "where did it go?" object permanence
      lostTimer: 0,
      investigation: null,
      // ponytail: one favorite spot + one decaying POI; use a ring buffer once several simultaneous memories matter.
      memory: {
        trust: 0.40 + random() * 0.25,
        favoriteX: 0,
        favoriteWeight: 0,
        poiKind: 'none',
        poiX: 0,
        poiY: 0,
        poiWeight: 0,
        poiAge: 0
      },
      reflexGuard: false,
      reflexGuardTimer: 0,
      glanceTimer: 2,
      wallCooldown: 12 + random() * 24,
      dockCooldown: 18 + random() * 36,
      scratchCooldown: 70 + random() * 90,
      contactSide: 'right',
      pendingWallAction: null,
      climbCooldown: 60 + random() * 90,
      climbTargetY: 0,
      climbTargetYOverride: null,
      wallJump: null,
      edgeTease: {
        side: null,
        score: 0,
        lastDir: 0
      },
      // The drive model: continuous needs that rise and fall with what the
      // cat does, deriving a mood that reshapes every decision. This is
      // what makes hour three look different from hour one.
      needs: {
        energy: 0.65 + random() * 0.25,   // restored by sleep, spent by play
        play: 0.35 + random() * 0.35,     // builds with boredom, spent hunting
        social: 0.30 + random() * 0.40,   // builds alone, satisfied by petting
        hunger: 0.30 + random() * 0.25,   // creeps up over hours; a hungry cat hunts harder, sated by catching prey
        groomNeed: 0.20 + random() * 0.30 // builds with time and after messy exertion/eating; paid down by grooming
      },
      mood: 'mellow',                     // frisky | mellow | sleepy
      clockHourOverride: null,            // null = live wall clock; set for tests/preview
      environment: {
        dockVisible: false,
        dockSide: 'none',
        dockThicknessPx: 0,
        wallInsetsPx: { left: 0, right: 0, bottom: 0 },
        effectiveGroundFraction: 0,
        worldPerPx: 0.0035,
        screenWidthWorld: 4,
        screenHeightWorld: 2.5
      }
    };

    animator.setLookOverride = (target) => {
      if (!target || !Number.isFinite(target.x) || !Number.isFinite(target.y)) {
        state.frameLookTarget = null;
        return;
      }
      state.frameLookTarget = {
        ...classifyLookTarget(target),
        x: target.x,
        y: target.y
      };
    };

    // Lazy cats nap longer; busy cats keep things short. A tired cat naps
    // longer still.
    function lazyScale() {
      return (1.6 - personality.activity) * (1.4 - state.needs.energy * 0.6);
    }

    // --- Circadian rhythm -------------------------------------------------
    // A real cat is crepuscular: bursts at dawn and dusk, a midday catnap, and
    // a deep consolidated sleep through the night. We read the operator's wall
    // clock so the desktop cat lives on their day. clockHourOverride lets the
    // preview/tests pin a specific hour. circadianDayDrive() returns 0..1
    // (1 = peak waking energy); sleep pressure is its complement.
    function clockHour() {
      if (state.clockHourOverride != null) return state.clockHourOverride;
      const d = new Date();
      return d.getHours() + d.getMinutes() / 60;
    }
    function circadianDayDrive() {
      const h = clockHour();
      const bump = (center, width) => Math.exp(-Math.pow((h - center) / width, 2));
      let drive = Math.max(bump(7, 2.2), bump(18.5, 2.4)) * 0.8 + 0.34; // dawn + dusk peaks over a daytime baseline
      if (h < 5.5 || h >= 22) drive *= 0.10;          // deep-night trough
      else if (h >= 11.5 && h < 15) drive *= 0.72;    // midday catnap dip
      return THREE.MathUtils.clamp(drive, 0.05, 1);
    }
    function circadianSleepPressure() {
      return 1 - circadianDayDrive();
    }
    function nightSleepScale() {
      // Sleep bouts run much longer in the deep night so the cat stays settled.
      return 1 + circadianSleepPressure() * 2.2;
    }

    const GROOMING_STATES = ['groomPaw', 'groomFace', 'groomFlank', 'groomBelly', 'groomTail', 'groomHaunch'];
    const RESTING_STATES = ['sleep', 'lie', 'loaf', 'bellyUp', 'bellyPet', 'dockRest', 'plantRest'];
    const BUG_STATES = ['bugWatch', 'bugStalk', 'bugCoil', 'bugSwat', 'bugLunge', 'bugEat'];
    const GNOME_STATES = ['gnomeApproach', 'gnomeWatch', 'gnomeRide', 'gnomeDismount'];
    const PLANT_STATES = ['plantApproach', 'plantInspect', 'plantRest'];
    const MOUSE_STRIKE_STATES = ['stalkMouse', 'crouchPounce', 'mouseProbe', 'mouseFeint', 'pounce',
      'swipe', 'lunge', 'lungeRecover', 'mouseCling'];
    const EXERTING_STATES = ['zoomies', 'lunge', 'pounce', 'stalkMouse', 'wallScratch', 'playOnBack',
      'mouseProbe', 'mouseFeint', 'bugStalk', 'bugSwat', 'bugLunge', 'gnomeRide'];

    // Displacement grooming: when the cat disengages from a fizzled hunt or a
    // false-alarm startle, it "saves face" with a couple of quick face/paw
    // washes instead of just standing there — the clearest read of an inner
    // state. Brief, then it goes back to normal idle business.
    function displacementGroom(odds) {
      if (random() >= odds) {
        enter('idle');
        return;
      }
      enter(random() < 0.6 ? 'groomFace' : 'groomPaw');
      state.timer = 1.4 + random() * 1.6;
    }

    function chooseGroomingState(context = 'default') {
      const curiosity = 0.55 + personality.curiosity * 0.55;
      if (context === 'afterBug') {
        return pickWeighted(random, [
          ['groomPaw', 0.44],
          ['groomFace', 0.26],
          ['groomFlank', 0.12],
          ['groomHaunch', 0.10],
          ['groomTail', 0.08]
        ]);
      }
      if (context === 'afterPet') {
        return pickWeighted(random, [
          ['groomFlank', 0.36],
          ['groomFace', 0.18],
          ['groomPaw', 0.18],
          ['groomTail', 0.16],
          ['groomHaunch', 0.12]
        ]);
      }
      if (context === 'afterBellyPet' || context === 'belly') {
        return pickWeighted(random, [
          ['groomBelly', 0.48],
          ['groomFlank', 0.22],
          ['groomPaw', 0.14],
          ['groomTail', 0.10],
          ['groomFace', 0.06]
        ]);
      }
      if (context === 'rest') {
        return pickWeighted(random, [
          ['groomPaw', 0.22],
          ['groomFace', 0.18],
          ['groomFlank', 0.24 * curiosity],
          ['groomTail', 0.20],
          ['groomHaunch', 0.16]
        ]);
      }
      return pickWeighted(random, [
        ['groomPaw', 0.26],
        ['groomFace', 0.18],
        ['groomFlank', 0.20 * curiosity],
        ['groomTail', 0.16],
        ['groomHaunch', 0.14],
        ['groomBelly', 0.06]
      ]);
    }

    function isGrooming() {
      return GROOMING_STATES.includes(state.name);
    }

    function intentReasonFor(name) {
      if (MOUSE_STRIKE_STATES.includes(name) || name === 'lostMouse' || name === 'alert') return 'hunt';
      if (BUG_STATES.includes(name)) return 'hunt';
      if (PLANT_STATES.includes(name) || name === 'investigateSpot'
          || name === 'wallInspect' || name === 'dockInspect') return 'inspect';
      if (name === 'returnToFavorite' || RESTING_STATES.includes(name)) return 'rest';
      if (name === 'seekAttention' || name === 'petted' || name === 'bellyPet') return 'seekAttention';
      if (GROOMING_STATES.includes(name)) return 'selfSoothe';
      if (name === 'wander' && state.petOverstim > 0.25) return 'avoidOverstim';
      if (GNOME_STATES.includes(name)) return 'inspect';
      if (name === 'wallRub' || name === 'wallScratch' || name === 'dockPaw') return 'inspect';
      return 'idle';
    }

    function setIntent(name) {
      const reason = intentReasonFor(name);
      if (state.intent.state !== name) {
        state.intent.since = 0;
        state.intent.hesitation = (name === 'plantApproach' || name === 'gnomeApproach' || name === 'seekAttention')
          ? 0.18 + random() * 0.28
          : 0;
      }
      state.intent.state = name;
      state.intent.reason = reason;
    }

    function tickNeeds(dt) {
      const needs = state.needs;
      const name = state.name;
      // Energy: sleep restores fast, rest slowly; exertion burns it.
      if (name === 'sleep') needs.energy += dt * 0.020;
      else if (RESTING_STATES.includes(name)) needs.energy += dt * 0.008;
      else if (GROOMING_STATES.includes(name)) needs.energy += dt * 0.003;
      else if (EXERTING_STATES.includes(name)) needs.energy -= dt * 0.030;
      else needs.energy -= dt * 0.0015;
      // Play drive simmers up with idleness, spent by hunting and play.
      needs.play += dt * 0.004 * (0.4 + personality.playfulness);
      if (EXERTING_STATES.includes(name) || name === 'swipe' || name === 'mouseCling') {
        needs.play -= dt * 0.045;
      }
      // Social hunger builds alone; being petted satisfies it deeply.
      needs.social += dt * 0.0025 * (0.3 + personality.curiosity);
      if (name === 'petted' || name === 'bellyPet') {
        needs.social -= dt * 0.10;
        needs.energy += dt * 0.004; // a good pet is restful
      }
      if (GROOMING_STATES.includes(name)) {
        needs.social -= dt * 0.010; // self-soothing, but not a replacement for attention
      }
      // Hunger creeps up over the hours; a workout or a wash doesn't touch it —
      // only catching prey (handled in tryCatchBug) sates it.
      needs.hunger += dt * 0.0018;
      // Grooming-need builds with time, faster after a workout (a hunt musses
      // the coat), and is paid down while grooming.
      needs.groomNeed += dt * 0.0026 * (0.7 + personality.curiosity * 0.6);
      if (EXERTING_STATES.includes(name)) needs.groomNeed += dt * 0.010;
      if (GROOMING_STATES.includes(name)) needs.groomNeed -= dt * 0.085;
      needs.energy = THREE.MathUtils.clamp(needs.energy, 0, 1);
      needs.play = THREE.MathUtils.clamp(needs.play, 0, 1);
      needs.social = THREE.MathUtils.clamp(needs.social, 0, 1);
      needs.hunger = THREE.MathUtils.clamp(needs.hunger, 0, 1);
      needs.groomNeed = THREE.MathUtils.clamp(needs.groomNeed, 0, 1);

      // Mood with hysteresis so it doesn't flicker at boundaries.
      if (state.mood !== 'sleepy' && needs.energy < 0.22) state.mood = 'sleepy';
      else if (state.mood === 'sleepy' && needs.energy > 0.38) state.mood = 'mellow';
      else if (state.mood !== 'frisky' && needs.play > 0.72 && needs.energy > 0.45) state.mood = 'frisky';
      else if (state.mood === 'frisky' && (needs.play < 0.45 || needs.energy < 0.30)) state.mood = 'mellow';
      // Deep night overrides the energy-driven mood: a cat in its night trough
      // reads as sleepy and calm even if it has rested up.
      if (circadianSleepPressure() > 0.72) state.mood = 'sleepy';

      // Arousal feeds the pupils: hunting interest, play mood, and any
      // active prey-drive state dilate; sleepiness constricts.
      const hunting = isMouseDriven() || isBugDriven() || name === 'lunge' ? 0.55 : 0;
      const arousal = THREE.MathUtils.clamp(
        state.mouseInterest * 0.28 + hunting
          + (state.mood === 'frisky' ? 0.18 : 0)
          - (state.mood === 'sleepy' ? 0.25 : 0)
          + (name === 'petted' || name === 'bellyPet' ? -0.2 : 0),
        0, 1
      );
      animator.setArousal(arousal);
    }

    function enter(name) {
      if (name === 'groom') name = chooseGroomingState('default');
      state.name = name;
      setIntent(name);
      // A hunting or playing cat is a different animal: it accelerates and
      // turns with feline snap instead of the ambling default.
      const nimbleStates = ['stalkMouse', 'mouseProbe', 'mouseFeint', 'pounce', 'swipe', 'lunge', 'lungeRecover',
        'mouseCling', 'zoomies', 'playOnBack', 'startle', 'gnomeRide', ...BUG_STATES];
      // Mood colors everything: frisky sharpens even ordinary moves,
      // sleepiness softens them.
      const moodScale = state.mood === 'frisky' ? 1.15 : state.mood === 'sleepy' ? 0.85 : 1;
      animator.setAgility((nimbleStates.includes(name) ? 1.75 : 1) * moodScale);
      switch (name) {
        case 'idle':
          animator.setPose('stand');
          animator.setLocomotion(0, 'walk');
          state.timer = (1.5 + random() * 3.5) * lazyScale();
          break;
        case 'rise':
          animator.setPose('stand');
          animator.setLocomotion(0, 'walk');
          state.timer = 0.8;
          break;
        case 'wander':
          animator.setPose('walk');
          state.targetX = state.minX + random() * (state.maxX - state.minX);
          state.timer = 30;
          break;
        case 'returnToFavorite':
          animator.setPose('walk');
          state.targetX = favoriteSpotX();
          state.timer = 18;
          break;
        case 'investigateSpot':
          animator.setPose('walk');
          state.targetX = state.investigation
            ? safeXOutsideGnomeTerritories(state.investigation.x)
            : state.worldX;
          state.timer = 10;
          break;
        case 'plantApproach':
          animator.setPose('walk');
          clearPendingMouseCatch();
          if (state.plantFocus) state.targetX = plantSniffSpot(state.plantFocus);
          state.timer = 12;
          break;
        case 'plantInspect':
          animator.setPose(random() < 0.72 ? 'sniff' : 'rubObject');
          animator.setLocomotion(0, 'walk');
          clearPendingMouseCatch();
          state.timer = 2.0 + random() * 2.4;
          break;
        case 'plantRest':
          animator.setPose(random() < 0.55 ? 'loaf' : 'lie');
          animator.setLocomotion(0, 'walk');
          clearPendingMouseCatch();
          state.timer = (7 + random() * 12) * lazyScale();
          break;
        case 'zoomies':
          animator.setPose('trot');
          state.zoomieLegs = 1 + Math.floor(random() * 2);
          state.targetX = random() < 0.5 ? state.minX : state.maxX;
          state.timer = 20;
          break;
        case 'sit':
          animator.setPose('sit');
          animator.setLocomotion(0, 'walk');
          state.timer = (6 + random() * 14) * lazyScale();
          break;
        case 'groomPaw':
        case 'groomFace':
        case 'groomFlank':
        case 'groomBelly':
        case 'groomTail':
        case 'groomHaunch':
          animator.setPose(name);
          animator.setLocomotion(0, 'walk');
          clearPendingMouseCatch();
          state.petScore = 0;
          state.timer = (3.4 + random() * 5.2) * lazyScale();
          break;
        case 'scratchEar':
          animator.setPose('scratchEar');
          animator.setLocomotion(0, 'walk');
          state.timer = 2.5 + random() * 2;
          break;
        case 'loaf':
          animator.setPose('loaf');
          animator.setLocomotion(0, 'walk');
          state.timer = (7 + random() * 16) * lazyScale();
          break;
        case 'bellyUp':
          animator.setPose('bellyUp');
          animator.setLocomotion(0, 'walk');
          clearPendingMouseCatch();
          state.timer = (7 + random() * 13) * lazyScale();
          break;
        case 'playOnBack':
          animator.setPose('playOnBack');
          animator.setLocomotion(0, 'walk');
          clearPendingMouseCatch();
          state.timer = 3.5 + random() * 4.5;
          break;
        case 'bellyPet':
          animator.setPose('bellyPet');
          animator.setLocomotion(0, 'walk');
          clearPendingMouseCatch();
          state.petIdle = 0;
          state.timer = 999; // exits when the stroking stops, not on a clock
          break;
        case 'petted':
          animator.setPose('petted');
          animator.setLocomotion(0, 'walk');
          state.petIdle = 0;
          state.timer = 999; // exits when the stroking stops, not on a clock
          break;
        case 'lungeRecover':
          // Falling out of a missed lunge; gravity is handled by the
          // standard worldY damp, the landing squash fires on touchdown.
          animator.setPose('stand');
          animator.setLocomotion(0, 'walk');
          state.timer = 2.5;
          break;
        case 'wallClimb': {
          // Up the screen edge, claws out. Height committed at launch.
          animator.setPose('wallClimb');
          animator.setLocomotion(0, 'walk');
          faceContactSide();
          const env = state.environment;
          const maxY = Math.max(
            0.8,
            env.screenHeightWorld * (1 - env.effectiveGroundFraction) - 0.85
          );
          state.climbTargetY = state.climbTargetYOverride === null
            ? maxY * (0.35 + random() * 0.55)
            : THREE.MathUtils.clamp(state.climbTargetYOverride, 0.55, maxY);
          state.climbTargetYOverride = null;
          state.climbCooldown = 150 + random() * 240;
          state.timer = 30;
          break;
        }
        case 'wallHang':
          animator.setPose('wallHang');
          animator.setLocomotion(0, 'walk');
          faceContactSide();
          // Generous fallback so an unattended cat eventually climbs down
          // on its own; the intended exit is the user's tap.
          state.timer = 150 + random() * 120;
          break;
        case 'wallJumpDown': {
          animator.setPose('lungeAir');
          animator.setLocomotion(0, 'walk');
          const inward = state.contactSide === 'left' ? 1 : -1;
          animator.setHeading(inward);
          const duration = 0.45 + state.worldY * 0.12;
          state.wallJump = {
            t: 0,
            duration,
            startX: state.worldX,
            startY: state.worldY,
            targetX: THREE.MathUtils.clamp(
              state.worldX + inward * (0.9 + random() * 0.7),
              state.minX, state.maxX
            ),
            arc: 0.16
          };
          animator.triggerLunge(duration);
          state.timer = duration + 0.4;
          break;
        }
        case 'seekAttention':
          // Walk over to the cursor's neighborhood, sit, and look up at it
          // hopefully. Petting from here satisfies; ignoring it long enough
          // sends the cat back to its day.
          animator.setPose('walk');
          state.targetX = state.mouse
            ? THREE.MathUtils.clamp(
                state.mouse.x + (state.worldX < state.mouse.x ? -0.55 : 0.55),
                state.minX, state.maxX
              )
            : state.worldX;
          state.timer = 14;
          break;
        case 'lie':
          animator.setPose('lie');
          animator.setLocomotion(0, 'walk');
          state.timer = (8 + random() * 14) * lazyScale();
          break;
        case 'sleep':
          animator.setPose('sleep');
          animator.setLocomotion(0, 'walk');
          state.timer = (20 + random() * 45) * lazyScale() * nightSleepScale();
          break;
        case 'stretch':
          animator.setPose('stretch');
          animator.setLocomotion(0, 'walk');
          state.timer = 2.4;
          break;
        case 'startle':
          // Woken or surprised: snap upright, eyes on the intruder.
          animator.setPose('stand');
          animator.setLocomotion(0, 'walk');
          state.timer = 1.4;
          break;
        case 'alert':
          animator.setPose('stand');
          animator.setLocomotion(0, 'walk');
          state.timer = 1.0 + random() * 1.5;
          break;
        case 'stalkMouse':
          animator.setPose('stalk');
          state.timer = 8;
          break;
        case 'lostMouse':
          // "Where did it go?" The cursor vanished mid-hunt: freeze low,
          // eyes pinned on the last spot it was seen, and wait a beat.
          animator.setPose('stalk');
          animator.setLocomotion(0, 'stalk');
          if (state.lastMouse) {
            animator.setHeading(state.lastMouse.x >= state.worldX ? 1 : -1);
            animator.setLookOverride({ x: state.lastMouse.x, y: state.lastMouse.y });
          }
          state.lostTimer = 0;
          state.timer = 1.8 + random() * 2.4;
          break;
        case 'crouchPounce':
          // The coiled wind-up before springing at the cursor: drop low,
          // lock on, and do the butt-wiggle, then launch.
          animator.setPose('stalk');
          animator.setLocomotion(0, 'stalk');
          if (state.mouse) faceMouse();
          state.timer = 0.34 + random() * 0.18;
          if (animator.triggerWiggle) animator.triggerWiggle(state.timer);
          break;
        case 'mouseProbe':
          animator.setPose('stalk');
          animator.setLocomotion(0, 'stalk');
          if (state.mouse) faceMouse();
          state.timer = 0.34 + random() * 0.24;
          animator.triggerSwipe(random() < 0.45, 'probe');
          armMouseCatch(0.55);
          break;
        case 'mouseFeint':
          animator.setPose('stalk');
          animator.setLocomotion(0, 'stalk');
          if (state.mouse) faceMouse();
          state.timer = 0.36 + random() * 0.30;
          if (animator.triggerWiggle) animator.triggerWiggle(Math.max(0.30, state.timer * 0.8));
          break;
        case 'bugWatch':
          animator.setPose('stand');
          animator.setLocomotion(0, 'walk');
          faceBugTarget();
          state.timer = 0.65 + random() * 0.8;
          break;
        case 'bugStalk':
          animator.setPose('stalk');
          faceBugTarget();
          state.timer = 3.5 + random() * 3.5;
          break;
        case 'bugCoil':
          animator.setPose('stalk');
          animator.setLocomotion(0, 'stalk');
          faceBugTarget();
          state.timer = 0.34 + random() * 0.20;
          // The pre-pounce butt-wiggle: load the haunches and waggle.
          if (animator.triggerWiggle) animator.triggerWiggle(state.timer);
          break;
        case 'bugSwat':
          animator.setPose('stand');
          animator.setLocomotion(0, 'walk');
          faceBugTarget();
          animator.triggerSwipe(random() < 0.45);
          state.timer = 0.52;
          break;
        case 'bugEat':
          animator.setPose('bugEat');
          animator.setLocomotion(0, 'walk');
          state.needs.play = Math.max(0, state.needs.play - 0.18);
          state.timer = 2.2 + random() * 1.4;
          state.bugEatTimer = state.timer;
          if (animator.triggerBugEat) animator.triggerBugEat();
          break;
        case 'pounce':
          animator.setPose('stalk');
          animator.triggerPounce(state.pendingPounceStyle || 'groundPounce');
          state.timer = state.pendingPounceStyle === 'sidePounce' ? 0.42 : 0.5;
          state.pendingPounceStyle = 'groundPounce';
          break;
        case 'swipe':
          animator.setPose('stand');
          animator.setLocomotion(0, 'walk');
          state.swipeChained = false;
          state.timer = 0.6;
          break;
        case 'mouseCling':
          animator.setPose('mouseCling');
          animator.setLocomotion(0, 'walk');
          if (animator.startMouseCling) animator.startMouseCling();
          state.catchArmed = false;
          state.catchWindow = 0;
          state.catchDelay = 0;
          state.clingLostTimer = 0;
          state.mouseInterest = 0;
          state.timer = 0;
          if (state.mouse) faceMouse();
          break;
        case 'wallApproach':
          // Walk right up to the screen edge before any wall interaction —
          // rubbing or scratching from a distance reads as pawing at air.
          animator.setPose('walk');
          state.targetX = wallApproachX(state.contactSide);
          state.timer = 9;
          break;
        case 'wallInspect':
          animator.setPose('wallInspect');
          animator.setLocomotion(0, 'walk');
          faceContactSide();
          state.timer = 1.4 + random() * 1.5;
          break;
        case 'wallRub':
          animator.setPose('wallRub');
          animator.setLocomotion(0, 'walk');
          faceContactSide();
          state.timer = 2.3 + random() * 1.4;
          break;
        case 'wallScratch':
          animator.setPose('wallScratch');
          animator.setLocomotion(0, 'walk');
          faceContactSide();
          state.timer = 2.4 + random() * 1.2;
          break;
        case 'dockInspect':
          animator.setPose('dockInspect');
          animator.setLocomotion(0, 'walk');
          state.timer = 1.8 + random() * 1.8;
          break;
        case 'dockPaw':
          animator.setPose('dockPaw');
          animator.setLocomotion(0, 'walk');
          animator.triggerDockPaw();
          state.timer = 0.8;
          break;
        case 'dockRest':
          animator.setPose('loaf');
          animator.setLocomotion(0, 'walk');
          state.timer = (9 + random() * 18) * lazyScale();
          break;
        case 'gnomeApproach':
          animator.setPose('walk');
          animator.setLocomotion(0, 'walk');
          clearPendingMouseCatch();
          clearGnomeRiding();
          if (state.gnomeFocus) {
            state.targetX = territoryWatchSpot(state.gnomeFocus);
          }
          state.timer = 12;
          break;
        case 'gnomeWatch':
          animator.setPose(random() < 0.45 ? 'sit' : 'loaf');
          animator.setLocomotion(0, 'walk');
          clearPendingMouseCatch();
          faceGnomeTerritory();
          state.timer = 4.5 + random() * (7.5 + personality.curiosity * 4);
          break;
        case 'gnomeRide': {
          animator.setPose('trot');
          animator.setLocomotion(0, 'trot');
          clearPendingMouseCatch();
          state.gnomeRiding = {
            active: true,
            phase: 'mounting',
            progress: 0,
            riderCount: 1 + Math.floor(random() * 2),
            heading: state.gnomeRideDirection,
            velocityX: 0,
            turning: false,
            stride: 0,
            lastX: state.worldX,
            mission: null,
            missionPhase: 'none',
            depthTrend: 'lateral',
            depthScale: 1,
            depthScaleTarget: 1,
            depthLiftY: 0,
            collectProgress: 0
          };
          const mission = beginGnomeMountedCollectionMission();
          if (!mission) {
            setGnomeRideTarget(1.0 + random() * 1.2);
          }
          state.timer = mission
            ? mission.rideOutDuration + mission.collectDuration + mission.rideHomeDuration + 1.8
            : 6.5 + random() * 5.0;
          break;
        }
        case 'gnomeDismount':
          animator.setPose('sit');
          animator.setLocomotion(0, 'walk');
          state.gnomeRiding = {
            active: true,
            phase: 'dismounting',
            progress: 0,
            riderCount: state.gnomeRiding.riderCount || 1,
            heading: animator.state.heading || state.gnomeRideDirection || 1,
            velocityX: 0,
            turning: false,
            stride: state.gnomeRiding.stride || 0,
            lastX: state.worldX,
            mission: state.gnomeRiding.mission || null,
            missionPhase: 'dismounting',
            depthTrend: state.gnomeRiding.depthTrend || 'lateral',
            depthScale: state.gnomeRiding.depthScale || 1,
            depthScaleTarget: state.gnomeRiding.depthScaleTarget || 1,
            depthLiftY: state.gnomeRiding.depthLiftY || 0,
            collectProgress: state.gnomeRiding.collectProgress || 0
          };
          faceGnomeTerritory();
          state.timer = 1.6;
          break;
      }
    }

    function nextFromIdle() {
      const p = personality;
      const needs = state.needs;
      if (maybeEnterGnomeInteraction()) return;
      if (maybeInvestigateMemory()) return;
      // Missing company: a socially hungry cat goes and sits near the
      // cursor, asking for attention.
      if (needs.social > 0.72 && mouseIsFresh() && mouseDistance() > 1.1
          && state.mood !== 'sleepy' && random() < 0.25 + state.memory.trust * 0.35) {
        enter('seekAttention');
        return;
      }
      if (maybeReturnToFavoriteSpot()) return;
      if (maybeEnterPlantCuriosity()) return;
      if (state.scratchCooldown <= 0 && state.wallCooldown <= 0
          && random() < 0.10 + p.playfulness * 0.10) {
        startScratchingPostTrip();
        return;
      }
      // Mood and needs reshape the menu: a frisky cat patrols and zooms, a
      // sleepy one melts toward the ground.
      const tired = 1.5 - needs.energy;
      const lively = 0.3 + needs.energy * 0.9;
      // Time of day reshapes the whole menu: at the dawn/dusk peaks the cat
      // roams and zooms; through the night it melts toward the floor and sleeps.
      const day = circadianDayDrive();
      const sleepPress = 1 - day;
      enter(pickWeighted(random, [
        ['wander', 0.40 * (0.4 + p.activity * 1.2) * lively * (0.35 + day)],
        ['sit', 0.24 * (0.6 + day * 0.5)],
        [chooseGroomingState('default'), 0.06 * (0.6 + p.curiosity * 0.7) * tired * (0.7 + needs.groomNeed * 2.2)],
        ['loaf', 0.09 * tired * (1 + sleepPress * 2.0)],
        ['lie', 0.11 * tired * (1 + sleepPress * 3.0)],
        ['bellyUp', 0.07 * (0.4 + needs.social * 0.7 + state.memory.trust * 0.9) * day],
        ['zoomies', 0.07 * (0.3 + p.playfulness * 1.6) * (needs.play + 0.2) * lively * (0.15 + day * 1.5)],
        ['scratchEar', 0.05],
        ['idle', 0.12 * (1 + sleepPress)]
      ]));
    }

    function walkToward(dt, speed, gait) {
      const preferredDirection = state.targetX >= state.worldX ? 1 : -1;
      state.targetX = safeXOutsideGnomeTerritories(state.targetX, preferredDirection);
      const dx = state.targetX - state.worldX;
      const currentHeading = animator.state.heading || 1;
      const arrived = Math.abs(dx) < 0.12;
      const heading = Math.abs(dx) < 0.04 ? currentHeading : dx >= 0 ? 1 : -1;
      animator.setHeading(heading);
      if (arrived) {
        animator.setLocomotion(0, gait);
        return true;
      }
      if (animator.isTurning()) {
        animator.setLocomotion(TURN_CREEP, gait);
      } else {
        animator.setLocomotion(speed, gait);
      }
      state.worldX += animator.state.speed * heading * dt;
      state.worldX = safeXOutsideGnomeTerritories(
        THREE.MathUtils.clamp(state.worldX, state.minX, state.maxX),
        heading
      );
      return false;
    }

    function holdForHesitation(dt, target) {
      if (state.intent.hesitation <= 0) return false;
      if (Math.abs(state.targetX - state.worldX) < 0.12) {
        state.intent.hesitation = 0;
        return false;
      }
      state.intent.hesitation = Math.max(0, state.intent.hesitation - dt);
      animator.setLocomotion(0, 'walk');
      if (target) animator.setLookOverride(target);
      return true;
    }

    function rememberLookBack(target) {
      if (!target || !Number.isFinite(target.x) || !Number.isFinite(target.y)) return;
      state.intent.lookBack = {
        x: target.x,
        y: target.y,
        timer: 1.1 + random() * 1.2
      };
    }

    function mouseIsFresh() {
      return state.mouse && state.mouse.age < MOUSE_STALE_SECONDS;
    }

    function mouseDistance() {
      return Math.abs(state.mouse.x - state.worldX);
    }

    function faceMouse() {
      animator.setHeading(state.mouse.x >= state.worldX ? 1 : -1);
    }

    function faceContactSide() {
      animator.setHeading(state.contactSide === 'left' ? -1 : 1);
    }

    function isResting() {
      return state.name === 'loaf' || state.name === 'lie'
        || state.name === 'sleep' || state.name === 'dockRest'
        || state.name === 'bellyUp' || state.name === 'bellyPet'
        || state.name === 'plantRest';
    }

    function isBellyExposed() {
      return state.name === 'bellyUp' || state.name === 'playOnBack'
        || state.name === 'bellyPet';
    }

    function clearPendingMouseCatch() {
      state.catchArmed = false;
      state.catchWindow = 0;
      state.catchDelay = 0;
      state.lunge = null;
    }

    function isMouseDriven() {
      return state.name === 'startle' || state.name === 'alert'
        || state.name === 'lostMouse'
        || MOUSE_STRIKE_STATES.includes(state.name);
    }

    function isBugDriven() {
      return BUG_STATES.includes(state.name);
    }

    function isEnvironmentDriven() {
      return state.name === 'wallApproach' || state.name === 'wallInspect'
        || state.name === 'wallRub' || state.name === 'wallScratch'
        || state.name === 'dockInspect' || state.name === 'dockPaw'
        || state.name === 'dockRest' || GNOME_STATES.includes(state.name)
        || PLANT_STATES.includes(state.name) || isClimbing();
    }

    function isClimbing() {
      return state.name === 'wallClimb' || state.name === 'wallHang'
        || state.name === 'wallJumpDown';
    }

    // States where the cat is physically pinned to the screen edge (climbing,
    // hanging, jumping down, or pressing nose/cheek/claws to the glass). These
    // intentionally sit closer to the edge than the walking bounds allow, so the
    // per-frame roaming clamp must not pull them back in — their pin functions
    // (pinClimbingBodyToWall / pinContactToWall) own worldX instead.
    function isWallContact() {
      return state.name === 'wallInspect' || state.name === 'wallRub'
        || state.name === 'wallScratch' || isClimbing();
    }

    function favoriteSpotX() {
      return safeXOutsideGnomeTerritories(
        THREE.MathUtils.clamp(state.memory.favoriteX, state.minX, state.maxX)
      );
    }

    function rememberPointOfInterest(kind, x, y, strength = 0.35) {
      if (!Number.isFinite(x) || !Number.isFinite(y) || isInsideGnomeTerritory(x, y)) return;
      const mem = state.memory;
      const incoming = THREE.MathUtils.clamp(strength, 0, 1);
      const old = (mem.poiKind === kind || Math.abs(mem.poiX - x) < 0.45)
        ? mem.poiWeight * 0.7
        : mem.poiWeight * 0.25;
      const total = old + incoming;
      mem.poiX = total > 0 ? (mem.poiX * old + x * incoming) / total : x;
      mem.poiY = total > 0 ? (mem.poiY * old + y * incoming) / total : y;
      mem.poiKind = kind;
      mem.poiWeight = Math.min(1, total);
      mem.poiAge = 0;
    }

    function rememberLastMouse(strength = 0.45) {
      if (state.lastMouse) rememberPointOfInterest('cursor', state.lastMouse.x, state.lastMouse.y, strength);
    }

    function tickMemory(dt) {
      const mem = state.memory;
      if (isResting() && state.name !== 'bellyPet') {
        if (mem.favoriteWeight <= 0.02) mem.favoriteX = state.worldX;
        mem.favoriteX = damp(mem.favoriteX, state.worldX, state.name === 'sleep' ? 0.12 : 0.08, dt);
        mem.favoriteWeight = Math.min(1, mem.favoriteWeight + dt * (state.name === 'sleep' ? 0.010 : 0.006));
      } else {
        mem.favoriteWeight = Math.max(0, mem.favoriteWeight - dt * 0.00003);
      }
      if (mem.poiWeight > 0) {
        mem.poiAge += dt;
        mem.poiWeight = Math.max(0, mem.poiWeight - dt * (mem.poiAge > 45 ? 0.025 : 0.006));
        if (mem.poiWeight <= 0) mem.poiKind = 'none';
      }
      mem.trust = damp(mem.trust, 0.48, 0.0008, dt);
    }

    function maybeInvestigateMemory() {
      const mem = state.memory;
      if (mouseIsFresh() || mem.poiWeight < 0.34 || state.mood === 'sleepy') return false;
      if (isInsideGnomeTerritory(mem.poiX, mem.poiY)) {
        mem.poiWeight = 0;
        mem.poiKind = 'none';
        return false;
      }
      if (random() > mem.poiWeight * (0.18 + personality.curiosity * 0.38)) return false;
      state.investigation = {
        kind: mem.poiKind,
        x: THREE.MathUtils.clamp(mem.poiX, state.minX, state.maxX),
        y: THREE.MathUtils.clamp(mem.poiY, 0.10, 1.60),
        settled: false
      };
      enter('investigateSpot');
      return true;
    }

    function maybeReturnToFavoriteSpot() {
      const mem = state.memory;
      if (mem.favoriteWeight < 0.42 || state.mood === 'frisky') return false;
      const target = favoriteSpotX();
      if (Math.abs(target - state.worldX) < 0.55) return false;
      const odds = mem.favoriteWeight * (0.10 + (1 - state.needs.energy) * 0.22 + (state.mood === 'sleepy' ? 0.22 : 0));
      if (random() > odds) return false;
      enter('returnToFavorite');
      return true;
    }

    function plantSniffSpot(plant) {
      const side = plant.x >= state.worldX ? -1 : 1;
      return safeXOutsideGnomeTerritories(
        THREE.MathUtils.clamp(plant.x + side * PLANT_SNIFF_OFFSET, state.minX, state.maxX),
        side
      );
    }

    function bestPlantCuriosityTarget() {
      let best = null;
      let bestScore = -Infinity;
      for (const plant of state.gnomePlantTargets) {
        if (!plant || !plant.id || isInsideGnomeTerritory(plant.x, plant.y)) continue;
        const dx = Math.abs(plant.x - state.worldX);
        if (dx > PLANT_CURIOSITY_RANGE) continue;
        const score = (plant.resourceValue || 0) * 0.85
          + (plant.canopyHeight || 0) * 0.75
          + (plant.canClimb ? 0.18 : 0)
          - dx * 0.16;
        if (score > bestScore) {
          best = plant;
          bestScore = score;
        }
      }
      return best;
    }

    function maybeEnterPlantCuriosity() {
      if (state.plantCooldown > 0 || state.gnomePlantTargets.length === 0
          || state.mood === 'sleepy' || isMouseDriven() || isBugDriven()
          || isEnvironmentDriven()) {
        return false;
      }
      const plant = bestPlantCuriosityTarget();
      if (!plant) return false;
      const odds = 0.10 + personality.curiosity * 0.22
        + (plant.resourceValue || 0) * 0.12
        + (state.needs.energy < 0.50 ? 0.08 : 0);
      if (random() > odds) return false;
      state.plantFocus = plant;
      state.plantCooldown = 45 + random() * 80;
      enter('plantApproach');
      return true;
    }

    function territoryBlocksX(territory, x, padding = GNOME_TERRITORY_PADDING) {
      return territory
        && x >= territory.minX - padding
        && x <= territory.maxX + padding;
    }

    function shouldRespectGnomeTerritories() {
      return !!personality.respectGnomeTerritories;
    }

    function pointInTerritoryPolygon(territory, x, y) {
      const points = territory && Array.isArray(territory.points) ? territory.points : [];
      if (points.length < 3) return false;
      let inside = false;
      for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
        const xi = points[i].x;
        const yi = points[i].y;
        const xj = points[j].x;
        const yj = points[j].y;
        const intersects = ((yi > y) !== (yj > y))
          && x < ((xj - xi) * (y - yi)) / ((yj - yi) || 0.00001) + xi;
        if (intersects) inside = !inside;
      }
      return inside;
    }

    function isInsideGnomeTerritory(x, y = 0.35) {
      if (!shouldRespectGnomeTerritories()) return false;
      return state.gnomeTerritories.some((territory) =>
        pointInTerritoryPolygon(territory, x, y) || territoryBlocksX(territory, x)
      );
    }

    function mouseInsideGnomeTerritory() {
      return !!state.mouse && isInsideGnomeTerritory(state.mouse.x, state.mouse.y);
    }

    function safeXOutsideGnomeTerritories(x, preferredDirection = 0) {
      let safeX = THREE.MathUtils.clamp(x, state.minX, state.maxX);
      if (!shouldRespectGnomeTerritories()) return safeX;
      for (let pass = 0; pass < 8; pass++) {
        const territory = state.gnomeTerritories.find((candidate) => territoryBlocksX(candidate, safeX));
        if (!territory) break;
        const left = THREE.MathUtils.clamp(territory.minX - GNOME_TERRITORY_PADDING - 0.18, state.minX, state.maxX);
        const right = THREE.MathUtils.clamp(territory.maxX + GNOME_TERRITORY_PADDING + 0.18, state.minX, state.maxX);
        if (preferredDirection < 0) safeX = left;
        else if (preferredDirection > 0) safeX = right;
        else safeX = Math.abs(left - safeX) <= Math.abs(right - safeX) ? left : right;
        if (safeX <= state.minX + 0.01 || safeX >= state.maxX - 0.01) break;
      }
      return safeX;
    }

    function gnomeRideDirectionFromPosition() {
      const mission = state.gnomeRiding && state.gnomeRiding.mission;
      if (mission && Number.isFinite(mission.targetX)) {
        const dx = mission.targetX - state.worldX;
        if (Math.abs(dx) > 0.05) return dx >= 0 ? 1 : -1;
      }
      if (state.worldX - state.minX < GNOME_RIDE_EDGE_MARGIN) return 1;
      if (state.maxX - state.worldX < GNOME_RIDE_EDGE_MARGIN) return -1;
      const territory = state.gnomeFocus || nearestGnomeTerritory();
      if (territory) return territory.centerX < state.worldX ? 1 : -1;
      return animator.state.heading || state.gnomeRideDirection || 1;
    }

    function setGnomeRideTarget(distance) {
      const direction = gnomeRideDirectionFromPosition();
      state.gnomeRideDirection = direction;
      const target = THREE.MathUtils.clamp(
        state.worldX + direction * distance,
        state.minX + GNOME_RIDE_EDGE_PADDING,
        state.maxX - GNOME_RIDE_EDGE_PADDING
      );
      state.targetX = safeXOutsideGnomeTerritories(target, direction);
    }

    function chooseGnomePlantMissionTarget(territory) {
      if (!territory || !state.gnomePlantTargets.length) return null;
      let best = null;
      let bestScore = -Infinity;
      for (const plant of state.gnomePlantTargets) {
        if (!plant || !plant.id) continue;
        if ((plant.resourceValue || 0) < GNOME_MISSION_MIN_RESOURCE) continue;
        if (state.gnomeTerritories.some((candidate) => pointInTerritoryPolygon(candidate, plant.x, plant.y))) continue;
        const dx = plant.x - territory.centerX;
        const dy = plant.y - territory.centerY;
        const distance = Math.hypot(dx, dy);
        if (distance < 0.32) continue;
        const distanceSweetSpot = 1 / (1 + Math.abs(distance - 1.25) * 0.55);
        const depthInterest = Math.min(0.42, Math.abs(dy) * 0.18);
        const climbBonus = plant.canClimb ? 0.22 : 0;
        const canopyBonus = Math.min(0.24, (plant.canopyHeight || 0) * 0.62);
        const score = (plant.resourceValue || 0) * 1.25
          + distanceSweetSpot
          + depthInterest
          + climbBonus
          + canopyBonus;
        if (score > bestScore) {
          best = plant;
          bestScore = score;
        }
      }
      return best;
    }

    function gnomeMissionPerspective(territory, plant) {
      const dy = (plant ? plant.y : 0) - (territory ? territory.centerY : 0);
      const depthTrend = dy > 0.16 ? 'away' : (dy < -0.16 ? 'toward' : 'lateral');
      const amount = THREE.MathUtils.clamp(Math.abs(dy) * 0.18 + (plant && plant.canopyHeight ? plant.canopyHeight * 0.18 : 0), 0, 0.22);
      if (depthTrend === 'away') {
        return {
          depthTrend,
          depthScaleTarget: THREE.MathUtils.clamp(1 - amount, 0.76, 0.98),
          depthLiftTarget: THREE.MathUtils.clamp(0.06 + Math.abs(dy) * 0.14, 0.08, 0.42)
        };
      }
      if (depthTrend === 'toward') {
        return {
          depthTrend,
          depthScaleTarget: THREE.MathUtils.clamp(1 + amount * 0.72, 1.02, 1.16),
          depthLiftTarget: THREE.MathUtils.clamp(-0.04 - Math.abs(dy) * 0.04, -0.14, -0.02)
        };
      }
      return {
        depthTrend,
        depthScaleTarget: 1,
        depthLiftTarget: 0
      };
    }

    function beginGnomeMountedCollectionMission() {
      const territory = state.gnomeFocus || nearestGnomeTerritory();
      const plant = chooseGnomePlantMissionTarget(territory);
      if (!territory || !plant) return null;
      const perspective = gnomeMissionPerspective(territory, plant);
      const homeX = territoryWatchSpot(territory);
      const rideDistance = Math.abs(plant.x - state.worldX);
      const duration = THREE.MathUtils.clamp(4.2 + rideDistance * 2.2, 5.5, 11.5);
      const mission = {
        targetID: plant.id,
        species: plant.species || '',
        targetX: THREE.MathUtils.clamp(plant.x, state.minX + GNOME_RIDE_EDGE_PADDING, state.maxX - GNOME_RIDE_EDGE_PADDING),
        targetY: plant.y,
        homeX,
        homeY: territory.centerY,
        resourceValue: plant.resourceValue || 0,
        canopyHeight: plant.canopyHeight || 0,
        canClimb: !!plant.canClimb,
        startedAtX: state.worldX,
        phaseTime: 0,
        rideOutDuration: duration,
        rideHomeDuration: Math.max(4.2, duration * 0.82),
        collectDuration: GNOME_MISSION_COLLECT_SECONDS + Math.min(0.95, (plant.canopyHeight || 0) * 2.2),
        depthTrend: perspective.depthTrend,
        depthScaleTarget: perspective.depthScaleTarget,
        depthLiftTarget: perspective.depthLiftTarget
      };
      state.gnomeRiding.mission = mission;
      state.gnomeRiding.missionPhase = 'rideOut';
      state.gnomeRiding.depthTrend = perspective.depthTrend;
      state.gnomeRiding.depthScaleTarget = perspective.depthScaleTarget;
      state.gnomeRiding.depthScale = 1;
      state.gnomeRiding.depthLiftY = 0;
      state.gnomeRiding.collectProgress = 0;
      state.targetX = mission.targetX;
      state.gnomeRideDirection = mission.targetX >= state.worldX ? 1 : -1;
      return mission;
    }

    function easeMission(u) {
      u = THREE.MathUtils.clamp(u, 0, 1);
      return u * u * (3 - 2 * u);
    }

    function updateGnomeMissionProjection(mission, phaseProgress) {
      if (!mission) {
        state.gnomeRiding.depthScale = damp(state.gnomeRiding.depthScale || 1, 1, 8, 1 / 60);
        state.gnomeRiding.depthLiftY = damp(state.gnomeRiding.depthLiftY || 0, 0, 8, 1 / 60);
        return;
      }
      const u = easeMission(phaseProgress);
      const outward = state.gnomeRiding.missionPhase === 'rideOut'
        || state.gnomeRiding.missionPhase === 'collecting';
      const depthU = outward ? u : (1 - u);
      const targetScale = 1 + ((mission.depthScaleTarget || 1) - 1) * depthU;
      const targetLift = (mission.depthLiftTarget || 0) * depthU;
      state.gnomeRiding.depthScale = targetScale;
      state.gnomeRiding.depthLiftY = targetLift;
      state.gnomeRiding.depthTrend = mission.depthTrend || 'lateral';
      state.gnomeRiding.depthScaleTarget = mission.depthScaleTarget || 1;
    }

    function stepGnomeMountedCollectionMission(dt) {
      const mission = state.gnomeRiding.mission;
      if (!mission) return false;
      mission.phaseTime += dt;
      state.gnomeRiding.missionPhase = state.gnomeRiding.missionPhase || 'rideOut';

      if (state.gnomeRiding.missionPhase === 'rideOut') {
        state.targetX = mission.targetX;
        animator.setLookOverride({
          x: mission.targetX,
          y: THREE.MathUtils.clamp(mission.targetY || 0.72, 0.28, 1.45)
        });
        updateGnomeMissionProjection(mission, mission.phaseTime / Math.max(0.1, mission.rideOutDuration));
        if (Math.abs(state.worldX - mission.targetX) < 0.16 || mission.phaseTime >= mission.rideOutDuration) {
          state.gnomeRiding.missionPhase = 'collecting';
          state.gnomeRiding.collectProgress = 0;
          mission.phaseTime = 0;
          animator.setLocomotion(0, 'walk');
        }
        return true;
      }

      if (state.gnomeRiding.missionPhase === 'collecting') {
        state.targetX = state.worldX;
        animator.setLookOverride({
          x: mission.targetX,
          y: THREE.MathUtils.clamp((mission.targetY || 0.72) + (mission.canClimb ? 0.28 : 0.10), 0.35, 1.55)
        });
        state.gnomeRiding.collectProgress = THREE.MathUtils.clamp(
          mission.phaseTime / Math.max(0.1, mission.collectDuration),
          0,
          1
        );
        updateGnomeMissionProjection(mission, 1);
        if (mission.phaseTime >= mission.collectDuration) {
          state.gnomeRiding.missionPhase = 'rideHome';
          mission.phaseTime = 0;
          state.targetX = mission.homeX;
          state.gnomeRideDirection = mission.homeX >= state.worldX ? 1 : -1;
        }
        return true;
      }

      if (state.gnomeRiding.missionPhase === 'rideHome') {
        state.targetX = mission.homeX;
        animator.setLookOverride({
          x: mission.homeX,
          y: THREE.MathUtils.clamp(mission.homeY || 0.52, 0.24, 1.20)
        });
        updateGnomeMissionProjection(mission, mission.phaseTime / Math.max(0.1, mission.rideHomeDuration));
        if (Math.abs(state.worldX - mission.homeX) < 0.16 || mission.phaseTime >= mission.rideHomeDuration) {
          state.gnomeRiding.missionPhase = 'dismounting';
          return false;
        }
        return true;
      }
      return false;
    }

    function nearestGnomeTerritory(x = state.worldX) {
      let best = null;
      let bestScore = Infinity;
      for (const territory of state.gnomeTerritories) {
        const dx = x < territory.minX
          ? territory.minX - x
          : x > territory.maxX
            ? x - territory.maxX
            : 0;
        if (dx < bestScore) {
          best = territory;
          bestScore = dx;
        }
      }
      return best && bestScore < GNOME_WATCH_RANGE ? best : null;
    }

    function territoryWatchSpot(territory) {
      const left = THREE.MathUtils.clamp(
        territory.minX - GNOME_TERRITORY_PADDING - 0.30,
        state.minX,
        state.maxX
      );
      const right = THREE.MathUtils.clamp(
        territory.maxX + GNOME_TERRITORY_PADDING + 0.30,
        state.minX,
        state.maxX
      );
      const leftDistance = Math.abs(state.worldX - left);
      const rightDistance = Math.abs(state.worldX - right);
      const prefer = leftDistance <= rightDistance ? -1 : 1;
      return safeXOutsideGnomeTerritories(prefer < 0 ? left : right, prefer);
    }

    function faceGnomeTerritory() {
      const territory = state.gnomeFocus || nearestGnomeTerritory();
      if (!territory) return;
      animator.setHeading(territory.centerX >= state.worldX ? 1 : -1);
      animator.setLookOverride({
        x: territory.centerX,
        y: THREE.MathUtils.clamp(territory.centerY, 0.25, 1.35)
      });
    }

    function clearGnomeRiding() {
      state.gnomeRiding = {
        active: false,
        phase: 'none',
        progress: 0,
        riderCount: 0,
        heading: animator.state.heading || 1,
        velocityX: 0,
        turning: false,
        stride: 0,
        mission: null,
        missionPhase: 'none',
        depthTrend: 'lateral',
        depthScale: 1,
        depthScaleTarget: 1,
        depthLiftY: 0,
        collectProgress: 0
      };
    }

    function scheduleGnomeCooldown() {
      state.gnomeCooldown = 35 + random() * (55 - personality.curiosity * 20);
    }

    function scheduleGnomeRideCooldown() {
      state.gnomeRideCooldown = GNOME_RIDE_MIN_COOLDOWN
        + random() * (GNOME_RIDE_MAX_COOLDOWN - GNOME_RIDE_MIN_COOLDOWN);
    }

    function canEnterGnomeInteraction() {
      return state.gnomeTerritories.length > 0
        && state.gnomeCooldown <= 0
        && !isMouseDriven()
        && !isBugDriven()
        && !isEnvironmentDriven()
        && !isClimbing()
        && state.name !== 'investigateSpot'
        && state.name !== 'returnToFavorite'
        && state.name !== 'petted'
        && state.name !== 'bellyPet'
        && state.name !== 'sleep';
    }

    function maybeEnterGnomeInteraction() {
      if (!canEnterGnomeInteraction()) return false;
      const territory = nearestGnomeTerritory();
      if (!territory) return false;
      state.gnomeFocus = territory;
      state.targetX = territoryWatchSpot(territory);
      enter('gnomeApproach');
      return true;
    }

    function bugByID(id) {
      return state.bugs.find((bug) => bug.id === id) || null;
    }

    function currentBugTarget() {
      if (state.targetBugID) {
        const existing = bugByID(state.targetBugID);
        if (existing) return existing;
      }
      return bestBugTarget();
    }

    function bestBugTarget() {
      let best = null;
      let bestScore = Infinity;
      for (const bug of state.bugs) {
        if (!bug || bug.age > BUG_STALE_SECONDS) continue;
        if (bug.y < BUG_MIN_HEIGHT || bug.y > BUG_MAX_HEIGHT) continue;
        if (isInsideGnomeTerritory(bug.x, bug.y)) continue;
        const dx = Math.abs(bug.x - state.worldX);
        if (dx > BUG_WATCH_RANGE) continue;
        const aim = bugAimPoint(bug);
        const verticalPenalty = aim.y > 1.1 ? (aim.y - 1.1) * 0.55 : 0;
        const plantBonus = bug.plantFocused ? -0.22 : 0;
        const currentTargetBonus = bug.id === state.targetBugID ? -0.34 : 0;
        const focusBonus = bug.id === state.bugFocus.id ? -state.bugFocus.lock * 0.26 : 0;
        const score = dx + Math.abs(aim.y - 0.58) * 0.35
          + verticalPenalty + plantBonus + currentTargetBonus + focusBonus;
        if (score < bestScore) {
          best = bug;
          bestScore = score;
        }
      }
      return best;
    }

    function bugAimPoint(bug) {
      if (!bug) return { x: state.worldX, y: 0.55 };
      const focus = bug.id === state.bugFocus.id ? state.bugFocus.lock : 0;
      const lead = BUG_LEAD_SECONDS + Math.min(0.16, focus * 0.08);
      return {
        x: THREE.MathUtils.clamp(
          bug.x + (bug.vx || 0) * lead,
          state.minX - 0.20,
          state.maxX + 0.20
        ),
        y: THREE.MathUtils.clamp(
          bug.y + (bug.vy || 0) * lead,
          BUG_MIN_HEIGHT,
          BUG_MAX_HEIGHT
        )
      };
    }

    function focusOnBug(bug, dt) {
      if (!bug) {
        state.bugFocus.lock = Math.max(0, state.bugFocus.lock - dt * 0.8);
        if (state.bugFocus.lock <= 0) state.bugFocus.id = null;
        return null;
      }

      const aim = bugAimPoint(bug);
      if (state.bugFocus.id !== bug.id) {
        state.bugFocus.id = bug.id;
        state.bugFocus.lock = 0;
        state.bugFocus.smoothX = aim.x;
        state.bugFocus.smoothY = aim.y;
      } else {
        const motion = Math.hypot(bug.vx || 0, bug.vy || 0);
        state.bugFocus.lock = THREE.MathUtils.clamp(
          state.bugFocus.lock
            + dt * (0.42 + Math.min(1.5, motion) * 0.54 + (bug.plantFocused ? 0.18 : 0)),
          0,
          1
        );
        state.bugFocus.smoothX = damp(state.bugFocus.smoothX, aim.x, 8, dt);
        state.bugFocus.smoothY = damp(state.bugFocus.smoothY, aim.y, 8, dt);
      }

      return {
        x: state.bugFocus.smoothX,
        y: state.bugFocus.smoothY
      };
    }

    function resetBugFacing() {
      state.bugFacing.id = null;
      state.bugFacing.heading = animator.state && animator.state.heading
        ? animator.state.heading
        : 1;
      state.bugFacing.pendingHeading = 0;
      state.bugFacing.pendingTime = 0;
    }

    function bugHeadingDeadZone(aim) {
      const overheadBoost = aim && aim.y > 0.95
        ? Math.min(0.16, (aim.y - 0.95) * 0.34)
        : 0;
      return BUG_HEADING_DEAD_ZONE + overheadBoost;
    }

    function stableBugHeading(bug, aim, dt) {
      const currentHeading = animator.state && animator.state.heading
        ? animator.state.heading
        : state.bugFacing.heading || 1;
      const dx = (aim ? aim.x : bug.x) - state.worldX;
      const deadZone = bugHeadingDeadZone(aim);

      if (state.bugFacing.id !== bug.id) {
        state.bugFacing.id = bug.id;
        state.bugFacing.heading = Math.abs(dx) > deadZone
          ? (dx >= 0 ? 1 : -1)
          : currentHeading;
        state.bugFacing.pendingHeading = 0;
        state.bugFacing.pendingTime = 0;
        return state.bugFacing.heading;
      }

      if (Math.abs(dx) <= deadZone) {
        state.bugFacing.pendingHeading = 0;
        state.bugFacing.pendingTime = 0;
        return state.bugFacing.heading || currentHeading;
      }

      const desiredHeading = dx >= 0 ? 1 : -1;
      if (desiredHeading === state.bugFacing.heading) {
        state.bugFacing.pendingHeading = 0;
        state.bugFacing.pendingTime = 0;
        return state.bugFacing.heading;
      }

      if (state.bugFacing.pendingHeading !== desiredHeading) {
        state.bugFacing.pendingHeading = desiredHeading;
        state.bugFacing.pendingTime = 0;
      }
      state.bugFacing.pendingTime += Math.max(0, dt || 0);

      const strongSide = Math.abs(dx) > deadZone + 0.34;
      const overheadPenalty = aim && aim.y > 1.05 ? 0.08 : 0;
      const commitSeconds = strongSide
        ? 0.04
        : BUG_HEADING_REVERSE_SECONDS + overheadPenalty;
      if (state.bugFacing.pendingTime >= commitSeconds) {
        state.bugFacing.heading = desiredHeading;
        state.bugFacing.pendingHeading = 0;
        state.bugFacing.pendingTime = 0;
      }

      return state.bugFacing.heading || currentHeading;
    }

    function faceBugTarget(dt = 0) {
      const bug = currentBugTarget();
      if (!bug) {
        resetBugFacing();
        return null;
      }
      const aim = focusOnBug(bug, dt) || bugAimPoint(bug);
      const heading = stableBugHeading(bug, aim, dt);
      animator.setHeading(heading);
      animator.setLookOverride(aim);
      return { bug, aim, heading };
    }

    function canInterruptForBug() {
      return !isMouseDriven()
        && !isEnvironmentDriven()
        && state.name !== 'petted'
        && state.name !== 'bellyPet'
        && state.name !== 'lungeRecover'
        && state.name !== 'wallJumpDown';
    }

    function scheduleBugCooldown(base = 8) {
      state.bugCooldown = base + random() * (18 + personality.playfulness * 10);
    }

    function tryCatchBug(bug, confidence) {
      if (!bug || bug.age > BUG_STALE_SECONDS) return false;
      const dx = Math.abs(bug.x - state.worldX);
      const dy = Math.abs(bug.y - 0.48);
      if (dx > BUG_CATCH_RANGE + confidence * 0.18 || dy > 0.88) return false;
      const odds = THREE.MathUtils.clamp(
        0.20 + confidence * 0.35 + personality.playfulness * 0.24
          + (bug.plantFocused ? 0.08 : 0),
        0.12,
        0.78
      );
      if (random() > odds) return false;

      state.bugs = state.bugs.filter((candidate) => candidate.id !== bug.id);
      state.targetBugID = null;
      state.bugFocus = { id: null, lock: 0, smoothX: 0, smoothY: 0 };
      resetBugFacing();
      state.bugStrike = null;
      scheduleBugCooldown(28);
      onBugCaught(bug.id, { species: bug.species });
      rememberPointOfInterest('caughtBug', bug.x, bug.y, 0.45);
      // A caught bug is a meal: it sates hunger and musses the coat (so the
      // post-meal groom that follows reads as motivated, not random).
      state.needs.hunger = Math.max(0, state.needs.hunger - 0.42);
      state.needs.groomNeed = Math.min(1, state.needs.groomNeed + 0.28);
      enter('bugEat');
      return true;
    }

    function maybeReactToBugs(dt) {
      for (const bug of state.bugs) bug.age += dt;
      state.bugs = state.bugs.filter((bug) => bug.age <= BUG_STALE_SECONDS);
      if (isBugDriven()) return false;
      if (!personality.mouseReactions || state.bugCooldown > 0 || !canInterruptForBug()) {
        return false;
      }

      const bug = bestBugTarget();
      if (!bug) return false;
      const aim = focusOnBug(bug, dt) || bugAimPoint(bug);
      const dx = Math.abs(bug.x - state.worldX);
      const close = dx < BUG_STRIKE_RANGE && bug.y < 1.18;
      const curiosityOdds = (0.14 + personality.curiosity * 0.24 + personality.playfulness * 0.16)
        * (bug.plantFocused ? 1.25 : 1);
      if (state.name === 'sleep' || isBellyExposed()) {
        return false;
      }
      rememberPointOfInterest('bug', aim.x, aim.y, dt * (0.20 + personality.curiosity * 0.30));
      if (isResting() && random() > 0.15 + personality.curiosity * 0.18) {
        animator.setLookOverride(aim);
        return false;
      }
      if (!isBugDriven()
          && state.bugFocus.lock < BUG_LOCK_TRIGGER
          && random() > curiosityOdds * dt) {
        if (dx < WATCH_RANGE * 0.7 && random() < 0.08) {
          animator.setLookOverride(aim);
        }
        return false;
      }

      state.targetBugID = bug.id;
      enter(close ? 'bugWatch' : 'bugStalk');
      return true;
    }

    function startBugLunge(bug) {
      if (!bug) return false;
      const aim = focusOnBug(bug, 0) || bugAimPoint(bug);
      const targetPawX = safeXOutsideGnomeTerritories(
        THREE.MathUtils.clamp(aim.x, state.minX - 0.25, state.maxX + 0.25),
        aim.x >= state.worldX ? 1 : -1
      );
      const targetPawY = THREE.MathUtils.clamp(aim.y, 0.20, BUG_MAX_HEIGHT);
      const dist = Math.abs(targetPawX - state.worldX);
      faceBugTarget();
      state.bugStrike = {
        id: bug.id,
        species: bug.species,
        t: 0,
        duration: THREE.MathUtils.clamp(0.24 + dist * 0.20, 0.30, 0.54),
        startX: state.worldX,
        startY: state.worldY,
        targetPawX,
        targetPawY,
        arc: 0.12 + dist * 0.09 + Math.max(0, targetPawY - 0.7) * 0.05
      };
      state.bugCooldown = 6 + random() * 10;
      animator.setPose('lungeAir');
      animator.setLocomotion(0, 'walk');
      animator.triggerLunge(state.bugStrike.duration);
      animator.setAgility(1.95);
      state.name = 'bugLunge';
      state.timer = state.bugStrike.duration + 0.25;
      return true;
    }

    function updateBugLunge(dt) {
      const strike = state.bugStrike;
      if (!strike) {
        enter('alert');
        return;
      }
      strike.t = Math.min(1, strike.t + dt / strike.duration);
      const tau = strike.t;
      const liveBug = bugByID(strike.id);
      if (liveBug && tau < 0.58) {
        const aim = focusOnBug(liveBug, dt) || bugAimPoint(liveBug);
        strike.targetPawX = damp(strike.targetPawX, aim.x, 3.5, dt);
        strike.targetPawY = damp(strike.targetPawY, aim.y, 3.5, dt);
      }
      const anchor = animator.getPawAnchor();
      const rootTargetX = safeXOutsideGnomeTerritories(
        THREE.MathUtils.clamp(strike.targetPawX - anchor.x, state.minX, state.maxX),
        strike.targetPawX >= state.worldX ? 1 : -1
      );
      const rootTargetY = Math.max(0, strike.targetPawY - anchor.yAbs);
      state.worldX = strike.startX + (rootTargetX - strike.startX) * tau;
      state.worldY = Math.max(0,
        strike.startY + (rootTargetY - strike.startY) * tau + strike.arc * Math.sin(tau * Math.PI));
      animator.setLookOverride({ x: strike.targetPawX, y: strike.targetPawY });

      if (tau >= 0.70 && liveBug && tryCatchBug(liveBug, 0.75)) {
        return;
      }
      if (tau >= 1) {
        rememberPointOfInterest('missedBug', strike.targetPawX, strike.targetPawY, 0.35);
        state.bugStrike = null;
        animator.cancelLunge();
        scheduleBugCooldown(12);
        enter('lungeRecover');
      }
    }

    // The wall is the physical screen edge. Side Dock / Stage Manager insets
    // still shape walking bounds, but a climbing cat should visibly put its
    // paws on the glass edge rather than hovering at the safe visible frame.
    function wallEdgeX(side) {
      const env = state.environment;
      const half = env.screenWidthWorld / 2;
      return side === 'left' ? -half : half;
    }

    function wallApproachX(side) {
      const edge = wallEdgeX(side);
      const bodyContactOffset = 0.72;
      const target = side === 'left'
        ? edge + bodyContactOffset
        : edge - bodyContactOffset;
      return THREE.MathUtils.clamp(target, state.minX, state.maxX);
    }

    // Servo the body so a measured contact point (paw tips or nose) sits
    // exactly on the wall plane — no guessed offsets, real contact.
    function pinContactToWall(dt, contactOffsetX, rate) {
      const target = wallEdgeX(state.contactSide) - contactOffsetX;
      state.worldX = damp(state.worldX, target, rate || 8, dt);
    }

    // Paw-tip anchoring can leave the cat's whole body visibly floating an
    // inch or two off the monitor edge. While climbing/hanging, pin the
    // wall-hugging body line instead so the silhouette reads as crawling
    // on the physical display edge.
    function pinClimbingBodyToWall(dt) {
      const sideSign = state.contactSide === 'left' ? -1 : 1;
      const target = wallEdgeX(state.contactSide) - sideSign * WALL_CLIMB_EDGE_INSET;
      state.worldX = damp(state.worldX, target, WALL_CLIMB_PIN_RATE, dt);
    }

    function scheduleWallCooldown() {
      state.wallCooldown = 45 + random() * 35;
    }

    function scheduleDockCooldown() {
      const curiosity = personality.curiosity;
      state.dockCooldown = 35 + random() * (55 - curiosity * 22);
    }

    function nearestWallSide() {
      const leftDistance = state.worldX - state.minX;
      const rightDistance = state.maxX - state.worldX;
      return leftDistance < rightDistance ? 'left' : 'right';
    }

    function distanceToNearestWall() {
      return Math.min(state.worldX - state.minX, state.maxX - state.worldX);
    }

    function mouseEdgeSide() {
      if (!mouseIsFresh()) return null;
      const mouse = state.mouse;
      const leftDistance = Math.abs(mouse.x - wallEdgeX('left'));
      const rightDistance = Math.abs(mouse.x - wallEdgeX('right'));
      const side = leftDistance <= rightDistance ? 'left' : 'right';
      const distance = Math.min(leftDistance, rightDistance);
      return distance <= EDGE_TEASE_RANGE ? side : null;
    }

    function climbTargetYFromMouse() {
      const env = state.environment;
      const maxY = Math.max(
        0.8,
        env.screenHeightWorld * (1 - env.effectiveGroundFraction) - 0.85
      );
      if (!state.mouse) return maxY * 0.55;
      return THREE.MathUtils.clamp(state.mouse.y, 0.55, maxY);
    }

    function startMouseEdgeClimb(side) {
      state.contactSide = side;
      state.pendingWallAction = 'wallClimb';
      state.climbTargetYOverride = climbTargetYFromMouse();
      state.edgeTease.score = 0;
      state.edgeTease.side = side;
      state.wallCooldown = Math.max(state.wallCooldown, 8);
      state.climbCooldown = Math.max(state.climbCooldown, 35);
      if (state.name === 'wallClimb' || state.name === 'wallHang') {
        state.climbTargetY = state.climbTargetYOverride;
        state.climbTargetYOverride = null;
        if (state.mouse) animator.setLookOverride({ x: state.mouse.x, y: state.mouse.y });
        return true;
      }
      if (state.name === 'mouseCling' || state.name === 'lunge' || state.name === 'wallJumpDown') {
        return false;
      }
      enter('wallApproach');
      return true;
    }

    function updateEdgeTease(dt) {
      const side = mouseEdgeSide();
      if (!side || !state.mouse) {
        state.edgeTease.score = Math.max(0, state.edgeTease.score - dt * EDGE_TEASE_DECAY);
        if (state.edgeTease.score === 0) {
          state.edgeTease.side = null;
          state.edgeTease.lastDir = 0;
        }
        return false;
      }

      const mouse = state.mouse;
      const verticalSpeed = Math.abs(mouse.vy || 0);
      const dir = Math.sign(mouse.vy || 0);
      if (state.edgeTease.side !== side) {
        state.edgeTease.side = side;
        state.edgeTease.score = 0;
        state.edgeTease.lastDir = 0;
      }

      if (verticalSpeed > EDGE_TEASE_MIN_VERTICAL_SPEED) {
        const reversalBonus = dir !== 0 && state.edgeTease.lastDir !== 0 && dir !== state.edgeTease.lastDir
          ? 0.22
          : 0;
        state.edgeTease.score = Math.min(
          EDGE_TEASE_TRIGGER + 0.6,
          state.edgeTease.score
            + dt * (0.65 + verticalSpeed * 1.25) * (0.55 + personality.curiosity * 0.7)
            + reversalBonus
        );
        if (dir !== 0) state.edgeTease.lastDir = dir;
      } else {
        state.edgeTease.score = Math.max(0, state.edgeTease.score - dt * EDGE_TEASE_DECAY * 0.5);
      }

      if ((state.name === 'wallClimb' || state.name === 'wallHang') && state.contactSide === side) {
        state.climbTargetY = climbTargetYFromMouse();
        animator.setLookOverride({ x: mouse.x, y: mouse.y });
        return true;
      }
      if (state.name === 'wallApproach'
          && state.pendingWallAction === 'wallClimb'
          && state.contactSide === side) {
        state.climbTargetYOverride = climbTargetYFromMouse();
        animator.setLookOverride({ x: mouse.x, y: mouse.y });
        return false;
      }

      if (state.edgeTease.score >= EDGE_TEASE_TRIGGER
          && !isMouseDriven() && !['wallApproach', 'wallInspect', 'wallRub', 'wallScratch', 'dockInspect', 'dockPaw', 'dockRest'].includes(state.name)) {
        return startMouseEdgeClimb(side);
      }
      return false;
    }

    function maybeEnterWallInteraction() {
      if (state.wallCooldown > 0 || isMouseDriven() || isEnvironmentDriven()) return false;
      if (distanceToNearestWall() > WALL_REACH) return false;

      state.contactSide = nearestWallSide();
      scheduleWallCooldown();
      const scratchWeight = state.scratchCooldown <= 0
        ? 0.18 * (0.45 + personality.playfulness)
        : 0;
      const climbWeight = state.climbCooldown <= 0 && state.needs.energy > 0.45
        ? 0.20 * (0.3 + personality.playfulness)
        : 0;
      const choice = pickWeighted(random, [
        ['wallInspect', 0.35 * (0.5 + personality.curiosity)],
        ['wallRub', 0.20],
        ['wallScratch', scratchWeight],
        ['wallClimb', climbWeight],
        ['turnAway', 0.27]
      ]);
      if (choice === 'wallScratch') {
        state.scratchCooldown = 120 + random() * 180;
      }
      if (choice === 'turnAway') {
        const range = Math.max(0.6, state.maxX - state.minX);
        state.targetX = state.contactSide === 'left'
          ? Math.min(state.maxX, state.minX + range * (0.35 + random() * 0.25))
          : Math.max(state.minX, state.maxX - range * (0.35 + random() * 0.25));
        enter('wander');
      } else {
        state.pendingWallAction = choice;
        enter('wallApproach');
      }
      return true;
    }

    // A cat with the urge to scratch doesn't wait to wander past the wall —
    // it crosses the room on purpose. Picked occasionally from idle.
    function startScratchingPostTrip() {
      state.contactSide = nearestWallSide();
      state.pendingWallAction = 'wallScratch';
      state.scratchCooldown = 120 + random() * 180;
      scheduleWallCooldown();
      enter('wallApproach');
    }

    function maybeEnterDockInteraction() {
      const env = state.environment;
      if (!env.dockVisible || env.dockSide !== 'bottom') return false;
      if (state.dockCooldown > 0 || isMouseDriven() || isEnvironmentDriven()) return false;
      if (!['idle', 'sit', 'loaf'].includes(state.name)) return false;

      scheduleDockCooldown();
      enter(pickWeighted(random, [
        ['dockInspect', 0.42 * (0.5 + personality.curiosity)],
        ['dockPaw', 0.24 * (0.4 + personality.playfulness)],
        ['dockRest', 0.18 * (1.4 - personality.activity)],
        ['idle', 0.16]
      ]));
      return true;
    }

    function canMouseLunge(dist) {
      return mouseIsFresh()
        && dist >= LUNGE_MIN_RANGE
        && dist <= LUNGE_MAX_RANGE
        && state.mouse.y > 0.18
        && state.mouse.y < LUNGE_MAX_HEIGHT
        && state.lungeCooldown <= 0;
    }

    function recordMouseStrike(kind) {
      if (state.lastMouseStrike === kind) {
        state.mouseStrikeStreak += 1;
      } else {
        state.lastMouseStrike = kind;
        state.mouseStrikeStreak = 1;
      }
    }

    function variedWeight(kind, weight) {
      if (state.lastMouseStrike !== kind) return weight;
      return weight * Math.max(0.30, 1 - state.mouseStrikeStreak * 0.28);
    }

    function mouseLungeStyle(dist) {
      const mouse = state.mouse || { y: 0.5, speed: 0, vx: 0, vy: 0 };
      if (mouse.y > 1.00) return 'highGrab';
      if (mouse.speed > 1.55 && Math.abs(mouse.vx || 0) > Math.abs(mouse.vy || 0) * 0.65) {
        return 'sideSwipe';
      }
      if (mouse.y < 0.55 && dist < 0.95) return 'lowPounce';
      return random() < 0.34 ? 'hookGrab' : 'flyingGrab';
    }

    function chooseMouseStrike(dist) {
      if (!state.mouse) return 'swipe';
      const mouse = state.mouse;
      const close = dist < SWIPE_RANGE;
      const canLunge = canMouseLunge(dist);
      const fast = mouse.speed > 1.35;
      const high = mouse.y > 0.88;
      const options = [];

      if (close) {
        options.push(['probe', variedWeight('probe', 0.14 + personality.curiosity * 0.16)]);
        options.push(['swipe', variedWeight('swipe', 0.42 + personality.playfulness * 0.22)]);
        options.push(['hookSwipe', variedWeight('hookSwipe', 0.18 + (fast ? 0.12 : 0))]);
        if (state.mouseInterest > 1.15 && mouse.y > 0.22) {
          options.push(['pounce', variedWeight('pounce', 0.14 + personality.playfulness * 0.16)]);
        }
      } else if (dist < PROBE_RANGE && mouse.y < SWIPE_HEIGHT) {
        options.push(['probe', variedWeight('probe', 0.42 + personality.curiosity * 0.20)]);
        options.push(['hookSwipe', variedWeight('hookSwipe', 0.16)]);
        options.push(['feint', variedWeight('feint', 0.14 + personality.curiosity * 0.12)]);
      }

      if (dist < FEINT_RANGE && state.mouseInterest > 0.8) {
        options.push(['feint', variedWeight('feint', 0.16 + personality.curiosity * 0.18)]);
      }
      if (dist < SWIPE_RANGE * 1.55 && mouse.y < 1.05) {
        options.push(['pounce', variedWeight('pounce', 0.20 + personality.playfulness * 0.18)]);
      }
      if (canLunge) {
        options.push(['lunge', variedWeight('lunge',
          0.26 + personality.playfulness * 0.34 + (high ? 0.22 : 0) + (fast ? 0.10 : 0)
        )]);
      }

      return pickWeighted(random, options.length > 0 ? options : [['swipe', 1]]);
    }

    function performMouseStrike(strike, dist) {
      recordMouseStrike(strike);
      if (strike === 'lunge' && canMouseLunge(dist)) {
        startLunge(mouseLungeStyle(dist));
        return true;
      }
      if (strike === 'pounce') {
        state.pendingPounceStyle = state.mouse && state.mouse.speed > 1.2 ? 'sidePounce' : 'groundPounce';
        enter('pounce');
        state.novelty = Math.max(0.10, state.novelty - 0.18);
        state.swipeCooldown = 1.0 + random() * 2.2 * (1.6 - personality.playfulness);
        return true;
      }
      if (strike === 'probe') {
        enter('mouseProbe');
        state.novelty = Math.max(0.14, state.novelty - 0.09);
        state.swipeCooldown = 0.55 + random() * 1.0;
        return true;
      }
      if (strike === 'feint') {
        enter('mouseFeint');
        state.novelty = Math.max(0.14, state.novelty - 0.07);
        state.swipeCooldown = 0.45 + random() * 0.8;
        return true;
      }

      enter('swipe');
      animator.triggerSwipe(false, strike === 'hookSwipe' ? 'hook' : 'bat');
      armMouseCatch(strike === 'hookSwipe' ? 1.08 : 1);
      state.novelty = Math.max(0.10, state.novelty - 0.2);
      state.swipeCooldown = 1.2 + random() * 3 * (1.6 - personality.playfulness);
      return true;
    }

    // Commit to a flying grab: capture the cursor position at launch (cats
    // can't steer mid-air), fly the root along a ballistic arc shaped so the
    // measured front-paw anchor — not the body — arrives on the prey.
    function startLunge(style = 'flyingGrab') {
      const mouse = state.mouse;
      const targetPawX = safeXOutsideGnomeTerritories(
        THREE.MathUtils.clamp(mouse.x, state.minX - 0.3, state.maxX + 0.3),
        mouse.x >= state.worldX ? 1 : -1
      );
      const env = state.environment;
      const maxY = Math.max(0.6, env.screenHeightWorld * (1 - env.effectiveGroundFraction) - CLING_TOP_MARGIN);
      const targetPawY = THREE.MathUtils.clamp(mouse.y, 0.25, maxY);
      const dist = Math.abs(targetPawX - state.worldX);
      const arcMultiplier = style === 'highGrab' ? 1.32 : style === 'lowPounce' ? 0.62 : style === 'sideSwipe' ? 0.82 : 1;
      const durationBias = style === 'highGrab' ? 0.04 : style === 'sideSwipe' ? -0.02 : 0;
      faceMouse();
      state.lunge = {
        t: 0,
        style,
        duration: THREE.MathUtils.clamp(0.26 + dist * 0.22 + durationBias, 0.30, 0.62),
        startX: state.worldX,
        startY: state.worldY,
        targetPawX,
        targetPawY,
        arc: (0.15 + dist * 0.10 + Math.max(0, targetPawY - 0.8) * 0.06) * arcMultiplier
      };
      state.lungeCooldown = 5 + random() * 7;
      state.mouseInterest = Math.max(1.2, state.mouseInterest);
      animator.setPose('lungeAir');
      animator.setLocomotion(0, 'walk');
      animator.triggerLunge(state.lunge.duration, style);
      animator.setAgility(1.9);
      state.name = 'lunge';
      state.timer = state.lunge.duration + 0.3;
    }

    function updateLunge(dt) {
      const lunge = state.lunge;
      if (!lunge) {
        enter('alert');
        return;
      }
      lunge.t = Math.min(1, lunge.t + dt / lunge.duration);
      const tau = lunge.t;
      const anchor = animator.getPawAnchor();
      const rootTargetX = safeXOutsideGnomeTerritories(
        THREE.MathUtils.clamp(lunge.targetPawX - anchor.x, state.minX, state.maxX),
        lunge.targetPawX >= state.worldX ? 1 : -1
      );
      const rootTargetY = Math.max(0, lunge.targetPawY - anchor.yAbs);
      state.worldX = lunge.startX + (rootTargetX - lunge.startX) * tau;
      state.worldY = Math.max(0,
        lunge.startY + (rootTargetY - lunge.startY) * tau + lunge.arc * Math.sin(tau * Math.PI));
      animator.setLookOverride({ x: lunge.targetPawX, y: lunge.targetPawY });

      // The grab window: paws converging at the end of the flight.
      if (tau >= 0.74 && mouseIsFresh()) {
        const pawX = state.worldX + anchor.x;
        const pawY = state.worldY + anchor.yAbs;
        if (Math.abs(pawX - state.mouse.x) < 0.36
            && Math.abs(pawY - state.mouse.y) < 0.36) {
          state.lunge = null;
          enter('mouseCling');
          return;
        }
      }
      if (tau >= 1) {
        rememberPointOfInterest('missedMouse', lunge.targetPawX, lunge.targetPawY, 0.55);
        state.lunge = null;
        animator.cancelLunge();
        state.catchCooldown = Math.max(state.catchCooldown, 2.5);
        state.swipeCooldown = Math.max(state.swipeCooldown, 1.2);
        enter('lungeRecover');
      }
    }

    function canCleanCatchMouse() {
      if (!mouseIsFresh() || state.catchCooldown > 0 || isBellyExposed()) return false;
      const mouse = state.mouse;
      return mouseDistance() < CATCH_RANGE
        && mouse.y >= CATCH_MIN_HEIGHT
        && mouse.y <= CATCH_MAX_HEIGHT;
    }

    function armMouseCatch(catchBias = 1) {
      state.catchArmed = false;
      state.catchWindow = 0;
      state.catchDelay = 0;
      if (!canCleanCatchMouse()) return;

      // "Just right" should feel like a real catch, not every swat. Curious,
      // playful cats are better at timing it, but the geometry still matters.
      const odds = (0.22 + personality.playfulness * 0.30 + personality.curiosity * 0.10)
        * catchBias;
      if (random() <= odds) {
        state.catchArmed = true;
        state.catchWindow = CATCH_WINDOW_SECONDS;
        state.catchDelay = 0.10;
      }
    }

    function updatePendingMouseCatch(dt) {
      if (!state.catchArmed) return false;
      if (state.name !== 'swipe' && state.name !== 'pounce' && state.name !== 'mouseProbe') {
        state.catchArmed = false;
        state.catchWindow = 0;
        return false;
      }

      state.catchWindow = Math.max(0, state.catchWindow - dt);
      state.catchDelay = Math.max(0, state.catchDelay - dt);
      if (state.catchDelay > 0) return false;
      if (canCleanCatchMouse()) {
        enter('mouseCling');
        return true;
      }
      if (state.catchWindow <= 0) {
        state.catchArmed = false;
      }
      return false;
    }

    function releaseMouseCling() {
      state.worldY = Math.max(0, state.worldY);
      state.catchCooldown = 18 + random() * 28;
      state.swipeCooldown = 2.0 + random() * 2.5;
      state.clingLostTimer = 0;
      state.catchArmed = false;
      state.catchWindow = 0;
      state.catchDelay = 0;
      enter('alert');
    }

    function updateMouseCling(dt) {
      animator.setPose('mouseCling');
      animator.setLocomotion(0, 'walk');

      if (state.mouse) {
        const mouse = state.mouse;
        const env = state.environment;
        state.clingLostTimer = 0;
        const prevX = state.worldX;
        const prevY = state.worldY;
        // Pin the measured front-paw tips on the cursor — the body hangs
        // wherever it has to for the paws to be exactly on the "prey".
        const anchor = animator.getPawAnchor();
        state.worldX = damp(
          state.worldX,
          safeXOutsideGnomeTerritories(
            THREE.MathUtils.clamp(mouse.x - anchor.x, state.minX, state.maxX),
            mouse.x >= state.worldX ? 1 : -1
          ),
          14,
          dt
        );
        // The cat may be carried anywhere on screen; only the very top edge
        // is shaved so the ears stay visible while it dangles.
        const maxY = Math.max(
          0.6,
          env.screenHeightWorld * (1 - env.effectiveGroundFraction) - CLING_TOP_MARGIN
        );
        const targetY = THREE.MathUtils.clamp(mouse.y - anchor.yAbs, 0, maxY);
        state.worldY = damp(state.worldY, targetY, 14, dt);
        // Hand the animator the carry velocity so the body swings like a
        // pendulum under the grip point and settles when the drag stops.
        if (dt > 0 && animator.setClingMotion) {
          animator.setClingMotion(
            (state.worldX - prevX) / dt,
            (state.worldY - prevY) / dt
          );
        }
        faceMouse();
        animator.setLookOverride({ x: mouse.x, y: mouse.y + 0.08 });
        if (mouse.y <= CLING_RELEASE_HEIGHT && state.worldY < 0.18) {
          state.worldY = 0;
          releaseMouseCling();
        }
      } else {
        // If the pointer leaves the screen, don't keep an invisible leash
        // forever. Drop softly back down after a grace beat.
        state.clingLostTimer += dt;
        state.worldY = damp(state.worldY, 0, 3.5, dt);
        if (animator.setClingMotion) animator.setClingMotion(0, 0);
        if (state.clingLostTimer > 1.3 || state.worldY < 0.05) {
          state.worldY = 0;
          releaseMouseCling();
        }
      }
    }

    // True while the cursor is resting on the cat's body (the strokeable
    // zone along the back, tracking the current posture height).
    function cursorOnBody() {
      if (!mouseIsFresh()) return false;
      const mouse = state.mouse;
      if (isBellyExposed()) {
        const rootHeight = animator.state && animator.state.ch
          ? animator.state.ch.rootHeight || 0
          : 0;
        const bellyY = state.worldY + 0.34
          + THREE.MathUtils.clamp(rootHeight, -0.30, 0.08) * 0.18;
        return Math.abs(mouse.x - state.worldX) < 0.62
          && mouse.y > bellyY - 0.28 && mouse.y < bellyY + 0.32;
      }
      const backY = 0.46 + animator.state.ch.rootHeight + 0.18 + state.worldY;
      return Math.abs(mouse.x - state.worldX) < 0.46
        && mouse.y > backY - 0.24 && mouse.y < backY + 0.28;
    }

    // Petting: back-and-forth strokes along the body build recognition;
    // a parked cursor or a fast jab does not. Returns true while the
    // petting interaction owns the cat (hunting reflexes stay out).
    function updatePetting(dt) {
      const mouse = state.mouse;
      const stroking = cursorOnBody()
        && mouse.speed > PET_SPEED_MIN && mouse.speed < PET_SPEED_MAX;

      if (stroking) {
        // Stroke direction from actual cursor motion, not position.
        const dir = state.petLastX === null
          ? 0
          : Math.sign(mouse.x - state.petLastX);
        // Direction reversals are the signature of petting vs a pass-by.
        if (dir !== 0 && state.petDir !== 0 && dir !== state.petDir) {
          state.petScore += 0.32;
        }
        if (dir !== 0) state.petDir = dir;
        state.petScore = Math.min(2.5, state.petScore + dt * 0.85);
        // The coat reacts to touch immediately — fur parts under the hand
        // from the first stroke. Recognition (the purring lean-in) follows.
        animator.setPetContact(
          mouse.x, mouse.y,
          state.petDir * Math.min(1, mouse.speed * 0.8),
          Math.min(1, 0.45 + mouse.speed * 0.35)
        );
      } else {
        state.petScore = Math.max(0, state.petScore - dt * 0.6);
      }
      state.petLastX = mouse.x;

      const ownsPetting = state.name === 'petted' || state.name === 'bellyPet';
      if (ownsPetting) {
        if (stroking || cursorOnBody()) {
          state.petIdle = 0;
          animator.setLookOverride(null); // eyes soft, not tracking
          // Petting-induced overstimulation builds while the hand keeps
          // going. Less playful / more aloof cats reach their limit sooner.
          const bellyEase = state.name === 'bellyPet' ? 0.34 : 1.0;
          state.petOverstim += dt * (0.55 + (1 - personality.playfulness) * 0.5) * bellyEase;
          state.memory.trust = THREE.MathUtils.clamp(
            state.memory.trust + dt * (state.name === 'bellyPet' ? 0.004 : 0.006),
            0,
            1
          );
        } else {
          state.petIdle += dt;
          state.petOverstim = Math.max(0, state.petOverstim - dt * 0.5);
        }
        // "That's enough." The classic over-petting limit: a tail-lash, then
        // the cat breaks off and walks a step away (and won't be re-petted
        // for a moment).
        const overstimLimit = state.name === 'bellyPet'
          ? 2.40 + state.memory.trust * 0.90
          : 0.78 + state.memory.trust * 0.48;
        if (state.petOverstim > overstimLimit) {
          state.petOverstim = 0;
          state.petScore = 0;
          state.memory.trust = Math.max(0, state.memory.trust - (state.name === 'bellyPet' ? 0.015 : 0.06));
          rememberLookBack({ x: mouse.x, y: mouse.y });
          if (state.name === 'bellyPet') {
            enter('playOnBack');
            return true;
          }
          state.reflexGuard = true;
          state.reflexGuardTimer = 6;
          state.swipeCooldown = Math.max(state.swipeCooldown, 2.5);
          if (animator.triggerTailLash) animator.triggerTailLash(1.0, 1);
          animator.setLookOverride(null);
          state.targetX = THREE.MathUtils.clamp(
            state.worldX + (random() < 0.5 ? -1 : 1) * (0.6 + random() * 0.6),
            state.minX, state.maxX);
          enter('wander');
          return true;
        }
        if (state.petIdle > 1.1 || !mouseIsFresh()) {
          // The hand left: stay mellow, and don't snap into hunt reflexes
          // until the cursor crosses back into the visual field.
          state.petScore = 0;
          state.reflexGuard = true;
          state.reflexGuardTimer = 6;
          if (state.name === 'bellyPet') {
            enter(random() < 0.46 ? chooseGroomingState('afterBellyPet') : 'bellyUp');
          } else {
            enter(random() < 0.36 ? chooseGroomingState('afterPet') : 'idle');
          }
        }
        return true;
      }

      if (state.petScore > 1.1 && !isMouseDriven() && state.name !== 'lunge') {
        enter(isBellyExposed() ? 'bellyPet' : 'petted');
        return true;
      }
      return false;
    }

    function updateReflexGuard(dt) {
      if (!state.reflexGuard) return;
      state.reflexGuardTimer -= dt;
      if (state.reflexGuardTimer <= 0) {
        state.reflexGuard = false;
        return;
      }
      // The guard lifts the moment the cursor re-enters the cat's visual
      // field — out in front of the face, at a watchable distance.
      if (mouseIsFresh()) {
        const dx = state.mouse.x - state.worldX;
        if (dx * animator.state.heading > 0.2 && Math.abs(dx) > 0.5
            && state.mouse.y < 1.3) {
          state.reflexGuard = false;
        }
      }
    }

    // Instinct layer: runs before the state machine and can hijack it.
    function reactToMouse(dt) {
      state.swipeCooldown = Math.max(0, state.swipeCooldown - dt);
      state.glanceTimer = Math.max(0, state.glanceTimer - dt);
      if (!personality.mouseReactions || !mouseIsFresh()) {
        if (state.name === 'petted' || state.name === 'bellyPet') {
          state.petIdle += dt;
          if (state.petIdle > 1.1) {
            state.petScore = 0;
            state.reflexGuard = true;
            state.reflexGuardTimer = 6;
            if (state.name === 'bellyPet') {
              enter(random() < 0.46 ? chooseGroomingState('afterBellyPet') : 'bellyUp');
            } else {
              enter(random() < 0.36 ? chooseGroomingState('afterPet') : 'idle');
            }
          }
          return;
        }
        // Object permanence: if the cursor vanished while the cat was locked
        // on, don't snap back to boredom — hold a beat staring at the last
        // spot ("where did it go?") before giving up.
        if (personality.mouseReactions && !mouseIsFresh() && state.lastMouse
            && state.mouseInterest > 0.7 && !isBugDriven() && !isEnvironmentDriven()
            && (!isMouseDriven() || state.name === 'alert')
            && state.name !== 'lostMouse' && state.name !== 'petted'
            && state.name !== 'bellyPet' && !isResting()) {
          rememberLastMouse(0.35 + state.mouseInterest * 0.18);
          enter('lostMouse');
          return;
        }
        if (!isMouseDriven() && state.name !== 'lostMouse') animator.setLookOverride(null);
        state.mouseInterest = Math.max(0, state.mouseInterest - dt * 0.5);
        return;
      }

      // Touch beats prey-drive: a hand on the body is petting, not a target.
      if (updatePetting(dt)) return;
      updateReflexGuard(dt);

      // A cursor resting on the cat's own back is not prey — it can't even
      // see it. No swatting, no lunging, no interest build; at most it
      // settles into being petted (handled above).
      if (cursorOnBody()) {
        clearPendingMouseCatch();
        state.mouseInterest = Math.max(0, state.mouseInterest - dt * 0.6);
        if (!isMouseDriven()) animator.setLookOverride(null);
        return;
      }

      if (mouseInsideGnomeTerritory()) {
        clearPendingMouseCatch();
        state.mouseInterest = Math.max(0, state.mouseInterest - dt * 0.55);
        if (!isMouseDriven() && mouseDistance() < WATCH_RANGE) {
          animator.setLookOverride({ x: state.mouse.x, y: state.mouse.y });
        }
        return;
      }

      if (isBellyExposed()) {
        clearPendingMouseCatch();
        state.mouseInterest = Math.max(0, state.mouseInterest - dt * 0.7);
        if (mouseDistance() < WATCH_RANGE) {
          animator.setLookOverride({ x: state.mouse.x, y: state.mouse.y });
        } else {
          animator.setLookOverride(null);
        }
        return;
      }

      const mouse = state.mouse;
      const dist = mouseDistance();
      const withinSwipe = dist < SWIPE_RANGE && mouse.y < SWIPE_HEIGHT;
      const withinWatch = dist < WATCH_RANGE && mouse.y < 1.6;
      // Remember where the cursor is whenever it's in view, so the cat can
      // look back to the last spot once it disappears.
      if (withinWatch) state.lastMouse = { x: mouse.x, y: mouse.y };

      // Motion is what cats key on: a fast-moving cursor builds interest
      // quickly, a parked one is furniture. Novelty gates the build — once
      // the cat has caught the same jiggle a few times it stops caring.
      if (withinWatch && mouse.speed > 0.4) {
        state.mouseInterest = Math.min(
          3, state.mouseInterest + dt * mouse.speed
            * (0.5 + personality.playfulness) * (0.25 + state.novelty * 0.75)
        );
      } else {
        state.mouseInterest = Math.max(0, state.mouseInterest - dt * 0.4);
      }

      // Poking a sleeping cat wakes it — but a slow hand settling onto the
      // body is the start of a pet, not an attack, so only fast intrusions
      // startle.
      if (isResting()) {
        if (updateEdgeTease(dt)) return;
        if (withinSwipe && mouse.speed > 1.3 && !cursorOnBody()) enter('startle');
        return;
      }

      if (state.reflexGuard) return;

      if (updateEdgeTease(dt)) return;

      // On the wall, all four paws are busy: it watches the cursor but
      // can't hunt it. The tap to come down is handled by pokeAt.
      if (isClimbing()) {
        animator.setLookOverride({ x: mouse.x, y: mouse.y });
        return;
      }

      if (withinWatch || isMouseDriven()) {
        animator.setLookOverride({ x: mouse.x, y: mouse.y });
      } else if (state.glanceTimer <= 0 && withinWatch === false && random() < personality.curiosity * 0.3) {
        // Occasional idle glance toward a distant cursor.
        animator.setLookOverride({ x: mouse.x, y: mouse.y });
        state.glanceTimer = 2 + random() * 3;
      } else if (!withinWatch) {
        animator.setLookOverride(null);
      }

      // Close cursor play: choose among a real swat, a paw probe, a feint,
      // a short ground pounce, or (rarely) a flying grab if the geometry is
      // just right. Recent repeats are downweighted so it feels improvisational.
      if (withinSwipe && !MOUSE_STRIKE_STATES.includes(state.name)
          && state.swipeCooldown <= 0) {
        // Bored of the same prey: once novelty has worn off the cat gives a
        // dismissive look and strolls away instead of swatting yet again.
        if (state.novelty < 0.26 && random() < 0.7) {
          state.mouseInterest = 0;
          state.swipeCooldown = 3 + random() * 3;
          rememberLookBack({ x: mouse.x, y: mouse.y });
          animator.setLookOverride(null);
          state.targetX = THREE.MathUtils.clamp(
            state.worldX + (random() < 0.5 ? -1 : 1) * (0.8 + random() * 0.7),
            state.minX, state.maxX);
          enter('wander');
          return;
        }
        faceMouse();
        if (!animator.isTurning()) {
          performMouseStrike(chooseMouseStrike(dist), dist);
        }
        return;
      }

      // Mid-range hunting: a worked-up cat may coil, fake out, or commit to
      // a styled lunge. Probability is per-second (scaled by dt) so
      // framerate doesn't change how often it happens.
      if (dist >= LUNGE_MIN_RANGE && dist <= LUNGE_MAX_RANGE
          && mouse.y > 0.18 && mouse.y < LUNGE_MAX_HEIGHT
          && !isMouseDriven() && state.lungeCooldown <= 0
          && state.mouseInterest > 0.9 && !animator.isTurning()) {
        faceMouse();
        if (random() < (0.28 + personality.playfulness * 0.62) * dt) {
          const strike = chooseMouseStrike(dist);
          if (strike === 'feint') {
            performMouseStrike('feint', dist);
          } else if (strike === 'pounce' && dist < FEINT_RANGE) {
            performMouseStrike('pounce', dist);
          } else {
            recordMouseStrike('lunge');
            startLunge(mouseLungeStyle(dist));
          }
          state.novelty = Math.max(0.12, state.novelty - 0.2);
          return;
        }
      }

      // Sustained teasing at mid range triggers the hunt — a hungry cat commits
      // to the stalk more readily.
      if (state.mouseInterest > 1.6 && !isMouseDriven()
          && dist > SWIPE_RANGE && random() < personality.playfulness * 0.04 * (1 + state.needs.hunger * 0.8)) {
        enter('stalkMouse');
      }
    }

    function classifyLookTarget(target) {
      if (mouseIsFresh() && Math.hypot(target.x - state.mouse.x, target.y - state.mouse.y) < 0.12) {
        return {
          kind: 'cursor',
          key: 'cursor',
          speed: state.mouse.speed || 0,
          score: 1.40,
          reason: isMouseDriven() ? 'hunt' : 'watch'
        };
      }
      const bug = currentBugTarget();
      if (bug) {
        const aim = bugAimPoint(bug);
        if (Math.hypot(target.x - aim.x, target.y - aim.y) < 0.18) {
          return {
            kind: 'bug',
            key: `bug:${bug.id}`,
            speed: Math.hypot(bug.vx || 0, bug.vy || 0),
            score: 1.48,
            reason: 'hunt'
          };
        }
      }
      if (state.plantFocus && Math.abs(target.x - state.plantFocus.x) < 0.18) {
        return {
          kind: 'plant',
          key: `plant:${state.plantFocus.id}`,
          score: 1.18,
          reason: 'inspect'
        };
      }
      if (state.gnomeFocus && Math.abs(target.x - state.gnomeFocus.centerX) < 0.20) {
        return {
          kind: 'gnome',
          key: `gnome:${state.gnomeFocus.id || state.gnomeFocus.centerX}`,
          score: 1.16,
          reason: 'inspect'
        };
      }
      if (state.investigation && Math.abs(target.x - state.investigation.x) < 0.16) {
        return {
          kind: 'memory',
          key: `memory:${state.investigation.kind}`,
          score: 1.12,
          reason: 'inspect'
        };
      }
      return {
        kind: 'state',
        key: `state:${state.name}`,
        score: 1.08,
        reason: state.intent.reason
      };
    }

    function attentionKey(candidate) {
      return candidate && (candidate.key || `${candidate.kind}:${candidate.id || 'main'}`);
    }

    function pushAttentionCandidate(candidates, candidate) {
      if (!candidate || !Number.isFinite(candidate.x) || !Number.isFinite(candidate.y)) return;
      const key = attentionKey(candidate);
      const habit = state.attentionHabituation[key] || 0;
      const same = state.attentionTarget && state.attentionTarget.key === key;
      const committed = same ? state.attentionCommitment * 0.30 : 0;
      const score = Math.max(0, (candidate.score || 0) * (1 - Math.min(0.72, habit)) + committed);
      candidates.push({
        ...candidate,
        key,
        score,
        habit
      });
    }

    function attentionCandidates() {
      const candidates = [];
      if (state.name === 'petted' || state.name === 'bellyPet') return candidates;

      if (state.frameLookTarget) pushAttentionCandidate(candidates, state.frameLookTarget);

      if (state.intent.lookBack && state.intent.lookBack.timer > 0) {
        pushAttentionCandidate(candidates, {
          kind: 'lookBack',
          key: 'lookBack',
          x: state.intent.lookBack.x,
          y: state.intent.lookBack.y,
          score: 0.86,
          reason: 'lookBack'
        });
      }

      if (mouseIsFresh() && !cursorOnBody()) {
        const dist = Math.abs(state.mouse.x - state.worldX);
        if (dist < WATCH_RANGE * 1.35 && state.mouse.y < 1.75 && !mouseInsideGnomeTerritory()) {
          pushAttentionCandidate(candidates, {
            kind: 'cursor',
            key: 'cursor',
            x: state.mouse.x,
            y: state.mouse.y,
            speed: state.mouse.speed || 0,
            score: 0.30 + Math.min(1.25, state.mouseInterest * 0.38)
              + Math.min(0.65, (state.mouse.speed || 0) * 0.20)
              + (isMouseDriven() ? 0.75 : 0)
              + state.novelty * 0.18
              - dist * 0.05,
            reason: isMouseDriven() ? 'hunt' : 'watch'
          });
        }
      }

      const bug = currentBugTarget();
      if (bug) {
        const aim = bug.id === state.bugFocus.id && state.bugFocus.lock > 0
          ? { x: state.bugFocus.smoothX, y: state.bugFocus.smoothY }
          : bugAimPoint(bug);
        pushAttentionCandidate(candidates, {
          kind: 'bug',
          key: `bug:${bug.id}`,
          x: aim.x,
          y: aim.y,
          speed: Math.hypot(bug.vx || 0, bug.vy || 0),
          score: 0.90 + state.bugFocus.lock * 0.45 + state.needs.hunger * 0.18
            + (bug.plantFocused ? 0.12 : 0)
            + (isBugDriven() ? 0.80 : 0)
            - Math.abs(bug.x - state.worldX) * 0.08,
          reason: 'hunt'
        });
      }

      const plant = state.plantFocus || bestPlantCuriosityTarget();
      if (plant) {
        pushAttentionCandidate(candidates, {
          kind: 'plant',
          key: `plant:${plant.id}`,
          x: plant.x,
          y: THREE.MathUtils.clamp(plant.y + (plant.canopyHeight || 0) * 0.72, 0.20, 1.58),
          score: (PLANT_STATES.includes(state.name) ? 0.78 : 0.34)
            + (plant.resourceValue || 0) * 0.24
            + (plant.canopyHeight || 0) * 0.30
            + personality.curiosity * 0.12
            - Math.abs(plant.x - state.worldX) * 0.05,
          reason: 'inspect'
        });
      }

      const territory = state.gnomeFocus || nearestGnomeTerritory();
      if (territory) {
        pushAttentionCandidate(candidates, {
          kind: 'gnome',
          key: `gnome:${territory.id || territory.centerX}`,
          x: territory.centerX,
          y: THREE.MathUtils.clamp(territory.centerY, 0.24, 1.35),
          score: (GNOME_STATES.includes(state.name) ? 0.82 : 0.32)
            + personality.curiosity * 0.16,
          reason: 'inspect'
        });
      }

      if (isWallContact() || distanceToNearestWall() < WALL_REACH * 1.3) {
        const side = isWallContact() ? state.contactSide : nearestWallSide();
        pushAttentionCandidate(candidates, {
          kind: 'wall',
          key: `wall:${side}`,
          x: wallEdgeX(side),
          y: THREE.MathUtils.clamp(state.worldY + 0.55, 0.24, 1.45),
          score: (isWallContact() ? 0.62 : 0.24) + personality.curiosity * 0.08,
          reason: 'inspect'
        });
      }

      if (state.environment.dockVisible && state.environment.dockSide === 'bottom') {
        pushAttentionCandidate(candidates, {
          kind: 'dock',
          key: 'dock',
          x: state.worldX,
          y: 0.13,
          score: (state.name === 'dockInspect' || state.name === 'dockPaw' || state.name === 'dockRest' ? 0.65 : 0.20)
            + personality.curiosity * 0.08,
          reason: 'inspect'
        });
      }

      if (state.investigation) {
        pushAttentionCandidate(candidates, {
          kind: 'memory',
          key: `memory:${state.investigation.kind}`,
          x: state.investigation.x,
          y: state.investigation.y,
          score: 0.78 + (state.investigation.settled ? 0.20 : 0),
          reason: 'inspect'
        });
      } else if (state.memory.poiWeight > 0.22 && state.memory.poiKind !== 'none') {
        pushAttentionCandidate(candidates, {
          kind: 'memory',
          key: `memory:${state.memory.poiKind}`,
          x: state.memory.poiX,
          y: THREE.MathUtils.clamp(state.memory.poiY, 0.16, 1.55),
          score: state.memory.poiWeight * (0.34 + personality.curiosity * 0.22),
          reason: 'inspect'
        });
      }

      if (state.memory.favoriteWeight > 0.45 && state.needs.energy < 0.52) {
        pushAttentionCandidate(candidates, {
          kind: 'favorite',
          key: 'favorite',
          x: favoriteSpotX(),
          y: 0.36,
          score: state.memory.favoriteWeight * (0.18 + (1 - state.needs.energy) * 0.20),
          reason: 'rest'
        });
      }

      return candidates;
    }

    function updateAttentionHabituation(target, dt) {
      for (const key of Object.keys(state.attentionHabituation)) {
        state.attentionHabituation[key] = Math.max(0, state.attentionHabituation[key] - dt * 0.035);
        if (state.attentionHabituation[key] <= 0.001) delete state.attentionHabituation[key];
      }
      if (!target) {
        state.attentionLast = null;
        return;
      }

      const last = state.attentionLast;
      const same = last && last.key === target.key;
      const move = same ? Math.hypot(target.x - last.x, target.y - last.y) : 1;
      const speed = target.speed || 0;
      let habit = state.attentionHabituation[target.key] || 0;
      if (same && move < 0.055 && speed < 0.20 && target.kind !== 'state' && target.kind !== 'bug') {
        habit += dt * 0.18;
      } else {
        habit -= dt * (0.18 + Math.min(0.45, move * 2.2 + speed * 0.16));
      }
      state.attentionHabituation[target.key] = THREE.MathUtils.clamp(habit, 0, 0.85);
      state.attentionLast = { key: target.key, x: target.x, y: target.y };
    }

    function chooseAttentionTarget(dt) {
      const candidates = attentionCandidates();
      if (candidates.length === 0) {
        state.attentionTarget = null;
        state.attentionCommitment = Math.max(0, state.attentionCommitment - dt * 0.9);
        state.attentionSurprise = damp(state.attentionSurprise, 0, 5, dt);
        updateAttentionHabituation(null, dt);
        return null;
      }

      candidates.sort((a, b) => b.score - a.score);
      const best = candidates[0];
      const current = state.attentionTarget
        ? candidates.find((candidate) => candidate.key === state.attentionTarget.key)
        : null;
      const keepCurrent = current
        && best.key !== current.key
        && best.score < current.score + ATTENTION_SWITCH_MARGIN + state.attentionCommitment * 0.16;
      const chosen = keepCurrent ? current : best;
      const last = state.attentionLast;
      const same = last && last.key === chosen.key;
      const move = same ? Math.hypot(chosen.x - last.x, chosen.y - last.y) : 0.3;
      const novelty = chosen.kind === 'bug' ? 0.40 : chosen.kind === 'cursor' ? Math.min(0.75, (chosen.speed || 0) * 0.24) : 0;
      const surprise = THREE.MathUtils.clamp(
        (same ? move * 2.4 : 0.45) + novelty - (chosen.habit || 0) * 0.35,
        0,
        1
      );

      state.attentionTarget = {
        kind: chosen.kind,
        key: chosen.key,
        x: chosen.x,
        y: chosen.y,
        score: chosen.score,
        reason: chosen.reason || state.intent.reason,
        habit: chosen.habit || 0
      };
      state.attentionCommitment = THREE.MathUtils.clamp(
        same ? state.attentionCommitment + dt * 0.55 : state.attentionCommitment * 0.35 + 0.22,
        0,
        1
      );
      state.attentionSurprise = damp(state.attentionSurprise, surprise, 5, dt);
      updateAttentionHabituation(chosen, dt);
      return state.attentionTarget;
    }

    function emotionSignals() {
      const target = state.attentionTarget;
      const hunting = isMouseDriven() || isBugDriven() || state.name === 'lunge' || state.name === 'bugLunge';
      const inspecting = target && (target.reason === 'inspect' || target.kind === 'plant'
        || target.kind === 'memory' || target.kind === 'wall' || target.kind === 'dock');
      return {
        curiosity: THREE.MathUtils.clamp(
          (target ? target.score * 0.34 : 0)
            + (inspecting ? 0.30 : 0)
            + personality.curiosity * 0.22
            - (state.mood === 'sleepy' ? 0.18 : 0),
          0,
          1
        ),
        tension: THREE.MathUtils.clamp(
          (hunting ? 0.58 : 0)
            + state.attentionSurprise * 0.30
            + Math.min(0.32, state.petOverstim * 0.18)
            + (state.name === 'startle' ? 0.45 : 0),
          0,
          1
        ),
        confidence: THREE.MathUtils.clamp(
          state.memory.trust * 0.48
            + (isResting() ? 0.22 : 0)
            + (state.intent.reason === 'seekAttention' ? 0.10 : 0)
            - state.attentionSurprise * 0.18,
          0,
          1
        ),
        sleepiness: THREE.MathUtils.clamp(
          (1 - state.needs.energy) * 0.62
            + circadianSleepPressure() * 0.30
            + (state.mood === 'sleepy' ? 0.25 : 0)
            + (isResting() ? 0.10 : 0),
          0,
          1
        )
      };
    }

    function maybeAbortSoftIntent() {
      if (!['plantApproach', 'plantInspect', 'investigateSpot', 'returnToFavorite', 'seekAttention'].includes(state.name)) {
        return false;
      }
      if (state.name === 'seekAttention' && state.memory.trust > 0.65) return false;
      if (state.attentionSurprise < 0.82) return false;
      const target = state.attentionTarget;
      if (!target || (target.kind !== 'cursor' && target.kind !== 'bug')) return false;
      state.plantFocus = null;
      state.investigation = null;
      enter('alert');
      return true;
    }

    function commitFrame(dt) {
      const target = chooseAttentionTarget(dt);
      if (animator.setEmotionSignals) animator.setEmotionSignals(emotionSignals());
      setAnimatorLookOverride(target ? { x: target.x, y: target.y } : null);
      if (!maybeAbortSoftIntent()) {
        animator.update(dt, state.worldX, state.worldY);
      } else {
        setAnimatorLookOverride(state.attentionTarget ? { x: state.attentionTarget.x, y: state.attentionTarget.y } : null);
        animator.update(dt, state.worldX, state.worldY);
      }
      state.frameLookTarget = null;
    }

    function update(dt) {
      state.frameLookTarget = null;
      state.intent.since += dt;
      if (state.intent.lookBack) {
        state.intent.lookBack.timer -= dt;
        if (state.intent.lookBack.timer <= 0) state.intent.lookBack = null;
      }
      if (state.mouse) state.mouse.age += dt;
      state.wallCooldown = Math.max(0, state.wallCooldown - dt);
      state.dockCooldown = Math.max(0, state.dockCooldown - dt);
      state.scratchCooldown = Math.max(0, state.scratchCooldown - dt);
      state.catchCooldown = Math.max(0, state.catchCooldown - dt);
      state.lungeCooldown = Math.max(0, state.lungeCooldown - dt);
      state.bugCooldown = Math.max(0, state.bugCooldown - dt);
      state.climbCooldown = Math.max(0, state.climbCooldown - dt);
      state.gnomeCooldown = Math.max(0, state.gnomeCooldown - dt);
      state.gnomeRideCooldown = Math.max(0, state.gnomeRideCooldown - dt);
      state.plantCooldown = Math.max(0, state.plantCooldown - dt);
      // Novelty (the cure for boredom) recovers fast once the cursor goes
      // quiet/leaves, but only crawls back while it's still right there — so
      // teasing the same jiggle over and over wears the cat down.
      const noveltyRecover = mouseIsFresh() ? 0.006 : 0.12;
      state.novelty = Math.min(1, state.novelty + dt * noveltyRecover);
      // Overstimulation bleeds off whenever the cat isn't actively petted.
      if (state.name !== 'petted' && state.name !== 'bellyPet') {
        state.petOverstim = Math.max(0, state.petOverstim - dt * 0.4);
      }
      tickNeeds(dt);
      tickMemory(dt);

      if (state.name === 'mouseCling') {
        updateMouseCling(dt);
        commitFrame(dt);
        return;
      }
      if (state.name === 'lunge') {
        updateLunge(dt);
        commitFrame(dt);
        return;
      }
      if (state.name === 'bugLunge') {
        updateBugLunge(dt);
        commitFrame(dt);
        return;
      }

      if (!isClimbing()) {
        state.worldY = damp(state.worldY, 0, 7, dt);
      }
      if (!GNOME_STATES.includes(state.name) && !isWallContact()) {
        state.worldX = safeXOutsideGnomeTerritories(state.worldX);
      }
      reactToMouse(dt);
      if (maybeReactToBugs(dt)) {
        commitFrame(dt);
        return;
      }
      if (updatePendingMouseCatch(dt)) {
        commitFrame(dt);
        return;
      }
      maybeEnterDockInteraction();
      maybeEnterGnomeInteraction();
      state.timer -= dt;

      switch (state.name) {
        case 'wander': {
          const arrived = walkToward(dt, WALK_SPEED, 'walk');
          if (arrived || state.timer <= 0) {
            if (maybeEnterWallInteraction()) break;
            enter(pickWeighted(random, [
              ['idle', 0.45], ['sit', 0.30], ['lie', 0.15], ['wander', 0.10]
            ]));
          }
          break;
        }
        case 'returnToFavorite': {
          const arrived = walkToward(dt, WALK_SPEED * 0.82, 'walk');
          if (arrived || state.timer <= 0) {
            state.memory.favoriteWeight = Math.min(1, state.memory.favoriteWeight + 0.06);
            enter(pickWeighted(random, [
              ['loaf', 0.42], ['lie', 0.25], ['sit', 0.22], [chooseGroomingState('rest'), 0.11]
            ]));
          }
          break;
        }
        case 'investigateSpot': {
          const point = state.investigation;
          if (!point) {
            enter('idle');
            break;
          }
          const arrived = point.settled || walkToward(dt, WALK_SPEED * 0.8, 'walk');
          animator.setLookOverride({ x: point.x, y: point.y });
          if (arrived && !point.settled) {
            point.settled = true;
            animator.setPose(random() < 0.55 ? 'sit' : 'stand');
            animator.setLocomotion(0, 'walk');
            state.timer = 2.2 + random() * 2.4;
          }
          if (state.timer <= 0) {
            state.memory.poiWeight = Math.max(0, state.memory.poiWeight - 0.45);
            state.investigation = null;
            animator.setLookOverride(null);
            enter(pickWeighted(random, [['sit', 0.40], [chooseGroomingState('default'), 0.22], ['idle', 0.38]]));
          }
          break;
        }
        case 'plantApproach': {
          const plant = state.plantFocus;
          if (!plant) {
            enter('idle');
            break;
          }
          state.targetX = plantSniffSpot(plant);
          const look = {
            x: plant.x,
            y: THREE.MathUtils.clamp(plant.y + (plant.canopyHeight || 0) * 0.65, 0.22, 1.55)
          };
          animator.setLookOverride(look);
          if (holdForHesitation(dt, look)) break;
          const arrived = walkToward(dt, WALK_SPEED * 0.78, 'walk');
          if (arrived) {
            enter('plantInspect');
          } else if (state.timer <= 0) {
            state.plantFocus = null;
            animator.setLookOverride(null);
            enter('idle');
          }
          break;
        }
        case 'plantInspect': {
          const plant = state.plantFocus;
          if (!plant) {
            enter('idle');
            break;
          }
          animator.setLookOverride({
            x: plant.x,
            y: THREE.MathUtils.clamp(plant.y + (plant.canopyHeight || 0) * 0.80, 0.24, 1.60)
          });
          if (state.timer <= 0) {
            const inviting = (plant.resourceValue || 0) + (plant.canopyHeight || 0) + (plant.canClimb ? 0.18 : 0);
            if (state.needs.energy < 0.55 && inviting > 0.78 && random() < 0.62) {
              enter('plantRest');
            } else {
              state.plantFocus = null;
              animator.setLookOverride(null);
              enter(pickWeighted(random, [['sit', 0.42], [chooseGroomingState('default'), 0.20], ['idle', 0.38]]));
            }
          }
          break;
        }
        case 'plantRest':
          if (state.plantFocus) {
            animator.setLookOverride({
              x: state.plantFocus.x,
              y: THREE.MathUtils.clamp(state.plantFocus.y + 0.12, 0.18, 1.10)
            });
          }
          if (state.timer <= 0) {
            state.plantFocus = null;
            animator.setLookOverride(null);
            enter(pickWeighted(random, [['sleep', 0.28], ['rise', 0.46], [chooseGroomingState('rest'), 0.26]]));
          }
          break;
        case 'zoomies': {
          const arrived = walkToward(dt, TROT_SPEED, 'trot');
          if (arrived || state.timer <= 0) {
            state.zoomieLegs -= 1;
            if (state.zoomieLegs > 0 && state.timer > 0) {
              state.targetX = state.targetX <= (state.minX + state.maxX) / 2 ? state.maxX : state.minX;
            } else {
              enter('idle');
            }
          }
          break;
        }
        case 'stalkMouse': {
          if (!mouseIsFresh()) {
            rememberLastMouse(0.52);
            enter(state.mouseInterest > 0.7 && state.lastMouse ? 'lostMouse' : 'alert');
            break;
          }
          state.targetX = THREE.MathUtils.clamp(state.mouse.x, state.minX, state.maxX);
          walkToward(dt, STALK_SPEED, 'stalk');
          const dist = mouseDistance();
          // In strike range: drop into the coiled butt-wiggle wind-up; the
          // launch (flying grab vs hop-pounce) is decided when it springs.
          if (dist < SWIPE_RANGE * 1.8 && state.mouse.y > 0.18
              && state.mouse.y < LUNGE_MAX_HEIGHT) {
            enter('crouchPounce');
          } else if (state.timer <= 0 || state.mouseInterest <= 0.2) {
            enter('alert');
          }
          break;
        }
        case 'crouchPounce': {
          if (!mouseIsFresh()) {
            rememberLastMouse(0.52);
            enter(state.mouseInterest > 0.7 && state.lastMouse ? 'lostMouse' : 'alert');
            break;
          }
          state.targetX = THREE.MathUtils.clamp(state.mouse.x, state.minX, state.maxX);
          faceMouse();
          animator.setLookOverride({ x: state.mouse.x, y: state.mouse.y });
          if (state.timer <= 0) {
            const dist = mouseDistance();
            const strike = chooseMouseStrike(dist);
            if (strike === 'lunge' && canMouseLunge(dist) && random() < 0.74) {
              recordMouseStrike('lunge');
              startLunge(mouseLungeStyle(dist));
            } else if (strike === 'probe' && dist < PROBE_RANGE) {
              performMouseStrike('probe', dist);
            } else if (strike === 'feint' && dist < FEINT_RANGE && random() < 0.45) {
              performMouseStrike('feint', dist);
            } else {
              state.pendingPounceStyle = strike === 'pounce' && state.mouse.speed > 1.0
                ? 'sidePounce'
                : 'groundPounce';
              performMouseStrike('pounce', dist);
            }
          }
          break;
        }
        case 'mouseProbe': {
          if (mouseIsFresh()) {
            faceMouse();
            animator.setLookOverride({ x: state.mouse.x, y: state.mouse.y });
          }
          if (state.timer <= 0) {
            if (mouseIsFresh() && state.mouseInterest > 1.15
                && mouseDistance() < FEINT_RANGE && random() < 0.42 + personality.playfulness * 0.18) {
              enter('crouchPounce');
            } else {
              enter('alert');
            }
          }
          break;
        }
        case 'mouseFeint': {
          if (mouseIsFresh()) {
            faceMouse();
            animator.setLookOverride({ x: state.mouse.x, y: state.mouse.y });
          }
          if (state.timer <= 0) {
            if (mouseIsFresh() && state.mouseInterest > 0.95
                && mouseDistance() < LUNGE_MAX_RANGE && random() < 0.55 + personality.playfulness * 0.18) {
              enter('crouchPounce');
            } else {
              enter('alert');
            }
          }
          break;
        }
        case 'lostMouse': {
          state.lostTimer += dt;
          // Keep staring at the last-seen spot with a slow curious head-cock.
          if (state.lastMouse) {
            animator.setLookOverride({
              x: state.lastMouse.x,
              y: state.lastMouse.y + Math.sin(state.lostTimer * 1.6) * 0.05
            });
          }
          // Reappeared in view → reassess (interest takes back over).
          if (mouseIsFresh() && Math.abs(state.mouse.x - state.worldX) < WATCH_RANGE
              && state.mouse.y < 1.6) {
            enter('alert');
            break;
          }
          if (state.timer <= 0) {
            state.mouseInterest = Math.max(0, state.mouseInterest - 0.5);
            animator.setLookOverride(null);
            displacementGroom(0.42);
          }
          break;
        }
        case 'bugWatch': {
          const bug = currentBugTarget();
          if (!bug) {
            scheduleBugCooldown(5);
            enter('alert');
            break;
          }
          faceBugTarget(dt);
          const dist = Math.abs(bug.x - state.worldX);
          if (state.timer <= 0) {
            if (dist < BUG_CATCH_RANGE && bug.y < 0.95) {
              if (!tryCatchBug(bug, 0.35)) enter('bugSwat');
            } else if (dist < BUG_STRIKE_RANGE && bug.y < 1.22) {
              enter('bugCoil');
            } else {
              enter('bugStalk');
            }
          }
          break;
        }
        case 'bugStalk': {
          const bug = currentBugTarget();
          if (!bug) {
            scheduleBugCooldown(5);
            enter('alert');
            break;
          }
          const tracking = faceBugTarget(dt);
          const aim = tracking ? tracking.aim : (focusOnBug(bug, dt) || bugAimPoint(bug));
          const lateral = aim.x - state.worldX;
          if (Math.abs(lateral) <= bugHeadingDeadZone(aim)) {
            state.targetX = state.worldX;
            animator.setLocomotion(0, 'stalk');
          } else {
            const heading = tracking ? tracking.heading : stableBugHeading(bug, aim, dt);
            state.targetX = THREE.MathUtils.clamp(
              aim.x - heading * 0.10,
              state.minX,
              state.maxX
            );
            walkToward(dt, STALK_SPEED * (0.9 + personality.playfulness * 0.3), 'stalk');
          }
          const dist = Math.abs(bug.x - state.worldX);
          if (dist < BUG_CATCH_RANGE && bug.y < 0.90 && tryCatchBug(bug, 0.45)) {
            break;
          }
          if (dist < BUG_STRIKE_RANGE && bug.y < 1.28) {
            enter('bugCoil');
          } else if (state.timer <= 0) {
            scheduleBugCooldown(8);
            enter('alert');
          }
          break;
        }
        case 'bugCoil': {
          const bug = currentBugTarget();
          if (!bug) {
            scheduleBugCooldown(5);
            enter('alert');
            break;
          }
          faceBugTarget(dt);
          if (state.timer <= 0) {
            if (bug.y > 0.48 && random() < 0.58 + personality.playfulness * 0.22) {
              startBugLunge(bug);
            } else {
              enter('bugSwat');
            }
          }
          break;
        }
        case 'bugSwat': {
          const bug = currentBugTarget();
          if (bug) {
            faceBugTarget(dt);
          }
          if (state.timer <= 0) {
            if (bug && tryCatchBug(bug, 0.40)) {
              break;
            }
            scheduleBugCooldown(7);
            enter('alert');
          }
          break;
        }
        case 'pounce': {
          // Leap covers ground fast; land into a swat.
          if (mouseIsFresh()) {
            state.targetX = THREE.MathUtils.clamp(state.mouse.x, state.minX, state.maxX);
          }
          walkToward(dt, POUNCE_SPEED, 'walk');
          if (state.timer <= 0) {
            animator.triggerSwipe(false, random() < 0.45 ? 'hook' : 'bat');
            state.swipeCooldown = 1.0 + random() * 2;
            armMouseCatch();
            if (!updatePendingMouseCatch(0)) {
              enter('alert');
            }
          }
          break;
        }
        case 'lungeRecover':
          // Airborne after a miss: the standard worldY damp is the fall.
          // Touchdown fires the landing squash and hands back to alert.
          if (state.worldY < 0.05) {
            state.worldY = 0;
            animator.triggerLand();
            enter('alert');
          } else if (state.timer <= 0) {
            state.worldY = 0;
            enter('alert');
          }
          break;
        case 'petted':
          // Owned by updatePetting; nothing timed here.
          break;
        case 'bellyPet':
          // Owned by updatePetting; resting on its back until the hand leaves.
          break;
        case 'seekAttention': {
          if (mouseIsFresh() && holdForHesitation(dt, { x: state.mouse.x, y: state.mouse.y })) break;
          const arrived = walkToward(dt, WALK_SPEED * 0.9, 'walk');
          if (arrived) {
            // Settle beside the cursor and gaze up at it.
            enter('sit');
            state.timer = 7 + random() * 8;
            if (mouseIsFresh()) {
              animator.setLookOverride({ x: state.mouse.x, y: state.mouse.y });
            }
          } else if (state.timer <= 0 || !mouseIsFresh()) {
            if (state.timer <= 0) state.memory.trust = Math.max(0, state.memory.trust - 0.025);
            enter('idle');
          }
          break;
        }
        case 'bellyUp':
          if (state.timer <= 0) {
            enter(pickWeighted(random, [
              ['playOnBack', 0.22 * (0.3 + personality.playfulness * 1.4)],
              ['lie', 0.22], ['rise', 0.34], ['sleep', 0.22]
            ]));
          }
          break;
        case 'playOnBack':
          if (state.timer <= 0) {
            enter(pickWeighted(random, [['bellyUp', 0.45], ['rise', 0.55]]));
          }
          break;
        case 'bugEat':
          if (state.timer <= 0) {
            animator.setLookOverride(null);
            enter(pickWeighted(random, [[chooseGroomingState('afterBug'), 0.48], ['sit', 0.28], ['alert', 0.24]]));
          }
          break;
        case 'swipe':
          if (state.timer <= 0) {
            // Playful cats often follow a miss with a quick second jab from
            // the other paw — one chain max so it never loops.
            if (!state.swipeChained && mouseIsFresh()
                && mouseDistance() < SWIPE_RANGE && state.mouse.y < SWIPE_HEIGHT
                && random() < 0.30 + personality.playfulness * 0.35) {
              state.swipeChained = true;
              state.timer = 0.55;
              animator.triggerSwipe(true, random() < 0.50 ? 'crossBat' : 'probe');
              armMouseCatch(0.85);
            } else {
              state.swipeChained = false;
              enter('alert');
            }
          }
          break;
        case 'startle':
          if (state.timer <= 0) enter('alert');
          break;
        case 'alert':
          if (state.timer <= 0) {
            if (mouseIsFresh() && state.mouseInterest > 0.8) {
              state.timer = 1.0 + random() * 1.5;
            } else {
              animator.setLookOverride(null);
              displacementGroom(0.3);
            }
          }
          break;
        case 'idle':
        case 'rise':
          if (state.timer <= 0) nextFromIdle();
          break;
        case 'sit':
          if (state.timer <= 0) {
            enter(pickWeighted(random, [
              [chooseGroomingState('rest'), 0.32], ['scratchEar', 0.10], ['idle', 0.22],
              ['loaf', 0.14], ['lie', 0.12], ['rise', 0.10]
            ]));
          }
          break;
        case 'groomPaw':
        case 'groomFace':
        case 'groomFlank':
        case 'groomBelly':
        case 'groomTail':
        case 'groomHaunch':
          if (state.timer <= 0) {
            const chainChance = state.mood === 'sleepy' ? 0.20 : 0.11 + personality.curiosity * 0.07;
            if (random() < chainChance) {
              enter(chooseGroomingState(state.name === 'groomBelly' ? 'belly' : 'rest'));
            } else {
              enter(pickWeighted(random, [['sit', 0.42], ['loaf', 0.18], ['rise', 0.40]]));
            }
          }
          break;
        case 'scratchEar':
          if (state.timer <= 0) {
            enter(pickWeighted(random, [['sit', 0.6], ['idle', 0.4]]));
          }
          break;
        case 'loaf':
          if (state.timer <= 0) {
            const s = circadianSleepPressure();
            enter(pickWeighted(random, [['sleep', 0.35 + s * 0.5], ['rise', 0.40 * (1 - s * 0.7)], [chooseGroomingState('rest'), 0.25 * (1 - s * 0.5)]]));
          }
          break;
        case 'lie':
          if (state.timer <= 0) {
            const s = circadianSleepPressure();
            enter(pickWeighted(random, [
              ['sleep', 0.50 + s * 0.45], ['bellyUp', 0.18 * (1 - s)], ['rise', 0.32 * (1 - s * 0.8)]
            ]));
          }
          break;
        case 'sleep':
          if (state.timer <= 0) {
            // Through the night the cat just rolls over and keeps sleeping; by
            // day it surfaces with a stretch. (A cursor still wakes it anytime.)
            if (circadianSleepPressure() > 0.6 && random() < 0.8) enter('sleep');
            else enter('stretch');
          }
          break;
        case 'stretch':
          if (state.timer <= 0) enter('rise');
          break;
        case 'wallClimb': {
          // Ascend with the visible body line held against the screen edge;
          // the animator's paw cycle keys off worldY so feet match height.
          pinClimbingBodyToWall(dt);
          state.worldY += CLIMB_SPEED * dt;
          if (state.worldY >= state.climbTargetY || state.timer <= 0) {
            enter('wallHang');
          }
          break;
        }
        case 'wallHang':
          pinClimbingBodyToWall(dt);
          if (state.timer <= 0) {
            // Nobody tapped it down; climb down on its own eventually.
            enter('wallJumpDown');
          }
          break;
        case 'wallJumpDown': {
          const jump = state.wallJump;
          if (!jump) {
            enter('alert');
            break;
          }
          jump.t = Math.min(1, jump.t + dt / jump.duration);
          const tau = jump.t;
          state.worldX = jump.startX + (jump.targetX - jump.startX) * tau;
          state.worldY = Math.max(
            0,
            jump.startY * (1 - tau * tau) + jump.arc * Math.sin(tau * Math.PI)
          );
          if (tau >= 1) {
            state.wallJump = null;
            state.worldY = 0;
            animator.cancelLunge();
            animator.triggerLand();
            enter('alert');
          }
          break;
        }
        case 'wallApproach': {
          const arrived = walkToward(dt, WALK_SPEED * 0.85, 'walk');
          if (arrived) {
            const action = state.pendingWallAction || 'wallInspect';
            state.pendingWallAction = null;
            enter(action);
          } else if (state.timer <= 0) {
            state.pendingWallAction = null;
            enter('idle');
          }
          break;
        }
        case 'wallInspect':
          // Nose held just at the glass.
          pinContactToWall(dt, animator.getHeadOffsetX() + (state.contactSide === 'left' ? -0.14 : 0.14), 5);
          if (state.timer <= 0) {
            enter(pickWeighted(random, [['wallRub', 0.28], ['rise', 0.28], ['idle', 0.44]]));
          }
          break;
        case 'wallRub':
          // Cheek pressed into the edge through the rub cycle.
          pinContactToWall(dt, animator.getHeadOffsetX() + (state.contactSide === 'left' ? -0.10 : 0.10), 5);
          if (state.timer <= 0) enter('rise');
          break;
        case 'wallScratch':
          // Claws raking the actual edge, not air beside it.
          pinContactToWall(dt, animator.getPawAnchor().x, 6);
          if (state.timer <= 0) enter('rise');
          break;
        case 'dockInspect':
          if (state.timer <= 0) {
            enter(pickWeighted(random, [['dockPaw', 0.34], ['dockRest', 0.20], ['idle', 0.46]]));
          }
          break;
        case 'dockPaw':
          if (state.timer <= 0) enter('alert');
          break;
        case 'dockRest':
          if (state.timer <= 0) enter(pickWeighted(random, [['rise', 0.65], ['sleep', 0.35]]));
          break;
        case 'gnomeApproach': {
          if (!state.gnomeFocus) {
            scheduleGnomeCooldown();
            enter('idle');
            break;
          }
          state.targetX = territoryWatchSpot(state.gnomeFocus);
          const look = {
            x: state.gnomeFocus.centerX,
            y: THREE.MathUtils.clamp(state.gnomeFocus.centerY, 0.25, 1.35)
          };
          if (holdForHesitation(dt, look)) break;
          const arrived = walkToward(dt, WALK_SPEED * 0.78, 'walk');
          faceGnomeTerritory();
          if (arrived || state.timer <= 0) {
            enter('gnomeWatch');
          }
          break;
        }
        case 'gnomeWatch':
          faceGnomeTerritory();
          if (!state.gnomeFocus) {
            scheduleGnomeCooldown();
            enter('idle');
            break;
          }
          if (state.timer <= 0) {
            const rideOdds = 0.20 + personality.curiosity * 0.18 + personality.playfulness * 0.16;
            if (state.gnomeRideCooldown <= 0 && random() < rideOdds) {
              enter('gnomeRide');
            } else {
              scheduleGnomeCooldown();
              enter(pickWeighted(random, [['sit', 0.40], ['rise', 0.35], ['idle', 0.25]]));
            }
          }
          break;
        case 'gnomeRide': {
          state.gnomeRiding.active = true;
          state.gnomeRiding.phase = state.gnomeRiding.progress < 0.98 ? 'mounting' : 'mounted';
          state.gnomeRiding.progress = Math.min(1, state.gnomeRiding.progress + dt * 1.25);
          const previousX = Number.isFinite(state.gnomeRiding.lastX)
            ? state.gnomeRiding.lastX
            : state.worldX;
          const previousHeading = animator.state.heading || state.gnomeRideDirection || 1;
          const hasMission = !!state.gnomeRiding.mission;
          let shouldWalk = true;
          if (hasMission) {
            shouldWalk = stepGnomeMountedCollectionMission(dt);
            if (state.gnomeRiding.missionPhase === 'collecting') shouldWalk = false;
          }
          const arrived = shouldWalk
            ? walkToward(dt, TROT_SPEED * 0.52, 'trot')
            : false;
          if (!shouldWalk) {
            animator.setLocomotion(0, 'walk');
          }
          const nextHeading = animator.state.heading || state.gnomeRideDirection || previousHeading;
          const velocityX = (state.worldX - previousX) / Math.max(0.001, dt);
          state.gnomeRiding.heading = nextHeading;
          state.gnomeRiding.velocityX = Number.isFinite(velocityX) ? velocityX : 0;
          state.gnomeRiding.turning = previousHeading !== nextHeading || animator.isTurning();
          state.gnomeRiding.stride = (state.gnomeRiding.stride || 0)
            + Math.abs(state.gnomeRiding.velocityX) * dt;
          state.gnomeRiding.lastX = state.worldX;
          if (!hasMission && arrived && state.timer > 1.8) {
            setGnomeRideTarget(0.75 + random() * 1.0);
          }
          if (state.gnomeRiding.missionPhase === 'dismounting' || state.timer <= 0) {
            enter('gnomeDismount');
          }
          break;
        }
        case 'gnomeDismount':
          faceGnomeTerritory();
          state.gnomeRiding.active = true;
          state.gnomeRiding.phase = 'dismounting';
          state.gnomeRiding.progress = Math.min(1, state.gnomeRiding.progress + dt * 1.4);
          if (state.timer <= 0) {
            clearGnomeRiding();
            state.gnomeFocus = null;
            scheduleGnomeRideCooldown();
            scheduleGnomeCooldown();
            enter('idle');
          }
          break;
      }
      commitFrame(dt);
    }

    return {
      state,
      personality,
      update,
      force: enter,
      isSleeping: () => state.name === 'sleep',
      circadianDayDrive,
      setClockHour(h) {
        state.clockHourOverride = (h == null ? null : Number(h));
      },
      // Cross-session memory: the cat's inner state (drives, mood, how worn-down
      // its novelty/over-pet tolerance is) so it resumes its emotional life each
      // launch instead of re-rolling. Temperament (activity/curiosity/play) is
      // already persisted via settings, so it is intentionally not duplicated here.
      snapshotMemory() {
        return {
          v: 1,
          energy: state.needs.energy,
          play: state.needs.play,
          social: state.needs.social,
          hunger: state.needs.hunger,
          groomNeed: state.needs.groomNeed,
          novelty: state.novelty,
          petOverstim: state.petOverstim,
          mood: state.mood,
          trust: state.memory.trust,
          favoriteX: state.memory.favoriteX,
          favoriteWeight: state.memory.favoriteWeight,
          poiKind: state.memory.poiKind,
          poiX: state.memory.poiX,
          poiY: state.memory.poiY,
          poiWeight: state.memory.poiWeight,
          poiAge: state.memory.poiAge
        };
      },
      restoreMemory(mem) {
        if (!mem || typeof mem !== 'object') return false;
        const clamp01 = (value, fallback) => {
          const n = Number(value);
          return Number.isFinite(n) ? Math.max(0, Math.min(1, n)) : fallback;
        };
        state.needs.energy = clamp01(mem.energy, state.needs.energy);
        state.needs.play = clamp01(mem.play, state.needs.play);
        state.needs.social = clamp01(mem.social, state.needs.social);
        state.needs.hunger = clamp01(mem.hunger, state.needs.hunger);
        state.needs.groomNeed = clamp01(mem.groomNeed, state.needs.groomNeed);
        state.novelty = clamp01(mem.novelty, state.novelty);
        const overstim = Number(mem.petOverstim);
        if (Number.isFinite(overstim)) state.petOverstim = Math.max(0, overstim);
        if (mem.mood === 'frisky' || mem.mood === 'mellow' || mem.mood === 'sleepy') {
          state.mood = mem.mood;
        }
        state.memory.trust = clamp01(mem.trust, state.memory.trust);
        const favoriteX = Number(mem.favoriteX);
        if (Number.isFinite(favoriteX)) state.memory.favoriteX = favoriteX;
        state.memory.favoriteWeight = clamp01(mem.favoriteWeight, state.memory.favoriteWeight);
        if (typeof mem.poiKind === 'string') state.memory.poiKind = mem.poiKind;
        const poiX = Number(mem.poiX);
        const poiY = Number(mem.poiY);
        if (Number.isFinite(poiX)) state.memory.poiX = poiX;
        if (Number.isFinite(poiY)) state.memory.poiY = poiY;
        state.memory.poiWeight = clamp01(mem.poiWeight, state.memory.poiWeight);
        const poiAge = Number(mem.poiAge);
        if (Number.isFinite(poiAge)) state.memory.poiAge = Math.max(0, poiAge);
        return true;
      },
      setPersonality(values) {
        Object.assign(personality, values || {});
      },
      setMouse(x, y) {
        const prev = state.mouse;
        let speed = 0;
        let vx = 0;
        let vy = 0;
        if (prev && prev.age < 0.5) {
          // Smoothed cursor speed in world units/second.
          const dtSample = Math.max(0.016, prev.age);
          const rawVx = (x - prev.x) / dtSample;
          const rawVy = (y - prev.y) / dtSample;
          speed = prev.speed * 0.6 + Math.hypot(rawVx, rawVy) * 0.4;
          vx = (prev.vx || 0) * 0.55 + rawVx * 0.45;
          vy = (prev.vy || 0) * 0.55 + rawVy * 0.45;
        }
        state.mouse = { x, y, speed, vx, vy, age: 0 };
      },
      clearMouse() {
        state.mouse = null;
      },
      setGnomeTerritories(items) {
        state.gnomeTerritories = (Array.isArray(items) ? items : [])
          .map((item) => {
            const points = Array.isArray(item.points) ? item.points : [];
            if (points.length < 3) return null;
            const minX = Number(item.minX);
            const maxX = Number(item.maxX);
            const minY = Number(item.minY);
            const maxY = Number(item.maxY);
            if (![minX, maxX, minY, maxY].every(Number.isFinite)) return null;
            return {
              id: String(item.id || ''),
              points,
              minX,
              maxX,
              minY,
              maxY,
              centerX: Number.isFinite(Number(item.centerX)) ? Number(item.centerX) : (minX + maxX) / 2,
              centerY: Number.isFinite(Number(item.centerY)) ? Number(item.centerY) : (minY + maxY) / 2
            };
          })
          .filter(Boolean);
        if (state.gnomeFocus && !state.gnomeTerritories.some((territory) => territory.id === state.gnomeFocus.id)) {
          state.gnomeFocus = null;
        }
        state.worldX = safeXOutsideGnomeTerritories(state.worldX);
        state.targetX = safeXOutsideGnomeTerritories(state.targetX);
        if (state.gnomeTerritories.length === 0 && GNOME_STATES.includes(state.name)) {
          clearGnomeRiding();
          enter('idle');
        }
      },
      setGnomePlantTargets(items) {
        state.gnomePlantTargets = (Array.isArray(items) ? items : [])
          .map((item) => {
            const x = Number(item.x);
            const y = Number(item.y);
            if (!Number.isFinite(x) || !Number.isFinite(y)) return null;
            return {
              id: String(item.id || item.species || ''),
              species: String(item.species || ''),
              kind: String(item.kind || ''),
              x,
              y,
              screenX: Number.isFinite(Number(item.screenX)) ? Number(item.screenX) : 0.5,
              screenY: Number.isFinite(Number(item.screenY)) ? Number(item.screenY) : 0.5,
              scale: Number.isFinite(Number(item.scale)) ? Number(item.scale) : 1,
              resourceValue: THREE.MathUtils.clamp(Number(item.resourceValue) || 0, 0, 1),
              canopyHeight: THREE.MathUtils.clamp(Number(item.canopyHeight) || 0, 0, 0.5),
              canClimb: !!item.canClimb
            };
          })
          .filter((item) => item && item.id);
        if (state.plantFocus) {
          const refreshedFocus = state.gnomePlantTargets.find((plant) => plant.id === state.plantFocus.id);
          if (refreshedFocus) {
            state.plantFocus = refreshedFocus;
          } else {
            state.plantFocus = null;
            if (PLANT_STATES.includes(state.name)) enter('idle');
          }
        }
      },
      setBugs(items) {
        const previous = new Map(state.bugs.map((bug) => [bug.id, bug]));
        state.bugs = (Array.isArray(items) ? items : []).map((item) => {
          const id = String(item.id || '');
          const x = Number(item.x) || 0;
          const y = Number(item.y) || 0;
          const prev = previous.get(id);
          let vx = 0;
          let vy = 0;
          if (prev && prev.age < BUG_STALE_SECONDS) {
            const dtSample = Math.max(0.05, prev.age);
            const rawVx = (x - prev.x) / dtSample;
            const rawVy = (y - prev.y) / dtSample;
            vx = (prev.vx || 0) * 0.55 + rawVx * 0.45;
            vy = (prev.vy || 0) * 0.55 + rawVy * 0.45;
          }
          return {
            id,
            species: String(item.species || ''),
            x,
            y,
            vx,
            vy,
            plantFocused: !!item.plantFocused,
            age: 0
          };
        }).filter((item) => item.id);
        if (state.targetBugID && !state.bugs.some((bug) => bug.id === state.targetBugID)
            && isBugDriven()) {
          state.targetBugID = null;
        }
        if (state.bugFocus.id && !state.bugs.some((bug) => bug.id === state.bugFocus.id)) {
          state.bugFocus.lock = Math.max(0, state.bugFocus.lock - 0.18);
        }
      },
      isPurring() {
        return state.name === 'petted' || state.name === 'bellyPet';
      },
      gnomeRiding() {
        return {
          ...state.gnomeRiding,
          state: state.name
        };
      },
      setEnvironment(values) {
        state.environment = {
          ...state.environment,
          ...(values || {}),
          wallInsetsPx: {
            ...state.environment.wallInsetsPx,
            ...((values && values.wallInsetsPx) || {})
          }
        };
      },
      // A real click landed at (wx, wy). On the wall, a tap on the body is
      // the signal to come down.
      pokeAt(wx, wy) {
        const bodyCenterY = state.worldY + 0.45;
        const isWallMounted = state.name === 'wallClimb' || state.name === 'wallHang';
        const halfWidth = isWallMounted ? WALL_CLICK_HALF_WIDTH : 0.68;
        const halfHeight = isWallMounted ? WALL_CLICK_HALF_HEIGHT : 0.90;
        const isBodyHit = Math.abs(wx - state.worldX) < halfWidth
          && Math.abs(wy - bodyCenterY) < halfHeight;
        if (isBodyHit && isWallMounted) {
          enter('wallJumpDown');
          return { hit: true, opensChat: false, action: 'wallJumpDown' };
        }
        return { hit: isBodyHit, opensChat: isBodyHit, action: isBodyHit ? 'chat' : 'none' };
      },
      setBounds(minX, maxX) {
        state.minX = minX;
        state.maxX = maxX;
        state.worldX = safeXOutsideGnomeTerritories(THREE.MathUtils.clamp(state.worldX, minX, maxX));
        state.targetX = safeXOutsideGnomeTerritories(THREE.MathUtils.clamp(state.targetX, minX, maxX));
      }
    };
  }

  return { create };
})();
