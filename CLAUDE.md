# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AirSync macOS is a native SwiftUI menu bar app that syncs notifications, media controls, clipboard, and files between Android devices and macOS over WebSocket. It uses AES-256-GCM encryption, UDP device discovery, and a custom binary protocol documented in `DOCUMENTATION.md`.

## Build Commands

```bash
# Debug build (used in CI)
xcodebuild -scheme airsync-mac -configuration Debug clean build

# Release build
xcodebuild -scheme airsync-mac -configuration Release clean build

# Local development: use "AirSync Self Compiled" scheme in Xcode
# Product → Archive → Distribute → Custom → Copy App
```

The `SELF_COMPILED` compilation condition (set in `airsync-mac/Configs/SelfCompiled.xcconfig`) distinguishes local builds from distributed binaries — it affects trial/licensing and update behavior.

There are no test targets or linting tools configured.

## Architecture

**Singleton-based MVVM** with reactive SwiftUI bindings:

- **`AppState`** (`Core/AppState.swift`): Central observable singleton. All UI state flows through `@Published` properties — device connection, notifications, media info, settings, app list.
- **`WebSocketServer`** (`Core/WebSocket/`): Split across 6 files by responsibility (handlers, outgoing, networking, models, ping). Manages sessions, encryption, and the chunked file transfer protocol.
- **`UDPDiscoveryManager`** (`Core/Discovery/`): UDP broadcast/listen on port 8889 for device discovery. Triggers on system wake and network changes.
- **`MenuBarManager`** (`Core/MenuBarManager.swift`): Status bar item, popover, drag-and-drop for Quick Share.
- **`AppDelegate`** (`Core/AppDelegate.swift`): App lifecycle, Sentry setup, window management, service provider registration.

**Data flow**: UDP discovery → user selects device → WebSocket handshake → `AppState` updated → SwiftUI views react.

## Key Directories

- `Core/` — All business logic: WebSocket, discovery, storage, trial, utilities (ADB, crypto, keychain, QR)
- `Model/` — Lightweight `Codable` structs (Device, Notification, Message, AndroidApp, etc.)
- `Screens/` — SwiftUI views organized by feature (Home, Settings, Onboarding, Scanner, Menubar)
- `Components/` — Reusable UI components (buttons, containers, text, WebView)
- `Constants/` — App constants and `MacDeviceMappings.json`
- `Localization/` — 35+ language JSON files (Crowdin-managed)

## Protocol & Dependencies

The WebSocket protocol (message types, encryption, file transfer with sliding window ACKs) is fully documented in `DOCUMENTATION.md` at the repo root.

**SPM dependencies** (managed via Xcode project, no Package.swift):
- `httpswift/swifter` — WebSocket/HTTP server
- `dagronf/QRCode` — QR generation/scanning
- `sparkle-project/Sparkle` — Auto-updates
- `ungive/media-control` — macOS media control
- `tfmart/LottieUI` — Lottie animations

## Contributing

- PRs target `main` or `dev` branch
- Adding app icons: add assets to `Assets.xcassets/AppIcons/`, define in `AppIconExtensions.swift`, register in `allIcons` array
- License: MPL 2.0 with non-commercial clause
