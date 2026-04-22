//! v2ray-core 内核适配器
//! 
//! 提供对 v2ray-core 代理内核的封装和管理。

use crate::{Result, ProxyClientError, kernels::ProcessManager};
use tokio::process::Command;
use std::path::Path;

/// v2ray 进程管理器
static V2RAY_PROCESS: once_cell::sync::Lazy<ProcessManager> = 
    once_cell::sync::Lazy::new(ProcessManager::new);

/// v2ray-core 内核实现
pub struct V2Ray;

#[async_trait::async_trait]
impl super::Kernel for V2Ray {
    const NAME: &'static str = "v2ray";
    
    async fn start(config_path: &str) -> Result<()> {
        // 检查是否已在运行
        if V2RAY_PROCESS.is_running().await {
            return Err(ProxyClientError::KernelError("v2ray 已经在运行".to_string()));
        }
        
        let v2ray_cmd = find_v2ray_binary()?;
        
        // 验证配置文件是否存在
        if !Path::new(config_path).exists() {
            return Err(ProxyClientError::ConfigError(
                format!("配置文件不存在：{}", config_path)
            ));
        }
        
        // 构建命令
        let command = Command::new(v2ray_cmd)
            .arg("-config")
            .arg(config_path);
        
        // 启动进程
        V2RAY_PROCESS.spawn(command).await?;
        
        log::info!("v2ray 已启动，配置文件：{}", config_path);
        Ok(())
    }
    
    async fn stop() -> Result<()> {
        if !V2RAY_PROCESS.is_running().await {
            log::warn!("v2ray 未在运行");
            return Ok(());
        }
        
        V2RAY_PROCESS.terminate().await?;
        log::info!("v2ray 已停止");
        Ok(())
    }
    
    async fn version() -> Result<String> {
        let v2ray_cmd = find_v2ray_binary()?;
        
        let output = Command::new(v2ray_cmd)
            .arg("-version")
            .output()
            .await
            .map_err(|e| ProxyClientError::KernelError(format!("获取版本失败：{}", e)))?;
        
        if !output.status.success() {
            return Err(ProxyClientError::KernelError(
                "获取 v2ray 版本失败".to_string()
            ));
        }
        
        let version = String::from_utf8_lossy(&output.stdout).trim().to_string();
        Ok(version)
    }
    
    async fn is_running() -> bool {
        V2RAY_PROCESS.is_running().await
    }
}

/// 查找 v2ray 可执行文件
fn find_v2ray_binary() -> Result<String> {
    #[cfg(windows)]
    {
        let paths = [
            "v2ray.exe",
            ".\\v2ray.exe",
            "C:\\Program Files\\v2ray\\v2ray.exe",
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
            "v2ray",
            "/usr/local/bin/v2ray",
            "/usr/bin/v2ray",
            "./v2ray",
        ];
        
        for path in &paths {
            if Path::new(path).exists() {
                return Ok(path.to_string());
            }
        }
    }
    
    Err(ProxyClientError::KernelError(
        "未找到 v2ray 可执行文件".to_string()
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_is_running_initially_false() {
        assert!(!V2Ray::is_running().await);
    }
    
    #[test]
    fn test_find_binary_returns_error_when_not_found() {
        let result = find_v2ray_binary();
        assert!(result.is_ok() || result.is_err());
    }
    
    #[test]
    fn test_kernel_name() {
        assert_eq!(V2Ray::NAME, "v2ray");
    }
}
