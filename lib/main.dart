import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const GautengElecApp());
}

/// =======================================================
/// ROOT
/// =======================================================
class GautengElecApp extends StatelessWidget {
  const GautengElecApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gauteng Electricity Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const Bootstrapper(),
    );
  }
}

/// Loads prefs, ensures tariffs exist, checks yearly update, then routes
class Bootstrapper extends StatefulWidget {
  const Bootstrapper({super.key});

  @override
  State<Bootstrapper> createState() => _BootstrapperState();
}

class _BootstrapperState extends State<Bootstrapper> {
  bool _ready = false;
  bool _hasUser = false;
  // Force app to show the sign-in page on startup.
  static const bool kStartAtLogin = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    await TariffManager.ensureTariffs();   // built-in defaults first run
    await TariffManager.tryAutoUpdate();   // yearly check

    if (kStartAtLogin) {
      // Clear only the active session (keeps registered users)
      await prefs.remove('active_email');
      await prefs.remove('active_region_key');
      _hasUser = false;
    } else {
      _hasUser = prefs.getString('active_email') != null;
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _hasUser ? const HomeShell() : const LoginPage();
  }
}

/// =======================================================
/// MODELS
/// =======================================================
class TariffBlock {
  final int from;        // inclusive (kWh)
  final int? to;         // inclusive (kWh), null = open-ended
  final double rate;     // R/kWh (VAT-inclusive)

  const TariffBlock({required this.from, required this.rate, this.to});

  Map<String, dynamic> toJson() => {'from': from, 'to': to, 'rate': rate};

  factory TariffBlock.fromJson(Map<String, dynamic> j) => TariffBlock(
        from: j['from'],
        to: j['to'],
        rate: (j['rate'] as num).toDouble(),
      );
}

class BandUse {
  final int tierIndex;   // 1-based tier number
  final int from;        // starting index used in this purchase
  final int? to;         // ending index used in this purchase (null = open)
  final double rate;     // R/kWh
  final double kwh;      // kWh purchased in this tier for this transaction
  final double cost;     // Rand spent in this tier

  BandUse({
    required this.tierIndex,
    required this.from,
    required this.to,
    required this.rate,
    required this.kwh,
    required this.cost,
  });
}

class RegionTariff {
  final String regionKey;       // e.g. "tshwane"
  final String displayName;     // e.g. "City of Tshwane"
  final List<TariffBlock> blocks;
  final DateTime startDate;     // effective from (inclusive)
  final DateTime? endDate;      // effective until (inclusive); null = ongoing

