import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/config.dart';
import '../services/proxy_service.dart';
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
          SliverAppBar(
            title: const Text('设置'),
          ),
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
                        onChanged: (v) {
                          proxyService
                              .updateConfig(config.copyWith(tunEnabled: v));
                        },
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
                          proxyService
                              .updateConfig(config.copyWith(systemProxy: v));
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
                          proxyService
                              .updateConfig(config.copyWith(lanSharing: v));
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
                          proxyService
                              .updateConfig(config.copyWith(adBlocking: v));
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
                          proxyService
                              .updateConfig(config.copyWith(smartNode: v));
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
                        subtitle: Text('v1.0.0',
                            style: theme.textTheme.labelSmall),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'ProxCore',
                            applicationVersion: '1.0.0',
                            applicationIcon:
                                const Icon(Icons.vpn_lock, size: 48),
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

  void _showDnsSettings(BuildContext context, ProxyConfig config) {
    var dnsMode = config.dnsConfig.mode;
    final serversCtrl =
        TextEditingController(text: config.dnsConfig.servers.join(', '));
    final fallbackCtrl =
        TextEditingController(text: config.dnsConfig.fallbackServers.join(', '));
    final dohUrlCtrl =
        TextEditingController(text: config.dnsConfig.dohUrl);
    final dotCtrl =
        TextEditingController(text: config.dnsConfig.dotServer);
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
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(m.label),
                          ))
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
                    subtitle: const Text('通过代理服务器解析 DNS',
                        style: TextStyle(fontSize: 10)),
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
                context.read<ProxyService>().updateConfig(config.copyWith(
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
                    ));
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
              context.read<ProxyService>().updateConfig(config.copyWith(
                    localAddress: addrCtrl.text.isEmpty
                        ? config.localAddress
                        : addrCtrl.text,
                    socksPort: socks.clamp(1, 65535),
                    httpPort: http.clamp(1, 65535),
                  ));
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
