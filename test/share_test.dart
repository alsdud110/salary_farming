import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salary_farming/app_store.dart';
import 'package:salary_farming/format.dart';
import 'package:salary_farming/main.dart';
import 'package:salary_farming/models.dart';
import 'package:salary_farming/period.dart';
import 'package:salary_farming/screens/share_screen.dart';
import 'package:salary_farming/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 일부러 다른 금액과 겹치지 않는 급여로 둬서, 화면 어디에든 새면 바로 걸리게 한다.
const totals = PeriodTotals(salary: 3123457, benefit: 27500);

List<BenefitSummary> summaries() => [
  BenefitSummary(name: '점심 식대', icon: '🍱')
    ..count = 2
    ..amount = 20000,
  BenefitSummary(name: '탕비실 커피', icon: '☕')
    ..count = 3
    ..amount = 6000,
  BenefitSummary(name: '탕비실 간식', icon: '🍪')
    ..count = 1
    ..amount = 1500,
];

/// 급여를 드러내거나 짐작하게 하는 글자들.
final salaryLeaks = [
  won(totals.salary),
  won(totals.total),
  '기본 수익',
  '총 수확',
  '%',
  '월급만으로',
  '월급 밖에서',
];

/// [root] 아래에 그려진 모든 글자(Text·RichText 모두).
List<String> textsUnder(Finder root) => find
    .descendant(of: root, matching: find.byType(RichText))
    .evaluate()
    .map((e) => (e.widget as RichText).text.toPlainText())
    .toList();

