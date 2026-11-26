import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// tool/make_app_icon.dart 가 만든 런처 아이콘 확인.
void main() {
  group('앱 아이콘', () {
    const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    const res = 'android/app/src/main/res';

    test('iOS: Contents.json의 모든 크기가 맞고 투명이 없다', () {
      final contents = File('$ios/Contents.json').readAsStringSync();
      final files = RegExp(r'"filename" : "([^"]+)"')
          .allMatches(contents)
          .map((m) => m.group(1)!);
      for (final name in files) {
        final size = RegExp(r'(\d+(?:\.\d+)?)x[\d.]+@(\d)x').firstMatch(name)!;
        final px = (double.parse(size.group(1)!) * int.parse(size.group(2)!))
            .round();
        final image = img.decodePng(File('$ios/$name').readAsBytesSync())!;
        expect((image.width, image.height), (px, px), reason: name);
        expect(image.numChannels, 3, reason: '$name 에 알파가 있으면 App Store가 거절한다');
      }
    });

    test('Android: 적응형 아이콘의 앞 그림이 지름 66dp 안전 영역 안에 있다', () {
      expect(
        File('$res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync(),
        allOf(
          contains('@color/ic_launcher_background'),
          contains('@mipmap/ic_launcher_foreground'),
        ),
      );
      for (final (density, scale) in [
        ('mdpi', 1.0),
        ('hdpi', 1.5),
        ('xhdpi', 2.0),
        ('xxhdpi', 3.0),
        ('xxxhdpi', 4.0),
      ]) {
        final legacy = img.decodePng(
          File('$res/mipmap-$density/ic_launcher.png').readAsBytesSync(),
        )!;
        expect(legacy.width, (48 * scale).round());
        final fg = img.decodePng(
          File('$res/mipmap-$density/ic_launcher_foreground.png')
              .readAsBytesSync(),
        )!;
        expect(fg.width, (108 * scale).round());
        final c = fg.width / 2, r = 33 * scale + 1;
        for (var y = 0; y < fg.height; y++) {
          for (var x = 0; x < fg.width; x++) {
            if (fg.getPixel(x, y).a <= 8) continue;
            final d =
                (x + 0.5 - c) * (x + 0.5 - c) + (y + 0.5 - c) * (y + 0.5 - c);
            expect(d, lessThanOrEqualTo(r * r), reason: '$density ($x, $y)');
          }
        }
      }
    });
  });
}
