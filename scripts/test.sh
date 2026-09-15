#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
mkdir -p "$PROJECT_DIR/.build"
clang -fobjc-arc -fblocks -framework Foundation -framework CoreGraphics \
    -I "$PROJECT_DIR/Sources" \
    "$PROJECT_DIR/Sources/ShakeAnalyzer.m" "$PROJECT_DIR/Tests/ShakeAnalyzerTests.m" \
    -o "$PROJECT_DIR/.build/ShakeAnalyzerTests"
"$PROJECT_DIR/.build/ShakeAnalyzerTests"
