import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../motion.dart';
import '../theme.dart';

/// 라이트 ↔ 다크 테마 바꾸기. 올인바이블 서랍의 테마 버튼과 같은 해·달 Lottie를 쓴다.
/// 누르면 [onToggle]이 테마를 바꾸고, 바뀐 [isDark]에 맞춰 해↔달 애니메이션이 재생된다.
class ThemeToggleTile extends StatefulWidget {
  const ThemeToggleTile({
    super.key,
    required this.isDark,
    required this.onToggle,
  });

  static const asset = 'assets/lottie/theme_toggler.json';

  final bool isDark;
  final VoidCallback onToggle;

  @override
  State<ThemeToggleTile> createState() => _ThemeToggleTileState();
}

class _ThemeToggleTileState extends State<ThemeToggleTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.isDark ? 1 : 0,
  );

  @override
  void didUpdateWidget(ThemeToggleTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 테마가 바뀌면 애니메이션 실행
    if (oldWidget.isDark != widget.isDark) {
      if (Motion.reduced(context)) {
        _controller.value = widget.isDark ? 1 : 0;
      } else if (widget.isDark) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: ExcludeSemantics(
                  // 해·달 원래 색 그대로
                  child: Lottie.asset(
                    ThemeToggleTile.asset,
                    controller: _controller,
                    onLoaded: (composition) {
                      _controller.duration = composition.duration;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isDark ? '다크 모드' : '라이트 모드',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isDark ? '어두운 테마 사용 중' : '밝은 테마 사용 중',
                      style: TextStyle(fontSize: 12, color: c.inkSoft),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.inkSoft, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
