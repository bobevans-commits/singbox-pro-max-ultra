import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/config.dart';
import 'screens/home_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'screens/node_editor_screen.dart';
import 'screens/routing_editor_screen.dart';
import 'screens/log_screen.dart';
import 'screens/settings_screen.dart';
import 'services/config_storage_service.dart';
import 'services/kernel_manager.dart';
import 'services/proxy_service.dart';
import 'services/subscription_service.dart';
import 'utils/app_utils.dart';
import 'widgets/proxy_link_importer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final configStorage = ConfigStorageService();
  await configStorage.init();

  final kernelManager = KernelManager();
  await kernelManager.init();

  final proxyService = ProxyService(kernelManager, configStorage);
  await proxyService.init();

  final subscriptionService = SubscriptionService(configStorage);
  await subscriptionService.init();
  subscriptionService.onNodesRefreshed = (nodes) async {
    proxyService.addNodes(nodes);
  };
  if (proxyService.config.subRefreshMinutes > 0) {
    subscriptionService.setupAutoRefresh(proxyService.config.subRefreshMinutes);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: kernelManager),
        ChangeNotifierProvider.value(value: proxyService),
        ChangeNotifierProvider.value(value: subscriptionService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void toggleThemeOf(BuildContext context) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?.toggleTheme();
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProxCore',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    SubscriptionsScreen(),
    LogScreen(),
    SettingsScreen(),
  ];

  void _showNodeList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, controller) => _NodeListSheet(
          scrollController: controller,
          onAdd: () {
            Navigator.pop(ctx);
            _showAddNodeOptions();
          },
        ),
      ),
    );
  }

  void _showAddNodeOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('手动添加'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NodeEditorScreen(
                      onSave: (node) {
                        context.read<ProxyService>().addNode(node);
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('导入链接'),
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ProxyLinkImporter(
                    onImport: (node) {
                      context.read<ProxyService>().addNode(node);
                    },
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.rss_feed),
              title: const Text('从订阅导入'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _currentIndex = 1);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final proxyService = context.watch<ProxyService>();

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: '仪表板',
          ),
          NavigationDestination(
            icon: Icon(Icons.rss_feed_outlined),
            selectedIcon: Icon(Icons.rss_feed),
            label: '订阅',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: '日志',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
      drawer: _AppDrawer(
        onToggleTheme: () => MyApp.toggleThemeOf(context),
        onOpenRouting: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoutingEditorScreen(
                rules: proxyService.routingRules,
                onSave: (rules) {
                  proxyService.updateRoutingRules(rules);
                },
              ),
            ),
          );
        },
        onOpenNodeList: _showNodeList,
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _showAddNodeOptions,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenRouting;
  final VoidCallback onOpenNodeList;

  const _AppDrawer({
    required this.onToggleTheme,
    required this.onOpenRouting,
    required this.onOpenNodeList,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proxyService = context.watch<ProxyService>();

    return NavigationDrawer(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 8),
          child: Text('ProxCore', style: theme.textTheme.titleMedium),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.list),
          title: Text('节点列表 (${proxyService.nodes.length})'),
          subtitle: proxyService.activeNode != null
              ? Text(
                  '当前: ${proxyService.activeNode!.name}',
                  style: const TextStyle(fontSize: 12),
                )
              : null,
          onTap: () {
            Navigator.pop(context);
            onOpenNodeList();
          },
        ),
        ListTile(
          leading: const Icon(Icons.route),
          title: Text('路由规则 (${proxyService.routingRules.length})'),
          onTap: () {
            Navigator.pop(context);
            onOpenRouting();
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.dark_mode),
          title: const Text('切换主题'),
          onTap: () {
            Navigator.pop(context);
            onToggleTheme();
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('关于'),
          onTap: () {
            Navigator.pop(context);
            showAboutDialog(
              context: context,
              applicationName: 'ProxCore',
              applicationVersion: '1.0.0',
              applicationIcon: const Icon(Icons.vpn_lock, size: 48),
              children: [
                const Text('多内核代理客户端'),
                const SizedBox(height: 8),
                const Text('支持 sing-box / mihomo / v2ray'),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _NodeListSheet extends StatefulWidget {
  final ScrollController scrollController;
  final VoidCallback onAdd;

  const _NodeListSheet({
    required this.scrollController,
    required this.onAdd,
  });

  @override
  State<_NodeListSheet> createState() => _NodeListSheetState();
}

class _NodeListSheetState extends State<_NodeListSheet> {
  _NodeSortMode _sortMode = _NodeSortMode.defaultOrder;
  ProxyProtocol? _filterProtocol;
  bool _groupByProtocol = false;

  List<NodeConfig> _applySortAndFilter(List<NodeConfig> nodes) {
    var filtered = _filterProtocol != null
        ? nodes.where((n) => n.protocol == _filterProtocol).toList()
        : nodes.toList();

    switch (_sortMode) {
      case _NodeSortMode.defaultOrder:
        break;
      case _NodeSortMode.latencyAsc:
        filtered.sort((a, b) {
          final la = a.latencyMs ?? 99999;
          final lb = b.latencyMs ?? 99999;
          return la.compareTo(lb);
        });
      case _NodeSortMode.latencyDesc:
        filtered.sort((a, b) {
          final la = a.latencyMs ?? -1;
          final lb = b.latencyMs ?? -1;
          return lb.compareTo(la);
        });
      case _NodeSortMode.nameAsc:
        filtered.sort((a, b) => a.name.compareTo(b.name));
    }

    return filtered;
  }

  Map<ProxyProtocol, List<NodeConfig>> _groupByProtocolFn(List<NodeConfig> nodes) {
    final map = <ProxyProtocol, List<NodeConfig>>{};
    for (final node in nodes) {
      (map[node.protocol] ??= []).add(node);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proxyService = context.watch<ProxyService>();
    final allNodes = proxyService.nodes;
    final nodes = _applySortAndFilter(allNodes);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('节点列表', style: theme.textTheme.titleLarge),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${allNodes.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  proxyService.testAllLatency(allNodes.toList());
                },
                icon: const Icon(Icons.speed, size: 20),
                tooltip: '全部测速',
              ),
              PopupMenuButton(
                icon: const Icon(Icons.sort, size: 20),
                tooltip: '排序',
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'default', child: Text('默认排序')),
                  const PopupMenuItem(value: 'latency_asc', child: Text('延迟升序')),
                  const PopupMenuItem(value: 'latency_desc', child: Text('延迟降序')),
                  const PopupMenuItem(value: 'name_asc', child: Text('名称排序')),
                ],
                onSelected: (value) {
                  setState(() {
                    switch (value) {
                      case 'default':
                        _sortMode = _NodeSortMode.defaultOrder;
                      case 'latency_asc':
                        _sortMode = _NodeSortMode.latencyAsc;
                      case 'latency_desc':
                        _sortMode = _NodeSortMode.latencyDesc;
                      case 'name_asc':
                        _sortMode = _NodeSortMode.nameAsc;
                    }
                  });
                },
              ),
              IconButton(
                onPressed: () {
                  setState(() => _groupByProtocol = !_groupByProtocol);
                },
                icon: Icon(
                  _groupByProtocol ? Icons.folder_open : Icons.folder_outlined,
                  size: 20,
                ),
                tooltip: '按协议分组',
              ),
              FilledButton.icon(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加'),
              ),
            ],
          ),
        ),
        if (_filterProtocol != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Chip(
                  label: Text(_filterProtocol!.label),
                  onDeleted: () => setState(() => _filterProtocol = null),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Text(
                  '${nodes.length} 个节点',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: nodes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无节点',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '添加订阅或手动导入节点',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              : _groupByProtocol
                  ? _buildGroupedList(context, nodes, proxyService, theme)
                  : _buildFlatList(context, nodes, proxyService, theme),
        ),
      ],
    );
  }

  Widget _buildFlatList(
    BuildContext context,
    List<NodeConfig> nodes,
    ProxyService proxyService,
    ThemeData theme,
  ) {
    return ListView.builder(
      controller: widget.scrollController,
      itemCount: nodes.length,
      itemBuilder: (context, index) =>
          _buildNodeTile(context, nodes[index], proxyService, theme),
    );
  }

  Widget _buildGroupedList(
    BuildContext context,
    List<NodeConfig> nodes,
    ProxyService proxyService,
    ThemeData theme,
  ) {
    final groups = _groupByProtocolFn(nodes);
    final protocols = groups.keys.toList();

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: protocols.length,
      itemBuilder: (context, index) {
        final protocol = protocols[index];
        final groupNodes = groups[protocol]!;
        return ExpansionTile(
          initiallyExpanded: true,
          leading: Text(
            AppUtils.protocolIcon(protocol),
            style: const TextStyle(fontSize: 18),
          ),
          title: Text(protocol.label),
          trailing: Text(
            '${groupNodes.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          children: groupNodes
              .map((node) => _buildNodeTile(context, node, proxyService, theme))
              .toList(),
        );
      },
    );
  }

  Widget _buildNodeTile(
    BuildContext context,
    NodeConfig node,
    ProxyService proxyService,
    ThemeData theme,
  ) {
    final isActive = proxyService.activeNode?.id == node.id;
    final latency = node.latencyMs;

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
      latencyText = '${latency}ms';
    }

    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppUtils.protocolIcon(node.protocol),
            style: const TextStyle(fontSize: 20),
          ),
          if (isActive) ...[
            const SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      title: Row(
        children: [
          Expanded(child: Text(node.name)),
          InkWell(
            onTap: () => proxyService.testLatency(node),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: latencyColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                latencyText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: latencyColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${node.protocol.label} | ${node.address}:${node.port}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: PopupMenuButton(
        itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'connect', child: Text('连接')),
          const PopupMenuItem(value: 'latency', child: Text('测速')),
          const PopupMenuItem(value: 'edit', child: Text('编辑')),
          const PopupMenuItem(value: 'delete', child: Text('删除')),
          const PopupMenuItem(value: 'filter', child: Text('筛选同协议')),
        ],
        onSelected: (value) {
          switch (value) {
            case 'connect':
              proxyService.start(node);
            case 'latency':
              proxyService.testLatency(node);
            case 'edit':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NodeEditorScreen(
                    node: node,
                    onSave: (n) => proxyService.updateNode(n),
                  ),
                ),
              );
            case 'delete':
              proxyService.deleteNode(node.id);
            case 'filter':
              setState(() => _filterProtocol = node.protocol);
          }
        },
      ),
      onTap: () => proxyService.start(node),
    );
  }
}

enum _NodeSortMode {
  defaultOrder,
  latencyAsc,
  latencyDesc,
  nameAsc,
}
