# Plant Wallpaper Architecture

## Layers

- `PlantGardenCore`: pure model, simulation, tending actions, and JSON persistence.
- `PlantWallpaper`: AppKit app, menu bar, desktop overlay windows, and procedural renderer.
- `Tests/PlantGardenCoreTests`: unit tests for growth, tending, and persistence.
- `GardenComposition`: deterministic screen-relative layout rules for intentional plant grouping.
- `WallpaperManager`: generates the calm solid background, applies it through `NSWorkspace`, and stores previous-wallpaper snapshots.
- `PlantAssetLibrary`: loads bundled transparent PNG cutouts from `Resources/PlantAssets` and maps them to species.

## Runtime

`AppDelegate` loads persisted garden state, upgrades old gardens to the current composition version, applies the calm desktop background, creates one borderless transparent `GardenWindow` per screen, and starts three timers:

- Simulation: advances plant hydration, health, bloom, and growth once per second.
- Display: redraws the overlay at 30 FPS for smooth wind sway.
- Autosave: writes state every 20 seconds.

The overlay window level is `desktopWindow + 1`, so the garden reads as part of the wallpaper instead of a normal foreground app.

## Assets

Photorealistic plant cutouts live in `Sources/PlantWallpaper/Resources/PlantAssets`. Source chroma-key copies live under `Docs/generated-asset-sources` for traceability but are not bundled into the app.

## Interaction

`GardenCanvasView` overrides `hitTest` so only plants and the inspector receive mouse events. Empty transparent regions fall through to the desktop. Plants are draggable, double-click watering is supported, and the menu bar performs app-level commands.
