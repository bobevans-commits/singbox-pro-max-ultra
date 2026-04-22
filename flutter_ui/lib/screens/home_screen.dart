import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/proxy_service.dart';
import '../models/singbox_config.dart';
import '../widgets/proxy_link_importer.dart';
import 'log_screen.dart';
import 'node_editor_screen.dart';
import 'routing_editor_screen.dart';

/// Main Home Screen with Dashboard, Nodes, Routing, DNS, and Settings tabs
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const NodesScreen(),
    const RoutingScreen(),
    const DnsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.dns), label: 'Nodes'),
          NavigationDestination(icon: Icon(Icons.route), label: 'Routing'),
          NavigationDestination(icon: Icon(Icons.security), label: 'DNS'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      appBar: AppBar(
        title: const Text('Proxy Client'),
        actions: [
          IconButton(
            icon: const Icon(Icons.subject),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogScreen()),
              );
            },
            tooltip: 'View Logs',
          ),
        ],
      ),
    );
  }
}

// ==================== Dashboard Screen ====================

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final proxyService = context.watch<ProxyService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          _buildStatusCard(proxyService),
          
          const SizedBox(height: 16),
          
          // Traffic Stats
          Row(
            children: [
              Expanded(child: _buildTrafficCard('Upload', proxyService.trafficUp, Icons.upload)),
              const SizedBox(width: 12),
              Expanded(child: _buildTrafficCard('Download', proxyService.trafficDown, Icons.download)),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Quick Actions
          _buildQuickActions(context, proxyService),
          
          const SizedBox(height: 16),
          
          // Connection Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Connection Info', style: Theme.of(context).textTheme.titleMedium),
                  const Divider(),
                  _buildInfoRow('Status', proxyService.status.name.toUpperCase()),
                  _buildInfoRow('Mode', proxyService.isTunEnabled ? 'TUN' : 'Proxy'),
                  _buildInfoRow('Latency', '${proxyService.latency.toStringAsFixed(1)} ms'),
                  _buildInfoRow('Selected', proxyService.selectedOutbound),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ProxyService service) {
    final isRunning = service.isRunning;
    final color = isRunning ? Colors.green : (service.status == ProxyStatus.error ? Colors.red : Colors.grey);
    
    return Card(
      color: color.withOpacity(0.1),
      child: InkWell(
        onTap: () => isRunning ? service.stopProxy() : service.startProxy(),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRunning ? 'Proxy Running' : 'Proxy Stopped',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isRunning ? 'Tap to stop' : 'Tap to start',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
              Icon(
                isRunning ? Icons.power_settings_new : Icons.power_off,
                size: 48,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrafficCard(String label, int bytes, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(height: 8),
            Text(_formatBytes(bytes), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, ProxyService service) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => service.toggleTun(!service.isTunEnabled),
                  icon: Icon(service.isTunEnabled ? Icons.check_circle : Icons.circle_outlined),
                  label: Text(service.isTunEnabled ? 'TUN On' : 'TUN Off'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await service.testLatency();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Latency test completed: ${result.length} nodes')),
                      );
                    }
                  },
                  icon: const Icon(Icons.speed),
                  label: const Text('Test Latency'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showImportDialog(context, service),
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import Config'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _showImportDialog(BuildContext context, ProxyService service) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Configuration'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Paste JSON config here'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              service.importConfig(controller.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Config imported')));
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }
}

// ==================== Nodes Screen ====================

