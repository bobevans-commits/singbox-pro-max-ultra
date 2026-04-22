# Fix GitHub Actions Workflows

## Problem Summary

Both GitHub Actions workflow files (`multi-platform-build.yml` and `windows-build.yml`) were written for a monorepo structure with `rust_core/` and `flutter_ui/` subdirectories, but the actual project is a flat Flutter project at the repository root with **no Rust code at all**. This means every workflow will fail immediately on execution.

## Current Project Structure

```
singbox-pro-max-ultra/
  lib/             # Flutter source code (root level)
  android/         # Android manifest only (no Gradle files)
  assets/          # Empty (should hold kernel binaries)
  scripts/         # Build helper scripts
  test/            # Dart tests
  pubspec.yaml     # At root level
```

Key facts:
- **No `rust_core/` directory** - no `.rs` files, no `Cargo.toml` anywhere
- **No `flutter_ui/` directory** - Flutter source is at root (`lib/`, `pubspec.yaml`)
- **Android project incomplete** - only `AndroidManifest.xml` exists, no Gradle build files
- `scripts/download_kernels.sh` has the correct URL pattern for kernel downloads

## Issues to Fix

### Issue 1: Remove all Rust-related steps (BOTH workflows)

Rust setup, build, and cache steps are entirely unnecessary since no Rust code exists in the project.

**Affected in `multi-platform-build.yml`:**
- Lines 40-49: `Setup Rust`, `Cache Rust` steps in Windows job
- Lines 67-68: `Build Rust Core` step in Windows job
- Lines 107-117: `Setup Rust`, `Cache Rust` steps in macOS job
- Lines 133-142: `Build Rust Core (Universal)` step in macOS job
- Lines 183-193: `Setup Rust`, `Cache Rust` steps in Linux job
- Lines 209-211: `Build Rust Core` step in Linux job
- Lines 272-281: `Setup Rust`, `Install Android NDK`, `Build Rust Core for Android` steps in Android job
- Lines 23-28: `RUST_VERSION`, `RUST_CORE_DIR`, `FLUTTER_UI_DIR` env vars

**Affected in `windows-build.yml`:**
- Lines 38-49: `Setup Rust`, `Cache Rust dependencies` steps
- Lines 65-70: `Build Rust Core (Release)` step
- Lines 72-90: `Copy Rust Core to Flutter assets` step (partially - keep sing-box download)
- Lines 21: `RUST_CORE_DIR` env var
- Lines 186-195: `Upload build logs` referencing Rust paths

### Issue 2: Fix `working-directory` references (multi-platform-build.yml)

All `working-directory: ${{ env.FLUTTER_UI_DIR }}` (which resolves to `flutter_ui`) must be removed since Flutter code is at root.

**All occurrences:** Lines 60, 64, 80, 127, 131, 152, 203, 207, 221, 291, 306, 310

### Issue 3: Fix `if` condition syntax (multi-platform-build.yml)

Lines 35, 102, 173, 261 use `${{ }} || ` which mixes GitHub Actions expression syntax incorrectly.

**Current (broken):**
```yaml
if: ${{ github.event_name == 'workflow_dispatch' && contains(github.event.inputs.platforms, 'windows') }} || github.event_name != 'workflow_dispatch'
```

**Should be:**
```yaml
if: >-
  ${{ github.event_name == 'workflow_dispatch' && contains(github.event.inputs.platforms, 'windows') }} ||
  ${{ github.event_name != 'workflow_dispatch' }}
```

Or simpler:
```yaml
if: github.event_name != 'workflow_dispatch' || contains(github.event.inputs.platforms, 'windows')
```

### Issue 4: Fix sing-box download URLs (BOTH workflows)

URLs use `/latest/download/` with a hardcoded version `1.10.0` which is contradictory. The `scripts/download_kernels.sh` uses the correct pattern.

**Current (broken):**
```
https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-1.10.0-windows-amd64.zip
```

**Should be:**
```
https://github.com/SagerNet/sing-box/releases/download/v1.10.0/sing-box-1.10.0-windows-amd64.zip
```

Also add `SINGBOX_VERSION` env var for maintainability.

### Issue 5: Fix macOS sing-box download (multi-platform-build.yml)

Only downloads `darwin-amd64`, should also support Apple Silicon (`darwin-arm64`). Use universal approach or download both.

### Issue 6: Fix Windows build - Copy Rust Core step (windows-build.yml)

