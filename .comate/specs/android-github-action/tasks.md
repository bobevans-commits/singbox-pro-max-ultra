# Android 专用 GitHub Action 工作流

- [x] Task 1: 创建 `.github/workflows/android-build.yml` 工作流文件
    - 1.1: 配置触发条件（push/PR/tag/workflow_dispatch）及路径过滤
    - 1.2: 配置环境准备步骤（Checkout, Java 17, Flutter SDK stable + cache）
    - 1.3: 配置依赖获取和内核下载步骤（flutter pub get, download_kernels.sh）
    - 1.4: 配置 Android 签名步骤（从 Secrets 解码 keystore，生成 key.properties）
    - 1.5: 配置构建步骤（APK split-per-abi + AAB tag-only）
    - 1.6: 配置缓存策略（Gradle cache, Flutter pub cache）
    - 1.7: 配置产物上传步骤（upload-artifact APK/AAB）
    - 1.8: 配置 GitHub Release 发布步骤（tag 触发时自动创建 Release）
