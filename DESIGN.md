# SafeRoute

Status 2026-09-29: written against Darktide 1.13.0 source. Static checks and the offline harness
pass. In game (Spillway, 1.13.0, user report 2026-09-29): chat reported "2 branching paths found"
and the markers showed on the roads correctly.

Release v0.1.0 (2026-09-29): source `mods/active/SafeRoute/`; Standard package
`releases/SafeRoute.zip` contains `SafeRoute.mod`, five runtime Lua files, and `README.md` under
`SafeRoute/`. SHA-256: `337119F9F3B955A9CC330CD84F2A1BECE8C06AB50568BC71A750184B30846CF8`.
Source hash manifest: `releases/SafeRoute.source.sha256`; ZIP hash record:
`releases/SafeRoute.zip.sha256`. `tests/` and `DESIGN.md` are development-only, not in the ZIP.
`tools/validate.ps1` and `tools/release-mod.ps1 -Mod SafeRoute` passed (LuaLS: zero diagnostics;
LuaJIT and Lua 5.5 parses passed). Offline LuaJIT harness: 500 seeds, zero failures.
In-game coverage is the Spillway marker report above; gas avoidance, second seed, other missions,
and enable/disable or mission-transition cleanup remain untested. Roll back by removing
`mods/SafeRoute/` and its `mod_load_order.txt` entry; development source stays in this directory.

## What it does
Spillway (zone `depths`, 1.13.0) has branching paths. At each fork the mission keeps one road and
the others lead into the pox gas, locked doors or extra tasks. SafeRoute puts a green "SAFE ROUTE"
marker a few metres into the kept road (plus small markers every 12 m along it) and a red
"WRONG WAY" marker into each other road. Markers show through walls within the set range. The mod
has no mission names: it works on any level whose main path defines crossroads.

## How the client knows the road (source evidence, 1.13.0)
- `MainPathManager.setup_for_level` (`scripts/managers/main_path/main_path_manager.lua:34-50`) calls
  `Crossroad.generate_road_choices(crossroads, level_seed)` and then removes the unused roads from
  the main path. The choice is `math.next_random` over the crossroad ids in sorted order
  (`scripts/managers/main_path/utilities/crossroad.lua:7-26`), so it is deterministic per seed.
- `Managers.state.main_path` is created on clients too
  (`gameplay_init_step_navigation.lua:70`, no server check). The level seed on a client is the
  session seed the host sends (`state_gameplay.lua:29`, `local_data_sync_state.lua:60-65`), so the
  client computes the same choice as the server.
- Level flow asks for the choice with `FlowCallbacks.get_crossroad_road_id`
  (`script_flow_nodes/flow_callbacks.lua:2378`), which returns the same `crossroad_road_id`.
- The mod reads the choice with the nil-safe `MainPathManager:is_crossroad_segment_available`.
  Because the manager drops the unused roads, the mod runs `dofile` on the main path resource
  again (`_main_path_resource_name`, private field) to get every road's nodes. `dofile` runs the
  chunk again and returns fresh tables (HUD elements and `options_view.lua:31` rely on that).

## Assumption to confirm in game
The road the main path keeps is the gas-free one. This follows from the design (bots, pacing and
the main path all use the kept road; flow reads the same id) but the Spillway level data and flow
are not in the source dump, so it is not proven. `tests/test_routes.lua` only proves that the road
marked safe is the road the game's own stitching keeps.

Also unconfirmed: that each road's first node lies at the fork, so 8 m in lands inside the road.

## Lifecycle
- `mod.update`: a new `Managers.state.main_path` instance resets the mission state and loads the
  crossroads once. Markers are added once per world-markers HUD element.
- Marker ids belong to the HUD that created them; they are removed through events only while that
  HUD is still current, otherwise just forgotten (a new HUD restarts its id counter).
- Settings change, disable and unload remove the markers; update re-adds them with new settings.

## In-game test
1. Spillway, any difficulty: chat shows "SafeRoute: N branching paths found". `/saferoute` lists
   each fork and its safe road.
2. At each fork: green marker in exactly one road, red in the others; walk the green road and
   confirm no gas. Repeat on a second run (different seed) to see the choice change.
3. If the console log records info lines, it contains `[Crossroad] Using road %d at crossroad %s` lines that
   match `/saferoute`.
4. Other missions: no chat line, no markers. Toggle the mod and change a setting mid-mission.
