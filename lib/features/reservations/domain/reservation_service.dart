import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/reservation_model.dart';
import '../data/reservations_repository.dart';
import '../../notifications/domain/notification_service.dart';

/// Business rules for reservations: validation and orchestration.
/// UI stays thin; validation and notification flow live here.
class ReservationService {
  final ReservationsRepository _repo;
  // ignore: unused_field - used when notification calls are re-enabled
  final NotificationService _notificationService;
  // ignore: unused_field - used when notification calls are re-enabled
  final SupabaseClient _client;

  ReservationService(
    this._repo,
    this._notificationService,
    this._client,
  );

  /// Validates then creates reservation; sends notification. Backend enforces overlap.
  Future<Reservation> createReservation({
    required String courtId,
    required String? categoryId,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String eventType,
    required int playersCount,
    bool createAsAdmin = false,
  }) async {
    _validateTimeRange(startTime, endTime);
    _validateCreateFields(eventType);

    final reservation = await _repo.createReservation(
      courtId: courtId,
      categoryId: categoryId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      eventType: eventType,
      playersCount: playersCount,
      createAsAdmin: createAsAdmin,
    );
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      await _notificationService.notifyReservationCreated(
        userId: userId,
        createAsAdmin: createAsAdmin,
      );
    }
    if (!createAsAdmin) {
      await _notificationService.notifyAllAdmins(
        title: 'New reservation request',
        message: 'A player submitted a new reservation pending approval.',
        data: {
          'type': 'NEW_RESERVATION_REQUEST',
          'reservation_id': reservation.id,
        },
      );
    }
    return reservation;
  }

  /// Updates reservation; if was APPROVED, sets PENDING and notifies. Backend enforces overlap.
  Future<void> updateReservation({
    required String id,
    required String courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String eventType,
    required int playersCount,
    String? currentStatus,
  }) async {
    _validateTimeRange(startTime, endTime);

    await _repo.updateReservation(
      id: id,
      courtId: courtId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      eventType: eventType,
      playersCount: playersCount,
      currentStatus: currentStatus,
    );

    final wasApproved = currentStatus?.toUpperCase() == 'APPROVED';
    if (wasApproved) {
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        await _notificationService.notifyRescheduleSubmitted(userId: userId);
      }
      await _notificationService.notifyAllAdmins(
        title: 'Reschedule needs approval',
        message: 'A player changed an approved reservation. Review is needed.',
        data: {
          'type': 'RESCHEDULE_PENDING_ADMIN',
          'reservation_id': id,
        },
      );
    }
  }

  Future<void> cancelReservation(String id) async {
    await _repo.cancelReservation(id);
    await _notificationService.notifyAllAdmins(
      title: 'Reservation cancelled',
      message: 'A player cancelled a reservation slot.',
      data: {
        'type': 'RESERVATION_CANCELLED',
        'reservation_id': id,
      },
    );
  }

  void _validateTimeRange(String startTime, String endTime) {
    if (startTime.trim().compareTo(endTime.trim()) >= 0) {
      throw Exception('End time must be after start time.');
    }
  }

  void _validateCreateFields(String eventType) {
    if (eventType.trim().isEmpty) {
      throw Exception('Please fill event type.');
    }
  }
}
