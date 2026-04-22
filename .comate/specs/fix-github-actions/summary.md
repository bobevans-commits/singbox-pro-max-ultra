# Fix GitHub Actions Workflows - Summary

## Changes Made

### multi-platform-build.yml

1. **Removed all Rust-related steps** - Removed `RUST_VERSION`, `RUST_CORE_DIR`, `FLUTTER_UI_DIR` env vars; removed Rust setup, cache, and build steps from all 4 platform jobs (Windows, macOS, Linux, Android)
2. **Added `SINGBOX_VERSION: '1.10.0'`** env var for centralized version management
3. **Fixed `if` condition syntax** - Changed from broken `${{ expr }} || expr` to proper `github.event_name != 'workflow_dispatch' || contains(...)`
4. **Removed all `working-directory: flutter_ui`** - Flutter source is at repo root, not in a subdirectory
5. **Fixed sing-box download URLs** - Changed from `/latest/download/sing-box-1.10.0-...` (contradictory) to `/download/v1.10.0/sing-box-1.10.0-...` (correct versioned path)
6. **Fixed macOS sing-box** - Now downloads both amd64 and arm64 binaries for full Apple Silicon support
7. **Fixed Android sing-box** - Now downloads both aarch64 and x86_64; removed `cargo ndk` and NDK steps entirely
8. **Fixed all packaging paths** - Changed `flutter_ui/build/...` to `build/...`, `flutter_ui/assets/bin/` to `assets/bin/`, etc.
9. **Fixed Linux `.desktop` file** - Used heredoc delimiter `DESKTOP_EOF` with quotes to prevent leading whitespace
10. **Updated `softprops/action-gh-release`** from v1 to v2 with `generate_release_notes: true`
11. **Removed deprecated `flutter config --enable-*-desktop`** steps (not needed in Flutter 3.24+)
12. **Fixed sing-box extraction** - Added proper `mv` from versioned subdirectory and cleanup

### windows-build.yml

1. **Removed `RUST_VERSION`, `RUST_CORE_DIR`** env vars; added `SINGBOX_VERSION: '1.10.0'`
2. **Removed Git LFS step** - Not needed for this project
3. **Removed all Rust steps** - Rust setup, cache, build, and "Copy Rust Core to Flutter assets" steps
4. **Replaced Rust copy step with clean "Download sing-box" step** - Downloads and extracts sing-box to `assets/bin/` with proper cleanup
5. **Removed `flutter config --enable-windows-desktop`** - Unnecessary in Flutter 3.24+
6. **Added `dev` branch** to push trigger (was only `main`)
7. **Fixed NSIS installer** - Replaced broken `refreshenv` with explicit NSIS PATH lookup; removed dummy icon creation
8. **Fixed ZIP archive creation** - Removed incorrect `..\` prefix from `Compress-Archive` path
9. **Removed upload build logs step** - Referenced non-existent Rust paths; not useful without Rust

## Root Cause

Both workflow files were written for a monorepo layout (`rust_core/` + `flutter_ui/`) that never existed in this repository. The actual project is a flat Flutter application at the repository root with no Rust code at all.
