import '../models.dart';

// Helper to build a small, lightweight corridor graph per mall.

Mall sandtonCity() {
  // Nodes
  final nodes = <String, Node>{
    // Entrances
    'E_A': const Node(id: 'E_A', name: 'Parking A (Alice Ln)', type: NodeType.entrance, lat: -26.1069, lon: 28.0587),
    'E_B': const Node(id: 'E_B', name: 'Parking B (Rivonia Rd)', type: NodeType.entrance, lat: -26.1069, lon: 28.0548),
    'E_C': const Node(id: 'E_C', name: 'Parking C (Maude St)', type: NodeType.entrance, lat: -26.1060, lon: 28.0567),

    // Junctions (simplified)
    'J1': const Node(id: 'J1', name: 'North Court', type: NodeType.junction),
    'J2': const Node(id: 'J2', name: 'Center Court', type: NodeType.junction),
    'J3': const Node(id: 'J3', name: 'South Court', type: NodeType.junction),

    // Stores (connect lightly to nearby junction)
    'S_WW': const Node(id: 'S_WW', name: 'Woolworths', type: NodeType.store),
    'S_DC': const Node(id: 'S_DC', name: 'Dis-Chem', type: NodeType.store),
    'S_IST': const Node(id: 'S_IST', name: 'iStore', type: NodeType.store),
    'S_HM': const Node(id: 'S_HM', name: 'H&M', type: NodeType.store),
    'S_ZARA': const Node(id: 'S_ZARA', name: 'ZARA', type: NodeType.store),
    'S_PNP': const Node(id: 'S_PNP', name: 'Pick n Pay', type: NodeType.store),
  };

  // Edges (bidirectional assumed in routing)
  final edges = <Edge>[
    // Entrances to corridors
    Edge(fromId: 'E_A', toId: 'J1', distance: 2.0),
    Edge(fromId: 'E_B', toId: 'J2', distance: 1.2),
    Edge(fromId: 'E_C', toId: 'J3', distance: 1.6),

    // Main spine
    Edge(fromId: 'J1', toId: 'J2', distance: 1.0),
    Edge(fromId: 'J2', toId: 'J3', distance: 1.0),

    // Store connectors (short spur)
    Edge(fromId: 'J1', toId: 'S_WW', distance: 0.1),
    Edge(fromId: 'J2', toId: 'S_IST', distance: 0.1),
    Edge(fromId: 'J2', toId: 'S_HM', distance: 0.1),
    Edge(fromId: 'J2', toId: 'S_ZARA', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_PNP', distance: 0.1),
    Edge(fromId: 'J3', toId: 'S_DC', distance: 0.1),
  ];

  final stores = <Store>[
    const Store(name: 'Woolworths', nodeId: 'S_WW'),
    const Store(name: 'Dis-Chem', nodeId: 'S_DC'),
    const Store(name: 'iStore', nodeId: 'S_IST'),
    const Store(name: 'H&M', nodeId: 'S_HM'),
    const Store(name: 'ZARA', nodeId: 'S_ZARA'),
    const Store(name: 'Pick n Pay', nodeId: 'S_PNP'),
  ];

  return Mall(
    id: 'sandton',
    name: 'Sandton City (JHB)',
    nodes: nodes,
    edges: edges,
    stores: stores,
    centerLat: -26.1076,
    centerLon: 28.0567,
  );
}

Mall mallOfAfrica() {
  final nodes = <String, Node>{
    'E_P1': const Node(id: 'E_P1', name: 'Parking P1 (Magwa Cres)', type: NodeType.entrance, lat: -26.0146, lon: 28.1113),
    'E_P2': const Node(id: 'E_P2', name: 'Parking P2 (Lone Creek)', type: NodeType.entrance, lat: -26.0160, lon: 28.1100),
    'E_P3': const Node(id: 'E_P3', name: 'Parking P3 (Waterfall Dr)', type: NodeType.entrance, lat: -26.0130, lon: 28.1080),

    'J1': const Node(id: 'J1', name: 'Crystal Court', type: NodeType.junction),
    'J2': const Node(id: 'J2', name: 'Food Court', type: NodeType.junction),
    'J3': const Node(id: 'J3', name: 'Town Square', type: NodeType.junction),

    'S_CHK': const Node(id: 'S_CHK', name: 'Checkers Hyper', type: NodeType.store),
    'S_GM': const Node(id: 'S_GM', name: 'Game', type: NodeType.store),
    'S_ZARA': const Node(id: 'S_ZARA', name: 'ZARA', type: NodeType.store),
    'S_CNA': const Node(id: 'S_CNA', name: 'CNA', type: NodeType.store),
    'S_WW': const Node(id: 'S_WW', name: 'Woolworths', type: NodeType.store),
    'S_DC': const Node(id: 'S_DC', name: 'Dis-Chem', type: NodeType.store),
  };

  final edges = <Edge>[
    Edge(fromId: 'E_P1', toId: 'J1', distance: 1.0),
    Edge(fromId: 'E_P2', toId: 'J2', distance: 1.3),
    Edge(fromId: 'E_P3', toId: 'J3', distance: 1.8),

    Edge(fromId: 'J1', toId: 'J2', distance: 0.9),
    Edge(fromId: 'J2', toId: 'J3', distance: 0.9),

    Edge(fromId: 'J2', toId: 'S_CHK', distance: 0.1),
    Edge(fromId: 'J3', toId: 'S_GM', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_ZARA', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_CNA', distance: 0.1),
    Edge(fromId: 'J2', toId: 'S_WW', distance: 0.1),
    Edge(fromId: 'J3', toId: 'S_DC', distance: 0.1),
  ];

  final stores = <Store>[
    const Store(name: 'Checkers Hyper', nodeId: 'S_CHK'),
    const Store(name: 'Game', nodeId: 'S_GM'),
    const Store(name: 'ZARA', nodeId: 'S_ZARA'),
    const Store(name: 'CNA', nodeId: 'S_CNA'),
    const Store(name: 'Woolworths', nodeId: 'S_WW'),
    const Store(name: 'Dis-Chem', nodeId: 'S_DC'),
  ];

  return Mall(
    id: 'moa',
    name: 'Mall of Africa (Midrand)',
    nodes: nodes,
    edges: edges,
    stores: stores,
    centerLat: -26.0145,
    centerLon: 28.1098,
  );
}

Mall canalWalk() {
  final nodes = <String, Node>{
    'E_EAST': const Node(id: 'E_EAST', name: 'East Entrance (Century Blvd)', type: NodeType.entrance, lat: -33.8929, lon: 18.5178),
    'E_WEST': const Node(id: 'E_WEST', name: 'West Entrance (Oasis)', type: NodeType.entrance, lat: -33.8937, lon: 18.5129),

    'J1': const Node(id: 'J1', name: 'East Atrium', type: NodeType.junction),
    'J2': const Node(id: 'J2', name: 'Centre Atrium', type: NodeType.junction),
    'J3': const Node(id: 'J3', name: 'West Atrium', type: NodeType.junction),

    'S_PNP': const Node(id: 'S_PNP', name: 'Pick n Pay', type: NodeType.store),
    'S_MTK': const Node(id: 'S_MTK', name: 'Mr Price Home', type: NodeType.store),
    'S_MTN': const Node(id: 'S_MTN', name: 'MTN', type: NodeType.store),
    'S_WW': const Node(id: 'S_WW', name: 'Woolworths', type: NodeType.store),
  };

  final edges = <Edge>[
    Edge(fromId: 'E_EAST', toId: 'J1', distance: 1.0),
    Edge(fromId: 'E_WEST', toId: 'J3', distance: 1.0),
    Edge(fromId: 'J1', toId: 'J2', distance: 1.1),
    Edge(fromId: 'J2', toId: 'J3', distance: 1.1),

    Edge(fromId: 'J1', toId: 'S_PNP', distance: 0.1),
    Edge(fromId: 'J2', toId: 'S_MTK', distance: 0.1),
    Edge(fromId: 'J3', toId: 'S_MTN', distance: 0.1),
    Edge(fromId: 'J2', toId: 'S_WW', distance: 0.1),
  ];

  final stores = <Store>[
    const Store(name: 'Pick n Pay', nodeId: 'S_PNP'),
    const Store(name: 'Mr Price Home', nodeId: 'S_MTK'),
    const Store(name: 'MTN', nodeId: 'S_MTN'),
    const Store(name: 'Woolworths', nodeId: 'S_WW'),
  ];

  return Mall(
    id: 'cw',
    name: 'Canal Walk (Cape Town)',
    nodes: nodes,
    edges: edges,
    stores: stores,
    centerLat: -33.8923,
    centerLon: 18.5139,
  );
}

final List<Mall> sampleMalls = [
  sandtonCity(),
  mallOfAfrica(),
  canalWalk(),
];

// Additional Gauteng malls (simplified graphs)
Mall menlynPark() {
  final nodes = <String, Node>{
    'E_N': const Node(id: 'E_N', name: 'North Entrance', type: NodeType.entrance, lat: -25.7769, lon: 28.2753),
    'E_S': const Node(id: 'E_S', name: 'South Entrance', type: NodeType.entrance, lat: -25.7793, lon: 28.2750),
    'J1': const Node(id: 'J1', name: 'Food Court', type: NodeType.junction),
    'J2': const Node(id: 'J2', name: 'Centre Court', type: NodeType.junction),
    'S_PNP': const Node(id: 'S_PNP', name: 'Pick n Pay', type: NodeType.store),
    'S_DIS': const Node(id: 'S_DIS', name: 'Dis-Chem', type: NodeType.store),
    'S_MR': const Node(id: 'S_MR', name: 'Mr Price', type: NodeType.store),
    'S_IST': const Node(id: 'S_IST', name: 'iStore', type: NodeType.store),
    'S_HM': const Node(id: 'S_HM', name: 'H&M', type: NodeType.store),
  };
  final edges = <Edge>[
    Edge(fromId: 'E_N', toId: 'J1', distance: 1.2),
    Edge(fromId: 'E_S', toId: 'J2', distance: 1.2),
    Edge(fromId: 'J1', toId: 'J2', distance: 0.8),
    Edge(fromId: 'J2', toId: 'S_PNP', distance: 0.1),
    Edge(fromId: 'J2', toId: 'S_MR', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_DIS', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_IST', distance: 0.1),
    Edge(fromId: 'J2', toId: 'S_HM', distance: 0.1),
  ];
  final stores = <Store>[
    const Store(name: 'Pick n Pay', nodeId: 'S_PNP'),
    const Store(name: 'Dis-Chem', nodeId: 'S_DIS'),
    const Store(name: 'Mr Price', nodeId: 'S_MR'),
    const Store(name: 'iStore', nodeId: 'S_IST'),
    const Store(name: 'H&M', nodeId: 'S_HM'),
  ];
  return Mall(
    id: 'menlyn',
    name: 'Menlyn Park (Pretoria)',
    nodes: nodes,
    edges: edges,
    stores: stores,
    centerLat: -25.7784,
    centerLon: 28.2750,
  );
}

Mall eastgate() {
  final nodes = <String, Node>{
    'E_E': const Node(id: 'E_E', name: 'East Entrance', type: NodeType.entrance, lat: -26.1770, lon: 28.1200),
    'E_W': const Node(id: 'E_W', name: 'West Entrance', type: NodeType.entrance, lat: -26.1777, lon: 28.1172),
    'J1': const Node(id: 'J1', name: 'Centre Court', type: NodeType.junction),
    'J2': const Node(id: 'J2', name: 'Fashion Court', type: NodeType.junction),
    'S_CNA': const Node(id: 'S_CNA', name: 'CNA', type: NodeType.store),
    'S_ZARA': const Node(id: 'S_ZARA', name: 'ZARA', type: NodeType.store),
    'S_WW': const Node(id: 'S_WW', name: 'Woolworths', type: NodeType.store),
    'S_PNP': const Node(id: 'S_PNP', name: 'Pick n Pay', type: NodeType.store),
  };
  final edges = <Edge>[
    Edge(fromId: 'E_E', toId: 'J1', distance: 1.1),
    Edge(fromId: 'E_W', toId: 'J2', distance: 1.0),
    Edge(fromId: 'J1', toId: 'J2', distance: 0.9),
    Edge(fromId: 'J1', toId: 'S_CNA', distance: 0.1),
    Edge(fromId: 'J2', toId: 'S_ZARA', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_WW', distance: 0.1),
    Edge(fromId: 'J2', toId: 'S_PNP', distance: 0.1),
  ];
  final stores = <Store>[
    const Store(name: 'CNA', nodeId: 'S_CNA'),
    const Store(name: 'ZARA', nodeId: 'S_ZARA'),
    const Store(name: 'Woolworths', nodeId: 'S_WW'),
    const Store(name: 'Pick n Pay', nodeId: 'S_PNP'),
  ];
  return Mall(
    id: 'eastgate',
    name: 'Eastgate Mall (Bedfordview)',
    nodes: nodes,
    edges: edges,
    stores: stores,
    centerLat: -26.1775,
    centerLon: 28.1185,
  );
}

Mall cresta() {
  final nodes = <String, Node>{
    'E_N': const Node(id: 'E_N', name: 'North Entrance', type: NodeType.entrance, lat: -26.1309, lon: 27.9723),
    'E_S': const Node(id: 'E_S', name: 'South Entrance', type: NodeType.entrance, lat: -26.1320, lon: 27.9721),
    'J1': const Node(id: 'J1', name: 'Centre Court', type: NodeType.junction),
    'S_HM': const Node(id: 'S_HM', name: 'H&M', type: NodeType.store),
    'S_WB': const Node(id: 'S_WB', name: 'Wimpy', type: NodeType.store),
    'S_PNP': const Node(id: 'S_PNP', name: 'Pick n Pay', type: NodeType.store),
    'S_DC': const Node(id: 'S_DC', name: 'Dis-Chem', type: NodeType.store),
  };
  final edges = <Edge>[
    Edge(fromId: 'E_N', toId: 'J1', distance: 1.0),
    Edge(fromId: 'E_S', toId: 'J1', distance: 0.9),
    Edge(fromId: 'J1', toId: 'S_HM', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_WB', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_PNP', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_DC', distance: 0.1),
  ];
  final stores = <Store>[
    const Store(name: 'H&M', nodeId: 'S_HM'),
    const Store(name: 'Wimpy', nodeId: 'S_WB'),
    const Store(name: 'Pick n Pay', nodeId: 'S_PNP'),
    const Store(name: 'Dis-Chem', nodeId: 'S_DC'),
  ];
  return Mall(
    id: 'cresta',
    name: 'Cresta (Randburg)',
    nodes: nodes,
    edges: edges,
    stores: stores,
    centerLat: -26.1315,
    centerLon: 27.9722,
  );
}

Mall rosebankMall() {
  final nodes = <String, Node>{
    'E_Ox': const Node(id: 'E_Ox', name: 'Oxford Rd Entrance', type: NodeType.entrance, lat: -26.1463, lon: 28.0405),
    'E_Tyr': const Node(id: 'E_Tyr', name: 'Tyrwhitt Ave Entrance', type: NodeType.entrance, lat: -26.1470, lon: 28.0423),
    'J1': const Node(id: 'J1', name: 'Piazza', type: NodeType.junction),
    'S_IS': const Node(id: 'S_IS', name: 'iStore', type: NodeType.store),
    'S_PEP': const Node(id: 'S_PEP', name: 'PEP', type: NodeType.store),
    'S_CLK': const Node(id: 'S_CLK', name: 'Clicks', type: NodeType.store),
    'S_WW': const Node(id: 'S_WW', name: 'Woolworths', type: NodeType.store),
  };
  final edges = <Edge>[
    Edge(fromId: 'E_Ox', toId: 'J1', distance: 0.8),
    Edge(fromId: 'E_Tyr', toId: 'J1', distance: 0.8),
    Edge(fromId: 'J1', toId: 'S_IS', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_PEP', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_CLK', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_WW', distance: 0.1),
  ];
  final stores = <Store>[
    const Store(name: 'iStore', nodeId: 'S_IS'),
    const Store(name: 'PEP', nodeId: 'S_PEP'),
    const Store(name: 'Clicks', nodeId: 'S_CLK'),
    const Store(name: 'Woolworths', nodeId: 'S_WW'),
  ];
  return Mall(
    id: 'rosebank',
    name: 'Rosebank Mall (JHB)',
    nodes: nodes,
    edges: edges,
    stores: stores,
    centerLat: -26.1462,
    centerLon: 28.0416,
  );
}

Mall fourwaysMall() {
  final nodes = <String, Node>{
    'E_N': const Node(id: 'E_N', name: 'North Entrance', type: NodeType.entrance, lat: -26.0105, lon: 28.0076),
    'E_S': const Node(id: 'E_S', name: 'South Entrance', type: NodeType.entrance, lat: -26.0135, lon: 28.0068),
    'J1': const Node(id: 'J1', name: 'Centre Court', type: NodeType.junction),
    'J2': const Node(id: 'J2', name: 'Food Court', type: NodeType.junction),
    'S_CHK': const Node(id: 'S_CHK', name: 'Checkers Hyper', type: NodeType.store),
    'S_DC': const Node(id: 'S_DC', name: 'Dis-Chem', type: NodeType.store),
    'S_GM': const Node(id: 'S_GM', name: 'Game', type: NodeType.store),
    'S_IST': const Node(id: 'S_IST', name: 'iStore', type: NodeType.store),
    'S_HM': const Node(id: 'S_HM', name: 'H&M', type: NodeType.store),
  };
  final edges = <Edge>[
    Edge(fromId: 'E_N', toId: 'J1', distance: 1.2),
    Edge(fromId: 'E_S', toId: 'J2', distance: 1.2),
    Edge(fromId: 'J1', toId: 'J2', distance: 0.9),
    Edge(fromId: 'J1', toId: 'S_CHK', distance: 0.1),
    Edge(fromId: 'J2', toId: 'S_DC', distance: 0.1),
    Edge(fromId: 'J2', toId: 'S_GM', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_IST', distance: 0.1),
    Edge(fromId: 'J2', toId: 'S_HM', distance: 0.1),
  ];
  final stores = <Store>[
    const Store(name: 'Checkers Hyper', nodeId: 'S_CHK'),
    const Store(name: 'Dis-Chem', nodeId: 'S_DC'),
    const Store(name: 'Game', nodeId: 'S_GM'),
    const Store(name: 'iStore', nodeId: 'S_IST'),
    const Store(name: 'H&M', nodeId: 'S_HM'),
  ];
  return Mall(
    id: 'fourways',
    name: 'Fourways Mall (JHB)',
    nodes: nodes,
    edges: edges,
    stores: stores,
    centerLat: -26.0122,
    centerLon: 28.0072,
  );
}

Mall clearwaterMall() {
  final nodes = <String, Node>{
    'E_E': const Node(id: 'E_E', name: 'East Entrance', type: NodeType.entrance, lat: -26.1419, lon: 27.9235),
    'E_W': const Node(id: 'E_W', name: 'West Entrance', type: NodeType.entrance, lat: -26.1430, lon: 27.9209),
    'J1': const Node(id: 'J1', name: 'Centre Court', type: NodeType.junction),
    'S_PNP': const Node(id: 'S_PNP', name: 'Pick n Pay', type: NodeType.store),
    'S_CLK': const Node(id: 'S_CLK', name: 'Clicks', type: NodeType.store),
    'S_MTK': const Node(id: 'S_MTK', name: 'Mr Price Home', type: NodeType.store),
  };
  final edges = <Edge>[
    Edge(fromId: 'E_E', toId: 'J1', distance: 1.0),
    Edge(fromId: 'E_W', toId: 'J1', distance: 1.0),
    Edge(fromId: 'J1', toId: 'S_PNP', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_CLK', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_MTK', distance: 0.1),
  ];
  final stores = <Store>[
    const Store(name: 'Pick n Pay', nodeId: 'S_PNP'),
    const Store(name: 'Clicks', nodeId: 'S_CLK'),
    const Store(name: 'Mr Price Home', nodeId: 'S_MTK'),
  ];
  return Mall(
    id: 'clearwater',
    name: 'Clearwater Mall (Roodepoort)',
    nodes: nodes,
    edges: edges,
    stores: stores,
    centerLat: -26.1424,
    centerLon: 27.9225,
  );
}

Mall greenstone() {
  final nodes = <String, Node>{
    'E_N': const Node(id: 'E_N', name: 'North Entrance', type: NodeType.entrance, lat: -26.1053, lon: 28.1505),
    'E_S': const Node(id: 'E_S', name: 'South Entrance', type: NodeType.entrance, lat: -26.1082, lon: 28.1509),
    'J1': const Node(id: 'J1', name: 'Centre Court', type: NodeType.junction),
    'S_PNP': const Node(id: 'S_PNP', name: 'Pick n Pay', type: NodeType.store),
    'S_WW': const Node(id: 'S_WW', name: 'Woolworths', type: NodeType.store),
    'S_GM': const Node(id: 'S_GM', name: 'Game', type: NodeType.store),
  };
  final edges = <Edge>[
    Edge(fromId: 'E_N', toId: 'J1', distance: 1.0),
    Edge(fromId: 'E_S', toId: 'J1', distance: 1.0),
    Edge(fromId: 'J1', toId: 'S_PNP', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_WW', distance: 0.1),
    Edge(fromId: 'J1', toId: 'S_GM', distance: 0.1),
  ];
  final stores = <Store>[
    const Store(name: 'Pick n Pay', nodeId: 'S_PNP'),
    const Store(name: 'Woolworths', nodeId: 'S_WW'),
    const Store(name: 'Game', nodeId: 'S_GM'),
  ];
  return Mall(
    id: 'greenstone',
    name: 'Greenstone (Edenvale)',
    nodes: nodes,
    edges: edges,
    stores: stores,
    centerLat: -26.1069,
    centerLon: 28.1507,
  );
}

final List<Mall> gautengMalls = [
  sandtonCity(),
  mallOfAfrica(),
  menlynPark(),
  eastgate(),
  cresta(),
  rosebankMall(),
  fourwaysMall(),
  clearwaterMall(),
  greenstone(),
];
