import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/utils/error_handling.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../data/ball_model.dart';
import '../domain/balls_providers.dart';
import 'widgets/ball_status_chip.dart';

class AdminBallsScreen extends ConsumerStatefulWidget {
  const AdminBallsScreen({super.key});

  @override
  ConsumerState<AdminBallsScreen> createState() => _AdminBallsScreenState();
}

class _AdminBallsScreenState extends ConsumerState<AdminBallsScreen> {
  RealtimeChannel? _ballsCh;
  RealtimeChannel? _rentalsCh;

  @override
  void dispose() {
    final c = Supabase.instance.client;
    if (_ballsCh != null) c.removeChannel(_ballsCh!);
    if (_rentalsCh != null) c.removeChannel(_rentalsCh!);
    super.dispose();
  }

  void _invalidate() {
    ref.invalidate(ballsListProvider);
    ref.invalidate(adminBallRentalsRecentProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (_ballsCh == null) {
      final repo = ref.read(ballsRepositoryProvider);
      _ballsCh = repo.subscribeToBallsChanges(_invalidate);
      _rentalsCh = repo.subscribeToBallRentalsChanges(_invalidate);
    }

    final ballsAsync = ref.watch(ballsListProvider);
    final rentalsAsync = ref.watch(adminBallRentalsRecentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Ball inventory',
        actions: [
          IconButton(
            icon:
                const Icon(Icons.add_circle_rounded, color: Colors.white),
            tooltip: 'Add ball',
            onPressed: () => _showAddBallDialog(),
          ),
          const AppBarThemeToggle(),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.surfaceGradientDark
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE0F2FE),
                    Color(0xFFF0F9FF),
                    Color(0xFFE0F2FE),
                  ],
                ),
        ),
        child: RefreshIndicator(
          onRefresh: () async => _invalidate(),
          color: AppColors.blue600,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Add or remove balls and override status if a ball is misplaced.',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.neutral600),
                  ),
                ),
              ),
              ballsAsync.when(
                data: (balls) => SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final ball = balls[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AdminBallCard(
                            ball: ball,
                            onDelete: () => _confirmDelete(ball),
                            onStatusChanged: (s) =>
                                _setBallStatus(ball, s),
                          ),
                        );
                      },
                      childCount: balls.length,
                    ),
                  ),
                ),
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(e.toString(),
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.error)),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded,
                          size: 18, color: AppColors.blue600),
                      const SizedBox(width: 8),
                      Text(
                        'Recent rentals',
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.blue800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              rentalsAsync.when(
                data: (rows) {
                  if (rows.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'No rental history yet.',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.neutral600),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final r = rows[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassCard(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          r.ballName ?? r.ballId,
                                          style: AppTypography.titleSmall
                                              .copyWith(
                                                  fontWeight:
                                                      FontWeight.w700),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      _RentalStatusLabel(status: r.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${DateFormat('MMM d, y · h:mm a').format(r.createdAt.toLocal())}'
                                    '${r.returnedAt != null ? ' → ${DateFormat('h:mm a').format(r.returnedAt!.toLocal())}' : ''}',
                                    style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.neutral600,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: rows.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: SizedBox()),
                error: (_, __) =>
                    const SliverToBoxAdapter(child: SizedBox()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddBallDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.add_circle_rounded,
                size: 20, color: AppColors.blue600),
            const SizedBox(width: 8),
            const Text('Add ball'),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. Ball #4',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    try {
      await ref.read(ballsRepositoryProvider).createBall(name);
      _invalidate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $name')),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, userMessageFromException(e));
    }
  }

  Future<void> _confirmDelete(Ball ball) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Remove ball?',
      message:
          'Delete ${ball.name} from inventory? This fails if an active rental still references it.',
      confirmLabel: 'Delete',
      isDanger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(ballsRepositoryProvider).deleteBall(ball.id);
      _invalidate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${ball.name}')),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, userMessageFromException(e));
    }
  }

  Future<void> _setBallStatus(Ball ball, String status) async {
    if (ball.status == status) return;
    try {
      await ref.read(ballsRepositoryProvider).updateBallStatus(ball.id, status);
      _invalidate();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, userMessageFromException(e));
    }
  }
}

class _AdminBallCard extends StatelessWidget {
  const _AdminBallCard({
    required this.ball,
    required this.onDelete,
    required this.onStatusChanged,
  });

  final Ball ball;
  final VoidCallback onDelete;
  final void Function(String status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ball.name,
                  style: AppTypography.titleSmall
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              BallStatusChip(status: ball.status),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded,
                    color: AppColors.error.withOpacity(0.9)),
                tooltip: 'Remove',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Override status',
            style: AppTypography.labelSmall
                .copyWith(color: AppColors.neutral600),
          ),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'AVAILABLE',
                label: Text('Available'),
                icon: Icon(Icons.check_circle_outline_rounded, size: 16),
              ),
              ButtonSegment(
                value: 'IN_USE',
                label: Text('In use'),
                icon: Icon(Icons.pause_circle_outline_rounded, size: 16),
              ),
            ],
            selected: {ball.status},
            onSelectionChanged: (s) {
              if (s.isEmpty) return;
              onStatusChanged(s.first);
            },
          ),
        ],
      ),
    );
  }
}

class _RentalStatusLabel extends StatelessWidget {
  const _RentalStatusLabel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status == 'ACTIVE';
    final bg = active
        ? AppColors.orange700.withOpacity(0.12)
        : AppColors.neutral300.withOpacity(0.35);
    final fg = active ? AppColors.orange700 : AppColors.neutral600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: AppTypography.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}
