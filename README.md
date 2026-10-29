<p align="center">
  <img src="Resources/Logo.svg" width="88" alt="compo.sh: three windows in composition" />
</p>

<h1 align="center">compo.sh</h1>
<p align="center"><strong>A little order. A lot of room.</strong><br />An app-aware window manager for macOS.</p>

<p align="center">
  <a href="https://github.com/virajshoor/compo.sh/releases/latest/download/compo.sh-macOS.zip"><strong>Download for Mac ↗</strong></a>
  &nbsp; · &nbsp; <a href="Resources/compo.sh-guide.pdf">Read the guide</a>
  &nbsp; · &nbsp; <a href="#build-from-source">Build from source</a>
</p>
<p align="center">macOS 13+ &nbsp; / &nbsp; Apple silicon + Intel &nbsp; / &nbsp; MIT licensed</p>

<img src="Resources/Readme.svg" width="100%" alt="Layout illustration: a wide browser beside a tall terminal. Give every window its place." />

Your browser needs room to breathe. Your terminal likes to stand tall. compo.sh gives each window its place, then stays in your menu bar while you work.

Native Swift, AppKit, and SwiftUI. No third-party runtime dependencies. No account, telemetry, screen recording, or SIP changes.

> **Public beta.** Version 0.2.3 is Developer ID signed and Apple notarized, with the notarization ticket stapled to the app. Fresh installs start paused. Enable Automatic Tiling when you are ready.

## Made for the way you work

| Make room | Make it yours |
| :--- | :--- |
| **App-aware layouts.** Browser + terminal gets a 60/40 split. Browser + document gets equal tall panes. Two browsers get wide rows. | **Simple controls.** Pick Stack, Columns, or Rows; adjust gaps and main pane width. |
| **Layouts that fit.** Narrow companion columns become a balanced grid. Wider displays keep tall companion panes when space allows. | **Per-app rules.** Override app roles or keep an app floating with a small JSON file. |
| **Preview, then place.** Drag to edges or corners for a foreground snap preview. Drag over another managed window to swap. | **Keyboard control.** Focus, swap, float, zoom, pause, and retile without reaching for the mouse. |
| **Quiet by design.** Window events drive tiling. Window placement is instant by default, with visible drag previews. No continuous window polling. | **Silent startup.** Optional launch at login starts in the menu bar. Preferences survive updates with the same app identity. |

## Get started

