import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationsService {
  PushNotificationsService(this._client);

  final SupabaseClient _client;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
    'courtside_default_channel',
    'CourtSide Notifications',
    description: 'General CourtSide alerts and updates',
    importance: Importance.high,
  );
  bool _initialized = false;
  bool _tapHandlersBound = false;
  bool _initialMessageHandled = false;
  GoRouter? _router;
  String? _pendingRoute;

  Future<void> init() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.requestPermission();
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await _initLocalNotifications();
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    await _syncToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => _syncToken());
    _client.auth.onAuthStateChange.listen((_) => _syncToken());
    _initialized = true;
  }

  Future<void> attachRouter(GoRouter router) async {
    _router = router;
    if (_pendingRoute != null) {
      try {
        router.go(_pendingRoute!);
      } catch (e) {
        debugPrint('[CourtSide] Pending route navigation failed: $e');
      } finally {
        _pendingRoute = null;
      }
    }
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
    final type = (message.data['type'] ?? '').toString().toUpperCase();
    final reservationId = (message.data['reservation_id'] ?? '').toString();
    final route = _routeForType(
      type,
      reservationId: reservationId.isEmpty ? null : reservationId,
    );
    _goToRoute(route);
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

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) {
          _goToRoute('/notifications');
          return;
        }
        _goToRoute(_routeForPayload(payload));
      },
    );
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_defaultChannel);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? (message.data['title']?.toString());
    final body = notification?.body ?? (message.data['message']?.toString());
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final type = (message.data['type'] ?? '').toString().toUpperCase();
    final reservationId = (message.data['reservation_id'] ?? '').toString();
    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        'courtside_default_channel',
        'CourtSide Notifications',
        channelDescription: 'General CourtSide alerts and updates',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    // Encode both fields so taps can deep-link to the correct reservation.
    final payload = reservationId.isEmpty
        ? type
        : jsonEncode({'type': type, 'reservation_id': reservationId});

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title ?? 'CourtSide',
      body ?? '',
      details,
      payload: payload,
    );
  }

  String _routeForPayload(String payload) {
    // Payload may be a legacy plain `type`, or a JSON string.
    String type = payload;
    String? reservationId;
    try {
      if (payload.startsWith('{')) {
        final decoded = jsonDecode(payload);
        type = (decoded['type'] ?? payload).toString();
        final rid = decoded['reservation_id']?.toString();
        if (rid != null && rid.isNotEmpty) reservationId = rid;
      }
    } catch (_) {
      // Fall back to legacy format.
    }

    return _routeForType(type.toUpperCase(), reservationId: reservationId);
  }

  String _routeForType(String type, {String? reservationId}) {
    final normalized = type.toUpperCase();

    // Payment-related updates should deep-link to the reservation.
    if (normalized == 'PAYMENT_INVALID' ||
        normalized == 'DOWNPAYMENT_PAID' ||
        normalized == 'PAID' ||
        normalized == 'RESERVATION_REMINDER_1H' ||
        normalized == 'RESERVATION_REMINDER_24H') {
      if (reservationId != null && reservationId.isNotEmpty) {
        return '/reservation/$reservationId';
      }
    }

    return switch (normalized) {
      'NEW_RESERVATION_REQUEST' => '/admin/pending',
      'RESCHEDULE_PENDING_ADMIN' => '/admin/pending',
      'RESERVATION_CANCELLED' => '/admin/pending',
      'CHANGE_REQUEST_ACCEPTED' => '/admin/pending',
      'CHANGE_REQUEST_REJECTED' => '/admin/pending',
      _ => '/notifications',
    };
  }

  void _goToRoute(String route) {
    final router = _router;
    if (router == null) {
      _pendingRoute = route;
      return;
    }
    try {
      router.go(route);
    } catch (e) {
      debugPrint('[CourtSide] Push route navigation failed: $e');
    }
  }
}
