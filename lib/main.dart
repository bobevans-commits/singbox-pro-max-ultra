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

  final proxyService = ProxyService(kernelManager);
  final subscriptionService = SubscriptionService(configStorage);

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
  final List<NodeConfig> _nodes = [];
  List<RoutingRule> _routingRules = [];
  ConfigStorageService? _storage;

  final _screens = const [
    HomeScreen(),
    SubscriptionsScreen(),
    LogScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final storage = ConfigStorageService();
    await storage.init();
    _storage = storage;
    setState(() {
      _nodes.addAll(storage.loadNodes());
      _routingRules = storage.loadRoutingRules();
    });
  }

  Future<void> _saveNodes() async {
    final storage = _storage ??= ConfigStorageService();
    if (!storage.isInitialized) await storage.init();
    await storage.saveNodes(_nodes);
  }

  Future<void> _saveRoutingRules() async {
    final storage = _storage ??= ConfigStorageService();
    if (!storage.isInitialized) await storage.init();
    await storage.saveRoutingRules(_routingRules);
  }

  void _addNode(NodeConfig node) {
    setState(() => _nodes.add(node));
    _saveNodes();
  }

  void _updateNode(NodeConfig node) {
    final index = _nodes.indexWhere((n) => n.id == node.id);
    if (index >= 0) {
      setState(() => _nodes[index] = node);
      _saveNodes();
    }
  }

  void _deleteNode(String id) {
    setState(() => _nodes.removeWhere((n) => n.id == id));
    _saveNodes();
  }

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
          nodes: _nodes,
          scrollController: controller,
          onAdd: () {
            Navigator.pop(ctx);
            _showAddNodeOptions();
          },
          onEdit: (node) {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    NodeEditorScreen(node: node, onSave: _updateNode),
              ),
            );
          },
          onDelete: _deleteNode,
          onConnect: (node) {
            Navigator.pop(ctx);
            context.read<ProxyService>().start(node);
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
                    builder: (_) => NodeEditorScreen(onSave: _addNode),
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
                  builder: (_) => ProxyLinkImporter(onImport: _addNode),
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
                rules: _routingRules,
                onSave: (rules) {
                  setState(() => _routingRules = rules);
                  _saveRoutingRules();
                },
              ),
            ),
          );
        },
        onOpenNodeList: _showNodeList,
        nodes: _nodes,
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
  final List<NodeConfig> nodes;

  const _AppDrawer({
    required this.onToggleTheme,
    required this.onOpenRouting,
    required this.onOpenNodeList,
    required this.nodes,
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
          title: Text('节点列表 (${nodes.length})'),
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
          title: const Text('路由规则'),
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

class _NodeListSheet extends StatelessWidget {
  final List<NodeConfig> nodes;
  final ScrollController scrollController;
  final VoidCallback onAdd;
  final void Function(NodeConfig) onEdit;
  final void Function(String) onDelete;
  final void Function(NodeConfig) onConnect;

  const _NodeListSheet({
    required this.nodes,
    required this.scrollController,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proxyService = context.watch<ProxyService>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('节点列表', style: theme.textTheme.titleLarge),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  proxyService.testAllLatency(nodes);
                },
                icon: const Icon(Icons.speed, size: 18),
                label: const Text('全部测速'),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加'),
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
                    ],
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  itemCount: nodes.length,
                  itemBuilder: (context, index) {
                    final node = nodes[index];
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
                          const PopupMenuItem(
                            value: 'connect',
                            child: Text('连接'),
                          ),
                          const PopupMenuItem(
                            value: 'latency',
                            child: Text('测速'),
                          ),
                          const PopupMenuItem(value: 'edit', child: Text('编辑')),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('删除'),
                          ),
                        ],
                        onSelected: (value) {
                          switch (value) {
                            case 'connect':
                              onConnect(node);
                            case 'latency':
                              proxyService.testLatency(node);
                            case 'edit':
                              onEdit(node);
                            case 'delete':
                              onDelete(node.id);
                          }
                        },
                      ),
                      onTap: () => onConnect(node),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
