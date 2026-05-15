import 'package:flutter/material.dart';

import '../models/notification_sound.dart';
import '../models/user_profile.dart';
import '../services/trip_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key, required this.uid});

  final String uid;

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _service = TripService();
  final _nameController = TextEditingController();
  String _selectedSoundKey = 'honest_ping';
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('名前・通知音')),
      body: StreamBuilder<UserProfile>(
        stream: _service.userProfile(widget.uid),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          if (profile != null && !_initialized) {
            _initialized = true;
            _nameController.text = profile.displayName;
            _selectedSoundKey = profile.selectedSoundKey;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('友達に見える名前', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                maxLength: 24,
                decoration: const InputDecoration(
                  labelText: '名前',
                  hintText: '例: たくや',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('自分の通知音', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Moment通知が来たとき、自分の端末で鳴る音です。友達ごとに別々に選べます。'),
              const SizedBox(height: 12),
              ...BeHonestNotificationSound.all.map((sound) {
                return RadioListTile<String>(
                  value: sound.key,
                  groupValue: _selectedSoundKey,
                  title: Text(sound.label),
                  subtitle: Text(sound.description),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _selectedSoundKey = value ?? sound.key),
                );
              }),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Androidは通知チャンネル作成後に音が固定されます。'
                    'このスターターでは音ごとに別チャンネルIDを用意しています。'
                    'iOS用の音源は30秒未満にしてください。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? '保存中...' : '保存する'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.updateUserProfile(
        uid: widget.uid,
        displayName: _nameController.text,
        selectedSoundKey: _selectedSoundKey,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存しました。')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
