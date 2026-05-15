import 'package:cloud_firestore/cloud_firestore.dart';

class BeMoment {
  const BeMoment({
    required this.id,
    required this.tripId,
    required this.status,
    required this.startsAt,
    required this.expiresAt,
    required this.createdBy,
  });

  final String id;
  final String tripId;
  final String status;
  final DateTime startsAt;
  final DateTime expiresAt;
  final String createdBy;

  bool get isScheduled => status == 'scheduled' && DateTime.now().isBefore(startsAt);
  bool get hasExpired => DateTime.now().isAfter(expiresAt);

  bool get isActive {
    final now = DateTime.now();
    return status == 'active' && !now.isBefore(startsAt) && now.isBefore(expiresAt);
  }

  Duration get remaining {
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return Duration.zero;
    return diff;
  }

  factory BeMoment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return BeMoment(
      id: doc.id,
      tripId: data['tripId'] as String? ?? '',
      status: data['status'] as String? ?? 'scheduled',
      startsAt: _readDate(data['startsAt']),
      expiresAt: _readDate(data['expiresAt']),
      createdBy: data['createdBy'] as String? ?? 'cloud',
    );
  }

  static DateTime _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
