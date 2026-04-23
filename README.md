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

---

## World Lore

### The Terraformer Before You
When you land you find:
- A **dead alien suit** near the landing zone — no dialogue, just presence
- A **signboard** with pictogram instructions — field notes from a professional who knew they were running out of time
- **The Chute** — a pre-built delivery system. Drop berries in. They slide to the lake. This is the machine. This is the theme.

### The Berry Field
At the hilltop the berry field pulses **RGB visuals** when full. Beautiful. Dangerous. Boulders spawn here.

---

## Multiplayer

Solo play is infinite survival — leaderboard glory only. Multiplayer changes the win condition entirely.

| Active Players | Rescue Timer |
|---|---|
| 1 | ~1 year IRL — effectively infinite |
| 10 | Hours |
| 100 | Minutes |

The formula is in the source code. Find it yourself.

---

## Easter Eggs

**The Rescue** — triggered when enough players sustain the planet long enough. We will never announce the conditions.

**The Statue** — the first group to trigger rescue gets permanent statues on the planet. Every solo player after sees them and wonders.

**The Tombstone Wall** — every dead player leaves a grave at their death location with their survival time. Permanent. Forever.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Engine | Godot 4 |
| Export | HTML5 (WebGL) |
| Language | GDScript |
| 3D Assets | Low poly, CC BY licensed (GLTF 2.0) |
| Platform SDK | Wavedash SDK (GDScript addon) |
| Multiplayer | Wavedash Multiplayer + WebSocket |
| Leaderboard | Wavedash Leaderboards API |
| Cloud Saves | Wavedash Cloud Saves API |
| Deployment | Wavedash + Itch.io |

---

## Project Structure

```
terra-engine/
│
├── wavedash.toml                        ← Wavedash config (game_id + export path)
├── project.godot
├── README.md
├── DEVNOTE.md
│
├── addons/
│   └── wavedash/                        ← Wavedash GDScript SDK (drop in from GitHub)
│       └── WavedashSDK.gd               ← Registered as Autoload, listed FIRST
│
├── exports/
│   └── web/                             ← HTML5 export output — wavedash.toml points here
│
├── scenes/
│   ├── splash.tscn                      ← Logo, planet breathing animation
│   ├── profile_setup.tscn               ← First time only — username or X handle
│   ├── main_menu.tscn                   ← Solo, Resume, Co-op, Leaderboard, Settings
│   ├── coop_lobby.tscn                  ← Create/join room, ready up
│   ├── loading.tscn                     ← Lore text while assets load
│   ├── gameplay.tscn                    ← Main 3D world scene
│   ├── leaderboard.tscn                 ← All time, today, personal best via Wavedash
│   └── overlays/
│       ├── pause_menu.tscn              ← Resume, Save and Exit, Settings
│       └── death_overlay.tscn           ← Survival time + tombstone placement animation
│
├── scripts/
│   ├── player/
│   │   ├── player_controller.gd         ← Movement, input, carrying logic
│   │   ├── stamina_system.gd            ← Drain on move, refill on idle, zero on boulder
│   │   └── inventory.gd                 ← One item at a time, drop on hit
│   │
│   ├── world/
│   │   ├── lake_system.gd               ← Berry count → visual state → planet health
│   │   ├── boulder_spawner.gd           ← Random timing, frequency tied to lake size
│   │   ├── plant_system.gd              ← Water dependency, seed spreading, decay
│   │   ├── chute.gd                     ← Receives berry, routes to nearest lake
│   │   └── pit_converter.gd             ← Converts pit into new lake on interaction
│   │
│   ├── multiplayer/
│   │   ├── session_manager.gd           ← Wavedash lobby create/join, player sync
│   │   └── sync.gd                      ← Position, inventory, world state sync
│   │
│   ├── meta/
│   │   ├── tombstone_manager.gd         ← Place grave on death, persist to all sessions
│   │   ├── leaderboard.gd               ← Posts score via WavedashSDK.post_leaderboard_score
│   │   ├── cloud_save.gd                ← Saves planet state via Wavedash Cloud Saves
│   │   └── rescue_timer.gd              ← 👀
│   │
│   ├── wavedash/
│   │   ├── wavedash_init.gd             ← Calls WavedashSDK.init() on game ready
│   │   ├── wavedash_identity.gd         ← WavedashSDK.get_username() → profile setup
│   │   └── wavedash_leaderboard.gd      ← Post + fetch survival time scores
│   │
│   └── ui/
│       ├── hud.gd                       ← Stamina bar, carried item icon, session timer
│       └── death_overlay.gd             ← Reads survival time, triggers tombstone drop
│
├── assets/
│   ├── models/                          ← GLTF exports from Blender, CC BY licensed
│   │   ├── player.glb
│   │   ├── dead_suit.glb
│   │   ├── berry.glb
│   │   ├── boulder.glb
│   │   ├── chute.glb
│   │   ├── signboard.glb
│   │   └── tombstone.glb
│   │
│   ├── textures/
│   ├── shaders/
│   │   ├── lake.gdshader                ← Color + displacement tied to berry count
│   │   └── berry_field_rgb.gdshader     ← RGB pulse when field is full
│   │
│   ├── audio/
│   │   ├── ambient/                     ← Planet hum, wind
│   │   └── sfx/                         ← Berry drop, boulder roll, stamina low
│   │
│   └── CREDITS.md                       ← All CC BY asset attributions listed here
│
└── LICENSE
```

