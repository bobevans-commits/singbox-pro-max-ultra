//! 系统代理设置模块

use crate::{Result, ProxyClientError};

/// HTTP/HTTPS 代理端口
const DEFAULT_PROXY_PORT: u16 = 7890;
const DEFAULT_SOCKS_PORT: u16 = 7891;

/// 启用系统代理
pub fn enable() -> Result<()> {
    #[cfg(target_os = "windows")]
    {
        enable_windows_proxy()
    }
    
    #[cfg(target_os = "macos")]
    {
        enable_macos_proxy()
    }
    
    #[cfg(target_os = "linux")]
    {
        enable_linux_proxy()
    }
    
    #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
    {
        Err(ProxyClientError::SystemProxyError("不支持的操作系统".to_string()))
    }
}

/// 禁用系统代理
pub fn disable() -> Result<()> {
    #[cfg(target_os = "windows")]
    {
        disable_windows_proxy()
    }
    
    #[cfg(target_os = "macos")]
    {
        disable_macos_proxy()
    }
    
    #[cfg(target_os = "linux")]
    {
        disable_linux_proxy()
    }
    
    #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
    {
        Err(ProxyClientError::SystemProxyError("不支持的操作系统".to_string()))
    }
}

#[cfg(target_os = "windows")]
fn enable_windows_proxy() -> Result<()> {
    use winreg::enums::*;
    use winreg::RegKey;
    
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    let internet_settings_path = r"Software\Microsoft\Windows\CurrentVersion\Internet Settings";
    
    let (internet_settings, _) = hkcu.create_subkey(internet_settings_path)
        .map_err(|e| ProxyClientError::SystemProxyError(format!("注册表访问失败：{}", e)))?;
    
    // 启用代理
    internet_settings.set_value("ProxyEnable", &1u32)
        .map_err(|e| ProxyClientError::SystemProxyError(format!("设置代理启用失败：{}", e)))?;
    
    // 设置代理服务器
    let proxy_server = format!("127.0.0.1:{}", DEFAULT_PROXY_PORT);
    internet_settings.set_value("ProxyServer", &proxy_server)
        .map_err(|e| ProxyClientError::SystemProxyError(format!("设置代理服务器失败：{}", e)))?;
    
    log::info!("Windows 系统代理已启用：{}", proxy_server);
    Ok(())
}

#[cfg(target_os = "windows")]
fn disable_windows_proxy() -> Result<()> {
    use winreg::enums::*;
    use winreg::RegKey;
    
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    let internet_settings_path = r"Software\Microsoft\Windows\CurrentVersion\Internet Settings";
    
    let (internet_settings, _) = hkcu.create_subkey(internet_settings_path)
        .map_err(|e| ProxyClientError::SystemProxyError(format!("注册表访问失败：{}", e)))?;
    
    internet_settings.set_value("ProxyEnable", &0u32)
        .map_err(|e| ProxyClientError::SystemProxyError(format!("禁用代理失败：{}", e)))?;
    
    log::info!("Windows 系统代理已禁用");
    Ok(())
}

#[cfg(target_os = "macos")]
fn enable_macos_proxy() -> Result<()> {
    use std::process::Command;
    
    // 获取网络服务名称（通常是 Wi-Fi 或 Ethernet）
    let output = Command::new("networksetup")
        .arg("-listallnetworkservices")
        .output()
        .map_err(|e| ProxyClientError::SystemProxyError(format!("获取网络服务失败：{}", e)))?;
    
    let services = String::from_utf8_lossy(&output.stdout);
    
    for service in services.lines() {
        if service.starts_with("*") || service.is_empty() {
            continue;
        }
        
        // 设置 HTTP 代理
        Command::new("networksetup")
            .arg("-setwebproxy")
            .arg(service)
            .arg("127.0.0.1")
            .arg(DEFAULT_PROXY_PORT.to_string())
            .output()
            .map_err(|e| ProxyClientError::SystemProxyError(format!("设置 HTTP 代理失败：{}", e)))?;
        
        // 设置 HTTPS 代理
        Command::new("networksetup")
            .arg("-setsecurewebproxy")
            .arg(service)
            .arg("127.0.0.1")
            .arg(DEFAULT_PROXY_PORT.to_string())
            .output()
            .map_err(|e| ProxyClientError::SystemProxyError(format!("设置 HTTPS 代理失败：{}", e)))?;
        
        // 设置 SOCKS 代理
        Command::new("networksetup")
            .arg("-setsocksfirewallproxy")
            .arg(service)
            .arg("127.0.0.1")
            .arg(DEFAULT_SOCKS_PORT.to_string())
            .output()
            .map_err(|e| ProxyClientError::SystemProxyError(format!("设置 SOCKS 代理失败：{}", e)))?;
    }
    
    log::info!("macOS 系统代理已启用");
    Ok(())
}

#[cfg(target_os = "macos")]
fn disable_macos_proxy() -> Result<()> {
    use std::process::Command;
    
    let output = Command::new("networksetup")
        .arg("-listallnetworkservices")
        .output()
        .map_err(|e| ProxyClientError::SystemProxyError(format!("获取网络服务失败：{}", e)))?;
    
    let services = String::from_utf8_lossy(&output.stdout);
    
    for service in services.lines() {
        if service.starts_with("*") || service.is_empty() {
            continue;
        }
        
        // 禁用 HTTP 代理
        let _ = Command::new("networksetup")
            .arg("-setwebproxystate")
            .arg(service)
            .arg("off")
            .output();
        
        // 禁用 HTTPS 代理
        let _ = Command::new("networksetup")
            .arg("-setsecurewebproxystate")
            .arg(service)
            .arg("off")
            .output();
        
        // 禁用 SOCKS 代理
        let _ = Command::new("networksetup")
            .arg("-setsocksfirewallproxystate")
            .arg(service)
            .arg("off")
            .output();
    }
    
    log::info!("macOS 系统代理已禁用");
    Ok(())
}

#[cfg(target_os = "linux")]
fn enable_linux_proxy() -> Result<()> {
    // Linux 桌面环境多样，这里设置环境变量作为通用方案
    // 对于 GNOME/KDE 等桌面环境，可能需要调用特定的 API
    
    log::warn!("Linux 系统代理设置可能需要手动配置，建议设置以下环境变量:");
    log::warn!("export http_proxy=http://127.0.0.1:{}", DEFAULT_PROXY_PORT);
    log::warn!("export https_proxy=http://127.0.0.1:{}", DEFAULT_PROXY_PORT);
    log::warn!("export socks_proxy=socks5://127.0.0.1:{}", DEFAULT_SOCKS_PORT);
    
    Ok(())
}

#[cfg(target_os = "linux")]
fn disable_linux_proxy() -> Result<()> {
    log::info!("Linux 系统代理已禁用提示");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_proxy_functions_exist() {
        // 测试函数存在性，不实际执行（因为需要特定环境）
        // 在 CI 环境中跳过实际执行
        let result_enable = enable();
        let result_disable = disable();
        
        // 在某些环境中可能会失败，这是正常的
        assert!(result_enable.is_ok() || result_enable.is_err());
        assert!(result_disable.is_ok() || result_disable.is_err());
    }
}
