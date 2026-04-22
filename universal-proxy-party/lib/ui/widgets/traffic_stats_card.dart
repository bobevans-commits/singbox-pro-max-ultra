import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_proxy_party/core/managers/kernel_manager.dart';
import 'package:universal_proxy_party/core/models/kernel_stats.dart';

/// Widget displaying traffic statistics
class TrafficStatsCard extends StatelessWidget {
  const TrafficStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<KernelManager>(
      builder: (context, kernelManager, child) {
        final stats = kernelManager.currentStats;
        final isRunning = kernelManager.isRunning;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Traffic Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                if (!isRunning) ...[
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.show_chart,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No active connection',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a kernel to view traffic statistics',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  _buildStatsGrid(stats),
                  const SizedBox(height: 20),
                  _buildSpeedChart(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(KernelStats? stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.5,
      children: [
        _StatItem(
          label: 'Upload Speed',
          value: _formatBytes(stats?.uploadSpeed ?? 0),
          unit: '/s',
          icon: Icons.upload,
          color: Colors.blue,
        ),
        _StatItem(
          label: 'Download Speed',
          value: _formatBytes(stats?.downloadSpeed ?? 0),
          unit: '/s',
          icon: Icons.download,
          color: Colors.green,
        ),
        _StatItem(
          label: 'Total Upload',
          value: _formatBytes(stats?.totalUpload ?? 0),
          icon: Icons.cloud_upload,
          color: Colors.orange,
        ),
        _StatItem(
          label: 'Total Download',
          value: _formatBytes(stats?.totalDownload ?? 0),
          icon: Icons.cloud_download,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildSpeedChart() {
    // Placeholder for speed chart
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insights,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time speed chart',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Coming soon...',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes == 0) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double value = bytes.toDouble();
    
    while (value >= 1024 && i < suffixes.length - 1) {
      value /= 1024;
      i++;
    }
    
    return '${value.toStringAsFixed(value < 10 && i > 0 ? 1 : 0)} ${suffixes[i]}';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        unit!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
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
    );
  }
}
