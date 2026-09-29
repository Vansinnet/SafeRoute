# SafeRoute offline tests

`test_routes.lua` runs the game's own `Crossroad.generate_road_choices` and
`Crossroad.stitch_and_remove_unused_roads` (from `darktide-source/Darktide-Source-Code-1.13.0`)
on synthetic crossroads (one with 2 roads, one with 3) for 500 seeds. It checks that the road
`routes.lua` marks safe is exactly the road whose nodes stay in the stitched main path, that each
crossroad has one safe road, and the polyline helpers.

`math.next_random` is an engine native and is mocked with an LCG, so the roads chosen per seed
say nothing about real missions. Offline evidence only, not an in-game result.

Command, from the workspace root:

    tools/luajit/luajit mods/active/SafeRoute/tests/test_routes.lua

Last result (2026-09-29, Linux LuaJIT): `500 seeds, 0 failures`.
