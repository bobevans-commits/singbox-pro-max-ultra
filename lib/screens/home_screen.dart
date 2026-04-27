import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/config.dart';
import '../services/proxy_service.dart';
import '../utils/app_utils.dart';

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
    final theme = Theme.of(context);
    final isRunning = proxyService.isRunning;
    final activeNode = proxyService.activeNode;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('仪表板'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusCard(
                    isRunning: isRunning,
                    activeNode: activeNode,
                    onToggle: () {
                      if (isRunning) {
                        proxyService.stop();
                      } else if (activeNode != null) {
                        proxyService.start(activeNode);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '流量统计',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _TrafficStats(
                    upload: proxyService.uploadBytes,
                    download: proxyService.downloadBytes,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '连接信息',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _ConnectionInfo(proxyService: proxyService),
                  const SizedBox(height: 24),
                  Text(
                    '延迟测试',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _LatencyCard(proxyService: proxyService),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool isRunning;
  final NodeConfig? activeNode;
  final VoidCallback onToggle;

  const _StatusCard({
    required this.isRunning,
    this.activeNode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              isRunning ? Icons.cloud_done : Icons.cloud_off,
              size: 64,
              color: isRunning ? Colors.green : theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              isRunning ? '代理运行中' : '代理未运行',
              style: theme.textTheme.titleLarge,
            ),
            if (activeNode != null) ...[
              const SizedBox(height: 8),
              Text(
                '${AppUtils.protocolIcon(activeNode!.protocol)} ${activeNode!.name}',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '${activeNode!.address}:${activeNode!.port}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onToggle,
              icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
              label: Text(isRunning ? '停止' : '启动'),
              style: FilledButton.styleFrom(
                backgroundColor: isRunning ? Colors.red : Colors.green,
                minimumSize: const Size(200, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficStats extends StatelessWidget {
  final int upload;
  final int download;

  const _TrafficStats({required this.upload, required this.download});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.upload, color: theme.colorScheme.primary),
                  const SizedBox(height: 4),
                  Text('上传', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    AppUtils.formatBytes(upload),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.download, color: theme.colorScheme.tertiary),
                  const SizedBox(height: 4),
                  Text('下载', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    AppUtils.formatBytes(download),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LatencyCard extends StatelessWidget {
  final ProxyService proxyService;

  const _LatencyCard({required this.proxyService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latency = proxyService.latencyMs;
    final activeNode = proxyService.activeNode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.speed,
              color: latency != null && latency > 0
                  ? Colors.green
                  : latency == -1
                      ? Colors.red
                      : theme.colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('延迟', style: theme.textTheme.bodyMedium),
                  Text(
                    latency == null
                        ? '未测试'
                        : latency == -1
                            ? '超时'
                            : '$latency ms',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: latency != null && latency > 0
                          ? Colors.green
                          : latency == -1
                              ? Colors.red
                              : null,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: activeNode != null
                  ? () => proxyService.testLatency(activeNode)
                  : null,
              child: const Text('测试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionInfo extends StatelessWidget {
  final ProxyService proxyService;

  const _ConnectionInfo({required this.proxyService});

  @override
  Widget build(BuildContext context) {
    final config = proxyService.config;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow(context, 'SOCKS 端口', '${config.socksPort}'),
            _infoRow(context, 'HTTP 端口', '${config.httpPort}'),
            _infoRow(context, '监听地址', config.localAddress),
            _infoRow(context, 'TUN 模式', config.tunEnabled ? '开启' : '关闭'),
            _infoRow(context, '系统代理', config.systemProxy ? '开启' : '关闭'),
            _infoRow(context, '内核', config.kernelType.label),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}
