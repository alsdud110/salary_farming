import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_store.dart';
import 'salary_calculator.dart';

const _channel = MethodChannel('salary_farming/widget');

/// 홈 화면 위젯이 앱을 열지 않아도 계산할 수 있게 넘기는 달별 예상 실수령.
/// 세금 계산은 앱에서 끝내고, 위젯은 홈의 월 누적과 같은
/// "예상 실수령 × 이번 달이 지난 비율"만 계산한다.
/// 앞으로 [months]달치를 미리 넘기므로 달이 바뀌어도 앱을 열지 않고 이어서 오른다.
List<Map<String, Object>> widgetMonths(AppStore store, {int months = 3}) {
  final s = store.currentSettings;
  if (s == null) return [];
  final now = store.now();
  int sec(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
  return [
    for (var i = 0; i < months; i++)
      {
        'start': sec(DateTime(now.year, now.month + i)),
        'end': sec(DateTime(now.year, now.month + i + 1)),
        'expected': SalaryCalculator.expectedInMonth(
          s,
          DateTime(now.year, now.month + i),
        ).round(),
      },
  ];
}

/// 위젯 데이터를 iOS 공유 저장소에 쓰고 위젯을 다시 그리게 한다.
Future<void> syncHomeWidget(AppStore store) async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return;
  try {
    await _channel.invokeMethod('update', jsonEncode(widgetMonths(store)));
  } on MissingPluginException {
    // 테스트 등 위젯이 없는 환경.
  } on PlatformException catch (e) {
    debugPrint('위젯 데이터를 쓰지 못했습니다: $e');
  }
}
