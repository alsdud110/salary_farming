import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_store.dart';
import 'motion.dart';
import 'screens/root_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  runApp(SalaryFarmingApp(store: store, splash: true));
}

class SalaryFarmingApp extends StatefulWidget {
  const SalaryFarmingApp({super.key, required this.store, this.splash = false});

  final AppStore store;

  /// 시작할 때 스플래시를 보여줄지. 앱 실행 때만 켜고, 테스트는 바로 첫 화면부터 본다.
  final bool splash;

  @override
  State<SalaryFarmingApp> createState() => _SalaryFarmingAppState();
}

class _SalaryFarmingAppState extends State<SalaryFarmingApp> {
  /// 첫 설정 화면을 보여주는 중인지. 저장 직후 계산 기준 안내까지 본 뒤에 끝난다.
  late bool _onboarding = !widget.store.isSetupDone;
  late bool _splash = widget.splash;

  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '월급파밍',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          // 데이터를 모두 지우면 다시 첫 설정부터 시작한다.
          if (!store.isSetupDone) _onboarding = true;
          final Widget app = _onboarding
              ? SetupScreen(
                  store: store,
                  onFinished: () => setState(() => _onboarding = false),
                )
              : RootScreen(store: store);
          // 스플래시에서 첫 화면으로 넘어갈 때만 겹쳐 바뀐다(설정↔홈 전환은 예전 그대로).
          return AnimatedSwitcher(
            duration: Motion.reduced(context)
                ? Duration.zero
                : const Duration(milliseconds: 300),
            child: _splash
                ? SplashScreen(
                    key: const ValueKey('splash'),
                    onDone: () => setState(() => _splash = false),
                  )
                : KeyedSubtree(key: const ValueKey('app'), child: app),
          );
        },
      ),
    );
  }
}
