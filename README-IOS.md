# Warfare HD for iPhone

An unofficial modern iPhone build of Spiffcode's original open-source **Hostile Takeover / Warfare Incorporated** engine. The original BSD license and game data are retained. This project is not an official Spiffcode release.

## What this build changes

- An arm64 iPhone executable, built by Xcode on GitHub Actions.
- Retina display output using the device's actual display scale.
- Optional edge-aware 2x enhancement of the original artwork, plus classic and smooth modes.
- Landscape presentation and matching touch mapping inside the screen's safe areas.
- Full original bundled game and audio databases, with local saved games.
- A three-finger tap opens display settings.

The enhancement reconstructs edges from the original pixels. It does **not** replace every sprite with newly painted high-resolution artwork. Simulation rules, AI, maps, mission scripts and unit statistics come from the original source.

## Build status and scope

Always use a release that passes both packaging and visual simulator startup checks. An executable that compiles is not sufficient evidence of a playable game.

The open-source snapshot predates the restored 2026 website. Its native multiplayer configuration contains unconfigured server placeholders; native online play is not verified or configured by this fork. It is not a 100% reproduction of the current hosted service. Full campaign completion, device performance and iPhone 18 Pro Max hardware compatibility require physical-device testing.

## Install with AltStore Classic

1. Download `Warfare-Incorporated-iOS.ipa` from this repository's Releases page on your iPhone. If using an Actions artifact, extract the outer ZIP once. **Do not unzip the IPA.**
2. Run AltServer on Windows and connect the unlocked iPhone. Trust the computer when iOS asks.
3. Open AltStore Classic on the iPhone. In **My Apps**, tap **+**, then select the IPA in Files.
4. Complete Apple account/signing prompts yourself. AltStore signs the unsigned build for your device.
5. Launch **Warfare HD**. Use landscape orientation. Three-finger tap for graphics settings.

AltStore's signing and refresh requirements depend on your Apple account. See the [official Windows setup guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows).

## Reproduce the build

The workflow `.github/workflows/ios.yml` builds the existing `game/wi.xcodeproj` target `wi`, configuration `Distribution`, for `iphoneos/arm64`, without signing. No Apple password or signing certificate is stored in GitHub.

`scripts/validate_ipa.py` checks the Payload layout, Mach-O architecture, device platform and bundled game/audio databases. `tests/hdscale_test.cpp` checks edge reconstruction and boundary handling with address and undefined-behavior sanitizers. `scripts/simulator_smoke.sh` builds and launches on an available Pro Max simulator, captures diagnostics and rejects a black startup screenshot.

Original engine documentation: [README.md](README.md). License: [LICENSE.txt](LICENSE.txt).
