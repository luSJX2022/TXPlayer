/// 播放队列页
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/player_controller.dart';
import '../widgets/song_row.dart';

class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerController>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            children: [
              Text('播放队列（${p.queue.length} 首）',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (p.queue.isNotEmpty)
                TextButton.icon(
                  onPressed: p.clearQueue,
                  icon: const Icon(Icons.delete_outline, size: 17),
                  label: const Text('清空'),
                ),
            ],
          ),
        ),
        Expanded(
          child: p.queue.isEmpty
              ? Center(
                  child: Text('队列为空，去搜索页或歌单页添加歌曲吧',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  itemCount: p.queue.length,
                  itemBuilder: (_, i) {
                    final s = p.queue[i];
                    final active = i == p.index;
                    return Container(
                      decoration: active
                          ? BoxDecoration(
                              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(10),
                            )
                          : null,
                      child: SongRow(
                        song: s,
                        onPlay: () => p.jumpTo(i),
                        onRemove: () => p.removeAt(i),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
