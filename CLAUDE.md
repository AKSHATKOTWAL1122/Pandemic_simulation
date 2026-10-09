# NPC Epidemic City

Godot epidemic simulation: ~1,000 NPCs live in an original 256 × 256 tile city, and a virus spreads between them (SEIR). See `specs/00-overview.md`.

## Sources of truth
1. `specs/` — the plan. **Wins over everything else.**
2. `context.txt` — reference transcript the project is based on. Background only; kept local, not in git.

## How to work
- Build **one spec at a time, in number order**. Don't start spec N+1 until every "Done when" check in spec N passes. The only exception is the parallel lanes below.
- Before coding, read `specs/00-overview.md` and the current spec.
- Build only what the spec says. Anything under "Out of scope" in `00-overview.md` must not be built, even if it seems helpful.
- If a spec is unclear or conflicts with another, stop and ask. Write the answer into the spec file before coding.
- When a spec is done, report what was built and how each "Done when" check was verified.
- Never weaken a test to make it pass.

## Parallel lanes
After spec 03 is merged to `main`, three lanes may run at the same time, each in its own git worktree and branch:

| Lane | Branch | Specs | Touches |
|---|---|---|---|
| A | `lane-a` | 04 | `scripts/world/paths.gd`, `tests/test_paths.gd` |
| B | `lane-b` | 05 → 06 → 07 | `scripts/npc/`, `tests/test_population.gd`, `test_timetable.gd`, `test_desires.gd` |
| C | `lane-c` | 15 | `analysis/` only (build against fake CSVs in the spec 14 format) |

Rules for lane sessions:
- Only touch your lane's files, plus adding your own keys to `config/default.json`. Don't edit other lanes' files or the specs of other lanes.
- Don't edit `scripts/core/sim.gd`; wiring systems into the tick happens on `main` after merging.
- Commit on your branch when your specs' checks pass. Merge order into `main`: A, then B, then C, with the full test suite run after each.
- Specs 08–14 are one chain and are built on `main` after the lanes merge.

## Code rules
- Godot 4 (latest stable), GDScript with static types everywhere.
- NPCs and cars are plain data in arrays indexed by id — not one Node each. Draw them with `MultiMeshInstance2D` or a single `_draw`.
- **Determinism:**
  - All randomness goes through the `Rng` autoload. Never call `randi()`, `randf()`, `Array.shuffle()` or `pick_random()`.
  - Iterate NPCs, cars, buildings and pairs in id / sorted order.
  - Sim logic never reads wall-clock time and never depends on frame rate.
- Every tunable number lives in `config/default.json` or an experiment file, never hard-coded.
- Units: positions in tiles (1 tile = 4 m), time in ticks (`tick_seconds` game seconds each).

## Commands
- Run: `godot --path .`
- Tests: `godot --headless --path . --script res://tests/run_all.gd`
- Experiment: `godot --path . -- --experiment experiments/baseline.json`
- Make the map: `python tools/make_map.py`
- Analysis: `python analysis/seir_curves.py output/baseline`

## Layout
`config/` defaults · `data/` map + buildings · `scenes/` · `scripts/{core,world,npc,sim,ui}` · `tests/` · `experiments/` · `output/` (generated) · `analysis/` (Python) · `tools/` · `specs/`
