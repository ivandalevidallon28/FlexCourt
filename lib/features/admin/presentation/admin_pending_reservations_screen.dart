import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../notifications/domain/notifications_providers.dart';
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
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Icon(Icons.pending_actions_rounded,
                          size: 18, color: AppColors.orange700),
                      Text(
                        '${list.length} pending',
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.orange700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
                        onMarkInvalid: () =>
                            _setPaymentStatus(r, paymentStatus: 'INVALID'),
                        onMarkDownpayment: () => _setPaymentStatus(
                          r,
                          paymentStatus: 'DOWNPAYMENT_PAID',
                        ),
                        onMarkPaid: () =>
                            _setPaymentStatus(r, paymentStatus: 'PAID'),
                        onViewReceipt: () => _viewReceipt(r),
                        onCallUser: () => _callUser(r),
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
        await ref.read(notificationServiceProvider).sendUserNotification(
              userId: uid,
              title: status == 'APPROVED'
                  ? 'Reservation approved'
                  : 'Reservation rejected',
              message: status == 'APPROVED'
                  ? 'Your reservation has been approved.'
                  : 'Your reservation has been rejected.',
              type: status == 'APPROVED'
                  ? 'RESERVATION_APPROVED'
                  : 'RESERVATION_REJECTED',
              reservationId: id,
            );
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

  Future<void> _setPaymentStatus(
    Map<String, dynamic> r, {
    required String paymentStatus,
  }) async {
    final id = r['id']?.toString();
    final userId = r['user_id']?.toString() ?? '';
    if (id == null || id.isEmpty) return;
    try {
      final client = Supabase.instance.client;
      await client.from('reservations').update({
        'payment_status': paymentStatus,
        'payment_reviewed_by': client.auth.currentUser?.id,
        'payment_reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      // Notify player when admin flags payment as invalid.
      if (userId.isNotEmpty) {
        if (paymentStatus == 'INVALID') {
          await ref.read(notificationServiceProvider).sendUserNotification(
                userId: userId,
                title: 'Payment marked invalid',
                message:
                    'Your uploaded payment receipt was marked invalid. Please upload a clearer/correct GCash receipt.',
                type: 'PAYMENT_INVALID',
                reservationId: id,
              );
        } else if (paymentStatus == 'DOWNPAYMENT_PAID') {
          await ref.read(notificationServiceProvider).sendUserNotification(
                userId: userId,
                title: 'Downpayment verified',
                message: 'Admin marked your reservation as downpayment paid.',
                type: 'DOWNPAYMENT_PAID',
                reservationId: id,
              );
        } else if (paymentStatus == 'PAID') {
          await ref.read(notificationServiceProvider).sendUserNotification(
                userId: userId,
                title: 'Payment verified',
                message: 'Admin marked your reservation as fully paid.',
                type: 'PAID',
                reservationId: id,
              );
        }
      }

      ref.invalidate(adminPendingReservationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment set to ${paymentStatus.replaceAll('_', ' ')}.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update payment status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewReceipt(Map<String, dynamic> r) async {
    final path = r['payment_receipt_path']?.toString();
    if (path == null || path.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No receipt uploaded yet.')),
        );
      }
      return;
    }
    try {
      final url = await Supabase.instance.client.storage
          .from('document')
          .createSignedUrl(path, 3600);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Receipt'),
          content: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open receipt: $e')),
        );
      }
    }
  }

  Future<void> _callUser(Map<String, dynamic> r) async {
    final users = r['users'] as Map<String, dynamic>?;
    final rawNumber = users?['contact_number']?.toString() ?? '';
    final phone = rawNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number found for this user.')),
        );
      }
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open phone dialer.')),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending Card
// ─────────────────────────────────────────────────────────────────────────────

class _PendingCard extends StatefulWidget {
  const _PendingCard({
    required this.reservation,
    required this.onEdit,
    required this.onApprove,
    required this.onReject,
    required this.onMarkInvalid,
    required this.onMarkDownpayment,
    required this.onMarkPaid,
    required this.onViewReceipt,
    required this.onCallUser,
  });

  final Map<String, dynamic> reservation;
  final VoidCallback onEdit;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onMarkInvalid;
  final VoidCallback onMarkDownpayment;
  final VoidCallback onMarkPaid;
  final VoidCallback onViewReceipt;
  final VoidCallback onCallUser;

  @override
  State<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends State<_PendingCard> {
  bool _paymentExpanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;
    final user = r['users'] as Map<String, dynamic>?;
    final court = r['courts'] as Map<String, dynamic>?;
    final category = r['categories'] as Map<String, dynamic>?;

    final userName = user?['name']?.toString() ?? 'Unknown';
    final userEmail = user?['email']?.toString() ?? '';
    final userPhone = user?['contact_number']?.toString() ?? '';
    final courtName = court?['name']?.toString() ?? 'Court';
    final eventLabel =
        category?['name']?.toString() ?? r['event_type']?.toString() ?? '';
    final date = r['date']?.toString() ?? '';
    final startTime = r['start_time']?.toString() ?? '';
    final endTime = r['end_time']?.toString() ?? '';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';
    final paymentStatus = (r['payment_status']?.toString() ?? 'UNPAID');
    final hasReceipt = (r['payment_receipt_path']?.toString().isNotEmpty ?? false);
    final paymentColor = switch (paymentStatus) {
      'PAID' => AppColors.approved,
      'DOWNPAYMENT_PAID' => AppColors.blue600,
      'INVALID' => AppColors.rejected,
      'RECEIPT_UPLOADED' => AppColors.orange700,
      _ => AppColors.neutral600,
    };

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
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: paymentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  paymentStatus.replaceAll('_', ' '),
                  style: AppTypography.labelSmall.copyWith(
                    color: paymentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (hasReceipt)
                TextButton.icon(
                  onPressed: widget.onViewReceipt,
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: const Text('View receipt'),
                ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Bottom row: user info ────────────────────────────────────
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
                    if (userPhone.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: InkWell(
                          onTap: widget.onCallUser,
                          borderRadius: BorderRadius.circular(6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.call_rounded,
                                size: 14,
                                color: AppColors.blue600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                userPhone,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.blue600,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Main reservation actions (large text buttons) ────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _BigActionButton(
                icon: Icons.edit_rounded,
                label: 'Edit',
                color: AppColors.blue600,
                onTap: widget.onEdit,
              ),
              _BigActionButton(
                icon: Icons.check_circle_rounded,
                label: 'Approve',
                color: AppColors.approved,
                onTap: widget.onApprove,
              ),
              _BigActionButton(
                icon: Icons.cancel_rounded,
                label: 'Reject',
                color: AppColors.rejected,
                onTap: widget.onReject,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Payment review section (expand/collapse) ──────────────────
          InkWell(
            onTap: () => setState(() => _paymentExpanded = !_paymentExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.neutral100.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.neutral300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_rounded, size: 18, color: AppColors.blue600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment Review Options',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.blue800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    _paymentExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.neutral500,
                  ),
                ],
              ),
            ),
          ),

          if (_paymentExpanded) ...[
            const SizedBox(height: 10),
            if (!hasReceipt)
              Text(
                'No receipt uploaded yet. Ask player to upload a GCash screenshot first.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.neutral600),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BigActionButton(
                    icon: Icons.money_off_csred_rounded,
                    label: 'Mark Invalid',
                    color: AppColors.rejected,
                    onTap: widget.onMarkInvalid,
                  ),
                  _BigActionButton(
                    icon: Icons.payments_outlined,
                    label: 'Downpayment Paid',
                    color: AppColors.blue600,
                    onTap: widget.onMarkDownpayment,
                  ),
                  _BigActionButton(
                    icon: Icons.verified_rounded,
                    label: 'Fully Paid',
                    color: AppColors.approved,
                    onTap: widget.onMarkPaid,
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  const _BigActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        minimumSize: const Size(120, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}