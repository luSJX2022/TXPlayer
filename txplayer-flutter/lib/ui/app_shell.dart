/// 应用壳：左侧导航 + 内容区 + 底部悬浮播放条
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../state/settings_controller.dart';
import 'pages/bili_page.dart';
import 'pages/downloads_page.dart';
import 'pages/local_page.dart';
import 'pages/playlist_detail_page.dart';
import 'pages/playlist_page.dart';
import 'pages/queue_page.dart';
import 'pages/recommend_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';
import 'pages/toplist_page.dart';
import 'widgets/player_bar.dart';
import 'widgets/song_row.dart';

enum _Nav { search, top, playlist, bili, local, recommend, fm, queue, downloads, settings }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _Nav _current = _Nav.search;
  List<PlaylistSummary> _myPlaylists = [];
  int _loadedUid = -1;

  static const _baseItems = [
    (_Nav.search, Icons.search, '搜索'),
    (_Nav.top, Icons.emoji_events_outlined, '排行榜'),
    (_Nav.playlist, Icons.queue_music, '歌单'),
    (_Nav.bili, Icons.live_tv_outlined, 'B站'),
    (_Nav.local, Icons.folder_outlined, '本地'),
  ];

  // 登录后才显示
  static const _loginItems = [
    (_Nav.recommend, Icons.explore_outlined, '推荐'),
    (_Nav.fm, Icons.radio_outlined, 'FM'),
  ];

  static const _bottomItems = [
    (_Nav.queue, Icons.list, '播放列表'),
    (_Nav.downloads, Icons.download_outlined, '下载'),
    (_Nav.settings, Icons.settings_outlined, '设置'),
  ];

  Widget _pageFor(_Nav nav) => switch (nav) {
        _Nav.search => const SearchPage(),
        _Nav.top => const ToplistPage(),
        _Nav.playlist => const PlaylistPage(),
        _Nav.bili => const BiliPage(),
        _Nav.local => const LocalPage(),
        _Nav.recommend => const RecommendPage(),
        _Nav.fm => const FmPage(),
        _Nav.queue => const QueuePage(),
        _Nav.downloads => const DownloadsPage(),
        _Nav.settings => const SettingsPage(),
      };

  /// 登录后加载“我的歌单”
  void _maybeLoadPlaylists(int uid) {
    if (uid <= 0 || uid == _loadedUid) return;
    _loadedUid = uid;
    api.getUserPlaylists(uid).then((list) {
      if (mounted) setState(() => _myPlaylists = list);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.watch<SettingsController>();
    final loggedIn = s.neteaseLogin;
    if (loggedIn) _maybeLoadPlaylists(s.neteaseUserId);

    final items = <( _Nav, IconData, String)>[
      ..._baseItems,
      if (loggedIn) ..._loginItems,
    ];
    // 当前页被隐藏（退出登录）时回退到搜索
    if (_current == _Nav.recommend || _current == _Nav.fm) {
      if (!loggedIn) _current = _Nav.search;
    }

    return Scaffold(
      body: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 侧栏：贯穿整条左侧（含底部区域）
              Container(
                width: 210,
                color: theme.colorScheme.surfaceContainer,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                        children: [
                          for (final (nav, icon, label) in items) _navItem(nav, icon, label),
                          // 我的歌单
                          if (loggedIn && _myPlaylists.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                              child: Text('我的歌单',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant)),
                            ),
                            for (final pl in _myPlaylists) _playlistItem(pl),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14, left: 10, right: 10),
                      child: Column(
                        children: [
                          for (final (nav, icon, label) in _bottomItems)
                            _navItem(nav, icon, label),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 内容区
              Expanded(child: _pageFor(_current)),
            ],
          ),
          // 底部悬浮播放条：居中于内容区（避开左侧栏）
          Positioned(
            left: 210,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 12),
              child: SafeArea(top: false, child: const PlayerBar()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playlistItem(PlaylistSummary pl) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(PlaylistDetailPage.route(
        id: pl.id,
        name: pl.name,
        coverImgUrl: pl.coverImgUrl,
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            CoverBox(url: pl.coverImgUrl, size: 30, radius: 5),
            const SizedBox(width: 8),
            Expanded(
              child: Text(pl.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(_Nav nav, IconData icon, String label) {
    final theme = Theme.of(context);
    final active = _current == nav;
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: active ? scheme.primaryContainer.withValues(alpha: 0.45) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _current = nav),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 18,
                    color: active ? scheme.primary : scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Text(label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? scheme.primary : scheme.onSurface,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
