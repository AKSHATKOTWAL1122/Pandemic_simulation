# 00 — Overview

## What we're building
An epidemic simulation inside an original tile-based city, made in Godot.
About 1,000 NPCs live daily lives (timetable + desires). A virus spreads between them using the SEIR model.
You play the epidemiologist: pick patient zero, close buildings, immunize part of the population, tune the virus, and compare the infection curves.

Based on `context.txt` (reference transcript). If a spec and `context.txt` disagree, **the spec wins**.

## In scope
- 256 × 256 tile city, original layout. Tiles: water, road, sidewalk, building. Islands joined by bridges.
- Buildings with purposes: home, workplace, school, restaurant, nightclub, mall (or a mix). Two malls.
- ~1,000 NPCs with households, friends, a timetable and a desire system.
- Walking and household cars.
- SEIR infection with five virus parameters.
- Live view: map, NPCs coloured by state, SEIR chart, contact/infection dots, click to infect.
- Experiments: patient zero, closures, immune share, virus parameters. Seeded, many runs.
- CSV export and Python analysis (curves, contact graph, transmission tree, heatmaps).

## Out of scope — do not build
Hospital, death, vaccination, buses, Uber/cabs, the 100 NPC roles list, parks, rivers/lakes layer, surface-objects layer, per-car AI, traffic collisions/lanes/lights, carjacking, masks or other control measures, a headless simulation mode (tests may still run headless).

## Decisions from the interview (2026-10-09)
| # | Topic | Decision |
|---|---|---|
| 1 | Scope | Only what `context.txt` describes. Earlier ideas dropped. |
| 2 | Map | Original city, same structure as the reference. No GTA assets. |
| 3 | Goals | All four: pick patient zero, close buildings, immunize a share, tune virus. |
| 4 | Evidence | Fixed seed + many runs per setup; show mean and spread. |
| 5 | Run mode | Visual only, with speed-up. |
| 6 | Trade-off | Accept slow batches. |
| 7 | NPC brain | Timetable + desires. |
| 8 | Indoors | NPCs have real positions inside building tiles; same radius rule. |
| 9 | Cars | Contacts in cars count, with lower transmission probability. |
| 10 | Platform | Godot. |
| 11 | Analysis | Live basics in Godot; everything logged to CSV; Python draws the rest. |
| 12 | Population | ~1,000. |
| 13 | Process | Many very small specs, built one at a time. |

## Units (every spec uses these)
- 1 tile = 4 m. Map = 1,024 m × 1,024 m.
- 1 tick = `tick_seconds` game seconds (default 60).
- A run starts on Monday 00:00, day 0.

## Where numbers come from
From `context.txt`: 256 × 256 tiles, 2 m radius, 0.1 %/min transmission, 1-day incubation, 3-day infection, 5-day immunity, ~1,000 NPCs, two malls.
Every other number in these specs is a **starting default** — tune it in config.

## Build order
| Spec | Builds | 
|---|---|
| 01-project-setup | Godot project, config, clock, seeded RNG |
| 02-tile-map | 256 × 256 map file, drawing, camera |
| 03-buildings | Buildings, purposes, entrances |
| 04-pathfinding | Walk and drive routes |
| 05-npc-population | 1,000 NPCs, households, friends, jobs |
| 06-npc-timetable | Sleep / work / school blocks |
| 07-npc-desires | Free-time choices |
| 08-npc-movement | Walking and moving inside buildings |
| 09-cars | Household cars |
| 10-contacts | Contact detection and events |
| 11-seir | Infection states and transmission |
| 12-ui-live | Controls, inspector, live chart, overlays |
| 13-experiments | Experiment files, seeds, batch runs |
| 14-data-export | CSV output |
| 15-analysis-python | Charts from CSVs |
