import 'package:cloud_firestore/cloud_firestore.dart';

class BeHonestPost {
  const BeHonestPost({
    required this.uid,
    required this.displayName,
    required this.frontImageUrl,
    required this.backImageUrl,
    required this.combinedImageUrl,
    required this.createdAt,
    required this.createdAtClient,
  });

  final String uid;
  final String displayName;
  final String frontImageUrl;
  final String backImageUrl;
  final String combinedImageUrl;
  final DateTime createdAt;
  final DateTime createdAtClient;

  factory BeHonestPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAt = data['createdAt'];
    final createdAtClient = data['createdAtClient'];
    return BeHonestPost(
      uid: data['uid'] as String? ?? doc.id,
      displayName: data['displayName'] as String? ?? 'Friend',
      frontImageUrl: data['frontImageUrl'] as String? ?? '',
      backImageUrl: data['backImageUrl'] as String? ?? '',
      combinedImageUrl: data['combinedImageUrl'] as String? ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      createdAtClient: createdAtClient is Timestamp ? createdAtClient.toDate() : DateTime.now(),
    );
  }
}
