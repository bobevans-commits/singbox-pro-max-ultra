#!/bin/bash
# Linux Build Script
# Generates AppImage and DEB packages

set -e

APP_NAME="ProxyClient"
FLUTTER_UI_DIR="flutter_ui"
RUST_CORE_DIR="rust_core"
VERSION="${1:-dev}"

echo "🚀 Starting Linux build..."
echo "   Version: $VERSION"

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev appstream

# Create directories
mkdir -p "$FLUTTER_UI_DIR/assets/bin"

# Download kernels
echo ""
echo "📥 Downloading kernels..."
bash scripts/download_kernels.sh "$FLUTTER_UI_DIR/assets/bin"

# Build Rust core
if [ -f "$RUST_CORE_DIR/Cargo.toml" ]; then
    echo ""
    echo "🦀 Building Rust core..."
    cd "$RUST_CORE_DIR"
    cargo build --release
    cd ..
fi

# Build Flutter
echo ""
echo "🎯 Building Flutter app..."
cd "$FLUTTER_UI_DIR"
flutter pub get
flutter build linux --release
cd ..

# Create distribution directory
DIST_DIR="dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Copy build output
cp -r "$FLUTTER_UI_DIR/build/linux/x64/release/bundle/"* "$DIST_DIR/"

# Copy kernels
cp "$FLUTTER_UI_DIR/assets/bin/sing-box" "$DIST_DIR/" 2>/dev/null || true
cp "$FLUTTER_UI_DIR/assets/bin/mihomo" "$DIST_DIR/" 2>/dev/null || true
cp "$FLUTTER_UI_DIR/assets/bin/xray" "$DIST_DIR/" 2>/dev/null || true

# Make binaries executable
chmod +x "$DIST_DIR/"*.so* 2>/dev/null || true
chmod +x "$DIST_DIR/sing-box" 2>/dev/null || true
chmod +x "$DIST_DIR/mihomo" 2>/dev/null || true
chmod +x "$DIST_DIR/xray" 2>/dev/null || true

# ========== Create AppImage ==========
echo ""
echo "📦 Creating AppImage..."

APPDIR="AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# Copy files to AppDir
cp -r "$DIST_DIR/"* "$APPDIR/usr/bin/"

# Create desktop file
cat > "$APPDIR/$APP_NAME.desktop" << EOF
[Desktop Entry]
Name=$APP_NAME
Comment=Proxy Client with TUN support
Exec=$APP_NAME
Icon=$APP_NAME
Type=Application
Categories=Network;Utility;
Keywords=proxy;vpn;tun;sing-box;mihomo;
EOF

cp "$APPDIR/$APP_NAME.desktop" "$APPDIR/usr/share/applications/"

# Create icon (placeholder)
if [ -f "$FLUTTER_UI_DIR/assets/icon.png" ]; then
    cp "$FLUTTER_UI_DIR/assets/icon.png" "$APPDIR/$APP_NAME.png"
    cp "$APP_NAME.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/" 2>/dev/null || true
else
    # Create simple placeholder icon
    convert -size 256x256 xc:blue "$APPDIR/$APP_NAME.png" 2>/dev/null || echo "No icon created"
fi

# Create AppRun script
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="$HERE/usr/bin:$PATH"
export LD_LIBRARY_PATH="$HERE/usr/lib:$HERE/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
exec "$HERE/usr/bin/proxy_client" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Download appimagetool
if [ ! -f "appimagetool-x86_64.AppImage" ]; then
    wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
fi

# Build AppImage
ARCH=x86_64 ./appimagetool-x86_64.AppImage "$APPDIR" "${APP_NAME}-linux-x86_64.AppImage"

# ========== Create DEB package ==========
echo ""
echo "📦 Creating DEB package..."

DEB_DIR="deb_build"
DEB_NAME="${APP_NAME}_${VERSION}_amd64.deb"
rm -rf "$DEB_DIR"
mkdir -p "$DEB_DIR/DEBIAN"
mkdir -p "$DEB_DIR/usr/bin"
mkdir -p "$DEB_DIR/usr/share/applications"
mkdir -p "$DEB_DIR/usr/share/doc/$APP_NAME"

# Copy files
cp -r "$DIST_DIR/"* "$DEB_DIR/usr/bin/"

# Create control file
cat > "$DEB_DIR/DEBIAN/control" << EOF
Package: $APP_NAME
Version: ${VERSION#v}
Section: net
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, liblzma5, libstdc++6
Maintainer: Proxy Client Team
Description: Proxy Client with TUN support
 A modern proxy client supporting multiple protocols and cores.
Features:
 - sing-box, mihomo, v2ray core support
 - TUN mode for system-wide proxy
 - Rule-based routing
 - Split DNS
EOF

# Copy desktop and docs
cp "$APPDIR/$APP_NAME.desktop" "$DEB_DIR/usr/share/applications/" 2>/dev/null || true
cp "$DIST_DIR/README.txt" "$DEB_DIR/usr/share/doc/$APP_NAME/" 2>/dev/null || true

# Build DEB
dpkg-deb --build "$DEB_DIR" "$DEB_NAME"

echo ""
echo "✅ Build completed successfully!"
echo ""
echo "📁 Generated files:"
ls -lh "${APP_NAME}-linux-x86_64.AppImage"
ls -lh "$DEB_NAME"
