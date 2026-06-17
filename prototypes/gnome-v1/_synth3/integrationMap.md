FILE: emergence.js is written and verified at
/Users/chrisdimarco/jarvis/projects/WallpaperGarden/Sources/PlantWallpaper/WebAssets/gnomes/emergence.js
(node --check = SYNTAX_OK; headless integration sim = PASS — see "VERIFICATION" at the end). It SUPERSEDES the two separate files ground.js / emergent-ground.js and routing.js — those can be deleted once wiring lands (they are not loaded by index.html). main.js and index.html are NOT yet modified; below is the exact wiring.

================================================================================
STEP 0 — LOAD THE SCRIPT  (index.html)
================================================================================
In gnomes/index.html, add ONE line BEFORE main.js (after the other module scripts):

    <script src="zone.js"></script>
    <script src="detail.js"></script>
    <script src="emergence.js"></script>      <!-- NEW: ground + routing globals -->
    <script src="main.js"></script>

emergence.js depends only on global THREE (already loaded via ../cat/three.min.js)
and the DOM (document.createElement('canvas')). It must load before main.js so
window.createEmergentGround / window.createTownRouting exist when buildVillage runs.

================================================================================
STEP 1 — PER-VILLAGE EMERGENT GROUND  (main.js, inside buildVillage)
================================================================================
buildVillage(zone) currently (lines ~178-189):
    const description = populateZone(poly, { seed });
    village.description = description;
    ... computes houseScale ...
    group.add(buildZone(description, { houseScale }));

CHANGE A — suppress authored roads + plaza so paths are PURELY emergent.
buildZone already supports opts.noRoads and opts.noPlaza (zone.js lines 263 & 265).
Pass both. Houses, props, and build-site placeholders are untouched:

    group.add(buildZone(description, { houseScale, noRoads: true, noPlaza: true }));

(No mesh-surgery needed — this is the cleanest suppression. Do NOT also strip
description.paths; routing ignores them. The bonfire still goes at description.plaza
in CHANGE-existing makeBonfire call ~line 206, which is correct — keep it.)

CHANGE B — create the emergent ground over the zone bounds and add it to village.group.
Insert right after the buildZone(...) line:

    // emergent desire-path ground over this zone's XZ bounds
    const gb = description.bounds; // {minX,maxX,minZ,maxZ,w,h} from populateZone
    village.ground = createEmergentGround({
      bounds: { minX: gb.minX, maxX: gb.maxX, minZ: gb.minZ, maxZ: gb.maxZ },
      cellSize: Math.max(6, Math.min(14, (description.minSpacing || 60) * 0.16)),
      y: 0.18                       // just above the y=0 shadow-catcher, below props
    });
    group.add(village.ground.mesh);
    // optional: pre-seed a faint plaza so the hub reads from t=0 (matches bonfire)
    village.ground.seedPlaza(description.plaza.x, description.plaza.z,
                             (description.minSpacing || 60) * 0.5, 0.7);

NOTE on cellSize: keep cells ~6-14u. With a ~300u zone that is ~22-50 cells/side,
well under the 120 cap and cheap. seedPlaza is optional — without it the plaza still
emerges from traffic within ~30-60s; with it the hub is visible immediately.

================================================================================
STEP 2 — BUILD POI LISTS + ATTACH ROUTING  (main.js, end of buildVillage)
================================================================================
DELETE the static spine/wanderer block (current lines ~242-247):
    village.spine = (description.paths && description.paths[0]) || [...];
    village.wanderers = [ spawnGnome(...), spawnGnome(...) ];
Replace with routing setup. Build POIs from the description + live build sites:

    // --- POIs for routing ---
    // homes = FINISHED cottage doorsteps (sites that are NOT live build sites)
    const homes = description.sites
      .filter(s => s.type !== 'build')
      .map(s => ({ x: s.x, z: s.z }));
    // works = the live build-site world positions
    const works = village.buildSites.map(bs => ({
      x: bs.site.group.position.x, z: bs.site.group.position.z
    }));
    // wells = optional resource nodes; none in the description, so seed one near
    // the plaza so carriers have a logistics endpoint (or pass [] to skip wells).
    const wells = [{
      x: description.plaza.x + (description.minSpacing || 60) * 0.8,
      z: description.plaza.z - (description.minSpacing || 60) * 0.5
    }];

    village.routing = createTownRouting({
      bounds: { minX: gb.minX, maxX: gb.maxX, minZ: gb.minZ, maxZ: gb.maxZ },
      plaza: { x: description.plaza.x, z: description.plaza.z },
      homes, works, wells,
      rng: mulberry32(seed)        // mulberry32 is global (zone.js) — stable village
    });

    // assign every gnome a routing state. Mirror current world pos into {x,z}.
    village.gnomes.forEach(rec => {
      rec.x = rec.group.position.x;
      rec.z = rec.group.position.z;
      // map the spawn 'role' string ('idle'|'build'|'carry') straight through;
      // assign() normalizes anything else to 'idle'.
      village.routing.assign(rec);   // sets rec.home/work/goal/action/heading/...
    });

