import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/push/push_notifications_service.dart';
import '../data/notifications_repository.dart';
import '../data/notification_model.dart';
import 'notification_service.dart';

/// Repository Provider
final notificationsRepositoryProvider =
Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(Supabase.instance.client);
});

/// Notification business logic (when/what to notify).
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(Supabase.instance.client);
});

final pushNotificationsServiceProvider = Provider<PushNotificationsService>((ref) {
  return PushNotificationsService(Supabase.instance.client);
});

/// My Notifications Provider with explicit type to avoid circular inference
final AutoDisposeFutureProvider<List<AppNotification>> myNotificationsProvider =
FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final repo = ref.read(notificationsRepositoryProvider);

  /// Subscribe to realtime notifications
  final channel = repo.subscribeToNotifications(() {
    ref.invalidate(myNotificationsProvider);
  });

  /// Clean up the channel when provider is disposed
  ref.onDispose(() {
    Supabase.instance.client.removeChannel(channel);
  });

  /// Fetch notifications
  return repo.getMyNotifications();
});