import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config.dart';
import '../services/kernel_manager.dart';

/// 内核管理设置页面
class KernelSettingsScreen extends StatefulWidget {
  const KernelSettingsScreen({super.key});

  @override
  State<KernelSettingsScreen> createState() => _KernelSettingsScreenState();
}

class _KernelSettingsScreenState extends State<KernelSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // 初始化时检查更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<KernelManager>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('内核管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<KernelManager>(context, listen: false)
                  .initialize();
            },
            tooltip: '刷新',
          ),
        ],
      ),
      body: Consumer<KernelManager>(
        builder: (context, kernelManager, child) {
          if (kernelManager.isUpdating) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在检查更新...'),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCurrentKernelCard(kernelManager),
                const SizedBox(height: 24),
                _buildKernelList(kernelManager),
                const SizedBox(height: 24),
                if (kernelManager.errorMessage != null)
                  _buildErrorCard(kernelManager),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建当前选中的内核卡片
  Widget _buildCurrentKernelCard(KernelManager manager) {
    final currentKernel = manager.selectedKernel;
    
    return Card(
      elevation: 4,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getKernelIcon(manager.selectedKernelType),
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前内核：${manager.selectedKernelType.name}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentKernel?.version != 'unknown'
                            ? '版本：v${currentKernel?.version}'
                            : '版本：未安装',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: manager.isCurrentKernelReady
                        ? Colors.green
                        : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    manager.isCurrentKernelReady ? '就绪' : '未就绪',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (currentKernel?.supportedProtocols.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                '支持的协议:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: currentKernel!.supportedProtocols
                    .map((protocol) => Chip(
                          label: Text(protocol),
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建内核列表
  Widget _buildKernelList(KernelManager manager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '可用内核',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...KernelType.values.map((type) => _buildKernelItem(manager, type)),
      ],
    );
  }

  /// 构建单个内核项
  Widget _buildKernelItem(KernelManager manager, KernelType type) {
    final info = manager.kernels[type];
    final isSelected = manager.selectedKernelType == type;
    final releases = manager.releases[type];
    final latestVersion = releases?.isNotEmpty == true ? releases!.first.version : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          _getKernelIcon(type),
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey,
        ),
        title: Text(
          type.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info?.version != 'unknown' ? 'v${info?.version}' : '未安装'),
            if (latestVersion != null && info?.version != latestVersion)
              Text(
                '最新版本：v$latestVersion',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!info!.isDownloaded)
              ElevatedButton.icon(
                icon: manager.isDownloading &&
                        manager.currentDownload != null
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download, size: 18),
                label: Text(manager.isDownloading ? '下载中...' : '下载'),
                onPressed: manager.isDownloading
                    ? null
                    : () => _downloadKernel(manager, type),
              )
            else
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'switch') {
                    await _switchKernel(manager, type);
                  } else if (value == 'update' && latestVersion != null) {
                    await _downloadKernel(manager, type, version: latestVersion);
                  } else if (value == 'delete') {
                    await _deleteKernel(manager, type);
                  }
                },
                itemBuilder: (context) => [
                  if (!isSelected)
                    const PopupMenuItem(
                      value: 'switch',
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline),
                        title: Text('切换到此内核'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (latestVersion != null && info.version != latestVersion)
                    const PopupMenuItem(
                      value: 'update',
                      child: ListTile(
                        leading: Icon(Icons.update),
                        title: Text('更新到最新版本'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('删除内核', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
          ],
        ),
        children: [
          if (releases != null && releases.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '历史版本:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ...releases.take(5).map((release) => ListTile(
                        dense: true,
                        title: Text('v${release.version}'),
                        subtitle: Text(
                          '发布于 ${_formatDate(release.publishedAt)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.download, size: 20),
                          onPressed: () => _downloadKernel(
                            manager,
                            type,
                            version: release.version,
                          ),
                          tooltip: '下载此版本',
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建错误提示卡片
  Widget _buildErrorCard(KernelManager manager) {
    return Card(
      color: Colors.red[50],
      child: ListTile(
        leading: const Icon(Icons.error, color: Colors.red),
        title: Text(
          manager.errorMessage!,
          style: const TextStyle(color: Colors.red),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: manager.clearError,
        ),
      ),
    );
  }

  /// 下载内核
  Future<void> _downloadKernel(
    KernelManager manager,
    KernelType type, {
    String? version,
  }) async {
    final success = await manager.downloadKernel(type: type, version: version);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '下载完成' : '下载失败',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  /// 切换内核
  Future<void> _switchKernel(KernelManager manager, KernelType type) async {
    try {
      await manager.switchKernel(type);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已切换到 ${type.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 删除内核
  Future<void> _deleteKernel(KernelManager manager, KernelType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${type.name} 内核吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await manager.deleteKernel(type);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? '删除成功' : '删除失败',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  /// 获取内核图标
  IconData _getKernelIcon(KernelType type) {
    switch (type) {
      case KernelType.singBox:
        return Icons.network_check;
      case KernelType.mihomo:
        return Icons.dns;
      case KernelType.v2Ray:
        return Icons.public;
    }
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
