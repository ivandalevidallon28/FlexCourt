import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/theme_mode_provider.dart';
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  /// [String] → styled white text. [Widget] → rendered directly.
  final dynamic title;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  static const _titleStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w700,
    fontSize: 18,
    letterSpacing: 0.3,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.primaryGradientDark
            : AppColors.primaryGradientLight,
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.cyan500 : AppColors.blue600)
                .withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AppBar(
        title: title is String
            ? Text(title as String, style: _titleStyle)
            : title as Widget,
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: leading,
        actions: actions,
      ),
    );
  }
}

class AppBarThemeToggle extends ConsumerWidget {
  const AppBarThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final icon = mode == ThemeMode.dark
        ? Icons.light_mode_rounded
        : mode == ThemeMode.light
        ? Icons.dark_mode_rounded
        : (isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded);

    final tooltip = mode == ThemeMode.dark
        ? 'Light mode'
        : mode == ThemeMode.light
        ? 'System mode'
        : 'Dark mode';

    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 22),
      tooltip: tooltip,
      onPressed: () {
        ref.read(themeModeProvider.notifier).state = mode == ThemeMode.dark
            ? ThemeMode.light
            : mode == ThemeMode.light
            ? ThemeMode.system
            : ThemeMode.dark;
      },
    );
  }
}