Lines 72-90: The step tries to copy from `rust_core/target/...` which doesn't exist. Should be simplified to only download sing-box to `assets/bin/`.

### Issue 7: Remove `flutter config --enable-*-desktop` steps (BOTH workflows)

`--enable-windows-desktop`, `--enable-macos-desktop`, `--enable-linux-desktop` are unnecessary since Flutter 3.24.0 has them enabled by default.

### Issue 8: Fix path references in packaging steps (BOTH workflows)

**multi-platform-build.yml:**
- Line 86: `flutter_ui\build\windows\x64\runner\Release\*` -> `build\windows\x64\runner\Release\*`
- Line 87: `flutter_ui\assets\bin\` -> `assets\bin\`
- Line 73-76: `flutter_ui/assets/bin` -> `assets/bin`
- Line 146: `flutter_ui/assets/bin` -> `assets/bin`
- Line 157: `flutter_ui/build/macos/...` -> `build/macos/...`
- Line 158: `flutter_ui/assets/bin/` -> `assets/bin/`
- Line 215: `flutter_ui/assets/bin` -> `assets/bin`
- Line 226-227: `flutter_ui/build/linux/...`, `flutter_ui/assets/bin/` -> root paths
- Line 295: `flutter_ui/android/app/src/main/jniLibs` -> `android/app/src/main/jniLibs`
- Line 300: `flutter_ui/assets/bin` -> `assets/bin`
- Line 317-318: `flutter_ui/build/...` -> `build/...`

**windows-build.yml:**
- Line 78: `copy ..\${{ env.RUST_CORE_DIR }}\target\...` -> remove (no Rust)
- Line 104: `build\windows\x64\runner\Release\*` -> OK (already root path)
- Line 107-108: `assets\bin\` references -> OK
- Line 155: `..\$zipName` -> should be `$zipName` at root or adjust path
- Line 193: `${{ env.RUST_CORE_DIR }}/target/...` -> remove

### Issue 9: Fix NSIS installer job (windows-build.yml)

- Line 211: Artifact name `windows-build-${{ github.run_number }}` - run_number may differ between jobs
- Line 217: `refreshenv` doesn't work in GitHub Actions; NSIS needs to be on PATH explicitly

### Issue 10: Fix Android build job (multi-platform-build.yml)

- `cargo ndk` command is used but `cargo-ndk` is never installed
- Android project lacks Gradle files entirely
- Should add Gradle setup and remove Rust/NDK steps
- Download sing-box for both arm64 and x86_64

### Issue 11: Fix `git-lfs/git-lfs@v3` action reference (windows-build.yml)

Line 36: Should use `git-lfs/git-lfs-action@v3` or just `git lfs install && git lfs pull` in a run step.

### Issue 12: Linux AppImage desktop file indentation (multi-platform-build.yml)

Lines 239-244: The heredoc indentation will add leading spaces to the `.desktop` file, which may cause parsing issues.

### Issue 13: Branch triggers should include `dev` (windows-build.yml)

Line 5: Only watches `main`, should also include `dev` branch for consistency.

## Architecture & Approach

### Strategy: Fix both workflows to match the actual project structure

1. **Remove all Rust-related steps** - no Rust code exists
2. **Remove `FLUTTER_UI_DIR` and `RUST_CORE_DIR` env vars** - not needed
3. **Remove all `working-directory: flutter_ui`** - Flutter is at root
4. **Fix all path references** - change from `flutter_ui/...` and `rust_core/...` to root-relative paths
5. **Fix sing-box download URLs** - use proper version-specific download path
6. **Add `SINGBOX_VERSION` env var** - centralized version management
7. **Fix `if` condition syntax** - proper GitHub Actions expression syntax
8. **Simplify Android build** - remove Rust/NDK, add proper Flutter Android setup
9. **Remove deprecated Flutter config flags** - `--enable-*-desktop` not needed
10. **Fix NSIS installer** - artifact name, PATH issues

### Data Flow

```
Checkout -> Setup Flutter -> flutter pub get -> Download sing-box -> flutter build -> Package -> Upload Artifact
```

## Expected Outcomes

- Both workflows can successfully build on their respective platforms
- No references to non-existent `rust_core/` or `flutter_ui/` directories
- sing-box kernel downloads use correct URLs
- Android build works with proper Flutter Android setup
- Windows NSIS installer job works correctly
- All `if` conditions use proper syntax
