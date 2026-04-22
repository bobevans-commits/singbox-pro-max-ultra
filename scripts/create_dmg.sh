#!/bin/bash
# macOS DMG Creation Script
# Creates a signed/unsigned DMG for distribution

set -e

APP_NAME="ProxyClient"
FLUTTER_UI_DIR="flutter_ui"
RUST_CORE_DIR="rust_core"
VERSION="${1:-dev}"

echo "🚀 Starting macOS build..."
echo "   Version: $VERSION"

# Create directories
mkdir -p "$FLUTTER_UI_DIR/assets/bin"

# Download kernels
echo ""
echo "📥 Downloading kernels..."
bash scripts/download_kernels.sh "$FLUTTER_UI_DIR/assets/bin"

# Build Rust core (Universal Binary)
if [ -f "$RUST_CORE_DIR/Cargo.toml" ]; then
    echo ""
    echo "🦀 Building Rust core (Universal)..."
    cd "$RUST_CORE_DIR"
    
    # Build for both architectures
    cargo build --release --target x86_64-apple-darwin
    cargo build --release --target aarch64-apple-darwin
    
    # Create universal binary
    mkdir -p target/universal
    lipo -create \
        target/x86_64-apple-darwin/release/libproxy_client.dylib \
        target/aarch64-apple-darwin/release/libproxy_client.dylib \
        -output target/universal/libproxy_client.dylib
    
    cd ..
fi

# Build Flutter
echo ""
echo "🎯 Building Flutter app..."
cd "$FLUTTER_UI_DIR"
flutter pub get
flutter build macos --release
cd ..

# Create distribution directory
DIST_DIR="dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Copy app bundle
cp -R "$FLUTTER_UI_DIR/build/macos/Build/Products/Release/$APP_NAME.app" "$DIST_DIR/"

# Copy kernels to app bundle
cp "$FLUTTER_UI_DIR/assets/bin/sing-box" "$DIST_DIR/$APP_NAME.app/Contents/MacOS/" 2>/dev/null || true
cp "$FLUTTER_UI_DIR/assets/bin/mihomo" "$DIST_DIR/$APP_NAME.app/Contents/MacOS/" 2>/dev/null || true
cp "$FLUTTER_UI_DIR/assets/bin/xray" "$DIST_DIR/$APP_NAME.app/Contents/MacOS/" 2>/dev/null || true

# Make executable
chmod +x "$DIST_DIR/$APP_NAME.app/Contents/MacOS/"* 2>/dev/null || true

# Sign the app (optional, requires developer certificate)
if command -v codesign &> /dev/null && [ -n "$APPLE_DEVELOPER_ID" ]; then
    echo ""
    echo "🔐 Signing application..."
    codesign --force --deep --sign "$APPLE_DEVELOPER_ID" "$DIST_DIR/$APP_NAME.app"
else
    echo ""
    echo "⚠️  Skipping code signing (no certificate found)"
fi

# Create DMG
echo ""
echo "📦 Creating DMG..."

DMG_NAME="${APP_NAME}-macos-universal.dmg"
VOLUME_NAME="$APP_NAME"

# Create temporary DMG
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$DIST_DIR" \
    -ov -format UDZO \
    -fs HFS+ \
    "$DMG_NAME"

echo ""
echo "✅ Build completed successfully!"
echo ""
echo "📁 Generated file:"
ls -lh "$DMG_NAME"

# Notarization (optional, requires Apple ID)
if command -v xcrun &> /dev/null && [ -n "$APPLE_ID" ] && [ -n "$APPLE_APP_PASSWORD" ]; then
    echo ""
    echo "🔐 Submitting for notarization..."
    xcrun notarytool submit "$DMG_NAME" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --team-id "$APPLE_TEAM_ID" \
        --wait
    
    # Staple the ticket
    xcrun stapler staple "$DMG_NAME"
    echo "✅ Notarization complete"
fi
