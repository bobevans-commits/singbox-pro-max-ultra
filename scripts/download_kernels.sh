#!/bin/bash
# Kernel Download Script for CI/CD
# Downloads sing-box, mihomo, and v2ray cores for all platforms

set -e

KERNELS_DIR="${1:-./flutter_ui/assets/bin}"
VERSION_FILE="$KERNELS_DIR/kernel_versions.txt"

echo "🚀 Starting kernel download to: $KERNELS_DIR"
mkdir -p "$KERNELS_DIR"

# Function to download with retry
download_with_retry() {
    local url=$1
    local output=$2
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "  Attempt $attempt/$max_attempts..."
        if curl -L --fail --silent --show-error "$url" -o "$output"; then
            echo "  ✅ Download successful"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    echo "  ❌ Download failed after $max_attempts attempts"
    return 1
}

# Platform detection
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l) ARCH="armv7" ;;
esac

echo "📱 Detected platform: $PLATFORM-$ARCH"

# ========== sing-box ==========
echo ""
echo "📦 Downloading sing-box..."
SINGBOX_VERSION="1.10.0"
declare -A SINGBOX_URLS=(
    ["linux-amd64"]="https://github.com/SagerNet/sing-box/releases/download/v$SINGBOX_VERSION/sing-box-$SINGBOX_VERSION-linux-amd64.tar.gz"
    ["linux-arm64"]="https://github.com/SagerNet/sing-box/releases/download/v$SINGBOX_VERSION/sing-box-$SINGBOX_VERSION-linux-arm64.tar.gz"
    ["darwin-amd64"]="https://github.com/SagerNet/sing-box/releases/download/v$SINGBOX_VERSION/sing-box-$SINGBOX_VERSION-darwin-amd64.tar.gz"
    ["darwin-arm64"]="https://github.com/SagerNet/sing-box/releases/download/v$SINGBOX_VERSION/sing-box-$SINGBOX_VERSION-darwin-arm64.tar.gz"
    ["windows-amd64"]="https://github.com/SagerNet/sing-box/releases/download/v$SINGBOX_VERSION/sing-box-$SINGBOX_VERSION-windows-amd64.zip"
    ["android-aarch64"]="https://github.com/SagerNet/sing-box/releases/download/v$SINGBOX_VERSION/sing-box-$SINGBOX_VERSION-android-aarch64.tar.gz"
)

SINGBOX_KEY="${PLATFORM}-${ARCH}"
if [ -n "${SINGBOX_URLS[$SINGBOX_KEY]}" ]; then
    URL="${SINGBOX_URLS[$SINGBOX_KEY]}"
    FILENAME="sing-box-${SINGBOX_VERSION}-${PLATFORM}-${ARCH}.tar.gz"
    
    echo "  URL: $URL"
    if [[ "$URL" == *.zip ]]; then
        FILENAME="${FILENAME%.tar.gz}.zip"
    fi
    
    download_with_retry "$URL" "$KERNELS_DIR/$FILENAME"
    
    # Extract
    cd "$KERNELS_DIR"
    if [[ "$FILENAME" == *.tar.gz ]]; then
        tar -xzf "$FILENAME"
        mv sing-box*/sing-box* . 2>/dev/null || true
        rm -rf sing-box*/ "$FILENAME"
    elif [[ "$FILENAME" == *.zip ]]; then
        unzip -o "$FILENAME" > /dev/null
        mv sing-box*/sing-box* . 2>/dev/null || true
        rm -rf sing-box*/ "$FILENAME"
    fi
    cd - > /dev/null
    
    echo "  ✅ sing-box downloaded and extracted"
    echo "sing-box: $SINGBOX_VERSION" >> "$VERSION_FILE"
else
    echo "  ⚠️ No sing-box build for $SINGBOX_KEY"
fi

# ========== mihomo (Clash Meta) ==========
echo ""
echo "📦 Downloading mihomo..."
MIHOMO_VERSION="1.18.0"
declare -A MIHOMO_URLS=(
    ["linux-amd64"]="https://github.com/MetaCubeX/mihomo/releases/download/v$MIHOMO_VERSION/mihomo-linux-amd64-v$MIHOMO_VERSION.gz"
    ["linux-arm64"]="https://github.com/MetaCubeX/mihomo/releases/download/v$MIHOMO_VERSION/mihomo-linux-arm64-v$MIHOMO_VERSION.gz"
    ["darwin-amd64"]="https://github.com/MetaCubeX/mihomo/releases/download/v$MIHOMO_VERSION/mihomo-darwin-amd64-v$MIHOMO_VERSION.gz"
    ["darwin-arm64"]="https://github.com/MetaCubeX/mihomo/releases/download/v$MIHOMO_VERSION/mihomo-darwin-arm64-v$MIHOMO_VERSION.gz"
    ["windows-amd64"]="https://github.com/MetaCubeX/mihomo/releases/download/v$MIHOMO_VERSION/mihomo-windows-amd64-v$MIHOMO_VERSION.zip"
    ["android-aarch64"]="https://github.com/MetaCubeX/mihomo/releases/download/v$MIHOMO_VERSION/mihomo-android-arm64-v$MIHOMO_VERSION.gz"
)

