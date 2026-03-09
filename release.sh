#!/bin/bash
set -e
cd "$(dirname "$0")"

# Read version from Info.plist
VERSION=$(grep -A1 CFBundleShortVersionString Sources/Info.plist | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
TAG="v${VERSION}"
REPO="lifedever/health-tick-release"

echo "=== HealthTick Release ${TAG} ==="
echo ""

# Check if tag already exists on remote
if git ls-remote --tags origin | grep -q "refs/tags/${TAG}$"; then
    echo "Error: tag ${TAG} already exists. Bump version in Sources/Info.plist first."
    exit 1
fi

# Build universal binary (arm64 + x86_64)
echo "[1/5] Building universal binary..."
if swift build -c release --arch arm64 --arch x86_64 2>&1; then
    BINARY=".build/apple/Products/Release/HealthTick"
    echo "  Built universal binary (arm64 + x86_64)"
else
    echo "  Universal build failed, building arm64 only..."
    swift build -c release --arch arm64
    BINARY=".build/arm64-apple-macosx/release/HealthTick"
    echo "  Built arm64 binary"
fi

# Package app bundles for each architecture label
echo "[2/5] Packaging app..."
STAGE="/tmp/health-tick-release-${VERSION}"
rm -rf "$STAGE"

for label in Apple-Silicon Intel; do
    APP_DIR="${STAGE}/${label}/HealthTick.app/Contents"
    mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"
    cp "$BINARY" "$APP_DIR/MacOS/"
    cp Sources/Info.plist "$APP_DIR/"
    if [ -d "Sources/Resources" ]; then
        cp -R Sources/Resources/* "$APP_DIR/Resources/"
    fi
    codesign --force --deep --sign - "${STAGE}/${label}/HealthTick.app"
done

# Create DMGs
echo "[3/5] Creating DMGs..."
for label in Apple-Silicon Intel; do
    DMG_NAME="HealthTick-${TAG}-${label}.dmg"
    DMG_DIR="${STAGE}/dmg-${label}"
    mkdir -p "$DMG_DIR"
    cp -R "${STAGE}/${label}/HealthTick.app" "$DMG_DIR/"
    ln -s /Applications "$DMG_DIR/Applications"
    hdiutil create -volname "HealthTick" -srcfolder "$DMG_DIR" -ov -format UDZO \
        "${STAGE}/${DMG_NAME}" -quiet
    echo "  Created ${DMG_NAME}"
done

# Git commit, tag, push
echo "[4/5] Pushing tag ${TAG}..."
git add -A
git diff --cached --quiet || git commit -m "${TAG}"
git tag "$TAG" 2>/dev/null || true
git push origin main --tags

# Upload to public release repo
echo "[5/5] Publishing release to ${REPO}..."
gh release create "$TAG" \
    --repo "$REPO" \
    --title "HealthTick ${TAG}" \
    --notes "## HealthTick ${TAG}

### Download
- **Apple Silicon (M1/M2/M3/M4)**: \`HealthTick-${TAG}-Apple-Silicon.dmg\`
- **Intel**: \`HealthTick-${TAG}-Intel.dmg\`

### Install
Open the \`.dmg\` file and drag HealthTick to the Applications folder.
First launch: go to **System Settings -> Privacy & Security** and click \"Open Anyway\"." \
    "${STAGE}/HealthTick-${TAG}-Apple-Silicon.dmg" \
    "${STAGE}/HealthTick-${TAG}-Intel.dmg"

echo ""
echo "=== Done! Released ${TAG} to ${REPO} ==="
echo "https://github.com/${REPO}/releases/tag/${TAG}"

# Cleanup
rm -rf "$STAGE"
