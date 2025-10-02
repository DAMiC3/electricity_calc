import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'models.dart';
import 'data/malls.dart';
import 'routing/dijkstra.dart';
import 'location/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'data/products.dart';

void main() => runApp(const TakeMeShoppingApp());

class TakeMeShoppingApp extends StatelessWidget {
  const TakeMeShoppingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Take Me Shopping',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Focus on Gauteng malls per request
  final malls = gautengMalls;
  Mall? selectedMall;
  Store? selectedStore;
  EntranceRecommendation? recommendation;
  String? infoMessage;

  // Live location tracking
  StreamSubscription<Position>? _posSub;
  Position? _currentPosition;
  bool _tracking = false;
  bool _routing = false;
  double _routingProgress = 0.0; // 0..1
  String? _routingLabel;

  @override
  void initState() {
    super.initState();
    selectedMall = malls.first;
  }

  Future<void> computeDirections() async {
    if (selectedMall == null || selectedStore == null) return;
    final mall = selectedMall!;
    final target = selectedStore!;
    final entrances = mall.entrances;
    if (entrances.isEmpty) return;
    setState(() {
      _routing = true;
      _routingProgress = 0;
      _routingLabel = 'Analyzing entrances...';
      recommendation = null;
      infoMessage = null;
    });

    EntranceRecommendation? best;
    for (int i = 0; i < entrances.length; i++) {
      final e = entrances[i];
      final pr = shortestPath(mall: mall, startNodeId: e.id, endNodeId: target.nodeId);
      if (pr != null) {
        if (best == null || pr.distance < best.path.distance) {
          best = EntranceRecommendation(entrance: e, path: pr);
        }
      }
      // update progress
      setState(() {
        _routingProgress = (i + 1) / entrances.length;
        _routingLabel = 'Checking ${i + 1}/${entrances.length}: ${e.name}';
      });
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    setState(() {
      recommendation = best;
      _routing = false;
      _routingLabel = null;
      infoMessage = best != null ? 'Best entrance: ${best.entrance.name}' : 'No route found.';
    });
  }

  Future<void> useMyLocation() async {
    setState(() => infoMessage = 'Getting location...');
    final pos = await LocationService.currentPosition();
    if (pos == null) {
      setState(() => infoMessage = 'Location unavailable or permission denied.');
      return;
    }

    // If mall not selected, try to pick nearest Gauteng mall by center
    Mall? mall = selectedMall;
    mall ??= _nearestMallByCenter(pos.latitude, pos.longitude, gautengMalls);
    if (mall == null) {
      setState(() => infoMessage = 'Not near supported malls. Select one.');
      return;
    }

    // Choose nearest entrance by GPS among entrances with coordinates
    final entrance = _nearestEntrance(mall, pos.latitude, pos.longitude);
    if (entrance == null) {
      setState(() => infoMessage = 'This mall has no geocoded entrances.');
      return;
    }

    // If no store selected yet, prompt in UI message
    if (selectedStore == null) {
      final pickedMall = mall;
      setState(() {
        selectedMall = pickedMall;
        recommendation = null;
        infoMessage = 'Near ${pickedMall.name}: closest entrance is ${entrance.name}. Pick a store.';
      });
      return;
    }

    final pr = shortestPath(mall: mall, startNodeId: entrance.id, endNodeId: selectedStore!.nodeId);
    setState(() {
      selectedMall = mall;
      recommendation = pr == null ? null : EntranceRecommendation(entrance: entrance, path: pr);
      infoMessage = pr == null ? 'No route found from that entrance.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mall = selectedMall;
    final stores = mall?.stores ?? const <Store>[];
    final mallOptions = _sortedMallsByLocationDesc();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Take Me Shopping (ZA)'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Guide', icon: Icon(Icons.directions_walk)),
              Tab(text: 'Ideas', icon: Icon(Icons.lightbulb_outline)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: _tracking ? 'Stop GPS tracking' : 'Start GPS tracking',
              icon: Icon(_tracking ? Icons.location_on : Icons.location_off),
              onPressed: () async {
                if (_tracking) {
                  await _stopTracking();
                } else {
                  await _startTracking();
                }
              },
            ),
          IconButton(
            tooltip: 'Search stores (Gauteng)',
            icon: const Icon(Icons.search),
            onPressed: () async {
              final sel = await showSearch<StorePick?>(
                context: context,
                delegate: StoreSearchDelegate(gautengMalls),
              );
              if (sel != null && sel.mall != null && sel.store != null) {
                setState(() {
                  selectedMall = sel.mall;
                  selectedStore = sel.store;
                  recommendation = null;
                  infoMessage = '';
                });
                await computeDirections();
              }
            },
          ),
          ],
        ),
        body: TabBarView(
          children: [
            // Guide tab
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Pick a mall and store. Get where to park and how to walk.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Theme(
                  data: Theme.of(context).copyWith(
                    focusColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                  ),
                  child: DropdownButtonFormField<Mall>(
                    value: mall,
                    items: mallOptions
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                _mallLabel(m),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ))
                        .toList(),
                    decoration: const InputDecoration(
                      labelText: 'Mall',
                      border: OutlineInputBorder(),
                      filled: false,
                    ),
                    isExpanded: true,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    onChanged: (m) {
                      setState(() {
                        selectedMall = m;
                        selectedStore = null;
                        recommendation = null;
                      });
                      if (selectedStore != null) {
                        // recompute for new mall
                        computeDirections();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _StorePicker(
                  stores: stores,
                  value: selectedStore,
                  onSelected: (s) {
                    setState(() {
                      selectedStore = s;
                      recommendation = null;
                    });
                    if (s != null) computeDirections();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(_tracking ? Icons.location_on : Icons.location_off, color: _tracking ? Colors.green : Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _tracking
                            ? 'GPS ${_currentPosition != null ? '~${_currentPosition!.accuracy.toStringAsFixed(0)}m acc' : 'active'}'
                            : 'GPS off',
                      ),
                    ),
                    if (!_tracking)
                      TextButton(
                        onPressed: _startTracking,
                        child: const Text('Start'),
                      ),
                    if (_tracking)
                      TextButton(
                        onPressed: _stopTracking,
                        child: const Text('Stop'),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_routing) ...[
                  LinearProgressIndicator(value: _routingProgress.clamp(0.0, 1.0)),
                  const SizedBox(height: 8),
                  Text('Routing ${(_routingProgress * 100).toStringAsFixed(0)}%${_routingLabel != null ? ' • $_routingLabel' : ''}'),
                ],
                const SizedBox(height: 8),
                if (infoMessage != null && infoMessage!.isNotEmpty)
                  Text(infoMessage!, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                if (recommendation != null && mall != null && selectedStore != null)
                  _LiveDirections(mall: mall, store: selectedStore!, rec: recommendation!),
              ],
            ),
            // Ideas tab: item search across malls
            _ItemSearchTab(
              malls: gautengMalls,
              onRouteTo: (mall, store) async {
                setState(() {
                  selectedMall = mall;
                  selectedStore = store;
                });
                await computeDirections();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Sort mall options by distance from current GPS (descending as requested)
  List<Mall> _sortedMallsByLocationDesc() {
    if (_currentPosition == null) return malls;
    final lat = _currentPosition!.latitude;
    final lon = _currentPosition!.longitude;
    final withDist = <(Mall, double)>[];
    for (final m in malls) {
      if (m.centerLat == null || m.centerLon == null) {
        withDist.add((m, double.infinity));
      } else {
        withDist.add((m, _haversine(lat, lon, m.centerLat!, m.centerLon!)));
      }
    }
    withDist.sort((a, b) => b.$2.compareTo(a.$2)); // descending
    return withDist.map((e) => e.$1).toList();
  }

  String _mallLabel(Mall m) {
    if (_currentPosition == null || m.centerLat == null || m.centerLon == null) return m.name;
    final d = _haversine(_currentPosition!.latitude, _currentPosition!.longitude, m.centerLat!, m.centerLon!);
    final km = d >= 1.0 ? '${d.toStringAsFixed(1)} km' : '${(d * 1000).toStringAsFixed(0)} m';
    return '${m.name} • $km away';
  }

  Future<void> _startTracking() async {
    if (_tracking) return;
    setState(() => infoMessage = 'Getting location...');
    final ok = await LocationService.ensurePermission();
    if (!ok) {
      setState(() {
        infoMessage = 'Location unavailable or permission denied.';
        _tracking = false;
      });
      return;
    }
    // Initial fix
    Position? first;
    try {
      first = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      first = null;
    }
    if (first != null) _handlePosition(first);
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5),
    ).listen(_handlePosition, onError: (e) {
      setState(() => infoMessage = 'Location error: $e');
    });
    setState(() => _tracking = true);
  }

  Future<void> _stopTracking() async {
    await _posSub?.cancel();
    _posSub = null;
    setState(() => _tracking = false);
  }

  void _handlePosition(Position pos) {
    _currentPosition = pos;
    // Pick mall: prefer selected if nearby, else nearest Gauteng mall
    Mall? mall = selectedMall;
    final nearSelected = mall != null && _nearestMallByCenter(pos.latitude, pos.longitude, [mall]) != null;
    if (!nearSelected) {
      mall = _nearestMallByCenter(pos.latitude, pos.longitude, gautengMalls) ?? mall;
    }
    // Update current mall context quietly; routing is computed via computeDirections()
    if (mall != null) {
      setState(() {
        selectedMall = mall;
      });
    }
  }
}

class _LiveDirections extends StatelessWidget {
  final Mall mall;
  final Store store;
  final EntranceRecommendation rec;
  const _LiveDirections({required this.mall, required this.store, required this.rec});

  @override
  Widget build(BuildContext context) {
    final path = rec.path.path;
    final distance = rec.path.distance;
    final steps = <String>[];
    for (int i = 0; i < path.length; i++) {
      final n = path[i];
      if (i == 0) {
        steps.add('Start at: ${n.name}');
      } else if (i == path.length - 1) {
        steps.add('Arrive at: ${n.name}');
      } else {
        steps.add('Walk via: ${n.name}');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Live Directions to ${store.name}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text('Start at: ${rec.entrance.name}'),
        const SizedBox(height: 8),
        ...steps.map((s) => Row(
              children: [
                const Icon(Icons.directions_walk, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(s)),
              ],
            )),
        const SizedBox(height: 8),
        Text('Route length: ${distance.toStringAsFixed(2)} units'),
        const SizedBox(height: 8),
        Text(
          'Note: Route updates live with your location; indoor maps simplified.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
        ),
      ],
    );
  }
}

class _ItemSearchTab extends StatefulWidget {
  final List<Mall> malls;
  final Future<void> Function(Mall mall, Store store) onRouteTo;
  const _ItemSearchTab({required this.malls, required this.onRouteTo});

  @override
  State<_ItemSearchTab> createState() => _ItemSearchTabState();
}

class _ItemSearchTabState extends State<_ItemSearchTab> {
  String _query = '';
  List<ProductHit> _results = const [];

  void _runSearch(String q) {
    setState(() {
      _query = q;
      _results = searchProducts(q, widget.malls);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search items (e.g., "black dress", "butter")',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: _runSearch,
        ),
        const SizedBox(height: 12),
        if (_query.isEmpty)
          Text('Type to search products across Gauteng malls.', style: Theme.of(context).textTheme.bodyMedium)
        else if (_results.isEmpty)
          Text('No matches found.', style: Theme.of(context).textTheme.bodyMedium)
        else
          ..._results.map((hit) => Card(
                child: ListTile(
                  leading: const Icon(Icons.shopping_bag),
                  title: Text('${hit.product.name}  •  R${hit.product.priceZar.toStringAsFixed(2)}'),
                  subtitle: Text('${hit.product.storeName} — ${hit.mall.name}'),
                  trailing: TextButton.icon(
                    onPressed: () => widget.onRouteTo(hit.mall, hit.store),
                    icon: const Icon(Icons.directions_walk),
                    label: const Text('Route'),
                  ),
                ),
              )),
      ],
    );
  }
}

// Simple search across malls
class StorePick {
  final Mall? mall;
  final Store? store;
  StorePick(this.mall, this.store);
}

class StoreSearchDelegate extends SearchDelegate<StorePick?> {
  final List<Mall> malls;
  StoreSearchDelegate(this.malls);

  List<(Mall, Store)> _matches(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return [];
    final hits = <(Mall, Store)>[];
    for (final m in malls) {
      for (final s in m.stores) {
        if (s.name.toLowerCase().contains(query)) {
          hits.add((m, s));
        }
      }
    }
    return hits;
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final hits = _matches(query);
    return ListView.builder(
      itemCount: hits.length,
      itemBuilder: (context, i) {
        final (m, s) = hits[i];
        return ListTile(
          leading: const Icon(Icons.store),
          title: Text(s.name),
          subtitle: Text(m.name),
          onTap: () => close(context, StorePick(m, s)),
        );
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );
}

class _StorePicker extends StatefulWidget {
  final List<Store> stores;
  final Store? value;
  final ValueChanged<Store?> onSelected;
  const _StorePicker({required this.stores, required this.value, required this.onSelected});

  @override
  State<_StorePicker> createState() => _StorePickerState();
}

class _StorePickerState extends State<_StorePicker> {
  String _filter = '';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.stores
        .where((s) => s.name.toLowerCase().contains(_filter.toLowerCase()))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search store in selected mall',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => _filter = v),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Store>(
          value: widget.value,
          items: filtered.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
          decoration: const InputDecoration(labelText: 'Store', border: OutlineInputBorder()),
          onChanged: widget.onSelected,
        ),
      ],
    );
  }
}

Mall? _nearestMallByCenter(double lat, double lon, List<Mall> malls) {
  double best = double.infinity;
  Mall? ans;
  for (final m in malls) {
    if (m.centerLat == null || m.centerLon == null) continue;
    final d = _haversine(lat, lon, m.centerLat!, m.centerLon!);
    if (d < best) {
      best = d;
      ans = m;
    }
  }
  // Consider within ~2km as at the mall
  if (best < 2.0) return ans;
  return null;
}

Node? _nearestEntrance(Mall mall, double lat, double lon) {
  double best = double.infinity;
  Node? ans;
  for (final e in mall.entrances) {
    if (e.lat == null || e.lon == null) continue;
    final d = _haversine(lat, lon, e.lat!, e.lon!);
    if (d < best) {
      best = d;
      ans = e;
    }
  }
  return ans;
}

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0; // km
  final p = 0.017453292519943295; // pi/180
  final dLat = (lat2 - lat1) * p;
  final dLon = (lon2 - lon1) * p;
  final a = 0.5 - math.cos(dLat) / 2 + math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos(dLon)) / 2;
  return 2 * R * math.asin(math.sqrt(a));
}
