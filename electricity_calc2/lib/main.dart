import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://qzcziazzbyvidawwlnen.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6Y3ppYXp6Ynl2aWRhd3dsbmVuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NjUxMzAsImV4cCI6MjA3NzE0MTEzMH0.lheIfO7B9d0a0Qhp5Hgg8jco1g6_Pn1U2EgCcwwddYk',
  );
  runApp(const GautengElecApp());
}

/// =======================================================
/// ROOT
/// =======================================================
class GautengElecApp extends StatelessWidget {
  const GautengElecApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(seedColor: Colors.deepOrange);
    final scheme = baseScheme.copyWith(
      primary: Colors.deepOrange.shade400,
      onPrimary: Colors.white,
      secondary: Colors.amber.shade600,
      onSecondary: Colors.black87,
      secondaryContainer: Colors.amber.shade100,
      tertiary: Colors.orangeAccent.shade100,
      surface: const Color(0xFFFFF9F0),
    );
    return MaterialApp(
      title: 'Gauteng Electricity Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: scheme.surface,
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: scheme.primary.withValues(alpha: 0.08),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: scheme.secondary,
          contentTextStyle: TextStyle(color: scheme.onSecondary),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
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
    await TariffManager.ensureTariffs();   // validate cached tariffs
    await TariffManager.tryAutoUpdate();   // monthly check for remote updates

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

  TransactionRecord copyWith({
    String? id,
    String? regionKey,
    DateTime? date,
    double? money,
    double? actualKwh,
    double? expectedKwh,
  }) {
    return TransactionRecord(
      id: id ?? this.id,
      regionKey: regionKey ?? this.regionKey,
      date: date ?? this.date,
      money: money ?? this.money,
      actualKwh: actualKwh ?? this.actualKwh,
      expectedKwh: expectedKwh ?? this.expectedKwh,
    );
  }

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

  factory TransactionRecord.fromSupabase(Map<String, dynamic> row) =>
      TransactionRecord(
        id: (row['id'] ?? '').toString(),
        regionKey: (row['region_key'] as String?) ?? '',
        date: DateTime.parse(row['purchased_at'] as String),
        money: (row['amount'] as num).toDouble(),
        actualKwh: (row['energy_kwh'] as num?)?.toDouble() ?? 0,
        expectedKwh: (row['expected_kwh'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toSupabaseMap({required String userId}) => {
        'user_id': userId,
        'region_key': regionKey,
        'amount': money,
        'energy_kwh': actualKwh,
        'expected_kwh': expectedKwh,
        'purchased_at': date.toIso8601String(),
      };
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

class SupportMessage {
  final String sender; // 'user' | 'admin'
  final String body;
  final DateTime timestamp;
  final bool readByUser;
  final bool readByAdmin;

  const SupportMessage({
    required this.sender,
    required this.body,
    required this.timestamp,
    required this.readByUser,
    required this.readByAdmin,
  });

  SupportMessage copyWith({bool? readByUser, bool? readByAdmin}) => SupportMessage(
        sender: sender,
        body: body,
        timestamp: timestamp,
        readByUser: readByUser ?? this.readByUser,
        readByAdmin: readByAdmin ?? this.readByAdmin,
      );

  Map<String, dynamic> toJson() => {
        'sender': sender,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'readByUser': readByUser,
        'readByAdmin': readByAdmin,
      };

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
        sender: json['sender'] as String,
        body: json['body'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        readByUser: json['readByUser'] == true,
        readByAdmin: json['readByAdmin'] == true,
      );
}

class QueryThread {
  final String userEmail;
  final List<SupportMessage> messages;

  const QueryThread({required this.userEmail, required this.messages});

  QueryThread append(SupportMessage message) => QueryThread(
        userEmail: userEmail,
        messages: [...messages, message],
      );

  QueryThread markReadByUser() => QueryThread(
        userEmail: userEmail,
        messages: messages
            .map((m) => m.sender == 'admin' ? m.copyWith(readByUser: true) : m)
            .toList(),
      );

  QueryThread markReadByAdmin() => QueryThread(
        userEmail: userEmail,
        messages: messages
            .map((m) => m.sender == 'user' ? m.copyWith(readByAdmin: true) : m)
            .toList(),
      );

  int get unreadForUser => messages
      .where((m) => m.sender == 'admin' && !m.readByUser)
      .length;

  int get unreadForAdmin => messages
      .where((m) => m.sender == 'user' && !m.readByAdmin)
      .length;

  DateTime? get lastTimestamp => messages.isEmpty ? null : messages.last.timestamp;

  Map<String, dynamic> toJson() => {
        'userEmail': userEmail,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory QueryThread.fromJson(Map<String, dynamic> json) => QueryThread(
        userEmail: json['userEmail'] as String,
        messages: (json['messages'] as List<dynamic>? ?? [])
            .map((e) => SupportMessage.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class QueryStore {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<String?> _userIdForEmail(String email) async {
    return Auth.userIdForEmail(email);
  }

  static SupportMessage _messageFromRow(Map<String, dynamic> row) {
    return SupportMessage(
      sender: (row['sender'] as String?) ?? 'user',
      body: (row['body'] as String?) ?? '',
      timestamp: DateTime.parse(row['created_at'] as String),
      readByUser: row['read_by_user'] == true,
      readByAdmin: row['read_by_admin'] == true,
    );
  }

  static Future<QueryThread> threadFor(String email) async {
    final canonical = Auth.canonicalEmail(email);
    final userId = await _userIdForEmail(canonical);
    if (userId == null) {
      return QueryThread(userEmail: canonical, messages: const []);
    }
    final rows = await _client
        .from('user_queries')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: true);
    final messages = rows
        .map((row) => _messageFromRow(Map<String, dynamic>.from(row)))
        .toList();
    return QueryThread(userEmail: canonical, messages: messages);
  }

  static Future<void> addMessage({
    required String userEmail,
    required SupportMessage message,
  }) async {
    final canonical = Auth.canonicalEmail(userEmail);
    final userId = await _userIdForEmail(canonical);
    if (userId == null) return;
    final isAdmin = message.sender == 'admin';
    final payload = {
      'user_id': userId,
      'subject': message.sender == 'admin' ? 'Admin message' : 'User message',
      'sender': message.sender,
      'body': message.body,
      'created_at': message.timestamp.toIso8601String(),
      'read_by_user': isAdmin ? false : true,
      'read_by_admin': isAdmin ? true : false,
    };
    try {
      await _client.from('user_queries').insert(payload);
    } catch (err) {
      if (kDebugMode) {
        debugPrint('Failed to insert query message: $err');
      }
    }
    await RemoteLog.queryMessage(userEmail: canonical, message: message);
  }

  static Future<void> markReadByUser(String userEmail) async {
    final canonical = Auth.canonicalEmail(userEmail);
    final userId = await _userIdForEmail(canonical);
    if (userId == null) return;
    try {
      await _client
          .from('user_queries')
          .update({'read_by_user': true})
          .eq('user_id', userId)
          .eq('sender', 'admin');
    } catch (err) {
      if (kDebugMode) debugPrint('Failed to mark user queries read: $err');
    }
  }

  static Future<void> markReadByAdmin(String userEmail) async {
    final canonical = Auth.canonicalEmail(userEmail);
    final userId = await _userIdForEmail(canonical);
    if (userId == null) return;
    try {
      await _client
          .from('user_queries')
          .update({'read_by_admin': true})
          .eq('user_id', userId)
          .eq('sender', 'user');
    } catch (err) {
      if (kDebugMode) debugPrint('Failed to mark admin queries read: $err');
    }
  }

  static Future<int> unreadForUser(String userEmail) async {
    final canonical = Auth.canonicalEmail(userEmail);
    final userId = await _userIdForEmail(canonical);
    if (userId == null) return 0;
    final rows = await _client
        .from('user_queries')
        .select()
        .eq('user_id', userId)
        .eq('sender', 'admin')
        .eq('read_by_user', false);
    return rows.length;
  }

  static Future<int> unreadForAdmin() async {
    final rows = await _client
        .from('user_queries')
        .select()
        .eq('sender', 'user')
        .eq('read_by_admin', false);
    return rows.length;
  }

  static Future<List<QueryThread>> allSorted() async {
    final rows = await _client
        .from('user_queries')
        .select()
        .order('created_at', ascending: true);
    final Map<String, List<SupportMessage>> grouped = {};
    for (final raw in rows) {
      final map = Map<String, dynamic>.from(raw);
      final userId = map['user_id'] as String?;
      if (userId == null || userId.isEmpty) continue;
      grouped.putIfAbsent(userId, () => []).add(_messageFromRow(map));
    }
    final threads = <QueryThread>[];
    for (final entry in grouped.entries) {
      final email = await Auth.emailForUserId(entry.key) ?? entry.key;
      threads.add(QueryThread(userEmail: email, messages: entry.value));
    }
    threads.sort((a, b) {
      final aTime = a.lastTimestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastTimestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return threads;
  }
}

/// =======================================================
/// TARIFF MANAGER: cached remote tariffs + monthly fetch
/// =======================================================
class TariffManager {
  // TODO: Replace with your hosted JSON (GitHub raw / Firebase / S3)
  static const String tariffsUrl =
      'https://damic3.github.io/electricity_calc/tariffs.json';

  /// Validate cached tariffs and clear them if they look malformed.
  static Future<void> ensureTariffs() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('tariffs_json');
    if (cached == null) return;
    try {
      final data = jsonDecode(cached);
      if (data is! Map<String, dynamic>) {
        await clearTariffs();
        return;
      }
      if (data['regions'] is! List) {
        await clearTariffs();
        return;
      }
    } catch (_) {
      await clearTariffs();
    }
  }

  // Latest effective tariff per region (deduplicated by regionKey)
  static Future<List<RegionTariff>> loadTariffs() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('tariffs_json');
    if (s == null) return [];
    try {
      final data = jsonDecode(s);
      if (data is Map<String, dynamic> && data['regions'] is List) {
        final parsed = (data['regions'] as List)
            .map((e) => RegionTariff.fromJson(e))
            .toList();
        final Map<String, RegionTariff> latest = {};
        for (final r in parsed) {
          final prev = latest[r.regionKey];
          if (prev == null || r.startDate.isAfter(prev.startDate)) {
            latest[r.regionKey] = r;
          }
        }
        return latest.values.toList();
      }
    } catch (_) {
      // ignore malformed cached tariffs
    }
    return [];
  }

  // For now both residential and commercial return the same list until
  // distinct commercial blocks are supplied remotely.
  static Future<List<RegionTariff>> loadTariffsForType(String customerType) async {
    return loadTariffs();
  }

  // Full list with history (multiple entries per regionKey).
  static Future<List<RegionTariff>> loadTariffsAll() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('tariffs_json');
    if (s == null) return [];
    try {
      final data = jsonDecode(s);
      if (data is Map<String, dynamic> && data['regions'] is List) {
        return (data['regions'] as List)
            .map((e) => RegionTariff.fromJson(e))
            .toList();
      }
    } catch (_) {
      // ignore malformed cached tariffs
    }
    return [];
  }

  /// Clear any cached tariff data. Use once remote data is updated.
  static Future<void> clearTariffs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tariffs_json');
    await prefs.remove('tariffs_updated_year');
    await prefs.remove('tariffs_updated_at');
    await prefs.remove('tariffs_checked_month');
  }

  /// Auto update (once per calendar month, or if no cached tariffs exist).
  static Future<void> tryAutoUpdate({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('tariffs_json');
    final bool hasCachedTariffs = cached != null;

    final now = DateTime.now();
    final nowMonth = DateFormat('yyyy-MM').format(now);
    final lastCheckedMonth = prefs.getString('tariffs_checked_month');

    if (!force && hasCachedTariffs && lastCheckedMonth == nowMonth) {
      return;
    }

    bool updated = false;
    try {
      final res = await http
          .get(Uri.parse(tariffsUrl))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final dynamic data = jsonDecode(res.body);
        if (data is Map && data['regions'] is List) {
          await prefs.setString('tariffs_json', res.body);
          final versionYear = data['versionYear'];
          if (versionYear is int) {
            await prefs.setInt('tariffs_updated_year', versionYear);
          } else {
            await prefs.remove('tariffs_updated_year');
          }
          await prefs.setString(
              'tariffs_updated_at', DateTime.now().toIso8601String());
          updated = true;
        }
      }
    } catch (_) {
      // swallow -> keep cached data or try again later
    }

    if (updated || hasCachedTariffs) {
      await prefs.setString('tariffs_checked_month', nowMonth);
    } else {
      await prefs.remove('tariffs_checked_month');
    }
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
/// AUTH (Supabase-backed)
/// =======================================================
class Auth {
  static const _usersTable = 'app_users';
  static const _activeKey = 'active_email';
  static const _activeRegionSessionKey = 'active_region_key';
  static const _activeUserIdKey = 'active_user_id';
  static const _lastLoginEmailKey = 'last_login_email';
  static const _lastLoginPasswordKey = 'last_login_password';
  static const _customerTypePrefPrefix = 'customer_type_local__';
  static const _passwordPrefPrefix = 'password_local__';
  static const _syntheticDomain = 'app.local';

  static const String _adminEmail = 'mic';

  static bool _adminActive = false;
  static bool _adminEditMode = false;
  static String? _adminImpersonatingEmail;
  static String? _adminImpersonatingUserId;
  static String? _activeUserId;
  static int _sessionGeneration = 0;

  static SupabaseClient get _client => Supabase.instance.client;
  static GoTrueClient get _auth => _client.auth;

  static String _canonicalEmail(String raw) => raw.trim().toLowerCase();
  static String canonicalEmail(String raw) => _canonicalEmail(raw);

  static int get sessionGeneration => _sessionGeneration;
  static bool get isAdminActive => _adminActive;
  static bool get isAdminViewing => _adminActive && _adminImpersonatingEmail != null;
  static bool get adminEditMode => _adminEditMode;
  static String? get adminImpersonatingEmail => _adminImpersonatingEmail;
  static bool get canModifyData => !_adminActive || _adminEditMode;

  static void _bumpSession() {
    _sessionGeneration++;
  }

  static String _normalizeLoginEmail(String raw) {
    final trimmed = raw.trim();
    if (trimmed.contains('@')) return trimmed.toLowerCase();
    return '${trimmed.toLowerCase()}@$_syntheticDomain';
  }

  static Map<String, dynamic> _normalizeRow(dynamic row) {
    if (row is Map<String, dynamic>) return row;
    return Map<String, dynamic>.from(row as Map);
  }

  static Future<Map<String, dynamic>?> _fetchUser(String email) async {
    try {
      final canonical = _canonicalEmail(email);
      final result = await _client
          .from(_usersTable)
          .select()
          .eq('email', canonical)
          .maybeSingle();
      if (result == null) return null;
      return _normalizeRow(result);
    } on PostgrestException catch (err) {
      debugPrint('Supabase fetch user failed: ${err.code} ${err.message}');
      return null;
    } catch (err) {
      debugPrint('Unknown fetch user error: $err');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchAllUsers() async {
    final List<dynamic> result = await _client.from(_usersTable).select();
    return result.map(_normalizeRow).toList();
  }

  static bool _isAdminRow(Map<String, dynamic>? row) {
    if (row == null) return false;
    final value = row['is_admin'];
    if (value is bool) return value;
    if (value is int) return value != 0;
    return false;
  }

  static String? _remoteCustomerType(Map<String, dynamic>? row) {
    if (row == null) return null;
    final value = row['customer_type'] ?? row['customerType'];
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  static String _customerTypePrefKey(String email) =>
      '$_customerTypePrefPrefix${_canonicalEmail(email)}';
  static String _passwordPrefKey(String email) =>
      '$_passwordPrefPrefix${_canonicalEmail(email)}';

  static Future<void> _cacheCustomerType(String email, String type) async {
    final canonical = _canonicalEmail(email);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customerTypePrefKey(canonical), type);
  }

  static Future<String?> _cachedCustomerType(String email) async {
    final canonical = _canonicalEmail(email);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customerTypePrefKey(canonical));
  }

  static Future<bool> _tryUpdateUser(String email, Map<String, dynamic> values) async {
    if (values.isEmpty) return true;
    final canonical = _canonicalEmail(email);
    if (values.containsKey('email')) {
      values['email'] = canonical;
    }
    try {
      await _client.from(_usersTable).update(values).eq('email', canonical);
      return true;
    } on PostgrestException catch (err) {
      debugPrint('Supabase update user failed: ${err.code} ${err.message}');
      if (err.code == '42703') {
        final fallback = Map<String, dynamic>.from(values)
          ..remove('customer_type')
          ..remove('password');
        if (fallback.isEmpty || mapEquals(fallback, values)) return false;
        try {
          await _client.from(_usersTable).update(fallback).eq('email', canonical);
          return true;
        } catch (error) {
          debugPrint('Supabase update fallback failed for $email: $error');
          return false;
        }
      }
      return false;
    } catch (error) {
      debugPrint('Unknown update user error for $email: $error');
      return false;
    }
  }

  static Future<bool> _tryInsertUser(Map<String, dynamic> values) async {
    final payload = Map<String, dynamic>.from(values);
    final emailValue = payload['email'];
    if (emailValue is String) {
      payload['email'] = _canonicalEmail(emailValue);
    }
    try {
      await _client.from(_usersTable).insert(payload);
      return true;
    } on PostgrestException catch (err) {
      debugPrint('Supabase insert user failed: ${err.code} ${err.message}');
      if (err.code == '42703') {
        final fallback = Map<String, dynamic>.from(payload)
          ..remove('customer_type')
          ..remove('password');
        if (fallback.isEmpty || mapEquals(fallback, values)) return false;
        try {
          await _client.from(_usersTable).insert(fallback);
          return true;
        } catch (error) {
          debugPrint('Supabase insert fallback failed for values $fallback: $error');
          return false;
        }
      }
      return false;
    } catch (error) {
      debugPrint('Unknown insert user error: $error');
      return false;
    }
  }

  static Future<void> _setActiveSession(
    String email, {
    required bool isAdmin,
    required String userId,
    String? password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, email);
    await prefs.setString(_lastLoginEmailKey, email);
    if (password != null && password.isNotEmpty) {
      await prefs.setString(_lastLoginPasswordKey, password);
      await prefs.setString(_passwordPrefKey(email), password);
    }
    await prefs.setString(_activeUserIdKey, userId);
    _activeUserId = userId;
    _adminActive = isAdmin;
    _adminEditMode = false;
    _adminImpersonatingEmail = null;
    _adminImpersonatingUserId = null;
    _bumpSession();
  }

  static Future<bool> register({
    required String email,
    required String password,
    required String regionKey,
    required String customerType,
  }) async {
    final canonical = _canonicalEmail(email);
    final loginEmail = _normalizeLoginEmail(email);
    if (canonical == _adminEmail) return false;
    try {
      final response = await _auth.signUp(email: loginEmail, password: password);
      final user = response.user;
      if (user == null) return false;
      final payload = <String, dynamic>{
        'email': canonical,
        'password': password,
        'user_id': user.id,
        'region_key': regionKey,
        'customer_type': customerType,
        'is_admin': false,
      };
      final inserted = await _tryInsertUser(payload);
      if (!inserted) {
        await _tryUpdateUser(canonical, {
          'password': password,
          'user_id': user.id,
          'region_key': regionKey,
          'customer_type': customerType,
        });
      }
      await _cacheCustomerType(canonical, customerType);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_passwordPrefKey(canonical), password);
      await _auth.signOut();
      return true;
    } on AuthException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> login({
    required String email,
    required String password,
  }) async {
    final canonical = _canonicalEmail(email);
    final loginEmail = _normalizeLoginEmail(email);
    try {
      final response = await _auth.signInWithPassword(email: loginEmail, password: password);
      final user = response.user;
      if (user == null) return false;

      Map<String, dynamic>? row = await _fetchUser(canonical);
      if (row == null) {
        final inserted = await _tryInsertUser({
          'email': canonical,
          'password': password,
          'user_id': user.id,
          'region_key': null,
          'customer_type': 'residential',
          'is_admin': false,
        });
        if (inserted) {
          row = await _fetchUser(canonical);
        }
      } else if ((row['user_id'] == null) ||
          (row['user_id'] is String && (row['user_id'] as String).isEmpty)) {
        await _tryUpdateUser(canonical, {'user_id': user.id});
        row = await _fetchUser(canonical);
      }
      await _tryUpdateUser(canonical, {'password': password});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_passwordPrefKey(canonical), password);

      final isAdmin = _isAdminRow(row);
      await _setActiveSession(canonical,
          password: password, isAdmin: isAdmin, userId: user.id);

      final region = row?['region_key'];
      if (region is String && region.isNotEmpty) {
        await setActiveRegionKey(region);
      } else if (!isAdmin) {
        final savedRegion = await regionFor(canonical);
        if (savedRegion != null) {
          await setActiveRegionKey(savedRegion);
        }
      }

      final remoteCustomerType = _remoteCustomerType(row);
      if (remoteCustomerType != null) {
        await _cacheCustomerType(canonical, remoteCustomerType);
      }

      return true;
    } on AuthException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> loginWithPreviousDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final lastEmail = prefs.getString(_lastLoginEmailKey);
    final lastPassword = prefs.getString(_lastLoginPasswordKey);
    if (lastEmail == null ||
        lastEmail.isEmpty ||
        lastPassword == null ||
        lastPassword.isEmpty) {
      return false;
    }
    return login(email: lastEmail, password: lastPassword);
  }

  static Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Ignore auth sign-out errors; we'll still clear local state.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
    await prefs.remove(_activeRegionSessionKey);
    await prefs.remove(_activeUserIdKey);
    _adminActive = false;
    _adminEditMode = false;
    _adminImpersonatingEmail = null;
    _adminImpersonatingUserId = null;
    _activeUserId = null;
    _bumpSession();
  }

  static Future<bool> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    final canonical = _canonicalEmail(email);
    final loginEmail = _normalizeLoginEmail(email);
    try {
      final signInResponse =
          await _auth.signInWithPassword(email: loginEmail, password: currentPassword);
      final user = signInResponse.user;
      if (user == null) return false;
      await _auth.updateUser(UserAttributes(password: newPassword));
      await _tryUpdateUser(canonical, {'password': newPassword});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastLoginPasswordKey, newPassword);
      await prefs.setString(_passwordPrefKey(canonical), newPassword);
      await _auth.signOut();
      return true;
    } on AuthException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> activeEmail() async {
    if (_adminActive && _adminImpersonatingEmail != null) {
      return _adminImpersonatingEmail;
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_activeKey);
    if (_adminActive) {
      return stored ?? _adminEmail;
    }
    return stored;
  }

  static Future<String?> activeUserId() async {
    if (_adminActive && _adminImpersonatingEmail != null) {
      if (_adminImpersonatingUserId != null && _adminImpersonatingUserId!.isNotEmpty) {
        return _adminImpersonatingUserId;
      }
      final row = await _fetchUser(_adminImpersonatingEmail!);
      final uid = row?['user_id'] as String?;
      _adminImpersonatingUserId = uid;
      return uid;
    }
    if (_activeUserId != null && _activeUserId!.isNotEmpty) {
      return _activeUserId;
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_activeUserIdKey);
    _activeUserId = stored;
    return stored;
  }

  static Future<String?> actorUserId() async {
    if (_adminActive && _adminImpersonatingEmail != null) {
      if (_activeUserId != null && _activeUserId!.isNotEmpty) return _activeUserId;
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_activeUserIdKey);
      _activeUserId = stored;
      return stored;
    }
    return activeUserId();
  }

  static Future<String?> userIdForEmail(String email) async {
    final row = await _fetchUser(email);
    final uid = row?['user_id'];
    if (uid is String && uid.isNotEmpty) return uid;
    return null;
  }

  static Future<String?> emailForUserId(String userId) async {
    final rows = await _fetchAllUsers();
    for (final row in rows) {
      final uid = row['user_id'];
      if (uid is String && uid.isNotEmpty && uid == userId) {
        final email = row['email'];
        if (email is String && email.isNotEmpty) {
          return email;
        }
      }
    }
    return null;
  }

  static Future<String?> regionFor(String email) async {
    final row = await _fetchUser(email);
    final region = row?['region_key'];
    if (region is String && region.isNotEmpty) return region;
    return null;
  }

  static Future<void> setRegion(String email, String regionKey) async {
    final canonical = _canonicalEmail(email);
    if (_adminActive && !_adminEditMode && canonical != _adminEmail) return;
    final ok = await _tryUpdateUser(canonical, {'region_key': regionKey});
    if (ok && (_adminImpersonatingEmail == canonical || !isAdminActive)) {
      await setActiveRegionKey(regionKey);
    }
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
    final row = await _fetchUser(email);
    final remote = _remoteCustomerType(row);
    if (remote != null) {
      await _cacheCustomerType(email, remote);
      return remote;
    }
    final cached = await _cachedCustomerType(email);
    return cached ?? 'residential';
  }

  static Future<void> setCustomerType(String email, String type) async {
    final canonical = _canonicalEmail(email);
    if (_adminActive && !_adminEditMode && canonical != _adminEmail) return;
    await _cacheCustomerType(canonical, type);
    await _tryUpdateUser(canonical, {'customer_type': type});
  }

  static Future<String?> storedPassword(String email) async {
    try {
      final row = await _fetchUser(email);
      final password = row?['password'];
      if (password is String && password.isNotEmpty) {
        return password;
      }
    } catch (_) {
      // ignore
    }
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_passwordPrefKey(email));
    if (cached != null && cached.isNotEmpty) return cached;
    return null;
  }

  static Future<Map<String, dynamic>> allUsers() async {
    final rows = await _fetchAllUsers();
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    for (final row in rows) {
      final email = row['email'];
      if (email is! String || email.isEmpty) continue;
      final customerType =
          _remoteCustomerType(row) ?? prefs.getString(_customerTypePrefKey(email)) ?? 'residential';
      map[email] = {
        'regionKey': row['region_key'] as String?,
        'customerType': customerType,
        'userId': row['user_id'] as String?,
      };
    }
    return map;
  }

  static Future<void> setAdminImpersonation(String? email) async {
    if (!_adminActive) return;
    final canonical = email == null ? null : _canonicalEmail(email);
    _adminImpersonatingEmail = canonical;
    _adminEditMode = false;
    final prefs = await SharedPreferences.getInstance();
    if (canonical == null) {
      await prefs.remove(_activeRegionSessionKey);
      _adminImpersonatingUserId = null;
    } else {
      final row = await _fetchUser(canonical);
      final regionValue = row?['region_key'];
      _adminImpersonatingUserId = row?['user_id'] as String?;
      if (regionValue is String && regionValue.isNotEmpty) {
        await prefs.setString(_activeRegionSessionKey, regionValue);
      } else {
        await prefs.remove(_activeRegionSessionKey);
      }
    }
    _bumpSession();
  }

  static void setAdminEditMode(bool enabled) {
    if (!_adminActive) return;
    final newValue = enabled && _adminImpersonatingEmail != null;
    if (newValue == _adminEditMode) return;
    _adminEditMode = newValue;
    _bumpSession();
  }
}

/// =======================================================
/// STORAGE (SharedPreferences)
/// =======================================================
class Store {
  static SupabaseClient get _client => Supabase.instance.client;

  static String monthKeyOf(DateTime d) => DateFormat('yyyy-MM').format(d);

  static Future<List<TransactionRecord>> loadTransactions() async {
    final userId = await Auth.activeUserId();
    if (userId == null) return [];
    final rows = await _client
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .order('purchased_at', ascending: true);
    final raw = rows
        .map((e) => TransactionRecord.fromSupabase(Map<String, dynamic>.from(e)))
        .toList();
    final computed = await _applyExpected(raw);
    computed.sort((a, b) => b.date.compareTo(a.date));
    return computed;
  }

  static Future<List<TransactionRecord>> fetchRawTransactions() async {
    final userId = await Auth.activeUserId();
    if (userId == null) return [];
    final rows = await _client
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .order('purchased_at', ascending: true);
    return rows
        .map((e) => TransactionRecord.fromSupabase(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<TransactionRecord>> _applyExpected(
      List<TransactionRecord> ascending) async {
    if (ascending.isEmpty) return [];
    final email = await Auth.activeEmail();
    final customerType =
        email == null ? 'residential' : await Auth.customerTypeFor(email);
    final regions = await TariffManager.loadTariffsForType(customerType);
    final allRegions = await TariffManager.loadTariffsAll();
    final Map<String, double> monthCursor = {};
    final List<TransactionRecord> out = [];
    for (final tx in ascending) {
      final monthKey = monthKeyOf(tx.date);
      final key = '${tx.regionKey}__$monthKey';
      final cursor = monthCursor[key] ?? 0.0;
      final region = TariffManager.findRegionForDate(allRegions, tx.regionKey, tx.date) ??
          TariffManager.findRegion(regions, tx.regionKey);
      final expected = region == null
          ? tx.actualKwh
          : Calc.expectedKwhFromMoneyAt(tx.money, region.blocks, cursor);
      monthCursor[key] = cursor + expected;
      out.add(tx.copyWith(expectedKwh: expected));
    }
    return out;
  }

  static Future<void> updateTransactions(List<TransactionRecord> updates) async {
    if (updates.isEmpty) return;
    for (final tx in updates) {
      if (tx.id.isEmpty) continue;
      try {
        await _client.from('transactions').update({
          'amount': tx.money,
          'energy_kwh': tx.actualKwh,
          'expected_kwh': tx.expectedKwh,
          'region_key': tx.regionKey,
          'purchased_at': tx.date.toIso8601String(),
        }).eq('id', tx.id);
      } catch (err) {
        if (kDebugMode) debugPrint('Failed to update txn ${tx.id}: $err');
      }
    }
  }

  static Future<TransactionRecord> insertTransaction(TransactionRecord tx) async {
    final userId = await Auth.activeUserId();
    if (userId == null) {
      throw StateError('No active user to insert transaction');
    }
    final payload = tx.toSupabaseMap(userId: userId);
    final inserted = await _client
        .from('transactions')
        .insert(payload)
        .select()
        .maybeSingle();
    if (inserted == null) return tx;
    return TransactionRecord.fromSupabase(Map<String, dynamic>.from(inserted));
  }

  static Future<void> deleteMonth(String monthKey) async {
    if (!Auth.canModifyData) return;
    final raw = await fetchRawTransactions();
    final removed = raw.where((t) => monthKeyOf(t.date) == monthKey).toList();
    if (removed.isEmpty) return;
    await RemoteLog.transactionsDeleted(await _applyExpected(removed));
    final userId = await Auth.activeUserId();
    if (userId == null) return;
    final start = DateTime.parse('$monthKey-01');
    final end = DateTime(start.year, start.month + 1, 1);
    try {
      await _client
          .from('transactions')
          .delete()
          .eq('user_id', userId)
          .gte('purchased_at', start.toIso8601String())
          .lt('purchased_at', end.toIso8601String());
    } catch (err) {
      if (kDebugMode) debugPrint('Failed to delete month $monthKey: $err');
    }
  }

  static Future<void> resetCurrentMonth() async {
    if (!Auth.canModifyData) return;
    final nowKey = monthKeyOf(DateTime.now());
    await deleteMonth(nowKey);
  }

  static Future<List<String>> loadMonthsDesc() async {
    final raw = await fetchRawTransactions();
    final set = <String>{};
    for (final tx in raw) {
      set.add(monthKeyOf(tx.date));
    }
    final list = set.toList()..sort();
    return list.reversed.toList();
  }

  static Future<MonthlySummary> computeSummary(String monthKey) async {
    final transactions = await loadTransactions();
    final inMonth = transactions.where((t) => monthKeyOf(t.date) == monthKey).toList();
    final totalMoney = inMonth.fold<double>(0, (sum, t) => sum + t.money);
    final totalActual = inMonth.fold<double>(0, (sum, t) => sum + t.actualKwh);
    final totalExpected = inMonth.fold<double>(0, (sum, t) => sum + t.expectedKwh);
    return MonthlySummary(
      monthKey: monthKey,
      totalMoney: totalMoney,
      totalActualKwh: totalActual,
      totalExpectedKwh: totalExpected,
      transactions: inMonth.length,
    );
  }
}

class RemoteLog {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<void> _insertEvents(List<Map<String, dynamic>> events) async {
    if (events.isEmpty) return;
    try {
      await _client.from('transaction_events').insert(events);
    } catch (err) {
      if (kDebugMode) {
        debugPrint('Failed to insert remote events: $err');
      }
    }
  }

  static Future<void> transactionCreated(TransactionRecord tx) async {
    final userId = await Auth.activeUserId();
    if (userId == null) return;
    final performer = await Auth.actorUserId();
    final payload = <String, dynamic>{
      'user_id': userId,
      'action': 'created',
      'transaction_id': null,
      'performed_by': performer ?? userId,
      'snapshot': {
        'type': 'transaction',
        'transaction': tx.toJson(),
      },
    };
    await _insertEvents([payload]);
  }

  static Future<void> transactionsDeleted(List<TransactionRecord> txs) async {
    if (txs.isEmpty) return;
    final userId = await Auth.activeUserId();
    if (userId == null) return;
    final performer = await Auth.actorUserId();
    final events = txs.map((tx) {
      return <String, dynamic>{
        'user_id': userId,
        'action': 'deleted',
        'transaction_id': null,
        'performed_by': performer ?? userId,
        'snapshot': {
          'type': 'transaction',
          'transaction': tx.toJson(),
        },
      };
    }).toList();
    await _insertEvents(events);
  }

  static Future<void> queryMessage({
    required String userEmail,
    required SupportMessage message,
  }) async {
    final targetUserId = await Auth.userIdForEmail(userEmail);
    if (targetUserId == null) return;
    final performer = await Auth.actorUserId();
    final payload = <String, dynamic>{
      'user_id': targetUserId,
      'action': 'created',
      'transaction_id': null,
      'performed_by': performer ?? targetUserId,
      'snapshot': {
        'type': 'query_message',
        'sender': message.sender,
        'userEmail': userEmail,
        'body': message.body,
        'timestamp': message.timestamp.toIso8601String(),
      },
    };
    await _insertEvents([payload]);
  }

  static Future<List<RemoteEvent>> fetchEventsForUser(String userId,
      {int limit = 50}) async {
    try {
      final rows = await _client
          .from('transaction_events')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map((e) => RemoteEvent.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (err) {
      if (kDebugMode) {
        debugPrint('Failed to fetch activity: $err');
      }
      return const [];
    }
  }
}

class RemoteEvent {
  final String id;
  final String userId;
  final String action;
  final String? performedBy;
  final Map<String, dynamic>? snapshot;
  final DateTime createdAt;

  const RemoteEvent({
    required this.id,
    required this.userId,
    required this.action,
    required this.performedBy,
    required this.snapshot,
    required this.createdAt,
  });

  factory RemoteEvent.fromMap(Map<String, dynamic> map) => RemoteEvent(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        action: map['action'] as String,
        performedBy: map['performed_by'] as String?,
        snapshot: map['snapshot'] == null
            ? null
            : Map<String, dynamic>.from(map['snapshot'] as Map),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  bool get isTransaction => snapshot?['type'] == 'transaction';
  bool get isQueryMessage => snapshot?['type'] == 'query_message';

  String describe() {
    if (isTransaction) {
      final tx = snapshot?['transaction'] as Map<String, dynamic>? ?? {};
      final amount = tx['money'];
      final kwh = tx['actualKwh'];
      final date = tx['date'];
      final amountStr = amount is num ? amount.toStringAsFixed(2) : '$amount';
      final kwhStr = kwh is num ? kwh.toStringAsFixed(2) : '$kwh';
      return action == 'deleted'
          ? 'Deleted transaction: R$amountStr, $kwhStr kWh ($date)'
          : 'Added transaction: R$amountStr, $kwhStr kWh ($date)';
    }
    if (isQueryMessage) {
      final sender = snapshot?['sender'] ?? 'user';
      final body = snapshot?['body'] ?? '';
      final bodyStr = body.toString();
      final preview =
          bodyStr.length > 120 ? '${bodyStr.substring(0, 117)}…' : bodyStr;
      final label = sender == 'admin' ? 'Admin' : 'User';
      return "$label message: $preview";
    }
    return action;
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
    if (_regions.isEmpty) {
      _selectedRegionKey = null;
    } else if (_selectedRegionKey == null ||
        !_regions.any((r) => r.regionKey == _selectedRegionKey)) {
      _selectedRegionKey = _regions.first.regionKey;
    }
    if (mounted) setState(() {});
  }

  Future<void> _doLogin() async {
    final email = emailC.text.trim();
    final pass = passC.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => message = 'Please enter username and password.');
      return;
    }
    final ok = await Auth.login(email: email, password: pass);
    if (!ok) {
      setState(() => message = 'Invalid login.');
      return;
    }
    if (_selectedRegionKey != null) {
      final selected = _selectedRegionKey!;
      await Auth.setRegion(email, selected);
      await Auth.setActiveRegionKey(selected);
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
      setState(() => message = 'Please enter username and password.');
      return;
    }
    if (email.length < 3) {
      setState(() => message = 'Username must be at least 3 characters long.');
      return;
    }
    if (pass.length < 6) {
      setState(() => message = 'Password must be at least 6 characters long.');
      return;
    }
    if (_selectedRegionKey == null) {
      setState(() => message =
          _regions.isEmpty ? 'No regions available yet. Try again later.' : 'Select a region.');
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
    final currentPass = passC.text;
    if (email.isEmpty || currentPass.isEmpty) {
      setState(() => message = 'Enter your username and current password.');
      return;
    }
    final newPassController = TextEditingController();
    final newPassword = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set new password'),
        content: TextField(
          controller: newPassController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New password',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = newPassController.text.trim();
              Navigator.of(ctx).pop(value.isEmpty ? null : value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    newPassController.dispose();
    if (newPassword == null || newPassword.isEmpty) {
      setState(() => message = 'Password change cancelled.');
      return;
    }
    final ok = await Auth.changePassword(
      email: email,
      currentPassword: currentPass,
      newPassword: newPassword,
    );
    if (ok) {
      passC.clear();
    }
    setState(() {
      message = ok
          ? 'Password updated. Use your new password to sign in.'
          : 'Incorrect username or password. Try again.';
    });
  }

  Future<void> _signInWithPrevious() async {
    setState(() => message = '');
    final ok = await Auth.loginWithPreviousDetails();
    if (!ok) {
      if (mounted) {
        setState(() => message = 'No previous sign-in saved on this device.');
      }
      return;
    }
    final email = await Auth.activeEmail();
    if (email != null) {
      final region = await Auth.regionFor(email);
      if (region != null) {
        await Auth.setActiveRegionKey(region);
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF3E0), Color(0xFFFFD180)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 12,
              color: Colors.white,
              shadowColor: Colors.deepOrange.withOpacity(0.25),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Gauteng Electricity Tracker',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: _signInWithPrevious,
                      child: const Text('Sign in with previous details'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailC,
                      decoration: const InputDecoration(
                        labelText: 'Username',
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
                    if (_regions.isEmpty)
                      const Text(
                        'No tariff regions available yet. Add tariff data in Settings once it is published.',
                        textAlign: TextAlign.center,
                      )
                      else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRegionKey,
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
                      initialValue: _customerType,
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

  void _handleSessionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<int> _fetchUnreadCount() async {
    if (Auth.isAdminActive && Auth.adminImpersonatingEmail == null) {
      return QueryStore.unreadForAdmin();
    }
    final email = await Auth.activeEmail();
    if (email == null) return 0;
    return QueryStore.unreadForUser(email);
  }

  Future<void> _openQueryFromAppBar(int queriesIndex, bool isAdmin) async {
    if (!mounted) return;
    if (isAdmin && queriesIndex >= 0 && Auth.adminImpersonatingEmail == null) {
      setState(() => _tab = queriesIndex);
      return;
    }
    final email = await Auth.activeEmail();
    if (!mounted) return;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to send a query.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QueryConversationPage(
          userEmail: email,
          isAdmin: Auth.isAdminActive && Auth.adminImpersonatingEmail != null,
          onUpdated: _handleSessionChanged,
        ),
      ),
    );
    _handleSessionChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = Auth.isAdminActive;
    final sessionGen = Auth.sessionGeneration;

    final pages = <Widget>[];
    final titles = <String>[];
    final destinations = <NavigationDestination>[];
    int queriesIndex = -1;

    pages.add(CalculatorPage(key: ValueKey('calc_$sessionGen')));
    titles.add('Calculator');
    destinations.add(const NavigationDestination(icon: Icon(Icons.calculate), label: 'Calc'));

    pages.add(HistoryPage(key: ValueKey('hist_$sessionGen')));
    titles.add('History');
    destinations.add(const NavigationDestination(icon: Icon(Icons.history), label: 'History'));

    pages.add(MonthlyPage(key: ValueKey('month_$sessionGen')));
    titles.add('Monthly cumulative purchases');
    destinations.add(const NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Monthly'));

    if (isAdmin) {
      queriesIndex = pages.length;
      pages.add(AdminQueriesPage(
        key: ValueKey('admin_queries_$sessionGen'),
        onSessionChanged: _handleSessionChanged,
      ));
      titles.add('Queries');
      destinations.add(const NavigationDestination(icon: Icon(Icons.mark_chat_unread), label: 'Queries'));

      pages.add(AdminPage(
        key: ValueKey('super_$sessionGen'),
        onSessionChanged: _handleSessionChanged,
      ));
      titles.add('Admin');
      destinations.add(const NavigationDestination(icon: Icon(Icons.admin_panel_settings), label: 'Admin'));
    }

    pages.add(SettingsPage(
      key: ValueKey('settings_$sessionGen'),
      onQueryActivity: _handleSessionChanged,
    ));
    titles.add('Settings');
    destinations.add(const NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'));

    int currentTab = _tab;
    if (currentTab >= pages.length) {
      currentTab = pages.length - 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[currentTab]),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          FutureBuilder<int>(
            key: ValueKey('queries_badge_$sessionGen'),
            future: _fetchUnreadCount(),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              return IconButton(
                onPressed: () => _openQueryFromAppBar(queriesIndex, isAdmin),
                tooltip: 'Queries',
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.chat_bubble_outline),
                    if (unread > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: pages[currentTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: destinations,
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
  final TextEditingController _smsC = TextEditingController();
  final moneyC = TextEditingController();
  final actualC = TextEditingController();
  DateTime? _pickedDate;

  RegionTariff? _activeRegion;

  String _resultText = '';
  bool _smsParserEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadRegion();
  }

  @override
  void dispose() {
    _smsC.dispose();
    moneyC.dispose();
    actualC.dispose();
    super.dispose();
  }

  void _parseSms() {
    final sms = _smsC.text.trim();
    if (!_smsParserEnabled) {
      _toast('Enable the SMS helper first.');
      return;
    }
    if (sms.isEmpty) {
      _toast('Paste the SMS message first.');
      return;
    }

    double? parseAmount(String text) {
      final moneyPatterns = [
        RegExp(r'R\s*([0-9]+(?:[.,][0-9]{1,2})?)', caseSensitive: false),
        RegExp(r'Rand\s*([0-9]+(?:[.,][0-9]{1,2})?)', caseSensitive: false),
        RegExp(r'Amount[:\s]*([0-9]+(?:[.,][0-9]{1,2})?)', caseSensitive: false),
      ];
      for (final pattern in moneyPatterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          final raw = match.group(1)!.replaceAll(',', '.');
          final value = double.tryParse(raw);
          if (value != null) return value;
        }
      }
      final generic = RegExp(r'([0-9]+(?:[.,][0-9]{1,2}))');
      final all = generic.allMatches(text).toList();
      for (final match in all) {
        final raw = match.group(1)!.replaceAll(',', '.');
        final value = double.tryParse(raw);
        if (value != null) return value;
      }
      return null;
    }

    double? parseKwh(String text) {
      final patterns = [
        RegExp(r'([0-9]+(?:[.,][0-9]+)?)\s*(?:kwh|kWh|kWhs|units)', caseSensitive: false),
        RegExp(r'(?:kwh|kWh|units)\s*([0-9]+(?:[.,][0-9]+)?)', caseSensitive: false),
      ];
      for (final pattern in patterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          final raw = match.group(1)!.replaceAll(',', '.');
          final value = double.tryParse(raw);
          if (value != null) return value;
        }
      }
      return null;
    }

    String titleCase(String input) {
      return input
          .split(RegExp(r'\s+'))
          .map((word) => word.isEmpty
              ? word
              : word[0].toUpperCase() + word.substring(1).toLowerCase())
          .join(' ');
    }

    DateTime? parseDate(String text) {
      final patterns = [
        RegExp(r'(\d{4}[-/]\d{2}[-/]\d{2}(?:\s+\d{2}:\d{2}(?::\d{2})?)?)'),
        RegExp(r'(\d{2}[-/]\d{2}[-/]\d{4})'),
        RegExp(r'(\d{2}\s+[A-Za-z]{3,}\s+\d{4})'),
        RegExp(r'([A-Za-z]{3,}\s+\d{1,2},?\s+\d{4})'),
        RegExp(r'(\d{2}[.]+\d{2}[.]+\d{4})'),
        RegExp(r'(\d{2}[.]+[A-Za-z]{3,}[.]+\d{4})'),
      ];
      DateTime? parsed;
      for (final pattern in patterns) {
        final match = pattern.firstMatch(text);
        if (match == null) continue;
        final value = match.group(1)!;
        final candidates = <String>{
          value,
          value.replaceAll('/', '-'),
          value.replaceAll('.', '-'),
          value.toLowerCase(),
          value.toUpperCase(),
          titleCase(value),
        };
        final formats = [
          DateFormat('dd/MM/yyyy'),
          DateFormat('dd-MM-yyyy'),
          DateFormat('dd MMM yyyy'),
          DateFormat('dd MMMM yyyy'),
          DateFormat('MMM dd yyyy'),
          DateFormat('MMMM dd yyyy'),
          DateFormat('MM/dd/yyyy'),
          DateFormat('MM-dd-yyyy'),
          DateFormat('MM.dd.yyyy'),
          DateFormat('dd.MM.yyyy'),
          DateFormat('yyyy/MM/dd'),
          DateFormat('yyyy-MM-dd'),
          DateFormat('yyyy.MM.dd'),
        ];
        for (final candidate in candidates) {
          parsed = DateTime.tryParse(candidate);
          if (parsed != null) break;
          for (final fmt in formats) {
            try {
              parsed = fmt.parse(candidate);
              break;
            } catch (_) {}
          }
          if (parsed != null) break;
        }
        if (parsed != null) break;
      }
      return parsed;
    }

    final amount = parseAmount(sms);
    final kwh = parseKwh(sms);
    final date = parseDate(sms);

    if (amount != null) {
      moneyC.text = amount.toStringAsFixed(2);
    }
    if (kwh != null) {
      actualC.text = kwh.toStringAsFixed(2);
    }
    if (date != null) {
      setState(() => _pickedDate = date);
    } else if (_pickedDate == null) {
      setState(() {});
    }

    final results = <String>[];
    results.add(amount != null
        ? 'Amount R${amount.toStringAsFixed(2)}'
        : 'Amount not found');
    results.add(kwh != null
        ? '${kwh.toStringAsFixed(2)} kWh captured'
        : 'kWh not found');
    if (date != null) {
      results.add('Date ${DateFormat('yyyy-MM-dd').format(date)}');
    }
    _toast(results.join(' | '));
  }

  Future<void> _loadRegion() async {
    final email = await Auth.activeEmail();
    final customerType = email == null ? 'residential' : await Auth.customerTypeFor(email);
    // Latest-only is sufficient for header display
    final regions = await TariffManager.loadTariffsForType(customerType);
    final regionKey = await Auth.activeRegionKey();
    String? targetKey = regionKey;
    if (targetKey != null && regions.every((r) => r.regionKey != targetKey)) {
      targetKey = null;
    }
    if (targetKey == null && regions.isNotEmpty) {
      targetKey = regions.first.regionKey;
    }
    // Use today's effective tariff for displaying in header
    final today = DateTime.now();
    RegionTariff? region;
    if (targetKey != null) {
      region = TariffManager.findRegionForDate(regions, targetKey, today) ??
          TariffManager.findRegion(regions, targetKey);
    }
    setState(() => _activeRegion = region);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now, // ?? prevent selecting future dates
      initialDate: _pickedDate ?? now,
    );
    if (d != null) setState(() => _pickedDate = d);
  }

  Future<void> _calculateAndSave() async {
    if (!Auth.canModifyData) {
      _toast('View-only mode. Enable change mode to modify this account.');
      return;
    }
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
    // Use full history to pick by date
    final regions = await TariffManager.loadTariffsAll();
    String? regionKey = _activeRegion?.regionKey ?? await Auth.activeRegionKey();
    if (regionKey != null && regions.every((r) => r.regionKey != regionKey)) {
      regionKey = null;
    }
    regionKey ??= regions.isNotEmpty ? regions.first.regionKey : null;
    if (regionKey == null) {
      _toast('No tariff data available. Add tariffs in Settings first.');
      return;
    }
    final regionForDate = TariffManager.findRegionForDate(regions, regionKey, date) ??
        TariffManager.findRegion(regions, regionKey);
    if (regionForDate == null) {
      _toast('No tariff data available for the selected date.');
      return;
    }
    final monthKey = Store.monthKeyOf(date);

    final rawTransactions = await Store.fetchRawTransactions();
    final monthList = rawTransactions
        .where((t) =>
            Store.monthKeyOf(t.date) == monthKey &&
            t.regionKey == regionForDate.regionKey)
        .toList();
    final placeholder = TransactionRecord(
      id: '',
      regionKey: regionForDate.regionKey,
      date: date,
      money: money,
      actualKwh: actual,
      expectedKwh: 0,
    );
    monthList.add(placeholder);
    monthList.sort((a, b) => a.date.compareTo(b.date));

    double cursorBought = 0.0;
    double cursorBeforePurchase = 0.0;
    final List<TransactionRecord> recomputed = [];
    TransactionRecord? newTransactionComputed;
    for (final t in monthList) {
      if (t.id.isEmpty) {
        cursorBeforePurchase = cursorBought;
      }
      final rT = TariffManager.findRegionForDate(regions, t.regionKey, t.date) ?? regionForDate;
      final exp = Calc.expectedKwhFromMoneyAt(t.money, rT.blocks, cursorBought);
      cursorBought += exp;
      final updated = t.copyWith(expectedKwh: exp);
      if (t.id.isEmpty) {
        newTransactionComputed = updated;
      } else {
        recomputed.add(updated);
      }
    }

    await Store.updateTransactions(recomputed);
    final inserted = await Store.insertTransaction(newTransactionComputed ?? placeholder);
    await RemoteLog.transactionCreated(inserted);

    final expected = inserted.expectedKwh;
    final breakdown = Calc.breakdownForPurchase(money, regionForDate.blocks, cursorBeforePurchase);
    final pct = Calc.percentDiff(expected, actual);
    final vat = Calc.vatPortion(money);
    final net = Calc.netExVat(money);
    setState(() {
      final bd = breakdown.map((b) {
        final rng = b.to == null ? '${b.from}-8' : '${b.from}-${b.to}';
        return 'Tier ${b.tierIndex} (${rng}) @ R${b.rate.toStringAsFixed(4)}/kWh -> '
               '${b.kwh.toStringAsFixed(2)} kWh, R${b.cost.toStringAsFixed(2)}';
      }).join('\n');

      _resultText =
          'Detailed calculation (month-cumulative)\n'
          'Region: ${regionForDate.displayName}\n'
          'Month-to-date before purchase: ${cursorBeforePurchase.toStringAsFixed(2)} kWh\n'
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
    final canEdit = Auth.canModifyData;
    final regionName = _activeRegion?.displayName ?? '...';
    final dateLabel = _pickedDate == null
        ? 'Pick purchase date'
        : DateFormat('yyyy-MM-dd').format(_pickedDate!);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF9E6), Color(0xFFFFE0B2)],
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
          SwitchListTile.adaptive(
            value: _smsParserEnabled,
            onChanged: canEdit
                ? (value) {
                    setState(() {
                      _smsParserEnabled = value;
                      if (!value) {
                        _smsC.clear();
                      }
                    });
                  }
                : null,
            title: const Text('Enable SMS paste helper'),
            subtitle: const Text('Toggle to paste and auto-fill details from tokens SMS'),
          ),
          if (_smsParserEnabled) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Paste SMS',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _smsC,
                      enabled: canEdit,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Paste the electricity purchase SMS here',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: canEdit ? _parseSms : null,
                        icon: const Icon(Icons.content_paste_search),
                        label: const Text('Parse SMS'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
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
            enabled: canEdit,
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
            enabled: canEdit,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: canEdit ? _pickDate : null,
            icon: const Icon(Icons.date_range),
            label: Text(dateLabel),
            style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: canEdit ? _calculateAndSave : null,
            icon: const Icon(Icons.save),
            label: const Text('Calculate & Save'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
          if (Auth.isAdminViewing && !canEdit) ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.red.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'You are viewing another user in read-only mode. Enable change mode from the Admin tab to make adjustments.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // ?? New disclaimer card about block pricing accuracy
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
/// HISTORY (last 20)
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
    final regions = await TariffManager.loadTariffsAll();
    if (regions.isEmpty) {
      return 'No tariff data available. Add tariffs in Settings once they are published.';
    }
    final region = TariffManager.findRegionForDate(regions, t.regionKey, t.date) ??
        TariffManager.findRegion(regions, t.regionKey);
    if (region == null) {
      return 'No tariff data found for region ${t.regionKey}.';
    }

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
      final rng = b.to == null ? '${b.from}-' : '${b.from}-${b.to}';
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

  void _onLongPress(TransactionRecord t) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delete individual entries by removing the month in the Monthly tab.'),
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
          colors: [Color(0xFFFFFBF2), Color(0xFFFFF3E0)],
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
                        initialValue: _selectedMonth ?? 'all',
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
                    title: Text('R${t.money.toStringAsFixed(2)} | $df'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expected: ${t.expectedKwh.toStringAsFixed(2)} kWh | '
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
    if (!Auth.canModifyData) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Read-only mode. Enable change mode to reset months.')),
        );
      }
      return;
    }
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
    if (!Auth.canModifyData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Read-only mode. Enable change mode to delete months.')),
      );
      return;
    }
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
          colors: [Color(0xFFFFF8E1), Color(0xFFFFE0B2)],
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
                          Text('VAT (15%): R${s.vatPortion.toStringAsFixed(2)} | '
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
/// QUERIES (shared conversation UI)
/// =======================================================
class QueryConversationPage extends StatefulWidget {
  final String userEmail;
  final bool isAdmin;
  final VoidCallback? onUpdated;

  const QueryConversationPage({
    super.key,
    required this.userEmail,
    required this.isAdmin,
    this.onUpdated,
  });

  @override
  State<QueryConversationPage> createState() => _QueryConversationPageState();
}

class _QueryConversationPageState extends State<QueryConversationPage> {
  final TextEditingController _messageC = TextEditingController();
  final ScrollController _scrollC = ScrollController();
  List<SupportMessage> _messages = const [];
  bool _loading = true;
  Timer? _pollTimer;

  bool get _isAdmin => widget.isAdmin;

  @override
  void initState() {
    super.initState();
    _loadThread();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadThread(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageC.dispose();
    _scrollC.dispose();
    super.dispose();
  }

  Future<void> _loadThread({bool silent = false}) async {
    if (!mounted) return;
    final previousCount = _messages.length;
    if (!silent) {
      setState(() => _loading = true);
    }
    final thread = await QueryStore.threadFor(widget.userEmail);
    if (_isAdmin) {
      await QueryStore.markReadByAdmin(widget.userEmail);
    } else {
      await QueryStore.markReadByUser(widget.userEmail);
    }
    widget.onUpdated?.call();
    if (!mounted) return;
    final newMessages = thread.messages;
    final hasNewMessage = newMessages.length != previousCount;
    if (silent && !hasNewMessage) {
      return;
    }
    setState(() {
      _messages = newMessages;
      if (!silent) {
        _loading = false;
      }
    });
    if (hasNewMessage) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollC.hasClients) return;
      _scrollC.animateTo(
        _scrollC.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageC.text.trim();
    if (text.isEmpty) return;
    final message = SupportMessage(
      sender: _isAdmin ? 'admin' : 'user',
      body: text,
      timestamp: DateTime.now(),
      readByUser: _isAdmin ? false : true,
      readByAdmin: _isAdmin ? true : false,
    );
    await QueryStore.addMessage(userEmail: widget.userEmail, message: message);
    _messageC.clear();
    FocusScope.of(context).unfocus();
    await _loadThread();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isAdmin ? 'Queries: ${widget.userEmail}' : 'Contact Admin';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('No messages yet. Send one below.'))
                    : ListView.builder(
                        controller: _scrollC,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final mine = _isAdmin ? msg.sender == 'admin' : msg.sender == 'user';
                          final align = mine ? Alignment.centerRight : Alignment.centerLeft;
                          final bubbleColor = mine
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300;
                          final textColor = mine ? Colors.white : Colors.black87;
                          final stamp = DateFormat('yyyy-MM-dd HH:mm').format(msg.timestamp);
                          return Align(
                            alignment: align,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 320),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: bubbleColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: mine
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(msg.body,
                                      style: TextStyle(color: textColor, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(stamp,
                                      style: TextStyle(
                                        color: textColor.withOpacity(0.75),
                                        fontSize: 11,
                                      )),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageC,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminQueriesPage extends StatefulWidget {
  final VoidCallback onSessionChanged;
  const AdminQueriesPage({super.key, required this.onSessionChanged});

  @override
  State<AdminQueriesPage> createState() => _AdminQueriesPageState();
}

class _AdminQueriesPageState extends State<AdminQueriesPage> {
  late Future<List<QueryThread>> _threadsFuture;

  @override
  void initState() {
    super.initState();
    _threadsFuture = QueryStore.allSorted();
  }

  Future<void> _reload() async {
    final future = QueryStore.allSorted();
    setState(() {
      _threadsFuture = future;
    });
    await future;
    widget.onSessionChanged();
  }

  Future<void> _openThread(QueryThread thread) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QueryConversationPage(
          userEmail: thread.userEmail,
          isAdmin: true,
          onUpdated: () {
            widget.onSessionChanged();
          },
        ),
      ),
    );
    widget.onSessionChanged();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<QueryThread>>(
        future: _threadsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text('Failed to load queries: ${snapshot.error}'),
              ],
            );
          }
          final threads = snapshot.data ?? const [];
          if (threads.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [Center(child: Text('No queries yet.'))],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: threads.length,
            itemBuilder: (context, index) {
              final thread = threads[index];
              final unread = thread.unreadForAdmin;
              final lastMsg = thread.messages.isNotEmpty ? thread.messages.last : null;
              final preview = lastMsg?.body ?? 'No messages yet';
              final stamp = lastMsg == null
                  ? ''
                  : DateFormat('yyyy-MM-dd HH:mm').format(lastMsg.timestamp);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(thread.userEmail.isEmpty
                        ? '?'
                        : thread.userEmail[0].toUpperCase()),
                  ),
                  title: Text(thread.userEmail),
                  subtitle: Text(stamp.isEmpty ? preview : '$preview\n$stamp'),
                  isThreeLine: stamp.isNotEmpty,
                  trailing: unread > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('$unread', style: const TextStyle(color: Colors.white)),
                        )
                      : null,
                  onTap: () => _openThread(thread),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// =======================================================
/// SUPERUSER
/// =======================================================
class AdminPage extends StatefulWidget {
  final VoidCallback onSessionChanged;
  const AdminPage({super.key, required this.onSessionChanged});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late Future<List<_UserSummary>> _usersFuture;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<List<_UserSummary>> _loadUsers() async {
    final raw = await Auth.allUsers();
    final out = <_UserSummary>[];
    raw.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        out.add(_UserSummary(
          email: key,
          regionKey: value['regionKey'] as String?,
          customerType: (value['customerType'] as String?) ?? 'residential',
          userId: value['userId'] as String?,
        ));
      }
    });
    out.sort((a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()));
    return out;
  }

  Future<void> _refreshUsers() async {
    final future = _loadUsers();
    setState(() {
      _usersFuture = future;
    });
    await future;
  }

  Future<void> _impersonate(String email) async {
    await Auth.setAdminImpersonation(email);
    widget.onSessionChanged();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing account: $email')),
    );
  }

  Future<void> _showActivity(_UserSummary user) async {
    final userId = user.userId;
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No activity available for ${user.email}')),
      );
      return;
    }
    final events = await RemoteLog.fetchEventsForUser(userId);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: events.isEmpty
              ? const Text('No activity recorded yet.')
              : ListView.separated(
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final stamp =
                        DateFormat('yyyy-MM-dd HH:mm').format(event.createdAt.toLocal());
                    final performer = event.performedBy == null
                        ? 'User'
                        : (event.performedBy == userId ? 'User' : 'Admin');
                    return ListTile(
                      leading: Icon(
                        event.isTransaction
                            ? (event.action == 'deleted'
                                ? Icons.delete_outline
                                : Icons.add_circle_outline)
                            : Icons.chat_bubble_outline,
                      ),
                      title: Text(event.describe()),
                      subtitle: Text('$stamp - $performer'),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _stopImpersonation() async {
    await Auth.setAdminImpersonation(null);
    widget.onSessionChanged();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stopped viewing any account')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewingEmail = Auth.adminImpersonatingEmail;
    final viewing = Auth.isAdminViewing;
    final editMode = Auth.adminEditMode;

    return RefreshIndicator(
      onRefresh: _refreshUsers,
      child: FutureBuilder<List<_UserSummary>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          final children = <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Admin tools',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(viewing
                        ? 'Currently viewing: $viewingEmail'
                        : 'Not viewing any other account'),
                    const SizedBox(height: 4),
                    Text(editMode
                        ? 'Change mode enabled - actions will modify this user.'
                        : 'View-only mode - actions are read-only.'),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      title: const Text('Enable change mode'),
                      subtitle: const Text('Allow editing on behalf of the selected user'),
                      value: editMode,
                      onChanged: viewingEmail == null
                          ? null
                          : (v) {
                              Auth.setAdminEditMode(v);
                              widget.onSessionChanged();
                              if (mounted) setState(() {});
                            },
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.visibility_off_outlined),
                      onPressed: viewingEmail == null ? null : _stopImpersonation,
                      label: const Text('Stop viewing user'),
                    ),
                  ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search users',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() => _search = value.trim().toLowerCase());
            },
          ),
        ),
        const SizedBox(height: 12),
      ];

      if (snapshot.connectionState == ConnectionState.waiting) {
        children.add(const Center(child: CircularProgressIndicator()));
      } else if (snapshot.hasError) {
        children.add(Center(child: Text('Failed to load users: ${snapshot.error}')));
      } else {
        final list = snapshot.data ?? const [];
        final query = _search;
        final filtered = query.isEmpty
            ? list
            : list
                .where((u) => u.email.toLowerCase().contains(query))
                .toList();
        if (filtered.isEmpty) {
          children.add(const Center(child: Text('No registered users found.')));
        } else {
          children.addAll(filtered.map((u) {
            final isActive = viewingEmail == u.email;
            return Card(
              child: ListTile(
                leading: Icon(isActive ? Icons.visibility : Icons.person_outline),
                    title: Text(u.email),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Customer type: ${u.customerType}'),
                        Text('Region: ${u.regionKey ?? 'Not set'}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'View activity',
                          icon: const Icon(Icons.list_alt),
                          onPressed: () => _showActivity(u),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _impersonate(u.email),
                  ),
                );
              }));
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: children,
          );
        },
      ),
    );
  }
}

class _UserSummary {
  final String email;
  final String? regionKey;
  final String customerType;
  final String? userId;

  _UserSummary({
    required this.email,
    required this.regionKey,
    required this.customerType,
    required this.userId,
  });
}

/// =======================================================
/// SETTINGS
/// =======================================================
class SettingsPage extends StatefulWidget {
  final VoidCallback? onQueryActivity;
  const SettingsPage({super.key, this.onQueryActivity});

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

    String? resolvedKey = rk;
    if (resolvedKey != null && regions.every((r) => r.regionKey != resolvedKey)) {
      resolvedKey = null;
    }
    if (resolvedKey == null && regions.isNotEmpty) {
      resolvedKey = regions.first.regionKey;
    }

    setState(() {
      _regions = regions;
      _email = email;
      _currentRegionKey = resolvedKey;
      _customerType = ct;
      if (updatedAt != null) {
        final date = DateTime.parse(updatedAt);
        _lastUpdated = DateFormat('yyyy-MM-dd HH:mm').format(date);
      }
    });
  }

  Future<void> _showCredentials() async {
    final email = _email;
    if (email == null) return;
    final password = await Auth.storedPassword(email);
    if (!mounted) return;
    if (password == null || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved password found for this account.')),
      );
      return;
    }
    final controller = TextEditingController(text: password);
    await showDialog<void>(
      context: context,
      builder: (_) {
        bool obscure = true;
        return StatefulBuilder(
          builder: (ctx, setStateDialog) => AlertDialog(
            title: const Text('Your login details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText('Username: $email'),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  readOnly: true,
                  obscureText: obscure,
                  enableInteractiveSelection: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setStateDialog(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
  }

  RegionTariff? _currentRegion() {
    if (_currentRegionKey == null || _regions.isEmpty) return null;
    final today = DateTime.now();
    return TariffManager.findRegionForDate(_regions, _currentRegionKey!, today)
        ?? TariffManager.findRegion(_regions, _currentRegionKey!);
  }

  Future<void> _saveRegion(String key) async {
    if (!Auth.canModifyData) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Read-only mode. Enable change mode to modify settings.')),
        );
      }
      return;
    }
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
    if (!Auth.canModifyData) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Read-only mode. Enable change mode to request updates.')),
        );
      }
      return;
    }
    await TariffManager.tryAutoUpdate(force: true);
    await _init(); // refresh UI + last updated
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checked for tariff updates')),
      );
    }
  }

  Future<void> _resetTariffs() async {
    if (!Auth.canModifyData) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Read-only mode. Enable change mode to clear tariffs.')),
        );
      }
      return;
    }
    await TariffManager.clearTariffs();
    await _init();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cached tariffs cleared.')),
      );
    }
  }

