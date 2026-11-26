import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../format.dart';
import '../motion.dart';
import '../widgets/benefit_glyph.dart';
import '../theme.dart';
import '../widgets/brand_symbol.dart';

/// 첫 실행 소개 3장. 마지막 장의 "내 정보 입력하기" 로 설정을 시작한다.
/// 각 장의 데모 애니메이션은 그 장이 화면에 들어올 때마다 처음부터 재생된다.
class IntroView extends StatefulWidget {
  const IntroView({super.key, required this.onDone});

  final VoidCallback onDone;

  static const pageCount = 3;

  @override
  State<IntroView> createState() => _IntroViewState();
}

class _IntroViewState extends State<IntroView> {
  final _pages = PageController();
  int _page = 0;

  bool get _isLast => _page == IntroView.pageCount - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      widget.onDone();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: Align(
            alignment: Alignment.centerRight,
            child: AnimatedOpacity(
              opacity: _isLast ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: _isLast,
                child: TextButton(
                  onPressed: widget.onDone,
                  child: Text(
                    '건너뛰기',
                    style: TextStyle(
                      color: _isLast
                          ? Colors.transparent
                          : context.colors.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pages,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              _IntroPage(
                // 첫 장은 브랜드 심볼로 시작한다.
                leading: const BrandSymbol(size: 88),
                title: '일하는 동안\n월급이 자라는 걸 지켜보세요',
                body: '출근해서 퇴근할 때까지 월급이 쌓여요.\n점심시간에도 쉬지 않고요.',
                demo: _GrowingDemo(active: _page == 0),
              ),
              _IntroPage(
                title: '회사에서 챙긴 것도\n다 내가 번 돈이에요',
                body: '탕비실 간식, 점심 법카, 사내 헬스장까지.\n한 번 누르면 오늘 번 돈에 더해져요.',
                demo: _BenefitDemo(active: _page == 1),
              ),
              _IntroPage(
                title: '하루, 한 달, 일 년\n얼마 벌었는지 한눈에',
                body: '일·월·연도별 통계로\n월급과 회사에서 챙긴 돈을 함께 결산해요.',
                demo: _StatsDemo(active: _page == 2),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < IntroView.pageCount; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? context.colors.salary
                        : context.colors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: FilledButton(
            onPressed: _next,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(_isLast ? '내 정보 입력하기' : '다음', key: ValueKey(_isLast)),
            ),
          ),
        ),
      ],
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({
    this.leading,
    required this.title,
    required this.body,
    required this.demo,
  });

  /// 제목 위에 놓는 그림(첫 장의 브랜드 심볼).
  final Widget? leading;
  final String title;
  final String body;
  final Widget demo;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      children: [
        if (leading != null) ...[
          StaggerIn(
            index: 0,
            child: Align(alignment: Alignment.centerLeft, child: leading),
          ),
          const SizedBox(height: 20),
        ],
        // 제목 줄 → 설명 줄 → 데모 순서로 한 줄씩 나온다. 읽어 주기는 한 덩어리로.
        Semantics(
          header: true,
          label: title.replaceAll('\n', ' '),
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, line) in title.split('\n').indexed)
                StaggerIn(
                  index: i,
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 28,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final (i, line) in body.split('\n').indexed)
          StaggerIn(
            index: title.split('\n').length + i,
            child: Text(
              line,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: context.colors.inkSoft,
              ),
            ),
          ),
        const SizedBox(height: 32),
        StaggerIn(
          index: title.split('\n').length + body.split('\n').length,
          child: ExcludeSemantics(child: demo),
        ),
      ],
    );
  }
}

/// 0~1 진행값 [t] 에서 [start]~[start]+[length] 구간만 떼어 0~1로 바꾼 뒤 [curve] 를 입힌다.
double _segment(
  double t,
  double start,
  double length, [
  Curve curve = Curves.linear,
]) {
  final v = ((t - start) / length).clamp(0.0, 1.0);
  return curve.transform(v);
}

// ---------------------------------------------------------------------------
// 1장: 월급이 자라는 카드

/// 홈 화면의 "오늘 자란 월급" 카드를 줄인 것. 매 프레임 금액을 다시 계산해
/// 1초 단위로 끊기지 않고 계속 오른다.
class _GrowingDemo extends StatefulWidget {
  const _GrowingDemo({required this.active});

  final bool active;

  @override
  State<_GrowingDemo> createState() => _GrowingDemoState();
}

