# Universal-Proxy-Party: Technical Architecture Document

## 1. Recommended Tech Stack

### Primary Recommendation: **Tauri + Rust + React**

**Why Tauri over Electron?**
- **Smaller bundle size**: ~3MB vs ~150MB (critical for distribution)
- **Better performance**: Rust backend is significantly faster than Node.js
- **Lower memory footprint**: Essential for a proxy app running in background
- **Security**: Rust's memory safety prevents common vulnerabilities
- **Native OS integration**: Better system tray, network, and process management

**Stack Components:**
- **Frontend**: React 18 + TypeScript + Vite + TailwindCSS
- **Backend**: Rust + Tauri v2
- **State Management**: Zustand (lightweight) or TanStack Query
- **Styling**: TailwindCSS + shadcn/ui components
- **Build Tool**: Vite (frontend), Cargo (backend)

### Alternative: Electron + Node.js + Vue 3
(Only if you need specific Node.js npm packages without Rust bindings)

---

## 2. Kernel Adapter Interface Design (Rust)

### Core Trait Definition

```rust
// src/kernel/adapter.rs

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tokio::process::Child;

/// Standardized kernel statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KernelStats {
    pub upload_total: u64,
    pub download_total: u64,
    pub upload_speed: u64,
    pub download_speed: u64,
    pub connections: Vec<Connection>,
    pub memory_usage: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Connection {
    pub id: String,
    pub metadata: ConnectionMetadata,
    pub upload: u64,
    pub download: u64,
    pub start_time: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConnectionMetadata {
    pub network: String,
    pub source_ip: String,
    pub destination_ip: String,
    pub destination_port: u16,
    pub host: Option<String>,
    pub process_path: Option<String>,
}

/// Health check result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HealthStatus {
    pub is_healthy: bool,
    pub latency_ms: Option<u128>,
    pub message: String,
    pub last_check: chrono::DateTime<chrono::Utc>,
}

/// Configuration validation result
#[derive(Debug, Clone)]
pub struct ConfigValidation {
    pub is_valid: bool,
    pub errors: Vec<String>,
    pub warnings: Vec<String>,
}

/// Unified kernel adapter interface
#[async_trait]
pub trait KernelAdapter: Send + Sync {
    /// Returns the kernel name (e.g., "sing-box", "mihomo", "v2ray")
    fn kernel_name(&self) -> &'static str;
    
    /// Returns the kernel version string
    async fn get_version(&self) -> Result<String, KernelError>;
    
    /// Start the kernel with given configuration path
    async fn start(&mut self, config_path: &str) -> Result<(), KernelError>;
    
    /// Stop the running kernel gracefully
    async fn stop(&mut self) -> Result<(), KernelError>;
    
    /// Restart the kernel (stop + start)
    async fn restart(&mut self, config_path: Option<&str>) -> Result<(), KernelError>;
    
    /// Check if kernel is currently running
    fn is_running(&self) -> bool;
    
    /// Get real-time statistics
    async fn fetch_stats(&self) -> Result<KernelStats, KernelError>;
    
    /// Perform health check
    async fn health_check(&self) -> Result<HealthStatus, KernelError>;
    
    /// Validate configuration file
    async fn validate_config(&self, config_path: &str) -> Result<ConfigValidation, KernelError>;
    
    /// Get external controller API URL (if applicable)
    fn get_controller_url(&self) -> Option<String>;
    
    /// Set log level dynamically
    async fn set_log_level(&self, level: LogLevel) -> Result<(), KernelError>;
}

/// Log levels supported across kernels
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum LogLevel {
    Silent,
    Error,
    Warn,
    Info,
    Debug,
    Trace,
}

/// Unified error type for kernel operations
#[derive(Debug, thiserror::Error)]
pub enum KernelError {
    #[error("Kernel not found: {0}")]
    NotFound(String),
    
    #[error("Failed to start kernel: {0}")]
    StartFailed(String),
    
    #[error("Failed to stop kernel: {0}")]
    StopFailed(String),
    
    #[error("Kernel process error: {0}")]
    ProcessError(#[from] tokio::process::ExitStatus),
    
    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),
    
    #[error("Configuration error: {0}")]
    ConfigError(String),
    
    #[error("Network error: {0}")]
    NetworkError(String),
    
    #[error("Timeout error: {0}")]
    Timeout(String),
    
    #[error("Already running")]
    AlreadyRunning,
    
    #[error("Not running")]
    NotRunning,
    
    #[error("Unsupported operation: {0}")]
    Unsupported(String),
}

impl Serialize for KernelError {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_str(&self.to_string())
    }
}
```

