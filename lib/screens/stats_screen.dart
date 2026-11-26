import 'package:flutter/material.dart';

import '../app_store.dart';
import '../format.dart';
import '../period.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/benefit_glyph.dart';
import 'share_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Period _period = Period.containing(PeriodKind.day, widget.store.now());

  AppStore get store => widget.store;

  void _setKind(PeriodKind kind) {
    // 종류를 바꾸면 오늘이 들어 있는 기간부터 보여준다.
    setState(() => _period = Period.containing(kind, store.now()));
  }

  void _openShare(PeriodTotals totals, List<BenefitSummary> summaries) {
    if (totals.isEmpty) {
      showAppToast(context, '이 기간에는 기록이 없어서 결산 이미지를 만들 수 없어요');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            ShareScreen(period: _period, totals: totals, summaries: summaries),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = store.now();
        final period = _period;
        final totals = store.totals(period.from, period.to, at: now);
        final summaries = store.summarize(period.from, period.to);
        final insights = buildInsights(totals, summaries);
        final buckets = period.buckets;

        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Text(
                  '수확 결산',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              SegmentedButton<PeriodKind>(
                showSelectedIcon: false,
                segments: [
                  for (final k in PeriodKind.values)
                    ButtonSegment(value: k, label: Text(k.label)),
                ],
                selected: {period.kind},
                onSelectionChanged: (v) => _setKind(v.first),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    tooltip: '이전 기간',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => _period = period.previous),
                  ),
                  Expanded(
                    child: Text(
                      period.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFeatures: tabular,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '다음 기간',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: period.canGoNext(now)
                        ? () => setState(() => _period = period.next)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _TotalsCard(totals: totals),
              if (totals.isEmpty) ...[
                const SizedBox(height: 16),
                const _EmptyPeriod(),
              ] else ...[
                if (buckets.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ChartCard(
                    period: period,
                    values: [
                      for (final b in buckets)
                        store.totals(b.from, b.to, at: now),
                    ],
                  ),
                ],
                if (insights.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _InsightCard(lines: insights),
                ],
                const SizedBox(height: 28),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '파밍한 혜택',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                if (summaries.isEmpty)
                  const _NoBenefits()
                else
                  _SummaryCard(summaries: summaries, benefit: totals.benefit),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _openShare(totals, summaries),
                icon: const Icon(Icons.image_outlined),
                label: const Text('결산 이미지 만들기'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals});
  final PeriodTotals totals;

  @override
  Widget build(BuildContext context) {
    final total = totals.total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '총 수확',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                won(total),
                style: const TextStyle(
                  fontSize: 38,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  fontFeatures: tabular,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 급여와 혜택이 총액에서 차지하는 몫.
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 10,
                child: total == 0
                    ? const ColoredBox(color: AppColors.line)
                    : Row(
                        // 색 조각이 막대 높이를 꽉 채우게 한다(안 그러면 높이 0으로 안 보인다).
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 원 단위 금액을 그대로 비율로 쓰면 값이 너무 커서 막대가
                          // 그려지지 않는다. 1000 분율로 줄여 쓴다.
                          if (totals.salary > 0)
                            Expanded(
                              flex: (totals.salary * 1000 / total)
                                  .round()
                                  .clamp(1, 1000),
                              child: const ColoredBox(color: AppColors.salary),
                            ),
                          if (totals.salary > 0 && totals.benefit > 0)
                            const SizedBox(width: 2),
                          if (totals.benefit > 0)
                            Expanded(
                              flex: (totals.benefit * 1000 / total)
                                  .round()
                                  .clamp(1, 1000),
                              child: const ColoredBox(color: AppColors.benefit),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            _LegendRow(
              color: AppColors.salary,
              label: '기본 수익',
              value: won(totals.salary),
            ),
            const SizedBox(height: 8),
            _LegendRow(
              color: AppColors.benefit,
              label: '파밍 수익',
              value: '${totals.benefit > 0 ? '+' : ''}${won(totals.benefit)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 15)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFeatures: tabular,
          ),
        ),
      ],
    );
  }
}

/// 구간별 급여(풀색)와 혜택(곡식색)을 쌓은 막대 그래프.
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.period, required this.values});

  final Period period;
  final List<PeriodTotals> values;

  @override
  Widget build(BuildContext context) {
    final buckets = period.buckets;
    final max = values.fold(0, (m, v) => v.total > m ? v.total : m);
    const chartHeight = 120.0;
    final gap = buckets.length > 12 ? 2.0 : 6.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  period.kind == PeriodKind.year ? '달마다' : '날마다',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '가장 많은 구간 ${won(max)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                    fontFeatures: tabular,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              label: '구간별 급여와 혜택 막대 그래프',
              child: SizedBox(
                height: chartHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < values.length; i++) ...[
                      if (i > 0) SizedBox(width: gap),
                      Expanded(
                        child: _Bar(
                          value: values[i],
                          max: max,
                          height: chartHeight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < buckets.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(
                    child: Text(
                      period.bucketLabel(buckets[i]),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSoft,
                        fontFeatures: tabular,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.max, required this.height});

  final PeriodTotals value;
  final int max;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (max == 0 || value.total == 0) {
      return Container(
        height: 2,
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(1),
        ),
      );
    }
    // 혜택 최소 높이만큼 여유를 두어 막대가 그래프 높이를 넘지 않게 한다.
    final usable = height - 2;
    final salaryH = usable * value.salary / max;
    final benefitH = usable * value.benefit / max;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.benefit > 0)
            Container(
              // 아주 작은 혜택도 보이도록 최소 높이를 준다.
              height: benefitH < 2 ? 2 : benefitH,
              color: AppColors.benefit,
            ),
          if (value.salary > 0)
            Container(height: salaryH, color: AppColors.salary),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.benefitSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '파밍 일지',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.benefitInk,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Text(lines[i], style: const TextStyle(fontSize: 15, height: 1.45)),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summaries, required this.benefit});

  final List<BenefitSummary> summaries;
  final int benefit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (var i = 0; i < summaries.length; i++) ...[
              if (i > 0) const Divider(indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        BenefitGlyph(summaries[i].icon, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            summaries[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${summaries[i].count}번',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.inkSoft,
                            fontFeatures: tabular,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          won(summaries[i].amount),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            fontFeatures: tabular,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: benefit == 0 ? 0 : summaries[i].amount / benefit,
                        minHeight: 6,
                        backgroundColor: AppColors.benefitSoft,
                        color: AppColors.benefit,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoBenefits extends StatelessWidget {
  const _NoBenefits();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        '이 기간에 파밍한 혜택이 없어요',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.inkSoft),
      ),
    );
  }
}

class _EmptyPeriod extends StatelessWidget {
  const _EmptyPeriod();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Text('🌾', style: TextStyle(fontSize: 30)),
          SizedBox(height: 8),
          Text(
            '이 기간에는 기록이 없어요',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4),
          Text(
            '급여도 혜택도 쌓이지 않은 기간이에요',
            style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
