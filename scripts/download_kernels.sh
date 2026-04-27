#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${1:-./assets/bin}"
PLATFORM="${2:-}"
ARCH="${3:-}"

SINGBOX_VERSION="1.10.0"
MIHOMO_VERSION="1.18.1"
XRAY_VERSION="25.1.2"

mkdir -p "$OUTPUT_DIR"

download_singbox() {
  local platform="$1"
  local arch="$2"

  local arch_name="$arch"
  if [[ "$platform" == "windows" && "$arch" == "amd64" ]]; then
    arch_name="amd64"
  elif [[ "$platform" == "darwin" && "$arch" == "amd64" ]]; then
    arch_name="amd64"
  elif [[ "$platform" == "darwin" && "$arch" == "arm64" ]]; then
    arch_name="arm64"
  fi

  local ext="zip"
  local url="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-${platform}-${arch_name}.${ext}"

  echo "Downloading sing-box v${SINGBOX_VERSION} for ${platform}-${arch_name}..."
  curl -fSL -o "/tmp/sing-box-${platform}-${arch_name}.zip" "$url" || {
    echo "Warning: Failed to download sing-box for ${platform}-${arch_name}"
    return 1
  }

  local extract_dir="/tmp/sing-box-${platform}-${arch_name}"
  mkdir -p "$extract_dir"
  unzip -o "/tmp/sing-box-${platform}-${arch_name}.zip" -d "$extract_dir"

  local binary_name="sing-box"
  if [[ "$platform" == "windows" ]]; then
    binary_name="sing-box.exe"
  fi

  local found_binary
  found_binary=$(find "$extract_dir" -name "$binary_name" -type f | head -1)
  if [[ -n "$found_binary" ]]; then
    cp "$found_binary" "$OUTPUT_DIR/$binary_name"
    chmod +x "$OUTPUT_DIR/$binary_name" 2>/dev/null || true
    echo "sing-box downloaded to $OUTPUT_DIR/$binary_name"
  else
    echo "Warning: sing-box binary not found in archive"
  fi

  rm -rf "$extract_dir" "/tmp/sing-box-${platform}-${arch_name}.zip"
}

download_mihomo() {
  local platform="$1"
  local arch="$2"

  local arch_name="$arch"
  if [[ "$platform" == "windows" && "$arch" == "amd64" ]]; then
    arch_name="amd64"
  fi

  local url="https://github.com/MetaCubeX/mihomo/releases/download/v${MIHOMO_VERSION}/mihomo-${platform}-${arch_name}-v${MIHOMO_VERSION}.gz"

  echo "Downloading mihomo v${MIHOMO_VERSION} for ${platform}-${arch_name}..."
  curl -fSL -o "/tmp/mihomo-${platform}-${arch_name}.gz" "$url" || {
    echo "Warning: Failed to download mihomo for ${platform}-${arch_name}"
    return 1
  }

  local binary_name="mihomo"
  if [[ "$platform" == "windows" ]]; then
    binary_name="mihomo.exe"
  fi

  gunzip -c "/tmp/mihomo-${platform}-${arch_name}.gz" > "$OUTPUT_DIR/$binary_name"
  chmod +x "$OUTPUT_DIR/$binary_name" 2>/dev/null || true
  echo "mihomo downloaded to $OUTPUT_DIR/$binary_name"

  rm -f "/tmp/mihomo-${platform}-${arch_name}.gz"
}

download_xray() {
  local platform="$1"
  local arch="$2"

  local arch_name="$arch"
  if [[ "$platform" == "windows" && "$arch" == "amd64" ]]; then
    arch_name="64"
  elif [[ "$platform" == "windows" && "$arch" == "arm64" ]]; then
    arch_name="arm64"
  elif [[ "$platform" == "linux" && "$arch" == "amd64" ]]; then
    arch_name="64"
  elif [[ "$platform" == "linux" && "$arch" == "arm64" ]]; then
    arch_name="arm64"
  elif [[ "$platform" == "darwin" && "$arch" == "amd64" ]]; then
    arch_name="macos-amd64"
  elif [[ "$platform" == "darwin" && "$arch" == "arm64" ]]; then
    arch_name="macos-arm64"
  fi

  local url="https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-${platform}-${arch_name}.zip"

  echo "Downloading xray v${XRAY_VERSION} for ${platform}-${arch_name}..."
  curl -fSL -o "/tmp/xray-${platform}-${arch_name}.zip" "$url" || {
    echo "Warning: Failed to download xray for ${platform}-${arch_name}"
    return 1
  }

  local extract_dir="/tmp/xray-${platform}-${arch_name}"
  mkdir -p "$extract_dir"
  unzip -o "/tmp/xray-${platform}-${arch_name}.zip" -d "$extract_dir"

  local binary_name="xray"
  if [[ "$platform" == "windows" ]]; then
    binary_name="xray.exe"
  fi

  local found_binary
  found_binary=$(find "$extract_dir" -name "$binary_name" -type f | head -1)
  if [[ -n "$found_binary" ]]; then
    cp "$found_binary" "$OUTPUT_DIR/$binary_name"
    chmod +x "$OUTPUT_DIR/$binary_name" 2>/dev/null || true
    echo "xray downloaded to $OUTPUT_DIR/$binary_name"
  else
    echo "Warning: xray binary not found in archive"
  fi

  rm -rf "$extract_dir" "/tmp/xray-${platform}-${arch_name}.zip"
}

detect_platform() {
  local os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  case "$os" in
    linux*) echo "linux" ;;
    darwin*) echo "darwin" ;;
    mingw*|msys*|cygwin*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

detect_arch() {
  local arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) echo "unknown" ;;
  esac
}

main() {
  if [[ -z "$PLATFORM" ]]; then
    PLATFORM="$(detect_platform)"
  fi
  if [[ -z "$ARCH" ]]; then
    ARCH="$(detect_arch)"
  fi

  echo "Downloading kernels for platform=$PLATFORM arch=$ARCH to $OUTPUT_DIR"

  download_singbox "$PLATFORM" "$ARCH" || true
  download_mihomo "$PLATFORM" "$ARCH" || true
  download_xray "$PLATFORM" "$ARCH" || true

  echo "Done. Files in $OUTPUT_DIR:"
  ls -la "$OUTPUT_DIR/" 2>/dev/null || true
}

main
