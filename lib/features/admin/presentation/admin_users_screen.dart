import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../domain/admin_providers.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
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
      _channel = Supabase.instance.client
          .channel('admin:users')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'users',
        callback: (_) => ref.invalidate(adminUsersListProvider),
      )
          .subscribe();
    }

    final usersAsync = ref.watch(adminUsersListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const GradientAppBar(title: 'Users'),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.surfaceGradientDark
              : AppColors.surfaceGradientLight,
        ),
        child: usersAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                icon: Icons.people_outline_rounded,
                title: 'No users yet',
                subtitle: 'Registered users will appear here.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Summary bar ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.people_rounded, size: 18, color: AppColors.blue600),
                      const SizedBox(width: 8),
                      Text(
                        '${list.length} user${list.length == 1 ? '' : 's'}',
                        style: AppTypography.titleSmall.copyWith(color: AppColors.blue800),
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
                    itemBuilder: (context, index) =>
                        _UserCard(
                          user: list[index],
                          onEdit: () => _editUser(list[index]),
                          onHistory: () => _viewHistory(list[index]),
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

  // ── Edit dialog ──────────────────────────────────────────────────────────

  Future<void> _editUser(Map<String, dynamic> user) async {
    final nameCtrl = TextEditingController(text: user['name']?.toString() ?? '');
    final contactCtrl = TextEditingController(text: user['contact_number']?.toString() ?? '');
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.edit_rounded, size: 20, color: AppColors.blue600),
            const SizedBox(width: 8),
            const Text('Edit User'),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Name',
                prefixIcon: const Icon(Icons.person_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contactCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Contact number',
                prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newContact = contactCtrl.text.trim();
              final origName = (user['name']?.toString() ?? '').trim();
              final origContact = (user['contact_number']?.toString() ?? '').trim();
              if (newName == origName && newContact == origContact) {
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
                title: 'Save changes?',
                message: 'Name and contact number will be updated.',
                confirmLabel: 'Yes, save',
                cancelLabel: 'Cancel',
                icon: Icons.person_outline_rounded,
              );
              if (!confirmed || !ctx.mounted) return;
              await Supabase.instance.client.from('users').update({
                'name': newName,
                'contact_number': newContact,
              }).eq('id', user['id']);
              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidate(adminUsersListProvider);
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── History bottom sheet ─────────────────────────────────────────────────

  Future<void> _viewHistory(Map<String, dynamic> user) async {
    final res = await Supabase.instance.client
        .from('reservations')
        .select()
        .eq('user_id', user['id'])
        .order('date', ascending: false);
    final list = (res as List).cast<Map<String, dynamic>>();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HistorySheet(userName: user['name'] ?? '?', reservations: list),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User Card
// ─────────────────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onHistory,
  });

  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback onHistory;

  String get _name => user['name']?.toString() ?? '?';
  String get _email => user['email']?.toString() ?? '';
  String get _role => user['role']?.toString() ?? '';
  String get _initial => _name.isNotEmpty ? _name[0].toUpperCase() : '?';

  @override
  Widget build(BuildContext context) {
    final isAdmin = _role.toLowerCase() == 'admin';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Avatar ───────────────────────────────────────────────────
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.orange100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.orange700.withOpacity(0.2),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _initial,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.orange800,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ── Name / email / role ───────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _name,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAdmin
                            ? AppColors.blue600.withOpacity(0.1)
                            : AppColors.orange700.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _role,
                        style: AppTypography.labelSmall.copyWith(
                          color: isAdmin ? AppColors.blue600 : AppColors.orange700,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _email,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.neutral600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // ── Actions ───────────────────────────────────────────────────
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
                icon: Icons.history_rounded,
                color: AppColors.orange700,
                tooltip: 'History',
                onTap: onHistory,
              ),
            ],
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

// ─────────────────────────────────────────────────────────────────────────────
// History Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({
    required this.userName,
    required this.reservations,
  });

  final String userName;
  final List<Map<String, dynamic>> reservations;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceCardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewPadding.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Drag handle ─────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.neutral300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.orange700.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: AppColors.orange700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reservation History',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      userName,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.neutral600,
                      ),
                    ),
                  ],
                ),
              ),
              // Count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.blue600.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${reservations.length}',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.blue600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── List ────────────────────────────────────────────────────
          if (reservations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.event_busy_rounded, size: 36, color: AppColors.neutral400),
                  const SizedBox(height: 8),
                  Text(
                    'No reservations found',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: reservations.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = reservations[i];
                  final status = r['status']?.toString() ?? '';
                  final statusColor = AppColors.statusColor(status);
                  final date = r['date']?.toString() ?? '';
                  final start = r['start_time']?.toString() ?? '';
                  final end = r['end_time']?.toString() ?? '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        // Date block
                        Container(
                          width: 44,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.blue600.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _shortMonth(date),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.blue600,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                _dayNum(date),
                                style: TextStyle(
                                  fontSize: 18,
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
                                '$start – $end',
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  status,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _shortMonth(String date) {
    try {
      final d = DateTime.parse(date);
      return DateFormat('MMM').format(d).toUpperCase();
    } catch (_) {
      return date.length >= 7 ? date.substring(5, 7) : '??';
    }
  }

  String _dayNum(String date) {
    try {
      return DateTime.parse(date).day.toString();
    } catch (_) {
      return date.length >= 10 ? date.substring(8, 10) : '?';
    }
  }
}