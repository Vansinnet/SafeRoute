# SafeRoute

Status 2026-09-29: written against Darktide 1.13.0 source. Static checks and the offline harness
pass. In game (Spillway, 1.13.0, user report 2026-09-29): chat reported "2 branching paths found"
and the markers showed on the roads correctly.

Release v1.0.0 (2026-09-29): source `mods/active/SafeRoute/`; Standard package
`releases/SafeRoute.zip` contains `SafeRoute.mod`, five runtime Lua files, and `README.md` under
`SafeRoute/`. SHA-256: `A1C82CE6DDE30700CF5FA074DCA7FD137E51F42AE6E0638731AF941C0639972A`.
Source hash manifest: `releases/SafeRoute.source.sha256`; ZIP hash record:
`releases/SafeRoute.zip.sha256`. `tests/` and `DESIGN.md` are development-only, not in the ZIP.
`tools/validate.ps1` and `tools/release-mod.ps1 -Mod SafeRoute` passed (LuaLS: zero diagnostics;
LuaJIT and Lua 5.5 parses passed). Offline LuaJIT harness: 500 seeds, zero failures.
In-game coverage is the Spillway marker report above; gas avoidance, second seed, other missions,
and enable/disable or mission-transition cleanup remain untested. Roll back by removing
`mods/SafeRoute/` and its `mod_load_order.txt` entry; development source stays in this directory.

