import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/utils/error_handling.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../data/ball_model.dart';
import '../data/ball_rental_model.dart';
import '../domain/ball_rental_constants.dart';
import '../domain/balls_providers.dart';
import 'widgets/ball_status_chip.dart';

/// Lists rentable balls, active rentals, and rent / return actions.
class BallRentalListScreen extends ConsumerStatefulWidget {
  const BallRentalListScreen({super.key});

  @override
  ConsumerState<BallRentalListScreen> createState() =>
      _BallRentalListScreenState();
}

class _BallRentalListScreenState extends ConsumerState<BallRentalListScreen> {
  RealtimeChannel? _ballsCh;
  RealtimeChannel? _rentalsCh;
  bool _busy = false;

  @override
  void dispose() {
    final c = Supabase.instance.client;
    if (_ballsCh != null) c.removeChannel(_ballsCh!);
    if (_rentalsCh != null) c.removeChannel(_rentalsCh!);
    super.dispose();
  }

  void _invalidateAll() {
    ref.invalidate(ballsListProvider);
    ref.invalidate(myActiveBallRentalsProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (_ballsCh == null) {
      final repo = ref.read(ballsRepositoryProvider);
      _ballsCh = repo.subscribeToBallsChanges(_invalidateAll);
      _rentalsCh = repo.subscribeToBallRentalsChanges(_invalidateAll);
    }

    final ballsAsync = ref.watch(ballsListProvider);
    final activeAsync = ref.watch(myActiveBallRentalsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Ball rental',
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
        child: RefreshIndicator(
          onRefresh: () async => _invalidateAll(),
          color: AppColors.blue600,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '₱$kBallRentalAmountPhp per ball · unlimited time this session · paid on confirm (cash / on-site)',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.neutral600,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              activeAsync.when(
                data: (active) {
                  if (active.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: _ActiveRentalsSection(
                        rentals: active,
                        busy: _busy,
                        onReturn: _onReturn,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Could not load your rentals: $e',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.error),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Icon(Icons.sports_basketball_rounded,
                          size: 18, color: AppColors.blue600),
                      const SizedBox(width: 8),
                      Text(
                        'Balls',
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.blue800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ballsAsync.when(
                data: (balls) {
                  if (balls.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.sports_basketball_outlined,
                        title: 'No balls yet',
                        subtitle:
                            'Ask an admin to add balls to the inventory.',
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final b = balls[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _BallTile(
                              ball: b,
                              busy: _busy,
                              onRent: () => _onRent(b),
                            ),
                          );
                        },
                        childCount: balls.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onRent(Ball ball) async {
    if (!ball.isAvailable || _busy) return;

    final ok = await ConfirmDialog.show(
      context,
      title: 'Rent this ball?',
      message:
          'Rent this ball for ₱$kBallRentalAmountPhp (unlimited time)? Payment will be recorded as paid immediately (cash / on-site).',
      confirmLabel: 'Rent',
      cancelLabel: 'Cancel',
      icon: Icons.sports_basketball_rounded,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(ballsRepositoryProvider).rentBall(ball.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'You are all set — enjoy ${ball.name}! (Paid ₱$kBallRentalAmountPhp)'),
          ),
        );
      }
      _invalidateAll();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, userMessageFromException(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onReturn(BallRental rental) async {
    if (!rental.isActive || _busy) return;

    final ok = await ConfirmDialog.show(
      context,
      title: 'Return ball?',
      message:
          'Mark this rental as returned? The ball will be available for others.',
      confirmLabel: 'Return',
      icon: Icons.undo_rounded,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(ballsRepositoryProvider).returnBall(rental.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ball returned. Thanks!')),
        );
      }
      _invalidateAll();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, userMessageFromException(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ActiveRentalsSection extends StatelessWidget {
  const _ActiveRentalsSection({
    required this.rentals,
    required this.busy,
    required this.onReturn,
  });

  final List<BallRental> rentals;
  final bool busy;
  final void Function(BallRental) onReturn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.play_circle_outline_rounded,
                size: 18, color: AppColors.blue600),
            const SizedBox(width: 8),
            Text(
              'Your active rentals',
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.blue800,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...rentals.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.ballName ?? 'Ball',
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.blue600.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.blue600,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Started ${DateFormat('MMM d, y · h:mm a').format(r.createdAt.toLocal())}',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.neutral600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Paid ₱${r.amount} · unlimited session',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.neutral600),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: busy ? null : () => onReturn(r),
                    icon: const Icon(Icons.undo_rounded, size: 20),
                    label: const Text('Return ball'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.blue600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BallTile extends StatelessWidget {
  const _BallTile({
    required this.ball,
    required this.busy,
    required this.onRent,
  });

  final Ball ball;
  final bool busy;
  final VoidCallback onRent;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.blue600.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.sports_basketball_rounded,
                color: AppColors.blue600, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ball.name,
                  style: AppTypography.titleSmall
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                BallStatusChip(status: ball.status),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: (ball.isAvailable && !busy) ? onRent : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.blue600,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Rent'),
          ),
        ],
      ),
    );
  }
}
