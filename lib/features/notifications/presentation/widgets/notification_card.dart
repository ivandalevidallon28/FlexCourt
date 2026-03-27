import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_design_system.dart';
import '../../../reservation_change/data/reservation_change_request_model.dart';
import '../../data/notification_model.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onCancel,
    required this.onGetIt,
    required this.onMarkRead,
    this.changeRequest,
    this.changeRequestLoading = false,
    this.onAccept,
    this.onReject,
  });

  final AppNotification notification;
  final VoidCallback onCancel;
  final VoidCallback onGetIt;
  final VoidCallback onMarkRead;
  final ReservationChangeRequest? changeRequest;
  final bool changeRequestLoading;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final isChangeRequest = n.type == 'reservation_change_request' &&
        n.changeRequestId != null &&
        !n.isRead;
    final isAdminEdit =
        n.type == 'RESERVATION_ADMIN_EDIT' && !n.isRead && n.reservationId != null;
    final isRead = n.isRead;

    // ── Icon + color by type ──────────────────────────────────────────────
    final (typeIcon, typeColor) = _typeAssets(n.type ?? 'GENERAL');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardBg(context, isRead),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead
              ? AppColors.neutral200.withOpacity(0.6)
              : typeColor.withOpacity(0.25),
          width: isRead ? 1 : 1.5,
        ),
        boxShadow: isRead
            ? null
            : [
          BoxShadow(
            color: typeColor.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header row ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type icon
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(typeIcon, size: 18, color: typeColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight:
                          isRead ? FontWeight.w500 : FontWeight.w700,
                          color: isRead
                              ? AppColors.neutral600
                              : AppColors.blue800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        n.message,
                        style: AppTypography.bodySmall.copyWith(
                          color: isRead
                              ? AppColors.neutral500
                              : AppColors.neutral700,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Unread dot
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: typeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),

            // ── Change request details ───────────────────────────────────
            if (isChangeRequest && changeRequestLoading) ...[
              const SizedBox(height: 10),
              const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ] else if (isChangeRequest && changeRequest != null) ...[
              const SizedBox(height: 12),
              _ChangeRequestDetails(
                courtName: n.courtName ?? 'Court',
                request: changeRequest!,
              ),
            ],

            // ── Admin edit hint ──────────────────────────────────────────
            if (isAdminEdit) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.orange700.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.orange700.withOpacity(0.2)),
                ),
                child: Text(
                  '"Get it" = agree to reschedule  ·  "Cancel" = decline',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.orange700,
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Action row ───────────────────────────────────────────────
            // Use Wrap to prevent small right-side overflows on narrow screens.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                // Timestamp
                Text(
                  _relativeTime(n.createdAt),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.neutral400,
                    fontSize: 11,
                  ),
                ),

                // Action buttons
                _buildActions(
                  context,
                  isChangeRequest: isChangeRequest,
                  isAdminEdit: isAdminEdit,
                  isRead: isRead,
                  changeRequest: changeRequest,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(
      BuildContext context, {
        required bool isChangeRequest,
        required bool isAdminEdit,
        required bool isRead,
        ReservationChangeRequest? changeRequest,
      }) {
    if (isChangeRequest) {
      if (changeRequest == null) return const SizedBox.shrink();
      final expired =
          changeRequest.isExpired ||
              changeRequest.expiresAt.isBefore(DateTime.now());
      if (expired) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.rejected.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Expired',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.rejected,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionBtn(
            label: 'Reject',
            color: AppColors.rejected,
            outlined: true,
            onTap: onReject,
          ),
          const SizedBox(width: 8),
          _ActionBtn(
            label: 'Accept',
            color: AppColors.approved,
            onTap: onAccept,
          ),
        ],
      );
    }

    if (isAdminEdit) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionBtn(
            label: 'Cancel',
            color: AppColors.rejected,
            outlined: true,
            onTap: onCancel,
          ),
          const SizedBox(width: 8),
          _ActionBtn(
            label: 'Get it',
            color: AppColors.approved,
            onTap: onGetIt,
          ),
        ],
      );
    }

    if (isRead) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded,
              size: 16, color: AppColors.approved),
          const SizedBox(width: 4),
          Text(
            'Read',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.approved,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    return _ActionBtn(
      label: 'Mark read',
      color: AppColors.blue600,
      outlined: true,
      onTap: onMarkRead,
    );
  }

  Color _cardBg(BuildContext context, bool isRead) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isRead) {
      return isDark
          ? Colors.white.withOpacity(0.03)
          : Colors.white.withOpacity(0.55);
    }
    return isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.85);
  }

  (IconData, Color) _typeAssets(String type) {
    switch (type) {
      case 'reservation_change_request':
        return (Icons.swap_horiz_rounded, AppColors.orange700);
      case 'RESERVATION_ADMIN_EDIT':
        return (Icons.admin_panel_settings_rounded, AppColors.blue600);
      case 'RESERVATION_APPROVED':
        return (Icons.check_circle_rounded, AppColors.approved);
      case 'RESERVATION_REJECTED':
        return (Icons.cancel_rounded, AppColors.rejected);
      case 'RESERVATION_CANCELLED':
        return (Icons.event_busy_rounded, AppColors.rejected);
      default:
        return (Icons.notifications_rounded, AppColors.blue600);
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action button
// ─────────────────────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.5)),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label,
            style: AppTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w600)),
      );
    }
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: 0,
      ),
      child: Text(label,
          style: AppTypography.labelSmall.copyWith(
              fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Change Request Details
// ─────────────────────────────────────────────────────────────────────────────

class _ChangeRequestDetails extends StatefulWidget {
  const _ChangeRequestDetails({
    required this.courtName,
    required this.request,
  });

  final String courtName;
  final ReservationChangeRequest request;

  @override
  State<_ChangeRequestDetails> createState() => _ChangeRequestDetailsState();
}

class _ChangeRequestDetailsState extends State<_ChangeRequestDetails> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(minutes: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final expired = r.isExpired || r.expiresAt.isBefore(DateTime.now());
    final remaining = r.expiresAt.difference(DateTime.now());
    final countdownText = expired
        ? 'Expired'
        : remaining.inHours >= 1
        ? '${remaining.inHours}h ${remaining.inMinutes % 60}m left'
        : remaining.inMinutes >= 1
        ? '${remaining.inMinutes}m left'
        : 'Expires very soon';
    final countdownColor = expired
        ? AppColors.rejected
        : remaining.inHours < 1
        ? AppColors.orange700
        : AppColors.neutral600;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blue600.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blue600.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Court
          Row(
            children: [
              const Icon(Icons.stadium_rounded,
                  size: 13, color: AppColors.neutral500),
              const SizedBox(width: 6),
              Text(
                widget.courtName,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.neutral600),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Time comparison
          Row(
            children: [
              Expanded(
                child: _TimeBlock(
                  label: 'Old time',
                  time: '${r.oldStartTime} – ${r.oldEndTime}',
                  isNew: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 16, color: AppColors.blue600.withOpacity(0.5)),
              ),
              Expanded(
                child: _TimeBlock(
                  label: 'New time',
                  time: '${r.newStartTime} – ${r.newEndTime}',
                  isNew: true,
                ),
              ),
            ],
          ),

          // Admin message
          if (r.message != null && r.message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.message_rounded,
                    size: 12, color: AppColors.neutral500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r.message!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.neutral600,
                      fontStyle: FontStyle.italic,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),

          // Countdown
          Row(
            children: [
              Icon(
                expired
                    ? Icons.timer_off_rounded
                    : Icons.timer_rounded,
                size: 12,
                color: countdownColor,
              ),
              const SizedBox(width: 5),
              Text(
                countdownText,
                style: AppTypography.bodySmall.copyWith(
                  color: countdownColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.label,
    required this.time,
    required this.isNew,
  });

  final String label;
  final String time;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final color = isNew ? AppColors.blue600 : AppColors.neutral400;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: AppTypography.labelSmall.copyWith(
            color: isNew ? AppColors.blue800 : AppColors.neutral500,
            fontWeight: isNew ? FontWeight.w700 : FontWeight.w400,
            decoration: isNew ? null : TextDecoration.lineThrough,
            decorationColor: AppColors.neutral400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}