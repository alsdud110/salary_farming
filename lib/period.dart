import 'app_store.dart';
import 'format.dart';
import 'models.dart';

enum PeriodKind {
  day('일간'),
  week('주간'),
  month('월간'),
  year('연간');

  const PeriodKind(this.label);
  final String label;
}

/// 결산 대상 기간. [from]~[to] 둘 다 포함.
class Period {
  const Period._(this.kind, this.from, this.to);

  factory Period.containing(PeriodKind kind, DateTime date) {
    final d = dateOnly(date);
    switch (kind) {
      case PeriodKind.day:
        return Period._(kind, d, d);
      case PeriodKind.week:
        final monday = DateTime(d.year, d.month, d.day - (d.weekday - 1));
        return Period._(
          kind,
          monday,
          DateTime(monday.year, monday.month, monday.day + 6),
        );
      case PeriodKind.month:
        return Period._(
          kind,
          DateTime(d.year, d.month, 1),
          DateTime(d.year, d.month + 1, 0),
        );
      case PeriodKind.year:
        return Period._(kind, DateTime(d.year, 1, 1), DateTime(d.year, 12, 31));
    }
  }

  final PeriodKind kind;
  final DateTime from;
  final DateTime to;

  Period get previous =>
      Period.containing(kind, DateTime(from.year, from.month, from.day - 1));
  Period get next =>
      Period.containing(kind, DateTime(to.year, to.month, to.day + 1));

  /// 아직 시작하지 않은 기간으로는 넘어가지 못한다.
  bool canGoNext(DateTime now) => !next.from.isAfter(dateOnly(now));

  String get label {
    switch (kind) {
      case PeriodKind.day:
        return '${from.year}년 ${from.month}월 ${from.day}일 '
            '(${weekdayLabels[from.weekday - 1]})';
      case PeriodKind.week:
        final tail = from.month == to.month
            ? '${to.day}일'
            : '${to.month}월 ${to.day}일';
        return '${from.year}년 ${from.month}월 ${from.day}일 – $tail';
      case PeriodKind.month:
        return '${from.year}년 ${from.month}월';
      case PeriodKind.year:
        return '${from.year}년';
    }
  }

  /// 공유 이미지 제목 등에 쓰는 짧은 이름.
  String get title {
    switch (kind) {
      case PeriodKind.day:
        return '${from.month}월 ${from.day}일 결산';
      case PeriodKind.week:
        return '${from.month}월 ${from.day}일 주간 결산';
      case PeriodKind.month:
        return '${from.year}년 ${from.month}월 결산';
      case PeriodKind.year:
        return '${from.year}년 결산';
    }
  }

  /// 막대 그래프 구간. 주간은 요일, 월간은 날짜, 연간은 달. 일간은 없다.
  List<Period> get buckets {
    switch (kind) {
      case PeriodKind.day:
        return const [];
      case PeriodKind.week:
      case PeriodKind.month:
        return [
          for (var d = from;
              !d.isAfter(to);
              d = DateTime(d.year, d.month, d.day + 1))
            Period.containing(PeriodKind.day, d),
        ];
      case PeriodKind.year:
        return [
          for (var m = 1; m <= 12; m++)
            Period.containing(PeriodKind.month, DateTime(from.year, m, 1)),
        ];
    }
  }

  /// 그래프 아래에 붙는 구간 이름. 빈 문자열이면 표시하지 않는다.
  String bucketLabel(Period bucket) {
    switch (kind) {
      case PeriodKind.day:
        return '';
      case PeriodKind.week:
        return weekdayLabels[bucket.from.weekday - 1];
      case PeriodKind.month:
        final day = bucket.from.day;
        return day == 1 || day % 5 == 0 ? '$day' : '';
      case PeriodKind.year:
        return '${bucket.from.month}';
    }
  }
}

/// 결산에 곁들이는 한마디들.
List<String> buildInsights(
  PeriodTotals totals,
  List<BenefitSummary> summaries,
) {
  if (totals.isEmpty) return const [];
  final lines = <String>[];

  if (totals.benefit == 0) {
    lines.add('월급만으로 묵묵히 ${won(totals.salary)}. 탕비실이 당신을 기다리고 있어요.');
    return lines;
  }

  final mostOften = [...summaries]..sort((a, b) => b.count.compareTo(a.count));
  final top = mostOften.first;
  if (top.count >= 2) {
    lines.add('${top.icon} ${top.name}만 ${top.count}번. 이 정도면 단골이에요.');
  } else {
    lines.add('${top.icon} ${top.name}, 놓치지 않고 챙겼어요.');
  }

  const chicken = 20000;
  const americano = 4500;
  if (totals.benefit >= chicken) {
    lines.add('주운 혜택만 모아도 치킨 ${totals.benefit ~/ chicken}마리 값이에요.');
  } else if (totals.benefit >= americano) {
    lines.add('주운 혜택으로 카페 아메리카노 ${totals.benefit ~/ americano}잔 값을 아꼈어요.');
  } else {
    lines.add('티끌 ${won(totals.benefit)}. 태산은 원래 이렇게 시작해요.');
  }

  if (totals.salary > 0) {
    final share = totals.benefit * 100 / totals.total;
    final text = share < 1 ? share.toStringAsFixed(1) : share.round().toString();
    lines.add('총 가치의 $text%는 월급 밖에서 나왔어요.');
  }
  return lines;
}
