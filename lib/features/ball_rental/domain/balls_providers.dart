import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/ball_model.dart';
import '../data/ball_rental_model.dart';
import '../data/balls_repository.dart';

final ballsRepositoryProvider = Provider<BallsRepository>((ref) {
  return BallsRepository(Supabase.instance.client);
});

final ballsListProvider = FutureProvider<List<Ball>>((ref) async {
  final repo = ref.read(ballsRepositoryProvider);
  return repo.getBalls();
});

final myActiveBallRentalsProvider = FutureProvider<List<BallRental>>((ref) async {
  final repo = ref.read(ballsRepositoryProvider);
  return repo.getMyActiveRentals();
});

final adminBallRentalsRecentProvider =
    FutureProvider<List<BallRental>>((ref) async {
  final repo = ref.read(ballsRepositoryProvider);
  return repo.getRecentRentals(limit: 80);
});
