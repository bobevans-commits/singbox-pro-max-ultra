# Build script for Windows
# Usage: .\build_windows.ps1 [-Version "v1.0.0"] [-SignCert "path/to/cert.pfx"]

param(
    [string]$Version = "dev",
    [string]$SignCert = "",
    [string]$SignPassword = ""
)

$ErrorActionPreference = "Stop"
$APP_NAME = "ProxyClient"
$FLUTTER_UI_DIR = "flutter_ui"
$RUST_CORE_DIR = "rust_core"
$OUTPUT_DIR = "dist"
$BIN_DIR = "$FLUTTER_UI_DIR/assets/bin"

Write-Host "🚀 Starting Windows build..." -ForegroundColor Green
Write-Host "   Version: $Version" -ForegroundColor Cyan

# Create directories
New-Item -ItemType Directory -Force -Path $BIN_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $OUTPUT_DIR | Out-Null

# Download kernels
Write-Host "`n📦 Downloading kernels..." -ForegroundColor Yellow
& bash scripts/download_kernels.sh "$BIN_DIR"

# Build Rust core (if exists)
if (Test-Path "$RUST_CORE_DIR/Cargo.toml") {
    Write-Host "`n🦀 Building Rust core..." -ForegroundColor Yellow
    Set-Location $RUST_CORE_DIR
    cargo build --release
    if ($LASTEXITCODE -ne 0) {
        throw "Rust build failed"
    }
    
    # Copy to assets
    Copy-Item "target/x86_64-pc-windows-msvc/release/proxy_client.dll" "../$BIN_DIR/" -ErrorAction SilentlyContinue
    Copy-Item "target/x86_64-pc-windows-msvc/release/proxy_client.exe" "../$BIN_DIR/" -ErrorAction SilentlyContinue
    Set-Location ..
}

# Build Flutter
Write-Host "`n🎯 Building Flutter app..." -ForegroundColor Yellow
Set-Location $FLUTTER_UI_DIR
flutter pub get
flutter build windows --release --dart-define=version=$Version
if ($LASTEXITCODE -ne 0) {
    throw "Flutter build failed"
}
Set-Location ..

# Package
Write-Host "`n📦 Packaging application..." -ForegroundColor Yellow
$BUILD_OUTPUT = "$FLUTTER_UI_DIR/build/windows/x64/runner/Release"
Copy-Item "$BUILD_OUTPUT/*" "$OUTPUT_DIR/" -Recurse -Force

# Copy kernels
if (Test-Path "$BIN_DIR/sing-box.exe") {
    Copy-Item "$BIN_DIR/sing-box.exe" "$OUTPUT_DIR/" -Force
}
if (Test-Path "$BIN_DIR/mihomo.exe") {
    Copy-Item "$BIN_DIR/mihomo.exe" "$OUTPUT_DIR/" -Force
}
if (Test-Path "$BIN_DIR/xray.exe") {
    Copy-Item "$BIN_DIR/xray.exe" "$OUTPUT_DIR/" -Force
}

# Create launcher script
@"
@echo off
echo Starting $APP_NAME...
start "" "$APP_NAME.exe"
exit
"@ | Out-File -FilePath "$OUTPUT_DIR/start.bat" -Encoding ASCII

# Create README
@"
# $APP_NAME for Windows

## Requirements
- Windows 10/11 (64-bit)
- Visual C++ Redistributable

## Usage
1. Run `$APP_NAME.exe` or `start.bat`
2. Import your configuration
3. Select a node and connect

## Supported Cores
- sing-box ✓
- mihomo (Clash Meta) ✓
- v2ray (Xray-core) ✓

## Troubleshooting
- Run as Administrator for TUN mode
- Check logs in %APPDATA%\$APP_NAME\logs
"@ | Out-File -FilePath "$OUTPUT_DIR/README.txt" -Encoding ASCII

# Sign if certificate provided
if ($SignCert -and (Test-Path $SignCert)) {
    Write-Host "`n🔐 Signing executable..." -ForegroundColor Yellow
    signtool sign /f $SignCert /p $SignPassword /tr http://timestamp.digicert.com /td sha256 /fd sha256 "$OUTPUT_DIR/$APP_NAME.exe"
}

# Create ZIP
$ZIP_NAME = "${APP_NAME}-windows-x64-${Version}.zip"
Write-Host "`n📄 Creating ZIP: $ZIP_NAME" -ForegroundColor Yellow
Compress-Archive -Path "$OUTPUT_DIR/*" -DestinationPath $ZIP_NAME -Force

Write-Host "`n✅ Build completed successfully!" -ForegroundColor Green
Write-Host "   Output: $ZIP_NAME" -ForegroundColor Cyan
