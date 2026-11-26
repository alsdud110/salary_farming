import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'theme.dart';

/// 앱 전체 모션 규칙.
///
/// - 스낵바: 아래에서 밀려 올라온다. 들어올 때 ease out, 나갈 때 ease in.
/// - 토스트: 제자리에서 fade 로 나타났다 사라진다.
/// - 팝업: 살짝 커지면서(scale in) ease out 으로 나온다.
/// - 바텀시트: 아래에서 밀려 올라오고 뒤 배경은 fade 로 어두워진다.
/// - 누르는 반응(좋아요에 해당): scale 에 spring 을 줘서 톡 튀긴다.
/// - 로딩: linear 로 같은 속도로 계속 돈다.
/// - 제목·순서: 한 줄씩 순서대로 나온다.
///
/// 기기의 "움직임 줄이기"를 켜면 모두 움직임 없이 바로 나타난다.
class Motion {
  const Motion._();

  static const enter = Duration(milliseconds: 280);
  static const exit = Duration(milliseconds: 200);
  static const enterCurve = Curves.easeOut;
  static const exitCurve = Curves.easeIn;

  /// 한 줄씩 나올 때 줄 사이 간격.
  static const stagger = Duration(milliseconds: 70);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// 바텀시트: 아래에서 slide in(ease out), 내려갈 때 ease in.
  /// 뒤 배경이 어두워지는 fade 는 바텀시트 기본 동작 그대로 쓴다.
  static const sheet = AnimationStyle(
    duration: Duration(milliseconds: 320),
    reverseDuration: Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
}

// ---------------------------------------------------------------------------
// 스낵바 · 토스트

OverlayEntry? _current;

void _show(BuildContext context, Widget Function(VoidCallback remove) build) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final previous = _current;
  if (previous != null && previous.mounted) previous.remove();
  late OverlayEntry entry;
  void remove() {
    if (entry.mounted) entry.remove();
    if (identical(_current, entry)) _current = null;
  }

  entry = OverlayEntry(builder: (_) => build(remove));
  _current = entry;
  overlay.insert(entry);
}

/// 실행 취소처럼 누를 수 있는 동작이 있는 알림. 아래에서 밀려 올라온다.
void showAppSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(milliseconds: 1500),
}) {
  _show(
    context,
    (remove) => _Notice(
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      hold: duration,
      slide: true,
      onDone: remove,
    ),
  );
}

/// 동작 없이 알려만 주는 짧은 안내. 제자리에서 fade 로 나타났다 사라진다.
void showAppToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 1200),
}) {
  _show(
    context,
    (remove) =>
        _Notice(message: message, hold: duration, slide: false, onDone: remove),
  );
}

