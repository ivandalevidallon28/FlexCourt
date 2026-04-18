import 'package:supabase_flutter/supabase_flutter.dart';

import 'ball_model.dart';
import 'ball_rental_model.dart';

class BallsRepository {
  BallsRepository(this._client);

  final SupabaseClient _client;

  RealtimeChannel subscribeToBallsChanges(void Function() onChange) {
    return _client
        .channel('public:balls:all')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'balls',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'balls',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'balls',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  RealtimeChannel subscribeToBallRentalsChanges(void Function() onChange) {
    return _client
        .channel('public:ball_rentals:user_relevant')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ball_rentals',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ball_rentals',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'ball_rentals',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<List<Ball>> getBalls() async {
    final res =
        await _client.from('balls').select().order('name', ascending: true);
    return (res as List)
        .map((e) => Ball.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Active rentals for the current user (RLS), with ball name for display.
  Future<List<BallRental>> getMyActiveRentals() async {
    final res = await _client
        .from('ball_rentals')
        .select('id, ball_id, user_id, amount, status, created_at, returned_at, paid_at, balls(name)')
        .eq('status', 'ACTIVE')
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => BallRental.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Admin / reporting: recent rentals visible under RLS.
  Future<List<BallRental>> getRecentRentals({int limit = 50}) async {
    final res = await _client
        .from('ball_rentals')
        .select(
            'id, ball_id, user_id, amount, status, created_at, returned_at, paid_at, balls(name)')
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List)
        .map((e) => BallRental.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> rentBall(String ballId) async {
    final raw = await _client.rpc(
      'rent_ball',
      params: {'p_ball_id': ballId},
    );
    if (raw == null) {
      throw StateError('rent_ball returned no id');
    }
    return raw.toString();
  }

  Future<void> returnBall(String rentalId) async {
    await _client.rpc(
      'return_ball',
      params: {'p_rental_id': rentalId},
    );
  }

  Future<void> createBall(String name) async {
    await _client.from('balls').insert({
      'name': name.trim(),
      'status': 'AVAILABLE',
    });
  }

  Future<void> deleteBall(String id) async {
    await _client.from('balls').delete().eq('id', id);
  }

  Future<void> updateBallStatus(String id, String status) async {
    if (status != 'AVAILABLE' && status != 'IN_USE') {
      throw ArgumentError('Invalid ball status: $status');
    }
    await _client.from('balls').update({'status': status}).eq('id', id);
  }
}
