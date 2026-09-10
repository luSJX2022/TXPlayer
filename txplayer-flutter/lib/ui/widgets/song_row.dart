/// 通用歌曲列表行
library;

import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/models.dart';
import '../../state/download_controller.dart';
import '../../state/player_controller.dart';

/// 封面占位（无图时用音符色块）
class CoverBox extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;

  const CoverBox({super.key, this.url, this.size = 44, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    final Widget child;
    final dim = Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    if (url != null && url!.isNotEmpty) {
      child = Image.network(
        ApiClient.resolve(url!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => _placeholder(context, dim),
      );
    } else {
      child = _placeholder(context, dim);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }

  Widget _placeholder(BuildContext context, Color dim) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(Icons.music_note, size: size * 0.45, color: dim),
      );
}

/// 单行歌曲：单击播放；提供操作回调时显示更多/移除
class SongRow extends StatelessWidget {
  final Song song;
  final bool showCover;
  final VoidCallback? onPlay;
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddQueue;
  final VoidCallback? onRemove;

  const SongRow({
    super.key,
    required this.song,
    this.showCover = true,
    this.onPlay,
    this.onPlayNext,
    this.onAddQueue,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onPlay,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (showCover) ...[
              CoverBox(url: song.picUrl, size: 42),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artists.isEmpty ? '未知歌手' : song.artists,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: dim),
                  ),
                ],
              ),
            ),
            if (song.duration > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  PlayerController.instance.formatTime(Duration(seconds: song.duration)),
                  style: theme.textTheme.bodySmall?.copyWith(color: dim),
                ),
              ),
            if (onRemove != null)
              IconButton(
                tooltip: '移除',
                icon: Icon(Icons.close, size: 17, color: dim),
                onPressed: onRemove,
              )
            else
              PopupMenuButton<String>(
                tooltip: '更多',
                icon: Icon(Icons.more_vert, size: 18, color: dim),
                onSelected: (v) {
                  switch (v) {
                    case 'play':
                      onPlay?.call();
                    case 'next':
                      onPlayNext?.call();
                    case 'queue':
                      onAddQueue?.call();
                    case 'download':
                      DownloadController.instance.start(song);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'play', child: Text('立即播放')),
                  const PopupMenuItem(value: 'next', child: Text('下一首播放')),
                  const PopupMenuItem(value: 'queue', child: Text('加入播放队列')),
                  if (song.source != 'local')
                    const PopupMenuItem(value: 'download', child: Text('下载')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
