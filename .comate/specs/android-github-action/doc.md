# Android 专用 GitHub Action 工作流

## 需求场景

当前项目文档中规划了 `multi-platform-build.yml`（多平台统一构建）和 `windows-build.yml`（Windows 专用构建）两个工作流，但实际 `.github/workflows/` 目录下尚无任何工作流文件。用户要求新增一个**独立的 Android 专用 GitHub Action**，用于自动化构建 Android APK/AAB。

## 技术方案

### 工作流设计

创建 `.github/workflows/android-build.yml`，作为独立的 Android 构建工作流，参考项目已有的构建脚本和文档中的构建命令。

### 触发条件

- **Push** 到 `main` / `dev` / `develop` 分支（仅当 `android/` 或 `lib/` 或 `pubspec.yaml` 有变更时触发）
- **Tag** 推送 `v*`（自动构建并发布到 GitHub Releases）
- **Pull Request** 到 `main` 分支（仅构建验证，不发布）
- **手动触发** `workflow_dispatch`（可选版本号参数）

### 构建步骤

1. **环境准备**：Checkout 代码，安装 Flutter SDK（stable channel），安装 Java 17
2. **依赖获取**：`flutter pub get`
3. **内核下载**：调用 `scripts/download_kernels.sh` 下载 sing-box 等内核（Android aarch64 版本）
4. **签名配置**：从 GitHub Secrets 解码 keystore 文件，生成 `key.properties`
5. **构建 APK**：`flutter build apk --release --split-per-abi`（分别生成 arm64-v8a、armeabi-v7a、x86_64 三个 APK）
6. **构建 AAB**：`flutter build appbundle --release`（Google Play 上传包）
7. **上传产物**：将 APK/AAB 文件上传为 GitHub Actions Artifacts
8. **发布 Release**：仅 Tag 触发时，自动创建 GitHub Release 并附带构建产物

### 缓存策略

- Flutter pub cache
- Gradle cache (`~/.gradle/caches`, `~/.gradle/wrapper`)
- Android SDK/NDK

### Secrets 依赖

| Secret 名称 | 用途 | 必需 |
|---|---|---|
| `ANDROID_KEYSTORE` | Base64 编码的 keystore 文件 | 否（debug 签名兜底） |
| `ANDROID_KEY_PASSWORD` | keystore 密码 | 否 |
| `ANDROID_KEY_ALIAS` | 密钥别名 | 否 |

无签名 Secrets 时使用 debug 签名构建，确保工作流始终可运行。

## 受影响文件

| 文件 | 操作类型 | 说明 |
|---|---|---|
| `.github/workflows/android-build.yml` | **新增** | Android 专用 GitHub Action 工作流 |

## 实现细节

### 工作流核心 YAML 结构

```yaml
name: Android Build

on:
  push:
    branches: [main, dev, develop]
    tags: ['v*']
    paths:
      - 'android/**'
      - 'lib/**'
      - 'pubspec.yaml'
      - '.github/workflows/android-build.yml'
  pull_request:
    branches: [main]
    paths:
      - 'android/**'
      - 'lib/**'
      - 'pubspec.yaml'
  workflow_dispatch:
    inputs:
      version:
        description: 'Version'
        required: false
        default: 'dev'

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Download kernels (Android)
        run: |
          chmod +x scripts/download_kernels.sh
          mkdir -p assets/bin
          bash scripts/download_kernels.sh ./assets/bin
        # 内核下载失败不阻塞构建

      - name: Setup Android signing
        if: ${{ env.ANDROID_KEYSTORE != '' }}
        env:
          ANDROID_KEYSTORE: ${{ secrets.ANDROID_KEYSTORE }}
        run: |
          echo "$ANDROID_KEYSTORE" | base64 --decode > android/app/upload-keystore.jks

      - name: Build APK (split per ABI)
        run: flutter build apk --release --split-per-abi

      - name: Build AAB
        if: startsWith(github.ref, 'refs/tags/v')
        run: flutter build appbundle --release

      - name: Upload APK artifacts
        uses: actions/upload-artifact@v4
        with:
          name: android-apk
          path: build/app/outputs/flutter-apk/*.apk

      - name: Upload AAB artifact
        if: startsWith(github.ref, 'refs/tags/v')
        uses: actions/upload-artifact@v4
        with:
          name: android-aab
          path: build/app/outputs/bundle/release/*.aab

      - name: Create GitHub Release
        if: startsWith(github.ref, 'refs/tags/v')
        uses: softprops/action-gh-release@v2
        with:
          files: |
            build/app/outputs/flutter-apk/*.apk
            build/app/outputs/bundle/release/*.aab
```

### 边界条件与异常处理

1. **内核下载失败**：`download_kernels.sh` 失败不应阻塞 APK 构建（APK 本身不依赖预编译内核也能打包成功），使用 `continue-on-error: true`
2. **缺少签名 Secrets**：不配置 keystore 时 Flutter 自动使用 debug 签名，确保 CI 始终能跑通
3. **AAB 仅在 Tag 触发时构建**：日常 push/PR 只构建 APK，节省 CI 时间
4. **路径过滤**：`paths` 过滤确保仅在 Android 相关文件变更时触发，避免无关变更浪费 CI 资源

### 数据流

```
Push/Tag/PR/Dispatch → Checkout → Java + Flutter Setup → flutter pub get
→ Download Kernels → Setup Signing (optional) → Build APK → Build AAB (tag only)
→ Upload Artifacts → Create Release (tag only)
```

## 预期结果

- 新增 `.github/workflows/android-build.yml` 文件
- Push 到 dev/main 分支时自动构建 Android APK（split-per-abi）
- 推送 `v*` 标签时自动构建 APK + AAB 并创建 GitHub Release
- PR 到 main 时仅做构建验证
- 支持手动触发并传入版本号
- 无签名 Secrets 时使用 debug 签名，工作流不中断
