import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salary_farming/app_store.dart';
import 'package:salary_farming/format.dart';
import 'package:salary_farming/main.dart';
import 'package:salary_farming/models.dart';
import 'package:salary_farming/widgets/benefit_glyph.dart';
import 'package:salary_farming/widgets/farm_charts.dart';
import 'package:salary_farming/widgets/top_benefits.dart';
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

void main() {
  test('파밍 밭 단계: 없음 0, 가장 많은 날 4, 조금이라도 있으면 1 이상', () {
    expect(farmLevel(0, 10000), 0);
    expect(farmLevel(10000, 10000), 4);
    expect(farmLevel(100, 10000), 1);
    expect(farmLevel(5000, 10000), 2);
    expect(farmLevel(100, 0), 0);
  });

  test('짧은 금액 표기', () {
    expect(shortWon(2000), '2,000');
    expect(shortWon(10000), '1만');
    expect(shortWon(12000), '1.2만');
    expect(shortWon(263000), '26만');
  });

  testWidgets('수확 결산: 파밍 수익이 맨 위, 기간마다 다른 그림, 1~3위 칸 + 4위부터 목록', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    var now = DateTime(2026, 11, 2, 9, 0);
    final store = AppStore(clock: () => now);
    await store.load();
    await store.saveSettings(office);
    BenefitTemplate t(String id) =>
        store.templates.firstWhere((t) => t.id == id);
    // 어제(25일) 커피 한 번, 오늘(26일) 커피·점심·간식·음료
    now = DateTime(2026, 11, 25, 10);
    await store.credit(t('d_coffee'));
    for (final (h, id) in [
      (9, 'd_coffee'),
      (12, 'd_lunch'),
      (15, 'd_snack'),
      (16, 'd_drink'),
    ]) {
      now = DateTime(2026, 11, 26, h);
      await store.credit(t(id));
    }
    now = DateTime(2026, 11, 26, 19, 30);

    await tester.pumpWidget(SalaryFarmingApp(store: store));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('수확 결산'));
    await tester.pumpAndSettle();

    // 일간: 오늘 15,000원, 어제 2,000원보다 13,000원 더
    expect(find.text('파밍 수익'), findsOneWidget);
    expect(find.text('+15,000원'), findsOneWidget);
    expect(find.text('어제보다 +13,000원 더 챙겼어요'), findsOneWidget);
    expect(find.text('총 수확'), findsOneWidget);
    expect(find.text('오늘의 파밍'), findsOneWidget);
    expect(find.byType(DayTimeline), findsOneWidget);
    expect(find.textContaining('가장 많은 구간'), findsNothing);

    await tester.scrollUntilVisible(
      find.byType(TopBenefitRow),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    // 금액순: 점심 10,000 · 커피 2,000 · 간식 1,500 → 칸, 음료 1,500 → 목록
    final row = find.byType(TopBenefitRow);
    for (final name in ['점심 식대', '탕비실 커피', '탕비실 간식']) {
      expect(
        find.descendant(of: row, matching: find.text(name)),
        findsOneWidget,
      );
    }
    expect(find.descendant(of: row, matching: find.text('음료수')), findsNothing);
    expect(find.text('음료수'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    for (final (tab, title, type) in [
      ('주간', '요일별 파밍', WeekStacks),
      ('월간', '11월 파밍 밭', FarmField),
      ('연간', '달마다 파밍', YearGrid),
    ]) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget, reason: tab);
      expect(find.byType(type), findsOneWidget, reason: tab);
      expect(tester.takeException(), isNull, reason: tab);
    }
    // 연간: 11월만 기록, 그 전·뒤 달은 빈칸
    final year = tester.widget<YearGrid>(find.byType(YearGrid));
    expect(year.amounts[10], 17000);
    expect(year.amounts[9], isNull);
    expect(year.amounts[11], isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('일간: 가까운 시각은 아이콘 하나 + 개수 배지, 누르면 펼쳐지고 다시 누르면 접힌다', (
    tester,
  ) async {
    final records = [
      for (final (i, (name, icon, amount, h, m)) in [
        ('탕비실 커피', '☕', 2000, 9, 10),
        ('점심 식대', '🍱', 10000, 12, 0),
        ('탕비실 간식', '🍪', 1500, 12, 5),
        ('음료수', '🥤', 1500, 12, 15),
      ].indexed)
        BenefitRecord(
          id: 'r$i',
          templateId: 't$i',
          name: name,
          icon: icon,
          amount: amount,
          at: DateTime(2026, 11, 26, h, m),
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: DayTimeline(
              records: records,
              startMinute: 9 * 60,
              endMinute: 18 * 60,
            ),
          ),
        ),
      ),
    );
    // 9:10 하나, 12시대 셋은 한 묶음(배지 3)
    expect(find.text('3'), findsOneWidget);
    // 묶음마다 아래 금액
    expect(find.text('2,000'), findsOneWidget);
    expect(find.text('1.3만'), findsOneWidget);
    expect(find.text('탕비실 간식'), findsNothing);

    await tester.tap(find.bySemanticsLabel(RegExp('점심 식대 외 2개')));
    await tester.pumpAndSettle();
    for (final name in ['점심 식대', '탕비실 간식', '음료수']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('오후 12:05'), findsOneWidget);
    expect(find.text('+10,000원'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('점심 식대 외 2개')));
    await tester.pumpAndSettle();
    expect(find.text('탕비실 간식'), findsNothing);
  });

  testWidgets('주간: 2개 이상인 날은 쌓지 않고 아이콘 하나 + 개수, 누르면 펼쳐진다', (tester) async {
    BenefitRecord r(int id, String name, String icon, int amount, int day) =>
        BenefitRecord(
          id: 'r$id',
          templateId: 't$id',
          name: name,
          icon: icon,
          amount: amount,
          at: DateTime(2026, 11, day, 9 + id),
        );
    final monday = DateTime(2026, 11, 23);
    final records = {
      23: [r(1, '탕비실 커피', '☕', 2000, 23)],
      24: [
        r(2, '점심 식대', '🍱', 10000, 24),
        r(3, '탕비실 간식', '🍪', 1500, 24),
        r(4, '음료수', '🥤', 1500, 24),
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: WeekStacks(
              days: [
                for (var i = 0; i < 7; i++)
                  (
                    DateTime(2026, 11, monday.day + i),
                    records[monday.day + i] ?? <BenefitRecord>[],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    // 화요일 3개는 아이콘 하나(점심) + 배지 3, 쌓인 아이콘 없음
    expect(find.text('3'), findsOneWidget);
    expect(find.byType(BenefitGlyph), findsNWidgets(2));
    expect(find.text('1.3만'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('점심 식대 외 2개')));
    await tester.pumpAndSettle();
    for (final name in ['점심 식대', '탕비실 간식', '음료수']) {
      expect(find.text(name), findsOneWidget);
    }
    // 다른 요일을 누르면 그날로 바뀐다
    await tester.tap(find.bySemanticsLabel(RegExp('탕비실 커피')));
    await tester.pumpAndSettle();
    expect(find.text('탕비실 커피'), findsOneWidget);
    expect(find.text('음료수'), findsNothing);
  });

  testWidgets('작은 화면·큰 글자에서도 결산 그림이 넘치지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var now = DateTime(2026, 11, 26, 12);
    final store = AppStore(clock: () => now);
    await store.load();
    await store.saveSettings(office);
    for (final id in [
      'd_coffee',
      'd_lunch',
      'd_snack',
      'd_drink',
      'd_coffee',
    ]) {
      await store.credit(store.templates.firstWhere((t) => t.id == id));
    }
    now = DateTime(2026, 11, 26, 19, 30);
    await tester.pumpWidget(SalaryFarmingApp(store: store));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('수확 결산').last);
    await tester.pumpAndSettle();
    for (final tab in ['일간', '주간', '월간', '연간']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
