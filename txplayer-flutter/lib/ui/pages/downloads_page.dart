/// 下载管理页：任务列表 / 进度 / 打开目录 / 清理
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/download_controller.dart';
import '../widgets/song_row.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DownloadController>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            children: [
              const Text('下载管理', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (d.tasks.isNotEmpty)
                TextButton.icon(
                  onPressed: d.clearFinished,
                  icon: const Icon(Icons.cleaning_services_outlined, size: 17),
                  label: const Text('清除已完成'),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final dir = await FilePicker.getDirectoryPath(dialogTitle: '选择下载目录');
                  if (dir != null && dir.isNotEmpty) await d.setDownloadDir(dir);
                },
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('更改目录'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: d.openDir,
                icon: const Icon(Icons.folder, size: 18),
                label: const Text('打开目录'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(d.downloadDir,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        Expanded(
          child: d.tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_outlined,
                          size: 46,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text('暂无下载任务\n在歌曲的「更多」菜单里选择「下载」',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                  itemCount: d.tasks.length,
                  itemBuilder: (_, i) {
                    final t = d.tasks[i];
                    final (label, color) = switch (t.status) {
                      DownloadStatus.queued => ('排队中', theme.colorScheme.onSurfaceVariant),
                      DownloadStatus.resolving => ('解析地址中', theme.colorScheme.onSurfaceVariant),
                      DownloadStatus.downloading => ('下载中', theme.colorScheme.primary),
                      DownloadStatus.done => ('已完成', Colors.green),
                      DownloadStatus.error => ('失败：${t.error}', theme.colorScheme.error),
                    };
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          CoverBox(url: t.song.picUrl, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.song.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text(
                                  t.error.isEmpty ? '${t.song.artists} · $label' : label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                                ),
                                if (t.status == DownloadStatus.downloading)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: t.progress,
                                        minHeight: 5,
                                        backgroundColor:
                                            theme.colorScheme.surfaceContainerHighest,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (t.status == DownloadStatus.downloading)
                            Text('${(t.progress * 100).round()}%',
                                style: theme.textTheme.bodySmall),
                          if (t.status == DownloadStatus.done)
                            Icon(Icons.check_circle, size: 20, color: Colors.green),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
