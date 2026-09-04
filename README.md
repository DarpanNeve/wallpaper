# LiveSpace

Live video wallpaper for macOS. Plays a rotating playlist of your own local videos as the desktop background, with best-effort lock-screen sync.

## Install

1. Download the latest `LiveSpace-*.dmg` from [Releases](https://github.com/DarpanNeve/wallpaper/releases/latest).
2. Open the dmg, drag **LiveSpace** into **Applications**.
3. Launch LiveSpace from Applications (or Spotlight). The app is notarized by Apple — it opens normally, no right-click/"unidentified developer" workaround needed.
4. Click the menu bar icon (sparkles) → **Open Settings** → point it at a folder of videos.

**Requirements:** macOS 14.0 or later.

## Features

- Rotates a playlist of local videos as your desktop background, per-monitor or shared across displays
- Order modes: In Order, Reverse, Shuffle, Pinned; switch on a timer or when each video ends
- Fill styles and per-display overrides (folder, pattern, order) via the Displays settings tab
- Optional break reminders (mini/long breaks) with a countdown overlay
- Experimental lock-screen video sync (requires you've already downloaded ≥1 Apple Aerial wallpaper in System Settings)
- Launch at login, menu bar quick actions (next video, jump to video)

## Uninstall

Quit LiveSpace, then drag `LiveSpace.app` from Applications to the Trash. Settings/config live at `~/Library/Application Support/LiveSpace/` if you want to remove those too.

## Building from source

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) and Xcode.

```bash
brew install xcodegen
cp Config/Signing.xcconfig.example Config/Signing.xcconfig
# edit Config/Signing.xcconfig with your own Apple Developer Team ID
xcodegen generate
xcodebuild -project LiveSpace.xcodeproj -scheme LiveSpace -configuration Debug build
```

See [docs/LLM_CONTEXT.md](docs/LLM_CONTEXT.md) for architecture notes and implementation details.