---

## Wavedash Integration

### Setup
```bash
# 1. Download SDK from https://github.com/wvdsh/sdk-godot
# Place folder at res://addons/wavedash/

# 2. Register Autoload
# Project > Project Settings > Autoload
# Add WavedashSDK.gd as "WavedashSDK"
# IMPORTANT: Must be FIRST in autoload list

# 3. Export HTML5
# Project > Export > Web
# Enable Threads support
# Export output to ./exports/web/
```

### wavedash.toml
```toml
game_id = "YOUR_GAME_ID_HERE"
upload_dir = "./exports/web"

[godot]
version = "4.5-stable"
```

### SDK Usage in Terra Engine
```gdscript
# wavedash_init.gd — runs on game start
func _ready():
    WavedashSDK.backend_connected.connect(_on_connected)
    WavedashSDK.init({"debug": true})
    WavedashSDK.ready_for_events()

func _on_connected(_payload):
    print("Playing as: ", WavedashSDK.get_username())

# leaderboard.gd — posts survival time on death
func post_survival_time(seconds: int):
    var response = await WavedashSDK.post_leaderboard_score(
        "survival_time",
        seconds,
        true
    )
    if response.success:
        print("Leaderboard rank: ", response.data.globalRank)
```

### What Wavedash Handles For You
- Player identity and username
- Leaderboard (survival time scores)
- Cloud saves (planet state persistence)
- Multiplayer lobbies (co-op session creation)
- Multiplayer networking (player sync)

---

## Deploy to Wavedash

```bash
# Install Wavedash CLI
npm install -g @wavedash/cli

# Authenticate
wavedash login

# Deploy
wavedash upload
wavedash publish
```

---

## Running Locally

```bash
git clone https://github.com/tobiawolaju/terra-engine
cd terra-engine

# Open in Godot 4
# File → Open Project → select project.godot

# Export HTML5
# Project → Export → Web → Export Project → ./exports/web/
```

---

## Asset Credits

All 3D assets used under Creative Commons CC BY 4.0 license.
Full credits in `/assets/CREDITS.md`

---

## Jam Submission

- **Jam:** Gamedev.js Jam 2026
- **Theme:** Machines
- **Challenges:** Deploy to Wavedash · Open Source by GitHub · YouTube Playables
- **Submitted by:** [@tobiawolaju](https://github.com/tobiawolaju)

---

## License

MIT — see `LICENSE` for details.

Open source. Read the code. The answers are in there.

---

*Built in 2 days. Dedicated to every Terraformer who didn't make it.*
