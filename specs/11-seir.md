# 11 — SEIR infection

**Goal:** the virus: states, transmission and timers.
**Depends on:** 10.

## Build
`Epidemic` (`scripts/sim/epidemic.gd`), run by `Simulation.step` after `ContactTracker`.

States (`NPC.Health`): `S` (Susceptible), `E` (Exposed), `I` (Infected), `R` (Recovered). Flag `immune_forever`: stays in R permanently (set by spec 13).
NPC fields: `health`, `health_since_tick`, `infected_by` (-1 if none), `first_infected_tick` (-1 if never), `immune_forever`.

Each tick, in this order:
1. **Transmission.** For each in-range pair from spec 10 (in sorted order) where one is `I` and the other is `S`:
   - `p = transmission_prob_per_min`; if `in_car`, `p *= car_transmission_multiplier`.
   - `p_tick = 1 − (1 − p) ^ (tick_seconds / 60)`.
   - If `Rng.chance(p_tick)`: the S NPC becomes `E`, `infected_by` = the I NPC. Record an infection event (spec 14) with the infected NPC's position and building.
   - NPCs that become E this tick can't infect anyone this tick.
2. **Timers** (fixed lengths, not random):
   - `E` → `I` after `incubation_days`.
   - `I` → `R` after `infection_days`.
   - `R` → `S` after `immunity_days`, unless `immune_forever`.
3. **Counts:** store S, E, I, R totals for the tick.

Exposed NPCs do **not** transmit. Only I does.
Manual infection (click, or patient zero): `Simulation.infect(id)` sets the NPC straight to `I` and logs an event with `infector` -1 and tick = the coming tick.

Events: `Epidemic.events` collects infections; after each tick `Simulation` calls every `listeners` callable with `(tick, contact_events, infection_events)` (exporter, overlay) and then clears them.

Counts: `Epidemic.counts` (S, E, I, R; R includes immune_forever) and `immune_forever_count`.

State colours: S `#7A8CA5` · E `#F2C14E` · I `#D7263D` · R `#3BB273` · immune_forever `#2E86AB`.

## Calibration
The reference's 0.1 %/min dies out in this city (5 patient zeros → 2 infections in 10 days): its contacts are much denser. Measured over 14 days with 5 patient zeros:

| p per min | 14-day result | Reference regime |
|---|---|---|
| 0.005 | slow growth, 95 infected by day 14 | flat |
| 0.02 | peak 59 % on day 8, then falls | — |
| **0.05** | peak 82 % on day 6, resurges as immunity fades | baseline endemic |
| 0.1 | peak 91 %, then extinct | pandemic |

So the default is 0.05. Recalibrate if the city, population or behaviour changes.

## Config keys (under `virus`)
`infection_radius_m` 2.0 · `transmission_prob_per_min` 0.05 · `incubation_days` 1 · `infection_days` 3 · `immunity_days` 5 · `car_transmission_multiplier` 0.1

## Done when
- `test_seir`: with p = 1, an S next to an I for one tick becomes E.
- `test_seir`: E → I exactly after the incubation time; I → R after 3 days; R → S after 5 days; `immune_forever` never leaves R.
- `test_seir`: p = 0 → no infections; in a car with multiplier 0 → no infections.
- `test_seir`: Exposed NPCs don't transmit.
- `test_seir`: 5 patient zeros in the real city infect others within 10 days (daily counts printed).
- On screen: infect one NPC and watch red spread over the days.
