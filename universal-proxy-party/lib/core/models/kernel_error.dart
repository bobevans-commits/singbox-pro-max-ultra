/// Custom exception types for kernel operations
class KernelException implements Exception {
  final String message;
  final KernelErrorCode code;
  final dynamic originalError;

  KernelException({
    required this.message,
    required this.code,
    this.originalError,
  });

  @override
  String toString() => 'KernelException($code): $message';
}

enum KernelErrorCode {
  startFailed,
  stopFailed,
  restartFailed,
  configInvalid,
  binaryNotFound,
  connectionRefused,
  timeout,
  permissionDenied,
  unknown,
}

/// Result wrapper for kernel operations
class KernelResult<T> {
  final bool success;
  final T? data;
  final KernelException? error;

  const KernelResult.success(this.data) : success = true, error = null;
  const KernelResult.failure(this.error) : success = false, data = null;

  factory KernelResult.ok(T data) => KernelResult.success(data);
  factory KernelResult.err(String message, KernelErrorCode code, [dynamic originalError]) {
    return KernelResult.failure(
      KernelException(
        message: message,
        code: code,
        originalError: originalError,
      ),
    );
  }
}
