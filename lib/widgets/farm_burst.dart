import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../theme.dart';

/// 적립 직후 띄우는 짧은 한마디. 자주 쓰는 혜택은 상황에 맞게, 나머지는 이름으로.
String farmMessage(BenefitTemplate t) {
  final name = t.name;
  bool has(List<String> words) => words.any(name.contains);
  if (t.icon == '☕' || has(['커피', '라떼', '아메리카노'])) {
    return '커피 한 잔 파밍 완료!';
  }
  if (t.icon == '🍱' || has(['식대', '점심', '식사', '밥'])) {
    return '오늘의 점심도 수확했어요!';
  }
  if (t.icon == '🍪' || has(['간식', '과자'])) {
    return '소소한 행복 +1';
  }
  return '$name +${won(t.amount)} 파밍했어요';
}

/// 혜택 칸에서 동전이 튀어나와 수확 카드로 날아가고, 적립 금액이 떠올랐다 사라진다.
///
/// 화면 맨 위 레이어에 그리고 터치는 모두 통과시키므로, 효과가 도는 동안에도
/// 다른 칸을 누르거나 화면을 옮길 수 있다. 데이터 저장과는 무관하다(보여주기만 한다).
class FarmBurst {
  const FarmBurst._();

  static const duration = Duration(milliseconds: 700);

  /// 연속으로 누를 때 한꺼번에 떠 있는 효과 수. 넘치면 가장 오래된 것부터 지운다.
  static const maxActive = 3;

  static final _active = <OverlayEntry>[];

  @visibleForTesting
  static int get activeCount => _active.length;

  /// [from]은 누른 칸, [to]는 동전이 날아갈 곳. 위치는 매 프레임 다시 읽어서, 효과 도중
  /// 목록이 밀리거나 스크롤돼도 칸과 카드를 따라간다. [to]가 없거나 화면 위로 벗어나 있으면
  /// 화면 위쪽 가운데로 날아간다.
  static void show(
    BuildContext context, {
    required RenderBox from,
    required RenderBox? to,
    required int amount,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final box = overlay.context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !from.attached) return;
    final top = MediaQuery.paddingOf(context).top + 24;

    while (_active.length >= maxActive) {
      final old = _active.removeAt(0);
      if (old.mounted) old.remove();
    }
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Burst(
        overlay: box,
        from: from,
        to: to,
        fallbackTop: top,
        amount: amount,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
        // 끝나서 지웠든, 화면이 통째로 사라졌든 목록에서 빠진다.
        onDispose: () => _active.remove(entry),
      ),
    );
    _active.add(entry);
    overlay.insert(entry);
  }
}

class _Burst extends StatefulWidget {
  const _Burst({
    required this.overlay,
    required this.from,
    required this.to,
    required this.fallbackTop,
    required this.amount,
    required this.onDone,
    required this.onDispose,
  });

  final RenderBox overlay;
  final RenderBox from;
  final RenderBox? to;
  final double fallbackTop;
  final int amount;
  final VoidCallback onDone;
  final VoidCallback onDispose;

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late Rect? _from = _rectOf(widget.from);
  late Rect _to = _target();
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: FarmBurst.duration,
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenCompleteOrCancel(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    widget.onDispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // 칸이 사라졌으면(화면 전환 등) 마지막으로 본 자리에서 마저 그린다.
          _from = _rectOf(widget.from) ?? _from;
          _to = _target();
          final from = _from;
          if (from == null) return const SizedBox.shrink();
          final origin = Offset(from.center.dx, from.top + from.height * 0.35);
          return Stack(
            children: [
              ..._sparkles(origin, t),
              _amount(from, t),
              _coin(origin, _to.center, t),
            ],
          );
        },
      ),
    );
  }

  /// [box]의 자리(오버레이 기준). 화면에서 빠졌으면 null.
  Rect? _rectOf(RenderBox? box) {
    if (box == null || !box.attached || !box.hasSize) return null;
    final o = box.localToGlobal(Offset.zero, ancestor: widget.overlay);
    return o & box.size;
  }

  Rect _target() {
    final r = _rectOf(widget.to);
    if (r != null && r.bottom >= widget.fallbackTop) return r;
    return Rect.fromCenter(
      center: Offset(widget.overlay.size.width / 2, widget.fallbackTop),
      width: 1,
      height: 1,
    );
  }

  /// 칸 위쪽에서 작은 점 네 개가 퍼졌다 사라진다.
  List<Widget> _sparkles(Offset origin, double t) {
    final p = Curves.easeOutCubic.transform((t / 0.5).clamp(0.0, 1.0));
    if (p >= 1) return const [];
    const angles = [-150.0, -105.0, -75.0, -30.0];
    return [
      for (var i = 0; i < angles.length; i++)
        _at(
          origin + Offset.fromDirection(angles[i] * math.pi / 180, 10 + 22 * p),
          Opacity(
            opacity: 1 - p,
            child: Container(
              width: i.isEven ? 6 : 4,
              height: i.isEven ? 6 : 4,
              decoration: BoxDecoration(
                color: i.isEven ? AppColors.coin : AppColors.benefitOnDark,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
    ];
  }

  /// "+2,000원"이 칸 윗부분에서 떠올랐다 사라진다(칸 밖 제목과 겹치지 않게).
  Widget _amount(Rect from, double t) {
    final rise = Curves.easeOutCubic.transform((t / 0.85).clamp(0.0, 1.0));
    final fade = t < 0.5 ? 1.0 : 1 - (t - 0.5) / 0.5;
    return _at(
      Offset(from.center.dx, from.top + 14 - 24 * rise),
      Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: Text(
          '+${won(widget.amount)}',
          // 앱 맨 위 레이어라 Material 글꼴 설정이 없어 직접 정한다.
          style: const TextStyle(
            fontFamily: appFont,
            decoration: TextDecoration.none,
            color: AppColors.benefitInk,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFeatures: tabular,
          ),
        ),
      ),
    );
  }

  /// 동전: 잠깐 톡 솟았다가 수확 카드 쪽으로 곡선을 그리며 날아가 작아진다.
  Widget _coin(Offset start, Offset end, double t) {
    final pop = Curves.easeOut.transform((t / 0.2).clamp(0.0, 1.0));
    final fly = Curves.easeInCubic.transform(
      ((t - 0.15) / 0.85).clamp(0.0, 1.0),
    );
    final lifted = start + Offset(0, -18 * pop);
    // 위로 볼록한 2차 곡선
    final control = Offset(
      (lifted.dx + end.dx) / 2,
      math.min(lifted.dy, end.dy) - 40,
    );
    final u = 1 - fly;
    final pos = lifted * (u * u) + control * (2 * u * fly) + end * (fly * fly);
    final scale = lerpDouble(0.6 + 0.4 * pop, 0.55, fly)!;
    final opacity = fly < 0.85 ? 1.0 : 1 - (fly - 0.85) / 0.15;
    return _at(
      pos,
      Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(scale: scale, child: const _Coin()),
      ),
    );
  }

  /// [center]에 [child]의 가운데를 맞춘다.
  Widget _at(Offset center, Widget child) => Positioned(
    left: center.dx,
    top: center.dy,
    child: FractionalTranslation(
      translation: const Offset(-0.5, -0.5),
      child: child,
    ),
  );
}

/// 평면 동전: 골드 원 + 안쪽 테두리.
class _Coin extends StatelessWidget {
  const _Coin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: AppColors.coin,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.benefitOnDark, width: 2),
        ),
      ),
    );
  }
}
