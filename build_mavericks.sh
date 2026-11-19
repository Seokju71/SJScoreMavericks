#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

NIM_BIN="${NIM_BIN:-$(command -v nim || echo "$HOME/.nimble/bin/nim")}"
CLANG_BIN="${CLANG_BIN:-/usr/bin/clang}"
MIN_MACOS="10.9"
APP_NAME="SJScore"
EXECUTABLE_NAME="SJScoreMavericks"
BUNDLE_ID="com.sjscore.mavericks"
VERSION="1.0.0"

RESOURCES_DIR="$SCRIPT_DIR/resources"
BUILD_DIR="$SCRIPT_DIR/build"
DIST_DIR="$SCRIPT_DIR/dist"
APP_BUNDLE="$DIST_DIR/${APP_NAME}.app"
DMG_STAGING="$DIST_DIR/dmg-staging"
DMG_PATH="$DIST_DIR/${APP_NAME}-Mavericks.dmg"

mkdir -p "$BUILD_DIR" "$DIST_DIR"

echo "==> 1. Running Nim Core Unit Tests..."
"$NIM_BIN" c -r \
  --cc:clang \
  --clang.exe:"$CLANG_BIN" \
  --clang.linkerexe:"$CLANG_BIN" \
  --nimcache:"$BUILD_DIR/nimcache_test" \
  -o:"$BUILD_DIR/core_tests" \
  "$SCRIPT_DIR/core/tests.nim"

echo ""
echo "==> 2. Building Nim Core Static Library (x86_64, min macOS ${MIN_MACOS})..."
"$NIM_BIN" c \
  --app:staticlib \
  --noMain \
  --mm:arc \
  -d:release \
  --cc:clang \
  --clang.exe:"$CLANG_BIN" \
  --clang.linkerexe:"$CLANG_BIN" \
  --passC:"-arch x86_64 -mmacosx-version-min=${MIN_MACOS}" \
  --nimcache:"$BUILD_DIR/nimcache_lib" \
  -o:"$BUILD_DIR/libsjscore_core.a" \
  "$SCRIPT_DIR/core/c_api.nim"

echo ""
echo "==> 3. Compiling Objective-C AppKit UI & Linking (x86_64, min macOS ${MIN_MACOS})..."
"$CLANG_BIN" \
  -arch x86_64 \
  -mmacosx-version-min="${MIN_MACOS}" \
  -fobjc-arc \
  -O2 \
  -Wall -Wextra -Wno-deprecated-declarations \
  -I"$SCRIPT_DIR/app" \
  "$SCRIPT_DIR/app/FontRegistrar.m" \
  "$SCRIPT_DIR/app/ScoreRenderer.m" \
  "$SCRIPT_DIR/app/PDFExporter.m" \
  "$SCRIPT_DIR/app/ScoreCanvasView.m" \
  "$SCRIPT_DIR/app/MainWindowController.m" \
  "$SCRIPT_DIR/app/main.m" \
  "$BUILD_DIR/libsjscore_core.a" \
  -framework Cocoa \
  -framework CoreGraphics \
  -framework CoreText \
  -framework QuartzCore \
  -o "$BUILD_DIR/$EXECUTABLE_NAME"

echo ""
echo "==> 4. Assembling ${APP_NAME}.app bundle (min OS X ${MIN_MACOS})..."
rm -rf "$APP_BUNDLE" "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

cp "$RESOURCES_DIR/Fonts/"*.otf "$APP_BUNDLE/Contents/Resources/"
if [[ -f "$RESOURCES_DIR/AppIcon.icns" ]]; then
  cp "$RESOURCES_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>ko</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "==> 5. Ad-hoc code signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> 6. Verifying OS X ${MIN_MACOS} binary compatibility..."
file "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
otool -l "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME" | grep -A 3 -E "LC_VERSION_MIN_MACOSX|LC_BUILD_VERSION" || true
echo "Linked dylibs:"
otool -L "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

if [[ "${SKIP_DMG:-0}" != "1" ]]; then
  echo ""
  echo "==> 7. Creating DMG (${DMG_PATH})..."
  mkdir -p "$DMG_STAGING"
  cp -R "$APP_BUNDLE" "$DMG_STAGING/"
  ln -s /Applications "$DMG_STAGING/Applications"
  hdiutil create \
    -volname "${APP_NAME} (OS X 10.9+)" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
  rm -rf "$DMG_STAGING"
fi

echo ""
echo "✅ Build complete!"
echo "   App Bundle : $APP_BUNDLE"
if [[ -f "$DMG_PATH" ]]; then
  echo "   Installer  : $DMG_PATH"
fi