## Recorded guide routes (v1.2.0, 2026-10-04; works in game)
Nav-mesh A* guide paths (v1.1.0) still ran through walls and floors in game; v1.1.0 shipped with
`LOG_GUIDE_PATHS = false`, so the runs gave no diagnostics. Replaced with recorded routes, the
method Markers Improved AIO uses for its Martyr's Skull guide (`referensmoddar/markers_aio/.../
martyrs_skull_markers.lua`: hand-placed coordinates per mission, shown as world markers with the
HUD line-of-sight check).
- `/saferoute_record` toggles recording: the player's foot position (`Unit.world_position(unit, 1)`)
  every 1 m (max 600 points). On stop, the route is assigned to the road whose entry marker is
  closest to its last point, shown immediately for the session, and written to the console log as
  `[MOD][SafeRoute][INFO] record "<main path resource>" crossroad "<id>" road <id> (...): { ... }`.
- Logged routes are copied into `recorded_routes.lua`, keyed by main path resource, crossroad id
  and road id. Guide dots are drawn only from recorded routes (every 2 m, 0.6 m above the recorded
  feet positions, line-of-sight fade); roads without a route get no dots.
- Removed: the nav-mesh A* code, its `MainPathManager.destroy` hook and the `LOG_GUIDE_PATHS` probe.
- Spillway has 5 roads (A: 2, B: 3). All five recorded 2026-10-04 (solo, game 1.13.0) and copied
  from the console log into `recorded_routes.lua` (A1 22.5 m, A2 28.6 m, B1 39.9 m, B2 32.7 m,
  B3 38.8 m; B3 climbs stairs from z 14.6 to 20.6). Each recording ended 12-15 m from the road's
  computed entry marker (8 m along the road's main path), so the walked routes and the marker
  positions do not coincide; dots follow the walked route. Gabriel's call (2026-10-04): with a
  recorded route, SAFE ROUTE / WRONG WAY stand 1 m past the route's last guide dot (dots every 2 m,
  stopping 1.5 m before the end); without one they stay 8 m along the main path. Offline check on
   the five routes: marker 1.0 m after the last dot on every route. The built-in data was
   subsequently tested in game as recorded below.

- In game (2026-10-04, Spillway): Gabriel: "funkar sjukt bra" with the built-in routes and markers
  1 m past the last dot. `/saferoute_record` was then removed (its logging, session routes and
  localization); `recorded_routes.lua` keeps the five routes. The command was never committed; to
  record another map, rebuild it as described above (feet position every 1 m, assign to the road
  whose entry marker is nearest the end, log the points).

## Release v1.2.0 — 2026-10-04

- Published: https://github.com/Vansinnet/SafeRoute/releases/tag/v1.2.0 (latest, public,
  not a prerelease). `main` and tag `v1.2.0` verified at
  `2f51873b1e0100609a50f0ee6dadb749a4770b9d`; tracked worktree clean. All three assets uploaded;
  GitHub's ZIP digest matches the local SHA-256 below.
- Authoritative source: `mods/active/SafeRoute/`. Version: README and GitHub tag `v1.2.0`.
  ModID/loader paths/packages reviewed; DMF and its mod loader required. All settings/defaults
  retained. English/Swedish option, marker and command localization keys are present.
- Standard package: `releases/SafeRoute-v1.2.0/SafeRoute.zip`; eight files under `SafeRoute/`:
  `README.md`, `SafeRoute.mod`, and six runtime Lua files, including `recorded_routes.lua`.
  SHA-256: `2A3CE3237CCD1BA5F1155773A9D821D88AE148654A860E439DFE308037C145F8`.
  Source manifest: `releases/SafeRoute-v1.2.0/SafeRoute.source.sha256`; checksum:
  `releases/SafeRoute-v1.2.0/SafeRoute.zip.sha256`; notes: `release-notes.md` alongside them.
- `tools\release-mod.ps1 -Mod SafeRoute -OutputDirectory releases\SafeRoute-v1.2.0` passed:
  LuaLS zero diagnostics, LuaJIT loadfile and Lua 5.5 parse for six runtime Lua files and `.mod`.
  Final ZIP entries were listed: forward-slash paths, exactly one mod root, all eight entries'
  uncompressed hashes matching the authoritative source. Excluded `.git/`, `.gitignore`,
  `DESIGN.md` and `tests/` reviewed; no recording command/logs or development probes in payload.
- Offline harness: `tools\luajit\luajit.exe mods/active/SafeRoute/tests/test_routes.lua`:
  1000 runs (500 seeds x 2 crossroads), zero failures, guide geometry assertions pass.
  Additional LuaJIT data check: five routes, 164 finite coordinate triples, consecutive
  samples 0.8–1.2 m apart; A1 22.50 m, A2 28.62 m, B1 39.92 m, B2 32.69 m, B3 38.82 m.
  Stair route B3 gains more than 5 m. Offline evidence only.
- Engine/DMF integration reuses the existing verified marker/settings/module patterns. Removed
  all A* API calls and the teardown hook; new recording lookup and marker placement use plain
  Lua data and the existing route helpers. No new API or changed contract knowledge, so no
  LuaCATS change required. Native resource ownership/cleanup no longer applies to this version.
- Runtime coverage: local notes above document Spillway solo, Darktide 1.13.0, 2026-10-04,
  with built-in routes/marker placement working well. No new agent-run in-game test. Untested:
  options/localization surfaces, toggle/reload, mission-transition cleanup, dedicated-server
  missions, broader mission/seed coverage, universal gas avoidance. Smallest remaining test:
  install the final ZIP, check Spillway dots/LOS and toggle, then exit and start another mission.
- Rollback: reinstall the previous GitHub v1.1.0 ZIP; remove the mod and load-order entry to
  uninstall. Previous version artifacts retained under `releases/`; development source stays here.

## Guide dots from the fork (v1.1.0, 2026-10-02; historical)
Option "Guide dots from the fork" (`show_guide_dots`, default on). From each fork, dots lead along
the walkable path into every road up to its marker: green to SAFE ROUTE, red to each WRONG WAY (red
only with "Mark wrong roads"). Nothing is drawn before the fork (Gabriel: "från forken till safe
route", and red to wrong way from the fork too).
- The fork is the end of the path into the crossroad (approach, below), or each road's first node
  when no approach is found. Per road, A* on the mission nav world runs between consecutive
  waypoints (fork, then the road's main path nodes up to the marker at 8 m), with the same calls
  as `payload_extension.lua:445-519`. Waypoints are snapped with
  `NavQueries.position_on_mesh_with_outside_position` (2 m up/down/sideways); a waypoint off the
  nav mesh or a leg without a path falls back to the straight main path line. One leg runs at a
  time across frames, starting once the HUD exists. Paths are searched once per mission;
  setting changes only re-place dots.
- Dots: 26 px, 0.6 m above the nav mesh, every 2 m, stopping 1.5 m before the marker. Only the
  green path has a dot at the fork.
- Approach (path into the fork): `routes.lua` `find_approach` takes the segment before the
  crossroad's first road, skipping roads the game dropped, as `Crossroad.stitch_and_remove_unused_roads`
  does, cut at its node closest to the fork. The console log of run 1 showed the layout: fork A
  roads in segments 6-7 (stitched 5 + road + 8), fork B roads in 10-12 (stitched 9 + road + 13).
- Dots use the HUD's line-of-sight check and fade out behind walls (`SafeRoute_marker.lua`, as
  `world_marker_template_interaction.lua:741-752`; the HUD raycasts camera -> marker,
  `hud_element_world_markers.lua:441-458,725-793`). SAFE ROUTE / WRONG WAY markers never do: they
  show through walls, as in v1.0.0. The HUD raycasts at most 10 markers every 5th frame, so a dot
  can take about a second to appear after turning a corner.
- Traverse logic: `Navigation.create_traverse_logic(nav_world, {}, nil, false)`, the same layers
  and costs as the client's own (`nav_mesh_manager.lua:333-343`); hosts (solo) have no client
  traverse logic, so the mod owns one. The A* query, traverse logic and cost table are released
  from a `MainPathManager.destroy` hook: `Managers.state:destroy()` runs before
  `_destroy_nav_world` (`mission_cleanup_utilities.lua:75,87`). Also released on disable and unload.
  If the hook did not run, they are only forgotten, never touched after the nav world is gone.
- Contracts: `types/darktide/safe_route.lua`, `types/SOURCES.md` ("SafeRoute nav-mesh guide paths").
- History (2026-10-01): run 1, ground `LineObject` lines, drew nothing (old 6 m node-gap rule);
  run 2 lines were ugly and partly under the floor; run 3 dots followed the sparse main path nodes
  20 m before the fork, did not sit in the corridors, and they and the markers showed through
  walls. A nav-mesh lead-in build (dots up to 50 m before the fork, option 10-50 m) was replaced
  before testing: the guide belongs between the fork and the markers. This version is not yet run
  in game.
- `/saferoute` prints, per fork, whether the path into it was found (node count, gap).
- Run 4 (2026-10-01, 22:57 local): green dots ran in a straight line through a wall to SAFE ROUTE,
  so the path search fell back to straight lines; no Lua error in the console log. Cause unknown
  (off-mesh waypoints, no A* path, or a search that never finished). Diagnostic build:
  `LOG_GUIDE_PATHS = true` writes one `[MOD][SafeRoute][INFO] guide ...` line per search leg
  (waypoints, snapping, found/no path/timeout, lengths) to the console log; legs time out after
   3 s. Release v1.1.0 sets `LOG_GUIDE_PATHS = false`.
- Latest-code runtime update (user report 2026-10-02): guide dots work perfectly in the latest
  local code. This supersedes run 4 as the current functional status; do not list the older
  straight-line observation as an unresolved failure of this release. The report did not specify
  mission, settings, game version, server context, or cleanup/transition tests. No new in-game
  test was performed by the release agent.

## Removed options
- "Markers along the safe road" (`show_breadcrumbs`, v1.0.0, default off) and the test-build
  options "Hide markers behind walls" (`hide_behind_walls`), "Guide line/dots into the fork"
  (`show_lead_in`) and its length (`lead_in_distance`). DMF reads stored settings only through
  `mod:get` and widget ids (`dmf-source/.../core/settings.lua`, `ui/options/color/color_widget.lua:38`),
  so a stale value cannot raise an error. The mod still clears these keys with `mod:set(id, nil)` at
   load so they leave the settings file.

## Release v1.1.0 — 2026-10-02

- Published GitHub release: https://github.com/Vansinnet/SafeRoute/releases/tag/v1.1.0
  (latest, public, not a prerelease). `main` and `v1.1.0` both point to commit
  `908a9636bbe534d4cae48d2cba898a5a6cadf09b`. Uploaded ZIP digest matches the local SHA-256;
  both checksum files are uploaded. Final Git worktree is clean for tracked files.
- Authoritative source: `mods/active/SafeRoute/`; version recorded in `README.md` and GitHub tag
  `v1.1.0`. ModID, loader paths, and empty package declarations remain consistent; DMF and its
  mod loader are required. English/Swedish option and command keys are present.
- Standard package: `releases/SafeRoute-v1.1.0/SafeRoute.zip`; seven files under `SafeRoute/`:
  `README.md`, `SafeRoute.mod`, and the five runtime Lua files in `scripts/mods/SafeRoute/`.
  SHA-256: `8AD0FD8D4C86AC0107E51C07983E96A1860EC716D531A37E1DF47068DFC7F48C`.
  Source manifest: `releases/SafeRoute-v1.1.0/SafeRoute.source.sha256`; archive hash record:
  `releases/SafeRoute-v1.1.0/SafeRoute.zip.sha256`.
- Final archive inspection: all seven entries listed, forward-slash paths, one mod root,
  no excluded artifacts; every entry's uncompressed SHA-256 matches its authoritative source.
- Excluded development files: `.git/`, `.gitignore`, `DESIGN.md`, and `tests/`. GitHub's existing
  removal of DESIGN/tests is preserved with `.gitignore`; the latest versions remain local.
- Canonical command: `powershell -NoProfile -ExecutionPolicy Bypass -File tools\release-mod.ps1
  -Mod SafeRoute -OutputDirectory releases\SafeRoute-v1.1.0`. Passed: LuaLS zero selected-file
  diagnostics, LuaJIT loadfile and `luac55 -p` for five runtime Lua files plus `SafeRoute.mod`.
  The first invocation timed out at 240 s before producing an archive; the retry passed with
  the full checks enabled.
- Offline command: `tools\luajit\luajit.exe mods/active/SafeRoute/tests/test_routes.lua`.
  Result: 1000 runs (500 seeds x 2 crossroads), zero failures; guide geometry assertions pass.
- Source review confirms the regular `MainPathManager.destroy(self)` hook forwards the original
  call/returns and releases native nav resources before the nav world is destroyed. Evidence:
  `main_path_manager.lua:172-198`, `mission_cleanup_utilities.lua:75-87`, DMF `core/hooks.lua:164-170`.
  A* creation/search/results/cleanup match `payload_extension.lua:345-358,445,498-519` and
  `minion_vortex_extension.lua:490-491`; snapping matches `nav_queries.lua:60-89` and current
  `boss_phase_utilities.lua:278`. Traverse setup matches `navigation.lua:18-51` and
  `nav_mesh_manager.lua:333-358`. Marker callback arguments and LOS match
  `hud_element_world_markers.lua:470,725-793`. Existing LuaCATS/evidence covers the native uses;
  no changed API contract was established by the release work.
- Runtime evidence: latest local guide dots work perfectly according to the user's 2026-10-02
  report; precise mission, version, settings, and server context were not supplied. Earlier
  Spillway marker coverage was reported for Darktide 1.13.0 on 2026-09-29. No new agent-run
  in-game checks. Untested: options/localization surfaces, toggle/reload, path-search abort and
  mission-transition cleanup, dedicated-server context, other missions/seeds, and universal
  gas avoidance. Smallest remaining test: latest ZIP in Spillway, check guide LOS and toggle,
  then leave during a search and load the next mission.
- Rollback: install the previous GitHub v1.0.0 `SafeRoute.zip` over `mods/SafeRoute/`, or remove
  that directory and the `SafeRoute` load-order entry. Previous artifacts under `releases/`
  were preserved; authoritative development source stays here.

## What it does
Spillway (zone `depths`, 1.13.0) has branching paths. At each fork the mission keeps one road and
the others lead into the pox gas, locked doors or extra tasks. SafeRoute puts a green "SAFE ROUTE"
marker a few metres into the kept road and a red "WRONG WAY" marker into each other road; both
   show through walls within the set range. Guide dots follow recorded walked routes from the forks;
   the bundled data covers all five Spillway roads. Main markers work on any level whose main path
   defines crossroads; other resources without recordings get no guide dots.

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
4. Guide dots: from each fork through the corridors (and up stairs), green to SAFE ROUTE, red to
   WRONG WAY; hidden behind walls, while SAFE ROUTE / WRONG WAY stay visible through walls.
5. Other missions: no chat line, no markers. Toggle the mod and change a setting mid-mission;
    leave the mission and enter another (no stale markers or crash).
