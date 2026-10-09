# 05 — NPC population

**Goal:** create ~1,000 NPCs with households, homes, jobs/schools and friends. No movement yet.
**Depends on:** 03.

## Build
NPCs are plain data in an array indexed by id — **not one Node per NPC**.

`NPC` fields: `id` (shown as `npc_000`), `household_id`, `home_id`, `occupation` (`WORKER` | `STUDENT` | `NONE`), `work_id` (-1 if none), `school_id` (-1 if none), `friends: Array[int]`, `pos: Vector2` (tiles, float). Later specs add fields.

Generation — all through `Rng`, in exactly this order:
1. **Households:** sizes 1–5 with weights 30 / 30 / 20 / 15 / 5 %, until `population` is reached (trim the last one).
2. **Homes:** each household goes to a random home with enough free capacity.
3. **Occupation:** 15 % STUDENT, 65 % WORKER, 20 % NONE.
4. **Jobs:** each worker gets a random building with a free job slot.
5. **Schools:** each student gets the nearest school to their home.
6. **Friends:** each NPC gets 3–8 friends. 70 % from the same workplace or school, 30 % from anyone. Friendship is mutual; no self-friends.
7. **Cars:** 60 % of households own one car (used in spec 09).

Start: every NPC is inside its home at Monday 00:00.

Drawing: one dot per NPC at `pos` (grey for now). Use `MultiMeshInstance2D` or a single `_draw`, not 1,000 sprites.

## Config keys
`household_size_weights` · `occupation_shares` · `friends_min` 3 · `friends_max` 8 · `friends_same_place_share` 0.7 · `car_ownership_share` 0.6

## Done when
- `test_population`: count == `population`; no home over capacity; no job over its slots; every friendship mutual.
- `test_population`: same seed twice → identical population (compare a serialized dump).
- On screen: dots sit inside home buildings.
