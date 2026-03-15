import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_design_system.dart';
import '../../data/reservation_change_request_model.dart';

/// Full-detail modal for a reservation change request.
class ReservationChangeModal extends StatelessWidget {
  const ReservationChangeModal({
    super.key,
    required this.request,
    this.courtName,
    this.reservationDate,
    required this.onAccept,
    required this.onReject,
  });

  final ReservationChangeRequest request;
  final String? courtName;
  final DateTime? reservationDate;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  static Future<void> show(
      BuildContext context, {
        required ReservationChangeRequest request,
        String? courtName,
        DateTime? reservationDate,
        required VoidCallback onAccept,
        required VoidCallback onReject,
      }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReservationChangeModal(
        request: request,
        courtName: courtName,
        reservationDate: reservationDate,
        onAccept: () {
          Navigator.pop(ctx);
          onAccept();
        },
        onReject: () {
          Navigator.pop(ctx);
          onReject();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = request;
    final expired = r.isExpired || r.expiresAt.isBefore(DateTime.now());
    final remaining = r.expiresAt.difference(DateTime.now());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hoursLeft = remaining.inHours;
    final minutesLeft = remaining.inMinutes % 60;
    final countdownText = expired
        ? 'This change request has expired'
        : '${hoursLeft > 0 ? '${hoursLeft}h ' : ''}${minutesLeft}m left to respond';

    final countdownColor = expired
        ? AppColors.rejected
        : hoursLeft < 1
        ? AppColors.orange600
        : AppColors.neutral600;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewPadding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Drag handle ────────────────────────────────────────────────
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

          // ── Header ─────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.blue600.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.blue600,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reschedule Request',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (courtName != null)
                      Text(
                        courtName!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.neutral600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Date info ──────────────────────────────────────────────────
          if (reservationDate != null)
            _InfoRow(
              icon: Icons.calendar_today_rounded,
              label: 'Date',
              value: DateFormat('EEEE, MMM d, y').format(reservationDate!),
            ),

          const SizedBox(height: 16),

          // ── Time comparison card ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.blue600.withOpacity(0.15),
              ),
            ),
            child: Column(
              children: [
                // Original
                _TimeRow(
                  label: 'Original',
                  time: '${r.oldStartTime} – ${r.oldEndTime}',
                  isProposed: false,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.neutral200, height: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.arrow_downward_rounded,
                          size: 16,
                          color: AppColors.blue600.withOpacity(0.6),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.neutral200, height: 1)),
                    ],
                  ),
                ),
                // Proposed
                _TimeRow(
                  label: 'Proposed',
                  time: '${r.newStartTime} – ${r.newEndTime}',
                  isProposed: true,
                ),
              ],
            ),
          ),

          // ── Admin message ──────────────────────────────────────────────
          if (r.message != null && r.message!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.neutral100.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 14,
                        color: AppColors.neutral500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Message from Admin',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.neutral500,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r.message!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.neutral700,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Countdown ──────────────────────────────────────────────────
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                expired
                    ? Icons.timer_off_rounded
                    : Icons.timer_rounded,
                size: 14,
                color: countdownColor,
              ),
              const SizedBox(width: 6),
              Text(
                countdownText,
                style: AppTypography.bodySmall.copyWith(
                  color: countdownColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // ── Action buttons ─────────────────────────────────────────────
          if (expired)
            Center(
              child: Text(
                'No action available — request has expired.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500),
                textAlign: TextAlign.center,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.rejected,
                        side: BorderSide(
                          color: AppColors.rejected.withOpacity(0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.neutral500),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.neutral500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.neutral700,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.time,
    required this.isProposed,
  });

  final String label;
  final String time;
  final bool isProposed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 68,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isProposed
                ? AppColors.blue600.withOpacity(0.1)
                : AppColors.neutral200.withOpacity(0.6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: isProposed ? AppColors.blue600 : AppColors.neutral500,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            time,
            style: AppTypography.titleSmall.copyWith(
              color: isProposed ? AppColors.blue800 : AppColors.neutral500,
              fontWeight: isProposed ? FontWeight.w700 : FontWeight.w400,
              decoration: isProposed ? null : TextDecoration.lineThrough,
              decorationColor: AppColors.neutral400,
            ),
          ),
        ),
      ],
    );
  }
}