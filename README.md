# G-Hockey

An original, offline neon air-hockey game for Android, built with Godot 4.7.2.

## Play

Open `project.godot` in Godot and press **F6** with `scenes/main.tscn` open,
or **F5** to run the project.

- **1 Player:** play against Easy, Normal, Hard, or Expert AI.
- **2 Players:** sit at opposite ends of one phone or tablet. Cyan is Player 1
  at the bottom; magenta is Player 2 at the top.
- Below the player selectors, click **Goals to win** to cycle through 3, 5, 7, and 10;
  click **Difficulty** to cycle through Easy, Normal, Hard, and Expert.
  Defaults are 7 goals and Normal. Difficulty applies only to solo matches.
- Select **1 Player** or **2 Players**, then click **Start** to begin the countdown.
  The selected mode is highlighted in cyan; 1 Player is the default.
  Mode and option selections remain for the current app session, including rematches and trips
  to settings or the main menu.
- Touch anywhere inside your half, then drag to move your paddle. The initial
  offset is preserved so the paddle does not jump underneath your finger.
  Each player owns one touch until it is released; extra fingers are ignored.
- Strike the puck into the other player's goal. Paddles stay in their own half.
  After a goal, the conceding player receives the next puck.
- **Tap either score** at the right edge, or use **Escape / Android Back**,
  to pause a live match. Resume includes
  a three-second countdown and preserves the puck's momentum.
- Use the mouse to click and drag the bottom half for editor testing. Mouse
  testing of local mode controls one paddle at a time; a device is needed for
  physical simultaneous-touch testing.

Sound effects volume, goal vibration, screen shake, and reduced effects are
adjustable. **Save & Back** persists preferences in `user://settings.cfg`.
The app pauses the match and stops sound effects when it loses focus. Returning to the app
leaves a match paused until the player explicitly resumes.

## Scenes and code

All visible game objects and interface composition live in `.tscn` scenes.
Open the scenes in the editor to inspect or change their default appearance.

| Subsystem | Responsibility |
| --- | --- |
| `scenes/main.tscn`, `scripts/main.gd` | Menus, match setup, settings, HUD, overlays, safe-area scaling, Android lifecycle |
| `scenes/arena.tscn`, `scripts/arena.gd` | Match states, countdowns, scoring, serves, pause, results |
| `scenes/rink.tscn`, `scripts/rink.gd` | Editor-visible rink geometry, adapted to the display |
| `scripts/rink_layout.gd` | Shared bounds, goals, courts, starting positions, and resize mapping |
| `scenes/paddle.tscn`, `scripts/paddle.gd` | Paddle visuals, court limits, movement speed, velocity |
| `scenes/puck.tscn`, `scripts/puck.gd` | Puck visuals and substepped circle collision simulation |
| `scripts/touch_controller.gd` | Independent finger ownership and drag offsets |
| `scripts/ai_controller.gd`, `resources/ai_*.tres` | AI reaction, movement, aiming, and wall-bounce prediction |
| `scenes/effects.tscn`, `scripts/effects.gd` | Bounded particle effects and puck trail |
| `scenes/audio.tscn`, `scripts/audio.gd` | An eight-voice sound effects pool |
| `scripts/settings.gd` | Saved user preferences |
| `scripts/touch_slider.gd` | Native finger dragging for the sound effects slider, alongside standard mouse controls |
| `resources/default_match.tres` | Default match configuration |
| `resources/neon_theme.tres`, `resources/neon_emission.tres`, `shaders/` | Shared UI styles, selective HDR emission, and background shader |

### Tune gameplay

Edit the four `resources/ai_*.tres` resources in the Inspector. Higher movement
speed, lower reaction delay, lower aiming error, and greater prediction weight
make the opponent harder. AI always obeys the same court boundaries as players.

Gameplay fills the complete display, with rails only **12 logical units** from
the edges. Its logical width is **720** and its height follows the display's
aspect ratio, with uniform scaling to keep the puck and paddles circular.
Goals are 180 units wide, centered at both ends. The two scores are 64 × 64
minimum touch targets at the right edge of midfield; either score pauses play.
Score controls respect display cutouts without shrinking the rink. Menus and
modal cards remain centered within the safe area; modal dimming covers the
entire display.

`RinkLayout` provides a single source for bounds, goals, courts, and spawn
positions. Physics, AI, input, and scene geometry all use the same instance.
Paddles start 16% of rink height from their respective ends. Serves start at
35% or 65% of rink height on the conceding player's side.

Resizing an active match pauses it, releases captured fingers, and maps object
positions proportionally into the new rink. Scores and puck momentum survive;
resuming uses the normal countdown. Dragging a paddle over a score does not
activate pause: release that finger and make a fresh tap to pause.

Physics runs at 120 ticks per second. Puck simulation subdivides movement into
steps of at most eight units at its maximum speed, samples each moving paddle
along its path, and resolves circles against the paddles, goal posts, and walls.
This avoids tunneling without depending on a heavyweight rigid-body setup.
Only the decorative rink moves during screen shake, keeping input stable.

The Mobile renderer is selected for desktop testing and Android, with HDR 2D
rendering and selective bloom. Android requires Vulkan support; automatic
Compatibility/OpenGL fallback is disabled. This is internal HDR rendering and
works on ordinary SDR phone displays without requiring an HDR screen.

The editor-visible `WorldEnvironment` in `scenes/main.tscn` controls bloom.
Neon outlines, trails, and particles use `resources/neon_emission.tres`, with
an emission strength of 2.5, while UI and dark object interiors retain ordinary
brightness. The Environment uses Canvas background mode, an HDR threshold of
1.0, bloom of 0.0, glow intensity of 0.6, and the third blur level. No full-screen
bloom is added to ordinary colors. Reduced effects disables glow, returns neon
emission to 1.0, and removes particles, trails, and screen shake while keeping
clear outlines and all gameplay rules. HDR stays enabled.

