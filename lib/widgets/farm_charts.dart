import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';
import '../motion.dart';
import '../models.dart';
import '../theme.dart';
import 'benefit_glyph.dart';

// 수확 결산의 기간별 그림. 월급은 매일 거의 같아서 그리지 않고, 날마다 달라지는
// 파밍 수익(골드)만 보여준다. 데이터는 모두 바깥에서 받아 온보딩 데모에서도 쓴다.

/// 파밍 금액을 0(없음)~4(가장 많음) 단계로.
int farmLevel(int amount, int max) {
  if (amount <= 0 || max <= 0) return 0;
  return (amount * 4 / max).ceil().clamp(1, 4);
}

const _levelAlpha = [0.0, 0.28, 0.5, 0.75, 1.0];

/// 단계별 밭 칸 색. 카드 위에 골드를 섞어 불투명하게 만든다.
Color farmCellColor(BuildContext context, int level) => level == 0
    ? context.colors.shade
    : Color.alphaBlend(
        AppColors.benefit.withValues(alpha: _levelAlpha[level]),
        context.colors.card,
      );

/// 진한 골드 칸 위 글자는 테마와 상관없이 짙게.
Color farmCellText(BuildContext context, int level) =>
    level >= 3 ? AppColors.ink : context.colors.ink;

// ---------------------------------------------------------------------------
// 월간: 파밍 밭

/// 한 달을 달력처럼 깐 밭. 파밍한 날일수록 골드로 진하게 칠한다.
class FarmField extends StatelessWidget {
  const FarmField({
    super.key,
    required this.month,
    required this.amounts,
    required this.workDays,
    this.lastDay,
    this.today,
    this.reveal = 1,
  });

  /// 그 달의 아무 날.
  final DateTime month;

  /// 1일부터 날짜별 파밍 수익.
  final List<int> amounts;

  /// 1일부터 근무일인지. 쉬는 날은 칸을 흐리게 둔다.
  final List<bool> workDays;

  /// 이 날 뒤(아직 오지 않은 날)는 테두리만 그린다. null 이면 모두 지난 날.
  final int? lastDay;

  /// 오늘 날짜에 테두리를 두른다.
  final int? today;

  /// 0~1. 칸이 1일부터 차례로 채워지는 정도(온보딩 데모). 1이면 다 보인다.
  final double reveal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1; // 월요일 시작
    final max = amounts.fold(0, math.max);
    final farmed = amounts.where((a) => a > 0).length;
    final rows = ((lead + days) / 7).ceil();

    Widget cell(int day) {
      final i = day - 1;
      final future = lastDay != null && day > lastDay!;
      final level = future ? 0 : farmLevel(amounts[i], max);
      // 칸마다 조금씩 늦게 나타난다.
      final show = ((reveal * (days + 6) - i) / 6).clamp(0.0, 1.0);
      final work = workDays[i];
      return Opacity(
        opacity: show,
        child: Transform.scale(
          scale: 0.7 + 0.3 * show,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: future
                  ? null
                  : (level == 0 && !work
                        ? Colors.transparent
                        : farmCellColor(context, level)),
              borderRadius: BorderRadius.circular(8),
              border: day == today
                  ? Border.all(color: c.fieldText, width: 2)
                  : future
                  ? Border.all(color: c.line)
                  : null,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: level > 0 ? FontWeight.w600 : FontWeight.w500,
                fontFeatures: tabular,
                color: future || (!work && level == 0)
                    ? c.inkSoft
                    : farmCellText(context, level),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: '${month.month}월 파밍 밭, 파밍한 날 $farmed일',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final w in weekdayLabels)
                Expanded(
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: c.inkSoft),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: () {
                            final day = r * 7 + col - lead + 1;
                            return day < 1 || day > days
                                ? const SizedBox()
                                : cell(day);
                          }(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          const FarmLegend(),
        ],
      ),
    );
  }
}

/// 적게 ▢▣▣▣ 많이
class FarmLegend extends StatelessWidget {
  const FarmLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 11, color: context.colors.inkSoft);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('적게', style: style),
        const SizedBox(width: 6),
        for (var l = 1; l <= 4; l++)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: farmCellColor(context, l),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        const SizedBox(width: 6),
        Text('많이', style: style),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 주간: 요일별 파밍 탑

/// 요일마다 그날 파밍한 혜택을 아이콘 하나로 보여주고 아래에 금액을 적는다.
/// 2개 이상이면 알림처럼 개수를 붙이고, 누르면 그날 기록이 아래로 쭈르륵 펼쳐진다.
class WeekStacks extends StatefulWidget {
  const WeekStacks({super.key, required this.days, this.today});

  /// 월~일 7일치 (날짜, 그날 기록).
  final List<(DateTime, List<BenefitRecord>)> days;
  final DateTime? today;

  @override
  State<WeekStacks> createState() => _WeekStacksState();
}

class _WeekStacksState extends State<WeekStacks> {
  static const _icon = 32.0;

  /// 펼친 요일(0=월). 없으면 null.
  int? _open;