class _GrowingDemoState extends State<_GrowingDemo>
    with SingleTickerProviderStateMixin {
  // 세전 연봉 5,500만원(월 실수령 약 389만원), 9~18시(점심시간 포함) 근무의 오후 2시 반 무렵.
  static const _perSecond = 5.72;
  static const _workSeconds = 9 * 3600.0;
  static const _startSeconds = 4 * 3600 + 30 * 60.0;

  late final Ticker _ticker = createTicker(_tick);
  Duration _elapsed = Duration.zero;
  Duration _carried = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.active) _ticker.start();
  }

  @override
  void didUpdateWidget(_GrowingDemo old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ticker.isActive) {
      _ticker.start();
    } else if (!widget.active && _ticker.isActive) {
      // 다른 장에 가 있는 동안 멈췄다가 돌아오면 이어서 오른다.
      _carried = _elapsed;
      _ticker.stop();
    }
  }

  void _tick(Duration d) => setState(() => _elapsed = _carried + d);

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _startSeconds + _elapsed.inMicroseconds / 1e6;
    final value = (seconds * _perSecond).floor();
    final progress = seconds / _workSeconds;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '오늘의 총 수확',
                style: TextStyle(
                  color: AppColors.darkSub,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              const LiveDot(live: true),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              won(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                height: 1.15,
                fontWeight: FontWeight.w600,
                fontFeatures: tabular,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '매초 +5.72원씩 자라는 중',
            style: TextStyle(color: AppColors.darkSub, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.darkTrack,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Text(
                '오전 9:00',
                style: TextStyle(color: AppColors.fieldMuted, fontSize: 12),
              ),
              Spacer(),
              Text(
                '오후 6:00',
                style: TextStyle(color: AppColors.fieldMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2장: 회사에서 챙긴 돈

/// 항목이 하나씩 톡 튀어나오고, 그때마다 합계가 굴러 올라간다.
class _BenefitDemo extends StatefulWidget {
  const _BenefitDemo({required this.active});

  final bool active;

  static const items = [
    ('☕', '탕비실 커피', 2000, '오전 9:12'),
    ('🍱', '점심 법카', 10000, '오후 12:05'),
    ('🍪', '탕비실 간식', 1500, '오후 3:30'),
    ('🏋️', '사내 헬스장', 5000, '오후 6:40'),
  ];

  @override
  State<_BenefitDemo> createState() => _BenefitDemoState();
}

class _BenefitDemoState extends State<_BenefitDemo>
    with SingleTickerProviderStateMixin {
  // 0.3초 쉬고, 0.75초 간격으로 4개가 튀어나온다.
  static const _total = Duration(milliseconds: 3600);
  static const _first = 0.3 / 3.6;
  static const _gap = 0.75 / 3.6;
  static const _pop = 0.55 / 3.6;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _total,
  );

  @override
  void initState() {
    super.initState();
    // 움직임 줄이기 설정(MediaQuery)은 initState 안에서 읽을 수 없어 첫 프레임 뒤에 시작한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) _play();
    });
  }

  @override
  void didUpdateWidget(_BenefitDemo old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _play();
  }

  void _play() {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const items = _BenefitDemo.items;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        var landed = 0;
        var sum = 0;
        final pops = <double>[];
        for (var i = 0; i < items.length; i++) {
          final start = _first + _gap * i;
          pops.add(_segment(t, start, _pop));
          // 항목이 거의 다 튀어나왔을 때 합계에 더한다.
          if (t >= start + _pop * 0.35) {
            landed++;
            sum += items[i].$3;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      Opacity(
                        opacity: pops[i],
                        child: const Divider(indent: 16, endIndent: 16),
                      ),
                    _PoppingRow(item: items[i], t: pops[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _BenefitTotal(sum: sum, landed: landed),
          ],
        );
      },
    );
  }
}

/// 한 항목. [t] 0→1 동안 아래에서 살짝 튀어 올라오며 커졌다가 제자리에 앉는다.
/// 자리는 처음부터 차지해 두어 다른 항목이 밀리지 않는다.
class _PoppingRow extends StatelessWidget {
  const _PoppingRow({required this.item, required this.t});

  final (String, String, int, String) item;
  final double t;

  @override
  Widget build(BuildContext context) {
    final scale = 0.7 + 0.3 * Curves.easeOutBack.transform(t);
    final opacity = Curves.easeOut.transform((t * 1.8).clamp(0.0, 1.0));
    final dy = 14 * (1 - Curves.easeOutCubic.transform(t));
    // 아이콘은 본문보다 조금 늦게, 더 크게 튀어 오른다.
    final iconT = _segment(t, 0.15, 0.85, Curves.elasticOut);
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Transform.scale(
          scale: scale,
          child: ListTile(
            leading: Transform.scale(
              scale: 0.4 + 0.6 * iconT,
              child: BenefitGlyph(item.$1, size: 40),
            ),
            title: Text(
              item.$2,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(item.$4),
            trailing: Text(
              '+${won(item.$3)}',
              style: TextStyle(
                color: context.colors.benefitInk,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFeatures: tabular,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 합계. 항목이 더해질 때마다 숫자가 굴러 오르고 상자가 살짝 부풀었다 돌아온다.
class _BenefitTotal extends StatelessWidget {
  const _BenefitTotal({required this.sum, required this.landed});

  final int sum;
  final int landed;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // landed 가 바뀔 때마다 1.05 에서 1 로 돌아오는 짧은 튕김.
      key: ValueKey(landed),
      tween: Tween(begin: landed == 0 ? 1 : 1.05, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.benefitSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                '오늘 회사에서 챙긴 돈',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(end: sum.toDouble()),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(
                '+${won(v.round())}',
                style: TextStyle(
                  color: context.colors.benefitInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFeatures: tabular,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3장: 통계

/// 일·월·연도별 결산 맛보기. 막대가 왼쪽부터 차례로 차오르고 합계가 함께 오른다.
class _StatsDemo extends StatefulWidget {
  const _StatsDemo({required this.active});

  final bool active;

  @override
  State<_StatsDemo> createState() => _StatsDemoState();
}

class _StatsDemoState extends State<_StatsDemo>
    with SingleTickerProviderStateMixin {
  // (월급, 챙긴 돈) 만원 단위. 월~일.
  static const _week = [
    (18.5, 1.4),
    (18.5, 1.2),
    (18.5, 1.9),
    (18.5, 1.1),
    (18.5, 2.3),
    (0.0, 0.0),
    (0.0, 0.0),
  ];
  static const _weekTotal = 1004000;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    // 움직임 줄이기 설정(MediaQuery)은 initState 안에서 읽을 수 없어 첫 프레임 뒤에 시작한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) _play();
    });
  }

  @override
  void didUpdateWidget(_StatsDemo old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _play();
  }

  void _play() {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const maxValue = 21.0;
    const barArea = 140.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final count = _segment(t, 0, 0.85, Curves.easeOutCubic);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _PeriodTabs(),
                const SizedBox(height: 16),
                Text(
                  '이번 주 번 돈',
                  style: TextStyle(color: context.colors.inkSoft),
                ),
                const SizedBox(height: 2),
                Text(
                  won((_weekTotal * count).round()),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    fontFeatures: tabular,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  // 막대가 튀어 올랐다 돌아오는 만큼 위쪽 여유를 둔다.
                  height: barArea + 40,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < _week.length; i++)
                        Expanded(
                          child: _Bar(
                            salary: barArea * _week[i].$1 / maxValue,
                            benefit: barArea * _week[i].$2 / maxValue,
                            // 막대마다 0.08씩 늦게 출발해 0.5 동안 차오른다.
                            grow: _segment(
                              t,
                              0.08 * i,
                              0.5,
                              Curves.easeOutCubic,
                            ),
                            // 챙긴 돈은 월급 막대가 거의 찬 뒤 위에 얹힌다.
                            cap: _segment(
                              t,
                              0.08 * i + 0.35,
                              0.3,
                              Curves.easeOutCubic,
                            ),
                            label: weekdayLabels[i],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Legend(color: context.colors.salary, label: '기본 수익'),
                    SizedBox(width: 16),
                    _Legend(color: AppColors.benefit, label: '파밍 수익'),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.salary,
    required this.benefit,
    required this.grow,
    required this.cap,
    required this.label,
  });

  final double salary;
  final double benefit;
  final double grow;
  final double cap;
  final String label;

  @override
  Widget build(BuildContext context) {
    // 곡선이 1을 넘지 않지만 혹시 모를 음수만 막는다.
    final salaryH = (salary * grow).clamp(0.0, double.infinity);
    final benefitH = (benefit * cap).clamp(0.0, double.infinity);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 18,
          height: benefitH,
          decoration: const BoxDecoration(
            color: AppColors.benefit,
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        Container(
          width: 18,
          height: salaryH,
          decoration: BoxDecoration(
            color: context.colors.salary,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(benefitH < 1 ? 4 : 0),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.colors.inkSoft),
        ),
      ],
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (label, selected) in const [
          ('일간', false),
          ('주간', true),
          ('월간', false),
          ('연간', false),
        ])
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? context.colors.inverse : context.colors.paper,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : context.colors.inkSoft,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

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
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.colors.inkSoft),
        ),
      ],
    );
  }
}