IMPORTANT — builders must keep their work site. spawnGnome gives build-site gnomes
`b.assignedSite = bs` (line ~236). Before assign(), pin their routing work to that
site so a builder routes to ITS OWN site, not a random one:

    village.gnomes.forEach(rec => {
      rec.x = rec.group.position.x; rec.z = rec.group.position.z;
      if (rec.assignedSite) {
        rec.role = 'build';
        rec.work = { x: rec.assignedSite.site.group.position.x,
                     z: rec.assignedSite.site.group.position.z };
      }
      village.routing.assign(rec);
    });

================================================================================
STEP 3 — DRIVE ROUTING + GROUND IN THE ANIMATE LOOP  (main.js, tick)
================================================================================
In tick(), inside `for (const v of state.villages.values())`:

(a) DELETE the wanderer ping-pong block (current lines ~328-336):
        if (v.wanderers && v.spine && v.spine.length >= 2) { ... }

(b) REPLACE the bare pose loop (current line ~326):
        for (const rec of v.gnomes) poseGnome(rec.parts, t + rec.phase, rec.action, {});
    with a step-then-pose loop that also feeds the ground:

        for (const rec of v.gnomes) {
          v.routing.stepGnome(rec, dt, v.ground.deposit);  // walk + deposit wear
          rec.group.position.set(rec.x, 0, rec.z);          // write world pos back
          if (rec.heading != null) rec.group.rotation.y = rec.heading; // face travel dir
          poseGnome(rec.parts, t + rec.phase, rec.action, {}); // rec.action set by routing
        }

(c) ADVANCE THE GROUND ONCE PER VILLAGE PER FRAME — add after the gnome loop
    (anywhere inside the per-village block, e.g. right after the pose loop):

        v.ground.update(dt);   // decay + throttled (10Hz) texture repaint

(d) FIX THE BUILDER 'cheer' OVERRIDE. Current line ~351:
        for (const rec of v.gnomes) { if (rec.assignedSite && rec.assignedSite.progress >= 1) rec.action = 'cheer'; }
    This now FIGHTS routing every frame (routing already set rec.action). Either
    DELETE this line, or guard it so it only fires while the builder is dwelling AT
    its finished site (so a walking builder isn't frozen mid-stride):

        for (const rec of v.gnomes) {
          if (rec.assignedSite && rec.assignedSite.progress >= 1 &&
              rec.dwell > 0 && rec.action === 'build') {
            rec.action = 'cheer';
          }
        }

================================================================================
STEP 4 — CLEANUP / TEARDOWN  (main.js, removeVillage)
================================================================================
removeVillage(village) (line ~252) removes the group + fire lights. Add a ground
dispose so the canvas/texture/Float32 buffers are freed when a zone is erased:

    function removeVillage(village) {
      village.fires.forEach(f => { if (f.light) { scene.remove(f.light); state.fireLightCount--; } });
      if (village.ground) village.ground.dispose();   // NEW
      scene.remove(village.group);
    }

================================================================================
WHAT STAYS UNCHANGED
================================================================================
- The bonfire at description.plaza (makeBonfire ~line 206) — KEEP. It marks the
  emergent hub. seedPlaza in STEP 1 aligns the paved hub under it.
- All houses, build sites, props, smoke, fireflies, lighting, camera — untouched.
- poseGnome(parts, t, action) calls — unchanged; routing only ever sets rec.action
  to walk|idle|build|cheer|carry, all of which pose.js already handles.
- spawnGnome and the gnome spawn distribution (residents/builders/plaza gatherers)
  — KEEP. Those gnomes now also become routing agents in STEP 2. (The two extra
  ex-wanderers are gone since we deleted that block; if you want the same headcount,
  add 2 more spawnGnome(...,'carry'/'idle') calls before the routing.assign loop.)

================================================================================
VERIFICATION (already run, PASS)
================================================================================
Headless sim /tmp/sim_emergence.js (stubs window/document/THREE, loads emergence.js
exactly as the browser would): 12 gnomes, mixed roles, 6 sim-minutes @ 60fps
(21,600 frames). Result:
  NaN false | OOB false | badAction null  (every rec.action stayed in the valid pose set)
  grid 38x38 cells for a 300u zone (canvas 152x152px — well under caps)
  hottestCell == plazaCell TRUE, plazaRank 1 of 1444
  plazaCell deposit 297.9, plaza 3x3 neighborhood 439.4 (dominates the field)
  cellsWithWear 33.2%  -> two-thirds of ground stays transparent over the desktop
The plaza wears in as the single densest cell; routes converge; the rest fades.