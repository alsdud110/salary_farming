import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_store.dart';
import 'screens/root_screen.dart';
import 'screens/setup_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  runApp(SalaryFarmingApp(store: store));
}

class SalaryFarmingApp extends StatefulWidget {
  const SalaryFarmingApp({super.key, required this.store});

  final AppStore store;

  @override
  State<SalaryFarmingApp> createState() => _SalaryFarmingAppState();
}

class _SalaryFarmingAppState extends State<SalaryFarmingApp> {
  /// 첫 설정 화면을 보여주는 중인지. 저장 직후 계산 기준 안내까지 본 뒤에 끝난다.
  late bool _onboarding = !widget.store.isSetupDone;

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
          return _onboarding
              ? SetupScreen(
                  store: store,
                  onFinished: () => setState(() => _onboarding = false),
                )
              : RootScreen(store: store);
        },
      ),
    );
  }
}
