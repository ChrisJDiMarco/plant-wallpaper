# Plant Wallpaper Selling Checklist

This app should ship as a generous free desktop garden with a Pro upgrade for worldbuilding, premium modes, and hosted AI credits.

## Recommended Product Split

Free:
- Garden mode, starter scenes, manual planting, watering, harvesting, seeds, Cozy Mode, environmental sounds, cat companion, basic radio companions.
- Optional AI generation with the user's own OpenAI API key.

Pro:
- Room Studio and Alien/UFO Garden modes.
- Gnome societies, bird sky areas, progression mode, AI Lock View, focus growth sessions, time-lapse export, Jarvis command center, Miso voice mode, premium companion packs, premium scene packs.
- Hosted AI credits and optional credit packs for 4K or high-volume generation.

Suggested pricing:
- Free: $0.
- Pro: $8/month or $60/year.
- Credit packs later: small prepaid bundles for hosted AI image generation.

## Two Payment Tracks

Mac App Store:
- Use StoreKit / In-App Purchase for Pro subscriptions and digital unlocks.
- Do not put Stripe checkout buttons or external purchase calls to action in the App Store build.
- Use App Store Connect for products, subscriptions, screenshots, support URL, privacy labels, and review notes.

Direct download from your site:
- Use Stripe Checkout for subscription signup and Stripe Customer Portal for billing management.
- The app should validate an app license/subscription with your server. Do not put Stripe secret keys in the macOS app.
- Use Developer ID signing, hardened runtime, notarization, and stapling before distributing the DMG.

## App Build & Installer

Use:

```bash
Scripts/package_release.sh
```

The script builds the app, stages the app and screen saver, creates an install README, and creates a DMG under `.build/dist/`.

For a public direct-download build, configure these before packaging:

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export NOTARYTOOL_PROFILE="PlantWallpaperNotary"
export PLANT_WALLPAPER_DISTRIBUTION_CHANNEL="direct-download"
export PLANT_WALLPAPER_PAID_VALIDATION_PROVIDER="stripe"
Scripts/package_release.sh
```

Create the notary profile once with `xcrun notarytool store-credentials`.
The package script also writes `.build/dist/release-readiness-<version>.json` so you can confirm the channel, paid-validation provider, signing, and notarization state for the exact DMG you are about to upload.

## Production Readiness Rules

The app now treats storefronts as different build channels:

- Direct download builds should use `PLANT_WALLPAPER_DISTRIBUTION_CHANNEL=direct-download` and `PLANT_WALLPAPER_PAID_VALIDATION_PROVIDER=stripe` or `custom-license`.
- Mac App Store builds should use `PLANT_WALLPAPER_DISTRIBUTION_CHANNEL=mac-app-store`, StoreKit/In-App Purchase validation, and App Sandbox entitlements.
- Stripe checkout or external purchase CTAs should not ship inside the Mac App Store build.
- A build with development-unlocked Pro features, no paid validation provider, a StoreKit direct-download provider, or a non-sandboxed App Store channel should be treated as not ready to sell.

Direct download is the practical first launch path for this app because the screen saver integration, desktop event monitoring, AI keys, and rich local file behavior all need careful App Store review strategy. Treat the Mac App Store as a separate later package, not the same DMG with a different upload target.

## Permissions & First-Run UX

Explain these before the user hits macOS prompts:
- Input Monitoring: needed for desktop clicks, drags, double-click planting, and cat/cursor interactions.
- Location: only for local weather effects if enabled.
- Microphone: only when Miso voice mode is started.
- Network: radio streams, weather, OpenAI, ElevenLabs, update/license checks.
- Screen Saver: optional install into `~/Library/Screen Savers`.

macOS Desktop & Dock setup:
- Tell users to open System Settings > Desktop & Dock.
- Set "Click wallpaper to show desktop" to "Only in Stage Manager" for the cleanest Plant Wallpaper interaction model.

## Must-Have Before Charging

- Stripe customer/subscription backend or StoreKit purchase validation.
- Server-side entitlement endpoint returning signed/validated Free vs Pro status.
- In-app restore purchases / refresh license action.
- Privacy policy, terms, support email, refund policy, and uninstall instructions.
- Crash/update plan for direct downloads, such as Sparkle or a simple manual update feed.
- Release QA on a clean Mac user account, including first-run permissions, screen saver install, app relaunch, and Pro downgrade behavior.
