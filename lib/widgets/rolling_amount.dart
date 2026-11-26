import 'package:flutter/material.dart';

import '../format.dart';

/// 값이 바뀌면 이전 값에서 새 값까지 숫자가 굴러 올라가는 금액 표시.
class RollingAmount extends StatelessWidget {
  const RollingAmount({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
    this.prefix = '',
    this.suffix = '원',
  });

  final int value;
  final TextStyle style;
  final Duration duration;
  final Curve curve;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    // 움직임 줄이기를 켠 사용자에게는 바로 최종 값을 보여준다.
    final reduce = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: reduce ? Duration.zero : duration,
      curve: curve,
      builder: (context, v, _) => Text(
        '$prefix${comma(v.floor())}$suffix',
        style: style,
        maxLines: 1,
        semanticsLabel: '$prefix${comma(value)}$suffix',
      ),
    );
  }
}
