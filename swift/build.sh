#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Building HealthTick..."
swift build -c release

APP_DIR="$HOME/Applications/HealthTick.app/Contents/MacOS"
mkdir -p "$APP_DIR"
cp .build/release/HealthTick "$APP_DIR/"
cp Sources/Info.plist "$HOME/Applications/HealthTick.app/Contents/"

# Copy resources
RES_DIR="$HOME/Applications/HealthTick.app/Contents/Resources"
mkdir -p "$RES_DIR"
if [ -d "Sources/Resources" ]; then
    cp -R Sources/Resources/* "$RES_DIR/"
fi

echo "Done! App installed to ~/Applications/HealthTick.app"
echo "Run: open ~/Applications/HealthTick.app"