class _Notice extends StatefulWidget {
  const _Notice({
    required this.message,
    required this.hold,
    required this.slide,
    required this.onDone,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration hold;
  final bool slide;
  final VoidCallback onDone;

  @override
  State<_Notice> createState() => _NoticeState();
}

class _NoticeState extends State<_Notice> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.enter,
    reverseDuration: Motion.exit,
  );
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: widget.hold,
  );
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await _c.forward();
    if (!mounted) return;
    // 머무는 시간도 컨트롤러로 재서, 화면이 사라지면 함께 멈춘다(남는 타이머 없음).
    await _hold.forward().orCancel.catchError((_) {});
    if (!mounted) return;
    await _close();
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    await _c.reverse().orCancel.catchError((_) {});
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _hold.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) {
      _c
        ..duration = Duration.zero
        ..reverseDuration = Duration.zero;
    }
    final bottom = MediaQuery.paddingOf(context).bottom + 88;
    final enterAnim = CurvedAnimation(
      parent: _c,
      curve: Motion.enterCurve,
      reverseCurve: Motion.exitCurve,
    );

    Widget box = Material(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          widget.actionLabel == null ? 14 : 4,
          widget.actionLabel == null ? 18 : 4,
          widget.actionLabel == null ? 14 : 4,
        ),
        child: Row(
          mainAxisSize: widget.slide ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.message,
                style: const TextStyle(
                  fontFamily: appFont,
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            if (widget.actionLabel != null) ...[
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.coin),
                onPressed: () {
                  widget.onAction?.call();
                  _close();
                },
                child: Text(widget.actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );

    box = Semantics(liveRegion: true, container: true, child: box);

    final animated = widget.slide
        ? SlideTransition(
            position: Tween(
              begin: const Offset(0, 1.6),
              end: Offset.zero,
            ).animate(enterAnim),
            child: FadeTransition(opacity: enterAnim, child: box),
          )
        : FadeTransition(opacity: enterAnim, child: box);

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: animated,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 팝업

/// 확인 팝업. 살짝 작은 크기에서 커지며(ease out) 나타나고, 뒤 배경은 fade 로 어두워진다.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final reduced = Motion.reduced(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: reduced ? Duration.zero : Motion.enter,
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Motion.enterCurve,
        reverseCurve: Motion.exitCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// 누르는 반응: spring 으로 톡

/// 누르면 살짝 눌렸다가 spring 으로 톡 튀어 제자리로 돌아온다.
/// [child] 의 탭 처리는 그대로 두고, 눌림 신호만 받아 크기를 움직인다.
class SpringPress extends StatefulWidget {
  const SpringPress({super.key, required this.child});

  final Widget child;

  @override
  State<SpringPress> createState() => _SpringPressState();
}

class _SpringPressState extends State<SpringPress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 14,
  );

  void _down(PointerDownEvent _) {
    if (Motion.reduced(context)) return;
    _c.animateTo(
      0.92,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
    );
  }

  void _up(PointerEvent _) {
    if (Motion.reduced(context)) return;
    // 눌린 크기에서 위로 튀어 오르는 속도를 주고 spring 으로 1 에 자리 잡게 한다.
    _c.animateWith(SpringSimulation(_spring, _c.value, 1, 3.5));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) =>
            Transform.scale(scale: _c.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 로딩

/// 같은 속도(linear)로 계속 도는 로딩 표시.
class LinearSpinner extends StatefulWidget {
  const LinearSpinner({
    super.key,
    this.size = 20,
    this.color = AppColors.salary,
    this.track = AppColors.salarySoft,
  });

  final double size;
  final Color color;
  final Color track;

  @override
  State<LinearSpinner> createState() => _LinearSpinnerState();
}

class _LinearSpinnerState extends State<LinearSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = SizedBox(
      width: widget.size,
      height: widget.size,
      child: CircularProgressIndicator(
        value: 0.28,
        strokeWidth: 2.5,
        strokeCap: StrokeCap.round,
        color: widget.color,
        backgroundColor: widget.track,
      ),
    );
    if (Motion.reduced(context)) return ring;
    // RotationTransition 의 기본 곡선이 linear 라 같은 속도로 돈다.
    return Semantics(
      label: '불러오는 중',
      child: RotationTransition(turns: _c, child: ring),
    );
  }
}

// ---------------------------------------------------------------------------
// 한 줄씩 순서대로

/// [index] 번째 줄. 앞줄보다 조금 늦게, 아래에서 살짝 떠오르며 나타난다.
class StaggerIn extends StatelessWidget {
  const StaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.baseDelay = Duration.zero,
  });

  final int index;
  final Widget child;
  final Duration baseDelay;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    const length = 380;
    final delay =
        baseDelay.inMilliseconds + Motion.stagger.inMilliseconds * index;
    final total = delay + length;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// 여러 줄을 [StaggerIn] 으로 감싸 순서대로 나오게 한다.
List<Widget> staggered(
  List<Widget> children, {
  Duration baseDelay = Duration.zero,
}) => [
  for (var i = 0; i < children.length; i++)
    StaggerIn(index: i, baseDelay: baseDelay, child: children[i]),
];

// ---------------------------------------------------------------------------
// 시그니처: 살아 있는 점

/// 돈이 실제로 쌓이고 있을 때만 금액 옆에 뜨는 작은 점. 천천히 숨 쉬듯 깜빡인다.
/// 실시간으로 오르는 금액 옆에만 쓴다(다른 곳에는 쓰지 않는다).
class LiveDot extends StatefulWidget {
  const LiveDot({
    super.key,
    required this.live,
    this.color = AppColors.secondary,
  });

  final bool live;
  final Color color;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  void _sync() {
    final animate = widget.live && !Motion.reduced(context);
    if (animate && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LiveDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.live) return const SizedBox.shrink();
    return Semantics(
      label: '실시간으로 쌓이는 중',
      child: FadeTransition(
        opacity: Tween(
          begin: 0.35,
          end: 1.0,
        ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
