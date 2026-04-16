import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = FirebaseFirestore.instance;

  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _authStats;
  Map<String, dynamic>? _bizStats;
  List<Map<String, dynamic>> _toolCounts = [];
  List<Map<String, dynamic>> _recentUsers = [];
  bool _loading = true;
  String? _error;

  // Live presence
  StreamSubscription<QuerySnapshot>? _presenceSub;
  Timer? _presenceTimer;
  List<Map<String, dynamic>> _liveUsers = [];

  static const _gold = Color(0xFFD4AF37);
  static const _bg = Color(0xFF0E0E0E);
  static const _card = Color(0xFF161616);
  static const _border = Color(0xFF282828);

  @override
  void initState() {
    super.initState();
    _load();
    _initPresence();
  }

  @override
  void dispose() {
    _presenceSub?.cancel();
    _presenceTimer?.cancel();
    super.dispose();
  }

  void _initPresence() {
    _presenceSub?.cancel();
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(minutes: 10)),
    );
    _presenceSub = _db
        .collection('users')
        .where('lastSeen', isGreaterThan: cutoff)
        .snapshots()
        .listen(
      (snap) {
        final now = DateTime.now();
        final threshold = now.subtract(const Duration(minutes: 10));
        if (!mounted) return;
        setState(() {
          _liveUsers = snap.docs.where((d) {
            final ts = (d.data() as Map)['lastSeen'] as Timestamp?;
            return ts != null && ts.toDate().isAfter(threshold);
          }).map((d) => {'uid': d.id, ...(d.data() as Map<String, dynamic>)}).toList();
        });
      },
      onError: (e) => debugPrint('[Presence] Firestore error: $e'),
    );
    // Re-init every 5 min to keep the threshold fresh
    _presenceTimer?.cancel();
    _presenceTimer = Timer(const Duration(minutes: 5), _initPresence);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final day1 = Timestamp.fromDate(now.subtract(const Duration(days: 1)));
      final week1 = Timestamp.fromDate(now.subtract(const Duration(days: 7)));
      final usersRef = _db.collection('users');
      final eventsRef = _db.collection('appEvents');

      final both = await Future.wait([
        Future.wait([
          usersRef.count().get(),
          usersRef.where('lastSeen', isGreaterThan: day1).count().get(),
          usersRef.where('lastSeen', isGreaterThan: week1).count().get(),
          usersRef.where('platform', isEqualTo: 'android').count().get(),
          usersRef.where('platform', isEqualTo: 'ios').count().get(),
          eventsRef.where('event', isEqualTo: 'tool_use').limit(500).get(),
          usersRef.orderBy('createdAt', descending: true).limit(8).get(),
          usersRef.where('authProvider', isEqualTo: 'google').count().get(),
          usersRef.where('authProvider', isEqualTo: 'email').count().get(),
        ]),
        ApiService.get('/api/stats'),
      ]);

      final r = both[0] as List<dynamic>;
      final bs = both[1] as Map<String, dynamic>;

      final toolEvents = (r[5] as QuerySnapshot).docs;
      final counts = <String, int>{};
      for (final d in toolEvents) {
        final t = (d.data() as Map)['tool'] as String? ?? 'unknown';
        counts[t] = (counts[t] ?? 0) + 1;
      }
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final fbTotal = (r[0] as AggregateQuerySnapshot).count ?? 0;
      final fbActDay = (r[1] as AggregateQuerySnapshot).count ?? 0;
      final fbActWk = (r[2] as AggregateQuerySnapshot).count ?? 0;
      final fbAndroid = (r[3] as AggregateQuerySnapshot).count ?? 0;
      final fbIos = (r[4] as AggregateQuerySnapshot).count ?? 0;
      final fbGoogle = (r[7] as AggregateQuerySnapshot).count ?? 0;
      final fbEmail = (r[8] as AggregateQuerySnapshot).count ?? 0;

      final gTotal = bs['guest_total'] as int? ?? 0;
      final gActDay = bs['guest_active_today'] as int? ?? 0;
      final gActWk = bs['guest_active_week'] as int? ?? 0;
      final gAndroid = bs['guest_android'] as int? ?? 0;
      final gIos = bs['guest_ios'] as int? ?? 0;

      setState(() {
        _stats = {
          'totalFirebase': fbTotal,
          'totalGuest': gTotal,
          'total': fbTotal + gTotal,
          'activeDay': fbActDay + gActDay,
          'activeWeek': fbActWk + gActWk,
          'android': fbAndroid + gAndroid,
          'ios': fbIos + gIos,
        };
        _authStats = {'google': fbGoogle, 'email': fbEmail, 'total': fbTotal};
        _bizStats = {
          'purchaseTotal': bs['purchase_total'] ?? 0,
          'purchaseActive': bs['purchase_active'] ?? 0,
          'revenue': _dbl(bs['revenue']),
        };
        _toolCounts = sorted
            .take(8)
            .map((e) => {'tool': e.key, 'count': e.value})
            .toList();
        _recentUsers = (r[6] as QuerySnapshot).docs
            .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  static double _dbl(dynamic v) =>
      v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,

      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _error != null
          ? _errorView()
          : RefreshIndicator(
              color: _gold,
              backgroundColor: _card,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _liveUsersCard()),
                  SliverToBoxAdapter(child: _heroCard()),
                  SliverToBoxAdapter(child: _activeRow()),
                  SliverToBoxAdapter(child: _breakdownRow()),
                  SliverToBoxAdapter(child: _bizRow()),
                  if (_toolCounts.isNotEmpty)
                    SliverToBoxAdapter(child: _toolSection()),
                  if (_recentUsers.isNotEmpty)
                    SliverToBoxAdapter(child: _recentSection()),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white24, size: 58),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'Retry',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            onPressed: _load,
          ),
        ],
      ),
    ),
  );

  // ── Live users card ───────────────────────────────────────────────────────

  Widget _liveUsersCard() {
    final count = _liveUsers.length;
    final byCountry = <String, int>{};
    for (final u in _liveUsers) {
      final c = (u['country'] as String? ?? '').isNotEmpty
          ? u['country'] as String
          : 'Unknown';
      byCountry[c] = (byCountry[c] ?? 0) + 1;
    }
    final sorted = byCountry.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: count > 0
                ? Colors.green.withValues(alpha: 0.35)
                : Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Pulsing green dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: count > 0 ? Colors.green : Colors.white24,
                    shape: BoxShape.circle,
                    boxShadow: count > 0
                        ? [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Live Now',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'Last 10 min',
                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$count',
                  style: GoogleFonts.poppins(
                    color: count > 0 ? Colors.green : Colors.white38,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    count == 1 ? 'user online' : 'users online',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (top.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: top.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 10,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${e.key}  ${e.value}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ] else if (count == 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'No active users right now',
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Hero card ─────────────────────────────────────────────────────────────

  Widget _heroCard() {
    final total = _stats!['total'] as int;
    final firebase = _stats!['totalFirebase'] as int;
    final guest = _stats!['totalGuest'] as int;
    final fbFrac = total > 0 ? firebase / total : 0.5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _gold.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: 0.05),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_rounded, color: _gold, size: 13),
                      SizedBox(width: 5),
                      Text(
                        'Total Users',
                        style: TextStyle(
                          color: _gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.white24,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$total',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 14),
            // Firebase vs Guest split bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    Expanded(
                      flex: (fbFrac * 100).round().clamp(1, 99),
                      child: Container(color: _gold),
                    ),
                    Expanded(
                      flex: ((1 - fbFrac) * 100).round().clamp(1, 99),
                      child: Container(
                        color: Colors.purpleAccent.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _legendDot(_gold, 'Firebase', '$firebase'),
                const SizedBox(width: 18),
                _legendDot(Colors.purpleAccent, 'Guest', '$guest'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label, String val) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        '$label ',
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      Text(
        val,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  // ── Active row ────────────────────────────────────────────────────────────

  Widget _activeRow() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    child: Row(
      children: [
        Expanded(
          child: _miniCard(
            icon: Icons.circle,
            iconColor: const Color(0xFF66BB6A),
            label: 'Active Today',
            value: '${_stats!['activeDay']}',
            glow: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniCard(
            icon: Icons.calendar_today_rounded,
            iconColor: Colors.blueAccent,
            label: 'Active 7 Days',
            value: '${_stats!['activeWeek']}',
          ),
        ),
      ],
    ),
  );

  // ── Breakdown row ─────────────────────────────────────────────────────────

  Widget _breakdownRow() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _breakdownCard(
            title: 'Auth Providers',
            icon: Icons.lock_rounded,
            items: [
              _BI(
                'Google',
                _authStats!['google'] as int,
                _authStats!['total'] as int,
                Colors.blueAccent,
              ),
              _BI(
                'Email',
                _authStats!['email'] as int,
                _authStats!['total'] as int,
                Colors.orangeAccent,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _breakdownCard(
            title: 'Platforms',
            icon: Icons.devices_rounded,
            items: [
              _BI(
                'Android',
                _stats!['android'] as int,
                _stats!['total'] as int,
                const Color(0xFF66BB6A),
              ),
              _BI(
                'iOS',
                _stats!['ios'] as int,
                _stats!['total'] as int,
                Colors.blueGrey,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _breakdownCard({
    required String title,
    required IconData icon,
    required List<_BI> items,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white38, size: 13),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          final frac = item.total > 0 ? item.count / item.total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      '${(frac * 100).round()}%',
                      style: TextStyle(
                        color: item.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation(item.color),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.count}',
                  style: const TextStyle(color: Colors.white24, fontSize: 9.5),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );

  // ── Biz row ───────────────────────────────────────────────────────────────

  Widget _bizRow() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    child: Row(
      children: [
        Expanded(
          child: _miniCard(
            icon: Icons.verified_rounded,
            iconColor: _gold,
            label: 'Active Subs',
            value: '${_bizStats!['purchaseActive']}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniCard(
            icon: Icons.attach_money_rounded,
            iconColor: const Color(0xFF66BB6A),
            label: 'Total Revenue',
            value: '\$${(_bizStats!['revenue'] as double).toStringAsFixed(2)}',
          ),
        ),
      ],
    ),
  );

  // ── Mini stat card ────────────────────────────────────────────────────────

  Widget _miniCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool glow = false,
  }) => Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: glow ? iconColor.withValues(alpha: 0.25) : _border,
      ),
      boxShadow: glow
          ? [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.06),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ]
          : null,
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: glow
              ? Center(
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withValues(alpha: 0.55),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                )
              : Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Tool usage ────────────────────────────────────────────────────────────

  Widget _toolSection() {
    final max = (_toolCounts.first['count'] as int).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(Icons.bar_chart_rounded, 'Tool Usage'),
            const SizedBox(height: 14),
            ..._toolCounts.asMap().entries.map((e) {
              final i = e.key;
              final t = e.value;
              final frac = max > 0 ? (t['count'] as int) / max : 0.0;
              final isTop = i == 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        _toolLabel(t['tool'] as String),
                        style: TextStyle(
                          color: isTop ? Colors.white : Colors.white54,
                          fontSize: 11,
                          fontWeight: isTop ? FontWeight.w600 : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          valueColor: AlwaysStoppedAnimation(
                            isTop ? _gold : _gold.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${t['count']}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: isTop ? _gold : Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Recent signups ────────────────────────────────────────────────────────

  Widget _recentSection() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
    child: Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _cardHeader(Icons.person_add_rounded, 'Recent Signups'),
          ),
          const SizedBox(height: 8),
          ..._recentUsers.asMap().entries.map((e) {
            final i = e.key;
            final u = e.value;
            final name = u['displayName'] as String? ?? '—';
            final email =
                u['email'] as String? ?? (u['id'] as String).substring(0, 12);
            final provider = u['authProvider'] as String? ?? 'email';
            final platform = u['platform'] as String? ?? '';
            final isGoogle = provider == 'google';

            return Column(
              children: [
                if (i > 0)
                  Divider(height: 1, color: _border, indent: 14, endIndent: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _gold.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            (name.isNotEmpty && name != '—'
                                    ? name[0]
                                    : email[0])
                                .toUpperCase(),
                            style: const TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              email,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _pill(
                            isGoogle ? 'Google' : 'Email',
                            isGoogle ? Colors.blueAccent : Colors.orangeAccent,
                          ),
                          if (platform.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _pill(
                              platform,
                              platform == 'android'
                                  ? const Color(0xFF66BB6A)
                                  : Colors.blueGrey,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _cardHeader(IconData icon, String title) => Row(
    children: [
      Icon(icon, color: _gold, size: 15),
      const SizedBox(width: 8),
      Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      const Spacer(),
      Container(height: 1, width: 36, color: _gold.withValues(alpha: 0.3)),
    ],
  );

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  String _toolLabel(String key) =>
      const {
        'face_shape': 'Face Shape',
        'symmetry': 'Symmetry',
        'nose': 'Nose Shape',
        'jawline': 'Jawline',
        'eyebrow': 'Eyebrow',
        'skin_glow': 'Skin Glow',
        'colour_analysis': 'Colour',
        'group_rating': 'Group Rating',
        'hairstyle': 'Hairstyle',
        'hairstyle_sim': 'Hairstyle Sim',
        'hair_colour': 'Hair Colour',
        'body_comp': 'Body Comp',
        'height_sim': 'Height Sim',
        'outfit_analysis': 'Outfit',
        'outfit_change': 'Outfit Change',
      }[key] ??
      key;
}

class _BI {
  final String label;
  final int count;
  final int total;
  final Color color;
  const _BI(this.label, this.count, this.total, this.color);
}
