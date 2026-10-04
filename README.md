# G-Hockey

An original, offline neon air-hockey game for Android, built with Godot 4.7.2.

## Play

Open `project.godot` in Godot and press **F6** with `scenes/main.tscn` open,
or **F5** to run the project.

- **1 Player:** play against Easy, Normal, Hard, or Expert AI.
- **2 Players:** sit at opposite ends of one phone or tablet. Cyan is Player 1
  at the bottom; magenta is Player 2 at the top.
- Select the first-to-3, 5, 7, or 10 goal rule. The default is 7.
- Touch anywhere inside your half, then drag to move your paddle. The initial
  offset is preserved so the paddle does not jump underneath your finger.
  Each player owns one touch until it is released; extra fingers are ignored.
- Strike the puck into the other player's goal. Paddles stay in their own half.
  After a goal, the conceding player receives the next puck.
- **Pause** or **Escape / Android Back** pauses a live match. Resume includes
  a three-second countdown and preserves the puck's momentum.
- Use the mouse to click and drag the bottom half for editor testing. Mouse
  testing of local mode controls one paddle at a time; a device is needed for
  physical simultaneous-touch testing.

Music, effects volume, goal vibration, screen shake, and reduced effects are
adjustable. **Save & Back** persists preferences in `user://settings.cfg`.
The app pauses the match and music when it loses focus. Returning to the app
leaves a match paused until the player explicitly resumes.

## Scenes and code

All visible game objects and interface composition live in `.tscn` scenes.
Open the scenes in the editor to inspect or change their default appearance.

| Subsystem | Responsibility |
| --- | --- |
| `scenes/main.tscn`, `scripts/main.gd` | Menus, match setup, settings, HUD, overlays, safe-area scaling, Android lifecycle |
| `scenes/arena.tscn`, `scripts/arena.gd` | Match states, countdowns, scoring, serves, pause, results |
| `scenes/rink.tscn` | Editor-visible rink, grid, goal openings, and neon lines |
| `scenes/paddle.tscn`, `scripts/paddle.gd` | Paddle visuals, court limits, movement speed, velocity |
| `scenes/puck.tscn`, `scripts/puck.gd` | Puck visuals and substepped circle collision simulation |
| `scripts/touch_controller.gd` | Independent finger ownership and drag offsets |
| `scripts/ai_controller.gd`, `resources/ai_*.tres` | AI reaction, movement, aiming, and wall-bounce prediction |
| `scenes/effects.tscn`, `scripts/effects.gd` | Bounded particle effects and puck trail |
| `scenes/audio.tscn`, `scripts/audio.gd` | Looping music and an eight-voice effects pool |
| `scripts/settings.gd` | Saved user preferences |
| `resources/default_match.tres` | Default match configuration |
| `resources/neon_theme.tres`, `shaders/` | Shared UI styles and inexpensive glow/background shaders |

### Tune gameplay

Edit the four `resources/ai_*.tres` resources in the Inspector. Higher movement
speed, lower reaction delay, lower aiming error, and greater prediction weight
make the opponent harder. AI always obeys the same court boundaries as players.

The logical game canvas is **720 × 1280**, uniformly fitted inside the display's
safe area. The rink spans `(48, 210)` to `(672, 1130)` with 180-unit-wide goals
centered at the ends. If changing rink dimensions, update the matching bounds
in the puck physics, touch controller, paddle courts, and AI prediction.

Physics runs at 120 ticks per second. Puck simulation subdivides movement into
steps of at most eight units at its maximum speed, samples each moving paddle
along its path, and resolves circles against the paddles, goal posts, and walls.
This avoids tunneling without depending on a heavyweight rigid-body setup.
Only the decorative rink moves during screen shake, keeping input stable.

The Compatibility renderer is selected for this 2D game. Its scene-based glow
works without HDR or Vulkan bloom. Reduced effects removes halos, particles,
trails, and screen shake while keeping clear outlines and all gameplay rules.

## Android build

Install matching **Godot 4.7.2 export templates**, Android SDK/build tools, and
JDK 17. Configure the SDK and Java paths in **Editor Settings → Export → Android**.
Use the existing **Android** export preset or run:

```sh
godot --headless --editor --path . --import
godot --headless --path . --export-debug Android builds/G-Hockey-debug.apk
```

The preset uses portrait orientation, immersive mode, the package ID
`com.ghockey.game`, version `0.1.0`, ARM64 for devices, and x86-64 for emulators.
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

Current validation: **37 gameplay checks passed**. Phone, tablet, and tall-phone
layouts were rendered at 720 × 1280, 960 × 1280, and 720 × 1620 and inspected.

On **2026-10-04**, the Compatibility APK was installed and launched on a real
**Samsung SM-A176B, Android 16, Mali-G68, 1080 × 2340**. Single-player and local
two-player gameplay, goals, portrait layout, app backgrounding, return to the
paused match, resume, and saved settings were observed. No Godot script errors,
renderer errors, or Android crashes appeared in the collected runtime logs.
A SurfaceFlinger sample of **126 frame intervals** averaged **60.0 FPS**, with
**16.669 ms** median, **16.826 ms** 95th percentile, and no intervals above 25 ms.
This is a short sample, not a sustained thermal or battery benchmark.

Hands-on confirmation of two simultaneous physical fingers, sound quality,
vibration feel, system-gesture edge cases, and longer performance sessions
remains necessary. These cannot be fully verified through screenshots and ADB.
The earlier Vulkan build failed to display on the emulator's software GPU;
Compatibility rendering is now the project and final APK default.

## Original assets

The neon geometry, shaders, icon, and synth audio were created for G-Hockey.
Regenerate the deterministic audio assets with:

```sh
python3 tools/generate_audio.py
```

The bundled Liberation Sans fonts use the SIL Open Font License; see
`assets/fonts/LICENSE.txt`. G-Hockey does not use the reference game's artwork,
recordings, or branding.
