import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../notifications/domain/notifications_providers.dart';
import '../../reservations/domain/reservations_providers.dart';
import '../data/reservation_change_request_model.dart';
import '../data/reservation_change_requests_repository.dart';
import 'reservation_change_service.dart';

final reservationChangeRequestsRepositoryProvider =
    Provider<ReservationChangeRequestsRepository>((ref) {
  return ReservationChangeRequestsRepository(Supabase.instance.client);
});

final reservationChangeServiceProvider = Provider<ReservationChangeService>((ref) {
  return ReservationChangeService(
    ref.read(reservationChangeRequestsRepositoryProvider),
    ref.read(reservationsRepositoryProvider),
    ref.read(notificationServiceProvider),
    Supabase.instance.client,
  );
});

/// PENDING change requests for the current player (for banner on reservation cards).
final myPendingChangeRequestsProvider =
    FutureProvider.autoDispose<List<ReservationChangeRequest>>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return [];
  final repo = ref.read(reservationChangeRequestsRepositoryProvider);
  return repo.getPendingByPlayerId(uid);
});

/// All change requests for the current player (for display on notifications page).
final myChangeRequestsProvider =
    FutureProvider.autoDispose<List<ReservationChangeRequest>>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return [];
  final repo = ref.read(reservationChangeRequestsRepositoryProvider);
  return repo.getByPlayerId(uid);
});

/// Single change request by id (for notification card details and countdown).
final changeRequestByIdProvider = FutureProvider.autoDispose
    .family<ReservationChangeRequest?, String>((ref, id) async {
  final repo = ref.read(reservationChangeRequestsRepositoryProvider);
  return repo.getById(id);
});
