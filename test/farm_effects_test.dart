import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salary_farming/app_store.dart';
import 'package:salary_farming/format.dart';
import 'package:salary_farming/main.dart';
import 'package:salary_farming/models.dart';
import 'package:salary_farming/screens/home_screen.dart';
import 'package:salary_farming/widgets/farm_burst.dart';
import 'package:shared_preferences/shared_preferences.dart';

final coffeeTile = find.widgetWithText(BenefitTile, '탕비실 커피');

/// 평일 9~18시, 점심 12~13시, 월급 300만원.
const office = WorkSettings(
  payAmount: 3000000,
  payBasis: PayBasis.monthlyNet,
  workWeekdays: {1, 2, 3, 4, 5},
  startMinute: 9 * 60,
  endMinute: 18 * 60,
  breakStartMinute: 12 * 60,
  breakEndMinute: 13 * 60,
);

BenefitTemplate template(String name, String icon, {int amount = 3000}) =>
    BenefitTemplate(
      id: 't_$name',
      name: name,
      icon: icon,
      amount: amount,
      category: BenefitCategory.custom,
      frequency: UseFrequency.often,
    );

void main() {
  group('상황별 파밍 문구', () {
    test('커피·식대·간식은 상황에 맞게, 나머지는 이름으로', () {
      expect(farmMessage(template('탕비실 커피', '☕')), '커피 한 잔 파밍 완료!');
      expect(farmMessage(template('아이스 라떼', '🧋')), '커피 한 잔 파밍 완료!');
      expect(farmMessage(template('점심 식대', '🍱')), '오늘의 점심도 수확했어요!');
      expect(farmMessage(template('저녁 식사', '🍜')), '오늘의 점심도 수확했어요!');
      expect(farmMessage(template('탕비실 간식', '🍪')), '소소한 행복 +1');
      expect(
        farmMessage(template('사내 헬스장', '🏋️', amount: 5000)),
        '사내 헬스장 +5,000원 파밍했어요',
      );
    });
  });

  group('파밍 효과 설정 저장', () {
    test('기본은 모두 켜짐, 바꾸면 다시 열어도 유지, 모든 데이터 지우기에도 남음', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(clock: () => DateTime(2026, 11, 26, 11));
      await store.load();
      expect(store.farmAnimation, isTrue);
      expect(store.farmHaptic, isTrue);

      await store.setFarmAnimation(false);
      await store.setFarmHaptic(false);
      final reopened = AppStore(clock: () => DateTime(2026, 11, 26, 11));
      await reopened.load();
      expect(reopened.farmAnimation, isFalse);
      expect(reopened.farmHaptic, isFalse);

      await reopened.resetAll();
      final again = AppStore(clock: () => DateTime(2026, 11, 26, 11));
      await again.load();
      expect(again.farmAnimation, isFalse);
      expect(again.isSetupDone, isFalse);
    });
  });

  group('홈 적립 효과', () {
    Future<AppStore> openHome(
      WidgetTester tester, {
      bool animation = true,
      bool haptic = true,
    }) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final store = AppStore(clock: () => DateTime(2026, 11, 26, 11, 0));
      await store.load();
      await store.saveSettings(office);
      await store.setFarmAnimation(animation);
      await store.setFarmHaptic(haptic);
      await tester.pumpWidget(SalaryFarmingApp(store: store));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.ensureVisible(coffeeTile);
      await tester.pump(const Duration(milliseconds: 300));
      return store;
    }

    /// 수확 카드의 파밍 수익 표시(첫 번째 '+...원' 또는 '0원').
    String shownBenefit(WidgetTester tester) {
      final card = find.ancestor(
        of: find.text('파밍 수익'),
        matching: find.byType(Column),
      );
      return tester
          .widgetList<Text>(
            find.descendant(of: card.first, matching: find.byType(Text)),
          )
          .map((t) => t.data!)
          .firstWhere((d) => d.endsWith('원'));
    }

    String expectedTotal(AppStore store, int benefit) {
      final n = store.now();
      return '${comma((store.salaryOn(n, n) + benefit).floor())}원';
    }

    testWidgets('연속으로 눌러도 누른 만큼만 저장되고, 효과는 3개까지만 겹치며 금액이 정확히 맞는다', (
      tester,
    ) async {
      final store = await openHome(tester);
      for (var i = 0; i < 5; i++) {
        await tester.tap(coffeeTile);
        await tester.pump(const Duration(milliseconds: 40));
        expect(FarmBurst.activeCount, lessThanOrEqualTo(FarmBurst.maxActive));
      }
      // 효과가 도는 중에도 저장은 이미 끝나 있다.
      expect(store.records, hasLength(5));
      expect(FarmBurst.activeCount, greaterThan(0));

      await tester.pump(const Duration(seconds: 1));
      expect(FarmBurst.activeCount, 0);
      expect(shownBenefit(tester), '+10,000원');
      expect(find.text(expectedTotal(store, 10000)), findsOneWidget);

      // 기기에 저장된 데이터도 5건
      final prefs = await SharedPreferences.getInstance();
      final saved =
          jsonDecode(prefs.getString('salary_farming_state_v1')!) as Map;
      expect(saved['records'], hasLength(5));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('파밍 수익은 이전 금액에서 새 금액까지 올라가고, 효과는 0.8초 안에 끝난다', (tester) async {
      final store = await openHome(tester);
      await tester.tap(coffeeTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final mid = int.parse(
        shownBenefit(tester).replaceAll(RegExp(r'[^0-9]'), ''),
      );
      expect(mid, inExclusiveRange(0, 2000));
      expect(FarmBurst.activeCount, 1);

      await tester.pump(const Duration(milliseconds: 650));
      expect(FarmBurst.activeCount, 0);
      expect(shownBenefit(tester), '+2,000원');
      expect(find.text(expectedTotal(store, 2000)), findsOneWidget);
      expect(find.text('커피 한 잔 파밍 완료!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('애니메이션을 끄면 효과 없이 바로 새 금액', (tester) async {
      final store = await openHome(tester, animation: false);
      await tester.tap(coffeeTile);
      await tester.pump();
      expect(FarmBurst.activeCount, 0);
      await tester.pump();
      expect(shownBenefit(tester), '+2,000원');
      expect(store.records, hasLength(1));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('기기의 동작 줄이기가 켜져 있으면 설정과 상관없이 효과를 끈다', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final store = await openHome(tester);
      expect(store.farmAnimation, isTrue);
      await tester.tap(coffeeTile);
      await tester.pump();
      expect(FarmBurst.activeCount, 0);
      await tester.pump();
      expect(shownBenefit(tester), '+2,000원');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('햅틱: 켜면 한 번 누를 때 한 번, 끄면 울리지 않는다', (tester) async {
      var count = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') count++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final store = await openHome(tester);
      await tester.tap(coffeeTile);
      await tester.pump();
      expect(count, 1);

      await store.setFarmHaptic(false);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(coffeeTile);
      await tester.pump();
      expect(count, 1);
      expect(store.records, hasLength(2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('적립 직후 바로 다른 탭으로 가도 오류 없이 효과가 정리되고 결산에 반영된다', (tester) async {
      final store = await openHome(tester);
      await tester.tap(coffeeTile);
      await tester.pump();
      await tester.tap(find.text('수확 결산').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(FarmBurst.activeCount, 0);
      expect(store.records, hasLength(1));
      expect(find.textContaining('2,000원'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('전체 보기 시트에서 빠르게 두 번 눌러도 한 번만 적립되고 홈은 그대로', (tester) async {
      final store = await openHome(tester);
      await tester.scrollUntilVisible(
        find.text('전체 보기'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('전체 보기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('회사 시설'));
      await tester.pump();
      final tile = find.text('사내 헬스장').last;
      await tester.tap(tile, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(tile, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(store.records, hasLength(1));
      expect(find.text('오늘의 총 수확'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('설정 화면의 스위치가 저장된다', (tester) async {
      final store = await openHome(tester);
      await tester.tap(find.text('설정').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('파밍 애니메이션'));
      await tester.pump();
      await tester.tap(find.text('햅틱 피드백'));
      await tester.pump();
      expect(store.farmAnimation, isFalse);
      expect(store.farmHaptic, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('farm_effect_animation'), isFalse);
      expect(prefs.getBool('farm_effect_haptic'), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
