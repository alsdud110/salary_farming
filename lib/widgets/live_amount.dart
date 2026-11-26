import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../format.dart';

/// 매 프레임마다 [valueAt] 을 다시 읽어 금액을 보여준다.
///
/// 1초마다 값을 바꾸고 그 사이를 애니메이션으로 메우면 타이머와 애니메이션의
/// 박자가 어긋날 때 숫자가 잠깐씩 멈칫한다. 대신 지금 시각으로 금액을 바로 계산해
/// 화면이 그려질 때마다 반영하므로 끊김 없이 계속 오른다.
/// [running] 이 false 면 프레임을 돌리지 않고, 값이 바뀔 때만 짧게 굴러간다.
class LiveAmount extends StatefulWidget {
  const LiveAmount({
    super.key,
    required this.valueAt,
    required this.running,
    required this.style,
    this.prefix = '',
    this.suffix = '원',
  });

  final double Function() valueAt;
  final bool running;
  final TextStyle style;
  final String prefix;
  final String suffix;

  @override
  State<LiveAmount> createState() => _LiveAmountState();
}

class _LiveAmountState extends State<LiveAmount>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  late int _value = widget.valueAt().floor();

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(LiveAmount old) {
    super.didUpdateWidget(old);
    _value = widget.valueAt().floor();
    _sync();
  }

  void _sync() {
    if (widget.running && !_ticker.isActive) {
      _ticker.start();
    } else if (!widget.running && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration _) {
    final v = widget.valueAt().floor();
    if (v != _value) setState(() => _value = v);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = '${widget.prefix}${comma(_value)}${widget.suffix}';
    if (widget.running) {
      return Text(text, style: widget.style, maxLines: 1);
    }
    // 멈춰 있을 때 값이 바뀌면(퇴근 후 다시 열기 등) 부드럽게 굴러간다.
    final reduce = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _value.toDouble()),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        '${widget.prefix}${comma(v.floor())}${widget.suffix}',
        style: widget.style,
        maxLines: 1,
        semanticsLabel: text,
      ),
    );
  }
}
