import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/utils/error_handling.dart';
import '../../../core/utils/slot_utils.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../auth/domain/auth_providers.dart';
import '../../categories/domain/categories_providers.dart';
import '../../categories/data/category_model.dart';
import '../../courts/domain/courts_providers.dart';
import '../../pricing/domain/pricing_providers.dart';
import '../domain/reservations_providers.dart';
import '../../courts/data/court_model.dart';
import '../../reservation_change/data/reservation_change_request_model.dart';
import '../../reservation_change/domain/reservation_change_providers.dart';
import '../../reservation_change/presentation/widgets/reservation_change_modal.dart';
import '../data/reservation_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kHorizontalPadding = 16.0;
const _kSectionSpacing = 20.0;
const _kCardRadius = 16.0;
const _kChipHeight = 32.0;
const _kWideBreakpoint = 640.0;

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class PlayerReservationsScreen extends ConsumerStatefulWidget {
  const PlayerReservationsScreen({super.key});

  @override
  ConsumerState<PlayerReservationsScreen> createState() =>
      _PlayerReservationsScreenState();
}

class _PlayerReservationsScreenState
    extends ConsumerState<PlayerReservationsScreen>
    with SingleTickerProviderStateMixin {
  // ── date helpers ──────────────────────────────────────────────────────────
  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime get _lastDay =>
      DateTime(_today.year + 1, _today.month, _today.day);

  // ── state ─────────────────────────────────────────────────────────────────
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  Court? _singleCourt;
  Category? _selectedCategory;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _eventCtrl = TextEditingController();
  final _playersCtrl = TextEditingController(text: '10');
  bool _booking = false;
  String? _error;
  String? _reservationStatusFilter;
  bool _calendarExpanded = true;

  // Tab controller for narrow layout
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _focusedDay = _today;
    _selectedDay = _today;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eventCtrl.dispose();
    _playersCtrl.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  List<int> availableEndsFor(
      List<({String start, String end})> occupied, int startHour) {
    final startStr = '${startHour.toString().padLeft(2, '0')}:00';
    return [
      for (var h = startHour + 1; h <= 23; h++)
        if (!slotOverlaps(startStr, '${h.toString().padLeft(2, '0')}:00', occupied)) h
    ];
  }

  bool _validateSlotWithOccupied(
      List<({String start, String end})> occupied) {
    if (_startTime == null || _endTime == null) return false;
    final s = _formatTime(_startTime!);
    final e = _formatTime(_endTime!);
    if (s.compareTo(e) >= 0) return false;
    return !slotOverlaps(s, e, occupied);
  }

  static const List<int> _bookingHours = [
    6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22
  ];

  static const List<String> _statusOptions = [
    'ALL', 'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', 'EXPIRED', 'ADMIN',
  ];

  Future<double?> _loadPricePreview() async {
    if (_startTime == null || _endTime == null) return null;
    final startStr = _formatTime(_startTime!);
    final endStr = _formatTime(_endTime!);
    if (startStr.compareTo(endStr) >= 0) return null;
    return ref.read(pricingServiceProvider).getBookingPrice(
          date: _selectedDay,
          startTime: startStr,
          endTime: endStr,
        );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(myReservationsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= _kWideBreakpoint;
    final profileAsync = ref.watch(currentUserProfileProvider);
    final role = profileAsync.valueOrNull?['role']?.toString().toLowerCase();
    final isAdmin = role == 'admin';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: _buildAppBar(isAdmin),
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
        child: isWide
            ? _buildWideLayout(reservationsAsync)
            : _buildNarrowLayout(reservationsAsync),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(bool isAdmin) {
    return GradientAppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'My Reservations',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: 0.3,
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            _AdminBadge(),
          ],
        ],
      ),
      actions: [
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 22),
            tooltip: 'Admin Dashboard',
            onPressed: () => context.push('/admin'),
          ),
        IconButton(
          icon: const Icon(Icons.sports_basketball_rounded, color: Colors.white, size: 22),
          tooltip: 'Ball rental',
          onPressed: () => context.push('/balls'),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_rounded, color: Colors.white, size: 22),
          tooltip: 'Notifications',
          onPressed: () => context.push('/notifications'),
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
          tooltip: 'Logout',
          onPressed: () async {
            await ref.read(authRepositoryProvider).signOut();
            if (mounted) context.go('/login');
          },
        ),
        const AppBarThemeToggle(),
      ],
    );
  }

  // ── Layouts ───────────────────────────────────────────────────────────────

  Widget _buildWideLayout(AsyncValue<List<Reservation>> reservationsAsync) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: _kHorizontalPadding,
              vertical: _kSectionSpacing,
            ),
            child: _buildBookingForm(),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: reservationsAsync.when(
            data: (res) => _buildReservationsSection(res),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _buildErrorState(e.toString()),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(AsyncValue<List<Reservation>> reservationsAsync) {
    return Column(
      children: [
        // Tab bar
        Material(
          color: Colors.transparent,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.blue600,
            labelColor: AppColors.blue600,
            unselectedLabelColor: AppColors.neutral600,
            labelStyle: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(icon: Icon(Icons.add_circle_outline_rounded, size: 20), text: 'Book'),
              Tab(icon: Icon(Icons.event_note_rounded, size: 20), text: 'My Bookings'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // ── Tab 0: Booking form ────────────────────────────────────────
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: _kHorizontalPadding,
                  vertical: _kSectionSpacing,
                ),
                child: _buildBookingForm(),
              ),
              // ── Tab 1: Reservations list ───────────────────────────────────
              reservationsAsync.when(
                data: (res) => _buildReservationsSection(res),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _buildErrorState(e.toString()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_kHorizontalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: AppTypography.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: AppTypography.bodySmall.copyWith(color: AppColors.neutral600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Booking Form
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBookingForm() {
    final courtsAsync = ref.watch(courtsListProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Section header ─────────────────────────────────────────────────
        _SectionHeader(
          icon: Icons.add_circle_rounded,
          title: 'New Reservation',
        ),
        const SizedBox(height: _kSectionSpacing),

        // ── Venue status ───────────────────────────────────────────────────
        courtsAsync.when(
          data: (courts) {
            _singleCourt ??= courts.isNotEmpty ? courts.first : null;
            if (courts.isEmpty) {
              return _InfoBanner(
                icon: Icons.info_outline_rounded,
                message: 'No venue configured. Add a court in Admin.',
                color: AppColors.neutral600,
              );
            }
            return _VenuePill(name: courts.first.name);
          },
          loading: () => const _LoadingRow(label: 'Loading venue…'),
          error: (e, _) => _InfoBanner(
            icon: Icons.error_outline_rounded,
            message: 'Error loading venue: $e',
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: 12),

        // ── Category dropdown ──────────────────────────────────────────────
        categoriesAsync.when(
          data: (categories) {
            if (categories.isEmpty) {
              if (_selectedCategory != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedCategory = null);
                });
              }
              return _InfoBanner(
                icon: Icons.category_rounded,
                message: 'No categories. Add categories in Admin.',
                color: AppColors.neutral600,
              );
            }

            Category? match;
            for (final c in categories) {
              if (c.id == _selectedCategory?.id) {
                match = c;
                break;
              }
            }
            final effectiveValue = match ?? categories.first;
            if (match == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _selectedCategory = categories.first);
              });
            }

            return DropdownButtonFormField<Category>(
              value: effectiveValue,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Category',
                prefixIcon: const Icon(Icons.category_rounded, size: 20),
                hintText: 'Basketball, Volleyball…',
                border: _inputBorder(),
                enabledBorder: _inputBorder(),
                focusedBorder: _inputBorder(focused: true),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              items: categories
                  .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c.name, overflow: TextOverflow.ellipsis),
              ))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedCategory = v;
                _startTime = null;
                _endTime = null;
                _error = null;
              }),
            );
          },
          loading: () => const _LoadingRow(label: 'Loading categories…'),
          error: (e, _) => _InfoBanner(
            icon: Icons.error_outline_rounded,
            message: 'Error loading categories: $e',
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: _kSectionSpacing),

        // ── Calendar ───────────────────────────────────────────────────────
        _buildCalendar(),
        const SizedBox(height: _kSectionSpacing),

        // ── Availability grid ──────────────────────────────────────────────
        _buildAvailabilitySection(),
        const SizedBox(height: _kSectionSpacing),

        // ── Time pickers ───────────────────────────────────────────────────
        _buildTimePickers(),
        const SizedBox(height: _kSectionSpacing),

        // ── Event details ──────────────────────────────────────────────────
        _SectionHeader(icon: Icons.info_outline_rounded, title: 'Event Details'),
        const SizedBox(height: 12),
        TextField(
          controller: _eventCtrl,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Event type',
            hintText: 'e.g. Friendly match, Tournament',
            prefixIcon: const Icon(Icons.sports_rounded, size: 20),
            border: _inputBorder(),
            enabledBorder: _inputBorder(),
            focusedBorder: _inputBorder(focused: true),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _playersCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Number of players',
            prefixIcon: const Icon(Icons.group_rounded, size: 20),
            border: _inputBorder(),
            enabledBorder: _inputBorder(),
            focusedBorder: _inputBorder(focused: true),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<double?>(
          key: ValueKey('${_selectedDay.toIso8601String()}-${_startTime?.hour}-${_endTime?.hour}'),
          future: _loadPricePreview(),
          builder: (context, snapshot) {
            if (_startTime == null || _endTime == null) return const SizedBox.shrink();
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingRow(label: 'Calculating total amount…');
            }
            if (snapshot.hasError) {
              return _InfoBanner(
                icon: Icons.info_outline_rounded,
                message: 'Could not load price preview right now.',
                color: AppColors.neutral600,
              );
            }
            final amount = snapshot.data;
            if (amount == null) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.blue600.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.blue600.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_rounded, size: 18, color: AppColors.blue600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Estimated total amount: PHP ${amount.toStringAsFixed(2)}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.blue800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // ── Error message ──────────────────────────────────────────────────
        if (_error != null) ...[
          const SizedBox(height: 10),
          _ErrorBanner(message: _error!),
        ],

        const SizedBox(height: _kSectionSpacing),

        // ── Submit button ──────────────────────────────────────────────────
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _booking ? null : _confirmCreateReservation,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            icon: _booking
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.add_circle_rounded, size: 22),
            label: Text(
              _booking ? 'Submitting…' : 'Create Reservation',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: _kSectionSpacing),
      ],
    );
  }

  OutlineInputBorder _inputBorder({bool focused = false}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: focused ? AppColors.blue600 : AppColors.neutral300,
        width: focused ? 1.5 : 1,
      ),
    );
  }

  // ── Calendar widget ───────────────────────────────────────────────────────

  Widget _buildCalendar() {
    DateTime clamp(DateTime d) {
      if (d.isBefore(_today)) return _today;
      if (d.isAfter(_lastDay)) return _lastDay;
      return DateTime(d.year, d.month, d.day);
    }

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _calendarExpanded = !_calendarExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      size: 20, color: AppColors.blue600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _calendarExpanded
                          ? 'Select date'
                          : DateFormat('EEE, MMM d, y').format(_selectedDay),
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.blue800,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _calendarExpanded ? 0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: AppColors.blue600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Calendar
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _calendarExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: TableCalendar(
              firstDay: _today,
              lastDay: _lastDay,
              focusedDay: clamp(_focusedDay),
              calendarFormat: CalendarFormat.month,
              selectedDayPredicate: (day) =>
              day.year == _selectedDay.year &&
                  day.month == _selectedDay.month &&
                  day.day == _selectedDay.day,
              enabledDayPredicate: (day) => !day.isBefore(_today),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppColors.blue600.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                todayTextStyle:
                const TextStyle(color: AppColors.blue600, fontWeight: FontWeight.w600),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.blue600,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(color: Colors.white),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                  _focusedDay = DateTime(focusedDay.year, focusedDay.month, focusedDay.day);
                  _startTime = null;
                  _endTime = null;
                  _error = null;
                });
              },
            ),
            secondChild: const SizedBox(height: 4),
          ),
        ],
      ),
    );
  }

  // ── Availability grid ─────────────────────────────────────────────────────

  Widget _buildAvailabilitySection() {
    final court = _singleCourt;
    if (court == null) return const SizedBox.shrink();

    final dateKey = _selectedDay.toIso8601String().substring(0, 10);
    final occupiedAsync =
    ref.watch(occupiedSlotsProvider((courtId: court.id, date: dateKey)));

    return occupiedAsync.when(
      data: (occupied) {
        const hours = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22];
        final bookedCount = hours.where((h) {
          final s = '${h.toString().padLeft(2, '0')}:00';
          final e = h < 23 ? '${(h + 1).toString().padLeft(2, '0')}:00' : '23:00';
          return slotOverlaps(s, e, occupied);
        }).length;
        final freeCount = hours.length - bookedCount;

        return GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.grid_view_rounded, size: 18, color: AppColors.blue600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Availability · ${DateFormat.MMMd().format(_selectedDay)}',
                      style: AppTypography.titleSmall.copyWith(color: AppColors.blue800),
                    ),
                  ),
                  // Summary chips
                  _MiniChip(label: '$freeCount free', isAvailable: true),
                  const SizedBox(width: 6),
                  _MiniChip(label: '$bookedCount booked', isAvailable: false),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: hours.map((h) {
                  final slotStart = '${h.toString().padLeft(2, '0')}:00';
                  final slotEnd = h < 23
                      ? '${(h + 1).toString().padLeft(2, '0')}:00'
                      : '23:00';
                  final isBooked = slotOverlaps(slotStart, slotEnd, occupied);
                  final isSelected = _startTime?.hour == h;

                  return GestureDetector(
                    onTap: isBooked
                        ? null
                        : () {
                      final ends = availableEndsFor(occupied, h);
                      setState(() {
                        _startTime = TimeOfDay(hour: h, minute: 0);
                        _endTime = ends.isNotEmpty
                            ? TimeOfDay(hour: ends.first, minute: 0)
                            : null;
                        _error = null;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.blue600
                            : isBooked
                            ? AppColors.rejected.withOpacity(0.12)
                            : AppColors.approved.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.blue600
                              : isBooked
                              ? AppColors.rejected.withOpacity(0.4)
                              : AppColors.approved.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        slotStart,
                        style: AppTypography.labelSmall.copyWith(
                          color: isSelected
                              ? Colors.white
                              : isBooked
                              ? AppColors.rejected
                              : AppColors.approved,
                          fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              // Legend
              Row(
                children: [
                  _LegendDot(color: AppColors.approved),
                  const SizedBox(width: 4),
                  Text('Available  ', style: AppTypography.bodySmall.copyWith(color: AppColors.neutral600, fontSize: 11)),
                  _LegendDot(color: AppColors.rejected),
                  const SizedBox(width: 4),
                  Text('Booked  ', style: AppTypography.bodySmall.copyWith(color: AppColors.neutral600, fontSize: 11)),
                  _LegendDot(color: AppColors.blue600),
                  const SizedBox(width: 4),
                  Text('Selected', style: AppTypography.bodySmall.copyWith(color: AppColors.neutral600, fontSize: 11)),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const GlassCard(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (e, _) => _InfoBanner(
        icon: Icons.error_outline_rounded,
        message: 'Could not load availability: $e',
        color: AppColors.error,
      ),
    );
  }

  // ── Time pickers ──────────────────────────────────────────────────────────

  Widget _buildTimePickers() {
    final court = _singleCourt;
    final isPast = _selectedDay.isBefore(_today);

    if (court == null || isPast) {
      return _InfoBanner(
        icon: isPast ? Icons.history_rounded : Icons.storefront_rounded,
        message: court == null
            ? 'Venue not loaded yet.'
            : 'Past date selected. Please pick a future date.',
        color: AppColors.neutral600,
      );
    }

    final dateKey = _selectedDay.toIso8601String().substring(0, 10);
    final occupiedAsync =
    ref.watch(occupiedSlotsProvider((courtId: court.id, date: dateKey)));

    return occupiedAsync.when(
      data: (occupied) {
        final availableStarts = [
          for (final h in _bookingHours)
            if (!slotOverlaps(
              '${h.toString().padLeft(2, '0')}:00',
              '${(h + 1).toString().padLeft(2, '0')}:00',
              occupied,
            ))
              h
        ];

        if (availableStarts.isEmpty) {
          return _InfoBanner(
            icon: Icons.event_busy_rounded,
            message: 'No slots available on this date. Try another day.',
            color: AppColors.rejected,
          );
        }

        final startHour = _startTime?.hour;
        final validStart =
            startHour != null && availableStarts.contains(startHour);
        final ends =
        validStart ? availableEndsFor(occupied, startHour) : <int>[];
        final validEnd = _endTime != null &&
            validStart &&
            ends.contains(_endTime!.hour);

        return GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 18, color: AppColors.blue600),
                  const SizedBox(width: 8),
                  Text('Select Time', style: AppTypography.titleSmall.copyWith(color: AppColors.blue800)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey<int?>(_startTime?.hour),
                      value: validStart ? startHour : null,
                      decoration: InputDecoration(
                        labelText: 'Start',
                        hintText: validStart ? null : 'Select start',
                        prefixIcon: const Icon(Icons.play_arrow_rounded, size: 18),
                        border: _inputBorder(),
                        enabledBorder: _inputBorder(),
                        focusedBorder: _inputBorder(focused: true),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: availableStarts
                          .map((h) => DropdownMenuItem(
                        value: h,
                        child: Text('${h.toString().padLeft(2, '0')}:00'),
                      ))
                          .toList(),
                      onChanged: (h) {
                        if (h == null) return;
                        final e = availableEndsFor(occupied, h);
                        setState(() {
                          _startTime = TimeOfDay(hour: h, minute: 0);
                          _endTime = e.isNotEmpty
                              ? TimeOfDay(hour: e.first, minute: 0)
                              : null;
                          _error = null;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 18, color: AppColors.neutral400),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey<int?>(_endTime?.hour),
                      value: validEnd ? _endTime!.hour : null,
                      decoration: InputDecoration(
                        labelText: 'End',
                        hintText: validEnd ? null : 'Select end',
                        prefixIcon: const Icon(Icons.stop_rounded, size: 18),
                        border: _inputBorder(),
                        enabledBorder: _inputBorder(),
                        focusedBorder: _inputBorder(focused: true),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: ends
                          .map((h) => DropdownMenuItem(
                        value: h,
                        child: Text('${h.toString().padLeft(2, '0')}:00'),
                      ))
                          .toList(),
                      onChanged: startHour == null
                          ? null
                          : (h) {
                        if (h == null) return;
                        setState(() {
                          _endTime = TimeOfDay(hour: h, minute: 0);
                          _error = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
              // Duration pill
              if (validStart && validEnd) ...[
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.blue600.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_endTime!.hour - _startTime!.hour} hour(s) booked',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.blue600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => _InfoBanner(
        icon: Icons.error_outline_rounded,
        message: 'Could not load slots: $e',
        color: AppColors.error,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reservations Section
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildReservationsSection(List<Reservation> list) {
    final filtered = (_reservationStatusFilter == null ||
        _reservationStatusFilter == 'ALL')
        ? list
        : list.where((r) => r.status == _reservationStatusFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              _kHorizontalPadding, _kSectionSpacing, _kHorizontalPadding, 0),
          child: Row(
            children: [
              const Icon(Icons.event_note_rounded, size: 20, color: AppColors.blue600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your Reservations',
                  style: AppTypography.titleLarge.copyWith(color: AppColors.blue800),
                ),
              ),
              Text(
                '${filtered.length}',
                style: AppTypography.titleMedium.copyWith(color: AppColors.blue600),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh',
                onPressed: () {
                  ref.invalidate(myReservationsProvider);
                  ref.invalidate(occupiedSlotsProvider);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── Status filter chips ────────────────────────────────────────────
        SizedBox(
          height: _kChipHeight + 8,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _kHorizontalPadding),
            itemCount: _statusOptions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final status = _statusOptions[i];
              final isSelected = (_reservationStatusFilter == null && status == 'ALL') ||
                  _reservationStatusFilter == status;
              return ChoiceChip(
                label: Text(
                  status == 'ALL' ? 'All' : _capitalize(status),
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) => setState(() {
                  _reservationStatusFilter = status == 'ALL' ? null : status;
                }),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // ── List ───────────────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? (list.isEmpty
              ? const EmptyState(
            icon: Icons.event_available_rounded,
            title: 'No reservations yet',
            subtitle:
            'Select a category, date & time, then tap "Create Reservation".',
          )
              : const EmptyState(
            icon: Icons.filter_list_rounded,
            title: 'No matches',
            subtitle: 'Try a different filter.',
          ))
              : _buildReservationsList(filtered),
        ),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  Widget _buildReservationsList(List<Reservation> list) {
    final pendingAsync = ref.watch(myPendingChangeRequestsProvider);
    return pendingAsync.when(
      data: (pendingRequests) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            _kHorizontalPadding, 4, _kHorizontalPadding, 24),
        itemCount: list.length,
        itemBuilder: (_, index) {
          final r = list[index];
          final request = pendingRequests
              .where((req) => req.reservationId == r.id)
              .firstOrNull;
          return _ReservationCard(
            reservation: r,
            changeRequest: request,
            onEdit: () => _editReservationDialog(r),
            onCancel: () => _confirmCancelReservation(r),
            onOpenDetails: () => context.push('/reservation/${r.id}'),
            onUploadReceipt: () => _uploadReceipt(r),
            onViewReceipt: () => _viewReceipt(r),
            onViewTimeline: () => _viewTimeline(r),
          );
        },
      ),
      loading: () => _buildSimpleList(list),
      error: (_, __) => _buildSimpleList(list),
    );
  }

  Widget _buildSimpleList(List<Reservation> list) {
    final dateFmt = DateFormat.yMMMd();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          _kHorizontalPadding, 4, _kHorizontalPadding, 24),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final r = list[i];
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          child: Text(
            '${dateFmt.format(r.date)} · ${r.startTime}–${r.endTime}',
            style: AppTypography.bodySmall,
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _confirmCreateReservation() async {
    final court = _singleCourt;
    final category = _selectedCategory;
    if (court == null ||
        category == null ||
        _startTime == null ||
        _endTime == null ||
        _eventCtrl.text.trim().isEmpty) {
      setState(() =>
      _error = 'Please fill in category, date, time, and event type.');
      return;
    }

    final dateKey = _selectedDay.toIso8601String().substring(0, 10);
    final occupied = await ref
        .read(occupiedSlotsProvider((courtId: court.id, date: dateKey)).future);
    if (!_validateSlotWithOccupied(occupied)) {
      setState(() =>
      _error = 'This slot is no longer available. Please pick another time.');
      return;
    }

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Submit reservation?',
      message:
      'Your request will be sent for approval. Youll be notified once confirmed.',
    confirmLabel: 'Yes, submit',
      cancelLabel: 'Cancel',
      icon: Icons.event_available_rounded,
    );
    if (!confirmed || !mounted) return;
    await _createReservation();
  }

  Future<void> _createReservation() async {
    final court = _singleCourt;
    final category = _selectedCategory;
    final startStr = _formatTime(_startTime!);
    final endStr = _formatTime(_endTime!);

    setState(() {
      _booking = true;
      _error = null;
    });

    try {
      final profile = await ref.read(currentUserProfileProvider.future);
      final createAsAdmin =
          profile?['role']?.toString().trim().toLowerCase() == 'admin';
      await ref.read(reservationServiceProvider).createReservation(
        courtId: court!.id,
        categoryId: category!.id,
        date: _selectedDay,
        startTime: startStr,
        endTime: endStr,
        eventType: _eventCtrl.text.trim(),
        playersCount: int.tryParse(_playersCtrl.text.trim()) ?? 1,
        createAsAdmin: createAsAdmin,
      );
      ref.invalidate(myReservationsProvider);
      ref.invalidate(occupiedSlotsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation submitted — pending approval.'),
            backgroundColor: Colors.green,
          ),
        );
        // Switch to reservations tab on narrow layout
        if (_tabController.index == 0) _tabController.animateTo(1);
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      setState(() => _error = (msg.contains('already') ||
          msg.contains('booked') ||
          msg.contains('overlap'))
          ? 'This time slot is already booked. Choose another.'
          : e.toString());
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  Future<void> _confirmCancelReservation(Reservation r) async {
    final parts = r.startTime.split(':');
    final startHour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final startMin = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final slotStart = DateTime(r.date.year, r.date.month, r.date.day, startHour, startMin);
    final now = DateTime.now();
    const twoHours = Duration(hours: 2);
    final isLateCancel = slotStart.difference(now) <= twoHours && slotStart.isAfter(now);

    final message = isLateCancel
        ? 'This reservation will be cancelled. Cancelling within 2 hours of the slot start may be subject to admin review.'
        : 'This reservation will be cancelled. The slot may become available for others.';

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Cancel reservation?',
      message: message,
      confirmLabel: 'Yes, cancel',
      cancelLabel: 'Keep it',
      isDanger: true,
      icon: Icons.cancel_outlined,
    );
    if (!confirmed || !mounted) return;
    await ref.read(reservationsRepositoryProvider).cancelReservation(r.id);
    ref.invalidate(myReservationsProvider);
    ref.invalidate(occupiedSlotsProvider);
  }

  Future<void> _uploadReceipt(Reservation r) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };

    try {
      await ref.read(reservationsRepositoryProvider).uploadPaymentReceipt(
            reservationId: r.id,
            fileBytes: bytes,
            fileExtension: ext,
            contentType: contentType,
          );
      ref.invalidate(myReservationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt uploaded. Waiting for admin review.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewReceipt(Reservation r) async {
    final path = r.paymentReceiptPath;
    if (path == null || path.isEmpty) return;
    try {
      final url = await ref.read(reservationsRepositoryProvider).getSignedReceiptUrl(path);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Payment Receipt'),
          content: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewTimeline(Reservation r) async {
    try {
      final rows = await Supabase.instance.client
          .from('reservation_history')
          .select(
              'changed_at, old_status, new_status, old_date, new_date, old_start_time, new_start_time, old_end_time, new_end_time, notes')
          .eq('reservation_id', r.id)
          .order('changed_at', ascending: false);
      if (!mounted) return;
      final history = (rows as List).cast<Map<String, dynamic>>();
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reservation Timeline'),
          content: SizedBox(
            width: 420,
            child: history.isEmpty
                ? const Text('No timeline events yet.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (_, i) {
                      final h = history[i];
                      final changedAt =
                          DateTime.tryParse(h['changed_at']?.toString() ?? '');
                      final ts = changedAt == null
                          ? ''
                          : DateFormat('MMM d, y · h:mm a').format(changedAt);
                      final oldStatus = h['old_status']?.toString();
                      final newStatus = h['new_status']?.toString();
                      final notes = h['notes']?.toString() ?? '';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ts, style: AppTypography.labelSmall),
                          const SizedBox(height: 4),
                          Text(
                            '${oldStatus ?? '—'} → ${newStatus ?? '—'}',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (notes.isNotEmpty)
                            Text(notes, style: AppTypography.bodySmall),
                        ],
                      );
                    },
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load timeline: $e')),
        );
      }
    }
  }

  Future<void> _editReservationDialog(Reservation r) async {
    final isReschedule = r.status == 'APPROVED';
    await showDialog(
      context: context,
      builder: (ctx) => _EditReservationDialogContent(
        r: r,
        ref: ref,
        isReschedule: isReschedule,
        parentContext: context,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Edit reservation dialog with state so Save is disabled when nothing changed.
class _EditReservationDialogContent extends ConsumerStatefulWidget {
  const _EditReservationDialogContent({
    required this.r,
    required this.ref,
    required this.isReschedule,
    required this.parentContext,
  });

  final Reservation r;
  final WidgetRef ref;
  final bool isReschedule;
  final BuildContext parentContext;

  static String _timeToStr(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static const _bookingHours = [
    6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22
  ];

  @override
  ConsumerState<_EditReservationDialogContent> createState() =>
      _EditReservationDialogContentState();
}

class _EditReservationDialogContentState
    extends ConsumerState<_EditReservationDialogContent> {
  static String _normTime(String t) =>
      t.length >= 5 ? t.substring(0, 5) : t;

  List<int> _availableEndsFor(
      List<({String start, String end})> occupied, int startHour) {
    final startStr = '${startHour.toString().padLeft(2, '0')}:00';
    return [
      for (var h = startHour + 1; h <= 23; h++)
        if (!slotOverlaps(
            startStr, '${h.toString().padLeft(2, '0')}:00', occupied))
          h
    ];
  }
  late final TextEditingController _eventCtrl;
  late final TextEditingController _playersCtrl;
  late DateTime _selectedDate;
  late TimeOfDay _start;
  late TimeOfDay _end;

  @override
  void initState() {
    super.initState();
    _eventCtrl = TextEditingController(text: widget.r.eventType);
    _playersCtrl = TextEditingController(text: widget.r.playersCount.toString());
    _eventCtrl.addListener(() => setState(() {}));
    _playersCtrl.addListener(() => setState(() {}));
    _selectedDate = widget.r.date;
    _start = TimeOfDay(
      hour: int.parse(widget.r.startTime.split(':')[0]),
      minute: int.parse(widget.r.startTime.split(':').length > 1
          ? widget.r.startTime.split(':')[1]
          : '0'),
    );
    _end = TimeOfDay(
      hour: int.parse(widget.r.endTime.split(':')[0]),
      minute: int.parse(widget.r.endTime.split(':').length > 1
          ? widget.r.endTime.split(':')[1]
          : '0'),
    );
  }

  @override
  void dispose() {
    _eventCtrl.dispose();
    _playersCtrl.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final dateUnchanged =
        _selectedDate.year == widget.r.date.year &&
            _selectedDate.month == widget.r.date.month &&
            _selectedDate.day == widget.r.date.day;
    final newStartStr = _EditReservationDialogContent._timeToStr(_start);
    final newEndStr = _EditReservationDialogContent._timeToStr(_end);
    final timeUnchanged =
        newStartStr == widget.r.startTime && newEndStr == widget.r.endTime;
    final newEvent = _eventCtrl.text.trim();
    final newPlayers =
        int.tryParse(_playersCtrl.text.trim()) ?? widget.r.playersCount;
    final detailsUnchanged =
        newEvent == widget.r.eventType && newPlayers == widget.r.playersCount;
    return !(dateUnchanged && timeUnchanged && detailsUnchanged);
  }

  Future<void> _onSave() async {
    final ctx = context;
    final newEvent = _eventCtrl.text.trim();
    final newPlayers =
        int.tryParse(_playersCtrl.text.trim()) ?? widget.r.playersCount;
    final newStartStr = _EditReservationDialogContent._timeToStr(_start);
    final newEndStr = _EditReservationDialogContent._timeToStr(_end);
    final confirmed = await ConfirmDialog.show(
      ctx,
      title: widget.isReschedule ? 'Submit reschedule?' : 'Save changes?',
      message: widget.isReschedule
          ? 'Your reschedule will need admin approval again.'
          : 'Reservation details will be updated.',
      confirmLabel: widget.isReschedule ? 'Yes, submit' : 'Yes, save',
      cancelLabel: 'Cancel',
      icon: Icons.save_outlined,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.ref.read(reservationServiceProvider).updateReservation(
        id: widget.r.id,
        courtId: widget.r.courtId,
        date: _selectedDate,
        startTime: newStartStr,
        endTime: newEndStr,
        eventType: newEvent,
        playersCount: newPlayers,
        currentStatus: widget.r.status,
      );
      if (mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text(widget.isReschedule
                ? 'Reschedule submitted — pending approval.'
                : 'Reservation updated.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      widget.ref.invalidate(myReservationsProvider);
      widget.ref.invalidate(occupiedSlotsProvider);
    } catch (e) {
      if (mounted) {
        final msg = e.toString().toLowerCase();
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text(
              (msg.contains('already') || msg.contains('booked'))
                  ? 'That time slot is already booked. Choose another.'
                  : e.toString(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  OutlineInputBorder _inputBorder({bool focused = false}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: focused ? AppColors.blue600 : AppColors.neutral300,
        width: focused ? 1.5 : 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final dateKey = _selectedDate.toIso8601String().substring(0, 10);
    final occupiedAsync = ref.watch(occupiedSlotsProvider(
        (courtId: widget.r.courtId, date: dateKey)));

    return AlertDialog(
      title: Text(widget.isReschedule ? 'Reschedule' : 'Edit Reservation'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EditRow(
              icon: Icons.calendar_today_rounded,
              label: DateFormat.yMMMd().format(_selectedDate),
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: _selectedDate,
                  firstDate:
                      DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _selectedDate = d);
              },
            ),
            const SizedBox(height: 12),
            occupiedAsync.when(
              data: (occupied) {
                final r = widget.r;
                final occupiedExcludingCurrent = occupied.where((o) =>
                    !(_normTime(o.start) == _normTime(r.startTime) &&
                        _normTime(o.end) == _normTime(r.endTime))).toList();
                final availableStarts = [
                  for (final h in _EditReservationDialogContent._bookingHours)
                    if (!slotOverlaps(
                      '${h.toString().padLeft(2, '0')}:00',
                      '${(h + 1).toString().padLeft(2, '0')}:00',
                      occupiedExcludingCurrent,
                    ))
                      h
                ];
                final startHour = _start.hour;
                final validStart =
                    availableStarts.isNotEmpty &&
                        availableStarts.contains(startHour);
                final ends = validStart
                    ? _availableEndsFor(occupiedExcludingCurrent, startHour)
                    : <int>[];
                final validEnd = validStart &&
                    _end.hour > startHour &&
                    ends.contains(_end.hour);

                if (availableStarts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No slots available on this date. Pick another day.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.rejected,
                      ),
                    ),
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey<int?>(_start.hour),
                        value: validStart ? startHour : null,
                        decoration: InputDecoration(
                          labelText: 'Start',
                          hintText: validStart ? null : 'Select start',
                          prefixIcon: const Icon(
                            Icons.play_arrow_rounded,
                            size: 18,
                          ),
                          border: _inputBorder(),
                          enabledBorder: _inputBorder(),
                          focusedBorder: _inputBorder(focused: true),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: availableStarts
                            .map((h) => DropdownMenuItem(
                                  value: h,
                                  child: Text(
                                      '${h.toString().padLeft(2, '0')}:00'),
                                ))
                            .toList(),
                        onChanged: (h) {
                          if (h == null) return;
                          final e =
                              _availableEndsFor(occupiedExcludingCurrent, h);
                          setState(() {
                            _start = TimeOfDay(hour: h, minute: 0);
                            _end = e.isNotEmpty
                                ? TimeOfDay(hour: e.first, minute: 0)
                                : TimeOfDay(hour: h + 1, minute: 0);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey<int?>(_end.hour),
                        value: validEnd ? _end.hour : null,
                        decoration: InputDecoration(
                          labelText: 'End',
                          hintText: validEnd ? null : 'Select end',
                          prefixIcon: const Icon(Icons.stop_rounded, size: 18),
                          border: _inputBorder(),
                          enabledBorder: _inputBorder(),
                          focusedBorder: _inputBorder(focused: true),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: ends
                            .map((h) => DropdownMenuItem(
                                  value: h,
                                  child: Text(
                                      '${h.toString().padLeft(2, '0')}:00'),
                                ))
                            .toList(),
                        onChanged: validStart
                            ? (h) {
                                if (h == null) return;
                                setState(() =>
                                    _end = TimeOfDay(hour: h, minute: 0));
                              }
                            : null,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Could not load availability. Try again.',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.rejected),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _eventCtrl,
              decoration: const InputDecoration(
                labelText: 'Event type',
                prefixIcon: Icon(Icons.sports_rounded, size: 18),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _playersCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Players count',
                prefixIcon: Icon(Icons.group_rounded, size: 18),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _hasChanges ? _onSave : null,
          child: Text(_hasChanges ? 'Save' : 'No changes'),
        ),
      ],
    );
  }
}

class _AdminBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.admin_panel_settings_rounded, size: 13, color: Colors.white),
          SizedBox(width: 4),
          Text('Admin', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.blue600),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.titleSmall.copyWith(
            color: AppColors.blue800,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.message, required this.color});
  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: AppTypography.bodySmall.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.neutral600)),
        ],
      ),
    );
  }
}

class _VenuePill extends StatelessWidget {
  const _VenuePill({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.blue600.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.blue600.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stadium_rounded, size: 14, color: AppColors.blue600),
          const SizedBox(width: 6),
          Text(
            name,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.blue600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.isAvailable});
  final String label;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final color = isAvailable ? AppColors.approved : AppColors.rejected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.neutral300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.blue600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodySmall.copyWith(color: AppColors.blue800),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reservation Card
// ─────────────────────────────────────────────────────────────────────────────

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.changeRequest,
    required this.onEdit,
    required this.onCancel,
    required this.onOpenDetails,
    required this.onUploadReceipt,
    required this.onViewReceipt,
    required this.onViewTimeline,
  });

  final Reservation reservation;
  final ReservationChangeRequest? changeRequest;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onOpenDetails;
  final VoidCallback onUploadReceipt;
  final VoidCallback onViewReceipt;
  final VoidCallback onViewTimeline;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final statusColor = AppColors.statusColor(r.status);
    final paymentColor = switch (r.paymentStatus) {
      'PAID' => AppColors.approved,
      'DOWNPAYMENT_PAID' => AppColors.blue600,
      'INVALID' => AppColors.rejected,
      'RECEIPT_UPLOADED' => AppColors.orange700,
      _ => AppColors.neutral600,
    };
    final canUpload = r.status != 'CANCELLED' && r.status != 'REJECTED';
    final hasReceipt = (r.paymentReceiptPath ?? '').isNotEmpty;
    final dueAt = r.paymentDueAt;
    final showDue = dueAt != null &&
        (r.paymentStatus == 'UNPAID' || r.paymentStatus == 'INVALID');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (changeRequest != null)
            _ChangeRequestBanner(reservation: r, request: changeRequest!),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Date & time row ─────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date block
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.blue600.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('MMM').format(r.date).toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.blue600,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            DateFormat('d').format(r.date),
                            style: TextStyle(
                              fontSize: 20,
                              color: AppColors.blue800,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r.startTime} – ${r.endTime}',
                            style: AppTypography.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${r.eventType}  ·  ${r.playersCount} players',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.neutral600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r.status,
                              style: AppTypography.labelSmall.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: paymentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r.paymentStatus.replaceAll('_', ' '),
                              style: AppTypography.labelSmall.copyWith(
                                color: paymentColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (showDue) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Pay before ${DateFormat('MMM d, h:mm a').format(dueAt)}',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.orange700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (canUpload) ...[
                      _ActionIconButton(
                        icon: Icons.upload_file_rounded,
                        color: AppColors.blue600,
                        tooltip: 'Upload GCash receipt',
                        onTap: onUploadReceipt,
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (hasReceipt) ...[
                      _ActionIconButton(
                        icon: Icons.receipt_long_rounded,
                        color: AppColors.orange700,
                        tooltip: 'View receipt',
                        onTap: onViewReceipt,
                      ),
                      const SizedBox(width: 6),
                    ],
                    _ActionIconButton(
                      icon: Icons.open_in_new_rounded,
                      color: AppColors.blue600,
                      tooltip: 'Open details',
                      onTap: onOpenDetails,
                    ),
                    const SizedBox(width: 6),
                    _ActionIconButton(
                      icon: Icons.history_rounded,
                      color: AppColors.neutral600,
                      tooltip: 'Timeline',
                      onTap: onViewTimeline,
                    ),
                    const SizedBox(width: 6),
                    const Spacer(),
                    if (r.status == 'PENDING') ...[
                      _ActionIconButton(
                        icon: Icons.edit_rounded,
                        color: AppColors.blue600,
                        tooltip: 'Edit',
                        onTap: onEdit,
                      ),
                      const SizedBox(width: 4),
                      _ActionIconButton(
                        icon: Icons.cancel_rounded,
                        color: AppColors.orange600,
                        tooltip: 'Cancel',
                        onTap: onCancel,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Change Request Banner
// ─────────────────────────────────────────────────────────────────────────────

class _ChangeRequestBanner extends ConsumerWidget {
  const _ChangeRequestBanner({
    required this.reservation,
    required this.request,
  });

  final Reservation reservation;
  final ReservationChangeRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expired =
        request.isExpired || request.expiresAt.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.blue600.withOpacity(0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(_kCardRadius)),
        border: Border.all(color: AppColors.blue600.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.blue600),
              const SizedBox(width: 6),
              Text(
                'Reschedule Proposed',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.blue800,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (expired) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.neutral300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Expired',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.neutral600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'New time: ${request.newStartTime} – ${request.newEndTime}',
            style: AppTypography.bodySmall.copyWith(color: AppColors.neutral700),
          ),
          if (!expired) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => ReservationChangeModal.show(
                    context,
                    request: request,
                    reservationDate: reservation.date,
                    onAccept: () => _accept(ref, context),
                    onReject: () => _reject(ref, context),
                  ),
                  icon: const Icon(Icons.info_outline_rounded, size: 14),
                  label: const Text('Details'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: () => _reject(ref, context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rejected,
                    side: BorderSide(color: AppColors.rejected.withOpacity(0.5)),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: () => _accept(ref, context),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _accept(WidgetRef ref, BuildContext context) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await ref.read(reservationChangeServiceProvider).acceptChangeRequest(
        changeRequestId: request.id,
        userId: uid,
        notificationId: null,
      );
      ref.invalidate(myReservationsProvider);
      ref.invalidate(myPendingChangeRequestsProvider);
      ref.invalidate(occupiedSlotsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Change accepted. Reservation updated.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyErrorMessage(e)),
              backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _reject(WidgetRef ref, BuildContext context) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await ref.read(reservationChangeServiceProvider).rejectChangeRequest(
        changeRequestId: request.id,
        userId: uid,
        notificationId: null,
      );
      ref.invalidate(myReservationsProvider);
      ref.invalidate(myPendingChangeRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Change rejected. Reservation unchanged.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyErrorMessage(e)),
              backgroundColor: Colors.red.shade700),
        );
      }
    }
  }
}