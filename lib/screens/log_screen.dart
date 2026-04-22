import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/proxy_service.dart';

/// Log viewer screen for displaying proxy logs
class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final List<LogEntry> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  LogLevel _filterLevel = LogLevel.debug;

  @override
  void initState() {
    super.initState();
    _simulateLogs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _simulateLogs() {
    // Simulate receiving logs
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _logs.add(LogEntry(
            level: LogLevel.info,
            message: 'Proxy service initialized',
            timestamp: DateTime.now(),
          ));
        });
      }
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _logs.add(LogEntry(
            level: LogLevel.info,
            message: 'Listening on 127.0.0.1:2080 (mixed)',
            timestamp: DateTime.now(),
          ));
          _logs.add(LogEntry(
            level: LogLevel.info,
            message: 'Listening on 127.0.0.1:2081 (socks)',
            timestamp: DateTime.now(),
          ));
        });
      }
    });
  }

  void _addLog(LogLevel level, String message) {
    setState(() {
      _logs.add(LogEntry(level: level, message: message, timestamp: DateTime.now()));
      // Keep only last 1000 logs
      if (_logs.length > 1000) {
        _logs.removeAt(0);
      }
    });

    if (_autoScroll && _scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  void _exportLogs() {
    final content = _logs.map((e) => e.toString()).join('\n');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${_logs.length} log entries')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final proxyService = context.watch<ProxyService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_bottom_outlined),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
            tooltip: 'Auto-scroll',
          ),
          PopupMenuButton<LogLevel>(
            onSelected: (level) => setState(() => _filterLevel = level),
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: LogLevel.debug, child: Text('Debug')),
              const PopupMenuItem(value: LogLevel.info, child: Text('Info')),
              const PopupMenuItem(value: LogLevel.warning, child: Text('Warning')),
              const PopupMenuItem(value: LogLevel.error, child: Text('Error')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _exportLogs,
            tooltip: 'Export logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  proxyService.isRunning ? Icons.circle : Icons.circle_outlined,
                  size: 12,
                  color: proxyService.isRunning ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_logs.length} entries',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (!proxyService.isRunning)
                  Text(
                    'Proxy not running',
                    style: TextStyle(color: Colors.orange[700], fontSize: 12),
                  ),
              ],
            ),
          ),
          // Log list
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.subject_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No logs yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the proxy to see logs',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _logs.where((log) => log.level.index >= _filterLevel.index).length,
                    itemBuilder: (ctx, i) {
                      final filteredLogs = _logs.where((log) => log.level.index >= _filterLevel.index).toList();
                      final log = filteredLogs[i];
                      return _buildLogTile(log);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          // Manual log test
          _addLog(LogLevel.debug, 'Test log entry at ${DateTime.now()}');
        },
        child: const Icon(Icons.bug_report),
      ),
    );
  }

  Widget _buildLogTile(LogEntry log) {
    Color levelColor;
    IconData levelIcon;

    switch (log.level) {
      case LogLevel.debug:
        levelColor = Colors.grey;
        levelIcon = Icons.bug_report;
        break;
      case LogLevel.info:
        levelColor = Colors.blue;
        levelIcon = Icons.info;
        break;
      case LogLevel.warning:
        levelColor = Colors.orange;
        levelIcon = Icons.warning;
        break;
      case LogLevel.error:
        levelColor = Colors.red;
        levelIcon = Icons.error;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(levelIcon, size: 16, color: levelColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.message,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                Text(
                  _formatTime(log.timestamp),
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}.${time.millisecond.toString().padLeft(3, '0')}';
  }
}

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final LogLevel level;
  final String message;
  final DateTime timestamp;

  LogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
  });

  @override
  String toString() {
    return '[${timestamp.toIso8601String()}] [${level.name.toUpperCase()}] $message';
  }
}
