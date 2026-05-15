import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.inviteCode,
    required this.memberIds,
    required this.active,
    required this.startDate,
    required this.endDate,
    required this.timezone,
    required this.dailyMomentCount,
    required this.captureWindowMinutes,
  });

  final String id;
  final String name;
  final String ownerId;
  final String inviteCode;
  final List<String> memberIds;
  final bool active;
  final DateTime startDate;
  final DateTime endDate;
  final String timezone;
  final int dailyMomentCount;
  final int captureWindowMinutes;

  bool get isActiveNow {
    final now = DateTime.now();
    return active && !now.isBefore(startDate) && now.isBefore(endDate);
  }

  bool isOwner(String uid) => ownerId == uid;

  factory Trip.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Trip(
      id: doc.id,
      name: data['name'] as String? ?? 'Untitled trip',
      ownerId: data['ownerId'] as String? ?? '',
      inviteCode: data['inviteCode'] as String? ?? '',
      memberIds: List<String>.from(data['memberIds'] as List? ?? const []),
      active: data['active'] as bool? ?? true,
      startDate: _readDate(data['startDate']),
      endDate: _readDate(data['endDate']),
      timezone: data['timezone'] as String? ?? 'Asia/Tokyo',
      dailyMomentCount: data['dailyMomentCount'] as int? ?? 1,
      captureWindowMinutes: data['captureWindowMinutes'] as int? ?? 15,
    );
  }

  static DateTime _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
