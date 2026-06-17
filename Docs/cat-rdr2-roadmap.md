# Cat → RDR2-Caliber Life — Master Plan

_Synthesized 2026-06-16 by a 7-agent design panel (audit + feline ethologist, animal-AI architect, real-time animation engineer, coat/morphology artist, performance engineer). Line anchors verified against current source._

The line numbers check out (tickNeeds:264, nextFromIdle:702, update:2279, SHELL_COUNT:16, setFurLength:1057, the per-frame bug filter at 1376). cat-behavior.js is 3012 lines, the rig is real. The plan is grounded. Here is the master plan.

---

# WallpaperGarden Cat → RDR2-Caliber Life: Master Plan

## 1. VISION

Right now the cat is a brilliant puppet with a great face and a long list of tricks — but the tricks fire from a flat lottery, the body still faintly skates and snaps between gaits, and the cat has no sense of time, no memory, and no inner weather. The goal is to turn it from *a thing that does cat behaviors* into *an animal that lives on the desktop* — one that wakes at dawn, naps in the afternoon, gets the zoomies at dusk, sleeps through the night, drifts back to its favorite corner, remembers where the bug went, arches and puffs when startled then grooms to recover its dignity, kneads the spot before curling up, and comes in seal-point, silver tabby, and a fluffy Maine-Coon longhair. The same cat each morning, picking up its emotional life where it left off. We get there not by rewriting the 3,000-line brain, but by installing **one needs/utility scorer underneath the existing state machine**, feeding it a **wall clock**, smoothing the **motion seams** the eye already catches, and unlocking the **coat and length variety** the geometry is already 90% built for — all under a hard performance budget so a fluffy cat next to a full garden never makes the fans spin.

---

## 2. DESIGN PRINCIPLES (RDR2, tailored to this cat)

**P1 — One brain that scores, many states that execute.** RDR2 animals don't pick from a fixed menu; each possible action *advertises an appetite* and the strongest wins. We insert a single `scoreActions()` arbiter above `nextFromIdle()` (cat-behavior.js:702) and keep all ~55 FSM states exactly as they are — they become pure motor executors. Every later feature (time of day, mood, memory) becomes *one multiplier into one formula*, not edits scattered across dozens of call sites.

**P2 — The day is the master rhythm.** A real cat is crepuscular: dawn and dusk peaks, a midday drowse, a deep night sleep. Time of day is the slow envelope every other drive rides on top of. It biases the scorer; it never overrides instinct (a midnight cursor still wakes the cat).

**P3 — Plant the feet, then move the body.** The single biggest "procedural vs. real" tell is feet that skate. Feet lock to the *world*, and the body rolls over them. Gaits *blend* continuously with speed instead of snapping. Every heavy pose lands with a little weight (anticipation + settle), never floats in.

**P4 — Every state has an inner cause, and you can read it.** Cats broadcast emotion through ears, tail, and posture. We add continuous mood (calm↔alert, content↔irritable) and route it to *shared signal channels* — one ear-pose channel and one tail-vocabulary layer feed startle, hunting, greeting, and irritation at once. The displacement groom after a missed pounce is the clearest possible window into that inner state.

**P5 — Memory makes it an individual.** The cat remembers its favorite corner, where the bug went, and how it felt — across the session and across launches. Two cats with the same coat feel like different animals because temperament and memory persist.

**P6 — Beauty must stay cheap.** This lives on the desktop forever, often behind a fullscreen app, often beside a busy garden. Fur shells are the dominant GPU cost. Richness is bought with a runtime quality knob and a split update budget — never by raising the frame ceiling.

---

## 3. PHASED ROADMAP

> Effort: S (<½ day) · M (1–2 days) · L (3–5 days) · XL (1–2 weeks). Sequenced for fastest visible payoff while respecting dependencies. Phase 0 ships the safety net the whole plan spends against.

