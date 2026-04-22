# Android 专用 GitHub Action - 总结

## 完成内容

新增 `.github/workflows/android-build.yml`，实现独立的 Android 构建工作流。

### 工作流特性

| 特性 | 说明 |
|---|---|
| **触发方式** | Push (main/dev/develop) + Tag (v*) + PR (main) + 手动 dispatch |
| **路径过滤** | 仅 `android/`、`lib/`、`pubspec.yaml`、工作流文件变更时触发 |
| **构建产物** | APK (arm64-v8a, armeabi-v7a, x86_64) + AAB (仅 tag 触发) |
| **签名** | 有 Secrets 时使用 release 签名，无则 debug 签名兜底 |
| **缓存** | Flutter SDK + Gradle caches |
| **Release** | Tag 推送时自动创建 GitHub Release 并附带所有产物 |

### 依赖的 Secrets（可选）

- `ANDROID_KEYSTORE` - Base64 编码的 keystore
- `ANDROID_KEY_PASSWORD` - keystore 密码
- `ANDROID_KEY_ALIAS` - 密钥别名

不配置时仍可正常构建（使用 debug 签名）。

### 修改文件

- `.github/workflows/android-build.yml` — 新增
