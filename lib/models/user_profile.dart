import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.selectedSoundKey,
  });

  final String uid;
  final String displayName;
  final String selectedSoundKey;

  bool get hasDisplayName => displayName.trim().isNotEmpty;

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? '',
      selectedSoundKey: data['selectedSoundKey'] as String? ?? 'honest_ping',
    );
  }
}