### PHASE 0 — Perf foundation & guardrails *(do first; protects everything after)*
| Item | Files | Effort | Impact | Quick win |
|---|---|---|---|---|
| Runtime `setShellCount(n)` LOD knob — pre-build all 16 shells, toggle `.visible` for indices > n (no rebuild, no skinning corruption) | fur.js, cat-model.js, main.js | M | transformative | |
| Three quality tiers (high=16 / balanced=10 / low=6) + Swift picks default from GPU class; `catBridge.setQuality()` | main.js, CatCompanionController.swift, CatCompanionSettings.swift | M | high | |
| Fix per-frame `state.bugs.filter()` allocation (cat-behavior.js:1376) → guarded in-place compaction | cat-behavior.js | S | medium | ✅ |
| Detail-channel sub-rate bus (20Hz for fur breeze, face micro-motion, blink, tail tip-flick; 60Hz for body/IK) | main.js, cat-anim.js, fur.js | M | high | |
| Codify perf budget as enforced header contract in `frame()` + fur.js | main.js, fur.js, cat-behavior.js | S | medium | ✅ |
| Pause when fully occluded by fullscreen app/Space (extend existing `visibilitychange` pause) | CatCompanionController.swift, main.js | M | high | |

### PHASE 1 — Brain: the utility arbiter *(the keystone — everything plugs into this)*
| Item | Files | Effort | Impact | Quick win |
|---|---|---|---|---|
| Extract `scoreActions()`; reduce `nextFromIdle()` to softmax-argmax over it; move hardcoded restore/drain coefficients into `RESTORE_TABLE` data | cat-behavior.js | M | transformative | |
| Add drives: `hunger`, `comfort`, `groomNeed` (bladder optional) to the 3 existing | cat-behavior.js | M | high | |
| Continuous valence/arousal mood replacing the 3-state enum (keep `moodLabel()` shim so existing arousal→pupil + agility scaling keep working) | cat-behavior.js | M | high | |
| Self-interrupt layer at top of `update()` — salience spike or frustration aborts low-commitment states (enables displacement groom) | cat-behavior.js | S | medium | |
| Idle micro-behavior scheduler (ear-twitch, tail-flick, idle blink) — no new states, just animator pokes | cat-behavior.js | S | medium | ✅ |

### PHASE 2 — Circadian / sleep *(the "it has its own life" payoff; depends on Phase 1)*
| Item | Files | Effort | Impact | Quick win |
|---|---|---|---|---|
| Plumb `normalizedTimeOfDay` (0–1) + coarse `phase` from Swift `Calendar` on the existing 5s timer; JS lerps between pushes | CatCompanionController.swift, main.js, cat-behavior.js | S | medium | ✅ |
| Crepuscular curve: dawn/dusk activity peaks, midday drowse, night sleep-pressure floor as a multiplier into `scoreActions()`; instinct still preempts | cat-behavior.js | M | transformative | |
| Consolidated overnight sleep with hard night-trough weighting + longer sleep timers | cat-behavior.js | S | high | ✅ |
| Settle-circle → knead ritual before sleep (knead reuses existing `applyPetting` fold cadence via new `triggerKnead()`) | cat-behavior.js, cat-anim.js | M | high | |
| Sleep architecture: drowse→light→deep→REM twitch (`sleepDepth` float drives sparse paw/whisker/ear flicks; free at SLEEP_FPS=12); groggy wake via stretch→rise | cat-behavior.js, cat-anim.js | M | high | |

### PHASE 3 — Motion smoothness *(removes the "procedural" tells; high fidelity-per-line)*
| Item | Files | Effort | Impact | Quick win |
|---|---|---|---|---|
| Critically-damped spring on body pose channels + per-pose anticipation impulse (sit/lie/loaf/sleep land with weight) | cat-anim.js | M | high | |
| Fixed-timestep substep for explicit spring integrators (mouseCling pendulum at 30/12fps) | cat-anim.js, main.js | S | medium | ✅ |
| Continuous speed→gait blend (idle→creep→walk→trot→gallop), including blended per-leg phase offsets + new gallop knot for zoomies | cat-anim.js, cat-behavior.js | M | high | |
| World-space foot planting / anti-slip lock during stance | cat-anim.js | M | high | |
| Verlet/spring tail chain (tail2–6 lag tail1) replacing kinematic sine — biggest expressiveness gain | cat-anim.js | M | high | |
| Spine ripple (travelling flexion wave hips→neck) | cat-anim.js | S | medium | ✅ |
| Turn-in-place foot stepping + spine bend + bank (kills the turret swivel) | cat-anim.js, cat-behavior.js | L | high | |

