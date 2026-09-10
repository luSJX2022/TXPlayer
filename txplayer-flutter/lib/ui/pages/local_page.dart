/// 本地音乐页：选择文件夹 → 服务端扫描 → 播放（同名 .lrc / FLAC 内嵌歌词自动接入歌词页）
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../api/models.dart';
import '../../state/player_controller.dart';
import '../widgets/song_row.dart';

const _audioExts = {'mp3', 'flac', 'm4a', 'aac', 'wav', 'ogg', 'opus', 'wma'};

class LocalPage extends StatefulWidget {
  const LocalPage({super.key});

  @override
  State<LocalPage> createState() => _LocalPageState();
}

class _LocalPageState extends State<LocalPage> {
  String _dir = '';
  List<Song> _songs = [];
  bool _loading = false;
  String _error = '';
  bool _scanned = false;

  Future<void> _pickAndScan() async {
    final dir = await FilePicker.getDirectoryPath(dialogTitle: '选择音乐文件夹');
    if (dir == null || dir.isEmpty || !mounted) return;
    setState(() {
      _loading = true;
      _error = '';
      _scanned = true;
    });
    try {
      final r = await api.scanLocal(dir);
      final files = (r['files'] as List?) ?? const [];
      final songs = <Song>[];
      for (final f in files.cast<Map<String, dynamic>>()) {
        final path = (f['path'] as String?) ?? '';
        final name = (f['name'] as String?) ?? '';
        final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
        if (!_audioExts.contains(ext)) continue; // 跳过视频等非音频文件
        final title = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
        songs.add(Song(
          id: -(path.hashCode & 0x3FFFFFFF) - 1,
          name: title,
          artists: '本地音乐',
          album: '',
          duration: 0,
          source: 'local',
          audioUrl: '/local/file?p=${Uri.encodeComponent(path)}',
          localPath: path,
        ));
      }
      if (!mounted) return;
      setState(() {
        _dir = (r['dir'] as String?) ?? dir;
        _songs = songs;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.read<PlayerController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            children: [
              const Text('本地音乐', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              if (_scanned)
                Text('${_songs.length} 首',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const Spacer(),
              if (_songs.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => p.playList(_songs, 0),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('播放全部'),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _pickAndScan,
                icon: const Icon(Icons.folder_open, size: 18),
                label: Text(_loading ? '扫描中...' : (_scanned ? '更换文件夹' : '选择文件夹')),
              ),
            ],
          ),
        ),
        if (_dir.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(_dir,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error, style: TextStyle(color: theme.colorScheme.error)),
          ),
        Expanded(
          child: !_scanned
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_outlined,
                          size: 46,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text('选择音乐文件夹，扫描后可播放本地歌曲\n（自动读取同名 .lrc 与 FLAC 内嵌歌词）',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : _songs.isEmpty
                  ? Center(
                      child: Text('未发现音频文件（支持 mp3/flac/m4a/wav/ogg 等）',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                      itemCount: _songs.length,
                      itemBuilder: (_, i) => SongRow(
                        song: _songs[i],
                        showCover: false,
                        onPlay: () => p.playList(_songs, i),
                        onPlayNext: () => p.playNext(_songs[i]),
                        onAddQueue: () => p.addToQueue(_songs[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}
