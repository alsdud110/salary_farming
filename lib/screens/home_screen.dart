import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_store.dart';
import '../format.dart';
import '../models.dart';
import '../motion.dart';
import '../salary_calculator.dart';
import '../theme.dart';
import '../widgets/benefit_glyph.dart';
import '../widgets/brand_symbol.dart';
import '../widgets/farm_burst.dart';
import '../widgets/live_amount.dart';
import '../widgets/template_sheet.dart';

/// 홈에 바로 놓는 혜택 수(한 줄). 나머지와 직접 추가는 "전체 보기"·"파밍하기" 시트에 있다.
const _homeTileCount = 3;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store, this.onOpenSettings});

  final AppStore store;

  /// 오른쪽 위 설정 버튼.
  final VoidCallback? onOpenSettings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _timer;

  /// "전체 보기" 시트에서 방금 적립한 기록. 칸이 사라진 뒤라 수확 카드에서 금액을 띄운다.
  BenefitRecord? _justCredited;

  /// 동전이 날아갈 곳: 수확 카드의 파밍 수익 금액.
  final _benefitTargetKey = GlobalKey();

  /// 파밍 효과를 보여줄지. 설정을 끄거나 기기의 동작 줄이기가 켜져 있으면 끈다.
  bool get _effects => store.farmAnimation && !Motion.reduced(context);

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.addListener(_onStore);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    store.removeListener(_onStore);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 화면이 꺼져 있는 동안에는 굳이 매초 그리지 않는다.
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      setState(() {});
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  /// 적립. 저장은 [AppStore.credit]이 하고, 여기서는 반응(진동·효과·알림)만 붙인다.
  /// 효과는 저장을 기다리지 않고 바로 시작하며 터치를 막지 않아 연속으로 눌러도 늦어지지 않는다.
  /// [tile]은 누른 칸(시트에서 고른 경우 null).
  Future<void> _credit(BenefitTemplate t, [BuildContext? tile]) async {
    if (store.farmHaptic) HapticFeedback.lightImpact();
    final tileBox = tile?.findRenderObject() as RenderBox?;
    if (_effects && tileBox != null) {
      FarmBurst.show(
        context,
        from: tileBox,
        to: _benefitTargetKey.currentContext?.findRenderObject() as RenderBox?,
        amount: t.amount,
      );
    }
    final record = await store.credit(t);
    if (!mounted) return;
    if (tileBox == null) setState(() => _justCredited = record);
    showAppSnackBar(
      context,
      farmMessage(t),
      actionLabel: '취소',
      onAction: () => store.removeRecord(record.id),
    );
  }

  Future<void> _removeRecord(BenefitRecord r) async {
    await store.removeRecord(r.id);
    if (!mounted) return;
    showAppToast(context, '${r.name} 기록을 지웠어요');
  }

  void _edit(BenefitTemplate t) =>
      showTemplateSheet(context, store, template: t);
  void _add() => showTemplateSheet(context, store);

  Future<void> _openFarmSheet() async {
    final picked = await showModalBottomSheet<BenefitTemplate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: Motion.sheet,
      builder: (_) => _FarmSheet(store: store, onAdd: _add, onEdit: _edit),
    );
    if (picked != null) await _credit(picked);
  }

  @override
  Widget build(BuildContext context) {
    final now = store.now();
    final settings = store.currentSettings!;
    // 오늘 급여는 화면이 그려질 때마다 지금 시각으로 다시 계산해 끊김 없이 오르게 한다.
    double salaryAt() {
      final n = store.now();
      return store.salaryOn(n, n);
    }

    final monthBefore = store.monthSalary(now) - store.salaryOn(now, now);
    final monthExpected = SalaryCalculator.expectedInMonth(
      settings,
      now,
    ).round();
    final todayRecords = store.recordsOn(now);
    final benefit = todayRecords.fold(0, (sum, r) => sum + r.amount);
    final phase = SalaryCalculator.phase(settings, now);
    final tiles = store.templatesByFrequency.take(_homeTileCount).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          StaggerIn(
            index: 0,
            child: _Header(
              now: now,
              phase: phase,
              onOpenSettings: widget.onOpenSettings,
            ),
          ),
          const SizedBox(height: 16),
          StaggerIn(
            index: 1,
            child: _HarvestCard(
              settings: settings,
              now: now,
              phase: phase,
              salaryAt: salaryAt,
              benefit: benefit,
              justCredited: _justCredited,
              animate: _effects,
              benefitKey: _benefitTargetKey,
            ),
          ),
          const SizedBox(height: 24),
          StaggerIn(
            index: 2,
            child: _WorkProgress(settings: settings, now: now, phase: phase),
          ),
          const SizedBox(height: 24),
          StaggerIn(
            index: 3,
            child: _MonthCard(
              now: now,
              valueAt: () => monthBefore + salaryAt(),
              expected: monthExpected,
              growing: SalaryCalculator.isGrowing(settings, now),
            ),
          ),
          const SizedBox(height: 28),
          _SectionTitle(
            '무엇을 파밍했나요?',
            trailing: TextButton(
              onPressed: _openFarmSheet,
              child: const Text('전체 보기'),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '누르면 바로 적립돼요. 길게 누르면 고칠 수 있어요.',
            style: TextStyle(fontSize: 13, color: context.colors.inkSoft),
          ),
          const SizedBox(height: 12),
          _BenefitGrid(templates: tiles, onTap: _credit, onLongPress: _edit),
          const SizedBox(height: 16),
          _AddButton(onPressed: _add),
          const SizedBox(height: 32),
          _SectionTitle(
            '오늘의 파밍 일지',
            trailing: todayRecords.isEmpty
                ? null
                : Text(
                    '${todayRecords.length}건',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.inkSoft,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          if (todayRecords.isEmpty)
            const _EmptyRecords()
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < todayRecords.length; i++) ...[
                    if (i > 0) const Divider(indent: 72, endIndent: 16),
                    _RecordRow(
                      record: todayRecords[i],
                      onDelete: () => _removeRecord(todayRecords[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 상단

class _Header extends StatelessWidget {
  const _Header({required this.now, required this.phase, this.onOpenSettings});

  final DateTime now;
  final WorkPhase phase;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Row(
                children: [
                  BrandSymbol(size: 30),
                  SizedBox(width: 8),
                  Text(
                    '월급파밍',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${now.month}월 ${now.day}일 ${weekdayLabels[now.weekday - 1]}요일',
                style: TextStyle(fontSize: 14, color: context.colors.inkSoft),
              ),
            ],
          ),
        ),
        if (onOpenSettings != null)
          IconButton(
            tooltip: '설정',
            onPressed: onOpenSettings,
            iconSize: 26,
            icon: Icon(Icons.settings_outlined, color: context.colors.ink),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 메인 카드: 오늘의 총 수확

class _HarvestCard extends StatelessWidget {
  const _HarvestCard({
    required this.settings,
    required this.now,
    required this.phase,
    required this.salaryAt,
    required this.benefit,
    required this.justCredited,
    required this.animate,
    required this.benefitKey,
  });

  final WorkSettings settings;
  final DateTime now;
  final WorkPhase phase;
  final double Function() salaryAt;
  final int benefit;
  final BenefitRecord? justCredited;

  /// 파밍 수익이 바뀔 때 이전 금액에서 새 금액까지 올라가게 할지.
  final bool animate;
  final Key benefitKey;

  String get _hint {
    switch (phase) {
      case WorkPhase.working:
        final perSec = SalaryCalculator.perSecond(settings, now);
        return '매초 +${perSec.toStringAsFixed(2)}원씩 자라는 중';
      case WorkPhase.beforeWork:
        return '${clock(settings.startMinute)}부터 자라기 시작해요';
      case WorkPhase.onBreak:
        if (settings.paidBreak) {
          final perSec = SalaryCalculator.perSecond(settings, now);
          return '휴게 중에도 매초 +${perSec.toStringAsFixed(2)}원씩 자라는 중';
        }
        return '${clock(settings.breakEndMinute)}에 다시 자라요';
      case WorkPhase.afterWork:
        return '오늘 수확을 모두 거뒀어요';
      case WorkPhase.dayOff:
        return '쉬는 날에도 파밍 수익은 쌓을 수 있어요';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 파밍 수익만 이전 값에서 새 값으로 올라가게 하고, 기본 수익은 지금 시각으로 매 프레임
    // 계산한 값을 그대로 더한다. 그래서 효과 중에도 실시간 급여와 어긋나지 않고, 끝나면
    // 저장된 금액과 정확히 같아진다.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: benefit.toDouble()),
      duration: animate ? const Duration(milliseconds: 600) : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => _build(shown),
    );
  }

  Widget _build(double shownBenefit) {
    final growing = SalaryCalculator.isGrowing(settings, now);
    final counting = shownBenefit != benefit;
    final shownWon = shownBenefit.floor();
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: surfaceBox(color: AppColors.field, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '오늘의 총 수확',
                style: TextStyle(
                  color: AppColors.fieldMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              LiveDot(live: growing),
              const Spacer(),
              if (animate) _CreditPop(record: justCredited),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: LiveAmount(
              valueAt: () => salaryAt() + shownBenefit,
              running: growing || counting,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                height: 1.15,
                fontWeight: FontWeight.w600,
                fontFeatures: tabular,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _hint,
            style: const TextStyle(color: AppColors.fieldMuted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.darkTrack),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SplitValue(
                    label: '기본 수익',
                    child: LiveAmount(
                      valueAt: salaryAt,
                      running: growing,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        fontFeatures: tabular,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SplitValue(
                    label: '파밍 수익',
                    child: Text(
                      '${shownWon > 0 ? '+' : ''}${won(shownWon)}',
                      key: benefitKey,
                      maxLines: 1,
                      semanticsLabel:
                          '${benefit > 0 ? '+' : ''}${won(benefit)}',
                      style: const TextStyle(
                        color: AppColors.benefitOnDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        fontFeatures: tabular,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitValue extends StatelessWidget {
  const _SplitValue({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.fieldMuted, fontSize: 14),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ],
    );
  }
}

/// 적립 직후 "+2,000" 이 잠깐 떠올랐다 사라진다.
class _CreditPop extends StatelessWidget {
  const _CreditPop({required this.record});

  final BenefitRecord? record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    if (r == null || MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(r.id),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, t, _) {
        final opacity = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, -14 * t),
            child: ExcludeSemantics(
              child: Text(
                '+${won(r.amount)}',
                style: const TextStyle(
                  color: AppColors.benefitOnDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 오늘의 근무

class _WorkProgress extends StatelessWidget {
  const _WorkProgress({
    required this.settings,
    required this.now,
    required this.phase,
  });

  final WorkSettings settings;
  final DateTime now;
  final WorkPhase phase;

  String _left(int seconds) {
    final m = (seconds / 60).ceil();
    return duration(m < 1 ? 1 : m);
  }

  String get _status {
    final sec = now.hour * 3600 + now.minute * 60 + now.second;
    switch (phase) {
      case WorkPhase.working:
      case WorkPhase.onBreak:
        return '퇴근까지 ${_left(settings.endMinute * 60 - sec)}';
      case WorkPhase.beforeWork:
        return '출근까지 ${_left(settings.startMinute * 60 - sec)}';
      case WorkPhase.afterWork:
        return '오늘 근무 끝, 수고했어요';
      case WorkPhase.dayOff:
        return '오늘은 근무가 없는 날이에요';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProgressSection(
      title: '오늘의 근무',
      chip: _PhaseChip(phase: phase),
      progress: SalaryCalculator.progress(settings, now),
      primary: Text(
        _status,
        style: TextStyle(fontSize: 14, color: context.colors.ink),
      ),
      secondary: phase == WorkPhase.dayOff
          ? null
          : '${clock(settings.startMinute)} – ${clock(settings.endMinute)}',
    );
  }
}

/// 제목·% 줄, 막대, 아래 한 줄로 된 진행 묶음. 오늘의 근무와 이번 달 누적 월급이
/// 같은 틀을 써서 두 막대의 굵기·간격·글자가 늘 같다.
class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.title,
    required this.progress,
    required this.primary,
    required this.secondary,
    this.chip,
  });

  final String title;
  final Widget? chip;
  final double progress;

  /// 아래 줄 왼쪽(진한 글자).
  final Widget primary;

  /// 아래 줄 오른쪽(흐린 글자). 없으면 비운다.
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 좁은 화면·큰 글자에서는 상태 칩이 다음 줄로 내려간다.
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ?chip,
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(progress * 100).floor()}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.colors.fieldText,
                fontFeatures: tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          // 1초마다 바뀌는 진행률 사이를 고르게 이어 막대도 멈칫하지 않게 한다.
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: const Duration(seconds: 1),
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 10,
              backgroundColor: context.colors.secondary,
              color: context.colors.salary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 2,
          children: [
            primary,
            if (secondary != null)
              Text(
                secondary!,
                style: TextStyle(fontSize: 13, color: context.colors.inkSoft),
              ),
          ],
        ),
      ],
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.phase});
  final WorkPhase phase;

  @override
  Widget build(BuildContext context) {
    final active = phase == WorkPhase.working;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: active ? context.colors.secondary : context.colors.shade,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        phase.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: active ? context.colors.fieldText : context.colors.inkSoft,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 이번 달

/// 11/01 처럼 두 자리 월/일.
String _mmdd(int month, int day) =>
    '${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}';

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.now,
    required this.valueAt,
    required this.expected,
    required this.growing,
  });

  final DateTime now;
  final double Function() valueAt;
  final int expected;
  final bool growing;

  @override
  Widget build(BuildContext context) {
    final ratio = expected <= 0 ? 0.0 : (valueAt() / expected).clamp(0.0, 1.0);
    // 오늘의 근무와 같은 틀: 제목·% 줄, 같은 굵기의 막대, 아래 한 줄.
    return _ProgressSection(
      title: '${now.month}월 누적 월급',
      // 제목 옆에 이번 달 전체 기간을 흐리게 붙인다. 예: (11/01~11/30)
      chip: Text(
        '(${_mmdd(now.month, 1)}~${_mmdd(now.month, DateTime(now.year, now.month + 1, 0).day)})',
        style: TextStyle(
          fontSize: 13,
          color: context.colors.inkSoft,
          fontFeatures: tabular,
        ),
      ),
      progress: ratio,
      primary: LiveAmount(
        valueAt: valueAt,
        running: growing,
        suffix: '원 쌓였어요',
        style: TextStyle(
          fontSize: 14,
          color: context.colors.ink,
          fontFeatures: tabular,
        ),
      ),
      secondary: '예상 실수령 ${won(expected)}',
    );
  }
}

// ---------------------------------------------------------------------------
// 혜택 그리드

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// 3열 혜택 그리드. 칸 높이는 글자 크기 설정에 맞춰 늘어난다.
class _BenefitGrid extends StatelessWidget {
  const _BenefitGrid({
    required this.templates,
    required this.onTap,
    required this.onLongPress,
  });

  final List<BenefitTemplate> templates;

  /// 누른 칸의 context도 넘겨 효과가 그 칸에서 시작하게 한다.
  final void Function(BenefitTemplate, BuildContext) onTap;
  final ValueChanged<BenefitTemplate> onLongPress;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: benefitGridDelegate(context),
      children: [
        for (final t in templates)
          Builder(
            builder: (tile) => BenefitTile(
              template: t,
              onTap: () => onTap(t, tile),
              onLongPress: () => onLongPress(t),
            ),
          ),
      ],
    );
  }
}

/// 3열 혜택 그리드 배치. 칸 높이는 아이콘·여백(고정)과 글자 두 줄(글자 크기 설정에
/// 따라 늘어남)을 더해 정하므로, 큰 글자에서도 칸 안이 넘치지 않는다.
SliverGridDelegate benefitGridDelegate(BuildContext context) {
  final scaler = MediaQuery.textScalerOf(context);
  // 이름 14px·금액 13px 한 줄씩(글꼴마다 줄 높이가 달라 넉넉히 1.6배) + 아이콘 44
  // + 여백 24 + 간격 10. 그래도 모자라면 칸 안 내용이 살짝 줄어든다(_TileBody).
  final text = scaler.scale(14) * 1.6 + scaler.scale(13) * 1.6;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    mainAxisExtent: 44 + 24 + 10 + text + 8,
  );
}

/// 혜택 칸 하나. 홈 그리드와 "파밍하기" 시트에서 같이 쓴다.
class BenefitTile extends StatelessWidget {
  const BenefitTile({
    super.key,
    required this.template,
    required this.onTap,
    this.onLongPress,
  });

  final BenefitTemplate template;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = template;
    return SpringPress(
      child: Semantics(
        button: true,
        label: '${t.name} ${won(t.amount)} 파밍하기',
        child: Material(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.tile),
            splashColor: context.colors.benefitSoft,
            highlightColor: context.colors.benefitSoft,
            onTap: onTap,
            onLongPress: onLongPress,
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: _TileBody(
                  children: [
                    BenefitGlyph(t.icon, size: 44, bare: true),
                    const SizedBox(height: 8),
                    Text(
                      t.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+${won(t.amount)}',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.colors.benefitInk,
                        fontFeatures: tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 칸 내용. 아주 큰 글자 설정에서 칸보다 커지면 넘치지 않고 비율대로 줄어든다.
class _TileBody extends StatelessWidget {
  const _TileBody({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class AddBenefitTile extends StatelessWidget {
  const AddBenefitTile({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SpringPress(
      child: Material(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: _TileBody(
              children: [
                Icon(Icons.add_circle, size: 40, color: context.colors.salary),
                SizedBox(height: 8),
                Text(
                  '직접 추가',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 2),
                Text(
                  '등록',
                  style: TextStyle(fontSize: 13, color: context.colors.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 골드 "직접 추가" 버튼. 내 혜택을 만드는 시트를 바로 연다(전체 혜택은 '전체 보기').
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.coin,
        // 골드 면 위 글자는 테마와 상관없이 짙게
        foregroundColor: AppColors.ink,
      ),
      icon: const Icon(Icons.add_circle_outline),
      label: const Text('직접 추가'),
    );
  }
}

/// 모든 혜택을 분류별로 보고 골라 적립하는 시트. 고른 혜택을 돌려준다.
class _FarmSheet extends StatefulWidget {
  const _FarmSheet({
    required this.store,
    required this.onAdd,
    required this.onEdit,
  });

  final AppStore store;
  final VoidCallback onAdd;
  final ValueChanged<BenefitTemplate> onEdit;

  @override
  State<_FarmSheet> createState() => _FarmSheetState();
}

class _FarmSheetState extends State<_FarmSheet> {
  BenefitCategory? _filter;

  /// 닫히는 동안 한 번 더 눌러도 두 번 닫히거나(아래 화면까지 닫힘) 두 번 적립되지 않게.
  bool _closing = false;

  void _close([BenefitTemplate? picked, VoidCallback? then]) {
    if (_closing) return;
    _closing = true;
    Navigator.pop(context, picked);
    then?.call();
  }

  @override
  Widget build(BuildContext context) {
    final templates = widget.store.templatesByFrequency
        .where((t) => _filter == null || t.category == _filter)
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '무엇을 파밍했나요?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: '닫기',
                onPressed: _close,
                icon: Icon(Icons.close, color: context.colors.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '하나를 고르면 바로 오늘 파밍 수익에 더해져요',
            style: TextStyle(fontSize: 14, color: context.colors.inkSoft),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: '전체',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final c in BenefitCategory.values)
                  _FilterChip(
                    label: c.label,
                    selected: _filter == c,
                    onTap: () => setState(() => _filter = c),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: benefitGridDelegate(context),
            children: [
              for (final t in templates)
                BenefitTile(
                  template: t,
                  onTap: () => _close(t),
                  onLongPress: () => _close(null, () => widget.onEdit(t)),
                ),
              AddBenefitTile(onTap: () => _close(null, widget.onAdd)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.field : context.colors.card,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : context.colors.inkSoft,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 오늘의 파밍 일지

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record, required this.onDelete});

  final BenefitRecord record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Row(
        children: [
          BenefitGlyph(r.icon, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  clock(r.at.hour * 60 + r.at.minute),
                  style: TextStyle(fontSize: 13, color: context.colors.inkSoft),
                ),
              ],
            ),
          ),
          Text(
            '+${won(r.amount)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.colors.benefitInk,
              fontFeatures: tabular,
            ),
          ),
          IconButton(
            tooltip: '${r.name} 기록 지우기',
            icon: Icon(Icons.close, size: 20, color: context.colors.inkSoft),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: surfaceBox(color: context.colors.shade),
      child: Column(
        children: [
          Icon(Icons.eco_outlined, size: 32, color: context.colors.salary),
          SizedBox(height: 8),
          Text(
            '아직 파밍한 게 없어요',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4),
          Text(
            '탕비실 커피 한 잔부터 파밍해 볼까요?',
            style: TextStyle(fontSize: 13, color: context.colors.inkSoft),
          ),
        ],
      ),
    );
  }
}
