import 'models.dart';

/// 지금 근무 상태.
enum WorkPhase {
  dayOff('쉬는 날'),
  beforeWork('출근 전'),
  working('근무 중'),
  onBreak('휴게 중'),
  afterWork('퇴근');

  const WorkPhase(this.label);
  final String label;
}

/// 실제 급여 계산.
///
/// 기준: 지급 주기(달력상 한 달 또는 한 주)의 급여를 그 주기 안의 근무일 수로
/// 똑같이 나눠 하루치로 삼고, 하루치는 휴게시간을 뺀 근무 시간에 비례해 쌓인다.
/// 세금·공제는 계산하지 않으므로 사용자가 넣은 금액이 그대로 기준이 된다.
class SalaryCalculator {
  const SalaryCalculator._();

  static bool isWorkday(WorkSettings s, DateTime date) =>
      s.workWeekdays.contains(date.weekday);

  /// [date] 가 속한 지급 주기 안의 근무일 수.
  static int workdaysInPeriod(WorkSettings s, DateTime date) {
    switch (s.payCycle) {
      case PayCycle.weekly:
        return s.workWeekdays.length;
      case PayCycle.monthly:
        final days = DateTime(date.year, date.month + 1, 0).day;
        var count = 0;
        for (var d = 1; d <= days; d++) {
          if (s.workWeekdays.contains(DateTime(date.year, date.month, d).weekday)) {
            count++;
          }
        }
        return count;
    }
  }

  /// [date] 하루를 다 일했을 때의 급여. 근무일이 아니면 0.
  static double dailyPay(WorkSettings s, DateTime date) {
    if (!isWorkday(s, date)) return 0;
    final workdays = workdaysInPeriod(s, date);
    if (workdays == 0) return 0;
    return s.payAmount / workdays;
  }

  /// 하루 근무 시간(초).
  static int workSecondsPerDay(WorkSettings s) => s.workMinutesPerDay * 60;

  /// [now] 시각까지 그날 실제로 일한 시간(초). 휴게시간은 빠진다.
  static int workedSeconds(WorkSettings s, DateTime now) {
    if (!isWorkday(s, now)) return 0;
    final sec = now.hour * 3600 + now.minute * 60 + now.second;
    final start = s.startMinute * 60;
    final end = s.endMinute * 60;
    if (sec <= start) return 0;
    final clamped = sec < end ? sec : end;
    var worked = clamped - start;
    if (s.hasBreak) {
      final bStart = s.breakStartMinute * 60;
      final bEnd = s.breakEndMinute * 60;
      if (clamped > bStart) {
        worked -= (clamped < bEnd ? clamped : bEnd) - bStart;
      }
    }
    return worked;
  }

  /// [date] 에 번 급여. 오늘이면 [now] 까지, 지난 날이면 하루치 전부, 앞날이면 0.
  static double earnedOn(WorkSettings s, DateTime date, DateTime now) {
    final day = dateOnly(date);
    final today = dateOnly(now);
    if (day.isAfter(today)) return 0;
    final pay = dailyPay(s, day);
    if (pay == 0) return 0;
    if (day.isBefore(today)) return pay;
    final total = workSecondsPerDay(s);
    if (total <= 0) return 0;
    return pay * workedSeconds(s, now) / total;
  }

  /// 오늘 근무 진행률 0~1.
  static double progress(WorkSettings s, DateTime now) {
    final total = workSecondsPerDay(s);
    if (total <= 0 || !isWorkday(s, now)) return 0;
    return workedSeconds(s, now) / total;
  }

  static WorkPhase phase(WorkSettings s, DateTime now) {
    if (!isWorkday(s, now)) return WorkPhase.dayOff;
    final sec = now.hour * 3600 + now.minute * 60 + now.second;
    if (sec < s.startMinute * 60) return WorkPhase.beforeWork;
    if (sec >= s.endMinute * 60) return WorkPhase.afterWork;
    if (s.hasBreak &&
        sec >= s.breakStartMinute * 60 &&
        sec < s.breakEndMinute * 60) {
      return WorkPhase.onBreak;
    }
    return WorkPhase.working;
  }

  /// 근무 중 1초에 쌓이는 금액.
  static double perSecond(WorkSettings s, DateTime date) {
    final total = workSecondsPerDay(s);
    if (total <= 0) return 0;
    return dailyPay(s, date) / total;
  }
}
