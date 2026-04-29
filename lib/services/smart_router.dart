// 智能路由服务
// 基于历史连接数据（延迟、速度、稳定性）对节点进行评分
// 自动选择最优节点，实现无需手动切换的智能代理

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/config.dart';

/// 节点评分数据模型
///
/// 记录单个节点的历史连接统计和综合评分
class NodeScore {
  /// 节点唯一标识
  final String nodeId;

  /// 成功连接次数
  final int successfulConnects;

  /// 失败连接次数
  final int failedConnects;

  /// 平均延迟（毫秒），使用指数移动平均计算
  final double avgLatencyMs;

  /// 平均下载速度（字节/秒），使用指数移动平均计算
  final double avgDownloadSpeed;

  /// 最后使用时间
  final DateTime lastUsed;

  /// 综合评分（0~100），由 _calculateScore 计算
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

  /// 连接稳定性比率（0.0~1.0）
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

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
        'node_id': nodeId,
        'successful_connects': successfulConnects,
        'failed_connects': failedConnects,
        'avg_latency_ms': avgLatencyMs,
        'avg_download_speed': avgDownloadSpeed,
        'last_used': lastUsed.toIso8601String(),
        'score': score,
      };

  /// 从 JSON 反序列化
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

/// 智能路由服务 — 基于历史数据自动选择最优节点
///
/// 评分算法：
/// - 稳定性分（0~40）：成功连接数 / 总连接数 × 40
/// - 延迟分（0~20）：延迟越低分越高，max(0, 20 - avgLatency/50)
/// - 速度分（0~30）：速度越快分越高，min(30, speed/MB × 3)
/// - 总分 = 稳定性分 + 延迟分 + 速度分（0~90）
///
/// 选路策略：
/// - 历史评分权重 60% + 实时延迟评分权重 40%
/// - 无历史数据时默认评分 25.0
class SmartRouter extends ChangeNotifier {
  /// 节点评分映射，键为节点 ID
  final Map<String, NodeScore> _scores = {};

  /// 历史记录最大保留数量
  static const int _maxHistory = 100;

  /// 节点评分映射（不可变）
  Map<String, NodeScore> get scores => Map.unmodifiable(_scores);

  /// 记录节点连接结果
  ///
  /// [success] 连接是否成功
  /// 新节点初始评分：成功 50.0，失败 0.0
  /// 已有节点更新连接计数并重新计算评分
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

  /// 记录节点延迟数据
  ///
  /// 使用指数移动平均（α=0.3）更新平均延迟
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

  /// 记录节点下载速度数据
  ///
  /// 使用指数移动平均（α=0.3）更新平均速度
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

  /// 计算节点综合评分
  ///
  /// 评分公式：
  /// - 稳定性分 = successConnects / total × 40（最高40分）
  /// - 延迟分 = max(0, 20 - avgLatency / 50)（最高20分）
  /// - 速度分 = min(30, avgSpeed / 1MB × 3)（最高30分）
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

  /// 智能选择最优节点
  ///
  /// 综合评分 = 历史评分 × 0.6 + 实时延迟评分 × 0.4
  /// 实时延迟评分 = max(0, 50 - latencyMs / 2)
  /// 无延迟数据时默认 25.0 分
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

  /// 获取节点排名列表
  ///
  /// 返回按评分降序排列的 (节点, 评分) 列表
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

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
        'scores': _scores.map((k, v) => MapEntry(k, v.toJson())),
      };

  /// 从 JSON 反序列化
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
