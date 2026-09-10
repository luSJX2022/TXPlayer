// 歌词解析与当前行定位测试（桌面歌词滚动逻辑核心）
import 'package:flutter_test/flutter_test.dart';

import 'package:txplayer/lrc.dart';

void main() {
  test('LRC 解析与当前行定位', () {
    const lrc = '[00:00.00]第一行\n[00:05.50]第二行\n[00:10.20]第三行\n';
    final lines = parseLrc(lrc);
    expect(lines.length, 3);
    expect(lines[1].time, closeTo(5.5, 0.01));

    expect(lyricIndexAt(lines, 0), 0);
    expect(lyricIndexAt(lines, 5.4), 0);
    expect(lyricIndexAt(lines, 5.6), 1);
    expect(lyricIndexAt(lines, 100), 2);
    expect(lyricIndexAt(lines, -1), -1);
    expect(lyricIndexAt(const [], 1), -1);
  });

  test('一行多时间戳与翻译合并', () {
    const lrc = '[00:01.00][00:31.00]副歌\n[00:10.00]主歌';
    final lines = parseLrc(lrc, transMap: parseTransMap('[00:01.00]Chorus\n[00:10.00]Verse'));
    // 多时间戳展开后按时间排序：[1s 副歌, 10s 主歌, 31s 副歌]
    expect(lines.length, 3);
    expect(lines[0].text, '副歌');
    expect(lines[0].trans, 'Chorus');
    expect(lines[1].text, '主歌');
    expect(lines[1].trans, 'Verse');
    expect(lines[2].text, '副歌');
  });
}
