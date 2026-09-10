/// 设置页：默认音质 / 歌词显示 / 账号（网易云扫码登录）/ 主题 / 关于
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/client.dart';
import '../../desktop_lyric.dart' show kLyricColorPresets;
import '../../state/equalizer_controller.dart';
import '../../state/player_controller.dart' show kEqFreqs;
import '../../state/settings_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 90),
      children: [
        const Text('设置', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        _groupTitle('播放', theme),
        _qualityRow(s),
        _divider(theme),
        _groupTitle('均衡器', theme),
        _eqGroup(context),
        _divider(theme),
        _groupTitle('歌词', theme),
        _lyricTransRow(s),
        _lyricFontRow(s),
        _divider(theme),
        _groupTitle('桌面歌词', theme),
        _desktopLyricRow(s),
        _dlFontRow(s),
        _dlColorRow(s, context),
        _divider(theme),
        _groupTitle('账号', theme),
        _accountRow(s, context),
        const SizedBox(height: 12),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 12),
        _biliRow(s, context),
        _divider(theme),
        _groupTitle('外观', theme),
        _themeRow(s),
        _divider(theme),
        _groupTitle('关于', theme),
        _aboutRow(theme),
      ],
    );
  }

  Widget _groupTitle(String t, ThemeData theme) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Text(t,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
      );

  Widget _divider(ThemeData theme) => Divider(height: 20, color: theme.colorScheme.outlineVariant);

  Widget _qualityRow(SettingsController s) {
    return Row(
      children: [
        const Expanded(child: Text('默认音质', style: TextStyle(fontSize: 14))),
        const SizedBox(width: 12),
        Wrap(
          spacing: 6,
          children: [
            for (final q in s.qualityOptions)
              ChoiceChip(
                label: Text(s.qualityLabel(q)),
                selected: s.qualityLevel == q,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => s.setQuality(q),
              ),
          ],
        ),
      ],
    );
  }

  Widget _lyricTransRow(SettingsController s) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('歌词翻译', style: TextStyle(fontSize: 14)),
              Text('歌词页显示翻译行', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        Switch(value: s.showLyricTrans, onChanged: s.setShowLyricTrans),
      ],
    );
  }

  Widget _lyricFontRow(SettingsController s) {
    return Row(
      children: [
        Expanded(child: Text('歌词字号  ${s.lyricFontSize.round()}px', style: const TextStyle(fontSize: 14))),
        SizedBox(
          width: 220,
          child: Slider(
            min: 14,
            max: 28,
            divisions: 14,
            value: s.lyricFontSize,
            label: '${s.lyricFontSize.round()}',
            onChanged: s.setLyricFontSize,
          ),
        ),
      ],
    );
  }

  /// 均衡器分组：开关 + 预设 + 10 段滑块（两列）
  Widget _eqGroup(BuildContext context) {
    final eq = context.watch<EqualizerController>();
    final theme = Theme.of(context);

    String freqLabel(int f) => f < 1000 ? '$f' : '${f ~/ 1000}k';

    Widget band(int i) => Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(freqLabel(kEqFreqs[i]),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  min: -12,
                  max: 12,
                  divisions: 48,
                  value: eq.gains[i],
                  onChanged: eq.enabled ? (v) => eq.setBand(i, v) : null,
                ),
              ),
            ),
            SizedBox(
              width: 46,
              child: Text(
                '${eq.gains[i] >= 0 ? '+' : ''}${eq.gains[i].toStringAsFixed(1)}',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: eq.gains[i] > 0
                      ? Colors.green
                      : (eq.gains[i] < 0 ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('启用均衡器', style: TextStyle(fontSize: 14)),
                  Text('10 段音频增益（mpv 滤镜）', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Switch(value: eq.enabled, onChanged: eq.setEnabled),
          ],
        ),
        const SizedBox(height: 6),
        // 预设
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final name in kEqPresets.keys)
              ChoiceChip(
                label: Text(name),
                selected: eq.preset == name,
                visualDensity: VisualDensity.compact,
                onSelected: eq.enabled ? (_) => eq.applyPreset(name) : null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        // 两列频段
        Opacity(
          opacity: eq.enabled ? 1 : 0.45,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(children: [for (var i = 0; i < 5; i++) band(i)]),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(children: [for (var i = 5; i < 10; i++) band(i)]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _themeRow(SettingsController s) {
    return Row(
      children: [
        const Expanded(child: Text('主题', style: TextStyle(fontSize: 14))),
        const SizedBox(width: 12),
        Wrap(
          spacing: 6,
          children: [
            for (final (v, label) in [('system', '跟随系统'), ('dark', '深色'), ('light', '浅色')])
              ChoiceChip(
                label: Text(label),
                selected: s.themeMode == v,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => s.setTheme(v),
              ),
          ],
        ),
      ],
    );
  }

  /// 桌面歌词分组
  Widget _desktopLyricRow(SettingsController s) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('桌面歌词', style: TextStyle(fontSize: 14)),
              Text('透明置顶歌词窗口：拖动移动，右键改字号/颜色/关闭', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        Switch(value: s.desktopLyric, onChanged: s.setDesktopLyric),
      ],
    );
  }

  Widget _dlFontRow(SettingsController s) {
    return Row(
      children: [
        Expanded(
            child: Text('桌面歌词字号  ${s.dlFontSize.round()}px',
                style: const TextStyle(fontSize: 14))),
        SizedBox(
          width: 220,
          child: Slider(
            min: 14,
            max: 40,
            divisions: 26,
            value: s.dlFontSize,
            label: '${s.dlFontSize.round()}',
            onChanged: s.desktopLyric ? s.setDlFont : null,
          ),
        ),
      ],
    );
  }

  Widget _dlColorRow(SettingsController s, BuildContext context) {
    final theme = Theme.of(context);
    Color parse(String hex) {
      final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
      return v == null ? Colors.white : Color(0xFF000000 | v);
    }

    return Row(
      children: [
        const Expanded(child: Text('桌面歌词颜色', style: TextStyle(fontSize: 14))),
        Wrap(
          spacing: 8,
          children: [
            for (final c in kLyricColorPresets)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: s.desktopLyric ? () => s.setDlColor(c) : null,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: parse(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: s.dlColor == c ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                      width: s.dlColor == c ? 3 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _accountRow(SettingsController s, BuildContext context) {
    if (!s.neteaseLogin) {
      return Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('网易云账号', style: TextStyle(fontSize: 14)),
                Text('登录后可使用推荐、私人 FM、我的歌单等（后端已就绪）', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => _QrLoginDialog(
                  title: '网易云扫码登录',
                  createQr: api.createLoginQr,
                  checkQr: api.checkLoginQr,
                  successCode: 803,
                  scannedCode: 802,
                  expiredCode: 800,
                ),
              );
              if (ok == true) await s.refreshNeteaseStatus();
            },
            child: const Text('扫码登录'),
          ),
        ],
      );
    }
    return Row(
      children: [
        if (s.neteaseAvatar.isNotEmpty)
          ClipOval(
            child: Image.network(ApiClient.resolve(s.neteaseAvatar),
                width: 36, height: 36, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.person, size: 36)),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.neteaseNickname.isEmpty ? '已登录' : s.neteaseNickname,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Text('已登录网易云账号', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        TextButton(onPressed: s.logoutNetease, child: const Text('退出登录')),
      ],
    );
  }

  /// B站账号行
  Widget _biliRow(SettingsController s, BuildContext context) {
    if (!s.biliLogin) {
      return Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('B站账号', style: TextStyle(fontSize: 14)),
                Text('登录后 B站视频可播放 1080P 及以上清晰度', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => _QrLoginDialog(
                  title: 'B站扫码登录',
                  createQr: api.createBiliQr,
                  checkQr: api.checkBiliQr,
                  successCode: 0,
                  scannedCode: 86090,
                  expiredCode: 86038,
                ),
              );
              if (ok == true) await s.refreshBiliStatus();
            },
            child: const Text('扫码登录'),
          ),
        ],
      );
    }
    return Row(
      children: [
        if (s.biliFace.isNotEmpty)
          ClipOval(
            child: Image.network(ApiClient.resolve(s.biliFace),
                width: 36, height: 36, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.person, size: 36)),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.biliUname.isEmpty ? '已登录' : s.biliUname,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Text('已登录B站账号，视频支持 1080P 及以上', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        TextButton(onPressed: s.logoutBili, child: const Text('退出登录')),
      ],
    );
  }

  Widget _aboutRow(ThemeData theme) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TXPlayer (Flutter)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        SizedBox(height: 6),
        Text('里程碑 5：B站视频播放与清晰度切换 / B站扫码登录\n'
            '后端：TXPlayer Node 服务（http://127.0.0.1:3000，需先行启动）'),
      ],
    );
  }
}

