import 'package:flutter/material.dart';

import '../app_store.dart';
import '../format.dart';
import '../models.dart';
import '../period.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/benefit_glyph.dart';
import '../widgets/farm_charts.dart';
import '../widgets/top_benefits.dart';
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

  String _chartTitle(Period period, DateTime now) {
    switch (period.kind) {
      case PeriodKind.day:
        return dateOnly(now) == period.from ? '오늘의 파밍' : '이날의 파밍';
      case PeriodKind.week:
        return '요일별 파밍';
      case PeriodKind.month:
        return '${period.from.month}월 파밍 밭';
      case PeriodKind.year:
        return '달마다 파밍';
    }
  }

  bool _isWorkDay(DateTime day) =>
      store.settingsFor(day)?.workWeekdays.contains(day.weekday) ?? false;

  /// 기간 종류마다 다른 그림. 모두 파밍 수익만 그린다.
  Widget _chart(Period period, DateTime now) {
    final today = dateOnly(now);
    switch (period.kind) {
      case PeriodKind.day:
        final day = period.from;
        final settings = store.settingsFor(day);
        final working = _isWorkDay(day);
        return DayTimeline(
          records: store.recordsBetween(day, day),
          startMinute: working ? settings!.startMinute : null,
          endMinute: working ? settings!.endMinute : null,
          nowMinute: day == today ? now.hour * 60 + now.minute : null,
        );
      case PeriodKind.week:
        return WeekStacks(
          today: today,
          days: [
            for (final b in period.buckets)
              (b.from, store.recordsBetween(b.from, b.from)),
          ],
        );
      case PeriodKind.month:
        final days = period.buckets.map((b) => b.from).toList();
        final current =
            period.from.year == now.year && period.from.month == now.month;
        return FarmField(
          month: period.from,
          amounts: [for (final d in days) store.benefitBetween(d, d)],
          workDays: [for (final d in days) _isWorkDay(d)],
          lastDay: current ? now.day : null,
          today: current ? now.day : null,
        );
      case PeriodKind.year:
        return YearGrid(
          currentMonth: period.from.year == now.year ? now.month : null,
          amounts: [
            for (final b in period.buckets)
              // 아직 오지 않은 달, 월급파밍을 쓰기 전 달은 빈칸
              b.from.isAfter(today) || store.settingsFor(b.to) == null
                  ? null
                  : store.benefitBetween(b.from, b.to),
          ],
        );
    }
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
        final prev = period.previous;
        final prevTotals = store.totals(prev.from, prev.to, at: now);

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
              _HarvestHero(
                kind: period.kind,
                totals: totals,
                previous: prevTotals.isEmpty ? null : prevTotals,
              ),
              if (totals.isEmpty) ...[
                const SizedBox(height: 16),
                const _EmptyPeriod(),
              ] else ...[
                const SizedBox(height: 16),
                _ChartCard(
                  title: _chartTitle(period, now),
                  child: _chart(period, now),
                ),
                if (insights.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _InsightPager(lines: insights),
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
                else ...[
                  TopBenefitRow(summaries: summaries),
                  // 4위부터는 목록으로
                  if (summaries.length > 3) ...[
                    const SizedBox(height: 12),
                    _SummaryCard(
                      summaries: summaries.skip(3).toList(),
                      benefit: totals.benefit,
                    ),
                  ],
                ],
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

/// 맨 위 카드: 파밍 수익을 가장 크게, 지난 기간과 비교, 아래에 총 수확·기본 수익.
class _HarvestHero extends StatelessWidget {
  const _HarvestHero({
    required this.kind,
    required this.totals,
    required this.previous,
  });

  final PeriodKind kind;
  final PeriodTotals totals;

  /// 지난 기간 합계. 기록이 없으면 null(비교 문구를 숨긴다).
  final PeriodTotals? previous;

  String? get _compare {
    final p = previous;
    if (p == null) return null;
    final (name, with_) = switch (kind) {
      PeriodKind.day => ('어제', '어제와'),
      PeriodKind.week => ('지난주', '지난주와'),
      PeriodKind.month => ('지난달', '지난달과'),
      PeriodKind.year => ('작년', '작년과'),
    };
    final diff = totals.benefit - p.benefit;
    if (diff == 0) return '$with_ 같아요';
    return diff > 0
        ? '$name보다 +${won(diff)} 더 챙겼어요'
        : '$name보다 ${won(-diff)} 적어요';
  }

  @override
  Widget build(BuildContext context) {
    final compare = _compare;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: surfaceBox(color: AppColors.field, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '파밍 수익',
            style: TextStyle(
              color: AppColors.fieldMuted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${totals.benefit > 0 ? '+' : ''}${won(totals.benefit)}',
              style: const TextStyle(
                color: AppColors.benefitOnDark,
                fontSize: 38,
                height: 1.2,
                fontWeight: FontWeight.w600,
                fontFeatures: tabular,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (compare != null) ...[
            const SizedBox(height: 4),
            Text(
              compare,
              style: const TextStyle(
                color: AppColors.fieldMuted,
                fontSize: 13,
                fontFeatures: tabular,
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.darkTrack),
          const SizedBox(height: 14),
          _HeroRow(label: '총 수확', value: won(totals.total)),
          const SizedBox(height: 6),
          _HeroRow(label: '기본 수익', value: won(totals.salary)),
        ],
      ),
    );
  }
}

class _HeroRow extends StatelessWidget {
  const _HeroRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.fieldMuted, fontSize: 14),
        ),
        const SizedBox(width: 12),
        // 큰 글자 설정에서는 금액이 줄어들어 한 줄에 들어간다.
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFeatures: tabular,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 기간별 그림을 담는 카드.
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// 파밍 일지: 한 줄씩 크게, 옆으로 넘겨 본다.
class _InsightPager extends StatefulWidget {
  const _InsightPager({required this.lines});
  final List<String> lines;

  @override
  State<_InsightPager> createState() => _InsightPagerState();
}

class _InsightPagerState extends State<_InsightPager> {
  final _pages = PageController(viewportFraction: 0.9);
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lines = widget.lines;
    const body = TextStyle(
      fontFamily: appFont,
      fontSize: 17,
      height: 1.45,
      fontWeight: FontWeight.w600,
    );
    final scaler = MediaQuery.textScalerOf(context);
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, box) {
            // 가장 긴 문구가 들어가는 높이로 맞춘다(카드 폭 = 화면의 90% - 여백).
            final textWidth = box.maxWidth * 0.9 - 10 - 36;
            final tallest = lines
                .map(
                  (l) => (TextPainter(
                    text: TextSpan(text: l, style: body),
                    textDirection: TextDirection.ltr,
                    textScaler: scaler,
                    maxLines: 3,
                  )..layout(maxWidth: textWidth)).height,
                )
                .fold(0.0, (m, h) => h > m ? h : m);
            final height = 16 + scaler.scale(12) * 1.4 + 6 + tallest + 16 + 2;
            return SizedBox(
              height: height,
              child: PageView.builder(
                controller: _pages,
                padEnds: false,
                itemCount: lines.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    decoration: BoxDecoration(
                      color: c.benefitSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '파밍 일지 ${i + 1}/${lines.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: c.benefitInk,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            lines[i],
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (lines.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < lines.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.benefit : c.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
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
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.inkSoft,
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
                        backgroundColor: context.colors.benefitSoft,
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
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '이 기간에 파밍한 혜택이 없어요',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.colors.inkSoft),
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
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
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
            style: TextStyle(fontSize: 13, color: context.colors.inkSoft),
          ),
        ],
      ),
    );
  }
}
