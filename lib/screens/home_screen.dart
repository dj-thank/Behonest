import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/trip.dart';
import '../models/user_profile.dart';
import '../services/trip_service.dart';
import 'profile_settings_screen.dart';
import 'trip_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.uid});

  final String uid;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = TripService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Be Honest'),
        actions: [
          IconButton(
            onPressed: _showJoinSheet,
            icon: const Icon(Icons.group_add),
            tooltip: '参加',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileSettingsScreen(uid: widget.uid),
              ),
            ),
            icon: const Icon(Icons.person_outline),
            tooltip: '名前・通知音',
          ),
        ],
      ),
      body: StreamBuilder<UserProfile>(
        stream: _service.userProfile(widget.uid),
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data;
          return StreamBuilder<List<Trip>>(
            stream: _service.tripsForUser(widget.uid),
            builder: (context, snapshot) {
              final trips = snapshot.data ?? const <Trip>[];
              if (snapshot.connectionState == ConnectionState.waiting && trips.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (trips.isEmpty) {
                return _EmptyState(
                  profile: profile,
                  onCreate: _showCreateSheet,
                  onJoin: _showJoinSheet,
                  onEditProfile: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileSettingsScreen(uid: widget.uid),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: trips.length + (profile?.hasDisplayName == false ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (profile?.hasDisplayName == false && index == 0) {
                    return _ProfilePrompt(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileSettingsScreen(uid: widget.uid),
                        ),
                      ),
                    );
                  }
                  final offset = profile?.hasDisplayName == false ? 1 : 0;
                  final trip = trips[index - offset];
                  return _TripCard(
                    trip: trip,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TripDetailScreen(
                          uid: widget.uid,
                          tripId: trip.id,
                          initialTrip: trip,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('旅行を作る'),
      ),
    );
  }

  Future<void> _showCreateSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateTripSheet(uid: widget.uid, service: _service),
    );
  }

  Future<void> _showJoinSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _JoinTripSheet(service: _service),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onTap});

  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('M/d');
    final statusLabel = trip.isActiveNow ? '旅行中' : '待機中';
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Chip(label: Text(statusLabel)),
                ],
              ),
              const SizedBox(height: 8),
              Text('${formatter.format(trip.startDate)} - ${formatter.format(trip.endDate)}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('メンバー ${trip.memberIds.length}人'),
                  const Spacer(),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.profile,
    required this.onCreate,
    required this.onJoin,
    required this.onEditProfile,
  });

  final UserProfile? profile;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              '旅行グループを作ろう',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '友達だけの正直写真タイムを始められます。',
              textAlign: TextAlign.center,
            ),
            if (profile?.hasDisplayName == false) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onEditProfile,
                icon: const Icon(Icons.badge_outlined),
                label: const Text('先に名前と通知音を設定'),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('新しく作る'),
            ),
            TextButton(
              onPressed: onJoin,
              child: const Text('招待コードで参加'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePrompt extends StatelessWidget {
  const _ProfilePrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: const Text('友達に見える名前を設定しよう'),
        subtitle: const Text('投稿に表示される名前と、自分の通知音を選べます。'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _CreateTripSheet extends StatefulWidget {
  const _CreateTripSheet({required this.uid, required this.service});

  final String uid;
  final TripService service;

  @override
  State<_CreateTripSheet> createState() => _CreateTripSheetState();
}

class _CreateTripSheetState extends State<_CreateTripSheet> {
  final _nameController = TextEditingController();
  int _days = 3;
  int _dailyCount = 1;
  int _captureWindow = 15;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('旅行を作る', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '旅行名',
                hintText: '例: 韓国旅行2026',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _days,
              decoration: const InputDecoration(labelText: '旅行日数'),
              items: [1, 2, 3, 4, 5, 7, 10]
                  .map((day) => DropdownMenuItem(value: day, child: Text('$day日')))
                  .toList(),
              onChanged: _loading ? null : (value) => setState(() => _days = value ?? 3),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _dailyCount,
              decoration: const InputDecoration(labelText: '1日の通知回数'),
              items: [1, 2, 3]
                  .map((count) => DropdownMenuItem(value: count, child: Text('$count回')))
                  .toList(),
              onChanged: _loading ? null : (value) => setState(() => _dailyCount = value ?? 1),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _captureWindow,
              decoration: const InputDecoration(labelText: '撮影できる時間'),
              items: [2, 5, 10, 15, 30, 60]
                  .map((minutes) => DropdownMenuItem(value: minutes, child: Text('$minutes分')))
                  .toList(),
              onChanged: _loading ? null : (value) => setState(() => _captureWindow = value ?? 15),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _create,
                child: Text(_loading ? '作成中...' : '作成する'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      await widget.service.createTrip(
        uid: widget.uid,
        name: _nameController.text,
        startDate: DateTime(now.year, now.month, now.day),
        endDate: DateTime(now.year, now.month, now.day).add(Duration(days: _days)),
        dailyMomentCount: _dailyCount,
        captureWindowMinutes: _captureWindow,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('作成に失敗しました: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _JoinTripSheet extends StatefulWidget {
  const _JoinTripSheet({required this.service});

  final TripService service;

  @override
  State<_JoinTripSheet> createState() => _JoinTripSheetState();
}

class _JoinTripSheetState extends State<_JoinTripSheet> {
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('招待コードで参加', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: '招待コード',
              border: OutlineInputBorder(),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(6),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _join,
              child: Text(_loading ? '参加中...' : '参加する'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _join() async {
    setState(() => _loading = true);
    try {
      await widget.service.joinTripByCode(inviteCode: _codeController.text);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('参加できませんでした: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
