import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:salary_farming/app_store.dart';
import 'package:salary_farming/main.dart';
import 'package:salary_farming/models.dart';
import 'package:salary_farming/period.dart';
import 'package:salary_farming/screens/share_screen.dart';
import 'package:salary_farming/screens/splash_screen.dart';
import 'package:salary_farming/theme.dart';
import 'package:salary_farming/widgets/brand_symbol.dart';
import 'package:shared_preferences/shared_preferences.dart';

const office = WorkSettings(
  payAmount: 3000000,
  payBasis: PayBasis.monthlyNet,
  workWeekdays: {1, 2, 3, 4, 5},
  startMinute: 9 * 60,
  endMinute: 18 * 60,
  breakStartMinute: 12 * 60,
  breakEndMinute: 13 * 60,
);

void setView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

void main() {
  group('브랜드 심볼 에셋', () {
    final file = File(BrandSymbol.asset);

    test('pubspec에 등록되어 있다', () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/images/brand/'),
      );
      expect(file.existsSync(), isTrue);
    });

    test('투명 배경이고, 불필요한 투명 여백이 없으며, 위젯 비율과 같다', () {
      final image = img.decodePng(file.readAsBytesSync())!;
      expect(image.numChannels, 4);
      expect(
        image.width / image.height,
        closeTo(BrandSymbol.aspectRatio, 1e-6),
      );
      // 네 모서리는 투명
      for (final (x, y) in [
        (0, 0),
        (image.width - 1, 0),
        (0, image.height - 1),
        (image.width - 1, image.height - 1),
      ]) {
        expect(image.getPixel(x, y).a, 0);
      }
      // 네 변 모두 8픽셀 안쪽에 보이는 그림이 닿아 있다(여백을 잘라 냈다).
      bool visibleRow(int y) =>
          [for (var x = 0; x < image.width; x++) image.getPixel(x, y).a > 8]
              .contains(true);
      bool visibleCol(int x) =>
          [for (var y = 0; y < image.height; y++) image.getPixel(x, y).a > 8]
              .contains(true);
      expect([for (var y = 0; y < 8; y++) visibleRow(y)], contains(true));
      expect([
        for (var y = image.height - 8; y < image.height; y++) visibleRow(y),
      ], contains(true));
      expect([for (var x = 0; x < 8; x++) visibleCol(x)], contains(true));
      expect([
        for (var x = image.width - 8; x < image.width; x++) visibleCol(x),
      ], contains(true));
    });
  });

  testWidgets('BrandSymbol: 비율대로 그리고 색 필터·배경을 얹지 않는다', (tester) async {
    await tester.pumpWidget(const Center(child: BrandSymbol(size: 100)));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.color, isNull);
    expect(image.colorBlendMode, isNull);
    expect(image.fit, BoxFit.contain);
    expect(
      tester.getSize(find.byType(Image)),
      const Size(100 * BrandSymbol.aspectRatio, 100),
    );
    expect(find.byType(DecoratedBox), findsNothing);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  group('화면별 적용', () {
    Future<AppStore> openApp(WidgetTester tester, {bool setup = true}) async {
      SharedPreferences.setMockInitialValues({});
      setView(tester);
      final store = AppStore(clock: () => DateTime(2026, 11, 26, 11, 0));
      await store.load();
      if (setup) await store.saveSettings(office);
      await tester.pumpWidget(SalaryFarmingApp(store: store));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      return store;
    }

    testWidgets('홈: 월급파밍 왼쪽, 30dp, 글자와 세로 가운데 정렬', (tester) async {
      await openApp(tester);
      final symbol = find.byType(BrandSymbol);
      expect(symbol, findsOneWidget);
      expect(tester.widget<BrandSymbol>(symbol).size, inInclusiveRange(28, 32));
      final title = find.text('월급파밍').first;
      expect(
        tester.getCenter(symbol).dy,
        closeTo(tester.getCenter(title).dy, 1),
      );
      expect(
        tester.getRect(symbol).right,
        lessThan(tester.getRect(title).left),
      );
      expect(find.byIcon(Icons.eco), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('설정: 앱 정보 영역에 있다', (tester) async {
      await openApp(tester);
      await tester.tap(find.text('설정').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.scrollUntilVisible(
        find.text('Salary Farming 1.0.0'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final symbol = find.byType(BrandSymbol);
      expect(symbol, findsOneWidget);
      expect(
        tester.getRect(symbol).bottom,
        lessThan(tester.getRect(find.text('Salary Farming 1.0.0')).top),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('온보딩: 첫 소개 장과 세팅 완료 화면에 80~120dp로 있다', (tester) async {
      await openApp(tester, setup: false);
      final intro = find.byType(BrandSymbol);
      expect(intro, findsOneWidget);
      expect(tester.widget<BrandSymbol>(intro).size, inInclusiveRange(80, 120));

      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle();
      expect(find.byType(BrandSymbol), findsNothing);
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('payAmount')),
        '40000000',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('설정 완료'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 700));
      }
      await tester.pumpAndSettle();
      expect(find.text('월급파밍을 시작할까요?'), findsOneWidget);
      final ready = find.byType(BrandSymbol);
      expect(ready, findsOneWidget);
      expect(tester.widget<BrandSymbol>(ready).size, inInclusiveRange(80, 120));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('결산 공유 이미지: 아래쪽에 심볼과 월급파밍', (tester) async {
      setView(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettlementCard(
                period: Period.containing(
                  PeriodKind.month,
                  DateTime(2026, 11, 26),
                ),
                totals: const PeriodTotals(salary: 3000000, benefit: 12000),
                summaries: [
                  BenefitSummary(name: '탕비실 커피', icon: '☕')
                    ..count = 6
                    ..amount = 12000,
                ],
              ),
            ),
          ),
        ),
      );
      final card = find.byType(SettlementCard);
      final symbol = find.descendant(
        of: card,
        matching: find.byType(BrandSymbol),
      );
      expect(symbol, findsOneWidget);
      final footer = find.descendant(
        of: card,
        matching: find.textContaining('월급파밍', findRichText: true),
      );
      expect(footer, findsOneWidget);
      // 카드 맨 아래, 심볼과 글자가 한 줄
      expect(
        tester.getRect(symbol).bottom,
        closeTo(tester.getRect(card).bottom, 40),
      );
      expect(
        tester.getCenter(symbol).dy,
        closeTo(tester.getCenter(footer).dy, 1),
      );
    });

    testWidgets('스플래시: 가운데 112dp 심볼과 월급파밍이 fade in 된 뒤 첫 화면으로', (tester) async {
      SharedPreferences.setMockInitialValues({});
      setView(tester);
      final store = AppStore(clock: () => DateTime(2026, 11, 26, 11, 0));
      await store.load();
      await store.saveSettings(office);
      await tester.pumpWidget(SalaryFarmingApp(store: store, splash: true));

      final splash = find.byType(SplashScreen);
      expect(splash, findsOneWidget);
      final symbol = find.descendant(
        of: splash,
        matching: find.byType(BrandSymbol),
      );
      expect(
        tester.widget<BrandSymbol>(symbol).size,
        inInclusiveRange(100, 120),
      );
      final label = find.descendant(of: splash, matching: find.text('월급파밍'));
      expect(
        tester.getRect(label).top,
        greaterThan(tester.getRect(symbol).bottom),
      );
      final screen = tester.getSize(splash);
      expect(tester.getCenter(symbol).dx, closeTo(screen.width / 2, 1));
      final scaffold = tester.widget<Scaffold>(
        find.descendant(of: splash, matching: find.byType(Scaffold)),
      );
      expect(scaffold.backgroundColor, AppColors.paper);

      double opacity() => tester
          .widget<FadeTransition>(
            find
                .ancestor(of: symbol, matching: find.byType(FadeTransition))
                .first,
          )
          .opacity
          .value;
      expect(opacity(), lessThan(0.1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacity(), inExclusiveRange(0.1, 1));
      await tester.pump(SplashScreen.fadeIn);
      expect(opacity(), 1);

      await tester.pump(SplashScreen.hold);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('오늘의 총 수확'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
