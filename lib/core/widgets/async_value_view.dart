import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_design_system.dart';
import 'error_view.dart';
import 'loading_view.dart';

/// Renders AsyncValue with consistent loading, error, and empty states.
/// Keeps UI separate from state; use for list/data screens.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.empty,
    this.isEmpty,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget Function()? loading;
  final Widget Function(Object err, StackTrace? st)? error;
  final Widget Function()? empty;
  final bool Function(T data)? isEmpty;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (d) {
        if (isEmpty != null && isEmpty!(d)) {
          return empty != null ? empty!() : const SizedBox.shrink();
        }
        return data(d);
      },
      loading: () => loading?.call() ?? const LoadingView(),
      error: (e, st) =>
      error?.call(e, st) ?? ErrorView(message: e.toString()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Default Loading View
// ─────────────────────────────────────────────────────────────────────────────

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Default Error View
// ─────────────────────────────────────────────────────────────────────────────

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: AppTypography.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.neutral600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}