  RegionTariff({
    required this.regionKey,
    required this.displayName,
    required this.blocks,
    required this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toJson() => {
        'regionKey': regionKey,
        'displayName': displayName,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      };

  factory RegionTariff.fromJson(Map<String, dynamic> j) {
    // Backward compatibility for old cached JSON without dates
    DateTime defaultStart = DateTime(2025, 7, 1);
    DateTime? parsedStart;
    DateTime? parsedEnd;
    try {
      final s = j['startDate'];
      if (s is String && s.isNotEmpty) parsedStart = DateTime.parse(s);
    } catch (_) {}
    try {
      final e = j['endDate'];
      if (e is String && e.isNotEmpty) parsedEnd = DateTime.parse(e);
    } catch (_) {}
    return RegionTariff(
      regionKey: j['regionKey'],
      displayName: j['displayName'],
      blocks: (j['blocks'] as List).map((e) => TariffBlock.fromJson(e)).toList(),
      startDate: parsedStart ?? defaultStart,
      endDate: parsedEnd,
    );
  }
}

class TransactionRecord {
  final String id;
  final String regionKey;
  final DateTime date;
  final double money;       // total paid (VAT incl.)
  final double actualKwh;   // tokens received
  final double expectedKwh; // estimated from tariff

  TransactionRecord({
    required this.id,
    required this.regionKey,
    required this.date,
    required this.money,
    required this.actualKwh,
    required this.expectedKwh,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'regionKey': regionKey,
        'date': date.toIso8601String(),
        'money': money,
        'actualKwh': actualKwh,
        'expectedKwh': expectedKwh,
      };

  factory TransactionRecord.fromJson(Map<String, dynamic> j) =>
      TransactionRecord(
        id: j['id'],
        regionKey: j['regionKey'],
        date: DateTime.parse(j['date']),
        money: (j['money'] as num).toDouble(),
        actualKwh: (j['actualKwh'] as num).toDouble(),
        expectedKwh: (j['expectedKwh'] as num).toDouble(),
      );
}

class MonthlySummary {
  final String monthKey; // YYYY-MM
  final double totalMoney;
  final double totalActualKwh;
  final double totalExpectedKwh;
  final int transactions;

  MonthlySummary({
    required this.monthKey,
    required this.totalMoney,
    required this.totalActualKwh,
    required this.totalExpectedKwh,
    required this.transactions,
  });

  double get percentDiff => totalExpectedKwh == 0
      ? 0
      : ((totalActualKwh - totalExpectedKwh) / totalExpectedKwh) * 100.0;

  double get netExVat => totalMoney / 1.15;
  double get vatPortion => totalMoney - netExVat;

  Map<String, dynamic> toJson() => {
        'monthKey': monthKey,
        'totalMoney': totalMoney,
        'totalActualKwh': totalActualKwh,
        'totalExpectedKwh': totalExpectedKwh,
        'transactions': transactions,
      };

  factory MonthlySummary.fromJson(Map<String, dynamic> j) => MonthlySummary(
        monthKey: j['monthKey'],
        totalMoney: (j['totalMoney'] as num).toDouble(),
        totalActualKwh: (j['totalActualKwh'] as num).toDouble(),
        totalExpectedKwh: (j['totalExpectedKwh'] as num).toDouble(),
        transactions: j['transactions'],
      );
}

/// =======================================================
/// TARIFF MANAGER: built-in defaults + yearly fetch
/// =======================================================
class TariffManager {
  // TODO: Replace with your hosted JSON (GitHub raw / Firebase / S3)
  static const String tariffsUrl =
      'https://example.com/gauteng_tariffs.json';

  // Built-in fallback defaults (illustrative — put confirmed rates here)
  /* static final List<RegionTariff> _builtInDefaults = [
    RegionTariff(
      regionKey: 'tshwane',
      displayName: 'City of Tshwane',
      blocks: [
        TariffBlock(from: 0, to: 100, rate: 2.40),
        TariffBlock(from: 101, to: 600, rate: 2.90),
        TariffBlock(from: 601, to: null, rate: 3.50),
      ],
    ),
    RegionTariff(
      regionKey: 'joburg',
      displayName: 'City of Johannesburg',
      blocks: [
        TariffBlock(from: 0, to: 150, rate: 2.55),
        TariffBlock(from: 151, to: 600, rate: 3.05),
        TariffBlock(from: 601, to: null, rate: 3.70),
      ],
    ),
    RegionTariff(
      regionKey: 'ekurhuleni',
      displayName: 'Ekurhuleni',
      blocks: [
        TariffBlock(from: 0, to: 100, rate: 2.50),
        TariffBlock(from: 101, to: 600, rate: 3.00),
        TariffBlock(from: 601, to: null, rate: 3.60),
      ],
    ),
  ];

  // Updated built-in defaults (VAT-inclusive) — Sep 2025 (FY 2025/26)
  // Includes Ekurhuleni Tariff B (Flat) as a separate selectable region.
  */
  static final List<RegionTariff> _builtInDefaultsV2 = [
    RegionTariff(
      regionKey: 'tshwane',
      displayName: 'City of Tshwane — Residential IBT',
      blocks: const [
        TariffBlock(from: 1, to: 100, rate: 3.4259),
        TariffBlock(from: 101, to: 400, rate: 4.0094),
        TariffBlock(from: 401, to: 650, rate: 4.3682),
        TariffBlock(from: 651, to: null, rate: 4.7090),
      ],
      startDate: DateTime(2025, 7, 1),
      endDate: null,
    ),
    RegionTariff(
      regionKey: 'joburg',
      displayName: 'City of Johannesburg — Prepaid High',
      blocks: const [
        TariffBlock(from: 1, to: 350, rate: 2.7179),
        TariffBlock(from: 351, to: 500, rate: 3.1176),
        TariffBlock(from: 501, to: null, rate: 3.5525),
      ],
      startDate: DateTime(2025, 7, 1),
      endDate: null,
    ),
    RegionTariff(
      regionKey: 'ekurhuleni',
      displayName: 'Ekurhuleni — Tariff A (IBT, Non‑Indigent)',
      blocks: const [
        TariffBlock(from: 1, to: 50, rate: 3.2530),
        TariffBlock(from: 51, to: 600, rate: 3.2530),
        TariffBlock(from: 601, to: 700, rate: 5.0809),
        TariffBlock(from: 701, to: null, rate: 13.1558),
      ],
      startDate: DateTime(2025, 7, 1),
      endDate: null,
    ),
    RegionTariff(
      regionKey: 'ekurhuleni_flat',
      displayName: 'Ekurhuleni — Tariff B (Flat)',
      blocks: const [
        TariffBlock(from: 1, to: null, rate: 4.2142),
      ],
      startDate: DateTime(2025, 7, 1),
      endDate: null,
    ),
  ];

  static Future<void> ensureTariffs() async {
    final prefs = await SharedPreferences.getInstance();
    final nowYear = DateTime.now().year;
    bool wrote = false;

    if (!prefs.containsKey('tariffs_json')) {
      final jsonStr = jsonEncode({
        'versionYear': nowYear,
        'regions': _builtInDefaultsV2.map((r) => r.toJson()).toList(),
      });
      await prefs.setString('tariffs_json', jsonStr);
      await prefs.setInt('tariffs_updated_year', nowYear);
      await prefs.setString('tariffs_updated_at', DateTime.now().toIso8601String());
      wrote = true;
    } else {
      // Migrate old cached tariffs to Sep 2025 defaults if they look outdated.
      try {
        final raw = prefs.getString('tariffs_json');
        final data = jsonDecode(raw!) as Map<String, dynamic>;
        final version = (data['versionYear'] is int) ? data['versionYear'] as int : 0;
        bool outdated = version < 2025;
        if (!outdated && data['regions'] is List) {
          try {
            final regions = (data['regions'] as List).cast<dynamic>();
            final tshwane = regions.firstWhere((e) => (e is Map && e['regionKey'] == 'tshwane')) as Map?;
            if (tshwane != null && tshwane['blocks'] is List && (tshwane['blocks'] as List).isNotEmpty) {
              final first = (tshwane['blocks'] as List).first as Map;
              final rate = (first['rate'] as num?)?.toDouble() ?? 0.0;
              // Old seed had 2.40; anything < 3.0 indicates old data
              if (rate < 3.0) outdated = true;
            }
          } catch (_) {}
        }
        if (outdated) {
          final jsonStr = jsonEncode({
            'versionYear': nowYear,
            'regions': _builtInDefaultsV2.map((r) => r.toJson()).toList(),
          });
          await prefs.setString('tariffs_json', jsonStr);
          await prefs.setInt('tariffs_updated_year', nowYear);
          await prefs.setString('tariffs_updated_at', DateTime.now().toIso8601String());
          wrote = true;
        }
      } catch (_) {
        // If parsing fails, reseed with built-ins
        final jsonStr = jsonEncode({
          'versionYear': nowYear,
          'regions': _builtInDefaultsV2.map((r) => r.toJson()).toList(),
        });
        await prefs.setString('tariffs_json', jsonStr);
        await prefs.setInt('tariffs_updated_year', nowYear);
        await prefs.setString('tariffs_updated_at', DateTime.now().toIso8601String());
        wrote = true;
      }
    }

    if (wrote) {
      // No-op: place to hook metrics/log if needed
    }
  }

  static Future<List<RegionTariff>> loadTariffs() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('tariffs_json');
    final all = s == null
        ? _builtInDefaultsV2
        : ((jsonDecode(s) as Map<String, dynamic>)['regions'] as List)
            .map((e) => RegionTariff.fromJson(e))
            .toList();
    // Deduplicate by regionKey to latest startDate for UI selection
    final Map<String, RegionTariff> latest = {};
    for (final r in all) {
      final prev = latest[r.regionKey];
      if (prev == null || r.startDate.isAfter(prev.startDate)) {
        latest[r.regionKey] = r;
      }
    }
    return latest.values.toList();
  }

  // For now both residential and commercial return the same list until
  // distinct commercial blocks are supplied.
  static Future<List<RegionTariff>> loadTariffsForType(String customerType) async {
    return loadTariffs();
  }

  // Full list with history (multiple entries per regionKey).
  static Future<List<RegionTariff>> loadTariffsAll() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('tariffs_json');
    if (s == null) return _builtInDefaultsV2;
    final data = jsonDecode(s) as Map<String, dynamic>;
    return (data['regions'] as List).map((e) => RegionTariff.fromJson(e)).toList();
  }

  /// Reset stored tariffs to the built-in Sep 2025 set.
  static Future<void> resetToBuiltins() async {
    final prefs = await SharedPreferences.getInstance();
    final nowYear = DateTime.now().year;
    final jsonStr = jsonEncode({
      'versionYear': nowYear,
      'regions': _builtInDefaultsV2.map((r) => r.toJson()).toList(),
    });
    await prefs.setString('tariffs_json', jsonStr);
    await prefs.setInt('tariffs_updated_year', nowYear);
    await prefs.setString('tariffs_updated_at', DateTime.now().toIso8601String());
  }

  /// Once/year auto update (on first run in a calendar year).
  static Future<void> tryAutoUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastYear = prefs.getInt('tariffs_updated_year');
    final nowYear = DateTime.now().year;

    if (lastYear != null && lastYear == nowYear) return;

    try {
      final res = await http
          .get(Uri.parse(tariffsUrl))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['regions'] is List) {
          await prefs.setString('tariffs_json', res.body);
          await prefs.setInt(
              'tariffs_updated_year', (data['versionYear'] ?? nowYear) as int);
          await prefs.setString(
              'tariffs_updated_at', DateTime.now().toIso8601String());
          return;
        }
      }
    } catch (_) {
      // swallow -> keep cached/builtin
    }
    await prefs.setInt('tariffs_updated_year', nowYear);
  }

  static RegionTariff? findRegion(List<RegionTariff> regions, String key) {
    try {
      return regions.firstWhere((r) => r.regionKey == key);
    } catch (_) {
      return null;
    }
  }

  /// Find the tariff entry for a region that is effective on a given date.
  /// If multiple entries match, choose the one with the latest startDate.
  static RegionTariff? findRegionForDate(
      List<RegionTariff> regions, String key, DateTime date) {
    final candidates = regions.where((r) => r.regionKey == key).where((r) {
      final startsOk = !date.isBefore(r.startDate);
      final endsOk = r.endDate == null || !date.isAfter(r.endDate!);
      return startsOk && endsOk;
    }).toList();
    if (candidates.isEmpty) return findRegion(regions, key);
    candidates.sort((a, b) => b.startDate.compareTo(a.startDate));
    return candidates.first;
  }
}

