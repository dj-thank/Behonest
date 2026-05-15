import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app/navigation.dart';
import '../services/notification_service.dart';
import '../services/trip_service.dart';
import '../widgets/loading_view.dart';
import 'home_screen.dart';
import 'trip_detail_screen.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  final _auth = FirebaseAuth.instance;
  final _tripService = TripService();
  final _syncedUsers = <String>{};
  StreamSubscription<Map<String, dynamic>>? _tapSubscription;
  String? _activeUid;

  @override
  void initState() {
    super.initState();
    unawaited(_signInIfNeeded());
    _tapSubscription = NotificationService.instance.notificationTaps.listen((data) {
      final uid = _activeUid;
      if (uid == null) return;
      _handleNotificationTap(data, uid);
    });
  }

  @override
  void dispose() {
    _tapSubscription?.cancel();
    super.dispose();
  }

  Future<void> _signInIfNeeded() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  Future<void> _syncUser(User user) async {
    if (_syncedUsers.contains(user.uid)) return;
    _syncedUsers.add(user.uid);
    await _tripService.ensureUserProfile(user.uid);
    await NotificationService.instance.syncTokenForUser(user.uid);

    for (final pending in NotificationService.instance.takePendingTaps()) {
      _handleNotificationTap(pending, user.uid);
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data, String uid) {
    final type = data['type']?.toString();
    final tripId = data['tripId']?.toString();
    final momentId = data['momentId']?.toString();
    if (type != 'moment' || tripId == null || tripId.isEmpty) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(
          uid: uid,
          tripId: tripId,
          initialMomentId: momentId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return const LoadingView(label: 'Be Honestを準備中...');
        }
        _activeUid = user.uid;
        unawaited(_syncUser(user));
        return HomeScreen(uid: user.uid);
      },
    );
  }
}