---

## 3. Project Directory Structure

```
universal-proxy-party/
├── .github/                          # GitHub Actions workflows
│   └── workflows/
│       ├── ci.yml
│       └── release.yml
│
├── assets/                           # Static assets (icons, splash screens)
│   ├── icons/
│   │   ├── icon.icns
│   │   ├── icon.ico
│   │   └── icon.png
│   └── splash.html
│
├── binaries/                         # External kernel binaries (managed separately)
│   ├── README.md                     # Instructions for downloading binaries
│   └── download_scripts/             # Scripts to fetch binaries
│       ├── download-singbox.sh
│       ├── download-mihomo.sh
│       └── download-v2ray.sh
│
├── docs/                             # Documentation
│   ├── ARCHITECTURE.md
│   ├── CONTRIBUTING.md
│   └── USER_GUIDE.md
│
├── frontend/                         # React + TypeScript Frontend
│   ├── public/
│   │   └── locales/                  # i18n translations
│   │       ├── en/
│   │       ├── zh-CN/
│   │       └── ja/
│   ├── src/
│   │   ├── components/               # Reusable UI components
│   │   │   ├── ui/                   # shadcn/ui components
│   │   │   ├── kernel/               # Kernel-specific components
│   │   │   ├── proxy/                # Proxy management components
│   │   │   └── settings/             # Settings components
│   │   ├── hooks/                    # Custom React hooks
│   │   │   ├── useKernel.ts
│   │   │   ├── useProxy.ts
│   │   │   └── useConfig.ts
│   │   ├── pages/                    # Page components
│   │   │   ├── Dashboard.tsx
│   │   │   ├── Proxies.tsx
│   │   │   ├── Rules.tsx
│   │   │   ├── Logs.tsx
│   │   │   ├── Configs.tsx
│   │   │   └── Settings.tsx
│   │   ├── stores/                   # Zustand state stores
│   │   │   ├── kernelStore.ts
│   │   │   ├── proxyStore.ts
│   │   │   └── configStore.ts
│   │   ├── types/                    # TypeScript type definitions
│   │   ├── utils/                    # Utility functions
│   │   ├── App.tsx
│   │   ├── main.tsx
│   │   └── index.css
│   ├── tests/                        # Frontend tests
│   ├── index.html
│   ├── package.json
│   ├── tsconfig.json
│   ├── vite.config.ts
│   └── tailwind.config.js
│
├── src-tauri/                        # Tauri + Rust Backend
│   ├── src/
│   │   ├── kernel/                   # Kernel management logic
│   │   │   ├── mod.rs
│   │   │   ├── adapter.rs            # KernelAdapter trait (from above)
│   │   │   ├── manager.rs            # Kernel lifecycle manager
│   │   │   ├── singbox.rs            # Sing-box adapter implementation
│   │   │   ├── mihomo.rs             # Mihomo (Clash) adapter implementation
│   │   │   └── v2ray.rs              # V2Ray adapter implementation
│   │   ├── config/                   # Configuration handling
│   │   │   ├── mod.rs
│   │   │   ├── converter.rs          # Config format converters
│   │   │   ├── validator.rs          # Config validation
│   │   │   └── profiles.rs           # Profile management
│   │   ├── proxy/                    # Proxy system integration
│   │   │   ├── mod.rs
│   │   │   ├── system_proxy.rs       # System proxy setter
│   │   │   ├── tun_mode.rs           # TUN mode manager
│   │   │   └── pac.rs                # PAC file generator
│   │   ├── utils/                    # Utility modules
│   │   │   ├── mod.rs
│   │   │   ├── binary_manager.rs     # Binary asset management
│   │   │   ├── logger.rs             # Logging setup
│   │   │   └── platform.rs           # Platform-specific helpers
│   │   ├── commands.rs               # Tauri commands (IPC)
│   │   ├── error.rs                  # Error types
│   │   ├── lib.rs                    # Library root
│   │   └── main.rs                   # Application entry point
│   ├── tests/                        # Integration tests
│   ├── Cargo.toml
│   ├── tauri.conf.json               # Tauri configuration
│   ├── build.rs                      # Build script
│   └── icons/                        # Tauri icons
│
├── scripts/                          # Development & deployment scripts
│   ├── dev.sh                        # Local development setup
│   ├── build.sh                      # Cross-platform build
│   ├── release.sh                    # Release automation
│   └── update-binaries.sh            # Binary update helper
│
├── .gitignore
├── .prettierrc
├── .eslintrc.js
├── Cargo.toml                        # Workspace Cargo config
├── package.json                      # Root package.json
├── pnpm-workspace.yaml               # Monorepo config (if using pnpm)
├── README.md
└── LICENSE
```

