# 12 — Live UI

**Goal:** watch and control a run.
**Depends on:** 11.

## Build
Top bar:
- Day and time.
- Pause / play (Space).
- Speed: 2, 10, 60 ticks per second, and Max (as many ticks as fit in 16 ms per frame). Keys 1–4. Default 10.
- Live S / E / I / R counts.

Built in code by `scripts/ui/hud.gd` (CanvasLayer); world overlay `scripts/ui/event_overlay.gd`; chart `scripts/ui/seir_chart.gd`. The window scales with its size (`canvas_items` stretch).

Left-click an NPC (nearest within 8 screen px) → inspector:
id, state and time in state, occupation, home, work/school, current activity and destination, contact_count, infected_by. Button **Infect** (sets it to I).

Click a building → panel: id, purposes, people inside now (and how many infected), button **Close / Open** (disabled for homes, as in spec 13).

Live SEIR chart (bottom panel): 4 lines, x = days, y = % of population, updated every game hour.

Overlay toggles:
- Contact dots — blue, last 20,000 events.
- Infection dots — red, all events.
- Parked cars on / off.
- Legend: state colours (spec 11) and building colours:
  home `#D9CBA3` · workplace `#9AA5B1` · school `#F4A259` · restaurant `#E07A5F` · nightclub `#8E5FA8` · mall `#F25F5C`.

## Done when
`tests/ui_smoke.gd` drives the real scene with synthetic clicks and keys, in a window (headless windows are 64 × 64 px, so panels would cover the map):
`godot --path . --script res://tests/ui_smoke.gd [-- <screenshot folder>]` — exits 0 when all pass.
- Clicking NPC 0 selects it and the inspector shows it; **Infect** sets it to I.
- Space pauses / resumes; keys 4 and 2 set Max and 10 ticks/s.
- Clicking a mall selects it; **Close** closes it; nobody enters it over the next 3 days.
- The chart has one sample per game hour and its last I value matches `Epidemic.counts` (the same counts `seir.csv` writes in spec 14).
