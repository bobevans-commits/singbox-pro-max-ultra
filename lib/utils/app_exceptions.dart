/// 自定义应用异常类
class AppException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;
  
  AppException(this.message, [this.originalError, this.stackTrace]);
  
  @override
  String toString() => message;
}

/// 代理服务异常
class ProxyException extends AppException {
  ProxyException(String message, [dynamic originalError, StackTrace? stackTrace])
      : super(message, originalError, stackTrace);
}

/// 内核管理异常
class KernelException extends AppException {
  KernelException(String message, [dynamic originalError, StackTrace? stackTrace])
      : super(message, originalError, stackTrace);
}

/// 配置异常
class ConfigException extends AppException {
  ConfigException(String message, [dynamic originalError, StackTrace? stackTrace])
      : super(message, originalError, stackTrace);
}

/// 网络异常
class NetworkException extends AppException {
  NetworkException(String message, [dynamic originalError, StackTrace? stackTrace])
      : super(message, originalError, stackTrace);
}

/// 文件操作异常
class FileException extends AppException {
  FileException(String message, [dynamic originalError, StackTrace? stackTrace])
      : super(message, originalError, stackTrace);
}