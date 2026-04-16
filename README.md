# 🧭 Canopy

**A keyboard-first command layer for macOS menubar apps.**

Canopy turns your menubar into a searchable, actionable interface. Instead of hunting through icons or opening apps manually, you invoke a Spotlight-style overlay, type intent-based commands, and execute app actions directly.

It bridges the gap between:
- launching apps
- controlling apps
- and interacting with menubar utilities

---

## ⚡ Example usage

```
⌥ Space → "wifi off"    → Wi-Fi disabled
⌥ Space → "1pass"       → 1Password opens
⌥ Space → "cal today"   → Calendar focused
```

Canopy is designed around **intent, not navigation**.

---

## 🧠 Core idea

macOS menubar apps expose functionality through:
- menu items
- accessibility trees
- app activation states

Canopy converts those fragmented interfaces into a single searchable action layer.

Instead of:
> "Open app → find menu → click action"

You do:
> "Type intent → execute action"

---

## ✨ Features

### 🔎 Intent-based action search

Canopy indexes:
- running menubar apps
- their Accessibility menu structures (`AXUIElement`)

It exposes actions as searchable commands:
- `"wifi off"`
- `"bluetooth on"`
- `"do not disturb"`
- `"mute"`

Actions are ranked by semantic match + usage history.

### 🧠 Adaptive ranking system

Results are ordered using a hybrid scoring model:
- usage frequency
- recency (time-decay weighting, ~14-day half-life)
- query-context similarity
- last-selected bias

This allows Canopy to "learn" user behavior without explicit configuration.

### 📁 Virtual folders

Users can group menubar apps into logical namespaces:
- Productivity
- Media
- Dev
- Comms

Folders act as both:
- visual filters
- searchable scopes

### 🪶 Reveal fallback mode

Not all apps expose usable Accessibility trees (notably Electron apps).

When action extraction fails, Canopy falls back to:
> "Focus app → bring into foreground"

This guarantees a meaningful result always exists, even in degraded conditions.

### ⌨️ Keyboard-first UX

Canopy is designed to never interrupt workflow:

| Key | Action |
|-----|--------|
| ⌥ Space | Open overlay |
| ↑ / ↓ | Navigate results |
| Return | Execute |
| Escape | Dismiss |

No mouse interaction required.

---

## 🏗 Architecture overview

Canopy is built as a single macOS application target with modular services:

```
App/
  Entry point, AppEnvironment, dependency wiring

Models/
  MenubarApp
  SearchResult
  AppFolder
  NormalizedMenuAction

Services/
  AppDiscovery
    - detects menubar-capable apps via NSRunningApplication heuristics

  Accessibility
    - AXUIElement traversal
    - menu normalization
    - action execution layer

  SearchEngine
    - in-memory inverted index
    - <100ms query target

  RankingService
    - decay-weighted scoring model
    - usage feedback loop

  HotkeyService
    - CGEventTap primary
    - Carbon fallback for compatibility

Persistence/
  JSON-based storage in:
  ~/Library/Application Support/Canopy/

Features/
  Overlay
    - NSPanel (.nonactivatingPanel)
    - SwiftUI search interface

  Settings
    - hotkey config
    - folder management

  Menubar
    - NSStatusItem integration
```

---

## ⚙️ Key design decisions

### 1. Non-activating overlay window

The search UI is implemented as:
- `NSPanel`
- `.nonactivatingPanel`
- `.popUpMenu` level

This ensures:
- no focus stealing
- seamless overlay behavior
- uninterrupted typing in background apps

### 2. Asynchronous Accessibility traversal

AX queries are:
- offloaded via `Task.detached`
- cached in-memory
- never executed on main thread

This prevents UI blocking during:
- slow apps
- broken AX trees
- large menu hierarchies

### 3. JSON-based persistence

No Core Data or external database.

Stored data includes:
- usage frequency
- folder mappings
- hotkey preferences

Located in:
```
~/Library/Application Support/Canopy/
```

---

## 🔐 Permissions model

Canopy requires elevated system access:

| Permission | Purpose |
|------------|---------|
| Accessibility | Read and execute app menu actions via AXUIElement |
| Input Monitoring | Global hotkey capture via CGEventTap |
| Apple Events | Activate and focus external apps |

Canopy is **not sandboxed**, as sandboxing prevents:
- cross-process AX access
- CGEventTap usage

This is consistent with tools like Alfred and Raycast.

---

## ⚠️ Known limitations

**Accessibility API inconsistency**
Not all apps expose reliable AX structures:
- Electron apps often partially fail
- some menu items are dynamic or hidden

**Hotkey reliability fallback**
Input Monitoring may degrade to Carbon-based event handling on some systems.

**Menu traversal variability**
AX hierarchy depth varies significantly across applications.

---

## 🚀 Install

### Option A — Download (recommended)

1. Go to the [**Releases**](https://github.com/emmi-dev12/Canopy/releases/latest) page
2. Download **Canopy.zip**
3. Unzip and drag **Canopy.app** to `/Applications`
4. Open it — macOS may show a security prompt on first launch; go to **System Settings → Privacy & Security** and click **Open Anyway**

No Xcode, no build tools required.

### Option B — Build from source

> Requires **macOS 13+** and **Xcode 15+**

```bash
git clone https://github.com/emmi-dev12/Canopy.git
cd Canopy
make install
```

Builds and installs to: `/Applications/Canopy.app`

---

## 🧪 Make targets

| Command | Description |
|---------|-------------|
| `make run` | Build and run locally |
| `make install` | Build + install to /Applications |
| `make open` | Launch installed app |
| `make uninstall` | Remove from /Applications |
| `make clean` | Remove build artifacts |

---

## 💡 Why Canopy exists

macOS menubar apps are powerful but fragmented.

Canopy reduces that fragmentation by introducing:
> a single, intent-driven command surface for all menubar utilities

It replaces:
- visual scanning
- menu hunting
- app switching

with:
- direct action execution

---

## 🧭 Design philosophy

- Optimize for **intent**, not navigation
- Prefer **speed** over configurability
- **Fail gracefully** rather than silently
- Keep interaction fully **keyboard-driven**
- Avoid focus disruption at all costs
