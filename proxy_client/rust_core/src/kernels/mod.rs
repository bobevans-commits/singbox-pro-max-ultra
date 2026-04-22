//! 内核适配器模块

pub mod singbox;
pub mod mihomo;
pub mod v2ray;

use crate::Result;

/// 内核 trait，定义统一的内核操作接口
#[async_trait::async_trait]
pub trait Kernel {
    /// 启动内核
    async fn start(config_path: &str) -> Result<()>;
    
    /// 停止内核
    async fn stop() -> Result<()>;
    
    /// 重启内核
    async fn restart(config_path: &str) -> Result<()> {
        Self::stop().await?;
        Self::start(config_path).await
    }
    
    /// 获取内核版本
    async fn version() -> Result<String>;
    
    /// 检查内核是否正在运行
    async fn is_running() -> bool;
}
