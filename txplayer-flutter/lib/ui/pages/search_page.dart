/// 搜索页：网易云综合（歌曲/专辑/歌手）· 歌单 · B站视频
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../api/models.dart';
import '../../state/player_controller.dart';
import '../widgets/song_row.dart';
import 'album_page.dart';
import 'artist_page.dart';

enum _Tab { netease, playlist, bili }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _textCtrl = TextEditingController();
  _Tab _tab = _Tab.netease;
  bool _loading = false;
  String _error = '';

  // netease 综合
  List<Song> _songs = [];
  int _songTotal = 0;
  List<AlbumSummary> _albums = [];
  List<ArtistSummary> _artists = [];
  // 歌单
  List<PlaylistSummary> _playlists = [];
  // bili
  List<Map<String, dynamic>> _videos = [];

  Future<void> _search() async {
    final kw = _textCtrl.text.trim();
    if (kw.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = '';
      _songs = [];
      _albums = [];
      _artists = [];
      _playlists = [];
      _videos = [];
    });
    try {
      switch (_tab) {
        case _Tab.netease:
          final r = await api.searchNetease(kw);
          setState(() {
            _songs = r['songs'] as List<Song>;
            _songTotal = r['songTotal'] as int;
            _albums = r['albums'] as List<AlbumSummary>;
            _artists = r['artists'] as List<ArtistSummary>;
          });
        case _Tab.playlist:
          final r = await api.searchPlaylists(kw);
          setState(() => _playlists = r);
        case _Tab.bili:
          final r = await api.searchBili(kw);
          setState(() => _videos = r);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标签
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Wrap(
            spacing: 8,
            children: [
              for (final (t, label) in [(_Tab.netease, '网易云'), (_Tab.playlist, '歌单'), (_Tab.bili, 'B站视频')])
                ChoiceChip(
                  label: Text(label),
                  selected: _tab == t,
                  onSelected: (_) {
                    setState(() => _tab = t);
                    if (_textCtrl.text.trim().isNotEmpty) _search();
                  },
                ),
            ],
          ),
        ),
        // 输入框
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _textCtrl,
            onSubmitted: (_) => _search(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: switch (_tab) {
                _Tab.netease => '搜索歌曲、专辑、歌手...',
                _Tab.playlist => '搜索歌单...',
                _Tab.bili => '搜索B站视频...',
              },
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: const Text('搜索', style: TextStyle(fontSize: 13)),
                      onPressed: _search,
                    ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
            child: _body(theme),
          ),
        ),
      ],
    );
  }

  Widget _body(ThemeData theme) {
    if (_error.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(child: Text(_error, style: TextStyle(color: theme.colorScheme.error))),
      );
    }
    final hasResult = _songs.isNotEmpty || _albums.isNotEmpty || _artists.isNotEmpty ||
        _playlists.isNotEmpty || _videos.isNotEmpty;
    if (!hasResult) {
      return Padding(
        padding: const EdgeInsets.all(60),
        child: Column(
          children: [
            Icon(Icons.music_note, size: 52, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 14),
            Text('输入关键词搜索，点击结果即可播放',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }
    return switch (_tab) {
      _Tab.netease => _neteaseBody(theme),
      _Tab.playlist => _playlistBody(theme),
      _Tab.bili => _biliBody(theme),
    };
  }

  Widget _sectionHeader(String title, [String? count]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if (count != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(count,
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  Widget _neteaseBody(ThemeData theme) {
    final p = context.read<PlayerController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_songs.isNotEmpty) ...[
          _sectionHeader('歌曲', '共 $_songTotal 首'),
          const SizedBox(height: 4),
          ..._songs.map((s) => SongRow(
                song: s,
                onPlay: () => p.playSong(s),
                onPlayNext: () => p.playNext(s),
                onAddQueue: () => p.addToQueue(s),
              )),
        ],
        if (_albums.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionHeader('专辑'),
          const SizedBox(height: 10),
          _cardGrid(_albums
              .map((a) => GestureDetector(
                    onTap: () => _openAlbum(a),
                    child: _AlbumCard(a: a),
                  ))
              .toList()),
        ],
        if (_artists.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionHeader('歌手'),
          const SizedBox(height: 10),
          _cardGrid(_artists
              .map((a) => GestureDetector(
                    onTap: () => _openArtist(a),
                    child: _ArtistCard(a: a),
                  ))
              .toList()),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _cardGrid(List<Widget> cards) => LayoutBuilder(
        builder: (_, c) => Wrap(
          spacing: 18,
          runSpacing: 18,
          children: cards
              .map((card) => SizedBox(width: ((c.maxWidth - 36) / 3).clamp(140.0, 190.0), child: card))
              .toList(),
        ),
      );

  void _openAlbum(AlbumSummary a) {
    Navigator.of(context).push(AlbumPage.route(
      id: a.id,
      name: a.name,
      picUrl: a.picUrl,
      artist: a.artist,
    ));
  }

  void _openArtist(ArtistSummary a) {
    Navigator.of(context).push(ArtistPage.route(
      id: a.id,
      name: a.name,
      picUrl: a.picUrl ?? a.img1v1Url ?? '',
    ));
  }

  Widget _playlistBody(ThemeData theme) {
    if (_playlists.isEmpty) {
      return Center(
        child: Text('未找到相关歌单', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('歌单', '${_playlists.length} 个'),
        const SizedBox(height: 10),
        ..._playlists.map((pl) => InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openPlaylist(pl),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    CoverBox(url: pl.coverImgUrl, size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pl.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                          Text('${pl.trackCount}首 · ${pl.playCount ?? 0}次播放 · ${pl.creator}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Future<void> _openPlaylist(PlaylistSummary pl) async {
    try {
      final songs = await api.getPlaylistSongs('${pl.id}');
      if (!mounted || songs.isEmpty) return;
      final play = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(pl.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          content: Text('共 ${songs.length} 首，播放全部歌曲？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('播放全部')),
          ],
        ),
      );
      if (play == true && mounted) {
        context.read<PlayerController>().playList(songs, 0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载歌单失败：$e')));
      }
    }
  }

  Widget _biliBody(ThemeData theme) {
    final p = context.read<PlayerController>();
    if (_videos.isEmpty) {
      return Center(
        child: Text('未找到相关视频', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('B站视频', '${_videos.length} 条'),
        const SizedBox(height: 8),
        ..._videos.map((v) => _BiliRow(
              v: v,
              onPlay: () => _playBili(v, p),
            )),
      ],
    );
  }

  Future<void> _playBili(Map<String, dynamic> v, PlayerController p) async {
    final bvid = (v['bvid'] as String?) ?? '';
    if (bvid.isEmpty) return;
    try {
      final info = await api.parseBili('https://www.bilibili.com/video/$bvid');
      if (!mounted) return;
      p.playSong(Song(
        id: -1 - (bvid.hashCode & 0x3FFFFFFF),
        name: info.title,
        artists: info.artists,
        album: '哔哩哔哩',
        duration: info.duration,
        picUrl: info.picUrl,
        source: 'bili',
        audioUrl: info.audioUrl,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('解析失败：$e')));
      }
    }
  }
}

class _AlbumCard extends StatelessWidget {
  final AlbumSummary a;
  const _AlbumCard({required this.a});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: CoverBox(url: a.picUrl, size: double.infinity, radius: 10),
        ),
        const SizedBox(height: 6),
        Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
        Text(a.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final ArtistSummary a;
  const _ArtistCard({required this.a});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: CoverBox(url: a.picUrl ?? a.img1v1Url, size: double.infinity, radius: 100),
        ),
        const SizedBox(height: 6),
        Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _BiliRow extends StatelessWidget {
  final Map<String, dynamic> v;
  final VoidCallback onPlay;
  const _BiliRow({required this.v, required this.onPlay});

  String _fmtCount(num n) => n >= 10000 ? '${(n / 10000).toStringAsFixed(1)}万' : '${n.round()}';

  String _fmtDur(num sec) {
    final s = sec.round();
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, ss = s % 60;
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}' : '$m:${ss.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = ((v['title'] as String?) ?? '').replaceAll(RegExp(r'</?em[^>]*>'), '');
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onPlay,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Stack(
              children: [
                CoverBox(url: (v['picUrl'] as String?) ?? '', size: 96, radius: 8),
                if ((v['duration'] as num? ?? 0) > 0)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(3)),
                      child: Text(_fmtDur((v['duration'] as num?) ?? 0),
                          style: const TextStyle(fontSize: 10, color: Colors.white)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('${v['artists']} · ${_fmtCount((v['playCount'] as num?) ?? 0)}次播放',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.play_circle_outline, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
