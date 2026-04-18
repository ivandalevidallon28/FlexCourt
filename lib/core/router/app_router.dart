import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/domain/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/courts/presentation/courts_list_screen.dart';
import '../../features/reservations/presentation/player_reservations_screen.dart';
import '../../features/reservations/presentation/reservation_details_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_pending_reservations_screen.dart';
import '../../features/admin/presentation/admin_users_screen.dart';
import '../../features/admin/presentation/admin_categories_screen.dart';
import '../../features/admin/presentation/admin_admin_reservations_screen.dart';
import '../../features/admin/presentation/admin_schedule_screen.dart';
import '../../features/ball_rental/presentation/admin_balls_screen.dart';
import '../../features/ball_rental/presentation/ball_rental_list_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final supabase = Supabase.instance.client;

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final session = supabase.auth.currentSession;
      final location = state.matchedLocation;
      final loggingIn = location == '/login' || location == '/register';

      if (session == null && !loggingIn) {
        return '/login';
      }
      if (session != null && loggingIn) {
        return '/home';
      }
      // Admin routes: only allow if role is 'admin' in users table
      if (session != null && (location == '/admin' || location.startsWith('/admin/'))) {
        try {
          final profile = await ref.read(currentUserProfileProvider.future);
          final role = profile?['role']?.toString().trim().toLowerCase();
          if (role != 'admin') {
            return '/home';
          }
        } catch (_) {
          return '/home';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const PlayerReservationsScreen(),
      ),
      GoRoute(
        path: '/reservation/:id',
        builder: (context, state) => ReservationDetailsScreen(
          reservationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/courts',
        builder: (context, state) => const CourtsListScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/balls',
        builder: (context, state) => const BallRentalListScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/pending',
        builder: (context, state) => const AdminPendingReservationsScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: '/admin/categories',
        builder: (context, state) => const AdminCategoriesScreen(),
      ),
      GoRoute(
        path: '/admin/reservations',
        builder: (context, state) => const AdminAdminReservationsScreen(),
      ),
      GoRoute(
        path: '/admin/schedule',
        builder: (context, state) => const AdminScheduleScreen(),
      ),
      GoRoute(
        path: '/admin/balls',
        builder: (context, state) => const AdminBallsScreen(),
      ),
    ],
  );
});

