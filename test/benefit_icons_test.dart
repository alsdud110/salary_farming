import 'package:flutter_test/flutter_test.dart';
import 'package:salary_farming/benefit_icons.dart';
import 'package:salary_farming/default_templates.dart';

import '../tool/make_icons.dart' as tool;

void main() {
  test('시트 자르는 도구와 앱의 아이콘 순서가 같다', () {
    expect(tool.sheets.length, benefitIconSheets.length);
    for (final name in benefitIconSheets.keys) {
      final path = 'art/source/icons/${name}_sheet.png';
      expect(tool.sheets[path], benefitIconSheets[name]!.map((i) => i.asset).toList(),
          reason: path);
    }
  });

  test('기본 템플릿 아이콘은 모두 아이콘 목록에 있다', () {
    for (final t in defaultTemplates) {
      expect(benefitIconFor(t.icon), isNotNull, reason: t.name);
    }
  });

  test('아이콘 키와 파일 이름이 겹치지 않는다', () {
    expect(benefitIcons.map((i) => i.key).toSet().length, benefitIcons.length);
    expect(benefitIcons.map((i) => i.asset).toSet().length, benefitIcons.length);
  });
}
