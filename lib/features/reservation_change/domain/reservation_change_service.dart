import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../notifications/domain/notification_service.dart';
import '../../reservations/data/reservations_repository.dart';
import '../data/reservation_change_request_model.dart';
import '../data/reservation_change_requests_repository.dart';

/// Creates change requests, applies accept/reject, and expires old requests.
/// Notification row is created by DB trigger on reservation_change_requests insert.
class ReservationChangeService {
  final ReservationChangeRequestsRepository _changeRepo;
  final ReservationsRepository _reservationsRepo;
  final NotificationService _notificationService;
  final SupabaseClient _client;

  ReservationChangeService(
    this._changeRepo,
    this._reservationsRepo,
    this._notificationService,
    this._client,
  );

  static const Duration expirationDuration = Duration(hours: 24);

  /// Admin creates a change request. Fails if reservation already has a PENDING request (lock rule).
  Future<ReservationChangeRequest> createChangeRequest({
    required String reservationId,
    required String playerId,
    required String courtName,
    required String oldStartTime,
    required String oldEndTime,
    required String newStartTime,
    required String newEndTime,
    String? message,
  }) async {
    final adminId = _client.auth.currentUser?.id;
    if (adminId == null) throw Exception('Not signed in. Please log in again.');

    final existing = await _changeRepo.getPendingByReservation(reservationId);
    if (existing != null) {
      throw Exception(
        'This reservation already has a pending change request. The player must respond first.',
      );
    }

    final expiresAt = DateTime.now().add(expirationDuration);
    final request = await _changeRepo.create(
      reservationId: reservationId,
      playerId: playerId,
      adminId: adminId,
      oldStartTime: oldStartTime,
      oldEndTime: oldEndTime,
      newStartTime: newStartTime,
      newEndTime: newEndTime,
      message: message,
      expiresAt: expiresAt,
    );
    debugPrint('[CourtSide] Change request created: ${request.id} for reservation $reservationId');
    // Notification is inserted by DB trigger notify_on_change_request_insert (so Notifications page shows it).
    await _notificationService.pushOnlyToUser(
      userId: playerId,
      title: 'Reservation Change Request',
      message:
          'Admin requested to change your reservation schedule. Please review in Notifications.',
      data: {
        'type': 'reservation_change_request',
        'reservation_id': reservationId,
        'change_request_id': request.id,
      },
    );
    return request;
  }

  /// Player accepts the change.
  /// - Apply new times
  /// - Set reservation back to PENDING so admin can approve again
  /// - Mark request ACCEPTED
  /// [notificationId] optional; if null, marks any notification with this change_request_id as read.
  Future<void> acceptChangeRequest({
    required String changeRequestId,
    required String userId,
    String? notificationId,
  }) async {
    final request = await _changeRepo.getById(changeRequestId);
    if (request == null) throw Exception('Change request not found');
    if (request.playerId != userId) throw Exception('Not your change request');
    if (!request.isPending) throw Exception('This request is no longer pending');
    if (request.expiresAt.isBefore(DateTime.now())) {
      throw Exception('This change request has expired');
    }

    await _reservationsRepo.updateReservationTimes(
      request.reservationId,
      request.newStartTime,
      request.newEndTime,
    );
    await _client
        .from('reservations')
        .update({'status': 'PENDING'})
        .eq('id', request.reservationId);
    await _changeRepo.updateStatus(changeRequestId, 'ACCEPTED');
    await _markNotificationReadForChangeRequest(changeRequestId, notificationId);
    await _notificationService.notifyAllAdmins(
      title: 'Player accepted new schedule',
      message:
          'Player accepted the admin schedule adjustment. Reservation is now pending for re-approval.',
      data: {
        'type': 'CHANGE_REQUEST_ACCEPTED',
        'reservation_id': request.reservationId,
      },
    );
  }

  /// Player rejects the change.
  /// - Cancel reservation so the slot is released for booking
  /// - Mark request REJECTED
  /// [notificationId] optional; if null, marks any notification with this change_request_id as read.
  Future<void> rejectChangeRequest({
    required String changeRequestId,
    required String userId,
    String? notificationId,
  }) async {
    final request = await _changeRepo.getById(changeRequestId);
    if (request == null) throw Exception('Change request not found');
    if (request.playerId != userId) throw Exception('Not your change request');
    if (!request.isPending) throw Exception('This request is no longer pending');

    await _client
        .from('reservations')
        .update({'status': 'CANCELLED'})
        .eq('id', request.reservationId);
    await _changeRepo.updateStatus(changeRequestId, 'REJECTED');
    await _markNotificationReadForChangeRequest(changeRequestId, notificationId);
    await _notificationService.notifyAllAdmins(
      title: 'Player declined schedule adjustment',
      message:
          'Player declined the admin adjustment. Reservation was cancelled and the slot is now available.',
      data: {
        'type': 'CHANGE_REQUEST_REJECTED',
        'reservation_id': request.reservationId,
      },
    );
  }

  Future<void> _markNotificationReadForChangeRequest(
    String changeRequestId,
    String? notificationId,
  ) async {
    if (notificationId != null && notificationId.isNotEmpty) {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } else {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('change_request_id', changeRequestId);
    }
  }

  /// Mark PENDING requests as EXPIRED where expires_at has passed. Call on app open or periodically.
  Future<int> expireChangeRequest() async {
    return _changeRepo.expirePendingWhereExpired();
  }
}
