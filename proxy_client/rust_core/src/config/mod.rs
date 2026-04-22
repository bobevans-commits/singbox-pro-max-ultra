//! 配置管理模块

use serde::{Deserialize, Serialize};
use crate::{ProxyClientError, Result};
use std::path::Path;
use std::fs;

/// 代理配置结构
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProxyConfig {
    pub kernel_type: String,
    pub log_level: String,
    pub inbound: InboundConfig,
    pub outbound: OutboundConfig,
    pub dns: DnsConfig,
    pub rules: Vec<RuleConfig>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InboundConfig {
    pub port: u16,
    pub socks_port: Option<u16>,
    pub http_port: Option<u16>,
    pub mixed_port: Option<u16>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OutboundConfig {
    pub nodes: Vec<NodeConfig>,
    pub default_node: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeConfig {
    pub name: String,
    pub r#type: String,
    pub server: String,
    pub port: u16,
    pub uuid: Option<String>,
    pub alter_id: Option<u16>,
    pub cipher: Option<String>,
    pub password: Option<String>,
    pub method: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DnsConfig {
    pub servers: Vec<String>,
    pub strategy: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleConfig {
    pub domain: Option<Vec<String>>,
    pub ip_cidr: Option<Vec<String>>,
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
