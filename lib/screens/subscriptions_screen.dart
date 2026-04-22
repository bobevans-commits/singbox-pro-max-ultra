import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import '../services/proxy_service.dart';

/// Subscription management screen
class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SubscriptionService(),
      child: const _SubscriptionsContent(),
    );
  }
}

class _SubscriptionsContent extends StatelessWidget {
  const _SubscriptionsContent();

  @override
  Widget build(BuildContext context) {
    final subscriptionService = context.watch<SubscriptionService>();
    final proxyService = context.watch<ProxyService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: subscriptionService.isUpdating
                ? null
                : () => subscriptionService.updateAllSubscriptions(),
            tooltip: 'Update All',
          ),
        ],
      ),
      body: subscriptionService.subscriptions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No subscriptions yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a subscription URL to get started',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => subscriptionService.updateAllSubscriptions(),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: subscriptionService.subscriptions.length,
                itemBuilder: (ctx, i) {
                  final sub = subscriptionService.subscriptions[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: sub.autoUpdate ? Colors.green[100] : Colors.grey[200],
                        child: Icon(
                          Icons.cloud,
                          color: sub.autoUpdate ? Colors.green : Colors.grey,
                        ),
                      ),
                      title: Text(sub.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            sub.url,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Chip(
                                label: Text('${sub.nodeCount} nodes'),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              if (sub.lastUpdated != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'Updated: ${_formatLastUpdated(sub.lastUpdated!)}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                              if (sub.autoUpdate) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.autorenew, size: 14, color: Colors.green[700]),
                              ],
                            ],
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) => _handleMenuAction(context, subscriptionService, proxyService, sub, value),
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'update', child: ListTile(leading: Icon(Icons.refresh), title: Text('Update'))),
                          const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'))),
                          const PopupMenuItem(value: 'toggle_auto', child: ListTile(leading: Icon(Icons.autorenew), title: Text('Toggle Auto-update'))),
                          const PopupMenuItem(value: 'import', child: ListTile(leading: Icon(Icons.download), title: Text('Import Nodes'))),
                          const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)))),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSubscriptionDialog(context, subscriptionService),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    SubscriptionService subscriptionService,
    ProxyService proxyService,
    Subscription sub,
    String action,
  ) async {
    switch (action) {
      case 'update':
        await subscriptionService.updateSubscription(sub.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Updated ${sub.name}')),
          );
        }
        break;
      case 'edit':
        _showEditSubscriptionDialog(context, subscriptionService, sub);
        break;
      case 'toggle_auto':
        subscriptionService.updateSubscriptionInfo(sub.id, autoUpdate: !sub.autoUpdate);
        break;
      case 'import':
        await _importSubscriptionNodes(context, subscriptionService, proxyService, sub);
        break;
      case 'delete':
        _showDeleteConfirmation(context, subscriptionService, sub);
        break;
    }
  }

  Future<void> _importSubscriptionNodes(
    BuildContext context,
    SubscriptionService subscriptionService,
    ProxyService proxyService,
    Subscription sub,
  ) async {
    try {
      // In a real app, we would fetch and parse the subscription here
      // For now, we'll just show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Importing nodes from subscription...')),
      );
      
      // Simulate import
      await Future.delayed(const Duration(seconds: 1));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${sub.nodeCount} nodes from ${sub.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    SubscriptionService subscriptionService,
    Subscription sub,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subscription'),
        content: Text('Are you sure you want to delete "${sub.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              subscriptionService.removeSubscription(sub.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('Deleted ${sub.name}')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddSubscriptionDialog(BuildContext context, SubscriptionService service) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    bool autoUpdate = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Subscription'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'My Subscription',
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Subscription URL',
                    hintText: 'https://example.com/sub',
                    prefixIcon: Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Auto Update'),
                  subtitle: const Text('Automatically update this subscription'),
                  value: autoUpdate,
                  onChanged: (v) => setDialogState(() => autoUpdate = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || urlController.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please fill in all fields')),
                  );
                  return;
                }

                try {
                  await service.addSubscription(
                    name: nameController.text,
                    url: urlController.text,
                    autoUpdate: autoUpdate,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Added ${nameController.text}')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSubscriptionDialog(
    BuildContext context,
    SubscriptionService service,
    Subscription sub,
  ) {
    final nameController = TextEditingController(text: sub.name);
    final urlController = TextEditingController(text: sub.url);
    bool autoUpdate = sub.autoUpdate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Subscription'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL',
                    prefixIcon: Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Auto Update'),
                  value: autoUpdate,
                  onChanged: (v) => setDialogState(() => autoUpdate = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                service.updateSubscriptionInfo(
                  sub.id,
                  name: nameController.text,
                  url: urlController.text,
                  autoUpdate: autoUpdate,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Subscription updated')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatLastUpdated(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${date.day}/${date.month}/${date.year}';
  }
}
