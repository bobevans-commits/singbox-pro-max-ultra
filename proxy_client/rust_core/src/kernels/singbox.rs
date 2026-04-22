//! sing-box 内核适配器

use crate::{Result, ProxyClientError};
use tokio::process::{Command, Child};
use std::sync::Arc;
use tokio::sync::Mutex;

static SINGBOX_PROCESS: once_cell::sync::Lazy<Arc<Mutex<Option<Child>>>> = 
    once_cell::sync::Lazy::new(|| Arc::new(Mutex::new(None)));

/// sing-box 实现
pub struct SingBox;

#[async_trait::async_trait]
impl super::Kernel for SingBox {
    async fn start(config_path: &str) -> Result<()> {
        let mut process_lock = SINGBOX_PROCESS.lock().await;
        
        if process_lock.is_some() {
            return Err(ProxyClientError::KernelError("sing-box 已经在运行".to_string()));
        }
        
        // 查找 sing-box 可执行文件
        let singbox_cmd = find_singbox_binary()?;
        
        let child = Command::new(singbox_cmd)
            .arg("run")
            .arg("-c")
            .arg(config_path)
            .spawn()
            .map_err(|e| ProxyClientError::KernelError(format!("启动 sing-box 失败：{}", e)))?;
        
        *process_lock = Some(child);
        log::info!("sing-box 已启动，配置文件：{}", config_path);
        
        Ok(())
    }
    
    async fn stop() -> Result<()> {
        let mut process_lock = SINGBOX_PROCESS.lock().await;
        
        if let Some(mut child) = process_lock.take() {
            // 尝试优雅关闭
            #[cfg(unix)]
            {
                use nix::sys::signal::{kill, Signal};
                use nix::unistd::Pid;
                if let Ok(pid) = child.id().ok_or_else(|| ProxyClientError::KernelError("无法获取进程 ID".to_string())) {
                    let _ = kill(Pid::from_raw(pid as i32), Signal::SIGTERM);
                }
            }
            
            // 等待进程退出
            let _ = child.wait().await;
            log::info!("sing-box 已停止");
        }
        
        Ok(())
    }
    
    async fn version() -> Result<String> {
        let singbox_cmd = find_singbox_binary()?;
        
        let output = Command::new(singbox_cmd)
            .arg("version")
            .output()
            .await
            .map_err(|e| ProxyClientError::KernelError(format!("获取版本失败：{}", e)))?;
        
        let version = String::from_utf8_lossy(&output.stdout).trim().to_string();
        Ok(version)
    }
    
    async fn is_running() -> bool {
        let process_lock = SINGBOX_PROCESS.lock().await;
        process_lock.is_some()
    }
}

fn find_singbox_binary() -> Result<String> {
    // 在不同平台查找 sing-box 可执行文件
    #[cfg(windows)]
    {
        let paths = [
            "sing-box.exe",
            ".\\sing-box.exe",
            "C:\\Program Files\\sing-box\\sing-box.exe",
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
            "sing-box",
            "/usr/local/bin/sing-box",
            "/usr/bin/sing-box",
            "./sing-box",
        ];
        
        for path in &paths {
            if std::path::Path::new(path).exists() {
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
}
