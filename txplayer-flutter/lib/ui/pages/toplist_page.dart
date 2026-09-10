/// 排行榜页：榜单列表 → 榜单详情（播放全部）
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../api/models.dart';
import '../../state/player_controller.dart';
import '../widgets/song_row.dart';

class ToplistPage extends StatefulWidget {
  const ToplistPage({super.key});

  @override
  State<ToplistPage> createState() => _ToplistPageState();
}

class _ToplistPageState extends State<ToplistPage> {
  List<Map<String, dynamic>>? _lists;
  bool _loading = false;
  String _error = '';

  // 详情
  Map<String, dynamic>? _opened;
  List<Song>? _songs;
  bool _detailLoading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final lists = await api.getToplists();
      if (mounted) setState(() => _lists = lists);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    setState(() {
      _opened = item;
      _songs = null;
      _detailLoading = true;
    });
    try {
      final songs = await api.getPlaylistSongs('${item['id']}');
      if (mounted) setState(() => _songs = songs);
    } catch (e) {
      if (mounted) {
        setState(() => _opened = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载榜单失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _detailLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_opened != null) return _detail(theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            children: [
              const Text('排行榜', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_loading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error, style: TextStyle(color: theme.colorScheme.error)),
          ),
        Expanded(
          child: _lists == null
              ? const SizedBox()
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 90),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: _lists!.length,
                  itemBuilder: (_, i) {
                    final t = _lists![i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _open(t),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Center(
                                child: CoverBox(
                                  url: t['coverImgUrl'] as String?,
                                  size: double.infinity,
                                  radius: 10,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(t['name'] as String? ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(t['updateFrequency'] as String? ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _detail(ThemeData theme) {
    final p = context.read<PlayerController>();
    final songs = _songs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 24, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _opened = null),
              ),
              Expanded(
                child: Text(_opened!['name'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              if (songs != null && songs.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => p.playList(songs, 0),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('播放全部'),
                ),
            ],
          ),
        ),
        Expanded(
          child: _detailLoading
              ? const Center(child: CircularProgressIndicator())
              : songs == null
                  ? const SizedBox()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                      itemCount: songs.length,
                      itemBuilder: (_, i) {
                        final s = songs[i];
                        return SongRow(
                          song: s,
                          onPlay: () => p.playList(songs, i),
                          onPlayNext: () => p.playNext(s),
                          onAddQueue: () => p.addToQueue(s),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
