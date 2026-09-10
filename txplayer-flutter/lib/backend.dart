/// 内置后端管理：优先复用已在运行的服务（开发环境），
/// 否则拉起安装目录内置的 Node 后端（node.exe + server/，随安装包分发）
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

const _healthUrl = 'http://127.0.0.1:3000/api/health';

Process? _backendProc;

Future<bool> _healthOk() async {
  final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 800);
  try {
    final req = await client.getUrl(Uri.parse(_healthUrl));
    final res = await req.close().timeout(const Duration(seconds: 2));
    await res.drain<void>();
    return res.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

/// 确保后端可用：已在运行则直接返回；否则拉起内置服务并等待就绪
Future<void> ensureBackend() async {
  if (await _healthOk()) return; // 开发环境/已有实例

  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final sep = Platform.pathSeparator;
  final node = File('$exeDir${sep}node.exe');
  final entry = File('$exeDir${sep}server${sep}index.js');
  if (!await node.exists() || !await entry.exists()) {
    debugPrint('未找到内置后端（开发模式可忽略）');
    return;
  }

  try {
    final support = await getApplicationSupportDirectory();
    _backendProc = await Process.start(
      node.path,
      [entry.path],
      workingDirectory: entry.parent.path,
      environment: {
        'PORT': '3000',
        // 与主程序共用数据目录：网易云/B站登录 cookie 持久化
        'MUSIC_PLAYER_DATA': support.path,
      },
    );
    // 输出转发到调试日志，便于排查
    _backendProc!.stdout.listen((d) => debugPrint('[server] $d'));
    _backendProc!.stderr.listen((d) => debugPrint('[server!] $d'));
  } catch (e) {
    debugPrint('内置后端启动失败: $e');
    return;
  }

  // 等待就绪（最多约 12 秒）
  for (var i = 0; i < 24; i++) {
    if (await _healthOk()) return;
    await Future.delayed(const Duration(milliseconds: 500));
  }
  debugPrint('内置后端启动超时');
}

/// 退出应用时关闭后端子进程
void stopBackend() {
  try {
    _backendProc?.kill();
  } catch (_) {
    /* 忽略 */
  }
  _backendProc = null;
}
