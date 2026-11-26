// App Store 제출용 스크린샷. 일반 테스트에는 포함되지 않는다.
//   flutter test tool/appstore_shots_test.dart --update-goldens
// 결과는 tool/appstore/iphone/, tool/appstore/ipad/ 에 생긴다.
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
    loader.addFont(Future.value(ByteData.view(File(p).readAsBytesSync().buffer)));
  }
  await loader.load();
}

/// 금액이 늘 올라 pumpAndSettle 이 끝나지 않으므로 시간을 정해 넘긴다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 화면에 있는 그림(브랜드 심볼·혜택 아이콘)을 실제로 다 읽은 뒤 찍는다.
Future<void> loadImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await settle(tester);
}

/// (폴더, 논리 크기, 배율, 위·아래 안전 영역). 물리 픽셀이 App Store 규격과 같다.
const devices = [
  ('iphone', Size(440, 956), 3.0, 62.0, 34.0), // 6.9" 1320×2868
  ('ipad', Size(1032, 1376), 2.0, 24.0, 20.0), // 13" 2064×2752
];

const office = WorkSettings(
  jobType: JobType.fullTime,
  payBasis: PayBasis.annualGross,
  payAmount: 40000000,
  nonTaxableMonthly: WorkSettings.defaultNonTaxableMonthly,
  workWeekdays: {1, 2, 3, 4, 5},
  startMinute: 9 * 60,
  endMinute: 18 * 60,
  breakStartMinute: 12 * 60,
  breakEndMinute: 13 * 60,
);

void main() {
  setUpAll(() async {
    final pretendard = [
      for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) 'assets/fonts/Pretendard-$w.otf',
    ];
    for (final family in ['Roboto', 'FlutterTest', '.SF UI Text', '.SF UI Display', 'Pretendard']) {
      await loadFont(family, pretendard);
    }
    final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
    await loadFont('MaterialIcons', [
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  });

  /// 11/2(월)부터 26일까지 평일마다 커피·점심, 이틀에 한 번 간식, 닷새에 한 번 헬스장.
  Future<AppStore> farmedStore({bool dark = false}) async {
    SharedPreferences.setMockInitialValues({if (dark) 'flutter.dark_theme': true});
    var now = DateTime(2026, 11, 2, 9);
    final store = AppStore(clock: () => now);
    await store.load();
    await store.saveSettings(office);
    BenefitTemplate t(String id) => store.templates.firstWhere((e) => e.id == id);
    for (var day = 2; day <= 26; day++) {
      if (DateTime(2026, 11, day).weekday > 5) continue;
      now = DateTime(2026, 11, day, 9, 20);
      await store.credit(t('d_coffee'));
      now = DateTime(2026, 11, day, 12, 5);
      await store.credit(t('d_lunch'));
      if (day.isEven) {
        now = DateTime(2026, 11, day, 15, 30);
        await store.credit(t('d_snack'));
      }
      if (day % 5 == 0) {
        now = DateTime(2026, 11, day, 19);
        await store.credit(t('d_gym'));
      }
    }
    now = DateTime(2026, 11, 26, 16, 42, 18); // 근무 중, 오늘 커피·점심·간식 적립
    return store;
  }

  for (final (folder, size, ratio, top, bottom) in devices) {
    void setDevice(WidgetTester tester) {
      tester.view.physicalSize = size * ratio;
      tester.view.devicePixelRatio = ratio;
      tester.view.padding = FakeViewPadding(top: top * ratio, bottom: bottom * ratio);
      tester.view.viewPadding = FakeViewPadding(top: top * ratio, bottom: bottom * ratio);
      addTearDown(tester.view.reset);
    }

    Future<void> shot(String name) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('appstore/$folder/$name.png'),
    );

    testWidgets('$folder light', (tester) async {
      setDevice(tester);
      final store = await farmedStore();
      await tester.pumpWidget(SalaryFarmingApp(store: store));
      await settle(tester);
      await loadImages(tester);
      await shot('1_home');

      // 초록 카드를 지나 '오늘의 근무' 제목이 맨 위에 오게. 목록이 짧아 끝까지 내리면 제목이 반쯤 잘린다.
      final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      if (position.maxScrollExtent > 0) {
        position.jumpTo(328.clamp(0, position.maxScrollExtent).toDouble());
        await settle(tester);
        await loadImages(tester);
        await shot('2_home_farming');
      } else {
        // 아이패드처럼 홈이 한 화면에 다 들어오면 1번과 같아지므로 전체 혜택 시트를 찍는다.
        await tester.tap(find.text('전체 보기'));
        await settle(tester);
        await loadImages(tester);
        await shot('2_home_farming');
        await tester.tapAt(const Offset(20, 20));
        await settle(tester);
      }

      await tester.tap(find.text('수확 결산'));
      await settle(tester);
      await tester.tap(find.text('주간'));
      await settle(tester);
      await loadImages(tester);
      await shot('3_stats_week');
      await tester.tap(find.text('월간'));
      await settle(tester);
      await shot('4_stats_month');

      await tester.scrollUntilVisible(
        find.text('결산 이미지 만들기'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      await tester.tap(find.text('결산 이미지 만들기'));
      await settle(tester);
      await loadImages(tester);
      await shot('5_share');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('$folder dark', (tester) async {
      setDevice(tester);
      final store = await farmedStore(dark: true);
      await tester.pumpWidget(SalaryFarmingApp(store: store));
      await settle(tester);
      await loadImages(tester);
      await shot('6_dark_home');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
