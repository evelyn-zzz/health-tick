#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Building HealthTick (Dev)..."

# Try universal binary, fallback to native arch
if swift build -c release --arch arm64 --arch x86_64 2>/dev/null; then
    BINARY=".build/apple/Products/Release/HealthTick"
    echo "Built universal binary (arm64 + x86_64)"
else
    swift build -c release
    BINARY=".build/release/HealthTick"
    echo "Built native binary"
fi

# Dev build uses different app name and bundle ID to coexist with release
APP_NAME="HealthTick Dev"
APP_DIR="$HOME/Applications/${APP_NAME}.app/Contents/MacOS"
mkdir -p "$APP_DIR"
cp "$BINARY" "$APP_DIR/"

# Create dev Info.plist with different bundle ID
cat > "$HOME/Applications/${APP_NAME}.app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>HealthTick</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIdentifier</key>
    <string>com.evelyn-zzz.healthtick.dev</string>
    <key>CFBundleName</key>
    <string>HealthTick Dev</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>$(grep -A1 CFBundleShortVersionString Sources/Info.plist | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')</string>
    <key>CFBundleVersion</key>
    <string>$(grep -A1 CFBundleVersion Sources/Info.plist | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')</string>
</dict>
</plist>
EOF

# Copy resources
RES_DIR="$HOME/Applications/${APP_NAME}.app/Contents/Resources"
mkdir -p "$RES_DIR"
if [ -d "Sources/Resources" ]; then
    cp -R Sources/Resources/* "$RES_DIR/"
fi

# Ad-hoc code signing
codesign --force --deep --sign - "$HOME/Applications/${APP_NAME}.app"
echo "Done! Dev app installed to ~/Applications/${APP_NAME}.app (signed)"
echo "Run: open ~/Applications/${APP_NAME}.app"
