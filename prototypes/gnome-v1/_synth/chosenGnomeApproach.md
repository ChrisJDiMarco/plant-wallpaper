Approach C (rig/animation-first) as the BASE, with grafts from B and A.

WHY C IS THE BASE:
- Cleanest, most correct rig. Each joint is a THREE.Group placed AT its pivot, and every limb's CylinderGeometry is pre-translated with `geo.translate(0,-len/2,0)` so the segment's TOP sits at the joint origin. This is the single load-bearing trick that makes bends pivot at the joint instead of through a tube's middle — A and B do the same in spirit, but C is the most consistent about it and is the only one that also pre-translates boot/thumb sub-meshes.
- Live `meshCount` instrumentation and an explicit budget (≤70) — the only approach that can prove it stays under the cap rather than estimating.
- Role prop (hammer) parented to the right hand so it follows the build swing — concrete and correct.
- poseGnome uses a `rot(joint,x,y,z)` helper writing ABSOLUTE rotations, with clean per-frame state, knee/elbow bends clamped forward-only (Math.max(0,...)) to prevent hyperextension. Best-structured action set.

GRAFTED FROM B (richest silhouette):
- The 5-segment nested floppy felt-cap chain (brim → base bell → seg2..seg5 with progressive rotation + a felt pom), exposed as parts.hat = {root,seg2..seg5} so poseGnome adds secondary lag motion. C's hat was static stacked cones; B's chained groups actually flop and can be animated. This is the biggest visual upgrade.
- Layered clothing reads: shirt collar peek, jerkin yoke seam, stacked tunic-hem fold rings, front placket, shirt cuffs peeking past tunic sleeves, mitten hand + thumb. Merged onto C's torso/arm joints.
- Multi-lobe swept mustache + the layered beard masses.

GRAFTED FROM A (proportions + pose discipline):
- The per-frame "reset all transient channels to a clean _rest base" discipline at the top of poseGnome — A was the most explicit that this prevents pose bleed-through when actions change. Implemented via the rot() resets + a stored parts._rest.
- The breathing channel added to every action (Math.sin(t*1.6)) and the resting arm splay (z = ±0.18) baked into _rest so idle is never a T-pose.
- Stocky ~3.6-3.75-heads proportions reconciled to ~26u so it matches the build-site (~24u) and zone houses.

NET RESULT: C's rig correctness + instrumentation, B's storybook clothing/cap/beard, A's animation hygiene — one internally consistent figure where every parts.* name poseGnome touches (root, pelvis, torso/spine, neck, head, chest, nose, hat{root,seg2..seg5}, hammer, left/right UpperArm/ForeArm/Hand, left/right Thigh/Shin/Foot, _rest) is created by makeGnome.