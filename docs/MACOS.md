# GBA DS on macOS

The `macos` branch of this fork (hstriepe/gba-ds) ports GBA DS to macOS 14+ on Apple silicon. It is a normal windowed Mac app with a menu bar, and the dual-screen player of [GB App Builder](https://github.com/hstriepe/mac-mgba), which builds a Mac app for a single GBA game with it.

## Building

```sh
scripts/build-macos.sh        # → build/macos/GBA DS.app (ad-hoc signed)
IDENTITY="Developer ID Application: …" scripts/build-macos.sh
make && make tools            # afterwards: build/macos/gba-ds, build/macos/harness (libpng from Homebrew)
```

The first run builds mGBA (the commit in `scripts/mgba-options.sh`, with the same options as the other builds) and a static SDL2 into `deps/`, so the app needs nothing installed. It needs Xcode's command line tools, cmake and git.

## What the port changes

| Where | What |
|---|---|
| `Makefile` | A Darwin case (no `CROSS`): clang, arm64, `-mmacosx-version-min=14.0`, `deps/mgba/build-macos`, `deps/sdl-macos` (static), `src/macos.m`, the system's zlib and iconv. `make tools` finds Homebrew's libpng. |
| `src/macos.h`, `src/macos.m` | Folders: the bundle's `Resources` stands in for the app folder (`gba-ds.cfg`, `gamecontrollerdb.txt`); the data folder is in Application Support (below). The menu bar, whose commands go to `game.c` (`mac_command`). `macos_renderer_opaque`. |
| `src/main.c` | `__APPLE__`: `macos_resource_dir` instead of `/proc/self/exe`; `macos_setup` instead of `data_dir_setup` (the bundle is read-only); no EmulationStation, BananaOS or updates; the menu bar after `ui_init`. Logs a quit on a signal. |
| `src/ui.c`, `ui.h` | The window at 3× in the shape of its layout. `ui_set_layout` and `ui_window_scale` (the window keeps its scale when the layout changes). The mouse cursor stays visible. Keys held with Command are the menu bar's, not the game's. The Metal layer is made opaque (see below). The test SHOT is opaque too. Logs a quit asked for by the system. |
| `src/game.c` | `mac_command`: the pause menu, quick save and load, restart, second screen on/off, stacked / side by side (kept in `prefs.cfg` as `layout`), swap screens, the LCD shader, window sizes. The log file's path via `F_GETPATH`. |
| `src/mapcap.c`, `logo.c`, `library.c` | Background threads use a QoS class on macOS. `syscall(SYS_gettid)` is a different system call there. |
| `scripts/build-macos.sh`, `macos/GBA DS Help.html` | The app bundle (icon from `assets/brand/gba-ds-icon.png`) and its help page. |

Linux, Android and the web build are unchanged: everything new is in `#ifdef __APPLE__` or Darwin-only Makefile lines.

### mGBA's alpha byte

The software renderer leaves flag bits in each pixel's top byte. On Linux the display ignores it. On macOS, SDL's Metal layer composited with it, and much of the game screen came out black: in Metroid: Zero Mission, the HUD, Samus and most of the room. `macos_renderer_opaque` sets the layer's `opaque` (for OpenGL, the window's), so alpha inside the renderer still works (HUD canvases, logos) but the window shows every pixel.

## Running

- **GBA DS.app** opens the game list. ROMs go in `~/Library/Application Support/GBA DS/roms` unless `rom_dir` says otherwise, and that folder is also the data folder. To run a game directly: `GBA\ DS.app/Contents/MacOS/gba-ds GAME.gba` (any option from `--help`).
- **A game's app** (GB App Builder) has `Resources/Game/game.json` (`romFile`, `dataFolder`) and the ROM beside it, and starts straight into the game. Its data folder is `~/Library/Application Support/mGBA Games/<dataFolder>/GBA DS`. The battery save goes in `<dataFolder>/saves`, or `savegamePath` from that folder's `config.ini`, else from `Resources/Game/defaults.ini`. That is the same file GB App Builder's GB Player apps use. `Resources/gba-ds.cfg` holds the builder's starting `layout`.
- **Layouts:** a window shows `single`, `span-v` (stacked) or `span-h` (side by side). `auto` and `dual` become `span-v`. View › Second Screen switches between `single` and the last two-screen layout.

## Testing

The offscreen video driver needs EGL, which macOS doesn't have. Tests run in a real window (the cocoa driver), and the input-script SHOT works as usual:

```sh
SDL_AUDIODRIVER=dummy build/macos/gba-ds --data_dir=/tmp/t --save_dir=/tmp/t \
  --quick_bar_hint=0 --input-script=script.txt GAME.zip
```

Checked so far (2026-11-21): Metroid Fusion and Metroid: Zero Mission play at full speed (Metal). Zero Mission's map is captured onto the second screen. The menu bar's layout commands work and are kept, and a GB App Builder app finds its game, data folder and shared save. The harness (`make tools`) renders a Zero Mission state the same as plain libmgba.