/// 通用扫码登录对话框（网易云 / B站）
class _QrLoginDialog extends StatefulWidget {
  final String title;
  final Future<Map<String, String>> Function() createQr;
  final Future<Map<String, dynamic>> Function(String key) checkQr;
  final int successCode;
  final int scannedCode;
  final int expiredCode;

  const _QrLoginDialog({
    required this.title,
    required this.createQr,
    required this.checkQr,
    required this.successCode,
    required this.scannedCode,
    required this.expiredCode,
  });

  @override
  State<_QrLoginDialog> createState() => _QrLoginDialogState();
}

class _QrLoginDialogState extends State<_QrLoginDialog> {
  Uint8List? _img;
  String _tip = '二维码生成中...';
  bool _ok = false;
  bool _expired = false;
  String _key = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    _timer?.cancel();
    setState(() {
      _img = null;
      _ok = false;
      _expired = false;
      _tip = '二维码生成中...';
    });
    try {
      final qr = await widget.createQr();
      _key = qr['key'] ?? '';
      final dataUrl = qr['qrimg'] ?? '';
      final b64 = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
      if (!mounted) return;
      setState(() {
        _img = base64Decode(b64);
        _tip = '请用手机APP扫码';
      });
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    } catch (e) {
      if (mounted) setState(() => _tip = '二维码生成失败：$e');
    }
  }

  Future<void> _poll() async {
    if (_key.isEmpty) return;
    try {
      final r = await widget.checkQr(_key);
      final code = (r['code'] as num?)?.toInt() ?? -1;
      if (!mounted) return;
      if (code == widget.successCode) {
        _timer?.cancel();
        setState(() {
          _ok = true;
          _tip = '登录成功';
        });
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.of(context).pop(true);
      } else if (code == widget.scannedCode) {
        setState(() => _tip = '已扫码，请在手机上确认');
      } else if (code == widget.expiredCode) {
        _timer?.cancel();
        setState(() {
          _expired = true;
          _tip = '二维码已过期，请点击刷新';
        });
      }
    } catch (_) {
      /* 忽略单次轮询失败 */
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: _img != null
                ? Image.memory(_img!, width: 176, height: 176, gaplessPlayback: true)
                : const CircularProgressIndicator(),
          ),
          const SizedBox(height: 12),
          Text(_tip,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _ok
                      ? Colors.green
                      : (_expired ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant))),
        ],
      ),
      actions: [
        if (_expired) TextButton(onPressed: _start, child: const Text('刷新二维码')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ok),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
