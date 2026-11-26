import 'package:flutter_test/flutter_test.dart';
import 'package:salary_farming/app_store.dart';
import 'package:salary_farming/home_widget_sync.dart';
import 'package:salary_farming/models.dart';
import 'package:salary_farming/salary_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// iOS 위젯(SalaryWidget.swift)과 같은 계산: 예상 실수령 × 달이 지난 비율.
double widgetEarned(List<Map<String, Object>> months, DateTime t) {
  final now = t.millisecondsSinceEpoch / 1000;
  final m = months.firstWhere(
    (m) => (m['start'] as int) <= now && now < (m['end'] as int),
  );
  final start = m['start'] as int, end = m['end'] as int;
  return (m['expected'] as int) * (now - start) / (end - start);
}

void main() {
  test('위젯 금액은 홈의 월 누적 월급과 같고, 다음 달로 넘어가도 이어진다', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(clock: () => DateTime(2026, 11, 26, 9));
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
    final months = widgetMonths(store);
    expect(months, hasLength(3));
    for (final t in [
      DateTime(2026, 11, 26, 3), // 근무 전 새벽에도 오른다
      DateTime(2026, 11, 26, 15),
      DateTime(2026, 12, 25, 22), // 앱을 열지 않고 다음 달
    ]) {
      expect(
        widgetEarned(months, t),
        closeTo(3000000 * SalaryCalculator.monthElapsedRatio(t), 0.01),
      );
    }
  });
}
