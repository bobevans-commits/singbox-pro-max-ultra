import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/proxy_service.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final ScrollController _scrollController = ScrollController();
  LogLevel _filterLevel = LogLevel.all;
  StreamSubscription<String>? _logSubscription;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    final proxyService = context.read<ProxyService>();
    _logSubscription = proxyService.logStream.listen((_) {
      if (_autoScroll && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _filterLogs(List<String> logs) {
    if (_filterLevel == LogLevel.all) return logs;
    return logs.where((log) {
      switch (_filterLevel) {
        case LogLevel.error:
          return log.contains('[ERROR]');
        case LogLevel.warning:
          return log.contains('[WARN]');
        case LogLevel.info:
          return log.contains('[INFO]');
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final proxyService = context.watch<ProxyService>();
    final theme = Theme.of(context);
    final filteredLogs = _filterLogs(proxyService.logs);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar.large(
            title: const Text('日志'),
            actions: [
              PopupMenuButton<LogLevel>(
                icon: const Icon(Icons.filter_list),
                onSelected: (level) {
                  setState(() => _filterLevel = level);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: LogLevel.all, child: Text('全部')),
                  const PopupMenuItem(value: LogLevel.info, child: Text('Info')),
                  const PopupMenuItem(
                      value: LogLevel.warning, child: Text('Warning')),
                  const PopupMenuItem(value: LogLevel.error, child: Text('Error')),
                ],
              ),
              IconButton(
                onPressed: () {
                  proxyService.clearLogs();
                },
                icon: const Icon(Icons.delete_sweep),
                tooltip: '清空日志',
              ),
              IconButton(
                onPressed: () {
                  final logs = proxyService.logs.join('\n');
                  Share.share(logs);
                },
                icon: const Icon(Icons.share),
                tooltip: '导出日志',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '自动滚动',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Switch(
                    value: _autoScroll,
                    onChanged: (v) => setState(() => _autoScroll = v),
                  ),
                  const Spacer(),
                  Text(
                    '${filteredLogs.length} 条日志',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= filteredLogs.length) return null;

                final log = filteredLogs[index];
                final isError = log.contains('[ERROR]');
                final isWarning = log.contains('[WARN]');

                return ListTile(
                  dense: true,
                  leading: Icon(
                    isError
                        ? Icons.error
                        : isWarning
                            ? Icons.warning
                            : Icons.info,
                    size: 16,
                    color: isError
                        ? Colors.red
                        : isWarning
                            ? Colors.orange
                            : theme.colorScheme.outline,
                  ),
                  title: Text(
                    log,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: isError
                          ? Colors.red
                          : isWarning
                              ? Colors.orange
                              : null,
                    ),
                  ),
                );
              },
              childCount: filteredLogs.length,
            ),
          ),
        ],
      ),
    );
  }
}

enum LogLevel { all, info, warning, error }
