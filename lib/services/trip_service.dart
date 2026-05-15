import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/be_honest_post.dart';
import '../models/moment.dart';
import '../models/notification_sound.dart';
import '../models/trip.dart';
import '../models/user_profile.dart';

class TripService {
  TripService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Stream<UserProfile> userProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(UserProfile.fromDoc);
  }

  Future<void> ensureUserProfile(String uid) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.set({
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    await ref.set({
      'displayName': '',
      'selectedSoundKey': 'honest_ping',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? selectedSoundKey,
  }) async {
    final data = <String, Object?>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (displayName != null) data['displayName'] = displayName.trim();
    if (selectedSoundKey != null) {
      data['selectedSoundKey'] = BeHonestNotificationSound.isValidKey(selectedSoundKey)
          ? selectedSoundKey
          : 'honest_ping';
    }
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  Stream<List<Trip>> tripsForUser(String uid) {
    return _db
        .collection('trips')
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final trips = snapshot.docs.map(Trip.fromDoc).toList();
      trips.sort((a, b) => b.startDate.compareTo(a.startDate));
      return trips;
    });
  }

  Stream<Trip?> tripStream(String tripId) {
    return _db.collection('trips').doc(tripId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Trip.fromDoc(doc);
    });
  }

  Future<Trip?> getTrip(String tripId) async {
    final doc = await _db.collection('trips').doc(tripId).get();
    if (!doc.exists) return null;
    return Trip.fromDoc(doc);
  }

  Future<String> createTrip({
    required String uid,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    int dailyMomentCount = 1,
    int captureWindowMinutes = 15,
  }) async {
    final ref = _db.collection('trips').doc();
    final inviteCode = await _generateUniqueInviteCode();
    await ref.set({
      'name': name.trim().isEmpty ? 'Be Honest Trip' : name.trim(),
      'ownerId': uid,
      'inviteCode': inviteCode,
      'memberIds': [uid],
      'active': true,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'timezone': 'Asia/Tokyo',
      'dailyMomentCount': dailyMomentCount.clamp(1, 3),
      'captureWindowMinutes': captureWindowMinutes.clamp(2, 60),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<String?> joinTripByCode({required String inviteCode}) async {
    final callable = _functions.httpsCallable('joinTrip');
    final result = await callable.call<Map<String, dynamic>>({
      'inviteCode': inviteCode.trim().toUpperCase(),
    });
    return result.data['tripId'] as String?;
  }

  Future<void> startMomentNow(String tripId) async {
    final callable = _functions.httpsCallable('startMoment');
    await callable.call({'tripId': tripId});
  }

  Stream<List<BeMoment>> momentsForTrip(String tripId) {
    return _db
        .collection('trips')
        .doc(tripId)
        .collection('moments')
        .orderBy('startsAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(BeMoment.fromDoc).toList());
  }

  Stream<BeMoment?> momentStream({required String tripId, required String momentId}) {
    return _db
        .collection('trips')
        .doc(tripId)
        .collection('moments')
        .doc(momentId)
        .snapshots()
        .map((doc) => doc.exists ? BeMoment.fromDoc(doc) : null);
  }

  Stream<List<BeHonestPost>> postsForMoment({
    required String tripId,
    required String momentId,
  }) {
    return _db
        .collection('trips')
        .doc(tripId)
        .collection('moments')
        .doc(momentId)
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(BeHonestPost.fromDoc).toList());
  }

  Stream<bool> hasPosted({
    required String uid,
    required String tripId,
    required String momentId,
  }) {
    return _db
        .collection('trips')
        .doc(tripId)
        .collection('moments')
        .doc(momentId)
        .collection('posts')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<String> _generateUniqueInviteCode() async {
    for (var attempt = 0; attempt < 5; attempt += 1) {
      final code = _generateInviteCode();
      final existing = await _db
          .collection('trips')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return code;
    }
    return _generateInviteCode();
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