## Android build

Install matching **Godot 4.7.2 export templates**, Android SDK/build tools, and
JDK 17. Configure the SDK and Java paths in **Editor Settings → Export → Android**.
Use the existing **Android** export preset or run:

```sh
godot --headless --editor --path . --import
godot --headless --path . --export-debug Android builds/G-Hockey-debug.apk
```

The preset uses portrait orientation, immersive edge-to-edge display, the package ID
`com.ghockey.game`, version `0.1.0`, and ARM64 for devices. The current preset
has x86-64 disabled; enable it to export for an x86-64 Vulkan-capable emulator.
Vibration is the only requested permission. It contains no ads, networking,
accounts, purchases, or external services.

Install on a connected test device:

```sh
adb install -r builds/G-Hockey-debug.apk
adb shell am start -n com.ghockey.game/com.godot.game.GodotAppLauncher
```

The APK uses Godot's development signing key. Configure a separate release key
and an appropriate package identifier before publishing. Never commit keystores
or signing passwords. The current deliverable is for development and testing.

## Verification

Run the regression scene:

```sh
godot --headless --path . tests/gameplay_test.tscn
```

It covers scoring, goal resets, score targets, rematches, pause/resume momentum,
fast collisions, simultaneous finger ownership, coordinate conversion, mouse
and touch dispatch through the UI, AI court limits, and settings persistence.
The settings check backs up and restores existing developer preferences.

Render the UI verification sequence:

```sh
godot --path . tests/visual_check.tscn
```

It captures menus, settings, match screens, countdown, pause, results, and
phone/tablet layouts to `/tmp/ghockey-*.png`. Tests and audio-generation tools
are excluded from Android exports.

Current validation after removing background audio, including native sound effects
slider touch input: **919 gameplay checks passed**. Volume tests cover scaled touch coordinates at four display sizes,
dragging beyond the slider, ignoring other fingers, cancellation, settings closure,
focus loss, mouse input, audio values, and persistence of sound effects volume.
The slider fix has not yet been verified on a physical Android device.

Mode selection and Start verification is included in the same suite.
Tests cover mouse and native touch selection, mutually exclusive mode toggles,
repeated selection, highlighting, option cycling and wraparound, Start with the
chosen mode/AI/goal target, rematches, and preserving selections through settings.
Alignment and touch targets are checked at four display sizes. The rendered
verification sequence produced 33 captures at phone, tall-phone, and tablet sizes,
including both mode selections and Reduced effects. Android export/device testing
is deferred to a separate requested step.

Previous validation for the Mobile/HDR migration: **494 gameplay checks passed**,
including bloom and emission state at startup, both gameplay and menu preview,
Reduced effects, and settings persistence. The Mobile/Vulkan visual sequence
produced 36 captures at 720 × 1280, 720 × 1620, and 960 × 1280. Menus, gameplay,
countdowns, pause, results, particle/trail effects, and reduced-effects layouts
were inspected. HDR captures are converted from linear color to sRGB before
saving PNGs.

The Mobile/HDR debug APK was exported, installed, and tested on **2026-10-04**
on the **Samsung SM-A176B, Android 16, Mali-G68, 1080 × 2340**. Logs confirmed
**Mobile with Vulkan 1.3.219**. Device captures showed colored bloom, circular
paddles, and readable scores and overlays. A paddle gesture moved the paddle,
a score tap paused the match, Resume returned to play, and returning from the
background left the match paused. The desktop captures also verify the resume
countdown. The additional final-build device countdown capture was not completed.

A final short SurfaceFlinger sample of 126 frame intervals measured **47.84 FPS**,
with a median interval of 16.698 ms, a 95th percentile of 33.348 ms, and 32
intervals above 25 ms. **The 60 FPS target is not met on this phone with HDR bloom.**
This sample does not establish sustained performance; further GPU profiling and
rendering optimization are needed. Removing the fifth bloom blur level did not
materially improve this device sample.

The following full-display validation predates the Mobile/HDR migration and used
the Compatibility renderer: **341 gameplay checks passed**
across 720 × 1280, 720 × 1560, 720 × 1620, and 960 × 1280 viewports. Rendered
phone, tall-phone, and tablet layouts were inspected. Tests cover both score
buttons in both game modes, touch and mouse dispatch, goal and wall collisions,
AI court limits, active resizing, safe-area placement, and full-display dimming.

The previous Compatibility debug APK was installed and tested on **2026-10-04** on a real
**Samsung SM-A176B, Android 16, Mali-G68, 1080 × 2340**. Screenshots confirmed
full-display field coverage, circular paddles, readable scores, and centered
overlays. Both score buttons opened pause, Resume showed the countdown, and
returning from the background preserved the paused match. ADB touch gestures
moved both paddles in local two-player mode with aligned coordinates. Runtime
logs contained no Godot or Android runtime errors.

A short SurfaceFlinger sample of 126 frame intervals measured **59.99 FPS**,
with a median interval of 16.668 ms, a 95th percentile of 16.802 ms, and no
intervals above 25 ms. This sample does not establish sustained performance.

Hands-on confirmation of simultaneous physical fingers, sound quality,
vibration feel, system-gesture edge cases, and longer performance sessions
remains necessary. These cannot be fully verified through screenshots and ADB.

## Original assets

The neon geometry, shaders, icon, and synth audio were created for G-Hockey.
Regenerate the deterministic audio assets with:

```sh
python3 tools/generate_audio.py
```

The bundled Liberation Sans fonts use the SIL Open Font License; see
`assets/fonts/LICENSE.txt`. G-Hockey does not use the reference game's artwork,
recordings, or branding.
