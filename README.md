# SafeRoute

SafeRoute is a client-side [Darktide Mod Framework (DMF)](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework) mod for Warhammer 40,000: Darktide. It marks the road the mission keeps at branching paths in **Spillway**: green **SAFE ROUTE** markers show the selected road, while red **WRONG WAY** markers show the other roads. Optional small green markers continue along the selected road. Markers are visible through walls within your configured range.

The choice is determined from the mission's level seed, which the client already receives. SafeRoute sends no data to the server. It also works on other missions whose main path defines branching roads; missions without them show no markers.

## Install

1. Install and enable Darktide Mod Framework and its required mod loader.
2. Download **SafeRoute.zip** from the [latest release](https://github.com/Vansinnet/SafeRoute/releases/latest). Use the release asset, not GitHub's automatically generated source-code ZIP.
3. Extract the ZIP into your Darktide `mods` folder, keeping the included `SafeRoute` directory intact. The resulting path should be `mods/SafeRoute/SafeRoute.mod`.
4. Add `SafeRoute` as a line in `mods/mod_load_order.txt` and start the game.

## Settings and command

| Setting | Default | Effect |
| --- | --- | --- |
| Mark wrong roads | On | Show red markers on roads the mission did not choose. |
| Markers along the safe road | On | Add small green markers every 12 metres. |
| Marker range (m) | 60 (20–200) | Maximum distance at which markers are shown. |
| Announce in chat | On | Report how many branching paths the mission has. |

Use `/saferoute` in chat to list the branching paths and their selected roads for the current mission. English and Swedish localization are included.

## Compatibility and testing

Developed against Darktide 1.13.0. In a Spillway run, a player reported two branching paths and correctly positioned markers. The selected road matches the game's main-path selection in offline tests across 500 synthetic seeds. Whether the selected road always avoids gas in every run has not yet been confirmed in game; please report any counterexample with the mission and road shown by `/saferoute`.

For the Lua source and offline test, see `scripts/mods/SafeRoute/` and `tests/` in this repository. This repository's source-code ZIP is for development; the installable ZIP is attached to the releases.
