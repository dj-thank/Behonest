import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/be_honest_post.dart';
import '../models/moment.dart';
import '../models/trip.dart';
import '../services/trip_service.dart';
import '../widgets/countdown_label.dart';
import '../widgets/loading_view.dart';
import 'capture_screen.dart';
import 'profile_settings_screen.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({
    super.key,
    required this.uid,
    required this.tripId,
    this.initialTrip,
    this.initialMomentId,
  });

  final String uid;
  final String tripId;
  final Trip? initialTrip;
  final String? initialMomentId;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final _service = TripService();
  bool _startingMoment = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trip?>(
      stream: _service.tripStream(widget.tripId),
      initialData: widget.initialTrip,
      builder: (context, tripSnapshot) {
        final trip = tripSnapshot.data;
        if (trip == null) {
          return const LoadingView(label: '旅行を読み込み中...');
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(trip.name),
            actions: [
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileSettingsScreen(uid: widget.uid),
                  ),
                ),
                icon: const Icon(Icons.notifications_active_outlined),
                tooltip: '自分の通知音',
              ),
            ],
          ),
          body: StreamBuilder<List<BeMoment>>(
            stream: _service.momentsForTrip(trip.id),
            builder: (context, snapshot) {
              final moments = snapshot.data ?? const <BeMoment>[];
              final latest = _selectMoment(moments);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _TripHeader(trip: trip),
                  const SizedBox(height: 16),
                  _MomentPanel(
                    moment: latest,
                    onCapture: latest?.isActive == true
                        ? () => _openCapture(trip, latest)
                        : null,
                    onStartMoment: _startingMoment ? null : () => _startMoment(trip),
                    startingMoment: _startingMoment,
                    canStartMoment: trip.isOwner(widget.uid),
                  ),
                  const SizedBox(height: 24),
                  if (latest == null)
                    const _NoPostsYet()
                  else
                    _MomentFeedGate(
                      postsStream: _service.postsForMoment(
                        tripId: trip.id,
                        momentId: latest.id,
                      ),
                      hasPostedStream: _service.hasPosted(
                        uid: widget.uid,
                        tripId: trip.id,
                        momentId: latest.id,
                      ),
                      onCapture: latest.isActive ? () => _openCapture(trip, latest) : null,
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  BeMoment? _selectMoment(List<BeMoment> moments) {
    final preferred = widget.initialMomentId;
    if (preferred != null) {
      for (final moment in moments) {
        if (moment.id == preferred) return moment;
      }
    }
    if (moments.isEmpty) return null;
    return moments.first;
  }

  Future<void> _startMoment(Trip trip) async {
    setState(() => _startingMoment = true);
    try {
      await _service.startMomentNow(trip.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Be Honest通知を送りました。')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('通知に失敗しました: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _startingMoment = false);
    }
  }

  void _openCapture(Trip trip, BeMoment? moment) {
    if (moment == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          uid: widget.uid,
          tripId: trip.id,
          momentId: moment.id,
        ),
      ),
    );
  }
}

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy/M/d');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('招待コード', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      SelectableText(
                        trip.inviteCode,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: trip.inviteCode));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('招待コードをコピーしました。')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  tooltip: 'コピー',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('${formatter.format(trip.startDate)} - ${formatter.format(trip.endDate)}'),
            Text('メンバー: ${trip.memberIds.length}人'),
            Text('撮影時間: ${trip.captureWindowMinutes}分'),
          ],
        ),
      ),
    );
  }
}

class _MomentPanel extends StatelessWidget {
  const _MomentPanel({
    required this.moment,
    required this.onCapture,
    required this.onStartMoment,
    required this.startingMoment,
    required this.canStartMoment,
  });

  final BeMoment? moment;
  final VoidCallback? onCapture;
  final VoidCallback? onStartMoment;
  final bool startingMoment;
  final bool canStartMoment;

  @override
  Widget build(BuildContext context) {
    final active = moment?.isActive == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Moment', style: Theme.of(context).textTheme.titleLarge)),
                if (active) CountdownLabel(until: moment!.expiresAt),
              ],
            ),
            const SizedBox(height: 8),
            Text(_statusText(moment)),
            const SizedBox(height: 16),
            if (active)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('今撮る'),
                ),
              )
            else if (canStartMoment)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onStartMoment,
                  icon: const Icon(Icons.bolt),
                  label: Text(startingMoment ? '通知中...' : '今すぐBe Honest'),
                ),
              )
            else
              const Text('通知開始は旅行の作成者だけができます。'),
          ],
        ),
      ),
    );
  }

  String _statusText(BeMoment? moment) {
    if (moment == null) return 'まだMomentはありません。幹事が通知を送ると撮影タイムが始まります。';
    if (moment.isActive) return '撮影タイム中です。今の旅の空気を撮ろう。';
    if (moment.isScheduled) return '次のMomentが予約されています。';
    if (moment.hasExpired) return '直近のMomentは終了しました。';
    return 'Momentの準備中です。';
  }
}

class _MomentFeedGate extends StatelessWidget {
  const _MomentFeedGate({
    required this.postsStream,
    required this.hasPostedStream,
    required this.onCapture,
  });

  final Stream<List<BeHonestPost>> postsStream;
  final Stream<bool> hasPostedStream;
  final VoidCallback? onCapture;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: hasPostedStream,
      builder: (context, snapshot) {
        final hasPosted = snapshot.data ?? false;
        if (!hasPosted) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 12),
                  Text('投稿したら見られます', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('先に自分たちの今を撮ると、友達の投稿が開きます。', textAlign: TextAlign.center),
                  if (onCapture != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onCapture,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('撮影する'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return _PostGrid(stream: postsStream);
      },
    );
  }
}

class _PostGrid extends StatelessWidget {
  const _PostGrid({required this.stream});

  final Stream<List<BeHonestPost>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BeHonestPost>>(
      stream: stream,
      builder: (context, snapshot) {
        final posts = snapshot.data ?? const <BeHonestPost>[];
        if (posts.isEmpty) return const _NoPostsYet();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('みんなの今', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return _PostTile(post: post);
              },
            ),
          ],
        );
      },
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post});

  final BeHonestPost post;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            post.combinedImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Colors.black12,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xAA000000), Color(0x00000000)],
                ),
              ),
              child: Text(
                post.displayName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPostsYet extends StatelessWidget {
  const _NoPostsYet();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.photo_camera_back_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'まだ投稿がありません',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('Momentが始まったら友達の写真がここに並びます。'),
          ],
        ),
      ),
    );
  }
}
