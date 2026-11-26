import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_store.dart';
import '../format.dart';
import '../models.dart';
import '../salary_calculator.dart';
import '../theme.dart';
import '../widgets/rolling_amount.dart';
import '../widgets/template_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _timer;
  BenefitCategory? _filter;

  /// 방금 적립한 기록. 금액이 떠오르는 효과에 쓴다.
  BenefitRecord? _justCredited;

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

  Future<void> _credit(BenefitTemplate t) async {
    HapticFeedback.lightImpact();
    final record = await store.credit(t);
    if (!mounted) return;
    setState(() => _justCredited = record);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 4),
        content: Text('${t.icon} ${t.name} +${won(t.amount)}'),
        action: SnackBarAction(
          label: '취소',
          onPressed: () => store.removeRecord(record.id),
        ),
      ));
  }

  Future<void> _removeRecord(BenefitRecord r) async {
    await store.removeRecord(r.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('${r.name} 기록을 지웠어요'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final now = store.now();
    final settings = store.currentSettings!;
    final salary = store.salaryOn(now, now).floor();
    final todayRecords = store.recordsOn(now);
    final benefit = todayRecords.fold(0, (sum, r) => sum + r.amount);
    final templates = store.templatesByFrequency
        .where((t) => _filter == null || t.category == _filter)
        .toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  '월급파밍',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  '${now.month}월 ${now.day}일 ${weekdayLabels[now.weekday - 1]}요일',
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          _TodayCard(
            settings: settings,
            now: now,
            salary: salary,
            benefit: benefit,
            justCredited: _justCredited,
          ),
          const SizedBox(height: 28),
          const _SectionTitle('혜택 줍기', hint: '받자마자 한 번만 누르면 끝'),
          const SizedBox(height: 10),
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
          const SizedBox(height: 12),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130,
              mainAxisExtent: 112,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            children: [
              for (final t in templates)
                _TemplateTile(
                  template: t,
                  onTap: () => _credit(t),
                  onLongPress: () => showTemplateSheet(context, store, template: t),
                ),
              _AddTile(onTap: () => showTemplateSheet(context, store)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '길게 누르면 이름과 금액을 고칠 수 있어요.',
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 28),
          _SectionTitle(
            '오늘 주운 것',
            hint: todayRecords.isEmpty ? null : '${todayRecords.length}건',
          ),
          const SizedBox(height: 10),
          if (todayRecords.isEmpty)
            const _EmptyRecords()
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < todayRecords.length; i++) ...[
                    if (i > 0) const Divider(indent: 16, endIndent: 16),
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

/// 오늘의 실제 급여 · 추가 혜택 · 총 가치.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.settings,
    required this.now,
    required this.salary,
    required this.benefit,
    required this.justCredited,
  });

  final WorkSettings settings;
  final DateTime now;
  final int salary;
  final int benefit;
  final BenefitRecord? justCredited;

  String _phaseHint(WorkPhase phase) {
    switch (phase) {
      case WorkPhase.dayOff:
        return '오늘은 밭도 쉬어요';
      case WorkPhase.beforeWork:
        return '${clock(settings.startMinute)}부터 자라기 시작해요';
      case WorkPhase.working:
        final perSec = SalaryCalculator.perSecond(settings, now);
        return '1초에 ${perSec.toStringAsFixed(1)}원씩 자라는 중';
      case WorkPhase.onBreak:
        return '${clock(settings.breakEndMinute)}에 다시 자라요';
      case WorkPhase.afterWork:
        return '오늘 수확 끝! 수고했어요';
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = SalaryCalculator.phase(settings, now);
    final progress = SalaryCalculator.progress(settings, now);
    final growing = phase == WorkPhase.working;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '오늘 자란 월급',
                style: TextStyle(
                  color: Color(0xFFB9D4BD),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _PhaseChip(phase: phase),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RollingAmount(
              value: salary,
              // 근무 중에는 다음 틱까지 쉬지 않고 굴러가게 1초 동안 고르게 올린다.
              duration: growing
                  ? const Duration(seconds: 1)
                  : const Duration(milliseconds: 600),
              curve: growing ? Curves.linear : Curves.easeOutCubic,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 46,
                height: 1.15,
                fontWeight: FontWeight.w900,
                fontFeatures: tabular,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _phaseHint(phase),
            style: const TextStyle(color: Color(0xFFB9D4BD), fontSize: 13),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFF2F5E3B),
              color: const Color(0xFF8FD19A),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                clock(settings.startMinute),
                style: const TextStyle(color: Color(0xFF8FB096), fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).floor()}%',
                style: const TextStyle(
                  color: Color(0xFFB9D4BD),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: tabular,
                ),
              ),
              const Spacer(),
              Text(
                clock(settings.endMinute),
                style: const TextStyle(color: Color(0xFF8FB096), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF173A22),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const _Dot(Color(0xFFF2C66B)),
                    const SizedBox(width: 8),
                    const Text(
                      '주운 혜택',
                      style: TextStyle(color: Color(0xFFD6E5D8), fontSize: 14),
                    ),
                    const Spacer(),
                    _CreditPop(record: justCredited),
                    RollingAmount(
                      value: benefit,
                      prefix: '+',
                      style: const TextStyle(
                        color: Color(0xFFF2C66B),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFeatures: tabular,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Color(0xFF2F5E3B)),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      '오늘의 총 가치',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: RollingAmount(
                          value: salary + benefit,
                          duration: growing
                              ? const Duration(seconds: 1)
                              : const Duration(milliseconds: 600),
                          curve: growing ? Curves.linear : Curves.easeOutCubic,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            fontFeatures: tabular,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ExcludeSemantics(
                child: Text(
                  '${r.icon} +${comma(r.amount)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF8FD19A) : const Color(0xFF2F5E3B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        phase.label,
        style: TextStyle(
          color: active ? AppColors.field : const Color(0xFFD6E5D8),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.hint});
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                hint!,
                style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
              ),
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
      child: Material(
        color: selected ? AppColors.ink : AppColors.card,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? AppColors.ink : AppColors.line),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.inkSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.onTap,
    required this.onLongPress,
  });

  final BenefitTemplate template;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = template;
    return Semantics(
      button: true,
      label: '${t.name} ${won(t.amount)} 적립',
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.benefitSoft,
          highlightColor: AppColors.benefitSoft,
          onTap: onTap,
          onLongPress: onLongPress,
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(t.icon, style: const TextStyle(fontSize: 28, height: 1.2)),
                  const SizedBox(height: 6),
                  Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '+${comma(t.amount)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.benefit,
                      fontFeatures: tabular,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.inkSoft, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 28, color: AppColors.ink),
            SizedBox(height: 6),
            Text(
              '직접 만들기',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record, required this.onDelete});

  final BenefitRecord record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 4, top: 6, bottom: 6),
      child: Row(
        children: [
          Text(r.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  clock(r.at.hour * 60 + r.at.minute),
                  style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          Text(
            '+${won(r.amount)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.benefit,
              fontFeatures: tabular,
            ),
          ),
          IconButton(
            tooltip: '${r.name} 기록 지우기',
            icon: const Icon(Icons.close, size: 20, color: AppColors.inkSoft),
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
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: const Column(
        children: [
          Text('🧺', style: TextStyle(fontSize: 30)),
          SizedBox(height: 8),
          Text(
            '바구니가 아직 비어 있어요',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            '탕비실 커피 한 잔부터 주워 볼까요?',
            style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
