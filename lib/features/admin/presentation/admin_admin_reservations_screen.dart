import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../domain/admin_providers.dart';
import 'widgets/admin_edit_reservation_dialog.dart';

class AdminAdminReservationsScreen extends ConsumerStatefulWidget {
  const AdminAdminReservationsScreen({super.key});

  @override
  ConsumerState<AdminAdminReservationsScreen> createState() =>
      _AdminAdminReservationsScreenState();
}

class _AdminAdminReservationsScreenState
    extends ConsumerState<AdminAdminReservationsScreen> {
  RealtimeChannel? _channel;

  // ── Status filter ─────────────────────────────────────────────────────────
  String? _statusFilter; // null = ALL

  static const _statusOptions = ['ALL', 'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'];

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_channel == null) {
      _channel = Supabase.instance.client
          .channel('admin:admin_reservations')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'reservations',
        callback: (_) => ref.invalidate(adminAdminReservationsProvider),
      )
          .subscribe();
    }

    final asyncData = ref.watch(adminAdminReservationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Admin Reservations',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminAdminReservationsProvider),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.surfaceGradientDark
              : AppColors.surfaceGradientLight,
        ),
        child: asyncData.when(
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                icon: Icons.admin_panel_settings_rounded,
                title: 'No admin reservations',
                subtitle:
                'Reservations you create as admin appear here. You can edit them anytime.',
              );
            }

            final filtered = _statusFilter == null || _statusFilter == 'ALL'
                ? list
                : list
                .where((r) =>
            (r['status']?.toString() ?? '') == _statusFilter)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Summary + filter row ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.admin_panel_settings_rounded,
                          size: 18, color: AppColors.blue600),
                      const SizedBox(width: 8),
                      Text(
                        '${filtered.length} of ${list.length}',
                        style: AppTypography.titleSmall
                            .copyWith(color: AppColors.blue800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // ── Status filter chips ────────────────────────────────
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _statusOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final s = _statusOptions[i];
                      final isAll = s == 'ALL';
                      final isSelected = isAll
                          ? _statusFilter == null
                          : _statusFilter == s;
                      return ChoiceChip(
                        label: Text(
                          isAll ? 'All' : _cap(s),
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        selected: isSelected,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() =>
                        _statusFilter = isAll ? null : s),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // ── List ──────────────────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                    icon: Icons.filter_list_rounded,
                    title: 'No matches',
                    subtitle:
                    'No admin reservations with status "${_cap(_statusFilter ?? '')}".',
                  )
                      : ListView.builder(
                    padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      final r = filtered[index];
                      return _AdminReservationCard(
                        reservation: r,
                        onEdit: () =>
                            AdminEditReservationDialog.show(
                              context,
                              ref,
                              r,
                              onSuccess: () => ref.invalidate(
                                  adminAdminReservationsProvider),
                            ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 40),
                  const SizedBox(height: 12),
                  Text('Something went wrong',
                      style: AppTypography.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    e.toString(),
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.neutral600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin Reservation Card
// ─────────────────────────────────────────────────────────────────────────────

class _AdminReservationCard extends StatelessWidget {
  const _AdminReservationCard({
    required this.reservation,
    required this.onEdit,
  });

  final Map<String, dynamic> reservation;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final user = r['users'] as Map<String, dynamic>?;
    final court = r['courts'] as Map<String, dynamic>?;
    final category = r['categories'] as Map<String, dynamic>?;

    final courtName = court?['name']?.toString() ?? 'Court';
    final userName = user?['name']?.toString() ?? 'Unknown';
    final userEmail = user?['email']?.toString() ?? '';
    final eventLabel =
        category?['name']?.toString() ?? r['event_type']?.toString() ?? '';
    final status = r['status']?.toString() ?? '';
    final startTime = r['start_time']?.toString() ?? '';
    final endTime = r['end_time']?.toString() ?? '';
    final dateStr = r['date']?.toString() ?? '';
    final statusColor = AppColors.statusColor(status);
    final userInitial =
    userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(dateStr);
    } catch (_) {}

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top: date block + details ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date block
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.blue600.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      parsedDate != null
                          ? DateFormat('MMM').format(parsedDate).toUpperCase()
                          : '---',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.blue600,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      parsedDate?.day.toString() ?? '?',
                      style: const TextStyle(
                        fontSize: 20,
                        color: AppColors.blue800,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      parsedDate != null
                          ? DateFormat('EEE').format(parsedDate).toUpperCase()
                          : '',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.neutral500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Court name + status badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            courtName,
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: AppTypography.labelSmall.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Time
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 13, color: AppColors.blue600),
                        const SizedBox(width: 4),
                        Text(
                          '$startTime – $endTime',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.blue800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Event type
                    Row(
                      children: [
                        const Icon(Icons.sports_rounded,
                            size: 13, color: AppColors.neutral500),
                        const SizedBox(width: 4),
                        Text(
                          eventLabel,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.orange700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Bottom: user + edit button ─────────────────────────────
          Row(
            children: [
              // User avatar
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.orange100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.orange700.withOpacity(0.2)),
                ),
                alignment: Alignment.center,
                child: Text(
                  userInitial,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.orange800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: AppTypography.labelMedium
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      userEmail,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.neutral500,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Edit button
              Tooltip(
                message: 'Edit reservation',
                child: InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.blue600.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: AppColors.blue600.withOpacity(0.25)),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        size: 18, color: AppColors.blue600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}