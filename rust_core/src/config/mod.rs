//! 配置管理模块
//! 
//! 提供代理配置的加载、保存和验证功能。

use serde::{Deserialize, Serialize};
use crate::{ProxyClientError, Result};
use std::path::Path;
use std::fs;

/// 代理配置结构体
/// 
/// 包含内核类型、日志级别、入站/出站配置、DNS 设置和路由规则等。
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProxyConfig {
    /// 内核类型 (sing-box, mihomo, v2ray)
    pub kernel_type: String,
    /// 日志级别 (debug, info, warn, error)
    pub log_level: String,
    /// 入站配置
    pub inbound: InboundConfig,
    /// 出站配置
    pub outbound: OutboundConfig,
    /// DNS 配置
    pub dns: DnsConfig,
    /// 路由规则列表
    pub rules: Vec<RuleConfig>,
}

/// 入站配置结构体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InboundConfig {
    /// 主端口
    pub port: u16,
    /// SOCKS5 代理端口
    pub socks_port: Option<u16>,
    /// HTTP 代理端口
    pub http_port: Option<u16>,
    /// 混合端口 (同时支持 SOCKS 和 HTTP)
    pub mixed_port: Option<u16>,
}

/// 出站配置结构体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OutboundConfig {
    /// 节点列表
    pub nodes: Vec<NodeConfig>,
    /// 默认节点名称
    pub default_node: Option<String>,
}

/// 节点配置结构体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeConfig {
    /// 节点名称
    pub name: String,
    /// 节点类型 (vmess, trojan, shadowsocks 等)
    pub r#type: String,
    /// 服务器地址
    pub server: String,
    /// 服务器端口
    pub port: u16,
    /// UUID (用于 VMess/VLESS)
    pub uuid: Option<String>,
    /// Alter ID (用于旧版 VMess)
    pub alter_id: Option<u16>,
    /// 加密方式
    pub cipher: Option<String>,
    /// 密码 (用于 Trojan/Shadowsocks)
    pub password: Option<String>,
    /// 加密方法 (用于 Shadowsocks)
    pub method: Option<String>,
}

/// DNS 配置结构体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DnsConfig {
    /// DNS 服务器列表
    pub servers: Vec<String>,
    /// IP 策略 (ipv4_only, ipv6_only, prefer_ipv4 等)
    pub strategy: String,
}

/// 路由规则配置结构体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleConfig {
    /// 域名匹配规则
    pub domain: Option<Vec<String>>,
    /// IP CIDR 匹配规则
    pub ip_cidr: Option<Vec<String>>,
    /// 匹配的出站标识
    pub outbound: String,
}

impl ProxyConfig {
    /// 从文件加载配置
    pub fn load_from_file(path: &str) -> Result<Self> {
        if !Path::new(path).exists() {
            return Err(ProxyClientError::ConfigError(
                format!("配置文件不存在：{}", path)
            ));
        }
        
        let content = fs::read_to_string(path)
            .map_err(|e| ProxyClientError::ConfigError(e.to_string()))?;
        
        // 尝试 JSON 格式
        if let Ok(config) = serde_json::from_str::<ProxyConfig>(&content) {
            return Ok(config);
        }
        
        // 尝试 YAML 格式
        #[cfg(feature = "yaml")]
        {
            if let Ok(config) = serde_yaml::from_str::<ProxyConfig>(&content) {
                return Ok(config);
            }
        }
        
        Err(ProxyClientError::ConfigError(
            "无法解析配置文件格式 (支持 JSON/YAML)".to_string()
        ))
    }
    
    /// 保存配置到文件
    pub fn save_to_file(&self, path: &str) -> Result<()> {
        let content = serde_json::to_string_pretty(self)
            .map_err(|e| ProxyClientError::ConfigError(e.to_string()))?;
        
        fs::write(path, content)
            .map_err(|e| ProxyClientError::ConfigError(e.to_string()))?;
        
        Ok(())
    }
    
    /// 创建默认配置
    pub fn default_config() -> Self {
        Self {
            kernel_type: "sing-box".to_string(),
            log_level: "info".to_string(),
            inbound: InboundConfig {
                port: 7890,
                socks_port: Some(7891),
                http_port: Some(7892),
                mixed_port: None,
            },
            outbound: OutboundConfig {
                nodes: vec![],
                default_node: None,
            },
            dns: DnsConfig {
                servers: vec!["8.8.8.8".to_string(), "1.1.1.1".to_string()],
                strategy: "ipv4_only".to_string(),
            },
            rules: vec![],
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::NamedTempFile;
    use std::io::Write;
    
    #[test]
    fn test_default_config() {
        let config = ProxyConfig::default_config();
        assert_eq!(config.kernel_type, "sing-box");
        assert_eq!(config.inbound.port, 7890);
    }
    
    #[test]
    fn test_save_and_load_config() {
        let temp_file = NamedTempFile::new().unwrap();
        let path = temp_file.path().to_str().unwrap();
        
        let original_config = ProxyConfig::default_config();
        original_config.save_to_file(path).unwrap();
        
        let loaded_config = ProxyConfig::load_from_file(path).unwrap();
        assert_eq!(loaded_config.kernel_type, original_config.kernel_type);
        assert_eq!(loaded_config.inbound.port, original_config.inbound.port);
    }
    
    #[test]
    fn test_load_nonexistent_file() {
        let result = ProxyConfig::load_from_file("/nonexistent/path/config.json");
        assert!(result.is_err());
        match result {
            Err(ProxyClientError::ConfigError(msg)) => {
                assert!(msg.contains("配置文件不存在"));
            }
            _ => panic!("Expected ConfigError"),
        }
    }
    
    #[test]
    fn test_invalid_json_config() {
        let mut temp_file = NamedTempFile::new().unwrap();
        writeln!(temp_file, "{{ invalid json }}").unwrap();
        let path = temp_file.path().to_str().unwrap();
        
        let result = ProxyConfig::load_from_file(path);
        assert!(result.is_err());
        match result {
            Err(ProxyClientError::ConfigError(msg)) => {
                assert!(msg.contains("无法解析"));
            }
            _ => panic!("Expected ConfigError"),
        }
    }
}
