import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../domain/courts_providers.dart';
import '../data/court_model.dart';

class CourtsListScreen extends ConsumerStatefulWidget {
  const CourtsListScreen({super.key});

  @override
  ConsumerState<CourtsListScreen> createState() => _CourtsListScreenState();
}

class _CourtsListScreenState extends ConsumerState<CourtsListScreen> {
  RealtimeChannel? _courtsChannel;

  @override
  void dispose() {
    if (_courtsChannel != null) {
      Supabase.instance.client.removeChannel(_courtsChannel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_courtsChannel == null) {
      final repo = ref.read(courtsRepositoryProvider);
      _courtsChannel = repo.subscribeToCourtsChanges(() {
        ref.invalidate(courtsListProvider);
      });
    }

    final courtsAsync = ref.watch(courtsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const GradientAppBar(title: 'Courts'),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.surfaceGradientDark
              : AppColors.surfaceGradientLight,
        ),
        child: courtsAsync.when(
          data: (courts) {
            if (courts.isEmpty) {
              return const EmptyState(
                icon: Icons.sports_basketball_rounded,
                title: 'No courts yet',
                subtitle: 'Courts will appear here once added by an admin.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              itemCount: courts.length,
              itemBuilder: (context, index) => _CourtCard(court: courts[index]),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Court Card
// ─────────────────────────────────────────────────────────────────────────────

class _CourtCard extends StatelessWidget {
  const _CourtCard({required this.court});
  final Court court;

  /// Maps a sport type string to a relevant icon.
  static IconData _sportIcon(String sport) {
    final s = sport.toLowerCase();
    if (s.contains('basket')) return Icons.sports_basketball_rounded;
    if (s.contains('volley')) return Icons.sports_volleyball_rounded;
    if (s.contains('tennis')) return Icons.sports_tennis_rounded;
    if (s.contains('soccer') || s.contains('football')) return Icons.sports_soccer_rounded;
    if (s.contains('badminton')) return Icons.sports_rounded;
    if (s.contains('swim')) return Icons.pool_rounded;
    return Icons.stadium_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final icon = _sportIcon(court.sportType);
    final initial = court.sportType.isNotEmpty ? court.sportType[0].toUpperCase() : '?';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // ── Sport icon avatar ──────────────────────────────────────────
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.blue600.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.blue600.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, color: AppColors.blue600, size: 26),
          ),
          const SizedBox(width: 14),

          // ── Court info ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  court.name,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Sport type pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.orange700.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    court.sportType,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.orange700,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ── Chevron ────────────────────────────────────────────────────
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.neutral400,
            size: 22,
          ),
        ],
      ),
    );
  }
}