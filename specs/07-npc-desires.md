# 07 — NPC desires

**Goal:** in free time, NPCs choose where to go based on their needs.
**Depends on:** 06.

## Build
Needs (0–100, float, start random 0–50): `hunger`, `fun`, `social`, `shopping`.

Growth per game hour while not asleep: hunger +6, fun +4, social +4, shopping +2. No growth while sleeping.

Decision — runs when the NPC is in free time, not travelling, and its current stay has ended:
1. Take the highest need that is ≥ 50.
2. Map it to a destination:
   | Need | Destination |
   |---|---|
   | hunger | restaurant (70 %) or home (30 %) |
   | fun | nightclub if 19:00–03:00, else mall |
   | social | a random friend's home (50 %), restaurant (25 %), nightclub (25 %) |
   | shopping | mall |
3. Candidates: buildings with that purpose that are **open**. Pick one of the 5 nearest (straight-line), weighted by 1 / distance. A friend's home doesn't need the friend to be there.
4. If no open candidate, try the next highest need ≥ 50.
5. If no need is ≥ 50, go home (or stay home).

Stay length: restaurant 60 min, nightclub 120, mall 90, friend's home 120, home 60 (then decide again).
At the end of a stay, the need that caused the visit drops to 0.

## Config keys
`need_growth_per_hour` · `need_threshold` 50 · `stay_minutes` · `candidate_count` 5

## Done when
- `test_desires`: hunger 80, others low, Sat 12:00 → goes to a restaurant or home.
- `test_desires`: one mall closed → shopping picks the other mall; both closed → next need, or home.
- A 7-day run prints visitors per mall per day, and every day has visitors.