  Future<void> _refreshEverything() async {
    await _init();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data refreshed')),
    );
  }

  void _showInclineInfo() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Incline Blocks'),
        content: const Text(
          'Incline blocks are tiered electricity tariffs. Each month starts in block one with the cheapest rate. As usage climbs beyond thresholds, higher blocks activate and each kilowatt-hour there costs more. Recording every purchase keeps the running totals accurate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
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
      useSafeArea: true,
      enableDrag: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: previous.isEmpty
              ? ListView(
                  controller: scrollController,
                  children: const [
                    Text(
                      'No historical tariffs available for the last 5 years.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                )
              : ListView(
                  controller: scrollController,
                  children: [
                    const Text(
                      'Previous 5 years - Incline Blocks',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
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
                                  final range = b.to == null ? '${b.from}-' : '${b.from}-${b.to}';
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
    final canEdit = Auth.canModifyData;
    // Resolve a friendly region name without allowing edits here.
    String regionName;
    try {
      final today = DateTime.now();
      final r = TariffManager.findRegionForDate(
              _regions, _currentRegionKey ?? '', today) ??
          (_currentRegionKey == null
              ? null
              : TariffManager.findRegion(_regions, _currentRegionKey!));
      regionName = r?.displayName ?? (_currentRegionKey ?? 'No region selected');
    } catch (_) {
      regionName = _currentRegionKey ?? 'No region selected';
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
        if (_email != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showCredentials,
            icon: const Icon(Icons.lock_outline),
            label: const Text('View my username & password'),
          ),
        ],
        OutlinedButton.icon(
          onPressed: _refreshEverything,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh everything'),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _showInclineInfo,
            icon: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.secondary),
            label: const Text('What is an incline block?'),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final email = await Auth.activeEmail();
            if (!mounted) return;
            if (email == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sign in to submit a query.')),
              );
              return;
            }
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QueryConversationPage(
                  userEmail: email,
                  isAdmin: Auth.isAdminActive && Auth.adminImpersonatingEmail != null,
                  onUpdated: () {
                    widget.onQueryActivity?.call();
                    if (mounted) setState(() {});
                  },
                ),
              ),
            );
            widget.onQueryActivity?.call();
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Contact admin'),
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
          onChanged: canEdit
              ? (v) async {
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
                }
              : null,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Select Customer Type',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _currentRegionKey == null ? null : _showPreviousFiveYears,
          icon: const Icon(Icons.history_toggle_off),
          label: const Text("View previous 5 years' tariffs"),
        ),
        const SizedBox(height: 16),
        if (Auth.isAdminViewing && !canEdit) ...[
          Card(
            color: Colors.red.shade50,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'You are viewing another user in read-only mode. Enable change mode from the Admin tab to make updates.',
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
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
                    final range = b.to == null ? '${b.from}-' : '${b.from}-${b.to}';
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
          onPressed: canEdit ? _checkTariffUpdate : null,
          icon: const Icon(Icons.system_update),
          label: const Text('Check tariff updates now'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: canEdit ? _resetTariffs : null,
          icon: const Icon(Icons.refresh),
          label: const Text('Clear cached tariffs'),
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
              '- Delete entries by removing the month in the Monthly tab.\n'
              '- Long-press a month to delete its data.\n'
              '- Monthly stats auto-reset when a new month starts (last 5 months kept).',
            ),
          ),
        ),
      ],
    );
  }
}






