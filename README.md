# Buckit

The things you reach for constantly — always within reach, whatever you're doing on your Mac.

Buckit is a tiny floating panel you summon with **⌥ Space**. Each **Space** (Job Search, School, Development, …) holds the files and links you keep reaching for, a few quick to‑dos, and a scratch note. Press **Esc** and it's gone.

## Run it

Requires macOS 14+ and Xcode 15+ (or the Swift command line tools).

```sh
make run        # debug build, runs from the terminal
make open       # builds build/Buckit.app and opens it
make install    # copies Buckit.app into /Applications
```

Buckit lives in the menu bar (no Dock icon). Turn on **Launch at Login** from the menu bar item once it's installed as an app.

## Using it

| | |
|---|---|
| **⌥ Space** | Show / hide Buckit |
| Type | Search resources in the current Space |
| **↑ ↓**, **↩** | Pick a result, open it |
| **⌘ ↩** | Copy the selected result |
| **⌘1 … ⌘9** | Jump to a Space |
| **⌃ Tab** / **⌃⇧ Tab** | Next / previous Space |
| Two‑finger swipe | Slide between Spaces |
| **Esc** | Clear search → close |

- **Hover** a row for its quick action — *Copy* for links, *Open* for files. Click a row to open it; drag a file row out into any app.
- **Drop** files or links anywhere on the panel to add them to the current Space.
- **Paste a link** into search and press ↩ to add it, or use **+ Add**.
- **Right‑click** a row to edit, move it to another Space, or remove it.
- Click the **Space name** to switch, create (**+ New Space**), rename, or delete Spaces.

Data is saved automatically to `~/Library/Application Support/Buckit/buckit.json`.

## Layout

```
Sources/Buckit/
  BuckitApp.swift        app entry, menu bar item
  HotKey.swift           global ⌥Space via Carbon (no Accessibility permission needed)
  PanelController.swift  floating NSPanel, show/hide, keyboard + swipe handling
  Model.swift            Space / Resource / Todo
  Store.swift            state, search, persistence
  Views/                 SwiftUI views
```
