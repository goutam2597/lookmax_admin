import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static const _gold = Color(0xFFD4AF37);
  static const _bg = Color(0xFF0E0E0E);
  static const _card = Color(0xFF161616);
  static const _card2 = Color(0xFF1C1C1C);

  final _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  final _searchCtrl = TextEditingController();

  DocumentSnapshot? _lastDoc;
  bool _hasMoreOnline = true;
  static const _pageSize = 50;

  int _guestPage = 1;
  bool _hasMoreGuest = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _all = [];
      _lastDoc = null;
      _hasMoreOnline = true;
      _guestPage = 1;
      _hasMoreGuest = true;
    });
    try {
      await Future.wait([
        _loadOnline(refresh: true),
        _loadGuests(refresh: true),
      ]);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
      _applyFilter();
    }
  }

  Future<void> _loadOnline({bool refresh = true}) async {
    Query q = _db
        .collection('users')
        .orderBy('lastSeen', descending: true)
        .limit(_pageSize);
    if (!refresh && _lastDoc != null) q = q.startAfterDocument(_lastDoc!);
    final snap = await q.get();
    final batch = snap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return {'type': 'online', 'uid': d.id, ...data};
    }).toList();
    if (refresh) _all.removeWhere((u) => u['type'] == 'online');
    _all.addAll(batch);
    _hasMoreOnline = snap.docs.length == _pageSize;
    if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
  }

  Future<void> _loadGuests({bool refresh = true}) async {
    final page = refresh ? 1 : _guestPage;
    final res = await ApiService.get('/api/offline_users?page=$page');
    final batch = (res['users'] as List? ?? [])
        .map((u) => {'type': 'guest', ...(u as Map<String, dynamic>)})
        .toList();
    if (refresh) _all.removeWhere((u) => u['type'] == 'guest');
    _all.addAll(batch);
    _hasMoreGuest = batch.length == 50;
    if (!refresh) _guestPage++;
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((u) {
        if (_filter == 'online' && u['type'] != 'online') return false;
        if (_filter == 'guest' && u['type'] != 'guest') return false;
        if (q.isEmpty) return true;
        final email = (u['email'] as String? ?? '').toLowerCase();
        final name = (u['displayName'] as String? ?? u['name'] as String? ?? '')
            .toLowerCase();
        return email.contains(q) || name.contains(q);
      }).toList();
    });
  }

  int get _onlineCount => _all.where((u) => u['type'] == 'online').length;
  int get _guestCount => _all.where((u) => u['type'] == 'guest').length;

  Future<void> _changePassword(String uid, String email) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Change Password',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              email,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'New password (min 6 chars)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF252525),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Update',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || ctrl.text.isEmpty) return;
    try {
      await ApiService.post('/api/update_password', {
        'uid': uid,
        'newPassword': ctrl.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleDisable(String uid, bool currentlyDisabled) async {
    final action = currentlyDisabled ? 'Enable' : 'Disable';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '$action User',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to $action this user?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: currentlyDisabled ? Colors.green : Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              action,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.post('/api/toggle_disable', {
        'uid': uid,
        'disabled': !currentlyDisabled,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${action}d'),
            backgroundColor: Colors.green,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _fmt(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) return DateFormat('dd MMM yyyy').format(ts.toDate());
    if (ts is String && ts.length >= 10) return ts.substring(0, 10);
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [],
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _gold, strokeWidth: 2),
              )
            : _error != null
            ? _buildError()
            : Column(
                children: [
                  _buildStatRow(),
                  _buildSearch(),
                  _buildFilterChips(),
                  Expanded(child: _buildList()),
                ],
              ),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: Colors.redAccent,
          size: 52,
        ),
        const SizedBox(height: 12),
        Text(
          _error!,
          style: const TextStyle(color: Colors.white60),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _gold,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(
            Icons.refresh_rounded,
            color: Colors.black,
            size: 16,
          ),
          label: const Text(
            'Retry',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
          ),
          onPressed: _load,
        ),
      ],
    ),
  );

  Widget _buildStatRow() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
    child: Row(
      children: [
        _statChip(
          '${_all.length}',
          'Total',
          Colors.white70,
          Icons.people_rounded,
        ),
        const SizedBox(width: 8),
        _statChip(
          '$_onlineCount',
          'Online',
          _gold,
          Icons.verified_user_rounded,
        ),
        const SizedBox(width: 8),
        _statChip(
          '$_guestCount',
          'Guest',
          Colors.purpleAccent,
          Icons.person_outline_rounded,
        ),
      ],
    ),
  );

  Widget _statChip(String count, String label, Color color, IconData icon) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildSearch() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
    child: TextField(
      controller: _searchCtrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search name or email…',
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Colors.white30,
          size: 20,
        ),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white30,
                  size: 18,
                ),
                onPressed: () {
                  _searchCtrl.clear();
                  _applyFilter();
                },
              )
            : null,
        filled: true,
        fillColor: _card,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _gold, width: 1),
        ),
      ),
    ),
  );

  Widget _buildFilterChips() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
    child: Row(
      children: [
        _chip('all', 'All', Colors.white60),
        const SizedBox(width: 8),
        _chip('online', 'Online', _gold),
        const SizedBox(width: 8),
        _chip('guest', 'Guest', Colors.purpleAccent),
      ],
    ),
  );

  Widget _chip(String value, String label, Color color) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        _applyFilter();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.white38,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_filtered.isEmpty) {
      return const Center(
        child: Text(
          'No users found.',
          style: TextStyle(color: Colors.white38, fontSize: 14),
        ),
      );
    }
    return RefreshIndicator(
      color: _gold,
      backgroundColor: _card,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        itemCount: _filtered.length + 1,
        itemBuilder: (_, i) {
          if (i == _filtered.length) return _loadMoreRow();
          final u = _filtered[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: u['type'] == 'guest' ? _guestCard(u) : _onlineCard(u),
          );
        },
      ),
    );
  }

  Widget _onlineCard(Map<String, dynamic> u) {
    final provider = u['authProvider'] as String? ?? 'email';
    final platform = (u['platform'] as String? ?? '?').toUpperCase();
    final uid = u['uid'] as String;
    final isGoogle = provider == 'google';
    final name = u['displayName'] as String? ?? '';
    final email = u['email'] as String? ?? '(no email)';
    final initial = name.isNotEmpty
        ? name[0].toUpperCase()
        : email[0].toUpperCase();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          border: Border(
            left: const BorderSide(color: _gold, width: 3),
            top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withValues(alpha: 0.12),
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.15),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name.isNotEmpty ? name : email,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _pill('Online', _gold),
                      ],
                    ),
                    if (name.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          email,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _pill(
                          isGoogle ? 'Google' : 'Email',
                          isGoogle ? Colors.blue : Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        _pill(platform, Colors.white38),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: uid));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('UID copied'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              const Icon(
                                Icons.copy_rounded,
                                size: 10,
                                color: Colors.white24,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                uid.substring(0, 8),
                                style: const TextStyle(
                                  color: Colors.white24,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Joined ${_fmt(u['createdAt'])}  ·  Last seen ${_fmt(u['lastSeen'])}',
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              // Menu
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white24,
                  size: 20,
                ),
                color: _card2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (val) {
                  if (val == 'password') _changePassword(uid, email);
                  if (val == 'disable') _toggleDisable(uid, false);
                  if (val == 'enable') _toggleDisable(uid, true);
                },
                itemBuilder: (_) => [
                  _menuItem(
                    'password',
                    Icons.lock_reset_rounded,
                    'Change Password',
                    Colors.white70,
                  ),
                  _menuItem(
                    'disable',
                    Icons.block_rounded,
                    'Disable',
                    Colors.redAccent,
                  ),
                  _menuItem(
                    'enable',
                    Icons.check_circle_outline_rounded,
                    'Enable',
                    Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guestCard(Map<String, dynamic> u) {
    final name = u['name'] as String? ?? 'Unknown';
    final platform = (u['platform'] as String? ?? '?').toUpperCase();
    final streak = u['streak'] ?? 0;
    final xp = u['xp'] ?? 0;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          border: Border(
            left: const BorderSide(color: Colors.purpleAccent, width: 3),
            top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purple.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.purpleAccent.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.purpleAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _pill('Guest', Colors.purpleAccent),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _pill(platform, Colors.white38),
                        const SizedBox(width: 6),
                        _statDot('🔥', '$streak streak', Colors.orange),
                        const SizedBox(width: 6),
                        _statDot('⚡', '$xp XP', Colors.yellow),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last seen ${_fmt(u['last_seen'])}',
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label,
    Color color,
  ) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    ),
  );

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );

  Widget _statDot(String emoji, String text, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 11)),
      const SizedBox(width: 3),
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

  Widget _loadMoreRow() {
    final showOnline =
        (_filter == 'all' || _filter == 'online') && _hasMoreOnline;
    final showGuest = (_filter == 'all' || _filter == 'guest') && _hasMoreGuest;
    if (!showOnline && !showGuest) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showOnline)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _gold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(
                Icons.expand_more_rounded,
                color: _gold,
                size: 16,
              ),
              label: const Text(
                'More Online',
                style: TextStyle(color: _gold, fontSize: 12),
              ),
              onPressed: () async {
                await _loadOnline(refresh: false);
                _applyFilter();
              },
            ),
          if (showOnline && showGuest) const SizedBox(width: 12),
          if (showGuest)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.purpleAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(
                Icons.expand_more_rounded,
                color: Colors.purpleAccent,
                size: 16,
              ),
              label: const Text(
                'More Guests',
                style: TextStyle(color: Colors.purpleAccent, fontSize: 12),
              ),
              onPressed: () async {
                await _loadGuests(refresh: false);
                _applyFilter();
              },
            ),
        ],
      ),
    );
  }
}
