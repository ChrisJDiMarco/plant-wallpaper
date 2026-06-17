DECISIONS AND TRADEOFFS:

1. BASE = Approach C, GRAFT B's clothing/cap + A's pose hygiene. C has the cleanest, most provably-correct rig (joints-at-pivots, pre-translated limb geometry, a live mesh counter under the 70 cap, hand-parented hammer). B's silhouette is the richest (5-segment animatable floppy cap, stacked tunic-hem folds, sleeve/cuff layering). A contributed the per-frame channel-reset discipline and breathing so actions never bleed and idle is never a T-pose. Every parts.* name poseGnome reads is guaranteed to exist in makeGnome — I cross-checked the full list.

2. INTERNAL CONSISTENCY VERIFIED BY READING, NOT ASSUMING. I read the real prototype (prototypes/gnome-v1/index.html, 449 lines) before writing the integration. Key ground-truths that shaped the answer:
   - `mat()` is a CLOSURE-LOCAL inside buildVillage(), not a true global. So all four modules must be pasted INSIDE that closure to pick it up; otherwise they fall back to their own MeshStandardMaterial. I documented this precisely rather than guessing "it's global."
   - The prototype's existing `box/cyl/cone/sph` helpers have DIFFERENT signatures than the candidate code's local helpers. makeBuildSite/buildZone declare their own locals that harmlessly shadow them; makeGnome uses uniquely-named add/grp/limbSeg. No renames needed — but I flagged it so the integrator isn't surprised.
   - Scale reality: the live prototype uses ~46u cabins at ±200 world coords and scales its cone-gnome to 0.85 (~17u). The brief's "26u gnome / 22-28u walls" matches the candidate code's INTERNAL scale, not the prototype's. So the new zone fills the same ±200 canvas but with correctly-relative buildings (houseScale 14), and the gnomes must NOT be re-scaled to 0.85.

3. CONVENTION RECONCILIATION. All modules use Y-up, XZ ground, faces +Z, and the SAME facing formula `atan2(T.x-P.x, T.z-P.z)` — which already matches the prototype's walker heading. So site.rotation, build-site placement, gnome lookAt, and walker heading are all coherent.

4. TRANSPARENT-OVERLAY vs PROTOTYPE. The shipped product is a transparent desktop overlay, so the opaque grass ground must die and be replaced by an invisible ShadowMaterial contact plane. But killing scene.background in the BROWSER prototype would make everything invisible against the page — so I kept makeSky()/fog for the prototype and documented the alpha-renderer switch as the ship step. This is the one place the prototype and product legitimately diverge.

5. LANTERN POINT-LIGHT BUDGET. Many lantern props each adding a real PointLight tanks FPS under PCFSoft shadows. makeProp takes an optional `lanternBudget = {n}` counter; the first N lanterns get real lights, the rest are emissive-only glow spheres. Caller controls the cap.

6. PER-FRAME COST / MATERIAL CLONING. makeBuildSite clones materials per part (so opacity cross-fades don't bleed) — fine for a handful of sites; flagged for scale-up. setProgress is O(parts)≈55 and idempotent/stateless so scrubbing works.

NOT VERIFIED (honesty per Karpathy Principle 2): I could not run this in a live r128 scene from here. The algorithm primitives in the zone code (point-in-polygon, centroid, snap, Poisson sampling) were validated in Node by the original Approach-C author; the gnome/build-site visuals are construction-correct but UNVERIFIED visually — see openRisks for the specific things to eyeball.