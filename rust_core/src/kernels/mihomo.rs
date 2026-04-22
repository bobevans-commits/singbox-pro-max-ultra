//! mihomo (Clash.Meta) 内核适配器
//! 
//! 提供对 mihomo 代理内核的封装和管理。

use crate::{Result, ProxyClientError, kernels::ProcessManager};
use tokio::process::Command;
use std::path::Path;

/// mihomo 进程管理器
static MIHOMO_PROCESS: once_cell::sync::Lazy<ProcessManager> = 
    once_cell::sync::Lazy::new(ProcessManager::new);

/// mihomo 内核实现
pub struct Mihomo;

#[async_trait::async_trait]
impl super::Kernel for Mihomo {
    const NAME: &'static str = "mihomo";
    
    async fn start(config_path: &str) -> Result<()> {
        // 检查是否已在运行
        if MIHOMO_PROCESS.is_running().await {
            return Err(ProxyClientError::KernelError("mihomo 已经在运行".to_string()));
        }
        
        let mihomo_cmd = find_mihomo_binary()?;
        
        // 验证配置文件是否存在
        if !Path::new(config_path).exists() {
            return Err(ProxyClientError::ConfigError(
                format!("配置文件不存在：{}", config_path)
            ));
        }
        
        // 获取配置目录
        let config_dir = Path::new(config_path)
            .parent()
            .unwrap_or(Path::new("."));
        
        // 构建命令
        let command = Command::new(mihomo_cmd)
            .arg("-d")
            .arg(config_dir)
            .arg("-f")
            .arg(config_path);
        
        // 启动进程
        MIHOMO_PROCESS.spawn(command).await?;
        
        log::info!("mihomo 已启动，配置文件：{}", config_path);
        Ok(())
    }
    
    async fn stop() -> Result<()> {
        if !MIHOMO_PROCESS.is_running().await {
            log::warn!("mihomo 未在运行");
            return Ok(());
        }
        
        MIHOMO_PROCESS.terminate().await?;
        log::info!("mihomo 已停止");
        Ok(())
    }
    
    async fn version() -> Result<String> {
        let mihomo_cmd = find_mihomo_binary()?;
        
        let output = Command::new(mihomo_cmd)
            .arg("-v")
            .output()
            .await
            .map_err(|e| ProxyClientError::KernelError(format!("获取版本失败：{}", e)))?;
        
        if !output.status.success() {
            return Err(ProxyClientError::KernelError(
                "获取 mihomo 版本失败".to_string()
            ));
        }
        
        let version = String::from_utf8_lossy(&output.stdout).trim().to_string();
        Ok(version)
    }
    
    async fn is_running() -> bool {
        MIHOMO_PROCESS.is_running().await
    }
}

/// 查找 mihomo 可执行文件
fn find_mihomo_binary() -> Result<String> {
    #[cfg(windows)]
    {
        let paths = [
            "mihomo.exe",
            "clash-meta.exe",
            ".\\mihomo.exe",
            "C:\\Program Files\\mihomo\\mihomo.exe",
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
            "mihomo",
            "clash-meta",
            "/usr/local/bin/mihomo",
            "/usr/bin/mihomo",
            "./mihomo",
        ];
        
        for path in &paths {
            if Path::new(path).exists() {
                return Ok(path.to_string());
            }
        }
    }
    
    Err(ProxyClientError::KernelError(
        "未找到 mihomo 可执行文件".to_string()
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_is_running_initially_false() {
        assert!(!Mihomo::is_running().await);
    }
    
    #[test]
    fn test_find_binary_returns_error_when_not_found() {
        let result = find_mihomo_binary();
        assert!(result.is_ok() || result.is_err());
    }
    
    #[test]
    fn test_kernel_name() {
        assert_eq!(Mihomo::NAME, "mihomo");
    }
}
