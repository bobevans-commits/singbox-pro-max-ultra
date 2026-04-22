import 'package:flutter/material.dart';
import 'dart:async';
import '../services/traffic_statistics_service.dart';

/// 实时流量图表组件
class TrafficChartWidget extends StatefulWidget {
  final int historySeconds;
  final bool showLegend;

  const TrafficChartWidget({
    Key? key,
    this.historySeconds = 60,
    this.showLegend = true,
  }) : super(key: key);

  @override
  State<TrafficChartWidget> createState() => _TrafficChartWidgetState();
}

class _TrafficChartWidgetState extends State<TrafficChartWidget> {
  final _trafficService = TrafficStatisticsService();
  StreamSubscription? _subscription;
  List<TrafficDataPoint> _history = [];

  @override
  void initState() {
    super.initState();
    _history = _trafficService.currentTraffic.history;
    
    _subscription = _trafficService.trafficStream.listen((data) {
      if (mounted) {
        setState(() {
          _history = data.history;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_history.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          '暂无流量数据',
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }

    // 计算最大值用于缩放
    double maxValue = 1;
    for (var point in _history) {
      final maxSpeed = point.uploadSpeed > point.downloadSpeed 
          ? point.uploadSpeed 
          : point.downloadSpeed;
      if (maxSpeed > maxValue) {
        maxValue = maxSpeed.toDouble();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLegend) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildLegendItem(Colors.blue, '下载'),
              const SizedBox(width: 12),
              _buildLegendItem(Colors.green, '上传'),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: CustomPaint(
            painter: TrafficChartPainter(
              dataPoints: _history,
              maxValue: maxValue,
            ),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

/// 流量图表绘制器
class TrafficChartPainter extends CustomPainter {
  final List<TrafficDataPoint> dataPoints;
  final double maxValue;

  TrafficChartPainter({
    required this.dataPoints,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final stepX = size.width / (dataPoints.length - 1);

    // 绘制下载曲线 (蓝色)
    paint.color = Colors.blue;
    final downloadPath = Path();
    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * stepX;
      final y = size.height - (dataPoints[i].downloadSpeed / maxValue) * size.height;
      
      if (i == 0) {
        downloadPath.moveTo(x, y);
      } else {
        downloadPath.lineTo(x, y);
      }
    }
    canvas.drawPath(downloadPath, paint);

    // 绘制上传曲线 (绿色)
    paint.color = Colors.green;
    final uploadPath = Path();
    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * stepX;
      final y = size.height - (dataPoints[i].uploadSpeed / maxValue) * size.height;
      
      if (i == 0) {
        uploadPath.moveTo(x, y);
      } else {
        uploadPath.lineTo(x, y);
      }
    }
    canvas.drawPath(uploadPath, paint);

    // 绘制背景网格
    paint.color = Colors.grey.withOpacity(0.2);
    paint.strokeWidth = 1.0;
    
    // 水平网格线
    for (int i = 1; i < 5; i++) {
      final y = (size.height / 5) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant TrafficChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints || oldDelegate.maxValue != maxValue;
  }
}
