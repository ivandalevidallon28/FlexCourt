import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../notifications/domain/notifications_providers.dart';
import '../data/reservation_model.dart';
import '../data/reservations_repository.dart';
import 'reservation_service.dart';

final reservationsRepositoryProvider =
    Provider<ReservationsRepository>((ref) {
  return ReservationsRepository(Supabase.instance.client);
});

/// Business logic: validation + repo + notifications.
final reservationServiceProvider = Provider<ReservationService>((ref) {
  return ReservationService(
    ref.read(reservationsRepositoryProvider),
    ref.read(notificationServiceProvider),
    Supabase.instance.client,
  );
});

/// My reservations; refreshes in realtime when admin approves/rejects or reservation is updated.
final AutoDisposeFutureProvider<List<Reservation>> myReservationsProvider =
    FutureProvider.autoDispose<List<Reservation>>((ref) async {
  final repo = ref.read(reservationsRepositoryProvider);
  final channel = repo.subscribeToMyReservationsChanges(() {
    ref.invalidate(myReservationsProvider);
    ref.invalidate(occupiedSlotsProvider);
  });
  ref.onDispose(() {
    Supabase.instance.client.removeChannel(channel);
  });
  return repo.getMyReservations();
});

/// Occupied time slots for a court/date (for availability). Key: 'courtId|yyyy-MM-dd'.
final occupiedSlotsProvider = FutureProvider.autoDispose
    .family<List<({String start, String end})>, ({String courtId, String date})>((ref, key) async {
  final repo = ref.read(reservationsRepositoryProvider);
  return repo.getOccupiedSlots(
    key.courtId,
    DateTime.parse(key.date),
  );
});

/// Single reservation details for deep-links (payment / history).
final reservationByIdProvider = FutureProvider.autoDispose
    .family<Reservation?, String>((ref, reservationId) async {
  final repo = ref.read(reservationsRepositoryProvider);
  return repo.getReservationById(reservationId);
});

