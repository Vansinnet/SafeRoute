# SafeRoute

**Version: 1.1.0**

SafeRoute is a client-side [Darktide Mod Framework (DMF)](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework) mod for Warhammer 40,000: Darktide. It marks the road the mission keeps at branching paths in **Spillway**: green **SAFE ROUTE** markers show the selected road, while red **WRONG WAY** markers show the other roads. Optional guide dots lead from each fork to the markers: green to SAFE ROUTE and red to WRONG WAY. The main markers are visible through walls within your configured range; guide dots hide behind walls.

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
| Guide dots from the fork | On | Add dots from each fork to the road markers, using nav-mesh paths. Red dots require Mark wrong roads. Dots hide behind walls. |
| Marker range (m) | 60 (20–200) | Maximum distance at which markers are shown. |
| Announce in chat | On | Report how many branching paths the mission has. |

Use `/saferoute` in chat to list the branching paths and their selected roads for the current mission. English and Swedish localization are included.

## Compatibility and testing

Developed against Darktide 1.13.0. In a Spillway run, a player reported two branching paths and correctly positioned markers. The latest local guide-dot code was also reported working perfectly in game on 2026-10-02. The selected road matches the game's main-path selection in offline tests across 500 synthetic seeds. Whether the selected road always avoids gas in every run has not yet been confirmed in game; please report any counterexample with the mission and road shown by `/saferoute`.

The latest guide-dot report does not specify the mission, game version, settings, or server context. Enable/disable, hot reload, mission-transition cleanup, and broader mission/seed coverage have not been verified for this release.

## Changes in 1.1.0

- Replace the old safe-road breadcrumbs with guide dots from the fork to each road marker, enabled by default.
- Search the mission nav mesh for guide paths, with green safe-road dots and optional red wrong-road dots.
- Hide guide dots behind walls while keeping SAFE ROUTE / WRONG WAY markers visible.
- Extend `/saferoute` with fork detection information and remove obsolete settings.
- Disable temporary guide-path diagnostic logging for release builds.

For the Lua source, see `scripts/mods/SafeRoute/` in this repository. This repository's source-code ZIP is for development; the installable ZIP is attached to the releases.
