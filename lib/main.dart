import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/constants/env.dart';
import 'core/router/app_router.dart';
import 'features/notifications/domain/notifications_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: FlexCourtApp()));
}

class FlexCourtApp extends ConsumerWidget {
  const FlexCourtApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final push = ref.read(pushNotificationsServiceProvider);
    push.init();
    push.attachRouter(router);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'FlexCourt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

