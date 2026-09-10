/// 每日推荐页（需登录）
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../api/models.dart';
import '../../state/player_controller.dart';
import '../widgets/song_row.dart';

class RecommendPage extends StatefulWidget {
  const RecommendPage({super.key});

  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  List<Song>? _songs;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _error = '');
    try {
      final songs = await api.getRecommendSongs();
      if (mounted) setState(() => _songs = songs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.read<PlayerController>();
    final songs = _songs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            children: [
              const Text('每日推荐', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (songs != null && songs.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => p.playList(songs, 0),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('播放全部'),
                ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '刷新',
                onPressed: _fetch,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$_error\n（每日推荐需要登录网易云账号）',
                style: TextStyle(color: theme.colorScheme.error)),
          ),
        Expanded(
          child: songs == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  itemCount: songs.length,
                  itemBuilder: (_, i) => SongRow(
                    song: songs[i],
                    onPlay: () => p.playList(songs, i),
                    onPlayNext: () => p.playNext(songs[i]),
                    onAddQueue: () => p.addToQueue(songs[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// 私人 FM（需登录）：拉一批歌直接播放
class FmPage extends StatefulWidget {
  const FmPage({super.key});

  @override
  State<FmPage> createState() => _FmPageState();
}

class _FmPageState extends State<FmPage> {
  List<Song>? _songs;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _error = '');
    try {
      final songs = await api.getPersonalFm();
      if (!mounted) return;
      setState(() => _songs = songs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.watch<PlayerController>();
    final songs = _songs;
    final current = p.current;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            children: [
              const Text('私人FM', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const Spacer(),
              FilledButton.icon(
                onPressed: songs == null || songs.isEmpty
                    ? null
                    : () => p.playList(songs, 0),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('播放'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await _fetch();
                  final list = _songs;
                  if (list != null && list.isNotEmpty) p.playList(list, 0);
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('换一批'),
              ),
            ],
          ),
        ),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$_error\n（私人FM需要登录网易云账号）',
                style: TextStyle(color: theme.colorScheme.error)),
          ),
        if (current != null && current.source != 'local')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                CoverBox(url: current.picUrl, size: 64, radius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(current.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(current.artists,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: songs == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  itemCount: songs.length,
                  itemBuilder: (_, i) => SongRow(
                    song: songs[i],
                    onPlay: () => p.playList(songs, i),
                    onPlayNext: () => p.playNext(songs[i]),
                    onAddQueue: () => p.addToQueue(songs[i]),
                  ),
                ),
        ),
      ],
    );
  }
}
