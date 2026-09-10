/// 歌单页：输入网易云/QQ 歌单链接或 ID → 解析 → 播放
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../state/player_controller.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  final _input = TextEditingController();
  bool _loading = false;
  String _error = '';
  bool _isQQ = false;

  Future<void> _load() async {
    final v = _input.text.trim();
    if (v.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final List<dynamic> songs = _isQQ ? await api.parseQQPlaylist(v) : await api.getPlaylistSongs(v);
      if (!mounted) return;
      if (songs.isEmpty) {
        setState(() => _error = '歌单为空或解析失败');
        return;
      }
      context.read<PlayerController>().playList(songs.cast(), 0);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已加载 ${songs.length} 首，开始播放')));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 90),
      children: [
        const Text('歌单', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('粘贴网易云或 QQ 音乐歌单链接 / ID，加载后直接播放整个歌单',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('网易云')),
            ButtonSegment(value: true, label: Text('QQ音乐')),
          ],
          selected: {_isQQ},
          onSelectionChanged: (v) => setState(() => _isQQ = v.first),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: _isQQ ? 'https://y.qq.com/n/ryqq/playlist/xxxx' : '网易云歌单链接或纯 ID',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: (_loading || _input.text.trim().isEmpty) ? null : _load,
              child: Text(_loading ? '加载中...' : '加载并播放'),
            ),
          ],
        ),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error, style: TextStyle(color: theme.colorScheme.error)),
          ),
      ],
    );
  }
}
