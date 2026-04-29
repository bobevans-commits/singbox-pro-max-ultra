import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/config.dart';
import '../services/kernel_manager.dart';
import '../services/proxy_service.dart';
import '../services/subscription_service.dart';
import '../utils/app_utils.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _trafficTimer;

  @override
  void initState() {
    super.initState();
    _trafficTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _trafficTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proxyService = context.watch<ProxyService>();
    final subService = context.watch<SubscriptionService>();
    final isRunning = proxyService.isRunning;
    final activeNode = proxyService.activeNode;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(title: const Text('仪表板')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  _StatusHero(
                    isRunning: isRunning,
                    activeNode: activeNode,
                    nodeCount: proxyService.nodes.length,
                    uptime: proxyService.uptime,
                    onToggle: () {
                      if (isRunning) {
                        proxyService.stop();
                      } else if (activeNode != null) {
                        proxyService.start(activeNode);
                      } else if (proxyService.nodes.isNotEmpty) {
                        proxyService.start(proxyService.nodes.first);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          icon: Icons.upload,
                          label: '上传',
                          value:
                              '${AppUtils.formatBytes(proxyService.uploadSpeed)}/s',
                          total: AppUtils.formatBytes(proxyService.uploadBytes),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatChip(
                          icon: Icons.download,
                          label: '下载',
                          value:
                              '${AppUtils.formatBytes(proxyService.downloadSpeed)}/s',
                          total: AppUtils.formatBytes(
                            proxyService.downloadBytes,
                          ),
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _LatencyChip(proxyService: proxyService)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (isRunning) ...[
                    _SpeedChart(proxyService: proxyService),
                    const SizedBox(height: 8),
                  ],
                  _OverviewBar(
                    nodeCount: proxyService.nodes.length,
                    ruleCount: proxyService.routingRules.length,
                    subCount: subService.subscriptions.length,
                    kernelLabel: proxyService.config.kernelType.label,
                  ),
                  const SizedBox(height: 8),
                  _QuickSettings(proxyService: proxyService),
                  const SizedBox(height: 8),
                  _ConnectionGrid(proxyService: proxyService),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UptimeText extends StatefulWidget {
  final Duration uptime;

  const _UptimeText({required this.uptime});

  @override
  State<_UptimeText> createState() => _UptimeTextState();
}

class _UptimeTextState extends State<_UptimeText> {
  late Duration _uptime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _uptime = widget.uptime;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _uptime = _uptime + const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _UptimeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _uptime = widget.uptime;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '运行时长 ${_formatDuration(_uptime)}',
      style: theme.textTheme.labelSmall?.copyWith(
        color: Colors.green,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  final bool isRunning;
  final NodeConfig? activeNode;
  final int nodeCount;
  final Duration? uptime;
  final VoidCallback onToggle;

  const _StatusHero({
    required this.isRunning,
    this.activeNode,
    required this.nodeCount,
    this.uptime,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bgColor = isRunning
        ? Colors.green.withValues(alpha: 0.08)
        : colorScheme.surfaceContainerLow;

    return Card(
      color: bgColor,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isRunning
                    ? Colors.green.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRunning ? Icons.power_settings_new : Icons.power_off,
                color: isRunning ? Colors.green : colorScheme.outline,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRunning ? '代理运行中' : '代理未运行',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (activeNode != null)
                    Text(
                      '${AppUtils.protocolIcon(activeNode!.protocol)} ${activeNode!.name}  ${activeNode!.address}:${activeNode!.port}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (isRunning && uptime != null)
                    _UptimeText(uptime: uptime!),
                  if (activeNode == null && !isRunning)
                    Text(
                      nodeCount > 0
                          ? '点击启动连接 $nodeCount 个节点'
                          : '添加节点开始使用',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onToggle,
              style: FilledButton.styleFrom(
                backgroundColor: isRunning ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                minimumSize: const Size(0, 36),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isRunning ? Icons.stop : Icons.play_arrow, size: 18),
                  const SizedBox(width: 4),
                  Text(isRunning ? '停止' : '启动'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewBar extends StatelessWidget {
  final int nodeCount;
  final int ruleCount;
  final int subCount;
  final String kernelLabel;

  const _OverviewBar({
    required this.nodeCount,
    required this.ruleCount,
    required this.subCount,
    required this.kernelLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _OverviewChip(
              icon: Icons.dns,
              label: '节点',
              value: '$nodeCount',
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            _OverviewChip(
              icon: Icons.route,
              label: '规则',
              value: '$ruleCount',
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(width: 12),
            _OverviewChip(
              icon: Icons.rss_feed,
              label: '订阅',
              value: '$subCount',
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 12),
            _OverviewChip(
              icon: Icons.memory,
              label: '内核',
              value: kernelLabel,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _OverviewChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String total;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              total,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatencyChip extends StatelessWidget {
  final ProxyService proxyService;

  const _LatencyChip({required this.proxyService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latency = proxyService.latencyMs;
    final activeNode = proxyService.activeNode;

    Color latencyColor;
    String latencyText;
    if (latency == null) {
      latencyColor = theme.colorScheme.outline;
      latencyText = '--';
    } else if (latency == -1) {
      latencyColor = Colors.red;
      latencyText = '超时';
    } else {
      latencyColor = Color(AppUtils.latencyColor(latency));
      latencyText = '$latency ms';
    }

    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: activeNode != null
            ? () => proxyService.testLatency(activeNode)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.speed, size: 14, color: latencyColor),
                  const SizedBox(width: 4),
                  Text(
                    '延迟',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                latencyText,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: latencyColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedChart extends StatelessWidget {
  final ProxyService proxyService;

  const _SpeedChart({required this.proxyService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = proxyService.speedHistory;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '实时网速',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _legend(theme.colorScheme.primary, '上传'),
                const SizedBox(width: 8),
                _legend(theme.colorScheme.tertiary, '下载'),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 80,
              child: CustomPaint(
                painter: _SpeedChartPainter(
                  history: history,
                  uploadColor: theme.colorScheme.primary,
                  downloadColor: theme.colorScheme.tertiary,
                  gridColor: theme.colorScheme.outline.withValues(alpha: 0.1),
                ),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ],
    );
  }
}

class _SpeedChartPainter extends CustomPainter {
  final List history;
  final Color uploadColor;
  final Color downloadColor;
  final Color gridColor;

  const _SpeedChartPainter({
    required this.history,
    required this.uploadColor,
    required this.downloadColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final gridPaint = Paint()..color = gridColor;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    int maxVal = 0;
    for (final r in history) {
      maxVal = max(maxVal, r.upload as int);
      maxVal = max(maxVal, r.download as int);
    }
    if (maxVal == 0) maxVal = 1;

    _drawLine(
      canvas,
      size,
      history.map((r) => r.upload as int).toList(),
      uploadColor,
      maxVal,
    );
    _drawLine(
      canvas,
      size,
      history.map((r) => r.download as int).toList(),
      downloadColor,
      maxVal,
    );
  }

  void _drawLine(
    Canvas canvas,
    Size size,
    List<int> values,
    Color color,
    int maxVal,
  ) {
    if (values.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (values.length - 1);

    for (var i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] / maxVal) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpeedChartPainter oldDelegate) => true;
}

class _QuickSettings extends StatelessWidget {
  final ProxyService proxyService;

  const _QuickSettings({required this.proxyService});

  Future<void> _onTunToggle(BuildContext context, bool enable) async {
    if (!enable) {
      proxyService.toggleTun(false);
      return;
    }

    if (proxyService.isKernelInstalled()) {
      proxyService.toggleTun(true);
      return;
    }

    final kernelType = proxyService.activeKernelType;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.vpn_lock, size: 32),
        title: const Text('需要安装内核'),
        content: Text(
          'TUN 模式需要 ${kernelType.label} 内核支持。当前未检测到已安装的内核，是否前往安装？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'install'),
            child: const Text('前往安装'),
          ),
        ],
      ),
    );

    if (result == 'install' && context.mounted) {
      final kernelManager = proxyService.kernelManager;
      final installed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _KernelInstallScreen(
            kernelType: kernelType,
            kernelManager: kernelManager,
          ),
        ),
      );

      if (installed == true && context.mounted) {
        proxyService.toggleTun(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('TUN 模式已开启'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = proxyService.config;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                children: [
                  Text(
                    '快捷设置',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '更多设置',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 4),
              secondary: Icon(
                Icons.vpn_lock,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              title: Text('TUN 模式', style: theme.textTheme.bodySmall),
              subtitle: Text(
                '虚拟网卡全局代理',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 10,
                ),
              ),
              value: config.tunEnabled,
              onChanged: (v) => _onTunToggle(context, v),
            ),
            const Divider(height: 1, indent: 32),
            SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 4),
              secondary: Icon(
                Icons.settings_ethernet,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              title: Text('系统代理', style: theme.textTheme.bodySmall),
              subtitle: Text(
                '设置系统 HTTP/SOCKS 代理',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 10,
                ),
              ),
              value: config.systemProxy,
              onChanged: (v) => proxyService.setSystemProxy(v),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionGrid extends StatelessWidget {
  final ProxyService proxyService;

  const _ConnectionGrid({required this.proxyService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = proxyService.config;
    final isRunning = proxyService.isRunning;

    final items = [
      _ConnItem(Icons.swap_vert, 'SOCKS', '${config.socksPort}'),
      _ConnItem(Icons.http, 'HTTP', '${config.httpPort}'),
      _ConnItem(
        Icons.lan,
        '监听',
        config.lanSharing ? '0.0.0.0' : config.localAddress,
      ),
      _ConnItem(Icons.memory, '内核', config.kernelType.label),
      _ConnItem(
        Icons.vpn_lock,
        'TUN',
        config.tunEnabled ? '开启' : '关闭',
        valueColor: config.tunEnabled ? Colors.green : null,
      ),
      _ConnItem(Icons.dns, 'DNS', config.dnsConfig.mode.label),
    ];

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Row(
                children: [
                  Text(
                    '连接信息',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isRunning
                          ? Colors.green
                          : theme.colorScheme.outline,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isRunning ? '已连接' : '未连接',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isRunning
                          ? Colors.green
                          : theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: items.map((item) {
                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 12,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        item.value,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: item.valueColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnItem {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ConnItem(this.icon, this.label, this.value, {this.valueColor});
}

class _KernelInstallScreen extends StatefulWidget {
  final KernelType kernelType;
  final KernelManager kernelManager;

  const _KernelInstallScreen({
    required this.kernelType,
    required this.kernelManager,
  });

  @override
  State<_KernelInstallScreen> createState() => _KernelInstallScreenState();
}

class _KernelInstallScreenState extends State<_KernelInstallScreen> {
  bool _downloading = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _progress = null;
    });

    widget.kernelManager.addListener(_onManagerUpdate);

    try {
      await widget.kernelManager.downloadKernel(widget.kernelType);
      if (mounted) {
        widget.kernelManager.removeListener(_onManagerUpdate);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        widget.kernelManager.removeListener(_onManagerUpdate);
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onManagerUpdate() {
    if (mounted) {
      setState(() {
        _progress = widget.kernelManager.downloadProgress;
      });
    }
  }

  @override
  void dispose() {
    widget.kernelManager.removeListener(_onManagerUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('安装 ${widget.kernelType.label}')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.download,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                _downloading ? '正在下载 ${widget.kernelType.label} 内核...' : '准备下载...',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (_downloading) ...[
                SizedBox(
                  width: 280,
                  child: LinearProgressIndicator(value: _progress),
                ),
                const SizedBox(height: 8),
                if (_progress != null)
                  Text(
                    '${(_progress! * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              Text(
                '下载完成后将自动返回并开启 TUN 模式',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              if (!_downloading)
                FilledButton.icon(
                  onPressed: _startDownload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
