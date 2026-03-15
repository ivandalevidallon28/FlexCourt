import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../reservation_change/domain/reservation_change_providers.dart';
import '../data/notification_model.dart';
import '../domain/notifications_providers.dart';
import 'widgets/notification_card.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(myNotificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Notifications',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(myNotificationsProvider);
              ref.invalidate(changeRequestByIdProvider);
            },
          ),
        ],
      ),
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
        child: AsyncValueView<List<AppNotification>>(
          value: notifsAsync,
          isEmpty: (list) => list.isEmpty,
          empty: () => const EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'No notifications yet',
            subtitle: "You'll see reservation updates and reminders here.",
          ),
          data: (list) {
            final changeRequestNotifs = list
                .where((n) => n.type == 'reservation_change_request')
                .toList();
            final otherNotifs = list
                .where((n) => n.type != 'reservation_change_request')
                .toList();
            final unreadCount = list.where((n) => !n.isRead).length;

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myNotificationsProvider);
                ref.invalidate(changeRequestByIdProvider);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // ── Summary row ──────────────────────────────────────
                  if (unreadCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.blue600.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.blue600.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.circle_notifications_rounded,
                              size: 16, color: AppColors.blue600),
                          const SizedBox(width: 8),
                          Text(
                            '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.blue800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Change requests section ──────────────────────────
                  if (changeRequestNotifs.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.swap_horiz_rounded,
                      title: 'Change Requests',
                      count: changeRequestNotifs.length,
                      color: AppColors.orange700,
                    ),
                    const SizedBox(height: 10),
                    ...changeRequestNotifs.map(
                          (n) => _buildNotificationCard(ref, context, n),
                    ),
                    if (otherNotifs.isNotEmpty) const SizedBox(height: 20),
                  ],

                  // ── Other notifications section ──────────────────────
                  if (otherNotifs.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.notifications_rounded,
                      title: 'Notifications',
                      count: otherNotifs.length,
                      color: AppColors.blue600,
                    ),
                    const SizedBox(height: 10),
                    ...otherNotifs.map(
                          (n) => _buildNotificationCard(ref, context, n),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
      WidgetRef ref,
      BuildContext context,
      AppNotification n,
      ) {
    final changeRequestAsync = n.changeRequestId != null
        ? ref.watch(changeRequestByIdProvider(n.changeRequestId!))
        : null;
    final changeRequest = changeRequestAsync?.valueOrNull;
    final changeRequestLoading =
        n.type == 'reservation_change_request' &&
            (changeRequestAsync?.isLoading ?? false);

    return NotificationCard(
      notification: n,
      changeRequest: changeRequest,
      changeRequestLoading: changeRequestLoading,
      onAccept: n.changeRequestId != null && n.reservationId != null
          ? () async {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid == null) return;
        try {
          await ref
              .read(reservationChangeServiceProvider)
              .acceptChangeRequest(
            changeRequestId: n.changeRequestId!,
            userId: uid,
            notificationId: n.id,
          );
          ref.invalidate(myNotificationsProvider);
          ref.invalidate(myPendingChangeRequestsProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Change accepted. Reservation updated.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }
      }
          : null,
      onReject: n.changeRequestId != null
          ? () async {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid == null) return;
        try {
          await ref
              .read(reservationChangeServiceProvider)
              .rejectChangeRequest(
            changeRequestId: n.changeRequestId!,
            userId: uid,
            notificationId: n.id,
          );
          ref.invalidate(myNotificationsProvider);
          ref.invalidate(myPendingChangeRequestsProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Change declined. Your reservation stays as is.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }
      }
          : null,
      onCancel: () async {
        await ref
            .read(notificationsRepositoryProvider)
            .handleAdminEditDecision(
          notificationId: n.id,
          reservationId: n.reservationId!,
          accept: false,
        );
        ref.invalidate(myNotificationsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reservation cancelled.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      onGetIt: () async {
        await ref
            .read(notificationsRepositoryProvider)
            .handleAdminEditDecision(
          notificationId: n.id,
          reservationId: n.reservationId!,
          accept: true,
        );
        ref.invalidate(myNotificationsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Got it. Reservation approved.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onMarkRead: () => ref
          .read(notificationsRepositoryProvider)
          .markAsRead(n.id)
          .then((_) => ref.invalidate(myNotificationsProvider)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.titleSmall.copyWith(
            color: AppColors.blue800,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}