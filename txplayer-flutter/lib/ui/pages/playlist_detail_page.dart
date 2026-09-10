/// 歌单详情页（我的歌单 / 搜索结果进入）
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../api/models.dart';
import '../../state/player_controller.dart';
import '../widgets/song_row.dart';

class PlaylistDetailPage extends StatefulWidget {
  final int id;
  final String name;
  final String coverImgUrl;

  const PlaylistDetailPage({
    super.key,
    required this.id,
    required this.name,
    required this.coverImgUrl,
  });

  static Route<void> route({required int id, required String name, required String coverImgUrl}) =>
      MaterialPageRoute(
        builder: (_) => PlaylistDetailPage(id: id, name: name, coverImgUrl: coverImgUrl),
      );

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  List<Song>? _songs;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final songs = await api.getPlaylistSongs('${widget.id}');
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

    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 60),
        children: [
          Row(
            children: [
              CoverBox(url: widget.coverImgUrl, size: 120, radius: 12),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    if (songs != null)
                      Text('共 ${songs.length} 首', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    if (songs != null && songs.isNotEmpty)
                      FilledButton.icon(
                        onPressed: () => p.playList(songs, 0),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('播放全部'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error, style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: 16),
          if (songs == null)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ...songs.asMap().entries.map((e) => SongRow(
                  song: e.value,
                  onPlay: () => p.playList(songs, e.key),
                  onPlayNext: () => p.playNext(e.value),
                  onAddQueue: () => p.addToQueue(e.value),
                )),
        ],
      ),
    );
  }
}
