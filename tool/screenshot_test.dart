// 화면을 PNG로 뽑아 눈으로 확인하는 용도. 일반 테스트에는 포함되지 않는다.
//   flutter test tool/screenshot_test.dart --update-goldens
// 결과는 tool/shots/ 에 생긴다. Windows 글꼴을 쓰므로 Windows에서만 돈다.
// test/ 밖에 있어서 분석기가 테스트 전용 API 사용을 경고하므로 끈다.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salary_farming/app_store.dart';
import 'package:salary_farming/main.dart';
import 'package:salary_farming/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final bytes = File(p).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    const malgun = ['C:/Windows/Fonts/malgun.ttf', 'C:/Windows/Fonts/malgunbd.ttf'];
    // 기본 글꼴 이름(플랫폼별)에 한글 글꼴을 물려 실제 글자가 보이게 한다.
    for (final family in ['Roboto', 'Segoe UI', '.SF UI Text', '.SF UI Display']) {
      await loadFont(family, malgun);
    }
    await loadFont('MaterialIcons', [
      'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  });

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/$name.png'),
    );
  }

  testWidgets('screens', (tester) async {
    tester.view.physicalSize = const Size(824, 1830);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    var now = DateTime(2026, 11, 2, 9, 0);
    final store = AppStore(clock: () => now);
    await store.load();

    await tester.pumpWidget(SalaryFarmingApp(store: store));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '3200000');
    await tester.pumpAndSettle();
    await shot(tester, '01_setup');
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await shot(tester, '02_setup_bottom');

    await tester.ensureVisible(find.text('설정 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정 완료'));
    await tester.pumpAndSettle();
    await shot(tester, '03_setup_done');

    // 한 달치 기록을 채운다.
    BenefitTemplate t(String id) => store.templates.firstWhere((e) => e.id == id);
    for (var day = 2; day <= 26; day++) {
      final date = DateTime(2026, 11, day);
      if (date.weekday > 5) continue;
      now = DateTime(2026, 11, day, 9, 20);
      await store.credit(t('d_coffee'));
      now = DateTime(2026, 11, day, 12, 5);
      await store.credit(t('d_lunch'));
      if (day.isEven) {
        now = DateTime(2026, 11, day, 15, 30);
        await store.credit(t('d_snack'));
      }
      if (day % 5 == 0) {
        now = DateTime(2026, 11, day, 19, 0);
        await store.credit(t('d_gym'));
      }
    }
    now = DateTime(2026, 11, 26, 14, 30, 12);

    await tester.tap(find.text('파밍 시작하기'));
    await tester.pumpAndSettle();
    await shot(tester, '04_home');
    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();
    await shot(tester, '05_home_scrolled');

    await tester.tap(find.text('직접 만들기'));
    await tester.pumpAndSettle();
    await shot(tester, '06_template_sheet');
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.text('결산'));
    await tester.pumpAndSettle();
    await shot(tester, '07_stats_day');
    await tester.tap(find.text('주간'));
    await tester.pumpAndSettle();
    await shot(tester, '08_stats_week');
    await tester.tap(find.text('월간'));
    await tester.pumpAndSettle();
    await shot(tester, '09_stats_month');
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await shot(tester, '10_stats_month_scrolled');
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('연간'));
    await tester.pumpAndSettle();
    await shot(tester, '11_stats_year');

    await tester.scrollUntilVisible(
      find.text('결산 이미지 만들기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('결산 이미지 만들기'));
    await tester.pumpAndSettle();
    await shot(tester, '12_share');
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await shot(tester, '13_settings');

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
