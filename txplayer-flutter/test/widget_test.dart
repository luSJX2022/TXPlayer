// TXPlayer Flutter 冒烟测试
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:txplayer/main.dart';

/// 在若干候选路径中寻找 libmpv-2.dll（测试环境需要显式指定）
String? _findLibmpv() {
  const candidates = [
    'build/windows/x64/runner/Release/libmpv-2.dll',
    'build/windows/x64/libmpv/libmpv-2.dll',
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return File(c).absolute.path;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final libmpv = _findLibmpv();
  if (libmpv != null) {
    MediaKit.ensureInitialized(libmpv: libmpv);
  }

  testWidgets('应用壳冒烟测试', (tester) async {
    if (libmpv == null) {
      // 尚未构建过 Windows 产物（无 libmpv），跳过本测试
      return;
    }
    // 模拟真实桌面窗口尺寸，避免窄视口误报布局溢出
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TxPlayerApp());
    await tester.pump();

    expect(find.text('搜索'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
    expect(find.text('未在播放'), findsOneWidget);
  });
}
