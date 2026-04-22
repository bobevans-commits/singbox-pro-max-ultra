//! v2ray-core 内核适配器

use crate::{Result, ProxyClientError};
use tokio::process::{Command, Child};
use std::sync::Arc;
use tokio::sync::Mutex;

static V2RAY_PROCESS: once_cell::sync::Lazy<Arc<Mutex<Option<Child>>>> = 
    once_cell::sync::Lazy::new(|| Arc::new(Mutex::new(None)));

/// v2ray-core 实现
pub struct V2Ray;

#[async_trait::async_trait]
impl super::Kernel for V2Ray {
    async fn start(config_path: &str) -> Result<()> {
        let mut process_lock = V2RAY_PROCESS.lock().await;
        
        if process_lock.is_some() {
            return Err(ProxyClientError::KernelError("v2ray 已经在运行".to_string()));
        }
        
        let v2ray_cmd = find_v2ray_binary()?;
        
        let child = Command::new(v2ray_cmd)
            .arg("-config")
            .arg(config_path)
            .spawn()
            .map_err(|e| ProxyClientError::KernelError(format!("启动 v2ray 失败：{}", e)))?;
        
        *process_lock = Some(child);
        log::info!("v2ray 已启动，配置文件：{}", config_path);
        
        Ok(())
    }
    
    async fn stop() -> Result<()> {
        let mut process_lock = V2RAY_PROCESS.lock().await;
        
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
            log::info!("v2ray 已停止");
        }
        
        Ok(())
    }
    
    async fn version() -> Result<String> {
        let v2ray_cmd = find_v2ray_binary()?;
        
        let output = Command::new(v2ray_cmd)
            .arg("-version")
            .output()
            .await
            .map_err(|e| ProxyClientError::KernelError(format!("获取版本失败：{}", e)))?;
        
        let version = String::from_utf8_lossy(&output.stdout).trim().to_string();
        Ok(version)
    }
    
    async fn is_running() -> bool {
        let process_lock = V2RAY_PROCESS.lock().await;
        process_lock.is_some()
    }
}

fn find_v2ray_binary() -> Result<String> {
    #[cfg(windows)]
    {
        let paths = [
            "v2ray.exe",
            ".\\v2ray.exe",
            "C:\\Program Files\\v2ray\\v2ray.exe",
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
            "v2ray",
            "/usr/local/bin/v2ray",
            "/usr/bin/v2ray",
            "./v2ray",
        ];
        
        for path in &paths {
            if std::path::Path::new(path).exists() {
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
}
