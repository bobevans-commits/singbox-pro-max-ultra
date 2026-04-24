import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/config.dart';

class RoutingEditorScreen extends StatefulWidget {
  final List<RoutingRule> rules;
  final void Function(List<RoutingRule>) onSave;

  const RoutingEditorScreen({
    super.key,
    required this.rules,
    required this.onSave,
  });

  @override
  State<RoutingEditorScreen> createState() => _RoutingEditorScreenState();
}

class _RoutingEditorScreenState extends State<RoutingEditorScreen> {
  late List<RoutingRule> _rules;

  @override
  void initState() {
    super.initState();
    _rules = List.from(widget.rules);
  }

  void _addRule() {
    final rule = RoutingRule(
      id: const Uuid().v4(),
      name: '规则 ${_rules.length + 1}',
    );
    setState(() => _rules.add(rule));
  }

  void _removeRule(int index) {
    setState(() => _rules.removeAt(index));
  }

  void _toggleRule(int index) {
    setState(() {
      _rules[index] = _rules[index].copyWith(
        enabled: !_rules[index].enabled,
      );
    });
  }

  void _editRule(int index) {
    final rule = _rules[index];
    final nameController = TextEditingController(text: rule.name);
    final matchController = TextEditingController(text: rule.match);
    String type = rule.type;
    String target = rule.target;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('编辑规则'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: '匹配类型',
                    border: OutlineInputBorder(),
                  ),
                  items: RoutingRule.typeOptions
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v ?? 'domain'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: matchController,
                  decoration: const InputDecoration(
                    labelText: '匹配值',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: target,
                  decoration: const InputDecoration(
                    labelText: '目标',
                    border: OutlineInputBorder(),
                  ),
                  items: RoutingRule.targetOptions
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => target = v ?? 'proxy'),
                ),
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
                setState(() {
                  _rules[index] = _rules[index].copyWith(
                    name: nameController.text.trim(),
                    type: type,
                    match: matchController.text.trim(),
                    target: target,
                  );
                });
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    widget.onSave(_rules);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('路由规则'),
        actions: [
          FilledButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _rules.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.route,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无路由规则',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击 + 添加路由规则',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rules.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) newIndex--;
                  final item = _rules.removeAt(oldIndex);
                  _rules.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final rule = _rules[index];
                return Card(
                  key: ValueKey(rule.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Switch(
                      value: rule.enabled,
                      onChanged: (_) => _toggleRule(index),
                    ),
                    title: Text(rule.name),
                    subtitle: Text(
                      '${rule.type}: ${rule.match} → ${rule.target}',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _editRule(index),
                          icon: const Icon(Icons.edit, size: 20),
                        ),
                        IconButton(
                          onPressed: () => _removeRule(index),
                          icon: const Icon(Icons.delete, size: 20),
                          color: Colors.red,
                        ),
                      ],
                    ),
                    onTap: () => _editRule(index),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRule,
        child: const Icon(Icons.add),
      ),
    );
  }
}