Future<void> pumpCard(
  WidgetTester tester,
  ShareScope scope, {
  Period? period,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SettlementCard(
            period:
                period ??
                Period.containing(PeriodKind.month, DateTime(2026, 11, 26)),
            totals: totals,
            summaries: summaries(),
            scope: scope,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('파밍 일지 문구', () {
    test('파밍 수익만 공유할 때는 급여 금액·비중 문구를 뺀다', () {
      final lines = buildInsights(totals, summaries(), includeSalary: false);
      expect(lines, isNotEmpty);
      for (final line in lines) {
        for (final leak in salaryLeaks) {
          expect(line, isNot(contains(leak)), reason: line);
        }
      }
    });

    test('파밍이 없으면 급여만 말하는 문구도 내지 않는다', () {
      const onlySalary = PeriodTotals(salary: 3123457, benefit: 0);
      expect(buildInsights(onlySalary, [], includeSalary: false), isEmpty);
      expect(buildInsights(onlySalary, []).single, contains('월급만으로'));
    });

    test('전체 수익 문구는 예전과 같다', () {
      final lines = buildInsights(totals, summaries());
      expect(lines, hasLength(3));
      expect(lines.last, contains('%는 월급 밖에서'));
    });
  });

  group('결산 카드', () {
    testWidgets('파밍 수익만: 급여를 짐작할 정보가 없다', (tester) async {
      await pumpCard(tester, ShareScope.benefitOnly);
      final texts = textsUnder(find.byType(SettlementCard));
      final all = texts.join('\n');
      for (final leak in salaryLeaks) {
        expect(all, isNot(contains(leak)), reason: leak);
      }
      // 파밍 수익이 가장 큰 글자
      final hero = tester.widget<Text>(find.text('+27,500원'));
      final heroSize = hero.style!.fontSize!;
      for (final e
          in find
              .descendant(
                of: find.byType(SettlementCard),
                matching: find.byType(Text),
              )
              .evaluate()) {
        final size = (e.widget as Text).style?.fontSize ?? 0;
        expect(size, lessThanOrEqualTo(heroSize));
      }
      expect(all, contains('파밍 횟수'));
      expect(all, contains('6번'));
      expect(all, contains('3가지'));
      expect(all, contains('많이 파밍한 혜택'));
      for (final name in ['점심 식대', '탕비실 커피', '탕비실 간식']) {
        expect(all, contains(name));
      }
      expect(all, contains('파밍 일지'));
      expect(all, contains('탕비실 커피만 3번'));
    });

    testWidgets('전체 수익: 기존 구조 그대로', (tester) async {
      await pumpCard(tester, ShareScope.all);
      final all = textsUnder(find.byType(SettlementCard)).join('\n');
      expect(all, contains('2026년 11월 총 수확'));
      expect(all, contains(won(totals.total)));
      expect(all, contains('기본 수익'));
      expect(all, contains(won(totals.salary)));
      expect(all, contains('+27,500원'));
      expect(all, contains('많이 파밍한 혜택'));
      // 파밍 일지는 예전처럼 첫 줄 하나
      expect(all, contains('탕비실 커피만 3번'));
      expect(all, isNot(contains('치킨')));
      expect(all, isNot(contains('파밍 횟수')));
    });

    testWidgets('일간·주간·월간·연간 모두 두 유형으로 그려진다', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      for (final kind in PeriodKind.values) {
        final period = Period.containing(kind, DateTime(2026, 11, 26));
        for (final scope in ShareScope.values) {
          await pumpCard(tester, scope, period: period);
          expect(tester.takeException(), isNull, reason: '$kind $scope');
          final all = textsUnder(find.byType(SettlementCard)).join('\n');
          expect(all, contains('${kind.label} 수확 결산'));
          expect(all, contains(period.label));
          if (scope == ShareScope.benefitOnly) {
            expect(all, isNot(contains(won(totals.salary))));
          }
        }
      }
    });
  });

  group('결산 이미지 화면', () {
    Future<Uint8List> capture(WidgetTester tester) async {
      // 저장·공유가 찍는 경계: 카드를 감싼 RepaintBoundary
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find
            .ancestor(
              of: find.byType(SettlementCard),
              matching: find.byType(RepaintBoundary),
            )
            .first,
      );
      return (await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      }))!;
    }

    testWidgets('기본은 파밍 수익만, 바꾸면 미리보기와 찍히는 이미지가 즉시 바뀐다', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: ShareScreen(
            period: Period.containing(PeriodKind.week, DateTime(2026, 11, 26)),
            totals: totals,
            summaries: summaries(),
          ),
        ),
      );
      await tester.pump();

      SettlementCard card() => tester.widget(find.byType(SettlementCard));
      String shown() => textsUnder(find.byType(SettlementCard)).join('\n');

      expect(card().scope, ShareScope.benefitOnly);
      expect(shown(), isNot(contains(won(totals.salary))));
      final benefitImage = await capture(tester);

      await tester.tap(find.text('전체 수익'));
      await tester.pump();
      expect(card().scope, ShareScope.all);
      expect(shown(), contains(won(totals.salary)));
      final allImage = await capture(tester);
      expect(allImage, isNot(equals(benefitImage)));

      await tester.tap(find.text('파밍 수익만'));
      await tester.pump();
      expect(shown(), isNot(contains(won(totals.salary))));
      expect(await capture(tester), equals(benefitImage));
    });

    testWidgets('앱 흐름: 수확 결산에서 연 이미지는 급여를 숨긴다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final store = AppStore(clock: () => DateTime(2026, 11, 26, 15, 0));
      await store.load();
      await store.saveSettings(
        const WorkSettings(
          payAmount: 3000000,
          payBasis: PayBasis.monthlyNet,
          workWeekdays: {1, 2, 3, 4, 5},
          startMinute: 9 * 60,
          endMinute: 18 * 60,
          breakStartMinute: 12 * 60,
          breakEndMinute: 13 * 60,
        ),
      );
      final coffee = store.templates.firstWhere((t) => t.id == 'd_coffee');
      await store.credit(coffee);
      await store.credit(coffee);

      await tester.pumpWidget(SalaryFarmingApp(store: store));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('수확 결산'));
      await tester.pumpAndSettle();
      final today = store.totals(
        DateTime(2026, 11, 26),
        DateTime(2026, 11, 26),
        at: store.now(),
      );
      expect(today.salary, greaterThan(0));

      await tester.scrollUntilVisible(
        find.text('결산 이미지 만들기'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('결산 이미지 만들기'));
      await tester.pumpAndSettle();

      final all = textsUnder(find.byType(SettlementCard)).join('\n');
      expect(all, contains('+4,000원'));
      expect(all, contains('2번'));
      expect(all, isNot(contains(won(today.salary))));
      expect(all, isNot(contains(won(today.total))));
      expect(all, isNot(contains('기본 수익')));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