/// =======================================================
/// AUTH (local only)
/// =======================================================
class Auth {
  static const _usersKey = 'users_json';
  static const _activeKey = 'active_email';
  static const _activeRegionSessionKey = 'active_region_key';

  static Future<Map<String, dynamic>> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_usersKey);
    return s == null ? {} : jsonDecode(s);
  }

  static Future<void> _saveUsers(Map<String, dynamic> m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, jsonEncode(m));
  }

  static Future<bool> register({
    required String email,
    required String password,
    required String regionKey,
    required String customerType,
  }) async {
    final users = await _loadUsers();
    if (users.containsKey(email)) return false;
    users[email] = {
      'password': password,
      'regionKey': regionKey,
      'customerType': customerType,
    };
    await _saveUsers(users);
    return true;
  }

  static Future<bool> login({
    required String email,
    required String password,
  }) async {
    final users = await _loadUsers();
    if (!users.containsKey(email)) return false;
    if (users[email]['password'] != password) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, email);
    return true;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
    await prefs.remove(_activeRegionSessionKey);
  }

  static Future<bool> changePassword({
    required String email,
    required String newPassword,
  }) async {
    final users = await _loadUsers();
    if (!users.containsKey(email)) return false;
    users[email]['password'] = newPassword;
    await _saveUsers(users);
    return true;
  }

  static Future<String?> activeEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  static Future<String?> regionFor(String email) async {
    final users = await _loadUsers();
    if (!users.containsKey(email)) return null;
    return users[email]['regionKey'] as String?;
  }

  static Future<void> setRegion(String email, String regionKey) async {
    final users = await _loadUsers();
    if (!users.containsKey(email)) return;
    users[email]['regionKey'] = regionKey;
    await _saveUsers(users);
  }

  // Session-scoped active region (chosen at sign-in)
  static Future<void> setActiveRegionKey(String regionKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeRegionSessionKey, regionKey);
  }

  static Future<String?> activeRegionKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeRegionSessionKey);
  }

  static Future<String> customerTypeFor(String email) async {
    final users = await _loadUsers();
    if (!users.containsKey(email)) return 'residential';
    final v = users[email]['customerType'];
    return (v is String && v.isNotEmpty) ? v : 'residential';
  }

  static Future<void> setCustomerType(String email, String type) async {
    final users = await _loadUsers();
    if (!users.containsKey(email)) return;
    users[email]['customerType'] = type;
    await _saveUsers(users);
  }
}

/// =======================================================
/// STORAGE (SharedPreferences)
/// =======================================================
class Store {
  static const _txKeyBase = 'transactions_json';
  static const _monthsKeyBase = 'months_set_json';

  // Build a per-user SharedPreferences key using the active email.
  static Future<String> _scopedKey(String base) async {
    final email = await Auth.activeEmail();
    final id = (email ?? 'guest').toLowerCase();
    return '${base}__${id}';
  }

  static String monthKeyOf(DateTime d) => DateFormat('yyyy-MM').format(d);

