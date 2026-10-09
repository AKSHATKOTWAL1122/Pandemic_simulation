# 11 — SEIR infection

**Goal:** the virus: states, transmission and timers.
**Depends on:** 10.

## Build
States: `S` (Susceptible), `E` (Exposed), `I` (Infected), `R` (Recovered). Flag `immune_forever`: stays in R permanently (set by spec 13).
NPC fields: `state`, `state_since_tick`, `infected_by` (-1 if none).

Each tick, in this order:
1. **Transmission.** For each in-range pair from spec 10 (in sorted order) where one is `I` and the other is `S`:
   - `p = transmission_prob_per_min`; if `in_car`, `p *= car_transmission_multiplier`.
   - `p_tick = 1 − (1 − p) ^ (tick_seconds / 60)`.
   - If `Rng.chance(p_tick)`: the S NPC becomes `E`, `infected_by` = the I NPC. Record an infection event (spec 14).
   - NPCs that become E this tick can't infect anyone this tick.
2. **Timers** (fixed lengths, not random):
   - `E` → `I` after `incubation_days`.
   - `I` → `R` after `infection_days`.
   - `R` → `S` after `immunity_days`, unless `immune_forever`.
3. **Counts:** store S, E, I, R totals for the tick.

Exposed NPCs do **not** transmit. Only I does.
Manual infection (click, or patient zero): set the NPC straight to `I`.

State colours: S `#7A8CA5` · E `#F2C14E` · I `#D7263D` · R `#3BB273` · immune_forever `#2E86AB`.

## Config keys (under `virus`)
`infection_radius_m` 2.0 · `transmission_prob_per_min` 0.001 · `incubation_days` 1 · `infection_days` 3 · `immunity_days` 5 · `car_transmission_multiplier` 0.1

## Done when
- `test_seir`: with p = 1, an S next to an I for one tick becomes E.
- `test_seir`: E → I exactly after the incubation time; I → R after 3 days; R → S after 5 days; `immune_forever` never leaves R.
- `test_seir`: p = 0 → no infections; in a car with multiplier 0 → no infections.
- On screen: infect one NPC and watch red spread over the days.
