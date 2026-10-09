# 07 — NPC desires

**Goal:** in free time, NPCs choose where to go based on their needs.
**Depends on:** 06.

## Build
Needs (0–100, float, start random 0–50): `hunger`, `fun`, `social`, `shopping`. Stored as `NPC.needs: PackedFloat64Array`, indexed by `Desires.Need` (HUNGER, FUN, SOCIAL, SHOPPING). Starting values are drawn by `Desires.init_needs(npc, rng, need_start_range)`, called by `Population.generate` as spec 05 step 10 (after jitter).

Growth per game hour while not asleep: hunger +6, fun +4, social +4, shopping +2. No growth while sleeping.

Decision — runs when the NPC is in free time, not travelling, and its current stay has ended:
1. Take the highest need that is ≥ 50 (ties: HUNGER, FUN, SOCIAL, SHOPPING order).
2. Map it to a destination:
   | Need | Destination |
   |---|---|
   | hunger | restaurant (70 %) or home (30 %) |
   | fun | nightclub if 19:00–03:00, else mall |
   | social | a random friend's home (50 %), restaurant (25 %), nightclub (25 %) |
   | shopping | mall |
3. Candidates: buildings with that purpose that are **open**. Pick one of the 5 nearest (straight-line, from `npc.pos` to the building's centre; ties → lowest id), weighted by 1 / distance (distances under 1 tile count as 1). A friend's home is one random friend's `home_id` — no candidate list; it doesn't need the friend to be there. "Home" for hunger is the NPC's own home. The random draw for the destination kind (restaurant/home, friend/restaurant/nightclub) happens before the candidate pick.
4. If no open candidate, try the next highest need ≥ 50.
5. If no need is ≥ 50, or none of them has an open candidate, go home (or stay home), `need` −1.

Stay length: restaurant 60 min, nightclub 120, mall 90, friend's home 120, home 60 (then decide again).
At the end of a stay, the need that caused the visit drops to 0.

API `Desires` (`scripts/npc/desires.gd`, `RefCounted`) — decides *where* and *for how long*; moving there is spec 08:
- `Desires.new(config: ConfigStore, buildings: BuildingRegistry, npcs: Array[NPC], rng: SeededRng)` — `npcs` is the whole population (for friends' homes); `rng` is the shared `Rng`.
- `grow(npc, minutes: float, asleep: bool)` — call every tick with `tick_seconds / 60` minutes; `asleep` = the timetable block is SLEEP. Capped at 100.
- `choose_destination(npc, tick) -> {building_id, need, place, stay_minutes, stay_ticks}` — `need` is a `Desires.Need` or −1 (going home with no need ≥ 50); `place` is `"restaurant" | "nightclub" | "mall" | "friend_home" | "home"`. Uses `npc.pos` for distances.
- `finish_stay(npc, need)` — call when the stay ends (need −1 does nothing). If a timetable block cuts a stay short, spec 08 decides whether to call it.
- Constants `Desires.RESTAURANT`, `NIGHTCLUB`, `MALL`, `FRIEND_HOME`, `HOME`; `Desires.need_name(need)`.

## Config keys
`need_growth_per_hour` {hunger 6, fun 4, social 4, shopping 2} · `need_threshold` 50 · `need_start_range` [0, 50] · `stay_minutes` {restaurant 60, nightclub 120, mall 90, friend_home 120, home 60} · `candidate_count` 5 · `hunger_restaurant_share` 0.7 · `social_destination_weights` {friend_home 50, restaurant 25, nightclub 25} · `nightclub_hours` [19, 3]

## Done when
- `test_desires`: hunger 80, others low, Sat 12:00 → goes to a restaurant or home.
- `test_desires`: one mall closed → shopping picks the other mall; both closed → next need, or home.
- A 7-day run prints visitors per mall per day, and every day has visitors. Built as `test_desires::test_seven_day_mall_visits` without movement (spec 08 isn't built yet): timetable + desires are evaluated every game hour, NPCs arrive instantly, and every mall must have visitors every day.
- `test_desires` (extra): fun → nightclub 19:00–03:00 else mall; social destinations and shares; highest need first; picks only among the 5 nearest; growth, sleep and the 100 cap; `finish_stay` reset; same seed → same choices.