---

## 4. Managing External Binary Assets

### Strategy Overview

Managing external binaries (sing-box, mihomo, v2ray) across platforms requires careful consideration of:
- **Platform differences** (Windows `.exe`, macOS, Linux)
- **Architecture differences** (x86_64, arm64, aarch64)
- **Version management**
- **Automatic updates**
- **Security verification** (checksums, signatures)

### Implementation Approach

#### A. Binary Manager Module (`src/utils/binary_manager.rs`)

```rust
// src-tauri/src/utils/binary_manager.rs

use std::path::{Path, PathBuf};
use std::fs;
use reqwest::Client;
use sha2::{Sha256, Digest};
use semver::Version;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BinaryInfo {
    pub name: String,
    pub version: Version,
    pub platform: String,
    pub arch: String,
    pub url: String,
    pub checksum: String,
    pub checksum_type: String, // "sha256" or "sha512"
}

#[derive(Debug, Clone)]
pub enum Platform {
    Windows,
    MacOS,
    Linux,
}

impl Platform {
    pub fn current() -> Self {
        #[cfg(target_os = "windows")]
        return Platform::Windows;
        
        #[cfg(target_os = "macos")]
        return Platform::MacOS;
        
        #[cfg(target_os = "linux")]
        return Platform::Linux;
    }
    
    pub fn as_str(&self) -> &'static str {
        match self {
            Platform::Windows => "windows",
            Platform::MacOS => "darwin",
            Platform::Linux => "linux",
        }
    }
}

pub struct BinaryManager {
    client: Client,
    base_dir: PathBuf,
}

impl BinaryManager {
    pub fn new() -> Result<Self, BinaryError> {
        let base_dir = Self::get_binary_storage_path()?;
        fs::create_dir_all(&base_dir)?;
        
        Ok(Self {
            client: Client::new(),
            base_dir,
        })
    }
    
    /// Get the appropriate storage path based on OS
    fn get_binary_storage_path() -> Result<PathBuf, BinaryError> {
        let dirs = nextapp_dirs::BaseDirs::new()
            .ok_or(BinaryError::NoHomeDir)?;
        
        let base_path = match Platform::current() {
            Platform::Windows => dirs.data_local_dir().join("universal-proxy-party"),
            Platform::MacOS => dirs.home_dir().join("Library/Application Support/universal-proxy-party"),
            Platform::Linux => dirs.config_dir().join("universal-proxy-party"),
        };
        
        Ok(base_path.join("binaries"))
    }
    
    /// Get the path for a specific kernel binary
    pub fn get_binary_path(&self, kernel: &str, version: &Version) -> PathBuf {
        let platform = Platform::current();
        let ext = match platform {
            Platform::Windows => ".exe",
            _ => "",
        };
        
        self.base_dir
            .join(kernel)
            .join(version.to_string())
            .join(format!("{}{}", kernel, ext))
    }
    
    /// Download and verify a binary
    pub async fn download_binary(&self, info: &BinaryInfo) -> Result<PathBuf, BinaryError> {
        let binary_path = self.get_binary_path(&info.name, &info.version);
        
        // Skip if already exists and valid
        if binary_path.exists() && self.verify_checksum(&binary_path, &info.checksum).await? {
            log::info!("Binary already exists and verified: {:?}", binary_path);
            return Ok(binary_path);
        }
        
        // Create directory structure
        fs::create_dir_all(binary_path.parent().unwrap())?;
        
        // Download
        log::info!("Downloading {} v{} from {}", info.name, info.version, info.url);
        let response = self.client.get(&info.url).send().await?;
        let bytes = response.bytes().await?;
        
        // Verify checksum before writing
        if !self.verify_bytes_checksum(&bytes, &info.checksum, &info.checksum_type)? {
            return Err(BinaryError::ChecksumMismatch);
        }
        
        // Write to disk
        fs::write(&binary_path, &bytes)?;
        
        // Set executable permissions (Unix only)
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = fs::metadata(&binary_path)?.permissions();
            perms.set_mode(0o755);
            fs::set_permissions(&binary_path, perms)?;
        }
        
        log::info!("Binary downloaded successfully: {:?}", binary_path);
        Ok(binary_path)
    }
    
    /// Verify file checksum
    async fn verify_checksum(&self, path: &Path, expected: &str) -> Result<bool, BinaryError> {
        let bytes = fs::read(path)?;
        self.verify_bytes_checksum(&bytes, expected, "sha256")
    }
    
    /// Verify bytes checksum
    fn verify_bytes_checksum(&self, bytes: &[u8], expected: &str, checksum_type: &str) -> Result<bool, BinaryError> {
        let computed = match checksum_type {
            "sha256" => {
                let mut hasher = Sha256::new();
                hasher.update(bytes);
                format!("{:x}", hasher.finalize())
            },
            "sha512" => {
                use sha2::Sha512;
                let mut hasher = Sha512::new();
                hasher.update(bytes);
                format!("{:x}", hasher.finalize())
            },
            _ => return Err(BinaryError::UnsupportedChecksumType),
        };
        
        Ok(computed == expected)
    }
    
    /// List available binaries
    pub fn list_binaries(&self) -> Result<Vec<(String, Version, PathBuf)>, BinaryError> {
        let mut binaries = Vec::new();
        
        if !self.base_dir.exists() {
            return Ok(binaries);
        }
        
        for kernel_entry in fs::read_dir(&self.base_dir)? {
            let kernel_entry = kernel_entry?;
            let kernel_name = kernel_entry.file_name().to_string_lossy().to_string();
            
            for version_entry in fs::read_dir(kernel_entry.path())? {
                let version_entry = version_entry?;
                let version_str = version_entry.file_name().to_string_lossy().to_string();
                
                if let Ok(version) = Version::parse(&version_str) {
                    let binary_path = self.get_binary_path(&kernel_name, &version);
                    if binary_path.exists() {
                        binaries.push((kernel_name.clone(), version, binary_path));
                    }
                }
            }
        }
        
        Ok(binaries)
    }
    
    /// Remove old binary versions (keep latest N)
    pub fn cleanup_old_versions(&self, kernel: &str, keep_count: usize) -> Result<(), BinaryError> {
        let kernel_path = self.base_dir.join(kernel);
        
        if !kernel_path.exists() {
            return Ok(());
        }
        
        let mut versions: Vec<Version> = fs::read_dir(&kernel_path)?
            .filter_map(|entry| {
                entry.ok().and_then(|e| {
                    Version::parse(&e.file_name().to_string_lossy()).ok()
                })
            })
            .collect();
        
        versions.sort_by(|a, b| b.cmp(a)); // Sort descending
        
        // Remove versions beyond keep_count
        for version in versions.iter().skip(keep_count) {
            let version_path = kernel_path.join(version.to_string());
            if version_path.exists() {
                fs::remove_dir_all(&version_path)?;
                log::info!("Cleaned up old version: {} v{}", kernel, version);
            }
        }
        
        Ok(())
    }
}

#[derive(Debug, thiserror::Error)]
pub enum BinaryError {
    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),
    
    #[error("Download error: {0}")]
    DownloadError(#[from] reqwest::Error),
    
    #[error("Checksum mismatch")]
    ChecksumMismatch,
    
    #[error("Unsupported checksum type")]
    UnsupportedChecksumType,
    
    #[error("No home directory found")]
    NoHomeDir,
    
    #[error("Invalid version: {0}")]
    InvalidVersion(#[from] semver::Error),
}
```

