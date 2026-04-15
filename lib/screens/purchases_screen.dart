import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});
  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  List<dynamic> _purchases = [];
  List<dynamic> _popular = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _total = 0;
  int _activeCount = 0;
  double _revenue = 0;
  double _monthRevenue = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  static const _gold = Color(0xFFD4AF37);
  static const _bg = Color(0xFF0E0E0E);
  static const _card = Color(0xFF181818);
  static const _border = Color(0xFF2C2C2C);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = true}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _purchases = [];
        _hasMore = true;
      });
    }
    try {
      final res = await ApiService.get('/api/purchases?page=$_page');
      final batch = List<dynamic>.from(res['purchases'] ?? []);
      setState(() {
        _total = res['total'] as int? ?? 0;
        _activeCount = res['active_count'] as int? ?? 0;
        _revenue = _dbl(res['revenue']);
        _monthRevenue = _dbl(res['month_revenue']);
        _popular = List<dynamic>.from(res['popular'] ?? []);
        _purchases = refresh ? batch : [..._purchases, ...batch];
        _hasMore = batch.length == 50;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    _page++;
    await _load(refresh: false);
  }

  // Safe numeric parsers — handles both num and String from JSON
  static double _dbl(dynamic v) =>
      v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
  static int _int(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;

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
                  // ── Stat cards ────────────────────────────────────────
                  SliverToBoxAdapter(child: _statSection()),

                  // ── Most Purchased ────────────────────────────────────
                  if (_popular.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _sectionHeader(
                        Icons.emoji_events_rounded,
                        'Most Purchased',
                        badge: '${_popular.length}',
                      ),
                    ),
                    SliverToBoxAdapter(child: _popularSection()),
                  ],

                  // ── Purchase History ──────────────────────────────────
                  SliverToBoxAdapter(
                    child: _sectionHeader(
                      Icons.receipt_long_rounded,
                      'Purchase History',
                      badge: '$_total',
                    ),
                  ),

                  _purchases.isEmpty
                      ? SliverToBoxAdapter(child: _emptyHistory())
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                          sliver: SliverList.builder(
                            itemCount: _purchases.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _purchaseTile(
                                _purchases[i] as Map<String, dynamic>,
                              ),
                            ),
                          ),
                        ),

                  // ── Load more ─────────────────────────────────────────
                  if (_hasMore) SliverToBoxAdapter(child: _loadMoreBtn()),

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
              'Try Again',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            onPressed: _load,
          ),
        ],
      ),
    ),
  );

  // ── Section header ────────────────────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String title, {String? badge}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Row(
        children: [
          Icon(icon, color: _gold, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: _gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const Spacer(),
          Container(height: 1, width: 40, color: _gold.withValues(alpha: 0.25)),
        ],
      ),
    );
  }

  // ── Stat cards ────────────────────────────────────────────────────────────

  Widget _statSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.receipt_long_rounded,
                  label: 'Total Purchases',
                  value: '$_total',
                  color: Colors.white54,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  icon: Icons.verified_rounded,
                  label: 'Active Subs',
                  value: '$_activeCount',
                  color: const Color(0xFF4CAF50),
                  glow: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.attach_money_rounded,
                  label: 'Total Revenue',
                  value: '\$${_revenue.toStringAsFixed(2)}',
                  color: _gold,
                  glow: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  icon: Icons.calendar_month_rounded,
                  label: 'This Month',
                  value: '\$${_monthRevenue.toStringAsFixed(2)}',
                  color: const Color(0xFF64B5F6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool glow = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: glow ? color.withValues(alpha: 0.3) : _border,
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              if (glow)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: glow ? color : Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Popular packages ──────────────────────────────────────────────────────

  Widget _popularSection() {
    final maxCount = _popular
        .map((p) => _int(p['total_purchases']))
        .fold(0, (a, b) => a > b ? a : b)
        .toDouble();

    return Column(
      children: List.generate(_popular.length, (i) {
        final p = _popular[i] as Map<String, dynamic>;
        final productId = p['product_id'] as String? ?? '';
        final type = p['purchase_type'] as String? ?? '';
        final count = _int(p['total_purchases']);
        final revenue = _dbl(p['revenue']);
        final avgPrice = _dbl(p['avg_price']);
        final frac = maxCount > 0 ? count / maxCount : 0.0;

        final rankColor = i == 0
            ? _gold
            : i == 1
            ? const Color(0xFFB0BEC5) // silver
            : i == 2
            ? const Color(0xFFCD7F32) // bronze
            : Colors.white24;

        return Padding(
          padding: EdgeInsets.fromLTRB(14, i == 0 ? 0 : 6, 14, 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: i == 0 ? _gold.withValues(alpha: 0.35) : _border,
                width: i == 0 ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Rank
                SizedBox(
                  width: 36,
                  child: Column(
                    children: [
                      if (i == 0)
                        Icon(
                          Icons.emoji_events_rounded,
                          color: rankColor,
                          size: 22,
                        )
                      else
                        Text(
                          '#${i + 1}',
                          style: GoogleFonts.poppins(
                            color: rankColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _productLabel(productId),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          _chip(type, i == 0 ? _gold : Colors.white38),
                        ],
                      ),
                      const SizedBox(height: 7),
                      // Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation(rankColor),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Inline stats
                      Row(
                        children: [
                          _inlineStat('$count sales', rankColor),
                          const SizedBox(width: 12),
                          _inlineStat(
                            '\$${revenue.toStringAsFixed(2)}',
                            const Color(0xFF66BB6A),
                          ),
                          const SizedBox(width: 12),
                          _inlineStat(
                            'avg \$${avgPrice.toStringAsFixed(2)}',
                            const Color(0xFF64B5F6),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _inlineStat(String text, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  // ── Purchase tile ─────────────────────────────────────────────────────────

  static Widget _emptyHistory() => Padding(
    padding: EdgeInsets.symmetric(vertical: 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.receipt_long_outlined, color: Colors.white12, size: 52),
        SizedBox(height: 12),
        Text(
          'No purchases yet',
          style: TextStyle(color: Colors.white24, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _purchaseTile(Map<String, dynamic> p) {
    final productId = p['product_id'] as String? ?? '';
    final type = p['purchase_type'] as String? ?? '';
    final status = p['status'] as String? ?? '';
    final priceNum = _dbl(p['price']);
    final hasPri = p['price'] != null;
    final currency = p['currency'] as String? ?? 'USD';
    final rawDate = p['purchased_at'] as String? ?? '';
    final date = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
    final uid = p['uid'] as String? ?? p['device_id'] as String? ?? '';
    final store = p['store'] as String? ?? 'google';
    final isActive = status == 'active';
    final isLifetime = type == 'lifetime' || productId.contains('lifetime');
    final accentColor = isActive ? _gold : Colors.white12;
    final typeColor = isLifetime ? _gold : Colors.purpleAccent;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: accentColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isLifetime
                            ? Icons.all_inclusive_rounded
                            : Icons.autorenew_rounded,
                        color: typeColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 11),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _productLabel(productId),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _chip(type, Colors.white24),
                              const SizedBox(width: 5),
                              _chip(store, Colors.white24),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${uid.length > 13 ? uid.substring(0, 13) : uid}  ·  $date',
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Price + status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          hasPri
                              ? '${currency.isEmpty ? 'USD' : currency} ${priceNum.toStringAsFixed(2)}'
                              : '—',
                          style: TextStyle(
                            color: hasPri ? _gold : Colors.white24,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        _statusPill(status, isActive),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status, bool isActive) {
    final c = isActive ? const Color(0xFF66BB6A) : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: c,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
    ),
  );

  // ── Load more ─────────────────────────────────────────────────────────────

  Widget _loadMoreBtn() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: _gold,
          side: BorderSide(color: _gold.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _loadingMore ? null : _loadMore,
        child: _loadingMore
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(color: _gold, strokeWidth: 2),
              )
            : Text(
                'Load More',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
      ),
    ),
  );

  String _productLabel(String id) {
    if (id.contains('lifetime')) return 'Lifetime Premium';
    if (id.contains('monthly')) return 'Monthly Premium';
    return id;
  }
}
