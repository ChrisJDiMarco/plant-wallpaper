# Plant Wallpaper

A native macOS menu-bar app that grows an interactive PNG-backed garden over the desktop wallpaper.

## What It Does

- Draws transparent, desktop-level garden windows on every connected display.
- Keeps the desktop usable with pass-through hit testing outside plants and controls.
- Grows the currently available source-backed PNG plant species, including ferns, moss, clover, creeping thyme, ivy, lavender, and bonsai.
- Applies selectable empty garden wallpaper scenes so the plants remain visible.
- Backs up the previous wallpaper and can restore it from the menu bar.
- Arranges plants into designed garden beds instead of scattering them randomly.
- Uses bundled transparent PNG plant assets generated as hyper-realistic 3D botanical cutouts.
- Persists garden state in Application Support.
- Lets you water, plant, prune, remove, drag, pause, reset, and inspect plants from the menu bar.
- Animates wind sway and gradual growth over real elapsed time.
- Installs a matching macOS screen saver that can mirror the last desktop garden scene or use its own selected scene.
- Offers a System Settings-style settings window with live-updating panes for simulation, scenes, wildlife, audio, assets, and maintenance.
- Can launch automatically at login and delete custom or AI-generated scenes (including their saved plant data) from the Scene pane.

## Controls

- Menu bar leaf: full app controls.
- Click a plant: select and inspect.
- Double-click a plant: water it.
- Drag a plant: move it on the desktop.
- Menu bar `Arrange Garden`: recompose the current plants into cleaner beds.
- Menu bar `Restore Previous Wallpaper`: put your prior desktop wallpaper back.
- Menu bar `Settings...` (or launching with `--open-settings`): open the settings window. Escape closes it.

## Build

```bash
swift test
Scripts/build_app.sh
open ".build/app/Plant Wallpaper.app"
```

## Screen Saver

Build and install the screen saver:

```bash
Scripts/build_screensaver.sh --install
```

Then open System Settings, go to Screen Saver, and choose `Plant Wallpaper`.
Use its Options sheet to keep `Follow Desktop Garden` or pick a specific saved scene.

## Data

Garden state is stored at:

```text
~/Library/Application Support/WallpaperGarden/PlantWallpaper/garden.json
```

Wallpaper assets and the previous-wallpaper backup are stored at:

```text
~/Library/Application Support/WallpaperGarden/PlantWallpaper/Wallpaper/
```
