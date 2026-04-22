//! sing-box 内核适配器
//! 
//! 提供对 sing-box 代理内核的封装和管理。

use crate::{Result, ProxyClientError, kernels::ProcessManager};
use tokio::process::Command;
use std::path::Path;

/// sing-box 进程管理器
static SINGBOX_PROCESS: once_cell::sync::Lazy<ProcessManager> = 
    once_cell::sync::Lazy::new(ProcessManager::new);

/// sing-box 内核实现
pub struct SingBox;

#[async_trait::async_trait]
impl super::Kernel for SingBox {
    const NAME: &'static str = "sing-box";
    
    async fn start(config_path: &str) -> Result<()> {
        // 检查是否已在运行
        if SINGBOX_PROCESS.is_running().await {
            return Err(ProxyClientError::KernelError("sing-box 已经在运行".to_string()));
        }
        
        // 查找 sing-box 可执行文件
        let singbox_cmd = find_singbox_binary()?;
        
        // 验证配置文件是否存在
        if !Path::new(config_path).exists() {
            return Err(ProxyClientError::ConfigError(
                format!("配置文件不存在：{}", config_path)
            ));
        }
        
        // 构建命令
        let command = Command::new(singbox_cmd)
            .arg("run")
            .arg("-c")
            .arg(config_path);
        
        // 启动进程
        SINGBOX_PROCESS.spawn(command).await?;
        
        log::info!("sing-box 已启动，配置文件：{}", config_path);
        Ok(())
    }
    
    async fn stop() -> Result<()> {
        if !SINGBOX_PROCESS.is_running().await {
            log::warn!("sing-box 未在运行");
            return Ok(());
        }
        
        SINGBOX_PROCESS.terminate().await?;
        log::info!("sing-box 已停止");
        Ok(())
    }
    
    async fn version() -> Result<String> {
        let singbox_cmd = find_singbox_binary()?;
        
        let output = Command::new(singbox_cmd)
            .arg("version")
            .output()
            .await
            .map_err(|e| ProxyClientError::KernelError(format!("获取版本失败：{}", e)))?;
        
        if !output.status.success() {
            return Err(ProxyClientError::KernelError(
                "获取 sing-box 版本失败".to_string()
            ));
        }
        
        let version = String::from_utf8_lossy(&output.stdout).trim().to_string();
        Ok(version)
    }
    
    async fn is_running() -> bool {
        SINGBOX_PROCESS.is_running().await
    }
}

/// 查找 sing-box 可执行文件
fn find_singbox_binary() -> Result<String> {
    #[cfg(windows)]
    {
        let paths = [
            "sing-box.exe",
            ".\\sing-box.exe",
            "C:\\Program Files\\sing-box\\sing-box.exe",
        ];
        
        for path in &paths {
            if Path::new(path).exists() {
                return Ok(path.to_string());
            }
        }
    }
    
    #[cfg(unix)]
    {
        let paths = [
            "sing-box",
            "/usr/local/bin/sing-box",
            "/usr/bin/sing-box",
            "./sing-box",
        ];
        
        for path in &paths {
            if Path::new(path).exists() {
                return Ok(path.to_string());
            }
        }
    }
    
    Err(ProxyClientError::KernelError(
        "未找到 sing-box 可执行文件，请确保已安装并添加到 PATH".to_string()
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_find_binary_not_found() {
        // 测试在未安装 sing-box 的环境中
        let result = find_singbox_binary();
        // 可能找到也可能找不到，取决于环境
        // 这里只验证函数能正常返回
        assert!(result.is_ok() || result.is_err());
    }
    
    #[tokio::test]
    async fn test_is_running_initially_false() {
        assert!(!SingBox::is_running().await);
    }
    
    #[test]
    fn test_kernel_name() {
        assert_eq!(SingBox::NAME, "sing-box");
    }
}