#### B. Binary Repository Configuration

Create a JSON manifest for known binary sources:

```json
// assets/binary-repositories.json
{
  "sing-box": {
    "repository": "https://api.github.com/repos/SagerNet/sing-box/releases",
    "asset_pattern": "sing-box-{version}-{platform}-{arch}.{ext}",
    "checksum_url": "https://github.com/SagerNet/sing-box/releases/download/{tag}/sing-box-{version}-{platform}-{arch}.txt",
    "supported_platforms": ["windows", "darwin", "linux"],
    "supported_archs": ["amd64", "arm64", "armv7"]
  },
  "mihomo": {
    "repository": "https://api.github.com/repos/MetaCubeX/mihomo/releases",
    "asset_pattern": "mihomo-{platform}-{arch}-{version}.{ext}",
    "checksum_url": null,
    "supported_platforms": ["windows", "darwin", "linux"],
    "supported_archs": ["amd64", "arm64", "armv7"]
  },
  "v2ray-core": {
    "repository": "https://api.github.com/repos/v2fly/v2ray-core/releases",
    "asset_pattern": "v2ray-{platform}-{arch}.{ext}",
    "checksum_url": "https://github.com/v2fly/v2ray-core/releases/download/{tag}/v2ray-{platform}-{arch}.zip.sha256sum",
    "supported_platforms": ["windows", "darwin", "linux"],
    "supported_archs": ["amd64", "arm64", "armv7"]
  }
}
```

