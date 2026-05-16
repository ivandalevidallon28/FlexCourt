import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Business logic for when and what to notify. Inserts go to notifications table.
/// Per spec: notifications for reservation_created, reservation_approved, reservation_rejected, etc.
class NotificationService {
  final SupabaseClient _client;

  NotificationService(this._client);

  Future<void> sendUserNotification({
    required String userId,
    required String title,
    required String message,
    String? type,
    String? reservationId,
    Map<String, String>? data,
  }) async {
    await _client.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'message': message,
      if (type != null) 'type': type,
      if (reservationId != null) 'reservation_id': reservationId,
    });
    await _pushToUsers(
      userIds: [userId],
      title: title,
      message: message,
      data: {
        if (type != null) 'type': type,
        if (reservationId != null) 'reservation_id': reservationId,
        ...?data,
      },
    );
  }

  Future<void> pushOnlyToUser({
    required String userId,
    required String title,
    required String message,
    Map<String, String>? data,
  }) async {
    await _pushToUsers(
      userIds: [userId],
      title: title,
      message: message,
      data: data,
    );
  }

  Future<void> notifyAllAdmins({
    required String title,
    required String message,
    Map<String, String>? data,
  }) async {
    final rows =
        await _client.from('users').select('id').eq('role', 'admin');
    final adminIds = (rows as List)
        .map((e) => (e as Map<String, dynamic>)['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (adminIds.isEmpty) return;
    final inserts = adminIds
        .map((id) => {
              'user_id': id,
              'title': title,
              'message': message,
              if (data?['type'] != null) 'type': data!['type'],
              if (data?['reservation_id'] != null)
                'reservation_id': data!['reservation_id'],
            })
        .toList();
    await _client.from('notifications').insert(inserts);
    await _pushToUsers(
      userIds: adminIds,
      title: title,
      message: message,
      data: data,
    );
  }

  Future<void> _pushToUsers({
    required List<String> userIds,
    required String title,
    required String message,
    Map<String, String>? data,
  }) async {
    try {
      final session = _client.auth.currentSession;
      if (session == null) {
        debugPrint('[FlexCourt] Push skipped: no active session');
        return;
      }

      // Validate current auth token before invoking JWT-protected Edge Function.
      final authCheck = await _client.auth.getUser();
      if (authCheck.user == null) {
        debugPrint('[FlexCourt] Push skipped: invalid/expired auth session');
        return;
      }

      await _client.functions.invoke('push_notify', body: {
        'user_ids': userIds,
        'title': title,
        'message': message,
        if (data != null) 'data': data,
      });
    } catch (e) {
      debugPrint('[FlexCourt] Push invoke failed: $e');
    }
  }

  /// After a reservation is created (player or admin).
  /// RPC/notif disabled – manual notif page only.
  Future<void> notifyReservationCreated({
    required String userId,
    required bool createAsAdmin,
  }) async {
    await sendUserNotification(
      userId: userId,
      title: 'Reservation created',
      message: createAsAdmin
          ? 'Admin reservation created. You can edit it in Admin.'
          : 'Your reservation is pending approval.',
      type: 'RESERVATION_CREATED',
    );
  }

  /// After user reschedules an approved reservation (needs re-approval).
  /// RPC/notif disabled – manual notif page only.
  Future<void> notifyRescheduleSubmitted({
    required String userId,
  }) async {
    await sendUserNotification(
      userId: userId,
      title: 'Reschedule submitted',
      message:
          'Your change requires admin approval again. You will be notified when it is reviewed.',
      type: 'RESCHEDULE_SUBMITTED',
    );
  }

  /// After admin edits a user's reservation; user can Get it or Cancel.
  /// RPC/notif disabled – manual notif page only.
  Future<void> notifyAdminEdit({
    required String userId,
    required String reservationId,
  }) async {
    await sendUserNotification(
      userId: userId,
      title: 'Reservation rescheduled by admin',
      message:
          'An admin rescheduled your reservation. Open Notifications and tap Get it to agree or Cancel to decline.',
      type: 'RESERVATION_ADMIN_EDIT',
      reservationId: reservationId,
    );
  }

  /// When admin creates a reservation change request. Player sees it in Notifications with Accept/Reject.
  Future<void> notifyReservationChangeRequest({
    required String userId,
    required String reservationId,
    required String changeRequestId,
    required String courtName,
    required String oldStartTime,
    required String oldEndTime,
    required String newStartTime,
    required String newEndTime,
    String? message,
  }) async {
    final body = message != null && message.isNotEmpty
        ? 'Admin requested a new schedule. Message: $message'
        : 'Admin requested to change your reservation schedule.';
    final payload = {
      'user_id': userId,
      'title': 'Reservation Change Request',
      'message': body,
      'type': 'reservation_change_request',
      'reservation_id': reservationId,
      'change_request_id': changeRequestId,
      'court_name': courtName,
    };
    try {
      await _client.from('notifications').insert(payload);
      await _pushToUsers(
        userIds: [userId],
        title: 'Reservation Change Request',
        message: body,
        data: {
          'type': 'reservation_change_request',
          'reservation_id': reservationId,
          'change_request_id': changeRequestId,
        },
      );
      debugPrint('[FlexCourt] Notification inserted: reservation_change_request for user $userId');
    } catch (e, st) {
      debugPrint('[FlexCourt] Notification insert failed: $e');
      debugPrint('[FlexCourt] Stack: $st');
      rethrow;
    }
  }
}
