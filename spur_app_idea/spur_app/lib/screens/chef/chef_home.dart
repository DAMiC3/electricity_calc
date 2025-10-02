import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../models/order.dart';

class ChefHome extends StatelessWidget {
  const ChefHome({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final orders = state.orders.where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Queue'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
        ),
      ),
      body: orders.isEmpty
          ? const Center(child: Text('No active orders'))
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, i) {
                final o = orders[i];
                final expected = o.expectedReadyAt;
                final remaining = expected == null ? null : expected.difference(DateTime.now());
                final mins = remaining == null ? null : (remaining.isNegative ? 0 : remaining.inMinutes);
                final allergens = o.lines.expand((l) => l.item.allergens).toSet().toList();
                return Card(
                  child: ListTile(
                    title: Text('Order ${o.id} • ${_statusLabel(o.status)}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (mins != null)
                          Row(
                            children: [
                              Text('Items: ${o.lines.length} • ETA: ${mins}m'),
                              const SizedBox(width: 8),
                              Expanded(child: ElapsedTimer(since: o.startedPreparingAt ?? o.createdAt)),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Text('Items: ${o.lines.length} • Waiting to start'),
                              const SizedBox(width: 8),
                              Expanded(child: ElapsedTimer(since: o.createdAt)),
                            ],
                          ),
                        if (allergens.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            children: allergens.map((a) => Chip(label: Text('Allergy: $a'), backgroundColor: Colors.red.shade300)).toList(),
                          ),
                        if (o.customerLanguage != null)
                          Text('Customer language: ${o.customerLanguage}')
                        else
                          const SizedBox.shrink(),
                        if (o.customerAllergies.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            children: o.customerAllergies
                                .map((a) => Chip(label: Text('Customer allergy: $a'), backgroundColor: Colors.orange.shade300))
                                .toList(),
                          ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () => state.setOrderStatus(o.id, _next(o.status)),
                          child: const Text('Next Phase'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _statusLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.received:
        return 'Received';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class ElapsedTimer extends StatefulWidget {
  final DateTime since;
  const ElapsedTimer({super.key, required this.since});

  @override
  State<ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<ElapsedTimer> {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.since);
    _ticker = Ticker((_) {
      if (mounted) {
        setState(() => _elapsed = DateTime.now().difference(widget.since));
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _elapsed.inMinutes;
    final s = _elapsed.inSeconds % 60;
    return Text('Time: ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}');
  }
}

class Ticker {
  final void Function(Duration) onTick;
  late final Stopwatch _sw;
  late final Duration _interval;
  bool _running = false;
  Ticker(this.onTick, {Duration interval = const Duration(seconds: 1)}) {
    _interval = interval;
    _sw = Stopwatch();
  }
  void start() {
    _running = true;
    _sw.start();
    _tick();
  }
  void _tick() async {
    while (_running) {
      await Future<void>.delayed(_interval);
      onTick(_sw.elapsed);
    }
  }
  void dispose() {
    _running = false;
  }
}

OrderStatus _next(OrderStatus s) {
  switch (s) {
    case OrderStatus.received:
      return OrderStatus.preparing;
    case OrderStatus.preparing:
      return OrderStatus.ready;
    case OrderStatus.ready:
      return OrderStatus.completed;
    case OrderStatus.completed:
      return OrderStatus.completed;
    case OrderStatus.cancelled:
      return OrderStatus.cancelled;
  }
}
