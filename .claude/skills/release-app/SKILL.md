---
name: release-app
description: Build and publish a new HealthTick release. Use when the user says "发版", "打包发布", "release", or invokes /release-app. Handles version bumping, dual-architecture compilation, DMG packaging, git tagging, and GitHub release publishing.
---

# 发布 HealthTick

本地构建并发布 HealthTick 新版本。

## 步骤

1. **升级版本号**：编辑 `Sources/Info.plist`，递增 `CFBundleShortVersionString`（patch）和 `CFBundleVersion`（+1）。未指定版本时先和用户确认。
2. **清理构建缓存**：`rm -rf .build`
3. **构建 arm64**：`swift build -c release --arch arm64`
4. **构建 x86_64**：`swift build -c release --arch x86_64`
5. **打包两个 DMG**：
   - 分别为 Apple-Silicon 和 Intel 创建 `HealthTick.app` 包
   - arm64 二进制 → Apple-Silicon DMG，x86_64 二进制 → Intel DMG
   - 每个 app bundle 包含：二进制文件、Info.plist、Resources，使用 ad-hoc 签名
   - **【必须】** 在每个 DMG 暂存目录中添加 Applications 符号链接：`ln -s /Applications "$STAGE/${LABEL}/Applications"`，用于 Finder 中拖拽安装
   - 暂存目录：`/tmp/health-tick-release-{VERSION}/`
6. **Git 提交并推送**：`git add -A && git commit -m "v{VERSION}" && git tag v{VERSION} && git push origin main --tags`
   - 创建前检查 tag 是否已存在
7. **发布到公开仓库**：使用 `gh release create` 发布到 `lifedever/health-tick-release`，上传两个 DMG，release notes 用中文
8. **更新 Homebrew Tap**：更新 `lifedever/homebrew-tap` 仓库中的 `Casks/health-tick.rb`：
   - 计算两个 DMG 的 sha256：`curl -sL <dmg-url> | shasum -a 256`
   - 更新 `version` 和两个 `sha256` 值
   - 使用 `mcp__github__create_or_update_file`（更新时需要现有文件的 `sha`）
9. **清理**：`rm -rf /tmp/health-tick-release-{VERSION}/`

## Release Notes 模板

```
## HealthTick v{VERSION}

### 下载
- **Apple Silicon (M1/M2/M3/M4)**: `HealthTick-v{VERSION}-Apple-Silicon.dmg`
- **Intel**: `HealthTick-v{VERSION}-Intel.dmg`

### 安装方式
打开 `.dmg` 文件，将 HealthTick 拖入 Applications 文件夹。
首次打开请前往 **系统设置 → 隐私与安全性** 点击"仍要打开"。
```

## 关键路径

- 版本号：`Sources/Info.plist`（`CFBundleShortVersionString` + `CFBundleVersion`）
- arm64 二进制：`.build/arm64-apple-macosx/release/HealthTick`
- x86_64 二进制：`.build/x86_64-apple-macosx/release/HealthTick`
- 应用资源：`Sources/Resources/`
- 公开发布仓库：`lifedever/health-tick-release`
- Homebrew tap 仓库：`lifedever/homebrew-tap`，cask 文件：`Casks/health-tick.rb`

## 重要规则

- **【禁止】绝对不要删除已发布的 GitHub Release 重新上传** —— 删除 release 会永久丢失该版本的下载计数。如果已发布的 DMG 有问题，必须使用新的 patch 版本号（如 1.3.5 → 1.3.6）重新发布。
- 创建 tag 前检查是否已存在，避免冲突
- 不要运行 build.sh 或替换本地 app
- 终止开发版用 `pkill -f "HealthTick Dev.app"`，绝不用 `killall HealthTick`
- 临时文件放在 `/tmp/health-tick-release-{VERSION}/`
