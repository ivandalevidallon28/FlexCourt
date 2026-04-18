import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../categories/data/category_model.dart';
import '../../categories/domain/categories_providers.dart';
import '../domain/admin_providers.dart';

class AdminScheduleScreen extends ConsumerStatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  ConsumerState<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends ConsumerState<AdminScheduleScreen> {
  DateTime _filterDate = DateTime.now();
  String? _filterCategoryId;
  bool _weeklyView = false;
  RealtimeChannel? _channel;

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  // ── Date nav helpers ────────────────────────────────────────────────────
  void _prevDay() => setState(() => _filterDate = _filterDate.subtract(const Duration(days: 1)));
  void _nextDay() => setState(() => _filterDate = _filterDate.add(const Duration(days: 1)));

  bool get _isToday {
    final now = DateTime.now();
    return _filterDate.year == now.year &&
        _filterDate.month == now.month &&
        _filterDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    if (_channel == null) {
      _channel = Supabase.instance.client
          .channel('admin:schedule')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'reservations',
        callback: (_) => ref.invalidate(adminScheduleProvider),
      )
          .subscribe();
    }

    final dateKey = _filterDate.toIso8601String().substring(0, 10);
    final weekStart = _filterDate.subtract(Duration(days: _filterDate.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final startKey = weekStart.toIso8601String().substring(0, 10);
    final endKey = weekEnd.toIso8601String().substring(0, 10);
    final scheduleAsync = _weeklyView
        ? ref.watch(
            adminScheduleRangeProvider((
              startDate: startKey,
              endDate: endKey,
              categoryId: _filterCategoryId,
            )),
          )
        : ref.watch(
            adminScheduleProvider((
              date: dateKey,
              categoryId: _filterCategoryId,
            )),
          );
    final categoriesAsync = ref.watch(categoriesListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const GradientAppBar(title: 'Court Schedule'),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.surfaceGradientDark
              : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F2FE), Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Filter bar ───────────────────────────────────────────────
            _FilterBar(
              filterDate: _filterDate,
              filterCategoryId: _filterCategoryId,
              categories: categoriesAsync.valueOrNull ?? const <Category>[],
              isToday: _isToday,
              isWeeklyView: _weeklyView,
              onPrevDay: _prevDay,
              onNextDay: _nextDay,
              onPickDate: _pickDate,
              onToggleView: (weekly) => setState(() => _weeklyView = weekly),
              onCategoryChanged: (v) => setState(() => _filterCategoryId = v),
              onClearCategory: () => setState(() => _filterCategoryId = null),
            ),

            // ── List ─────────────────────────────────────────────────────
            Expanded(
              child: scheduleAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.event_busy_rounded,
                      title: 'No reservations',
                      subtitle: _filterCategoryId != null
                          ? 'No reservations in this category for selected period.'
                          : 'Nothing scheduled for this period.',
                    );
                  }
                  if (_weeklyView) {
                    return _buildWeeklySchedule(list, weekStart);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final r = list[index];
                      return _ScheduleCard(
                        reservation: r,
                        onTap: () => _openReservationDetails(r),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
                        const SizedBox(height: 12),
                        Text('Something went wrong', style: AppTypography.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          e.toString(),
                          style: AppTypography.bodySmall.copyWith(color: AppColors.neutral600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _filterDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _filterDate = d);
  }

  Widget _buildWeeklySchedule(List<Map<String, dynamic>> list, DateTime weekStart) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      grouped[day.toIso8601String().substring(0, 10)] = <Map<String, dynamic>>[];
    }
    for (final row in list) {
      final date = row['date']?.toString();
      if (date != null && grouped.containsKey(date)) {
        grouped[date]!.add(row);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        for (var i = 0; i < 7; i++) ...[
          Builder(
            builder: (context) {
              final day = weekStart.add(Duration(days: i));
              final key = day.toIso8601String().substring(0, 10);
              final rows = grouped[key] ?? const <Map<String, dynamic>>[];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 8),
                    child: Text(
                      DateFormat('EEE, MMM d').format(day),
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.blue800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (rows.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.neutral300.withOpacity(0.5)),
                      ),
                      child: Text(
                        'No reservations',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.neutral600),
                      ),
                    )
                  else
                    ...rows.map(
                      (r) => _ScheduleCard(
                        reservation: r,
                        onTap: () => _openReservationDetails(r),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Future<void> _openReservationDetails(Map<String, dynamic> r) async {
    final reservationId = r['id']?.toString() ?? '';
    if (reservationId.isEmpty) return;
    final date = r['date']?.toString() ?? '';
    final startTime = r['start_time']?.toString() ?? '';
    final endTime = r['end_time']?.toString() ?? '';
    final status = r['status']?.toString() ?? '';
    final user = r['users'] as Map<String, dynamic>?;
    final court = r['courts'] as Map<String, dynamic>?;
    final category = r['categories'] as Map<String, dynamic>?;
    final statusColor = AppColors.statusColor(status);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reservation Details'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: $date'),
              Text('Time: $startTime - $endTime'),
              Text('Court: ${court?['name'] ?? 'Court'}'),
              Text('Category: ${category?['name'] ?? r['event_type'] ?? 'N/A'}'),
              Text('User: ${user?['name'] ?? 'Unknown'}'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: AppTypography.labelSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Bar
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filterDate,
    required this.filterCategoryId,
    required this.categories,
    required this.isToday,
    required this.isWeeklyView,
    required this.onPrevDay,
    required this.onNextDay,
    required this.onPickDate,
    required this.onToggleView,
    required this.onCategoryChanged,
    required this.onClearCategory,
  });

  final DateTime filterDate;
  final String? filterCategoryId;
  final List<Category> categories;
  final bool isToday;
  final bool isWeeklyView;
  final VoidCallback onPrevDay;
  final VoidCallback onNextDay;
  final VoidCallback onPickDate;
  final ValueChanged<bool> onToggleView;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onClearCategory;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark
          ? Colors.white.withOpacity(0.04)
          : Colors.white.withOpacity(0.6),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Date row with prev / next ──────────────────────────────────
          Row(
            children: [
              // Prev
              _NavButton(icon: Icons.chevron_left_rounded, onTap: onPrevDay),
              const SizedBox(width: 8),

              // Date pill (tappable)
              Expanded(
                child: GestureDetector(
                  onTap: onPickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.blue600.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.blue600.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 16, color: AppColors.blue600),
                        const SizedBox(width: 8),
                        Text(
                          isToday
                              ? 'Today · ${DateFormat('MMM d').format(filterDate)}'
                              : DateFormat('EEE, MMM d, y').format(filterDate),
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.blue800,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),
              // Next
              _NavButton(icon: Icons.chevron_right_rounded, onTap: onNextDay),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              ChoiceChip(
                label: const Text('Daily'),
                selected: !isWeeklyView,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onToggleView(false),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Weekly'),
                selected: isWeeklyView,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onToggleView(true),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Category filter chips ──────────────────────────────────────
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length + 1, // +1 for "All"
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                if (i == 0) {
                  final isSelected = filterCategoryId == null;
                  return ChoiceChip(
                    label: const Text('All'),
                    selected: isSelected,
                    visualDensity: VisualDensity.compact,
                    labelStyle: AppTypography.labelSmall.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                    onSelected: (_) => onClearCategory(),
                  );
                }
                final category = categories[i - 1];
                final isSelected = filterCategoryId == category.id;
                return ChoiceChip(
                  label: Text(category.name),
                  selected: isSelected,
                  visualDensity: VisualDensity.compact,
                  labelStyle: AppTypography.labelSmall.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                  onSelected: (_) =>
                      onCategoryChanged(isSelected ? null : category.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.blue600.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.blue600.withOpacity(0.2)),
        ),
        child: Icon(icon, size: 20, color: AppColors.blue600),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedule Card
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.reservation, required this.onTap});
  final Map<String, dynamic> reservation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final user = r['users'] as Map<String, dynamic>?;
    final court = r['courts'] as Map<String, dynamic>?;
    final category = r['categories'] as Map<String, dynamic>?;
    final status = r['status']?.toString() ?? '';
    final startTime = r['start_time']?.toString() ?? '';
    final endTime = r['end_time']?.toString() ?? '';
    final eventLabel = category?['name']?.toString() ?? r['event_type']?.toString() ?? '';
    final courtName = court?['name']?.toString() ?? 'Court';
    final userName = user?['name']?.toString() ?? 'Unknown';
    final statusColor = AppColors.statusColor(status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status bar accent ──────────────────────────────────────────
          Container(
            width: 4,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),

          // ── Time block ────────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                startTime,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.blue800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Container(width: 1, height: 10, color: AppColors.neutral300),
              const SizedBox(height: 2),
              Text(
                endTime,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.neutral500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // ── Details ───────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Court name + status badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        courtName,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: AppTypography.labelSmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // User
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 13, color: AppColors.neutral500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        userName,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.neutral600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Event type
                Row(
                  children: [
                    Icon(Icons.sports_rounded, size: 13, color: AppColors.neutral500),
                    const SizedBox(width: 4),
                    Text(
                      eventLabel,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.orange700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}