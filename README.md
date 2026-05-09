<div align="center">

<img src="https://raw.githubusercontent.com/tobiawolaju/Terra-engine/master/logo.png" alt="Terra Engine" width="340"/>

# Terra Engine

**Gamedev.js Jam 2026 · Theme: Machines · Open Source Track**

[![Play Now](https://img.shields.io/badge/▶%20Play%20Now-Wavedash-6c47ff?style=for-the-badge)](https://wavedash.com/playtest/terraengine/982ee9a4-d669-4112-913b-ce13fbb2a852)
[![Open Source](https://img.shields.io/badge/Track-Open%20Source-brightgreen?style=for-the-badge)](https://github.com/tobiawolaju/Terra-engine)
[![Godot 4](https://img.shields.io/badge/Engine-Godot%204.6-blue?style=for-the-badge)](https://godotengine.org/)

---

*The last Terraformer left no manual.*
*Just a body, a lake, and a machine that only works if you keep feeding it.*
*You are not here to win. You are here to hold the system together for one more minute.*

</div>

---

## Screenshots

<div align="center">

<img src="https://raw.githubusercontent.com/tobiawolaju/Terra-engine/master/assets/splashs/screenshots%20(1).png" width="48%"/> <img src="https://raw.githubusercontent.com/tobiawolaju/Terra-engine/master/assets/splashs/screenshots%20(2).png" width="48%"/>

<img src="https://raw.githubusercontent.com/tobiawolaju/Terra-engine/master/assets/splashs/screenshots%20(3).png" width="48%"/> <img src="https://raw.githubusercontent.com/tobiawolaju/Terra-engine/master/assets/splashs/screenshots%20(4).png" width="48%"/>

<img src="https://raw.githubusercontent.com/tobiawolaju/Terra-engine/master/assets/splashs/screenshots%20(5).png" width="48%"/> <img src="https://raw.githubusercontent.com/tobiawolaju/Terra-engine/master/assets/splashs/screenshots%20(6).png" width="48%"/>

<img src="https://raw.githubusercontent.com/tobiawolaju/Terra-engine/master/assets/splashs/screenshots%20(7).png" width="48%"/> <img src="https://raw.githubusercontent.com/tobiawolaju/Terra-engine/master/assets/splashs/screenshots%20(8).png" width="48%"/>

<img src="https://raw.githubusercontent.com/tobiawolaju/Terra-engine/master/assets/splashs/screenshots%20(9).png" width="32%"/> <img src="https://raw.githubusercontent.com/tobiawolaju/Terra-engine/master/assets/splashs/screenshots%20(10).png" width="32%"/> <img src="https://raw.githubusercontent.com/tobiawolaju/Terra-engine/master/assets/splashs/screenshots%20(11).png" width="32%"/>

</div>

---

## The Idea

Most survival games ask you to protect yourself.

This one asks you to **maintain a living system that is already failing.**

The planet is a machine:
- **Inputs** — berries, biomass, anything organic
- **Decay** — oxygen drains on a fixed clock, no pausing
- **Output** — the HUD and world state show you exactly how close to collapse you are
- **Failure condition** — oxygen reaches zero, score posts to the global leaderboard

You are the maintenance worker, the fuel line, and the last backup process.

---

## How It Works

| What | Detail |
|---|---|
| Oxygen starts at | `50` |
| Drain rate | `-2` every `5s` |
| Berry feed | Drop in lake → `5s` absorb → `+10 oxygen` |
| Alien body bonus | One-time push into lake → `+45 oxygen` |
| Fail state | Score (survival time) posts to global leaderboard |

---

## Gameplay

- Third-person camera-relative movement
- Pick up and carry physics objects
- Water slows movement to 50%
- Auto leap-assist on ground movement
- Death overlay + orbiting camera on game over
- Touch joystick support (mobile-ready HUD)

**Controls**

| Input | Action |
|---|---|
| `W A S D` | Move |
| `Space` | Jump |
| `P` | Pick up / Drop |
| `LMB + drag` | Orbit camera |
| `Scroll` | Zoom |

---

## Theme: Machines

The game treats the planet as a **biological machine** — inputs, throughput, decay, output.

Every mechanic maps to a mechanical concept:
- The lake is the reactor
- Berries are fuel
- Oxygen is the system health metric
- You are the operator keeping it from shutting down

There is no enemy. The machine is the challenge.

---

## Online (Wavedash SDK)

- Fetches current username on load
- Posts `survival_time` score to global leaderboard on death
- Leaderboard scene reads live top entries
- Full Wavedash SDK integration via `addons/wavedash/`

---

## Open Source

All gameplay logic is readable GDScript. Key files:

```
scripts/player/player_controller.gd   — movement, carry, death
scripts/world/berryspawner.gd         — berry spawn logic
scripts/world/pickable.gd             — physics pickup system
scripts/wavedash/wavedash_init.gd     — SDK init + score post
```

Export settings included. Reproducible web build via Godot 4.6 HTML5 export.

---

## Run It Yourself

```bash
# Clone
git clone https://github.com/tobiawolaju/Terra-engine.git

# Open in Godot 4.6.x
# Run default scene: scenes/splash.tscn
```

Web export preset already configured to `Builds/index.html`.

---

## Credits

See [`assets/CREDITS.md`](assets/CREDITS.md) for full asset attributions.

---

<div align="center">

Built in jam time. Shipped on MTN. Kept alive by anyone willing to carry one more berry.

[![Play Terra Engine](https://img.shields.io/badge/▶%20Play%20Terra%20Engine-Now-6c47ff?style=for-the-badge)](https://wavedash.com/playtest/terraengine/982ee9a4-d669-4112-913b-ce13fbb2a852)

</div>
