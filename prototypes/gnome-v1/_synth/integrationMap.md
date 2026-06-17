WIRING for prototypes/gnome-v1/index.html. All four functions (makeGnome, poseGnome, makeBuildSite, populateZone/buildZone/makeZoneOutline/makeShadowCatcher/spawnZone) must be defined so they can see the closure-local `mat()` — paste them INSIDE the `buildVillage(container)` closure, AFTER the `M` material table and the `box/cyl/cone/sph` helpers are declared (≈ after line 142), and BEFORE the world-layout section. They each `typeof mat === 'function'` check and will resolve the closure `mat`. (If you instead keep them outside the IIFE, they fall back to their own MeshStandardMaterial — also fine, just slightly different palette.)
   NAME-COLLISION WARNING: makeBuildSite and buildZone declare their OWN local `box/cyl/sph`/`M` inside their function bodies — these shadow the closure helpers harmlessly. No rename needed. makeGnome uses `add/grp/limbSeg` (no collision).

ONE-TIME WORLD SETUP (replace the deleted house/tree/path/plaza/gnome placement block, ≈ lines 161-364):

   // --- define the zone (the old footprint, or a user-drawn polygon) ---
   const zonePolygon = [
     { x: -200, z: -200 }, { x: 200, z: -200 }, { x: 200, z: 200 }, { x: -200, z: 200 }
   ];
   const HOUSE_SCALE = 14;                       // cottage walls ≈ 14*0.8 ≈ 11u; towers taller — reads with ~26u gnomes
   const zoneSeed = 1337;
   const description = populateZone(zonePolygon, { seed: zoneSeed, build: { houseScale: HOUSE_SCALE } });

   // shadow catcher (ships) + outline (drawn region) + finished houses/roads/plaza/props
   scene.add(makeShadowCatcher({ size: 1200, opacity: 0.28 }));   // size ≥ zone bounds
   scene.add(makeZoneOutline(zonePolygon, { color: 0x4fd1c5, width: 4 }));
   const lanternBudget = { n: 8 };                                // cap real point-lights
   // build the static zone meshes, but pass the lantern budget through makeProp:
   //   simplest: call buildZone(description, { houseScale: HOUSE_SCALE }) then, if you
   //   want capped lights, instead loop description.props yourself calling makeProp(p, M, lanternBudget).
   scene.add(buildZone(description, { houseScale: HOUSE_SCALE }));

   // --- live build sites at flagged indices ---
   const buildSites = [];
   description.buildSites.forEach((idx, k) => {
     const s = description.sites[idx];
     const site = makeBuildSite({ type: (k % 2 === 0) ? 'cabin' : 'roundhouse', seed: zoneSeed + idx, scale: 1 });
     site.group.position.set(s.x, 0, s.z);
     site.group.rotation.y = s.rotation;        // faces plaza, same convention as houses
     scene.add(site.group);
     buildSites.push({ site, progress: 0, rate: 0.012 + Math.random() * 0.01, smokeBound: false });
   });

   // --- rigged gnomes (replace cone gnome + walkers + idlers) ---
   const gnomeColors = [0xb8512f, 0x3f6b9c, 0x6a8f3a, 0xb08a2e, 0x824a8c];
   const gnomes = [];
   function spawnGnome(action, role, x, z) {
     const g = makeGnome({ hatColor: gnomeColors[gnomes.length % gnomeColors.length], role });
     g.group.position.set(x, 0, z);
     g.group.scale.setScalar(1.0);              // ~26u tall; bump to ~1.1 if it reads small vs houses
     scene.add(g.group);
     const rec = { group: g.group, parts: g.parts, action, role,
                   home: { x, z }, target: null, speed: 16 + Math.random() * 8, phase: Math.random() * 6 };
     gnomes.push(rec); return rec;
   }
   // a few idlers at the plaza, a couple of walkers, and one builder per build site
   spawnGnome('idle','idle', description.plaza.x - 22, description.plaza.z + 14);
   spawnGnome('idle','idle', description.plaza.x + 20, description.plaza.z - 10);
   spawnGnome('cheer','idle', description.plaza.x + 6, description.plaza.z + 24);
   buildSites.forEach(bs => {
     const sp = description.sites[bs.idxRef || 0];
     const b = spawnGnome('build','build', bs.site.group.position.x + 10, bs.site.group.position.z + 10);
     b.assignedSite = bs; b.group.lookAt(bs.site.group.position.x, 0, bs.site.group.position.z);
   });
   // 2 wandering gnomes that drift between the plaza and build sites along description.paths
   const wanderers = [ spawnGnome('walk','carry', description.plaza.x, description.plaza.z + 30),
                       spawnGnome('walk','carry', description.plaza.x, description.plaza.z - 30) ];

