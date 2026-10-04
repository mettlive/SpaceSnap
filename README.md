# SpaceSnap

Instant macOS Spaces switching — no slide animation, no lag after it. A small menu bar app for macOS 26.6+. No SIP disabling, no global Reduce Motion.

## Features

- **Instant trackpad swipe** — the horizontal swipe between desktops is intercepted and replaced with an instant switch. Vertical gestures (Mission Control, App Exposé) are untouched.
- **Hotkeys** — previous/next desktop (`⌃←` / `⌃→` by default), fully configurable.
- **Jump to desktop 1–10** — modifier + digit (`⌃1` … `⌃0` by default). Fullscreen apps are skipped when numbering, just like macOS does.
- **Back to the previous desktop** — `` ⌃` `` by default.
- **Empty-desktop guard** — about 0.4 s after you land on a desktop with no windows, macOS activates some other app and yanks you to its desktop. SpaceSnap takes focus itself so that never happens.
- **Indicator** — current desktop number in the menu bar and a short overlay on every switch.
- Switching always targets the display under the pointer (same as the native `⌃←/→`), with no rubber-band bounce at the first/last desktop.

## Install

### One command

```sh
curl -fsSL https://raw.githubusercontent.com/mettlive/SpaceSnap/main/install.sh | bash
```

Downloads the latest release, installs it to `/Applications` (replacing an older version and quitting it first) and launches it. Run the same command again to update.

### DMG

Download `SpaceSnap.dmg` from [Releases](https://github.com/mettlive/SpaceSnap/releases/latest) and drag SpaceSnap into Applications.

If the release is not notarized, macOS blocks the first launch. Open **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.

### From source

Requires Xcode 26+.

```sh
git clone https://github.com/mettlive/SpaceSnap.git
cd SpaceSnap
./scripts/bundle.sh --install
```

## First launch

Grant **Accessibility** access: **System Settings → Privacy & Security → Accessibility → SpaceSnap**. macOS ignores synthetic input events from apps without it.

The grant is tied to the app's code signature. Builds signed with a Developer ID keep it across updates. Ad-hoc signed builds (local builds and non-notarized releases) look like a new app to macOS after every update, and re-enabling the old entry does nothing. The install script and `scripts/bundle.sh --install` reset the stale entry for you, so just grant access again when asked. After a manual DMG update, remove SpaceSnap from the list with **−** (or run `tccutil reset Accessibility dev.mettlive.SpaceSnap`) and grant it again.

Settings live in the menu bar icon → **Settings…**: swipe interception, overlay, empty-desktop guard, menu bar number, launch at login, and all shortcuts.

## Uninstall

1. Quit SpaceSnap from its menu bar icon.
2. Delete `/Applications/SpaceSnap.app`.
3. Optionally remove it from **Privacy & Security → Accessibility** and clear its settings: `defaults delete dev.mettlive.SpaceSnap`.

## How it works

macOS has no supported way to disable the Spaces slide animation. SpaceSnap posts a synthetic Dock-swipe gesture with near-zero progress and very high velocity. The Dock performs the switch through its own pipeline — focus, wallpaper and Mission Control stay consistent — but the animation has nowhere to travel. On macOS 27+ the event also carries the serialized IOHID payload that the system validates there.

Conflicting Mission Control shortcuts ("Move left/right a space", "Switch to Desktop N") are disabled only while SpaceSnap runs, and only those that match your SpaceSnap shortcuts. This changes the live WindowServer state, not `com.apple.symbolichotkeys`, and they are re-enabled on quit.

## Limitations

- Relies on undocumented APIs (`SkyLight`, private `CGEvent` fields). Any macOS release can break them; the symptom is that switching silently stops working.
- macOS 26.0–26.5 is not supported: a WindowServer bug there can leave the destination desktop's windows unpainted after an instant switch.
- The macOS 27 path is ported from noswoosh and has not been verified by this project yet.
- With **Automatically rearrange Spaces based on most recent use** enabled, desktop order keeps changing; turn it off in **Desktop & Dock**.
- If SpaceSnap crashes, the Mission Control shortcuts it disabled stay off until you log out or relaunch and quit it.

## Development

```sh
swift build
swift test
./scripts/bundle.sh            # build/SpaceSnap.app (universal, ad-hoc signed)
./scripts/bundle.sh --install  # + install to /Applications and launch
./scripts/package.sh           # build/SpaceSnap.dmg + build/SpaceSnap.zip
```

Layout:

- `Sources/SpaceSnapCore/Domain` — Spaces model, switch planner, landing prediction, history, hotkeys, settings.
- `Sources/SpaceSnapCore/Application` — `SpaceSwitchService`, `SystemShortcutCoordinator`.
- `Sources/SpaceSnapCore/Infrastructure` — private SkyLight APIs, gesture synthesis, event tap, Carbon hotkeys, empty-desktop guard.
- `Sources/SpaceSnap` — SwiftUI menu bar app, settings window, overlay.

## Credits

The synthetic Dock-swipe technique comes from [jurplel/InstantSpaceSwitcher](https://github.com/jurplel/InstantSpaceSwitcher) (MIT). Swipe interception, the macOS 27 payload and the empty-desktop guard are based on [mmathys/noswoosh](https://github.com/mmathys/noswoosh) (MIT) and [joshuarli/iss](https://github.com/joshuarli/iss) (0BSD).

## License

[MIT](LICENSE). Third-party notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md); both files ship inside `SpaceSnap.app/Contents/Resources`.
