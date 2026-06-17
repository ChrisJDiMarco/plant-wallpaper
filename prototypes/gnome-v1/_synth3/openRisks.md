PERFORMANCE
- Decay loop is O(cells) every frame per village. At cellSize ~8 a 300u zone is ~38x38=1444 cells (trivial). The 120x120=14,400 cap bounds the worst case; many large simultaneous villages add up. Mitigations in place: GRID_CAP=120, TEX_MAX=768, repaint throttled to 10Hz.
- repaint() loops over canvas pixels (up to 768*768=590k) at 10Hz — the heaviest op. If it shows in a profile, lower TEX_OVERSAMPLE or REPAINT_HZ.

TEXTURE UPLOAD COST
- Each repaint sets tex.needsUpdate=true -> full GPU re-upload of the canvas, rate-limited to 10Hz. With N villages that is N uploads/100ms; fine for a handful, drop REPAINT_HZ for dozens. This is the classic cost center for canvas-accumulation paths and is deliberately throttled.

TRANSPARENCY / SORT
- Ground is transparent + depthWrite:false + renderOrder:1 at y~0.18 above the y=0 shadow catcher; polygonOffset + the y-lift prevent z-fighting. Opaque houses/props draw first and sort fine. RISK: two overlapping depthWrite:false transparents (ground vs lantern-glow sprites) can flicker order — low risk since glows are small/elevated; if seen, give the ground a lower renderOrder than the glows.
- alphaTest:0.01 discards fully-transparent texels so unworn ground shows the desktop with no grey haze; raise it if a faint film appears.

GNOMES LEAVING BOUNDS
- stepGnome clamps every move inside [min+EDGE_PAD, max-EDGE_PAD]; sim showed zero OOB over 21,600 frames. If a caller passes a POI outside bounds, clampInside pins the goal to the padded edge (gnome walks to the wall, not off it). The STEP-2 well is plaza+offset and could near an edge on a tiny zone — clampInside covers it; snapInside (zone.js) it first if you want it strictly in-polygon.
- Routing uses the axis-aligned bounding BOX, not the drawn polygon. On concave/L-shaped zones a straight leg between two in-polygon POIs can clip an empty corner of the box. Endpoints are always in-polygon (populateZone enforces it). Acceptable for the aesthetic; gate moves with pointInPolygon if it looks wrong on heavily concave zones.

CORRECTNESS / WIRING
- deposit(x,z,strength): strength is the already-accumulated per-frame amount routing passes (roleW*dt). Do NOT also multiply by dt in the caller. This is the one reconciliation between the two source modules; verified by sim.
- mulberry32 (routing rng, STEP 2) is a zone.js global; if load order regresses, emergence's built-in PRNG is the fallback (still deterministic).
- Builder work-pinning (STEP 2) needs rec.assignedSite set before routing.assign — spawnGnome sets it before buildVillage returns, so safe as written.
- seedPlaza calls repaint() synchronously — fine at build time, never per frame.

MEMORY
- dispose() frees geo/mat/tex and nulls the Float32 + canvas buffers; STEP 4 wires it into removeVillage. Without STEP 4, each erased zone leaks a canvas + texture + two Float32Arrays — ensure it lands.