# The Legend of Zelda: The Minish Cap

| | |
|---|---|
| Releases | `BZME` USA |
| Dumps | `BZME` cartridge `abcebbb1` |
| Profile | `src/profiles.c`: the `BZME` entry |
| Tests | `tests/regress/zelda-the-minish-cap.json` (`tools/regress.py zelda-the-minish-cap`) |
| Status | in progress (branch `zelda-minish-cap`) |

What GBA DS does with this game. Each rule is a promise the profile keeps; the regression tests check them (the cases citing a rule are listed by `tools/regress.py --list zelda-the-minish-cap`). Change a rule here first when the behaviour is meant to change, then the profile, then the tests and goldens. Rule numbers are never reused: a dropped rule stays, marked *retired*.

Every game also follows the [general rules](README.md#general-rules) (GEN-1 to GEN-6).

## Rules

**MC-1. Area map.** Once Link has the map (from the opening at the Picori Festival), the second screen shows the game's own MAP screen, the one START and then L / R open from the pause menu: the area Link is in, the parts he hasn't been to greyed out as the game shows them. The pause menu's lettering and prompts (the MAP tab, "Choose", the L / R buttons) and the map's cursor aren't shown; the frame round the map and the background behind it are.

**MC-2. Dungeon map.** In a dungeon, once Link has its map, the second screen shows the game's dungeon map, as the pause menu's map screen shows it there, with the same parts left out as in MC-1.

**MC-3. A new place, a new map.** When Link goes to another area or room, the second screen captures the map again, so Link's marker on it is where he is.

**MC-4. When the map can't be opened.** Where the pause menu can't be opened (cutscenes, a message on screen, Ezlo talking, a dungeon without its map) the last map stays up, dimmed; before the first map (before Link has it), the logo.

**MC-5. Logo at the menus.** At the title, the file menu and after the game is quit to it, the second screen shows the logo.

**MC-6. Still, with Link's marker showing.** The map never animates, whatever `map_animations` says: Link's marker, which blinks on the game's map screen, is shown in its visible state.

## Not covered yet

- Europe (`BZMP`) and Japan (`BZMJ`): no ROMs tested.
- Dungeon maps (MC-2), Minish-sized areas and the Dark Hyrule Castle maps need states from the device.

## For the merge

- Changelog: "The Legend of Zelda: The Minish Cap (USA): the second screen shows the area map, and in dungeons the dungeon map once Link has it."
- Wiki (`wiki/Supported-games.md`): a row for The Minish Cap (USA) and a section saying what the second screen shows (MC-1, MC-2, MC-4, MC-5).
