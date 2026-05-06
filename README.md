# Machlif (מחליף)

A tiny macOS menu-bar utility that converts text between Hebrew and English keyboard layouts.

If you ever started typing in the wrong layout — `שלום` came out as `akuo`, or `hello` came out as `יקללם` — select the offending text and **double-tap Shift**. Machlif replaces the selection with what the same physical keys would have produced under the other layout. Direction is auto-detected.

## Requirements

- macOS 13 (Ventura) or later
- Xcode command-line tools (`xcode-select --install`) — Xcode itself is not required

## Build & run

```sh
make run        # build, bundle into .app, and launch
make install    # copy Machlif.app to /Applications
make test       # run unit tests
make clean
```

Or open `Package.swift` in Xcode and Run from there.

## First launch

macOS will ask for **Accessibility** permission — Machlif needs it to read modifier-key events and to synthesize the ⌘C/⌘V keystrokes that capture and replace your selection. After granting it, quit and relaunch the app.

If the permission dialog never appeared, open *System Settings → Privacy & Security → Accessibility* and add `Machlif.app` manually, or use the **Grant Accessibility…** item in the menu-bar dropdown.

## Usage

1. Select the text you want to convert.
2. Press **Shift twice quickly** (within 0.4 s, no other key in between).
3. The selection is replaced with the converted text. Your clipboard is restored a moment later.

The menu-bar icon is the Hebrew letter **מ**. From the dropdown:

- **Enabled** — toggles the double-tap handler without quitting.
- **Open at Login** — registers the app with `SMAppService` (macOS 13+).
- **Quit Machlif**.

## Layout

The mapping follows the Israeli SI-1452 Hebrew layout aligned to US QWERTY by physical key position:

| Top row | Home row | Bottom row |
|---|---|---|
| ק→e ר→r א→t ט→y ו→u ן→i ם→o פ→p | ש→a ד→s ג→d כ→f ע→g י→h ח→j ל→k ך→l ף→; | ז→z ס→x ב→c ה→v נ→b מ→n צ→m ת→, ץ→. |

Plus `/`↔`q` and `'`↔`w`. Digits, spaces, and unmapped punctuation pass through unchanged. Uppercase Latin letters fold to the same Hebrew letter (Hebrew has no case).

## Project layout

```
Sources/
├── MachlifCore/          # pure logic — no AppKit
│   └── LayoutConverter.swift
└── Machlif/              # menu-bar app — AppKit, CGEventTap, Accessibility
    ├── MachlifApp.swift
    ├── AppDelegate.swift
    ├── ShiftDoubleTapDetector.swift
    ├── SelectionRoundTrip.swift
    ├── PermissionsHelper.swift
    └── LoginItemHelper.swift
Tests/MachlifTests/
└── LayoutConverterTests.swift
Resources/
├── Info.plist            # bundled into Machlif.app/Contents/
└── Machlif.entitlements
```
