# Buckit

The things you reach for constantly — always within reach, whatever you're doing on your Mac.

Buckit is a tiny floating panel you summon with **⌥ Space**. Each **Space** (Job Search, School, Development, …) holds the files and links you keep reaching for. The panel stays open while you work in Finder, so you can drag files in and out. Press **Esc** to close it.

Search is tucked beside the Space name. Click the magnifying glass or start typing to find a resource, then press Return to open it.

## Run it

Requires macOS 14+ and Xcode 15+ (or the Swift command line tools).

```sh
make run        # debug build, runs from the terminal
make open       # builds build/Buckit.app and opens it
make install    # copies Buckit.app into /Applications
```

Buckit lives in the menu bar (no Dock icon). Open **Settings…** from the menu bar item (or ⌘,) to turn on Launch at Login, colour your Spaces, and rebind shortcuts.

## Using it

| | |
|---|---|
| **⌥ Space** | Show / hide Buckit |
| Click 🔍 or type | Search resources in the current Space |
| **↑ ↓**, **↩** | Pick a result, open it |
| **⌘ ↩** | Copy the selected result |
| **⌘1 … ⌘9** | Jump to a Space |
| **⌃ Tab** / **⌃⇧ Tab** | Next / previous Space |
| Two‑finger swipe | Slide between Spaces |
| **Esc** | Clear search → collapse search → close |

⌥Space, Open, Copy and Show in Finder are rebindable in **Settings → Shortcuts**; the rest are fixed.

- **Hover** a row for its quick action — *Copy* for links, *Open* for files. Click a row to open it; drag a file row out into any app.
- **Drop** files or links anywhere on the panel to add them to the current Space. The panel stays visible while you switch to Finder.
- Files added to a Space receive its same-named Finder tag. Files given that tag in Finder appear in the Space automatically. Removing a Finder-sourced file from Buckit removes that tag from the file; other tags stay intact.
- **Paste a link** into search and press ↩ to add it, or use **+ Add**.
- **Add** suggests the active tab from the last focused Safari, Chrome, or Arc browser window; press ↩ to save it. macOS may request browser Automation access the first time. If the tab URL is unavailable, Buckit suggests a link from the clipboard.
- **Right‑click** a row to edit, move it to another Space, or remove it.
- Click the **Space name** to switch, create (**+ New Space**), rename, or delete Spaces.

## Settings

A normal window, opened from the menu bar or **⌘,**. It follows your system appearance rather than the panel's dark HUD.

- **General** — adjust the blurred panel background's opacity, set Launch at Login, and find your Spaces file.
- **Spaces** — choose each Space's color and color intensity with a live preview, rename, reorder (the order sets ⌘1 … ⌘9), add and delete.
- **Shortcuts** — click a shortcut, press the keys you want. Escape backs out; the global one needs at least one modifier. Conflicts are called out rather than blocked.

Settings live in `UserDefaults`, separate from your Spaces.

Data is saved automatically to `~/Library/Application Support/Buckit/buckit.json`.

## Release for your website

The ordinary `make app` build is ad hoc signed for local use. `make dmg-preview` uses [create-dmg](https://github.com/sindresorhus/create-dmg) to make a polished, unsigned test DMG. Node.js 20 or newer is required. A public download should be signed with a **Developer ID Application** certificate and notarized by Apple. `make release` uses create-dmg, staples the notarization ticket, and produces a signed DMG in `build/release/`.

1. Join the Apple Developer Program and create a Developer ID Application certificate in your keychain.
2. Save notarization credentials once with `xcrun notarytool store-credentials buckit-notary --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID`. It prompts for an app-specific password.
3. Run `CODE_SIGN_IDENTITY='Developer ID Application: YOUR NAME (TEAM_ID)' NOTARY_PROFILE=buckit-notary make release`.
4. Test the DMG on another Mac, then upload it to your website and link to it from a Download button.

The current build targets macOS 14 or newer and contains only an Apple Silicon (`arm64`) binary. An Intel release requires an additional `x86_64` build. Update the version and build number in `scripts/build-app.sh` before each release.

## Layout

```
Sources/Buckit/
  BuckitApp.swift        app entry, menu bar item
  HotKey.swift           global ⌥Space via Carbon (no Accessibility permission needed)
  PanelController.swift  floating NSPanel, show/hide, keyboard + swipe handling
  Model.swift            Space / Resource; legacy to-do and note decoding
  SpaceColor.swift       the Space palette
  Shortcuts.swift        rebindable key combinations + Prefs
  Store.swift            state, search, persistence
  Views/                 SwiftUI views (panel + settings window)
```
