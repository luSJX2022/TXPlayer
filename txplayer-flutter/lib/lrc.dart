/// LRC 歌词解析（主程序与桌面歌词窗口共用）
library;

/// 一行歌词（time 秒）
class LyricLine {
  final double time;
  final String text;
  final String trans;
  LyricLine(this.time, this.text, this.trans);
}

final _lrcReg = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

double _lrcTime(Match m) {
  final min = int.parse(m.group(1)!);
  final sec = int.parse(m.group(2)!);
  final fracStr = m.group(3) ?? '0';
  final frac = int.parse(fracStr) / (fracStr.length == 3 ? 1000 : 100);
  return min * 60 + sec + frac;
}

/// 解析 LRC（支持一行多时间戳）；transMap：时间(百分秒) -> 翻译
List<LyricLine> parseLrc(String lrc, {Map<int, String>? transMap}) {
  final list = <LyricLine>[];
  if (lrc.isEmpty) return list;
  for (final raw in lrc.split('\n')) {
    final matches = _lrcReg.allMatches(raw).toList();
    if (matches.isEmpty) continue;
    final text = raw.replaceAll(_lrcReg, '').trim();
    if (text.isEmpty) continue;
    for (final m in matches) {
      final t = _lrcTime(m);
      list.add(LyricLine(t, text, transMap?[(t * 100).round()] ?? ''));
    }
  }
  list.sort((a, b) => a.time.compareTo(b.time));
  return list;
}

/// 解析翻译 LRC 为 时间(百分秒) -> 文本
Map<int, String> parseTransMap(String lrc) {
  final map = <int, String>{};
  if (lrc.isEmpty) return map;
  for (final raw in lrc.split('\n')) {
    final m = _lrcReg.firstMatch(raw);
    if (m == null) continue;
    final text = raw.replaceAll(_lrcReg, '').trim();
    if (text.isEmpty) continue;
    map[(_lrcTime(m) * 100).round()] = text;
  }
  return map;
}

/// 二分查找当前时间对应的歌词行下标（-1 表示无）
int lyricIndexAt(List<LyricLine> lyric, double seconds) {
  if (lyric.isEmpty) return -1;
  var lo = 0, hi = lyric.length - 1, ans = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (lyric[mid].time <= seconds) {
      ans = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return ans;
}