MIHOMO_KEY="${PLATFORM}-${ARCH}"
if [ -n "${MIHOMO_URLS[$MIHOMO_KEY]}" ]; then
    URL="${MIHOMO_URLS[$MIHOMO_KEY]}"
    FILENAME="mihomo-${MIHOMO_VERSION}-${PLATFORM}-${ARCH}"
    
    echo "  URL: $URL"
    if [[ "$URL" == *.zip ]]; then
        FILENAME="${FILENAME}.zip"
    else
        FILENAME="${FILENAME}.gz"
    fi
    
    download_with_retry "$URL" "$KERNELS_DIR/$FILENAME"
    
    # Extract
    cd "$KERNELS_DIR"
    if [[ "$FILENAME" == *.gz ]]; then
        gunzip -f "$FILENAME"
        chmod +x mihomo 2>/dev/null || true
    elif [[ "$FILENAME" == *.zip ]]; then
        unzip -o "$FILENAME" > /dev/null
        chmod +x mihomo.exe 2>/dev/null || true
        rm -f "$FILENAME"
    fi
    cd - > /dev/null
    
    echo "  ✅ mihomo downloaded and extracted"
    echo "mihomo: $MIHOMO_VERSION" >> "$VERSION_FILE"
else
    echo "  ⚠️ No mihomo build for $MIHOMO_KEY"
fi

# ========== v2ray (Xray-core) ==========
echo ""
echo "📦 Downloading v2ray (Xray-core)..."
V2RAY_VERSION="5.13.0"
declare -A V2RAY_URLS=(
    ["linux-amd64"]="https://github.com/XTLS/Xray-core/releases/download/v$V2RAY_VERSION/Xray-linux-64.zip"
    ["linux-arm64"]="https://github.com/XTLS/Xray-core/releases/download/v$V2RAY_VERSION/Xray-linux-arm64-v8a.zip"
    ["darwin-amd64"]="https://github.com/XTLS/Xray-core/releases/download/v$V2RAY_VERSION/Xray-macos-64.zip"
    ["darwin-arm64"]="https://github.com/XTLS/Xray-core/releases/download/v$V2RAY_VERSION/Xray-macos-arm64-v8a.zip"
    ["windows-amd64"]="https://github.com/XTLS/Xray-core/releases/download/v$V2RAY_VERSION/Xray-windows-64.zip"
    ["android-aarch64"]="https://github.com/XTLS/Xray-core/releases/download/v$V2RAY_VERSION/Xray-android-arm64-v8a.zip"
)

V2RAY_KEY="${PLATFORM}-${ARCH}"
if [ -n "${V2RAY_URLS[$V2RAY_KEY]}" ]; then
    URL="${V2RAY_URLS[$V2RAY_KEY]}"
    FILENAME="v2ray-${V2RAY_VERSION}-${PLATFORM}-${ARCH}.zip"
    
    echo "  URL: $URL"
    download_with_retry "$URL" "$KERNELS_DIR/$FILENAME"
    
    # Extract
    cd "$KERNELS_DIR"
    unzip -o "$FILENAME" > /dev/null
    if [ -f "xray" ]; then
        mv xray xray-bin 2>/dev/null || true
    fi
    if [ -f "xray.exe" ]; then
        mv xray.exe xray-bin.exe 2>/dev/null || true
    fi
    rm -f "$FILENAME"
    cd - > /dev/null
    
    echo "  ✅ v2ray downloaded and extracted"
    echo "v2ray: $V2RAY_VERSION" >> "$VERSION_FILE"
else
    echo "  ⚠️ No v2ray build for $V2RAY_KEY"
fi

echo ""
echo "✅ All kernels downloaded successfully!"
echo ""
echo "📋 Kernel versions:"
cat "$VERSION_FILE" 2>/dev/null || echo "No version file created"
echo ""
echo "📁 Files in $KERNELS_DIR:"
ls -lh "$KERNELS_DIR"
