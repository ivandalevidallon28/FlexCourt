import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../domain/admin_providers.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  RealtimeChannel? _reservationsChannel;
  RealtimeChannel? _analyticsChannel;

  @override
  void dispose() {
    final client = Supabase.instance.client;
    if (_reservationsChannel != null) client.removeChannel(_reservationsChannel!);
    if (_analyticsChannel != null) client.removeChannel(_analyticsChannel!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reservationsChannel == null) {
      _reservationsChannel = Supabase.instance.client
          .channel('admin:reservations')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'reservations',
        callback: (_) => ref.invalidate(adminStatsProvider),
      )
          .subscribe();
    }
    if (_analyticsChannel == null) {
      _analyticsChannel = Supabase.instance.client
          .channel('admin:analytics')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'analytics_daily',
        callback: (_) => ref.invalidate(adminStatsProvider),
      )
          .subscribe();
    }

    final statsAsync = ref.watch(adminStatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Admin Dashboard',
        actions: [AppBarThemeToggle()],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.surfaceGradientDark
              : AppColors.surfaceGradientLight,
        ),
        child: statsAsync.when(
          data: (stats) => _DashboardBody(stats: stats),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 40),
                  const SizedBox(height: 12),
                  Text('Something went wrong',
                      style: AppTypography.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    e.toString(),
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.neutral600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Body
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final busiestDays = (stats['busiestDays'] as List?)
        ?.cast<Map<String, dynamic>>() ??
        [];
    final pending = (stats['pending'] ?? 0) as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Greeting / date ──────────────────────────────────────────
          Text(
            DateFormat('EEEE, MMM d').format(DateTime.now()),
            style: AppTypography.bodySmall.copyWith(color: AppColors.neutral600),
          ),
          const SizedBox(height: 2),
          Text(
            'Overview',
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.blue800,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 16),

          // ── Metric cards (2-column grid) ─────────────────────────────
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              _MetricCard(
                icon: Icons.event_available_rounded,
                label: 'Today',
                value: (stats['totalToday'] ?? 0).toString(),
                color: AppColors.blue600,
              ),
              _MetricCard(
                icon: Icons.pending_actions_rounded,
                label: 'Pending',
                value: pending.toString(),
                color: pending > 0 ? AppColors.orange700 : AppColors.approved,
                urgent: pending > 0,
              ),
              _MetricCard(
                icon: Icons.schedule_rounded,
                label: 'Busiest hour',
                value: stats['busiestHour']?.toString() ?? '—',
                color: AppColors.blue600,
              ),
              _MetricCard(
                icon: Icons.sports_rounded,
                label: 'Top sport',
                value: stats['mostSport']?.toString() ?? '—',
                color: AppColors.orange700,
                smallValue: true,
              ),
            ],
          ),

          // ── Busiest days ─────────────────────────────────────────────
          if (busiestDays.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(
              icon: Icons.bar_chart_rounded,
              title: 'Busiest days',
              subtitle: 'Last 7 days',
            ),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: busiestDays.map((m) {
                  final dateStr = m['date']?.toString() ?? '';
                  final count = (m['total_bookings'] ?? 0) as int;
                  final maxCount = busiestDays
                      .map((x) => (x['total_bookings'] ?? 0) as int)
                      .reduce((a, b) => a > b ? a : b);
                  final fraction = maxCount > 0 ? count / maxCount : 0.0;
                  DateTime? parsedDate;
                  try { parsedDate = DateTime.parse(dateStr); } catch (_) {}

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            parsedDate != null
                                ? DateFormat('EEE, d MMM').format(parsedDate)
                                : dateStr,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.neutral600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 8,
                              backgroundColor: AppColors.blue600.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.blue600.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 24,
                          child: Text(
                            '$count',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.blue800,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // ── Quick nav ────────────────────────────────────────────────
          const SizedBox(height: 24),
          _SectionHeader(
            icon: Icons.grid_view_rounded,
            title: 'Manage',
          ),
          const SizedBox(height: 10),
          _NavGrid(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric Card
// ─────────────────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.urgent = false,
    this.smallValue = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool urgent;
  final bool smallValue;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icon + urgent dot
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              if (urgent) ...[
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.orange700,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Value
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: smallValue ? 20 : 26,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.cyan400 : color,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Label
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.neutral500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav Grid
// ─────────────────────────────────────────────────────────────────────────────

class _NavGrid extends StatelessWidget {
  const _NavGrid();

  static const _items = [
    (
    icon: Icons.pending_actions_rounded,
    label: 'Pending',
    route: '/admin/pending',
    color: AppColors.orange700,
    ),
    (
    icon: Icons.people_rounded,
    label: 'Users',
    route: '/admin/users',
    color: AppColors.blue600,
    ),
    (
    icon: Icons.category_rounded,
    label: 'Categories',
    route: '/admin/categories',
    color: AppColors.blue600,
    ),
    (
    icon: Icons.event_note_rounded,
    label: 'Reservations',
    route: '/admin/reservations',
    color: AppColors.blue600,
    ),
    (
    icon: Icons.calendar_month_rounded,
    label: 'Schedule',
    route: '/admin/schedule',
    color: AppColors.blue600,
    ),
    (
    icon: Icons.sports_basketball_rounded,
    label: 'Balls',
    route: '/admin/balls',
    color: AppColors.orange700,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: _items
          .map((item) => _NavTile(
        icon: item.icon,
        label: item.label,
        route: item.route,
        color: item.color,
      ))
          .toList(),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String route;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.blue600),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.titleSmall.copyWith(
            color: AppColors.blue800,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 6),
          Text(
            subtitle!,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.neutral500,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}