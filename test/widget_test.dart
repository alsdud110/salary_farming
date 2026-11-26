import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salary_farming/app_store.dart';
import 'package:salary_farming/main.dart';
import 'package:salary_farming/models.dart';
import 'package:salary_farming/period.dart';
import 'package:salary_farming/salary_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 평일 9~18시, 점심 12~13시, 월급 300만원.
const office = WorkSettings(
  payAmount: 3000000,
  payCycle: PayCycle.monthly,
  workWeekdays: {1, 2, 3, 4, 5},
  startMinute: 9 * 60,
  endMinute: 18 * 60,
  breakStartMinute: 12 * 60,
  breakEndMinute: 13 * 60,
);

void main() {
  group('급여 계산', () {
    // 2026년 11월: 평일 21일. 26일은 목요일, 28일은 토요일.
    test('한 달 근무일 수와 하루치', () {
      final day = DateTime(2026, 11, 26);
      expect(SalaryCalculator.workdaysInPeriod(office, day), 21);
      expect(SalaryCalculator.dailyPay(office, day), closeTo(3000000 / 21, 0.001));
      expect(office.workMinutesPerDay, 8 * 60);
    });

    test('출근 전에는 0원', () {
      final now = DateTime(2026, 11, 26, 8, 59);
      expect(SalaryCalculator.earnedOn(office, now, now), 0);
      expect(SalaryCalculator.phase(office, now), WorkPhase.beforeWork);
    });

    test('근무 중에는 일한 시간만큼 쌓인다', () {
      final now = DateTime(2026, 11, 26, 11, 0);
      final daily = 3000000 / 21;
      expect(SalaryCalculator.earnedOn(office, now, now),
          closeTo(daily * 2 / 8, 0.001));
      expect(SalaryCalculator.phase(office, now), WorkPhase.working);
    });

    test('휴게시간에는 쌓이지 않는다', () {
      final start = DateTime(2026, 11, 26, 12, 0);
      final mid = DateTime(2026, 11, 26, 12, 40);
      final end = DateTime(2026, 11, 26, 13, 0);
      final atStart = SalaryCalculator.earnedOn(office, start, start);
      expect(SalaryCalculator.earnedOn(office, mid, mid), atStart);
      expect(SalaryCalculator.earnedOn(office, end, end), atStart);
      expect(SalaryCalculator.phase(office, mid), WorkPhase.onBreak);
    });

    test('퇴근 후에는 하루치에서 멈춘다', () {
      final now = DateTime(2026, 11, 26, 22, 0);
      expect(SalaryCalculator.earnedOn(office, now, now),
          closeTo(3000000 / 21, 0.001));
      expect(SalaryCalculator.phase(office, now), WorkPhase.afterWork);
    });

    test('비근무일에는 0원', () {
      final saturday = DateTime(2026, 11, 28, 14, 0);
      expect(SalaryCalculator.earnedOn(office, saturday, saturday), 0);
      expect(SalaryCalculator.phase(office, saturday), WorkPhase.dayOff);
    });

    test('주급은 한 주 근무일 수로 나눈다', () {
      const weekly = WorkSettings(
        payAmount: 500000,
        payCycle: PayCycle.weekly,
        workWeekdays: {1, 2, 3, 4, 5},
        startMinute: 9 * 60,
        endMinute: 18 * 60,
        breakStartMinute: 0,
        breakEndMinute: 0,
      );
      expect(SalaryCalculator.dailyPay(weekly, DateTime(2026, 11, 26)), 100000);
    });
  });

  group('설정 검증', () {
    String? check({
      int? pay = 3000000,
      Set<int> days = const {1, 2, 3, 4, 5},
      int start = 540,
      int end = 1080,
      bool hasBreak = true,
      int bStart = 720,
      int bEnd = 780,
    }) =>
        WorkSettings.validate(
          payAmount: pay,
          workWeekdays: days,
          startMinute: start,
          endMinute: end,
          hasBreak: hasBreak,
          breakStartMinute: bStart,
          breakEndMinute: bEnd,
        );

    test('정상 값은 통과', () => expect(check(), isNull));
    test('금액이 없거나 0 이하이면 막는다', () {
      expect(check(pay: null), isNotNull);
      expect(check(pay: 0), isNotNull);
      expect(check(pay: -100), isNotNull);
    });
    test('근무 요일이 없으면 막는다', () => expect(check(days: {}), isNotNull));
    test('퇴근이 출근보다 이르면 막는다', () {
      expect(check(start: 1080, end: 540), isNotNull);
      expect(check(start: 540, end: 540), isNotNull);
    });
    test('휴게시간이 근무 시간을 벗어나면 막는다', () {
      expect(check(bStart: 480, bEnd: 600), isNotNull);
      expect(check(bStart: 780, bEnd: 720), isNotNull);
    });
  });

  group('저장소', () {
    late DateTime now;
    late AppStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      now = DateTime(2026, 11, 26, 11, 0);
      store = AppStore(clock: () => now);
      await store.load();
    });

    test('처음에는 설정이 없고 기본 템플릿이 있다', () {
      expect(store.isSetupDone, isFalse);
      expect(
        store.templates.where((t) => t.category == BenefitCategory.food),
        isNotEmpty,
      );
      expect(
        store.templates.where((t) => t.category == BenefitCategory.facility),
        isNotEmpty,
      );
    });

    test('혜택이 없으면 총 가치는 급여와 같다', () async {
      await store.saveSettings(office);
      final t = store.totals(now, now);
      expect(t.benefit, 0);
      expect(t.total, t.salary);
      expect(t.salary, (3000000 / 21 * 2 / 8).floor());
    });

    test('적립하면 급여는 그대로이고 혜택과 총액만 늘어난다', () async {
      await store.saveSettings(office);
      final before = store.totals(now, now);
      final coffee = store.templates.firstWhere((t) => t.id == 'd_coffee');
      final record = await store.credit(coffee);
      final after = store.totals(now, now);
      expect(after.salary, before.salary);
      expect(after.benefit, coffee.amount);
      expect(after.total, before.total + coffee.amount);

      await store.removeRecord(record.id);
      expect(store.totals(now, now).total, before.total);
    });

    test('다시 불러와도 설정·템플릿·기록이 남는다', () async {
      await store.saveSettings(office);
      await store.addTemplate(
        name: '법카 저녁',
        icon: '🍕',
        amount: 15000,
        frequency: UseFrequency.sometimes,
      );
      await store.credit(store.templates.last);

      final reopened = AppStore(clock: () => now);
      await reopened.load();
      expect(reopened.isSetupDone, isTrue);
      expect(reopened.currentSettings!.payAmount, 3000000);
      expect(reopened.templates.last.name, '법카 저녁');
      expect(reopened.records.single.amount, 15000);
    });

    test('설정 이전 날짜와 기록 없는 기간은 0원', () async {
      await store.saveSettings(office);
      final lastMonth = Period.containing(PeriodKind.month, DateTime(2026, 10, 15));
      final t = store.totals(lastMonth.from, lastMonth.to);
      expect(t.isEmpty, isTrue);
      expect(store.summarize(lastMonth.from, lastMonth.to), isEmpty);
    });

    test('설정을 바꿔도 지난 날 급여는 그대로다', () async {
      await store.saveSettings(office);
      now = DateTime(2026, 11, 27, 20, 0);
      final thursday = DateTime(2026, 11, 26);
      final before = store.totals(thursday, thursday).salary;
      await store.saveSettings(const WorkSettings(
        payAmount: 6000000,
        payCycle: PayCycle.monthly,
        workWeekdays: {1, 2, 3, 4, 5},
        startMinute: 9 * 60,
        endMinute: 18 * 60,
        breakStartMinute: 12 * 60,
        breakEndMinute: 13 * 60,
      ));
      expect(store.totals(thursday, thursday).salary, before);
      expect(store.totals(now, now).salary, (6000000 / 21).floor());
    });

    test('기간 집계와 혜택별 횟수', () async {
      await store.saveSettings(office);
      final coffee = store.templates.firstWhere((t) => t.id == 'd_coffee');
      final lunch = store.templates.firstWhere((t) => t.id == 'd_lunch');
      await store.credit(coffee);
      await store.credit(coffee);
      await store.credit(lunch);

      final week = Period.containing(PeriodKind.week, now);
      expect(week.from, DateTime(2026, 11, 23));
      expect(week.to, DateTime(2026, 11, 29));
      final summaries = store.summarize(week.from, week.to);
      expect(summaries.first.name, lunch.name);
      expect(summaries.last.count, 2);
      expect(store.totals(week.from, week.to).benefit,
          coffee.amount * 2 + lunch.amount);
      expect(week.canGoNext(now), isFalse);
      expect(week.previous.canGoNext(now), isTrue);
    });
  });

  group('화면', () {
    testWidgets('첫 설정을 마치면 계산 기준을 보여주고 홈으로 간다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final store = AppStore(clock: () => DateTime(2026, 11, 26, 11, 0));
      await store.load();
      await tester.pumpWidget(SalaryFarmingApp(store: store));
      await tester.pumpAndSettle();

      // 금액 없이 누르면 저장되지 않고 안내가 나온다.
      await tester.ensureVisible(find.text('설정 완료'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('설정 완료'));
      await tester.pumpAndSettle();
      expect(store.isSetupDone, isFalse);
      expect(find.text('급여 금액을 숫자로 입력해 주세요.'), findsOneWidget);

      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3000000');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('설정 완료'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('설정 완료'));
      await tester.pumpAndSettle();

      expect(store.isSetupDone, isTrue);
      expect(find.text('밭 준비 끝!'), findsOneWidget);
      expect(find.text('계산 기준'), findsOneWidget);

      await tester.tap(find.text('파밍 시작하기'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('오늘 자란 월급'), findsOneWidget);
      expect(find.text('오늘의 총 가치'), findsOneWidget);

      // 템플릿을 한 번 누르면 바로 적립된다.
      await tester.tap(find.text('탕비실 커피'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(store.records.single.amount, 2000);

      // 주기 타이머가 남지 않게 화면을 내린다.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
