import 'dart:collection';

import '../models.dart';

class PathResult {
  final List<Node> path;
  final double distance;

  const PathResult({required this.path, required this.distance});
}

class _QueueItem {
  final String nodeId;
  final double dist;
  const _QueueItem(this.nodeId, this.dist);
}

PathResult? shortestPath({
  required Mall mall,
  required String startNodeId,
  required String endNodeId,
}) {
  // Build adjacency list
  final adj = <String, List<Edge>>{};
  for (final e in mall.edges) {
    adj.putIfAbsent(e.fromId, () => []).add(e);
    // assume undirected corridors for mall walking
    adj.putIfAbsent(e.toId, () => []).add(Edge(fromId: e.toId, toId: e.fromId, distance: e.distance));
  }

  final dist = <String, double>{};
  final prev = <String, String?>{};
  for (final id in mall.nodes.keys) {
    dist[id] = double.infinity;
    prev[id] = null;
  }
  dist[startNodeId] = 0;

  // Simple priority queue using SplayTreeSet keyed by distance+nodeId
  final queue = SplayTreeSet<_QueueItem>(
    (a, b) => a.dist == b.dist ? a.nodeId.compareTo(b.nodeId) : a.dist.compareTo(b.dist),
  );
  queue.add(_QueueItem(startNodeId, 0));

  while (queue.isNotEmpty) {
    final current = queue.first;
    queue.remove(current);
    if (current.nodeId == endNodeId) break;
    final neighbors = adj[current.nodeId] ?? const [];
    for (final e in neighbors) {
      final alt = dist[current.nodeId]! + e.distance;
      if (alt < dist[e.toId]!) {
        // update priority queue
        queue.removeWhere((q) => q.nodeId == e.toId);
        dist[e.toId] = alt;
        prev[e.toId] = current.nodeId;
        queue.add(_QueueItem(e.toId, alt));
      }
    }
  }

  if (dist[endNodeId] == double.infinity) return null;

  // Reconstruct path (backwards from end -> start)
  final backtrack = <Node>[];
  String? cur = endNodeId;
  while (cur != null) {
    final node = mall.nodes[cur];
    if (node == null) break;
    backtrack.add(node);
    cur = prev[cur];
  }
  final ordered = backtrack.reversed.toList();
  return PathResult(path: ordered, distance: dist[endNodeId]!);
}

class EntranceRecommendation {
  final Node entrance;
  final PathResult path;
  const EntranceRecommendation({required this.entrance, required this.path});
}

EntranceRecommendation? bestEntranceToStore(Mall mall, String storeNodeId) {
  EntranceRecommendation? best;
  for (final entrance in mall.entrances) {
    final pr = shortestPath(mall: mall, startNodeId: entrance.id, endNodeId: storeNodeId);
    if (pr == null) continue;
    if (best == null || pr.distance < best.path.distance) {
      best = EntranceRecommendation(entrance: entrance, path: pr);
    }
  }
  return best;
}