#### C. Tauri Configuration for Bundling Binaries

Optionally bundle default binaries with the app:

```json
// src-tauri/tauri.conf.json
{
  "bundle": {
    "resources": [
      "../binaries/default/*"
    ],
    "externalBin": [
      "binaries/sing-box",
      "binaries/mihomo",
      "binaries/v2ray"
    ]
  }
}
```

#### D. Automatic Update Strategy

```rust
// Auto-update binaries on app startup or user trigger
pub async fn check_and_update_binaries() -> Result<(), BinaryError> {
    let manager = BinaryManager::new()?;
    let repos = load_binary_repositories()?;
    
    for (kernel_name, repo_info) in repos {
        // Fetch latest version from GitHub API
        let latest = fetch_latest_release(&repo_info.repository).await?;
        
        // Check if we have it
        let current = manager.list_binaries()?
            .iter()
            .filter(|(name, _, _)| name == &kernel_name)
            .map(|(_, v, _)| v)
            .max();
        
        if current.is_none() || current.unwrap() < &latest.version {
            // Download new version
            let binary_info = construct_binary_info(&kernel_name, &latest, &repo_info)?;
            manager.download_binary(&binary_info).await?;
            
            // Cleanup old versions (keep last 2)
            manager.cleanup_old_versions(&kernel_name, 2)?;
        }
    }
    
    Ok(())
}
```

---

## 5. Key Architectural Decisions Summary

### Why This Architecture?

1. **Tauri + Rust**: Best performance/security trade-off for system-level proxy app
2. **Trait-based Adapter Pattern**: Enables easy addition of new kernels
3. **Separation of Concerns**: Clear boundaries between UI, business logic, and system integration
4. **Binary Management**: Secure, verifiable, auto-updating external dependencies
5. **Cross-platform**: Single codebase for Windows, macOS, Linux

### Next Steps

After setting up this architecture:
1. Implement concrete adapters for each kernel (sing-box, mihomo, v2ray)
2. Build the React frontend with proxy management UI
3. Implement system proxy switching logic
4. Add TUN mode support for advanced routing
5. Create configuration converter utilities

This foundation provides a robust, maintainable, and extensible base for your multi-kernel proxy application.
