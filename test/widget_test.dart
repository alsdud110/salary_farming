import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salary_farming/app_store.dart';
import 'package:salary_farming/main.dart';
import 'package:salary_farming/models.dart';
import 'package:salary_farming/period.dart';
import 'package:salary_farming/salary_calculator.dart';
import 'package:salary_farming/tax.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  group('급여 계산', () {
    // 2026년 11월: 평일 21일. 26일은 목요일, 28일은 토요일.
    test('한 달 근무일 수와 하루치', () {
      final day = DateTime(2026, 11, 26);
      expect(SalaryCalculator.workdaysInMonth(office, day), 21);
      expect(SalaryCalculator.dailyPay(office, day), closeTo(3000000 / 21, 0.001));
      expect(office.workMinutesPerDay, 8 * 60);
    });

    test('출근 전에는 0원', () {
      final now = DateTime(2026, 11, 26, 8, 59);
      expect(SalaryCalculator.earnedOn(office, now, now), 0);
      expect(SalaryCalculator.phase(office, now), WorkPhase.beforeWork);
    });

    // 기본(휴게시간에도 쌓기 켜짐): 9~18시 9시간 동안 고르게 쌓인다.
    test('근무 중에는 지난 시간만큼 쌓인다', () {
      final now = DateTime(2026, 11, 26, 11, 0);
      final daily = 3000000 / 21;
      expect(SalaryCalculator.earnedOn(office, now, now),
          closeTo(daily * 2 / 9, 0.001));
      expect(SalaryCalculator.phase(office, now), WorkPhase.working);
    });

    test('휴게시간에도 쌓기를 켜면 휴게 중에도 계속 쌓인다', () {
      final start = DateTime(2026, 11, 26, 12, 0);
      final mid = DateTime(2026, 11, 26, 12, 40);
      final atStart = SalaryCalculator.earnedOn(office, start, start);
      expect(SalaryCalculator.earnedOn(office, mid, mid), greaterThan(atStart));
      expect(SalaryCalculator.phase(office, mid), WorkPhase.onBreak);
      expect(SalaryCalculator.isGrowing(office, mid), isTrue);
    });

    test('휴게시간에도 쌓기를 끄면 휴게 중에는 멈춘다', () {
      const unpaid = WorkSettings(
        payAmount: 3000000,
        workWeekdays: {1, 2, 3, 4, 5},
        startMinute: 9 * 60,
        endMinute: 18 * 60,
        breakStartMinute: 12 * 60,
        breakEndMinute: 13 * 60,
        paidBreak: false,
      );
      final start = DateTime(2026, 11, 26, 12, 0);
      final mid = DateTime(2026, 11, 26, 12, 40);
      final end = DateTime(2026, 11, 26, 13, 0);
      final atStart = SalaryCalculator.earnedOn(unpaid, start, start);
      expect(SalaryCalculator.earnedOn(unpaid, mid, mid), atStart);
      expect(SalaryCalculator.earnedOn(unpaid, end, end), atStart);
      expect(SalaryCalculator.isGrowing(unpaid, mid), isFalse);
      // 11시면 일한 2시간 / 실제 근무 8시간.
      final eleven = DateTime(2026, 11, 26, 11, 0);
      expect(SalaryCalculator.earnedOn(unpaid, eleven, eleven),
          closeTo(3000000 / 21 * 2 / 8, 0.001));
      // 하루 총액은 켜든 끄든 같다(월급제).
      final day = DateTime(2026, 11, 26);
      expect(SalaryCalculator.dailyPay(unpaid, day),
          SalaryCalculator.dailyPay(office, day));
    });

    test('예전 설정(값 없음)은 휴게시간에도 쌓기 켜짐으로 읽는다', () {
      final j = office.toJson()..remove('paidBreak');
      expect(WorkSettings.fromJson(j).paidBreak, isTrue);
      final off = WorkSettings.fromJson({...j, 'paidBreak': false});
      expect(off.paidBreak, isFalse);
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

    WorkSettings shift(
      PayBasis basis,
      int amount, {
      bool withholding = false,
      bool paidBreak = true,
    }) =>
        WorkSettings(
          paidBreak: paidBreak,
          jobType: JobType.partTime,
          payBasis: basis,
          payAmount: amount,
          withholding: withholding,
          workWeekdays: const {1, 2, 3, 4, 5},
          startMinute: 9 * 60,
          endMinute: 18 * 60,
          breakStartMinute: 12 * 60,
          breakEndMinute: 13 * 60,
        );

    test('시급: 휴게시간에도 쌓기를 켜면 휴게시간도 시급으로 친다', () {
      final s = shift(PayBasis.hourly, 10320);
      final day = DateTime(2026, 11, 26);
      expect(SalaryCalculator.dailyPay(s, day), 10320 * 9);
      // 11월 평일 21일.
      expect(SalaryCalculator.expectedInMonth(s, day), closeTo(10320 * 9 * 21, 0.01));
      // 11시면 2시간치.
      final now = DateTime(2026, 11, 26, 11, 0);
      expect(SalaryCalculator.earnedOn(s, now, now), closeTo(10320 * 2, 0.01));
    });

    test('시급: 끄면 휴게시간을 뺀 근무 시간만큼이 하루치', () {
      final s = shift(PayBasis.hourly, 10320, paidBreak: false);
      final day = DateTime(2026, 11, 26);
      expect(SalaryCalculator.dailyPay(s, day), 10320 * 8);
      final now = DateTime(2026, 11, 26, 11, 0);
      expect(SalaryCalculator.earnedOn(s, now, now), closeTo(10320 * 2, 0.01));
    });

    test('일당은 그대로 하루치, 3.3%를 켜면 그만큼 뗀다', () {
      final day = DateTime(2026, 11, 26);
      expect(SalaryCalculator.dailyPay(shift(PayBasis.daily, 100000), day), 100000);
      expect(
        SalaryCalculator.dailyPay(
            shift(PayBasis.daily, 100000, withholding: true), day),
        closeTo(96700, 0.01),
      );
    });

    test('세전 연봉은 세금을 뗀 월 실수령액을 근무일 수로 나눈다', () {
      const s = WorkSettings(
        payBasis: PayBasis.annualGross,
        payAmount: 55000000,
        nonTaxableMonthly: 200000,
        workWeekdays: {1, 2, 3, 4, 5},
        startMinute: 9 * 60,
        endMinute: 18 * 60,
        breakStartMinute: 12 * 60,
        breakEndMinute: 13 * 60,
      );
      final net = SalaryCalculator.monthlyNet(s)!;
      expect(net, lessThan(55000000 / 12));
      expect(SalaryCalculator.dailyPay(s, DateTime(2026, 11, 26)),
          closeTo(net / 21, 0.001));
      expect(SalaryCalculator.expectedInMonth(s, DateTime(2026, 11, 26)), net);
    });

    test('월 경과 비율은 근무 시간과 상관없이 한 달 내내 오른다', () {
      expect(SalaryCalculator.monthElapsedRatio(DateTime(2026, 11, 1)), 0);
      expect(SalaryCalculator.monthElapsedRatio(DateTime(2026, 11, 16)), 0.5);
      // 새벽 3시(근무 전)에도 전날보다 오른다.
      expect(
        SalaryCalculator.monthElapsedRatio(DateTime(2026, 11, 26, 3)),
        greaterThan(SalaryCalculator.monthElapsedRatio(DateTime(2026, 11, 25, 23))),
      );
    });

    test('예전 주급 데이터는 같은 하루치의 일당으로 읽는다', () {
      final s = WorkSettings.fromJson({
        'payAmount': 500000,
        'payCycle': 'weekly',
        'workWeekdays': [1, 2, 3, 4, 5],
        'startMinute': 540,
        'endMinute': 1080,
        'breakStartMinute': 0,
        'breakEndMinute': 0,
      });
      expect(s.payBasis, PayBasis.daily);
      expect(SalaryCalculator.dailyPay(s, DateTime(2026, 11, 26)), 100000);
    });
  });

  group('세금 추정(2026)', () {
    // 비교 기준: 공개 실수령액 계산기(k-calc, 2026) 연봉 5,500만원 · 비과세 0 · 1인 → 3,833,753원.
    test('연봉 5,500만원 실수령액이 공개 계산기와 1% 안으로 맞는다', () {
      final p = TaxCalculator.fromAnnual(annualGross: 55000000);
      expect(p.gross, 4583333);
      expect(p.pension, 217690); // 4,583,000 × 4.75%, 10원 미만 절사
      expect(p.employment, 41240);
      expect(p.net, closeTo(3833753, 3833753 * 0.01));
    });

    test('비과세가 있으면 공제가 줄어든다', () {
      final a = TaxCalculator.fromAnnual(annualGross: 55000000);
      final b = TaxCalculator.fromAnnual(
          annualGross: 55000000, nonTaxableMonthly: 200000);
      expect(b.net, greaterThan(a.net));
    });

    test('부양가족이 많을수록 소득세가 줄어든다', () {
      final one = TaxCalculator.fromAnnual(annualGross: 55000000);
      final three =
          TaxCalculator.fromAnnual(annualGross: 55000000, dependents: 3);
      expect(three.incomeTax, lessThan(one.incomeTax));
      expect(three.insurance, one.insurance);
    });

    test('국민연금은 기준소득월액 상한에서 멈춘다', () {
      final p = TaxCalculator.fromAnnual(annualGross: 200000000);
      expect(p.pension, (6590000 * 0.0475 ~/ 10) * 10);
    });

    test('저소득이면 소득세가 없다', () {
      final p = TaxCalculator.fromAnnual(annualGross: 12000000);
      expect(p.incomeTax, 0);
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
        WorkSettings.validatePay(payBasis: PayBasis.monthlyNet, payAmount: pay) ??
        WorkSettings.validateTime(
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
      expect(t.salary, (3000000 / 21 * 2 / 9).floor());
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
        payBasis: PayBasis.monthlyNet,
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

  group('첫 설정 적용 범위', () {
    test('맨 처음 설정은 이번 달 1일부터 쌓인 것으로 친다', () async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime(2026, 11, 26, 11, 0);
      final store = AppStore(clock: () => now);
      await store.load();
      await store.saveSettings(office);
      // 11/1~25 평일 18일 + 오늘 2시간.
      final daily = 3000000 / 21;
      expect(store.monthSalary(now), closeTo(daily * 18 + daily * 2 / 9, 0.01));
    });
  });

  group('화면', () {
    /// 앱을 띄우고 소개를 건너뛰어 직업군 단계로 간다.
    /// 소개의 금액이 매초 오르므로 소개가 떠 있는 동안에는 pumpAndSettle 을 쓰지 않는다.
    Future<void> openSetup(WidgetTester tester, AppStore store) async {
      await tester.pumpWidget(SalaryFarmingApp(store: store));
      await tester.pump();
      await tester.tap(find.text('건너뛰기'));
      await tester.pump();
      await tester.pumpAndSettle();
    }

    testWidgets('소개 3장을 넘기면 내 정보 입력으로 간다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final store = AppStore(clock: () => DateTime(2026, 11, 26, 11, 0));
      await store.load();
      await tester.pumpWidget(SalaryFarmingApp(store: store));
      await tester.pump();

      expect(find.textContaining('월급이 자라는 걸 지켜보세요'), findsOneWidget);
      expect(find.text('오늘의 총 수확'), findsOneWidget);
      // 데모 금액이 실제로 오른다.
      String amount() => tester
          .widgetList<Text>(find.textContaining('원'))
          .map((t) => t.data ?? '')
          .firstWhere((t) => RegExp(r'^[0-9,]+원$').hasMatch(t));
      final before = amount();
      // 타이머가 값을 올리고, 숫자가 1초 동안 굴러 올라간다.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(amount(), isNot(before));

      await tester.tap(find.text('다음'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('회사에서 챙긴 것도'), findsOneWidget);
      expect(find.text('점심 법카'), findsOneWidget);

      await tester.tap(find.text('다음'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.textContaining('얼마 벌었는지 한눈에'), findsOneWidget);
      // 마지막 장에서는 건너뛰기가 흐려지며 사라진다.
      final skip = tester.widget<AnimatedOpacity>(find.ancestor(
        of: find.text('건너뛰기'),
        matching: find.byType(AnimatedOpacity),
      ));
      expect(skip.opacity, 0);

      await tester.tap(find.text('내 정보 입력하기'));
      await tester.pumpAndSettle();
      expect(find.text('어떤 일을 하세요?'), findsOneWidget);

      // 직업군에서 뒤로 가면 소개로 돌아간다.
      await tester.tap(find.byTooltip('이전'));
      await tester.pump();
      expect(find.text('내 정보 입력하기'), findsNothing);
      expect(find.textContaining('월급이 자라는 걸 지켜보세요'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('온보딩: 직업군 → 급여 → 근무시간 → 세팅 중 → 시작', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final store = AppStore(clock: () => DateTime(2026, 11, 26, 11, 0));
      await store.load();
      await openSetup(tester, store);

      // 1. 직업군
      expect(find.text('어떤 일을 하세요?'), findsOneWidget);
      await tester.tap(find.text('정규직'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      // 2. 급여 — 빈칸에 예시 문구(4천만원)가 보인다.
      expect(find.text('급여를 알려주세요'), findsOneWidget);
      expect(find.text('세전 연봉'), findsOneWidget);
      expect(find.text('세후 월급'), findsOneWidget);
      expect(find.text('40,000,000'), findsOneWidget);
      // 비운 채 누르면 넘어가지 않는다.
      await tester.enterText(find.byKey(const ValueKey('payAmount')), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('연봉을 숫자로 입력해 주세요'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('payAmount')), '55000000');
      await tester.pumpAndSettle();
      // 부양가족·비과세는 묻지 않고, 추정 실수령액이 맞는지만 묻는다.
      expect(find.text('부양가족 수'), findsNothing);
      expect(find.textContaining('맞나요?', findRichText: true), findsOneWidget);
      expect(find.text('아니요, 직접 입력할게요'), findsOneWidget);
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      // 3. 근무 시간 (기본 9~18시, 점심 12~13시)
      expect(find.text('언제 일하세요?'), findsOneWidget);
      await tester.tap(find.text('설정 완료'));
      await tester.pump();

      // 4. 세팅 중
      expect(find.text('월급 계산표 만드는 중'), findsOneWidget);
      expect(store.isSetupDone, isFalse);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 700));
      }
      await tester.pumpAndSettle();

      // 5. 시작 확인
      expect(find.text('월급파밍을 시작할까요?'), findsOneWidget);
      expect(find.text('지금 이 순간까지 11월에 쌓인 월급'), findsOneWidget);
      expect(find.text('월 실수령(추정)'), findsOneWidget);
      await tester.ensureVisible(find.text('월급파밍 시작하기'));
      await tester.tap(find.text('월급파밍 시작하기'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(store.isSetupDone, isTrue);
      expect(store.currentSettings!.payBasis, PayBasis.annualGross);
      expect(store.currentSettings!.payAmount, 55000000);
      expect(find.text('오늘의 총 수확'), findsOneWidget);
      expect(find.text('11월 누적 월급'), findsOneWidget);

      // 템플릿을 한 번 누르면 바로 적립된다.
      await tester.ensureVisible(find.text('탕비실 커피'));
      await tester.tap(find.text('탕비실 커피'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(store.records.single.amount, 2000);

      // 주기 타이머가 남지 않게 화면을 내린다.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('추정 실수령액이 틀리면 세후 월급을 직접 넣는다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final store = AppStore(clock: () => DateTime(2026, 11, 26, 11, 0));
      await store.load();
      await openSetup(tester, store);

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('payAmount')), '55000000');
      await tester.pumpAndSettle();

      await tester.tap(find.text('아니요, 직접 입력할게요'));
      await tester.pumpAndSettle();
      // 세후 월급으로 바뀌고 추정치가 미리 채워져 있다.
      expect(find.text('월 실수령액'), findsOneWidget);
      expect(find.text('3,888,863'), findsOneWidget);
      expect(find.text('아니요, 직접 입력할게요'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('payAmount')), '3700000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('설정 완료'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 700));
      }
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('월급파밍 시작하기'));
      await tester.tap(find.text('월급파밍 시작하기'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(store.currentSettings!.payBasis, PayBasis.monthlyNet);
      expect(store.currentSettings!.payAmount, 3700000);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('소개 2장: 항목이 하나씩 나오며 합계가 차례로 오른다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final store = AppStore(clock: () => DateTime(2026, 11, 26, 11, 0));
      await store.load();
      await tester.pumpWidget(SalaryFarmingApp(store: store));
      await tester.pump();
      await tester.tap(find.text('다음'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      int total() {
        final t = tester
            .widgetList<Text>(find.textContaining('+'))
            .map((w) => w.data ?? '')
            .where((s) => s.startsWith('+'))
            .toList();
        // 마지막 '+…원' 이 합계 상자다.
        return int.parse(t.last.replaceAll(RegExp(r'[^0-9]'), ''));
      }

      double opacityOf(String name) => tester
          .widget<Opacity>(find
              .ancestor(of: find.text(name), matching: find.byType(Opacity))
              .first)
          .opacity;

      // 페이지가 들어온 직후: 아무것도 안 나왔다.
      expect(opacityOf('사내 헬스장'), 0);

      // 커피만 나온 시점: 합계는 2,000원을 향해 오른다.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(opacityOf('탕비실 커피'), greaterThan(0.9));
      expect(opacityOf('사내 헬스장'), 0);
      expect(total(), 2000);

      // 법카까지 나오면 12,000원.
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pump(const Duration(milliseconds: 600));
      expect(total(), 12000);

      // 끝까지 가면 모두 보이고 18,500원.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(opacityOf('사내 헬스장'), 1);
      expect(total(), 18500);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('홈의 오늘 월급은 1초를 기다리지 않고 매 프레임 오른다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      var now = DateTime(2026, 11, 26, 11, 0);
      final store = AppStore(clock: () => now);
      await store.load();
      await store.saveSettings(office);
      await tester.pumpWidget(SalaryFarmingApp(store: store));
      await tester.pump();

      final amountFinder = find.descendant(
        of: find.byType(FittedBox),
        matching: find.byType(Text),
      );
      String shown() => tester.widget<Text>(amountFinder.first).data!;
      final before = shown();

      // 0.5초 흐르면 1초 타이머를 기다리지 않고 다음 프레임에 바로 반영된다.
      // (300만원·21일·8시간 → 1초에 약 4.96원)
      now = now.add(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 16));
      expect(shown(), isNot(before));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    Future<AppStore> openHome(
      WidgetTester tester, {
      Size size = const Size(1080, 2400),
      double ratio = 2.5,
      double textScale = 1,
    }) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = ratio;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = AppStore(clock: () => DateTime(2026, 11, 26, 11, 0));
      await store.load();
      await store.saveSettings(office);
      await tester.pumpWidget(SalaryFarmingApp(store: store));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      return store;
    }

    testWidgets('홈: 레퍼런스 구성과 브랜드 용어', (tester) async {
      await openHome(tester);
      const expected = [
        '월급파밍',
        '오늘의 총 수확',
        '기본 수익',
        '파밍 수익',
        '오늘의 근무',
        '11월 누적 월급',
        '무엇을 파밍했나요?',
        '직접 추가',
        '오늘의 파밍 일지',
        '수확 결산',
      ];
      // 목록은 보이는 만큼만 그리므로 조금씩 내려가며 본 것을 모은다.
      final seen = <String>{};
      for (var i = 0; i < 8; i++) {
        for (final t in expected) {
          if (find.text(t).evaluate().isNotEmpty) seen.add(t);
        }
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(seen, containsAll(expected));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('퇴근까지'), findsOneWidget);
      expect(find.textContaining('매초 +'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('홈: 노란 직접 추가 버튼은 혜택 만들기 시트를 연다', (tester) async {
      await openHome(tester);
      final button = find.widgetWithText(FilledButton, '직접 추가');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('내 혜택 만들기'), findsOneWidget);
      // 시트가 화면 꼭대기까지 덮지 않고(뒤 배경이 보이게) 90% 안에서 멈춘다.
      final sheetTop = tester.getTopLeft(find.byType(BottomSheet)).dy;
      expect(sheetTop, greaterThan(0));
      // 닫기 버튼으로 닫을 수 있다.
      await tester.tap(find.byTooltip('닫기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('내 혜택 만들기'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('홈: 전체 보기 시트에서 고르면 적립된다', (tester) async {
      final store = await openHome(tester);
      await tester.scrollUntilVisible(
        find.text('전체 보기'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // 버튼이 아래 탭 바에 가리지 않게 조금 더 올린다.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('전체 보기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // 시트의 분류 필터로 회사 시설만 본다.
      await tester.tap(find.text('회사 시설'));
      await tester.pump();
      expect(find.text('사내 헬스장'), findsWidgets);
      await tester.tap(find.text('사내 헬스장').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(store.records.single.name, '사내 헬스장');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('홈: 설정 버튼은 설정 탭으로 간다', (tester) async {
      await openHome(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('급여와 근무 시간'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('홈: 작은 화면·큰 글자에서도 넘치지 않는다', (tester) async {
      // 320×568pt 화면, 글자 크기 1.5배.
      await openHome(
        tester,
        size: const Size(640, 1136),
        ratio: 2,
        textScale: 1.5,
      );
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('홈: 터치 영역은 48dp 이상, 글자 대비는 AA', (tester) async {
      await openHome(tester);
      final handle = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      // 수확 결산·설정 탭도 같은 기준으로 본다.
      for (final tab in ['수확 결산', '설정']) {
        await tester.tap(find.text(tab).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await expectLater(
          tester,
          meetsGuideline(androidTapTargetGuideline),
          reason: tab,
        );
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: tab,
        );
      }
      handle.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('온보딩: 터치 영역 48dp 이상, 글자 대비 AA', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final store = AppStore(clock: () => DateTime(2026, 11, 26, 11, 0));
      await store.load();
      final handle = tester.ensureSemantics();
      await openSetup(tester, store);
      // 직업 → 급여 → 근무 시간 단계마다 검사한다.
      for (var step = 0; step < 3; step++) {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        if (step == 0) {
          await tester.tap(find.text('다음'));
        } else if (step == 1) {
          await tester.enterText(
            find.byKey(const ValueKey('payAmount')),
            '55000000',
          );
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.tap(find.text('다음'));
        }
        await tester.pumpAndSettle();
      }
      handle.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('근무 시간: 알람처럼 휠을 돌려 고른다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final store = AppStore(clock: () => DateTime(2026, 11, 26, 11, 0));
      await store.load();
      await openSetup(tester, store);
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('payAmount')), '40000000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      // 출근 칸을 누르면 휠 시트가 아래에서 올라온다.
      await tester.tap(find.text('출근'));
      await tester.pumpAndSettle();
      expect(find.text('출근 시간'), findsOneWidget);
      expect(find.byType(CupertinoDatePicker), findsOneWidget);

      // 취소하면 그대로.
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.text('오전 9:00'), findsOneWidget);

      // 시 휠을 한 칸 올리면 10시.
      await tester.tap(find.text('출근'));
      await tester.pumpAndSettle();
      final nine = find.descendant(
        of: find.byType(CupertinoDatePicker),
        matching: find.text('09'),
      );
      await tester.drag(nine, const Offset(0, -32), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('오전 10:00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('주말: 근무 시간을 빼고, 파밍 수익 0원에는 + 를 붙이지 않는다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      var now = DateTime(2026, 11, 26, 11, 0);
      final store = AppStore(clock: () => now);
      await store.load();
      await store.saveSettings(office);
      now = DateTime(2026, 11, 28, 14, 0); // 토요일
      await tester.pumpWidget(SalaryFarmingApp(store: store));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('오늘은 근무가 없는 날이에요'), findsOneWidget);
      expect(find.text('오전 9:00 – 오후 6:00'), findsNothing);
      expect(find.text('+0원'), findsNothing);
      // 막대는 그대로 있다.
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('아르바이트는 시급·일당을 고른다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final store = AppStore(clock: () => DateTime(2026, 11, 26, 11, 0));
      await store.load();
      await openSetup(tester, store);

      await tester.tap(find.text('아르바이트'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('시급'), findsWidgets);
      expect(find.text('일당'), findsOneWidget);
      expect(find.text('3.3% 떼고 계산'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
