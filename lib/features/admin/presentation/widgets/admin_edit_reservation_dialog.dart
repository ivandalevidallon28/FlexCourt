import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_design_system.dart';
import '../../../../core/utils/slot_utils.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../reservation_change/domain/reservation_change_providers.dart';

class AdminEditReservationDialog extends ConsumerStatefulWidget {
  const AdminEditReservationDialog({
    super.key,
    required this.reservation,
    this.onSuccess,
  });

  final Map<String, dynamic> reservation;
  final VoidCallback? onSuccess;

  static Future<void> show(
      BuildContext context,
      WidgetRef ref,
      Map<String, dynamic> reservation, {
        VoidCallback? onSuccess,
      }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminEditReservationDialog(
        reservation: reservation,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  ConsumerState<AdminEditReservationDialog> createState() =>
      _AdminEditReservationDialogState();
}

class _AdminEditReservationDialogState
    extends ConsumerState<AdminEditReservationDialog> {
  static const List<int> _bookingHours = [
    6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
  ];

  late final TextEditingController _eventCtrl;
  late final TextEditingController _playersCtrl;
  late final TextEditingController _messageCtrl;
  late DateTime _pickedDate;

  int? _startHour;
  int? _endHour;

  List<({String start, String end})> _occupied = [];
  bool _slotsLoading = true;
  bool _saving = false;
  String? _error;
  bool _initialLoadScheduled = false;

  Map<String, dynamic> get r => widget.reservation;

  static String toHhMm(dynamic v) {
    final s = (v?.toString() ?? '').trim();
    if (s.isEmpty) return '';
    final parts = s.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  List<int> _availableEndsFor(int startHour) {
    final startStr = '${startHour.toString().padLeft(2, '0')}:00';
    return [
      for (var h = startHour + 1; h <= 23; h++)
        if (!slotOverlaps(
            startStr, '${h.toString().padLeft(2, '0')}:00', _occupied))
          h
    ];
  }

  Future<void> _loadOccupied(DateTime day) async {
    setState(() {
      _slotsLoading = true;
      _error = null;
    });
    final client = Supabase.instance.client;
    final dateStr = day.toIso8601String().substring(0, 10);
    try {
      final res = await client.rpc('get_occupied_slots', params: {
        'p_court_id': r['court_id'] as String,
        'p_date': dateStr,
      });
      final list = (res as List?) ?? [];
      final mapped = list.map<({String start, String end})>((e) {
        final m = e as Map<String, dynamic>;
        return (
        start: toHhMm(m['start_time']),
        end: toHhMm(m['end_time']),
        );
      }).toList();
      final currentStart = toHhMm(r['start_time']);
      final currentEnd = toHhMm(r['end_time']);
      setState(() {
        _occupied = mapped
            .where((o) => !(o.start == currentStart && o.end == currentEnd))
            .toList();
        _slotsLoading = false;
      });
    } catch (_) {
      setState(() {
        _occupied = [];
        _slotsLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _pickedDate =
        DateTime.tryParse(r['date']?.toString() ?? '') ?? DateTime.now();
    _eventCtrl =
        TextEditingController(text: r['event_type']?.toString() ?? '');
    _playersCtrl =
        TextEditingController(text: r['players_count']?.toString() ?? '');
    _messageCtrl = TextEditingController();

    final startHhMm = toHhMm(r['start_time']);
    final endHhMm = toHhMm(r['end_time']);
    _startHour = startHhMm.length >= 2 ? int.tryParse(startHhMm.substring(0, 2)) : null;
    _endHour = endHhMm.length >= 2 ? int.tryParse(endHhMm.substring(0, 2)) : null;
  }

  @override
  void dispose() {
    _eventCtrl.dispose();
    _playersCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  String _fmtHour(int h) => '${h.toString().padLeft(2, '0')}:00';

  /// True when date or start/end hour differ from original (so submit is allowed).
  bool _hasChanges() {
    if (_startHour == null || _endHour == null) return false;
    final origDateStr = (r['date']?.toString() ?? '').substring(0, 10);
    final pickedDateStr = _pickedDate.toIso8601String().substring(0, 10);
    final startHhMm = toHhMm(r['start_time']);
    final endHhMm = toHhMm(r['end_time']);
    final origStartHour = startHhMm.length >= 2 ? int.tryParse(startHhMm.substring(0, 2)) : null;
    final origEndHour = endHhMm.length >= 2 ? int.tryParse(endHhMm.substring(0, 2)) : null;
    if (origStartHour == null || origEndHour == null) return true;
    return pickedDateStr != origDateStr ||
        _startHour != origStartHour ||
        _endHour != origEndHour;
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _onSave() async {
    if (_startHour == null || _endHour == null) {
      setState(() => _error = 'Please select both start and end time.');
      return;
    }
    final startStr = _fmtHour(_startHour!);
    final endStr = _fmtHour(_endHour!);
    if (_startHour! >= _endHour!) {
      setState(() => _error = 'End time must be after start time.');
      return;
    }

    // Guard: don't save if nothing changed
    final origDateStr = (r['date']?.toString() ?? '').substring(0, 10);
    final pickedDateStr = _pickedDate.toIso8601String().substring(0, 10);
    final origStart = toHhMm(r['start_time']);
    final origEnd = toHhMm(r['end_time']);
    if (pickedDateStr == origDateStr &&
        startStr == origStart &&
        endStr == origEnd) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No changes made. Date and time are unchanged.'),
            backgroundColor: AppColors.neutral600,
          ),
        );
      }
      return;
    }

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Send change request?',
      message:
      'A change request will be sent to the player. They must accept or reject within 24 hours.',
      confirmLabel: 'Yes, send request',
      cancelLabel: 'Cancel',
      icon: Icons.schedule_send_outlined,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final dateStr = _pickedDate.toIso8601String().substring(0, 10);

    try {
      // Check for existing pending request
      final changeRepo = ref.read(reservationChangeRequestsRepositoryProvider);
      final pending = await changeRepo.getPendingByReservation(r['id'].toString());
      if (pending != null && mounted) {
        setState(() => _saving = false);
        _showInfoDialog(
          title: 'Pending request exists',
          message:
          'This reservation already has a pending change request. The player must respond first.',
        );
        return;
      }

      // Check overlap
      final client = Supabase.instance.client;
      String normTime(String t) {
        final s = t.trim();
        return (s.length == 5 && s[2] == ':') ? '$s:00' : s;
      }

      final overlapRes = await client.rpc('check_reservation_overlap', params: {
        'p_court_id': r['court_id'].toString(),
        'p_date': dateStr,
        'p_start': normTime(startStr),
        'p_end': normTime(endStr),
        'p_exclude_reservation_id': r['id'].toString(),
      });

      if (overlapRes == null) {
        setState(() {
          _error = 'Could not check availability. Please try again.';
          _saving = false;
        });
        return;
      }
      if (overlapRes != true) {
        setState(() {
          _error = 'This time slot is already booked. Choose another.';
          _saving = false;
        });
        return;
      }

      // Create change request
      final playerId = (r['user_id']?.toString() ?? '').trim();
      final reservationId = (r['id']?.toString() ?? '').trim();
      if (playerId.isEmpty || reservationId.isEmpty) {
        setState(() {
          _error = 'Reservation or player ID is missing.';
          _saving = false;
        });
        return;
      }

      final court = r['courts'] as Map<String, dynamic>?;
      final courtName = court?['name']?.toString() ?? 'Court';
      final message = _messageCtrl.text.trim().isEmpty
          ? null
          : _messageCtrl.text.trim();

      await ref.read(reservationChangeServiceProvider).createChangeRequest(
        reservationId: reservationId,
        playerId: playerId,
        courtName: courtName,
        oldStartTime: toHhMm(r['start_time']),
        oldEndTime: toHhMm(r['end_time']),
        newStartTime: startStr,
        newEndTime: endStr,
        message: message,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess?.call();
        // Success snackbar shown by parent or here
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Change request sent. Player has 24h to respond.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  void _showInfoDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_initialLoadScheduled) {
      _initialLoadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadOccupied(_pickedDate));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = r['users'] as Map<String, dynamic>?;
    final court = r['courts'] as Map<String, dynamic>?;
    final courtName = court?['name']?.toString() ?? 'Court';
    final userName = user?['name']?.toString() ?? 'Unknown';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle ────────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ─────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.blue600.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_calendar_rounded,
                      color: AppColors.blue600, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Reservation',
                        style: AppTypography.titleLarge
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '$courtName · $userName',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.neutral600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Current reservation summary ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.neutral100.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: AppColors.neutral500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current: ${DateFormat('MMM d').format(_pickedDate)}  ·  '
                          '${toHhMm(r['start_time'])} – ${toHhMm(r['end_time'])}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.neutral600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            _SheetSectionLabel(label: 'New Schedule'),
            const SizedBox(height: 10),

            // ── Date picker row ─────────────────────────────────────────
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _pickedDate,
                  firstDate:
                  DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) {
                  setState(() {
                    _pickedDate = d;
                    _startHour = null;
                    _endHour = null;
                    _error = null;
                  });
                  await _loadOccupied(d);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neutral300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        size: 18, color: AppColors.blue600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        DateFormat('EEE, MMM d, y').format(_pickedDate),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.blue800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down_rounded,
                        color: AppColors.neutral400),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Time dropdowns ──────────────────────────────────────────
            if (_slotsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              _buildTimeDropdowns(),

            const SizedBox(height: 16),
            _SheetSectionLabel(label: 'Event Details'),
            const SizedBox(height: 10),

            // ── Event type ──────────────────────────────────────────────
            _SheetField(
              controller: _eventCtrl,
              label: 'Event type',
              icon: Icons.sports_rounded,
              action: TextInputAction.next,
            ),
            const SizedBox(height: 10),

            // ── Players ─────────────────────────────────────────────────
            _SheetField(
              controller: _playersCtrl,
              label: 'Number of players',
              icon: Icons.group_rounded,
              keyboardType: TextInputType.number,
              action: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            _SheetSectionLabel(label: 'Message to Player (optional)'),
            const SizedBox(height: 10),

            // ── Message ─────────────────────────────────────────────────
            TextField(
              controller: _messageCtrl,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'e.g. Moved to fit another booking',
                prefixIcon: const Icon(Icons.message_rounded, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  BorderSide(color: AppColors.neutral300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.blue600, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),

            // ── Error ───────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                  Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 22),

            // ── Actions ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed:
                      _saving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _saving || !_hasChanges() ? null : _onSave,
                      icon: _saving
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.send_rounded, size: 18),
                      label:
                      Text(_saving ? 'Sending…' : _hasChanges() ? 'Send Request' : 'No changes'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeDropdowns() {
    final availableStarts = <int>[];
    for (final h in _bookingHours) {
      final s = _fmtHour(h);
      final e = h < 23 ? _fmtHour(h + 1) : '23:00';
      if (!slotOverlaps(s, e, _occupied)) availableStarts.add(h);
    }

    if (availableStarts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.rejected.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.rejected.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.event_busy_rounded,
                size: 16, color: AppColors.rejected),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No available slots for this date. Pick another day.',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.rejected),
              ),
            ),
          ],
        ),
      );
    }

    final validStart =
        _startHour != null && availableStarts.contains(_startHour);
    final availableEnds =
    validStart ? _availableEndsFor(_startHour!) : <int>[];
    final validEnd = _endHour != null && availableEnds.contains(_endHour);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: validStart ? _startHour : null,
                decoration: InputDecoration(
                  labelText: 'Start',
                  prefixIcon:
                  const Icon(Icons.play_arrow_rounded, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.neutral300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.blue600, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
                items: availableStarts
                    .map((h) => DropdownMenuItem(
                  value: h,
                  child: Text(_fmtHour(h)),
                ))
                    .toList(),
                onChanged: (h) {
                  if (h == null) return;
                  final ends = _availableEndsFor(h);
                  setState(() {
                    _startHour = h;
                    _endHour =
                    ends.isNotEmpty ? ends.first : null;
                    _error = null;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded,
                  size: 18, color: AppColors.neutral400),
            ),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: validEnd ? _endHour : null,
                decoration: InputDecoration(
                  labelText: 'End',
                  prefixIcon:
                  const Icon(Icons.stop_rounded, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.neutral300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.blue600, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
                items: availableEnds
                    .map((h) => DropdownMenuItem(
                  value: h,
                  child: Text(_fmtHour(h)),
                ))
                    .toList(),
                onChanged: _startHour == null
                    ? null
                    : (h) {
                  if (h == null) return;
                  setState(() {
                    _endHour = h;
                    _error = null;
                  });
                },
              ),
            ),
          ],
        ),
        // Duration pill
        if (validStart && validEnd) ...[
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.blue600.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_endHour! - _startHour!} hour(s)',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.blue600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.labelSmall.copyWith(
        color: AppColors.neutral500,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        fontSize: 11,
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.label,
    required this.icon,
    this.action = TextInputAction.next,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputAction action;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: action,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border:
        OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.neutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: AppColors.blue600, width: 1.5),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}