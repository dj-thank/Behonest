class BeHonestNotificationSound {
  const BeHonestNotificationSound({
    required this.key,
    required this.label,
    required this.description,
    required this.androidChannelId,
    required this.androidRawResourceName,
    required this.iosSoundFile,
  });

  final String key;
  final String label;
  final String description;
  final String androidChannelId;
  final String androidRawResourceName;
  final String iosSoundFile;

  static const honestPing = BeHonestNotificationSound(
    key: 'honest_ping',
    label: 'Honest Ping',
    description: '短くて気づきやすい標準音',
    androidChannelId: 'be_honest_honest_ping_v2',
    androidRawResourceName: 'honest_ping',
    iosSoundFile: 'honest_ping.caf',
  );

  static const travelBell = BeHonestNotificationSound(
    key: 'travel_bell',
    label: 'Travel Bell',
    description: '旅行っぽい軽めのベル',
    androidChannelId: 'be_honest_travel_bell_v2',
    androidRawResourceName: 'travel_bell',
    iosSoundFile: 'travel_bell.caf',
  );

  static const cameraPop = BeHonestNotificationSound(
    key: 'camera_pop',
    label: 'Camera Pop',
    description: '撮影タイム感のあるポップ音',
    androidChannelId: 'be_honest_camera_pop_v2',
    androidRawResourceName: 'camera_pop',
    iosSoundFile: 'camera_pop.caf',
  );

  static const all = [honestPing, travelBell, cameraPop];
  static const keys = ['honest_ping', 'travel_bell', 'camera_pop'];

  static BeHonestNotificationSound byKey(String? key) {
    return all.firstWhere(
      (sound) => sound.key == key,
      orElse: () => honestPing,
    );
  }

  static bool isValidKey(String? key) => keys.contains(key);
}
