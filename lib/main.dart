// ProxCore 应用入口
// 多内核代理客户端，支持 sing-box / mihomo / v2ray
// 初始化所有服务并通过 Provider 注入到 Widget 树

import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/config.dart';
import 'screens/home_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'screens/node_editor_screen.dart';
import 'screens/routing_editor_screen.dart';
import 'screens/log_screen.dart';
import 'screens/settings_screen.dart';
import 'services/clash_api_service.dart';
import 'services/config_storage_service.dart';
import 'services/geo_data_service.dart';
import 'services/kernel_manager.dart';
import 'services/proxy_service.dart';
import 'services/smart_router.dart';
import 'services/subscription_service.dart';
import 'services/tray_service.dart';
import 'services/webdav_sync_service.dart';
import 'utils/app_utils.dart';
import 'widgets/glass_theme.dart';
import 'widgets/proxy_link_importer.dart';

/// 应用入口函数
///
/// 初始化流程：
/// 1. 初始化 Flutter 绑定
/// 2. 初始化配置存储服务
/// 3. 初始化内核管理器（检测已安装内核）
/// 4. 初始化代理服务（加载配置和节点）
/// 5. 初始化订阅服务（加载订阅列表，配置自动刷新）
/// 6. 初始化 Clash API、智能路由、GeoIP/GeoSite、WebDAV 同步
/// 7. 注入依赖到 ProxyService
/// 8. 初始化系统托盘（桌面平台）
/// 9. 启动应用（MultiProvider + MyApp）
/// 10. 配置窗口（bitsdojo_window：大小、最小尺寸、居中、标题）
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

  final clashApi = ClashApiService();
  final smartRouter = SmartRouter();
  final geoDataService = GeoDataService();
  await geoDataService.init();
  final webdavService = WebDavSyncService();

  proxyService.setClashApi(clashApi);
  proxyService.setSmartRouter(smartRouter);

  TrayService? trayService;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    trayService = TrayService(proxyService);
    await trayService.init();
    proxyService.addListener(() => trayService?.update());
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: kernelManager),
        ChangeNotifierProvider.value(value: proxyService),
        ChangeNotifierProvider.value(value: subscriptionService),
        ChangeNotifierProvider.value(value: clashApi),
        ChangeNotifierProvider.value(value: smartRouter),
        ChangeNotifierProvider.value(value: geoDataService),
        ChangeNotifierProvider.value(value: webdavService),
      ],
      child: const MyApp(),
    ),
  );

  doWhenWindowReady(() {
    const initialSize = Size(960, 680);
    const minSize = Size(480, 400);
    appWindow.minSize = minSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = 'ProxCore';
    appWindow.show();
  });
}

/// 应用根组件
///
/// 管理主题模式（亮色/暗色），提供全局主题切换方法
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  /// 切换主题模式的静态方法
  ///
  /// 通过 findAncestorStateOfType 查找 _MyAppState 并调用 toggleTheme
  static void toggleThemeOf(BuildContext context) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?.toggleTheme();
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

/// MyApp 状态管理
///
/// 管理当前主题模式，默认跟随系统
class _MyAppState extends State<MyApp> {
  /// 当前主题模式
  ThemeMode _themeMode = ThemeMode.system;

  /// 获取当前主题模式
  ThemeMode get themeMode => _themeMode;

  /// 设置主题模式
  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  /// 切换亮色/暗色主题
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
      theme: GlassTheme.lightTheme,
      darkTheme: GlassTheme.darkTheme,
      themeMode: _themeMode,
      home: const MainNavigation(),
    );
  }
}

