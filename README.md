# Soniqo

Soniqo is a macOS menu bar app that keeps system audio aligned with the screen containing the active playback window.

Move a YouTube, music, or video window to another monitor and Soniqo can switch the macOS default output to the audio device mapped to that monitor. The menu also shows every currently available display, its mapped output, routing state, and current volume when Core Audio exposes it.

Documentation: **English** / [繁體中文](docs/README.zh-TW.md) / [简体中文](docs/README.zh-CN.md)

## Features

- Lists every display currently available to macOS, including the built-in display.
- Maps each monitor to a Core Audio output device.
- Automatically follows an audible window as it moves between screens.
- Shows the current system output and each mapped output's live volume.
- Provides a draggable volume slider when the device supports software volume control.
- Provides one-click manual output switching for each configured monitor.
- Keeps volume controls available in Auto mode while locking manual output switching.
- Distinguishes disconnected, unavailable, unconfigured, unknown, and device-controlled audio states.
- Expands the menu to fit its content and scrolls only when it would exceed the current screen.

## Requirements

- macOS 14.2 or later.
- At least one Core Audio output device.
- A monitor must be mapped to an output before Soniqo can route audio to it.

## Usage

1. Open Soniqo from the menu bar.
2. Use the gear button on a monitor card to choose its audio output.
3. Turn on **Auto** to let the active audible window control the system output.
4. Turn off **Auto** to use a monitor card's play button for immediate manual switching.
5. Drag a monitor card's volume slider to change that output's volume. Volume remains adjustable while Auto is enabled.

The **SYSTEM** badge identifies the output currently used by macOS. The **ACTIVE** badge identifies the screen containing the playback window Soniqo is following.

## Audio and Routing Limitations

Soniqo changes the macOS system-wide default output; it does not route different applications to different outputs simultaneously.

Not every audio device exposes a writable software-volume property. HDMI, DisplayPort, TVs, receivers, and some displays often require volume adjustment on the hardware itself. Soniqo reports these devices as **Device Controlled** instead of showing a nonfunctional slider. The displayed Core Audio percentage may also differ from a display or receiver's physical on-screen volume.

macOS does not provide a universal display-to-audio-device association. Soniqo uses saved mappings and conservative name/built-in-device matching; ambiguous monitors remain unconfigured so the app does not claim an incorrect connection. Use the gear button to correct or complete a mapping.

Playback-window detection depends on the audio processes and visible windows macOS reports. Browser helper processes, hidden windows, protected content, and applications with unusual process models may not always match immediately.

## Build

Open `Soniqo.xcodeproj` in Xcode and run the `Soniqo` scheme.

For a local unsigned build:

```sh
xcodebuild \
  -project Soniqo.xcodeproj \
  -scheme Soniqo \
  -configuration Debug \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The project has no external package dependencies. The app is a menu-bar-only app and does not show a Dock icon or a conventional main window.

## Packaging

This repository includes a GitHub Actions workflow that builds downloadable app bundles. Branches, pull requests, and manual runs produce ad-hoc-signed development artifacts. Version tags in the official repository produce Developer ID-signed and Apple-notarized releases.

To build from a fork or development branch, run the `Build and Release` workflow manually from GitHub Actions. To attach packaged files to a GitHub Release in your own fork, push a version tag:

```sh
git tag v1.0.0
git push origin v1.0.0
```

The workflow builds a universal macOS app (`arm64` and `x86_64`), sets the app version from the tag (`v1.0.0` becomes `1.0.0`), uses the GitHub Actions run number as the build number, and packages:

- `Soniqo-1.0.0.dmg`
- `Soniqo-1.0.0-macOS-universal.zip`
- `SHA256SUMS`

Official tagged releases are signed with a Developer ID Application certificate, submitted to Apple's notary service, stapled, and checked with Gatekeeper before publication. The release workflow requires these repository secrets:

```text
MACOS_CERTIFICATE
MACOS_CERTIFICATE_PASSWORD
APPLE_ID
APPLE_APP_SPECIFIC_PASSWORD
APPLE_TEAM_ID
```

Development artifacts produced without release credentials remain ad-hoc signed and are not intended for end-user distribution.

## Roadmap

- Improve playback-window detection across browsers and media apps.
- Add priority rules for multiple playback windows.
- React to Core Audio device, default-output, volume, and mute changes through property listeners.
- Research true per-window audio routing for simultaneous multi-monitor playback.
