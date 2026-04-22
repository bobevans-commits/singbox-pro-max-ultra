import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/proxy_service.dart';
import '../models/config.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proxy Client'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: Consumer<ProxyService>(
        builder: (context, service, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 状态卡片
                _buildStatusCard(service),
                const SizedBox(height: 16),

                // 内核选择
                _buildKernelSelector(service),
                const SizedBox(height: 16),

                // 流量统计
                _buildTrafficCard(service),
                const SizedBox(height: 16),

                // 节点列表
                _buildNodeList(service),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Consumer<ProxyService>(
        builder: (context, service, child) {
          return FloatingActionButton.extended(
            onPressed: () => _toggleProxy(service),
            icon: Icon(service.isRunning ? Icons.stop : Icons.play_arrow),
            label: Text(service.isRunning ? '停止' : '启动'),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(ProxyService service) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: service.status.getColor(context),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  service.status.description,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            if (service.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                service.errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKernelSelector(ProxyService service) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '内核选择',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<KernelType>(
              segments: const [
                ButtonSegment(
                  value: KernelType.singBox,
                  label: Text('sing-box'),
                ),
                ButtonSegment(
                  value: KernelType.mihomo,
                  label: Text('mihomo'),
                ),
                ButtonSegment(
                  value: KernelType.v2Ray,
                  label: Text('v2ray'),
                ),
              ],
              selected: {service.currentKernel},
              onSelectionChanged: (Set<KernelType> selected) {
                if (selected.isNotEmpty) {
                  service.switchKernel(selected.first);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrafficCard(ProxyService service) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '流量统计',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(Icons.arrow_upward, color: Colors.green),
                    const SizedBox(height: 4),
                    Text(
                      '${service.uploadSpeed.toStringAsFixed(2)} KB/s',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const Text('上传', style: TextStyle(fontSize: 12)),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.arrow_downward, color: Colors.blue),
                    const SizedBox(height: 4),
                    Text(
                      '${service.downloadSpeed.toStringAsFixed(2)} KB/s',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const Text('下载', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeList(ProxyService service) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '节点列表',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: () => _importConfig(context, service),
                  icon: const Icon(Icons.add),
                  label: const Text('导入'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (service.config?.nodes.isEmpty ?? true)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('暂无节点，请点击右上角导入配置'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: service.config?.nodes.length ?? 0,
                itemBuilder: (context, index) {
                  final node = service.config!.nodes[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.dns),
                    ),
                    title: Text(node.name),
                    subtitle: Text('${node.server}:${node.port}'),
                    trailing: FutureBuilder<int>(
                      future: service.testLatency(node.name),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        final latency = snapshot.data ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: latency < 100
                                ? Colors.green.shade100
                                : latency < 200
                                    ? Colors.orange.shade100
                                    : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$latency ms',
                            style: TextStyle(
                              color: latency < 100
                                  ? Colors.green.shade700
                                  : latency < 200
                                      ? Colors.orange.shade700
                                      : Colors.red.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _toggleProxy(ProxyService service) {
    if (service.isRunning) {
      service.stopKernel();
    } else {
      service.startKernel(service.currentKernel);
    }
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const SettingsSheet(),
    );
  }

  void _importConfig(BuildContext context, ProxyService service) {
    // TODO: 实现配置文件导入
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('配置文件导入功能开发中...')),
    );
  }
}

/// 设置面板
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '设置',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('开机自启'),
            value: false,
            onChanged: (value) {},
          ),
          SwitchListTile(
            title: const Text('系统代理'),
            value: false,
            onChanged: (value) {},
          ),
          ListTile(
            title: const Text('关于'),
            trailing: const Icon(Icons.info_outline),
            onTap: () => _showAbout(context),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Proxy Client',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2024 Open Source',
      children: [
        const Text('多平台代理客户端'),
        const Text('支持 sing-box, mihomo, v2ray-core'),
      ],
    );
  }
}
