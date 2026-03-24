import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

import 'reservation_model.dart';

class ReservationsRepository {
  final SupabaseClient _client;

  ReservationsRepository(this._client);

  /// Normalize time for RPC (PostgreSQL time): "HH:mm" or "HH:mm:ss" -> "HH:mm:00" so PostgREST accepts it.
  static String _normalizeTimeForRpc(String t) {
    final s = t.trim();
    if (s.length == 5 && s[2] == ':') return '$s:00'; // HH:mm -> HH:mm:00
    return s;
  }

  /// Only the current user's reservations (filtered by user_id).
  Future<List<Reservation>> getMyReservations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final res = await _client
        .from('reservations')
        .select()
        .eq('user_id', userId)
        .order('date', ascending: false)
        .order('start_time', ascending: false);
    return (res as List)
        .map((e) => Reservation.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Reservation>> getCourtReservations(
    String courtId,
    DateTime day,
  ) async {
    final res = await _client
        .from('reservations')
        .select()
        .eq('court_id', courtId)
        .eq('date', day.toIso8601String().substring(0, 10))
        .order('start_time');
    return (res as List)
        .map((e) => Reservation.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches occupied time ranges for a court/date (for availability). Uses RPC so players can see slots.
  Future<List<({String start, String end})>> getOccupiedSlots(
    String courtId,
    DateTime day,
  ) async {
    final res = await _client.rpc(
      'get_occupied_slots',
      params: {
        'p_court_id': courtId,
        'p_date': day.toIso8601String().substring(0, 10),
      },
    );
    if (res == null) return [];
    return (res as List)
        .map((e) {
          final m = e as Map<String, dynamic>;
          final start = m['start_time'] as String? ?? '';
          final end = m['end_time'] as String? ?? '';
          return (start: start.length >= 5 ? start.substring(0, 5) : start, end: end.length >= 5 ? end.substring(0, 5) : end);
        })
        .toList();
  }

  /// Creates a reservation via direct Supabase (no Edge Function), avoiding gateway 401/JWT issues.
  /// With one court, courtId should be the single venue; categoryId is the activity category (Basketball, Volleyball, etc.).
  /// When [createAsAdmin] is true, status is set to 'ADMIN' (admin-created; admin can edit it later).
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
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw AuthException('Not signed in. Please log in again.');
    }

    final dateStr = date.toIso8601String().substring(0, 10);

    final overlapRes = await _client.rpc(
      'check_reservation_overlap',
      params: {
        'p_court_id': courtId,
        'p_date': dateStr,
        'p_start': _normalizeTimeForRpc(startTime),
        'p_end': _normalizeTimeForRpc(endTime),
      },
    );
    if (overlapRes == null) {
      throw Exception('Could not check availability');
    }
    if (overlapRes != true) {
      throw Exception('Time slot already booked');
    }

    final priceRes = await _client.rpc(
      'calculate_booking_price',
      params: {
        'p_date': dateStr,
        'p_start': startTime,
        'p_end': endTime,
      },
    );
    final price = (priceRes is num) ? priceRes : 0.0;

    final status = createAsAdmin ? 'ADMIN' : 'PENDING';
    final insertPayload = <String, dynamic>{
      'user_id': userId,
      'court_id': courtId,
      'date': dateStr,
      'start_time': startTime,
      'end_time': endTime,
      'event_type': eventType,
      'players_count': playersCount,
      'price': price,
      'status': status,
    };
    if (categoryId != null) insertPayload['category_id'] = categoryId;

    final insertRes = await _client
        .from('reservations')
        .insert(insertPayload)
        .select()
        .single();

    final reservation = Reservation.fromMap(insertRes);
    // Notification is sent by NotificationService (called from ReservationService).
    return reservation;
  }

  Future<void> cancelReservation(String id) async {
    await _client
        .from('reservations')
        .update({'status': 'CANCELLED'}).eq('id', id);
  }

  /// Update only start_time and end_time (e.g. when player accepts a change request). No overlap check.
  Future<void> updateReservationTimes(
    String reservationId,
    String startTime,
    String endTime,
  ) async {
    await _client.from('reservations').update({
      'start_time': _normalizeTimeForRpc(startTime),
      'end_time': _normalizeTimeForRpc(endTime),
    }).eq('id', reservationId);
  }

  /// Updates reservation details. When [currentStatus] is APPROVED, also sets status to PENDING
  /// and inserts a notification so admin must re-approve (reschedule-after-approval flow).
  /// [courtId] is required to validate the new slot does not overlap others (current reservation excluded).
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
    final dateStr = date.toIso8601String().substring(0, 10);
    final overlapRes = await _client.rpc(
      'check_reservation_overlap',
      params: {
        'p_court_id': courtId,
        'p_date': dateStr,
        'p_start': _normalizeTimeForRpc(startTime),
        'p_end': _normalizeTimeForRpc(endTime),
        'p_exclude_reservation_id': id,
      },
    );
    if (overlapRes == null) {
      throw Exception('Could not check availability');
    }
    if (overlapRes != true) {
      throw Exception('Time slot already booked');
    }

    final payload = <String, dynamic>{
      'date': dateStr,
      'start_time': startTime,
      'end_time': endTime,
      'event_type': eventType,
      'players_count': playersCount,
    };
    final wasApproved = currentStatus?.toUpperCase() == 'APPROVED';
    if (wasApproved) {
      payload['status'] = 'PENDING';
    }
    await _client.from('reservations').update(payload).eq('id', id);
    // Reschedule notification is sent by NotificationService (called from ReservationService).
  }

  RealtimeChannel subscribeToMyReservationsChanges(void Function() onChange) {
    final userId = _client.auth.currentUser!.id;
    final channel = _client
        .channel('public:reservations:user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reservations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'reservations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'reservations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onChange(),
        )
        .subscribe();
    return channel;
  }

  Future<void> uploadPaymentReceipt({
    required String reservationId,
    required Uint8List fileBytes,
    required String fileExtension,
    required String contentType,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw AuthException('Not signed in. Please log in again.');
    }
    final safeExt = fileExtension.toLowerCase().replaceAll('.', '');
    final path =
        'receipts/$userId/$reservationId/${DateTime.now().millisecondsSinceEpoch}.$safeExt';

    await _client.storage.from('document').uploadBinary(
          path,
          fileBytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    await _client.from('reservations').update({
      'payment_receipt_path': path,
      'payment_receipt_uploaded_at': DateTime.now().toIso8601String(),
      'payment_status': 'RECEIPT_UPLOADED',
      'payment_review_note': null,
      'payment_reviewed_by': null,
      'payment_reviewed_at': null,
    }).eq('id', reservationId);
  }

  Future<String> getSignedReceiptUrl(String path, {int expiresInSeconds = 3600}) {
    return _client.storage
        .from('document')
        .createSignedUrl(path, expiresInSeconds);
  }

  Future<void> setPaymentStatusByAdmin({
    required String reservationId,
    required String paymentStatus,
    String? reviewNote,
  }) async {
    final adminId = _client.auth.currentUser?.id;
    await _client.from('reservations').update({
      'payment_status': paymentStatus,
      'payment_review_note': reviewNote?.trim().isEmpty == true ? null : reviewNote?.trim(),
      'payment_reviewed_by': adminId,
      'payment_reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', reservationId);
  }
}

