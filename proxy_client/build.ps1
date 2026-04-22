# Build Script for Windows

param(
    [string]$Version = "dev",
    [switch]$SkipTests,
    [switch]$CreateInstaller
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Proxy Client - Windows Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$RustCoreDir = "rust_core"
$FlutterUiDir = "flutter_ui"
$AppName = "ProxyClient"
$OutputDir = "dist"
$ArtifactName = "$AppName-windows-x64-$Version.zip"

# Step 1: Check prerequisites
Write-Host "[1/7] Checking prerequisites..." -ForegroundColor Yellow

try {
    $rustVersion = rustc --version
    Write-Host "  ✓ Rust: $rustVersion" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Rust not found. Please install from https://rustup.rs/" -ForegroundColor Red
    exit 1
}

try {
    $flutterVersion = flutter --version | Select-Object -First 1
    Write-Host "  ✓ Flutter: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Flutter not found. Please install Flutter SDK" -ForegroundColor Red
    exit 1
}

# Check Windows desktop support
$windowsEnabled = flutter config | Select-String "Windows"
if ($windowsEnabled -notlike "*enable*") {
    Write-Host "  ⚠ Windows desktop not enabled. Enabling..." -ForegroundColor Yellow
    flutter config --enable-windows-desktop
}

# Step 2: Build Rust Core
Write-Host ""
Write-Host "[2/7] Building Rust Core..." -ForegroundColor Yellow
Set-Location $RustCoreDir

try {
    cargo build --release
    Write-Host "  ✓ Rust core built successfully" -ForegroundColor Green
    
    # Verify output
    if (Test-Path "target\release\proxy_client.dll") {
        Write-Host "  ✓ Found proxy_client.dll" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ proxy_client.dll not found (may be normal)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ✗ Rust build failed: $_" -ForegroundColor Red
    exit 1
}

Set-Location ..

# Step 3: Download sing-box
Write-Host ""
Write-Host "[3/7] Downloading sing-box..." -ForegroundColor Yellow

if (-not (Test-Path "$FlutterUiDir\assets\bin")) {
    New-Item -ItemType Directory -Force -Path "$FlutterUiDir\assets\bin" | Out-Null
}

$singBoxUrl = "https://github.com/SagerNet/sing-box/releases/latest/download/sing-box-1.10.0-windows-amd64.zip"
$singBoxZip = "sing-box.zip"

try {
    Invoke-WebRequest -Uri $singBoxUrl -OutFile $singBoxZip -UseBasicParsing
    Write-Host "  ✓ Downloaded sing-box" -ForegroundColor Green
    
    Expand-Archive -Path $singBoxZip -DestinationPath "$FlutterUiDir\assets\bin\" -Force
    Write-Host "  ✓ Extracted sing-box to assets/bin" -ForegroundColor Green
    
    Remove-Item $singBoxZip -Force
} catch {
    Write-Host "  ⚠ Failed to download sing-box: $_" -ForegroundColor Yellow
    Write-Host "    You can download it manually from https://github.com/SagerNet/sing-box/releases" -ForegroundColor Yellow
}

# Step 4: Get Flutter dependencies
Write-Host ""
Write-Host "[4/7] Getting Flutter dependencies..." -ForegroundColor Yellow
Set-Location $FlutterUiDir

try {
    flutter pub get
    Write-Host "  ✓ Dependencies installed" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to get dependencies: $_" -ForegroundColor Red
    exit 1
}

Set-Location ..

# Step 5: Run tests (optional)
if (-not $SkipTests) {
    Write-Host ""
    Write-Host "[5/7] Running tests..." -ForegroundColor Yellow
    Set-Location $FlutterUiDir
    
    try {
        $testResult = flutter test
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ All tests passed" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ Some tests failed" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ⚠ Test execution failed: $_" -ForegroundColor Yellow
    }
    
    Set-Location ..
} else {
    Write-Host ""
    Write-Host "[5/7] Skipping tests (--SkipTests flag used)" -ForegroundColor Yellow
}

# Step 6: Build Flutter Windows App
Write-Host ""
Write-Host "[6/7] Building Flutter Windows App..." -ForegroundColor Yellow
Set-Location $FlutterUiDir

try {
    flutter build windows --release --dart-define=version=$Version
    Write-Host "  ✓ Flutter app built successfully" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Flutter build failed: $_" -ForegroundColor Red
    exit 1
}

Set-Location ..

# Step 7: Package distribution
Write-Host ""
Write-Host "[7/7] Packaging distribution..." -ForegroundColor Yellow

if (Test-Path $OutputDir) {
    Remove-Item $OutputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputDir | Out-Null

# Copy Flutter build output
Write-Host "  Copying Flutter build artifacts..." -ForegroundColor Gray
xcopy /E /I /Y "$FlutterUiDir\build\windows\x64\runner\Release\*" "$OutputDir\" | Out-Null

# Copy sing-box
if (Test-Path "$FlutterUiDir\assets\bin\sing-box.exe") {
    Copy-Item "$FlutterUiDir\assets\bin\sing-box.exe" "$OutputDir\" -Force
    Write-Host "  ✓ Copied sing-box.exe" -ForegroundColor Green
}

# Copy Rust core DLL
if (Test-Path "$RustCoreDir\target\release\proxy_client.dll") {
    Copy-Item "$RustCoreDir\target\release\proxy_client.dll" "$OutputDir\" -Force
    Write-Host "  ✓ Copied proxy_client.dll" -ForegroundColor Green
}

# Create launcher script
Write-Host "  Creating start.bat..." -ForegroundColor Gray
@"
@echo off
echo ========================================
echo   Proxy Client for Windows
echo ========================================
echo.
echo Starting Proxy Client...
echo.
start "" "proxy_client.exe"
echo Application started. You can close this window.
timeout /t 2 >nul
exit
"@ | Out-File -FilePath "$OutputDir\start.bat" -Encoding ASCII

# Create README
Write-Host "  Creating README.txt..." -ForegroundColor Gray
@"
================================================================================
                        PROXY CLIENT FOR WINDOWS
================================================================================

VERSION: $Version
BUILD DATE: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

--------------------------------------------------------------------------------
INSTALLATION
--------------------------------------------------------------------------------

1. Extract all files to a folder of your choice
2. Run proxy_client.exe or start.bat
3. (Optional) Create desktop shortcut

--------------------------------------------------------------------------------
USAGE
--------------------------------------------------------------------------------

1. Import Configuration:
   - Click "Import Config" button
   - Select your JSON/YAML configuration file
   - Or paste configuration URL

2. Select Node:
   - Browse available nodes in the Nodes tab
   - Click on a node to select it
   - Use the search box to find specific nodes

3. Connect:
   - Click the large Connect button
   - Wait for connection to establish
   - Check status indicators

4. Enable TUN Mode (for system-wide proxy):
   - Go to Settings tab
   - Toggle "TUN Mode"
   - Grant administrator permission when prompted

--------------------------------------------------------------------------------
SUPPORTED PROTOCOLS
--------------------------------------------------------------------------------

✓ Shadowsocks / Shadowsocks2022
✓ VMess / VLESS
✓ Trojan
✓ Hysteria / Hysteria2
✓ TUIC
✓ WireGuard
✓ REALITY

--------------------------------------------------------------------------------
REQUIREMENTS
--------------------------------------------------------------------------------

- Windows 10/11 (64-bit)
- Visual C++ Redistributable (usually pre-installed)
- Administrator rights for TUN mode

--------------------------------------------------------------------------------
TROUBLESHOOTING
--------------------------------------------------------------------------------

Q: Application won't start
A: Ensure all DLL files are present in the same directory
   Try running as Administrator

Q: TUN mode fails to enable
A: Run the application as Administrator
   Check Windows Firewall settings

Q: Can't connect to nodes
A: Verify your internet connection
   Check if the configuration is valid
   Try different nodes

Q: High CPU/Memory usage
A: Close unused applications
   Reduce the number of active rules
   Update to the latest version

--------------------------------------------------------------------------------
LOGS & SUPPORT
--------------------------------------------------------------------------------

Log files are stored in: %APPDATA%\ProxyClient\logs

For support and updates, visit: https://github.com/your-username/proxy_client

================================================================================
"@ | Out-File -FilePath "$OutputDir\README.txt" -Encoding ASCII

# Create ZIP archive
Write-Host "  Creating ZIP archive..." -ForegroundColor Gray
Compress-Archive -Path "$OutputDir\*" -DestinationPath $ArtifactName -Force
Write-Host "  ✓ Created $ArtifactName" -ForegroundColor Green

# Create installer (optional)
if ($CreateInstaller) {
    Write-Host ""
    Write-Host "Creating NSIS Installer..." -ForegroundColor Yellow
    
    # Check if NSIS is installed
    $nsisPath = "C:\Program Files (x86)\NSIS\makensis.exe"
    if (-not (Test-Path $nsisPath)) {
        Write-Host "  ⚠ NSIS not found. Download from http://nsis.sourceforge.net/" -ForegroundColor Yellow
        Write-Host "    Skipping installer creation." -ForegroundColor Yellow
    } else {
        # Create NSIS script
        @"
!include "MUI2.nsh"

Name "$AppName"
OutFile "$AppName-Setup-$Version.exe"
InstallDir "`$PROGRAMFILES64\$AppName"
RequestExecutionLevel admin

!define MUI_ABORTWARNING
!define MUI_ICON "installer_icon.ico"

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Install"
  SetOutPath "`$INSTDIR"
  File /r "dist\*.*"
  WriteUninstaller "`$INSTDIR\uninstall.exe"
  
  CreateDirectory "`$SMPROGRAMS\$AppName"
  CreateShortcut "`$SMPROGRAMS\$AppName\$AppName.lnk" "`$INSTDIR\proxy_client.exe"
  CreateShortcut "`$DESKTOP\$AppName.lnk" "`$INSTDIR\proxy_client.exe"
  
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppName" "DisplayName" "$AppName"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppName" "UninstallString" '"`$INSTDIR\uninstall.exe"'
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppName" "DisplayVersion" "$Version"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppName" "Publisher" "Proxy Client Team"
SectionEnd

Section "Uninstall"
  Delete "`$INSTDIR\uninstall.exe"
  RMDir /r "`$INSTDIR"
  
  Delete "`$SMPROGRAMS\$AppName\$AppName.lnk"
  RMDir "`$SMPROGRAMS\$AppName"
  
  Delete "`$DESKTOP\$AppName.lnk"
  
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppName"
SectionEnd
"@ | Out-File -FilePath "installer.nsi" -Encoding ASCII
        
        # Create dummy icon
        Add-Type -AssemblyName System.Drawing
        $icon = New-Object System.Drawing.Bitmap(64, 64)
        $graphics = [System.Drawing.Graphics]::FromImage($icon)
        $graphics.Clear([System.Drawing.Color]::FromArgb(0, 120, 212))
        $icon.Save("installer_icon.ico")
        $icon.Dispose()
        $graphics.Dispose()
        
        # Build installer
        & $nsisPath /V2 installer.nsi
        
        if (Test-Path "$AppName-Setup-$Version.exe") {
            Write-Host "  ✓ Created $AppName-Setup-$Version.exe" -ForegroundColor Green
        }
        
        # Cleanup
        Remove-Item "installer.nsi" -Force -ErrorAction SilentlyContinue
        Remove-Item "installer_icon.ico" -Force -ErrorAction SilentlyContinue
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "           BUILD COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Artifacts:" -ForegroundColor Yellow
Write-Host "  📦 $ArtifactName" -ForegroundColor White

if ($CreateInstaller -and (Test-Path "$AppName-Setup-$Version.exe")) {
    Write-Host "  📦 $AppName-Setup-$Version.exe" -ForegroundColor White
}

Write-Host ""
Write-Host "Distribution contents:" -ForegroundColor Yellow
Get-ChildItem $OutputDir | ForEach-Object {
    Write-Host "  - $($_.Name)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "To test the application:" -ForegroundColor Yellow
Write-Host "  1. Extract $ArtifactName to a test folder" -ForegroundColor Gray
Write-Host "  2. Run proxy_client.exe or start.bat" -ForegroundColor Gray
Write-Host "  3. Import your configuration and test" -ForegroundColor Gray

Write-Host ""
