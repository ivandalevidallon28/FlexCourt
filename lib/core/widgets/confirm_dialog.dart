import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_design_system.dart';
import 'glass_card.dart';

/// Great-looking confirmation modal for add / update / delete / submit.
/// Returns true if user confirmed, false if cancelled.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDanger = false,
    this.icon,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDanger;
  final IconData? icon;

  static Future<bool> show(
      BuildContext context, {
        required String title,
        String? message,
        String confirmLabel = 'Confirm',
        String cancelLabel = 'Cancel',
        bool isDanger = false,
        IconData? icon,
      }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDanger: isDanger,
        icon: icon,
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDanger
        ? AppColors.rejected
        : (isDark ? AppColors.cyan400 : AppColors.blue600);
    final defaultIcon = isDanger
        ? Icons.warning_amber_rounded
        : Icons.help_outline_rounded;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          margin: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon in tinted circle ──────────────────────────────
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon ?? defaultIcon,
                  size: 32,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 16),

              // ── Title ──────────────────────────────────────────────
              Text(
                title,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.neutral900Dark
                      : AppColors.neutral900,
                ),
                textAlign: TextAlign.center,
              ),

              // ── Message ────────────────────────────────────────────
              if (message != null && message!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.neutral800Dark
                        : AppColors.neutral600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 24),

              // ── Buttons ────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(cancelLabel),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: isDanger
                              ? AppColors.rejected
                              : accentColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}