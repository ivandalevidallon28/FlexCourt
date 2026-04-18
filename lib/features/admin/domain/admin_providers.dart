import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin dashboard stats (reservations today, pending, busiest hour, etc.).
final adminStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = Supabase.instance.client;
  final today = DateTime.now().toIso8601String().substring(0, 10);

  final totalTodayData = await client
      .from('reservations')
      .select('id')
      .eq('date', today);
  final totalToday = (totalTodayData as List).length;

  final pendingTodayData = await client
      .from('reservations')
      .select('id')
      .eq('status', 'PENDING');
  final pendingToday = (pendingTodayData as List).length;

  final analytics = await client
      .from('analytics_daily')
      .select()
      .eq('date', today)
      .maybeSingle();

  final weekAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String().substring(0, 10);
  final busiestDaysData = await client
      .from('analytics_daily')
      .select('date,total_bookings')
      .gte('date', weekAgo)
      .order('total_bookings', ascending: false)
      .limit(5);
  final busiestDays = busiestDaysData as List;

  return {
    'totalToday': totalToday,
    'pending': pendingToday,
    'busiestHour': analytics?['busiest_hour'],
    'mostSport': analytics?['most_booked_sport'],
    'busiestDays': busiestDays,
  };
});

/// Admin pending reservations list (player-created; approve/reject only).
final adminPendingReservationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final res = await client
      .from('reservations')
      .select(
        '*, users:users!reservations_user_id_fkey(name,email,contact_number), courts(name), categories(name)',
      )
      .eq('status', 'PENDING')
      .order('date')
      .order('start_time');
  return (res as List).cast<Map<String, dynamic>>();
});

/// Admin-created reservations (status = ADMIN); admin can edit these.
final adminAdminReservationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final res = await client
      .from('reservations')
      .select(
        '*, users:users!reservations_user_id_fkey(name,email), courts(name), categories(name)',
      )
      .eq('status', 'ADMIN')
      .order('date')
      .order('start_time');
  return (res as List).cast<Map<String, dynamic>>();
});

/// Admin users list.
final adminUsersListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('users')
      .select()
      .order('name');
  return (res as List).cast<Map<String, dynamic>>();
});

/// Admin schedule (reservations for a date, optional event type filter).
final adminScheduleProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String date, String? categoryId})>((ref, params) async {
  var query = Supabase.instance.client
      .from('reservations')
      .select(
        '*, users:users!reservations_user_id_fkey(name,email), courts(name,sport_type), categories(name)',
      )
      .eq('date', params.date);
  if (params.categoryId != null && params.categoryId!.isNotEmpty) {
    query = query.eq('category_id', params.categoryId!);
  }
  final res = await query.order('start_time');
  return (res as List).cast<Map<String, dynamic>>();
});

/// Admin schedule range (used by weekly calendar mode).
final adminScheduleRangeProvider = FutureProvider.autoDispose.family<
    List<Map<String, dynamic>>,
    ({String startDate, String endDate, String? categoryId})>((ref, params) async {
  var query = Supabase.instance.client
      .from('reservations')
      .select(
        '*, users:users!reservations_user_id_fkey(name,email), courts(name,sport_type), categories(name)',
      )
      .gte('date', params.startDate)
      .lte('date', params.endDate);
  if (params.categoryId != null && params.categoryId!.isNotEmpty) {
    query = query.eq('category_id', params.categoryId!);
  }
  final res = await query.order('date').order('start_time');
  return (res as List).cast<Map<String, dynamic>>();
});
