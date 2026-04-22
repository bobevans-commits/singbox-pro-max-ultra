//! 多平台代理客户端核心库
//! 
//! # 特性
//! 
//! - 支持多种代理内核：sing-box, mihomo (Clash.Meta), v2ray-core
//! - 统一的配置管理和内核生命周期管理
//! - 跨平台系统代理设置支持
//! - IPC 通信用于与 UI 层交互
//! 
//! # 架构
//! 
//! ```text
//! ┌─────────────────┐
//! │   Flutter UI    │
//! └────────┬────────┘
//!          │ FFI / Platform Channels
//! ┌────────▼────────┐
//! │  Rust Core Lib  │
//! ├─────────────────┤
//! │  ProxyClient    │ ← 统一接口
//! ├─────────────────┤
//! │  Kernel Trait   │ ← 内核抽象层
//! ├──────┬────┬─────┤
//! │SingBox│Mihomo│V2Ray│
//! └──────┴────┴─────┘
//! ```
//! 
//! # 快速开始
//! 
//! ```rust,no_run
//! use proxy_client_core::{ProxyClient, KernelType};
//! 
//! #[tokio::main]
//! async fn main() -> Result<(), Box<dyn std::error::Error>> {
//!     // 创建客户端
//!     let mut client = ProxyClient::new(KernelType::SingBox, "config.json");
//!     
//!     // 启动内核
//!     client.start().await?;
//!     
//!     // 启用系统代理
//!     client.set_system_proxy(true)?;
//!     
//!     // ... 使用代理服务
//!     
//!     // 清理
//!     client.set_system_proxy(false)?;
//!     client.stop().await?;
//!     
//!     Ok(())
//! }
//! ```

pub mod config;
pub mod core;
pub mod kernels;
pub mod ipc;

use thiserror::Error;

/// 代理客户端错误类型
#[derive(Error, Debug)]
pub enum ProxyClientError {
    /// 配置相关错误
    #[error("配置错误：{0}")]
    ConfigError(String),
    
    /// 内核相关错误
    #[error("内核错误：{0}")]
    KernelError(String),
    
    /// 系统代理设置错误
    #[error("系统代理设置失败：{0}")]
    SystemProxyError(String),
    
    /// IPC 通信错误
    #[error("IPC 通信错误：{0}")]
    IpcError(String),
}

/// 结果类型别名
pub type Result<T> = std::result::Result<T, ProxyClientError>;

/// 代理内核类型枚举
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
pub enum KernelType {
    SingBox,
    Mihomo,
    V2Ray,
}

/// 内核状态
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
pub enum KernelStatus {
    Stopped,
    Starting,
    Running,
    Stopping,
    Error(String),
}

/// 核心客户端结构体
/// 
/// 提供统一的代理内核管理接口，包括启动、停止、状态查询和系统代理设置。
pub struct ProxyClient {
    kernel_type: KernelType,
    status: KernelStatus,
    config_path: String,
}

impl ProxyClient {
    /// 创建新的代理客户端
    /// 
    /// # 参数
    /// * `kernel_type` - 要使用的内核类型
    /// * `config_path` - 配置文件路径
    /// 
    /// # 示例
    /// ```
    /// use proxy_client_core::{ProxyClient, KernelType};
    /// 
    /// let client = ProxyClient::new(KernelType::SingBox, "config.json");
    /// ```
    pub fn new(kernel_type: KernelType, config_path: &str) -> Self {
        Self {
            kernel_type,
            status: KernelStatus::Stopped,
            config_path: config_path.to_string(),
        }
    }
    
    /// 启动代理内核
    pub async fn start(&mut self) -> Result<()> {
        self.status = KernelStatus::Starting;
        
        let result = match self.kernel_type {
            KernelType::SingBox => {
                kernels::singbox::start(&self.config_path).await
            }
            KernelType::Mihomo => {
                kernels::mihomo::start(&self.config_path).await
            }
            KernelType::V2Ray => {
                kernels::v2ray::start(&self.config_path).await
            }
        };
        
        match result {
            Ok(_) => {
                self.status = KernelStatus::Running;
                Ok(())
            }
            Err(e) => {
                self.status = KernelStatus::Error(e.to_string());
                Err(e)
            }
        }
    }
    
    /// 停止代理内核
    pub async fn stop(&mut self) -> Result<()> {
        if matches!(self.status, KernelStatus::Stopped | KernelStatus::Error(_)) {
            return Ok(());
        }
        
        self.status = KernelStatus::Stopping;
        
        let result = match self.kernel_type {
            KernelType::SingBox => {
                kernels::singbox::stop().await
            }
            KernelType::Mihomo => {
                kernels::mihomo::stop().await
            }
            KernelType::V2Ray => {
                kernels::v2ray::stop().await
            }
        };
        
        self.status = KernelStatus::Stopped;
        result
    }
    
    /// 获取当前内核状态
    pub fn get_status(&self) -> &KernelStatus {
        &self.status
    }
    
    /// 获取当前内核类型
    pub fn get_kernel_type(&self) -> &KernelType {
        &self.kernel_type
    }
    
    /// 设置系统代理
    /// 
    /// # 参数
    /// * `enable` - true 启用代理，false 禁用代理
    pub fn set_system_proxy(&self, enable: bool) -> Result<()> {
        if enable {
            core::system_proxy::enable()
        } else {
            core::system_proxy::disable()
        }
    }
    
    /// 重启内核
    pub async fn restart(&mut self) -> Result<()> {
        self.stop().await?;
        self.start().await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_client_creation() {
        let client = ProxyClient::new(KernelType::SingBox, "/tmp/config.json");
        assert_eq!(*client.get_status(), KernelStatus::Stopped);
        assert_eq!(client.get_kernel_type(), &KernelType::SingBox);
    }
    
    #[test]
    fn test_kernel_type_serialization() {
        let json = serde_json::to_string(&KernelType::Mihomo).unwrap();
        assert!(json.contains("Mihomo"));
    }
    
    #[test]
    fn test_kernel_status_display() {
        let status = KernelStatus::Running;
        // Just verify it can be cloned and compared
        assert_eq!(status, KernelStatus::Running);
    }
    
    #[test]
    fn test_error_types() {
        let config_err = ProxyClientError::ConfigError("test".to_string());
        assert!(matches!(config_err, ProxyClientError::ConfigError(_)));
        
        let kernel_err = ProxyClientError::KernelError("test".to_string());
        assert!(matches!(kernel_err, ProxyClientError::KernelError(_)));
    }
}
