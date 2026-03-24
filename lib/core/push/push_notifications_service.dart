import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationsService {
  PushNotificationsService(this._client);

  final SupabaseClient _client;
  bool _initialized = false;
  bool _tapHandlersBound = false;
  bool _initialMessageHandled = false;
  GoRouter? _router;

  Future<void> init() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.requestPermission();
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await _syncToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => _syncToken());
    _client.auth.onAuthStateChange.listen((_) => _syncToken());
    _initialized = true;
  }

  Future<void> attachRouter(GoRouter router) async {
    _router = router;
    if (!_tapHandlersBound) {
      FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageTap);
      _tapHandlersBound = true;
    }
    if (!_initialMessageHandled) {
      _initialMessageHandled = true;
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        await _handleRemoteMessageTap(initial);
      }
    }
  }

  Future<void> _handleRemoteMessageTap(RemoteMessage message) async {
    final router = _router;
    if (router == null) return;

    final type = (message.data['type'] ?? '').toString().toUpperCase();
    final route = switch (type) {
      'NEW_RESERVATION_REQUEST' => '/admin/pending',
      'RESCHEDULE_PENDING_ADMIN' => '/admin/pending',
      'RESERVATION_CANCELLED' => '/admin/pending',
      'CHANGE_REQUEST_ACCEPTED' => '/admin/pending',
      'CHANGE_REQUEST_REJECTED' => '/admin/pending',
      _ => '/notifications',
    };

    try {
      router.go(route);
    } catch (e) {
      debugPrint('[CourtSide] Push route navigation failed: $e');
    }
  }

  Future<void> _syncToken() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _client.from('user_push_tokens').upsert({
        'user_id': uid,
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');
    } catch (e) {
      debugPrint('[CourtSide] Push token sync failed: $e');
    }
  }
}
