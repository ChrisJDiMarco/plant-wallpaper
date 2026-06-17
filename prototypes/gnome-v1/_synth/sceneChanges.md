DELETE from prototypes/gnome-v1/index.html (current static diorama):

1. GROUND + GRASS:
   - The `ground` mesh (lines 156-159) and the entire `grassMaterial()` factory (lines 417-434). The product is a transparent desktop overlay; an opaque ground would paint over the wallpaper. REPLACE with `makeShadowCatcher({ size: 4000, opacity: 0.28 })` — an invisible ShadowMaterial plane at y=0 that shows ONLY contact shadows.
   - `M.grass`, `M.leaf`, `M.leafLite` material entries become dead once trees go (lines 104,112-113) — remove.

2. TREES / TREEHOUSE / FOREST:
   - `tree()` (lines 207-218) and `treehouse()` (219-226) factories.
   - The forest placement loop (lines 270-271) and `place(treehouse(120), 150, -118)` (272).
   - The forest path `pathTo(150, -118, -40)` (296).

3. HAND-PLACED FIXED HOUSES + their factories:
   - `cabin()` (162-173), `mushroom()` (174-187), `roundhouse()` (188-197), `elderTower()` (198-206), `cottage()` (259-266).
   - Their placements: `place(cabin(),…)`, `place(mushroom(),…)`, `place(roundhouse(),…)`, `place(elderTower(),…)`, `place(cottage(),…)` (lines 254-257, 267).

4. HAND-AUTHORED PATHS:
   - `pathTo()` factory (276-289) and ALL its calls (290-296: cabinPath, the 112/-52 path, roundPath, the 8/-112 path, the 96/84 path, the forest path).
   - The manual `plaza` cobble disc + the 26-stone scatter loop (299-304). REPLACED by buildZone's `makePlaza`.

5. HAND-PLACED LANTERNS:
   - The `[[-58,-14],…].forEach(place(lantern()))` loop (307). REPLACED by populateZone props (lantern type). KEEP the `lantern()` factory ONLY if you want the prototype's sprite-glow style; otherwise buildZone's makeProp('lantern') supersedes it.

6. OLD STATIC GNOME + WALKERS/IDLERS:
   - The cone-body `gnome(hueColor)` factory (237-249) — REPLACE with `makeGnome()`.
   - The `walkers` array bound to `cabinPath`/`roundPath` (354-358) and the idle-gnome loop (360-364) — REPLACE with rigged gnomes driven by `poseGnome()` (see integrationMap).
   - In animate(): the `walkers.forEach` curve-follow (390-395) and `idlers.forEach` (396) blocks — REPLACE with per-gnome poseGnome + the build-advance loop.

WHAT REPLACES IT (new world build, run once after lights/materials are set up):
   - Define a `zonePolygon` = ordered [{x,z}] covering the old layout footprint, e.g.
       [{x:-200,z:-200},{x:200,z:-200},{x:200,z:200},{x:-200,z:200}]  (or the user-drawn region).
   - `const { group: zoneGroup, description } = spawnZone(zonePolygon, { seed: 1337, build: { houseScale: 14 } }); scene.add(zoneGroup);`
     This adds: shadow catcher + glowing outline + plaza + roads (ribbons) + finished houses + props.
   - For each index in `description.buildSites`: `const site = makeBuildSite({ type: rng()>0.5?'cabin':'roundhouse', seed }); site.group.position.set(s.x,0,s.z); site.group.rotation.y = s.rotation; scene.add(site.group);` and store `{ site, progress:0 }`.
   - Spawn N rigged gnomes via `makeGnome({...})` at plaza-adjacent points; store `{ group, parts, action, ... }`.

KEEP UNCHANGED:
   - renderer (antialias, PCFSoft shadowMap, ACESFilmic) — BUT for the shipped overlay product, switch to `{ alpha:true, premultipliedAlpha:false }` + `renderer.setClearColor(0x000000,0)` and DROP `scene.background`/`scene.fog`. For the browser PROTOTYPE keep the makeSky() background + fog so geometry is visible (the transparent path is the integrationMap's "ship" note).
   - All lighting: HemisphereLight, the `moon` DirectionalLight (it drives contact shadows — widen its shadow.camera bounds to enclose the zone), the `fill` light, and the `fireLight` PointLight.
   - The `mat`, `box`, `cyl`, `cone`, `sph`, `glow`, `litWindow` helpers, `makeGlowTex`, `makeSky` (prototype only).
   - Bonfire group (310-317), festival bunting (319-329), fireflies (332-344), and cabin smoke (347-351) — KEEP as ambient diorama dressing; re-anchor the smoke onto a build-site `smokeAnchor` once that site is finished (see integrationMap).
   - OrbitControls (56-69) and the animate() fire flicker / firefly / clock scaffolding.