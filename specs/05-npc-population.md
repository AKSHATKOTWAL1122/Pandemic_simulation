# 05 — NPC population

**Goal:** create ~1,000 NPCs with households, homes, jobs/schools and friends. No movement yet.
**Depends on:** 03.

## Build
NPCs are plain data in an array indexed by id — **not one Node per NPC**.

`NPC` (`scripts/npc/npc.gd`, `RefCounted`) fields: `id` (shown as `npc_000` by `label()`), `household_id`, `home_id`, `occupation` (`NPC.Occupation.STUDENT` | `WORKER` | `NONE`), `work_id` (-1 if none), `school_id` (-1 if none), `friends: Array[int]` (sorted), `pos: Vector2` (tiles, float). Later specs add fields.

`Household` (`scripts/npc/household.gd`): `id`, `home_id`, `members: Array[int]`, `has_car`.

API `Population` (`scripts/npc/population.gd`):
- `Population.generate(rng: SeededRng, buildings: BuildingRegistry, config: ConfigStore) -> Population` — fields `npcs: Array[NPC]`, `households: Array[Household]`, both indexed by id.
- `households_with_car() -> Array[int]` — used by spec 09 to create the cars.
- `serialize() -> String` — deterministic dump of every household and NPC.
- `Population.random_point_in(rng, rect: Rect2i) -> Vector2` — random float position inside a building rect.

Generation — all through `Rng`, in exactly this order:
1. **Households:** sizes 1–5 with weights 30 / 30 / 20 / 15 / 5 %, until `population` is reached (trim the last one). NPC ids are given out household by household.
2. **Homes:** each household (id order) goes to a random home (uniform over buildings) with enough free capacity.
3. **Occupation:** 15 % STUDENT, 65 % WORKER, 20 % NONE — one weighted draw per NPC, id order.
4. **Jobs:** each worker (id order) gets a random building (uniform over buildings) with a free job slot.
5. **Schools:** each student gets the nearest school to their home (centre to centre; ties → lowest id). No draws.
6. **Friends:** each NPC gets 3–8 friends. First every NPC draws a target in [3, 8] (id order). Then, in id order, each NPC adds friends until it has its target: each pick is from the same workplace or school with probability 0.7 (workers and students only), otherwise from anyone; if nobody at the place can take another friend, the pick falls back to anyone. Friendship is mutual; no self-friends; nobody goes above 8 (friends made by others count toward the target). Each pick tries 20 random candidates, then picks from the full list of valid ones.
   Note: workers are spread over ~230 job buildings (~2.8 per building), so most workers' places are too small for 70 % of their friends; the real same-place share is ~40 % overall and ~60 % at places with ≥ 30 people.
7. **Cars:** 60 % of households own one car (`Household.has_car`, one draw per household). The car objects are spec 09.
8. **Positions:** each NPC gets a random point inside its home's rect.
9. **Timetable jitter** (spec 06) and 10. **Needs** (spec 07) are drawn after this, in the same pass.

Start: every NPC is inside its home at Monday 00:00.

Drawing: one dot per NPC at `pos` (grey for now). Use `MultiMeshInstance2D` or a single `_draw`, not 1,000 sprites. *Built in spec 08* (this spec ran in parallel lane B, which can't touch the scene).

## Config keys
`household_size_weights` · `occupation_shares` · `friends_min` 3 · `friends_max` 8 · `friends_same_place_share` 0.7 · `car_ownership_share` 0.6

## Done when
- `test_population`: count == `population`; no home over capacity; no job over its slots; every friendship mutual.
- `test_population`: same seed twice → identical population (compare a serialized dump).
- `test_population`: every NPC's `pos` is inside its home's rect. (Replaces the on-screen check "dots sit inside home buildings": NPC drawing is built with movement in spec 08.)