ANIMATION LOOP (inside the existing animate(), keep the fire flicker / firefly / clock code; ADD):

   const dt = Math.min(0.05, clock.getDelta ? clock.getDelta() : 0.016); // if you switch to getDelta; else track manually

   // (1) pose every gnome each frame
   gnomes.forEach(rec => {
     poseGnome(rec.parts, t + rec.phase, rec.action, { speed: 1.0 });
   });

   // (2) walkers advance along a path; builders advance the nearest site
   wanderers.forEach((w, i) => {
     // simple ping-pong along the spine path (description.paths[0]) — sample it like the old curve:
     const path = description.paths[0];
     const u = (Math.sin(t * 0.06 + i * Math.PI) * 0.5 + 0.5);
     const fi = Math.min(path.length - 2, Math.floor(u * (path.length - 1)));
     const a = path[fi], b = path[fi + 1];
     w.group.position.set(a.x, 0, a.z);
     w.group.rotation.y = Math.atan2(b.x - a.x, b.z - a.z);  // face +Z down the path (faces travel dir)
     // poseGnome already added the vertical bob via root.position.y inside the rig
   });

   // (3) builders slowly advance their assigned build site, then admire it
   buildSites.forEach(bs => {
     if (bs.progress < 1) {
       bs.progress = Math.min(1, bs.progress + bs.rate * dt * 4);   // ~tunable build speed
       bs.site.setProgress(bs.progress);
     }
     if (bs.progress >= 1 && !bs.smokeBound) {                       // chimney smoke when finished
       bs.smokeBound = true;
       const wp = new THREE.Vector3();
       bs.site.smokeAnchor.getWorldPosition(wp);
       smoke.forEach((s, i) => { s.userData.base = wp.y + i * 7; s.position.x = wp.x; s.position.z = wp.z; });
     }
   });
   // when a builder's site finishes, flip its action so it stops hammering an empty space:
   gnomes.forEach(rec => {
     if (rec.assignedSite && rec.assignedSite.progress >= 1) rec.action = 'cheer';
   });

   // (4) cap lantern flicker etc. — unchanged from prototype.

KEEP (do not remove): renderer config, all four lights (moon/fill/hemisphere/fireLight), OrbitControls, bonfire group, festival bunting, fireflies, the smoke sprite array (now re-anchored to a finished build site), makeSky/makeGlowTex/grassMaterial-removed, the fire flicker + firefly drift in animate().

CONVENTION RECONCILIATION (all three modules agree):
   - Up axis Y; ground XZ at y=0; characters/houses face +Z. ✓ matches existing walkers' atan2(dx,dz).
   - facing yaw to point +Z at a target T from P: `Math.atan2(T.x - P.x, T.z - P.z)` — used identically by populateZone (site.rotation), buildSites placement, gnome lookAt, and walker heading.
   - Scale ladder: gnome ~26u · build-site footprint 22x18 / ~24u tall · zone houseScale 14 → cottage ≈ 11-22u. All within the brief's 22-28u wall band. The OLD prototype used ~46u cabins at ~±200 world coords — the new zone fills that same ±200 canvas but with correctly-scaled ~26u-relative buildings, so DON'T also scale the gnomes down to 0.85 like the old cone gnome did.
   - mat() usage: all modules prefer the host closure mat(hex,{roughness,metalness,emissive,emissiveIntensity[,transparent,opacity]}); the prototype's mat signature matches, so no option is dropped.