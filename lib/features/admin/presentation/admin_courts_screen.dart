import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../courts/data/court_model.dart';
import '../../courts/domain/courts_providers.dart';

class AdminCourtsScreen extends ConsumerStatefulWidget {
  const AdminCourtsScreen({super.key});

  @override
  ConsumerState<AdminCourtsScreen> createState() => _AdminCourtsScreenState();
}

class _AdminCourtsScreenState extends ConsumerState<AdminCourtsScreen> {
  RealtimeChannel? _channel;

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_channel == null) {
      final repo = ref.read(courtsRepositoryProvider);
      _channel = repo.subscribeToCourtsChanges(() {
        ref.invalidate(courtsListProvider);
      });
    }

    final courtsAsync = ref.watch(courtsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Courts',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_rounded, color: Colors.white),
            tooltip: 'Add court',
            onPressed: () => _showEditDialog(),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.surfaceGradientDark
              : AppColors.surfaceGradientLight,
        ),
        child: courtsAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return _EmptyWithAction(onAdd: () => _showEditDialog());
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Summary bar ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.stadium_rounded,
                          size: 18, color: AppColors.blue600),
                      const SizedBox(width: 8),
                      Text(
                        '${list.length} court${list.length == 1 ? '' : 's'}',
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.blue800,
                        ),
                      ),
                      const Spacer(),
                      // Inline add button
                      TextButton.icon(
                        onPressed: () => _showEditDialog(),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add court'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.blue600,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── List ─────────────────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: list.length,
                    itemBuilder: (_, index) => _CourtAdminCard(
                      court: list[index],
                      onEdit: () => _showEditDialog(court: list[index]),
                      onDelete: () => _confirmDeleteCourt(list[index]),
                    ),
                  ),
                ),
              ],
            );
          },
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
      // FAB for quick add — always reachable
      floatingActionButton: courtsAsync.valueOrNull?.isNotEmpty == true
          ? FloatingActionButton(
        onPressed: () => _showEditDialog(),
        backgroundColor: AppColors.blue600,
        tooltip: 'Add court',
        child: const Icon(Icons.add_rounded, color: Colors.white),
      )
          : null,
    );
  }

  // ── Edit / Create dialog ──────────────────────────────────────────────────

  Future<void> _showEditDialog({Court? court}) async {
    final isEdit = court != null;
    final nameCtrl = TextEditingController(text: court?.name ?? '');
    final sportCtrl = TextEditingController(text: court?.sportType ?? '');
    final descCtrl = TextEditingController(text: court?.description ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isEdit ? Icons.edit_rounded : Icons.add_circle_rounded,
              size: 20,
              color: AppColors.blue600,
            ),
            const SizedBox(width: 8),
            Text(isEdit ? 'Edit Court' : 'Add Court'),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogField(
              controller: nameCtrl,
              label: 'Court name',
              icon: Icons.stadium_rounded,
              hint: 'e.g. Main Court',
              action: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _DialogField(
              controller: sportCtrl,
              label: 'Sport type',
              icon: Icons.sports_basketball_rounded,
              hint: 'e.g. Basketball',
              action: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _DialogField(
              controller: descCtrl,
              label: 'Description',
              icon: Icons.notes_rounded,
              hint: 'Optional details',
              action: TextInputAction.done,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty ||
                  sportCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Name and sport type are required.'),
                  ),
                );
                return;
              }
              final newName = nameCtrl.text.trim();
              final newSport = sportCtrl.text.trim();
              final newDesc = descCtrl.text.trim();
              if (isEdit) {
                final sameName = newName == court!.name;
                final sameSport = newSport == court.sportType;
                final sameDesc = newDesc == (court.description ?? '');
                if (sameName && sameSport && sameDesc) {
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('No changes to save.'),
                        backgroundColor: AppColors.neutral600,
                      ),
                    );
                  }
                  return;
                }
              }
              final confirmed = await ConfirmDialog.show(
                ctx,
                title: isEdit ? 'Save changes?' : 'Add this court?',
                message: isEdit
                    ? 'Court details will be updated.'
                    : 'This court will be available for reservations.',
                confirmLabel: 'Yes, save',
                cancelLabel: 'Cancel',
                icon: isEdit
                    ? Icons.save_outlined
                    : Icons.add_circle_outline,
              );
              if (!confirmed || !ctx.mounted) return;
              final repo = ref.read(courtsRepositoryProvider);
              if (!isEdit) {
                await repo.createCourt(newName, newSport, newDesc);
              } else {
                await repo.updateCourt(court!.id, newName, newSport, newDesc);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidate(courtsListProvider);
            },
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCourt(Court court) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Delete "${court.name}"?',
      message:
      'This court will be removed. Reservations linked to it may be affected.',
      confirmLabel: 'Yes, delete',
      cancelLabel: 'Cancel',
      isDanger: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!ok || !mounted) return;
    await ref.read(courtsRepositoryProvider).deleteCourt(court.id);
    ref.invalidate(courtsListProvider);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state with CTA
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyWithAction extends StatelessWidget {
  const _EmptyWithAction({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const EmptyState(
          icon: Icons.sports_basketball_rounded,
          title: 'No courts yet',
          subtitle: 'Add your first court to get started.',
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Court'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Court Admin Card
// ─────────────────────────────────────────────────────────────────────────────

class _CourtAdminCard extends StatelessWidget {
  const _CourtAdminCard({
    required this.court,
    required this.onEdit,
    required this.onDelete,
  });

  final Court court;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static IconData _sportIcon(String sport) {
    final s = sport.toLowerCase();
    if (s.contains('basket')) return Icons.sports_basketball_rounded;
    if (s.contains('volley')) return Icons.sports_volleyball_rounded;
    if (s.contains('tennis')) return Icons.sports_tennis_rounded;
    if (s.contains('soccer') || s.contains('football'))
      return Icons.sports_soccer_rounded;
    if (s.contains('badminton')) return Icons.sports_rounded;
    if (s.contains('swim')) return Icons.pool_rounded;
    return Icons.stadium_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final icon = _sportIcon(court.sportType);
    final hasDesc =
        court.description != null && court.description!.trim().isNotEmpty;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Icon ───────────────────────────────────────────────────
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.blue600.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.blue600.withOpacity(0.2),
              ),
            ),
            child: Icon(icon, color: AppColors.blue600, size: 26),
          ),
          const SizedBox(width: 14),

          // ── Info ───────────────────────────────────────────────────
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
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
                  ),
                ),
                if (hasDesc) ...[
                  const SizedBox(height: 4),
                  Text(
                    court.description!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.neutral500,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // ── Actions ────────────────────────────────────────────────
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionIconButton(
                icon: Icons.edit_rounded,
                color: AppColors.blue600,
                tooltip: 'Edit',
                onTap: onEdit,
              ),
              const SizedBox(height: 6),
              _ActionIconButton(
                icon: Icons.delete_rounded,
                color: AppColors.rejected,
                tooltip: 'Delete',
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

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
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.action = TextInputAction.next,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final TextInputAction action;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: action,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.neutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: AppColors.blue600, width: 1.5),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}