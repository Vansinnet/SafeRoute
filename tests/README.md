# SafeRoute offline tests

`test_routes.lua` runs the game's own `Crossroad.generate_road_choices` and
`Crossroad.stitch_and_remove_unused_roads` (from `darktide-source/`)
on synthetic crossroads (one with 2 roads, one with 3, each in its own data set because the game stitches several crossroads in `pairs()` order, which LuaJIT varies between runs) for 500 seeds. It checks that the road
`routes.lua` marks safe is exactly the road whose nodes stay in the stitched main path, that each
crossroad has one safe road, and the polyline helpers.

`math.next_random` is an engine native and is mocked with an LCG, so the roads chosen per seed
say nothing about real missions. Offline evidence only, not an in-game result.

Command, from the workspace root:

    tools\luajit\luajit.exe mods/active/SafeRoute/tests/test_routes.lua

Last result (2026-10-04, Windows bundled LuaJIT, v1.2.0 release): `1000 runs (500 seeds x 2 crossroads), 0 failures`, plus the guide geometry asserts (approach, head, tail, spaced points, append).

Additional release data check (LuaJIT `-e`, 2026-10-04): all five built-in recorded routes load;
164 points are finite coordinate triples and consecutive samples are 0.8–1.2 m apart.
Lengths: A1 22.50 m, A2 28.62 m, B1 39.92 m, B2 32.69 m, B3 38.82 m;
B3 gains more than 5 m in elevation. This is data integrity evidence, not an in-game test.