  bool _isToday(DateTime d) {
    final t = widget.today;
    return t != null &&
        d.year == t.year &&
        d.month == t.month &&
        d.day == t.day;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final days = widget.days;
    final open = _open != null && days[_open!].$2.isNotEmpty ? _open : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, (date, records)) in days.indexed)
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: _icon + 16,
                      child: records.isEmpty
                          ? Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  color: c.line,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : Align(
                              alignment: Alignment.bottomCenter,
                              child: _GroupMarker(
                                records: records,
                                size: _icon,
                                selected: i == open,
                                onTap: () => setState(
                                  () => _open = i == open ? null : i,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      records.isEmpty
                          ? '–'
                          : shortWon(records.fold(0, (s, r) => s + r.amount)),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: tabular,
                        color: records.isEmpty ? c.inkSoft : c.benefitInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      weekdayLabels[date.weekday - 1],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _isToday(date)
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: _isToday(date) ? c.fieldText : c.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        _Expanded(
          openKey: open,
          records: open == null ? const [] : days[open].$2,
        ),
      ],
    );
  }
}

/// 펼친 묶음: 한 줄씩 차례로 떨어지듯 나타난다. [openKey]가 null 이면 접힘.
class _Expanded extends StatelessWidget {
  const _Expanded({required this.openKey, required this.records});

  final Object? openKey;
  final List<BenefitRecord> records;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Motion.reduced(context)
          ? Duration.zero
          : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: openKey == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              key: ValueKey(openKey),
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  for (final (i, r) in records.indexed)
                    StaggerIn(
                      index: i,
                      child: _RecordLine(record: r),
                    ),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// 일간: 시간 띠

/// 근무 시간을 가로 띠로 그리고, 혜택을 챙긴 시각에 아이콘을 찍는다.
///
/// 가까운 시각에 몰린 혜택은 아이콘 하나로 묶고 알림처럼 개수를 붙인다.
/// 아이콘을 누르면 그 묶음의 기록이 아래로 한 줄씩 쭈르륵 펼쳐지고, 다시 누르면 접힌다.
class DayTimeline extends StatefulWidget {
  const DayTimeline({
    super.key,
    required this.records,
    this.startMinute,
    this.endMinute,
    this.nowMinute,
  });

  final List<BenefitRecord> records;

  /// 근무 시작·끝(분). 쉬는 날이면 null.
  final int? startMinute;
  final int? endMinute;

