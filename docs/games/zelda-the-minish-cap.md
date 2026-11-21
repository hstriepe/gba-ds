# The Legend of Zelda: The Minish Cap

| | |
|---|---|
| Releases | `BZME` USA |
| Dumps | `BZME` cartridge `abcebbb1` (tested) |
| Profile | `src/profiles.c`: the `BZME` entry |
| Tests | `tests/regress/zelda-the-minish-cap.json` (`tools/regress.py zelda-the-minish-cap`) |
| Status | in progress (branch `zelda-minish-cap`) |

What GBA DS does with this game. Each rule is a promise the profile keeps; the regression tests check them (the cases citing a rule are listed by `tools/regress.py --list zelda-the-minish-cap`). Change a rule here first when the behaviour is meant to change, then the profile, then the tests and goldens. Rule numbers are never reused: a dropped rule stays, marked *retired*.

Every game also follows the [general rules](README.md#general-rules) (GEN-1 to GEN-6).

## Rules

**MC-1. Area map.** Once Link has the map (from the opening at the Picori Festival), the second screen shows the game's own MAP screen, the one START and then L / R open from the pause menu: the area Link is in, the parts he hasn't been to greyed out as the game shows them. The pause menu's lettering and prompts (the MAP tab, "Choose", the L / R buttons) and the map's cursor aren't shown; the frame round the map and the background behind it are.

**MC-2. Dungeon map.** In a dungeon, the second screen shows the game's dungeon map, as the pause menu's map screen shows it there: the rooms Link has been in, and the whole floor once he has the dungeon's map. The same parts are left out as in MC-1, and the floor list's cursor as well.

**MC-3. A new place, a new map.** When Link goes to another area or room, the second screen captures the map again, so Link's marker on it is where he is.

**MC-4. When the map can't be opened.** Where the pause menu can't be opened (cutscenes, a message on screen, Ezlo talking) the last map stays up, dimmed; before the first map (before Link has it), the logo.

**MC-5. Logo at the menus.** At the title, the file menu and after the game is quit to it, the second screen shows the logo.

**MC-6. Still, with Link's marker showing.** The map never animates, whatever `map_animations` says: Link's marker, which blinks on the game's map screen, is shown in its visible state, and the red check mark that shows where to go next is at its reddest. The map's own animations (the Minish Woods glow) are held at their brightest.

## Not covered yet

- Europe (`BZMP`) and Japan (`BZMJ`): no ROMs tested.
- Cave of Flames, Fortress of Winds, Temple of Droplets, Palace of Winds and Dark Hyrule Castle (MC-2) are tested on states made by warping from Deepwood Shrine (the `mc-us-warp-*` cases): Link at a room of each, with and without the dungeon's map, but not a real playthrough's progress (rooms visited, compass, bosses). Replace them with states from the device when there are some.
- The Royal Crypt and Dark Hyrule Castle's grounds show the area map, not a dungeon map; a warped state can't test them (the area map stays on where Link last was outside), so they wait for states from the device. Dark Hyrule's overworld too.

## For the merge

- Changelog: "The Legend of Zelda: The Minish Cap (USA): the second screen shows the area map, and in dungeons the dungeon map."
- Wiki (`wiki/Supported-games.md`): a row for The Minish Cap (USA) and a section saying what the second screen shows (MC-1, MC-2, MC-4, MC-5).
