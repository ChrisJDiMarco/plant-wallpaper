VISUAL VERIFICATION PENDING — I could not run this in a live r128 scene, so per Karpathy Principle 2 the visual result is unconfirmed. Drop it in and eyeball at the listed checkpoints. Specific watch-items:

GNOME:
1. Feet-to-ground offset. The rig is authored so soles land near root-local y≈0 with hip at y=10.6 and legs (thigh 4.2 + shin 4.0 + boot ~3.2) hanging below. At group.position.y=0 the boots should touch the ground; if it floats/sinks, nudge group.position.y by ±1-2. The walk bob (root.position.y up to +0.5) and lift/cheer (root moves ±1.4) are applied by poseGnome on the ROOT, so they won't desync placement.
2. Floppy-cap flop direction. hatSeg2..5 rotate about X (forward) and Z (sideways). From some camera angles the curl may read as "leaning" not "flopping." If so, increase the X component vs Z on seg3/seg4 so the tip aims toward camera/forward. poseGnome animates seg4/seg5 each frame — if you hand-edit their rest rotation, also update the poseGnome tail block or the two will fight.
3. 'cheer' uses upperArm.rotation.x = -2.6 to throw arms overhead. Combined with rest splay this is fine, but if you layer custom arm edits, reset rotation first to avoid compounding.
4. Mesh budget is ~66-68 by construction. Confirm once: `let n=0; group.traverse(o=>o.isMesh&&n++); console.log(n)` before instancing to ~12.
5. Materials are per-makeGnome(). 12 gnomes = 12 material sets. If draw-state churn shows in a profile, hoist the palette and pass shared materials in.

BUILD SITE:
6. All site meshes are transparent:true (for cross-fades). Transparent meshes can show minor sort artifacts at grazing angles and don't write depth normally — if z-fighting appears on a finished structure, flip fully-appeared parts back to transparent:false inside setObjOpacity once opacity===1.
7. grow:'y' scales a centered geometry about its midpoint (top and bottom both move). It reads as "rising" because opacity ramps in tandem, but it's not strictly bottom-anchored. If you want true bottom-up growth, offset each grow-y group's children up by half-height at build time.
8. Cabin roof shingle-strip rotation (the `strip.rotation.set(0, PI/2, atan2(...))`) is the single most likely spot to need a small angle tweak. Verify at p=0.72 for 'cabin'.
9. Verify both types at p = 0, 0.2, 0.45, 0.72, 1.0. Beard on the builder gnome could overlap the belt at extreme 'build'/'lift' torso bends — reduce the torso.rotation.x cap in those poses if it intersects the thighs.

ZONE:
10. makeRibbon uses simple left-normal offsetting (no miter join); acute path hairpins can pinch/self-overlap. Roads are Catmull-Rom-smoothed so it's rare; widen roadWidth cautiously, don't narrow it on a kinky path.
11. Rejection sampling can place FEWER than targetSites in a thin/tiny polygon (capped at targetSites*320 tries). Degrades gracefully (fewer houses). For slivers, lower minSpacing/edgeMargin or pass explicit siteCount.
12. ShadowMaterial needs the moon DirectionalLight's shadow frustum to ENCLOSE the zone. The prototype's moon shadow.camera is ±300 — fine for a ±200 zone, but if you draw a larger region, widen shadow.camera.{left,right,top,bottom} and far, or houses/gnomes will appear shadowless (the #1 "it looks ungrounded" cause).
13. buildZone SKIPS sites flagged type:'build' (the caller spawns makeBuildSite there). If you forget to spawn build sites, those plots are empty holes in the village — make sure the description.buildSites loop runs.

INTEGRATION:
14. The four modules must be pasted INSIDE buildVillage() to see the closure `mat`. If pasted outside the IIFE, they silently use their own materials — visually close but a slightly different palette. Decide deliberately.
15. dt in the animate loop: the prototype uses clock.getElapsedTime() only. To advance build progress smoothly you need a delta — either add `clock.getDelta()` (but note getElapsedTime and getDelta share the same internal clock and getDelta resets it, so call getDelta ONCE per frame and derive t from a running accumulator, or track lastT yourself). Mixing both naively will make `t` jump. Simplest safe fix: keep one `let prevT=0;` accumulate dt = t - prevT; prevT = t; using getElapsedTime only.
16. Re-anchoring the cabin-smoke sprite array to a finished build site's smokeAnchor (integrationMap step 3) moves ALL 7 smoke sprites to one chimney. If you have multiple finishing sites, give each its own smoke array or the smoke teleports between chimneys.