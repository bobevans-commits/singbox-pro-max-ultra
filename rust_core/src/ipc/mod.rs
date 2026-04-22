//! IPC 通信模块

use crate::{Result, ProxyClientError};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::sync::mpsc;
use serde_json::{json, Value};

/// IPC 消息结构
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct IpcMessage {
    pub id: String,
    pub method: String,
    pub params: Option<Value>,
}

/// IPC 响应结构
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct IpcResponse {
    pub id: String,
    pub result: Option<Value>,
    pub error: Option<String>,
}

/// IPC 服务器
pub struct IpcServer {
    socket_path: String,
}

impl IpcServer {
    pub fn new(socket_path: &str) -> Self {
        Self {
            socket_path: socket_path.to_string(),
        }
    }
    
    /// 启动 IPC 服务器
    pub async fn start(&self) -> Result<()> {
        #[cfg(unix)]
        {
            use tokio::net::UnixListener;
            
            // 如果 socket 文件已存在，先删除
            if std::path::Path::new(&self.socket_path).exists() {
                std::fs::remove_file(&self.socket_path)
                    .map_err(|e| ProxyClientError::IpcError(format!("删除旧 socket 失败：{}", e)))?;
            }
            
            let listener = UnixListener::bind(&self.socket_path)
                .map_err(|e| ProxyClientError::IpcError(format!("绑定 socket 失败：{}", e)))?;
            
            log::info!("IPC 服务器已启动：{}", self.socket_path);
            
            loop {
                match listener.accept().await {
                    Ok((stream, _addr)) => {
                        tokio::spawn(handle_connection(stream));
                    }
                    Err(e) => {
                        log::error!("接受连接失败：{}", e);
                    }
                }
            }
        }
        
        #[cfg(windows)]
        {
            use tokio::net::windows::named_pipe::NamedPipeServer;
            
            let server = NamedPipeServer::builder()
                .first_pipe_instance(true)
                .create(&format!(r"\\.\pipe\proxy_client_{}", self.socket_path))
                .map_err(|e| ProxyClientError::IpcError(format!("创建命名管道失败：{}", e)))?;
            
            log::info!("IPC 服务器已启动 (Windows Named Pipe)");
            
            // Windows 实现略简化
            loop {
                match server.connect().await {
                    Ok(_) => {
                        // 处理连接
                    }
                    Err(e) => {
                        log::error!("连接失败：{}", e);
                    }
                }
            }
        }
        
        #[cfg(not(any(unix, windows)))]
        {
            return Err(ProxyClientError::IpcError("不支持的平台".to_string()));
        }
    }
}

#[cfg(unix)]
async fn handle_connection(stream: tokio::net::UnixStream) {
    let (reader, mut writer) = stream.into_split();
    let mut reader = BufReader::new(reader);
    
    let mut line = String::new();
    while let Ok(n) = reader.read_line(&mut line).await {
        if n == 0 {
            break; // 连接关闭
        }
        
        // 解析 JSON-RPC 请求
        match serde_json::from_str::<IpcMessage>(&line) {
            Ok(msg) => {
                let response = process_message(msg).await;
                let response_json = serde_json::to_string(&response).unwrap();
                let _ = writer.write_all(format!("{}\n", response_json).as_bytes()).await;
            }
            Err(e) => {
                let error_response = IpcResponse {
                    id: "unknown".to_string(),
                    result: None,
                    error: Some(format!("解析错误：{}", e)),
                };
                let response_json = serde_json::to_string(&error_response).unwrap();
                let _ = writer.write_all(format!("{}\n", response_json).as_bytes()).await;
            }
        }
        
        line.clear();
    }
}

async fn process_message(msg: IpcMessage) -> IpcResponse {
    match msg.method.as_str() {
        "ping" => {
            IpcResponse {
                id: msg.id,
                result: Some(json!("pong")),
                error: None,
            }
        }
        "get_status" => {
            // 这里应该调用核心层的状态查询
            IpcResponse {
                id: msg.id,
                result: Some(json!({"status": "running"})),
                error: None,
            }
        }
        _ => {
            IpcResponse {
                id: msg.id,
                result: None,
                error: Some(format!("未知方法：{}", msg.method)),
            }
        }
    }
}

/// IPC 客户端
pub struct IpcClient {
    #[cfg(unix)]
    socket_path: String,
    #[cfg(windows)]
    pipe_name: String,
}

impl IpcClient {
    pub fn new(socket_path: &str) -> Self {
        #[cfg(unix)]
        {
            Self {
                socket_path: socket_path.to_string(),
            }
        }
        #[cfg(windows)]
        {
            Self {
                pipe_name: format!(r"\\.\pipe\proxy_client_{}", socket_path),
            }
        }
        #[cfg(not(any(unix, windows)))]
        {
            unreachable!()
        }
    }
    
    /// 发送请求并获取响应
    pub async fn send_request(&self, method: &str, params: Option<Value>) -> Result<IpcResponse> {
        #[cfg(unix)]
        {
            use tokio::net::UnixStream;
            
            let stream = UnixStream::connect(&self.socket_path)
                .await
                .map_err(|e| ProxyClientError::IpcError(format!("连接失败：{}", e)))?;
            
            let (reader, mut writer) = stream.into_split();
            let mut reader = BufReader::new(reader);
            
            let message = IpcMessage {
                id: uuid::Uuid::new_v4().to_string(),
                method: method.to_string(),
                params,
            };
            
            let request = serde_json::to_string(&message).unwrap();
            writer.write_all(format!("{}\n", request).as_bytes()).await
                .map_err(|e| ProxyClientError::IpcError(format!("发送失败：{}", e)))?;
            
            let mut response_line = String::new();
            reader.read_line(&mut response_line).await
                .map_err(|e| ProxyClientError::IpcError(format!("接收失败：{}", e)))?;
            
            let response: IpcResponse = serde_json::from_str(&response_line)
                .map_err(|e| ProxyClientError::IpcError(format!("解析响应失败：{}", e)))?;
            
            Ok(response)
        }
        
        #[cfg(windows)]
        {
            // Windows 实现略
            Err(ProxyClientError::IpcError("Windows 客户端未完全实现".to_string()))
        }
        
        #[cfg(not(any(unix, windows)))]
        {
            Err(ProxyClientError::IpcError("不支持的平台".to_string()))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_ipc_message_serialization() {
        let msg = IpcMessage {
            id: "test-123".to_string(),
            method: "ping".to_string(),
            params: None,
        };
        
        let json = serde_json::to_string(&msg).unwrap();
        assert!(json.contains("test-123"));
        assert!(json.contains("ping"));
    }
    
    #[test]
    fn test_ipc_response_serialization() {
        let resp = IpcResponse {
            id: "test-123".to_string(),
            result: Some(json!("pong")),
            error: None,
        };
        
        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("pong"));
    }
    
    #[tokio::test]
    async fn test_process_message_ping() {
        let msg = IpcMessage {
            id: "test".to_string(),
            method: "ping".to_string(),
            params: None,
        };
        
        let response = process_message(msg).await;
        assert_eq!(response.result, Some(json!("pong")));
        assert!(response.error.is_none());
    }
}
