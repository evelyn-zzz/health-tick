---
name: release-app
description: Build and publish a new HealthTick release. Use when the user says "发版", "打包发布", "release", or invokes /release-app. Handles version bumping, dual-architecture compilation, DMG packaging, git tagging, and GitHub release publishing.
---

# Release HealthTick

本地构建并发布 HealthTick 新版本。

## Steps

1. **Bump version**: Edit `Sources/Info.plist` — increment `CFBundleShortVersionString` (patch) and `CFBundleVersion` (+1). Confirm version with user if not specified.
2. **Clean build cache**: `rm -rf .build`
3. **Build arm64**: `swift build -c release --arch arm64`
4. **Build x86_64**: `swift build -c release --arch x86_64`
5. **Package two DMGs**:
   - Create `HealthTick.app` bundles for Apple-Silicon and Intel
   - arm64 binary → Apple-Silicon DMG, x86_64 binary → Intel DMG
   - Each app bundle contains: binary, Info.plist, Resources, ad-hoc signed
   - **MANDATORY**: Add Applications symlink in each DMG staging folder: `ln -s /Applications "$STAGE/${LABEL}/Applications"` — this enables drag-to-install in Finder
   - Stage in `/tmp/health-tick-release-{VERSION}/`
6. **Git commit & push**: `git add -A && git commit -m "v{VERSION}" && git tag v{VERSION} && git push origin main --tags`
   - Check tag doesn't already exist before proceeding
7. **Publish to public repo**: `gh release create` to `lifedever/health-tick-release`, upload both DMGs, release notes in Chinese
8. **Update Homebrew Tap**: Update `Casks/health-tick.rb` in `lifedever/homebrew-tap` repo:
   - Compute sha256 for both DMGs: `curl -sL <dmg-url> | shasum -a 256`
   - Update `version` and both `sha256` values
   - Use `mcp__github__create_or_update_file` (need existing file's `sha` to update)
9. **Clean up**: `rm -rf /tmp/health-tick-release-{VERSION}/`

## Release Notes Template

```
## HealthTick v{VERSION}

### 下载
- **Apple Silicon (M1/M2/M3/M4)**: `HealthTick-v{VERSION}-Apple-Silicon.dmg`
- **Intel**: `HealthTick-v{VERSION}-Intel.dmg`

### 安装方式
打开 `.dmg` 文件，将 HealthTick 拖入 Applications 文件夹。
首次打开请前往 **系统设置 → 隐私与安全性** 点击"仍要打开"。
```

## Key Paths

- Version: `Sources/Info.plist` (`CFBundleShortVersionString` + `CFBundleVersion`)
- arm64 binary: `.build/arm64-apple-macosx/release/HealthTick`
- x86_64 binary: `.build/x86_64-apple-macosx/release/HealthTick`
- App resources: `Sources/Resources/`
- Public release repo: `lifedever/health-tick-release`
- Homebrew tap repo: `lifedever/homebrew-tap`, cask file: `Casks/health-tick.rb`

## Important

- Check tag existence before creating to avoid conflicts
- Do NOT run build.sh or replace the local app
- Use `pkill -f "HealthTick Dev.app"` to kill dev version, never `killall HealthTick`
- Temp files go in `/tmp/health-tick-release-{VERSION}/`