  static Future<List<TransactionRecord>> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final txKey = await _scopedKey(_txKeyBase);
    final s = prefs.getString(txKey);
    if (s == null) return [];
    final list = (jsonDecode(s) as List)
        .map((e) => TransactionRecord.fromJson(e))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list.take(20).toList(); // keep last 20
  }

  static Future<void> saveTransactions(List<TransactionRecord> tx) async {
    tx.sort((a, b) => b.date.compareTo(a.date));
    final capped = tx.take(20).toList();
    final prefs = await SharedPreferences.getInstance();
    final txKey = await _scopedKey(_txKeyBase);
    await prefs.setString(
      txKey,
      jsonEncode(capped.map((e) => e.toJson()).toList()),
    );
  }

  static Future<Set<String>> _loadMonthSet() async {
    final prefs = await SharedPreferences.getInstance();
    final monthsKey = await _scopedKey(_monthsKeyBase);
    final s = prefs.getString(monthsKey);
    if (s == null) return {};
    return (jsonDecode(s) as List).map((e) => e.toString()).toSet();
  }

  static Future<void> _saveMonthSet(Set<String> set) async {
    final prefs = await SharedPreferences.getInstance();
    final list = set.toList()..sort(); // ascending
    final keep = list.length <= 5 ? list : list.sublist(list.length - 5);
    final monthsKey = await _scopedKey(_monthsKeyBase);
    await prefs.setString(monthsKey, jsonEncode(keep));
  }

  static Future<void> includeMonth(String monthKey) async {
    final set = await _loadMonthSet();
    set.add(monthKey);
    await _saveMonthSet(set);
  }

  static Future<List<String>> loadMonthsDesc() async {
    final set = await _loadMonthSet();
    var list = set.toList();
    list.sort(); // asc
    list = list.reversed.toList(); // desc
    return list;
  }

  static Future<void> deleteMonth(String monthKey) async {
    final all = await loadTransactions();
    final filtered = all.where((t) => monthKeyOf(t.date) != monthKey).toList();
    await saveTransactions(filtered);

    final set = await _loadMonthSet();
    set.remove(monthKey);
    await _saveMonthSet(set);
  }

  static Future<void> resetCurrentMonth() async {
    final nowKey = monthKeyOf(DateTime.now());
    await deleteMonth(nowKey);
  }

  static Future<MonthlySummary> computeSummary(String monthKey) async {
    final tx = await loadTransactions();
    final inMonth = tx.where((t) => monthKeyOf(t.date) == monthKey).toList();
    final totalMoney =
        inMonth.fold<double>(0, (p, n) => p + n.money);
    final totalActual =
        inMonth.fold<double>(0, (p, n) => p + n.actualKwh);
    final totalExpected =
        inMonth.fold<double>(0, (p, n) => p + n.expectedKwh);
    return MonthlySummary(
      monthKey: monthKey,
      totalMoney: totalMoney,
      totalActualKwh: totalActual,
      totalExpectedKwh: totalExpected,
      transactions: inMonth.length,
    );
  }
}

/// =======================================================
/// CALC
/// =======================================================
class Calc {
  /// Estimate expected kWh by spending through each progressive block.
  /// Assumes rates are VAT-inclusive and blocks are inclusive ranges.
  static double expectedKwhFromMoney(double money, List<TariffBlock> blocks) {
    // Backward-compatible wrapper: start at beginning of tier 1
    return expectedKwhFromMoneyAt(money, blocks, 0.0);
  }

  /// Same as above, but continues from an existing month-to-date kWh cursor.
  /// alreadyBoughtKwh is the cumulative kWh purchased earlier this month.
  static double expectedKwhFromMoneyAt(
      double money, List<TariffBlock> blocks, double alreadyBoughtKwh) {
    double remainingMoney = money;
    double totalKwh = 0.0;
    // Next kWh index to be purchased (1-based indices for tiers)
    double nextIndex = alreadyBoughtKwh + 1.0;

    for (final b in blocks) {
      if (remainingMoney <= 0) break;

      final start = b.from.toDouble();
      final end = (b.to == null) ? double.infinity : b.to!.toDouble();

      // Portion of this block still available given what we've already bought
      final blockStart = nextIndex < start ? start : nextIndex;
      if (blockStart > end) continue; // no capacity left in this block

      final availableHere = end.isInfinite ? double.infinity : (end - blockStart + 1);

      if (availableHere.isInfinite) {
        // Spend everything in open-ended block
        final kwhInBlock = remainingMoney / b.rate;
        totalKwh += kwhInBlock;
        remainingMoney = 0;
        nextIndex = blockStart + kwhInBlock;
      } else {
        final blockCost = availableHere * b.rate;
        if (remainingMoney >= blockCost) {
          // Buy the remainder of this block
          totalKwh += availableHere;
          remainingMoney -= blockCost;
          nextIndex = blockStart + availableHere;
        } else {
          // Partial within this block
          final kwhInBlock = remainingMoney / b.rate;
          totalKwh += kwhInBlock;
          nextIndex += kwhInBlock;
          remainingMoney = 0;
        }
      }
    }

    return totalKwh;
  }

  /// Detailed tier breakdown for a single purchase given month-to-date kWh.
  static List<BandUse> breakdownForPurchase(
      double money, List<TariffBlock> blocks, double alreadyBoughtKwh) {
    double remainingMoney = money;
    double nextIndex = alreadyBoughtKwh + 1.0; // 1-based tier indexing
    final List<BandUse> out = [];

    for (int i = 0; i < blocks.length && remainingMoney > 0; i++) {
      final b = blocks[i];
      final start = b.from.toDouble();
      final end = (b.to == null) ? double.infinity : b.to!.toDouble();

      final blockStart = nextIndex < start ? start : nextIndex;
      if (blockStart > end) continue;

      final availableHere = end.isInfinite ? double.infinity : (end - blockStart + 1);

      if (availableHere.isInfinite) {
        final kwhInBlock = remainingMoney / b.rate;
        out.add(BandUse(
          tierIndex: i + 1,
          from: blockStart.floor(),
          to: null,
          rate: b.rate,
          kwh: kwhInBlock,
          cost: remainingMoney,
        ));
        remainingMoney = 0;
        nextIndex = blockStart + kwhInBlock;
      } else {
        final blockCost = availableHere * b.rate;
        if (remainingMoney >= blockCost) {
          out.add(BandUse(
            tierIndex: i + 1,
            from: blockStart.floor(),
            to: (blockStart + availableHere - 1).floor(),
            rate: b.rate,
            kwh: availableHere,
            cost: blockCost,
          ));
          remainingMoney -= blockCost;
          nextIndex = blockStart + availableHere;
        } else {
          final kwhInBlock = remainingMoney / b.rate;
          out.add(BandUse(
            tierIndex: i + 1,
            from: blockStart.floor(),
            to: (blockStart + kwhInBlock - 1).floor(),
            rate: b.rate,
            kwh: kwhInBlock,
            cost: remainingMoney,
          ));
          nextIndex += kwhInBlock;
          remainingMoney = 0;
        }
      }
    }

    return out;
  }

  static double vatPortion(double totalIncl) => totalIncl - (totalIncl / 1.15);
  static double netExVat(double totalIncl) => totalIncl / 1.15;

  static double percentDiff(double expected, double actual) {
    if (expected <= 0) return 0;
    return ((actual - expected) / expected) * 100.0;
  }
}

