import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salary_farming/motion.dart';

/// 버튼 하나만 있는 화면. 누르면 [onPress] 를 부른다.
Widget _host(void Function(BuildContext) onPress, {Widget? extra}) =>
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => onPress(context),
                child: const Text('열기'),
              ),
              ?extra,
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('스낵바: 아래에서 밀려 올라오고, 시간이 지나면 내려가며 사라진다', (tester) async {
    await tester.pumpWidget(
      _host((c) => showAppSnackBar(c, '커피 파밍했어요', actionLabel: '취소')),
    );
    await tester.tap(find.text('열기'));
    await tester.pump();

    Offset slide() => tester
        .widget<SlideTransition>(
          find.ancestor(
            of: find.text('커피 파밍했어요'),
            matching: find.byType(SlideTransition),
          ),
        )
        .position
        .value;

    expect(slide().dy, greaterThan(1)); // 화면 아래쪽에서 출발
    await tester.pump(const Duration(milliseconds: 140));
    final mid = slide().dy;
    // ease out: 시간의 절반이 지났을 때 이미 절반 넘게 올라와 있다.
    expect(mid, lessThan(1.6 * 0.5));
    await tester.pump(const Duration(milliseconds: 200));
    expect(slide().dy, 0);

    // 1.5초 머문 뒤 내려가며 사라진다.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('커피 파밍했어요'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('커피 파밍했어요'), findsNothing);
  });

  testWidgets('토스트: 밀리지 않고 제자리에서 fade 로 나타난다', (tester) async {
    await tester.pumpWidget(_host((c) => showAppToast(c, '저장했어요')));
    await tester.tap(find.text('열기'));
    await tester.pump();
    expect(
      find.ancestor(
        of: find.text('저장했어요'),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    double opacity() => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.text('저장했어요'),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;
    expect(opacity(), 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(opacity(), 1);
    await tester.pumpAndSettle();
    expect(find.text('저장했어요'), findsNothing);
  });

  testWidgets('팝업: 0.9 에서 커지며 나온다', (tester) async {
    await tester.pumpWidget(
      _host(
        (c) => showAppDialog<void>(
          context: c,
          builder: (_) => const AlertDialog(title: Text('지울까요?')),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pump();
    double scale() => tester
        .widget<ScaleTransition>(
          find
              .ancestor(
                of: find.text('지울까요?'),
                matching: find.byType(ScaleTransition),
              )
              .first,
        )
        .scale
        .value;
    expect(scale(), closeTo(0.9, 0.001));
    await tester.pump(const Duration(milliseconds: 300));
    expect(scale(), 1);
  });

  testWidgets('로딩: 같은 속도로 계속 돈다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: LinearSpinner())),
    );
    double turns() =>
        tester.widget<RotationTransition>(find.byType(RotationTransition)).turns.value;
    await tester.pump(const Duration(milliseconds: 225));
    final a = turns();
    await tester.pump(const Duration(milliseconds: 225));
    final b = turns();
    // 같은 시간 동안 같은 만큼 돈다(linear). 한 바퀴 900ms → 225ms 에 0.25 바퀴.
    expect(a, closeTo(0.25, 0.01));
    expect(b - a, closeTo(0.25, 0.01));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('누르는 반응: 눌렸다가 spring 으로 톡 튀어 제자리', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SpringPress(
            child: SizedBox(
              width: 80,
              height: 80,
              child: ColoredBox(color: Colors.green),
            ),
          ),
        ),
      ),
    );
    double scale() => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(SpringPress),
            matching: find.byType(Transform),
          ),
        )
        .transform
        .storage[0]; // x 축 배율(getMaxScaleOnAxis 는 늘 1 인 z 축까지 봐서 쓸 수 없다)

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SpringPress)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(scale(), lessThan(0.95));
    await gesture.up();
    var peak = 0.0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (scale() > peak) peak = scale();
    }
    expect(peak, greaterThan(1.0)); // 1 을 살짝 넘겨 튀었다가
    await tester.pumpAndSettle();
    expect(scale(), closeTo(1, 0.001)); // 제자리에 앉는다
  });

  testWidgets('한 줄씩: 뒷줄은 앞줄보다 늦게 나온다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: staggered(const [Text('첫 줄'), Text('둘째 줄'), Text('셋째 줄')]),
        ),
      ),
    );
    double opacityOf(String t) => tester
        .widget<Opacity>(
          find.ancestor(of: find.text(t), matching: find.byType(Opacity)),
        )
        .opacity;
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacityOf('첫 줄'), greaterThan(opacityOf('둘째 줄')));
    expect(opacityOf('둘째 줄'), greaterThan(opacityOf('셋째 줄')));
    await tester.pumpAndSettle();
    expect(opacityOf('셋째 줄'), 1);
  });
}
