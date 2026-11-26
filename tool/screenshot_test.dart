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
    for (final family in ['Roboto', 'FlutterTest', 'Segoe UI', '.SF UI Text', '.SF UI Display']) {
      await loadFont(family, malgun);
    }
    // 앱 글꼴. 테스트에서는 pubspec 의 글꼴이 자동으로 실리지 않아 직접 싣는다.
    await loadFont('Pretendard', [
      for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold'])
        'assets/fonts/Pretendard-$w.otf',
    ]);
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

    // 소개 첫 장은 금액이 매초 오르므로 pumpAndSettle 대신 시간을 지정해 넘긴다.
    /// 실제 화면처럼 16ms 프레임 단위로 시간을 흘린다. 한 번에 크게 넘기면
    /// 애니메이션이 그 프레임에서야 시작해 중간 모습을 찍을 수 없다.
    Future<void> play(int ms) async {
      for (var t = 0; t < ms; t += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> settlePage() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));
    }

    await tester.pumpWidget(SalaryFarmingApp(store: store));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    await shot(tester, '00a_intro_growing');
    // 2장: 항목이 하나씩 나오는 중간과 끝.
    await tester.tap(find.text('다음'));
    await play(450 + 1250);
    await shot(tester, '00b1_intro_benefit_mid');
    await play(3000);
    await shot(tester, '00b_intro_benefit');
    // 3장: 막대가 차오르는 중간과 끝.
    await tester.tap(find.text('다음'));
    await play(450 + 520);
    await shot(tester, '00c1_intro_stats_mid');
    await play(1600);
    await shot(tester, '00c_intro_stats');
    await tester.tap(find.text('내 정보 입력하기'));
    await tester.pumpAndSettle();
    await shot(tester, '01_onboard_job');
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await shot(tester, '02_onboard_pay');
    await tester.enterText(find.byKey(const ValueKey('payAmount')), '40000000');
    await tester.pumpAndSettle();
    await shot(tester, '02b_onboard_pay_filled');
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await shot(tester, '03_onboard_time');
    await tester.tap(find.text('출근'));
    await tester.pumpAndSettle();
    await shot(tester, '03b_time_wheel');
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정 완료'));
    await play(1000);
    await shot(tester, '04_onboard_loading');
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 700));
    }
    await tester.pumpAndSettle();
    await shot(tester, '05_onboard_ready');

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

    await tester.tap(find.text('월급파밍 시작하기'));
    await settlePage();
    await shot(tester, '06_home');
    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await settlePage();
    await shot(tester, '07_home_scrolled');

    // 홈의 노란 '직접 추가' 버튼이 혜택 만들기 시트를 바로 연다.
    await tester.tap(find.widgetWithText(FilledButton, '직접 추가'));
    await settlePage();
    await shot(tester, '08_template_sheet');
    await tester.tapAt(const Offset(200, 20));
    await settlePage();

    await tester.tap(find.text('수확 결산'));
    await tester.pumpAndSettle();
    await shot(tester, '09_stats_day');
    await tester.tap(find.text('주간'));
    await tester.pumpAndSettle();
    await shot(tester, '10_stats_week');
    await tester.tap(find.text('월간'));
    await tester.pumpAndSettle();
    await shot(tester, '11_stats_month');
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await shot(tester, '12_stats_month_scrolled');
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('연간'));
    await tester.pumpAndSettle();
    await shot(tester, '13_stats_year');

    await tester.scrollUntilVisible(
      find.text('결산 이미지 만들기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('결산 이미지 만들기'));
    await tester.pumpAndSettle();
    await shot(tester, '14_share');
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await shot(tester, '15_settings');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 시간대별 홈 모습: 평일 출근 전 · 평일 퇴근 후 · 주말.
  // (이름, 여는 시각, [(기록 시각, 혜택 id)])
  final scenes = <(String, DateTime, List<(DateTime, String)>)>[
    ('16_home_before_work', DateTime(2026, 11, 26, 8, 20), []),
    (
      '17_home_after_work',
      DateTime(2026, 11, 26, 19, 30),
      [
        (DateTime(2026, 11, 26, 9, 15), 'd_coffee'),
        (DateTime(2026, 11, 26, 12, 10), 'd_lunch'),
      ],
    ),
    (
      '18_home_weekend',
      DateTime(2026, 11, 28, 14, 0),
      [(DateTime(2026, 11, 28, 11, 20), 'd_coffee')],
    ),
  ];

  for (final (name, openAt, credits) in scenes) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = const Size(824, 1830);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});

      // 2026-11-02(월)에 처음 설정. 평일 9~18시, 점심 12~13시, 세전 연봉 4천만원.
      var now = DateTime(2026, 11, 2, 9, 0);
      final store = AppStore(clock: () => now);
      await store.load();
      await store.saveSettings(
        const WorkSettings(
          jobType: JobType.fullTime,
          payBasis: PayBasis.annualGross,
          payAmount: 40000000,
          nonTaxableMonthly: WorkSettings.defaultNonTaxableMonthly,
          workWeekdays: {1, 2, 3, 4, 5},
          startMinute: 9 * 60,
          endMinute: 18 * 60,
          breakStartMinute: 12 * 60,
          breakEndMinute: 13 * 60,
        ),
      );
      for (final (at, id) in credits) {
        now = at;
        await store.credit(store.templates.firstWhere((t) => t.id == id));
      }
      now = openAt;

      await tester.pumpWidget(SalaryFarmingApp(store: store));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      await shot(tester, name);
      await tester.drag(find.byType(ListView), const Offset(0, -620));
      await tester.pumpAndSettle();
      await shot(tester, '${name}_scrolled');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
