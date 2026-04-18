import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/glass_card.dart';
import '../domain/reservations_providers.dart';
import '../data/reservation_model.dart';

class ReservationDetailsScreen extends ConsumerWidget {
  const ReservationDetailsScreen({
    super.key,
    required this.reservationId,
  });

  final String reservationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncReservation = ref.watch(reservationByIdProvider(reservationId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservation'),
        backgroundColor: isDark ? Colors.black12 : AppColors.blue600,
      ),
      body: asyncReservation.when(
        data: (r) {
          if (r == null) {
            return const Center(child: Text('Reservation not found.'));
          }

          final paymentColor = switch (r.paymentStatus) {
            'PAID' => AppColors.approved,
            'DOWNPAYMENT_PAID' => AppColors.blue600,
            'INVALID' => AppColors.rejected,
            'RECEIPT_UPLOADED' => AppColors.orange700,
            _ => AppColors.neutral600,
          };

          final canUpload =
              (r.paymentStatus == 'UNPAID' || r.paymentStatus == 'INVALID') &&
                  r.status != 'CANCELLED' &&
                  r.status != 'REJECTED' &&
                  r.paymentDueAt != null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateFormat('MMM d, y').format(r.date)}',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.blue800,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${r.startTime} – ${r.endTime}',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${r.eventType} · ${r.playersCount} players',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.neutral600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: paymentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        r.paymentStatus.replaceAll('_', ' '),
                        style: AppTypography.labelMedium.copyWith(
                          color: paymentColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (r.paymentDueAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Pay before ${DateFormat('MMM d, h:mm a').format(r.paymentDueAt!)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.orange700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receipt',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.blue800,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if ((r.paymentReceiptPath ?? '').isEmpty)
                      Text(
                        'No receipt uploaded yet.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.neutral600,
                        ),
                      )
                    else ...[
                      SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final path = r.paymentReceiptPath!;
                            final url = await ref
                                .read(reservationsRepositoryProvider)
                                .getSignedReceiptUrl(path);
                            await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Payment Receipt'),
                                content: InteractiveViewer(
                                  child: Image.network(url),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.receipt_long_rounded),
                          label: const Text('View receipt'),
                        ),
                      ),
                    ],

                    if (canUpload) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () => _uploadReceipt(ref, context, r),
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Upload receipt'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Timeline',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.blue800,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          // Reuse the same UI used elsewhere (player timeline).
                          final rows = await Supabase.instance.client
                              .from('reservation_history')
                              .select(
                                'changed_at, old_status, new_status, notes',
                              )
                              .eq('reservation_id', r.id)
                              .order('changed_at', ascending: false);
                          final history = (rows as List)
                              .cast<Map<String, dynamic>>();
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
                                        separatorBuilder: (_, __) =>
                                            const Divider(height: 12),
                                        itemBuilder: (_, i) {
                                          final h = history[i];
                                          final changedAt = DateTime.tryParse(
                                            h['changed_at']?.toString() ?? '',
                                          );
                                          final ts = changedAt == null
                                              ? ''
                                              : DateFormat(
                                                      'MMM d, y · h:mm a')
                                                  .format(changedAt);
                                          final oldStatus =
                                              h['old_status']?.toString();
                                          final newStatus =
                                              h['new_status']?.toString();
                                          final notes =
                                              h['notes']?.toString() ?? '';
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(ts,
                                                  style:
                                                      AppTypography.labelSmall),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${oldStatus ?? '—'} → ${newStatus ?? '—'}',
                                                style: AppTypography.bodySmall
                                                    .copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (notes.isNotEmpty)
                                                Text(notes,
                                                    style:
                                                        AppTypography.bodySmall),
                                            ],
                                          );
                                        },
                                      ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Close'),
                                )
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.history_rounded),
                        label: const Text('View timeline'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Failed to load reservation: $e',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Future<void> _uploadReceipt(
    WidgetRef ref,
    BuildContext context,
    Reservation r,
  ) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (picked == null) return;
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
    await ref.read(reservationsRepositoryProvider).uploadPaymentReceipt(
          reservationId: r.id,
          fileBytes: bytes,
          fileExtension: ext,
          contentType: contentType,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt uploaded. Waiting for admin review.'),
        ),
      );
    }
    ref.invalidate(reservationByIdProvider(r.id));
  }
}

