// 歌词自动滚动机制的回归测试：
// 行高不一致（含翻译行）时，基于 ensureVisible 的定位应精确把目标行滚到视口中间
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('变高行歌词列表可精确定位到目标行', (tester) async {
    final controller = ScrollController();
    final keys = List.generate(60, (_) => GlobalKey());

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 400,
          child: ListView.builder(
            controller: controller,
            itemCount: 60,
            itemBuilder: (_, i) => SizedBox(
              key: keys[i],
              // 模拟：偶数行只有原文（60），奇数行带翻译（90）
              height: i.isEven ? 60.0 : 90.0,
              child: Text('line $i'),
            ),
          ),
        ),
      ),
    ));
    expect(controller.offset, 0);

    // 目标行在屏幕外（未构建）——与拖动进度远跳的场景一致
    expect(keys[40].currentContext, isNull);

    // 第一阶段：按平均行高估算跳转（让目标行进入构建范围）
    controller.jumpTo(40 * 75.0);
    await tester.pump();

    // 第二阶段：目标行已构建 → 精确定位到视口中间
    final ctx = keys[40].currentContext;
    expect(ctx, isNotNull);
    // 注意：不能 await（测试环境要用 pump 推进动画）
    Scrollable.ensureVisible(
      ctx!,
      alignment: 0.5,
      duration: const Duration(milliseconds: 1),
    );
    await tester.pumpAndSettle();

    // 已发生滚动
    expect(controller.offset, greaterThan(500));

    // 目标行中心接近视口中心（±行高范围内）
    final box = ctx.findRenderObject() as RenderBox;
    final top = box.localToGlobal(Offset.zero).dy;
    final center = top + box.size.height / 2;
    expect((center - 200).abs(), lessThan(60));
  });
}
