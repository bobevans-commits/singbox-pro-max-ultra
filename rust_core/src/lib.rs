//! 多平台代理客户端核心库
//! 
//! 支持 sing-box, mihomo, v2ray-core 等多种内核
//! 提供统一的配置管理、内核生命周期管理和系统代理设置

pub mod config;
pub mod core;
pub mod kernels;
pub mod ipc;

use thiserror::Error;

#[derive(Error, Debug)]
pub enum ProxyClientError {
    #[error("配置错误：{0}")]
    ConfigError(String),
    
    #[error("内核错误：{0}")]
    KernelError(String),
    
    #[error("系统代理设置失败：{0}")]
    SystemProxyError(String),
    
    #[error("IPC 通信错误：{0}")]
    IpcError(String),
}

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

/// 核心客户端结构
pub struct ProxyClient {
    kernel_type: KernelType,
    status: KernelStatus,
    config_path: String,
}

impl ProxyClient {
    pub fn new(kernel_type: KernelType, config_path: &str) -> Self {
        Self {
            kernel_type,
            status: KernelStatus::Stopped,
            config_path: config_path.to_string(),
        }
    }
    
    pub async fn start(&mut self) -> Result<()> {
        self.status = KernelStatus::Starting;
        
        match self.kernel_type {
            KernelType::SingBox => {
                kernels::singbox::start(&self.config_path).await?;
            }
            KernelType::Mihomo => {
                kernels::mihomo::start(&self.config_path).await?;
            }
            KernelType::V2Ray => {
                kernels::v2ray::start(&self.config_path).await?;
            }
        }
        
        self.status = KernelStatus::Running;
        Ok(())
    }
    
    pub async fn stop(&mut self) -> Result<()> {
        self.status = KernelStatus::Stopping;
        
        match self.kernel_type {
            KernelType::SingBox => {
                kernels::singbox::stop().await?;
            }
            KernelType::Mihomo => {
                kernels::mihomo::stop().await?;
            }
            KernelType::V2Ray => {
                kernels::v2ray::stop().await?;
            }
        }
        
        self.status = KernelStatus::Stopped;
        Ok(())
    }
    
    pub fn get_status(&self) -> &KernelStatus {
        &self.status
    }
    
    pub fn set_system_proxy(&self, enable: bool) -> Result<()> {
        if enable {
            core::system_proxy::enable()
        } else {
            core::system_proxy::disable()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_client_creation() {
        let client = ProxyClient::new(KernelType::SingBox, "/tmp/config.json");
        assert_eq!(*client.get_status(), KernelStatus::Stopped);
    }
    
    #[test]
    fn test_kernel_type_serialization() {
        let json = serde_json::to_string(&KernelType::Mihomo).unwrap();
        assert!(json.contains("Mihomo"));
    }
}
