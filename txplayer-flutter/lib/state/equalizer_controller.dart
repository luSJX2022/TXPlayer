/// 均衡器：10 段增益 / 预设 / 持久化，变化时防抖应用到播放引擎（mpv 滤镜）
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'player_controller.dart';

/// 预设（10 段：31Hz ~ 16kHz）
const kEqPresets = <String, List<double>>{
  '默认': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  '流行': [-1, 0, 2, 4, 4, 2, 0, -1, -1, -1],
  '摇滚': [5, 4, 2, 0, -1, 0, 2, 4, 5, 5],
  '爵士': [3, 2, 1, 2, -1, -1, 0, 1, 2, 3],
  '古典': [4, 3, 2, 0, -1, -1, 0, 2, 3, 4],
  '电子': [4, 3, 1, 0, -2, 1, 2, 3, 5, 4],
  '人声': [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1],
  '低音增强': [7, 6, 5, 3, 1, 0, 0, 0, 0, 0],
};

class EqualizerController extends ChangeNotifier {
  EqualizerController._();

  static final EqualizerController instance = EqualizerController._();

  bool enabled = false;
  List<double> gains = List.filled(kEqFreqs.length, 0);
  String preset = '默认';

  Timer? _debounce;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool('eq_enabled') ?? false;
    final raw = prefs.getStringList('eq_gains');
    if (raw != null && raw.length == kEqFreqs.length) {
      gains = raw.map((e) => double.tryParse(e) ?? 0).toList();
    }
    preset = prefs.getString('eq_preset') ?? '默认';
    await PlayerController.instance.setEq(enabled, gains);
    notifyListeners();
  }

  void setEnabled(bool v) {
    enabled = v;
    _save();
    _apply();
    notifyListeners();
  }

  /// 调整某段增益（dB，-12 ~ +12）
  void setBand(int i, double db) {
    if (i < 0 || i >= gains.length) return;
    gains[i] = db.clamp(-12.0, 12.0);
    preset = '自定义';
    _save();
    _apply();
    notifyListeners();
  }

  void applyPreset(String name) {
    final p = kEqPresets[name];
    if (p == null) return;
    gains = List.of(p);
    preset = name;
    _save();
    _apply();
    notifyListeners();
  }

  void reset() => applyPreset('默认');

  /// 防抖 250ms 应用（拖动滑块时避免频繁重建滤镜链）
  void _apply() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      PlayerController.instance.setEq(enabled, gains);
    });
  }

  void _save() {
    SharedPreferences.getInstance().then((p) {
      p.setBool('eq_enabled', enabled);
      p.setStringList('eq_gains', gains.map((g) => g.toStringAsFixed(1)).toList());
      p.setString('eq_preset', preset);
    });
  }
}