/// 自定义标题栏组件
///
/// 使用 bitsdojo_window 实现无边框窗口的自定义标题栏
/// 包含：可拖动区域、窗口标题、最小化/最大化/关闭按钮
class _CustomTitleBar extends StatelessWidget {
  const _CustomTitleBar();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return WindowTitleBarBox(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0E27) : const Color(0xFFF0F2F5),
        ),
        child: Row(
          children: [
            Expanded(
              child: MoveWindow(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    'ProxCore',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
              ),
            ),
            MinimizeWindowButton(
              colors: WindowButtonColors(
                iconNormal: isDark ? Colors.white54 : Colors.black45,
                mouseOver: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            MaximizeWindowButton(
              colors: WindowButtonColors(
                iconNormal: isDark ? Colors.white54 : Colors.black45,
                mouseOver: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            CloseWindowButton(
              colors: WindowButtonColors(
                iconNormal: isDark ? Colors.white54 : Colors.black45,
                mouseOver: Colors.red.shade400,
                mouseDown: Colors.red.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 主导航组件
///
/// 底部导航栏 + 侧边抽屉 + 浮动添加按钮
/// 四个页面：仪表板、订阅、日志、设置
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

/// MainNavigation 状态管理
class _MainNavigationState extends State<MainNavigation> {
  /// 当前选中的导航索引
  int _currentIndex = 0;

  /// 四个主页面
  final _screens = const [
    HomeScreen(),
    SubscriptionsScreen(),
    LogScreen(),
    SettingsScreen(),
  ];

  /// 显示节点列表底部弹窗
  ///
  /// 使用 DraggableScrollableSheet 实现可拖拽高度的节点列表
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

  /// 显示添加节点选项底部弹窗
  ///
  /// 三种添加方式：手动添加、导入链接、从订阅导入
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
      body: Column(
        children: [
          if (Platform.isWindows) const _CustomTitleBar(),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
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

/// 应用侧边抽屉
///
/// 包含：节点列表入口、路由规则入口、主题切换、关于
class _AppDrawer extends StatelessWidget {
  /// 主题切换回调
  final VoidCallback onToggleTheme;

  /// 打开路由规则编辑器回调
  final VoidCallback onOpenRouting;

  /// 打开节点列表回调
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

/// 节点列表底部弹窗
///
/// 支持功能：
/// - 排序（默认/延迟升序/延迟降序/名称）
/// - 按协议筛选
/// - 按协议分组显示
/// - 批量选择和删除
/// - 全部测速
/// - 单节点连接/测速/编辑/删除
class _NodeListSheet extends StatefulWidget {
  /// 滚动控制器
  final ScrollController scrollController;

  /// 添加节点回调
  final VoidCallback onAdd;

  const _NodeListSheet({required this.scrollController, required this.onAdd});

  @override
  State<_NodeListSheet> createState() => _NodeListSheetState();
}

/// _NodeListSheet 状态管理
class _NodeListSheetState extends State<_NodeListSheet> {
  /// 当前排序模式
  _NodeSortMode _sortMode = _NodeSortMode.defaultOrder;

  /// 协议筛选，null 表示不筛选
  ProxyProtocol? _filterProtocol;

  /// 是否按协议分组显示
  bool _groupByProtocol = false;

  /// 是否处于批量选择模式
  bool _selectMode = false;

  /// 批量选中的节点 ID 集合
  final Set<String> _selectedIds = {};

  /// 应用排序和筛选
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

  /// 按协议分组
  Map<ProxyProtocol, List<NodeConfig>> _groupByProtocolFn(
    List<NodeConfig> nodes,
  ) {
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
              if (_selectMode) ...[
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedIds.length == allNodes.length) {
                        _selectedIds.clear();
                      } else {
                        _selectedIds.clear();
                        _selectedIds.addAll(allNodes.map((n) => n.id));
                      }
                    });
                  },
                  child: Text(
                    _selectedIds.length == allNodes.length ? '取消全选' : '全选',
                  ),
                ),
                IconButton(
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () {
                          final count = _selectedIds.length;
                          for (final id in _selectedIds) {
                            proxyService.deleteNode(id);
                          }
                          setState(() {
                            _selectedIds.clear();
                            _selectMode = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已删除 $count 个节点'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  icon: const Icon(Icons.delete, size: 20),
                  tooltip: '删除选中',
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectMode = false;
                      _selectedIds.clear();
                    });
                  },
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: '退出管理',
                ),
              ] else ...[
                IconButton(
                  onPressed: () {
                    setState(() => _selectMode = true);
                  },
                  icon: const Icon(Icons.checklist, size: 20),
                  tooltip: '批量管理',
                ),
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
                    const PopupMenuItem(
                      value: 'latency_asc',
                      child: Text('延迟升序'),
                    ),
                    const PopupMenuItem(
                      value: 'latency_desc',
                      child: Text('延迟降序'),
                    ),
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
                    _groupByProtocol
                        ? Icons.folder_open
                        : Icons.folder_outlined,
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

  /// 构建扁平列表
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

  /// 构建按协议分组列表
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

  /// 构建单个节点列表项
  ///
  /// 显示：协议图标、活跃指示器、节点名称、延迟标签、协议/地址信息
  /// 右键菜单：连接、测速、编辑、删除、筛选同协议
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
      selected: _selectMode && _selectedIds.contains(node.id),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectMode)
            Checkbox(
              value: _selectedIds.contains(node.id),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedIds.add(node.id);
                  } else {
                    _selectedIds.remove(node.id);
                  }
                });
              },
            ),
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      trailing: _selectMode
          ? null
          : PopupMenuButton(
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
      onTap: _selectMode
          ? () {
              setState(() {
                if (_selectedIds.contains(node.id)) {
                  _selectedIds.remove(node.id);
                } else {
                  _selectedIds.add(node.id);
                }
              });
            }
          : () => proxyService.start(node),
    );
  }
}

/// 节点排序模式
enum _NodeSortMode {
  /// 默认顺序
  defaultOrder,

  /// 延迟升序
  latencyAsc,

  /// 延迟降序
  latencyDesc,

  /// 名称升序
  nameAsc,
}
