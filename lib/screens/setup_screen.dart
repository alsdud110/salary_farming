import 'dart:async';

import 'package:flutter/material.dart';

import '../app_store.dart';
import '../format.dart';
import '../models.dart';
import '../motion.dart';
import '../salary_calculator.dart';
import '../theme.dart';
import '../widgets/benefit_glyph.dart';
import '../widgets/brand_symbol.dart';
import '../widgets/work_settings_form.dart';
import 'intro_view.dart';

enum _Step { intro, job, pay, time, loading, ready }

/// 첫 실행 온보딩. 소개 → 직업군 → 급여 → 근무 시간 → 세팅 중 → 시작 확인.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.store, required this.onFinished});

  final AppStore store;
  final VoidCallback onFinished;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _draft = SettingsDraft();
  _Step _step = _Step.intro;
  WorkSettings? _result;
  bool _forward = true;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheBenefitIcons(context);
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    _forward = true;
    switch (_step) {
      case _Step.job:
        setState(() => _step = _Step.pay);
      case _Step.pay:
        if (_draft.check(_draft.payError)) setState(() => _step = _Step.time);
      case _Step.time:
        if (_draft.check(_draft.validate)) {
          setState(() {
            _result = _draft.build();
            _step = _Step.loading;
          });
        }
      case _Step.intro:
      case _Step.loading:
      case _Step.ready:
        break;
    }
  }

  void _back() {
    FocusScope.of(context).unfocus();
    _forward = false;
    _draft.update(() {});
    setState(() {
      _step = switch (_step) {
        _Step.job => _Step.intro,
        _Step.pay => _Step.job,
        _Step.time => _Step.pay,
        _Step.ready => _Step.time,
        _ => _step,
      };
    });
  }

  Future<void> _start() async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.store.saveSettings(_result!);
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _Step.intro,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step != _Step.loading) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: _StepSwitcher(
            forward: _forward,
            child: switch (_step) {
              _Step.intro => IntroView(
                key: const ValueKey('intro'),
                onDone: () => setState(() {
                  _forward = true;
                  _step = _Step.job;
                }),
              ),
              _Step.loading => _LoadingView(
                key: const ValueKey('loading'),
                onDone: () {
                  if (mounted) {
                    setState(() {
                      _forward = true;
                      _step = _Step.ready;
                    });
                  }
                },
              ),
              _Step.ready => _ReadyView(
                key: const ValueKey('ready'),
                settings: _result!,
                now: widget.store.now(),
                saving: _saving,
                onStart: _start,
                onBack: _back,
              ),
              _ => KeyedSubtree(
                key: const ValueKey('form'),
                child: _buildFormStep(),
              ),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFormStep() {
    final index = _step.index - _Step.job.index; // 0, 1, 2
    final (kicker, title, subtitle) = switch (_step) {
      _Step.job => ('직업', '어떤 일을 하세요?', '직업군에 맞춰 급여 계산 방식을 골라 드려요'),
      _Step.pay => ('급여', '급여를 알려주세요', '세금은 월급파밍이 알아서 떼고 계산해요'),
      _ => ('근무 시간', '언제 일하세요?', '출근부터 퇴근까지 월급이 자라요. 점심시간 포함 여부도 고를 수 있어요.'),
    };

    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 20, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: '이전',
                  onPressed: _back,
                  icon: Icon(Icons.arrow_back, color: context.colors.ink),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: (index + 1) / 3),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        backgroundColor: context.colors.line,
                        color: context.colors.salary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${index + 1} / 3',
                  style: TextStyle(
                    color: context.colors.inkSoft,
                    fontWeight: FontWeight.w600,
                    fontFeatures: tabular,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _StepSwitcher(
              forward: _forward,
              child: ListView(
                key: ValueKey(_step),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  StaggerIn(
                    index: 0,
                    child: Text(
                      kicker,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.colors.fieldText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  StaggerIn(
                    index: 1,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  StaggerIn(
                    index: 2,
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: context.colors.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  StaggerIn(
                    index: 3,
                    child: switch (_step) {
                      _Step.job => JobTypePicker(draft: _draft),
                      _Step.pay => PayFields(draft: _draft),
                      _ => WorkTimeFields(draft: _draft),
                    },
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _draft.error == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: ErrorBox(_draft.error!),
                          ),
                  ),
                  if (_step == _Step.job) ...[
                    const SizedBox(height: 20),
                    Text(
                      '입력한 내용은 이 기기에만 저장되고 어디로도 전송되지 않아요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.inkSoft,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: FilledButton(
              onPressed: _next,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _step == _Step.time ? '설정 완료' : '다음',
                  key: ValueKey(_step == _Step.time),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 단계가 바뀔 때 새 화면이 진행 방향에서 살짝 밀려 들어오며 나타난다.
class _StepSwitcher extends StatelessWidget {
  const _StepSwitcher({required this.forward, required this.child});

  final bool forward;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == this.child.key;
        final dx = forward == incoming ? 0.06 : -0.06;
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: Offset(dx, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// "월급 계산표 만드는 중" 화면. 할 일 네 줄에 차례로 체크가 찍힌 뒤 [onDone] 을 부른다.
class _LoadingView extends StatefulWidget {
  const _LoadingView({super.key, required this.onDone});

  final VoidCallback onDone;

  static const messages = ['직업군 확인', '세금과 4대보험 떼기', '하루치 월급 나누기', '월급 씨앗 심기'];
  static const stepDuration = Duration(milliseconds: 650);

  /// 마지막 줄에 체크가 찍히고 다음 화면으로 넘어가기 전 잠깐 보여주는 시간.
  static const holdDuration = Duration(milliseconds: 450);

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView> {
  Timer? _timer;
  Timer? _hold;

  /// 체크가 찍힌 줄 수. 이 값의 줄이 지금 진행 중인 줄이다.
  int _done = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_LoadingView.stepDuration, (t) {
      setState(() => _done++);
      if (_done >= _LoadingView.messages.length) {
        t.cancel();
        _hold = Timer(_LoadingView.holdDuration, widget.onDone);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const messages = _LoadingView.messages;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggerIn(
            index: 0,
            child: Text(
              '설정 반영',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.colors.fieldText,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const StaggerIn(
            index: 1,
            child: Text(
              '월급 계산표 만드는 중',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          StaggerIn(
            index: 2,
            child: Text(
              '급여와 근무 시간으로 하루치와 1초치를 계산해요',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: context.colors.inkSoft,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (var i = 0; i < messages.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 52),
                  StaggerIn(
                    index: 3 + i,
                    child: _TaskRow(
                      label: messages[i],
                      state: i < _done
                          ? _TaskState.done
                          : i == _done
                          ? _TaskState.running
                          : _TaskState.waiting,
                    ),
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

enum _TaskState { waiting, running, done }

/// 할 일 한 줄. 대기는 흐린 빈 원, 진행은 도는 원, 끝나면 체크가 톡 찍힌다.
class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.label, required this.state});

  final String label;
  final _TaskState state;

  @override
  Widget build(BuildContext context) {
    final indicator = switch (state) {
      _TaskState.waiting => Container(
        key: const ValueKey('waiting'),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.colors.line, width: 2),
        ),
      ),
      _TaskState.running => const LinearSpinner(key: ValueKey('running')),
      _TaskState.done => TweenAnimationBuilder<double>(
        key: const ValueKey('done'),
        tween: Tween(begin: 0.4, end: 1),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: Icon(Icons.check_circle, size: 20, color: context.colors.salary),
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: indicator,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontFamily: appFont,
                fontSize: 16,
                fontWeight: state == _TaskState.waiting
                    ? FontWeight.w400
                    : FontWeight.w600,
                color: state == _TaskState.waiting
                    ? context.colors.inkSoft
                    : context.colors.ink,
              ),
              child: Text(label),
            ),
          ),
          AnimatedOpacity(
            opacity: state == _TaskState.done ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: Text(
              '완료',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.colors.fieldText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 세팅 결과와 "월급파밍을 시작할까요?" 확인.
class _ReadyView extends StatelessWidget {
  const _ReadyView({
    super.key,
    required this.settings,
    required this.now,
    required this.saving,
    required this.onStart,
    required this.onBack,
  });

  final WorkSettings settings;
  final DateTime now;
  final bool saving;
  final VoidCallback onStart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final today = SalaryCalculator.earnedOn(s, now, now).floor();
    var month = 0.0;
    for (var d = 1; d <= now.day; d++) {
      month += SalaryCalculator.earnedOn(
        s,
        DateTime(now.year, now.month, d),
        now,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                const StaggerIn(
                  index: 0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BrandSymbol(size: 80),
                  ),
                ),
                const SizedBox(height: 16),
                StaggerIn(
                  index: 0,
                  child: Text(
                    '세팅 완료',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.colors.fieldText,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const StaggerIn(
                  index: 1,
                  child: Text(
                    '월급파밍을 시작할까요?',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                StaggerIn(
                  index: 2,
                  child: Text(
                    '${s.jobType.label} · ${s.payBasis.label} ${wonReadable(s.payAmount)} · '
                    '${clock(s.startMinute)}–${clock(s.endMinute)}',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: context.colors.inkSoft,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _Rise(
                  delay: 240,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.field,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '지금 이 순간까지 ${now.month}월에 쌓인 월급',
                          style: const TextStyle(
                            color: AppColors.darkSub,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: _CountUp(
                            value: month.floor(),
                            delay: 250,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w600,
                              fontFeatures: tabular,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _CountUp(
                          value: today,
                          delay: 250,
                          prefix: '오늘 ',
                          style: const TextStyle(
                            color: AppColors.darkSub,
                            fontWeight: FontWeight.w600,
                            fontFeatures: tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Rise(
                  delay: 320,
                  child: BasisCard(settings: s, today: now),
                ),
                const SizedBox(height: 12),
                Text(
                  '설정은 언제든 설정 탭에서 바꿀 수 있어요',
                  style: TextStyle(fontSize: 13, color: context.colors.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: saving ? null : onStart,
            child: const Text('월급파밍 시작하기'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: saving ? null : onBack,
            child: const Text('설정 다시 보기'),
          ),
        ],
      ),
    );
  }
}

/// [delay] 밀리초 뒤에 아래에서 살짝 떠오르며 나타난다.
class _Rise extends StatelessWidget {
  const _Rise({required this.delay, required this.child});

  final int delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const length = 480;
    final total = delay + length;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// 0원에서 [value] 까지 굴러 오르는 금액.
class _CountUp extends StatelessWidget {
  const _CountUp({
    required this.value,
    required this.style,
    this.delay = 0,
    this.prefix = '',
  });

  final int value;
  final TextStyle style;
  final int delay;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    const length = 1100;
    final total = delay + length;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? value.toDouble() : 0, end: value.toDouble()),
      duration: Duration(milliseconds: reduce ? 0 : total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, v, _) => Text(
        '$prefix${won(v.floor())}',
        style: style,
        semanticsLabel: '$prefix${won(value)}',
      ),
    );
  }
}
