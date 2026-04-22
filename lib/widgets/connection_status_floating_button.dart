import 'package:flutter/material.dart';
import '../services/connection_state_manager.dart';
import '../services/proxy_service.dart';

/// 连接状态悬浮球组件
class ConnectionStatusFloatingButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool showTooltip;

  const ConnectionStatusFloatingButton({
    Key? key,
    this.onTap,
    this.showTooltip = true,
  }) : super(key: key);

  @override
  State<ConnectionStatusFloatingButton> createState() => _ConnectionStatusFloatingButtonState();
}

class _ConnectionStatusFloatingButtonState extends State<ConnectionStatusFloatingButton> {
  final _connectionManager = ConnectionStateManager();
  ConnectionStatus _status = ConnectionStatus();
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _status = _connectionManager.currentStatus;
    
    // 监听状态变化
    _connectionManager.statusStream.listen((newStatus) {
      if (mounted) {
        setState(() {
          _status = newStatus;
          _isAnimating = newStatus.state == ConnectionState.connecting;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTap?.call();
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _getConnectionColor(),
          boxShadow: [
            BoxShadow(
              color: _getConnectionColor().withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 连接中动画
            if (_isAnimating) ...[
              Positioned.fill(
                child: TweenAnimationBuilder(
                  duration: const Duration(seconds: 1),
                  tween: Tween<double>(begin: 0.8, end: 1.2),
                  builder: (context, double scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
                  onEnd: () {
                    if (_isAnimating && mounted) {
                      setState(() {}); // 触发动画循环
                    }
                  },
                ),
              ),
            ],
            // 图标
            Icon(
              _getIcon(),
              color: Colors.white,
              size: 32,
            ),
          ],
        ),
      ),
    );
  }

  Color _getConnectionColor() {
    switch (_status.state) {
      case ConnectionState.connected:
        return Colors.green;
      case ConnectionState.connecting:
        return Colors.orange;
      case ConnectionState.error:
        return Colors.red;
      case ConnectionState.disconnected:
      default:
        return Colors.grey;
    }
  }

  IconData _getIcon() {
    switch (_status.state) {
      case ConnectionState.connected:
        return Icons.check;
      case ConnectionState.connecting:
        return Icons.sync;
      case ConnectionState.error:
        return Icons.error_outline;
      case ConnectionState.disconnected:
      default:
        return Icons.power_off;
    }
  }
}
