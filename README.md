# Terra Engineer

Terraforming survival game built for **Gamedev.js Jam 2026** (theme: **Machines**), and submitted to the **Open Source track**.

> The last Terraformer left no manual.
>  
> Just a body, a lake, and a machine that only works if you keep feeding it.
>  
> You are not here to win. You are here to hold the system together for one more minute.

You are dropped on a failing planet with one job: keep oxygen alive for as long as possible.

## Jam Submission Snapshot

- Jam: `Gamedev.js Jam 2026`
- Theme: `Machines`
- Engine: `Godot 4.6.x`
- Platform: `Web (HTML5 export)`
- Track: `Open Source`

## Field Note

This was built fast, under jam pressure, with a simple design rule:
- If the machine is starving, the world should show it.
- If the player fails, the system should remember it.
- If the player survives longer, it should mean something.

## What Is Implemented Right Now

This README reflects what is currently wired in the project.

### Core Survival Loop

1. Oxygen starts at `50`.
2. Oxygen drains by `2` every `5` seconds.
3. Berries spawn around the map.
4. Carry berries and drop them into the lake.
5. A berry that stays underwater for `5` seconds is consumed and gives `+10` oxygen.
6. If oxygen reaches `0`, game over triggers and your survival time is submitted to the leaderboard.

There is also one extra risk/reward object:
- A dead alien body can be pushed into the lake for a one-time `+45` oxygen bonus.

### Player Mechanics

- Third-person movement with camera-relative controls.
- Jumping.
- Water movement slowdown (50% speed).
- Pick up and carry one nearby physics object at a time.
- Drop held object on command.
- Auto leap-assist while moving on ground (small periodic hop).
- Death state with orbiting camera and death overlay.

### UI and Flow

- Splash scene -> main menu.
- Main menu `Play` starts gameplay with a loading transition.
- Main menu `Leaderboard` opens the online leaderboard screen.
- HUD shows player username, time alive (seconds), touch joystick controls, and oxygen bar state.
- Death overlay shows final time alive.

### Online (Wavedash)

- Fetches current username.
- Posts survival score to leaderboard id: `survival_time`.
- Reads top leaderboard entries for leaderboard scene.

## Controls

- Move: `W A S D`
- Jump: `Space`
- Pick/Drop item: `P`
- Orbit camera: hold left mouse button + move mouse
- Zoom: mouse wheel
- Menu selections: left click

## Project Structure

```text
scenes/
  splash.tscn
  main_menu.tscn
  loading.tscn
  gameplay.tscn
  leaderboard.tscn
  overlays/death_overlay.tscn
  HUD.tscn

scripts/
  player/player_controller.gd
  world/berryspawner.gd
  world/pickable.gd
  world/peashooter.gd
  ui/hud.gd
  ui/main_menu.gd
  ui/leaderboard_screen.gd
  ui/splash.gd
  ui/screen_fader.gd
  ui/loading_overlay.gd
  wavedash/wavedash_init.gd
```

## Run Locally (Godot)

1. Open `project.godot` in Godot 4.6.x.
2. Run the default scene (splash).
3. Play from menu.

## Export Web Build

`export_presets.cfg` is already set up for Web export to:

- `Builds/index.html`

Current repo also contains ready web export folders:
- `Builds/`
- `ItichIO/`

## Why This Fits The Theme "Machines"

The planet is treated like a machine with:
- Inputs (berries and biomass).
- Decay (oxygen drain).
- Observable output (HUD + world color shifts).
- Failure condition (oxygen collapse).

Your job is to keep the system running under pressure.

## Jam Intent

Most survival games ask you to protect yourself.
This one asks you to maintain a living system that is already failing.

You are the maintenance worker, the fuel line, and the last backup process.
Keep it running until it breaks, or until you do.

## Open Source Track Notes

- Full source code is included.
- Gameplay logic is readable in GDScript (see `scripts/world/berryspawner.gd` and `scripts/player/player_controller.gd`).
- Web export settings are included for reproducible builds.

## Credits

- See `assets/CREDITS.md` for asset attributions.

---

Built in jam time.
Made for the Open Source track.
Kept alive by anyone willing to carry one more berry.
