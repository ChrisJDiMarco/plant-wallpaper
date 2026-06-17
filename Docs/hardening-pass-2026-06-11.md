# RD: WallpaperGarden Hardening And Improvement Pass

**Created**: 2026-06-11
**Created by**: JARVIS Orchestrator
**Assigned to**: builder
**Priority**: high
**Due**: ASAP

## 1. What Needs to Be Done

Audit the latest WallpaperGarden delight-layer update, harden the risky lifecycle and persistence paths, then implement the highest-value improvements already identified: quieter audio defaults, per-layer ambience controls, replayable onboarding, weather privacy copy, health-check export, and targeted file-size relief.

## 2. Context

- **Business context**: Shipped-app portfolio; WallpaperGarden is a proof-of-craft app.
- **Background**: A prior Claude pass added ambience, welcome tour, dashboard, harvest/seeds, focus sessions, rare moments, weather/rainbow, diary, and time-lapse.
- **Baseline**: `swift test` passed 288 tests before edits.

## 3. Scope

### In Scope
- Verify build/test state before and after changes.
- Add focused regression tests for audio defaults/layers, persistence, notification memory, time-lapse metadata, and health-check output.
- Implement the named improvements without adding external services.
- Keep existing app behavior intact unless the hardening item intentionally changes it.

### Out of Scope
- New gameplay systems beyond the existing seed/harvest/focus loop.
- Real sampled ambience assets.
- Store/release packaging.

## 4. Skills Required

- `tdd-workflow`
- `verification-loop`
- `coding-standards`

## 5. Completion Criteria

- [x] Tests cover the highest-risk double-check items.
- [x] Audio is opt-in and layer-controllable.
- [x] Weather copy explains approximate-location usage.
- [x] Welcome tour can be replayed.
- [x] Health-check export is available from the app.
- [x] Full test suite and build script pass, or any remaining blocker is explicit.
