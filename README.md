# 🌍 Terra Engine

> *A Terraformer received coordinates and landed. The planet wasn't on the manifest. No atmosphere processor. No water cycle. Just dying soil and a chute they built themselves. They kept it alive as long as they could. They documented everything. Then the air ran out.*
>
> *You got the same coordinates. You found their notes. Now it's your shift.*

---

## What Is Terra Engine?

Terra Engine is a 3D survival game built for the **Gamedev.js Jam 2026** under the theme **"Machines."**

You are a Terraformer — a professional planet cultivator — who has crash-landed on the wrong planet. The Terraformer before you built a system to keep the planet alive. They still died. You inherited their machine. Your job is simple: keep the biological engine running until rescue arrives.

Rescue never comes for one person. But it might come for ten.

---

## Core Concept

The planet is the machine. It has inputs, outputs, and a decay rate. Feed it or it dies. You die with it.

No HUD health bars. The planet shows its own health:

| Berries in Lake | Visual State | Planet Effect |
|---|---|---|
| 0 | Cracked dust | Plants dying fast |
| 1 | Chalky residue | Plants dying slow |
| 2–4 | Blue goo | Plants surviving |
| 5–9 | Shallow shimmer | Plants growing |
| 10+ | Deep blue waves | Planet thriving |

---

## Gameplay

### The Loop
```
Climb to berry field → Carry berry → Drop in chute → Berry slides to lake
                                                            ↓
                                                     Lake stays alive
                                                            ↓
                                                      Air stays clean
                                                            ↓
                                                       You stay alive
```

### Player Mechanics
- **Stamina bar** — drains while moving, refills while standing still
- **Half speed** when carrying any item
- **One item** carried at a time
- **Boulders** wipe stamina to zero and knock you sideways
- Drop item on boulder hit — walk back and recover it

### World Layout
```
[ HILLTOPS ]     ← berry trees, boulder spawn zone
[ MIDSLOPE ]     ← plants, seed zones, danger area
[ FLATLAND ]     ← player base, chute entrance
[ LAKESIDE ]     ← delivery destination, relative safety
[ EDGE     ]     ← boulders fall off the planet here
```

### Tasks
- **Carry berries** from hilltop to chute to feed the lake
- **Carry water** manually to plants on the slope
- **Spread seeds** anywhere on flatland to grow new plants
- **Convert pits** into new lakes to expand survivable area
- **Dodge boulders** rolling from hilltops at increasing frequency

### Pressure Systems
- Lake decays constantly over time
- Bigger lake = more boulders spawning
- Berry trees die if the lake dries out
- Late game: you run further for fewer berries

---

## World Lore

### The Terraformer Before You
When you land you find:
- A **dead alien suit** near the landing zone — no dialogue, just presence
- A **signboard** with pictogram instructions — chute, lake, berry, arrow — field notes from a professional who knew they were running out of time
- **The Chute** — a pre-built delivery system. Drop berries in. They slide to the lake. This is the machine. This is the theme.

The Terraformer before you had every skill to survive. They built the system. They documented everything. They still died. Now it is your turn.

### The Berry Field
At the hilltop the berry field pulses **RGB acid-trip visuals** when full. Beautiful. Dangerous. Boulders spawn here. The planet's most vital resource lives at its most volatile point.

---

## Multiplayer

### Session System
- Persistent world — pause and log out anytime
- Return to same planet same state
- On return: play solo or invite players
- Up to 100 players on the same planet

### Why Multiplayer Changes Everything
Solo play is infinite survival — leaderboard glory only.
Multiplayer changes the win condition entirely.

| Active Players | Rescue Timer |
|---|---|
| 1 | ~1 year IRL — effectively infinite |
| 10 | Hours |
| 100 | Minutes |

The formula is in the source code. Find it yourself.

---

## Easter Eggs

### The Rescue
Triggered when enough players sustain the planet long enough. A ship lands. You actually made it. Nobody knows the exact conditions until they read the source code. The community will figure it out.

### The Statue
The first group to trigger rescue gets permanent statues on the planet. All player names carved in. Every solo player who loads the game after sees them and wonders what happened there. We will never announce this exists.

### The Tombstone Wall
Every player who dies leaves a small grave at their death location. It shows their survival time. It stays forever. Over time the map fills with graves — a silent history of everyone who tried before you.

---

## Screens

| Screen | Type | Notes |
|---|---|---|
| Splash | Full | Planet breathing animation, 3–5 seconds |
| Profile Setup | Full | First time only — enter username or X handle |
| Main Menu | Full | Solo, Resume, Co-op, Leaderboard, Settings |
| Co-op Lobby | Full | Create or join room, ready up |
| Loading | Full | Lore text while assets load |
| Gameplay | Full | 3D world, minimal HUD |
| Pause Menu | Overlay | Resume, Save and Exit, Settings |
| Death | Overlay | Survival time, tombstone placement animation |
| Leaderboard | Full | All time, today, personal best |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Engine | Godot 4 |
| Export | HTML5 (WebGL) |
| Language | GDScript |
| 3D Assets | Low poly, CC BY licensed |
| Multiplayer | Godot multiplayer API + WebSocket |
| Persistence | Backend session storage |
| Leaderboard | Online database |
| Deployment | Wavedash + Itch.io |

---

## Project Structure

```
terra-engine/
├── scenes/
│   ├── splash.tscn
│   ├── profile_setup.tscn
│   ├── main_menu.tscn
│   ├── coop_lobby.tscn
│   ├── loading.tscn
│   ├── gameplay.tscn
│   ├── leaderboard.tscn
│   └── overlays/
│       ├── pause_menu.tscn
│       └── death_overlay.tscn
├── scripts/
│   ├── player/
│   │   ├── player_controller.gd
│   │   ├── stamina_system.gd
│   │   └── inventory.gd
│   ├── world/
│   │   ├── lake_system.gd
│   │   ├── boulder_spawner.gd
│   │   ├── plant_system.gd
│   │   └── chute.gd
│   ├── multiplayer/
│   │   ├── session_manager.gd
│   │   └── sync.gd
│   ├── meta/
│   │   ├── tombstone_manager.gd
│   │   ├── leaderboard.gd
│   │   └── rescue_timer.gd        ← 👀
│   └── ui/
│       ├── hud.gd
│       └── death_overlay.gd
├── assets/
│   ├── models/
│   ├── textures/
│   ├── shaders/
│   │   ├── lake.gdshader
│   │   └── berry_field_rgb.gdshader
│   └── audio/
├── addons/
└── README.md
```

---

## Running Locally

```bash
# Clone the repo
git clone https://github.com/tobiawolaju/terra-engine
cd terra-engine

# Open in Godot 4
# File → Open Project → select project.godot

# Export HTML5
# Project → Export → HTML5 → Export Project
```

---

## Playing Online

Live at: **[itch.io link]**
Also deployed on: **[Wavedash link]**

---

## Asset Credits

All 3D assets used under Creative Commons CC BY 4.0 license.
Full credits list in `/assets/CREDITS.md`

---

## Jam Submission

- **Jam:** Gamedev.js Jam 2026
- **Theme:** Machines
- **Challenges:** Deploy to Wavedash · Open Source by GitHub · YouTube Playables
- **Submitted by:** [@tobiawolaju](https://github.com/tobiawolaju)

---

## License

MIT License — see `LICENSE` file for details.

Open source. Read the code. The answers are in there.

---

*Built in 2 days. Dedicated to every Terraformer who didn't make it.*