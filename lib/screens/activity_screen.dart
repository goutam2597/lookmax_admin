import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const _gold = Color(0xFFD4AF37);
  static const _bg = Color(0xFF0E0E0E);
  static const _card = Color(0xFF161616);

  final _db = FirebaseFirestore.instance;

  String _filter = 'all';
  bool _loading = true;
  bool _loadingMore = false;
  bool _isExporting = false;
  String? _error;

  final List<Map<String, dynamic>> _registrations = [];
  final List<Map<String, dynamic>> _subscriptions = [];
  final List<Map<String, dynamic>> _notifications = [];

  // Pagination state
  DocumentSnapshot? _lastOnlineDoc;
  int _guestPage = 1;
  int _subPage = 1;
  int _notifPage = 1;
  bool _hasMoreOnline = false;
  bool _hasMoreGuest = false;
  bool _hasMoreSub = false;
  bool _hasMoreNotif = false;

  static const _filterDefs = [
    ('all', 'All', Colors.white70, Icons.grid_view_rounded),
    ('registration', 'Registrations', Colors.green, Icons.person_add_rounded),
    ('subscription', 'Subscriptions', _gold, Icons.card_membership_rounded),
    (
      'notification',
      'Notifications',
      Colors.blueAccent,
      Icons.notifications_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _registrations.clear();
      _subscriptions.clear();
      _notifications.clear();
      _lastOnlineDoc = null;
      _guestPage = 1;
      _subPage = 1;
      _notifPage = 1;
    });
    try {
      await Future.wait([
        _fetchOnlineRegistrations(reset: true),
        _fetchGuestRegistrations(reset: true),
        _fetchSubscriptions(reset: true),
        _fetchNotifications(reset: true),
      ]);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Data fetchers ─────────────────────────────────────────────────────────

  Future<void> _fetchOnlineRegistrations({bool reset = false}) async {
    Query q = _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(30);
    if (!reset && _lastOnlineDoc != null) {
      q = q.startAfterDocument(_lastOnlineDoc!);
    }
    final snap = await q.get();
    final batch = snap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return <String, dynamic>{
        '_type': 'registration_online',
        '_ts': data['createdAt'],
        'uid': d.id,
        'name':
            data['displayName'] ??
            (data['email'] as String?)?.split('@').first ??
            '—',
        'email': data['email'] ?? '',
        'authProvider': data['authProvider'] ?? 'email',
        'platform': (data['platform'] as String? ?? '').toUpperCase(),
      };
    }).toList();
    if (reset) {
      _registrations.removeWhere((e) => e['_type'] == 'registration_online');
    }
    _registrations.addAll(batch);
    _hasMoreOnline = snap.docs.length == 30;
    if (snap.docs.isNotEmpty) _lastOnlineDoc = snap.docs.last;
  }

  Future<void> _fetchGuestRegistrations({bool reset = false}) async {
    if (reset) _guestPage = 1;
    try {
      final res = await ApiService.get('/api/offline_users?page=$_guestPage');
      final rows = (res['users'] as List? ?? []);
      final batch = rows
          .map(
            (g) => <String, dynamic>{
              '_type': 'registration_guest',
              '_ts': g['first_seen'],
              'name': g['name'] ?? 'Unknown',
              'platform': (g['platform'] as String? ?? '').toUpperCase(),
              'gender': g['gender'] ?? '',
              'device_id': (g['device_id'] as String? ?? ''),
            },
          )
          .toList();
      if (reset) {
        _registrations.removeWhere((e) => e['_type'] == 'registration_guest');
      }
      _registrations.addAll(batch);
      _hasMoreGuest = rows.length == 50;
      if (!reset) _guestPage++;
    } catch (_) {}
  }

  Future<void> _fetchSubscriptions({bool reset = false}) async {
    if (reset) _subPage = 1;
    try {
      final res = await ApiService.get('/api/purchases?page=$_subPage');
      final rows = (res['purchases'] as List? ?? []);
      final batch = rows
          .map(
            (r) => <String, dynamic>{
              '_type': 'subscription',
              '_ts': r['purchased_at'],
              'uid': r['uid'] ?? '',
              'product_id': r['product_id'] ?? '',
              'purchase_type': r['purchase_type'] ?? '',
              'price': r['price'],
              'currency': r['currency'] ?? '',
              'store': r['store'] ?? '',
              'status': r['status'] ?? '',
            },
          )
          .toList();
      if (reset) _subscriptions.clear();
      _subscriptions.addAll(batch);
      _hasMoreSub = rows.length == 50;
      if (!reset) _subPage++;
    } catch (_) {}
  }

  Future<void> _fetchNotifications({bool reset = false}) async {
    if (reset) _notifPage = 1;
    try {
      final res = await ApiService.get('/api/fcm_token?page=$_notifPage');
      final rows = (res['tokens'] as List? ?? []);
      final batch = rows
          .map(
            (r) => <String, dynamic>{
              '_type': 'notification',
              '_ts': r['updated_at'],
              'uid': r['uid'] ?? '',
              'platform': (r['platform'] as String? ?? '').toUpperCase(),
            },
          )
          .toList();
      if (reset) _notifications.clear();
      _notifications.addAll(batch);
      _hasMoreNotif = rows.length == 50;
      if (!reset) _notifPage++;
    } catch (_) {}
  }

  // ── Load More ─────────────────────────────────────────────────────────────

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      switch (_filter) {
        case 'registration':
          await Future.wait([
            if (_hasMoreOnline) _fetchOnlineRegistrations(),
            if (_hasMoreGuest) _fetchGuestRegistrations(),
          ]);
          _sortRegistrations();
        case 'subscription':
          await _fetchSubscriptions();
        case 'notification':
          await _fetchNotifications();
        default:
          break;
      }
    } finally {
      setState(() => _loadingMore = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _sortRegistrations() {
    _registrations.sort(
      (a, b) => _dateOf(b['_ts']).compareTo(_dateOf(a['_ts'])),
    );
  }

  DateTime _dateOf(dynamic ts) {
    if (ts == null) return DateTime(2000);
    if (ts is Timestamp) return ts.toDate();
    return DateTime.tryParse(ts.toString()) ?? DateTime(2000);
  }

  String _timeAgo(dynamic ts) {
    final d = _dateOf(ts);
    if (d.year == 2000) return '—';
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _fmtDate(dynamic ts) {
    final d = _dateOf(ts);
    if (d.year == 2000) return '';
    return DateFormat('dd MMM yyyy  HH:mm').format(d);
  }

  List<Map<String, dynamic>> get _items {
    switch (_filter) {
      case 'registration':
        return _registrations;
      case 'subscription':
        return _subscriptions;
      case 'notification':
        return _notifications;
      default:
        final all = [..._registrations, ..._subscriptions, ..._notifications];
        all.sort((a, b) => _dateOf(b['_ts']).compareTo(_dateOf(a['_ts'])));
        return all;
    }
  }

  bool get _hasMore {
    switch (_filter) {
      case 'registration':
        return _hasMoreOnline || _hasMoreGuest;
      case 'subscription':
        return _hasMoreSub;
      case 'notification':
        return _hasMoreNotif;
      default:
        return false;
    }
  }

  // ── Export ────────────────────────────────────────────────────────────────

  String _csvRow(List<String> vals) =>
      vals.map((v) => '"${v.replaceAll('"', '""')}"').join(',');

  Future<void> _exportCsv() async {
    if (_isExporting) return;
    final items = _items;
    if (items.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final buf = StringBuffer();
      buf.writeln(
        'Type,Name / UID,Email,Platform,Provider / Store,Product,Price,Status,Date',
      );
      for (final item in items) {
        final type = item['_type'] as String? ?? '';
        final date = _fmtDate(item['_ts']);
        switch (type) {
          case 'registration_online':
            buf.writeln(
              _csvRow([
                'Online User',
                item['name'] as String? ?? '',
                item['email'] as String? ?? '',
                item['platform'] as String? ?? '',
                item['authProvider'] as String? ?? '',
                '',
                '',
                '',
                date,
              ]),
            );
          case 'registration_guest':
            buf.writeln(
              _csvRow([
                'Guest',
                item['name'] as String? ?? '',
                '',
                item['platform'] as String? ?? '',
                '',
                '',
                '',
                '',
                date,
              ]),
            );
          case 'subscription':
            buf.writeln(
              _csvRow([
                'Subscription',
                item['uid'] as String? ?? '',
                '',
                '',
                item['store'] as String? ?? '',
                item['product_id'] as String? ?? '',
                item['price']?.toString() ?? '',
                item['status'] as String? ?? '',
                date,
              ]),
            );
          default:
            buf.writeln(
              _csvRow([
                'Notification',
                item['uid'] as String? ?? '',
                '',
                item['platform'] as String? ?? '',
                '',
                '',
                '',
                '',
                date,
              ]),
            );
        }
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/lookmax_activity.csv');
      await file.writeAsString(buf.toString());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'LookMaxing Activity Export',
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.small(
              backgroundColor: _gold,
              onPressed: _isExporting ? null : _exportCsv,
              tooltip: 'Export CSV',
              child: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.download_rounded,
                      color: Colors.black,
                      size: 18,
                    ),
            ),
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [],
        body: Column(
          children: [
            _buildFilterBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() => SizedBox(
    height: 50,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      children: _filterDefs.map((def) {
        final (value, label, color, icon) = def;
        final active = _filter == value;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () {
              if (_filter == value) return;
              setState(() => _filter = value);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: active
                    ? color.withValues(alpha: 0.18)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? color : Colors.white12,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: active ? color : Colors.white30, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? color : Colors.white38,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _gold, strokeWidth: 2),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadInitial,
              child: const Text('Retry', style: TextStyle(color: _gold)),
            ),
          ],
        ),
      );
    }
    final items = _items;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, color: Colors.white12, size: 52),
            const SizedBox(height: 12),
            Text(
              'No activity yet.',
              style: GoogleFonts.poppins(color: Colors.white30, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      itemCount: items.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == items.length) return _buildLoadMore();
        final item = items[i];
        final isFirst = i == 0;
        final isLast = i == items.length - 1 && !_hasMore;
        return _buildRow(item, isFirst: isFirst, isLast: isLast);
      },
    );
  }

  // ── Timeline row ──────────────────────────────────────────────────────────

  Widget _buildRow(
    Map<String, dynamic> item, {
    required bool isFirst,
    required bool isLast,
  }) {
    final type = item['_type'] as String? ?? '';
    final Color color;
    final IconData icon;

    switch (type) {
      case 'registration_online':
        color = Colors.green;
        icon = Icons.person_add_rounded;
      case 'registration_guest':
        color = Colors.purpleAccent;
        icon = Icons.person_outline_rounded;
      case 'subscription':
        color = _gold;
        icon = Icons.card_membership_rounded;
      default: // notification
        color = Colors.blueAccent;
        icon = Icons.notifications_rounded;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isFirst)
                  Container(width: 2, height: 10, color: Colors.white10)
                else
                  const SizedBox(height: 10),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.15),
                    border: Border.all(
                      color: color.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.18),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: Colors.white10))
                else
                  const SizedBox(height: 10),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: _card,
                    border: Border(
                      left: BorderSide(
                        color: color.withValues(alpha: 0.6),
                        width: 2.5,
                      ),
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                      right: BorderSide(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: switch (type) {
                      'registration_online' => _regOnlineCard(item, color),
                      'registration_guest' => _regGuestCard(item, color),
                      'subscription' => _subscriptionCard(item, color),
                      _ => _notificationCard(item, color),
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card bodies ───────────────────────────────────────────────────────────

  Widget _regOnlineCard(Map<String, dynamic> item, Color color) {
    final name = item['name'] as String? ?? '—';
    final email = item['email'] as String? ?? '';
    final platform = item['platform'] as String? ?? '';
    final provider = item['authProvider'] as String? ?? 'email';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _pill('Online', Colors.green),
                ],
              ),
              if (email.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    email,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (platform.isNotEmpty) _pill(platform, Colors.white38),
                  if (platform.isNotEmpty) const SizedBox(width: 6),
                  _pill(
                    provider == 'google' ? 'Google' : 'Email',
                    provider == 'google' ? Colors.redAccent : Colors.blueGrey,
                  ),
                ],
              ),
              if (_fmtDate(item['_ts']).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    _fmtDate(item['_ts']),
                    style: const TextStyle(color: Colors.white24, fontSize: 9),
                  ),
                ),
            ],
          ),
        ),
        _timeBadge(item['_ts'], color),
      ],
    );
  }

  Widget _regGuestCard(Map<String, dynamic> item, Color color) {
    final name = item['name'] as String? ?? 'Unknown';
    final platform = item['platform'] as String? ?? '';
    final gender = item['gender'] as String? ?? '';
    final deviceId = item['device_id'] as String? ?? '';
    final shortId = deviceId.length > 12
        ? '${deviceId.substring(0, 12)}…'
        : deviceId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _pill('Guest', Colors.purpleAccent),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (platform.isNotEmpty) ...[
                    _pill(platform, Colors.white38),
                    const SizedBox(width: 6),
                  ],
                  if (gender.isNotEmpty) ...[
                    _pill(gender, Colors.white30),
                    const SizedBox(width: 6),
                  ],
                  if (shortId.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_android_rounded,
                          size: 10,
                          color: Colors.white24,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          shortId,
                          style: const TextStyle(
                            color: Colors.white30,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (_fmtDate(item['_ts']).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    _fmtDate(item['_ts']),
                    style: const TextStyle(color: Colors.white24, fontSize: 9),
                  ),
                ),
            ],
          ),
        ),
        _timeBadge(item['_ts'], color),
      ],
    );
  }

  Widget _subscriptionCard(Map<String, dynamic> item, Color color) {
    final productId = item['product_id'] as String? ?? '—';
    final purchaseType = item['purchase_type'] as String? ?? '';
    final price = item['price'];
    final currency = item['currency'] as String? ?? '';
    final store = item['store'] as String? ?? '';
    final status = item['status'] as String? ?? '';
    final uid = item['uid'] as String? ?? '';
    final shortUid = uid.length > 12 ? '${uid.substring(0, 12)}…' : uid;
    final priceStr = price != null
        ? '$currency ${price.toStringAsFixed(2)}'
        : '—';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      productId.replaceAll('_', ' '),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (purchaseType.isNotEmpty) ...[
                    _pill(purchaseType, color),
                    const SizedBox(width: 6),
                  ],
                  _pill(priceStr, Colors.green),
                  const SizedBox(width: 6),
                  if (store.isNotEmpty)
                    _pill(
                      store == 'apple' ? '🍎 Apple' : '▶ Google',
                      store == 'apple' ? Colors.white54 : Colors.green,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _pill(
                    status,
                    status == 'active' ? Colors.green : Colors.redAccent,
                  ),
                  if (shortUid.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.fingerprint_rounded,
                      size: 10,
                      color: Colors.white24,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      shortUid,
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ],
              ),
              if (_fmtDate(item['_ts']).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    _fmtDate(item['_ts']),
                    style: const TextStyle(color: Colors.white24, fontSize: 9),
                  ),
                ),
            ],
          ),
        ),
        _timeBadge(item['_ts'], color),
      ],
    );
  }

  Widget _notificationCard(Map<String, dynamic> item, Color color) {
    final uid = item['uid'] as String? ?? '';
    final shortUid = uid.length > 16 ? '${uid.substring(0, 16)}…' : uid;
    final platform = item['platform'] as String? ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notifications Enabled',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (platform.isNotEmpty) ...[
                    _pill(platform, Colors.blueAccent),
                    const SizedBox(width: 6),
                  ],
                  if (shortUid.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.fingerprint_rounded,
                          size: 10,
                          color: Colors.white24,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          shortUid,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (_fmtDate(item['_ts']).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    _fmtDate(item['_ts']),
                    style: const TextStyle(color: Colors.white24, fontSize: 9),
                  ),
                ),
            ],
          ),
        ),
        _timeBadge(item['_ts'], color),
      ],
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _timeBadge(dynamic ts, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      _timeAgo(ts),
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(
      label.length > 14 ? '${label.substring(0, 13)}…' : label,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
    ),
  );

  Widget _buildLoadMore() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Center(
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _gold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        ),
        icon: _loadingMore
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(color: _gold, strokeWidth: 2),
              )
            : const Icon(Icons.expand_more_rounded, color: _gold, size: 18),
        label: Text(
          _loadingMore ? 'Loading…' : 'Load More',
          style: const TextStyle(
            color: _gold,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: _loadingMore ? null : _loadMore,
      ),
    ),
  );
}
