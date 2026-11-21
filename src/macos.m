/* macOS: the app bundle, its folders and the menu bar (see macos.h). */
#import <Cocoa/Cocoa.h>
#import <QuartzCore/CAMetalLayer.h>

#include "macos.h"
#include "paths.h"
#include "ui.h"

#include <SDL.h>
#include <SDL_syswm.h>
#include <string.h>

static Config* mcfg;

/* ------------------------------------------------------------- folders */

void macos_resource_dir(char* out, size_t n) {
	@autoreleasepool {
		NSBundle* b = [NSBundle mainBundle];
		NSString* dir = [b.bundlePath hasSuffix:@".app"] ? b.resourcePath : b.executablePath.stringByDeletingLastPathComponent;
		snprintf(out, n, "%s", dir ? dir.fileSystemRepresentation : ".");
	}
}

/* config.ini's value for key (GB App Builder's game apps write it: mGBA's
 * key = value lines), or nil */
static NSString* ini_value(NSString* path, NSString* key) {
	NSString* text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	NSString* found = nil;
	for (NSString* line in [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
		NSRange eq = [line rangeOfString:@"="];
		if (eq.location == NSNotFound) continue;
		NSString* k = [[line substringToIndex:eq.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
		if ([k isEqualToString:key]) {
			found = [[line substringFromIndex:eq.location + 1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
		}
	}
	return found.length ? found : nil;
}

void macos_setup(Config* cfg, const char* resDir, char* dataDir, size_t n) {
	@autoreleasepool {
		NSString* res = @(resDir);
		NSFileManager* fm = NSFileManager.defaultManager;
		NSString* support = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
		if (!support) support = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"];

		/* a game's app (GB App Builder): Game/game.json names the ROM and the data folder */
		NSData* json = [NSData dataWithContentsOfFile:[res stringByAppendingPathComponent:@"Game/game.json"]];
		NSDictionary* game = json ? [NSJSONSerialization JSONObjectWithData:json options:0 error:nil] : nil;
		if (![game isKindOfClass:NSDictionary.class]) game = nil;
		NSString* romFile = [game[@"romFile"] isKindOfClass:NSString.class] ? game[@"romFile"] : nil;
		NSString* folder = [game[@"dataFolder"] isKindOfClass:NSString.class] ? game[@"dataFolder"] : nil;

		NSString* base;  /* the app's own folder */
		NSString* data;  /* GBA DS's data folder */
		if (romFile && folder.length) {
			base = [[support stringByAppendingPathComponent:@"mGBA Games"] stringByAppendingPathComponent:folder];
			data = [base stringByAppendingPathComponent:@"GBA DS"];
			if (!cfg->rom[0]) snprintf(cfg->rom, sizeof(cfg->rom), "%s", [[res stringByAppendingPathComponent:@"Game"] stringByAppendingPathComponent:romFile].fileSystemRepresentation);
			/* battery saves: where the game's GB Player app keeps them (the same file) */
			if (!cfg->saveDir[0]) {
				/* (as GB Player: the player's config.ini, over the app's defaults.ini, over saves/) */
				NSString* saves = ini_value([base stringByAppendingPathComponent:@"config.ini"], @"savegamePath");
				if (!saves) saves = ini_value([res stringByAppendingPathComponent:@"Game/defaults.ini"], @"savegamePath");
				if (!saves) saves = [base stringByAppendingPathComponent:@"saves"];
				snprintf(cfg->saveDir, sizeof(cfg->saveDir), "%s", saves.fileSystemRepresentation);
			}
		} else {
			base = data = [support stringByAppendingPathComponent:@"GBA DS"];
			if (!strcmp(cfg->romDir, "/storage/roms/gba")) {
				NSString* roms = [data stringByAppendingPathComponent:@"roms"];
				[fm createDirectoryAtPath:roms withIntermediateDirectories:YES attributes:nil error:nil];
				snprintf(cfg->romDir, sizeof(cfg->romDir), "%s", roms.fileSystemRepresentation);
			}
		}
		/* a relative ROM (on the command line): from the resource folder */
		if (cfg->rom[0] && cfg->rom[0] != '/' && ![fm fileExistsAtPath:@(cfg->rom)]) {
			NSString* p = [res stringByAppendingPathComponent:@(cfg->rom)];
			snprintf(cfg->rom, sizeof(cfg->rom), "%s", p.fileSystemRepresentation);
		}
		if (cfg->dataDir[0]) data = [@(cfg->dataDir) stringByExpandingTildeInPath];
		if (!cfg->screenshotDir[0] || !strncmp(cfg->screenshotDir, "/storage/", 9)) {
			snprintf(cfg->screenshotDir, sizeof(cfg->screenshotDir), "%s", [base stringByAppendingPathComponent:@"screenshots"].fileSystemRepresentation);
		}
		[fm createDirectoryAtPath:data withIntermediateDirectories:YES attributes:nil error:nil];
		if (cfg->saveDir[0]) [fm createDirectoryAtPath:@(cfg->saveDir) withIntermediateDirectories:YES attributes:nil error:nil];
		snprintf(dataDir, n, "%s", data.fileSystemRepresentation);
		/* no updates (the app is replaced as a whole) */
		cfg->updateCheck = false;
		/* the dual layout on a Mac: one window, the screens stacked */
		if (!strcmp(cfg->layout, "auto") || !strcmp(cfg->layout, "dual")) snprintf(cfg->layout, sizeof(cfg->layout), "span-v");
	}
}

void macos_renderer_opaque(SDL_Renderer* ren) {
	CAMetalLayer* layer = (__bridge CAMetalLayer*) SDL_RenderGetMetalLayer(ren);
	if (layer) {
		layer.opaque = YES;
		return;
	}
	/* (OpenGL: the window's content view is opaque) */
	SDL_Window* win = SDL_RenderGetWindow(ren);
	SDL_SysWMinfo wm;
	SDL_VERSION(&wm.version);
	if (win && SDL_GetWindowWMInfo(win, &wm) && wm.subsystem == SDL_SYSWM_COCOA) {
		wm.info.cocoa.window.opaque = YES;
	}
}

/* ------------------------------------------------------------- commands */

static int queue[16];
static int qHead, qTail;
static bool inGame;

static void push(int c) {
	if (!inGame) return;
	int next = (qTail + 1) % 16;
	if (next == qHead) return;
	queue[qTail] = c;
	qTail = next;
}

int macos_command(void) {
	if (qHead == qTail) return MC_NONE;
	int c = queue[qHead];
	qHead = (qHead + 1) % 16;
	return c;
}

void macos_in_game(bool on) {
	inGame = on;
	qHead = qTail = 0;
}

/* ------------------------------------------------------------- menu bar */

static NSString* app_name(void) {
	NSDictionary* info = NSBundle.mainBundle.infoDictionary;
	NSString* name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"];
	return name.length ? name : @"GBA DS";
}

@interface GBADSMenu : NSObject <NSMenuItemValidation>
@end

@implementation GBADSMenu
- (void)command:(NSMenuItem*)item {
	push((int) item.tag);
}

- (void)closeWindow:(id)sender {
	SDL_Event ev = { .type = SDL_QUIT };
	SDL_PushEvent(&ev);
}

- (void)about:(id)sender {
	NSString* text = @"Game Boy Advance with a second screen: the game's own map beside it, as in the DS Castlevanias.\n\n"
	                 @"GBA DS by kyannon and contributors (github.com/kyannon/gba-ds), macOS port by Harald Striepe. "
	                 @"Free software under the GNU General Public License, version 3.\n\n"
	                 @"Emulation by mGBA (mgba.io), © Jeffrey Pfau, Mozilla Public License 2.0.";
	NSDictionary* attrs = @{ NSFontAttributeName: [NSFont systemFontOfSize:NSFont.smallSystemFontSize],
		                     NSForegroundColorAttributeName: NSColor.labelColor };
	NSAttributedString* credits = [[NSAttributedString alloc] initWithString:text attributes:attrs];
	[NSApp orderFrontStandardAboutPanelWithOptions:@{ NSAboutPanelOptionCredits: credits }];
}

- (void)help:(id)sender {
	NSString* page = [NSBundle.mainBundle pathForResource:@"GBA DS Help" ofType:@"html"];
	if (page) [NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:page]];
	else [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://github.com/kyannon/gba-ds/wiki/Playing"]];
}

- (void)manual:(id)sender {
	NSString* pdf = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Game/Manual.pdf"];
	[NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:pdf]];
}

- (void)dataFolder:(id)sender {
	if (!mcfg) return;
	NSString* states = @(mcfg->stateDir);
	[NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:states.stringByDeletingLastPathComponent isDirectory:YES]];
}

- (BOOL)validateMenuItem:(NSMenuItem*)item {
	if (item.action == @selector(manual:)) {
		NSString* pdf = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Game/Manual.pdf"];
		return [NSFileManager.defaultManager fileExistsAtPath:pdf];
	}
	if (item.action != @selector(command:)) return YES;
	const char* lay = mcfg ? mcfg->layout : "single";
	bool dual = strcmp(lay, "single") != 0;
	switch (item.tag) {
	case MC_SECOND_SCREEN: item.state = dual ? NSControlStateValueOn : NSControlStateValueOff; break;
	case MC_STACKED: item.state = !strcmp(lay, "span-v") ? NSControlStateValueOn : NSControlStateValueOff; break;
	case MC_SIDE_BY_SIDE: item.state = !strcmp(lay, "span-h") ? NSControlStateValueOn : NSControlStateValueOff; break;
	case MC_SHADER: item.state = mcfg && mcfg->shader != SH_OFF ? NSControlStateValueOn : NSControlStateValueOff; break;
	}
	return inGame;
}
@end

static GBADSMenu* target;

static NSMenuItem* add(NSMenu* m, NSString* title, SEL action, NSString* key, NSEventModifierFlags mods, int tag) {
	NSMenuItem* it = [m addItemWithTitle:title action:action keyEquivalent:key ?: @""];
	if (key) it.keyEquivalentModifierMask = mods;
	it.tag = tag;
	if (action && [target respondsToSelector:action]) it.target = target;
	return it;
}

static NSMenu* submenu(NSMenu* bar, NSString* title) {
	NSMenuItem* top = [bar addItemWithTitle:title action:nil keyEquivalent:@""];
	NSMenu* m = [[NSMenu alloc] initWithTitle:title];
	top.submenu = m;
	return m;
}

void macos_menu_install(Config* cfg) {
	mcfg = cfg;
	@autoreleasepool {
		target = [GBADSMenu new];
		NSString* name = app_name();
		const NSEventModifierFlags cmd = NSEventModifierFlagCommand;
		NSMenu* bar = [[NSMenu alloc] initWithTitle:@""];

		NSMenu* app = submenu(bar, name);
		add(app, [NSString stringWithFormat:@"About %@", name], @selector(about:), nil, 0, 0);
		[app addItem:NSMenuItem.separatorItem];
		NSMenuItem* services = add(app, @"Services", nil, nil, 0, 0);
		services.submenu = [[NSMenu alloc] initWithTitle:@"Services"];
		NSApp.servicesMenu = services.submenu;
		[app addItem:NSMenuItem.separatorItem];
		add(app, [NSString stringWithFormat:@"Hide %@", name], @selector(hide:), @"h", cmd, 0);
		add(app, @"Hide Others", @selector(hideOtherApplications:), @"h", cmd | NSEventModifierFlagOption, 0);
		add(app, @"Show All", @selector(unhideAllApplications:), nil, 0, 0);
		[app addItem:NSMenuItem.separatorItem];
		add(app, [NSString stringWithFormat:@"Quit %@", name], @selector(terminate:), @"q", cmd, 0);

		NSMenu* game = submenu(bar, @"Game");
		add(game, @"Pause Menu", @selector(command:), @"p", cmd, MC_MENU);
		[game addItem:NSMenuItem.separatorItem];
		add(game, @"Quick Save", @selector(command:), @"s", cmd, MC_QUICK_SAVE);
		add(game, @"Quick Load", @selector(command:), @"l", cmd, MC_QUICK_LOAD);
		[game addItem:NSMenuItem.separatorItem];
		add(game, @"Restart", @selector(command:), @"r", cmd, MC_RESET);
		[game addItem:NSMenuItem.separatorItem];
		add(game, @"Show Data Folder", @selector(dataFolder:), nil, 0, 0);

		NSMenu* view = submenu(bar, @"View");
		add(view, @"Second Screen", @selector(command:), @"d", cmd, MC_SECOND_SCREEN);
		add(view, @"Stacked", @selector(command:), @"d", cmd | NSEventModifierFlagOption, MC_STACKED);
		add(view, @"Side by Side", @selector(command:), @"d", cmd | NSEventModifierFlagShift, MC_SIDE_BY_SIDE);
		add(view, @"Swap Screens", @selector(command:), @"x", cmd | NSEventModifierFlagShift, MC_SWAP);
		[view addItem:NSMenuItem.separatorItem];
		add(view, @"LCD Shader", @selector(command:), @"g", cmd | NSEventModifierFlagShift, MC_SHADER);
		[view addItem:NSMenuItem.separatorItem];
		add(view, @"Size 2×", @selector(command:), @"2", cmd, MC_SIZE_2);
		add(view, @"Size 3×", @selector(command:), @"3", cmd, MC_SIZE_3);
		add(view, @"Size 4×", @selector(command:), @"4", cmd, MC_SIZE_4);
		add(view, @"Size 5×", @selector(command:), @"5", cmd, MC_SIZE_5);
		[view addItem:NSMenuItem.separatorItem];
		add(view, @"Enter Full Screen", @selector(toggleFullScreen:), @"f", cmd | NSEventModifierFlagControl, 0);

		NSMenu* win = submenu(bar, @"Window");
		add(win, @"Minimize", @selector(performMiniaturize:), @"m", cmd, 0);
		add(win, @"Zoom", @selector(performZoom:), nil, 0, 0);
		[win addItem:NSMenuItem.separatorItem];
		add(win, @"Close", @selector(closeWindow:), @"w", cmd, 0);
		NSApp.windowsMenu = win;

		NSMenu* help = submenu(bar, @"Help");
		add(help, [NSString stringWithFormat:@"%@ Help", name], @selector(help:), @"?", cmd, 0);
		add(help, @"Game Manual", @selector(manual:), nil, 0, 0);
		NSApp.helpMenu = help;

		NSApp.mainMenu = bar;
		/* the window has the app's name (a game's app: the game's) */
		for (NSWindow* w in NSApp.windows) w.title = name;
	}
}