1. [Download compo.sh](https://github.com/virajshoor/compo.sh/releases/latest/download/compo.sh-macOS.zip), unzip, and move **compo.sh.app** to **Applications**.
2. Open it. Choose **Allow Accessibility Access…**, then approve compo.sh in **System Settings → Privacy & Security → Accessibility**. This lets it move, resize, and focus windows.
3. Quit other window managers, then enable **Automatic Tiling**. Try App-Aware Layout first.

Click the tiled menu bar icon for controls. The bundled **Open Guide PDF…** works offline. Launch at login is optional and off on a fresh install; manual launches open controls.

**Updating:** quit compo.sh normally, replace the app in the same Applications location, then reopen. Keep its preferences and Application Support folder. Settings persist; macOS may still require renewed approval after a signing or system policy change.

[Release notes and checksums →](https://github.com/virajshoor/compo.sh/releases/latest)

## Your hands. Your rules.

All shortcuts use **Control + Option**. Close the compo.sh panel first; actions target the focused app window.

| Shortcut | Action |
| :--- | :--- |
| `⌃⌥` + arrows | Focus in that direction |
| `⌃⌥⇧` + arrows | Swap in that direction |
| `⌃⌥ L` | Cycle Stack → Columns → Rows |
| `⌃⌥ Space` | Float or tile the focused window |
| `⌃⌥ Return` | Zoom the focused window |
| `⌃⌥ P` | Pause or resume |
| `⌃⌥ R` | Clear manual placements and retile |

Shortcuts are fixed for now. They may conflict with VoiceOver or other apps. Floating and zoom are session-only; layout preferences persist.

### App rules

Choose **Edit App Rules**, edit the file, then **Reload App Rules**. Invalid JSON keeps the last working rules.

```json
{
  "apps": {
    "com.apple.Safari": { "role": "browser" },
    "com.apple.Terminal": { "role": "terminal" },
    "com.apple.calculator": { "floating": true }
  }
}
```

Rules live at `~/Library/Application Support/compo/config.json`. Use exact bundle identifiers. Allowed roles: `browser`, `terminal`, `document`, `other`. File limit: 256 KB.

## Native, with boundaries

**0.2.3:** placement skips unchanged frames, corrects origin shifts after resizing, and checks settled sizes before adapting layouts to app minimums. Columns can become rows or a grid to avoid overlap. Activation and geometry events trigger bounded recovery; brief Accessibility/WindowServer mismatches preserve known layout state. Clicks no longer interrupt swap animations, and snaps/swaps use the same constraint-aware layout path, including display crossings.

**0.2.2:** clicking to activate a window cannot trigger a snap or swap. Placement now requires a mouse-drag event, pointer travel, and window movement; content drags and live resizing remain excluded.

**0.2.1:** **Disable All Animations** is on by default, including after upgrading. Edge snaps, drag-to-swap, and keyboard swaps place windows instantly; drag overlays remain visible without appearance animations. Turn this option off to restore swap/replace transitions, which respect Reduce Motion. Edge snaps stay instant. This preference persists and controls compo.sh window placement; macOS still controls its own Spaces and Mission Control transitions.

compo.sh arranges existing windows through Accessibility. macOS still handles rendering, fullscreen, Mission Control, and Spaces. This is a window manager, not a replacement compositor.

- **Snap Edges:** on macOS 15+, compo.sh saves native edge/top/Option tiling preferences and disables competing previews while snapping is active. Turning snapping off, pausing, or quitting normally restores them. These preferences are undocumented and may change after OS updates.
- **After a crash:** reopen compo.sh, then pause or turn off Snap Edges to restore saved native settings. If needed, adjust tiling in System Settings → Desktop & Dock.
- **App limits:** compo.sh learns enforced minimum sizes and tries fitting rows, columns, or grids. If none fits, or an app rejects writes, the menu reports the problem; float a window or use fewer panes. Retile Now clears learned limits and retries. Dialogs, minimized windows, native fullscreen windows, hidden apps, and compo.sh itself are excluded.
- **Manual placement:** snaps and swaps remain until window membership changes or you choose Retile Now, provided they fit the display and app minimums. Zoom intentionally covers other panes. Quitting does not restore earlier window frames.
- **Privacy:** no app network requests or screen capture. Window metadata is read locally to manage visible windows. The distributed app's signing certificate publicly identifies its developer.

Pause anytime with `⌃⌥ P`. Before uninstalling, turn off Launch at Login, quit normally, then remove the app. Revoke Accessibility access in System Settings if desired.

## Build from source

Requires macOS, Xcode Command Line Tools, and Swift 5.9 or later. Deployment target: macOS 13.

```sh
git clone https://github.com/virajshoor/compo.sh.git
cd compo.sh
bash scripts/build.sh
```

Output: `dist/compo.sh.app`, universal for Apple silicon and Intel. The script builds and packages only; it never installs, launches, or enables login startup. Its default signature is ad hoc. Put the app in its permanent location before granting Accessibility access.

The current signed, notarized app bundle is also checked into [`dist/compo.sh.app`](dist/compo.sh.app), with its notarization ticket stapled. The release ZIP contains the same bundle.

For your own Developer ID signature:

```sh
COMPO_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' bash scripts/build.sh
```

Local builds are not automatically notarized. Submit your signed ZIP with `xcrun notarytool`, then staple the accepted ticket on your Mac. Rebuilding with a different identity can require renewed Accessibility approval.

### Checks

```sh
swift test
swiftc Sources/Compo/LaunchBehavior.swift Tests/LaunchBehaviorCheck.swift -o /tmp/compo-launch-check
/tmp/compo-launch-check
```

26 Swift tests cover layouts, app hierarchy, narrow and ultrawide displays, gaps, non-overlap, directional focus, snap zones, click-versus-drag placement intent, minimum-size fitting, shifted origins, refused writes, discovery races, and simulated activation recovery. The launch check covers four synthetic launch events. They do not move real desktop windows; app compatibility and actual login behavior need hands-on testing.

### Around the source

| Path | Purpose |
| :--- | :--- |
| `Sources/CompoCore/` | Layouts, app roles, focus geometry, snap zones |
| `Sources/Compo/` | Menu bar UI, Accessibility, hotkeys, dragging, native tiling preferences |
| `Tests/` | Geometry tests and login launch checks |
| `Resources/` | App metadata, logo, offline PDF guide |
| `scripts/build.sh` | Universal bundle packaging and signing |
| `scripts/Icon.swift` | App icon generation |
| `scripts/Guide.py` | PDF guide source; regenerate with Python + ReportLab |

## Contribute

Bug reports and focused pull requests welcome. For layout bugs, include macOS version, display arrangement, affected app names, and steps to reproduce. Remove private window titles and content before sharing screenshots.

[Open an issue](https://github.com/virajshoor/compo.sh/issues) · [MIT license](LICENSE)

<p align="center"><sub>Less arranging. More doing.</sub></p>
