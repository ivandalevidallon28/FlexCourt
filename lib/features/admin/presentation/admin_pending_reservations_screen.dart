import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../domain/admin_providers.dart';
import 'widgets/admin_edit_reservation_dialog.dart';

class AdminPendingReservationsScreen extends ConsumerStatefulWidget {
  const AdminPendingReservationsScreen({super.key});

  @override
  ConsumerState<AdminPendingReservationsScreen> createState() =>
      _AdminPendingReservationsScreenState();
}

class _AdminPendingReservationsScreenState
    extends ConsumerState<AdminPendingReservationsScreen> {
  RealtimeChannel? _channel;

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
          .channel('admin:pending_reservations')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'reservations',
        callback: (_) => ref.invalidate(adminPendingReservationsProvider),
      )
          .subscribe();
    }

    final pendingAsync = ref.watch(adminPendingReservationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const GradientAppBar(title: 'Pending Reservations'),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.surfaceGradientDark
              : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F2FE), Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
          ),
        ),
        child: pendingAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                icon: Icons.pending_actions_rounded,
                title: 'All caught up!',
                subtitle: 'No pending reservations. New requests will appear here.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Summary bar ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.pending_actions_rounded,
                          size: 18, color: AppColors.orange700),
                      const SizedBox(width: 8),
                      Text(
                        '${list.length} pending',
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.orange700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'awaiting review',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.neutral600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── List ───────────────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final r = list[index];
                      return _PendingCard(
                        reservation: r,
                        onEdit: () => AdminEditReservationDialog.show(
                          context,
                          ref,
                          r,
                          onSuccess: () =>
                              ref.invalidate(adminPendingReservationsProvider),
                        ),
                        onApprove: () => _confirmSetStatus(r, 'APPROVED'),
                        onReject: () => _confirmSetStatus(r, 'REJECTED'),
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
                  Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
                  const SizedBox(height: 12),
                  Text('Something went wrong', style: AppTypography.titleSmall),
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

  Future<void> _confirmSetStatus(Map<String, dynamic> r, String status) async {
    final isApprove = status == 'APPROVED';
    final confirmed = await ConfirmDialog.show(
      context,
      title: isApprove ? 'Approve reservation?' : 'Reject reservation?',
      message: isApprove
          ? 'The user will be notified and the slot will be confirmed.'
          : 'The user will be notified. The slot will become available.',
      confirmLabel: isApprove ? 'Yes, approve' : 'Yes, reject',
      cancelLabel: 'Cancel',
      isDanger: !isApprove,
      icon: isApprove ? Icons.check_circle_outline : Icons.cancel_outlined,
    );
    if (!confirmed || !mounted) return;
    await _setStatus(r['id'], r['user_id'], status);
  }

  Future<void> _setStatus(String id, dynamic userId, String status) async {
    final client = Supabase.instance.client;
    try {
      final res = await client
          .from('reservations')
          .update({'status': status})
          .eq('id', id)
          .select('id')
          .maybeSingle();

      if (res == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reservation not found.')),
          );
        }
        return;
      }

      final uid = userId?.toString() ?? '';
      if (uid.isNotEmpty) {
        await client.from('notifications').insert({
          'user_id': uid,
          'title': status == 'APPROVED'
              ? 'Reservation approved'
              : 'Reservation rejected',
          'message': status == 'APPROVED'
              ? 'Your reservation has been approved.'
              : 'Your reservation has been rejected.',
        });
      }

      ref.invalidate(adminPendingReservationsProvider);

      if (mounted) {
        final isApprove = status == 'APPROVED';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isApprove ? 'Reservation approved.' : 'Reservation rejected.',
            ),
            backgroundColor: isApprove ? Colors.green : AppColors.orange600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending Card
// ─────────────────────────────────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.reservation,
    required this.onEdit,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> reservation;
  final VoidCallback onEdit;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final user = r['users'] as Map<String, dynamic>?;
    final court = r['courts'] as Map<String, dynamic>?;
    final category = r['categories'] as Map<String, dynamic>?;

    final userName = user?['name']?.toString() ?? 'Unknown';
    final userEmail = user?['email']?.toString() ?? '';
    final courtName = court?['name']?.toString() ?? 'Court';
    final eventLabel =
        category?['name']?.toString() ?? r['event_type']?.toString() ?? '';
    final date = r['date']?.toString() ?? '';
    final startTime = r['start_time']?.toString() ?? '';
    final endTime = r['end_time']?.toString() ?? '';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    // Parse date for the date block
    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(date);
    } catch (_) {}

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top row: date block + details ────────────────────────────
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
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.blue600,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      parsedDate?.day.toString() ?? '?',
                      style: TextStyle(
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
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.neutral500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Main details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Court + time
                    Text(
                      courtName,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
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

          // ── Bottom row: user info + actions ──────────────────────────
          Row(
            children: [
              // User avatar
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.orange100,
                  borderRadius: BorderRadius.circular(8),
                  border:
                  Border.all(color: AppColors.orange700.withOpacity(0.2)),
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
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                    icon: Icons.edit_rounded,
                    color: AppColors.blue600,
                    tooltip: 'Edit / reschedule',
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    icon: Icons.check_rounded,
                    color: AppColors.approved,
                    tooltip: 'Approve',
                    onTap: onApprove,
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    icon: Icons.close_rounded,
                    color: AppColors.rejected,
                    tooltip: 'Reject',
                    onTap: onReject,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}