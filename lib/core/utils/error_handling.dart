import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns a short, user-friendly message for UI. Avoids exposing raw exceptions.
String userFriendlyErrorMessage(Object error, [String? fallback]) {
  final fallbackMsg = fallback ?? 'Something went wrong. Please try again.';
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid') || msg.contains('credentials')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('email') && msg.contains('confirm')) {
      return 'Please check your email to confirm your account.';
    }
  }
  final s = error.toString().toLowerCase();
  if (s.contains('already') || s.contains('duplicate') || s.contains('unique')) {
    return 'This email is already registered. Use another or sign in.';
  }
  if (s.contains('booked') || s.contains('overlap') || s.contains('slot')) {
    return 'This time slot is already booked. Choose another.';
  }
  if (s.contains('network') || s.contains('connection') || s.contains('timeout')) {
    return 'Network error. Check your connection and try again.';
  }
  if (s.contains('not found')) {
    return 'Item not found. It may have been removed.';
  }
  return fallbackMsg;
}
