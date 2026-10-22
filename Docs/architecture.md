# Plant Wallpaper Architecture

## Layers

- `PlantGardenCore`: pure model, simulation, tending actions, and JSON persistence.
- `PlantWallpaper`: AppKit app, menu bar, desktop overlay windows, and procedural renderer.
- `Tests/PlantGardenCoreTests`: unit tests for growth, tending, and persistence.
- `GardenComposition`: deterministic screen-relative layout rules for intentional plant grouping.
- `WallpaperManager`: generates the calm solid background, applies it through `NSWorkspace`, and stores previous-wallpaper snapshots.
- `PlantAssetLibrary`: loads bundled transparent PNG cutouts from `Resources/PlantAssets` and maps them to species.

## Runtime

`AppDelegate` loads persisted garden state (per scene), applies the selected scene wallpaper, creates the overlay windows plus the WebKit companion layers (cat, gnomes, birds, rainbow), and runs three timers:

- Simulation (1 Hz): advances plant hydration, health, bloom and growth. Observers are only notified when `GardenStateRenderSignature` changes, not on every tick.
- Display (adaptive, `GardenDisplayCadence`): repaints ambient sway, from 0.5 s while something is animating up to several seconds when calm, and slower still on battery or in Low Power Mode.
- Autosave (20 s): writes the scene's garden JSON. The screen saver snapshot JSON is rewritten only when what it would draw has changed.

Pointer routing polls at 25 Hz only while the cursor moves or a button is held, drops to 4 Hz when idle, and stops while the displays sleep. Screen-parameter changes rebuild windows only when display geometry actually changed.

The overlay window level is `desktopWindow + 1`, so the garden reads as part of the wallpaper instead of a normal foreground app.

## Data safety

- An unreadable scene file is moved aside as `*.corrupt-<timestamp>` before a fallback garden is saved in its place.
- Plants decode element by element, so one unknown species skips that plant instead of the whole garden.
- An unreadable custom-plant manifest is preserved and never causes custom plants to be pruned.
- Custom and AI wallpapers are never evicted automatically; removal is explicit from Settings › Scene.
- Superseded AI Lock View renders go to the Trash; the newest two per scene are kept.

## Assets

Photorealistic plant cutouts live in `Sources/PlantWallpaper/Resources/PlantAssets`. Source chroma-key copies live under `Docs/generated-asset-sources` for traceability but are not bundled into the app.

## Interaction

`GardenCanvasView` overrides `hitTest` so only plants and the inspector receive mouse events. Empty transparent regions fall through to the desktop. Plants are draggable, double-click watering is supported, and the menu bar performs app-level commands.
