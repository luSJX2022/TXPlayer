/// 歌词页：纯歌词排版（模糊封面背景 + 居中滚动歌词）
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../state/player_controller.dart';
import '../../state/settings_controller.dart';

class LyricPage extends StatefulWidget {
  const LyricPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const LyricPage(), fullscreenDialog: true);

  @override
  State<LyricPage> createState() => _LyricPageState();
}

class _LyricPageState extends State<LyricPage> {
  final ScrollController _scroll = ScrollController();
  int _lastIdx = -1;
  int _lastLyricLen = -1;
  // 每行歌词的 key：按实际渲染位置精确定位（估算行高会因翻译行/边距而失准）
  final List<GlobalKey> _lineKeys = [];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 滚动到当前行并居中（基于真实布局位置）
  void _scrollToLine(int idx, {bool retry = false}) {
    if (idx < 0) return;
    if (idx < _lineKeys.length) {
      final ctx = _lineKeys[idx].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
        return;
      }
    }
    // 目标行尚未构建（如拖动进度远跳）：先按估算位置跳过去，下一帧再精确定位
    if (retry || !_scroll.hasClients) return;
    final s = SettingsController.instance;
    final est = idx * (s.lyricFontSize * 2.4 + (s.showLyricTrans ? s.lyricFontSize : 0));
    _scroll.jumpTo(est.clamp(0.0, _scroll.position.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLine(idx, retry: true));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerController>();
    final s = context.watch<SettingsController>();
    final song = p.current;
    final cover = song?.picUrl ?? '';
    final idx = p.currentLyricIndex;

    // 歌词列表变化（切歌/重新加载）时重置跟踪状态并回到顶部
    if (p.lyric.length != _lastLyricLen) {
      _lastLyricLen = p.lyric.length;
      _lastIdx = -1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
      });
    }

    // 当前行变化：按真实布局位置滚动居中
    if (idx != _lastIdx) {
      _lastIdx = idx;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLine(idx));
    }

    // 确保有足够的行 key
    while (_lineKeys.length < p.lyric.length) {
      _lineKeys.add(GlobalKey());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 模糊封面背景
          if (cover.isNotEmpty)
            Image.network(ApiClient.resolve(cover), fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox()),
          BackdropFilter(
            filter: ColorFilter.mode(Colors.black.withValues(alpha: 0.72), BlendMode.srcOver),
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 歌名 / 歌手
                      Text(
                        song?.name ?? '暂无播放',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        song == null
                            ? ''
                            : '${song.artists}${song.album.isEmpty ? '' : ' · ${song.album}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 14),
                      Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                      const SizedBox(height: 6),
                      // 歌词
                      Expanded(
                        child: p.lyric.isEmpty
                            ? Center(
                                child: Text('暂无歌词，请欣赏',
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.45))))
                            : ListView.builder(
                                controller: _scroll,
                                padding: EdgeInsets.symmetric(
                                    vertical: MediaQuery.of(context).size.height * 0.38),
                                itemCount: p.lyric.length,
                                itemBuilder: (_, i) {
                                  final line = p.lyric[i];
                                  final active = i == idx;
                                  return InkWell(
                                    key: i < _lineKeys.length ? _lineKeys[i] : null,
                                    onTap: () => p.seekTo(line.time + 0.01),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            line.text.isEmpty ? '♪' : line.text,
                                            style: TextStyle(
                                              fontSize: active
                                                  ? s.lyricFontSize * 1.18
                                                  : s.lyricFontSize,
                                              fontWeight:
                                                  active ? FontWeight.w700 : FontWeight.w400,
                                              color: Colors.white
                                                  .withValues(alpha: active ? 1.0 : 0.4),
                                              height: 1.6,
                                            ),
                                          ),
                                          if (s.showLyricTrans && line.trans.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                line.trans,
                                                style: TextStyle(
                                                  fontSize: s.lyricFontSize * 0.78,
                                                  color: Colors.white.withValues(
                                                      alpha: active ? 0.75 : 0.35),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 关闭
          Positioned(
            top: 14,
            right: 18,
            child: IconButton(
              tooltip: '关闭歌词',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
        ],
      ),
    );
  }
}
