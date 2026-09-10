/// 底部悬浮播放条（居中胶囊，与主界面一致）
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/player_controller.dart';
import '../pages/lyric_page.dart';
import 'song_row.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerController>();
    final theme = Theme.of(context);
    final song = p.current;

    // 液态玻璃：背景模糊 + 半透明渐变 + 镜面高光描边
    final isDark = theme.brightness == Brightness.dark;
    final glassRadius = BorderRadius.circular(24);
    final glassGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0.04)]
          : [Colors.white.withValues(alpha: 0.66), Colors.white.withValues(alpha: 0.42)],
    );
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.08);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 880),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: glassRadius,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                gradient: glassGradient,
                borderRadius: glassRadius,
                border: Border.all(color: glassBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                    blurRadius: 34,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Stack(
                children: [
                  // 顶部镜面高光
                  Positioned(
                    top: 0,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: isDark ? 0.5 : 0.9),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
          children: [
            // 左：封面 + 信息（点击打开歌词页）
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.of(context).push(LyricPage.route()),
              child: CoverBox(url: song?.picUrl, size: 48, radius: 8),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () => Navigator.of(context).push(LyricPage.route()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song?.name ?? '未在播放',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      song == null
                          ? '选择一首歌开始播放'
                          : (song.artists.isEmpty ? '未知歌手' : song.artists),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            // 中：控制 + 进度
            Expanded(
              flex: 3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 控制按钮：窄宽度时按比例缩放，避免溢出
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CtrlButton(
                          icon: switch (p.mode) {
                            PlayMode.list => Icons.repeat,
                            PlayMode.single => Icons.repeat_one,
                            PlayMode.random => Icons.shuffle,
                          },
                          tooltip: p.modeLabel,
                          onTap: p.cycleMode,
                        ),
                        _CtrlButton(icon: Icons.skip_previous, tooltip: '上一首', onTap: p.prev),
                        _PlayButton(playing: p.isPlaying, loading: p.loading, onTap: p.togglePlay),
                        _CtrlButton(icon: Icons.skip_next, tooltip: '下一首', onTap: p.next),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(p.formatTime(p.position),
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          ),
                          child: Slider(
                            value: p.duration.inMilliseconds == 0
                                ? 0
                                : (p.position.inMilliseconds / p.duration.inMilliseconds).clamp(0.0, 1.0),
                            onChanged: p.duration.inMilliseconds == 0
                                ? null
                                : (v) => p.seekTo(v * p.duration.inMilliseconds / 1000),
                          ),
                        ),
                      ),
                      Text(p.formatTime(p.duration),
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
            // 右侧：音量（静音键 + 滑条）
            SizedBox(
              width: 150,
              child: Row(
                children: [
                  IconButton(
                    tooltip: p.muted ? '取消静音' : '静音',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      p.muted || p.volume == 0
                          ? Icons.volume_off
                          : (p.volume < 0.5 ? Icons.volume_down : Icons.volume_up),
                      size: 19,
                    ),
                    color: theme.colorScheme.onSurface,
                    onPressed: p.toggleMute,
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: p.muted ? 0 : p.volume,
                        onChanged: (v) => p.setVolume(v),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  ),
  ),
  ),
  ),
  );
  }
}

class _CtrlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CtrlButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 19),
      color: theme.colorScheme.onSurface,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool playing;
  final bool loading;
  final VoidCallback onTap;

  const _PlayButton({required this.playing, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        tooltip: playing ? '暂停' : '播放',
        iconSize: 24,
        style: IconButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(playing ? Icons.pause : Icons.play_arrow),
        onPressed: onTap,
      ),
    );
  }
}
