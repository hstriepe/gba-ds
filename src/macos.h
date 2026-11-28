/* macOS: the app bundle, its folders and the menu bar (macos.m).
 *
 * GBA DS runs on macOS as a normal windowed app, "GBA DS.app"
 * (scripts/build-macos.sh), or as a single game's app made by GB App
 * Builder, which puts the game in Contents/Resources/Game/ and a
 * gba-ds.cfg with `rom = Game/<file>` beside it. Such an app keeps its
 * data where GB App Builder's own game apps do, so their battery saves are
 * the same files:
 *
 *   ~/Library/Application Support/mGBA Games/<app name>/
 *       saves/<game>.sav     (or config.ini's savegamePath)
 *       GBA DS/              GBA DS's own data folder (states/, cheats/...)
 *       screenshots/
 *
 * A builder can name another folder than "mGBA Games" with game.json's
 * dataRoot: Yoshi (hstriepe's multi-system successor of GB App Builder)
 * writes "Yoshi", where its own game apps keep their data.
 *
 * The plain GBA DS.app keeps it in ~/Library/Application Support/GBA DS/.
 */
#ifndef GBADS_MACOS_H
#define GBADS_MACOS_H

#ifdef __APPLE__

#include "config.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* The folder that holds gba-ds.cfg (Contents/Resources in an app bundle,
 * else the executable's folder). */
void macos_resource_dir(char* out, size_t n);
/* Paths, data folder and defaults for a Mac app, after gba-ds.cfg and the
 * command line: a relative `rom` is taken from the resource folder, and
 * data_dir, save_dir and screenshot_dir get their Mac places when they
 * weren't set. Writes the data folder into dataDir. */
void macos_setup(Config* cfg, const char* resDir, char* dataDir, size_t n);
/* After every settings file: the Mac has three layouts, stacked (span-v),
 * side by side (span-h) or one screen; auto and dual become stacked. */
void macos_settle_layout(Config* cfg);

/* The window's picture is opaque whatever alpha the renderer leaves in it */
struct SDL_Renderer;
void macos_renderer_opaque(struct SDL_Renderer* ren);
/* The window is in macOS's own full screen (View › Enter Full Screen, the
 * green button), which SDL's window flags don't show. */
struct SDL_Window;
bool macos_window_fullscreen(struct SDL_Window* win);

/* The game window as a media window, as GB App Builder's GB Player has it:
 * a title bar over the picture that shows with the mouse at the top and
 * hides 2 s later; borderless (floating) on mac_borderless; resizing held
 * to the layout's shape on mac_lock_aspect; the pointer hidden in full
 * screen when the mouse rests; the display kept awake (mac_keep_awake). */
void macos_window_setup(struct SDL_Window* win);
/* A Mac setting changed by the menu bar or the Settings window: kept in
 * prefs.cfg (as the pause menu's choices are) */
void macos_pref_save(const char* key, const char* value);
/* The game is held: Game › Pause, or another app in front with
 * mac_pause_inactive. game.c doesn't run frames while it is. */
bool macos_hold(void);
/* each frame of a game: whether it is paused (its menu, or held: no
 * display-sleep assertion then); also runs the window's checks */
void macos_game_paused(bool paused);

/* GB Player's "Clean up GBA music": after the sound is resampled to the
 * device's rate, an 8th-order Butterworth low-pass at 0.45 x the game's
 * DirectSound mix rate (emu_gba_mix_rate; 0: nothing to tune to, the
 * sound is passed through) and a 10 Hz DC blocker. Stereo int16. reset:
 * the filter starts over (a new game, or after a pause). */
void macos_audio_filter(int16_t* samples, size_t frames, unsigned deviceRate, unsigned mixRate);
void macos_audio_filter_reset(void);

/* The menu bar (after ui_init: SDL puts its own up as video starts). */
void macos_menu_install(Config* cfg);

/* What the menu bar asks a game to do (game.c takes them each frame) */
enum {
	MC_NONE,
	MC_MENU,          /* the pause menu */
	MC_RESET,
	MC_QUICK_SAVE,
	MC_QUICK_LOAD,
	MC_STACKED,       /* the second screen stacked under the game, or off (one screen) */
	MC_SIDE_BY_SIDE,  /* the second screen beside the game, or off */
	MC_SWAP,
	MC_SHADER,
	MC_SIZE_2, MC_SIZE_3, MC_SIZE_4, MC_SIZE_5,
};
/* The next command from the menu bar, MC_NONE when there's none. */
int macos_command(void);
/* the game a menu command applies to is running (or not: the game list) */
void macos_in_game(bool on);

#endif
#endif