  /// 오늘이면 지금 시각(분)에 표시를 둔다.
  final int? nowMinute;

  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<DayTimeline> {
  static const _icon = 32.0;

  /// 펼친 묶음의 첫 기록 id. 기록이 바뀌어도 같은 묶음을 가리킨다.
  String? _open;

  static int _minuteOf(BenefitRecord r) => r.at.hour * 60 + r.at.minute;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final records = [...widget.records]..sort((a, b) => a.at.compareTo(b.at));
    final times = records.map(_minuteOf).toList();
    // 보여줄 시간 범위: 근무 시간과 기록을 모두 담고 정시로 맞춘다.
    var from = widget.startMinute ?? (times.isEmpty ? 9 * 60 : times.first);
    var to = widget.endMinute ?? (times.isEmpty ? 18 * 60 : times.last);
    if (times.isNotEmpty) {
      from = math.min(from, times.first);
      to = math.max(to, times.last);
    }
    from = (from ~/ 60) * 60;
    to = math.min(24 * 60, ((to + 59) ~/ 60) * 60);
    if (to - from < 120) to = math.min(24 * 60, from + 120);
    final span = (to - from).toDouble();
    final now = widget.nowMinute;
    final showNow = now != null && now >= from && now <= to;

    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        double x(int minute) =>
            (_icon / 2) + (w - _icon) * ((minute - from) / span).clamp(0, 1);

        // 아이콘이 겹칠 만큼 가까운 기록끼리 한 묶음으로.
        final groups = <List<BenefitRecord>>[];
        final groupX = <double>[];
        for (final r in records) {
          final px = x(_minuteOf(r));
          if (groups.isNotEmpty && px - groupX.last < _icon + 6) {
            groups.last.add(r);
          } else {
            groups.add([r]);
            groupX.add(px);
          }
        }
        final open = groups.indexWhere((g) => g.first.id == _open);

        return Semantics(
          label: records.isEmpty
              ? '이날은 파밍한 게 없어요'
              : '시간대별 파밍 ${records.length}번',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _icon + 26,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 띠: 전체 범위는 옅게, 근무 시간은 초록으로
                    Positioned(
                      left: _icon / 2,
                      right: _icon / 2,
                      bottom: 0,
                      height: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.shade,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    if (widget.startMinute != null && widget.endMinute != null)
                      Positioned(
                        left: x(widget.startMinute!),
                        width: x(widget.endMinute!) - x(widget.startMinute!),
                        bottom: 0,
                        height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.secondary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    if (showNow)
                      Positioned(
                        left: x(now) - 1.5,
                        bottom: -3,
                        width: 3,
                        height: 14,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.fieldText,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    for (var g = 0; g < groups.length; g++) ...[
                      // 아이콘에서 띠까지 이어지는 가는 줄기
                      Positioned(
                        left: groupX[g] - 0.75,
                        bottom: 8,
                        width: 1.5,
                        height: 10,
                        child: const ColoredBox(color: AppColors.benefit),
                      ),
                      Positioned(
                        left: groupX[g] - _icon / 2 - 8,
                        bottom: 14,
                        child: _GroupMarker(
                          records: groups[g],
                          size: _icon,
                          selected: g == open,
                          onTap: () => setState(
                            () => _open = g == open ? null : groups[g].first.id,
                          ),
                        ),
                      ),
                    ],
                    if (records.isEmpty)
                      Positioned.fill(
                        bottom: 14,
                        child: Center(
                          child: Text(
                            '이날은 파밍한 게 없어요',
                            style: TextStyle(fontSize: 13, color: c.inkSoft),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 묶음마다 아래에 금액(주간과 같은 짧은 표기)
              if (groups.isNotEmpty)
                SizedBox(
                  height: 20,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var g = 0; g < groups.length; g++)
                        Positioned(
                          left: groupX[g] - 30,
                          width: 60,
                          top: 4,
                          child: Text(
                            shortWon(groups[g].fold(0, (s, r) => s + r.amount)),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFeatures: tabular,
                              color: c.benefitInk,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    clock(from),
                    style: TextStyle(fontSize: 11, color: c.inkSoft),
                  ),
                  const Spacer(),
                  if (showNow)
                    Text(
                      '지금 ${clock(now)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.fieldText,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    clock(to),
                    style: TextStyle(fontSize: 11, color: c.inkSoft),
                  ),
                ],
              ),
              _Expanded(
                openKey: open < 0 ? null : _open,
                records: open < 0 ? const [] : groups[open],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 시간 띠 위의 아이콘. 여러 개가 묶이면 대표 아이콘 하나에 개수 배지를 붙인다.
class _GroupMarker extends StatelessWidget {
  const _GroupMarker({
    required this.records,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final List<BenefitRecord> records;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = records.length;
    final total = records.fold(0, (s, r) => s + r.amount);
    return Semantics(
      button: true,
      selected: selected,
      label: count == 1
          ? '${clock(records.first.at.hour * 60 + records.first.at.minute)} '
                '${records.first.name} ${won(total)}'
          : '${records.first.name} 외 ${count - 1}개, ${won(total)}. 눌러서 펼치기',
      excludeSemantics: true,
      // 아이콘(32)보다 넓게 눌리도록 둘레에 여백을 둔다(48×48).
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: SpringPress(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? context.colors.benefitSoft : null,
                  ),
                  child: BenefitGlyph(
                    records.first.icon,
                    size: size,
                    bare: true,
                  ),
                ),
                if (count > 1)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: context.colors.card,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          fontFeatures: tabular,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 펼친 묶음의 기록 한 줄: 아이콘 · 이름 · 시각 · 금액.
class _RecordLine extends StatelessWidget {
  const _RecordLine({required this.record});

  final BenefitRecord record;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = record;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          BenefitGlyph(r.icon, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              r.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            clock(r.at.hour * 60 + r.at.minute),
            style: TextStyle(fontSize: 12, color: c.inkSoft),
          ),
          const SizedBox(width: 10),
          Text(
            '+${won(r.amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: tabular,
              color: c.benefitInk,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 연간: 12개월 격자

/// 한 해를 달마다 작은 칸으로. 칸에는 그달 파밍 수익과 짧은 골드 막대.
class YearGrid extends StatelessWidget {
  const YearGrid({super.key, required this.amounts, this.currentMonth});

  /// 1월부터 12개 달의 파밍 수익. null 이면 아직 기록이 없는 달(시작 전·앞으로 올 달).
  final List<int?> amounts;
  final int? currentMonth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final max = amounts.fold<int>(0, (m, v) => math.max(m, v ?? 0));

    Widget cell(int m) {
      final v = amounts[m - 1];
      final current = m == currentMonth;
      return Semantics(
        label: '$m월 ${v == null ? '기록 없음' : won(v)}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: v == null ? Colors.transparent : c.shade,
            borderRadius: BorderRadius.circular(12),
            border: current
                ? Border.all(color: c.fieldText, width: 1.5)
                : v == null
                ? Border.all(color: c.line)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$m월',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: current ? FontWeight.w600 : FontWeight.w500,
                  color: current ? c.fieldText : c.inkSoft,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  v == null ? '–' : (v > 0 ? '+${shortWon(v)}' : '0'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: tabular,
                    color: v == null || v == 0 ? c.inkSoft : c.benefitInk,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: v == null || max == 0 ? 0 : v / max,
                  minHeight: 4,
                  backgroundColor: v == null ? Colors.transparent : c.line,
                  color: AppColors.benefit,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var r = 0; r < 4; r++) ...[
          if (r > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(child: cell(r * 3 + col + 1)),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
