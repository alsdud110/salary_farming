// 앱 아이콘 원본 한 장으로 iOS·Android 런처 아이콘을 모두 만든다.
//
//   dart run tool/make_app_icon.dart
//
// 입력: art/source/app_icon.png (정사각형, 흰 배경)
// 출력:
//   iOS     ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png
//           iOS는 앱 아이콘에 투명을 쓸 수 없어 원본의 흰 배경 그대로(알파 없는 RGB).
//   Android mipmap-*/ic_launcher.png  (Android 7 이하용, 원본 그대로)
//           mipmap-*/ic_launcher_foreground.png (Android 8+ 적응형 아이콘의 앞 그림, 투명 배경)
//           적응형 아이콘의 뒤 배경은 흰색 한 장(values/ic_launcher_background.xml)이고,
//           둘을 묶는 설정은 mipmap-anydpi-v26/ic_launcher.xml 이다.
//
// 적응형 아이콘은 기기마다 원·둥근 사각형 등으로 잘린다. 어떤 모양이든 잘리지 않도록
// 그림 높이를 108dp 중 [foregroundContentDp] 로 맞춰 가운데 둔다(안전 영역은 지름 66dp 원).
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const source = 'art/source/app_icon.png';
const foregroundContentDp = 50.0;

const iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const iosIcons = {
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

/// 밀도별 배율(mdpi = 1).
const androidDensities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

img.Image resize(img.Image src, int side) => img.copyResize(
  src,
  width: side,
  height: side,
  interpolation: img.Interpolation.average,
);

void main() {
  final src = img.decodeImage(File(source).readAsBytesSync())!;
  if (src.width != src.height) {
    stderr.writeln('$source 는 정사각형이어야 한다 (${src.width}x${src.height})');
    exit(1);
  }
  final opaque = src.convert(numChannels: 3);

  for (final e in iosIcons.entries) {
    File('$iosDir/${e.key}').writeAsBytesSync(img.encodePng(resize(opaque, e.value)));
  }

  final (cutout, box) = removeWhiteBackground(src);
  // 그림 부분만 잘라 108dp 캔버스 가운데에 [foregroundContentDp] 높이로 놓는다.
  final content = img.copyCrop(
    cutout,
    x: box.$1,
    y: box.$2,
    width: box.$3 - box.$1 + 1,
    height: box.$4 - box.$2 + 1,
  );
  for (final e in androidDensities.entries) {
    final dir = 'android/app/src/main/res/mipmap-${e.key}';
    File('$dir/ic_launcher.png')
        .writeAsBytesSync(img.encodePng(resize(opaque, (48 * e.value).round())));

    final canvasSide = (108 * e.value).round();
    final h = (foregroundContentDp * e.value).round();
    final w = (content.width * h / content.height).round();
    final fg = img.Image(width: canvasSide, height: canvasSide, numChannels: 4);
    img.compositeImage(
      fg,
      img.copyResize(content, width: w, height: h, interpolation: img.Interpolation.average),
      dstX: (canvasSide - w) ~/ 2,
      dstY: (canvasSide - h) ~/ 2,
    );
    File('$dir/ic_launcher_foreground.png').writeAsBytesSync(img.encodePng(fg));
  }
  stdout.writeln('iOS ${iosIcons.length}개, Android ${androidDensities.length * 2}개 만듦 '
      '(그림 영역 ${box.$3 - box.$1 + 1}x${box.$4 - box.$2 + 1})');
}

/// 가장자리에서 이어진 흰 배경을 투명하게 만든다. 그림 안쪽의 밝은 색(₩ 글자 등)은 건드리지 않는다.
/// 배경과 맞닿은 2픽셀은 흰색과 섞인 만큼을 투명도로 되돌려 흰 테두리가 남지 않게 한다
/// (tool/make_icons.dart 와 같은 방법). 반환: (투명 배경 그림, 그림 영역 minX, minY, maxX, maxY).
(img.Image, (int, int, int, int)) removeWhiteBackground(img.Image src) {
  final w = src.width, h = src.height;
  bool white(int x, int y) {
    final p = src.getPixel(x, y);
    final lo = math.min(p.r, math.min(p.g, p.b)), hi = math.max(p.r, math.max(p.g, p.b));
    return lo >= 246 && hi - lo <= 8;
  }

  final bg = List.filled(w * h, false);
  final queue = <int>[];
  void seed(int x, int y) {
    if (!bg[y * w + x] && white(x, y)) {
      bg[y * w + x] = true;
      queue.add(y * w + x);
    }
  }

  for (var x = 0; x < w; x++) {
    seed(x, 0);
    seed(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    seed(0, y);
    seed(w - 1, y);
  }
  for (var i = 0; i < queue.length; i++) {
    final x = queue[i] % w, y = queue[i] ~/ w;
    if (x > 0) seed(x - 1, y);
    if (x < w - 1) seed(x + 1, y);
    if (y > 0) seed(x, y - 1);
    if (y < h - 1) seed(x, y + 1);
  }

  final dist = List.filled(w * h, 99);
  var frontier = [for (var i = 0; i < w * h; i++) if (bg[i]) i];
  for (final i in frontier) {
    dist[i] = 0;
  }
  for (var d = 1; d <= 2; d++) {
    final next = <int>[];
    for (final i in frontier) {
      final x = i % w, y = i ~/ w;
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final j = ny * w + nx;
        if (dist[j] > d) {
          dist[j] = d;
          next.add(j);
        }
      }
    }
    frontier = next;
  }

  final out = img.Image(width: w, height: h, numChannels: 4);
  var minX = w, minY = h, maxX = -1, maxY = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (bg[i]) continue;
      final p = src.getPixel(x, y);
      if (dist[i] <= 2) {
        final r = p.r.toDouble(), g = p.g.toDouble(), b = p.b.toDouble();
        final a = ((255 - math.min(r, math.min(g, b))) / 255).clamp(0.0, 1.0);
        if (a < 0.02) continue;
        int un(double c) => ((c - 255 * (1 - a)) / a).round().clamp(0, 255);
        out.setPixelRgba(x, y, un(r), un(g), un(b), (a * 255).round());
      } else {
        out.setPixelRgba(x, y, p.r, p.g, p.b, 255);
      }
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
  }
  return (out, (minX, minY, maxX, maxY));
}
