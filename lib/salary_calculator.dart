import 'models.dart';
import 'tax.dart';

export 'tax.dart' show PayrollDeduction;

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
/// 기준:
/// - 한 달 금액(세전 연봉·세후 월급·월 계약금)은 세금·공제를 뗀 월 실수령액을
///   그 달 근무일 수로 똑같이 나눠 하루치로 삼는다.
/// - 시급은 급여가 쌓이는 시간(휴게시간 포함 여부는 설정)만큼, 일당은 그대로 하루치가 된다.
/// - 하루치는 급여가 쌓이는 시간 동안 고르게 쌓인다. 휴게시간을 급여에 포함하면
///   출근부터 퇴근까지 쭉, 포함하지 않으면 휴게시간에는 멈춘다.
class SalaryCalculator {
  const SalaryCalculator._();

  static bool isWorkday(WorkSettings s, DateTime date) =>
      s.workWeekdays.contains(date.weekday);

  /// [date] 가 속한 달의 근무일 수.
  static int workdaysInMonth(WorkSettings s, DateTime date) {
    final days = DateTime(date.year, date.month + 1, 0).day;
    var count = 0;
    for (var d = 1; d <= days; d++) {
      if (s.workWeekdays.contains(DateTime(date.year, date.month, d).weekday)) {
        count++;
      }
    }
    return count;
  }

  /// 세전 연봉일 때의 월 공제 내역. 다른 급여 방식이면 null.
  static PayrollDeduction? payroll(WorkSettings s) {
    if (!s.payBasis.usesPayrollTax) return null;
    return TaxCalculator.fromAnnual(
      annualGross: s.payAmount,
      nonTaxableMonthly: s.nonTaxableMonthly,
      dependents: s.dependents,
    );
  }

  /// 3.3% 원천징수 뒤 남는 비율.
  static double _keepRatio(WorkSettings s) =>
      s.appliesWithholding ? 1 - TaxCalculator.withholdingRate : 1;

  /// 한 달 금액 방식의 월 실수령액. 시급·일당이면 null.
  static double? monthlyNet(WorkSettings s) {
    switch (s.payBasis) {
      case PayBasis.annualGross:
        return payroll(s)!.net.toDouble();
      case PayBasis.monthlyNet:
        return s.payAmount.toDouble();
      case PayBasis.monthlyGross:
        return s.payAmount * _keepRatio(s);
      case PayBasis.hourly:
      case PayBasis.daily:
        return null;
    }
  }

  /// 근무일 하루를 다 일했을 때의 실수령 급여. 근무일이 아니면 0.
  static double dailyPay(WorkSettings s, DateTime date) {
    if (!isWorkday(s, date)) return 0;
    switch (s.payBasis) {
      case PayBasis.hourly:
        // 휴게시간을 급여에 포함하면 휴게시간도 시급으로 친다.
        return s.payAmount * s.paidMinutesPerDay / 60 * _keepRatio(s);
      case PayBasis.daily:
        return s.payAmount * _keepRatio(s);
      case PayBasis.annualGross:
      case PayBasis.monthlyNet:
      case PayBasis.monthlyGross:
        final workdays = workdaysInMonth(s, date);
        if (workdays == 0) return 0;
        return monthlyNet(s)! / workdays;
    }
  }

  /// [date] 가 속한 달을 다 일했을 때의 예상 실수령액.
  static double expectedInMonth(WorkSettings s, DateTime date) {
    final monthly = monthlyNet(s);
    if (monthly != null) return monthly;
    final days = DateTime(date.year, date.month + 1, 0).day;
    var sum = 0.0;
    for (var d = 1; d <= days; d++) {
      sum += dailyPay(s, DateTime(date.year, date.month, d));
    }
    return sum;
  }

  /// 하루에 급여가 쌓이는 시간(초).
  static int workSecondsPerDay(WorkSettings s) => s.paidMinutesPerDay * 60;

  /// [now] 시각까지 그날 급여가 쌓인 시간(초).
  /// 휴게시간을 급여에 포함하지 않으면 휴게시간은 빠진다.
  /// 화면에서 금액이 끊김 없이 오르도록 1초보다 작은 단위까지 센다.
  static double workedSeconds(WorkSettings s, DateTime now) {
    if (!isWorkday(s, now)) return 0;
    final sec =
        now.hour * 3600 +
        now.minute * 60 +
        now.second +
        now.millisecond / 1000 +
        now.microsecond / 1e6;
    final start = s.startMinute * 60.0;
    final end = s.endMinute * 60.0;
    if (sec <= start) return 0;
    final clamped = sec < end ? sec : end;
    var worked = clamped - start;
    if (s.hasBreak && !s.paidBreak) {
      final bStart = s.breakStartMinute * 60.0;
      final bEnd = s.breakEndMinute * 60.0;
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

  /// 지금 급여가 쌓이고 있는지. 근무 중이거나, 휴게시간을 급여에 포함한 휴게 중.
  static bool isGrowing(WorkSettings s, DateTime now) {
    final p = phase(s, now);
    return p == WorkPhase.working || (p == WorkPhase.onBreak && s.paidBreak);
  }

  /// 근무 중 1초에 쌓이는 금액.
  static double perSecond(WorkSettings s, DateTime date) {
    final total = workSecondsPerDay(s);
    if (total <= 0) return 0;
    return dailyPay(s, date) / total;
  }
}