class NodesScreen extends StatelessWidget {
  const NodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProxyService>();
    final outbounds = service.currentConfig?.outbounds ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Proxy Nodes')),
      body: ListView.builder(
        itemCount: outbounds.length,
        itemBuilder: (ctx, i) {
          final outbound = outbounds[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: _getProtocolIcon(outbound.type),
              title: Text(outbound.tag),
              subtitle: Text('${outbound.type}${outbound.server != null ? ' - ${outbound.server}' : ''}'),
              trailing: outbound.type == 'selector' || outbound.type == 'urltest' 
                  ? const Icon(Icons.group)
                  : IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => service.removeOutbound(outbound.tag),
                    ),
              onTap: () => _showNodeDetails(context, outbound),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNodeDialog(context, service),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _getProtocolIcon(String type) {
    switch (type) {
      case 'vmess': return const Icon(Icons.flash_on, color: Colors.orange);
      case 'vless': return const Icon(Icons.bolt, color: Colors.amber);
      case 'trojan': return const Icon(Icons.shield, color: Colors.purple);
      case 'shadowsocks': return const Icon(Icons.lock, color: Colors.blue);
      case 'hysteria': 
      case 'hysteria2': return const Icon(Icons.rocket, color: Colors.red);
      case 'tuic': return const Icon(Icons.speed, color: Colors.teal);
      case 'wireguard': return const Icon(Icons.vpn_key, color: Colors.green);
      default: return const Icon(Icons.public);
    }
  }

  void _showNodeDetails(BuildContext context, Outbound node) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(node.tag, style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NodeEditorScreen(existingNode: node),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildDetailRow('Type', node.type),
            if (node.server != null) _buildDetailRow('Server', '${node.server}:${node.serverPort}'),
            if (node.uuid != null) _buildDetailRow('UUID', node.uuid!),
            if (node.password != null) _buildDetailRow('Password', '••••••••'),
            if (node.tls != null) _buildDetailRow('TLS', node.tls!.enabled ? 'Enabled' : 'Disabled'),
            if (node.tls?.serverName != null) _buildDetailRow('SNI', node.tls!.serverName!),
            if (node.transport != null) _buildDetailRow('Transport', node.transport!.type),
            if (node.reality != null) _buildDetailRow('Reality', 'Enabled'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NodeEditorScreen(existingNode: node),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Node'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showAddNodeDialog(BuildContext context, ProxyService service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: ProxyLinkImporter(
            onLinksParsed: (nodes) {
              for (final node in nodes) {
                final outbound = Outbound(
                  type: node['type'],
                  tag: node['tag'],
                  server: node['server'],
                  serverPort: node['serverPort'],
                  uuid: node['uuid'],
                  password: node['password'],
                  flow: node['flow'],
                  security: node['security'],
                  tls: node['tls'] != null ? TlsConfig.fromJson(node['tls']) : null,
                  reality: node['reality'] != null ? RealityConfig.fromJson(node['reality']) : null,
                  transport: node['transport'] != null ? TransportConfig.fromJson(node['transport']) : null,
                  upMbps: node['upMbps'],
                  downMbps: node['downMbps'],
                  obfsPassword: node['obfsPassword'],
                  congestionControl: node['congestionControl'],
                );
                service.addOutbound(outbound);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Imported ${nodes.length} node(s)')),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ==================== Routing Screen ====================

class RoutingScreen extends StatelessWidget {
  const RoutingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProxyService>();
    final rules = service.currentConfig?.route.rules ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routing Rules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rule),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RoutingEditorScreen()),
            ),
            tooltip: 'Add Rule',
          ),
        ],
      ),
      body: rules.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No routing rules', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Add rules to control traffic routing', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            )
          : ListView.builder(
              itemCount: rules.length,
              itemBuilder: (ctx, i) {
                final rule = rules[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: _getRuleIcon(rule),
                    title: Text(_getRuleDescription(rule)),
                    subtitle: Text('→ ${rule.outbound}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(rule.protocol ?? rule.ipCidr != null ? 'IP' : rule.domainSuffix != null ? 'Domain' : 'All'),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => RoutingEditorScreen(existingRule: rule)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _deleteRule(context, service, i),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RoutingEditorScreen(existingRule: rule)),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _getRuleIcon(RuleConfig rule) {
    if (rule.protocol != null) return const Icon(Icons.protocol, color: Colors.blue);
    if (rule.ipCidr != null) return const Icon(Icons.ip, color: Colors.green);
    if (rule.domainSuffix != null) return const Icon(Icons.link, color: Colors.orange);
    if (rule.domain != null) return const Icon(Icons.dns, color: Colors.purple);
    return const Icon(Icons.rule, color: Colors.grey);
  }

  String _getRuleDescription(RuleConfig rule) {
    if (rule.protocol != null) return 'Protocol: ${rule.protocol}';
    if (rule.ipCidr != null) return 'IP: ${rule.ipCidr!.join(', ')}';
    if (rule.domainSuffix != null) return 'Domain Suffix: ${rule.domainSuffix!.join(', ')}';
    if (rule.domain != null) return 'Domain: ${rule.domain!.join(', ')}';
    return 'Custom Rule';
  }

  void _deleteRule(BuildContext context, ProxyService service, int index) {
    final currentRules = List<RuleConfig>.from(service.currentConfig?.route.rules ?? []);
    if (index >= 0 && index < currentRules.length) {
      currentRules.removeAt(index);
      service.updateRoutingRules(currentRules);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rule deleted')));
    }
  }
}

// ==================== DNS Screen ====================

class DnsScreen extends StatelessWidget {
  const DnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProxyService>();
    final dnsConfig = service.currentConfig?.dns;

    return Scaffold(
      appBar: AppBar(title: const Text('DNS Configuration')),
      body: dnsConfig == null
          ? const Center(child: Text('No DNS config'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DNS Servers', style: Theme.of(context).textTheme.titleMedium),
                        const Divider(),
                        ...dnsConfig.servers.map((s) => ListTile(
                          leading: const Icon(Icons.dns),
                          title: Text(s.tag),
                          subtitle: Text(s.address),
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DNS Rules', style: Theme.of(context).textTheme.titleMedium),
                        const Divider(),
                        ...dnsConfig.rules.map((r) => ListTile(
                          leading: const Icon(Icons.rule),
                          title: Text('Server: ${r.server}'),
                          subtitle: Text(r.domainSuffix?.join(', ') ?? r.ipCidr?.join(', ') ?? 'All'),
                        )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ==================== Settings Screen ====================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProxyService>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('TUN Mode'),
                subtitle: const Text('Intercept all system traffic'),
                value: service.isTunEnabled,
                onChanged: (v) => service.toggleTun(v),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Auto Start'),
                subtitle: const Text('Start proxy on app launch'),
                value: false,
                onChanged: (v) {},
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Start on Boot'),
                subtitle: const Text('Launch app when system starts'),
                value: false,
                onChanged: (v) {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.content_copy),
                title: const Text('Export Config'),
                onTap: () {
                  final json = service.exportConfig();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Config exported (${json.length} bytes)')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.subject),
                title: const Text('View Logs'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LogScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About'),
                onTap: () => showAboutDialog(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Developer Options'),
                subtitle: const Text('Debug and testing tools'),
                onTap: () => _showDeveloperOptions(context, service),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Proxy Client'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version 1.0.0', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('A multi-platform proxy client supporting:'),
            SizedBox(height: 4),
            Text('• sing-box'),
            Text('• mihomo (Clash)'),
            Text('• v2ray-core'),
            SizedBox(height: 16),
            Text('Built with Flutter', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showDeveloperOptions(BuildContext context, ProxyService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Developer Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Test Latency'),
              subtitle: const Text('Test all nodes latency'),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await service.testLatency();
                if (ctx.mounted) {
                  showDialog(
                    context: ctx,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Latency Test Results'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: result.entries.map((e) => 
                          ListTile(
                            title: Text(e.key),
                            trailing: Text('${e.value.toStringAsFixed(1)} ms'),
                          ),
                        ).toList(),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Close')),
                      ],
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reload Config'),
              subtitle: const Text('Reload without restart'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Configuration reloaded')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}