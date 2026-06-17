KEY CONSTANTS (all at the top of PART 1 in emergence.js) and what to nudge:

PATHS FORM TOO SLOWLY (you walk for a minute and see nothing):
  - DEPOSIT_GAIN (0.34) — the master "wear-in speed" dial. Raise to 0.45-0.6 and
    routes pave in ~half the time. This is the FIRST knob to touch.
  - DECAY_RATE (0.0163/s) — if wear is gained but immediately fades, LOWER toward
    0.010 so wear persists longer (slower forgetting). Gain vs decay is the balance:
    a route paves when per-pass gain outruns decay.
  - ALPHA_KNEE (0.16) — wear below this is invisible. LOWER to 0.10 to make faint
    trails show up sooner (earlier "trampled dirt" read).

PATHS FORM TOO FAST / EVERYTHING PAVES (whole zone goes brown):
  - LOWER DEPOSIT_GAIN toward 0.20-0.25.
  - RAISE DECAY_RATE toward 0.025-0.030 so unused detours fade before they pave.
  - RAISE ALPHA_KNEE toward 0.22 so only well-trodden routes become visible.
  - Lower WEAR_MAX (1.6) toward 1.2 to cap how dark a hub can get.

PATHS LOOK WRONG:
  - Too BLOCKY / pixelated: raise TEX_OVERSAMPLE (4 -> 6) and/or GRID_BLUR_PASS
    (1 -> 2). Or use a SMALLER cellSize in the integration call (more cells = finer
    paths) — but watch the GRID_CAP=120 ceiling and the per-frame blur cost.
  - Too BLURRY / no crisp edges: GRID_BLUR_PASS 1 -> 0, and/or RAISE ALPHA_FULL
    toward 1.0 for a harder edge.
  - Paths too WIDE: lower DEPOSIT_RADIUS_CELLS (2.0 -> 1.5) and DEPOSIT_SIGMA
    (0.95 -> 0.7). Too THIN/broken: raise both.
  - Reads as PAINT not worn ground: lower ALPHA_CEIL (0.92 -> 0.85) for more
    desktop bleed-through; the path should never be fully opaque.
  - Cobble looks like a flat grey blob: raise NOISE_AMP (0.10 -> 0.16). Bands
    crossing wrong: BAND_EARTH (0.45) / BAND_COBBLE (0.95) set where dirt->earth->
    cobble transition; lower them to reach stone sooner.

ROUTING / HUB SHAPE (constants in PART 2 of emergence.js):
  - PLAZA_RELAY { build:0.34, carry:0.40, idle:0.55 } — THE hub-forming dial.
    Raise toward 0.6-0.7 for a strongly star-shaped town that funnels hard through
    the center; lower toward 0.2 for a sparser, peripheral network where the plaza
    is just another node. Verified: at these values the plaza is the #1 cell, ~3x
    the next-busiest route.
  - SPEED (22 u/s) — busier feel + more wear/min if raised; ~14s to cross a 300u
    village at 22.
  - Per-role destination weights in chooseDestination() (build 0.55 work/0.25 home/
    0.20 plaza; carry 0.35/0.30/0.35; idle 0.30/0.20/0.50) shape which spokes wear in.
  - Role wear weights in stepGnome (carry 1.25, build 1.0, idle 0.85) — heavy
    haulers pave first; raise carry's to make logistics routes dominate.
  - MEANDER_AMPL (min(7, SPAN*0.018)) — wider/braided trails if raised; the
    sin(u*PI) taper MUST stay (it's what keeps doorsteps/plaza sharp instead of fuzzy).
  - seedPlaza amount in STEP 1 (0.7) — raise to 1.0 for a fully-cobbled hub from t=0,
    drop to 0 (or omit the call) to let the plaza emerge purely from traffic.

PERF DIAL: REPAINT_HZ (10) is the texture re-upload rate. The decay loop runs every
frame (cheap, ~1-14k cells); only the canvas repaint+upload is throttled. If GPU
upload is a bottleneck with many zones, drop to 6-8 Hz (paths animate slightly
chunkier but cost less). TEX_MAX (768) caps canvas dimension regardless of zone size.