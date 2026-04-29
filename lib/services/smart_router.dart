import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/config.dart';

class NodeScore {
  final String nodeId;
  final int successfulConnects;
  final int failedConnects;
  final double avgLatencyMs;
  final double avgDownloadSpeed;
  final DateTime lastUsed;
  final double score;

  const NodeScore({
    required this.nodeId,
    this.successfulConnects = 0,
    this.failedConnects = 0,
    this.avgLatencyMs = 0,
    this.avgDownloadSpeed = 0,
    required this.lastUsed,
    required this.score,
  });

  double get stability =>
      successfulConnects + failedConnects > 0
          ? successfulConnects / (successfulConnects + failedConnects)
          : 0;

  NodeScore copyWith({
    int? successfulConnects,
    int? failedConnects,
    double? avgLatencyMs,
    double? avgDownloadSpeed,
    DateTime? lastUsed,
    double? score,
  }) {
    return NodeScore(
      nodeId: nodeId,
      successfulConnects: successfulConnects ?? this.successfulConnects,
      failedConnects: failedConnects ?? this.failedConnects,
      avgLatencyMs: avgLatencyMs ?? this.avgLatencyMs,
      avgDownloadSpeed: avgDownloadSpeed ?? this.avgDownloadSpeed,
      lastUsed: lastUsed ?? this.lastUsed,
      score: score ?? this.score,
    );
  }

  Map<String, dynamic> toJson() => {
        'node_id': nodeId,
        'successful_connects': successfulConnects,
        'failed_connects': failedConnects,
        'avg_latency_ms': avgLatencyMs,
        'avg_download_speed': avgDownloadSpeed,
        'last_used': lastUsed.toIso8601String(),
        'score': score,
      };

  factory NodeScore.fromJson(Map<String, dynamic> json) => NodeScore(
        nodeId: json['node_id'] as String,
        successfulConnects: json['successful_connects'] as int? ?? 0,
        failedConnects: json['failed_connects'] as int? ?? 0,
        avgLatencyMs: (json['avg_latency_ms'] as num?)?.toDouble() ?? 0,
        avgDownloadSpeed: (json['avg_download_speed'] as num?)?.toDouble() ?? 0,
        lastUsed: DateTime.tryParse(json['last_used'] as String? ?? '') ?? DateTime.now(),
        score: (json['score'] as num?)?.toDouble() ?? 0,
      );
}

class SmartRouter extends ChangeNotifier {
  final Map<String, NodeScore> _scores = {};
  static const int _maxHistory = 100;

  Map<String, NodeScore> get scores => Map.unmodifiable(_scores);

  void recordConnect(NodeConfig node, {required bool success}) {
    final existing = _scores[node.id];
    if (existing == null) {
      _scores[node.id] = NodeScore(
        nodeId: node.id,
        successfulConnects: success ? 1 : 0,
        failedConnects: success ? 0 : 1,
        lastUsed: DateTime.now(),
        score: success ? 50.0 : 0.0,
      );
    } else {
      final newSuccess = existing.successfulConnects + (success ? 1 : 0);
      final newFail = existing.failedConnects + (success ? 0 : 1);
      _scores[node.id] = existing.copyWith(
        successfulConnects: min(newSuccess, _maxHistory),
        failedConnects: min(newFail, _maxHistory),
        lastUsed: DateTime.now(),
        score: _calculateScore(
          newSuccess,
          newFail,
          existing.avgLatencyMs,
          existing.avgDownloadSpeed,
        ),
      );
    }
    notifyListeners();
  }

  void recordLatency(NodeConfig node, int latencyMs) {
    final existing = _scores[node.id];
    if (existing == null) {
      _scores[node.id] = NodeScore(
        nodeId: node.id,
        avgLatencyMs: latencyMs.toDouble(),
        lastUsed: DateTime.now(),
        score: _calculateScore(1, 0, latencyMs.toDouble(), 0),
      );
    } else {
      final alpha = 0.3;
      final newAvg = existing.avgLatencyMs * (1 - alpha) + latencyMs * alpha;
      _scores[node.id] = existing.copyWith(
        avgLatencyMs: newAvg,
        score: _calculateScore(
          existing.successfulConnects,
          existing.failedConnects,
          newAvg,
          existing.avgDownloadSpeed,
        ),
      );
    }
    notifyListeners();
  }

  void recordSpeed(NodeConfig node, double bytesPerSec) {
    final existing = _scores[node.id];
    if (existing == null) {
      _scores[node.id] = NodeScore(
        nodeId: node.id,
        avgDownloadSpeed: bytesPerSec,
        lastUsed: DateTime.now(),
        score: _calculateScore(1, 0, 0, bytesPerSec),
      );
    } else {
      final alpha = 0.3;
      final newAvg = existing.avgDownloadSpeed * (1 - alpha) + bytesPerSec * alpha;
      _scores[node.id] = existing.copyWith(
        avgDownloadSpeed: newAvg,
        score: _calculateScore(
          existing.successfulConnects,
          existing.failedConnects,
          existing.avgLatencyMs,
          newAvg,
        ),
      );
    }
    notifyListeners();
  }

  double _calculateScore(
    int successConnects,
    int failedConnects,
    double avgLatency,
    double avgSpeed,
  ) {
    final total = successConnects + failedConnects;
    if (total == 0) return 50.0;

    final stabilityScore = successConnects / total * 40;

    final latencyScore = avgLatency <= 0
        ? 20.0
        : max(0, 20 - (avgLatency / 50));

    final speedScore = avgSpeed <= 0
        ? 10.0
        : min(30, (avgSpeed / 1024 / 1024) * 3);

    return stabilityScore + latencyScore + speedScore;
  }

  NodeConfig? pickBest(List<NodeConfig> nodes) {
    if (nodes.isEmpty) return null;

    final scored = nodes.map((node) {
      final s = _scores[node.id];
      final latencyScore = node.latencyMs != null && node.latencyMs! > 0
          ? max(0, 50 - node.latencyMs! / 2)
          : 25.0;
      final historyScore = s?.score ?? 25.0;
      return MapEntry(node, historyScore * 0.6 + latencyScore * 0.4);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return scored.first.key;
  }

  List<MapEntry<NodeConfig, NodeScore?>> getRankedNodes(List<NodeConfig> nodes) {
    final ranked = nodes.map((node) {
      return MapEntry(node, _scores[node.id]);
    }).toList()
      ..sort((a, b) {
        final sa = a.value?.score ?? 0;
        final sb = b.value?.score ?? 0;
        return sb.compareTo(sa);
      });
    return ranked;
  }

  Map<String, dynamic> toJson() => {
        'scores': _scores.map((k, v) => MapEntry(k, v.toJson())),
      };

  void loadFromJson(Map<String, dynamic> json) {
    final scoresData = json['scores'] as Map<String, dynamic>?;
    if (scoresData == null) return;
    _scores.clear();
    for (final entry in scoresData.entries) {
      _scores[entry.key] = NodeScore.fromJson(entry.value as Map<String, dynamic>);
    }
    notifyListeners();
  }
}
