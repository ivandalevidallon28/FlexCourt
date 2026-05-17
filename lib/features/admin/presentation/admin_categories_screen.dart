import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../categories/data/category_model.dart';
import '../../categories/domain/categories_providers.dart';

class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  ConsumerState<AdminCategoriesScreen> createState() =>
      _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState
    extends ConsumerState<AdminCategoriesScreen> {
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
      final repo = ref.read(categoriesRepositoryProvider);
      _channel = repo.subscribeToCategoriesChanges(() {
        ref.invalidate(categoriesListProvider);
      });
    }

    final categoriesAsync = ref.watch(categoriesListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Categories',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_rounded, color: Colors.white),
            tooltip: 'Add category',
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
        child: categoriesAsync.when(
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
                      const Icon(Icons.category_rounded,
                          size: 18, color: AppColors.blue600),
                      const SizedBox(width: 8),
                      Text(
                        '${list.length} categor${list.length == 1 ? 'y' : 'ies'}',
                        style: AppTypography.titleSmall
                            .copyWith(color: AppColors.blue800),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showEditDialog(),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add category'),
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
                    itemBuilder: (_, index) => _CategoryCard(
                      category: list[index],
                      index: index,
                      onEdit: () => _showEditDialog(category: list[index]),
                      onDelete: () => _confirmDeleteCategory(list[index]),
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
      floatingActionButton: categoriesAsync.valueOrNull?.isNotEmpty == true
          ? FloatingActionButton(
        onPressed: () => _showEditDialog(),
        backgroundColor: AppColors.blue600,
        tooltip: 'Add category',
        child: const Icon(Icons.add_rounded, color: Colors.white),
      )
          : null,
    );
  }

  // ── Edit / Create dialog ──────────────────────────────────────────────────

  Future<void> _showEditDialog({Category? category}) async {
    final isEdit = category != null;
    final nameCtrl = TextEditingController(text: category?.name ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isEdit ? Icons.edit_rounded : Icons.add_circle_rounded,
              size: 20,
              color: AppColors.blue600,
            ),
            const SizedBox(width: 8),
            Text(isEdit ? 'Edit Category' : 'Add Category'),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Category name',
                hintText: 'e.g. Basketball, Volleyball',
                prefixIcon:
                const Icon(Icons.category_rounded, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  BorderSide(color: AppColors.neutral300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.blue600, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
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
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Category name cannot be empty.')),
                );
                return;
              }
              if (isEdit && name == category!.name) {
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
              final confirmed = await ConfirmDialog.show(
                ctx,
                title: isEdit ? 'Save changes?' : 'Add this category?',
                message: isEdit
                    ? 'Category name will be updated.'
                    : 'This category will appear in the reservation form.',
                confirmLabel: 'Yes, save',
                cancelLabel: 'Cancel',
                icon: isEdit
                    ? Icons.save_outlined
                    : Icons.add_circle_outline,
              );
              if (!confirmed || !ctx.mounted) return;
              final repo = ref.read(categoriesRepositoryProvider);
              if (!isEdit) {
                await repo.createCategory(name);
              } else {
                await repo.updateCategory(category!.id, name);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidate(categoriesListProvider);
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

  Future<void> _confirmDeleteCategory(Category category) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Delete "${category.name}"?',
      message:
      'This category will be removed. Reservations using it may show no category.',
      confirmLabel: 'Yes, delete',
      cancelLabel: 'Cancel',
      isDanger: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!ok || !mounted) return;
    await ref.read(categoriesRepositoryProvider).deleteCategory(category.id);
    ref.invalidate(categoriesListProvider);
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
          icon: Icons.category_rounded,
          title: 'No categories yet',
          subtitle:
          'Add categories like Basketball or Volleyball to appear in the reservation form.',
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Category'),
          style: ElevatedButton.styleFrom(
            padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Card
// ─────────────────────────────────────────────────────────────────────────────

// Cycles through accent colors to make the list visually distinct
const _kAccentColors = [
  AppColors.blue600,
  AppColors.orange700,
  Color(0xFF7C3AED), // violet
  Color(0xFF059669), // emerald
  Color(0xFFDB2777), // pink
  Color(0xFF0284C7), // sky
];

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  final Category category;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _kAccentColors[index % _kAccentColors.length];
    final initial =
    category.name.isNotEmpty ? category.name[0].toUpperCase() : '?';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // ── Avatar ──────────────────────────────────────────────────
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // ── Name ─────────────────────────────────────────────────────
          Expanded(
            child: Text(
              category.name,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── Actions ──────────────────────────────────────────────────
          const SizedBox(width: 8),
          _ActionIconButton(
            icon: Icons.edit_rounded,
            color: AppColors.blue600,
            tooltip: 'Edit',
            onTap: onEdit,
          ),
          const SizedBox(width: 6),
          _ActionIconButton(
            icon: Icons.delete_rounded,
            color: AppColors.rejected,
            tooltip: 'Delete',
            onTap: onDelete,
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
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}