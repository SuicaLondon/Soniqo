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

## Roadmap

- Improve playback-window detection across browsers and media apps.
- Add explicit screen-to-output mapping controls.
- Add priority rules for multiple playback windows.
- Research true per-window audio routing for simultaneous multi-monitor playback.
