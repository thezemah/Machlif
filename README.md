# Machlif — מחליף

> **Hebrew** *makh-LEEF* · "switcher / replacer"

A tiny macOS menu-bar app that fixes text typed in the wrong keyboard layout — instantly.

**[⬇ Download v1.2](https://github.com/thezemah/Machlif/releases/latest)** &nbsp;·&nbsp; **[Website](https://thezemah.github.io/Machlif)**

---

## What it does

Ever started typing in the wrong layout?

```
Typed with Hebrew layout active:   שלום חברים
Wanted:                            akuo jarum
```

Select the broken text, **double-tap Shift**, and Machlif replaces it with what you meant to type. Direction is auto-detected — it works both ways.

Works with **any non-Latin keyboard layout** installed on your Mac: Hebrew, Arabic, Cyrillic, Greek, and more. Layout maps are built at runtime from the system's keyboard data — no hard-coded character tables.

---

## Install

1. Download **Machlif-1.2.dmg** from the [latest release](https://github.com/thezemah/Machlif/releases/latest).
2. Open the DMG → drag **Machlif** to **Applications**.
3. Launch Machlif — macOS will prompt for **Accessibility** permission. Grant it.

The **מ** icon appears in your menu bar. That's it.

---

## Usage

| Step | Action |
|------|--------|
| 1 | Select the text you want to fix |
| 2 | Double-tap **Shift** (default trigger) |
| 3 | The selection is replaced in place |

Your clipboard is silently restored after conversion.

### Preferences (⌘,)

Open from the menu-bar icon:

- **Trigger** — double-tap any modifier key (Shift, Option, Command, Control) or record a custom keyboard shortcut
- **Keyboard Layouts** — toggle which installed non-Latin layouts participate in conversion
- **Double-tap Speed** — tune the detection window (0.15 s – 0.7 s)

---

## Build from source

Requires Xcode command-line tools (`xcode-select --install`). Xcode itself is not needed.

```sh
make run        # build + launch
make install    # copy to /Applications
make dmg        # build distributable DMG
make test       # run unit tests
make clean
```

---

## How it works

1. A **CGEventTap** on the main run loop watches for the configured trigger (default: Shift double-tap).
2. On trigger: `⌘C` copies the selection → direction is detected by counting non-Latin vs Latin characters → the best-matching installed layout's character map is applied → `⌘V` pastes the result.
3. Layout maps are built via **TIS** (Text Input Services) + **UCKeyTranslate** — same data macOS uses internally.
4. The original clipboard is restored 300 ms later.

---

## Requirements

- macOS 13 Ventura or later
- Accessibility permission (prompted on first launch)

---

## Project layout

```
Sources/
├── MachlifCore/
│   └── LayoutConverter.swift          # direction detection + char map logic
└── Machlif/
    ├── AppDelegate.swift
    ├── ShiftDoubleTapDetector.swift   # TriggerDetector — event tap
    ├── SelectionRoundTrip.swift       # ⌘C → convert → ⌘V
    ├── KeyboardLayoutDetector.swift   # TIS/UCKeyTranslate map builder
    ├── LanguagePreferences.swift      # UserDefaults + TriggerConfig model
    ├── PreferencesView.swift          # SwiftUI preferences UI
    ├── PreferencesWindowController.swift
    ├── ShortcutRecorderView.swift     # hotkey recorder (NSViewRepresentable)
    ├── PermissionsHelper.swift
    └── LoginItemHelper.swift
Tests/MachlifTests/
└── LayoutConverterTests.swift
```

---

## License

Personal use. Pull requests welcome.
