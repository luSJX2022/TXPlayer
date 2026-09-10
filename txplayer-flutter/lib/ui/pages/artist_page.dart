/// 歌手页（从搜索结果进入）：头像 + 热门歌曲 + 专辑
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../api/models.dart';
import '../../state/player_controller.dart';
import '../widgets/song_row.dart';
import 'album_page.dart';

class ArtistPage extends StatefulWidget {
  final int id;
  final String name;
  final String picUrl;

  const ArtistPage({super.key, required this.id, required this.name, required this.picUrl});

  static Route<void> route({required int id, required String name, required String picUrl}) =>
      MaterialPageRoute(builder: (_) => ArtistPage(id: id, name: name, picUrl: picUrl));

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  List<Song>? _songs;
  List<AlbumSummary>? _albums;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final results = await Future.wait([
        api.getArtistSongs(widget.id),
        api.getArtistAlbums(widget.id, limit: 12),
      ]);
      if (!mounted) return;
      setState(() {
        _songs = results[0] as List<Song>;
        _albums = results[1] as List<AlbumSummary>;
      });
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
          // 头像 + 名称
          Row(
            children: [
              CoverBox(url: widget.picUrl, size: 92, radius: 999),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('歌手', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    if (songs != null && songs.isNotEmpty)
                      FilledButton.icon(
                        onPressed: () => p.playList(songs, 0),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('播放热门歌曲'),
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
          const SizedBox(height: 20),
          // 热门歌曲
          if (songs != null) ...[
            const Text('热门歌曲', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...songs.asMap().entries.map((e) => SongRow(
                  song: e.value,
                  onPlay: () => p.playList(songs, e.key),
                  onPlayNext: () => p.playNext(e.value),
                  onAddQueue: () => p.addToQueue(e.value),
                )),
          ],
          // 专辑
          if (_albums != null && _albums!.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('专辑', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _albums!
                  .map((a) => SizedBox(
                        width: 150,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.of(context).push(AlbumPage.route(
                            id: a.id,
                            name: a.name,
                            picUrl: a.picUrl,
                            artist: a.artist,
                          )),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 1,
                                child: CoverBox(url: a.picUrl, size: double.infinity, radius: 10),
                              ),
                              const SizedBox(height: 6),
                              Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${a.size ?? ''}',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
