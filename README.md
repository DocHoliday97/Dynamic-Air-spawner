# Dynamic Air Spawner

Dynamic AI air threat generator for DCS missions.

This script continuously monitors airborne BLUE players and spawns OPFOR air groups in one of the configured frontline trigger zones, with threat type and scenario selected from player aircraft type, weapon profile, and distance.

## What It Does

- Spawns OPFOR aircraft dynamically while players are airborne.
- Supports both circle and polygon trigger zones.
- Can randomly choose from multiple configured spawn zones.
- Uses in-zone safety checks so spawned aircraft stay inside the configured zone.
- Picks threat aircraft based on player type and current loadout profile.
- Uses scenario-based loadout selection (ACM / BVR families with fallbacks).
- Forces fighter threats into BVR families when enabled.
- Scales active threat group cap with player count.
- Cleans up landed/dead threat groups automatically.
- Adds an F10 debug menu command to force a spawn when debug mode is enabled.

## Recent Changes

- Improved zone spawn reliability:
    - Better polygon point sampling.
    - Final in-zone correction for lead and wingmen.
- Updated AI routing/tasking:
    - Threat groups use Intercept tasking.
    - Waypoint 1 includes EngageTargets for Air.
- Added/expanded loadout-aware threat behavior.
- Added altitude clamp controls for spawned groups.
- Added fighter-BVR scenario forcing toggle.
- Updated and fixed L-39ZA packages:
    - Added ACM_IR package.
    - Corrected pylon indexing to stations 1, 2, 4, 5.
    - Filled previously empty ACM package.

## Files

- Air_lib.lua: aircraft definitions, scenarios, and loadout packages.
- DynamicAirSpawner.lua: runtime manager, zone logic, spawn logic, and AI task setup.

## Setup

1. Copy Air_lib.lua and DynamicAirSpawner.lua into your mission script location.
2. In the Mission Editor, create one or more trigger zones for spawning.
3. Add a mission start trigger and load scripts in this exact order:
     - DO SCRIPT FILE: Air_lib.lua
     - DO SCRIPT FILE: DynamicAirSpawner.lua
4. Start the mission and launch at least one BLUE aircraft into the air.

The script auto-starts and schedules itself. No additional function calls are required.

## Configuration

Edit these values near the top of DynamicAirSpawner.lua:

- DEBUG_MODE: enables debug messages and F10 manual spawn command.
- FRONTLINE_ZONES: list of zone names used for spawning.
- SPAWN_COOLDOWN: minimum seconds between spawns.
- SPAWN_MIN_INTERVAL and SPAWN_MAX_INTERVAL: manager tick interval range.
- MAX_ACTIVE_GROUPS: hard cap for simultaneous spawned threat groups.
- SPAWN_GROUP_OPTIONS and MAX_AIRCRAFT_PER_GROUP: spawned group size controls.
- SPAWN_ALT_MIN_M and SPAWN_ALT_MAX_M: global spawn altitude clamp.
- FORCE_FIGHTER_BVR: force fighter threats to BVR loadout families.
- CURRENT_SKILL: AI skill used for spawned units.

## Runtime Behavior

- The manager runs on a timer and checks airborne BLUE players.
- Threat groups are capped by player count and then limited by MAX_ACTIVE_GROUPS.
- Aircraft count within a spawned group is randomly selected from SPAWN_GROUP_OPTIONS and capped by MAX_AIRCRAFT_PER_GROUP. Repeating a value in SPAWN_GROUP_OPTIONS weights selection toward that group size.
- Threat type is selected from a pool and filtered by player capability.
- Spawn package is selected through Air_lib scenario/fallback logic.
- Spawned groups receive payload from the selected package and patrol/intercept toward players.

## L-39ZA Notes

L-39ZA loadouts in Air_lib use DCS station keys, not connector order.

- Outer pylons (stations 1 and 5): AAM-capable (for example R-3S, APU-60-1_R_60M).
- Inner pylons (stations 2 and 4): tank/strike stores (for example PTB_150L_L39).

Current L-39ZA package mapping in this repo is aligned to those station rules.

## Troubleshooting

- No spawns:
    - Verify each configured zone name exists in FRONTLINE_ZONES.
    - Confirm scripts were loaded in order: Air_lib first, then DynamicAirSpawner.
    - Confirm at least one BLUE player is airborne.
- No package for aircraft:
    - Check Air_lib has a matching scenario/loadout for that aircraft.
    - Confirm pylon station indices match DCS station numbering for that unit.
- Spawn outside zone:
    - Re-check zone shape and ensure zone data is valid.
    - Keep DEBUG_MODE on and review zone sample debug lines.

## If You Use an External Runtime Copy

If you also run a separate mission script copy (for example in Saved Games mission script folders), keep that copy synced with this repository version to avoid behavior mismatches.

## Requirements

- DCS World.
- Mission scripting enabled.
- Mission Editor access for trigger and script setup.

## License

MIT License. See LICENSE.

## Credits

Created by DocHoliday97 and contributors.