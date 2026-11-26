import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:salary_farming/app_store.dart';
import 'package:salary_farming/main.dart';
import 'package:salary_farming/models.dart';
import 'package:salary_farming/period.dart';
import 'package:salary_farming/screens/share_screen.dart';
import 'package:salary_farming/theme.dart';
import 'package:salary_farming/widgets/theme_toggle_tile.dart';
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

Future<AppStore> openApp(WidgetTester tester, {bool dark = false}) async {
  SharedPreferences.setMockInitialValues({'flutter.dark_theme': dark});
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  // 퇴근 후라 금액이 멈춰 있다.
  final store = AppStore(clock: () => DateTime(2026, 11, 26, 19, 30));
  await store.load();
  await store.saveSettings(office);
  await tester.pumpWidget(SalaryFarmingApp(store: store));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return store;
}

Brightness shownBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.text('수확 결산').last)).brightness;

void main() {
  test('테마 저장: 기본 라이트, 바꾸면 다시 열어도 유지, 데이터 지우기에도 남음', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(clock: () => DateTime(2026, 11, 26, 11));
    await store.load();
    expect(store.darkTheme, isFalse);
    await store.toggleTheme();
    final reopened = AppStore(clock: () => DateTime(2026, 11, 26, 11));
    await reopened.load();
    expect(reopened.darkTheme, isTrue);
    await reopened.resetAll();
    final again = AppStore(clock: () => DateTime(2026, 11, 26, 11));
    await again.load();
    expect(again.darkTheme, isTrue);
  });

  test('다크 팔레트: 바탕 위 글자는 대비 기준(AA)을 넘는다', () {
    double lum(Color c) => c.computeLuminance();
    double ratio(Color a, Color b) {
      final (hi, lo) = lum(a) > lum(b) ? (a, b) : (b, a);
      return (lum(hi) + 0.05) / (lum(lo) + 0.05);
    }

    const d = AppPalette.dark;
    for (final bg in [d.paper, d.card]) {
      expect(ratio(d.ink, bg), greaterThan(7));
      expect(ratio(d.inkSoft, bg), greaterThan(4.5));
      expect(ratio(d.fieldText, bg), greaterThan(4.5));
      expect(ratio(d.benefitInk, bg), greaterThan(4.5));
      expect(ratio(d.danger, bg), greaterThan(4.5));
    }
    expect(ratio(Colors.white, d.inverse), greaterThan(4.5));
  });

  testWidgets('설정의 테마 버튼: 로티와 함께 라이트 ↔ 다크, 앱 전체가 바뀐다', (tester) async {
    final store = await openApp(tester);
    expect(shownBrightness(tester), Brightness.light);

    await tester.tap(find.text('설정').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('라이트 모드'), findsOneWidget);
    final lottie = find.descendant(
      of: find.byType(ThemeToggleTile),
      matching: find.byType(Lottie),
    );
    expect(lottie, findsOneWidget);

    await tester.tap(find.byType(ThemeToggleTile));
    await tester.pumpAndSettle();
    expect(store.darkTheme, isTrue);
    expect(find.text('다크 모드'), findsOneWidget);
    expect(shownBrightness(tester), Brightness.dark);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor ??
          Theme.of(tester.element(find.byType(Scaffold).first))
              .scaffoldBackgroundColor,
      AppPalette.dark.paper,
    );
    // 탭은 그대로 설정에 머문다.
    expect(find.byType(ThemeToggleTile), findsOneWidget);

    await tester.tap(find.byType(ThemeToggleTile));
    await tester.pumpAndSettle();
    expect(store.darkTheme, isFalse);
    expect(shownBrightness(tester), Brightness.light);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('다크: 홈·수확 결산·설정의 글자 대비 AA, 넘침 없음', (tester) async {
    await openApp(tester, dark: true);
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    for (final tab in ['수확 결산', '설정']) {
      await tester.tap(find.text(tab).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(
        tester,
        meetsGuideline(textContrastGuideline),
        reason: tab,
      );
    }
    expect(tester.takeException(), isNull);
    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('다크: 온보딩·혜택 만들기 시트·혜택 템플릿도 대비 AA', (tester) async {
    SharedPreferences.setMockInitialValues({'flutter.dark_theme': true});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final store = AppStore(clock: () => DateTime(2026, 11, 26, 19, 30));
    await store.load();
    await tester.pumpWidget(SalaryFarmingApp(store: store));
    await tester.pump();
    final handle = tester.ensureSemantics();
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
    await expectLater(
      tester,
      meetsGuideline(textContrastGuideline),
      reason: '직업',
    );
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('payAmount')), '40000000');
    await tester.pumpAndSettle();
    await expectLater(
      tester,
      meetsGuideline(textContrastGuideline),
      reason: '급여',
    );
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await expectLater(
      tester,
      meetsGuideline(textContrastGuideline),
      reason: '근무 시간',
    );
    await tester.tap(find.text('설정 완료'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 700));
    }
    await tester.pumpAndSettle();
    await expectLater(
      tester,
      meetsGuideline(textContrastGuideline),
      reason: '세팅 완료',
    );
    await tester.tap(find.text('월급파밍 시작하기'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('설정').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('혜택 템플릿'));
    await tester.pumpAndSettle();
    await expectLater(
      tester,
      meetsGuideline(textContrastGuideline),
      reason: '템플릿',
    );
    await tester.tap(find.text('직접 만들기'));
    await tester.pumpAndSettle();
    await expectLater(
      tester,
      meetsGuideline(textContrastGuideline),
      reason: '시트',
    );
    expect(tester.takeException(), isNull);
    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('다크에서도 공유 이미지는 밝은 결산 카드', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(dark: true),
        home: ShareScreen(
          period: Period.containing(PeriodKind.month, DateTime(2026, 11, 26)),
          totals: const PeriodTotals(salary: 3000000, benefit: 12000),
          summaries: [
            BenefitSummary(name: '탕비실 커피', icon: '☕')
              ..count = 6
              ..amount = 12000,
          ],
        ),
      ),
    );
    await tester.pump();
    final card = tester.element(find.byType(SettlementCard));
    expect(Theme.of(card).brightness, Brightness.light);
    expect(card.colors.paper, AppColors.paper);
  });
}
