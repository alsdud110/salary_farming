import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _won = NumberFormat('#,###', 'ko_KR');

/// 12345 -> "12,345"
String comma(num value) => _won.format(value);

/// 12345 -> "12,345원"
String won(num value) => '${_won.format(value)}원';

/// 3000000 -> "300만원", 3250000 -> "325만원", 12345 -> "1만 2,345원"
String wonReadable(int value) {
  if (value < 10000) return won(value);
  final man = value ~/ 10000;
  final rest = value % 10000;
  if (rest == 0) return '${comma(man)}만원';
  return '${comma(man)}만 ${comma(rest)}원';
}

/// 분 단위 시각 -> "오전 9:00"
String clock(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final period = h < 12 ? '오전' : '오후';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$period $h12:${m.toString().padLeft(2, '0')}';
}

/// 분 -> "8시간", "7시간 30분"
String duration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m분';
  if (m == 0) return '$h시간';
  return '$h시간 $m분';
}

const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// 입력 중인 숫자에 천 단위 쉼표를 넣는다.
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final trimmed = digits.length > 12 ? digits.substring(0, 12) : digits;
    final text = comma(int.parse(trimmed));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

int? parseAmount(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}
