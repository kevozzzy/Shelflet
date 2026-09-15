#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
DIST_DIR="$PROJECT_DIR/outputs"
APP_DIR="$DIST_DIR/Shelflet.app"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$PROJECT_DIR/.build"
clang -O2 -fobjc-arc -fblocks -arch arm64 -arch x86_64 -mmacosx-version-min=13.0 \
    -framework Cocoa -framework CoreGraphics -framework ServiceManagement \
    -I "$PROJECT_DIR/Sources" \
    "$PROJECT_DIR/Sources/main.m" "$PROJECT_DIR/Sources/ShakeAnalyzer.m" \
    -o "$APP_DIR/Contents/MacOS/Shelflet"
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

clang -O2 -fobjc-arc -framework Cocoa "$PROJECT_DIR/scripts/make-icon.m" -o "$PROJECT_DIR/.build/make-icon"
"$PROJECT_DIR/.build/make-icon" "$PROJECT_DIR/.build/AppIcon-1024.png"
cp "$PROJECT_DIR/.build/AppIcon-1024.png" "$APP_DIR/Contents/Resources/AppIcon.png"

codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
