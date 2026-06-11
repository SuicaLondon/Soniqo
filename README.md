# Soniqo

Soniqo is a macOS menu bar app for screen-aware audio routing.

Final goal: a window should sound from the monitor it is on.

For example, a YouTube window on a Dell monitor should play through the Dell speakers; the same window dragged back to the MacBook display should play through the MacBook speakers.

This creates a more spatial, screen-local listening experience for multi-monitor setups, especially when external displays, TVs, or Studio Displays also provide audio output.

Chinese documentation: [繁體中文](docs/README.zh-TW.md) / [简体中文](docs/README.zh-CN.md)

## Current Support

- Menu bar app.
- Automatic output switching.
- Playback window tracking.

## Build

Open `Soniqo.xcodeproj` in Xcode and run the `Soniqo` scheme.

For a local unsigned build:

```sh
xcodebuild -project Soniqo.xcodeproj -scheme Soniqo -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

## Packaging

This repository includes a GitHub Actions workflow for contributors or fork maintainers who want to build their own downloadable app bundle.

To build from a fork or development branch, run the `Build and Release` workflow manually from GitHub Actions. To attach packaged files to a GitHub Release in your own fork, push a version tag:

```sh
git tag v1.0.0
git push origin v1.0.0
```

The workflow builds a universal macOS app (`arm64` and `x86_64`), sets the app version from the tag (`v1.0.0` becomes `1.0.0`), uses the GitHub Actions run number as the build number, ad-hoc signs the app, and packages:

- `Soniqo-1.0.0.dmg`
- `Soniqo-1.0.0-macOS-universal.zip`

These self-built packages are not Apple-notarized. When testing a local or fork build, macOS may require right-clicking the app and choosing Open the first time, or removing quarantine after download:

```sh
xattr -dr com.apple.quarantine /Applications/Soniqo.app
```

## Roadmap

- Improve playback-window detection across browsers and media apps.
- Add explicit screen-to-output mapping controls.
- Add priority rules for multiple playback windows.
- Research true per-window audio routing for simultaneous multi-monitor playback.
