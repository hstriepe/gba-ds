#!/bin/bash
# macOS build (Apple silicon, macOS 14+): mGBA and a static SDL2 into deps/
# the first time, then the app, then build/macos/GBA DS.app.
#
# Needs: Xcode's command line tools, cmake, git.
#
#   scripts/build-macos.sh                  ad-hoc signed
#   IDENTITY="Developer ID Application: …" scripts/build-macos.sh
#   BUNDLE_ID=com.example.gba-ds scripts/build-macos.sh
#
# The app runs the game list (ROMs in ~/Library/Application Support/GBA DS/roms
# unless rom_dir says otherwise), or a game: GBA\ DS.app/Contents/MacOS/gba-ds GAME.gba.
# GB App Builder (Mac-mgba) and Yoshi use it as the template for a game's own app,
# with the game in Contents/Resources/Game/ (src/macos.h).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
DEPS="$ROOT/deps"
OUT="$ROOT/build/macos"
APP="$OUT/GBA DS.app"
IDENTITY="${IDENTITY:--}"
BUNDLE_ID="${BUNDLE_ID:-com.windholm.gba-ds}"
MACOS_MIN=14.0
JOBS="$(sysctl -n hw.ncpu)"
mkdir -p "$DEPS" "$OUT"
. scripts/mgba-options.sh

if [ ! -d "$DEPS/mgba" ]; then
	echo "== mGBA $MGBA_COMMIT"
	git clone https://github.com/mgba-emu/mgba.git "$DEPS/mgba"
	git -C "$DEPS/mgba" checkout "$MGBA_COMMIT"
fi
# libmgba again when the pinned commit or the options change (mgba-options.sh;
# M_CORE_GB, for one, came with the Game Boy games)
MGBA_STAMP="$DEPS/mgba/build-macos/.gba-ds-stamp"
MGBA_WANT="$MGBA_COMMIT ${MGBA_OPTS[*]} $MACOS_MIN"
if [ ! -f "$DEPS/mgba/build-macos/libmgba.a" ] || [ "$(cat "$MGBA_STAMP" 2>/dev/null)" != "$MGBA_WANT" ]; then
	echo "== libmgba (macOS, mGBA $MGBA_COMMIT)"
	git -C "$DEPS/mgba" fetch -q origin || true
	git -C "$DEPS/mgba" checkout -q "$MGBA_COMMIT"
	rm -rf "$DEPS/mgba/build-macos"
	cmake -S "$DEPS/mgba" -B "$DEPS/mgba/build-macos" "${MGBA_OPTS[@]}" \
		-DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_MIN"
	make -C "$DEPS/mgba/build-macos" -j"$JOBS" mgba
	echo "$MGBA_WANT" > "$MGBA_STAMP"
	rm -rf "$OUT/gba-ds" # (linked with the old library)
fi

if [ ! -f "$DEPS/sdl-macos/lib/libSDL2.a" ]; then
	echo "== SDL2 (static, macOS)"
	[ -d "$DEPS/SDL2" ] || git clone --depth 1 -b "$SDL_BRANCH" https://github.com/libsdl-org/SDL.git "$DEPS/SDL2"
	cmake -S "$DEPS/SDL2" -B "$DEPS/SDL2/build-macos" -DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_MIN" \
		-DCMAKE_INSTALL_PREFIX="$DEPS/sdl-macos" -DSDL_TEST=OFF -DSDL_SHARED=OFF -DSDL_STATIC=ON
	make -C "$DEPS/SDL2/build-macos" -j"$JOBS" install
fi

echo "== gba-ds"
# the widescreen patches the app offers (WS-6): a release's from main, a -dev version's from dev
WIDE_REF=main
case "$(cat VERSION)" in *-dev*) WIDE_REF=dev ;; esac
make -j"$JOBS" WIDE_REF="$WIDE_REF"

echo "== $APP"
VERSION="$(cat VERSION)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$OUT/gba-ds" "$APP/Contents/MacOS/gba-ds"
cp dist/gamecontrollerdb.txt LICENSE "macos/GBA DS Help.html" "$APP/Contents/Resources/"

# the icon, from the brand artwork
ICONSET="$OUT/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
	sips -z $s $s assets/brand/gba-ds-icon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
	sips -z $((s * 2)) $((s * 2)) assets/brand/gba-ds-icon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleExecutable</key><string>gba-ds</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundleName</key><string>GBA DS</string>
	<key>CFBundleDisplayName</key><string>GBA DS</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>${VERSION%%-*}</string>
	<key>CFBundleVersion</key><string>$VERSION</string>
	<key>LSApplicationCategoryType</key><string>public.app-category.games</string>
	<key>LSMinimumSystemVersion</key><string>$MACOS_MIN</string>
	<key>NSHighResolutionCapable</key><true/>
	<key>NSSupportsAutomaticGraphicsSwitching</key><true/>
	<key>NSHumanReadableCopyright</key><string>GBA DS © kyannon and contributors; macOS port © Harald Striepe. GNU General Public License, version 3.</string>
</dict>
</plist>
EOF

echo "== signing ($IDENTITY)"
xattr -cr "$APP"
if [ "$IDENTITY" = "-" ]; then
	codesign --force --sign - "$APP"
else
	codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
codesign --verify --strict "$APP"
echo "built $APP ($VERSION)"
