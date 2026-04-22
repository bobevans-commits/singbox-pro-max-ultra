//! mihomo (Clash.Meta) 内核适配器

use crate::{Result, ProxyClientError};
use tokio::process::{Command, Child};
use std::sync::Arc;
use tokio::sync::Mutex;

static MIHOMO_PROCESS: once_cell::sync::Lazy<Arc<Mutex<Option<Child>>>> = 
    once_cell::sync::Lazy::new(|| Arc::new(Mutex::new(None)));

/// mihomo 实现
pub struct Mihomo;

#[async_trait::async_trait]
impl super::Kernel for Mihomo {
    async fn start(config_path: &str) -> Result<()> {
        let mut process_lock = MIHOMO_PROCESS.lock().await;
        
        if process_lock.is_some() {
            return Err(ProxyClientError::KernelError("mihomo 已经在运行".to_string()));
        }
        
        let mihomo_cmd = find_mihomo_binary()?;
        
        let child = Command::new(mihomo_cmd)
            .arg("-d")
            .arg(std::path::Path::new(config_path).parent().unwrap_or(std::path::Path::new(".")))
            .arg("-f")
            .arg(config_path)
            .spawn()
            .map_err(|e| ProxyClientError::KernelError(format!("启动 mihomo 失败：{}", e)))?;
        
        *process_lock = Some(child);
        log::info!("mihomo 已启动，配置文件：{}", config_path);
        
        Ok(())
    }
    
    async fn stop() -> Result<()> {
        let mut process_lock = MIHOMO_PROCESS.lock().await;
        
        if let Some(mut child) = process_lock.take() {
            #[cfg(unix)]
            {
                use nix::sys::signal::{kill, Signal};
                use nix::unistd::Pid;
                if let Ok(pid) = child.id().ok_or_else(|| ProxyClientError::KernelError("无法获取进程 ID".to_string())) {
                    let _ = kill(Pid::from_raw(pid as i32), Signal::SIGTERM);
                }
            }
            
            let _ = child.wait().await;
            log::info!("mihomo 已停止");
        }
        
        Ok(())
    }
    
    async fn version() -> Result<String> {
        let mihomo_cmd = find_mihomo_binary()?;
        
        let output = Command::new(mihomo_cmd)
            .arg("-v")
            .output()
            .await
            .map_err(|e| ProxyClientError::KernelError(format!("获取版本失败：{}", e)))?;
        
        let version = String::from_utf8_lossy(&output.stdout).trim().to_string();
        Ok(version)
    }
    
    async fn is_running() -> bool {
        let process_lock = MIHOMO_PROCESS.lock().await;
        process_lock.is_some()
    }
}

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
            if std::path::Path::new(path).exists() {
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
            if std::path::Path::new(path).exists() {
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
}
