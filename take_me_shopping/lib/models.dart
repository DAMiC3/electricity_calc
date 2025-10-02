enum NodeType { entrance, junction, store }

class Node {
  final String id;
  final String name;
  final NodeType type;
  final double? lat; // optional GPS latitude
  final double? lon; // optional GPS longitude

  const Node({
    required this.id,
    required this.name,
    required this.type,
    this.lat,
    this.lon,
  });
}

class Edge {
  final String fromId;
  final String toId;
  final double distance; // in arbitrary units (e.g., 10s of meters)

  const Edge({required this.fromId, required this.toId, required this.distance});
}

class Store {
  final String name;
  final String nodeId; // node representing the store location

  const Store({required this.name, required this.nodeId});
}

class Mall {
  final String id;
  final String name;
  final Map<String, Node> nodes;
  final List<Edge> edges;
  final List<Store> stores;
  final double? centerLat;
  final double? centerLon;

  const Mall({
    required this.id,
    required this.name,
    required this.nodes,
    required this.edges,
    required this.stores,
    this.centerLat,
    this.centerLon,
  });

  List<Node> get entrances =>
      nodes.values.where((n) => n.type == NodeType.entrance).toList();
}

class Product {
  final String id;
  final String name;
  final String mallId;
  final String storeNodeId;
  final String storeName;
  final List<String> tags;
  final double priceZar;

  const Product({
    required this.id,
    required this.name,
    required this.mallId,
    required this.storeNodeId,
    required this.storeName,
    required this.tags,
    required this.priceZar,
  });
}
