# 12 — Live UI

**Goal:** watch and control a run.
**Depends on:** 11.

## Build
Top bar:
- Day and time.
- Pause / play (Space).
- Speed: 1, 10, 60 ticks per frame, and Max (as many ticks as fit in 16 ms). Keys 1–4.

Click an NPC (nearest within 8 px) → inspector:
id, state and time in state, occupation, home, work/school, current activity and destination, contact_count, infected_by. Button **Infect** (sets it to I).

Click a building → panel: id, purposes, people inside now, button **Close / Open**.

Live SEIR chart (bottom panel): 4 lines, x = days, y = % of population, updated every game hour.

Overlay toggles:
- Contact dots — blue, last 20,000 events.
- Infection dots — red, all events.
- Parked cars on / off.
- Legend: state colours (spec 11) and building colours:
  home `#D9CBA3` · workplace `#9AA5B1` · school `#F4A259` · restaurant `#E07A5F` · nightclub `#8E5FA8` · mall `#F25F5C`.

## Done when
- Every control works during a live run.
- Inspector values match the NPC's data.
- Closing a mall live makes NPCs stop entering it.
- Chart numbers match `seir.csv` (spec 14) for the same run.
