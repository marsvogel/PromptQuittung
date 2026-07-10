<p align="center">
  <img src="PromptQuittung/AppIcon.icon/Assets/icon.png" alt="PromptQuittung app icon" width="128">
</p>

# PromptQuittung

[![Build](https://github.com/marsvogel/PromptQuittung/actions/workflows/build.yml/badge.svg)](https://github.com/marsvogel/PromptQuittung/actions/workflows/build.yml)
[![Latest release](https://img.shields.io/github/v/release/marsvogel/PromptQuittung)](https://github.com/marsvogel/PromptQuittung/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/marsvogel/PromptQuittung)
[![Built with Claude Code](https://img.shields.io/badge/Built_with-Claude_Code-D97757?logo=claude&logoColor=fff)](./AI_DISCLOSURE.md)

A macOS menu bar app that sends a notification whenever a new usage event appears in your [Cursor](https://cursor.com) usage overview — showing price, model, and token count, like a receipt for every AI prompt.

To authenticate, it reads the session of the locally installed Cursor IDE. No setup, no password, no API key.

## Requirements

- macOS 15 or newer
- A locally installed, logged-in [Cursor](https://cursor.com) IDE

## Try it

Download the app from the [latest release](../../releases/latest), unzip it, and move `PromptQuittung.app` to *Applications*.

The app is only ad-hoc signed (not notarized), so Gatekeeper blocks the first launch. To open it anyway, either:

- Right-click the app in Finder, choose *Open*, then confirm — or, if macOS only offers *Move to Trash*, go to *System Settings → Privacy & Security*, scroll down, and click *Open Anyway*; or
- remove the quarantine flag in Terminal:

  ```sh
  xattr -d com.apple.quarantine /Applications/PromptQuittung.app
  ```

If you prefer not to run an unsigned binary, you can [build it from source](#building-from-source) in a few seconds.

## Usage

After launch, an owl icon appears in the menu bar — there is no Dock icon and no window. On first launch, macOS asks for permission to show notifications; without it the app cannot do its job (the menu bar menu will point this out and link to System Settings).

The app then polls your Cursor usage events and posts a notification for every new one, e.g. **“$0.42 · claude-4.5-sonnet”** with the total token count as the message body. On the very first run, existing events are only recorded, not notified — you only hear about new activity.

## How it works & privacy

- The app reads the Cursor session token **read-only** from Cursor's local `state.vscdb` (SQLite) — the same session your IDE is already logged in with. It never modifies Cursor's data.
- The token is sent **exclusively to `cursor.com`** to fetch your own usage events. No other server is contacted, ever.
- The token is never logged and never written anywhere else.
- There is no analytics, no tracking, no third-party code — the app has zero external dependencies, and the whole source is about 400 lines of Swift you can read in minutes.

## Building from source

Requires a recent Xcode:

```sh
xcodebuild -project PromptQuittung.xcodeproj -target PromptQuittung -configuration Release build
```

The app lands in `build/Release/PromptQuittung.app`. Run tests with:

```sh
xcodebuild test -project PromptQuittung.xcodeproj -scheme PromptQuittung
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security issues: see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
