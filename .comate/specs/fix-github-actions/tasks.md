# Fix GitHub Actions Workflows - Task Plan

- [x] Task 1: Fix multi-platform-build.yml - Remove Rust and fix directory structure
    - 1.1: Remove `RUST_VERSION`, `RUST_CORE_DIR`, `FLUTTER_UI_DIR` env vars, add `SINGBOX_VERSION: '1.10.0'`
    - 1.2: Fix Windows job - remove Rust setup/cache/build steps, remove `working-directory` from Flutter steps, fix `if` condition, fix sing-box download URL, fix packaging paths
    - 1.3: Fix macOS job - remove Rust setup/cache/build steps, remove `working-directory` from Flutter steps, fix `if` condition, fix sing-box download URL (add arm64 support), fix packaging paths
    - 1.4: Fix Linux job - remove Rust setup/cache/build steps, remove `working-directory` from Flutter steps, fix `if` condition, fix sing-box download URL, fix packaging paths, fix desktop file indentation
    - 1.5: Fix Android job - remove Rust/NDK/cargo-ndk steps, remove `working-directory` from Flutter steps, fix `if` condition, fix sing-box download URL and path, fix artifact upload paths
    - 1.6: Fix create-release job - update `softprops/action-gh-release` to v2

- [x] Task 2: Fix windows-build.yml - Remove Rust and fix paths
    - 2.1: Remove `RUST_VERSION`, `RUST_CORE_DIR` env vars, add `SINGBOX_VERSION: '1.10.0'`
    - 2.2: Remove Git LFS step (not needed), remove Rust setup/cache/build steps
    - 2.3: Rewrite "Copy Rust Core to Flutter assets" step as "Download sing-box" only
    - 2.4: Remove `flutter config --enable-windows-desktop` (unnecessary in Flutter 3.24+)
    - 2.5: Fix NSIS installer job - fix artifact download name, fix NSIS PATH after install, remove `refreshenv`
    - 2.6: Fix upload build logs step - remove Rust core path references
    - 2.7: Add `dev` branch to push trigger
