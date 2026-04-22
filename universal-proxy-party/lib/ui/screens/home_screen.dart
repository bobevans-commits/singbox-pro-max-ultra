import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_proxy_party/core/managers/kernel_manager.dart';
import 'package:universal_proxy_party/core/models/kernel_config.dart';
import 'package:universal_proxy_party/ui/widgets/kernel_status_card.dart';
import 'package:universal_proxy_party/ui/widgets/traffic_stats_card.dart';
import 'package:universal_proxy_party/ui/widgets/kernel_selector.dart';

/// Main home screen of the application
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Navigation Rail
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.dns_outlined),
                selectedIcon: Icon(Icons.dns),
                label: Text('Proxies'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          
          const VerticalDivider(thickness: 1, width: 1),
          
          // Main content area
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                _DashboardTab(),
                _ProxiesTab(),
                _SettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashboard tab showing kernel status and traffic stats
class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Monitor and control your proxy kernels',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 32),
          
          // Kernel Status Card
          const KernelStatusCard(),
          const SizedBox(height: 24),
          
          // Traffic Stats Card
          const TrafficStatsCard(),
          const SizedBox(height: 24),
          
          // Quick Actions
          _buildQuickActions(context),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement start action
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement stop action
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement restart action
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Restart'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Implement health check
                  },
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text('Health Check'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Proxies tab placeholder
class _ProxiesTab extends StatelessWidget {
  const _ProxiesTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Proxy Management',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }
}

/// Settings tab placeholder
class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.settings_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }
}
