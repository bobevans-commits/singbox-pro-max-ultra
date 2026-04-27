import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/config.dart';
import '../services/kernel_manager.dart';

class KernelSettingsScreen extends StatefulWidget {
  const KernelSettingsScreen({super.key});

  @override
  State<KernelSettingsScreen> createState() => _KernelSettingsScreenState();
}

class _KernelSettingsScreenState extends State<KernelSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KernelManager>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final kernelManager = context.watch<KernelManager>();
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('内核管理'),
          ),
          if (kernelManager.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.error,
                            color: theme.colorScheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            kernelManager.error!,
                            style: TextStyle(
                                color: theme.colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final type = KernelType.values[index];
                final status = kernelManager.getStatus(type);
                final version = kernelManager.getVersion(type);
                final isInstalled = kernelManager.isInstalled(type);

                return _KernelCard(
                  type: type,
                  status: status,
                  version: version,
                  isInstalled: isInstalled,
                  onDownload: () => _downloadKernel(kernelManager, type),
                  onDelete: () => _deleteKernel(kernelManager, type),
                  onCheckUpdate: () => _checkUpdate(kernelManager, type),
                );
              },
              childCount: KernelType.values.length,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadKernel(KernelManager manager, KernelType type) async {
    try {
      await manager.downloadKernel(type);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${type.label} 下载安装成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteKernel(KernelManager manager, KernelType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除内核'),
        content: Text('确定要删除 ${type.label} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await manager.deleteKernel(type);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${type.label} 已删除')),
        );
      }
    }
  }

  Future<void> _checkUpdate(KernelManager manager, KernelType type) async {
    final latestVersion = await manager.getLatestVersion(type);
    final currentVersion = manager.getVersion(type);

    if (!mounted) return;

    if (latestVersion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法获取最新版本信息')),
      );
      return;
    }

    if (latestVersion == currentVersion) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type.label} 已是最新版本 v$currentVersion')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '发现新版本: v$latestVersion (当前: v${currentVersion ?? "未安装"})',
          ),
          action: SnackBarAction(
            label: '更新',
            onPressed: () => _downloadKernel(manager, type),
          ),
        ),
      );
    }
  }
}

class _KernelCard extends StatelessWidget {
  final KernelType type;
  final KernelStatus status;
  final String? version;
  final bool isInstalled;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onCheckUpdate;

  const _KernelCard({
    required this.type,
    required this.status,
    this.version,
    required this.isInstalled,
    required this.onDownload,
    required this.onDelete,
    required this.onCheckUpdate,
  });

  Color _statusColor() {
    switch (status) {
      case KernelStatus.installed:
      case KernelStatus.running:
        return Colors.green;
      case KernelStatus.downloading:
      case KernelStatus.installing:
        return Colors.orange;
      case KernelStatus.error:
        return Colors.red;
      case KernelStatus.notInstalled:
      case KernelStatus.stopping:
        return Colors.grey;
    }
  }

  IconData _kernelIcon() {
    switch (type) {
      case KernelType.singbox:
        return Icons.dns;
      case KernelType.mihomo:
        return Icons.hub;
      case KernelType.v2ray:
        return Icons.language;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_kernelIcon(), size: 32, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.label,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _statusColor(),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _statusColor(),
                            ),
                          ),
                          if (version != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              'v$version',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (status == KernelStatus.downloading ||
                status == KernelStatus.installing)
              const LinearProgressIndicator(),
            if (status != KernelStatus.downloading &&
                status != KernelStatus.installing) ...[
              Row(
                children: [
                  if (!isInstalled)
                    FilledButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('下载'),
                    ),
                  if (isInstalled) ...[
                    OutlinedButton.icon(
                      onPressed: onCheckUpdate,
                      icon: const Icon(Icons.update, size: 18),
                      label: const Text('检查更新'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('删除'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
