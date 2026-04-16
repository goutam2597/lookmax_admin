import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _gold = Color(0xFFD4AF37);
  static const _bg = Color(0xFF0E0E0E);
  static const _card = Color(0xFF181818);
  static const _card2 = Color(0xFF1F1F1F);
  static const _border = Color(0xFF2C2C2C);
  static const _green = Color(0xFF42C97A);
  static const _blue = Color(0xFF4BA3FF);
  static const _red = Color(0xFFFF6B6B);

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _slots = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.get('/api/notifications?admin=1');
      final slots = (res['slots'] as List? ?? [])
          .map((slot) => Map<String, dynamic>.from(slot as Map))
          .toList();
      setState(() {
        _slots = slots;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int get _enabledSlots =>
      _slots.where((slot) => _isEnabled(slot['enabled'])).length;

  int get _totalMessages => _slots.fold<int>(
    0,
    (sum, slot) => sum + ((slot['messages'] as List?)?.length ?? 0),
  );

  Future<void> _createSlot() async {
    final payload = await _openSlotEditor();
    if (payload == null) return;
    await _saveSlot(payload, successMessage: 'Notification slot created');
  }

  Future<void> _editSlot(Map<String, dynamic> slot) async {
    final payload = await _openSlotEditor(initial: slot);
    if (payload == null) return;
    await _saveSlot(payload, successMessage: 'Notification slot updated');
  }

  Future<Map<String, dynamic>?> _openSlotEditor({
    Map<String, dynamic>? initial,
  }) {
    return Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _SlotEditorPage(initial: initial),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _saveSlot(
    Map<String, dynamic> payload, {
    required String successMessage,
  }) async {
    setState(() => _saving = true);
    try {
      await ApiService.post('/api/notifications', payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: _green),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: _red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteSlot(Map<String, dynamic> slot) async {
    final slotId = _int(slot['id']);
    final slotName = slot['name']?.toString() ?? 'this slot';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete Slot',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Delete "$slotName" and all 7 day messages?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
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
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await ApiService.delete('/api/notifications?id=$slotId');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification slot deleted'),
          backgroundColor: _green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: _red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: (_loading || _error != null)
          ? null
          : FloatingActionButton(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              onPressed: _saving ? null : _createSlot,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.add_rounded, size: 26),
            ),
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
                  SliverToBoxAdapter(child: _statsStrip()),
                  SliverToBoxAdapter(child: _slotsSectionHeader()),
                  if (_slots.isEmpty)
                    SliverToBoxAdapter(child: _emptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                      sliver: SliverList.builder(
                        itemCount: _slots.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _slotCard(_slots[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _statsStrip() {
    final totalSlots = _slots.length;
    final enabledSlots = _enabledSlots;
    final disabledSlots = totalSlots - enabledSlots;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Row(
        children: [
          _statTile(
            label: 'Total',
            value: '$totalSlots',
            icon: Icons.schedule_rounded,
            color: _gold,
          ),
          const SizedBox(width: 10),
          _statTile(
            label: 'Active',
            value: '$enabledSlots',
            icon: Icons.check_circle_rounded,
            color: _green,
          ),
          const SizedBox(width: 10),
          _statTile(
            label: 'Paused',
            value: '$disabledSlots',
            icon: Icons.pause_circle_rounded,
            color: _red,
          ),
          const SizedBox(width: 10),
          _statTile(
            label: 'Messages',
            value: '$_totalMessages',
            icon: Icons.message_rounded,
            color: _blue,
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotsSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 10),
      child: Row(
        children: [
          Text(
            'Schedules',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          if (_slots.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_slots.length}',
                style: GoogleFonts.poppins(
                  color: _gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const Spacer(),
          TextButton.icon(
            onPressed: _saving ? null : _createSlot,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('New'),
            style: TextButton.styleFrom(
              foregroundColor: _gold,
              textStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              backgroundColor: _gold.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_off_rounded,
            color: Colors.white24,
            size: 58,
          ),
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
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'Try Again',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _slotCard(Map<String, dynamic> slot) {
    final slotId = _int(slot['id']);
    final name = slot['name']?.toString() ?? 'Untitled Slot';
    final hour = _int(slot['hour']);
    final minute = _int(slot['minute']);
    final channel = slot['channel']?.toString() ?? 'daily_habits';
    final enabled = _isEnabled(slot['enabled']);
    final isMotivation = channel == 'motivation';
    final channelColor = isMotivation ? const Color(0xFFAF79FF) : _blue;
    final messages = (slot['messages'] as List? ?? const [])
        .map((msg) => Map<String, dynamic>.from(msg as Map))
        .toList();
    final enabledMsgs = messages.where((m) => _isEnabled(m['enabled'])).length;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: enabled ? _border : Colors.white12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // ── card header ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Time bubble
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: enabled ? 0.1 : 0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _gold.withValues(alpha: enabled ? 0.35 : 0.12),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _timePart(hour, minute),
                        style: GoogleFonts.poppins(
                          color: enabled ? _gold : Colors.white38,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _amPm(hour),
                        style: GoogleFonts.poppins(
                          color: enabled
                              ? _gold.withValues(alpha: 0.7)
                              : Colors.white24,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Name + chips
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          color: enabled ? Colors.white : Colors.white54,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _chip(
                            isMotivation ? 'Motivation' : 'Daily Habits',
                            channelColor,
                          ),
                          _chip(
                            enabled ? 'Active' : 'Paused',
                            enabled ? _green : _red,
                          ),
                          _chip('$enabledMsgs/7 days', Colors.white38),
                        ],
                      ),
                    ],
                  ),
                ),
                // Popup menu
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white38,
                    size: 22,
                  ),
                  color: _card2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: _border),
                  ),
                  enabled: !_saving,
                  onSelected: (val) {
                    if (val == 'edit') _editSlot(slot);
                    if (val == 'delete' && slotId != 0) _deleteSlot(slot);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, color: _gold, size: 17),
                          const SizedBox(width: 10),
                          Text(
                            'Edit Schedule',
                            style: TextStyle(color: _gold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_rounded, color: _red, size: 17),
                          const SizedBox(width: 10),
                          Text(
                            'Delete Slot',
                            style: TextStyle(color: _red, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── day messages (collapsible) ─────────────────────
          Container(height: 1, color: _border),
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.white10,
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 2,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              collapsedIconColor: Colors.white24,
              iconColor: _gold,
              title: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: Colors.white38,
                    size: 15,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Day Messages',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$enabledMsgs active',
                      style: GoogleFonts.poppins(
                        color: _gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              children: messages.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'No messages configured.',
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ]
                  : messages.map(_messageRow).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static const _dayAccents = [
    Color(0xFFFF6B6B), // Sun
    Color(0xFF4BA3FF), // Mon
    Color(0xFF42C97A), // Tue
    Color(0xFFFFB84D), // Wed
    Color(0xFFAF79FF), // Thu
    Color(0xFF4BA3FF), // Fri
    Color(0xFFFF79C6), // Sat
  ];

  Widget _messageRow(Map<String, dynamic> message) {
    final dayIndex = _int(message['day_of_week']);
    final day = _dayLabel(dayIndex);
    final title = (message['title']?.toString().trim().isNotEmpty ?? false)
        ? message['title'].toString()
        : null;
    final body = message['body']?.toString() ?? '';
    final enabled = _isEnabled(message['enabled']);
    final accent = _dayAccents[dayIndex % _dayAccents.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? accent.withValues(alpha: 0.3) : _border,
        ),
      ),
      child: Row(
        children: [
          // Day badge
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: enabled
                  ? accent.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                bottomLeft: Radius.circular(11),
              ),
            ),
            child: Center(
              child: Text(
                day,
                style: GoogleFonts.poppins(
                  color: enabled ? accent : Colors.white24,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: title != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: enabled ? Colors.white : Colors.white38,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            body,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    )
                  : Text(
                      'No message set',
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
          // Status
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? accent : Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: _gold.withValues(alpha: 0.2)),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: _gold,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No schedules yet',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the + button to create your first\nnotification schedule.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _saving ? null : _createSlot,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Create Schedule',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static bool _isEnabled(dynamic value) {
    if (value is bool) return value;
    return '$value' != '0';
  }

  static int _int(dynamic value) => int.tryParse('$value') ?? 0;

  static String _timePart(int hour, int minute) {
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static String _amPm(int hour) => hour >= 12 ? 'PM' : 'AM';

  static String _dayLabel(int dayOfWeek) {
    switch (dayOfWeek) {
      case 0:
        return 'Sun';
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      default:
        return 'Day';
    }
  }
}

class _SlotEditorPage extends StatefulWidget {
  final Map<String, dynamic>? initial;

  const _SlotEditorPage({this.initial});

  @override
  State<_SlotEditorPage> createState() => _SlotEditorPageState();
}

class _SlotEditorPageState extends State<_SlotEditorPage> {
  static const _gold = Color(0xFFD4AF37);
  static const _bg = Color(0xFF0E0E0E);
  static const _card = Color(0xFF181818);
  static const _card2 = Color(0xFF1F1F1F);
  static const _border = Color(0xFF2C2C2C);
  static const _green = Color(0xFF42C97A);

  late final TextEditingController _nameCtrl;
  late TimeOfDay _time;
  late String _channel;
  late bool _enabled;
  late List<_DayMessageDraft> _messages;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameCtrl = TextEditingController(text: initial?['name']?.toString() ?? '');
    _time = TimeOfDay(
      hour: int.tryParse('${initial?['hour'] ?? 8}') ?? 8,
      minute: int.tryParse('${initial?['minute'] ?? 0}') ?? 0,
    );
    _channel = initial?['channel']?.toString() ?? 'daily_habits';
    _enabled = '${initial?['enabled'] ?? 1}' != '0';

    final existing = <int, Map<String, dynamic>>{};
    for (final msg in (initial?['messages'] as List? ?? const [])) {
      final map = Map<String, dynamic>.from(msg as Map);
      existing[int.tryParse('${map['day_of_week']}') ?? 0] = map;
    }

    _messages = List.generate(7, (day) {
      final message = existing[day];
      return _DayMessageDraft(
        dayOfWeek: day,
        title: message?['title']?.toString() ?? '',
        body: message?['body']?.toString() ?? '',
        enabled: '${message?['enabled'] ?? 1}' != '0',
      );
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final message in _messages) {
      message.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(primary: _gold, surface: _card),
            dialogTheme: const DialogThemeData(backgroundColor: _card),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => _time = picked);
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) return;
    Navigator.pop(context, {
      if (_isEditing) 'id': widget.initial!['id'],
      'name': _nameCtrl.text.trim(),
      'hour': _time.hour,
      'minute': _time.minute,
      'channel': _channel,
      'enabled': _enabled ? 1 : 0,
      'messages': _messages
          .map(
            (message) => {
              'day_of_week': message.dayOfWeek,
              'title': message.titleCtrl.text.trim(),
              'body': message.bodyCtrl.text.trim(),
              'enabled': message.enabled ? 1 : 0,
            },
          )
          .toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEditing ? 'Edit Schedule' : 'New Schedule',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _isEditing
                  ? 'Update time, channel & messages'
                  : 'Configure time, channel & messages',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: _submit,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: Text(
                'Save',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel(Icons.tune_rounded, 'Slot Configuration'),
            const SizedBox(height: 10),
            _settingsCard(),
            const SizedBox(height: 26),
            _sectionLabel(Icons.calendar_month_rounded, 'Day-wise Messages'),
            const SizedBox(height: 6),
            const Text(
              'Customize the notification text for each day of the week.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 14),
            ..._messages.map((msg) => _messageEditor(msg)),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(IconData icon, String label) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _card2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Icon(icon, color: _gold, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _settingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // Slot name
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Slot name', 'e.g. Morning Routine'),
            ),
          ),
          Container(height: 1, color: _border),
          // Time picker row
          InkWell(
            onTap: _pickTime,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: _gold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notification Time',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTime(_time),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),
          Container(height: 1, color: _border),
          // Channel
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: DropdownButtonFormField<String>(
              initialValue: _channel,
              dropdownColor: _card2,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Channel', '').copyWith(
                prefixIcon: const Icon(
                  Icons.category_outlined,
                  color: Colors.white38,
                  size: 20,
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'daily_habits',
                  child: Text('Daily Habits'),
                ),
                DropdownMenuItem(
                  value: 'motivation',
                  child: Text('Motivation'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _channel = v);
              },
            ),
          ),
          Container(height: 1, color: _border),
          // Active toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (_enabled ? _green : Colors.white24).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _enabled
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    color: _enabled ? _green : Colors.white38,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Slot Active',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _enabled
                            ? 'Will send notifications'
                            : 'Notifications paused',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _enabled,
                  activeThumbColor: _gold,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageEditor(_DayMessageDraft msg) {
    const dayAccents = [
      Color(0xFFFF6B6B), // Sun
      Color(0xFF4BA3FF), // Mon
      Color(0xFF42C97A), // Tue
      Color(0xFFFFB84D), // Wed
      Color(0xFFAF79FF), // Thu
      Color(0xFF4BA3FF), // Fri
      Color(0xFFFF79C6), // Sat
    ];
    final accent = dayAccents[msg.dayOfWeek % dayAccents.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: msg.enabled ? accent.withValues(alpha: 0.35) : _border,
        ),
      ),
      child: Column(
        children: [
          // Day header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: msg.enabled ? accent.withValues(alpha: 0.08) : _card2,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: msg.enabled
                        ? accent.withValues(alpha: 0.18)
                        : Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _dayLabel(msg.dayOfWeek).substring(0, 3),
                      style: GoogleFonts.poppins(
                        color: msg.enabled ? accent : Colors.white38,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _dayLabel(msg.dayOfWeek),
                    style: GoogleFonts.poppins(
                      color: msg.enabled ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: msg.enabled,
                  activeThumbColor: accent,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => setState(() => msg.enabled = v),
                ),
              ],
            ),
          ),
          if (msg.enabled) ...[
            Container(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                children: [
                  TextField(
                    controller: msg.titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration('Title', 'e.g. Time to level up!'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: msg.bodyCtrl,
                    style: const TextStyle(color: Colors.white),
                    minLines: 2,
                    maxLines: 3,
                    decoration: _decoration(
                      'Body',
                      'The notification body text…',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint.isEmpty ? null : hint,
      labelStyle: const TextStyle(color: Colors.white54),
      hintStyle: const TextStyle(color: Colors.white30),
      filled: true,
      fillColor: _card2,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _gold),
      ),
    );
  }

  static String _formatTime(TimeOfDay time) {
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final hour = time.hour == 0
        ? 12
        : (time.hour > 12 ? time.hour - 12 : time.hour);
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
  }

  static String _dayLabel(int dayOfWeek) {
    switch (dayOfWeek) {
      case 0:
        return 'Sunday';
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      default:
        return 'Day';
    }
  }
}

class _DayMessageDraft {
  final int dayOfWeek;
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  bool enabled;

  _DayMessageDraft({
    required this.dayOfWeek,
    required String title,
    required String body,
    required this.enabled,
  }) : titleCtrl = TextEditingController(text: title),
       bodyCtrl = TextEditingController(text: body);

  void dispose() {
    titleCtrl.dispose();
    bodyCtrl.dispose();
  }
}
