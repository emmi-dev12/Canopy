# Canopy

**Your menubar, searchable.**

Canopy is a native macOS app that puts a Spotlight-style search overlay on top of your menubar apps. Press a hotkey, type what you want, and either launch an app or trigger one of its actions directly — without touching the mouse.

```
⌥Space  →  "wifi off"  →  Wi-Fi turns off
⌥Space  →  "1pass"     →  1Password opens
⌥Space  →  "cal"       →  Calendar activates
```

It also lets you organise menubar apps into named folders, so you can hide the clutter without losing access.

---

## Features

**Instant actions**
Type what you want to do, not which app to open. Canopy reads your menubar apps' menus via the macOS Accessibility API and surfaces actions as first-class search results. "wifi off", "bluetooth on", "do not disturb" — done in one keystroke.

**Smart suggestions**
Results get smarter the more you use Canopy. A time-decay algorithm (14-day half-life) surfaces your most-used apps and actions first, and remembers what you picked last time you typed the same query.

**Reveal fallback**
When Canopy can't read an app's menu (Electron apps, obscure tools, anything that blocks Accessibility), it still shows an "Open in menu bar →" result that brings the app to focus. Something useful always happens.

**Virtual folders**
Group menubar apps into named folders — Productivity, Media, Dev, whatever you like. Folders appear in the overlay and let you drill in to find and launch apps without them cluttering the system menubar itself.

**Keyboard-first**
Arrow keys to navigate, Return to activate, Escape to dismiss. Canopy never steals focus from your current app.

---

## Install

> Requires **macOS 13+** and **Xcode 15+** (free from the App Store).

```bash
git clone https://github.com/emmi-dev12/Canopy.git
cd Canopy
make install
```

That's it. `make install` builds a Release binary, copies it to `/Applications`, and ad-hoc signs it for local use.

### First launch

After installation, Canopy needs two permissions to work fully:

1. **Open Canopy** from Launchpad (or run `make open`)
2. Go to **System Settings → Privacy & Security**
3. Under **Accessibility** — enable Canopy
4. Under **Input Monitoring** — enable Canopy
5. Press **⌥Space** anywhere to open the overlay

Without Accessibility, Canopy shows app names only (no action search).  
Without Input Monitoring, the hotkey falls back to a less reliable Carbon shortcut; you can always click Canopy's menubar icon instead.

---

## Usage

| Action | How |
|--------|-----|
| Open overlay | ⌥Space (default) |
| Navigate results | ↑ / ↓ arrows |
| Activate selection | Return |
| Dismiss | Escape |
| Change hotkey | Right-click Canopy's menubar icon → Settings |
| Manage folders | Right-click → Settings → Folders |

**Search tips**
- Short abbreviations work: `"cal"` → Calendar, `"1p"` → 1Password
- Action phrases work: `"wifi off"`, `"bt on"`, `"dnd"`, `"mute"`
- Folder names are searchable too

---

## Other make targets

```bash
make run        # Build and launch from .build/ (skips /Applications install)
make open       # Open the already-installed app
make uninstall  # Remove Canopy from /Applications
make clean      # Delete the .build/ folder
make help       # Print all targets
```

---

## Building & architecture

The project is a single Xcode target — no dependencies, no package manager.

```
Canopy/
├── App/               Entry point, AppDelegate, dependency wiring (AppEnvironment)
├── Models/            MenubarApp, NormalizedMenuAction, SearchResult, AppFolder
├── Services/
│   ├── AppDiscovery/  Finds running apps with menubar presence (NSRunningApplication heuristics)
│   ├── Accessibility/ AXUIElement traversal, action normalisation, activation
│   ├── HotkeyService  CGEventTap + Carbon fallback
│   ├── SearchEngine   In-memory search index, <100 ms query guarantee
│   └── RankingService Decay-weighted scoring + query-context boosting
├── Persistence/       JSON-based (no Core Data) — usage scores, folders, hotkey prefs
├── Features/
│   ├── Overlay/       NSPanel controller + SwiftUI search UI
│   ├── Settings/      Preferences window, folder manager, hotkey recorder
│   └── Menubar/       Canopy's own NSStatusItem
└── Utilities/         SmartMatcher, DecayCalculator, AXHelpers
```

**Key design decisions**

- The overlay is an `NSPanel` at `.popUpMenu` window level with `.nonactivatingPanel` — it never steals focus.
- AX enumeration runs off the main thread (`Task.detached`) and results are cached in-memory. Search never blocks on AX.
- Persistence uses plain JSON files in `~/Library/Application Support/Canopy/` — no Core Data tooling required.
- Services are protocol-injected so `SearchEngine` and `RankingService` are unit-testable without the full app graph.

---

## Permissions explained

| Permission | Why Canopy needs it |
|------------|---------------------|
| Accessibility | Read menu items from other apps via AXUIElement |
| Input Monitoring | Intercept the global hotkey with CGEventTap |
| Apple Events | Activate other apps when triggering menu actions |

Canopy is **not sandboxed** — sandboxing blocks CGEventTap and cross-process AX access, which are both essential. This is consistent with similar tools (Bartender, Alfred, Raycast).

---

## License

MIT
