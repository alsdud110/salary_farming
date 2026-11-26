import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';

/// 아이폰 알람처럼 오전/오후·시·분을 위아래로 돌려 고르는 시간 선택 시트.
/// 고른 시각을 자정 기준 분으로 돌려주고, 취소하면 null.
Future<int?> showTimeWheel(
  BuildContext context, {
  required String title,
  required int initialMinute,
}) {
  return showModalBottomSheet<int>(
    context: context,
    sheetAnimationStyle: Motion.sheet,
    showDragHandle: false,
    backgroundColor: context.colors.card,
    builder: (_) => _TimeWheelSheet(title: title, initialMinute: initialMinute),
  );
}

class _TimeWheelSheet extends StatefulWidget {
  const _TimeWheelSheet({required this.title, required this.initialMinute});

  final String title;
  final int initialMinute;

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  late int _minute = widget.initialMinute;

  @override
  Widget build(BuildContext context) {
    final initial = DateTime(
      2000,
      1,
      1,
      widget.initialMinute ~/ 60,
      widget.initialMinute % 60,
    );
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 취소 · 제목 · 확인 (아이폰 알람 편집 화면과 같은 배치)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.inkSoft,
                  ),
                  child: const Text('취소'),
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _minute),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          SizedBox(
            height: 216,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(
                    fontFamily: appFont,
                    fontSize: 22,
                    color: context.colors.ink,
                  ),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: initial,
                use24hFormat: false,
                onDateTimeChanged: (t) => _minute = t.hour * 60 + t.minute,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
