import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_proxy_party/core/managers/kernel_manager.dart';
import 'package:universal_proxy_party/core/models/kernel_config.dart';

/// Widget displaying kernel selection and status
class KernelStatusCard extends StatelessWidget {
  const KernelStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<KernelManager>(
      builder: (context, kernelManager, child) {
        final isRunning = kernelManager.isRunning;
        final isInitializing = kernelManager.isInitializing;
        final activeConfig = kernelManager.activeConfig;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kernel Status',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _buildStatusIndicator(isRunning, isInitializing),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Kernel Selector
                KernelSelector(
                  selectedType: activeConfig?.type,
                  onChanged: (type) {
                    // TODO: Implement kernel type change
                  },
                ),
                const SizedBox(height: 20),
                
                // Status Information
                _buildStatusInfo(kernelManager),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIndicator(bool isRunning, bool isInitializing) {
    if (isInitializing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'Starting...',
            style: TextStyle(color: Colors.orange[700]),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isRunning ? Colors.green[100] : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isRunning ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isRunning ? 'Running' : 'Stopped',
            style: TextStyle(
              color: isRunning ? Colors.green[800] : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfo(KernelManager kernelManager) {
    final config = kernelManager.activeConfig;
    
    if (config == null) {
      return Column(
        children: [
          Icon(
            Icons.info_outline,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'No kernel selected',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a kernel type above to get started',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          label: 'Kernel Type',
          value: config.type.name,
        ),
        const SizedBox(height: 12),
        _InfoRow(
          label: 'Config Path',
          value: config.configPath,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        _InfoRow(
          label: 'API Port',
          value: '${config.apiPort}',
        ),
        if (config.logLevel != null) ...[
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Log Level',
            value: config.logLevel!,
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final int maxLines;

  const _InfoRow({
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
