import 'dart:async';

import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';
import '../widgets/brand_symbol.dart';

/// 앱을 켤 때 잠깐 보이는 화면. 브랜드 심볼과 이름이 fade in 된 뒤 [onDone]을 부른다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  static const fadeIn = Duration(milliseconds: 600);
  static const hold = Duration(milliseconds: 500);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: SplashScreen.fadeIn,
  );
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted || _timer != null) return;
    // 동작 줄이기면 fade 없이 바로 보인다.
    if (Motion.reduced(context)) {
      _c.value = 1;
      _timer = Timer(SplashScreen.hold, widget.onDone);
    } else {
      _c.forward().whenComplete(() {
        if (mounted) _timer = Timer(SplashScreen.hold, widget.onDone);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.paper,
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandSymbol(size: 112),
              SizedBox(height: 16),
              Text(
                '월급파밍',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: context.colors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
