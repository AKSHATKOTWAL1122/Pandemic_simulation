# 01 — Project setup

**Goal:** an empty Godot project that runs, with the config, sim clock and seeded RNG every later spec uses.
**Depends on:** nothing.

## Build
Folder layout:
```
project.godot
config/default.json
data/              map.png, buildings.json (specs 02–03)
scenes/main.tscn
scripts/core/      config.gd, sim_clock.gd, rng.gd, sim.gd
scripts/world/     (02–04)
scripts/npc/       (05–09)
scripts/sim/       (10–11, 13–14)
scripts/ui/        (12)
experiments/       (13)
output/            run results (14)
analysis/          Python (15)
tools/             one-off scripts
tests/             run_all.gd + test_*.gd
```

Autoloads:
- `Config` — loads `config/default.json` into a Dictionary. `Config.get_value(key)` errors if the key is missing.
- `SimClock` — `tick: int`, and helpers `day()`, `weekday()` (0 = Mon), `hour()`, `minute()`, all derived from `tick * tick_seconds`. `advance()` adds 1 and emits `ticked(tick)`.
- `Rng` — one `RandomNumberGenerator` seeded from `seed`. Helpers: `randi_range`, `randf`, `chance(p)`, `pick(array)`, `shuffle(array)`, `weighted_pick(weights)`.

`Sim` node in `main.tscn`: in `_process`, if not paused, runs `ticks_per_frame` ticks. Each tick calls the systems in a fixed order (filled in by later specs) and then `SimClock.advance()`.

Test runner: `tests/run_all.gd` extends `SceneTree`, runs every `tests/test_*.gd`, prints pass/fail, exits with code 0 or 1.

## Config keys
`seed` 12345 · `tick_seconds` 60 · `days` 30 · `population` 1000 · `ticks_per_frame` 1

## Not in this spec
Map, NPCs, UI beyond a time label.

## Done when
- `main.tscn` runs with no errors and a label shows `Day 0 Mon 00:00`, advancing.
- `test_rng`: two `Rng` instances with the same seed give the same 1,000 values; different seeds give different values.
- `test_clock`: tick 1440 at 60 s/tick is `Day 1 Tue 00:00`.
- `godot --headless --path . --script res://tests/run_all.gd` exits 0.