### PHASE 4 — Behavior vocabulary *(the beloved cat tells; depends on mood + tail/ear channels)*
| Item | Files | Effort | Impact | Quick win |
|---|---|---|---|---|
| Shared ear-pose channel (alert-forward / neutral / airplane / pinned) feeding startle, hunt, greeting, irritation | cat-anim.js, cat-model.js | L | high | |
| Tail vocabulary as first-class signal layer (content swish, question-mark hook, tucked, pre-strike tip-twitch) — amplitude tweaks on the new tail chain | cat-anim.js | M | medium | |
| Startle arch + piloerection + recover-with-dignity (`triggerArch()` + tail-puff + face-saving groomFace) | cat-behavior.js, cat-anim.js | M | high | |
| Displacement groom when conflicted (abrupt single groom after missed swipe / lostMouse timeout / startle recover) | cat-behavior.js | S | high | ✅ |
| Prey-loop finisher: bite → bunny-kick → reposition → victory groom | cat-behavior.js, cat-anim.js | M | high | |
| Affiliative greeting: question-mark tail + chirrup + head-bonk on cursor approach | cat-behavior.js, cat-anim.js, cat-purr.js | M | medium | |
| Chatter / ekekek at unreachable prey | cat-behavior.js, cat-anim.js, cat-purr.js | M | medium | |
| Eye saccades + smooth pursuit + VOR micro-stabilization | cat-anim.js, cat-model.js | M | medium | |
| Sploot pose + posture-by-comfort (loaf=guarded, side-lie/sploot=relaxed) | cat-behavior.js, cat-anim.js | M | medium | |

### PHASE 5 — Memory & continuity *(makes it an individual; depends on Phase 1)*
| Item | Files | Effort | Impact | Quick win |
|---|---|---|---|---|
| Generalize `lastMouse` into a decaying POI working-memory ring buffer (revisit-last-POI behavior) | cat-behavior.js | M | high | |
| Per-stimulus habituation Map replacing the single global novelty scalar | cat-behavior.js | S | medium | ✅ |
| Favorite-spots affinity → emergent patrol routines | cat-behavior.js | M | high | |
| Temperament axes (boldness, affection) shaping the new states | cat-behavior.js, CatCompanionSettings.swift | M | medium | |
| Cross-session persistence (drives/mood/memory/temperament → localStorage + Swift blob) so the cat resumes its life each launch | cat-behavior.js, main.js, CatCompanionController.swift, CatCompanionSettings.swift | L | high | |

### PHASE 6 — Appearance variety & longhair *(the visible wow; gated by Phase 0 perf knob)*
| Item | Files | Effort | Impact | Quick win |
|---|---|---|---|---|
| Eye-color table + heterochromia / odd-eye (decoupled from coat) | cat-model.js | S | high | ✅ |
| Split `stripeField` → `tabbyField(style)`: mackerel / classic / spotted | cat-model.js | S | high | ✅ |
| Tortoiseshell / torbie pattern engine | cat-model.js | S | medium | ✅ |
| Bengal rosette pattern engine | cat-model.js | M | high | |
| Expand PALETTES (brown classic, blue mackerel, chocolate, lilac, seal/blue point, smoke, silver shaded) | cat-model.js | S | medium | ✅ |
| Per-region `aFurLen` attribute → cheap longhair ruff/britches/tail-plume (additive, NOT more body shells) | cat-model.js, fur.js | L | transformative | |
| Region-masked plume/ruff shells (~+2 draw calls, gated behind longhair tier) for plume volume | fur.js, cat-model.js | L | high | |
| Smoke/shaded/silver tipped-fur via shell-depth color ramp | cat-model.js, fur.js | M | medium | |
| Breed morphology dials (legLength, headWedge, earSize, muscle — clamped, adult proportions) + lynx-tip ear tufts | cat-model.js | L | high | |
| BREED PRESETS (maineCoon / siamese / persian / bengal / britishShorthair) bundling morph+palette+coatLength+eye, wired through Swift | cat-model.js, main.js, CatCompanionSettings.swift, CatCompanionController.swift | L | transformative | |