/// =======================================================
/// LOGIN + REGISTER + CHANGE PASSWORD (region selection)
/// =======================================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailC = TextEditingController();
  final passC = TextEditingController();
  String message = '';
  List<RegionTariff> _regions = [];
  String? _selectedRegionKey;
  String _customerType = 'residential'; // 'residential' | 'commercial'

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  @override
  void dispose() {
    emailC.dispose();
    passC.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    _regions = await TariffManager.loadTariffs();
    if (_regions.isNotEmpty && _selectedRegionKey == null) {
      _selectedRegionKey = _regions.first.regionKey;
    }
    if (mounted) setState(() {});
  }

  Future<void> _doLogin() async {
    final email = emailC.text.trim();
    final pass = passC.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => message = 'Please enter email and password.');
      return;
    }
    final ok = await Auth.login(email: email, password: pass);
    if (!ok) {
      setState(() => message = 'Invalid login.');
      return;
    }
    // Persist chosen region into session for this login
    if (_selectedRegionKey != null) {
      await Auth.setActiveRegionKey(_selectedRegionKey!);
    }
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    }
  }

  Future<void> _doRegister() async {
    final email = emailC.text.trim();
    final pass = passC.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => message = 'Please enter email and password.');
      return;
    }
    if (_selectedRegionKey == null) {
      setState(() => message = 'Select a region.');
      return;
    }
    final ok = await Auth.register(
      email: email,
      password: pass,
      regionKey: _selectedRegionKey!,
      customerType: _customerType,
    );
    setState(() {
      message = ok ? 'Registered! You can log in.' : 'User already exists.';
    });
    if (ok) {
      // Seed session region so the next login uses it
      await Auth.setActiveRegionKey(_selectedRegionKey!);
    }
  }

  Future<void> _doChangePass() async {
    final email = emailC.text.trim();
    final pass = passC.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => message = 'Please enter email and new password.');
      return;
    }
    final ok = await Auth.changePassword(email: email, newPassword: pass);
    setState(() {
      message = ok ? 'Password changed.' : 'User not found.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1e3c72), Color(0xFF2a5298)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Gauteng Electricity Tracker',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailC,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passC,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedRegionKey,
                      items: _regions
                          .map((r) => DropdownMenuItem(
                                value: r.regionKey,
                                child: Text(r.displayName),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedRegionKey = v),
                      decoration: const InputDecoration(
                        labelText: 'Select Region (Gauteng)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _customerType,
                      items: const [
                        DropdownMenuItem(value: 'residential', child: Text('Residential')),
                        DropdownMenuItem(value: 'commercial', child: Text('Commercial')),
                      ],
                      onChanged: (v) => setState(() => _customerType = v ?? 'residential'),
                      decoration: const InputDecoration(
                        labelText: 'Customer Type',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _doLogin,
                            child: const Text('Login'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _doRegister,
                            child: const Text('Register'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _doChangePass,
                            child: const Text('Change Password'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (message.isNotEmpty)
                      Text(
                        message,
                        style: TextStyle(
                          color: message.contains('Registered') || message.contains('changed')
                              ? Colors.green
                              : Colors.redAccent,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// =======================================================
/// HOME SHELL (tabs)
/// =======================================================
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const CalculatorPage(),
      const HistoryPage(),
      const MonthlyPage(),
      const SettingsPage(),
    ];
    final titles = ['Calculator', 'History', 'Monthly cumulative purchases', 'Settings'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calculate), label: 'Calc'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Monthly'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

/// =======================================================
/// CALCULATOR
/// =======================================================
class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final moneyC = TextEditingController();
  final actualC = TextEditingController();
  DateTime? _pickedDate;

  RegionTariff? _activeRegion;

  String _resultText = '';

  @override
  void initState() {
    super.initState();
    _loadRegion();
  }

  @override
  void dispose() {
    moneyC.dispose();
    actualC.dispose();
    super.dispose();
  }

  Future<void> _loadRegion() async {
    final email = await Auth.activeEmail();
    final customerType = email == null ? 'residential' : await Auth.customerTypeFor(email);
    // Latest-only is sufficient for header display
    final regions = await TariffManager.loadTariffsForType(customerType);
    final regionKey = await Auth.activeRegionKey();
    final fallbackKey = regions.isNotEmpty ? regions.first.regionKey : 'tshwane';
    // Use today's effective tariff for displaying in header
    final today = DateTime.now();
    final region = TariffManager.findRegionForDate(
            regions, regionKey ?? fallbackKey, today) ??
        (TariffManager.findRegion(regions, regionKey ?? fallbackKey) ?? regions.first);
    setState(() => _activeRegion = region);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now, // 👈 prevent selecting future dates
      initialDate: _pickedDate ?? now,
    );
    if (d != null) setState(() => _pickedDate = d);
  }

  Future<void> _calculateAndSave() async {
    final money = double.tryParse(moneyC.text.replaceAll(',', '.'));
    final actual = double.tryParse(actualC.text.replaceAll(',', '.'));

    if (money == null || money <= 0) {
      _toast('Please enter a valid amount');
      return;
    }
    if (actual == null || actual <= 0) {
      _toast('Please enter actual kWh received');
      return;
    }
    if (_activeRegion == null) {
      _toast('No region selected');
      return;
    }

    // Recompute expected per month cumulatively across all transactions
    // to respect IBT blocks across the month.
    final date = _pickedDate ?? DateTime.now();
    // Resolve the tariff version effective on the chosen date
    final email = await Auth.activeEmail();
    final customerType = email == null ? 'residential' : await Auth.customerTypeFor(email);
    // Use full history to pick by date
    final regions = await TariffManager.loadTariffsAll();
    final regionKey = _activeRegion?.regionKey ?? (await Auth.activeRegionKey()) ??
        (regions.isNotEmpty ? regions.first.regionKey : 'tshwane');
    final regionForDate = TariffManager.findRegionForDate(regions, regionKey, date) ??
        (TariffManager.findRegion(regions, regionKey) ?? regions.first);
    final monthKey = Store.monthKeyOf(date);

    final allBefore = await Store.loadTransactions();
    // Sort ascending by date to apply tiers in order
    final monthList = allBefore
        .where((t) => Store.monthKeyOf(t.date) == monthKey && t.regionKey == _activeRegion!.regionKey)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Recompute expected for each prior tx in this month using cumulative cursor
    double cursorBought = 0.0;
    final List<TransactionRecord> recomputed = [];
    for (final t in monthList) {
      // Use the tariff effective on each transaction's date
      final rT = TariffManager.findRegionForDate(regions, t.regionKey, t.date) ?? regionForDate;
      final exp = Calc.expectedKwhFromMoneyAt(t.money, rT.blocks, cursorBought);
      cursorBought += exp;
      recomputed.add(TransactionRecord(
        id: t.id,
        regionKey: t.regionKey,
        date: t.date,
        money: t.money,
        actualKwh: t.actualKwh,
        expectedKwh: exp,
      ));
    }

    // Expected for this new transaction continues from month cursor
    final expected = Calc.expectedKwhFromMoneyAt(money, regionForDate.blocks, cursorBought);
    final breakdown = Calc.breakdownForPurchase(money, regionForDate.blocks, cursorBought);
    final pct = Calc.percentDiff(expected, actual);
    final vat = Calc.vatPortion(money);
    final net = Calc.netExVat(money);
    final tx = TransactionRecord(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      regionKey: regionForDate.regionKey,
      date: date,
      money: money,
      actualKwh: actual,
      expectedKwh: expected,
    );

    // Merge recomputed month entries back with other months and save
    final all = await Store.loadTransactions();
    // Remove this month's entries for this region, replace with recomputed
    final filtered = all
        .where((t) => !(Store.monthKeyOf(t.date) == monthKey && t.regionKey == _activeRegion!.regionKey))
        .toList();
    filtered.addAll(recomputed);
    filtered.add(tx);
    // Keep same descending sort then cap in save
    filtered.sort((a, b) => b.date.compareTo(a.date));
    await Store.saveTransactions(filtered);
    await Store.includeMonth(Store.monthKeyOf(date));

    setState(() {
      final bd = breakdown.map((b) {
        final rng = b.to == null ? '${b.from}–∞' : '${b.from}–${b.to}';
        return 'Tier ${b.tierIndex} (${rng}) @ R${b.rate.toStringAsFixed(4)}/kWh -> '
               '${b.kwh.toStringAsFixed(2)} kWh, R${b.cost.toStringAsFixed(2)}';
      }).join('\n');

      _resultText =
          'Detailed calculation (month-cumulative)\n'
          'Region: ${regionForDate.displayName}\n'
          'Month-to-date before purchase: ${cursorBought.toStringAsFixed(2)} kWh\n'
          'Breakdown:\n${bd.isEmpty ? '(no spend)' : bd}\n'
          '---\n'
          'Expected (this purchase): ${expected.toStringAsFixed(2)} kWh\n'
          'Actual (this purchase): ${actual.toStringAsFixed(2)} kWh\n'
          'Difference: ${pct > 0 ? '+' : ''}${pct.toStringAsFixed(2)}%\n'
          'Net (ex VAT): R${net.toStringAsFixed(2)}\n'
          'VAT (15%): R${vat.toStringAsFixed(2)}\n'
          'Total paid: R${money.toStringAsFixed(2)}';
      moneyC.clear();
      actualC.clear();
      _pickedDate = null;
    });

    _toast('Saved transaction');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final regionName = _activeRegion?.displayName ?? '...';
    final dateLabel = _pickedDate == null
        ? 'Pick purchase date'
        : DateFormat('yyyy-MM-dd').format(_pickedDate!);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Region: $regionName',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: moneyC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Money spent (R, VAT incl.)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
              prefixText: 'R ',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: actualC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Actual kWh received',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
              suffixText: 'kWh',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.date_range),
            label: Text(dateLabel),
            style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _calculateAndSave,
            icon: const Icon(Icons.save),
            label: const Text('Calculate & Save'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
          const SizedBox(height: 12),
          // ⚠️ New disclaimer card about block pricing accuracy
          Card(
            color: Colors.orange.shade50,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Important: For accurate results, log every electricity purchase in a month. '
                'Because tariffs use block pricing, skipping any transaction can make the totals and comparisons incorrect.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_resultText.isNotEmpty)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_resultText, style: const TextStyle(fontSize: 15, height: 1.5)),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Note: Tariffs are treated as VAT-inclusive. The app auto-checks for updated tariffs yearly and uses your cached latest rates if offline.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================================================
/// HISTORY (last 20) with long-press delete
/// =======================================================
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<TransactionRecord> _tx = [];
  // Cache of computed detail strings per transaction id
  final Map<String, String> _detailsCache = {};
  // Track which transactions are currently computing details
  final Set<String> _loading = {};
  // Month filter state
  List<String> _months = [];
  String? _selectedMonth; // null or 'all' means show all

  @override
  void initState() {
    super.initState();
    _load();
    _loadMonths();
  }

  Future<void> _load() async {
    final list = await Store.loadTransactions();
    if (mounted) setState(() => _tx = list);
  }

  Future<void> _loadMonths() async {
    final months = await Store.loadMonthsDesc();
    if (mounted) {
      setState(() {
        _months = months;
        _selectedMonth ??= 'all';
      });
    }
  }

  Future<String> _computeDetails(TransactionRecord t) async {
    // Use customer type of active user if available (falls back to residential)
    final email = await Auth.activeEmail();
    final customerType = email == null ? 'residential' : await Auth.customerTypeFor(email);
    final regions = await TariffManager.loadTariffsAll();
    final region = TariffManager.findRegionForDate(regions, t.regionKey, t.date) ??
        (TariffManager.findRegion(regions, t.regionKey) ?? regions.first);

    // Compute month-to-date cursor before this transaction for the same region
    final monthKey = Store.monthKeyOf(t.date);
    final all = await Store.loadTransactions();
    final monthList = all
        .where((x) => Store.monthKeyOf(x.date) == monthKey && x.regionKey == t.regionKey)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    double cursorBought = 0.0;
    for (final x in monthList) {
      if (x.id == t.id) break;
      final expPrev = Calc.expectedKwhFromMoneyAt(x.money, region.blocks, cursorBought);
      cursorBought += expPrev;
    }

    final breakdown = Calc.breakdownForPurchase(t.money, region.blocks, cursorBought);
    final expected = Calc.expectedKwhFromMoneyAt(t.money, region.blocks, cursorBought);
    final pct = Calc.percentDiff(expected, t.actualKwh);
    final vat = Calc.vatPortion(t.money);
    final net = Calc.netExVat(t.money);

    final bd = breakdown.map((b) {
      final rng = b.to == null ? '${b.from}–' : '${b.from}–${b.to}';
      return 'Tier ${b.tierIndex} (${rng}) @ R${b.rate.toStringAsFixed(4)}/kWh -> '
          '${b.kwh.toStringAsFixed(2)} kWh, R${b.cost.toStringAsFixed(2)}';
    }).join('\n');

    final details =
        'Detailed calculation (month-cumulative)\n'
        'Region: ${region.displayName}\n'
        'Month-to-date before purchase: ${cursorBought.toStringAsFixed(2)} kWh\n'
        'Breakdown:\n${bd.isEmpty ? '(no spend)' : bd}\n'
        '---\n'
        'Expected (this purchase): ${expected.toStringAsFixed(2)} kWh\n'
        'Actual (this purchase): ${t.actualKwh.toStringAsFixed(2)} kWh\n'
        'Difference: ${pct > 0 ? '+' : ''}${pct.toStringAsFixed(2)}%\n'
        'Net (ex VAT): R${net.toStringAsFixed(2)}\n'
        'VAT (15%): R${vat.toStringAsFixed(2)}\n'
        'Total paid: R${t.money.toStringAsFixed(2)}';

    return details;
  }

  Future<void> _ensureDetails(TransactionRecord t) async {
    if (_detailsCache.containsKey(t.id) || _loading.contains(t.id)) return;
    setState(() => _loading.add(t.id));
    try {
      final s = await _computeDetails(t);
      if (mounted) setState(() => _detailsCache[t.id] = s);
    } finally {
      if (mounted) setState(() => _loading.remove(t.id));
    }
  }

  Future<void> _deleteTx(String id) async {
    final all = await Store.loadTransactions();
    all.removeWhere((t) => t.id == id);
    await Store.saveTransactions(all);
    await _load();
  }

  void _onLongPress(TransactionRecord t) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete transaction'),
              onTap: () async {
                Navigator.pop(context);
                await _deleteTx(t.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transaction deleted')),
                  );
                }
              },
            ),
            // Future options: Edit, Export
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = (_selectedMonth == null || _selectedMonth == 'all')
        ? _tx
        : _tx.where((t) => Store.monthKeyOf(t.date) == _selectedMonth).toList();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFAFAFA), Color(0xFFECEFF1)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView(
        children: [
          // Filter control
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedMonth ?? 'all',
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All months')),
                          ..._months.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                        ],
                        onChanged: (v) => setState(() => _selectedMonth = v),
                        decoration: const InputDecoration(
                          labelText: 'Filter by month',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No transactions for this filter.')),
            )
          else
            ...filtered.map((t) {
              final df = DateFormat('yyyy-MM-dd').format(t.date);
              final pct = Calc.percentDiff(t.expectedKwh, t.actualKwh);
              final pctColor = Colors.red;
              final details = _detailsCache[t.id];
              final isLoading = _loading.contains(t.id);
              return GestureDetector(
                onLongPress: () => _onLongPress(t),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    onExpansionChanged: (expanded) {
                      if (expanded) _ensureDetails(t);
                    },
                    title: Text('R${t.money.toStringAsFixed(2)} • $df'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expected: ${t.expectedKwh.toStringAsFixed(2)} kWh • '
                          'Actual: ${t.actualKwh.toStringAsFixed(2)} kWh',
                        ),
                        Text(
                          'Difference: ${pct > 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
                          style: TextStyle(color: pctColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: isLoading && details == null
                              ? const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('Loading details...'),
                                )
                              : Text(
                                  details ?? 'Tap to load details',
                                  style: const TextStyle(fontSize: 14, height: 1.5),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// =======================================================
/// MONTHLY (last 5) with auto-reset + long-press delete
/// =======================================================
class MonthlyPage extends StatefulWidget {
  const MonthlyPage({super.key});

  @override
  State<MonthlyPage> createState() => _MonthlyPageState();
}

class _MonthlyPageState extends State<MonthlyPage> {
  List<String> _months = [];
  MonthlySummary? _currentSummary;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final months = await Store.loadMonthsDesc();
    MonthlySummary? current;
    if (months.isNotEmpty) current = await Store.computeSummary(months.first);
    if (mounted) {
      setState(() {
        _months = months;
        _currentSummary = current;
      });
    }
  }

  Future<void> _resetCurrentMonth() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Current Month?'),
        content: const Text('This will delete all transactions for the current month.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await Store.resetCurrentMonth();
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current month reset')),
        );
      }
    }
  }

  void _onLongPressMonth(String monthKey) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text('Delete $monthKey'),
              onTap: () async {
                Navigator.pop(context);
                await Store.deleteMonth(monthKey);
                await _reload();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted $monthKey')),
                  );
                }
              },
            ),
            // Future options: Export month CSV, Edit month notes, etc.
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nowKey = Store.monthKeyOf(DateTime.now());

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF1F8E9), Color(0xFFE8F5E9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text('Current month: $nowKey',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _resetCurrentMonth,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_currentSummary != null)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _SummaryView(summary: _currentSummary!),
              ),
            )
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No data for the current month yet.'),
              ),
            ),
          const SizedBox(height: 12),
          const Text('Last 5 months:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._months.map((m) => Card(
                child: ListTile(
                  title: Text(m, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: FutureBuilder<MonthlySummary>(
                    future: Store.computeSummary(m),
                    builder: (_, snap) {
                      if (!snap.hasData) return const Text('Loading...');
                      final s = snap.data!;
                      final pct = s.percentDiff;
                      final pctColor = Colors.red;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Transactions: ${s.transactions}'),
                          Text('Spent: R${s.totalMoney.toStringAsFixed(2)}'),
                          Text('kWh: ${s.totalActualKwh.toStringAsFixed(2)} (actual) / '
                              '${s.totalExpectedKwh.toStringAsFixed(2)} (expected)'),
                          Text(
                            'Difference: ${pct > 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
                            style: TextStyle(color: pctColor, fontWeight: FontWeight.w600),
                          ),
                          Text('VAT (15%): R${s.vatPortion.toStringAsFixed(2)} • '
                              'Net: R${s.netExVat.toStringAsFixed(2)}'),
                        ],
                      );
                    },
                  ),
                  onLongPress: () => _onLongPressMonth(m),
                ),
              )),
        ],
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  final MonthlySummary summary;
  const _SummaryView({required this.summary});

  @override
  Widget build(BuildContext context) {
    final pct = summary.percentDiff;
    final pctColor = Colors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Month: ${summary.monthKey}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const Divider(),
        Text('Transactions: ${summary.transactions}'),
        Text('Total spent: R${summary.totalMoney.toStringAsFixed(2)}'),
        Text('Net (ex VAT): R${summary.netExVat.toStringAsFixed(2)}'),
        Text('VAT (15%): R${summary.vatPortion.toStringAsFixed(2)}'),
        const SizedBox(height: 6),
        Text('Expected kWh: ${summary.totalExpectedKwh.toStringAsFixed(2)}'),
        Text('Actual kWh: ${summary.totalActualKwh.toStringAsFixed(2)}'),
        Text(
          'Difference: ${pct > 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
          style: TextStyle(color: pctColor, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// =======================================================
/// SETTINGS
/// =======================================================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<RegionTariff> _regions = [];
  String? _currentRegionKey;
  String? _email;
  String? _lastUpdated;
  String _customerType = 'residential';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final email = await Auth.activeEmail();
    final ct = email == null ? 'residential' : await Auth.customerTypeFor(email);
    final regions = await TariffManager.loadTariffsForType(ct);
    final rk = await Auth.activeRegionKey();

    final prefs = await SharedPreferences.getInstance();
    final updatedAt = prefs.getString('tariffs_updated_at');

    setState(() {
      _regions = regions;
      _email = email;
      _currentRegionKey = rk ?? (regions.isNotEmpty ? regions.first.regionKey : null);
      _customerType = ct;
      if (updatedAt != null) {
        final date = DateTime.parse(updatedAt);
        _lastUpdated = DateFormat('yyyy-MM-dd HH:mm').format(date);
      }
    });
  }

  RegionTariff? _currentRegion() {
    if (_currentRegionKey == null || _regions.isEmpty) return null;
    final today = DateTime.now();
    return TariffManager.findRegionForDate(_regions, _currentRegionKey!, today)
        ?? TariffManager.findRegion(_regions, _currentRegionKey!)
        ?? _regions.first;
  }

  Future<void> _saveRegion(String key) async {
    if (_email != null) {
      await Auth.setRegion(_email!, key);
      setState(() => _currentRegionKey = key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Region saved')),
        );
      }
    }
  }

  Future<void> _checkTariffUpdate() async {
    await TariffManager.tryAutoUpdate();
    await _init(); // refresh UI + last updated
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checked for tariff updates')),
      );
    }
  }

  Future<void> _resetTariffs() async {
    await TariffManager.resetToBuiltins();
    await _init();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tariffs reset to built-ins (Sep 2025)')),
      );
    }
  }

  Future<void> _showPreviousFiveYears() async {
    final rk = _currentRegionKey;
    if (rk == null) return;
    final all = await TariffManager.loadTariffsAll();
    // Filter this region, sort newest->oldest
    final list = all.where((r) => r.regionKey == rk).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    // Identify the current effective entry (today)
    final today = DateTime.now();
    final current = TariffManager.findRegionForDate(list, rk, today) ??
        (list.isNotEmpty ? list.first : null);

    // Take up to 5 entries older than current (previous years)
    final previous = list.where((r) => current == null || r.startDate.isBefore(current.startDate))
        .take(5)
        .toList();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: previous.isEmpty
              ? const Text('No historical tariffs available for the last 5 years.',
                  style: TextStyle(fontSize: 16))
              : ListView(
                  children: [
                    const Text('Previous 5 years — Incline Blocks',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    ...previous.map((r) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Effective: '
                                  '${DateFormat('yyyy-MM-dd').format(r.startDate)} '
                                  'to '
                                  '${r.endDate == null ? 'ongoing' : DateFormat('yyyy-MM-dd').format(r.endDate!)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                ...r.blocks.map((b) {
                                  final range = b.to == null ? '${b.from}–' : '${b.from}–${b.to}';
                                  return Text('$range: R${b.rate.toStringAsFixed(4)}/kWh');
                                }),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await Auth.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Resolve a friendly region name without allowing edits here.
    String regionName;
    try {
      final today = DateTime.now();
      final r = TariffManager.findRegionForDate(
              _regions, _currentRegionKey ?? '', today) ??
          (_currentRegionKey == null
              ? null
              : TariffManager.findRegion(_regions, _currentRegionKey!));
      regionName = r?.displayName ?? (_currentRegionKey ?? 'Unknown');
    } catch (_) {
      regionName = _currentRegionKey ?? 'Unknown';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Region', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(regionName),
            subtitle: const Text('Set during sign in/registration'),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Customer Type', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _customerType,
          items: const [
            DropdownMenuItem(value: 'residential', child: Text('Residential')),
            DropdownMenuItem(value: 'commercial', child: Text('Commercial')),
          ],
          onChanged: (v) async {
            if (v != null && _email != null) {
              await Auth.setCustomerType(_email!, v);
              // Reload regions for the selected customer type
              final regions = await TariffManager.loadTariffsForType(v);
              String? rk = _currentRegionKey;
              if (regions.indexWhere((r) => r.regionKey == rk) < 0) {
                rk = regions.isNotEmpty ? regions.first.regionKey : null;
              }
              setState(() {
                _customerType = v;
                _regions = regions;
                _currentRegionKey = rk;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Customer type saved')),
                );
              }
            }
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Select Customer Type',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _showPreviousFiveYears,
          icon: const Icon(Icons.history_toggle_off),
          label: const Text("View previous 5 years' tariffs"),
        ),
        const SizedBox(height: 16),
        // Show effective dates and incline blocks for the current region
        if (_currentRegion() != null) ...[
          const Text('Incline Blocks', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(builder: (_) {
                    final r = _currentRegion()!;
                    final sd = DateFormat('yyyy-MM-dd').format(r.startDate);
                    final ed = r.endDate == null
                        ? 'ongoing'
                        : DateFormat('yyyy-MM-dd').format(r.endDate!);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('Effective: $sd to $ed',
                          style: const TextStyle(color: Colors.black54)),
                    );
                  }),
                  ..._currentRegion()!.blocks.map((b) {
                    final range = b.to == null ? '${b.from}–' : '${b.from}–${b.to}';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('$range: R${b.rate.toStringAsFixed(4)}/kWh'),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _checkTariffUpdate,
          icon: const Icon(Icons.system_update),
          label: const Text('Check tariff updates now'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _resetTariffs,
          icon: const Icon(Icons.refresh),
          label: const Text('Reset tariffs to built-ins (Sep 2025)'),
        ),
        if (_lastUpdated != null) ...[
          const SizedBox(height: 8),
          Text('Tariffs last updated: $_lastUpdated',
              style: const TextStyle(color: Colors.black54)),
        ],
        const SizedBox(height: 24),
        FilledButton.tonalIcon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
        const SizedBox(height: 24),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Tips:\n'
              '• Long-press a transaction to delete it.\n'
              '• Long-press a month to delete its data.\n'
              '• Monthly stats auto-reset when a new month starts (last 5 months kept).',
            ),
          ),
        ),
      ],
    );
  }
}
