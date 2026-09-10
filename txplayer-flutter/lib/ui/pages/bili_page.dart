/// B站解析页：解析 → 内嵌视频播放（清晰度切换，保持进度）/ 播放音频入队
library;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../api/models.dart';
import '../../state/player_controller.dart';
import '../widgets/song_row.dart';

class BiliPage extends StatefulWidget {
  const BiliPage({super.key});

  @override
  State<BiliPage> createState() => _BiliPageState();
}

class _BiliPageState extends State<BiliPage> {
  final _input = TextEditingController();
  bool _loading = false;
  String _error = '';
  BiliVideoInfo? _info;
  String _parsedInput = '';

  // 内嵌视频（media_kit）
  late final Player _player = Player();
  late final VideoController _videoCtrl = VideoController(_player);
  bool _showVideo = false;
  bool _switching = false;

  Future<void> _parse({String? url, int qn = 0}) async {
    final target = url ?? _input.text.trim();
    if (target.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = '';
      if (qn == 0) _info = null;
    });
    try {
      final info = await api.parseBili(target, qn: qn);
      if (mounted) {
        setState(() {
          _info = info;
          _parsedInput = target;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Song _toSong(BiliVideoInfo v) {
    var h = 0;
    final s = '${v.bvid}#${v.page}';
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7FFFFFFF;
    }
    return Song(
      id: -(h % 1000000000) - 1,
      name: v.title,
      artists: v.artists,
      album: '哔哩哔哩',
      duration: v.duration,
      picUrl: v.picUrl,
      source: 'bili',
      audioUrl: v.audioUrl,
      videoUrl: v.videoUrl,
    );
  }

  /// 播放视频（音画合一，mpv 解码）
  Future<void> _playVideo() async {
    final info = _info;
    if (info == null) return;
    if (info.videoUrl.isEmpty) {
      _snack('该视频暂无可用的视频节点');
      return;
    }
    setState(() => _showVideo = true);
    try {
      await _player.open(Media(ApiClient.resolve(info.videoUrl)), play: true);
    } catch (e) {
      _snack('视频加载失败：$e');
    }
  }

  /// 切换清晰度：重新解析并保持当前播放进度
  Future<void> _switchQuality(int qn) async {
    final info = _info;
    if (info == null || _switching || qn == info.currentQn) return;
    final pos = _player.state.position;
    final wasPlaying = _player.state.playing;
    setState(() => _switching = true);
    try {
      final newInfo = await api.parseBili(_parsedInput, qn: qn);
      if (!mounted) return;
      setState(() => _info = newInfo);
      if (_showVideo && newInfo.videoUrl.isNotEmpty) {
        await _player.open(
          Media(ApiClient.resolve(newInfo.videoUrl), start: pos),
          play: wasPlaying,
        );
      }
    } catch (e) {
      _snack('切换清晰度失败：$e');
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _input.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.read<PlayerController>();
    final info = _info;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 90),
      children: [
        const Text('B站视频解析', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('粘贴 B 站视频链接 / BV 号（支持 ?p= 分P），可播放视频（含清晰度切换）或把音频加入播放队列',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                onSubmitted: (_) => _parse(),
                decoration: InputDecoration(
                  hintText: 'https://www.bilibili.com/video/BVxxxxxxxxxx',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: (_loading || _input.text.trim().isEmpty) ? null : () => _parse(),
              child: Text(_loading ? '解析中...' : '解析'),
            ),
          ],
        ),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error, style: TextStyle(color: theme.colorScheme.error)),
          ),
        if (info != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                CoverBox(url: info.picUrl, size: 110, radius: 10),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(info.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('UP: ${info.artists} · ${p.formatTime(Duration(seconds: info.duration))}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _playVideo,
                            icon: const Icon(Icons.play_arrow, size: 17),
                            label: const Text('播放视频'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => p.playSong(_toSong(info)),
                            icon: const Icon(Icons.music_note, size: 17),
                            label: const Text('播放音频'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => p.addToQueue(_toSong(info)),
                            icon: const Icon(Icons.add, size: 17),
                            label: const Text('加入队列'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 视频区
          if (_showVideo) ...[
            const SizedBox(height: 14),
            // 清晰度切换
            if (info.qualities.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text('清晰度',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    for (final q in info.qualities)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text((q['desc'] as String?) ?? '${q['qn']}'),
                          selected: q['qn'] == info.currentQn,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => _switchQuality((q['qn'] as num?)?.toInt() ?? 0),
                        ),
                      ),
                    if (_switching)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: SizedBox(
                            width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                  ],
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Video(controller: _videoCtrl),
              ),
            ),
            const SizedBox(height: 6),
            Text('提示：未登录 B 站最高 720P；在设置页登录 B 站账号后可播放 1080P 及以上',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ],
    );
  }
}