> **Conflict resolved (longhair):** the appearance lens floated "+6 full-body shells," the perf lens vetoed it. **Ruling:** longhair is bought with the per-region `aFurLen` attribute (zero extra body shells) plus *at most* a region-masked plume/ruff shell pair that `discard`s over 90% of the body — and the whole thing lives under the Phase 0 quality tier, which auto-caps longhair to "balanced" off the high tier. Length, not bulk.

---

## 4. START HERE — first 3–5 builds (max wow-per-effort)

These ship visible life inside the first few days and lay the rails for everything else:

1. **Perf safety net first (Phase 0):** the `setShellCount` LOD knob + the bug-filter allocation fix. *Why first:* it's the regression backstop. Every richness item afterward spends against a budget that can now claw itself back. ~M+S.
2. **The `scoreActions()` arbiter (Phase 1 keystone).** *Why:* it's the foundation the other four lenses all plug into. Doing it early means circadian, mood, and memory are each "one multiplier," not a refactor. M.
3. **Plumb time-of-day + the crepuscular curve + consolidated night sleep (Phase 2).** *Why:* this is the single biggest "it has its own little life" payoff and the operator explicitly asked for a night sleep schedule. The plumbing is a quick win; the curve rides the arbiter you just built. S + M.
4. **Critically-damped springs + per-pose anticipation (Phase 3).** *Why:* one-function change, touches every sit/lie/loaf/sleep transition, instantly removes the "floaty" read. Highest fidelity-per-line in the whole plan. M.
5. **Displacement groom + idle micro-behaviors (Phases 1/4 quick wins).** *Why:* tiny code, huge "this thing has an inner state" signal — the cat washing its shoulder after a missed pounce, never freezing statue-still. S + S.

Two visible coat quick wins (**eye-color/odd-eye** and **mackerel/classic/spotted tabby**) are S-effort, zero-dependency, and can be dropped in any time the operator wants an immediate visual treat while the deeper work proceeds.

---

## 5. PERF GUARDRAILS (non-negotiable, enforced)

1. **Draw-call ceiling:** total = 1 base mesh + *active* shellCount + fixed face details. Never unbounded. Any new `SkinnedMesh` must be justified against the shell budget, not added freely.
2. **Shell fur is the budget:** SHELL_COUNT stops being a frozen constant — it becomes the runtime LOD lever. Longhair buys *length* (per-vertex `aFurLen`), never extra full-body shells.
3. **Two-speed update budget:** primary translation + limb IK + gait run at 60fps; all secondary/detail channels (fur breeze, face micro-motion, blink, tail tip-flick, ear flick) run ≤20fps on the detail bus. New detail behaviors register on the slow bus *by default*.
4. **Brain tick stays allocation-free:** no `new`, no array rebuilds, no `THREE.*` in `update()`'s hot path. The bug-filter fix restores this invariant; circadian/memory must honor it (time-of-day is a cached float, never per-frame polled).
5. **Invisible = zero cost:** pause fully on `visibilitychange` (exists) and extend to fullscreen-occlusion via Swift. A wallpaper cat behind an editor burns no GPU.
6. **Self-correcting under contention:** the auto-degrade governor steps the quality tier down when the cat persistently misses its frame budget (the "many plants = laggy cat" scenario) and back up when headroom returns — so the Swift launch-time GPU guess is never the last word.
7. **Springs must be framerate-independent:** all explicit integrators (mouseCling pendulum, new tail Verlet, jiggle) either substep at a fixed ~120Hz or use the existing framerate-independent `damp()` form — otherwise they oscillate at the 30/12fps tiers.

---

**Key files this plan touches:** `/Users/chrisdimarco/jarvis/projects/WallpaperGarden/Sources/PlantWallpaper/WebAssets/cat/cat-behavior.js` (brain/arbiter/circadian/memory), `cat-anim.js` (motion/springs/gait/tail/ears), `cat-model.js` (coats/morphology/eyes/fur attributes), `fur.js` (shell LOD/longhair/tipping), `main.js` (perf bus/quality/time plumbing), `cat-purr.js` (chirrup/chatter audio), and Swift hosts `CatCompanionController.swift` + `CatCompanionSettings.swift` (time-of-day, quality tier, breed presets, persistence). All cited line anchors (tickNeeds:264, nextFromIdle:702, update:2279, the per-frame bug filter:1376, SHELL_COUNT:16, setFurLength:1057) verified against the current source.