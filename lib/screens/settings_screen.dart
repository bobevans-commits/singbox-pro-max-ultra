import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../models/config.dart';
import '../services/proxy_service.dart';
import '../services/kernel_manager.dart';
import 'kernel_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proxyService = context.watch<ProxyService>();
    final config = proxyService.config;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(title: const Text('设置')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  _SectionCard(
                    title: '内核',
                    icon: Icons.memory,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.dns_outlined),
                        title: const Text('内核管理'),
                        subtitle: Text(
                          '${config.kernelType.label} 内核',
                          style: theme.textTheme.labelSmall,
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const KernelSettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SectionCard(
                    title: '网络',
                    icon: Icons.language,
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.vpn_lock),
                        title: const Text('TUN 模式'),
                        subtitle: Text(
                          '虚拟网卡全局代理，无需安装服务',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 10,
                          ),
                        ),
                        value: config.tunEnabled,
                        onChanged: (v) =>
                            _onTunToggle(context, proxyService, v),
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.settings_ethernet),
                        title: const Text('系统代理'),
                        subtitle: Text(
                          '设置系统 HTTP/SOCKS 代理',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 10,
                          ),
                        ),
                        value: config.systemProxy,
                        onChanged: (v) {
                          proxyService.setSystemProxy(v);
                        },
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.wifi),
                        title: const Text('局域网共享'),
                        subtitle: Text(
                          '允许其他设备通过本机代理',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 10,
                          ),
                        ),
                        value: config.lanSharing,
                        onChanged: (v) {
                          proxyService.updateConfig(
                            config.copyWith(lanSharing: v),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SectionCard(
                    title: '规则',
                    icon: Icons.shield_outlined,
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.block),
                        title: const Text('广告屏蔽'),
                        subtitle: Text(
                          '过滤常见广告域名',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 10,
                          ),
                        ),
                        value: config.adBlocking,
                        onChanged: (v) {
                          proxyService.updateConfig(
                            config.copyWith(adBlocking: v),
                          );
                        },
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.auto_awesome),
                        title: const Text('智能节点'),
                        subtitle: Text(
                          '自动选择延迟最低的节点',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 10,
                          ),
                        ),
                        value: config.smartNode,
                        onChanged: (v) {
                          proxyService.updateConfig(
                            config.copyWith(smartNode: v),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SectionCard(
                    title: 'DNS',
                    icon: Icons.dns,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.dns_outlined),
                        title: const Text('DNS 配置'),
                        subtitle: Text(
                          config.dnsConfig.mode.label,
                          style: theme.textTheme.labelSmall,
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => _showDnsSettings(context, config),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SectionCard(
                    title: '端口',
                    icon: Icons.swap_vert,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.swap_vert),
                        title: const Text('端口设置'),
                        subtitle: Text(
                          'SOCKS ${config.socksPort}  |  HTTP ${config.httpPort}',
                          style: theme.textTheme.labelSmall,
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => _showPortSettings(context, config),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SectionCard(
                    title: '数据',
                    icon: Icons.storage,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.upload_file),
                        title: const Text('导出配置'),
                        subtitle: Text(
                          '导出全部设置、节点和规则',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 10,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => _exportConfig(context),
                      ),
                      ListTile(
                        leading: const Icon(Icons.download),
                        title: const Text('导入配置'),
                        subtitle: Text(
                          '从文件恢复配置',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 10,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => _importConfig(context),
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.delete_forever,
                          color: theme.colorScheme.error,
                        ),
                        title: Text(
                          '清除所有数据',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        subtitle: Text(
                          '删除全部节点、规则和设置',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 10,
                          ),
                        ),
                        onTap: () => _confirmClearData(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SectionCard(
                    title: '外观',
                    icon: Icons.palette,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.dark_mode),
                        title: const Text('主题模式'),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => _showThemePicker(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SectionCard(
                    title: '关于',
                    icon: Icons.info_outline,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('关于 ProxCore'),
                        subtitle: Text(
                          'v1.0.0',
                          style: theme.textTheme.labelSmall,
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'ProxCore',
                            applicationVersion: '1.0.0',
                            applicationIcon: const Icon(
                              Icons.vpn_lock,
                              size: 48,
                            ),
                            children: [
                              const Text('多内核代理客户端'),
                              const SizedBox(height: 8),
                              const Text('支持 sing-box / mihomo / v2ray'),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportConfig(BuildContext context) async {
    try {
      final proxyService = context.read<ProxyService>();
      final jsonStr = await proxyService.exportConfig();
      final dir = Directory.systemTemp;
      final file = File(
        '${dir.path}/proxcore_config_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(jsonStr);

      await Share.shareXFiles([XFile(file.path)], text: 'ProxCore 配置文件');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _importConfig(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonStr = await file.readAsString();

        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认导入'),
            content: const Text('导入将覆盖当前所有配置，确定继续吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('确定'),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          final success = await context.read<ProxyService>().importConfig(
            jsonStr,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success ? '导入成功' : '导入失败，文件格式错误'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _confirmClearData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除所有数据'),
        content: const Text('此操作将删除全部节点、规则、订阅和设置，且不可恢复。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final proxyService = context.read<ProxyService>();
              proxyService.clearNodes();
              proxyService.updateRoutingRules([]);
              proxyService.updateConfig(ProxyConfig());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已清除所有数据'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确定清除'),
          ),
        ],
      ),
    );
  }

  void _showDnsSettings(BuildContext context, ProxyConfig config) {
    var dnsMode = config.dnsConfig.mode;
    final serversCtrl = TextEditingController(
      text: config.dnsConfig.servers.join(', '),
    );
    final fallbackCtrl = TextEditingController(
      text: config.dnsConfig.fallbackServers.join(', '),
    );
    final dohUrlCtrl = TextEditingController(text: config.dnsConfig.dohUrl);
    final dotCtrl = TextEditingController(text: config.dnsConfig.dotServer);
    var remoteResolve = config.dnsConfig.remoteResolve;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('DNS 配置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<DnsMode>(
                  initialValue: dnsMode,
                  decoration: const InputDecoration(
                    labelText: 'DNS 模式',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: DnsMode.values
                      .map(
                        (m) => DropdownMenuItem(value: m, child: Text(m.label)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => dnsMode = v);
                  },
                ),
                const SizedBox(height: 12),
                if (dnsMode != DnsMode.system) ...[
                  TextField(
                    controller: serversCtrl,
                    decoration: const InputDecoration(
                      labelText: 'DNS 服务器（逗号分隔）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fallbackCtrl,
                    decoration: const InputDecoration(
                      labelText: '备用 DNS（逗号分隔）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
                if (dnsMode == DnsMode.doh) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: dohUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'DoH URL',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
                if (dnsMode == DnsMode.dot) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: dotCtrl,
                    decoration: const InputDecoration(
                      labelText: 'DoT 服务器',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
                if (dnsMode != DnsMode.system) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('远程解析'),
                    subtitle: const Text(
                      '通过代理服务器解析 DNS',
                      style: TextStyle(fontSize: 10),
                    ),
                    value: remoteResolve,
                    onChanged: (v) {
                      setDialogState(() => remoteResolve = v);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final servers = serversCtrl.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                final fallback = fallbackCtrl.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                context.read<ProxyService>().updateConfig(
                  config.copyWith(
                    dnsConfig: DnsConfig(
                      mode: dnsMode,
                      servers: servers.isNotEmpty
                          ? servers
                          : const ['8.8.8.8', '1.1.1.1'],
                      fallbackServers: fallback.isNotEmpty
                          ? fallback
                          : const ['223.5.5.5', '119.29.29.29'],
                      remoteResolve: remoteResolve,
                      dohUrl: dohUrlCtrl.text.isEmpty
                          ? 'https://dns.google/dns-query'
                          : dohUrlCtrl.text,
                      dotServer: dotCtrl.text.isEmpty
                          ? 'dns.google'
                          : dotCtrl.text,
                    ),
                  ),
                );
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPortSettings(BuildContext context, ProxyConfig config) {
    final socksCtrl = TextEditingController(text: '${config.socksPort}');
    final httpCtrl = TextEditingController(text: '${config.httpPort}');
    final addrCtrl = TextEditingController(text: config.localAddress);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('端口设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: addrCtrl,
              decoration: const InputDecoration(
                labelText: '监听地址',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: socksCtrl,
                    decoration: const InputDecoration(
                      labelText: 'SOCKS 端口',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: httpCtrl,
                    decoration: const InputDecoration(
                      labelText: 'HTTP 端口',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final socks = int.tryParse(socksCtrl.text) ?? config.socksPort;
              final http = int.tryParse(httpCtrl.text) ?? config.httpPort;
              context.read<ProxyService>().updateConfig(
                config.copyWith(
                  localAddress: addrCtrl.text.isEmpty
                      ? config.localAddress
                      : addrCtrl.text,
                  socksPort: socks.clamp(1, 65535),
                  httpPort: http.clamp(1, 65535),
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    MyApp.toggleThemeOf(context);
  }

  Future<void> _onTunToggle(
    BuildContext context,
    ProxyService proxyService,
    bool enable,
  ) async {
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
        content: Text('TUN 模式需要 ${kernelType.label} 内核支持。当前未检测到已安装的内核，是否前往安装？'),
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
      final kernelType = proxyService.activeKernelType;
      final kernelManager = proxyService.kernelManager;
      final installed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _SettingsKernelInstallScreen(
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
}

class _SettingsKernelInstallScreen extends StatefulWidget {
  final KernelType kernelType;
  final KernelManager kernelManager;

  const _SettingsKernelInstallScreen({
    required this.kernelType,
    required this.kernelManager,
  });

  @override
  State<_SettingsKernelInstallScreen> createState() =>
      _SettingsKernelInstallScreenState();
}

class _SettingsKernelInstallScreenState
    extends State<_SettingsKernelInstallScreen> {
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
                _downloading
                    ? '正在下载 ${widget.kernelType.label} 内核...'
                    : '准备下载...',
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

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
