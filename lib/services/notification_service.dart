import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/notification_sound.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _tapController = StreamController<Map<String, dynamic>>.broadcast();
  final _pendingTaps = <Map<String, dynamic>>[];
  StreamSubscription<String>? _tokenRefreshSubscription;

  Stream<Map<String, dynamic>> get notificationTaps => _tapController.stream;

  Future<void> configure() async {
    await _requestPermission();
    await _initLocalNotifications();
    await _createAndroidChannels();

    FirebaseMessaging.onMessage.listen(_showForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _emitTap(message.data);
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _emitTap(initial.data);
    }
  }

  List<Map<String, dynamic>> takePendingTaps() {
    final copy = List<Map<String, dynamic>>.from(_pendingTaps);
    _pendingTaps.clear();
    return copy;
  }

  Future<void> syncTokenForUser(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(uid, token);
      }
    } catch (_) {}

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
      _saveToken(uid, newToken);
    });
  }

  Future<void> _requestPermission() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (_) {}

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            _emitTap(decoded);
          } else if (decoded is Map) {
            _emitTap(Map<String, dynamic>.from(decoded));
          } else {
            _emitTap({'payload': payload});
          }
        } catch (_) {
          _emitTap({'payload': payload});
        }
      },
    );
  }

  Future<void> _createAndroidChannels() async {
    if (!Platform.isAndroid) return;

    final android = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    for (final sound in BeHonestNotificationSound.all) {
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          sound.androidChannelId,
          sound.label,
          description: sound.description,
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(sound.androidRawResourceName),
        ),
      );
    }
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final sound = BeHonestNotificationSound.byKey(message.data['soundKey']);
    final title = message.notification?.title ?? 'Be Honest time 📸';
    final body = message.notification?.body ?? '今の旅の空気を撮ろう';

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          sound.androidChannelId,
          sound.label,
          channelDescription: sound.description,
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound(sound.androidRawResourceName),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: sound.iosSoundFile,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _emitTap(Map<String, dynamic> data) {
    if (_tapController.hasListener) {
      _tapController.add(data);
    } else {
      _pendingTaps.add(data);
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    final tokenDocId = base64Url.encode(utf8.encode(token)).replaceAll('=', '');
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tokens')
        .doc(tokenDocId)
        .set({
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
