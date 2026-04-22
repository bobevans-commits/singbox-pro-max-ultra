//! 内核适配器模块
//! 
//! 提供对不同代理内核的统一抽象，包括 sing-box、mihomo 和 v2ray。

pub mod singbox;
pub mod mihomo;
pub mod v2ray;

use crate::{Result, ProxyClientError};
use tokio::process::Child;
use std::sync::Arc;
use tokio::sync::Mutex;

/// 内核 trait，定义统一的内核操作接口
#[async_trait::async_trait]
pub trait Kernel {
    /// 内核名称
    const NAME: &'static str;
    
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

/// 进程管理器，用于统一管理内核进程
pub struct ProcessManager {
    process: Arc<Mutex<Option<Child>>>,
}

impl ProcessManager {
    /// 创建新的进程管理器
    pub fn new() -> Self {
        Self {
            process: Arc::new(Mutex::new(None)),
        }
    }
    
    /// 启动进程
    pub async fn spawn(&self, mut command: tokio::process::Command) -> Result<()> {
        let mut process_lock = self.process.lock().await;
        
        if process_lock.is_some() {
            return Err(ProxyClientError::KernelError(format!("{} 已经在运行", Self::get_kernel_name())));
        }
        
        let child = command.spawn()
            .map_err(|e| ProxyClientError::KernelError(format!("启动进程失败：{}", e)))?;
        
        *process_lock = Some(child);
        Ok(())
    }
    
    /// 停止进程
    pub async fn terminate(&self) -> Result<()> {
        let mut process_lock = self.process.lock().await;
        
        if let Some(mut child) = process_lock.take() {
            // Unix 系统发送 SIGTERM 信号
            #[cfg(unix)]
            {
                use nix::sys::signal::{kill, Signal};
                use nix::unistd::Pid;
                
                if let Some(pid) = child.id() {
                    let _ = kill(Pid::from_raw(pid as i32), Signal::SIGTERM);
                }
            }
            
            // 等待进程退出
            let _ = child.wait().await;
        }
        
        Ok(())
    }
    
    /// 检查进程是否正在运行
    pub async fn is_running(&self) -> bool {
        let process_lock = self.process.lock().await;
        process_lock.is_some()
    }
    
    /// 获取内核名称（用于错误消息）
    fn get_kernel_name() -> &'static str {
        "Kernel"
    }
}

impl Default for ProcessManager {
    fn default() -> Self {
        Self::new()
    }
}
